class_name SettingsScreen
extends CanvasLayer
## Configurações (0.16): volume da música, dos efeitos e da máquina (broca e motor).
## Abre por cima de tudo (pausa o jogo) pelo botão de engrenagem da base ou do HUD; os
## valores ficam salvos à parte do perfil (Sfx.save_settings).

signal closed

const ROWS: Array = [
	[&"music", "Música", "Trilha sonora"],
	[&"sfx", "Efeitos", "Coleta, golpes, criaturas, botões"],
	[&"machine", "Máquina", "Broca e motor da nave"],
]

var _root: Control
var _panel: PanelContainer
var _sliders: Dictionary = {}   ## canal → HSlider
var _values: Dictionary = {}    ## canal → Label (porcentagem)
var _was_paused: bool = false


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	for ch: StringName in _sliders:
		(_sliders[ch] as HSlider).set_value_no_signal(roundf(Sfx.get_volume(ch) * 100.0))
		_update_label(ch)
	Transitions.pop_in(_panel)


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused
	Sfx.save_settings()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			close())
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", PixelArt.style(&"frame"))
	_panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	_panel.add_child(v)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", PixelArt.style(&"plate"))
	v.add_child(plate)
	var title := UiTheme.label(UiTheme.display_text("CONFIGURAÇÕES"), 34, Color("2a1606"), 700)
	title.add_theme_constant_override("outline_size", 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(title)
	v.add_child(UiTheme.label("VOLUME", 26, UiTheme.ORANGE, 700))
	for row: Array in ROWS:
		v.add_child(_volume_row(row[0], row[1], row[2]))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	v.add_child(buttons)
	var reset := Button.new()
	reset.name = "ResetButton"
	reset.text = UiTheme.display_text("PADRÃO")
	reset.custom_minimum_size = Vector2(0, 76)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.add_theme_font_size_override("font_size", UiTheme.font_size(24, 700))
	UiTheme.style_button(reset, &"steel")
	reset.pressed.connect(func() -> void:
		for ch: StringName in _sliders:
			(_sliders[ch] as HSlider).value = 100.0)
	buttons.add_child(reset)
	var ok := Button.new()
	ok.name = "SettingsClose"
	ok.text = UiTheme.display_text("PRONTO")
	ok.custom_minimum_size = Vector2(0, 76)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.add_theme_font_size_override("font_size", UiTheme.font_size(24, 700))
	UiTheme.style_button(ok, &"green")
	ok.pressed.connect(close)
	buttons.add_child(ok)


func _volume_row(ch: StringName, name: String, hint: String) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", PixelArt.style(&"inset"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	box.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var l := UiTheme.label(name, 26, UiTheme.TEXT, 700)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var val := UiTheme.label("100%", 26, UiTheme.ORANGE, 700)
	head.add_child(val)
	_values[ch] = val
	var h := UiTheme.label(hint, 19, UiTheme.TEXT_DIM, 500)
	v.add_child(h)
	var s := HSlider.new()
	s.name = "Volume_" + String(ch)
	s.min_value = 0.0
	s.max_value = 100.0
	s.step = 5.0
	s.custom_minimum_size = Vector2(0, 56)
	_style_slider(s)
	s.value_changed.connect(func(x: float) -> void:
		Sfx.set_volume(ch, x / 100.0)
		_update_label(ch))
	# Ao soltar, um som de exemplo do canal (a música já está tocando).
	s.drag_ended.connect(func(_changed: bool) -> void: _preview(ch))
	v.add_child(s)
	_sliders[ch] = s
	return box


func _update_label(ch: StringName) -> void:
	var p: int = roundi(Sfx.get_volume(ch) * 100.0)
	(_values[ch] as Label).text = "MUDO" if p == 0 else "%d%%" % p


func _preview(ch: StringName) -> void:
	match ch:
		&"sfx":
			Sfx.play(&"pickup")
		&"machine":
			Sfx.play_on_bus(&"drill", &"machine")


## Trilho grosso e alça grande (fácil de arrastar com o dedo).
func _style_slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("1a1f29")
	track.border_color = Color("0b0e14")
	track.set_border_width_all(3)
	track.content_margin_top = 10
	track.content_margin_bottom = 10
	s.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.ORANGE
	fill.content_margin_top = 10
	fill.content_margin_bottom = 10
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var g := _grabber()
	s.add_theme_icon_override("grabber", g)
	s.add_theme_icon_override("grabber_highlight", g)


static var _grabber_tex: ImageTexture = null


static func _grabber() -> ImageTexture:
	if _grabber_tex == null:
		var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
		img.fill(Color("0b0e14"))
		img.fill_rect(Rect2i(4, 4, 32, 32), Color("e4e9f0"))
		img.fill_rect(Rect2i(4, 30, 32, 6), Color("9aa6b4"))
		img.fill_rect(Rect2i(17, 10, 6, 16), Color("5a6378"))
		_grabber_tex = ImageTexture.create_from_image(img)
	return _grabber_tex
