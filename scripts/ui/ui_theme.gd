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

	# Botões: grandes, contrastados, com estado pressionado visível.
	t.set_stylebox("normal", "Button", panel_box(Color("2e2636"), PANEL_EDGE.lightened(0.2), 16, 3))
	t.set_stylebox("hover", "Button", panel_box(Color("3a3044"), ACCENT.darkened(0.2), 16, 3))
	t.set_stylebox("pressed", "Button", panel_box(ACCENT.darkened(0.25), ACCENT, 16, 3))
	t.set_stylebox("hover_pressed", "Button", panel_box(ACCENT.darkened(0.2), ACCENT, 16, 3))
	t.set_stylebox("disabled", "Button", panel_box(Color("1c1722"), Color("2c2533"), 16, 3))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", BG)
	t.set_color("font_hover_pressed_color", "Button", BG)
	t.set_color("font_disabled_color", "Button", TEXT_DIM.darkened(0.3))
	t.set_font_size("font_size", "Button", FONT_NORMAL)
	return t


## Botão de destaque (ação principal: vender, comprar).
static func accent_button(b: Button, color: Color = ACCENT) -> void:
	b.add_theme_stylebox_override("normal", panel_box(color.darkened(0.1), color.lightened(0.25), 16, 3))
	b.add_theme_stylebox_override("hover", panel_box(color, color.lightened(0.35), 16, 3))
	b.add_theme_stylebox_override("pressed", panel_box(color.darkened(0.35), color, 16, 3))
	b.add_theme_stylebox_override("hover_pressed", panel_box(color.darkened(0.35), color, 16, 3))
	b.add_theme_color_override("font_color", BG)
	b.add_theme_color_override("font_hover_color", BG)
	b.add_theme_color_override("font_pressed_color", BG)
