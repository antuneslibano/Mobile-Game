class_name CaveDecor
extends Node2D
## Vegetação e pedras decorativas das cavernas de um chunk: plantas, musgo e cogumelos no
## chão; raízes, cipós e estalactites no teto. Só visual: sem colisão, não interfere na
## mineração. Aparecem apenas em cavernas naturais (nunca em túneis escavados) e somem
## quando a célula em que se apoiam é escavada. Desenhadas por cima do terreno, sem o
## shader (pixels de arte de 3 px, filtro nearest).

const SINK_PX: float = 3.0           ## Base afundada 1 pixel de arte no apoio.
const CHANCE_PER_CELL: float = 0.35  ## Multiplica a densidade da camada (por célula de borda).
## Plantas bioluminescentes (0.15, só no Vale): chance por célula de borda de caverna,
## distância mínima entre elas (células) e profundidade mínima (células, abaixo da névoa).
const BIO_CHANCE: float = 0.014
const BIO_SPACING: int = 30
const BIO_MIN_ROW: int = 64
const BIO_REGIONS: Array[StringName] = [&"vale"]

## Decorações vivas (a névoa procura as luzes das plantas nelas).
static var live: Array[CaveDecor] = []

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
			if region_id in BIO_REGIONS and cy >= BIO_MIN_ROW and EnvArt.hash01(cx, cy, 5151) < BIO_CHANCE and not _bio_near(out, c):
				out[c] = [-1, EnvArt.hash01(cx, cy, 99) < 0.5, &"bio_" + String(kind)]
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


static func is_bio(e: Array) -> bool:
	return String(e[2]).begins_with("bio_")


static func _bio_near(out: Dictionary, c: Vector2i) -> bool:
	for o: Vector2i in out:
		if is_bio(out[o]) and absi(o.x - c.x) < BIO_SPACING and absi(o.y - c.y) < BIO_SPACING:
			return true
	return false


## Posições (mundo) das luzes das plantas bioluminescentes deste chunk (em cache).
func bio_lights() -> PackedVector2Array:
	return _bio


var _bio := PackedVector2Array()


func _update_bio() -> void:
	var out := PackedVector2Array()
	if Guard.compat_level >= 3:
		_bio = out  # nível 3 (0.21): as plantas brilham, mas sem luz na névoa
		return
	for c: Vector2i in items:
		var e: Array = items[c]
		if is_bio(e):
			var up: bool = e[2] == &"bio_floor"
			out.append(Vector2(c.x * Balance.CELL_PX + Balance.CELL_PX * 0.5, c.y * Balance.CELL_PX + (-40.0 if up else Balance.CELL_PX + 40.0)))
	_bio = out


func _enter_tree() -> void:
	if not self in live:
		live.append(self)


func _exit_tree() -> void:
	live.erase(self)


static func _natural_air(w: WorldModel, c: Vector2i) -> bool:
	return c.y >= 0 and w.peek_cell(c) == BlockRegistry.AIR and not w.is_modified(c)


func build(p_world: WorldModel, index: int) -> void:
	world = p_world
	chunk_index = index
	items = plan(world, index, TerrainTextures.region_id)
	for c: Vector2i in items:
		if is_bio(items[c]):
			Guard.mark("plantas que brilham")
			break
	_update_bio()
	queue_redraw()


## Some a decoração cuja célula de apoio deixou de ser sólida.
func on_cells_changed(cells: Array[Vector2i]) -> void:
	var changed: bool = false
	for c in cells:
		if items.has(c) and not BlockRegistry.is_solid(world.peek_cell(c)):
			items.erase(c)
			changed = true
	if changed:
		_update_bio()
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
		if is_bio(e):
			_draw_bio(c, e, y0)
			continue
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


## Planta bioluminescente em pixels de arte: caule com folhas escuras e bulbos que brilham
## (no chão cresce para cima; no teto pende para baixo).
func _draw_bio(c: Vector2i, e: Array, y0: int) -> void:
	var a: float = float(Balance.CELL_PX) / Balance.CELL_SUB * 2.0  # pixel grosso (6 px)
	var up: bool = e[2] == &"bio_floor"
	var sy: float = -1.0 if up else 1.0
	var bx: float = roundf((c.x * Balance.CELL_PX + Balance.CELL_PX * 0.5) / a) * a
	var by: float = (c.y - y0) * Balance.CELL_PX + (SINK_PX if up else Balance.CELL_PX - SINK_PX)
	var fl: float = -1.0 if e[1] else 1.0
	var leaf := Color("1f5a52")
	var stem := Color("2f8a6e")
	var glow := Color("5cf2d0")
	var core := Color("eafffa")
	var px := func(dx: float, dy: float, w: float, h: float, col: Color) -> void:
		# dy cresce para longe da parede de apoio.
		var x: float = bx + dx * fl * a
		var rx: float = x if fl > 0.0 else x - w * a + a
		var ry: float = by + sy * dy * a
		draw_rect(Rect2(rx, ry if sy > 0.0 else ry - h * a + a, w * a, h * a), col)
	draw_circle(Vector2(bx, by + sy * 7.0 * a), 6.0 * a, Color(0.5, 1.0, 0.9, 0.12))
	draw_circle(Vector2(bx, by + sy * 8.0 * a), 3.5 * a, Color(0.6, 1.0, 0.9, 0.16))
	px.call(0.0, 0.0, 1.0, 9.0, stem)
	px.call(-3.0, 2.0, 3.0, 1.0, leaf)
	px.call(1.0, 3.0, 3.0, 1.0, leaf)
	px.call(-2.0, 5.0, 2.0, 1.0, leaf)
	px.call(1.0, 4.0, 1.0, 3.0, stem)
	px.call(-2.0, 6.0, 1.0, 2.0, stem)
	px.call(-1.0, 9.0, 3.0, 2.0, glow)
	px.call(0.0, 10.0, 1.0, 1.0, core)
	px.call(1.0, 7.0, 2.0, 2.0, glow)
	px.call(1.0, 8.0, 1.0, 1.0, core)
	px.call(-3.0, 8.0, 2.0, 2.0, glow)
	px.call(-3.0, 9.0, 1.0, 1.0, core)
