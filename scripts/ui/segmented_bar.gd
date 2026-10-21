class_name SegmentedBar
extends Control
## Barra segmentada em pixel art (níveis, atributos, energia), como na referência.

var segments: int = 10
var value: float = 0.0:
	set(v):
		v = clampf(v, 0.0, 1.0)
		if not is_equal_approx(v, value):
			value = v
			queue_redraw()
var color: Color = UiTheme.ORANGE
var glow: bool = false:
	set(v):
		if v != glow:
			glow = v
			queue_redraw()


func _init(p_segments: int = 10, p_color: Color = UiTheme.ORANGE, height: float = 24.0) -> void:
	segments = p_segments
	color = p_color
	custom_minimum_size = Vector2(120, height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var p: float = float(PixelArt.SCALE)
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, PixelArt.OUTLINE)
	draw_rect(r.grow(-p), Color("0b0e14"))
	var inner: Rect2 = r.grow(-p * 2.0)
	var gap: float = p
	var seg_w: float = (inner.size.x - gap * (segments - 1)) / segments
	var filled: float = value * segments
	for i in segments:
		var sr := Rect2(inner.position + Vector2(i * (seg_w + gap), 0.0), Vector2(seg_w, inner.size.y))
		var f: float = clampf(filled - i, 0.0, 1.0)
		draw_rect(sr, Color("262c3a"))
		if f > 0.0:
			var fr := Rect2(sr.position, Vector2(sr.size.x * f, sr.size.y))
			var c: Color = color.lightened(0.2) if glow else color
			draw_rect(fr, c)
			draw_rect(Rect2(fr.position, Vector2(fr.size.x, p)), c.lightened(0.45))
			draw_rect(Rect2(fr.position + Vector2(0, fr.size.y - p), Vector2(fr.size.x, p)), c.darkened(0.3))
