class_name ShipArt
extends RefCounted
## Sprite da nave de perfuração (pixel art procedural, sem imagens externas).
## Desenhada apontando para a DIREITA (+x); a broca fica na frente. Quadros com a
## espiral da broca deslocada animam a rotação.

const W: int = 35
const H: int = 20
## Centro do corpo no sprite (origem da rotação em jogo).
const ORIGIN := Vector2(13.0, 10.0)
const FRAMES: int = 3

const HULL := Color("e9edf3")
const HULL_SHADE := Color("b7c0cd")
const YELLOW := Color("f7b52c")
const YELLOW_HI := Color("ffd970")
const YELLOW_LO := Color("c47a10")
const STEEL := Color("3b4356")
const STEEL_HI := Color("566078")
const STEEL_DARK := Color("232937")
const POD := Color("8b94a5")
const POD_HI := Color("c4cbd7")
const SCREEN := Color("2f8fe6")
const SCREEN_HI := Color("8fe4ff")
const LIGHT := Color("4ff0ff")
const DRILL_HI := Color("dfe5ee")
const DRILL := Color("9aa3b2")
const DRILL_LO := Color("5e6677")

static var _frames: Array[ImageTexture] = []


static func frame(i: int) -> ImageTexture:
	if _frames.is_empty():
		for f in FRAMES:
			_frames.append(ImageTexture.create_from_image(build(f)))
	return _frames[posmod(i, FRAMES)]


static func build(phase: int) -> Image:
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
	# Bloco traseiro escuro.
	PixelArt.rect(img, 4, 5, 6, 10, STEEL)
	PixelArt.rect(img, 4, 5, 6, 1, STEEL_HI)
	PixelArt.rect(img, 4, 14, 6, 1, STEEL_DARK)
	PixelArt.rect(img, 5, 7, 2, 2, Color("1a4f8f"))
	PixelArt.px(img, 5, 7, LIGHT)
	PixelArt.rect(img, 5, 11, 2, 2, Color("1a4f8f"))
	PixelArt.px(img, 5, 11, LIGHT)
	# Bocais traseiros amarelos.
	for y0: int in [5, 11]:
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
	PixelArt.rect(img, 14, 8, 3, 3, SCREEN)
	PixelArt.px(img, 14, 8, SCREEN_HI)
	PixelArt.px(img, 15, 8, SCREEN_HI)
	PixelArt.px(img, 14, 9, SCREEN_HI)
	# Detalhes do casco.
	PixelArt.rect(img, 10, 8, 2, 1, HULL_SHADE)
	PixelArt.rect(img, 10, 10, 2, 1, HULL_SHADE)
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
			var c: Color = DRILL_HI if dy < -0.5 else (DRILL if dy < 1.5 else DRILL_LO)
			img.set_pixel(x, y, c.darkened(0.35) if stripe else c)
	PixelArt.outline(img)
	return img
