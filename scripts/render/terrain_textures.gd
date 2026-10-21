class_name TerrainTextures
extends RefCounted
## Texturas compartilhadas do shader de terreno, geradas em código (sem assets externos):
## - paleta: uma linha por bloco (cores + tipo de arte) e linhas de fundo por bioma;
## - ruído: 4 canais de ruído contínuo e repetível (bordas, deformação, textura).

const PALETTE_COLS: int = 8
const NOISE_SIZE: int = 256
const SHADER_PATH: String = "res://shaders/terrain.gdshader"

static var _palette: ImageTexture
static var _noise: ImageTexture
static var _material: ShaderMaterial


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
	return _material


static func get_palette() -> ImageTexture:
	if _palette == null:
		_palette = ImageTexture.create_from_image(build_palette())
	return _palette


static func get_noise() -> ImageTexture:
	if _noise == null:
		_noise = ImageTexture.create_from_image(build_noise())
	return _noise


static func build_palette() -> Image:
	var img := Image.create(PALETTE_COLS, BlockRegistry.COUNT + BiomeRegistry.COUNT, false, Image.FORMAT_RGBA8)
	for def: BlockDef in BlockRegistry.all():
		var light: Color = def.color_accent if def.art == BlockDef.Art.STONE else def.color_base.lightened(0.16)
		var row: Array[Color] = [
			def.color_base, def.color_dark, light,
			def.color_accent, def.color_accent.darkened(0.35), def.color_accent.lightened(0.45),
			Color(float(def.art) / 255.0, 0, 0, 1), Color.BLACK,
		]
		for c in PALETTE_COLS:
			img.set_pixel(c, def.id, row[c])
	for b in BiomeRegistry.COUNT:
		var biome: BiomeDef = BiomeRegistry.get_def(b)
		var r: int = biome_row() + b
		img.set_pixel(0, r, biome.back_color)
		img.set_pixel(1, r, biome.back_color.darkened(0.3))
		img.set_pixel(2, r, biome.back_color.lightened(0.07))
	return img


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
