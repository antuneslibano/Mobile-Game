class_name SliderGrip
extends Control
## Arrasto de slider fácil no celular (0.21): envolve um HSlider e cuida do toque. Ao
## encostar em qualquer ponto da faixa, segura o valor de onde ele está (não pula) e
## acompanha só o movimento horizontal do dedo, mesmo que ele suba ou desça para fora da
## linha, até soltar. As listas roláveis não roubam esse arrasto.

var slider: HSlider
var _active: bool = false
var _start_x: float = 0.0
var _start_value: float = 0.0
var _moved: bool = false


static func wrap(s: HSlider) -> SliderGrip:
	var g := SliderGrip.new()
	g.slider = s
	g.name = String(s.name) + "Grip"
	g.size_flags_horizontal = s.size_flags_horizontal
	g.size_flags_vertical = s.size_flags_vertical
	g.custom_minimum_size = Vector2(s.custom_minimum_size.x, maxf(72.0, s.custom_minimum_size.y))
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.add_child(s)
	return g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _enter_tree() -> void:
	TouchScroll.no_scroll.append(self)


func _exit_tree() -> void:
	TouchScroll.no_scroll.erase(self)


func _gui_input(event: InputEvent) -> void:
	if not slider.editable:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_active = true
			_moved = false
			_start_x = mb.position.x
			_start_value = slider.value
		elif _active:
			_active = false
			if not _moved:
				# Toque sem arrastar: anda um passo na direção do toque.
				var grab_x: float = _value_to_x(slider.value)
				slider.value += slider.step * (1.0 if mb.position.x > grab_x else -1.0)
			slider.drag_ended.emit(true)
		accept_event()
	elif event is InputEventMouseMotion and _active:
		var dx: float = (event as InputEventMouseMotion).position.x - _start_x
		if absf(dx) > 3.0:
			_moved = true
		var span: float = maxf(1.0, size.x - 40.0)
		slider.value = clampf(_start_value + dx / span * (slider.max_value - slider.min_value), slider.min_value, slider.max_value)
		accept_event()


func _value_to_x(v: float) -> float:
	var r: float = slider.max_value - slider.min_value
	var k: float = (v - slider.min_value) / r if r > 0.0 else 0.0
	return 20.0 + k * maxf(1.0, size.x - 40.0)
