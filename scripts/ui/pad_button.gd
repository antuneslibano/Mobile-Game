class_name PadButton
extends Control
## Botão grande de toque desenhado em código. Não consome eventos: o InputController
## faz o hit-test (permite multitoque real entre botões).

enum Icon { LEFT, RIGHT, DRILL, BOOST }

var kind: StringName = &""
var icon: Icon = Icon.DRILL
var text: String = ""
var accent: Color = UiTheme.ACCENT
var pressed: bool = false:
	set(v):
		if v != pressed:
			pressed = v
			queue_redraw()


func _init(p_kind: StringName, p_icon: Icon, p_text: String, p_accent: Color) -> void:
	kind = p_kind
	icon = p_icon
	text = p_text
	accent = p_accent
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var press_off: float = 4.0 if pressed else 0.0
	var shadow := UiTheme.panel_box(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 22, 0)
	draw_style_box(shadow, Rect2(r.position + Vector2(0, 6), r.size))
	var face_col: Color = accent.darkened(0.15) if pressed else UiTheme.PANEL
	var edge_col: Color = accent if pressed else UiTheme.PANEL_EDGE.lightened(0.15)
	var face := UiTheme.panel_box(Color(face_col, 0.95), edge_col, 22, 4)
	var face_rect := Rect2(r.position + Vector2(0, press_off), r.size - Vector2(0, 6))
	draw_style_box(face, face_rect)

	var c: Vector2 = face_rect.get_center() + Vector2(0, -12 if text != "" else 0)
	var ic: Color = UiTheme.BG if pressed else accent
	var s: float = minf(face_rect.size.x, face_rect.size.y) * 0.22
	match icon:
		Icon.LEFT:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(s * 0.7, -s), c + Vector2(s * 0.7, s)]), ic)
		Icon.RIGHT:
			draw_colored_polygon(PackedVector2Array([c + Vector2(s, 0), c + Vector2(-s * 0.7, -s), c + Vector2(-s * 0.7, s)]), ic)
		Icon.DRILL:
			draw_rect(Rect2(c + Vector2(-s * 0.8, -s), Vector2(s * 1.6, s * 0.7)), ic)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.6, -s * 0.2), c + Vector2(s * 0.6, -s * 0.2), c + Vector2(0, s * 1.1)]), ic)
		Icon.BOOST:
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.3, -s), c + Vector2(-s * 0.5, s * 0.2), c + Vector2(s * 0.1, s * 0.1)]), ic)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.1, -s * 0.1), c + Vector2(s * 0.5, -s * 0.2), c + Vector2(-s * 0.3, s)]), ic)
	if text != "":
		var font: Font = get_theme_default_font()
		var fs: int = UiTheme.FONT_SMALL
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(face_rect.get_center().x - tw * 0.5, face_rect.end.y - 18)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.BG if pressed else UiTheme.TEXT)
