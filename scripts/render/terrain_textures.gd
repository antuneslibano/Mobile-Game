class_name TerrainTextures
extends RefCounted
## Texturas compartilhadas do shader de terreno:
## - paleta: uma linha por bloco (cores, tipo de arte, brilho, sprite de depósito) e linhas
##   de fundo por camada;
## - ruído: 4 canais de ruído contínuo e repetível (bordas, deformação, textura);
## - atlas montados a partir dos PNGs de assets/environment (terreno, depósitos, decorações);
## - tabelas da região ativa: textura por material/camada e decorações embutidas por camada.

const PALETTE_COLS: int = 9
const SKIN_W: int = 64           ## Colunas da tabela de texturas (≥ BlockRegistry.COUNT).
const DECOR_SLOTS: int = 16      ## Escolha da decoração embutida: 16 faixas + densidade.
const NOISE_SIZE: int = 256
const SHADER_PATH: String = "res://shaders/terrain.gdshader"

static var _palette: ImageTexture
static var _noise: ImageTexture
static var _material: ShaderMaterial
static var _terrain_atlas: ImageTexture
static var _ore_atlas: ImageTexture
static var _decor_atlas: ImageTexture
static var _decor_image: Image
static var _skin: ImageTexture
static var _decor_table: ImageTexture
## Região cujas tabelas estão aplicadas (lida pelas decorações de caverna).
static var region_id: StringName = &""


static func biome_row() -> int:
	return BlockRegistry.COUNT


static func get_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load(SHADER_PATH) as Shader
		_material.set_shader_parameter("noise_tex", get_noise())
		_material.set_shader_parameter("palette_tex", get_palette())
		_material.set_shader_parameter("cell_px", float(Balance.CELL_PX))
		_material.set_shader_parameter("sub", float(Balance.CELL_SUB))
		_material.set_shader_parameter("halo", ChunkRenderer.HALO)
		_material.set_shader_parameter("noise_size", float(NOISE_SIZE))
		_material.set_shader_parameter("biome_row", biome_row())
		_material.set_shader_parameter("terrain_atlas", _terrain_tex())
		_material.set_shader_parameter("ore_atlas", _ore_tex())
		_material.set_shader_parameter("decor_atlas", decor_texture())
		_material.set_shader_parameter("skin_tex", _skin_tex())
		_material.set_shader_parameter("decor_tex", _decor_tex())
		_material.set_shader_parameter("fossil_first", TerrainSkins.fossil_indices()[0])
	return _material


# --- Atlas (a partir dos PNGs) -----------------------------------------------------------

static func _load_png(path: String) -> Image:
	var img: Image = load(path) as Image
	if img == null:
		push_warning("Ambiente: asset ausente %s" % path)
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img = img.duplicate()
		img.convert(Image.FORMAT_RGBA8)
	return img


## Lado das texturas de terreno no atlas (0.23: 128, arte importada com mais detalhe).
## PNGs menores são ampliados sem filtro (pixel art).
const TERRAIN_TILE: int = 128


## 8 colunas × 2 linhas de texturas TERRAIN_TILE² (ordem de TerrainSkins.TILES).
static func terrain_atlas() -> Image:
	var t: int = TERRAIN_TILE
	var atlas := Image.create(t * 8, t * ceili(TerrainSkins.TILES.size() / 8.0), false, Image.FORMAT_RGBA8)
	for i in TerrainSkins.TILES.size():
		var img: Image = _load_png("%s/terrain/%s.png" % [TerrainSkins.ROOT, TerrainSkins.TILES[i]])
		if img != null:
			if img.get_width() != t:
				img = img.duplicate()
				img.resize(t, t, Image.INTERPOLATE_NEAREST)
			atlas.blit_rect(img, Rect2i(0, 0, t, t), Vector2i((i % 8) * t, (i / 8) * t))
	return atlas


## Uma linha por minério, uma coluna por variação (12×12).
static func ore_atlas() -> Image:
	var o: int = EnvArt.ORE
	var atlas := Image.create(o * TerrainSkins.ORE_VARIANTS, o * TerrainSkins.ORES.size(), false, Image.FORMAT_RGBA8)
	for r in TerrainSkins.ORES.size():
		for v in TerrainSkins.ORE_VARIANTS:
			var img: Image = _load_png("%s/ores/%s_%d.png" % [TerrainSkins.ROOT, TerrainSkins.ORES[r], v + 1])
			if img != null:
				atlas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(v * o, r * o))
	return atlas


## Células de 24×24; alinhamento pelo tipo (chão = embaixo, teto = em cima, demais = centro).
static func decor_atlas() -> Image:
	var c: int = TerrainSkins.DECOR_CELL
	var n: int = TerrainSkins.DECOR.size()
	var atlas := Image.create(c * TerrainSkins.DECOR_COLS, c * ceili(float(n) / TerrainSkins.DECOR_COLS), false, Image.FORMAT_RGBA8)
	for i in n:
		var e: Array = TerrainSkins.DECOR[i]
		var img: Image = _load_png("%s/%s/%s.png" % [TerrainSkins.ROOT, e[0], e[1]])
		if img == null:
			continue
		var sz: Vector2i = img.get_size()
		var ox: int = (c - sz.x) / 2
		var oy: int = (c - sz.y) / 2
		if e[2] == &"floor":
			oy = c - sz.y
		elif e[2] == &"ceil":
			oy = 0
		atlas.blit_rect(img, Rect2i(Vector2i.ZERO, sz), Vector2i((i % TerrainSkins.DECOR_COLS) * c + ox, (i / TerrainSkins.DECOR_COLS) * c + oy))
	return atlas


static func _terrain_tex() -> ImageTexture:
	if _terrain_atlas == null:
		_terrain_atlas = ImageTexture.create_from_image(terrain_atlas())
	return _terrain_atlas


static func _ore_tex() -> ImageTexture:
	if _ore_atlas == null:
		_ore_atlas = ImageTexture.create_from_image(ore_atlas())
	return _ore_atlas


static func decor_texture() -> ImageTexture:
	if _decor_atlas == null:
		_decor_image = decor_atlas()
		_decor_atlas = ImageTexture.create_from_image(_decor_image)
	return _decor_atlas


## Região do atlas de decorações (em pixels de arte) de uma entrada.
static func decor_region(index: int) -> Rect2:
	var c: int = TerrainSkins.DECOR_CELL
	return Rect2((index % TerrainSkins.DECOR_COLS) * c, (index / TerrainSkins.DECOR_COLS) * c, c, c)


# --- Tabelas da região -------------------------------------------------------------------

## r,g,b,a = até 4 índices de textura do material (x = bloco) na camada (y).
static func build_skin(rid: StringName) -> Image:
	var img := Image.create(SKIN_W, BiomeRegistry.MAX_LAYERS, false, Image.FORMAT_RGBA8)
	for layer in BiomeRegistry.MAX_LAYERS:
		for id in BlockRegistry.COUNT:
			var k: PackedByteArray = TerrainSkins.skin_for(rid, layer, id)
			img.set_pixel(id, layer, Color8(k[0], k[1], k[2], k[3]))
	return img


## Linha = camada; x 0..15 = decoração embutida para cada 1/16 do sorteio; x 16 = densidade.
static func build_decor_table(rid: StringName) -> Image:
	var img := Image.create(DECOR_SLOTS + 1, BiomeRegistry.MAX_LAYERS, false, Image.FORMAT_RGBA8)
	img.fill(Color8(TerrainSkins.NONE, 0, 0, 255))
	for layer in BiomeRegistry.MAX_LAYERS:
		var table: Array = TerrainSkins.decor_for(rid, layer).get("embed", [])
		if table.size() < 2:
			img.set_pixel(DECOR_SLOTS, layer, Color8(0, 0, 0, 255))
			continue
		for k in DECOR_SLOTS:
			img.set_pixel(k, layer, Color8(TerrainSkins.pick(table, (k + 0.5) / DECOR_SLOTS), 0, 0, 255))
		img.set_pixel(DECOR_SLOTS, layer, Color8(roundi(float(table[0]) * 255.0), 0, 0, 255))
	return img


static func _skin_tex() -> ImageTexture:
	if _skin == null:
		_skin = ImageTexture.create_from_image(build_skin(region_id))
	return _skin


static func _decor_tex() -> ImageTexture:
	if _decor_table == null:
		_decor_table = ImageTexture.create_from_image(build_decor_table(region_id))
	return _decor_table


## Aplica a região: fundo das camadas, texturas por material e decorações.
static func apply_region(r: RegionDef) -> void:
	region_id = r.id
	apply_layers(r.layers)
	_skin_tex().update(build_skin(region_id))
	_decor_tex().update(build_decor_table(region_id))


static func get_palette() -> ImageTexture:
	if _palette == null:
		_palette = ImageTexture.create_from_image(build_palette())
	return _palette


static func get_noise() -> ImageTexture:
	if _noise == null:
		_noise = ImageTexture.create_from_image(build_noise())
	return _noise


static func build_palette(layers: Array[BiomeDef] = []) -> Image:
	if layers.is_empty():
		layers = BiomeRegistry.layers()
	var img := Image.create(PALETTE_COLS, BlockRegistry.COUNT + BiomeRegistry.MAX_LAYERS, false, Image.FORMAT_RGBA8)
	for def: BlockDef in BlockRegistry.all():
		var light: Color = def.color_accent if def.art == BlockDef.Art.STONE else def.color_base.lightened(0.16)
		var row: Array[Color] = [
			def.color_base, def.color_dark, light,
			def.color_accent, def.color_accent.darkened(0.35), def.color_accent.lightened(0.45),
			Color(float(def.art) / 255.0, 0, 0, 1),
			# Coluna 7: brilho dos minérios valiosos (0 nenhum, 0,5 cintila, 1 cintila + aura + partículas).
			Color(TerrainSkins.glow_tier(def) / 2.0, 0, 0, 1),
			# Coluna 8: linha do sprite de depósito no atlas de minérios (255 = nenhum).
			Color8(_ore_row(def.id), 0, 0, 255),
		]
		for c in PALETTE_COLS:
			img.set_pixel(c, def.id, row[c])
	for b in BiomeRegistry.MAX_LAYERS:
		var biome: BiomeDef = layers[mini(b, layers.size() - 1)]
		var r: int = biome_row() + b
		img.set_pixel(0, r, biome.back_color)
		img.set_pixel(1, r, biome.back_color.darkened(0.3))
		img.set_pixel(2, r, biome.back_color.lightened(0.07))
	return img


static func _ore_row(block_id: int) -> int:
	var key: String = TerrainSkins.ore_sprite_for(block_id)
	return TerrainSkins.NONE if key.is_empty() else TerrainSkins.ORES.find(key)


## Atualiza as cores de fundo das camadas para a região ativa.
static func apply_layers(layers: Array[BiomeDef]) -> void:
	if _palette == null:
		_palette = ImageTexture.create_from_image(build_palette(layers))
	else:
		_palette.update(build_palette(layers))


## RGBA: r = bordas (~28 px), g/b = deformação de materiais (~110 px), a = textura (~25 px).
static func build_noise() -> Image:
	var channels: Array[PackedByteArray] = [
		_channel(1301, 0.036, 2),
		_channel(2602, 0.009, 2),
		_channel(3903, 0.009, 2),
		_channel(5204, 0.04, 3),
	]
	var n: int = NOISE_SIZE * NOISE_SIZE
	var data := PackedByteArray()
	data.resize(n * 4)
	for i in n:
		var o: int = i * 4
		data[o] = channels[0][i]
		data[o + 1] = channels[1][i]
		data[o + 2] = channels[2][i]
		data[o + 3] = channels[3][i]
	return Image.create_from_data(NOISE_SIZE, NOISE_SIZE, false, Image.FORMAT_RGBA8, data)


static func _channel(p_seed: int, freq: float, octaves: int) -> PackedByteArray:
	var fn := FastNoiseLite.new()
	fn.seed = p_seed
	fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fn.frequency = freq
	fn.fractal_octaves = octaves
	var img: Image = fn.get_seamless_image(NOISE_SIZE, NOISE_SIZE)
	img.convert(Image.FORMAT_L8)
	return img.get_data()
