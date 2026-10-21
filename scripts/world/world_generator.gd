class_name WorldGenerator
extends RefCounted
## Geração determinística e pura: (seed, x, y) → block_id.
## Não guarda estado mutável além dos geradores de ruído; seguro para chamar em qualquer ordem.

const SALT_ORE: int = 0x51ED27
const SALT_VARIANT: int = 0x2F9A11
## Multiplicador de chance dentro de um veio (ruído de minério alto).
const VEIN_MULT: float = 3.0
const OUTSIDE_VEIN_MULT: float = 0.55
const VEIN_THRESHOLD: float = 0.25
## Escala vertical das cavernas (<1 = cavernas mais largas que altas).
const CAVE_Y_SCALE: float = 1.45
## Linhas após SAFE_SURFACE_ROWS em que as cavernas aparecem gradualmente.
const CAVE_FADE_ROWS: int = 10

var seed_value: int = 0
var _cave: FastNoiseLite
var _mix: FastNoiseLite
var _ore: FastNoiseLite
var _border: FastNoiseLite
# Tabelas de minério pré-processadas por bioma (evita consultas por célula).
var _ore_ids: Array[PackedInt32Array] = []
var _ore_chance: Array[PackedFloat32Array] = []
var _ore_min_row: Array[PackedInt32Array] = []
var _ore_in_vein: Array[PackedByteArray] = []
var _boundaries: PackedInt32Array = PackedInt32Array()


func _init(p_seed: int) -> void:
	seed_value = p_seed
	_cave = _make_noise(p_seed, 0.07, 2)
	_mix = _make_noise(p_seed + 101, 0.11, 1)
	_ore = _make_noise(p_seed + 202, 0.17, 1)
	_border = _make_noise(p_seed + 303, 0.21, 1)
	_prepare_tables()


## Também garante que os registros estáticos estejam construídos antes de uso em threads.
func _prepare_tables() -> void:
	BlockRegistry.all()
	for b in BiomeRegistry.COUNT:
		var biome: BiomeDef = BiomeRegistry.get_def(b)
		if b > 0:
			_boundaries.append(biome.start_row)
		var ids := PackedInt32Array()
		var chance := PackedFloat32Array()
		var min_row := PackedInt32Array()
		var in_vein := PackedByteArray()
		for entry: Array in biome.ore_table:
			var id: int = int(entry[0])
			ids.append(id)
			chance.append(float(entry[1]))
			min_row.append(int(entry[2]))
			in_vein.append(1 if BlockRegistry.get_def(id).special == &"" else 0)
		_ore_ids.append(ids)
		_ore_chance.append(chance)
		_ore_min_row.append(min_row)
		_ore_in_vein.append(in_vein)


static func _make_noise(p_seed: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = p_seed & 0x7FFFFFFF
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = octaves
	return n


## Hash inteiro determinístico → [0, 1). Independe de plataforma e de randf().
static func hash01(x: int, y: int, salt: int) -> float:
	var h: int = (x & 0xFFFF) * 374761393 + (y & 0xFFFFF) * 668265263 + (salt & 0xFFFFFF) * 1440662683
	h &= 0xFFFFFFFF
	h = ((h ^ (h >> 15)) * 739982445) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 696929593) & 0xFFFFFFFF
	h ^= h >> 16
	return float(h & 0xFFFFFF) / 16777216.0


## Variante visual estável (0..3) para uma célula.
func variant_at(x: int, y: int) -> int:
	return int(hash01(x, y, seed_value + SALT_VARIANT) * 4.0) & 3


## Bioma real da célula, com borda serrilhada por ruído.
func biome_at(x: int, y: int) -> int:
	if y < 0:
		return BiomeRegistry.CRUST
	if not _near_boundary(y):
		return BiomeRegistry.id_for_row(y)
	var jitter: int = roundi(_border.get_noise_2d(float(x), float(y) * 0.25) * BiomeRegistry.BORDER_JITTER_ROWS)
	return BiomeRegistry.id_for_row(maxi(0, y + jitter))


func _near_boundary(y: int) -> bool:
	for edge in _boundaries:
		if absi(y - edge) <= BiomeRegistry.BORDER_JITTER_ROWS:
			return true
	return false


func generate_cell(x: int, y: int) -> int:
	if y < 0:
		return BlockRegistry.AIR
	return _cell(x, y, biome_at(x, y))


func _cell(x: int, y: int, biome_id: int) -> int:
	if y < 0:
		return BlockRegistry.AIR
	if x <= 0 or x >= Balance.WORLD_WIDTH - 1 or y >= Balance.MAX_DEPTH_ROWS:
		return BlockRegistry.BEDROCK
	var biome: BiomeDef = BiomeRegistry.get_def(biome_id)

	# Cavernas
	if y >= Balance.SAFE_SURFACE_ROWS:
		var fade: float = clampf(float(y - Balance.SAFE_SURFACE_ROWS) / CAVE_FADE_ROWS, 0.0, 1.0)
		var threshold: float = lerpf(1.0, biome.cave_threshold, fade)
		var c: float = (_cave.get_noise_2d(float(x), float(y) * CAVE_Y_SCALE) + 1.0) * 0.5
		if c > threshold:
			return BlockRegistry.AIR

	# Minérios e especiais (especiais raros não se concentram em veios).
	var ids: PackedInt32Array = _ore_ids[biome_id]
	if not ids.is_empty():
		var span: float = maxf(1.0, float(biome.end_row - biome.start_row))
		var depth_bonus: float = 1.0 + 0.5 * clampf(float(y - biome.start_row) / span, 0.0, 1.0)
		var vein_mult: float = VEIN_MULT if _ore.get_noise_2d(float(x), float(y)) > VEIN_THRESHOLD else OUTSIDE_VEIN_MULT
		var roll: float = hash01(x, y, seed_value + SALT_ORE)
		var chances: PackedFloat32Array = _ore_chance[biome_id]
		var min_rows: PackedInt32Array = _ore_min_row[biome_id]
		var in_vein: PackedByteArray = _ore_in_vein[biome_id]
		var acc: float = 0.0
		for i in ids.size():
			if y < min_rows[i]:
				continue
			acc += chances[i] * depth_bonus * (vein_mult if in_vein[i] == 1 else 1.0)
			if roll < acc:
				return ids[i]

	# Material base
	var ratio: float = biome.secondary_ratio
	if biome.id == BiomeRegistry.CRUST:
		# Terra domina perto da superfície; pedra cresce com a profundidade.
		ratio = lerpf(0.04, 0.8, clampf(float(y) / 100.0, 0.0, 1.0))
	var m: float = (_mix.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
	return biome.secondary_block if m < ratio else biome.primary_block


## Gera os ids de um chunk inteiro (linhas index*CHUNK_HEIGHT ..).
func generate_chunk(index: int) -> PackedByteArray:
	var w: int = Balance.WORLD_WIDTH
	var h: int = Balance.CHUNK_HEIGHT
	var ids := PackedByteArray()
	ids.resize(w * h)
	var y0: int = index * h
	for ly in h:
		var y: int = y0 + ly
		var row: int = ly * w
		if y < 0:
			continue  # céu: PackedByteArray já vem zerado (AIR)
		# Bioma calculado uma vez por linha, exceto perto das bordas serrilhadas.
		var row_biome: int = -1 if _near_boundary(y) else BiomeRegistry.id_for_row(y)
		for x in w:
			ids[row + x] = _cell(x, y, row_biome if row_biome >= 0 else biome_at(x, y))
	return ids
