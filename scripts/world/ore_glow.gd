class_name OreGlow
extends Node2D
## Brilho dos minérios valiosos de um chunk (só visual, por cima do terreno):
##   nível 1 (ouro, cristal…)   – cintilações em estrela de vez em quando;
##   nível 2 (gemas, urânio…)   – aura pulsante, cintilações e partículas subindo.
## Tudo em pixels de arte (3 px) e mistura aditiva. Some quando o centro do bloco é
## escavado. O nível vem de TerrainSkins.glow_tier (valor do que o bloco rende).

const ART: float = 3.0

var world: WorldModel
var chunk_index: int = 0
## Célula do centro do bloco → [posição local do centro, nível, cor, fase].
var items: Dictionary = {}
var _t: float = 0.0
var _redraw_cd: float = 0.0
const REDRAW_SEC: float = 1.0 / 30.0


func _init() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


## Blocos valiosos do chunk (função pura sobre o mundo: testável).
static func plan(w: WorldModel, index: int) -> Dictionary:
	var out: Dictionary = {}
	var sub: int = Balance.CELL_SUB
	var ch: int = Balance.CHUNK_CELLS_Y
	var ids: PackedByteArray = w.get_chunk(index).ids
	for by in ch / sub:
		for bx in Balance.WORLD_WIDTH:
			var lc := Vector2i(bx * sub + sub / 2, by * sub + sub / 2)
			var id: int = ids[lc.y * Balance.WORLD_CELLS_X + lc.x]
			var def: BlockDef = BlockRegistry.get_def(id)
			var tier: int = TerrainSkins.glow_tier(def)
			if tier == 0:
				continue
			var center := Vector2((bx + 0.5) * sub * Balance.CELL_PX, (by + 0.5) * sub * Balance.CELL_PX)
			var col: Color = def.color_accent.lightened(0.35)
			if id == BlockRegistry.CHEST:
				# Baú: a cor da aura mostra a raridade (dourada, azul, roxa).
				var gy: int = by + index * (ch / sub)
				var rar: int = Chests.rarity(Vector2i(bx, gy), w.generator.seed_value, gy)
				col = Chests.COLORS[rar]
				tier = 1 if rar == Chests.COMMON else 2
			out[Vector2i(lc.x, lc.y + index * ch)] = [center, tier, col, EnvArt.hash01(bx, by + index * 16, 913)]
	return out


func build(p_world: WorldModel, index: int) -> void:
	world = p_world
	chunk_index = index
	items = plan(world, index)
	queue_redraw()


func on_cells_changed(cells: Array[Vector2i]) -> void:
	var changed: bool = false
	for c in cells:
		if items.has(c) and not BlockRegistry.is_solid(world.peek_cell(c)):
			items.erase(c)
			changed = true
	if changed:
		queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if items.is_empty() or not is_visible_in_tree():
		return
	# Desempenho (0.14): redesenha a ~30 quadros/s e só se o chunk estiver na tela.
	_redraw_cd -= delta
	if _redraw_cd > 0.0:
		return
	_redraw_cd = REDRAW_SEC
	if _on_screen():
		queue_redraw()


func _on_screen() -> bool:
	var view: Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()
	var top: float = global_position.y
	var h: float = float(Balance.CHUNK_CELLS_Y * Balance.CELL_PX)
	return top < view.end.y + 64.0 and top + h > view.position.y - 64.0


func _px(p: Vector2) -> Vector2:
	return (p / ART).floor() * ART


func _draw() -> void:
	for c: Vector2i in items:
		var e: Array = items[c]
		var center: Vector2 = e[0]
		var tier: int = e[1]
		var col: Color = e[2]
		var ph: float = e[3]
		# Aura pulsante em degraus (anéis de pixels de arte); mais forte no nível 2.
		var pulse: float = 0.55 + 0.45 * sin(_t * 2.2 + ph * TAU)
		var strength: float = 1.0 if tier >= 2 else 0.7
		for ring in 3:
			var r: float = ART * (7 + ring * 3)
			draw_circle(_px(center), r, Color(col.r, col.g, col.b, (0.16 - ring * 0.045) * pulse * strength))
		if tier >= 2:
			# Partículas subindo e se apagando (algumas maiores).
			for m in 6:
				var mt: float = fposmod(_t * 0.32 + ph + m / 6.0, 1.0)
				var x: float = center.x + (EnvArt.hash01(m, int(ph * 977.0), 5) - 0.5) * 36.0 + sin(mt * 7.0 + m) * 5.0
				var y: float = center.y + 10.0 - mt * 70.0
				var sz: float = ART * (2.0 if m % 3 == 0 and mt < 0.5 else 1.0)
				draw_rect(Rect2(_px(Vector2(x, y)), Vector2(sz, sz)), Color(col.r, col.g, col.b, 1.0 - mt))
		# Cintilações: estrela de 4 pontas que acende e apaga.
		for k in (3 if tier >= 2 else 1):
			var tt: float = fposmod(_t * (0.55 if tier >= 2 else 0.45) + ph + k / 3.0, 1.0)
			if tt > 0.28:
				continue
			var kk: float = sin(tt / 0.28 * PI)
			var sp: Vector2 = center + Vector2((EnvArt.hash01(k, int(ph * 977.0), 7) - 0.5) * 30.0, (EnvArt.hash01(k, int(ph * 977.0), 8) - 0.5) * 30.0)
			var p: Vector2 = _px(sp)
			var a := Color(1.0, 0.97, 0.88, kk)
			draw_rect(Rect2(p, Vector2(ART, ART)), a)
			var arm: int = (3 if tier >= 2 else 2) if kk > 0.55 else 1
			for i in range(1, arm + 1):
				var s := Color(a.r, a.g, a.b, kk * (0.75 if i == 1 else 0.45))
				for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
					draw_rect(Rect2(p + d * ART * i, Vector2(ART, ART)), s)
