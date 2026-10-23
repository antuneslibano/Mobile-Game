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
var _care: ShipCarePanel
var _lab_page: VBoxContainer
var _lab_box: VBoxContainer
var _looks_box: VBoxContainer
## Prévia flutuante da nave (0.19.1): aparece no canto quando a vitrine do topo saiu da
## tela e o jogador está na parte de visual ou de cuidados.
var _float_preview: ShipPreview
var _thumbs: Dictionary = {}             ## chave do visual → textura da miniatura
var _lab_tab: StringName = &"minerals"
const TITLES: Dictionary = {&"bench": "BANCADA", &"hangar": "HANGAR", &"market": "MERCADO", &"lab": "LABORATÓRIO"}
## Minerais do catálogo (sem os materiais antigos de entulho).
const CATALOG_SKIP: Array[StringName] = [&"dirt", &"stone", &"basalt", &"abyss_stone", &"bio_sample", &"leather"]


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
		if _kind != &"lab":  # o Laboratório entra pela porta de metal
			Transitions.slide_in(_root)
			Sfx.play(&"whoosh")
	else:
		Transitions.fade_in(_root, 0.18)
	_show_page()
	_refresh()
	if _kind == &"lab":
		GameState.journal_seen = Journal.unlocked(GameState.economy.discovered, GameState.done, GameState.creatures).size()
	elif _kind == &"hangar":
		GameState.looks_seen = ShipLooks.unlocked_count(GameState.economy, GameState.done)
		_care.reload()


func station() -> StringName:
	return _kind


## Volta para a base: do Laboratório pela porta de metal; das outras estações direto.
func close_animated() -> void:
	if not visible or Transitions.shutter_busy():
		return
	if _kind == &"lab":
		Transitions.shutter(get_tree(), close)
	else:
		close()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused
	EventBus.garage_closed.emit()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_animated()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_float_preview()
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.4, 0.0, 1.0)


func _update_float_preview() -> void:
	if _float_preview == null:
		return
	var show: bool = visible and _kind == &"hangar" and _showcase.is_visible_in_tree()
	if show:
		var view: Rect2 = _scroll.get_global_rect()
		show = _showcase.get_global_rect().end.y < view.position.y + 40.0 \
				and _looks_box.get_global_rect().position.y < view.end.y
	if show:
		var vp: Vector2 = _root.size
		var sz: Vector2 = _float_preview.size
		_float_preview.position = Vector2(vp.x - sz.x - 22.0, vp.y - sz.y - 22.0 - SafeArea.bottom(get_viewport()))
	if show != _float_preview.visible:
		_float_preview.visible = show
		if show:
			Transitions.pop_in(_float_preview)


## Depuração: rola o corpo até a seção (-1 = visual da nave) ou N pixels.
func debug_scroll(px: int) -> void:
	if px < 0:
		px = int(_looks_box.position.y + _modules_page.position.y)
	_scroll.scroll_vertical = px


## Miniatura da nave com uma opção de visual aplicada (cacheada).
func _thumb(look: Dictionary) -> Texture2D:
	var k: String = ShipLooks.key(look)
	if not _thumbs.has(k):
		_thumbs[k] = ImageTexture.create_from_image(ShipArt.build(0, look))
	return _thumbs[k]


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

	# Margens com a área segura do aparelho (notch, cantos, barra de gestos).
	var margin := SafeMargin.new(4.0, 10.0, 10.0)
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
	close_b.pressed.connect(close_animated)
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
	# Cuidar da nave (0.19): limpar e consertar arrastando as ferramentas.
	_care = ShipCarePanel.new()
	_modules_page.add_child(_care)
	_looks_box = VBoxContainer.new()
	_looks_box.name = "Looks"
	_looks_box.add_theme_constant_override("separation", 8)
	_modules_page.add_child(_looks_box)
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

	_float_preview = ShipPreview.new()
	_float_preview.name = "FloatPreview"
	_float_preview.custom_minimum_size = Vector2(220, 165)
	_float_preview.size = Vector2(220, 165)
	_float_preview.visible = false
	_root.add_child(_float_preview)

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
	var mname := UiTheme.label(def.display_name.to_upper(), 28, UiTheme.TEXT, 700)
	mname.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		b.disabled = rd.sell_value <= 0
		if b.disabled:
			b.text = "—"
		b.add_theme_font_size_override("font_size", UiTheme.font_size(24, 700))
		UiTheme.style_button(b, &"gold")
		b.pressed.connect(func() -> void: sell_one(key))
		h.add_child(b)
		_market_rows.add_child(row)


func _refresh_lab(econ: Economy) -> void:
	for c in _lab_box.get_children():
		_lab_box.remove_child(c)  # sai já da árvore: o novo "Catalog" mantém o nome
		c.queue_free()
	# Abas: só uma seção aparece por vez (o catálogo não fica todo à mostra).
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	_lab_box.add_child(tabs)
	for t: Array in [[&"minerals", "MINERAIS"], [&"creatures", "CRIATURAS"], [&"plans", "PLANTAS"], [&"diary", "DIÁRIO"]]:
		var tb := Button.new()
		tb.name = "LabTab_" + String(t[0])
		tb.text = UiTheme.display_text(String(t[1]))
		tb.custom_minimum_size = Vector2(0, 64)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", UiTheme.font_size(20, 700))
		UiTheme.style_button(tb, &"gold" if _lab_tab == t[0] else &"steel")
		var id: StringName = t[0]
		tb.pressed.connect(func() -> void:
			_lab_tab = id
			Sfx.play(&"click")
			_refresh())
		tabs.add_child(tb)
	_lab_box.add_child(UiTheme.label("Toque em um item para ver a ficha.", 21, UiTheme.TEXT_DIM, 500))
	match _lab_tab:
		&"creatures":
			_lab_creatures()
		&"plans":
			_lab_plans(econ)
		&"diary":
			_lab_diary(econ)
		_:
			_lab_minerals(econ)


func _lab_grid(name: String, cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.name = name
	g.columns = cols
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	_lab_box.add_child(g)
	return g


## Célula tocável do catálogo (ícone + nome, ou silhueta "???").
func _lab_cell(icon_tex: Texture2D, title: String, known: bool, on_tap: Callable) -> Button:
	var cell := Button.new()
	cell.custom_minimum_size = Vector2(0, 112)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_button(cell, &"steel")
	if known:
		cell.add_theme_stylebox_override("normal", PixelArt.style(&"icon_frame"))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(v)
	var icon := TextureRect.new()
	icon.texture = icon_tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(56, 52)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color.WHITE if known else Color(0, 0, 0, 0.75)
	v.add_child(icon)
	var nl := UiTheme.label(title if known else "???", 19, UiTheme.TEXT if known else UiTheme.TEXT_DIM, 600)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(80, 0)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nl)
	cell.pressed.connect(func() -> void:
		Sfx.play(&"click")
		on_tap.call())
	return cell


func _lab_minerals(econ: Economy) -> void:
	var keys: Array[StringName] = []
	for key in ResourceRegistry.order():
		if not key in CATALOG_SKIP and not Relics.is_relic_key(key):
			keys.append(key)
	var found: int = 0
	for key in keys:
		if econ.discovered.has(key):
			found += 1
	_lab_box.add_child(UiTheme.label("MINERAIS  ·  %d/%d" % [found, keys.size()], 28, UiTheme.ORANGE, 700))
	var grid := _lab_grid("Catalog", 4)
	for key in keys:
		var known: bool = econ.discovered.has(key)
		var rd: ResourceDef = ResourceRegistry.get_def(key)
		grid.add_child(_lab_cell(PixelArt.ore_icon(key), rd.display_name, known, func() -> void: _mineral_card(key, known)))


func _lab_creatures() -> void:
	_lab_box.add_child(UiTheme.label("CRIATURAS  ·  %d/%d" % [GameState.creatures.size(), Creature.ORDER.size()], 28, UiTheme.ORANGE, 700))
	var grid := _lab_grid("Creatures", 2)
	for sp in Creature.ORDER:
		var known: bool = GameState.creatures.has(sp)
		var tex: Texture2D = CreatureManager.sprite(&"worm_head" if sp == &"worm" else sp, 0)
		grid.add_child(_lab_cell(tex, String(Creature.DEFS[sp].name), known, func() -> void: _creature_card(sp, known)))


func _lab_plans(econ: Economy) -> void:
	_lab_box.add_child(UiTheme.label("PLANTAS DE BAÚ  ·  %d/%d" % [econ.blueprints.size(), Chests.BLUEPRINTS.size()], 28, UiTheme.ORANGE, 700))
	var grid := _lab_grid("Plans", 2)
	for id: StringName in Chests.BLUEPRINTS:
		var known: bool = econ.blueprints.has(id)
		var bp: Array = Chests.BLUEPRINTS[id]
		var look: Dictionary = {bp[0]: _look_for_blueprint(id)}
		var tex: Texture2D = ShipArt.frame(0, look)
		grid.add_child(_lab_cell(tex, String(bp[1]), known, func() -> void: _detail(String(bp[1]) if known else "???", tex if known else null,
				["Visual exclusivo da nave (%s)." % ShipLooks.SLOT_NAMES[bp[0]].to_lower(), "Encontrada em baú raro ou lendário." if known else "Ainda não encontrada. Procure baús raros (aura azul) e lendários (aura roxa).",
				"Escolha no Hangar." if known else ""], UiTheme.ORANGE)))
	# Relíquias (0.19): uma por região; instalar aqui as que estiverem no armazém.
	var installed: int = econ.relics.size()
	_lab_box.add_child(UiTheme.label("RELÍQUIAS  ·  %d/%d instaladas" % [installed, Relics.DEFS.size()], 28, UiTheme.ORANGE, 700))
	var rgrid := _lab_grid("Relics", 2)
	for region_id: StringName in Relics.REGION_ORDER:
		var rd: Array = Relics.DEFS[region_id]
		var key: StringName = rd[0]
		var have: bool = int(econ.cargo.get(key, 0)) > 0
		var known: bool = econ.relics.has(key) or have or econ.discovered.has(key)
		var tex: Texture2D = PixelArt.ore_icon(key)
		var title: String = String(rd[1]) + ("  ✓" if econ.relics.has(key) else "")
		rgrid.add_child(_lab_cell(tex, title, known, func() -> void: _relic_card(region_id)))


func _relic_card(region_id: StringName) -> void:
	var rd: Array = Relics.DEFS[region_id]
	var key: StringName = rd[0]
	var econ: Economy = GameState.economy
	var known: bool = econ.relics.has(key) or int(econ.cargo.get(key, 0)) > 0 or econ.discovered.has(key)
	var lines: Array = []
	if known:
		lines.append(String(rd[2]))
	lines.append("Escondida em %s: só uma no mapa, numa pequena câmara funda. Brilha e aparece no sonar como estrela." % RegionRegistry.get_def(region_id).display_name)
	lines.append("Instalada: %s (para sempre)." % rd[6])
	lines.append("Ou vender por %s créditos." % UiTheme.short_number(int(rd[3])))
	if econ.relics.has(key):
		lines.append("JÁ INSTALADA.")
	_detail(String(rd[1]) if known else "???", PixelArt.ore_icon(key) if known else null, lines, Color(rd[7]))
	if int(econ.cargo.get(key, 0)) > 0:
		# Tem uma no armazém: abre a escolha instalar/vender por cima.
		EventBus.relic_choice_requested.emit(key)


static func _look_for_blueprint(id: StringName) -> StringName:
	for slot in ShipLooks.SLOTS:
		for o: Array in ShipLooks.OPTIONS[slot]:
			if String(o[2]) == "bp:" + String(id):
				return o[0]
	return &""


func _lab_diary(econ: Economy) -> void:
	var entries: Array = Journal.unlocked(econ.discovered, GameState.done, GameState.creatures)
	_lab_box.add_child(UiTheme.label("DIÁRIO  ·  %d/%d" % [entries.size(), Journal.ENTRIES.size()], 28, UiTheme.ORANGE, 700))
	entries.reverse()
	for e: Array in entries:
		var b := Button.new()
		b.text = UiTheme.display_text(String(e[2]).to_upper())
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", UiTheme.font_size(18, 700))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiTheme.style_button(b, &"steel")
		b.pressed.connect(func() -> void: _detail(String(e[2]), null, [String(e[3])], UiTheme.BLUE))
		_lab_box.add_child(b)


## Ficha de um mineral: descrição (do diário), preço, broca necessária e onde aparece.
func _mineral_card(key: StringName, known: bool) -> void:
	var rd: ResourceDef = ResourceRegistry.get_def(key)
	if not known:
		_detail("???", null, ["Ainda não descoberto. Colete para catalogar."], UiTheme.TEXT_DIM)
		return
	var lines: Array = []
	for e: Array in Journal.ENTRIES:
		if String(e[1]) == "res:" + String(key):
			lines.append(String(e[3]))
	if rd.currency != &"":
		lines.append("Moeda: usada nos módulos (Cristais).")
	else:
		lines.append("Valor: %d créditos cada." % rd.sell_value)
	var block_id: int = -1
	for def: BlockDef in BlockRegistry.all():
		if def.drops.has(key) and not def.is_terrain():
			block_id = def.id
			break
	if block_id >= 0:
		var tier: int = MiningRules.required_tier(block_id)
		lines.append("Broca necessária: Nv. %d (%s)." % [Balance.DRILL_TIER_LEVELS[tier], MiningRules.TIER_NAMES[tier]])
		var where: PackedStringArray = []
		for r in RegionRegistry.all():
			for b in r.layers:
				for entry: Array in b.ore_table:
					if int(entry[0]) == block_id and b.start_row < r.target_depth_m:
						where.append("%s (%d m+)" % [r.display_name, maxi(int(entry[2]), b.start_row)])
						break
		if not where.is_empty():
			lines.append("Onde: " + ", ".join(where.slice(0, 4)) + ".")
	var uses: PackedStringArray = []
	for u in UpgradeRegistry.all():
		for lvl in [0, 4, 8]:
			if Recipes.materials(u, lvl).has(key) and not uses.has(u.display_name):
				uses.append(u.display_name)
	if not uses.is_empty():
		lines.append("Bancada: " + ", ".join(uses) + ".")
	lines.append("Coletados nesta região: %d." % int(GameState._rstats(GameState.region_id).res.get(String(key), 0)))
	_detail(rd.display_name, PixelArt.ore_icon(key), lines, rd.color)


func _creature_card(sp: StringName, known: bool) -> void:
	if not known:
		_detail("???", null, ["Criatura ainda não vista. Explore as cavernas do Vale (use o sonar)."], UiTheme.TEXT_DIM)
		return
	var d: Dictionary = Creature.DEFS[sp]
	var lines: Array = []
	for e: Array in Journal.ENTRIES:
		if String(e[1]) == "creature:" + String(sp):
			lines.append(String(e[3]))
	lines.append("Hostil: morde (%d de casco)." % int(d.dmg) if bool(d.hostile) else "Inofensiva.")
	lines.append("Vida: %d  ·  Couro: %d" % [int(d.hp), int(d.samples)])
	lines.append("Profundidade: a partir de %d m." % int(CreatureManager.SPAWNS[&"vale"][sp]))
	lines.append("Vencidas: %d." % int(GameState.creatures[sp].defeated))
	_detail(String(d.name), CreatureManager.sprite(&"worm_head" if sp == &"worm" else sp, 0), lines, Color("9bff5a"))


## Cartão de detalhes por cima do catálogo (toque fora ou em FECHAR para sair).
func _detail(title: String, icon_tex: Texture2D, lines: Array, color: Color) -> void:
	var old: Node = _root.get_node_or_null("LabDetail")
	if old != null:
		old.queue_free()
	var layer := Control.new()
	layer.name = "LabDetail"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			layer.queue_free())
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelArt.style(&"frame"))
	panel.custom_minimum_size = Vector2(minf(620.0, _root.get_viewport_rect().size.x - 40.0), 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	if icon_tex != null:
		var fr := PanelContainer.new()
		fr.add_theme_stylebox_override("panel", PixelArt.style(&"icon_frame"))
		head.add_child(fr)
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(96, 96)
		fr.add_child(icon)
	var t := UiTheme.label(title.to_upper(), 30, color, 700)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size = Vector2(200, 0)
	head.add_child(t)
	for line: Variant in lines:
		if String(line) == "":
			continue
		var l := UiTheme.label(String(line), 23, UiTheme.TEXT, 500)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(minf(560.0, _root.get_viewport_rect().size.x - 80.0), 0)
		v.add_child(l)
	var close_b := Button.new()
	close_b.name = "DetailClose"
	close_b.text = UiTheme.display_text("FECHAR")
	close_b.custom_minimum_size = Vector2(0, 70)
	close_b.add_theme_font_size_override("font_size", UiTheme.font_size(24, 700))
	UiTheme.style_button(close_b, &"steel")
	close_b.pressed.connect(func() -> void: layer.queue_free())
	v.add_child(close_b)
	Transitions.pop_in(panel)


func _refresh_looks(econ: Economy) -> void:
	for c in _looks_box.get_children():
		c.queue_free()
	_looks_box.add_child(UiTheme.label("VISUAL DA NAVE", 32, UiTheme.ORANGE, 700))
	var look: Dictionary = GameState.ship_look()
	for slot in ShipLooks.SLOTS:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", PixelArt.style(&"inset"))
		_looks_box.add_child(panel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		panel.add_child(v)
		v.add_child(UiTheme.label(ShipLooks.SLOT_NAMES[slot], 26, UiTheme.TEXT, 700))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		v.add_child(flow)
		for o: Array in ShipLooks.OPTIONS[slot]:
			var id: StringName = o[0]
			var ok: bool = ShipLooks.is_unlocked(String(o[2]), econ, GameState.done)
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 2)
			cell.custom_minimum_size = Vector2(196, 0)
			var b := Button.new()
			b.name = "Look_%s_%s" % [slot, id]
			b.text = UiTheme.display_text(String(o[1]).to_upper())
			b.custom_minimum_size = Vector2(196, 128)
			b.add_theme_font_size_override("font_size", UiTheme.font_size(17, 700))
			# Miniatura: a nave como fica com esta opção (0.19.1).
			var try_look: Dictionary = look.duplicate()
			try_look[slot] = id
			b.icon = _thumb(try_look)
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.add_theme_constant_override("icon_max_width", 140)
			if not ok:
				b.modulate = Color(1, 1, 1, 0.55)
			UiTheme.style_button(b, &"green" if look.get(slot) == id else &"steel")
			b.disabled = not ok
			b.pressed.connect(func() -> void:
				GameState.set_look(slot, id)
				Sfx.play(&"click")
				_refresh()
				if _float_preview.visible:
					Transitions.bump(_float_preview))
			cell.add_child(b)
			if not ok:
				# Requisito em fonte de texto (legível), embaixo do botão.
				var req := UiTheme.label(ShipLooks.requirement_text(String(o[2])), 19, UiTheme.TEXT_DIM, 500)
				req.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				req.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				req.custom_minimum_size = Vector2(196, 0)
				cell.add_child(req)
			flow.add_child(cell)


func _refresh_modules(econ: Economy) -> void:
	if _kind == &"hangar":
		_refresh_looks(econ)
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
	_toast.position = Vector2(0, vp.y - SafeArea.bottom(get_viewport()) - 120)
	_toast_t = 1.6

