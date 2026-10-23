class_name SonarOverlay
extends CanvasLayer
## Sonar (0.13): habilidade da nave com recarga. Ao usar, uma onda sai da nave (bip de
## submarino) e, por onde passa, marca minérios, baús e criaturas próximos: um sinal
## pulsante na posição (visível mesmo na névoa) e, se estiver fora da tela, uma seta na
## borda apontando a direção. Os sinais somem depois de SONAR_BLIP_SEC.

const ART: float = 3.0

var world: WorldModel
var drill: Drill
var creatures: CreatureManager
## Recarga restante (s). 0 = pronto.
var cooldown: float = 0.0
var wave_center: Vector2 = Vector2.ZERO
var wave_radius: float = 0.0
## Sinais: {pos (mundo), color, t, kind (&"ore"/&"chest"/&"creature")}.
var blips: Array[Dictionary] = []
var _wave_t: float = -1.0
var _scanned: Dictionary = {}
var _draw_node: Control
var _beeps: int = 0
## Tempo desde o fim da onda (para a luz e o anel apagarem devagar).
var _fade_t: float = 99.0
const FADE_SEC: float = 0.9


func _ready() -> void:
	layer = 3
	_draw_node = Control.new()
	_draw_node.name = "SonarDraw"
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.draw.connect(_on_draw)
	add_child(_draw_node)


func reset() -> void:
	cooldown = 0.0
	blips.clear()
	_wave_t = -1.0


func ready_ratio() -> float:
	return 1.0 - clampf(cooldown / Balance.SONAR_COOLDOWN, 0.0, 1.0)


func is_ready() -> bool:
	return cooldown <= 0.0


func wave_active() -> bool:
	return _wave_t >= 0.0


## Luz da onda (1 durante a onda, caindo até 0 em FADE_SEC depois dela).
func light_level() -> float:
	if wave_active():
		return 1.0
	return clampf(1.0 - _fade_t / FADE_SEC, 0.0, 1.0)


## Dispara o sonar (se pronto). Retorna true se disparou.
func ping() -> bool:
	if not is_ready() or drill == null or world == null:
		return false
	cooldown = Balance.SONAR_COOLDOWN
	wave_center = drill.position
	wave_radius = 0.0
	_wave_t = 0.0
	_fade_t = 99.0
	_scanned.clear()
	_beeps = 0
	Sfx.play(&"sonar")
	return true


## Avança a onda e os sinais (chamado pelo Game no passo de física).
func step(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	for b in blips:
		b.t = float(b.t) + delta
	blips = blips.filter(func(b: Dictionary) -> bool: return float(b.t) < Balance.SONAR_BLIP_SEC)
	if _wave_t < 0.0:
		_fade_t += delta
		return
	_wave_t += delta
	var prev: float = wave_radius
	var max_r: float = Balance.SONAR_RANGE_BLOCKS * Balance.BLOCK_PX
	wave_radius = minf(max_r, _wave_t * Balance.SONAR_SPEED_BLOCKS * Balance.BLOCK_PX)
	_scan_ring(prev, wave_radius)
	if wave_radius >= max_r:
		_wave_t = -1.0
		_fade_t = 0.0


## Marca o que a onda alcançou entre r0 e r1 (por bloco: célula central do bloco).
func _scan_ring(r0: float, r1: float) -> void:
	var b: float = Balance.BLOCK_PX
	var c: Vector2 = wave_center
	var bx0: int = maxi(0, floori((c.x - r1) / b))
	var bx1: int = mini(Balance.WORLD_WIDTH - 1, floori((c.x + r1) / b))
	var by0: int = maxi(0, floori((c.y - r1) / b))
	var by1: int = floori((c.y + r1) / b)
	for by in range(by0, by1 + 1):
		for bx in range(bx0, bx1 + 1):
			var center := Vector2((bx + 0.5) * b, (by + 0.5) * b)
			var d: float = center.distance_to(c)
			if d < r0 or d >= r1:
				continue
			var key := Vector2i(bx, by)
			if _scanned.has(key):
				continue
			_scanned[key] = true
			var cell := Vector2i(bx * Balance.CELL_SUB + 2, by * Balance.CELL_SUB + 2)
			if not world.has_chunk(WorldModel.chunk_index_for_row(cell.y)):
				continue
			var id: int = world.peek_cell(cell)
			var def: BlockDef = BlockRegistry.get_def(id)
			var kind: StringName = &""
			if Relics.is_relic_block(id):
				kind = &"relic"
			elif id == BlockRegistry.CHEST:
				kind = &"chest"
			elif not TerrainSkins.ore_sprite_for(id).is_empty() or id == BlockRegistry.ARTIFACT or id == BlockRegistry.FOSSIL:
				kind = &"ore"
			if kind == &"":
				continue
			if _near_blip(center, kind):
				continue  # um sinal por veio (blocos vizinhos do mesmo tipo não repetem)
			var col: Color = def.color_accent.lightened(0.3)
			if kind == &"chest":
				col = Chests.COLORS[Chests.rarity(key, world.generator.seed_value, by)]
			elif kind == &"relic":
				col = Color("ffd23f")
			blips.append({"pos": center, "color": col, "t": 0.0, "kind": kind,
					"weak": not MiningRules.can_break(id, drill.stats.drill_tier)})
			_beep(d)
	if creatures != null:
		for cr in creatures.creatures:
			var d: float = cr.pos.distance_to(c)
			if d >= r0 and d < r1:
				blips.append({"pos": cr.pos, "color": Color("ff4a3a") if cr.is_hostile() else Color("9bff5a"), "t": 0.0, "kind": &"creature", "weak": false})


func _near_blip(p: Vector2, kind: StringName) -> bool:
	for b in blips:
		if b.kind == kind and (b.pos as Vector2).distance_to(p) < Balance.BLOCK_PX * 2.2:
			return true
	return false


func _beep(dist: float) -> void:
	if _beeps >= 8:
		return
	_beeps += 1
	Sfx.play(&"blip", 1.3 - dist / (Balance.SONAR_RANGE_BLOCKS * Balance.BLOCK_PX) * 0.5, -10.0, 0.06)


func _process(_delta: float) -> void:
	if wave_active() or not blips.is_empty() or light_level() > 0.0:
		_draw_node.queue_redraw()
	elif _draw_node.get_meta("drawn", false):
		_draw_node.set_meta("drawn", false)
		_draw_node.queue_redraw()


func _on_draw() -> void:
	_draw_node.set_meta("drawn", true)
	var xf: Transform2D = _draw_node.get_viewport().get_canvas_transform()
	var sc: float = xf.get_scale().x
	var vp: Vector2 = _draw_node.get_viewport_rect().size
	var now: float = Time.get_ticks_msec() / 1000.0
	if light_level() > 0.0:
		var c: Vector2 = xf * wave_center
		var a: float = (1.0 - wave_radius / (Balance.SONAR_RANGE_BLOCKS * Balance.BLOCK_PX) * 0.7) * light_level()
		_draw_node.draw_arc(c, wave_radius * sc, 0.0, TAU, 96, Color(0.4, 1.0, 0.8, 0.8 * a), 4.0)
		_draw_node.draw_arc(c, wave_radius * sc - 10.0, 0.0, TAU, 96, Color(0.4, 1.0, 0.8, 0.25 * a), 10.0)
	var margin: float = 46.0
	var top: float = 300.0
	for b in blips:
		# Aparece rápido (0,25 s) e some devagar (último terço da vida).
		var life: float = float(b.t) / Balance.SONAR_BLIP_SEC
		var k: float = clampf(float(b.t) / 0.25, 0.0, 1.0) * clampf((1.0 - life) / 0.35, 0.0, 1.0)
		var col: Color = b.color
		var p: Vector2 = xf * (b.pos as Vector2)
		var pulse: float = 0.5 + 0.5 * sin(now * 6.0 + p.x * 0.01)
		var inside: bool = p.x > 0 and p.y > top and p.x < vp.x and p.y < vp.y
		if inside and b.kind == &"relic":
			# Relíquia: estrela dourada grande, pulsando.
			var rs: float = 16.0 + 6.0 * pulse
			var star := PackedVector2Array()
			for si in 10:
				var rad: float = rs if si % 2 == 0 else rs * 0.45
				star.append(p + Vector2.from_angle(-PI * 0.5 + si * TAU / 10.0) * rad)
			_draw_node.draw_colored_polygon(star, Color(col.r, col.g, col.b, k))
			_draw_node.draw_arc(p, rs + 10.0, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.6 * k), 3.0)
		elif inside:
			var r: float = 11.0 if b.kind == &"chest" else 7.0
			_draw_node.draw_arc(p, r + 6.0 + 6.0 * pulse, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.6 * k), 3.0)
			_draw_node.draw_rect(Rect2(p - Vector2(r, r) * 0.5, Vector2(r, r)), Color(col.r, col.g, col.b, k))
			if bool(b.weak):
				_draw_node.draw_line(p + Vector2(-r, -r), p + Vector2(r, r), Color(1, 0.3, 0.2, k), 2.0)
		else:
			# Fora da tela: seta na borda apontando para o sinal.
			var center: Vector2 = vp * 0.5
			var dir: Vector2 = (p - center).normalized()
			var edge: Vector2 = Vector2(clampf(p.x, margin, vp.x - margin), clampf(p.y, top + margin, vp.y - margin))
			var tip: Vector2 = edge
			var side := Vector2(-dir.y, dir.x)
			var pts := PackedVector2Array([tip + dir * 14.0, tip - dir * 8.0 + side * 10.0, tip - dir * 8.0 - side * 10.0])
			_draw_node.draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.85 * k))
			_draw_node.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0, 0, 0, 0.8 * k), 2.0)
