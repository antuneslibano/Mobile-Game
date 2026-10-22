class_name BaseView
extends Control
## Desenho do galpão da base (pixel art de 4 px, procedural): parede de chapas com janela
## para o céu da região, mezanino com a Mesa de mapas e o Laboratório, piso com a Bancada,
## o Hangar (nave na plataforma, guindaste) e o Mercado (caixas, balança). Animações leves:
## holograma girando, tubos borbulhando, faíscas na bancada, nave flutuando.

const P: float = 4.0

var region: RegionDef
var rects: Dictionary = {}
var floor_y: float = 1100.0
var mezz_y: float = 680.0
var pressed_kind: StringName = &""
var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(Vector2(x, y).snapped(Vector2(P, P)), Vector2(w, h).snapped(Vector2(P, P))), c)


func _draw() -> void:
	if rects.is_empty():
		return
	var w: float = size.x
	var h: float = size.y
	# Parede de chapas.
	_px(0, 0, w, floor_y, Color("1a2030"))
	var x: float = 0.0
	while x < w:
		_px(x, 120, P, floor_y - 120, Color("121722"))
		for y in range(160, int(floor_y), 120):
			_px(x + P * 3, y, P, P, Color("2c3448"))
		x += 120.0
	# Viga superior com faixa de advertência.
	_px(0, 116, w, P * 5, Color("2a3040"))
	for i in int(w / 32.0) + 1:
		_px(i * 32.0, 116 + P * 5, 16, P * 2, Color("f2b33d"))
	_window(Rect2(150, 150, 420, mezz_y - 430))
	# Mezanino.
	_px(0, mezz_y, w, P * 4, Color("3a4252"))
	_px(0, mezz_y + P * 4, w, P * 2, Color("12161f"))
	for i in int(w / 40.0) + 1:
		_px(i * 40.0, mezz_y - P * 9, P, P * 9, Color("4a5266"))
	_px(0, mezz_y - P * 9, w, P, Color("5a6478"))
	# Piso.
	_px(0, floor_y, w, h - floor_y, Color("232836"))
	_px(0, floor_y, w, P * 2, Color("4a5266"))
	for i in int(w / 96.0) + 1:
		_px(i * 96.0, floor_y + P * 2, P, h - floor_y, Color("1a1e29"))
	_map_table(rects[&"map"])
	_lab(rects[&"lab"])
	_bench(rects[&"bench"])
	_hangar(rects[&"hangar"])
	_market(rects[&"market"])
	if pressed_kind != &"" and rects.has(pressed_kind):
		draw_rect(rects[pressed_kind], Color(1, 1, 1, 0.08))


func _window(r: Rect2) -> void:
	var top: Color = region.sky_top if region != null else Color("1b1530")
	var bot: Color = region.sky_bottom if region != null else Color("d9774a")
	draw_rect(r.grow(P * 3), Color("3a4252"))
	var steps: int = int(r.size.y / P)
	for i in steps:
		_px(r.position.x, r.position.y + i * P, r.size.x, P, top.lerp(bot, float(i) / steps))
	# Colinas da região.
	var far: Color = region.hill_far if region != null else Color("3a2440")
	var near: Color = region.hill_near if region != null else Color("2a1a2c")
	for i in int(r.size.x / P):
		var hx: float = r.position.x + i * P
		var h1: float = 30.0 + 18.0 * sin(i * 0.09) + 10.0 * sin(i * 0.23)
		var h2: float = 14.0 + 10.0 * sin(i * 0.13 + 2.0)
		_px(hx, r.end.y - h1, P, h1, far)
		_px(hx, r.end.y - h2, P, h2, near)
	# Caixilho.
	_px(r.get_center().x - P, r.position.y, P * 2, r.size.y, Color("3a4252"))
	_px(r.position.x, r.get_center().y - P, r.size.x, P * 2, Color("3a4252"))


## Mesa de mapas: mesa de aço com projetor e globo holográfico girando.
func _map_table(r: Rect2) -> void:
	var base_y: float = r.end.y - 40
	var cx: float = r.get_center().x
	_px(r.position.x + 30, base_y - 50, r.size.x - 60, P * 5, Color("5a6478"))
	_px(r.position.x + 30, base_y - 50 + P * 5, r.size.x - 60, P * 2, Color("2a3040"))
	_px(r.position.x + 44, base_y - 30, P * 3, 34, Color("3a4252"))
	_px(r.end.x - 56, base_y - 30, P * 3, 34, Color("3a4252"))
	_px(cx - 24, base_y - 62, 48, P * 3, Color("2a3040"))
	# Cone de luz e globo.
	var gy: float = base_y - 130
	var cone := PackedVector2Array([Vector2(cx - 12, base_y - 60), Vector2(cx + 12, base_y - 60), Vector2(cx + 62, gy + 30), Vector2(cx - 62, gy + 30)])
	draw_colored_polygon(cone, Color(0.3, 0.85, 1.0, 0.12))
	var rad: float = 56.0
	draw_circle(Vector2(cx, gy), rad, Color(0.2, 0.7, 1.0, 0.18))
	draw_arc(Vector2(cx, gy), rad, 0.0, TAU, 40, Color(0.5, 0.95, 1.0, 0.9), 3.0)
	for k in 3:
		var phase: float = fposmod(_t * 0.6 + k / 3.0, 1.0)
		var ex: float = rad * cos(phase * PI)
		draw_arc(Vector2(cx, gy), absf(ex) + 1.0, 0.0, TAU, 32, Color(0.5, 0.95, 1.0, 0.45), 2.0)
	for k in 3:
		var yy: float = gy + (k - 1) * rad * 0.5
		var hw: float = sqrt(maxf(0.0, rad * rad - pow(yy - gy, 2)))
		draw_line(Vector2(cx - hw, yy), Vector2(cx + hw, yy), Color(0.5, 0.95, 1.0, 0.45), 2.0)
	# Pontos das regiões.
	for k in 6:
		var a: float = _t * 0.6 * PI + k * 1.05
		if cos(a) > 0.0:
			draw_rect(Rect2(Vector2(cx + sin(a) * rad * 0.8, gy + (k - 2.5) * 14.0) - Vector2(3, 3), Vector2(6, 6)), Color("ffd54a"))


## Laboratório: bancada com dois monitores, microscópio e tubos borbulhando.
func _lab(r: Rect2) -> void:
	var base_y: float = r.end.y - 40
	_px(r.position.x + 20, base_y - 46, r.size.x - 40, P * 4, Color("5a6478"))
	_px(r.position.x + 20, base_y - 30, r.size.x - 40, 30, Color("2a3040"))
	for m in 2:
		var mx: float = r.position.x + 36 + m * 110
		_px(mx, base_y - 150, 96, 80, Color("12161f"))
		_px(mx + P, base_y - 146, 96 - P * 2, 72, Color("0b2a1c"))
		for i in 20:
			var gy: float = base_y - 110 + sin(i * 0.7 + _t * 3.0 + m) * 16.0
			_px(mx + 6 + i * P, gy, P, P, Color("5aff9a"))
		_px(mx + 40, base_y - 70, 16, 24, Color("3a4252"))
	# Tubos de ensaio.
	var tx: float = r.end.x - 70
	_px(tx - 6, base_y - 64, 64, P * 2, Color("3a4252"))
	var cols: Array[Color] = [Color("ff5aa0"), Color("6fe3ff"), Color("ffd54a")]
	for i in 3:
		var x: float = tx + i * 18
		_px(x, base_y - 110, 12, 46, Color(1, 1, 1, 0.25))
		_px(x, base_y - 90, 12, 26, cols[i])
		var by: float = base_y - 90 - fposmod(_t * 30.0 + i * 11.0, 30.0)
		_px(x + 4, by, P, P, Color(1, 1, 1, 0.7))


## Bancada: mesa de trabalho, painel de ferramentas e faíscas de solda.
func _bench(r: Rect2) -> void:
	var base_y: float = r.end.y - 40
	# Painel de ferramentas.
	_px(r.position.x + 20, r.position.y + 30, r.size.x - 40, 90, Color("2a3040"))
	for i in 5:
		_px(r.position.x + 36 + i * 32, r.position.y + 44, P * 2, 40 + (i % 2) * 20, Color("aab4c4"))
		_px(r.position.x + 32 + i * 32, r.position.y + 40, P * 4, P * 3, Color("f2b33d") if i % 2 == 0 else Color("e05a3a"))
	# Mesa.
	_px(r.position.x + 10, base_y - 70, r.size.x - 20, P * 5, Color("8a5a32"))
	_px(r.position.x + 10, base_y - 70 + P * 5, r.size.x - 20, P * 2, Color("4a2e18"))
	_px(r.position.x + 22, base_y - 42, P * 3, 42, Color("3a4252"))
	_px(r.end.x - 34, base_y - 42, P * 3, 42, Color("3a4252"))
	# Peça na morsa + faíscas.
	var vx: float = r.get_center().x
	_px(vx - 30, base_y - 100, 60, 30, Color("5a6478"))
	_px(vx - 14, base_y - 118, 28, 18, Color("c8d0dc"))
	for i in 6:
		var k: float = fposmod(_t * 2.2 + i / 6.0, 1.0)
		var sx: float = vx + 18 + cos(i * 1.3) * k * 40.0
		var sy: float = base_y - 118 - sin(i * 0.9 + 0.5) * k * 40.0 + k * k * 30.0
		_px(sx, sy, P, P, Color(1.0, 0.85, 0.4, 1.0 - k))


## Hangar: plataforma listrada, guindaste e a nave flutuando.
func _hangar(r: Rect2) -> void:
	var base_y: float = r.end.y - 40
	var cx: float = r.get_center().x
	# Guindaste.
	_px(r.position.x + 10, r.position.y, P * 3, base_y - r.position.y, Color("3a4252"))
	_px(r.position.x + 10, r.position.y, r.size.x * 0.6, P * 3, Color("f2b33d"))
	_px(cx - 2, r.position.y + P * 3, P, 50, Color("c3cad6"))
	# Plataforma.
	_px(r.position.x + 10, base_y - 24, r.size.x - 20, 24, Color("2a3040"))
	for i in int((r.size.x - 20) / 24.0):
		_px(r.position.x + 10 + i * 24, base_y - 24, 12, P * 2, Color("f2b33d"))
	# Nave (de pé, broca para baixo), flutuando.
	var tex: Texture2D = ShipArt.frame(int(_t * 9.0))
	var k: float = 5.0
	var sz := Vector2(ShipArt.W, ShipArt.H) * k
	var bob: float = roundf(sin(_t * 2.0) * 2.0) * P
	draw_set_transform(Vector2(cx, base_y - 40 - sz.x * 0.5 + bob), PI * 0.5, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(cx, base_y - 26), 40.0, Color(0.31, 0.76, 1.0, 0.10 + 0.05 * sin(_t * 3.0)))


## Mercado: caixas empilhadas, balança e placa com moeda.
func _market(r: Rect2) -> void:
	var base_y: float = r.end.y - 40
	var crate := func(x: float, y: float, s: float, c: Color) -> void:
		_px(x, y, s, s, c)
		_px(x, y, s, P, c.lightened(0.25))
		_px(x + P * 2, y + P * 2, s - P * 4, P, c.darkened(0.35))
		_px(x + P * 2, y + s - P * 3, s - P * 4, P, c.darkened(0.35))
		_px(x, y + s - P, s, P, c.darkened(0.5))
	crate.call(r.position.x + 20, base_y - 64, 64.0, Color("8a5a32"))
	crate.call(r.position.x + 88, base_y - 64, 64.0, Color("7a4e2a"))
	crate.call(r.position.x + 52, base_y - 120, 56.0, Color("9a6a3a"))
	# Minério saindo da caixa de cima.
	_px(r.position.x + 64, base_y - 132, P * 3, P * 3, Color("e08a4f"))
	_px(r.position.x + 80, base_y - 128, P * 3, P * 2, Color("6fe3ff"))
	# Balança.
	var bx: float = r.end.x - 50
	_px(bx - 2, base_y - 100, P, 100, Color("aab4c4"))
	var tilt: float = sin(_t * 1.5) * 6.0
	_px(bx - 40, base_y - 100 + tilt, 80, P, Color("aab4c4"))
	_px(bx - 44, base_y - 92 + tilt, 24, P * 2, Color("ffd54a"))
	_px(bx + 20, base_y - 92 - tilt, 24, P * 2, Color("c3cad6"))
	# Placa com moeda.
	_px(r.position.x + 30, r.position.y + 30, 100, 56, Color("2a3040"))
	draw_circle(Vector2(r.position.x + 80, r.position.y + 58), 18.0, Color("ffb02e"))
	draw_circle(Vector2(r.position.x + 80, r.position.y + 58), 11.0, Color("ffd54a"))
