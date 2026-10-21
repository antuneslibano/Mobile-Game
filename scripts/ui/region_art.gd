class_name RegionArt
extends RefCounted
## Ilustração procedural de cada região (ilha flutuante em pixel art, sem imagens externas).
## As faixas do penhasco usam as cores das camadas reais da região.

const W: int = 150
const H: int = 112
const CX: float = 75.0
const TOP_Y: float = 44.0
const RX: float = 62.0
const RY: float = 13.0

static var _cache: Dictionary = {}


static func texture(r: RegionDef) -> ImageTexture:
	if not _cache.has(r.id):
		_cache[r.id] = ImageTexture.create_from_image(build(r))
	return _cache[r.id]


static func _h(x: int, y: int, salt: int) -> float:
	return WorldGenerator.hash01(x, y, salt)


static func build(r: RegionDef) -> Image:
	var img := PixelArt.new_img(W, H)
	_cliff(img, r)
	_top(img, r)
	match r.theme:
		&"savanna":
			_savanna(img)
		&"desert":
			_desert(img)
		&"mountain":
			_mountain(img)
		&"swamp":
			_swamp(img)
		&"volcanic":
			_volcanic(img)
		&"crystal":
			_crystal(img)
	_floating_rocks(img, r)
	PixelArt.outline(img)
	return img


## Penhasco da ilha com estratos nas cores das camadas da região.
static func _cliff(img: Image, r: RegionDef) -> void:
	var bands: Array[int] = [7, 9, 10, 11, 14, 16]
	for x in range(int(CX - RX), int(CX + RX) + 1):
		var t: float = (x - CX) / RX
		if absf(t) > 1.0:
			continue
		var edge: float = TOP_Y + RY * sqrt(1.0 - t * t)
		var depth: float = 52.0 * pow(1.0 - t * t, 0.7) + _h(x, 0, 11) * 5.0
		var bottom: int = int(edge + depth)
		for y in range(int(TOP_Y), bottom):
			var d: float = y - edge
			if y < edge - 0.5:
				continue
			var acc: int = 0
			var layer: int = 0
			for i in bands.size():
				acc += bands[i]
				if d + (_h(x / 3, i, 21) - 0.5) * 3.0 < acc:
					layer = i
					break
				layer = i + 1
			var biome: BiomeDef = r.layers[mini(layer, r.layers.size() - 1)]
			var def: BlockDef = BlockRegistry.get_def(biome.primary_block)
			var n: float = _h(x, y, 31 + layer)
			var c: Color = def.color_base if n > 0.35 else def.color_dark
			if n > 0.86:
				c = def.color_base.lightened(0.18)
			# Luz da esquerda, sombra à direita e na base.
			c = c.darkened(clampf(t * 0.22, -0.1, 0.25) + clampf((y - edge) / depth, 0.0, 1.0) * 0.18)
			PixelArt.px(img, x, y, c)


static func _top_colors(theme: StringName) -> Array[Color]:
	match theme:
		&"savanna":
			return [Color("8bbf3a"), Color("6a9a2a"), Color("b5d65a")]
		&"desert":
			return [Color("e8b860"), Color("c99440"), Color("f6d88a")]
		&"mountain":
			return [Color("7c8594"), Color("5a6270"), Color("a8b0bc")]
		&"swamp":
			return [Color("3f6b3a"), Color("2c4f2a"), Color("5f8f4a")]
		&"volcanic":
			return [Color("3a2c2e"), Color("241a1c"), Color("54403f")]
		_:
			return [Color("4a3a7a"), Color("33275a"), Color("6a56a8")]


static func _top(img: Image, r: RegionDef) -> void:
	var c: Array[Color] = _top_colors(r.theme)
	for y in range(int(TOP_Y - RY), int(TOP_Y + RY) + 1):
		for x in range(int(CX - RX), int(CX + RX) + 1):
			var e: float = pow((x - CX) / RX, 2.0) + pow((y - TOP_Y) / RY, 2.0)
			if e > 1.0:
				continue
			var n: float = _h(x, y, 41)
			var col: Color = c[0] if n > 0.3 else c[1]
			if n > 0.88 or (y < TOP_Y - RY * 0.55 and n > 0.6):
				col = c[2]
			if e > 0.86 and y > TOP_Y:
				col = col.darkened(0.2)
			PixelArt.px(img, x, y, col)


static func _tree(img: Image, x: int, base_y: int, h: int, w: int, leaf: Color) -> void:
	PixelArt.rect(img, x, base_y - h, 2, h, Color("5a3a22"))
	PixelArt.rect(img, x - 3, base_y - h + 2, 3, 1, Color("5a3a22"))
	PixelArt.rect(img, x + 2, base_y - h + 3, 3, 1, Color("5a3a22"))
	for dx in range(-w, w + 1):
		var t: float = absf(float(dx) / w)
		var hh: int = int(3.0 * (1.0 - t * t)) + 1
		PixelArt.rect(img, x + dx, base_y - h - hh, 1, hh, leaf)
		PixelArt.px(img, x + dx, base_y - h, leaf.darkened(0.3))
	PixelArt.rect(img, x - w / 2, base_y - h - 4, w, 1, leaf.lightened(0.25))


static func _savanna(img: Image) -> void:
	# Mesas vermelhas ao fundo.
	PixelArt.rect(img, 30, 27, 14, 10, Color("b0583a"))
	PixelArt.rect(img, 30, 27, 14, 2, Color("d07a50"))
	PixelArt.rect(img, 96, 24, 18, 13, Color("a04e34"))
	PixelArt.rect(img, 96, 24, 18, 2, Color("c96a46"))
	PixelArt.rect(img, 112, 30, 8, 7, Color("8a4430"))
	# Acácias.
	_tree(img, 52, 44, 14, 11, Color("5f9a2e"))
	_tree(img, 88, 47, 11, 8, Color("6aa832"))
	_tree(img, 116, 44, 9, 7, Color("5f9a2e"))
	# Caminho de terra.
	for i in 30:
		PixelArt.px(img, 60 + i, 47 + int(sin(i * 0.3) * 2.0), Color("c08a52"))
	PixelArt.rect(img, 40, 46, 2, 3, Color("4f8a2a"))
	PixelArt.rect(img, 39, 47, 1, 1, Color("4f8a2a"))


static func _desert(img: Image) -> void:
	for x in range(20, 130):
		var y0: int = int(TOP_Y - 4 - 6.0 * maxf(0.0, sin((x - 20) * 0.07)))
		for y in range(y0, int(TOP_Y + 2)):
			if pow((x - CX) / RX, 2.0) + pow((y - TOP_Y) / RY, 2.0) <= 1.0 or y < TOP_Y:
				PixelArt.px(img, x, y, Color("f0c46a") if y < y0 + 2 else Color("e0aa52"))
	for cx: int in [42, 108]:
		PixelArt.rect(img, cx, 30, 3, 14, Color("4f9a3a"))
		PixelArt.rect(img, cx - 3, 34, 3, 2, Color("4f9a3a"))
		PixelArt.rect(img, cx - 3, 31, 2, 3, Color("4f9a3a"))
		PixelArt.rect(img, cx + 3, 36, 3, 2, Color("4f9a3a"))
		PixelArt.rect(img, cx + 4, 33, 2, 3, Color("4f9a3a"))
		PixelArt.rect(img, cx, 30, 1, 14, Color("6fbe4a"))
	# Ossada de costelas.
	for i in 5:
		var x: int = 66 + i * 4
		for k in 6:
			PixelArt.px(img, x + int(k * 0.4), 40 - k + (2 if i % 2 == 0 else 0), Color("efe6d0"))
	PixelArt.rect(img, 64, 41, 22, 2, Color("e4d8bc"))
	PixelArt.rect(img, 86, 39, 5, 4, Color("efe6d0"))


static func _peak(img: Image, x0: int, base_y: int, w: int, h: int) -> void:
	for dx in range(-w, w + 1):
		var col_h: int = int(h * (1.0 - absf(float(dx)) / w)) + int(_h(x0 + dx, 0, 7) * 2.0)
		for k in col_h:
			var y: int = base_y - k
			var c: Color = Color("8a93a3") if dx < 0 else Color("5a6270")
			if k > col_h - int(h * 0.22):
				c = Color("e8eef6") if dx < 0 else Color("c4ccd8")
			PixelArt.px(img, x0 + dx, y, c)


static func _mountain(img: Image) -> void:
	_peak(img, 50, 44, 22, 32)
	_peak(img, 92, 44, 26, 40)
	_peak(img, 122, 46, 12, 18)
	# Entrada de mina com lâmpada.
	PixelArt.rect(img, 70, 38, 9, 8, Color("1a1a22"))
	PixelArt.rect(img, 69, 37, 11, 1, Color("6b4a2a"))
	PixelArt.rect(img, 69, 37, 1, 9, Color("6b4a2a"))
	PixelArt.rect(img, 79, 37, 1, 9, Color("6b4a2a"))
	PixelArt.px(img, 74, 40, Color("ffd36b"))
	PixelArt.px(img, 73, 41, Color("ffb02e"))


static func _swamp(img: Image) -> void:
	for p: Vector3 in [Vector3(55, 44, 12), Vector3(95, 46, 10)]:
		for y in range(int(p.y) - 3, int(p.y) + 4):
			for x in range(int(p.x - p.z), int(p.x + p.z) + 1):
				if pow((x - p.x) / p.z, 2.0) + pow((y - p.y) / 3.5, 2.0) <= 1.0:
					PixelArt.px(img, x, y, Color("2f8a8a") if _h(x, y, 5) > 0.2 else Color("6ad0c8"))
	# Cachoeira descendo pelo penhasco.
	for y in range(48, 92):
		PixelArt.rect(img, 104, y, 4, 1, Color("6ad0c8") if (y % 4) < 2 else Color("3fa8a8"))
	# Árvores mortas e musgo.
	for t: Vector2i in [Vector2i(38, 44), Vector2i(78, 42), Vector2i(118, 44)]:
		PixelArt.rect(img, t.x, t.y - 16, 2, 16, Color("3a3226"))
		PixelArt.rect(img, t.x - 4, t.y - 12, 4, 1, Color("3a3226"))
		PixelArt.rect(img, t.x + 2, t.y - 9, 4, 1, Color("3a3226"))
		PixelArt.rect(img, t.x - 5, t.y - 14, 1, 2, Color("3a3226"))
		PixelArt.rect(img, t.x - 3, t.y - 18, 7, 3, Color("3f7a3a"))


static func _volcanic(img: Image) -> void:
	# Vulcão com cratera brilhante.
	for dx in range(-30, 31):
		var h: int = int(30.0 * (1.0 - absf(float(dx)) / 30.0))
		for k in h:
			var c: Color = Color("3a2c2e") if dx < 0 else Color("261c1e")
			PixelArt.px(img, 75 + dx, 44 - k, c)
	PixelArt.rect(img, 70, 14, 11, 3, Color("ff7a2e"))
	PixelArt.rect(img, 72, 14, 7, 1, Color("ffd36b"))
	# Rios de lava descendo.
	for i in 40:
		var x: int = 75 + int(sin(i * 0.25) * 6.0) - i / 6
		PixelArt.px(img, x, 17 + i, Color("ff7a2e") if i % 5 else Color("ffd36b"))
		PixelArt.px(img, x + 1, 17 + i, Color("e04a1a"))
	for i in 34:
		var x: int = 82 + i / 2
		PixelArt.px(img, x, 30 + i, Color("ff7a2e"))
	# Fumaça.
	for p: Vector2i in [Vector2i(72, 8), Vector2i(78, 4), Vector2i(84, 1)]:
		PixelArt.circle(img, p.x, p.y, 3.5, Color("5a5058"))


static func _crystal(img: Image) -> void:
	for spec: Vector4 in [Vector4(52, 44, 4, 26), Vector4(64, 44, 3, 18), Vector4(78, 42, 5, 34), Vector4(94, 44, 3, 20), Vector4(108, 45, 4, 24)]:
		var x0: int = int(spec.x)
		var w: int = int(spec.z)
		var h: int = int(spec.w)
		for k in h:
			var half: int = int(w * (1.0 - float(k) / h)) + 1
			for dx in range(-half, half + 1):
				var c: Color = Color("6fe3ff") if dx < 0 else Color("3f8fe6")
				if k > h - 4:
					c = Color("c9f3ff")
				PixelArt.px(img, x0 + dx, int(spec.y) - k, c)
	# Fragmentos flutuantes roxos.
	for p: Vector2i in [Vector2i(30, 20), Vector2i(124, 16), Vector2i(116, 30)]:
		PixelArt.poly(img, PackedVector2Array([Vector2(p.x, p.y - 5), Vector2(p.x + 3, p.y), Vector2(p.x, p.y + 4), Vector2(p.x - 3, p.y)]), Color("b06cff"))
	# Trilha luminosa.
	for i in 40:
		PixelArt.px(img, 50 + i, 48 - int(sin(i * 0.2) * 2.0), Color("c08cff"))


static func _floating_rocks(img: Image, r: RegionDef) -> void:
	var def: BlockDef = BlockRegistry.get_def(r.layers[0].primary_block)
	for p: Vector3 in [Vector3(14, 72, 4), Vector3(136, 64, 3), Vector3(28, 96, 2.5)]:
		PixelArt.circle(img, p.x, p.y, p.z, def.color_dark)
		PixelArt.circle(img, p.x - 1, p.y - 1, p.z * 0.6, def.color_base)
