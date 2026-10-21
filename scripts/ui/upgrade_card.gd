class_name UpgradeCard
extends PanelContainer
## Cartão de um upgrade: nome, nível, descrição, antes → depois e botão de compra.

signal buy_requested(id: StringName)

var def: UpgradeDef
var _name_label: Label
var _level_label: Label
var _desc_label: Label
var _before_label: Label
var _after_label: Label
var _buy: Button
var _icon: GemIcon


func _init(p_def: UpgradeDef) -> void:
	def = p_def
	name = "Card_" + String(def.id)
	add_theme_stylebox_override("panel", UiTheme.panel_box(Color("261f2d"), def.color.darkened(0.45), 16, 3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)

	var stripe := ColorRect.new()
	stripe.color = def.color
	stripe.custom_minimum_size = Vector2(8, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stripe)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 10)
	info.add_child(title)
	_name_label = _label(def.display_name, UiTheme.FONT_NORMAL, UiTheme.TEXT)
	title.add_child(_name_label)
	_level_label = _label("", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	_level_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(_level_label)
	_desc_label = _label(def.description, 20, UiTheme.TEXT_DIM)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(300, 0)
	info.add_child(_desc_label)
	var change := HBoxContainer.new()
	change.add_theme_constant_override("separation", 8)
	info.add_child(change)
	_before_label = _label("", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	change.add_child(_before_label)
	change.add_child(_label("→", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM))
	_after_label = _label("", UiTheme.FONT_SMALL, Color("8dff8a"))
	change.add_child(_after_label)

	var buy_box := VBoxContainer.new()
	buy_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(buy_box)
	_buy = Button.new()
	_buy.custom_minimum_size = Vector2(170, 76)
	_buy.focus_mode = Control.FOCUS_NONE
	_buy.add_theme_font_size_override("font_size", UiTheme.FONT_NORMAL)
	_buy.pressed.connect(func() -> void: buy_requested.emit(def.id))
	buy_box.add_child(_buy)
	_icon = GemIcon.new(UiTheme.CRYSTALS if def.currency == Economy.CRYSTALS else UiTheme.CREDITS)
	_icon.custom_minimum_size = Vector2(24, 24)
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy_box.add_child(_icon)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func refresh(econ: Economy) -> void:
	var level: int = econ.get_level(def.id)
	_level_label.text = "Nv %d/%d" % [level, def.max_level]
	var status: Progression.BuyStatus = Progression.buy_status(econ, def)
	var maxed: bool = status == Progression.BuyStatus.MAXED
	if maxed:
		var now: PackedStringArray = Progression.preview(def, econ.upgrade_levels)
		_before_label.text = now[0]
		_after_label.text = "máximo"
	else:
		var p: PackedStringArray = Progression.preview(def, econ.upgrade_levels)
		_before_label.text = p[0]
		_after_label.text = p[1]
	match status:
		Progression.BuyStatus.LOCKED:
			_buy.text = "Em breve"
			_buy.disabled = true
			_icon.visible = false
			modulate = Color(1, 1, 1, 0.6)
		Progression.BuyStatus.MAXED:
			_buy.text = "MÁX"
			_buy.disabled = true
			_icon.visible = false
			modulate = Color.WHITE
		_:
			_buy.text = _short(Progression.cost(def, level))
			_buy.disabled = status != Progression.BuyStatus.OK
			_icon.visible = true
			modulate = Color.WHITE
	if status == Progression.BuyStatus.OK:
		UiTheme.accent_button(_buy, UiTheme.CRYSTALS if def.currency == Economy.CRYSTALS else UiTheme.ACCENT)
	else:
		for s: String in ["normal", "hover", "pressed", "hover_pressed"]:
			_buy.remove_theme_stylebox_override(s)
		for c: String in ["font_color", "font_hover_color", "font_pressed_color"]:
			_buy.remove_theme_color_override(c)


## 1234 → "1.234", 1500000 → "1,5 mi".
static func _short(n: int) -> String:
	if n >= 1000000:
		return "%.1f mi" % (n / 1000000.0)
	var s: String = str(n)
	var out: String = ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
