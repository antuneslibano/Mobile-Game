class_name ShipPreview
extends Control
## Vitrine da nave na garagem: moldura metálica, faixas de advertência nas laterais,
## cantoneiras amarelas, grade sutil e a nave grande com a broca girando.

var _t: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(290, 240)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var p: float = float(PixelArt.SCALE)
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(PixelArt.style(&"frame"), r)
	var inner: Rect2 = r.grow(-p * 7.0)
	draw_rect(inner, Color("121722"))
	# Grade sutil.
	var step: float = 24.0
	var gx: float = inner.position.x
	while gx < inner.end.x:
		draw_rect(Rect2(gx, inner.position.y, 1, inner.size.y), Color(1, 1, 1, 0.035))
		gx += step
	var gy: float = inner.position.y
	while gy < inner.end.y:
		draw_rect(Rect2(inner.position.x, gy, inner.size.x, 1), Color(1, 1, 1, 0.035))
		gy += step
	# Faixas de advertência nas laterais.
	for side: float in [0.0, 1.0]:
		var x0: float = r.position.x + p * 2.0 if side == 0.0 else r.end.x - p * 5.0
		var band := Rect2(x0, inner.position.y + inner.size.y * 0.3, p * 3.0, inner.size.y * 0.4)
		draw_rect(band, PixelArt.OUTLINE)
		var y: float = band.position.y
		var k: int = 0
		while y < band.end.y:
			draw_rect(Rect2(band.position.x, y, band.size.x, minf(p * 2.0, band.end.y - y)), PixelArt.ORANGE if k % 2 == 0 else Color("1a1d24"))
			y += p * 2.0
			k += 1
	# Cantoneiras amarelas.
	var c := Color("ffb02e")
	var L: float = p * 4.0
	for corner: Vector2 in [inner.position, Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y), inner.end]:
		var sx: float = 1.0 if corner.x == inner.position.x else -1.0
		var sy: float = 1.0 if corner.y == inner.position.y else -1.0
		var base: Vector2 = corner + Vector2(sx, sy) * p * 3.0
		for i in 3:
			draw_rect(Rect2(base + Vector2(sx * i * p, sy * (2 - i) * p) - Vector2(p, p) * 0.5, Vector2(p, p)), c)
		draw_rect(Rect2(base, Vector2(L * 0.2, L * 0.2)), Color(0, 0, 0, 0))
	# Nave grande, com leve flutuação.
	var tex: Texture2D = ShipArt.frame(int(_t * 9.0), GameState.ship_look())
	var k2: float = floorf(minf(inner.size.x * 0.82 / ShipArt.W, inner.size.y * 0.7 / ShipArt.H))
	var sz := Vector2(ShipArt.W, ShipArt.H) * k2
	var pos: Vector2 = inner.get_center() - sz * 0.5 + Vector2(0, roundf(sin(_t * 2.0) * 2.0) * p)
	draw_texture_rect(tex, Rect2(pos, sz), false)
