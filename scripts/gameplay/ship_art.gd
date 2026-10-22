class_name ShipArt
extends RefCounted
## Sprite da nave de perfuração (pixel art procedural, sem imagens externas).
## Desenhada apontando para a DIREITA (+x); a broca fica na frente. Quadros com a
## espiral da broca deslocada animam a rotação. O visual (ShipLooks) troca a broca, o
## casco, os motores e a pintura; cada combinação é gerada uma vez e guardada.

const W: int = 35
const H: int = 20
## Centro do corpo no sprite (origem da rotação em jogo).
const ORIGIN := Vector2(13.0, 10.0)
const FRAMES: int = 3

const HULL_C := Color("e9edf3")
const HULL_SHADE_C := Color("b7c0cd")
const STEEL := Color("3b4356")
const STEEL_HI := Color("566078")
const STEEL_DARK := Color("232937")
const POD := Color("8b94a5")
const POD_HI := Color("c4cbd7")
const SCREEN := Color("2f8fe6")
const SCREEN_HI := Color("8fe4ff")
const LIGHT := Color("4ff0ff")

static var _cache: Dictionary = {}   ## chave do visual → Array[ImageTexture]

## Cores do cone da broca por opção: [claro, médio, escuro].
const DRILLS: Dictionary = {
	&"steel": [Color("dfe5ee"), Color("9aa3b2"), Color("5e6677")],
	&"gold": [Color("fff0a0"), Color("f2c14e"), Color("9a6a10")],
	&"crystal": [Color("dcfaff"), Color("6fd8ff"), Color("1f6ab0")],
	&"root": [Color("e0a070"), Color("94522a"), Color("4a2210")],
	&"plasma": [Color("ffffff"), Color("ff7ae0"), Color("8a2aa0")],
}


static func frame(i: int, look: Dictionary = {}) -> ImageTexture:
	var k: String = ShipLooks.key(look)
	if not _cache.has(k):
		var frames: Array[ImageTexture] = []
		for f in FRAMES:
			frames.append(ImageTexture.create_from_image(build(f, look)))
		_cache[k] = frames
	return (_cache[k] as Array[ImageTexture])[posmod(i, FRAMES)]


static func build(phase: int, look: Dictionary = {}) -> Image:
	var drill_kind: StringName = look.get(&"drill", &"steel")
	var hull_kind: StringName = look.get(&"hull", &"standard")
	var engine: StringName = look.get(&"engine", &"standard")
	var paint: Array = ShipLooks.PAINTS.get(look.get(&"paint", &"yellow"), ShipLooks.PAINTS[&"yellow"])
	var YELLOW_HI: Color = paint[0]
	var YELLOW: Color = paint[1]
	var YELLOW_LO: Color = paint[2]
	var HULL: Color = HULL_C
	var HULL_SHADE: Color = HULL_SHADE_C
	if hull_kind == &"titanium":
		HULL = Color("c8d8f0")
		HULL_SHADE = Color("7f98c0")
	var dc: Array = DRILLS.get(drill_kind, DRILLS[&"steel"])
	var img := PixelArt.new_img(W, H)
	# Pods de propulsão em cima e embaixo (cinza com luzes azuis).
	for y0: int in [1, 15]:
		PixelArt.rect(img, 7, y0, 9, 4, POD)
		PixelArt.rect(img, 7, y0, 9, 1, POD_HI)
		PixelArt.rect(img, 7, y0 + 3, 9, 1, POD.darkened(0.25))
		PixelArt.rect(img, 5, y0 + 1, 2, 2, STEEL)
		PixelArt.px(img, 9, y0 + 1, LIGHT)
		PixelArt.px(img, 12, y0 + 1, LIGHT)
		PixelArt.rect(img, 16, y0 + 1, 2, 2, YELLOW)
		if engine == &"tanks":
			# Tanques extras: faixas laranja nos pods.
			PixelArt.rect(img, 8, y0 + 1, 7, 2, Color("ff8a3a"))
			PixelArt.rect(img, 8, y0 + 1, 7, 1, Color("ffc080"))
	# Bloco traseiro escuro.
	PixelArt.rect(img, 4, 5, 6, 10, STEEL)
	PixelArt.rect(img, 4, 5, 6, 1, STEEL_HI)
	PixelArt.rect(img, 4, 14, 6, 1, STEEL_DARK)
	PixelArt.rect(img, 5, 7, 2, 2, Color("1a4f8f"))
	PixelArt.px(img, 5, 7, LIGHT)
	PixelArt.rect(img, 5, 11, 2, 2, Color("1a4f8f"))
	PixelArt.px(img, 5, 11, LIGHT)
	# Bocais traseiros (Turbo: bocais de aço com anel azul).
	for y0: int in [5, 11]:
		if engine == &"turbo":
			PixelArt.rect(img, 0, y0 - 1, 4, 6, STEEL_HI)
			PixelArt.rect(img, 0, y0 - 1, 4, 1, Color("c4cbd7"))
			PixelArt.rect(img, 3, y0, 1, 4, LIGHT)
			PixelArt.rect(img, 0, y0 + 1, 1, 2, STEEL_DARK)
			continue
		PixelArt.rect(img, 0, y0, 4, 4, YELLOW)
		PixelArt.rect(img, 0, y0, 4, 1, YELLOW_HI)
		PixelArt.rect(img, 0, y0 + 3, 4, 1, YELLOW_LO)
		PixelArt.rect(img, 0, y0 + 1, 1, 2, STEEL_DARK)
	# Casco branco.
	PixelArt.rect(img, 9, 5, 11, 10, HULL)
	PixelArt.rect(img, 9, 12, 11, 3, HULL_SHADE)
	PixelArt.rect(img, 10, 5, 9, 1, Color.WHITE)
	# Placas amarelas de blindagem em cima e embaixo.
	PixelArt.rect(img, 10, 4, 8, 2, YELLOW)
	PixelArt.rect(img, 10, 4, 8, 1, YELLOW_HI)
	PixelArt.rect(img, 10, 14, 8, 2, YELLOW)
	PixelArt.rect(img, 10, 15, 8, 1, YELLOW_LO)
	# Cabine azul com reflexo.
	PixelArt.rect(img, 13, 7, 5, 5, STEEL_DARK)
	var scr: Color = Color("3ad890") if engine == &"reactor" else SCREEN
	var scr_hi: Color = Color("c8ffe0") if engine == &"reactor" else SCREEN_HI
	PixelArt.rect(img, 14, 8, 3, 3, scr)
	PixelArt.px(img, 14, 8, scr_hi)
	PixelArt.px(img, 15, 8, scr_hi)
	PixelArt.px(img, 14, 9, scr_hi)
	if engine == &"reactor":
		PixelArt.px(img, 15, 9, Color.WHITE)
	# Detalhes do casco.
	PixelArt.rect(img, 10, 8, 2, 1, HULL_SHADE)
	PixelArt.rect(img, 10, 10, 2, 1, HULL_SHADE)
	if hull_kind != &"standard":
		# Placas de blindagem rebitadas na frente e atrás da cabine.
		for x0: int in [9, 18]:
			PixelArt.rect(img, x0, 6, 2, 8, STEEL_HI)
			PixelArt.rect(img, x0, 6, 2, 1, Color("c4cbd7"))
			PixelArt.px(img, x0, 7, STEEL_DARK)
			PixelArt.px(img, x0, 12, STEEL_DARK)
	# Anel da broca (colar escuro + amarelo).
	PixelArt.rect(img, 20, 4, 2, 12, STEEL)
	PixelArt.rect(img, 20, 4, 2, 1, STEEL_HI)
	PixelArt.rect(img, 22, 4, 1, 12, YELLOW)
	PixelArt.rect(img, 22, 4, 1, 1, YELLOW_HI)
	# Cone da broca com espiral (deslocada por quadro).
	for x in range(23, W - 1):
		var t: float = float(x - 23) / float(W - 2 - 23)
		var half: float = lerpf(5.6, 0.6, t)
		for y in H:
			var dy: float = (y + 0.5) - 10.0
			if absf(dy) > half:
				continue
			var stripe: bool = posmod(x + int(floor(dy)) + phase, 3) == 0
			var c: Color = dc[0] if dy < -0.5 else (dc[1] if dy < 1.5 else dc[2])
			if stripe:
				c = c.lightened(0.5) if drill_kind == &"plasma" else c.darkened(0.35)
			img.set_pixel(x, y, c)
	if drill_kind == &"crystal" or drill_kind == &"plasma":
		PixelArt.px(img, W - 3, 9, Color.WHITE)
	elif drill_kind == &"root":
		# Espinhos de raiz ao longo do cone.
		for x: int in [25, 28, 31]:
			var half: int = int(lerpf(5.6, 0.6, float(x - 23) / float(W - 2 - 23)))
			PixelArt.px(img, x, 10 - half - 1, dc[2])
			PixelArt.px(img, x + 1, 10 + half + 1, dc[2])
	PixelArt.outline(img)
	return img
