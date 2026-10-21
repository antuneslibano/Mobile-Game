class_name Garage
extends CanvasLayer
## Garagem: vender a carga e comprar upgrades. Pausa o jogo enquanto aberta.
## Só chama GameState (regras) e lê Progression (textos); não calcula economia.

signal closed

var _root: Control
var _credits: Label
var _crystals: Label
var _cargo_list: GridContainer
var _cargo_empty: Label
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
		_show_toast("+%s Créditos" % UpgradeCard._short(value), UiTheme.CREDITS)
	return value


func buy(id: StringName) -> bool:
	var ok: bool = GameState.buy_upgrade(id)
	if ok:
		var def: UpgradeDef = UpgradeRegistry.get_def(id)
		_show_toast("%s → Nv %d" % [def.display_name, GameState.economy.get_level(id)], Color("8dff8a"))
	_refresh()
	return ok


# --- Construção ----------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.04, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.add_theme_constant_override("margin_top", 18 + int(_safe_top()))
	margin.add_theme_constant_override("margin_bottom", 18)
	_root.add_child(margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(UiTheme.PANEL, UiTheme.ACCENT.darkened(0.3), 22, 4))
	margin.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	# Cabeçalho.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	v.add_child(header)
	var title := _label("GARAGEM", 40, UiTheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_b := Button.new()
	close_b.name = "CloseButton"
	close_b.text = "FECHAR"
	close_b.focus_mode = Control.FOCUS_NONE
	close_b.custom_minimum_size = Vector2(150, 64)
	close_b.pressed.connect(close)
	header.add_child(close_b)

	var wallet := HBoxContainer.new()
	wallet.add_theme_constant_override("separation", 10)
	v.add_child(wallet)
	wallet.add_child(GemIcon.new(UiTheme.CREDITS))
	_credits = _label("0", UiTheme.FONT_NORMAL, UiTheme.CREDITS)
	_credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wallet.add_child(_credits)
	wallet.add_child(GemIcon.new(UiTheme.CRYSTALS))
	_crystals = _label("0", UiTheme.FONT_NORMAL, UiTheme.CRYSTALS)
	wallet.add_child(_crystals)

	# Carga.
	var cargo_panel := PanelContainer.new()
	cargo_panel.add_theme_stylebox_override("panel", UiTheme.panel_box(Color("1a1520"), UiTheme.PANEL_EDGE, 16, 2))
	v.add_child(cargo_panel)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	cargo_panel.add_child(cv)
	cv.add_child(_label("CARGA", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM))
	_cargo_list = GridContainer.new()
	_cargo_list.columns = 2
	_cargo_list.add_theme_constant_override("h_separation", 24)
	cv.add_child(_cargo_list)
	_cargo_empty = _label("Vazia — mine blocos para coletar minério.", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	cv.add_child(_cargo_empty)
	_sell = Button.new()
	_sell.name = "SellButton"
	_sell.focus_mode = Control.FOCUS_NONE
	_sell.custom_minimum_size = Vector2(0, 76)
	_sell.pressed.connect(func() -> void: sell_all())
	cv.add_child(_sell)

	# Abas.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	v.add_child(tabs)
	_tab_upgrades = _tab_button("UPGRADES", true)
	_tab_modules = _tab_button("MÓDULOS", false)
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
	_upgrades_page.add_theme_constant_override("separation", 10)
	_upgrades_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(_upgrades_page)
	for def in UpgradeRegistry.all():
		var card := UpgradeCard.new(def)
		card.buy_requested.connect(func(id: StringName) -> void: buy(id))
		_upgrades_page.add_child(card)
		_cards.append(card)

	_modules_page = VBoxContainer.new()
	_modules_page.add_theme_constant_override("separation", 10)
	pages.add_child(_modules_page)
	_slots_label = _label("", UiTheme.FONT_NORMAL, UiTheme.ACCENT)
	_modules_page.add_child(_slots_label)
	for id in ModuleSystem.ALL:
		_modules_page.add_child(_module_card(id))
	var syn_panel := PanelContainer.new()
	syn_panel.add_theme_stylebox_override("panel", UiTheme.panel_box(Color("201a2a"), Color("c57bff").darkened(0.4), 16, 3))
	_modules_page.add_child(syn_panel)
	_synergy_label = _label("", UiTheme.FONT_SMALL, UiTheme.TEXT)
	_synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_synergy_label.custom_minimum_size = Vector2(400, 0)
	syn_panel.add_child(_synergy_label)

	_toast = _label("", UiTheme.FONT_NORMAL, UiTheme.TEXT)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.position = Vector2(0, -150)
	_toast.modulate.a = 0.0
	_root.add_child(_toast)


func _module_card(id: StringName) -> PanelContainer:
	var def: UpgradeDef = UpgradeRegistry.get_def(id)
	var card := PanelContainer.new()
	card.name = "Module_" + String(id)
	card.add_theme_stylebox_override("panel", UiTheme.panel_box(Color("261f2d"), def.color.darkened(0.45), 16, 3))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(_label(def.display_name, UiTheme.FONT_NORMAL, UiTheme.TEXT))
	var desc := _label(def.description, 20, UiTheme.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(280, 0)
	info.add_child(desc)
	var status := _label("", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	info.add_child(status)
	_module_status[id] = status
	var b := Button.new()
	b.name = "Toggle"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(170, 76)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: toggle_module(id))
	row.add_child(b)
	_module_buttons[id] = b
	return card


func toggle_module(id: StringName) -> bool:
	var ok: bool = GameState.toggle_module(id)
	if not ok:
		var reason: String = "Compre o módulo na aba Upgrades" if not GameState.economy.owns_module(id) else "Todos os slots estão ocupados"
		_show_toast(reason, Color("ff8a8a"))
	_refresh()
	return ok


func _refresh_modules(econ: Economy) -> void:
	_slots_label.text = "SLOTS  %d / %d" % [econ.equipped_modules.size(), Balance.MODULE_SLOTS]
	for id in ModuleSystem.ALL:
		var b: Button = _module_buttons[id]
		var st: Label = _module_status[id]
		var lvl: int = econ.get_level(id)
		var on: bool = econ.equipped_modules.has(id)
		if lvl == 0:
			st.text = "Não adquirido"
			b.text = "—"
			b.disabled = true
		else:
			st.text = "Nível %d · %s" % [lvl, "EQUIPADO" if on else "na garagem"]
			b.text = "REMOVER" if on else "EQUIPAR"
			b.disabled = not on and econ.equipped_modules.size() >= Balance.MODULE_SLOTS
		st.add_theme_color_override("font_color", Color("8dff8a") if on else UiTheme.TEXT_DIM)
		if on:
			UiTheme.accent_button(b, Color("c57bff"))
		else:
			for sname: String in ["normal", "hover", "pressed", "hover_pressed"]:
				b.remove_theme_stylebox_override(sname)
			for cname: String in ["font_color", "font_hover_color", "font_pressed_color"]:
				b.remove_theme_color_override(cname)
	var lines: PackedStringArray = []
	for d in SynergyRules.DEFS:
		var active: bool = SynergyRules.is_active(d["id"], econ.equipped_modules, GameState.stats)
		lines.append("SINERGIA · %s %s\n%s" % [d["name"], "(ATIVA)" if active else "(inativa — equipe o Pulso sísmico)", d["description"]])
	_synergy_label.text = "\n\n".join(lines)


func show_modules_tab() -> void:
	_show_tab(false)


func _tab_button(text: String, active: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = active
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void: _show_tab(b == _tab_upgrades))
	return b


func _show_tab(upgrades: bool) -> void:
	_tab_upgrades.button_pressed = upgrades
	_tab_modules.button_pressed = not upgrades
	_upgrades_page.visible = upgrades
	_modules_page.visible = not upgrades
	_scroll.scroll_vertical = 0


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _refresh() -> void:
	if not visible:
		return
	var econ: Economy = GameState.economy
	_credits.text = UpgradeCard._short(econ.credits)
	_crystals.text = UpgradeCard._short(econ.crystals)
	for child in _cargo_list.get_children():
		child.queue_free()
	var any: bool = false
	for key in ResourceRegistry.order():
		var n: int = int(econ.cargo.get(key, 0))
		if n <= 0:
			continue
		any = true
		var def: ResourceDef = ResourceRegistry.get_def(key)
		_cargo_list.add_child(_label("%s ×%d" % [def.display_name, n], UiTheme.FONT_SMALL, def.color.lightened(0.2)))
		_cargo_list.add_child(_label("%s" % UpgradeCard._short(def.sell_value * n), UiTheme.FONT_SMALL, UiTheme.CREDITS))
	_cargo_empty.visible = not any
	var value: int = econ.cargo_value()
	_sell.text = "VENDER TUDO   +%s" % UpgradeCard._short(value) if any else "NADA PARA VENDER"
	_sell.disabled = not any
	if any:
		UiTheme.accent_button(_sell, UiTheme.CREDITS)
	for card in _cards:
		card.refresh(econ)
	_refresh_modules(econ)


func _show_toast(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.size = Vector2(_root.get_viewport_rect().size.x, 50)
	_toast.position = Vector2(0, _root.get_viewport_rect().size.y - 140)
	_toast_t = 1.6


func _safe_top() -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	if win.y <= 0.0:
		return 0.0
	return float(DisplayServer.get_display_safe_area().position.y) * (_root.get_viewport_rect().size.y / win.y) if _root != null else 0.0
