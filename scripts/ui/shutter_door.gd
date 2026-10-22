class_name ShutterDoor
extends CanvasLayer
## Porta de metal de enrolar que cobre a tela inteira na troca de telas (0.15). Desenhada
## em código (chapas com frisos, rebites e faixa de perigo na barra de baixo). Desce,
## quica ao bater no chão, espera um instante, chama on_closed e sobe. Veja
## Transitions.shutter.

const DOWN_SEC: float = 0.26
const HOLD_SEC: float = 0.12
const UP_SEC: float = 0.32
const SLAT_H: float = 44.0
const BAR_H: float = 46.0

var on_closed: Callable
var _panel: Control


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = Control.new()
	_panel.name = "Door"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.draw.connect(_draw_door)
	add_child(_panel)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_panel.size = vp
	_panel.position = Vector2(0, -vp.y)
	Sfx.play(&"shutter", 1.0, -4.0)
	var tw: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_panel, "position:y", 0.0, DOWN_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: Sfx.play(&"door_slam", 1.0, -2.0))
	tw.tween_property(_panel, "position:y", -22.0, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "position:y", 0.0, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(HOLD_SEC)
	tw.tween_callback(_swap)
	tw.tween_callback(func() -> void: Sfx.play(&"shutter", 0.85, -6.0))
	tw.tween_property(_panel, "position:y", -vp.y, UP_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _swap() -> void:
	if on_closed.is_valid():
		on_closed.call()


func _draw_door() -> void:
	var sz: Vector2 = _panel.size
	var body_h: float = sz.y - BAR_H
	# Chapas horizontais com friso claro em cima e sulco escuro embaixo.
	var y: float = body_h
	var i: int = 0
	while y > -SLAT_H:
		y -= SLAT_H
		var base: Color = Color("5d6876") if i % 2 == 0 else Color("566170")
		_panel.draw_rect(Rect2(0, y, sz.x, SLAT_H), base)
		_panel.draw_rect(Rect2(0, y, sz.x, 6), Color("8d99a8"))
		_panel.draw_rect(Rect2(0, y + 6, sz.x, 3), Color("6f7b8a"))
		_panel.draw_rect(Rect2(0, y + SLAT_H - 8, sz.x, 5), Color("3a424d"))
		_panel.draw_rect(Rect2(0, y + SLAT_H - 3, sz.x, 3), Color("20262e"))
		i += 1
	# Trilhos laterais com rebites.
	for x: float in [0.0, sz.x - 24.0]:
		_panel.draw_rect(Rect2(x, 0, 24, body_h), Color("323a44"))
		_panel.draw_rect(Rect2(x + 4, 0, 4, body_h), Color("4a5461"))
		var ry: float = 20.0
		while ry < body_h:
			_panel.draw_rect(Rect2(x + 9, ry, 6, 6), Color("9aa6b4"))
			_panel.draw_rect(Rect2(x + 12, ry + 3, 3, 3), Color("2a3038"))
			ry += 88.0
	# Barra de baixo: faixa de perigo amarela e preta e puxador.
	var by: float = body_h
	_panel.draw_rect(Rect2(0, by, sz.x, BAR_H), Color("1c2027"))
	var stripe: float = 30.0
	var sx: float = -BAR_H
	var k: int = 0
	while sx < sz.x:
		var col: Color = UiTheme.ORANGE if k % 2 == 0 else Color("1c2027")
		_panel.draw_colored_polygon(PackedVector2Array([
			Vector2(sx, by + BAR_H - 6), Vector2(sx + stripe, by + BAR_H - 6),
			Vector2(sx + stripe + BAR_H - 18, by + 6), Vector2(sx + BAR_H - 18, by + 6)]), col)
		sx += stripe
		k += 1
	_panel.draw_rect(Rect2(0, by, sz.x, 6), Color("8d99a8"))
	_panel.draw_rect(Rect2(0, by + BAR_H - 6, sz.x, 6), Color("0e1014"))
	var hw: float = 120.0
	_panel.draw_rect(Rect2(sz.x * 0.5 - hw * 0.5, by - 30, hw, 18), Color("2a3038"))
	_panel.draw_rect(Rect2(sz.x * 0.5 - hw * 0.5 + 6, by - 27, hw - 12, 6), Color("9aa6b4"))
