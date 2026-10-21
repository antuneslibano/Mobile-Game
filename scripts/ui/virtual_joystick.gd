class_name VirtualJoystick
extends Control
## Desenho do joystick flutuante. A lógica fica no InputController; aqui só visual.
## Inativo: aparece "fantasma" na posição de descanso para indicar o controle.

var active: bool = false
var base_pos: Vector2 = Vector2.ZERO
var knob_pos: Vector2 = Vector2.ZERO
var rest_pos: Vector2 = Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func show_at(base: Vector2, knob: Vector2) -> void:
	active = true
	base_pos = base
	knob_pos = knob
	queue_redraw()


func hide_stick() -> void:
	if active:
		active = false
		queue_redraw()


func _draw() -> void:
	var r: float = Balance.JOYSTICK_RADIUS_PX
	var b: Vector2 = base_pos if active else rest_pos
	var k: Vector2 = knob_pos if active else rest_pos
	var a: float = 1.0 if active else 0.35
	draw_circle(b, r + 6.0, Color(0, 0, 0, 0.25 * a))
	draw_arc(b, r, 0.0, TAU, 48, Color(UiTheme.TEXT, 0.35 * a), 4.0, true)
	# Setas: só baixo e lados — para cima não há ação.
	var c := Color(UiTheme.ACCENT, 0.7 * a)
	for d: Vector2 in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var tip: Vector2 = b + d * (r - 10.0)
		var side: Vector2 = d.orthogonal() * 10.0
		draw_colored_polygon(PackedVector2Array([tip, tip - d * 14.0 + side, tip - d * 14.0 - side]), c)
	draw_circle(k, 40.0, Color(UiTheme.PANEL, 0.85 * a))
	draw_arc(k, 40.0, 0.0, TAU, 36, Color(UiTheme.ACCENT, 0.9 * a), 4.0, true)
	draw_circle(k, 14.0, Color(UiTheme.ACCENT, 0.8 * a))
