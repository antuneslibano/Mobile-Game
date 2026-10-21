class_name Garage
extends CanvasLayer
## Garagem no estilo da referência visual: placa de título laranja, moedas em caixas, botão
## vermelho de fechar, vitrine da nave com barras de atributos, carga/venda, abas
## Upgrades/Módulos e cartões em pixel art. Pausa o jogo enquanto aberta.
## Só chama GameState (regras) e lê Progression (textos); não calcula economia.

signal closed

## Referências para as barras de atributos (valor no nível máximo de cada upgrade).
const STAT_MAX_DAMAGE: float = 104.0
const STAT_MAX_HITS: float = 17.0
const STAT_MAX_COLLECT: float = 1.5

var _root: Control
var _title: Label
var _credits: Label
var _crystals: Label
var _stat_bars: Dictionary = {}          ## StringName → SegmentedBar
var _cargo_label: Label
var _sell: Button
var _tab_upgrades: Button
var _tab_modules: Button
var _upgrades_page: VBoxContainer
var _modules_page: VBoxContainer
var _scroll: ScrollContainer
var _toast: Label
var _toast_t: float = 0.0
var _cards: Array[UpgradeCard] = []
var _slots_label: Label
var _module_buttons: Dictionary = {}     ## StringName → Button
var _module_status: Dictionary = {}      ## StringName → Label
var _module_bars: Dictionary = {}        ## StringName → SegmentedBar
var _synergy_label: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	EventBus.wallet_changed.connect(func(_c: int, _k: int) -> void: _refresh())
	EventBus.cargo_changed.connect(func(_n: int, _v: int) -> void: _refresh())
	EventBus.modules_changed.connect(func(_e: Array[StringName]) -> void: _refresh())


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	get_tree().paused = true
	_show_tab(true)
	_refresh()
	EventBus.garage_opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	EventBus.garage_closed.emit()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Botão "voltar" do Android fecha a garagem.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible:
		close()


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.4, 0.0, 1.0)


# --- Ações ------------------------------------------------------------------------

func sell_all() -> int:
	var value: int = GameState.sell_cargo()
	if value > 0:
		_show_toast("+%s Créditos" % UiTheme.short_number(value), UiTheme.CREDITS)
	return value


func buy(id: StringName) -> bool:
	var ok: bool = GameState.buy_upgrade(id)
	if ok:
		var def: UpgradeDef = UpgradeRegistry.get_def(id)
		_show_toast("%s → Nv. %d" % [def.display_name, GameState.economy.get_level(id)], UiTheme.GREEN)
	_refresh()
	return ok


func toggle_module(id: StringName) -> bool:
	var ok: bool = GameState.toggle_module(id)
	if not ok:
		var reason: String = "Compre o módulo na aba Upgrades" if not GameState.economy.owns_module(id) else "Todos os slots estão ocupados"
		_show_toast(reason, UiTheme.RED)
	_refresh()
	return ok


func show_modules_tab() -> void:
	_show_tab(false)


# --- Construção ----------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	margin.add_theme_constant_override("margin_top", 10 + int(_safe_top()))
	margin.add_theme_constant_override("margin_bottom", 10)
	_root.add_child(margin)

	var window := PanelContainer.new()
	window.add_theme_stylebox_override("panel", PixelArt.style(&"frame"))
	margin.add_child(window)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	window.add_child(v)

	# Cabeçalho: placa laranja + moedas + fechar.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	v.add_child(header)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", PixelArt.style(&"plate"))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(plate)
	_title = UiTheme.label("UPGRADES", 40, Color("2a1606"), 700)
	_title.add_theme_constant_override("outline_size", 0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(_title)
	var cbox: Array = UiTheme.currency_box(Economy.CREDITS)
	(cbox[0] as Control).custom_minimum_size = Vector2(170, 0)
	header.add_child(cbox[0])
	_credits = cbox[1]
	var kbox: Array = UiTheme.currency_box(Economy.CRYSTALS)
	(kbox[0] as Control).custom_minimum_size = Vector2(110, 0)
	header.add_child(kbox[0])
	_crystals = kbox[1]
	var close_b := Button.new()
	close_b.name = "CloseButton"
	close_b.icon = PixelArt.icon(&"close")
	close_b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_b.add_theme_constant_override("icon_max_width", 34)
	close_b.custom_minimum_size = Vector2(72, 72)
	UiTheme.style_button(close_b, &"red")
	close_b.pressed.connect(close)
	header.add_child(close_b)

	# Vitrine da nave + atributos.
	var showcase := HBoxContainer.new()
	showcase.add_theme_constant_override("separation", 10)
	v.add_child(showcase)
	var preview := ShipPreview.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	showcase.add_child(preview)
	var stats := PanelContainer.new()
	stats.add_theme_stylebox_override("panel", PixelArt.style(&"inset"))
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	showcase.add_child(stats)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_child(sv)
	for entry: Array in [[&"energy", "ENERGIA", UiTheme.BLUE], [&"speed", "VELOCIDADE", UiTheme.ORANGE], [&"power", "PODER DE MINERAÇÃO", Color("f04a3a")], [&"collect", "COLETA", Color("3fc45a")]]:
		sv.add_child(UiTheme.label(entry[1], 19, UiTheme.TEXT_DIM, 600))
		var bar := SegmentedBar.new(6, entry[2], 22.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sv.add_child(bar)
		_stat_bars[entry[0]] = bar

	# Carga e venda.
	var cargo := PanelContainer.new()
	cargo.add_theme_stylebox_override("panel", PixelArt.style(&"inset"))
	v.add_child(cargo)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 10)
	cargo.add_child(ch)
	var cv := VBoxContainer.new()
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch.add_child(cv)
	cv.add_child(UiTheme.label("CARGA", 20, UiTheme.ORANGE, 700))
	_cargo_label = UiTheme.label("", 19, UiTheme.TEXT_DIM, 500)
	_cargo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cargo_label.custom_minimum_size = Vector2(200, 0)
	cv.add_child(_cargo_label)
	_sell = Button.new()
	_sell.name = "SellButton"
	_sell.custom_minimum_size = Vector2(230, 70)
	_sell.icon = PixelArt.icon(&"coin")
	_sell.add_theme_constant_override("icon_max_width", 30)
	_sell.add_theme_font_size_override("font_size", UiTheme.font_size(24, 700))
	_sell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sell.pressed.connect(func() -> void: sell_all())
	ch.add_child(_sell)

	# Abas.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	v.add_child(tabs)
	_tab_upgrades = _tab_button("UPGRADES")
	_tab_modules = _tab_button("MÓDULOS")
	tabs.add_child(_tab_upgrades)
	tabs.add_child(_tab_modules)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(pages)

	_upgrades_page = VBoxContainer.new()
	_upgrades_page.add_theme_constant_override("separation", 8)
	_upgrades_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(_upgrades_page)
	for def in UpgradeRegistry.all():
		if def.id in ModuleSystem.ALL:
			continue
		_add_card(def)
	_upgrades_page.add_child(UiTheme.label("MÓDULOS", 24, UiTheme.ORANGE, 700))
	for id in ModuleSystem.ALL:
		_add_card(UpgradeRegistry.get_def(id))

	_modules_page = VBoxContainer.new()
	_modules_page.add_theme_constant_override("separation", 8)
	_modules_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(_modules_page)
	_slots_label = UiTheme.label("", 26, UiTheme.ORANGE, 700)
	_modules_page.add_child(_slots_label)
	for id in ModuleSystem.ALL:
		_modules_page.add_child(_module_card(id))
	var syn := PanelContainer.new()
	syn.add_theme_stylebox_override("panel", PixelArt.style(&"inset"))
	_modules_page.add_child(syn)
	_synergy_label = UiTheme.label("", 19, UiTheme.TEXT, 500)
	_synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_synergy_label.custom_minimum_size = Vector2(400, 0)
	syn.add_child(_synergy_label)

	_toast = UiTheme.label("", UiTheme.FONT_NORMAL, UiTheme.TEXT, 700)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_root.add_child(_toast)


func _add_card(def: UpgradeDef) -> void:
	var card := UpgradeCard.new(def)
	card.buy_requested.connect(func(id: StringName) -> void: buy(id))
	_upgrades_page.add_child(card)
	_cards.append(card)


func _module_card(id: StringName) -> PanelContainer:
	var def: UpgradeDef = UpgradeRegistry.get_def(id)
	var card := PanelContainer.new()
	card.name = "Module_" + String(id)
	card.add_theme_stylebox_override("panel", PixelArt.style(&"inset"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", PixelArt.style(&"icon_frame"))
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_child(UiTheme.icon_rect(id, 54))
	row.add_child(frame)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	info.add_child(UiTheme.label(def.display_name.to_upper(), 24, UiTheme.TEXT, 700))
	var bar := SegmentedBar.new(10, UiTheme.ORANGE, 21.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(bar)
	_module_bars[id] = bar
	var status := UiTheme.label("", 19, UiTheme.TEXT_DIM, 600)
	info.add_child(status)
	_module_status[id] = status
	var b := Button.new()
	b.name = "Toggle"
	b.custom_minimum_size = Vector2(170, 70)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", UiTheme.font_size(22, 700))
	b.pressed.connect(func() -> void: toggle_module(id))
	row.add_child(b)
	_module_buttons[id] = b
	return card


func _tab_button(text: String) -> Button:
	var b := Button.new()
	b.text = UiTheme.display_text(text)
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void: _show_tab(b == _tab_upgrades))
	return b


func _show_tab(upgrades: bool) -> void:
	_title.text = UiTheme.display_text("UPGRADES" if upgrades else "MÓDULOS")
	UiTheme.style_button(_tab_upgrades, &"gold" if upgrades else &"steel")
	UiTheme.style_button(_tab_modules, &"steel" if upgrades else &"gold")
	_upgrades_page.visible = upgrades
	_modules_page.visible = not upgrades
	_scroll.scroll_vertical = 0


# --- Atualização ----------------------------------------------------------------------

func _refresh() -> void:
	if not visible:
		return
	var econ: Economy = GameState.economy
	_credits.text = UiTheme.short_number(econ.credits)
	_crystals.text = UiTheme.short_number(econ.crystals)
	var s: DrillStats = GameState.stats
	(_stat_bars[&"energy"] as SegmentedBar).value = (s.energy_gain - 1.0) / (Balance.ENERGY_GAIN_PER_LEVEL * 20.0) * 0.83 + 0.17
	(_stat_bars[&"speed"] as SegmentedBar).value = s.hits_per_second / STAT_MAX_HITS
	(_stat_bars[&"power"] as SegmentedBar).value = s.damage / STAT_MAX_DAMAGE * 0.83 + 0.17
	(_stat_bars[&"collect"] as SegmentedBar).value = (s.collect_mult - 1.0) / STAT_MAX_COLLECT * 0.83 + 0.17

	var parts: PackedStringArray = []
	for key in ResourceRegistry.order():
		var n: int = int(econ.cargo.get(key, 0))
		if n > 0:
			parts.append("%s ×%d" % [ResourceRegistry.get_def(key).display_name, n])
	var any: bool = not parts.is_empty()
	_cargo_label.text = " · ".join(parts) if any else "Vazia — cave para coletar minério."
	_sell.text = "VENDER +%s" % UiTheme.short_number(econ.cargo_value()) if any else "VENDER"
	_sell.disabled = not any
	UiTheme.style_button(_sell, &"gold")
	for card in _cards:
		card.refresh(econ)
	_refresh_modules(econ)


func _refresh_modules(econ: Economy) -> void:
	_slots_label.text = "SLOTS  %d / %d" % [econ.equipped_modules.size(), Balance.MODULE_SLOTS]
	for id in ModuleSystem.ALL:
		var b: Button = _module_buttons[id]
		var st: Label = _module_status[id]
		var lvl: int = econ.get_level(id)
		var on: bool = econ.equipped_modules.has(id)
		(_module_bars[id] as SegmentedBar).value = float(lvl) / float(UpgradeRegistry.get_def(id).max_level)
		if lvl == 0:
			st.text = "Não adquirido (compre em Upgrades)"
			b.text = "—"
			b.disabled = true
		else:
			st.text = "Nv. %d · %s" % [lvl, "EQUIPADO" if on else "na garagem"]
			b.text = "REMOVER" if on else "EQUIPAR"
			b.disabled = not on and econ.equipped_modules.size() >= Balance.MODULE_SLOTS
		st.add_theme_color_override("font_color", UiTheme.GREEN if on else UiTheme.TEXT_DIM)
		UiTheme.style_button(b, &"red" if on else &"green")
	var lines: PackedStringArray = []
	for d in SynergyRules.DEFS:
		var active: bool = SynergyRules.is_active(d["id"], econ.equipped_modules, GameState.stats)
		lines.append("SINERGIA · %s %s\n%s" % [d["name"], "(ATIVA)" if active else "(inativa — equipe o Pulso sísmico)", d["description"]])
	_synergy_label.text = "\n\n".join(lines)


func _show_toast(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	var vp: Vector2 = _root.get_viewport_rect().size
	_toast.size = Vector2(vp.x, 50)
	_toast.position = Vector2(0, vp.y - 120)
	_toast_t = 1.6


func _safe_top() -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	if win.y <= 0.0:
		return 0.0
	return float(DisplayServer.get_display_safe_area().position.y) * (_root.get_viewport_rect().size.y / win.y) if _root != null else 0.0
