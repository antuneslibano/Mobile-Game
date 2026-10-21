class_name Hud
extends CanvasLayer
## HUD: barra superior (profundidade, moedas, energia, calor, garagem), joystick flutuante e
## botão de impulso. Apenas exibe estado e expõe áreas de toque; não altera regras de jogo.

signal garage_requested

const TOP_HEIGHT: float = 170.0
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
var _energy_bar: ProgressBar
var _garage_button: Button
var _heat_label: Label
var _heat_tint: ColorRect
var _boost: PadButton
var _joystick: VirtualJoystick
var _banner: Label
var _banner_t: float = 0.0
var _hint: Label
var _fps_label: Label
var _pads: Array[PadButton] = []
var _safe_top: float = 0.0
var _safe_bottom: float = 0.0
var _hint_time: float = 0.0
## Perfuradora observada (somente leitura) para energia, impulso e calor.
var drill: Drill


func _ready() -> void:
	_build()
	EventBus.depth_changed.connect(_on_depth_changed)
	EventBus.biome_changed.connect(_on_biome_changed)
	EventBus.material_dug.connect(func(_a: Vector2, _c: Dictionary) -> void: _dismiss_hint())
	EventBus.overdrive_ready.connect(func() -> void: _show_banner("SOBRECARGA PRONTA", UiTheme.BLUE))
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
	return _top.get_global_rect().has_point(p)


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
	_depth_label = _label("0 m", UiTheme.FONT_BIG, UiTheme.TEXT)
	depth_box.add_child(_depth_label)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 14)
	depth_box.add_child(sub)
	_biome_label = _label("Crosta", UiTheme.FONT_SMALL, UiTheme.ACCENT)
	sub.add_child(_biome_label)
	_max_label = _label("máx 0 m", UiTheme.FONT_SMALL, UiTheme.TEXT_DIM)
	sub.add_child(_max_label)
	_heat_label = _label("", UiTheme.FONT_SMALL, Color("ff8a4a"))
	_heat_label.visible = false
	sub.add_child(_heat_label)

	var money := VBoxContainer.new()
	money.add_theme_constant_override("separation", 2)
	money.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(money)
	_credits_label = _currency_row(money, UiTheme.CREDITS, "Créditos")
	_crystals_label = _currency_row(money, UiTheme.CRYSTALS, "Cristais")

	var energy_row := HBoxContainer.new()
	energy_row.add_theme_constant_override("separation", 10)
	top_v.add_child(energy_row)
	energy_row.add_child(_label("ENERGIA", UiTheme.FONT_SMALL, UiTheme.BLUE))
	_energy_bar = ProgressBar.new()
	_energy_bar.max_value = 100.0
	_energy_bar.value = 100.0
	_energy_bar.show_percentage = false
	_energy_bar.custom_minimum_size = Vector2(0, 22)
	_energy_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_energy_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_row.add_child(_energy_bar)
	_garage_button = Button.new()
	_garage_button.name = "GarageButton"
	_garage_button.text = "GARAGEM"
	_garage_button.custom_minimum_size = Vector2(210, 52)
	_garage_button.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
	_garage_button.focus_mode = Control.FOCUS_NONE
	UiTheme.accent_button(_garage_button)
	_garage_button.pressed.connect(func() -> void: garage_requested.emit())
	energy_row.add_child(_garage_button)

	# Botão de impulso (canto inferior direito). O restante da tela é área do joystick.
	_boost = PadButton.new(&"boost", PadButton.Icon.BOOST, "0%", UiTheme.BLUE)
	_boost.name = "BoostButton"
	_boost.size_flags_horizontal = Control.SIZE_SHRINK_END
	_root.add_child(_boost)
	_pads.append(_boost)

	_hint = _label("Arraste o dedo em qualquer direção (menos para cima)\ne desenhe o seu próprio túnel.", UiTheme.FONT_SMALL, UiTheme.TEXT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hint)

	_banner = _label("", 44, UiTheme.TEXT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.modulate.a = 0.0
	_root.add_child(_banner)

	_fps_label = _label("", 18, UiTheme.TEXT_DIM)
	_fps_label.visible = OS.is_debug_build()
	_root.add_child(_fps_label)


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
	_compute_safe_area(vp)
	_top.position = Vector2(SIDE_MARGIN * 0.5, _safe_top + 8.0)
	_top.size = Vector2(vp.x - SIDE_MARGIN, TOP_HEIGHT - 16.0)
	_boost.size = Vector2(BOOST_SIZE, BOOST_SIZE)
	_boost.position = Vector2(vp.x - BOOST_SIZE - SIDE_MARGIN, vp.y - _safe_bottom - BOOST_SIZE - SIDE_MARGIN)
	_joystick.rest_pos = Vector2(vp.x * 0.5, vp.y - _safe_bottom - Balance.JOYSTICK_RADIUS_PX - 60.0)
	_joystick.queue_redraw()
	_hint.position = Vector2(0, _joystick.rest_pos.y - Balance.JOYSTICK_RADIUS_PX - 110.0)
	_hint.size = Vector2(vp.x, 80)
	_banner.position = Vector2(0, vp.y * 0.36)
	_banner.size = Vector2(vp.x, 70)
	_fps_label.position = Vector2(SIDE_MARGIN, _top.position.y + _top.size.y + 6.0)


func _compute_safe_area(vp: Vector2) -> void:
	_safe_top = 0.0
	_safe_bottom = 0.0
	if not OS.has_feature("mobile"):
		return
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if win.x <= 0.0 or win.y <= 0.0:
		return
	var scale: float = vp.y / win.y
	_safe_top = maxf(0.0, float(safe.position.y)) * scale
	_safe_bottom = maxf(0.0, win.y - float(safe.end.y)) * scale


# --- Atualizações -------------------------------------------------------------------

func _process(delta: float) -> void:
	if drill != null:
		var e: EnergySystem = drill.energy
		set_energy(e.energy, e.max_energy)
		var ready: bool = e.is_ready()
		var glow: float = 1.25 + 0.35 * sin(Time.get_ticks_msec() * 0.012)
		_energy_bar.modulate = Color(glow, glow, glow * 1.1) if (ready or e.is_boosting()) else Color.WHITE
		_boost.modulate = Color(glow, glow, glow) if ready else Color(1, 1, 1, 1.0 if e.is_boosting() else 0.5)
		if e.is_boosting():
			_boost.text = "%.1fs" % e.boost_left
		elif ready:
			_boost.text = "SOBRECARGA"
		else:
			_boost.text = "%d%%" % int(e.fill_ratio() * 100.0)
		_set_heat(drill.depth_m(), drill.heat_penalty)
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


func _show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_t = BANNER_TIME


func _set_biome(biome_id: int) -> void:
	var biome: BiomeDef = BiomeRegistry.get_def(biome_id)
	_biome_label.text = biome.display_name
	_biome_label.add_theme_color_override("font_color", biome.ui_color)


func _set_heat(depth_m: int, penalty: float) -> void:
	var heat: float = HeatRules.heat_at(depth_m)
	_heat_label.visible = heat > 0.0
	if heat > 0.0:
		_heat_label.text = "calor %.1f · −%.0f%%" % [heat, penalty * 100.0]
	_heat_tint.color.a = penalty * 0.45


func _on_cargo_changed(count: int, value: int) -> void:
	_garage_button.text = "GARAGEM" if count == 0 else "GARAGEM  +%d" % value


func set_currencies(credits: int, crystals: int) -> void:
	_credits_label.text = str(credits)
	_crystals_label.text = str(crystals)


func set_energy(value: float, max_value: float) -> void:
	_energy_bar.max_value = max_value
	_energy_bar.value = value
