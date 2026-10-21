class_name ChunkRenderer
extends Node2D
## Desenha um chunk com o shader de terreno orgânico (1 quad, 1 chamada de desenho).
## Os dados das micro-células vão para uma textura (WORLD_CELLS_X+2·HALO × CHUNK_CELLS_Y+2·HALO):
## r = material, g = desgaste, b = bioma, a = sólido. Escavar atualiza só os texels afetados,
## enviados à GPU uma vez por quadro.

## Células extras em volta do chunk, para contornos contínuos entre chunks.
const HALO: int = 2

static var _solid_lut: PackedByteArray

var world: WorldModel
var chunk_index: int = 0
var _image: Image
var _texture: ImageTexture
var _dirty: bool = false
var _decor: CaveDecor


static func _ensure_lut() -> void:
	if _solid_lut.is_empty():
		_solid_lut.resize(256)
		for def: BlockDef in BlockRegistry.all():
			_solid_lut[def.id] = 255 if def.solid else 0


func setup(p_world: WorldModel) -> void:
	world = p_world
	material = TerrainTextures.get_material()
	_ensure_lut()


func assign(index: int) -> void:
	chunk_index = index
	position = Vector2(0.0, float(index * Balance.CHUNK_CELLS_Y * Balance.CELL_PX))
	visible = true
	rebuild()
	if _decor == null:
		_decor = CaveDecor.new()
		_decor.name = "CaveDecor"
		add_child(_decor)
	_decor.build(world, index)


## Reescreve toda a textura de dados (ao atribuir o chunk).
func rebuild() -> void:
	var cw: int = Balance.WORLD_CELLS_X
	var ch: int = Balance.CHUNK_CELLS_Y
	var w: int = cw + HALO * 2
	var h: int = ch + HALO * 2
	var y0: int = chunk_index * ch
	var chunk: ChunkData = world.get_chunk(chunk_index)
	var gen: WorldGenerator = world.generator
	var biome_cache: Dictionary = {}
	var data := PackedByteArray()
	data.resize(w * h * 4)
	for j in h:
		var cy: int = y0 + j - HALO
		var inside_row: bool = j >= HALO and j < h - HALO
		var by: int = maxi(0, floori(float(cy) / Balance.CELL_SUB))
		for i in w:
			var cx: int = i - HALO
			var id: int
			var dmg: int = 0
			if inside_row and cx >= 0 and cx < cw:
				var local: int = (j - HALO) * cw + cx
				id = chunk.ids[local]
				dmg = chunk.dmg[local]
			else:
				var c := Vector2i(cx, cy)
				id = world.peek_cell(c)
				dmg = int(world.get_damage(c) * 255.0)
			var bx: int = clampi(floori(float(cx) / Balance.CELL_SUB), 0, Balance.WORLD_WIDTH - 1)
			var bkey: int = by * 64 + bx
			var biome: int
			if biome_cache.has(bkey):
				biome = biome_cache[bkey]
			else:
				biome = gen.biome_at(bx, by)
				biome_cache[bkey] = biome
			var o: int = (j * w + i) * 4
			data[o] = id
			data[o + 1] = dmg
			data[o + 2] = biome
			data[o + 3] = _solid_lut[id] if cy >= 0 else 0
	if _image == null:
		_image = Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
		_texture = ImageTexture.create_from_image(_image)
	else:
		_image.set_data(w, h, false, Image.FORMAT_RGBA8, data)
		_texture.update(_image)
	_dirty = false
	queue_redraw()


## Verdadeiro se a célula aparece nesta textura (inclui o halo).
func covers(c: Vector2i) -> bool:
	var ly: int = c.y - chunk_index * Balance.CHUNK_CELLS_Y
	return ly >= -HALO and ly < Balance.CHUNK_CELLS_Y + HALO


func update_cells(cells: Array[Vector2i]) -> void:
	if _image == null:
		return
	var any: bool = false
	for c in cells:
		if not covers(c):
			continue
		var i: int = c.x + HALO
		var j: int = c.y - chunk_index * Balance.CHUNK_CELLS_Y + HALO
		if i < 0 or i >= _image.get_width():
			continue
		var id: int = world.peek_cell(c)
		var old: Color = _image.get_pixel(i, j)
		var dmg: float = world.get_damage(c)
		_image.set_pixel(i, j, Color(id / 255.0, dmg, old.b, _solid_lut[id] / 255.0))
		any = true
	if any and _decor != null:
		_decor.on_cells_changed(cells)
	if any and not _dirty:
		_dirty = true
		_flush.call_deferred()


func _flush() -> void:
	if _dirty and _texture != null:
		_texture.update(_image)
	_dirty = false


func _draw() -> void:
	if _texture == null:
		return
	draw_texture_rect(_texture, Rect2(0, 0, Balance.WORLD_CELLS_X * Balance.CELL_PX, Balance.CHUNK_CELLS_Y * Balance.CELL_PX), false)
