class_name SellDialog
extends Control
## Venda em quantidade (0.20): ícone do recurso, quanto tem (×N) e um slider de 1 até N.
## O botão mostra quanto vai render. Fica por cima da estação que abriu.

signal sold(value: int)

var key: StringName
var have: int = 1
var price: int = 0
var slider: HSlider
var _amount: Label
var _ok: Button


func setup(p_key: StringName) -> SellDialog:
	key = p_key
	have = maxi(1, int(GameState.economy.cargo.get(key, 0)))
	price = ResourceRegistry.get_def(key).sell_value
	return self


func _ready() -> void:
	name = "SellDialog"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			queue_free())
	add_child(dim)
	var safe := SafeMargin.new(16.0, 16.0, 16.0, 600.0)
	add_child(safe)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelArt.style(&"frame"))
	panel.custom_minimum_size = Vector2(minf(560.0, get_viewport_rect().size.x - 40.0), 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	var icon := TextureRect.new()
	icon.texture = PixelArt.ore_icon(key)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(84, 76)
	head.add_child(icon)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(names)
	names.add_child(UiTheme.label(ResourceRegistry.get_def(key).display_name, 30, UiTheme.TEXT, 700))
	names.add_child(UiTheme.label("×%d" % have, 26, UiTheme.TEXT_DIM, 700))
	_amount = UiTheme.label("", 40, UiTheme.ORANGE, 700)
	_amount.name = "SellAmount"
	_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_amount)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	row.add_child(_step_button("−", -1))
	slider = HSlider.new()
	slider.name = "SellSlider"
	slider.min_value = 1
	slider.max_value = have
	slider.step = 1
	slider.value = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 56)
	slider.editable = have > 1
	SettingsScreen._style_slider(slider)
	slider.value_changed.connect(func(_x: float) -> void: _update())
	row.add_child(SliderGrip.wrap(slider))
	row.add_child(_step_button("+", 1))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	v.add_child(buttons)
	var cancel := Button.new()
	cancel.name = "SellCancel"
	cancel.text = UiTheme.display_text("VOLTAR")
	cancel.custom_minimum_size = Vector2(0, 78)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.add_theme_font_size_override("font_size", UiTheme.font_size(22, 700))
	UiTheme.style_button(cancel, &"steel")
	cancel.pressed.connect(queue_free)
	buttons.add_child(cancel)
	_ok = Button.new()
	_ok.name = "SellConfirm"
	_ok.icon = PixelArt.icon(&"coin")
	_ok.add_theme_constant_override("icon_max_width", 30)
	_ok.custom_minimum_size = Vector2(0, 78)
	_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ok.size_flags_stretch_ratio = 1.6
	_ok.add_theme_font_size_override("font_size", UiTheme.font_size(22, 700))
	UiTheme.style_button(_ok, &"gold")
	_ok.pressed.connect(confirm)
	buttons.add_child(_ok)
	_update()
	Transitions.pop_in(panel)


func _step_button(text: String, dir: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(68, 68)
	b.add_theme_font_size_override("font_size", UiTheme.font_size(30, 700))
	UiTheme.style_button(b, &"steel")
	b.pressed.connect(func() -> void:
		Sfx.play(&"click")
		slider.value = clampf(slider.value + dir, 1, have))
	return b


func amount() -> int:
	return int(slider.value)


func _update() -> void:
	_amount.text = "%d" % amount()
	_ok.text = UiTheme.display_text("VENDER +%s" % UiTheme.short_number(amount() * price))


func confirm() -> int:
	var value: int = GameState.sell_resource(key, amount())
	sold.emit(value)
	queue_free()
	return value
