class_name UpgradeCard
extends PanelContainer
## Cartão de peça da Bancada: ícone em moldura laranja, nome + "Nv. X", barra de nível,
## descrição, antes → depois, receita (materiais: tem/precisa) ou o projeto que falta,
## preço (botão dourado) e seta verde para construir.

signal buy_requested(id: StringName)

var def: UpgradeDef
var _level_label: Label
var _bar: SegmentedBar
var _change: Label
var _price: Button
var _arrow: Button
var _mats: HFlowContainer
var _req: Label


func _init(p_def: UpgradeDef) -> void:
	def = p_def
	name = "Card_" + String(def.id)
	add_theme_stylebox_override("panel", PixelArt.style(&"inset"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", PixelArt.style(&"icon_frame"))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_child(UiTheme.icon_rect(def.id, 80))
	row.add_child(frame)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)
	var title := HBoxContainer.new()
	info.add_child(title)
	var name_l := UiTheme.label(def.display_name.to_upper(), 32, UiTheme.TEXT, 700)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	title.add_child(name_l)
	_level_label = UiTheme.label("", 28, UiTheme.ORANGE, 700)
	title.add_child(_level_label)
	_bar = SegmentedBar.new(10, UiTheme.ORANGE, 26.0)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_bar)
	var desc := UiTheme.label(def.description, 25, UiTheme.TEXT_DIM, 500)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(120, 0)
	info.add_child(desc)
	_change = UiTheme.label("", 26, UiTheme.GREEN, 600)
	_change.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_change.custom_minimum_size = Vector2(120, 0)
	info.add_child(_change)
	_mats = HFlowContainer.new()
	_mats.name = "Materials"
	_mats.add_theme_constant_override("h_separation", 12)
	_mats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(_mats)
	_req = UiTheme.label("", 24, UiTheme.ORANGE, 600)
	_req.name = "Requirement"
	_req.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_req.custom_minimum_size = Vector2(120, 0)
	info.add_child(_req)

	var buy := VBoxContainer.new()
	buy.alignment = BoxContainer.ALIGNMENT_CENTER
	buy.add_theme_constant_override("separation", 8)
	row.add_child(buy)
	_price = Button.new()
	_price.name = "Price"
	_price.custom_minimum_size = Vector2(172, 76)
	_price.icon = PixelArt.icon(&"crystal" if def.currency == Economy.CRYSTALS else &"coin")
	_price.add_theme_constant_override("icon_max_width", 38)
	_price.add_theme_font_size_override("font_size", UiTheme.font_size(30, 700))
	_price.pressed.connect(func() -> void: buy_requested.emit(def.id))
	buy.add_child(_price)
	_arrow = Button.new()
	_arrow.name = "Buy"
	_arrow.custom_minimum_size = Vector2(172, 66)
	_arrow.icon = PixelArt.icon(&"arrow_up")
	_arrow.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow.add_theme_constant_override("icon_max_width", 42)
	_arrow.pressed.connect(func() -> void: buy_requested.emit(def.id))
	buy.add_child(_arrow)


func refresh(econ: Economy) -> void:
	var level: int = econ.get_level(def.id)
	_level_label.text = "Nv. %d" % level
	_bar.value = float(level) / float(def.max_level)
	var status: Progression.BuyStatus = Progression.buy_status(econ, def)
	var p: PackedStringArray = Progression.preview(def, econ.upgrade_levels)
	_change.text = "%s  →  %s" % [p[0], p[1]] if status != Progression.BuyStatus.MAXED else "%s  (máximo)" % p[0]
	_refresh_recipe(econ, status, level)
	match status:
		Progression.BuyStatus.LOCKED, Progression.BuyStatus.RESEARCH:
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
	if not can and (status == Progression.BuyStatus.NO_FUNDS or status == Progression.BuyStatus.NO_MATERIALS):
		_price.add_theme_stylebox_override("disabled", PixelArt.style(&"gold_pressed"))
		_price.add_theme_color_override("font_disabled_color", Color("3a2208"))
	else:
		_price.remove_theme_stylebox_override("disabled")
		_price.remove_theme_color_override("font_disabled_color")


## Receita do próximo nível: cada material com tem/precisa (verde/vermelho); projeto
## bloqueado mostra o que falta (descobrir material ou vencer um guardião).
func _refresh_recipe(econ: Economy, status: Progression.BuyStatus, level: int) -> void:
	for c in _mats.get_children():
		c.queue_free()
	var maxed: bool = status == Progression.BuyStatus.MAXED
	var req: String = "" if maxed else Recipes.requirement(def, level, econ.discovered, econ.tech)
	_req.visible = req != ""
	_req.text = "PROJETO BLOQUEADO · " + req if req != "" else ""
	_mats.visible = not maxed and req == ""
	if not _mats.visible:
		return
	var mats: Dictionary = Progression.materials(def, level)
	for k: StringName in mats:
		var have: int = int(econ.cargo.get(k, 0))
		var need: int = int(mats[k])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.texture = PixelArt.ore_icon(k)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(36, 32)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		row.add_child(UiTheme.label("%d/%d" % [have, need], 25, UiTheme.GREEN if have >= need else UiTheme.RED, 700))
		_mats.add_child(row)


## Mantido para compatibilidade (outros scripts formatam números com ele).
static func _short(n: int) -> String:
	return UiTheme.short_number(n)
