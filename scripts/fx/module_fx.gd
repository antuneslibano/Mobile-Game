class_name ModuleFx
extends Node2D
## Visuais dos módulos: drone orbitando a máquina com laser, e ondas do pulso sísmico.
## Apenas reage aos sinais do ModuleSystem; nenhuma regra aqui.

const LASER_TIME: float = 0.18
const RING_TIME: float = 0.45

var drill: Drill
var _t: float = 0.0
var _drone_pos: Vector2 = Vector2.ZERO
var _lasers: Array[Dictionary] = []
var _rings: Array[Dictionary] = []


func setup(p_drill: Drill) -> void:
	drill = p_drill
	drill.modules.drone_shot.connect(_on_drone_shot)
	drill.modules.pulse_fired.connect(_on_pulse)
	_drone_pos = drill.position + Vector2(40, -40)


func _process(delta: float) -> void:
	if drill == null:
		return
	_t += delta
	var target: Vector2 = drill.position + Vector2(cos(_t * 1.7) * 46.0, -44.0 + sin(_t * 3.4) * 7.0)
	_drone_pos = _drone_pos.lerp(target, 1.0 - exp(-8.0 * delta))
	for list: Array[Dictionary] in [_lasers, _rings]:
		var i: int = 0
		while i < list.size():
			list[i]["t"] = float(list[i]["t"]) + delta
			if float(list[i]["t"]) >= (LASER_TIME if list == _lasers else RING_TIME):
				list.remove_at(i)
			else:
				i += 1
	queue_redraw()


func _on_drone_shot(point: Vector2) -> void:
	_lasers.append({"to": point, "t": 0.0})


func _on_pulse(center: Vector2, radius_px: float, crit: bool) -> void:
	_rings.append({"center": center, "r": radius_px, "crit": crit, "t": 0.0})


func _draw() -> void:
	if drill == null:
		return
	for ring in _rings:
		var k: float = float(ring["t"]) / RING_TIME
		var col: Color = Color("ffd36b") if ring["crit"] else Color("c57bff")
		var r: float = float(ring["r"]) * ease(k, 0.4)
		draw_arc(ring["center"], r, 0.0, TAU, 48, Color(col, 0.8 * (1.0 - k)), 6.0 * (1.0 - k) + 2.0, true)
		draw_circle(ring["center"], r, Color(col, 0.12 * (1.0 - k)))
	if not drill.modules.has(ModuleSystem.DRONE):
		return
	for laser in _lasers:
		var k: float = float(laser["t"]) / LASER_TIME
		draw_line(_drone_pos, laser["to"], Color(0.45, 0.9, 1.0, 0.9 * (1.0 - k)), 4.0 * (1.0 - k) + 1.0)
		draw_circle(laser["to"], 8.0 * (1.0 - k), Color(0.7, 0.95, 1.0, 0.7 * (1.0 - k)))
	# Drone: casco metálico, olho azul e hélices.
	var p: Vector2 = _drone_pos
	var spin: float = sin(_t * 40.0) * 6.0
	draw_line(p + Vector2(-16, -9), p + Vector2(-6, -9), Color("b8c4cf"), 2.0)
	draw_line(p + Vector2(6, -9), p + Vector2(16, -9), Color("b8c4cf"), 2.0)
	draw_line(p + Vector2(-11 - spin, -12), p + Vector2(-11 + spin, -12), Color("dfe7ee", 0.8), 2.0)
	draw_line(p + Vector2(11 - spin, -12), p + Vector2(11 + spin, -12), Color("dfe7ee", 0.8), 2.0)
	draw_circle(p, 11.0, Color("2a2026"))
	draw_circle(p, 9.0, Color("6e7a86"))
	draw_rect(Rect2(p + Vector2(-9, -2), Vector2(18, 4)), Color("f2b33d"))
	draw_circle(p + Vector2(0, 2), 4.0, Color("4fc3ff"))
	draw_circle(p + Vector2(0, 2), 7.0, Color(0.31, 0.76, 1.0, 0.25))
