class_name WorldMap
extends CanvasLayer
## Mapa mundial: carrossel com uma região grande por vez (deslizar na horizontal) e painel
## com descrição, dificuldade, progresso, camadas, recursos, riscos, equipamentos
## recomendados e desbloqueio. EXPLORAR inicia (ou continua) a exploração na região.
## Pausa o jogo enquanto aberto. Só lê GameState/registros; a troca de região é feita
## por quem escuta explore_requested (Main).

signal explore_requested(region_id: StringName)
signal closed

var _root: Control
var _carousel: RegionCarousel
var _info: VBoxContainer
var _scroll: ScrollContainer
var _explore: Button
var _close: Button
var _credits: Label
var _crystals: Label


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	EventBus.wallet_changed.connect(func(c: int, k: int) -> void:
		_credits.text = UiTheme.short_number(c)
		_crystals.text = UiTheme.short_number(k))


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	get_tree().paused = true
	_credits.text = UiTheme.short_number(GameState.economy.credits)
	_crystals.text = UiTheme.short_number(GameState.economy.crystals)
	_carousel.setup(RegionRegistry.all(), RegionRegistry.index_of(GameState.region_id))
	_refresh()
	EventBus.map_opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	EventBus.map_closed.emit()
	closed.emit()


func current_region() -> RegionDef:
	return RegionRegistry.all()[_carousel.target]


func go_to_page(index: int, instant: bool = false) -> void:
	_carousel.go_to(index, instant)
	_refresh()


## Pede a exploração da região selecionada (se desbloqueada).
func explore() -> bool:
	var r: RegionDef = current_region()
	if not GameState.is_region_unlocked(r.id):
		return false
	explore_requested.emit(r.id)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and GameState.dive_active:
		close()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible and GameState.dive_active:
		close()


# --- Construção ----------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color("0b101a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	margin.add_theme_constant_override("margin_top", 10 + int(_safe_top()))
	margin.add_theme_constant_override("margin_bottom", 10)
	_root.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)

	# Cabeçalho.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	v.add_child(header)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", PixelArt.style(&"plate"))
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(plate)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 10)
	ph.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.add_child(ph)
	ph.add_child(UiTheme.icon_rect(&"map", 40))
	var title := UiTheme.label("MAPA MUNDIAL", 34, Color("2a1606"), 700)
	title.add_theme_constant_override("outline_size", 0)
	ph.add_child(title)
	var cbox: Array = UiTheme.currency_box(Economy.CREDITS)
	(cbox[0] as Control).custom_minimum_size = Vector2(150, 0)
	header.add_child(cbox[0])
	_credits = cbox[1]
	var kbox: Array = UiTheme.currency_box(Economy.CRYSTALS)
	(kbox[0] as Control).custom_minimum_size = Vector2(100, 0)
	header.add_child(kbox[0])
	_crystals = kbox[1]
	_close = Button.new()
	_close.name = "CloseButton"
	_close.icon = PixelArt.icon(&"close")
	_close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_close.add_theme_constant_override("icon_max_width", 30)
	_close.custom_minimum_size = Vector2(64, 64)
	UiTheme.style_button(_close, &"red")
	_close.pressed.connect(close)
	header.add_child(_close)

	# Carrossel.
	_carousel = RegionCarousel.new()
	_carousel.name = "Carousel"
	_carousel.custom_minimum_size = Vector2(0, 470)
	_carousel.page_changed.connect(func(_i: int) -> void: _refresh())
	v.add_child(_carousel)

	# Painel de informações (rolável).
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_info = VBoxContainer.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_constant_override("separation", 8)
	_scroll.add_child(_info)

	# Botão principal.
	_explore = Button.new()
	_explore.name = "ExploreButton"
	_explore.custom_minimum_size = Vector2(0, 88)
	_explore.icon = PixelArt.icon(&"pick")
	_explore.add_theme_constant_override("icon_max_width", 44)
	_explore.add_theme_font_size_override("font_size", UiTheme.font_size(40, 700))
	_explore.pressed.connect(func() -> void: explore())
	v.add_child(_explore)


func _panel(title: String) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", PixelArt.style(&"inset"))
	_info.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	p.add_child(box)
	if title != "":
		box.add_child(UiTheme.label(title, 22, UiTheme.ORANGE, 700))
	return box


func _tile(icon: Texture2D, caption: String, frame_style: StringName, caption_color: Color = UiTheme.TEXT_DIM) -> VBoxContainer:
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", 2)
	t.custom_minimum_size = Vector2(112, 0)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", PixelArt.style(frame_style))
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var r := TextureRect.new()
	r.texture = icon
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(54, 54)
	frame.add_child(r)
	t.add_child(frame)
	var l := UiTheme.label(caption, 16, caption_color, 500)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(112, 0)
	t.add_child(l)
	return t


func _refresh() -> void:
	for c in _info.get_children():
		c.queue_free()
	var r: RegionDef = current_region()
	var unlocked: bool = GameState.is_region_unlocked(r.id)
	var depth: int = GameState.region_depth(r.id)

	# Título, situação, dificuldade e descrição.
	var head := _panel("")
	var row := HBoxContainer.new()
	head.add_child(row)
	var name := UiTheme.label(r.display_name.to_upper(), 30, r.ui_color, 700)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var status: String = "BLOQUEADO"
	var status_col: Color = UiTheme.RED
	if unlocked:
		status = "ATIVA" if r.id == GameState.region_id and GameState.dive_active else "LIBERADA"
		status_col = UiTheme.GREEN
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", PixelArt.style(&"slot"))
	badge.add_child(UiTheme.label(status, 18, status_col, 700))
	row.add_child(badge)
	var diff := HBoxContainer.new()
	diff.add_theme_constant_override("separation", 4)
	head.add_child(diff)
	diff.add_child(UiTheme.label("DIFICULDADE", 18, UiTheme.TEXT_DIM, 700))
	for i in 5:
		diff.add_child(UiTheme.icon_rect(&"star" if i < r.difficulty else &"star_empty", 30))
	diff.add_child(UiTheme.label("  " + RegionRegistry.DIFFICULTY_NAMES[r.difficulty], 20, UiTheme.TEXT, 600))
	var desc := UiTheme.label(r.description, 20, UiTheme.TEXT, 500)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(300, 0)
	head.add_child(desc)

	# Progresso / desbloqueio.
	var prog := _panel("PROGRESSO" if unlocked else "DESBLOQUEIO")
	if unlocked:
		var bar := SegmentedBar.new(10, PixelArt.GOLD, 26.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.value = RegionRegistry.progress_ratio(r, depth)
		prog.add_child(bar)
		prog.add_child(UiTheme.label("%d%% explorado · recorde %d m de %d m" % [int(bar.value * 100.0), depth, r.target_depth_m], 19, UiTheme.TEXT_DIM, 500))
	else:
		var lr := HBoxContainer.new()
		lr.add_theme_constant_override("separation", 10)
		prog.add_child(lr)
		lr.add_child(UiTheme.icon_rect(&"lock", 34))
		var req := UiTheme.label(RegionRegistry.requirement_text(r), 20, UiTheme.TEXT, 500)
		req.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		req.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lr.add_child(req)
		var have: int = GameState.region_depth(r.unlock_region)
		var bar := SegmentedBar.new(10, UiTheme.RED, 22.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.value = float(have) / float(maxi(1, r.unlock_depth_m))
		prog.add_child(bar)
		prog.add_child(UiTheme.label("Atual: %d / %d m em %s" % [have, r.unlock_depth_m, RegionRegistry.get_def(r.unlock_region).display_name], 18, UiTheme.TEXT_DIM, 500))

	# Camadas de profundidade.
	var layers := _panel("CAMADAS DE PROFUNDIDADE")
	for b in r.layers:
		var lr := HBoxContainer.new()
		lr.add_theme_constant_override("separation", 10)
		layers.add_child(lr)
		var sw := TextureRect.new()
		sw.texture = PixelArt.material_swatch(b.primary_block)
		sw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sw.custom_minimum_size = Vector2(72, 32)
		lr.add_child(sw)
		var range_txt: String = "%d - %d m" % [b.start_row, b.end_row] if b.end_row < Balance.MAX_DEPTH_ROWS else "%d m +" % b.start_row
		var rl := UiTheme.label(range_txt, 19, UiTheme.TEXT, 600)
		rl.custom_minimum_size = Vector2(130, 0)
		lr.add_child(rl)
		var dl := UiTheme.label(b.description, 19, UiTheme.TEXT_DIM, 500)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lr.add_child(dl)

	# Recursos principais.
	var res := _panel("PRINCIPAIS RECURSOS")
	var rg := HFlowContainer.new()
	rg.add_theme_constant_override("h_separation", 6)
	res.add_child(rg)
	for key in r.resources:
		var rd: ResourceDef = ResourceRegistry.get_def(key)
		rg.add_child(_tile(PixelArt.ore_icon(key), rd.display_name if rd != null else String(key), &"icon_frame"))

	# Riscos ambientais.
	var haz := _panel("RISCOS AMBIENTAIS")
	var hg := HFlowContainer.new()
	hg.add_theme_constant_override("h_separation", 6)
	haz.add_child(hg)
	for h in r.hazards:
		hg.add_child(_tile(PixelArt.icon(h), RegionRegistry.HAZARDS.get(h, String(h)), &"red_pressed", Color("ffb0a0")))
	if r.hazards.has(&"heat"):
		var hn := UiTheme.label("Calor a partir de %d m: reduz a velocidade de perfuração (use Refrigeração)." % r.heat_start_m, 17, UiTheme.TEXT_DIM, 500)
		hn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hn.custom_minimum_size = Vector2(300, 0)
		haz.add_child(hn)

	# Equipamentos recomendados.
	var eq := _panel("EQUIPAMENTOS RECOMENDADOS")
	var eg := HFlowContainer.new()
	eg.add_theme_constant_override("h_separation", 6)
	eq.add_child(eg)
	for id in r.recommended:
		var def: UpgradeDef = UpgradeRegistry.get_def(id)
		if def != null:
			eg.add_child(_tile(PixelArt.icon(id), "%s\nNv. %d" % [def.display_name, GameState.economy.get_level(id)], &"icon_frame"))

	# Botão principal.
	if not unlocked:
		_explore.text = UiTheme.display_text("BLOQUEADO")
		_explore.disabled = true
		UiTheme.style_button(_explore, &"steel")
	else:
		var cont: bool = r.id == GameState.region_id and GameState.dive_active
		_explore.text = UiTheme.display_text("CONTINUAR  >" if cont else "EXPLORAR  >")
		_explore.disabled = false
		UiTheme.style_button(_explore, &"green")
	_close.visible = GameState.dive_active
	_scroll.scroll_vertical = 0


func _safe_top() -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	if win.y <= 0.0:
		return 0.0
	return float(DisplayServer.get_display_safe_area().position.y) * (_root.get_viewport_rect().size.y / win.y) if _root != null else 0.0
