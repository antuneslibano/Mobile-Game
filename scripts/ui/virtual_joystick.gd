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
	# Estilo pixel art: anel metálico com rebites, setas laranja (baixo e lados), manopla dourada.
	var r: float = Balance.JOYSTICK_RADIUS_PX
	var b: Vector2 = base_pos if active else rest_pos
	var k: Vector2 = knob_pos if active else rest_pos
	var a: float = 1.0 if active else 0.4
	draw_circle(b, r + 9.0, Color(PixelArt.OUTLINE, 0.55 * a))
	draw_arc(b, r + 3.0, 0.0, TAU, 40, Color(PixelArt.STEEL, a), 6.0, false)
	draw_arc(b, r, 0.0, TAU, 40, Color(PixelArt.STEEL_HI, a), 2.0, false)
	for i in 8:
		var p: Vector2 = b + Vector2.from_angle(i * TAU / 8.0 + PI / 8.0) * (r + 3.0)
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(Color("c3cad8"), a))
	# Setas: só baixo e lados — para cima não há ação.
	var c := Color(PixelArt.ORANGE, 0.9 * a)
	for d: Vector2 in [Vector2.DOWN, Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2.LEFT, Vector2.RIGHT]:
		var tip: Vector2 = b + d * (r - 12.0)
		var side: Vector2 = d.orthogonal() * 9.0
		draw_colored_polygon(PackedVector2Array([tip + d * 2.0, tip - d * 14.0 + side, tip - d * 14.0 - side]), Color(PixelArt.OUTLINE, a))
		draw_colored_polygon(PackedVector2Array([tip, tip - d * 11.0 + side * 0.7, tip - d * 11.0 - side * 0.7]), c)
	draw_circle(k, 42.0, Color(PixelArt.OUTLINE, 0.9 * a))
	draw_circle(k, 38.0, Color(PixelArt.GOLD_LO, a))
	draw_circle(k + Vector2(-2, -2), 34.0, Color(PixelArt.GOLD, a))
	draw_circle(k + Vector2(-8, -9), 10.0, Color(PixelArt.GOLD_HI, a))
