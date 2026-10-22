class_name PixelArt
extends RefCounted
## Pixel art procedural da interface: painéis metálicos com rebites, placas e botões,
## ícones, moeda e cristal. Tudo gerado em código (sem imagens externas) e cacheado.
## Estilos 9-slice são pré-ampliados (nearest) para manter pixels nítidos.

const SCALE: int = 3                      ## Tamanho do "pixel de arte" na interface.
const OUTLINE := Color("0c0f16")

# Paleta da interface (ver referência visual do jogo).
const STEEL_HI := Color("6a7488")
const STEEL := Color("3c4456")
const STEEL_LO := Color("262c3a")
const PANEL := Color("161b27")
const PANEL_IN := Color("1d2332")
const ORANGE_HI := Color("ffd36a")
const ORANGE := Color("f5a623")
const ORANGE_LO := Color("c46a12")
const GOLD_HI := Color("ffe08a")
const GOLD := Color("f7b52c")
const GOLD_LO := Color("b8700e")
const GREEN_HI := Color("8ff08a")
const GREEN := Color("3fb44a")
const GREEN_LO := Color("1f7a2c")
const RED_HI := Color("ff8a6a")
const RED := Color("d8392b")
const RED_LO := Color("8e1f16")
const FRAME_ORANGE := Color("e8821e")
const FRAME_INNER := Color("2a1c15")
const CYAN := Color("3fd0ff")

static var _tex_cache: Dictionary = {}
static var _style_cache: Dictionary = {}


# --- Primitivas ----------------------------------------------------------------

static func new_img(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	return img


static func px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in range(y, y + h):
		for i in range(x, x + w):
			px(img, i, j, c)


static func circle(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for j in img.get_height():
		for i in img.get_width():
			if Vector2(i + 0.5 - cx, j + 0.5 - cy).length() <= r:
				img.set_pixel(i, j, c)


static func poly(img: Image, pts: PackedVector2Array, c: Color) -> void:
	for j in img.get_height():
		for i in img.get_width():
			if Geometry2D.is_point_in_polygon(Vector2(i + 0.5, j + 0.5), pts):
				img.set_pixel(i, j, c)


## Contorno escuro de 1 px em volta de tudo que é opaco (estilo da referência).
static func outline(img: Image, c: Color = OUTLINE) -> void:
	var src := img.duplicate() as Image
	for j in img.get_height():
		for i in img.get_width():
			if src.get_pixel(i, j).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var x: int = i + d.x
				var y: int = j + d.y
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and src.get_pixel(x, y).a > 0.0:
					img.set_pixel(i, j, c)
					break


static func upscale(img: Image, k: int) -> Image:
	var out := img.duplicate() as Image
	out.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	return out


## Textura cacheada a partir de um construtor de Image (em resolução de arte).
static func texture(key: StringName, builder: Callable, k: int = 1) -> ImageTexture:
	var ck: String = "%s@%d" % [key, k]
	if not _tex_cache.has(ck):
		var img: Image = builder.call()
		if k > 1:
			img = upscale(img, k)
		_tex_cache[ck] = ImageTexture.create_from_image(img)
	return _tex_cache[ck]


# --- Painéis e botões (9-slice) ---------------------------------------------------

## Estilos: &"frame" (janela metálica), &"inset" (painel interno), &"plate" (placa laranja),
## &"gold", &"gold_pressed", &"green", &"green_pressed", &"red", &"red_pressed",
## &"disabled", &"icon_frame", &"slot" (caixa de valor).
static func style(kind: StringName) -> StyleBoxTexture:
	if _style_cache.has(kind):
		return _style_cache[kind]
	var img: Image
	var m: int = 4
	var content: int = 4
	match kind:
		&"frame":
			img = _frame_img()
			m = 7
			content = 9
		&"inset":
			img = _bevel_img(12, Color("2b3242"), PANEL_IN, Color("10141c"), PANEL_IN, 2)
		&"slot":
			img = _bevel_img(12, Color("10141c"), Color("12161f"), Color("323a4c"), Color("12161f"), 2)
		&"plate":
			img = _button_img(ORANGE_HI, ORANGE, ORANGE_LO, true)
		&"gold":
			img = _button_img(GOLD_HI, GOLD, GOLD_LO, false)
		&"gold_pressed":
			img = _button_img(GOLD, GOLD_LO, GOLD_LO.darkened(0.3), false)
		&"green":
			img = _button_img(GREEN_HI, GREEN, GREEN_LO, false)
		&"green_pressed":
			img = _button_img(GREEN, GREEN_LO, GREEN_LO.darkened(0.3), false)
		&"red":
			img = _button_img(RED_HI, RED, RED_LO, false)
		&"red_pressed":
			img = _button_img(RED, RED_LO, RED_LO.darkened(0.3), false)
		&"blue":
			img = _button_img(Color("8fe4ff"), Color("2f8fe6"), Color("1a4f8f"), false)
		&"blue_pressed":
			img = _button_img(Color("2f8fe6"), Color("1a4f8f"), Color("10305a"), false)
		&"disabled":
			img = _button_img(Color("5a6070"), Color("3a3f4c"), Color("262a34"), false)
		&"icon_frame":
			img = _icon_frame_img()
			m = 5
			content = 6
		_:
			img = _bevel_img(12, STEEL_HI, STEEL, STEEL_LO, PANEL, 2)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(upscale(img, SCALE))
	sb.set_texture_margin_all(m * SCALE)
	sb.set_content_margin_all(content * SCALE)
	_style_cache[kind] = sb
	return sb


## Caixa com contorno, borda clara em cima/esquerda e escura embaixo/direita.
static func _bevel_img(size: int, hi: Color, mid: Color, lo: Color, inner: Color, band: int) -> Image:
	var img := new_img(size, size)
	rect(img, 0, 0, size, size, OUTLINE)
	rect(img, 1, 1, size - 2, size - 2, mid)
	rect(img, 1, 1, size - 2, 1, hi)
	rect(img, 1, 1, 1, size - 2, hi)
	rect(img, 1, size - 2, size - 2, 1, lo)
	rect(img, size - 2, 1, 1, size - 2, lo)
	rect(img, 1 + band, 1 + band, size - 2 - band * 2, size - 2 - band * 2, inner)
	return img


## Janela metálica: moldura de aço com bisel, linha interna escura e rebites nos cantos.
static func _frame_img() -> Image:
	var s: int = 18
	var img := new_img(s, s)
	rect(img, 0, 0, s, s, OUTLINE)
	rect(img, 1, 1, s - 2, s - 2, STEEL)
	rect(img, 1, 1, s - 2, 1, STEEL_HI)
	rect(img, 1, 1, 1, s - 2, STEEL_HI)
	rect(img, 1, s - 2, s - 2, 1, STEEL_LO)
	rect(img, s - 2, 1, 1, s - 2, STEEL_LO)
	rect(img, 5, 5, s - 10, s - 10, OUTLINE)
	rect(img, 6, 6, s - 12, s - 12, PANEL)
	for p: Vector2i in [Vector2i(2, 2), Vector2i(s - 4, 2), Vector2i(2, s - 4), Vector2i(s - 4, s - 4)]:
		rect(img, p.x, p.y, 2, 2, Color("8790a4"))
		px(img, p.x, p.y, Color("c3cad8"))
		px(img, p.x + 1, p.y + 1, STEEL_LO)
	return img


## Botão/placa: contorno, cantos chanfrados, brilho em cima, sombra embaixo.
static func _button_img(hi: Color, mid: Color, lo: Color, notched: bool) -> Image:
	var s: int = 12
	var img := new_img(s, s)
	rect(img, 0, 0, s, s, OUTLINE)
	rect(img, 1, 1, s - 2, s - 2, mid)
	rect(img, 1, 1, s - 2, 2, hi)
	rect(img, 1, s - 3, s - 2, 2, lo)
	rect(img, 1, 3, 1, s - 6, hi.lerp(mid, 0.5))
	# Cantos chanfrados.
	for p: Vector2i in [Vector2i(0, 0), Vector2i(s - 1, 0), Vector2i(0, s - 1), Vector2i(s - 1, s - 1)]:
		px(img, p.x, p.y, Color.TRANSPARENT)
	for p: Vector2i in [Vector2i(1, 1), Vector2i(s - 2, 1), Vector2i(1, s - 2), Vector2i(s - 2, s - 2)]:
		px(img, p.x, p.y, OUTLINE)
	if notched:
		for p: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(s - 2, 0), Vector2i(s - 1, 1), Vector2i(0, s - 2), Vector2i(1, s - 1), Vector2i(s - 1, s - 2), Vector2i(s - 2, s - 1)]:
			px(img, p.x, p.y, Color.TRANSPARENT)
		for p: Vector2i in [Vector2i(2, 1), Vector2i(1, 2), Vector2i(s - 3, 1), Vector2i(s - 2, 2), Vector2i(1, s - 3), Vector2i(2, s - 2), Vector2i(s - 2, s - 3), Vector2i(s - 3, s - 2)]:
			px(img, p.x, p.y, OUTLINE)
	return img


static func _icon_frame_img() -> Image:
	var s: int = 14
	var img := new_img(s, s)
	rect(img, 0, 0, s, s, OUTLINE)
	rect(img, 1, 1, s - 2, s - 2, FRAME_ORANGE)
	rect(img, 1, 1, s - 2, 1, Color("ffb04a"))
	rect(img, 1, s - 2, s - 2, 1, Color("a85510"))
	rect(img, 3, 3, s - 6, s - 6, OUTLINE)
	rect(img, 4, 4, s - 8, s - 8, FRAME_INNER)
	return img


# --- Ícones (16×16, contorno automático) -----------------------------------------

static func icon(id: StringName) -> ImageTexture:
	return texture(StringName("icon_" + String(id)), func() -> Image: return _icon_img(id))


static func _icon_img(id: StringName) -> Image:
	var img := new_img(18, 18)
	match id:
		&"damage":
			_cone(img, Vector2(3, 14), Vector2(15, 3), 5.5)
			rect(img, 2, 12, 4, 4, ORANGE_LO)
			rect(img, 2, 12, 3, 2, ORANGE)
		&"speed":
			# Turbina: motor metálico com anel amarelo e chama azul.
			poly(img, PackedVector2Array([Vector2(1, 9), Vector2(7, 5), Vector2(7, 13)]), CYAN)
			poly(img, PackedVector2Array([Vector2(3, 9), Vector2(7, 7), Vector2(7, 11)]), Color("c9f3ff"))
			rect(img, 7, 4, 3, 10, GOLD)
			rect(img, 7, 4, 3, 1, GOLD_HI)
			rect(img, 10, 5, 6, 8, Color("5a6378"))
			rect(img, 10, 5, 6, 2, Color("8a93a3"))
			rect(img, 13, 8, 2, 2, CYAN)
		&"crit":
			circle(img, 9, 9, 7.0, RED)
			circle(img, 9, 9, 5.0, Color("ffe0d0"))
			circle(img, 9, 9, 3.0, RED)
			circle(img, 9, 9, 1.2, Color("ffe0d0"))
		&"collect":
			rect(img, 3, 3, 4, 10, RED)
			rect(img, 11, 3, 4, 10, RED)
			rect(img, 3, 11, 12, 4, RED)
			rect(img, 3, 3, 4, 3, Color("c3cad6"))
			rect(img, 11, 3, 4, 3, Color("c3cad6"))
			rect(img, 4, 12, 10, 1, RED_HI)
		&"energy":
			rect(img, 3, 3, 12, 12, Color("5a6378"))
			rect(img, 4, 4, 10, 10, Color("1a3a6a"))
			rect(img, 4, 4, 10, 1, Color("8a93a3"))
			poly(img, PackedVector2Array([Vector2(10, 5), Vector2(6, 10), Vector2(9, 10), Vector2(8, 14), Vector2(12, 8), Vector2(9, 8)]), CYAN)
		&"sonar":
			for r: float in [3.0, 6.0, 9.0]:
				for a in range(-40, 41, 8):
					var ang: float = deg_to_rad(float(a) - 90.0)
					px(img, int(9.0 + cos(ang) * r), int(14.0 + sin(ang) * r), CYAN if r < 9.0 else Color("8affd0"))
			circle(img, 9, 14, 2.0, Color("8affd0"))
		&"boost":
			poly(img, PackedVector2Array([Vector2(11, 1), Vector2(4, 10), Vector2(9, 10), Vector2(6, 17), Vector2(14, 7), Vector2(9, 7)]), GOLD)
			poly(img, PackedVector2Array([Vector2(10, 3), Vector2(6, 9), Vector2(9, 9), Vector2(8, 13), Vector2(12, 8), Vector2(9, 8)]), GOLD_HI)
		&"side_drill":
			_cone(img, Vector2(2, 6), Vector2(10, 6), 3.0)
			_cone(img, Vector2(8, 12), Vector2(16, 12), 3.0)
		&"drone":
			rect(img, 2, 5, 5, 1, Color("c3cad6"))
			rect(img, 11, 5, 5, 1, Color("c3cad6"))
			circle(img, 9, 10, 5.0, Color("6e7a86"))
			rect(img, 5, 9, 8, 2, GOLD)
			circle(img, 9, 11, 2.0, CYAN)
		&"seismic":
			circle(img, 9, 9, 8.0, Color("6b3fa0"))
			circle(img, 9, 9, 6.5, FRAME_INNER)
			circle(img, 9, 9, 5.0, Color("c57bff"))
			circle(img, 9, 9, 3.5, FRAME_INNER)
			circle(img, 9, 9, 2.0, Color("e3c2ff"))
		&"cooling":
			for d: Vector2 in [Vector2(1, 0), Vector2(0, 1), Vector2(0.7, 0.7), Vector2(0.7, -0.7)]:
				for t in range(-7, 8):
					var p: Vector2 = Vector2(9, 9) + d * t
					rect(img, int(p.x), int(p.y), 2, 2, Color("8fe4ff"))
			circle(img, 9.5, 9.5, 2.0, Color.WHITE)
		&"fuel_tank", &"fuel":
			# Galão de combustível.
			rect(img, 4, 4, 10, 12, Color("c0392b"))
			rect(img, 4, 4, 10, 2, Color("e8604c"))
			rect(img, 5, 7, 2, 8, Color("e8604c"))
			rect(img, 10, 1, 4, 3, Color("8a93a3"))
			rect(img, 7, 9, 5, 4, Color("7a1e14"))
		&"fuel_eff":
			# Gota com engrenagem (consumo).
			poly(img, PackedVector2Array([Vector2(9, 1), Vector2(15, 10), Vector2(13, 15), Vector2(5, 15), Vector2(3, 10)]), GOLD)
			poly(img, PackedVector2Array([Vector2(9, 3), Vector2(12, 9), Vector2(9, 9)]), GOLD_HI)
			circle(img, 9, 11, 3.0, Color("3fc45a"))
			circle(img, 9, 11, 1.2, Color("1a3a12"))
		&"hull":
			# Escudo do casco.
			poly(img, PackedVector2Array([Vector2(2, 3), Vector2(9, 1), Vector2(16, 3), Vector2(15, 11), Vector2(9, 17), Vector2(3, 11)]), Color("8a93a3"))
			poly(img, PackedVector2Array([Vector2(4, 4), Vector2(9, 3), Vector2(9, 15), Vector2(5, 11)]), Color("c3cad6"))
			rect(img, 8, 5, 2, 8, Color("3fd0ff"))
		&"heat":
			# Termômetro.
			rect(img, 7, 1, 4, 11, Color("e6e9ee"))
			circle(img, 9, 14, 3.5, Color("e6e9ee"))
			rect(img, 8, 5, 2, 8, Color("ff5a3a"))
			circle(img, 9, 14, 2.4, Color("ff5a3a"))
		&"extract":
			# Cápsula subindo (seta + cabo).
			rect(img, 8, 1, 2, 6, Color("c3cad6"))
			poly(img, PackedVector2Array([Vector2(9, 0), Vector2(14, 5), Vector2(4, 5)]), Color.WHITE)
			rect(img, 4, 8, 10, 7, GOLD)
			rect(img, 4, 8, 10, 2, GOLD_HI)
			rect(img, 7, 11, 4, 3, Color("3fd0ff"))
		&"elevator":
			rect(img, 3, 1, 2, 16, Color("8a93a3"))
			rect(img, 13, 1, 2, 16, Color("8a93a3"))
			rect(img, 5, 7, 8, 6, GOLD)
			rect(img, 5, 7, 8, 1, GOLD_HI)
			rect(img, 8, 0, 2, 7, Color("c3cad6"))
		&"arrow_up":
			poly(img, PackedVector2Array([Vector2(9, 2), Vector2(16, 9), Vector2(12, 9), Vector2(12, 16), Vector2(6, 16), Vector2(6, 9), Vector2(2, 9)]), Color.WHITE)
		&"close":
			for t in range(3, 15):
				rect(img, t, t, 2, 2, Color.WHITE)
				rect(img, 17 - t - 1, t, 2, 2, Color.WHITE)
		&"coin":
			circle(img, 9, 9, 7.0, GOLD_LO)
			circle(img, 8.5, 8.5, 6.0, GOLD)
			circle(img, 8, 8, 4.0, GOLD_HI)
			circle(img, 9, 9, 3.0, GOLD)
			rect(img, 5, 5, 2, 2, Color.WHITE)
		&"crystal":
			poly(img, PackedVector2Array([Vector2(4, 3), Vector2(14, 3), Vector2(17, 7), Vector2(9, 16), Vector2(1, 7)]), Color("1f78d1"))
			poly(img, PackedVector2Array([Vector2(4, 3), Vector2(14, 3), Vector2(17, 7), Vector2(1, 7)]), Color("5fd0ff"))
			poly(img, PackedVector2Array([Vector2(6, 7), Vector2(12, 7), Vector2(9, 15)]), Color("3fa8f0"))
			rect(img, 5, 4, 3, 2, Color("c9f3ff"))
		&"map":
			poly(img, PackedVector2Array([Vector2(1, 4), Vector2(6, 2), Vector2(12, 4), Vector2(17, 2), Vector2(17, 14), Vector2(12, 16), Vector2(6, 14), Vector2(1, 16)]), Color("3fae49"))
			poly(img, PackedVector2Array([Vector2(6, 2), Vector2(12, 4), Vector2(12, 16), Vector2(6, 14)]), Color("e9dcb0"))
			rect(img, 8, 6, 2, 2, RED)
			rect(img, 3, 9, 2, 2, Color("2a7a34"))
			rect(img, 14, 7, 2, 3, Color("2a7a34"))
		&"lock":
			rect(img, 5, 2, 8, 2, Color("c3cad6"))
			rect(img, 4, 3, 2, 6, Color("c3cad6"))
			rect(img, 12, 3, 2, 6, Color("c3cad6"))
			rect(img, 3, 8, 12, 9, RED)
			rect(img, 3, 8, 12, 2, RED_HI)
			rect(img, 8, 11, 2, 3, Color("2a0a08"))
		&"star":
			_star(img, GOLD, GOLD_HI)
		&"star_empty":
			_star(img, Color("3a3f4c"), Color("5a6070"))
		&"pick":
			for t in range(4, 16):
				rect(img, t - 1, 19 - t - 1, 2, 2, Color("8a5a2b"))
			poly(img, PackedVector2Array([Vector2(3, 6), Vector2(9, 1), Vector2(17, 5), Vector2(15, 7), Vector2(9, 4), Vector2(5, 8)]), Color("c3cad6"))
		&"arrow_left":
			poly(img, PackedVector2Array([Vector2(3, 9), Vector2(12, 1), Vector2(12, 17)]), Color.WHITE)
		&"arrow_right":
			poly(img, PackedVector2Array([Vector2(15, 9), Vector2(6, 1), Vector2(6, 17)]), Color.WHITE)
		&"quicksand":
			circle(img, 9, 11, 7.0, Color("d8b878"))
			for t in 12:
				var ang: float = t * 0.7
				var rr: float = 1.0 + t * 0.45
				rect(img, int(9 + cos(ang) * rr), int(11 + sin(ang) * rr * 0.6), 1, 1, Color("8a6a3a"))
		&"cave_in":
			rect(img, 2, 14, 14, 3, Color("6a6058"))
			for p: Vector3 in [Vector3(5, 4, 2.5), Vector3(11, 2, 2.0), Vector3(13, 8, 2.5), Vector3(7, 10, 2.0)]:
				circle(img, p.x, p.y, p.z, Color("9a8f86"))
				rect(img, int(p.x) - 1, int(p.y) - 1, 1, 1, Color("c8beb4"))
		&"unstable":
			rect(img, 1, 9, 16, 8, Color("8a5a3b"))
			rect(img, 1, 9, 16, 2, Color("a7744d"))
			for t in 8:
				rect(img, 4 + t, 9 + (t % 3) + t / 2, 1, 2, Color("2a1a10"))
		&"heat":
			poly(img, PackedVector2Array([Vector2(9, 1), Vector2(15, 10), Vector2(13, 16), Vector2(5, 16), Vector2(3, 10), Vector2(7, 6)]), Color("ff7a2e"))
			poly(img, PackedVector2Array([Vector2(9, 7), Vector2(12, 12), Vector2(11, 16), Vector2(7, 16), Vector2(6, 12)]), Color("ffd36b"))
		&"mud":
			rect(img, 1, 11, 16, 6, Color("4d4a2c"))
			circle(img, 6, 10, 3.0, Color("5a5634"))
			circle(img, 12, 9, 2.5, Color("5a5634"))
			rect(img, 4, 12, 2, 1, Color("8a8660"))
			rect(img, 11, 13, 3, 1, Color("8a8660"))
		&"hard_rock":
			circle(img, 9, 10, 7.0, Color("5a5468"))
			circle(img, 8, 9, 5.0, Color("7a7290"))
			rect(img, 5, 6, 3, 2, Color("aaa2c0"))
			rect(img, 10, 11, 4, 1, Color("2a2636"))
		&"ice":
			poly(img, PackedVector2Array([Vector2(9, 1), Vector2(16, 8), Vector2(9, 17), Vector2(2, 8)]), Color("8fc8ef"))
			poly(img, PackedVector2Array([Vector2(9, 1), Vector2(16, 8), Vector2(9, 9), Vector2(2, 8)]), Color("d6f1ff"))
		&"magma":
			poly(img, PackedVector2Array([Vector2(9, 2), Vector2(15, 11), Vector2(9, 17), Vector2(3, 11)]), Color("ff5a1e"))
			circle(img, 9, 12, 3.5, Color("ffd36b"))
		_:
			circle(img, 9, 9, 6.0, Color("8a93a3"))
	outline(img)
	return img


static func _star(img: Image, c: Color, hi: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var r: float = 8.0 if i % 2 == 0 else 3.6
		var a: float = -PI * 0.5 + i * PI / 5.0
		pts.append(Vector2(9, 9.5) + Vector2.from_angle(a) * r)
	poly(img, pts, c)
	rect(img, 7, 6, 2, 2, hi)


## Ícone de catálogo de um recurso (estilo da referência de minérios): pepitas cúbicas para
## metais, lascas para gemas, osso, rocha com fissuras. Cores do material real.
static func ore_icon(key: StringName) -> ImageTexture:
	return texture(StringName("ore_" + String(key)), func() -> Image: return _ore_img(key))


static func _ore_img(key: StringName) -> Image:
	# Mesmo sprite usado na mina (assets/environment), centralizado na tela do ícone.
	var block: int = _block_for(key)
	var sprite: String = TerrainSkins.ore_sprite_for(block)
	var path: String = "%s/ores/%s_1.png" % [TerrainSkins.ROOT, sprite]
	if block == BlockRegistry.FOSSIL:
		path = "%s/decorations/fossil_osso.png" % TerrainSkins.ROOT
	if (not sprite.is_empty() or block == BlockRegistry.FOSSIL) and ResourceLoader.exists(path):
		var src: Image = load(path) as Image
		if src != null:
			src = src.duplicate()
			src.convert(Image.FORMAT_RGBA8)
			var out := new_img(20, 18)
			out.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i((20 - src.get_width()) / 2, (18 - src.get_height()) / 2))
			return out
	var img := new_img(20, 18)
	var def: BlockDef = BlockRegistry.get_def(block)
	var acc: Color = def.color_accent
	match def.art:
		BlockDef.Art.CRYSTAL, BlockDef.Art.PRISM:
			var shards: Array[Vector4] = [Vector4(10, 16, 3.5, 14), Vector4(5, 16, 2.5, 9), Vector4(15, 16, 2.5, 10), Vector4(2, 16, 1.5, 5), Vector4(18, 16, 1.5, 6)]
			for i in shards.size():
				var sh: Vector4 = shards[i]
				var c: Color = acc
				if def.art == BlockDef.Art.PRISM:
					c = Color.from_hsv(float(i) / 5.0, 0.45, 1.0)
				poly(img, PackedVector2Array([Vector2(sh.x - sh.z, sh.y), Vector2(sh.x - sh.z, sh.y - sh.w * 0.7), Vector2(sh.x, sh.y - sh.w), Vector2(sh.x + sh.z, sh.y - sh.w * 0.7), Vector2(sh.x + sh.z, sh.y)]), c.darkened(0.25))
				poly(img, PackedVector2Array([Vector2(sh.x - sh.z, sh.y), Vector2(sh.x - sh.z, sh.y - sh.w * 0.7), Vector2(sh.x, sh.y - sh.w), Vector2(sh.x, sh.y)]), c.lightened(0.3))
		BlockDef.Art.FOSSIL:
			rect(img, 5, 8, 10, 3, acc)
			for p: Vector2 in [Vector2(4, 7), Vector2(4, 11), Vector2(16, 7), Vector2(16, 11)]:
				circle(img, p.x, p.y, 2.2, acc)
			rect(img, 5, 8, 10, 1, acc.lightened(0.3))
			rect(img, 3, 14, 14, 3, Color("8a7a66"))
		BlockDef.Art.VEINED:
			circle(img, 10, 10, 7.5, def.color_dark)
			circle(img, 9, 9, 6.0, def.color_base.lightened(0.15))
			for t in 9:
				rect(img, 5 + t, 6 + (t * 7) % 9, 1, 1, acc)
				rect(img, 6 + (t * 5) % 9, 4 + t, 1, 1, acc.lightened(0.3))
		_:
			var dark_metal: bool = acc.get_luminance() < 0.3
			var cubes: Array[Vector3] = [Vector3(10, 8, 4), Vector3(5, 12, 3), Vector3(15, 12, 3), Vector3(10, 14, 3), Vector3(3, 15, 2)]
			for cube: Vector3 in cubes:
				var x: int = int(cube.x - cube.z)
				var y: int = int(cube.y - cube.z)
				var sz: int = int(cube.z * 2)
				rect(img, x, y, sz, sz, acc.darkened(0.35))
				rect(img, x, y, sz - 1, sz - 1, acc)
				rect(img, x, y, sz - 1, maxi(1, sz / 3), acc.lightened(0.45 if not dark_metal else 0.25))
	outline(img)
	return img


## Amostra do material (camadas no painel do mapa).
static func material_swatch(block_id: int) -> ImageTexture:
	return texture(StringName("swatch_%d" % block_id), func() -> Image:
		var def: BlockDef = BlockRegistry.get_def(block_id)
		var img := new_img(24, 12)
		for y in 12:
			for x in 24:
				var n: float = WorldGenerator.hash01(x, y, block_id * 7 + 3)
				var c: Color = def.color_base if n > 0.35 else def.color_dark
				if n > 0.85:
					c = def.color_base.lightened(0.2)
				img.set_pixel(x, y, c)
		return img)


static func _block_for(key: StringName) -> int:
	for def: BlockDef in BlockRegistry.all():
		if def.key == key:
			return def.id
	return BlockRegistry.COPPER


## Cone de broca listrado entre base e ponta.
static func _cone(img: Image, base: Vector2, tip: Vector2, half_w: float) -> void:
	var dir: Vector2 = (tip - base).normalized()
	var n: Vector2 = dir.orthogonal()
	var pts := PackedVector2Array([base + n * half_w, tip, base - n * half_w])
	for j in img.get_height():
		for i in img.get_width():
			var p := Vector2(i + 0.5, j + 0.5)
			if Geometry2D.is_point_in_polygon(p, pts):
				var along: float = (p - base).dot(dir)
				var side: float = (p - base).dot(n)
				var stripe: bool = int(floor(along * 0.7 + side * 0.5)) % 2 == 0
				var c: Color = Color("d5dbe4") if side > 0.0 else Color("8a93a3")
				img.set_pixel(i, j, c if stripe else c.darkened(0.35))
