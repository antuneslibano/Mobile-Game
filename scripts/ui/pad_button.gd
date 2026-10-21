class_name PadButton
extends Control
## Botão grande de toque (ex.: Sobrecarga) em pixel art. Não consome eventos: o
## InputController faz o hit-test (permite multitoque real com o joystick).

var kind: StringName = &""
var icon_id: StringName = &"boost"
var text: String = "":
	set(v):
		if v != text:
			text = v
			queue_redraw()
var style_kind: StringName = &"blue"
var pressed: bool = false:
	set(v):
		if v != pressed:
			pressed = v
			queue_redraw()


func _init(p_kind: StringName, p_icon: StringName, p_text: String, p_style: StringName) -> void:
	kind = p_kind
	icon_id = p_icon
	text = p_text
	style_kind = p_style
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sb: StyleBox = PixelArt.style(StringName(String(style_kind) + "_pressed") if pressed else style_kind)
	draw_style_box(sb, r)
	var tex: Texture2D = PixelArt.icon(icon_id)
	var isz: float = minf(size.x, size.y) * 0.5
	var ir := Rect2(Vector2((size.x - isz) * 0.5, size.y * 0.12), Vector2(isz, isz))
	draw_texture_rect(tex, ir, false)
	if text != "":
		var f: Font = UiTheme.font(700)
		var fs: int = UiTheme.font_size(UiTheme.FONT_SMALL, 700)
		var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2((size.x - tw) * 0.5, size.y - 18.0)
		draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, PixelArt.OUTLINE)
		draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.TEXT)
