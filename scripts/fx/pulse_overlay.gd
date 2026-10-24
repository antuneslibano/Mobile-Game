class_name PulseOverlay
extends CanvasLayer
## Batimento do guardião (0.21): a cada pulso, as bordas da tela brilham na cor do núcleo
## e uma onda passa pela tela. Só desenho; quem chama é Game (sinal beat da perseguição).

var _k: float = 0.0
var _color: Color = Color.RED
var _from: Vector2 = Vector2.ZERO
var _rect: Control


func _ready() -> void:
	layer = 3
	_rect = Control.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.draw.connect(_draw_pulse)
	add_child(_rect)


## Um pulso (strength 0..1) saindo de screen_pos.
func pulse(strength: float, color: Color, screen_pos: Vector2) -> void:
	_k = clampf(strength, 0.0, 1.0)
	_color = color
	_from = screen_pos


func _process(delta: float) -> void:
	if _k > 0.0:
		_k = maxf(0.0, _k - delta * 1.8)
		_rect.queue_redraw()


func _draw_pulse() -> void:
	if _k <= 0.0:
		return
	var sz: Vector2 = _rect.size
	var c: Color = _color
	# Bordas pulsando (faixas que somem para dentro).
	for i in 6:
		var w: float = 10.0 + i * 12.0
		var a: float = _k * 0.22 * (1.0 - i / 6.0)
		var col := Color(c.r, c.g, c.b, a)
		_rect.draw_rect(Rect2(0, 0, w, sz.y), col)
		_rect.draw_rect(Rect2(sz.x - w, 0, w, sz.y), col)
		_rect.draw_rect(Rect2(0, sz.y - w, sz.x, w), col)
	# Onda saindo do núcleo.
	var r: float = (1.0 - _k) * sz.y * 0.9 + 40.0
	_rect.draw_arc(_from, r, 0.0, TAU, 72, Color(c.r, c.g, c.b, 0.35 * _k), 10.0 * _k + 2.0)
	_rect.draw_arc(_from, r * 0.8, 0.0, TAU, 72, Color(1, 1, 1, 0.12 * _k), 3.0)
