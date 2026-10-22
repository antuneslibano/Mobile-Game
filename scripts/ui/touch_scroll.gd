class_name TouchScroll
extends ScrollContainer
## Lista rolável por arrasto em qualquer ponto do conteúdo (inclusive sobre cartões e
## botões), com inércia ao soltar. O arrasto nativo do ScrollContainer não funciona quando
## o dedo começa num botão (o botão consome o toque), então ele é desligado e o arrasto é
## lido em _input. Ao virar arrasto, o toque no botão é cancelado: rolar nunca compra nada.

const DRAG_START_PX: float = 14.0   ## Movimento mínimo para virar arrasto (toque vira rolagem).
const FRICTION: float = 5.0         ## Desaceleração da inércia (1/s).
const MIN_FLING: float = 40.0       ## Velocidade (px/s) abaixo da qual a inércia para.

var _tracking: bool = false
var _dragging: bool = false
var _index: int = -1
var _start: Vector2 = Vector2.ZERO
var _start_scroll: float = 0.0
var _scroll_f: float = 0.0
var _vel: float = 0.0
var _last_y: float = 0.0
var _last_t: float = 0.0


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Desliga o arrasto nativo (evita rolagem dobrada quando o toque começa em área vazia).
	scroll_deadzone = 1000000


func is_dragging() -> bool:
	return _dragging


func _max_scroll() -> float:
	return maxf(0.0, get_v_scroll_bar().max_value - size.y)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		_tracking = false
		_dragging = false
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if not _tracking and get_global_rect().has_point(t.position):
				_tracking = true
				_dragging = false
				_index = t.index
				_start = t.position
				_start_scroll = float(scroll_vertical)
				_scroll_f = _start_scroll
				_vel = 0.0
				_last_y = t.position.y
				_last_t = Time.get_ticks_msec() / 1000.0
		elif t.index == _index and _tracking:
			_tracking = false
			if _dragging:
				_dragging = false
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _tracking:
		var d := event as InputEventScreenDrag
		if d.index != _index:
			return
		var dy: float = d.position.y - _start.y
		if not _dragging and absf(dy) > DRAG_START_PX:
			_dragging = true
			_start = d.position
			_start_scroll = float(scroll_vertical)
			_cancel_press()
		if _dragging:
			_scroll_f = clampf(_start_scroll - (d.position.y - _start.y), 0.0, _max_scroll())
			scroll_vertical = roundi(_scroll_f)
			var now: float = Time.get_ticks_msec() / 1000.0
			if now > _last_t:
				_vel = lerpf(_vel, (d.position.y - _last_y) / (now - _last_t), 0.5)
			_last_y = d.position.y
			_last_t = now
			get_viewport().set_input_as_handled()


## Inércia depois de soltar.
func _process(delta: float) -> void:
	if _dragging or absf(_vel) < MIN_FLING:
		return
	_scroll_f = clampf(_scroll_f - _vel * delta, 0.0, _max_scroll())
	scroll_vertical = roundi(_scroll_f)
	_vel *= exp(-FRICTION * delta)
	if _scroll_f <= 0.0 or _scroll_f >= _max_scroll():
		_vel = 0.0


## O botão sob o dedo só dispara ao soltar dentro dele: move o "mouse" para longe e solta
## lá, então o botão desiste e o soltar real (depois do arrasto) não aciona nada.
func _cancel_press() -> void:
	var far := Vector2(-100000, -100000)
	var mm := InputEventMouseMotion.new()
	mm.position = far
	mm.global_position = far
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(mm)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = false
	mb.position = far
	mb.global_position = far
	get_viewport().push_input(mb)
