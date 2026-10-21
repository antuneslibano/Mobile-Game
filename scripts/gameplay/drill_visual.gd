class_name DrillVisual
extends Node2D
## Desenho procedural da perfuradora (amarelo industrial, metal e luzes azuis).
## Apenas lê o estado do nó Drill pai; nenhuma regra de jogo aqui.

const YELLOW := Color("f2b33d")
const YELLOW_LIGHT := Color("ffd77a")
const YELLOW_DARK := Color("b87a1f")
const OUTLINE := Color("2a2026")
const METAL := Color("6e7a86")
const METAL_LIGHT := Color("b8c4cf")
const METAL_DARK := Color("3a3f47")
const BLUE := Color("4fc3ff")
const BLUE_GLOW := Color(0.31, 0.76, 1.0, 0.22)

var drill: Drill
var _t: float = 0.0
var _kick: float = 0.0
var _spin: float = 0.0
var _tread: float = 0.0
var _hop_squash: float = 0.0


func _ready() -> void:
	drill = get_parent() as Drill
	if drill != null:
		drill.block_hit.connect(_on_hit)
		drill.hopped.connect(func() -> void: _hop_squash = 1.0)


func _on_hit(_cell: Vector2i, _id: int, _dmg: float, crit: bool, destroyed: bool) -> void:
	_kick = 1.0 if (crit or destroyed) else maxf(_kick, 0.6)


func _process(delta: float) -> void:
	_t += delta
	_kick = maxf(0.0, _kick - delta * 7.0)
	_hop_squash = maxf(0.0, _hop_squash - delta * 4.0)
	var drilling: bool = drill != null and drill.has_target
	_spin += delta * (26.0 if drilling else 4.0)
	if drill != null:
		_tread += drill.velocity.x * delta * 0.25
	# Tremor durante a perfuração.
	if drilling:
		position = Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0)) * (1.0 + _kick * 1.5)
	else:
		position = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var drilling: bool = drill != null and drill.has_target
	var dir: Vector2i = drill.drill_dir if drill != null else Vector2i.DOWN
	var squash: float = _hop_squash * 2.0

	# Feixe do farol (suave, translúcido).
	var beam_len: float = 70.0
	if dir == Vector2i.DOWN:
		draw_colored_polygon(PackedVector2Array([Vector2(-10, 10), Vector2(10, 10), Vector2(30, 10 + beam_len), Vector2(-30, 10 + beam_len)]), Color(0.6, 0.85, 1.0, 0.06))
	else:
		var s: float = float(dir.x)
		draw_colored_polygon(PackedVector2Array([Vector2(14 * s, -8), Vector2(14 * s, 4), Vector2((14 + beam_len) * s, 22), Vector2((14 + beam_len) * s, -26)]), Color(0.6, 0.85, 1.0, 0.06))

	# Broca.
	if dir == Vector2i.DOWN:
		_draw_bit_down(drilling)
	else:
		_draw_bit_side(dir.x, drilling)

	var mods: Array[StringName] = drill.modules.equipped if drill != null else ([] as Array[StringName])
	var boosting: bool = drill != null and drill.energy.is_boosting()
	if boosting:
		var pulse_a: float = 0.18 + 0.08 * sin(_t * 18.0)
		draw_circle(Vector2(0, -4), 34.0, Color(0.31, 0.76, 1.0, pulse_a))
		draw_circle(Vector2(0, -4), 26.0, Color(0.6, 0.9, 1.0, pulse_a * 0.8))

	# Brocas laterais (módulo).
	if mods.has(ModuleSystem.SIDE_DRILL):
		for sx: float in [-1.0, 1.0]:
			var base_x: float = 17.0 * sx
			draw_colored_polygon(PackedVector2Array([Vector2(base_x, -4), Vector2(base_x, 6), Vector2(base_x + 11.0 * sx, 1)]), OUTLINE)
			draw_colored_polygon(PackedVector2Array([Vector2(base_x, -3), Vector2(base_x, 5), Vector2(base_x + 9.0 * sx, 1)]), METAL_LIGHT)
			var ph: float = fposmod(_spin, 1.0)
			draw_line(Vector2(base_x + 3.0 * sx * (1.0 + ph), -2), Vector2(base_x + 3.0 * sx * (1.0 + ph), 4), METAL_DARK, 1.5)

	# Esteiras.
	var tread_rect := Rect2(-21, 5 + squash * 0.5, 42, 12 - squash * 0.5)
	draw_rect(tread_rect.grow(1.5), OUTLINE)
	draw_rect(tread_rect, METAL_DARK)
	var peg_off: float = fposmod(_tread, 6.0)
	var x: float = -21.0 + peg_off
	while x < 21.0:
		draw_rect(Rect2(x, tread_rect.position.y + 2, 3, tread_rect.size.y - 4), METAL)
		x += 6.0
	draw_rect(Rect2(-21, tread_rect.position.y, 42, 2), METAL_LIGHT.darkened(0.2))

	# Corpo.
	var body := Rect2(-17, -19 + squash, 34, 25 - squash)
	draw_rect(body.grow(1.5), OUTLINE)
	draw_rect(body, YELLOW)
	draw_rect(Rect2(body.position, Vector2(body.size.x, 3)), YELLOW_LIGHT)
	draw_rect(Rect2(body.position.x, body.end.y - 4, body.size.x, 4), YELLOW_DARK)
	# Faixas de advertência.
	for i in 4:
		var fx: float = body.position.x + 3.0 + i * 8.0
		draw_colored_polygon(PackedVector2Array([Vector2(fx, body.end.y - 4), Vector2(fx + 4, body.end.y - 4), Vector2(fx + 2, body.end.y), Vector2(fx - 2, body.end.y)]), OUTLINE)
	# Placa metálica e rebites.
	draw_rect(Rect2(3, body.position.y + 6, 11, 10), METAL)
	draw_rect(Rect2(3, body.position.y + 6, 11, 2), METAL_LIGHT)
	draw_rect(Rect2(5, body.position.y + 11, 2, 2), METAL_DARK)
	draw_rect(Rect2(10, body.position.y + 11, 2, 2), METAL_DARK)
	# Cabine com luz azul.
	var pulse: float = 0.75 + 0.25 * sin(_t * 3.0) + _kick * 0.3
	var win := Rect2(-13, body.position.y + 6, 13, 8)
	draw_rect(win.grow(1.0), OUTLINE)
	draw_rect(win, BLUE.darkened(0.45))
	draw_rect(Rect2(win.position, Vector2(win.size.x, 3)), BLUE * Color(1, 1, 1, pulse))
	draw_rect(Rect2(win.position.x + 1, win.position.y + 1, 3, 2), Color(1, 1, 1, 0.7))
	# Escapamento.
	draw_rect(Rect2(9, body.position.y - 7, 5, 8), OUTLINE)
	draw_rect(Rect2(10, body.position.y - 6, 3, 7), METAL)
	# Emissor sísmico (módulo): antena com anel pulsante.
	if mods.has(ModuleSystem.SEISMIC):
		var ex: Vector2 = Vector2(-8, body.position.y - 4)
		draw_line(ex, ex + Vector2(0, -9), METAL_DARK, 3.0)
		draw_circle(ex + Vector2(0, -11), 4.0, Color("c57bff"))
		var cd: float = drill.modules.pulse_cd if drill != null else 1.0
		var charge: float = 1.0 - clampf(cd / ModuleSystem.pulse_interval(drill.stats), 0.0, 1.0) if drill != null else 0.0
		draw_arc(ex + Vector2(0, -11), 7.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 16, Color("e3c2ff"), 2.0)
	# Base do drone (módulo).
	if mods.has(ModuleSystem.DRONE):
		draw_rect(Rect2(-3, body.position.y - 3, 8, 3), BLUE)
	# Chamas de impulso no escapamento.
	if boosting:
		var fl: float = 8.0 + 4.0 * sin(_t * 30.0)
		draw_colored_polygon(PackedVector2Array([Vector2(10, body.position.y - 7), Vector2(13, body.position.y - 7), Vector2(11.5, body.position.y - 7 - fl)]), Color(0.6, 0.9, 1.0, 0.9))

	# Farol azul.
	var lamp := Vector2(-15 if dir.x < 0 else 15, body.position.y + 17)
	draw_circle(lamp, 7.0 + _kick * 3.0, BLUE_GLOW)
	draw_circle(lamp, 3.0, BLUE * Color(1, 1, 1, pulse))
	draw_circle(lamp, 1.5, Color.WHITE)


func _draw_bit_down(drilling: bool) -> void:
	var ext: float = 6.0 if drilling else 0.0
	var top: float = 13.0
	var tip: float = 27.0 + ext
	var cone := PackedVector2Array([Vector2(-12, top), Vector2(12, top), Vector2(0, tip)])
	draw_colored_polygon(PackedVector2Array([Vector2(-14, top - 1), Vector2(14, top - 1), Vector2(0, tip + 2)]), OUTLINE)
	draw_colored_polygon(cone, METAL)
	# Espirais animadas.
	var phase: float = fposmod(_spin, 1.0)
	for i in 4:
		var f: float = (float(i) + phase) / 4.0
		var y: float = lerpf(top, tip, f)
		var hw: float = 12.0 * (1.0 - f)
		draw_line(Vector2(-hw, y), Vector2(hw, y + 3.0 * (1.0 - f)), METAL_LIGHT if i % 2 == 0 else METAL_DARK, 2.0)
	draw_rect(Rect2(-14, top - 3, 28, 4), METAL_DARK)
	if drilling:
		draw_circle(Vector2(0, tip), 3.0 + _kick * 2.0, Color(1.0, 0.85, 0.5, 0.5))


func _draw_bit_side(dir_x: int, drilling: bool) -> void:
	var s: float = float(dir_x)
	var ext: float = 6.0 if drilling else 0.0
	var base: float = 15.0
	var tip: float = 30.0 + ext
	draw_colored_polygon(PackedVector2Array([Vector2(base * s, -11), Vector2(base * s, 9), Vector2((tip + 2) * s, -1)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([Vector2(base * s, -10), Vector2(base * s, 8), Vector2(tip * s, -1)]), METAL)
	var phase: float = fposmod(_spin, 1.0)
	for i in 4:
		var f: float = (float(i) + phase) / 4.0
		var x: float = lerpf(base, tip, f) * s
		var hh: float = 9.0 * (1.0 - f)
		draw_line(Vector2(x, -1 - hh), Vector2(x + 3.0 * s * (1.0 - f), -1 + hh), METAL_LIGHT if i % 2 == 0 else METAL_DARK, 2.0)
	if drilling:
		draw_circle(Vector2(tip * s, -1), 3.0 + _kick * 2.0, Color(1.0, 0.85, 0.5, 0.5))
