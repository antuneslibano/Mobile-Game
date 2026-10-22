class_name WorldMap
extends CanvasLayer
## Mapa mundial = base entre expedições (0.9): carrossel com uma região por vez e painel
## com descrição, dificuldade, objetivos (principal, pesquisa, estrelas), camadas até o
## fundo, recursos, riscos e equipamentos. Toda expedição parte da superfície.
## EXPLORAR começa uma expedição; BASE (ou o X) volta à base. Pausa o jogo enquanto
## aberto. Só lê GameState/registros; quem escuta explore_requested (Main) inicia a expedição.

signal explore_requested(region_id: StringName)
signal closed

var _root: Control
var _carousel: RegionCarousel
var _info: VBoxContainer
var _scroll: TouchScroll
var _explore: Button
var _close: Button
var _credits: Label
var _crystals: Label
var _garage: Button
var _confirm: Control


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
	_was_paused = get_tree().paused
	get_tree().paused = true
	_credits.text = UiTheme.short_number(GameState.economy.credits)
	_crystals.text = UiTheme.short_number(GameState.economy.crystals)
	_carousel.setup(RegionRegistry.all(), RegionRegistry.index_of(GameState.region_id))
	_refresh()
	Transitions.slide_in(_root)
	Sfx.play(&"whoosh")
	EventBus.map_opened.emit()


var _was_paused: bool = false


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused
	EventBus.map_closed.emit()
	closed.emit()


## Volta para a base (a base aparece com fade).
func close_animated() -> void:
	close()


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
	if visible and event.is_action_pressed("ui_cancel"):
		close_animated()
		get_viewport().set_input_as_handled()


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
		margin.add_theme_constant_override("margin_" + side, 4)
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
	_close.pressed.connect(close_animated)
	header.add_child(_close)

	# Carrossel.
	_carousel = RegionCarousel.new()
	_carousel.name = "Carousel"
	_carousel.custom_minimum_size = Vector2(0, 420)
	_carousel.page_changed.connect(func(_i: int) -> void: _refresh())
	v.add_child(_carousel)

	# Painel de informações (rolável).
	_scroll = TouchScroll.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_scroll)
	_info = VBoxContainer.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_constant_override("separation", 12)
	_scroll.add_child(_info)

	# Botão principal.
	_explore = Button.new()
	_explore.name = "ExploreButton"
	_explore.custom_minimum_size = Vector2(0, 88)
	_explore.icon = PixelArt.icon(&"pick")
	_explore.add_theme_constant_override("icon_max_width", 44)
	_explore.add_theme_font_size_override("font_size", UiTheme.font_size(40, 700))
	_explore.pressed.connect(func() -> void: explore())
	_explore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	v.add_child(bottom)
	_garage = Button.new()
	_garage.name = "BaseButton"
	_garage.text = UiTheme.display_text("< BASE")
	_garage.custom_minimum_size = Vector2(230, 88)
	_garage.add_theme_font_size_override("font_size", UiTheme.font_size(30, 700))
	UiTheme.style_button(_garage, &"gold")
	_garage.pressed.connect(close_animated)
	bottom.add_child(_garage)
	bottom.add_child(_explore)


func _panel(title: String) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", PixelArt.style(&"inset"))
	_info.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	p.add_child(box)
	if title != "":
		box.add_child(UiTheme.label(title, 30, UiTheme.ORANGE, 700))
	return box


func _tile(icon: Texture2D, caption: String, frame_style: StringName, caption_color: Color = UiTheme.TEXT_DIM) -> VBoxContainer:
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", 2)
	t.custom_minimum_size = Vector2(150, 0)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", PixelArt.style(frame_style))
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var r := TextureRect.new()
	r.texture = icon
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(76, 76)
	frame.add_child(r)
	t.add_child(frame)
	var l := UiTheme.label(caption, 23, caption_color, 500)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(150, 0)
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
	var name := UiTheme.label(r.display_name.to_upper(), 38, r.ui_color, 700)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	var status: String = "BLOQUEADO"
	var status_col: Color = UiTheme.RED
	if unlocked:
		status = "CONCLUÍDA" if GameState.done.has(r.id) else "LIBERADA"
		status_col = UiTheme.GREEN
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", PixelArt.style(&"slot"))
	badge.add_child(UiTheme.label(status, 24, status_col, 700))
	row.add_child(badge)
	var diff := HBoxContainer.new()
	diff.add_theme_constant_override("separation", 4)
	head.add_child(diff)
	diff.add_child(UiTheme.label("DIFICULDADE", 24, UiTheme.TEXT_DIM, 700))
	for i in 5:
		diff.add_child(UiTheme.icon_rect(&"star" if i < r.difficulty else &"star_empty", 38))
	diff.add_child(UiTheme.label("  " + RegionRegistry.DIFFICULTY_NAMES[r.difficulty], 27, UiTheme.TEXT, 600))
	var desc := UiTheme.label(r.description, 27, UiTheme.TEXT, 500)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(300, 0)
	head.add_child(desc)

	if GameState.pending_notice != "":
		var np := _panel("")
		var nl := UiTheme.label(GameState.pending_notice, 25, UiTheme.RED, 500)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size = Vector2(300, 0)
		np.add_child(nl)
		GameState.pending_notice = ""

	if unlocked:
		_objectives_panel(r)
		_tunnels_panel(r)
	else:
		var prog := _panel("DESBLOQUEIO")
		var lr := HBoxContainer.new()
		lr.add_theme_constant_override("separation", 10)
		prog.add_child(lr)
		lr.add_child(UiTheme.icon_rect(&"lock", 44))
		var req := UiTheme.label(RegionRegistry.requirement_text(r), 27, UiTheme.TEXT, 500)
		req.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		req.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lr.add_child(req)
		_objectives_panel(r)

	# Camadas de profundidade.
	var layers := _panel("CAMADAS DE PROFUNDIDADE")
	for b in RegionRegistry.reachable_layers(r):
		var lr := HBoxContainer.new()
		lr.add_theme_constant_override("separation", 10)
		layers.add_child(lr)
		var sw := TextureRect.new()
		sw.texture = PixelArt.material_swatch(b.primary_block)
		sw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sw.custom_minimum_size = Vector2(96, 44)
		lr.add_child(sw)
		var range_txt: String = "%d - %d m" % [b.start_row, mini(b.end_row, r.target_depth_m)]
		var rl := UiTheme.label(range_txt, 25, UiTheme.TEXT, 600)
		rl.custom_minimum_size = Vector2(160, 0)
		lr.add_child(rl)
		var dl := UiTheme.label(b.description, 25, UiTheme.TEXT_DIM, 500)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lr.add_child(dl)

	var fl := HBoxContainer.new()
	fl.add_theme_constant_override("separation", 10)
	layers.add_child(fl)
	fl.add_child(UiTheme.icon_rect(&"star", 40))
	var fdesc := UiTheme.label("%d m  ·  fundo: %s (câmara final)" % [r.target_depth_m, r.final_name], 25, UiTheme.ORANGE, 600)
	fdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fdesc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fl.add_child(fdesc)

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
		var hn := UiTheme.label("Calor a partir de %d m: reduz a velocidade de perfuração (use Refrigeração)." % r.heat_start_m, 24, UiTheme.TEXT_DIM, 500)
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
		_explore.text = UiTheme.display_text("EXPLORAR  >")
		_explore.disabled = false
		UiTheme.style_button(_explore, &"green")
	_close.visible = true
	_scroll.scroll_vertical = 0


## Objetivos: principal, pesquisa (com barra) e desafios (estrelas).
func _objectives_panel(r: RegionDef) -> void:
	var box := _panel("OBJETIVOS  ·  ★ %d/3" % GameState.stars(r.id))
	box.name = "Objectives"
	for o: Dictionary in r.objectives:
		var done: bool = GameState.is_objective_done(r.id, o.id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var icon: StringName = &"star" if done else (&"star_empty" if o.group == &"star" else (&"hull" if o.group == &"main" else &"pick"))
		var ir := UiTheme.icon_rect(icon, 34)
		ir.modulate = Color.WHITE if done or o.group != &"research" else Color(1, 1, 1, 0.7)
		row.add_child(ir)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var color: Color = UiTheme.GREEN if done else (UiTheme.ORANGE if o.group == &"main" else UiTheme.TEXT)
		var l := UiTheme.label(String(o.text), 24, color, 600 if o.group == &"main" else 500)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(240, 0)
		col.add_child(l)
		if not done and o.kind in [&"collect", &"clean"]:
			var p: Vector2 = GameState.objective_progress(r.id, o)
			var pr := HBoxContainer.new()
			pr.add_theme_constant_override("separation", 8)
			col.add_child(pr)
			var bar := SegmentedBar.new(10, UiTheme.ORANGE, 18.0)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.value = p.x / maxf(1.0, p.y)
			pr.add_child(bar)
			pr.add_child(UiTheme.label("%d/%d" % [int(p.x), int(p.y)], 22, UiTheme.TEXT_DIM, 600))
	box.add_child(UiTheme.label("Recorde: %d m de %d m" % [GameState.region_depth(r.id), r.target_depth_m], 23, UiTheme.TEXT_DIM, 500))


## Mundo persistente: os túneis ficam; descer por eles (caindo) não gasta combustível.
func _tunnels_panel(r: RegionDef) -> void:
	var box := _panel("SEUS TÚNEIS")
	box.name = "TunnelsPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	row.add_child(UiTheme.icon_rect(&"fuel", 40))
	var txt: String = "Tudo o que você escava fica salvo. Cair pelos túneis antigos não gasta combustível: cave um poço e chegue mais fundo a cada expedição."
	if GameState.region_depth(r.id) > 0:
		txt += " Recorde: %d m." % GameState.region_depth(r.id)
	var l := UiTheme.label(txt, 24, UiTheme.TEXT, 500)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(240, 0)
	row.add_child(l)
	var nb := Button.new()
	nb.name = "NewAreaButton"
	nb.text = UiTheme.display_text("EXPLORAR NOVA ÁREA")
	nb.custom_minimum_size = Vector2(0, 76)
	nb.add_theme_font_size_override("font_size", UiTheme.font_size(24, 700))
	UiTheme.style_button(nb, &"steel")
	nb.pressed.connect(func() -> void: ask_new_area(r))
	box.add_child(nb)


## Confirmação de "nova área" (a área atual da região é apagada).
func ask_new_area(r: RegionDef) -> void:
	if _confirm != null:
		_confirm.queue_free()
	_confirm = Control.new()
	_confirm.name = "NewAreaConfirm"
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(dim)
	# Painel centralizado na tela (um CenterContainer cuida de qualquer proporção).
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelArt.style(&"frame"))
	panel.custom_minimum_size = Vector2(minf(640.0, _root.get_viewport_rect().size.x - 40.0), 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", PixelArt.style(&"red_pressed"))
	v.add_child(plate)
	var t := UiTheme.label("NOVA ÁREA?", 34, UiTheme.TEXT, 700)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(t)
	var msg := UiTheme.label("Você vai explorar um mapa novo de %s. A área atual será APAGADA: túneis, minério e baús que ficaram para trás e o recorde de profundidade. Objetivos, guardião vencido, catálogo e o armazém continuam." % r.display_name, 24, UiTheme.TEXT, 500)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(minf(580.0, _root.get_viewport_rect().size.x - 80.0), 0)
	v.add_child(msg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var no := Button.new()
	no.name = "Cancel"
	no.text = UiTheme.display_text("CANCELAR")
	no.custom_minimum_size = Vector2(0, 80)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.add_theme_font_size_override("font_size", UiTheme.font_size(26, 700))
	UiTheme.style_button(no, &"steel")
	no.pressed.connect(func() -> void: _confirm.queue_free())
	row.add_child(no)
	var yes := Button.new()
	yes.name = "Confirm"
	yes.text = UiTheme.display_text("NOVA ÁREA")
	yes.custom_minimum_size = Vector2(0, 80)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.add_theme_font_size_override("font_size", UiTheme.font_size(26, 700))
	UiTheme.style_button(yes, &"red")
	yes.pressed.connect(func() -> void:
		GameState.new_area(r.id)
		_confirm.queue_free()
		_refresh())
	row.add_child(yes)


func _safe_top() -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	if win.y <= 0.0:
		return 0.0
	return float(DisplayServer.get_display_safe_area().position.y) * (_root.get_viewport_rect().size.y / win.y) if _root != null else 0.0
