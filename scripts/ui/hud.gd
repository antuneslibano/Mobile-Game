class_name Hud
extends CanvasLayer
## HUD: barra superior (profundidade, moedas, energia, combustível, casco, calor, extrair),
## joystick flutuante e botão de impulso. Alertas visuais: vinheta pulsante nas bordas e
## aviso piscando para calor/dano no casco e combustível baixo/crítico. Apenas exibe estado
## e expõe áreas de toque; não altera regras de jogo. Na câmara final: barra de vida do
## guardião e, ao vencê-lo, o painel de região concluída (voltar à base ou continuar).

signal extract_requested
signal settings_requested

const TOP_HEIGHT: float = 262.0
const SIDE_MARGIN: float = 20.0
const BOOST_SIZE: float = 150.0
const BANNER_TIME: float = 2.8

var _root: Control
var _top: PanelContainer
var _depth_label: Label
var _max_label: Label
var _biome_label: Label
var _credits_label: Label
var _crystals_label: Label
var _energy_bar: SegmentedBar
var _extract_button: Button
var _fuel_bar: SegmentedBar
var _fuel_label: Label
var _hull_bar: SegmentedBar
var _heat_value: Label
var _heat_icon: TextureRect
var _vignette: ColorRect
var _warn: Label
var _t: float = 0.0
var _heat_label: Label
var _heat_tint: ColorRect
var _boost: PadButton
var _sonar: PadButton
## Sonar observado (recarga) para o botão.
var sonar: SonarOverlay
var _joystick: VirtualJoystick
var _banner: Label
var _banner_t: float = 0.0
var _hint: Label
var _fps_label: Label
var _gear: Button
var _pads: Array[PadButton] = []
var _safe_top: float = 0.0
var _safe_bottom: float = 0.0
var _hint_time: float = 0.0
var _boss: PanelContainer
var _boss_name: Label
var _boss_bar: SegmentedBar
var _done_panel: PanelContainer
var _done_text: Label
var _hit_flash: float = 0.0
var _combat: bool = false
## Perfuradora observada (somente leitura) para energia, impulso e calor.
var drill: Drill
## Guardião da câmara final (somente leitura) para a barra de vida.
var guardian: FinalGuardian


func _ready() -> void:
	_build()
	EventBus.depth_changed.connect(_on_depth_changed)
	EventBus.relic_found.connect(func(key: StringName) -> void:
		Sfx.play(&"chest", 0.8)
		show_alert("RELÍQUIA: %s!" % String(Relics.def_by_key(key)[1]).to_upper(), Color("ffd23f")))
	EventBus.wear_alert.connect(func(p: float) -> void:
		show_alert("NAVE DESGASTADA −%d%% · CUIDE DELA NO HANGAR" % roundi(p * 100.0), Color("ffb347")))
	EventBus.biome_changed.connect(_on_biome_changed)
	EventBus.material_dug.connect(func(_a: Vector2, _c: Dictionary) -> void: _dismiss_hint())
	EventBus.overdrive_ready.connect(func() -> void: _show_banner("SOBRECARGA PRONTA", UiTheme.BLUE))
	EventBus.objective_completed.connect(func(_r: StringName, _o: StringName, _t: String) -> void: _show_banner("OBJETIVO CONCLUÍDO!", PixelArt.GOLD))
	EventBus.final_chamber_reached.connect(_on_final_chamber)
	EventBus.ship_hit.connect(func(_d: float) -> void: _hit_flash = 1.0)
	EventBus.guardian_combat.connect(_on_combat)
	EventBus.drill_too_weak.connect(_on_too_weak)
	EventBus.chest_opened.connect(func(rar: int, bp: StringName) -> void:
		var txt: String = "BAÚ %s!" % Chests.NAMES[rar]
		if bp != &"":
			txt = "PLANTA: " + String(Chests.BLUEPRINTS[bp][1]).to_upper()
		_show_banner(txt, Chests.COLORS[rar]))
	EventBus.creature_discovered.connect(func(sp: StringName) -> void:
		_show_banner(("NOVA CRIATURA: " + String(Creature.DEFS[sp].name)).to_upper(), Color("9bff5a")))
	EventBus.wallet_changed.connect(set_currencies)
	EventBus.cargo_changed.connect(_on_cargo_changed)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	_on_depth_changed(GameState.depth_m, GameState.max_depth_m)
	_set_biome(GameState.biome_id)
	set_currencies(GameState.economy.credits, GameState.economy.crystals)
	_on_cargo_changed(GameState.economy.cargo_count(), GameState.economy.cargo_value())


# --- API usada pelo InputController -------------------------------------------------

## Pontos sobre a barra superior não devem virar comandos de perfuração.
func is_point_blocking(p: Vector2) -> bool:
	return _top.get_global_rect().has_point(p) or (_done_panel.visible and _done_panel.get_global_rect().has_point(p))


## Botões de toque do HUD (hoje só o impulso); vazio = área do joystick.
func pad_action_at(p: Vector2) -> StringName:
	for pad in _pads:
		if pad.visible and pad.get_global_rect().grow(10.0).has_point(p):
			return pad.kind
	return &""


func show_joystick(base: Vector2, knob: Vector2) -> void:
	_joystick.show_at(base, knob)


func hide_joystick() -> void:
	_joystick.hide_stick()


func set_pad_pressed(pressed: Dictionary) -> void:
	for pad in _pads:
		pad.pressed = pressed.has(pad.kind)


## Retângulo (coordenadas de tela) livre para a escavação.
func dig_area() -> Rect2:
	var vp: Vector2 = _root.get_viewport_rect().size
	var top: float = _top.get_global_rect().end.y
	return Rect2(0, top, vp.x, vp.y - top - _safe_bottom)


# --- Construção ---------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = UiTheme.get_theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Tinta de calor (atrás do restante do HUD).
	_heat_tint = ColorRect.new()
	_heat_tint.color = Color(1.0, 0.35, 0.1, 0.0)
	_heat_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heat_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_heat_tint)

	_vignette = ColorRect.new()
	_vignette.name = "AlertVignette"
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vm := ShaderMaterial.new()
	vm.shader = load("res://shaders/vignette.gdshader") as Shader
	_vignette.material = vm
	_root.add_child(_vignette)

	_joystick = VirtualJoystick.new()
	_joystick.name = "Joystick"
	_root.add_child(_joystick)

	# Barra superior.
	_top = PanelContainer.new()
	_top.name = "TopBar"
	_top.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_top)
	var top_v := VBoxContainer.new()
	top_v.add_theme_constant_override("separation", 6)
	_top.add_child(top_v)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	top_v.add_child(row)

	var depth_box := VBoxContainer.new()
	depth_box.add_theme_constant_override("separation", -4)
	depth_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(depth_box)
	_depth_label = UiTheme.label("0 m", UiTheme.FONT_BIG, UiTheme.TEXT, 700)
	depth_box.add_child(_depth_label)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 14)
	depth_box.add_child(sub)
	_biome_label = UiTheme.label("Crosta", UiTheme.FONT_SMALL, UiTheme.ACCENT, 700)
	sub.add_child(_biome_label)
	_max_label = _label("máx 0 m", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	sub.add_child(_max_label)
	_heat_label = _label("", UiTheme.FONT_SMALL, Color("ff8a4a"))
	_heat_label.visible = false
	sub.add_child(_heat_label)

	var money := VBoxContainer.new()
	money.add_theme_constant_override("separation", 6)
	money.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(money)
	var cbox: Array = UiTheme.currency_box(Economy.CREDITS)
	(cbox[0] as Control).custom_minimum_size = Vector2(190, 0)
	money.add_child(cbox[0])
	_credits_label = cbox[1]
	var kbox: Array = UiTheme.currency_box(Economy.CRYSTALS)
	(kbox[0] as Control).custom_minimum_size = Vector2(190, 0)
	money.add_child(kbox[0])
	_crystals_label = kbox[1]

	var energy_row := HBoxContainer.new()
	energy_row.add_theme_constant_override("separation", 10)
	top_v.add_child(energy_row)
	energy_row.add_child(UiTheme.label("ENERGIA", UiTheme.FONT_SMALL, UiTheme.BLUE, 700))
	_energy_bar = SegmentedBar.new(10, UiTheme.BLUE, 30.0)
	_energy_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy_row.add_child(_energy_bar)
	_extract_button = Button.new()
	_extract_button.name = "ExtractButton"
	_extract_button.text = UiTheme.display_text("EXTRAIR")
	_extract_button.icon = PixelArt.icon(&"extract")
	_extract_button.add_theme_constant_override("icon_max_width", 34)
	_extract_button.custom_minimum_size = Vector2(230, 60)
	_extract_button.add_theme_font_size_override("font_size", UiTheme.font_size(UiTheme.FONT_SMALL, 700))
	UiTheme.style_button(_extract_button, &"gold")
	_extract_button.pressed.connect(func() -> void: extract_requested.emit())
	energy_row.add_child(_extract_button)

	# Combustível, casco e calor.
	var vit := HBoxContainer.new()
	vit.add_theme_constant_override("separation", 8)
	top_v.add_child(vit)
	vit.add_child(UiTheme.icon_rect(&"fuel", 34))
	_fuel_bar = SegmentedBar.new(10, Color("ffb347"), 26.0)
	_fuel_bar.name = "FuelBar"
	_fuel_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fuel_bar.size_flags_stretch_ratio = 1.4
	_fuel_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vit.add_child(_fuel_bar)
	_fuel_label = _label("100%", UiTheme.FONT_SMALL, Color("ffb347"))
	_fuel_label.custom_minimum_size = Vector2(62, 0)
	vit.add_child(_fuel_label)
	vit.add_child(UiTheme.icon_rect(&"hull", 34))
	_hull_bar = SegmentedBar.new(6, UiTheme.GREEN, 26.0)
	_hull_bar.name = "HullBar"
	_hull_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hull_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vit.add_child(_hull_bar)
	_heat_icon = UiTheme.icon_rect(&"heat", 34)
	vit.add_child(_heat_icon)
	_heat_value = _label("0.0", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	_heat_value.name = "HeatValue"
	_heat_value.custom_minimum_size = Vector2(58, 0)
	vit.add_child(_heat_value)

	# Botão de impulso (canto inferior direito). O restante da tela é área do joystick.
	_boost = PadButton.new(&"boost", &"boost", "0%", &"blue")
	_boost.name = "BoostButton"
	_boost.size_flags_horizontal = Control.SIZE_SHRINK_END
	_root.add_child(_boost)
	_pads.append(_boost)
	_sonar = PadButton.new(&"sonar", &"sonar", "SONAR", &"green")
	_sonar.name = "SonarButton"
	_root.add_child(_sonar)
	_pads.append(_sonar)

	_hint = _label("Arraste o dedo em qualquer direção (menos para cima)\ne desenhe o seu próprio túnel.", UiTheme.FONT_SMALL, UiTheme.TEXT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_hint)

	_banner = _label("", 44, UiTheme.TEXT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.modulate.a = 0.0
	_root.add_child(_banner)

	_warn = UiTheme.label("", 34, UiTheme.RED, 700)
	_warn.name = "Warning"
	_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warn.add_theme_constant_override("outline_size", 8)
	_warn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_warn.visible = false
	_root.add_child(_warn)

	# Guardião: nome e barra de vida (só na arena).
	_boss = PanelContainer.new()
	_boss.name = "GuardianBar"
	_boss.add_theme_stylebox_override("panel", PixelArt.style(&"frame"))
	_boss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss.visible = false
	_root.add_child(_boss)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	_boss.add_child(bv)
	_boss_name = UiTheme.label("", 26, UiTheme.RED, 700)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_boss_name)
	_boss_bar = SegmentedBar.new(20, UiTheme.RED, 24.0)
	_boss_bar.name = "GuardianHp"
	bv.add_child(_boss_bar)

	# Região concluída: voltar à base (extração com toda a carga) ou continuar.
	_done_panel = PanelContainer.new()
	_done_panel.name = "RegionDonePanel"
	_done_panel.add_theme_stylebox_override("panel", PixelArt.style(&"frame"))
	_done_panel.visible = false
	_root.add_child(_done_panel)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 14)
	_done_panel.add_child(dv)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", PixelArt.style(&"plate"))
	dv.add_child(plate)
	var title := UiTheme.label("REGIÃO CONCLUÍDA!", 36, Color("2a1606"), 700)
	title.add_theme_constant_override("outline_size", 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(title)
	_done_text = UiTheme.label("", 25, UiTheme.TEXT, 500)
	_done_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_done_text.custom_minimum_size = Vector2(300, 0)
	_done_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dv.add_child(_done_text)
	var back := Button.new()
	back.name = "DoneBaseButton"
	back.text = UiTheme.display_text("VOLTAR À BASE")
	back.icon = PixelArt.icon(&"extract")
	back.add_theme_constant_override("icon_max_width", 40)
	back.custom_minimum_size = Vector2(0, 90)
	back.add_theme_font_size_override("font_size", UiTheme.font_size(32, 700))
	UiTheme.style_button(back, &"green")
	back.pressed.connect(func() -> void:
		_done_panel.visible = false
		extract_requested.emit())
	dv.add_child(back)
	var stay := Button.new()
	stay.name = "DoneStayButton"
	stay.text = UiTheme.display_text("CONTINUAR AQUI")
	stay.custom_minimum_size = Vector2(0, 70)
	stay.add_theme_font_size_override("font_size", UiTheme.font_size(24, 700))
	UiTheme.style_button(stay, &"steel")
	stay.pressed.connect(func() -> void: _done_panel.visible = false)
	dv.add_child(stay)

	_fps_label = _label("", 18, UiTheme.TEXT_DIM)
	_fps_label.visible = OS.is_debug_build()
	_root.add_child(_fps_label)

	# Configurações (0.16): engrenagem logo abaixo do painel, à direita.
	_gear = UiTheme.gear_button()
	_gear.pressed.connect(func() -> void: settings_requested.emit())
	_root.add_child(_gear)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _currency_row(parent: Control, color: Color, tooltip: String) -> Label:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.alignment = BoxContainer.ALIGNMENT_END
	h.tooltip_text = tooltip
	parent.add_child(h)
	var value := _label("0", UiTheme.FONT_NORMAL, color)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size = Vector2(120, 0)
	h.add_child(value)
	h.add_child(GemIcon.new(color))
	return value


func _apply_layout() -> void:
	var vp: Vector2 = _root.get_viewport_rect().size
	var safe: Vector4 = SafeArea.insets(get_viewport())
	_safe_top = safe.x
	_safe_bottom = safe.y
	var left: float = safe.z + SIDE_MARGIN
	var right: float = vp.x - safe.w - SIDE_MARGIN
	# Painel de cima: largura limitada e centralizado (tablets e telas largas).
	var top_w: float = minf(right - left + SIDE_MARGIN, SafeArea.MAX_CONTENT_W)
	_top.position = Vector2((left + right - top_w) * 0.5, _safe_top + 8.0)
	_top.size = Vector2(top_w, TOP_HEIGHT - 16.0)
	_boost.size = Vector2(BOOST_SIZE, BOOST_SIZE)
	_boost.position = Vector2(right - BOOST_SIZE, vp.y - _safe_bottom - BOOST_SIZE - SIDE_MARGIN)
	_sonar.size = Vector2(BOOST_SIZE * 0.85, BOOST_SIZE * 0.85)
	_sonar.position = Vector2(left, vp.y - _safe_bottom - _sonar.size.y - SIDE_MARGIN)
	_joystick.rest_pos = Vector2((left + right) * 0.5, vp.y - _safe_bottom - Balance.JOYSTICK_RADIUS_PX - 60.0)
	_joystick.queue_redraw()
	_hint.position = Vector2(left, _joystick.rest_pos.y - Balance.JOYSTICK_RADIUS_PX - 110.0)
	_hint.size = Vector2(right - left, 80)
	_banner.position = Vector2(left, vp.y * 0.36)
	_banner.size = Vector2(right - left, 120)
	_fps_label.position = Vector2(left, _top.position.y + _top.size.y + 6.0)
	_gear.size = _gear.custom_minimum_size
	_gear.position = Vector2(right - _gear.size.x, _top.position.y + _top.size.y + 8.0)
	_warn.position = Vector2(left, _top.position.y + _top.size.y + 14.0)
	_warn.size = Vector2(right - left, 44)
	_boss.position = Vector2(left + SIDE_MARGIN, _warn.position.y + 52.0)
	_boss.size = Vector2(minf(right - left - SIDE_MARGIN * 2.0, SafeArea.MAX_CONTENT_W - 40.0), 0)
	_boss.position.x = (left + right - _boss.size.x) * 0.5
	var done_w: float = minf(right - left - 40.0, SafeArea.MAX_CONTENT_W - 80.0)
	_done_panel.size = Vector2(done_w, 0)
	_done_panel.position = Vector2((left + right - done_w) * 0.5, vp.y * 0.3)


# --- Atualizações -------------------------------------------------------------------

func _process(delta: float) -> void:
	if drill != null:
		var e: EnergySystem = drill.energy
		set_energy(e.energy, e.max_energy)
		var ready: bool = e.is_ready()
		var glow: float = 1.25 + 0.35 * sin(Time.get_ticks_msec() * 0.012)
		_energy_bar.glow = ready or e.is_boosting()
		_energy_bar.modulate = Color(glow, glow, glow) if ready else Color.WHITE
		_boost.modulate = Color(glow, glow, glow) if ready else Color(1, 1, 1, 1.0 if e.is_boosting() else 0.5)
		if e.is_boosting():
			_boost.text = "%.1fs" % e.boost_left
		elif ready:
			_boost.text = "SOBRECARGA"
		else:
			_boost.text = "%d%%" % int(e.fill_ratio() * 100.0)
		if sonar != null:
			var ready_s: bool = sonar.is_ready()
			_sonar.text = "SONAR" if ready_s else "%ds" % ceili(sonar.cooldown)
			_sonar.modulate = Color(1.15 + 0.15 * sin(Time.get_ticks_msec() * 0.008), 1.2, 1.15) if ready_s else Color(1, 1, 1, 0.55)
		_set_heat(drill.depth_m(), drill.heat_penalty)
		_update_vitals(delta)
		_update_guardian()
	if _banner_t > 0.0:
		_banner_t -= delta
		var k: float = _banner_t / BANNER_TIME
		_banner.modulate.a = clampf(minf(k * 4.0, (1.0 - k) * 6.0), 0.0, 1.0)
	if _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if _hint_time > 0.0:
		_hint_time -= delta
		_hint.modulate.a = clampf(_hint_time / 0.6, 0.0, 1.0)
		if _hint_time <= 0.0:
			_hint.visible = false


## Esconde a dica de "arraste o dedo" (o tutorial explica do jeito dele).
func hide_hint() -> void:
	_hint.visible = false


func _dismiss_hint() -> void:
	if _hint.visible and _hint_time <= 0.0 and GameState.blocks_broken >= 3:
		_hint_time = 0.6


func _on_depth_changed(depth_m: int, max_depth_m: int) -> void:
	_depth_label.text = "%d m" % depth_m
	_max_label.text = "máx %d m" % max_depth_m


func _on_biome_changed(biome_id: int) -> void:
	var was: String = _biome_label.text
	_set_biome(biome_id)
	if was != "" and was != _biome_label.text and GameState.depth_m > 0:
		_show_banner(_biome_label.text.to_upper(), BiomeRegistry.get_def(biome_id).ui_color)


func _on_final_chamber(region_id: StringName, alive: bool) -> void:
	if not alive:
		_show_banner(("CÂMARA FINAL: " + RegionRegistry.get_def(region_id).final_name).to_upper(), PixelArt.GOLD)


func _update_guardian() -> void:
	var show: bool = guardian != null and guardian.alive and guardian.in_arena(drill.position)
	_boss.visible = show
	if show:
		_boss_name.text = UiTheme.display_text(guardian.region.guardian_name.to_upper())
		_boss_bar.value = guardian.hp_ratio()
		_boss.modulate = Color(1.4, 1.4, 1.4) if guardian.danger() and int(Time.get_ticks_msec() / 110) % 2 == 0 else Color.WHITE


var _weak_t: float = 0.0


## Minério duro demais: avisa qual nível de Broca é preciso (no máximo a cada 2 s).
func _on_too_weak(block_id: int) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _weak_t < 2.0:
		return
	_weak_t = now
	var tier: int = MiningRules.required_tier(block_id)
	var lvl: int = Balance.DRILL_TIER_LEVELS[tier]
	var name: String = BlockRegistry.get_def(block_id).display_name
	_show_banner(("BROCA FRACA PARA %s · BROCA NV. %d" % [name, lvl]).to_upper(), UiTheme.ORANGE)


func _on_combat(active: bool) -> void:
	_combat = active
	if active:
		_show_banner("COMBATE!", UiTheme.RED)
		_hint.visible = false


## Guardião vencido: painel com a saída (extração com toda a carga) e o que foi liberado.
func show_region_complete(region: RegionDef, unlocked_name: String) -> void:
	var txt: String = "Você venceu %s!" % region.guardian_name
	if unlocked_name != "":
		txt += "\nNova região liberada: %s." % unlocked_name
	txt += "\nVolte à base com toda a carga."
	_done_text.text = txt
	_done_panel.visible = true


func is_region_complete_open() -> bool:
	return _done_panel.visible


## Aviso grande no centro (resgate, objetivo, câmara final...).
func show_alert(text: String, color: Color) -> void:
	_show_banner(text, color)


func _show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_t = BANNER_TIME


func _set_biome(biome_id: int) -> void:
	var biome: BiomeDef = BiomeRegistry.get_def(biome_id)
	_biome_label.text = biome.display_name
	_biome_label.tooltip_text = GameState.region().display_name
	_biome_label.add_theme_color_override("font_color", biome.ui_color)


## Calor: a perda de eficiência aparece no aviso de superaquecimento (0.19), que tem
## espaço; aqui fica só o tom avermelhado da tela.
func _set_heat(_depth_m: int, penalty: float) -> void:
	_heat_label.visible = false
	_heat_tint.color.a = penalty * 0.3


func _on_cargo_changed(_count: int, _value: int) -> void:
	pass


## Barras de combustível/casco/calor e alertas (vinheta + aviso piscando).
## Prioridade: dano no casco > combustível crítico > calor > combustível baixo.
func _update_vitals(delta: float) -> void:
	_t += delta
	var v: ShipVitals = drill.vitals
	var fr: float = v.fuel_ratio()
	_fuel_bar.value = fr
	_fuel_label.text = "%d%%" % ceili(fr * 100.0)
	# Sobrecarga gasta o dobro: o combustível mostra "×2" e pisca em laranja.
	if drill.energy.is_boosting():
		_fuel_label.text += " ×2"
		_fuel_label.add_theme_color_override("font_color", Color("ffb347").lerp(UiTheme.RED, 0.5 + 0.5 * sin(_t * 12.0)))
	else:
		_fuel_label.add_theme_color_override("font_color", Color("ffb347"))
	_hull_bar.value = v.hull_ratio()
	_hull_bar.color = UiTheme.GREEN if v.hull_ratio() > 0.5 else (Color("ffb347") if v.hull_ratio() > 0.25 else UiTheme.RED)
	# Termômetro em °C: cinza com folga, laranja perto do limite, vermelho acima.
	var temp: float = HeatRules.temp_at(drill.depth_m())
	var limit: float = drill.stats.temp_limit
	var near: bool = temp >= limit - Balance.TEMP_WARN_MARGIN
	var hot: bool = temp > limit
	_heat_value.text = "%d°" % roundi(temp)
	var heat_col: Color = UiTheme.RED if hot else (Color("ffb347") if near else UiTheme.TEXT_DIM)
	_heat_value.add_theme_color_override("font_color", heat_col)
	_heat_icon.modulate = Color.WHITE if near else Color(1, 1, 1, 0.55)
	var tint := Color.BLACK
	var strength: float = 0.0
	var text: String = ""
	var color: Color = UiTheme.RED
	var blink: float = 0.5 + 0.5 * sin(_t * 9.0)
	_hit_flash = maxf(0.0, _hit_flash - delta * 2.5)
	if _hit_flash > 0.0:
		tint = Color(1.0, 0.1, 0.05)
		strength = 0.3 + 0.5 * _hit_flash
		text = "CASCO ATINGIDO!"
	elif drill.strain > 1.0:
		tint = Color(1.0, 0.25, 0.05)
		strength = 0.4 + 0.3 * blink
		text = "BROCA SUPERAQUECIDA! PARE DE FORÇAR"
	elif drill.strain > 0.35:
		tint = Color(1.0, 0.5, 0.1)
		strength = 0.15 + 0.25 * drill.strain
		text = "BROCA ESQUENTANDO %d%%" % roundi(drill.strain * 100.0)
		color = Color("ffb347")
	elif v.hull_dps > 0.0:
		tint = Color(1.0, 0.12, 0.05)
		strength = 0.35 + 0.25 * blink
		text = "SUPERAQUECENDO %d°/%d°\nBROCA −%.0f%%  ·  CASCO −%.0f/s" % [roundi(temp), roundi(limit), drill.heat_penalty * 100.0, v.hull_dps]
	elif fr <= Balance.FUEL_CRITICAL_RATIO:
		tint = Color(1.0, 0.12, 0.04)
		strength = 0.45 + 0.35 * blink
		text = "COMBUSTÍVEL CRÍTICO!"
		color = Color("ff8a3a")
	elif near:
		# Perto do limite térmico: aviso antes de começar a ferir o casco.
		tint = Color(1.0, 0.45, 0.1)
		strength = 0.12 + 0.05 * sin(_t * 2.0)
		text = "QUENTE %d° · LIMITE %d°" % [roundi(temp), roundi(limit)]
		color = Color("ffb347")
	elif fr <= Balance.FUEL_LOW_RATIO:
		tint = Color(1.0, 0.65, 0.1)
		strength = 0.22 + 0.16 * (0.5 + 0.5 * sin(_t * 4.0))
		text = "COMBUSTÍVEL BAIXO"
		color = Color("ffc24a")
	elif _combat:
		# Modo de combate: bordas avermelhadas, pulsando devagar.
		tint = Color(0.8, 0.05, 0.08)
		strength = 0.16 + 0.06 * sin(_t * 3.0)
	var mat := _vignette.material as ShaderMaterial
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("strength", strength)
	_warn.visible = text != ""
	if _warn.visible:
		_warn.text = UiTheme.display_text(text)
		_warn.add_theme_color_override("font_color", color)
		_warn.modulate.a = 0.55 + 0.45 * blink if strength > 0.3 else 1.0
	# A barra de combustível pisca quando está baixa; o botão EXTRAIR chama atenção.
	_fuel_bar.modulate = Color(1, 1, 1, 0.45 + 0.55 * blink) if fr <= Balance.FUEL_LOW_RATIO else Color.WHITE
	_extract_button.modulate = Color(1.0 + 0.3 * blink, 1.0 + 0.3 * blink, 1.0 + 0.3 * blink) if fr <= Balance.FUEL_LOW_RATIO else Color.WHITE


func set_currencies(credits: int, crystals: int) -> void:
	_credits_label.text = str(credits)
	_crystals_label.text = str(crystals)


func set_energy(value: float, max_value: float) -> void:
	_energy_bar.value = value / max_value if max_value > 0.0 else 0.0
