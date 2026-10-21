class_name UpgradeCard
extends PanelContainer
## Cartão de upgrade no estilo da referência: ícone em moldura laranja, nome + "Nv. X",
## barra de nível segmentada, descrição, antes → depois, preço (botão dourado) e seta verde.

signal buy_requested(id: StringName)

var def: UpgradeDef
var _level_label: Label
var _bar: SegmentedBar
var _change: Label
var _price: Button
var _arrow: Button


func _init(p_def: UpgradeDef) -> void:
	def = p_def
	name = "Card_" + String(def.id)
	add_theme_stylebox_override("panel", PixelArt.style(&"inset"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", PixelArt.style(&"icon_frame"))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_child(UiTheme.icon_rect(def.id, 54))
	row.add_child(frame)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	var title := HBoxContainer.new()
	info.add_child(title)
	var name_l := UiTheme.label(def.display_name.to_upper(), 24, UiTheme.TEXT, 700)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	title.add_child(name_l)
	_level_label = UiTheme.label("", 22, UiTheme.ORANGE, 700)
	title.add_child(_level_label)
	_bar = SegmentedBar.new(10, UiTheme.ORANGE, 21.0)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_bar)
	var desc := UiTheme.label(def.description, 18, UiTheme.TEXT_DIM, 500)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(200, 0)
	info.add_child(desc)
	_change = UiTheme.label("", 19, UiTheme.GREEN, 600)
	info.add_child(_change)

	var buy := VBoxContainer.new()
	buy.alignment = BoxContainer.ALIGNMENT_CENTER
	buy.add_theme_constant_override("separation", 8)
	row.add_child(buy)
	_price = Button.new()
	_price.name = "Price"
	_price.custom_minimum_size = Vector2(132, 58)
	_price.icon = PixelArt.icon(&"crystal" if def.currency == Economy.CRYSTALS else &"coin")
	_price.add_theme_constant_override("icon_max_width", 30)
	_price.add_theme_font_size_override("font_size", UiTheme.font_size(24, 700))
	_price.pressed.connect(func() -> void: buy_requested.emit(def.id))
	buy.add_child(_price)
	_arrow = Button.new()
	_arrow.name = "Buy"
	_arrow.custom_minimum_size = Vector2(132, 52)
	_arrow.icon = PixelArt.icon(&"arrow_up")
	_arrow.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow.add_theme_constant_override("icon_max_width", 34)
	_arrow.pressed.connect(func() -> void: buy_requested.emit(def.id))
	buy.add_child(_arrow)


func refresh(econ: Economy) -> void:
	var level: int = econ.get_level(def.id)
	_level_label.text = "Nv. %d" % level
	_bar.value = float(level) / float(def.max_level)
	var status: Progression.BuyStatus = Progression.buy_status(econ, def)
	var p: PackedStringArray = Progression.preview(def, econ.upgrade_levels)
	_change.text = "%s  →  %s" % [p[0], p[1]] if status != Progression.BuyStatus.MAXED else "%s  (máximo)" % p[0]
	match status:
		Progression.BuyStatus.LOCKED:
			_price.text = "—"
		Progression.BuyStatus.MAXED:
			_price.text = "MÁX"
		_:
			_price.text = UiTheme.short_number(Progression.cost(def, level))
	var can: bool = status == Progression.BuyStatus.OK
	UiTheme.style_button(_price, &"gold" if status != Progression.BuyStatus.MAXED else &"steel")
	UiTheme.style_button(_arrow, &"green")
	_price.disabled = not can
	_arrow.disabled = not can
	# Sem saldo: preço continua legível (dourado apagado), seta desativada.
	_price.modulate = Color.WHITE if can else Color(1, 1, 1, 0.75)
	if not can and status == Progression.BuyStatus.NO_FUNDS:
		_price.add_theme_stylebox_override("disabled", PixelArt.style(&"gold_pressed"))
		_price.add_theme_color_override("font_disabled_color", Color("3a2208"))
	else:
		_price.remove_theme_stylebox_override("disabled")
		_price.remove_theme_color_override("font_disabled_color")


## Mantido para compatibilidade (outros scripts formatam números com ele).
static func _short(n: int) -> String:
	return UiTheme.short_number(n)
