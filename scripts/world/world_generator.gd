class_name WorldGenerator
extends RefCounted
## Geração determinística e pura em dois níveis:
## 1. Layout de BLOCOS (biomas, cavernas, minérios): generate_block(bx, by).
## 2. MICRO-CÉLULAS (terreno real, escavação livre): o layout é amostrado com deformação
##    por ruído, dando bordas orgânicas: generate_cell(cx, cy) / generate_chunk(index).
## Somente leitura após _init — seguro para threads de trabalho.

const SALT_ORE: int = 0x51ED27
const SALT_VARIANT: int = 0x2F9A11
## Minérios concentrados em veios (ruído de minério alto) e quase nenhum solto: poucos
## aglomerados por tela, que valem o desvio (GAME_DESIGN.md §5.5).
const VEIN_MULT: float = 3.4
const OUTSIDE_VEIN_MULT: float = 0.08
const VEIN_THRESHOLD: float = 0.32
## Escala vertical das cavernas (<1 = cavernas mais largas que altas).
const CAVE_Y_SCALE: float = 1.45
## Linhas após SAFE_SURFACE_ROWS em que as cavernas aparecem gradualmente.
const CAVE_FADE_ROWS: int = 10

var seed_value: int = 0
## Núcleo do guardião (rocha-mãe sob o sprite) no piso da câmara final. Defina antes de
## gerar qualquer chunk: false quando o guardião da região já foi vencido.
var guardian_alive: bool = true
var _core_c: Vector2 = Vector2.ZERO   ## Centro do núcleo em células.
var _core_r2: float = 0.0
## Região e camadas usadas por este gerador (cópia própria: seguro em threads).
var region: RegionDef
var _layers: Array[BiomeDef] = []
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
## Tabelas de deformação (256×256, repetíveis) em bytes.
var _warp_x: PackedByteArray
var _warp_y: PackedByteArray
const WARP_SIZE: int = 256


func _init(p_seed: int, p_region: RegionDef = null) -> void:
	seed_value = p_seed
	region = p_region if p_region != null else RegionRegistry.all()[0]
	_layers = region.layers
	_cave = _make_noise(p_seed, 0.07, 2)
	_mix = _make_noise(p_seed + 101, 0.11, 1)
	_ore = _make_noise(p_seed + 202, 0.17, 1)
	_border = _make_noise(p_seed + 303, 0.21, 1)
	_prepare_tables()
	_warp_x = _warp_table(p_seed + 404)
	_warp_y = _warp_table(p_seed + 505)
	_core_c = RegionRegistry.guardian_center(region) / Balance.CELL_PX
	_core_r2 = pow(Balance.GUARDIAN_RADIUS_BLOCKS * Balance.CELL_SUB * 0.9, 2.0)


static func _warp_table(p_seed: int) -> PackedByteArray:
	# Fractal de 3 oitavas: curvas amplas com bordas recortadas em escala fina.
	var n := _make_noise(p_seed, 0.05, 3)
	n.fractal_gain = 0.55
	var img: Image = n.get_seamless_image(WARP_SIZE, WARP_SIZE)
	img.convert(Image.FORMAT_L8)
	return img.get_data()


## Também garante que os registros estáticos estejam construídos antes de uso em threads.
func _prepare_tables() -> void:
	BlockRegistry.all()
	for b in _layers.size():
		var biome: BiomeDef = _layers[b]
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
		return 0
	if not _near_boundary(y):
		return BiomeRegistry.id_for_row_in(_layers, y)
	var jitter: int = roundi(_border.get_noise_2d(float(x), float(y) * 0.25) * BiomeRegistry.BORDER_JITTER_ROWS)
	return BiomeRegistry.id_for_row_in(_layers, maxi(0, y + jitter))


func _near_boundary(y: int) -> bool:
	for edge in _boundaries:
		if absi(y - edge) <= BiomeRegistry.BORDER_JITTER_ROWS:
			return true
	return false


## Bloco do layout (unidade de design). Fora do mundo = rocha-mãe; acima = ar.
func generate_block(x: int, y: int) -> int:
	if y < 0:
		return BlockRegistry.AIR
	return _cell(x, y, biome_at(x, y))


func _cell(x: int, y: int, biome_id: int) -> int:
	if y < 0:
		return BlockRegistry.AIR
	if x <= 0 or x >= Balance.WORLD_WIDTH - 1 or y >= mini(Balance.MAX_DEPTH_ROWS, region.target_depth_m):
		return BlockRegistry.BEDROCK
	# Câmara final: salão logo acima do fundo, no centro (o guardião fica no piso).
	var top: int = region.target_depth_m - Balance.FINAL_CHAMBER_ROWS
	if y >= top:
		var cx: int = RegionRegistry.chamber_center_x()
		var dx: float = float(x - cx) / Balance.FINAL_CHAMBER_HALF_WIDTH
		var dy: float = (float(y) - (top + region.target_depth_m - 1) * 0.5) / (Balance.FINAL_CHAMBER_ROWS * 0.5)
		var wobble: float = _cave.get_noise_2d(float(x) * 1.7, float(y) * 1.7) * 0.25
		if dx * dx + dy * dy <= 1.0 + wobble:
			return BlockRegistry.AIR
	var biome: BiomeDef = _layers[clampi(biome_id, 0, _layers.size() - 1)]

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
			acc += chances[i] * depth_bonus * (vein_mult * Balance.ORE_DENSITY if in_vein[i] == 1 else 1.0)
			if roll < acc:
				return ids[i]

	# Material base
	var ratio: float = biome.secondary_ratio
	var m: float = (_mix.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
	return biome.secondary_block if m < ratio else biome.primary_block


static func _is_special(id: int) -> bool:
	return id == BlockRegistry.CHEST or id == BlockRegistry.ARTIFACT or id == BlockRegistry.FOSSIL


## Deformação (em células) da amostragem do layout para uma micro-célula.
func warp_at(cx: int, cy: int) -> Vector2:
	var i: int = (cx & (WARP_SIZE - 1)) + ((cy & (WARP_SIZE - 1)) << 8)
	return Vector2(float(_warp_x[i]) - 127.5, float(_warp_y[i]) - 127.5) * (Balance.WARP_CELLS / 127.5)


## Combina o bloco deformado com o não deformado: especiais (baú, artefato) mantêm forma
## própria e não "vazam" para os vizinhos.
static func _resolve(warped: int, unwarped: int) -> int:
	if _is_special(unwarped) or _is_special(warped):
		return unwarped
	return warped


func _forced_cell(cx: int, cy: int) -> int:
	if cy < 0:
		return BlockRegistry.AIR
	if cx < Balance.WALL_CELLS or cx >= Balance.WORLD_CELLS_X - Balance.WALL_CELLS \
			or cy >= Balance.MAX_DEPTH_ROWS * Balance.CELL_SUB:
		return BlockRegistry.BEDROCK
	if guardian_alive:
		var dy: float = cy + 0.5 - _core_c.y
		if dy * dy <= _core_r2:
			var dx: float = cx + 0.5 - _core_c.x
			if dx * dx + dy * dy <= _core_r2:
				return BlockRegistry.BEDROCK
	return -1


## Micro-célula avulsa (usada para vizinhos fora de chunks carregados).
func generate_cell(cx: int, cy: int) -> int:
	var forced: int = _forced_cell(cx, cy)
	if forced >= 0:
		return forced
	var sub: int = Balance.CELL_SUB
	var w: Vector2 = warp_at(cx, cy)
	var unwarped: int = generate_block(floori(float(cx) / sub), floori(float(cy) / sub))
	var warped: int = generate_block(floori((cx + 0.5 + w.x) / sub), floori((cy + 0.5 + w.y) / sub))
	return _resolve(warped, unwarped)


## Bioma de uma micro-célula (do bloco não deformado).
func biome_at_cell(cx: int, cy: int) -> int:
	return biome_at(clampi(floori(float(cx) / Balance.CELL_SUB), 0, Balance.WORLD_WIDTH - 1), maxi(0, floori(float(cy) / Balance.CELL_SUB)))


## Gera as micro-células de um chunk (WORLD_CELLS_X × CHUNK_CELLS_Y). O layout de blocos do
## chunk (+ margem para a deformação) é calculado uma vez e então amostrado.
func generate_chunk(index: int) -> PackedByteArray:
	var sub: int = Balance.CELL_SUB
	var cw: int = Balance.WORLD_CELLS_X
	var ch: int = Balance.CHUNK_CELLS_Y
	var margin: int = 3
	var bw: int = Balance.WORLD_WIDTH + margin * 2
	var by0: int = index * Balance.CHUNK_HEIGHT - margin
	var bh: int = Balance.CHUNK_HEIGHT + margin * 2
	var coarse := PackedByteArray()
	coarse.resize(bw * bh)
	for j in bh:
		var by: int = by0 + j
		for i in bw:
			var bx: int = i - margin
			var id: int = BlockRegistry.BEDROCK
			if by < 0:
				id = BlockRegistry.AIR
			elif bx >= 0 and bx < Balance.WORLD_WIDTH:
				id = generate_block(bx, by)
			coarse[j * bw + i] = id
	var ids := PackedByteArray()
	ids.resize(cw * ch)
	var cy0: int = index * ch
	for ly in ch:
		var cy: int = cy0 + ly
		if cy < 0:
			continue  # céu: zeros = AIR
		var row: int = ly * cw
		var uby: int = floori(float(cy) / sub) - by0
		for cx in cw:
			var forced: int = _forced_cell(cx, cy)
			if forced >= 0:
				ids[row + cx] = forced
				continue
			var wi: int = (cx & (WARP_SIZE - 1)) + ((cy & (WARP_SIZE - 1)) << 8)
			var wx: float = (float(_warp_x[wi]) - 127.5) * (Balance.WARP_CELLS / 127.5)
			var wy: float = (float(_warp_y[wi]) - 127.5) * (Balance.WARP_CELLS / 127.5)
			var bxi: int = clampi(floori((cx + 0.5 + wx) / sub) + margin, 0, bw - 1)
			var byi: int = clampi(floori((cy + 0.5 + wy) / sub) - by0, 0, bh - 1)
			var unwarped: int = coarse[uby * bw + (cx / sub) + margin]
			ids[row + cx] = _resolve(coarse[byi * bw + bxi], unwarped)
	return ids
