class_name UiTheme
extends RefCounted
## Tema visual único da interface (cores, fontes e caixas). Construído em código.

const BG := Color("17131c")
const PANEL := Color("221c29")
const PANEL_EDGE := Color("3b3245")
const TEXT := Color("f4ecdf")
const TEXT_DIM := Color("b3a89a")
const ACCENT := Color("f2b33d")
const BLUE := Color("4fc3ff")
const CREDITS := Color("ffd166")
const CRYSTALS := Color("6fe3ff")

const FONT_SMALL: int = 22
const FONT_NORMAL: int = 28
const FONT_BIG: int = 52

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func panel_box(color: Color, edge: Color, radius: int = 18, border: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = edge
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	return sb


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_NORMAL
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	t.set_constant("outline_size", "Label", 6)
	t.set_stylebox("panel", "PanelContainer", panel_box(Color(PANEL, 0.92), PANEL_EDGE))

	var bar_bg := panel_box(Color("0f0c13"), PANEL_EDGE, 8, 2)
	bar_bg.set_content_margin_all(0)
	var bar_fill := panel_box(BLUE, BLUE.lightened(0.3), 8, 0)
	bar_fill.set_content_margin_all(0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_font_size("font_size", "ProgressBar", FONT_SMALL)
	return t
