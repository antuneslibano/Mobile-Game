class_name ChunkRenderer
extends Node2D
## Desenha um chunk com o shader de terreno orgânico (1 quad, 1 chamada de desenho).
## Os dados das células vão para uma textura pequena (WIDTH+2·HALO × CHUNK_HEIGHT+2·HALO);
## alterar uma célula atualiza só um texel.

## Células extras em volta do chunk, para contornos contínuos entre chunks.
const HALO: int = 2

var world: WorldModel
var chunk_index: int = 0
var _image: Image
var _texture: ImageTexture


func setup(p_world: WorldModel) -> void:
	world = p_world
	material = TerrainTextures.get_material()
	if _image == null:
		_image = Image.create(Balance.WORLD_WIDTH + HALO * 2, Balance.CHUNK_HEIGHT + HALO * 2, false, Image.FORMAT_RGBA8)


func assign(index: int) -> void:
	chunk_index = index
	position = Vector2(0.0, float(index * Balance.CHUNK_HEIGHT * Balance.BLOCK_PX))
	visible = true
	rebuild()


## Reescreve toda a textura de dados (ao atribuir o chunk).
func rebuild() -> void:
	var y0: int = chunk_index * Balance.CHUNK_HEIGHT
	for j in Balance.CHUNK_HEIGHT + HALO * 2:
		for i in Balance.WORLD_WIDTH + HALO * 2:
			var cell := Vector2i(i - HALO, y0 + j - HALO)
			_image.set_pixel(i, j, _encode(cell))
	if _texture == null:
		_texture = ImageTexture.create_from_image(_image)
	else:
		_texture.update(_image)
	queue_redraw()


## Verdadeiro se a célula aparece nesta textura (inclui o halo).
func covers(cell: Vector2i) -> bool:
	var ly: int = cell.y - chunk_index * Balance.CHUNK_HEIGHT
	return ly >= -HALO and ly < Balance.CHUNK_HEIGHT + HALO


func update_cell(cell: Vector2i) -> void:
	if _texture == null or not covers(cell):
		return
	var i: int = cell.x + HALO
	var j: int = cell.y - chunk_index * Balance.CHUNK_HEIGHT + HALO
	if i < 0 or i >= _image.get_width():
		return
	_image.set_pixel(i, j, _encode(cell))
	_texture.update(_image)


func _encode(cell: Vector2i) -> Color:
	var id: int = world.peek_block(cell)
	var stage: int = 0
	var ratio: float = world.get_damage_ratio(cell)
	if ratio > 0.0:
		stage = clampi(int(ratio * 4.0) + 1, 1, 4)
	var biome: int = world.generator.biome_at(clampi(cell.x, 0, Balance.WORLD_WIDTH - 1), maxi(cell.y, 0))
	var solid: float = 1.0 if BlockRegistry.is_solid(id) and cell.y >= 0 else 0.0
	return Color(id / 255.0, stage / 255.0, biome / 255.0, solid)


func _draw() -> void:
	if _texture == null:
		return
	draw_texture_rect(_texture, Rect2(0, 0, Balance.WORLD_WIDTH * Balance.BLOCK_PX, Balance.CHUNK_HEIGHT * Balance.BLOCK_PX), false)
