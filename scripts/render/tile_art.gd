class_name TileArt
extends RefCounted
## Gera em tempo de execução o atlas de pixel art de todos os blocos (sem assets externos).
## Layout: cada tile ocupa STRIDE×STRIDE px (16 px de arte + 1 px de borda replicada,
## evitando sangramento com filtro nearest). Colunas = variantes; linhas = blocos e extras.

const ART: int = Balance.ART_PX
const PAD: int = 1
const STRIDE: int = ART + PAD * 2
const VARIANTS: int = 4

## Linhas extras após os blocos.
const ROW_BACK: int = BlockRegistry.COUNT          ## + bioma (4 linhas): parede de fundo
const ROW_CRACK: int = ROW_BACK + BiomeRegistry.COUNT  ## 4 estágios de rachadura
const ROW_EDGE: int = ROW_CRACK + 1                 ## bordas: topo, base, esquerda, direita
const ROW_AO: int = ROW_EDGE + 1                    ## sombras projetadas em células de ar
const ROWS: int = ROW_AO + 1

const EDGE_TOP: int = 0
const EDGE_BOTTOM: int = 1
const EDGE_LEFT: int = 2
const EDGE_RIGHT: int = 3

static var _texture: ImageTexture


static func get_texture() -> ImageTexture:
	if _texture == null:
		_texture = ImageTexture.create_from_image(build_image())
	return _texture


## Região de origem (em px do atlas) de um tile.
static func region(row: int, col: int) -> Rect2:
	return Rect2(col * STRIDE + PAD, row * STRIDE + PAD, ART, ART)


static func build_image() -> Image:
	var img := Image.create(STRIDE * VARIANTS, STRIDE * ROWS, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for def: BlockDef in BlockRegistry.all():
		if def.art == BlockDef.Art.NONE:
			continue
		for v in VARIANTS:
			var tile := _block_tile(def, v)
			_blit(img, tile, def.id, v)
	for b in BiomeRegistry.COUNT:
		for v in VARIANTS:
			_blit(img, _back_tile(BiomeRegistry.get_def(b), b * 31 + v), ROW_BACK + b, v)
	for s in 4:
		_blit(img, _crack_tile(s), ROW_CRACK, s)
	for e in 4:
		_blit(img, _edge_tile(e), ROW_EDGE, e)
		_blit(img, _ao_tile(e), ROW_AO, e)
	return img


static func _blit(dst: Image, tile: Image, row: int, col: int) -> void:
	var ox: int = col * STRIDE
	var oy: int = row * STRIDE
	for y in STRIDE:
		for x in STRIDE:
			var sx: int = clampi(x - PAD, 0, ART - 1)
			var sy: int = clampi(y - PAD, 0, ART - 1)
			dst.set_pixel(ox + x, oy + y, tile.get_pixel(sx, sy))


static func _rnd(x: int, y: int, salt: int) -> float:
	return WorldGenerator.hash01(x, y, salt)


static func _new_tile() -> Image:
	var t := Image.create(ART, ART, false, Image.FORMAT_RGBA8)
	t.fill(Color.TRANSPARENT)
	return t


## Base granulada com luz no topo/esquerda e sombra na base/direita.
static func _fill_base(t: Image, base: Color, dark: Color, light: Color, salt: int, grain: float) -> void:
	for y in ART:
		for x in ART:
			var r: float = _rnd(x, y, salt)
			var c: Color = base
			if r < grain * 0.5:
				c = dark
			elif r > 1.0 - grain * 0.35:
				c = light
			else:
				c = base.darkened((r - 0.5) * 0.08)
			t.set_pixel(x, y, c)


static func _bevel(t: Image, amount: float) -> void:
	for i in ART:
		t.set_pixel(i, 0, t.get_pixel(i, 0).lightened(amount))
		t.set_pixel(0, i, t.get_pixel(0, i).lightened(amount * 0.6))
		t.set_pixel(i, ART - 1, t.get_pixel(i, ART - 1).darkened(amount * 1.4))
		t.set_pixel(ART - 1, i, t.get_pixel(ART - 1, i).darkened(amount))


static func _block_tile(def: BlockDef, v: int) -> Image:
	var t := _new_tile()
	var salt: int = def.id * 977 + v * 131
	match def.art:
		BlockDef.Art.DIRT:
			_fill_base(t, def.color_base, def.color_dark, def.color_accent, salt, 0.34)
			# pedrinhas
			for i in 3:
				var px: int = 2 + int(_rnd(i, 1, salt) * 11.0)
				var py: int = 2 + int(_rnd(i, 2, salt) * 11.0)
				t.set_pixel(px, py, Color("9b938c"))
				t.set_pixel(px + 1, py, Color("6f6862"))
			_bevel(t, 0.12)
		BlockDef.Art.STONE, BlockDef.Art.ORE, BlockDef.Art.CRYSTAL, BlockDef.Art.ARTIFACT:
			_fill_base(t, def.color_base, def.color_dark, def.color_accent if def.art == BlockDef.Art.STONE else def.color_base.lightened(0.15), salt, 0.22)
			_stone_cracks(t, def.color_dark, salt)
			_bevel(t, 0.14)
			if def.art == BlockDef.Art.ORE:
				_ore_nuggets(t, def.color_accent, salt)
			elif def.art == BlockDef.Art.CRYSTAL:
				_crystals(t, def.color_accent, salt)
			elif def.art == BlockDef.Art.ARTIFACT:
				_artifact(t, def.color_accent)
		BlockDef.Art.MAGMA:
			_fill_base(t, def.color_base, def.color_dark, def.color_base.lightened(0.1), salt, 0.25)
			_magma_veins(t, def.color_accent, salt)
			_bevel(t, 0.1)
		BlockDef.Art.BEDROCK:
			_fill_base(t, def.color_base, def.color_dark, def.color_accent, salt, 0.45)
			for i in 5:
				var px: int = int(_rnd(i, 7, salt) * 14.0)
				var py: int = int(_rnd(i, 8, salt) * 14.0)
				t.set_pixel(px, py, def.color_dark.darkened(0.3))
				t.set_pixel(px + 1, py + 1, def.color_dark.darkened(0.3))
				t.set_pixel(px + 1, py, def.color_accent)
			_bevel(t, 0.06)
		BlockDef.Art.CHEST:
			_fill_base(t, Color("6b4a35"), Color("4a3123"), Color("7d5a42"), salt, 0.3)
			_chest(t, def)
	return t


static func _stone_cracks(t: Image, dark: Color, salt: int) -> void:
	var x: int = int(_rnd(0, 9, salt) * 10.0) + 3
	var y: int = int(_rnd(1, 9, salt) * 4.0) + 2
	for i in 6:
		t.set_pixel(clampi(x, 1, ART - 2), clampi(y, 1, ART - 2), dark.darkened(0.15))
		x += int(_rnd(i, 10, salt) * 3.0) - 1
		y += 1


static func _ore_nuggets(t: Image, accent: Color, salt: int) -> void:
	# Pepitas de 3×2 a 3×3 px com brilho e sombra, legíveis em telas pequenas.
	var count: int = 3 + int(_rnd(3, 3, salt) * 2.0)
	for i in count:
		var cx: int = 2 + int(_rnd(i, 4, salt) * 10.0)
		var cy: int = 2 + int(_rnd(i, 5, salt) * 10.0)
		var big: bool = _rnd(i, 6, salt) > 0.5
		for dy in (3 if big else 2):
			for dx in 3:
				var c: Color = accent if dy == 0 else accent.darkened(0.2 + 0.15 * dy)
				t.set_pixel(clampi(cx + dx, 1, ART - 2), clampi(cy + dy, 1, ART - 2), c)
		t.set_pixel(clampi(cx, 1, ART - 2), clampi(cy, 1, ART - 2), accent.lightened(0.55))
		t.set_pixel(clampi(cx + 3, 1, ART - 2), clampi(cy + 1, 1, ART - 2), Color(0, 0, 0, 0.35))


static func _crystals(t: Image, accent: Color, salt: int) -> void:
	# Brilho de fundo para destacar o depósito.
	for y in ART:
		for x in ART:
			if _rnd(x, y, salt + 55) < 0.12:
				t.set_pixel(x, y, t.get_pixel(x, y).lerp(accent, 0.35))
	var count: int = 3 + int(_rnd(4, 4, salt) * 2.0)
	for i in count:
		var cx: int = 2 + int(_rnd(i, 6, salt) * 11.0)
		var base_y: int = 12 + int(_rnd(i, 7, salt) * 3.0)
		var h: int = 5 + int(_rnd(i, 8, salt) * 5.0)
		for k in h:
			var y: int = base_y - k
			if y < 1:
				break
			var narrow: bool = k >= h - 2
			t.set_pixel(cx, y, accent.lightened(0.25) if k > h / 2 else accent)
			if not narrow:
				t.set_pixel(cx + 1, y, accent.darkened(0.3))
				t.set_pixel(clampi(cx - 1, 0, ART - 1), y, accent.darkened(0.5))
		t.set_pixel(cx, maxi(1, base_y - h + 1), Color.WHITE)


static func _magma_veins(t: Image, accent: Color, salt: int) -> void:
	var y: int = 3 + int(_rnd(0, 11, salt) * 6.0)
	for x in ART:
		var yy: int = clampi(y + int(_rnd(x, 12, salt) * 3.0) - 1, 1, ART - 2)
		t.set_pixel(x, yy, accent)
		t.set_pixel(x, yy + 1, accent.darkened(0.45))
		if _rnd(x, 13, salt) < 0.25:
			t.set_pixel(x, yy - 1, accent.lightened(0.35))
		y = yy


static func _artifact(t: Image, accent: Color) -> void:
	# Glifo ancestral: anel com núcleo brilhante.
	var c := Vector2(7.5, 7.5)
	for y in ART:
		for x in ART:
			var d: float = Vector2(x, y).distance_to(c)
			if d > 3.6 and d < 5.0:
				t.set_pixel(x, y, accent.darkened(0.2))
			elif d <= 1.6:
				t.set_pixel(x, y, accent.lightened(0.5))
	for i: int in [3, 12]:
		t.set_pixel(i, 7, accent)
		t.set_pixel(7, i, accent)


static func _chest(t: Image, def: BlockDef) -> void:
	var wood: Color = def.color_base
	var dark: Color = def.color_dark
	var gold: Color = def.color_accent
	for y in range(4, 13):
		for x in range(2, 14):
			var c: Color = wood if (y % 3 != 0) else wood.darkened(0.2)
			if x == 2 or x == 13 or y == 4 or y == 12:
				c = dark
			t.set_pixel(x, y, c)
	for x in range(2, 14):
		t.set_pixel(x, 7, gold.darkened(0.3))
	for y in range(7, 10):
		t.set_pixel(7, y, gold)
		t.set_pixel(8, y, gold.darkened(0.2))
	t.set_pixel(7, 8, Color("2a1a0c"))
	t.set_pixel(3, 5, wood.lightened(0.3))


static func _back_tile(biome: BiomeDef, salt: int) -> Image:
	var t := _new_tile()
	var base: Color = biome.back_color
	_fill_base(t, base, base.darkened(0.25), base.lightened(0.08), salt + 7001, 0.3)
	return t


static func _crack_tile(stage: int) -> Image:
	var t := _new_tile()
	var c := Color(0.05, 0.03, 0.03, 0.85)
	var hl := Color(1, 1, 1, 0.18)
	# Segmentos acumulativos a partir do centro.
	var paths: Array = [
		[Vector2i(7, 7), Vector2i(8, 6), Vector2i(9, 5), Vector2i(6, 8), Vector2i(5, 9)],
		[Vector2i(10, 4), Vector2i(11, 3), Vector2i(4, 10), Vector2i(3, 11), Vector2i(8, 8), Vector2i(9, 9), Vector2i(10, 10)],
		[Vector2i(6, 6), Vector2i(5, 5), Vector2i(4, 4), Vector2i(11, 11), Vector2i(12, 12), Vector2i(9, 7), Vector2i(11, 7), Vector2i(12, 7), Vector2i(2, 12), Vector2i(12, 2)],
		[Vector2i(7, 3), Vector2i(7, 2), Vector2i(7, 1), Vector2i(3, 7), Vector2i(2, 7), Vector2i(1, 7), Vector2i(13, 8), Vector2i(14, 9), Vector2i(8, 12), Vector2i(8, 13), Vector2i(9, 14), Vector2i(13, 13), Vector2i(1, 13)],
	]
	for s in stage + 1:
		for p: Vector2i in paths[s]:
			t.set_pixel(p.x, p.y, c)
			if p.y + 1 < ART:
				t.set_pixel(p.x, p.y + 1, hl)
	return t


static func _edge_tile(edge: int) -> Image:
	var t := _new_tile()
	var light := Color(1.0, 0.96, 0.85, 0.30)
	var shade := Color(0.0, 0.0, 0.0, 0.45)
	for i in ART:
		match edge:
			EDGE_TOP:
				t.set_pixel(i, 0, light)
				t.set_pixel(i, 1, Color(light, 0.12))
			EDGE_BOTTOM:
				t.set_pixel(i, ART - 1, shade)
				t.set_pixel(i, ART - 2, Color(shade, 0.2))
			EDGE_LEFT:
				t.set_pixel(0, i, Color(shade, 0.3))
			EDGE_RIGHT:
				t.set_pixel(ART - 1, i, Color(shade, 0.3))
	return t


## Sombra suave dentro de uma célula de ar, vinda do bloco sólido vizinho (direção = edge).
static func _ao_tile(edge: int) -> Image:
	var t := _new_tile()
	for k in 5:
		var a: float = 0.42 * (1.0 - float(k) / 5.0)
		var c := Color(0, 0, 0, a)
		for i in ART:
			match edge:
				EDGE_TOP:
					t.set_pixel(i, k, c)
				EDGE_BOTTOM:
					t.set_pixel(i, ART - 1 - k, Color(0, 0, 0, a * 0.5))
				EDGE_LEFT:
					t.set_pixel(k, i, Color(0, 0, 0, a * 0.7))
				EDGE_RIGHT:
					t.set_pixel(ART - 1 - k, i, Color(0, 0, 0, a * 0.7))
	return t
