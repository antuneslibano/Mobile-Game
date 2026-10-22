class_name BaseScreen
extends CanvasLayer
## Base de pesquisa (0.10): o hub entre expedições. Um galpão em pixel art com cinco
## estações tocáveis (sem personagem andando):
##   Mesa de mapas (regiões e expedição), Laboratório (catálogo e diário),
##   Bancada (construir peças), Hangar (nave e módulos) e Mercado (vender excedente).
## Cada estação tem placa com nome e um alerta "!" quando há algo novo (peça que dá para
## construir, excedente para vender, entrada nova no diário, módulo sem uso). O botão
## EXPEDIÇÃO abre a mesa de mapas. Pausa o jogo enquanto aberta. Só lê o estado; quem
## escuta station_requested (Main) abre as telas.

signal station_requested(kind: StringName)

const ART: float = 4.0
const STATIONS: Array[StringName] = [&"map", &"lab", &"bench", &"hangar", &"market"]
const NAMES: Dictionary = {&"map": "MESA DE MAPAS", &"lab": "LABORATÓRIO", &"bench": "BANCADA", &"hangar": "HANGAR", &"market": "MERCADO"}

var _root: Control
var _view: BaseView
var _credits: Label
var _crystals: Label
var _buttons: Dictionary = {}    ## kind → Button
var _plates: Dictionary = {}     ## kind → PanelContainer
var _badges: Dictionary = {}     ## kind → Label
var _expedition: Button
var _notice: Label


func _ready() -> void:
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	EventBus.wallet_changed.connect(func(_c: int, _k: int) -> void: _refresh())
	EventBus.cargo_changed.connect(func(_n: int, _v: int) -> void: _refresh())
	get_viewport().size_changed.connect(_layout)


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	get_tree().paused = true
	_view.region = GameState.region()
	_layout()
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false


## Alerta de cada estação (também usado pelos testes).
func has_badge(kind: StringName) -> bool:
	var econ: Economy = GameState.economy
	match kind:
		&"bench":
			for u in UpgradeRegistry.all():
				if Progression.buy_status(econ, u) == Progression.BuyStatus.OK:
					return true
			return false
		&"market":
			var reserve: Dictionary = Recipes.reserve(econ.upgrade_levels)
			for k: StringName in econ.cargo:
				if int(econ.cargo[k]) > int(reserve.get(k, 0)):
					return true
			return false
		&"lab":
			return Journal.unlocked(econ.discovered, GameState.done, GameState.creatures).size() > GameState.journal_seen
		&"hangar":
			if ShipLooks.unlocked_count(econ, GameState.done) > GameState.looks_seen:
				return true
			for id in ModuleSystem.ALL:
				if econ.owns_module(id) and not econ.equipped_modules.has(id) and econ.equipped_modules.size() < Balance.MODULE_SLOTS:
					return true
			return false
		&"map":
			return GameState.pending_notice != ""
	return false


func press(kind: StringName) -> void:
	station_requested.emit(kind)


# --- Construção ----------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color("0b0e16")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)
	_view = BaseView.new()
	_view.name = "View"
	_root.add_child(_view)

	for kind in STATIONS:
		var b := Button.new()
		b.name = "Station_" + String(kind)
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for st: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.pressed.connect(func() -> void: press(kind))
		b.button_down.connect(func() -> void: _view.pressed_kind = kind)
		b.button_up.connect(func() -> void: _view.pressed_kind = &"")
		_root.add_child(b)
		_buttons[kind] = b
		var plate := PanelContainer.new()
		plate.add_theme_stylebox_override("panel", PixelArt.style(&"plate"))
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := UiTheme.label(NAMES[kind], 22, Color("2a1606"), 700)
		l.add_theme_constant_override("outline_size", 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plate.add_child(l)
		_root.add_child(plate)
		_plates[kind] = plate
		var badge := UiTheme.label("!", 30, Color.WHITE, 700)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_stylebox_override("normal", PixelArt.style(&"red"))
		badge.custom_minimum_size = Vector2(44, 44)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.visible = false
		_root.add_child(badge)
		_badges[kind] = badge

	# Cabeçalho: título e moedas.
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	_root.add_child(header)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", PixelArt.style(&"plate"))
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(plate)
	var title := UiTheme.label("BASE DE PESQUISA", 32, Color("2a1606"), 700)
	title.add_theme_constant_override("outline_size", 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(title)
	var cbox: Array = UiTheme.currency_box(Economy.CREDITS)
	(cbox[0] as Control).custom_minimum_size = Vector2(170, 0)
	header.add_child(cbox[0])
	_credits = cbox[1]
	var kbox: Array = UiTheme.currency_box(Economy.CRYSTALS)
	(kbox[0] as Control).custom_minimum_size = Vector2(110, 0)
	header.add_child(kbox[0])
	_crystals = kbox[1]

	_notice = UiTheme.label("", 22, UiTheme.TEXT, 500)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_notice)

	_expedition = Button.new()
	_expedition.name = "ExpeditionButton"
	_expedition.text = UiTheme.display_text("EXPEDIÇÃO  >")
	_expedition.icon = PixelArt.icon(&"pick")
	_expedition.add_theme_constant_override("icon_max_width", 44)
	_expedition.add_theme_font_size_override("font_size", UiTheme.font_size(36, 700))
	UiTheme.style_button(_expedition, &"green")
	_expedition.pressed.connect(func() -> void: press(&"map"))
	_root.add_child(_expedition)


## Posições (em unidades de 720 de largura; a altura acompanha a tela).
func _layout() -> void:
	if _root == null:
		return
	var vp: Vector2 = _root.get_viewport_rect().size
	var ox: float = maxf(0.0, (vp.x - 720.0) * 0.5)
	var h: float = vp.y
	var floor_y: float = h - 170.0
	var mezz_y: float = floor_y - 420.0
	var rects: Dictionary = {
		&"map": Rect2(24, mezz_y - 230, 320, 230),
		&"lab": Rect2(376, mezz_y - 230, 320, 230),
		&"bench": Rect2(12, floor_y - 250, 226, 250),
		&"hangar": Rect2(238, floor_y - 280, 244, 280),
		&"market": Rect2(482, floor_y - 250, 226, 250),
	}
	_view.position = Vector2(ox, 0)
	_view.size = Vector2(720, h)
	_view.rects = rects
	_view.floor_y = floor_y
	_view.mezz_y = mezz_y
	_view.queue_redraw()
	for kind in STATIONS:
		var r: Rect2 = rects[kind]
		r.position.x += ox
		var b: Button = _buttons[kind]
		b.position = r.position
		b.size = r.size
		var plate: PanelContainer = _plates[kind]
		plate.size = Vector2(minf(r.size.x, 250.0), 0)
		plate.reset_size()
		plate.position = Vector2(r.get_center().x - plate.size.x * 0.5, r.end.y - 18.0)
		var badge: Label = _badges[kind]
		badge.position = Vector2(plate.position.x + plate.size.x - 22.0, plate.position.y - 30.0)
	var header: Control = _root.get_node("Header")
	header.position = Vector2(ox + 8, 10)
	header.size = Vector2(704, 0)
	_notice.position = Vector2(ox + 20, mezz_y + 34)
	_notice.size = Vector2(680, 40)
	_expedition.position = Vector2(ox + 20, h - 124)
	_expedition.size = Vector2(680, 104)


func _refresh() -> void:
	if not visible:
		return
	_credits.text = UiTheme.short_number(GameState.economy.credits)
	_crystals.text = UiTheme.short_number(GameState.economy.crystals)
	for kind in STATIONS:
		(_badges[kind] as Label).visible = has_badge(kind)
	_notice.text = GameState.pending_notice
	_notice.add_theme_color_override("font_color", UiTheme.RED)


func _process(_delta: float) -> void:
	if not visible:
		return
	var blink: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
	for kind in STATIONS:
		var badge: Label = _badges[kind]
		if badge.visible:
			badge.scale = Vector2.ONE * blink
			badge.pivot_offset = badge.size * 0.5
