class_name CaveDecor
extends Node2D
## Vegetação e pedras decorativas das cavernas de um chunk: plantas, musgo e cogumelos no
## chão; raízes, cipós e estalactites no teto. Só visual: sem colisão, não interfere na
## mineração. Aparecem apenas em cavernas naturais (nunca em túneis escavados) e somem
## quando a célula em que se apoiam é escavada. Desenhadas por cima do terreno, sem o
## shader (pixels de arte de 3 px, filtro nearest).

const SINK_PX: float = 3.0           ## Base afundada 1 pixel de arte no apoio.
const CHANCE_PER_CELL: float = 0.35  ## Multiplica a densidade da camada (por célula de borda).

var world: WorldModel
var chunk_index: int = 0
## Célula de apoio → [índice da decoração, flip, tipo].
var items: Dictionary = {}


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1


## Planeja as decorações de um chunk (função pura sobre o mundo: testável).
static func plan(w: WorldModel, index: int, region_id: StringName) -> Dictionary:
	var out: Dictionary = {}
	var cw: int = Balance.WORLD_CELLS_X
	var ch: int = Balance.CHUNK_CELLS_Y
	var y0: int = index * ch
	var gen: WorldGenerator = w.generator
	var tables: Dictionary = {}
	var ids: PackedByteArray = w.get_chunk(index).ids
	for j in ch:
		var cy: int = y0 + j
		if cy < 3:
			continue
		for cx in range(1, cw - 1):
			var k: int = j * cw + cx
			if not BlockRegistry.is_solid(ids[k]):
				continue
			var up: int = ids[k - cw] if j >= 1 else w.peek_cell(Vector2i(cx, cy - 1))
			var down: int = ids[k + cw] if j < ch - 1 else w.peek_cell(Vector2i(cx, cy + 1))
			if up != BlockRegistry.AIR and down != BlockRegistry.AIR:
				continue
			var c := Vector2i(cx, cy)
			if not BlockRegistry.get_def(ids[k]).is_terrain():
				continue
			var kind: StringName = &""
			if up == BlockRegistry.AIR and _natural_air(w, c + Vector2i(0, -1)) and _natural_air(w, c + Vector2i(0, -2)):
				kind = &"floor"
			elif down == BlockRegistry.AIR and _natural_air(w, c + Vector2i(0, 1)) and _natural_air(w, c + Vector2i(0, 2)):
				kind = &"ceil"
			else:
				continue
			var layer: int = gen.biome_at_cell(cx, cy)
			if not tables.has(layer):
				tables[layer] = TerrainSkins.decor_for(region_id, layer)
			var table: Array = (tables[layer] as Dictionary).get(String(kind), [])
			if table.size() < 2:
				continue
			if EnvArt.hash01(cx, cy, 4242) >= float(table[0]) * CHANCE_PER_CELL:
				continue
			# Espaçamento: nada encostado em outra decoração do mesmo tipo.
			if out.has(c + Vector2i(-1, 0)) or out.has(c + Vector2i(-2, 0)):
				continue
			var pick: int = TerrainSkins.pick(table, EnvArt.hash01(cx, cy, 777))
			out[c] = [pick, EnvArt.hash01(cx, cy, 99) < 0.5, kind]
	return out


static func _natural_air(w: WorldModel, c: Vector2i) -> bool:
	return c.y >= 0 and w.peek_cell(c) == BlockRegistry.AIR and not w.is_modified(c)


func build(p_world: WorldModel, index: int) -> void:
	world = p_world
	chunk_index = index
	items = plan(world, index, TerrainTextures.region_id)
	queue_redraw()


## Some a decoração cuja célula de apoio deixou de ser sólida.
func on_cells_changed(cells: Array[Vector2i]) -> void:
	var changed: bool = false
	for c in cells:
		if items.has(c) and not BlockRegistry.is_solid(world.peek_cell(c)):
			items.erase(c)
			changed = true
	if changed:
		queue_redraw()


func _draw() -> void:
	if items.is_empty():
		return
	var tex: Texture2D = TerrainTextures.decor_texture()
	var art: float = float(Balance.CELL_PX) / Balance.CELL_SUB
	var size: float = TerrainSkins.DECOR_CELL * art
	var y0: int = chunk_index * Balance.CHUNK_CELLS_Y
	for c: Vector2i in items:
		var e: Array = items[c]
		var x: float = c.x * Balance.CELL_PX + Balance.CELL_PX * 0.5 - size * 0.5
		var y: float = (c.y - y0) * Balance.CELL_PX
		if e[2] == &"floor":
			y = y - size + SINK_PX
		else:
			y = y + Balance.CELL_PX - SINK_PX
		x = roundf(x / art) * art
		var rect := Rect2(x, y, size, size)
		if e[1]:
			rect = Rect2(x + size, y, -size, size)
		draw_texture_rect_region(tex, rect, TerrainTextures.decor_region(e[0]), Color(0.9, 0.9, 0.9))
