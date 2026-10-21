class_name ChunkRenderer
extends Node2D
## Desenha um chunk inteiro em lote a partir de um único atlas. Só redesenha quando o chunk muda.

var world: WorldModel
var chunk_index: int = 0
var _tex: Texture2D


func setup(p_world: WorldModel, tex: Texture2D) -> void:
	world = p_world
	_tex = tex


func assign(index: int) -> void:
	chunk_index = index
	position = Vector2(0.0, float(index * Balance.CHUNK_HEIGHT * Balance.BLOCK_PX))
	visible = true
	queue_redraw()


func _draw() -> void:
	if world == null or not world.has_chunk(chunk_index):
		return
	var chunk: ChunkData = world.get_chunk(chunk_index)
	var ids: PackedByteArray = chunk.ids
	var w: int = Balance.WORLD_WIDTH
	var h: int = Balance.CHUNK_HEIGHT
	var b: float = float(Balance.BLOCK_PX)
	var size := Vector2(b, b)
	var y0: int = chunk_index * h
	var gen: WorldGenerator = world.generator
	for ly in h:
		var y: int = y0 + ly
		if y < 0:
			continue
		for x in w:
			var id: int = ids[ly * w + x]
			var rect := Rect2(Vector2(x * b, ly * b), size)
			var v: int = gen.variant_at(x, y)
			if id == BlockRegistry.AIR:
				draw_texture_rect_region(_tex, rect, TileArt.region(TileArt.ROW_BACK + gen.biome_at(x, y), v))
				if _solid(ids, x, ly - 1, y - 1):
					draw_texture_rect_region(_tex, rect, TileArt.region(TileArt.ROW_AO, TileArt.EDGE_TOP))
				if _solid(ids, x - 1, ly, y):
					draw_texture_rect_region(_tex, rect, TileArt.region(TileArt.ROW_AO, TileArt.EDGE_LEFT))
				if _solid(ids, x + 1, ly, y):
					draw_texture_rect_region(_tex, rect, TileArt.region(TileArt.ROW_AO, TileArt.EDGE_RIGHT))
				if _solid(ids, x, ly + 1, y + 1):
					draw_texture_rect_region(_tex, rect, TileArt.region(TileArt.ROW_AO, TileArt.EDGE_BOTTOM))
				continue
			draw_texture_rect_region(_tex, rect, TileArt.region(id, v))
			if not _solid(ids, x, ly - 1, y - 1):
				draw_texture_rect_region(_tex, rect, TileArt.region(TileArt.ROW_EDGE, TileArt.EDGE_TOP))
			if not _solid(ids, x, ly + 1, y + 1):
				draw_texture_rect_region(_tex, rect, TileArt.region(TileArt.ROW_EDGE, TileArt.EDGE_BOTTOM))
			if not _solid(ids, x - 1, ly, y):
				draw_texture_rect_region(_tex, rect, TileArt.region(TileArt.ROW_EDGE, TileArt.EDGE_LEFT))
			if not _solid(ids, x + 1, ly, y):
				draw_texture_rect_region(_tex, rect, TileArt.region(TileArt.ROW_EDGE, TileArt.EDGE_RIGHT))


## Solidez de um vizinho; usa os dados locais quando possível, senão consulta sem gerar.
func _solid(ids: PackedByteArray, x: int, ly: int, y: int) -> bool:
	if x < 0 or x >= Balance.WORLD_WIDTH:
		return true
	if y < 0:
		return false
	if ly >= 0 and ly < Balance.CHUNK_HEIGHT:
		return BlockRegistry.is_solid(ids[ly * Balance.WORLD_WIDTH + x])
	return BlockRegistry.is_solid(world.peek_block(Vector2i(x, y)))
