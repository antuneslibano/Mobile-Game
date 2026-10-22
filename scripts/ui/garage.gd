class_name Garage
extends CanvasLayer
## Painel das estações da base (0.10), no estilo da referência visual: placa de título
## laranja, moedas, botão vermelho de fechar e corpo rolável. Cada estação mostra uma página:
##   &"bench"  Bancada      – construir peças (cartões com receita: materiais + moeda);
##   &"hangar" Hangar       – vitrine da nave, atributos e módulos (equipar/remover);
##   &"market" Mercado      – armazém: vender por recurso, só o excedente ou tudo;
##   &"lab"    Laboratório  – catálogo de minerais descobertos e diário de pesquisa.
## Pausa o jogo enquanto aberto. Só chama GameState (regras) e lê Progression/Recipes.

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
var _scroll: TouchScroll
var _toast: Label
var _toast_t: float = 0.0
var _cards: Array[UpgradeCard] = []
var _slots_label: Label
var _module_buttons: Dictionary = {}     ## StringName → Button
var _module_status: Dictionary = {}      ## StringName → Label
var _module_bars: Dictionary = {}        ## StringName → SegmentedBar
var _synergy_label: Label
var _kind: StringName = &"bench"
var _showcase: Control
var _tabs: Control
var _market_page: VBoxContainer
var _market_rows: VBoxContainer
var _surplus: Button
var _lab_page: VBoxContainer
var _lab_box: VBoxContainer
const TITLES: Dictionary = {&"bench": "BANCADA", &"hangar": "HANGAR", &"market": "MERCADO", &"lab": "LABORATÓRIO"}
## Minerais do catálogo (sem os materiais antigos de entulho).
const CATALOG_SKIP: Array[StringName] = [&"dirt", &"stone", &"basalt", &"abyss_stone"]


func _ready() -> void:
	layer = 27  # acima do mapa (a garagem abre a partir da base)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	EventBus.wallet_changed.connect(func(_c: int, _k: int) -> void: _refresh())
	EventBus.cargo_changed.connect(func(_n: int, _v: int) -> void: _refresh())
	EventBus.modules_changed.connect(func(_e: Array[StringName]) -> void: _refresh())


var _was_paused: bool = false


func is_open() -> bool:
	return visible


## Abre na Bancada (compatibilidade).
func open() -> void:
	open_station(&"bench")


func open_station(kind: StringName) -> void:
	_kind = kind if TITLES.has(kind) else &"bench"
	if not visible:
		visible = true
		_was_paused = get_tree().paused
		get_tree().paused = true
		EventBus.garage_opened.emit()
	_show_page()
	_refresh()
	if _kind == &"lab":
		GameState.journal_seen = Journal.unlocked(GameState.economy.discovered, GameState.done).size()


func station() -> StringName:
	return _kind


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused
	EventBus.garage_closed.emit()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.4, 0.0, 1.0)


# --- Ações ------------------------------------------------------------------------

func sell_surplus() -> int:
	var value: int = GameState.sell_surplus()
	if value > 0:
		_show_toast("+%s Créditos" % UiTheme.short_number(value), UiTheme.CREDITS)
	return value


func sell_one(key: StringName) -> int:
	var value: int = GameState.sell_resource(key)
	if value > 0:
		_show_toast("+%s Créditos" % UiTheme.short_number(value), UiTheme.CREDITS)
	return value


func sell_all() -> int:
	var value: int = GameState.sell_cargo()
	if value > 0:
		_show_toast("+%s Créditos" % UiTheme.short_number(value), UiTheme.CREDITS)
	return value


func buy(id: StringName) -> bool:
	var ok: bool = GameState.buy_upgrade(id)
	if ok:
		var def: UpgradeDef = UpgradeRegistry.get_def(id)
		_show_toast("Construído: %s Nv. %d" % [def.display_name, GameState.economy.get_level(id)], UiTheme.GREEN)
	_refresh()
	return ok


func toggle_module(id: StringName) -> bool:
	var ok: bool = GameState.toggle_module(id)
	if not ok:
		var reason: String = "Construa o módulo na Bancada" if not GameState.economy.owns_module(id) else "Todos os slots estão ocupados"
		_show_toast(reason, UiTheme.RED)
	_refresh()
	return ok


func show_modules_tab() -> void:
	open_station(&"hangar")


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
		margin.add_theme_constant_override("margin_" + side, 4)
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

	# Corpo rolável (arraste em qualquer ponto): vitrine, carga, abas e cartões.
	_scroll = TouchScroll.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	_scroll.add_child(body)

	# Vitrine da nave + atributos.
	var showcase := HBoxContainer.new()
	showcase.add_theme_constant_override("separation", 10)
	body.add_child(showcase)
	_showcase = showcase
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
		sv.add_child(UiTheme.label(entry[1], 25, UiTheme.TEXT_DIM, 600))
		var bar := SegmentedBar.new(6, entry[2], 26.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sv.add_child(bar)
		_stat_bars[entry[0]] = bar

	# Abas.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	tabs.visible = false
	body.add_child(tabs)
	_tabs = tabs
	_tab_upgrades = _tab_button("UPGRADES")
	_tab_modules = _tab_button("MÓDULOS")
	tabs.add_child(_tab_upgrades)
	tabs.add_child(_tab_modules)

	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(pages)

	_upgrades_page = VBoxContainer.new()
	_upgrades_page.add_theme_constant_override("separation", 12)
	_upgrades_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(_upgrades_page)
	for def in UpgradeRegistry.all():
		if def.id in ModuleSystem.ALL:
			continue
		_add_card(def)
	_upgrades_page.add_child(UiTheme.label("MÓDULOS", 32, UiTheme.ORANGE, 700))
	for id in ModuleSystem.ALL:
		_add_card(UpgradeRegistry.get_def(id))

	_modules_page = VBoxContainer.new()
	_modules_page.add_theme_constant_override("separation", 12)
	_modules_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(_modules_page)
	_slots_label = UiTheme.label("", 32, UiTheme.ORANGE, 700)
	_modules_page.add_child(_slots_label)
	for id in ModuleSystem.ALL:
		_modules_page.add_child(_module_card(id))
	var syn := PanelContainer.new()
	syn.add_theme_stylebox_override("panel", PixelArt.style(&"inset"))
	_modules_page.add_child(syn)
	_synergy_label = UiTheme.label("", 25, UiTheme.TEXT, 500)
	_synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_synergy_label.custom_minimum_size = Vector2(400, 0)
	syn.add_child(_synergy_label)

	# Mercado: armazém, vender excedente/tudo e por recurso.
	_market_page = VBoxContainer.new()
	_market_page.add_theme_constant_override("separation", 12)
	_market_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(_market_page)
	var mhint := UiTheme.label("A Bancada reserva o que precisa para o próximo nível de cada peça. Venda o excedente para ganhar Créditos.", 24, UiTheme.TEXT_DIM, 500)
	mhint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mhint.custom_minimum_size = Vector2(300, 0)
	_market_page.add_child(mhint)
	var mb := HBoxContainer.new()
	mb.add_theme_constant_override("separation", 10)
	_market_page.add_child(mb)
	_surplus = _big_button("SellSurplusButton", &"green")
	_surplus.pressed.connect(func() -> void: sell_surplus())
	mb.add_child(_surplus)
	_sell = _big_button("SellButton", &"gold")
	_sell.pressed.connect(func() -> void: sell_all())
	mb.add_child(_sell)
	_market_page.add_child(UiTheme.label("ARMAZÉM", 30, UiTheme.ORANGE, 700))
	_market_rows = VBoxContainer.new()
	_market_rows.add_theme_constant_override("separation", 8)
	_market_page.add_child(_market_rows)

	# Laboratório: catálogo e diário.
	_lab_page = VBoxContainer.new()
	_lab_page.add_theme_constant_override("separation", 12)
	_lab_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(_lab_page)
	_lab_box = VBoxContainer.new()
	_lab_box.add_theme_constant_override("separation", 12)
	_lab_page.add_child(_lab_box)

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
	frame.add_child(UiTheme.icon_rect(id, 80))
	row.add_child(frame)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	var mname := UiTheme.label(def.display_name.to_upper(), 32, UiTheme.TEXT, 700)
	mname.clip_text = true
	mname.custom_minimum_size = Vector2(120, 0)
	info.add_child(mname)
	var bar := SegmentedBar.new(10, UiTheme.ORANGE, 26.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(bar)
	_module_bars[id] = bar
	var status := UiTheme.label("", 25, UiTheme.TEXT_DIM, 600)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(120, 0)
	info.add_child(status)
	_module_status[id] = status
	var b := Button.new()
	b.name = "Toggle"
	b.custom_minimum_size = Vector2(196, 86)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", UiTheme.font_size(28, 700))
	b.pressed.connect(func() -> void: toggle_module(id))
	row.add_child(b)
	_module_buttons[id] = b
	return card


func _big_button(node_name: String, style: StringName) -> Button:
	var b := Button.new()
	b.name = node_name
	b.custom_minimum_size = Vector2(0, 86)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.icon = PixelArt.icon(&"coin")
	b.add_theme_constant_override("icon_max_width", 34)
	b.add_theme_font_size_override("font_size", UiTheme.font_size(24, 700))
	UiTheme.style_button(b, style)
	return b


func _tab_button(text: String) -> Button:
	var b := Button.new()
	b.text = UiTheme.display_text(text)
	b.custom_minimum_size = Vector2(0, 84)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", UiTheme.font_size(30, 700))
	b.pressed.connect(func() -> void: _show_tab(b == _tab_upgrades))
	return b


func _show_tab(upgrades: bool) -> void:
	open_station(&"bench" if upgrades else &"hangar")


func _show_page() -> void:
	_title.text = UiTheme.display_text(TITLES[_kind])
	_showcase.visible = _kind == &"hangar"
	_upgrades_page.visible = _kind == &"bench"
	_modules_page.visible = _kind == &"hangar"
	_market_page.visible = _kind == &"market"
	_lab_page.visible = _kind == &"lab"
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

	for card in _cards:
		card.refresh(econ)
	_refresh_modules(econ)
	if _kind == &"market":
		_refresh_market(econ)
	elif _kind == &"lab":
		_refresh_lab(econ)


func _refresh_market(econ: Economy) -> void:
	var reserve: Dictionary = Recipes.reserve(econ.upgrade_levels)
	var surplus: int = 0
	for k: StringName in econ.cargo:
		surplus += maxi(0, int(econ.cargo[k]) - int(reserve.get(k, 0))) * ResourceRegistry.get_def(k).sell_value
	var any: bool = econ.cargo_count() > 0
	_surplus.text = "EXCEDENTE +%s" % UiTheme.short_number(surplus)
	_surplus.disabled = surplus <= 0
	_sell.text = "TUDO +%s" % UiTheme.short_number(econ.cargo_value()) if any else "TUDO"
	_sell.disabled = not any
	for c in _market_rows.get_children():
		c.queue_free()
	if not any:
		_market_rows.add_child(UiTheme.label("Armazém vazio — cave para coletar minério.", 25, UiTheme.TEXT_DIM, 500))
		return
	for key in ResourceRegistry.order():
		var n: int = int(econ.cargo.get(key, 0))
		if n <= 0:
			continue
		var rd: ResourceDef = ResourceRegistry.get_def(key)
		var row := PanelContainer.new()
		row.name = "Res_" + String(key)
		row.add_theme_stylebox_override("panel", PixelArt.style(&"inset"))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		var icon := TextureRect.new()
		icon.texture = PixelArt.ore_icon(key)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(52, 48)
		h.add_child(icon)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		info.add_child(UiTheme.label("%s  ×%d" % [rd.display_name, n], 27, UiTheme.TEXT, 700))
		var res: int = int(reserve.get(key, 0))
		var sub: String = "%d cada" % rd.sell_value
		if res > 0:
			sub += "  ·  Bancada usa %d" % res
		info.add_child(UiTheme.label(sub, 23, UiTheme.ORANGE if res > 0 else UiTheme.TEXT_DIM, 500))
		var b := Button.new()
		b.name = "Sell"
		b.text = "+%s" % UiTheme.short_number(n * rd.sell_value)
		b.icon = PixelArt.icon(&"coin")
		b.add_theme_constant_override("icon_max_width", 30)
		b.custom_minimum_size = Vector2(170, 70)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", UiTheme.font_size(24, 700))
		UiTheme.style_button(b, &"gold")
		b.pressed.connect(func() -> void: sell_one(key))
		h.add_child(b)
		_market_rows.add_child(row)


func _refresh_lab(econ: Economy) -> void:
	for c in _lab_box.get_children():
		c.queue_free()
	var keys: Array[StringName] = []
	for key in ResourceRegistry.order():
		if not key in CATALOG_SKIP:
			keys.append(key)
	var found: int = 0
	for key in keys:
		if econ.discovered.has(key):
			found += 1
	_lab_box.add_child(UiTheme.label("CATÁLOGO  ·  %d/%d" % [found, keys.size()], 30, UiTheme.ORANGE, 700))
	var grid := GridContainer.new()
	grid.name = "Catalog"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_lab_box.add_child(grid)
	for key in keys:
		var known: bool = econ.discovered.has(key)
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override("panel", PixelArt.style(&"icon_frame" if known else &"inset"))
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_child(v)
		var icon := TextureRect.new()
		icon.texture = PixelArt.ore_icon(key)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(56, 50)
		icon.modulate = Color.WHITE if known else Color(0, 0, 0, 0.75)
		v.add_child(icon)
		var nl := UiTheme.label(ResourceRegistry.get_def(key).display_name if known else "???", 20, UiTheme.TEXT if known else UiTheme.TEXT_DIM, 600)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.clip_text = true
		nl.custom_minimum_size = Vector2(60, 0)
		v.add_child(nl)
		grid.add_child(cell)
	var entries: Array = Journal.unlocked(econ.discovered, GameState.done)
	_lab_box.add_child(UiTheme.label("DIÁRIO DE PESQUISA  ·  %d/%d" % [entries.size(), Journal.ENTRIES.size()], 30, UiTheme.ORANGE, 700))
	entries.reverse()
	for e: Array in entries:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", PixelArt.style(&"inset"))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		card.add_child(v)
		v.add_child(UiTheme.label(String(e[2]).to_upper(), 26, UiTheme.BLUE, 700))
		var t := UiTheme.label(String(e[3]), 24, UiTheme.TEXT, 500)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(300, 0)
		v.add_child(t)
		_lab_box.add_child(card)


func _refresh_modules(econ: Economy) -> void:
	_slots_label.text = "SLOTS  %d / %d" % [econ.equipped_modules.size(), Balance.MODULE_SLOTS]
	for id in ModuleSystem.ALL:
		var b: Button = _module_buttons[id]
		var st: Label = _module_status[id]
		var lvl: int = econ.get_level(id)
		var on: bool = econ.equipped_modules.has(id)
		(_module_bars[id] as SegmentedBar).value = float(lvl) / float(UpgradeRegistry.get_def(id).max_level)
		if lvl == 0:
			st.text = "Não construído (faça na Bancada)"
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
