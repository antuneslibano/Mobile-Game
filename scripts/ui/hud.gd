class_name Hud
extends CanvasLayer
## HUD: barra superior (profundidade, moedas, energia, garagem) e controles inferiores.
## Apenas exibe estado e expõe áreas de toque; não altera regras de jogo.

signal garage_requested

const TOP_HEIGHT: float = 170.0
const BOTTOM_HEIGHT: float = 200.0
const SIDE_MARGIN: float = 20.0

var _root: Control
var _top: PanelContainer
var _depth_label: Label
var _max_label: Label
var _biome_label: Label
var _credits_label: Label
var _crystals_label: Label
var _energy_bar: ProgressBar
var _garage_button: Button
var _bottom: HBoxContainer
var _hint: Label
var _fps_label: Label
var _pads: Array[PadButton] = []
var _safe_top: float = 0.0
var _safe_bottom: float = 0.0
var _hint_time: float = 0.0


func _ready() -> void:
	_build()
	EventBus.depth_changed.connect(_on_depth_changed)
	EventBus.biome_changed.connect(_on_biome_changed)
	EventBus.block_destroyed.connect(func(_c: Vector2i, _id: int, _d: Dictionary) -> void: _dismiss_hint())
	EventBus.wallet_changed.connect(set_currencies)
	EventBus.cargo_changed.connect(_on_cargo_changed)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	_on_depth_changed(GameState.depth_m, GameState.max_depth_m)
	_on_biome_changed(GameState.biome_id)
	set_currencies(GameState.economy.credits, GameState.economy.crystals)
	_on_cargo_changed(GameState.economy.cargo_count(), GameState.economy.cargo_value())


# --- API usada pelo InputController -------------------------------------------------

## Pontos sobre a barra superior não devem virar comandos de perfuração.
func is_point_blocking(p: Vector2) -> bool:
	return _top.get_global_rect().has_point(p)


func pad_action_at(p: Vector2) -> StringName:
	for pad in _pads:
		if pad.visible and pad.get_global_rect().grow(8.0).has_point(p):
			return pad.kind
	return &""


func set_pad_pressed(pressed: Dictionary) -> void:
	for pad in _pads:
		pad.pressed = pressed.has(pad.kind)


## Retângulo (coordenadas de tela) livre para a escavação.
func dig_area() -> Rect2:
	var vp: Vector2 = _root.get_viewport_rect().size
	var top: float = _top.get_global_rect().end.y
	var bottom: float = _bottom.get_global_rect().position.y
	return Rect2(0, top, vp.x, bottom - top)


# --- Construção ---------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = UiTheme.get_theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

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

	# Controles inferiores.
	_bottom = HBoxContainer.new()
	_bottom.name = "BottomPad"
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_theme_constant_override("separation", 14)
	_root.add_child(_bottom)
	_add_pad(&"left", PadButton.Icon.LEFT, "", UiTheme.ACCENT, 1.0)
	_add_pad(&"drill", PadButton.Icon.DRILL, "PERFURAR", UiTheme.ACCENT, 1.7)
	_add_pad(&"right", PadButton.Icon.RIGHT, "", UiTheme.ACCENT, 1.0)

	_hint = _label("Segure na tela para perfurar\nArraste para os lados para mover", UiTheme.FONT_SMALL, UiTheme.TEXT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hint)

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


func _add_pad(kind: StringName, icon: PadButton.Icon, text: String, accent: Color, ratio: float) -> void:
	var pad := PadButton.new(kind, icon, text, accent)
	pad.name = "Pad_" + String(kind)
	pad.size_flags_stretch_ratio = ratio
	_bottom.add_child(pad)
	_pads.append(pad)


func _apply_layout() -> void:
	var vp: Vector2 = _root.get_viewport_rect().size
	_compute_safe_area(vp)
	_top.position = Vector2(SIDE_MARGIN * 0.5, _safe_top + 8.0)
	_top.size = Vector2(vp.x - SIDE_MARGIN, TOP_HEIGHT - 16.0)
	_bottom.position = Vector2(SIDE_MARGIN, vp.y - _safe_bottom - BOTTOM_HEIGHT)
	_bottom.size = Vector2(vp.x - SIDE_MARGIN * 2.0, BOTTOM_HEIGHT - SIDE_MARGIN)
	_hint.position = Vector2(0, _bottom.position.y - 110.0)
	_hint.size = Vector2(vp.x, 80)
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
	var biome: BiomeDef = BiomeRegistry.get_def(biome_id)
	_biome_label.text = biome.display_name
	_biome_label.add_theme_color_override("font_color", biome.ui_color)


func _on_cargo_changed(count: int, value: int) -> void:
	_garage_button.text = "GARAGEM" if count == 0 else "GARAGEM  +%d" % value


func set_currencies(credits: int, crystals: int) -> void:
	_credits_label.text = str(credits)
	_crystals_label.text = str(crystals)


func set_energy(value: float, max_value: float) -> void:
	_energy_bar.max_value = max_value
	_energy_bar.value = value
