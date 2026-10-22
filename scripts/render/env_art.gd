class_name EnvArt
extends RefCounted
## Gerador da pixel art do ambiente: texturas de terreno repetíveis (64×64 pixels de arte),
## depósitos minerais (16×16), vegetação e decorações. Roda offline em
## tools/gen_env_assets.gd e grava PNGs em assets/environment/; o jogo usa só os PNGs
## (que podem ser retocados à mão). Escala: 1 pixel de arte = 3 px na tela (art_px).
##
## Tudo é determinístico (mesmas seeds → mesmos arquivos) e as texturas de terreno são
## periódicas (Voronoi em grade com envoltório, ruído periódico), então repetem sem emendas.
## Estilo da referência: torrões em "bolhas" com pontinho de brilho, frestas escuras entre
## grupos de torrões, luz vinda do alto à esquerda, contorno escuro nos sprites.

const TILE: int = 64
const ORE: int = 16
## Direção para onde a luz aponta a partir do objeto (alto-esquerda): n·LIT > 0 = lado claro.
const LIT := Vector2(-0.6, -0.8)


# --- Utilidades ----------------------------------------------------------------------

static func hash01(x: int, y: int, s: int) -> float:
	var n: int = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0


## Ruído de valor periódico no tile (cells divide TILE).
static func vnoise(x: float, y: float, cells: int, s: int) -> float:
	var fx: float = x / TILE * cells
	var fy: float = y / TILE * cells
	var ix: int = floori(fx)
	var iy: int = floori(fy)
	var tx: float = fx - ix
	var ty: float = fy - iy
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a: float = hash01(posmod(ix, cells), posmod(iy, cells), s)
	var b: float = hash01(posmod(ix + 1, cells), posmod(iy, cells), s)
	var c: float = hash01(posmod(ix, cells), posmod(iy + 1, cells), s)
	var d: float = hash01(posmod(ix + 1, cells), posmod(iy + 1, cells), s)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


static func fbm(x: float, y: float, s: int) -> float:
	return vnoise(x, y, 4, s) * 0.5 + vnoise(x, y, 8, s + 1) * 0.3 + vnoise(x, y, 16, s + 2) * 0.2


## Diferença com envoltório (menor caminho no toro do tile).
static func wrap_delta(a: Vector2, b: Vector2) -> Vector2:
	var d: Vector2 = a - b
	d.x -= TILE * roundf(d.x / TILE)
	d.y -= TILE * roundf(d.y / TILE)
	return d


## Voronoi em grade com jitter, periódico no tile (g células por lado, qualquer g inteiro).
## Retorna [d1, d2, rel (pixel − ponto), id da célula].
static func jvor(p: Vector2, g: int, s: int) -> Array:
	var cs: float = float(TILE) / g
	var cx: int = floori(p.x / cs)
	var cy: int = floori(p.y / cs)
	var d1: float = 1e9
	var d2: float = 1e9
	var rel := Vector2.ZERO
	var id: int = 0
	for j in range(-1, 2):
		for i in range(-1, 2):
			var gx: int = cx + i
			var gy: int = cy + j
			var hx: int = posmod(gx, g)
			var hy: int = posmod(gy, g)
			var pt := Vector2((gx + 0.12 + 0.76 * hash01(hx, hy, s)) * cs, (gy + 0.12 + 0.76 * hash01(hx, hy, s + 1)) * cs)
			var dv: Vector2 = p - pt
			var d: float = dv.length()
			if d < d1:
				d2 = d1
				d1 = d
				rel = dv
				id = hy * g + hx
			elif d < d2:
				d2 = d
	return [d1, d2, rel, id]


static func ramp(hexes: Array) -> Array[Color]:
	var out: Array[Color] = []
	for h: String in hexes:
		out.append(Color(h))
	return out


# --- Texturas de terreno ---------------------------------------------------------------

## Torrões em dois níveis (como a referência): grupos grandes separados por frestas escuras
## e, dentro deles, "bolhas" pequenas sombreadas com um pontinho de brilho.
## ramp = [fresta, escuro, médio, claro, brilho].
static func bubbles(spec: Dictionary) -> Image:
	var s: int = spec.get("seed", 1)
	var pal: Array[Color] = ramp(spec.ramp)
	var pal2: Array[Color] = ramp(spec.get("ramp2", spec.ramp))
	var mix2: float = spec.get("mix2", 0.0)
	var g_macro: int = spec.get("macro", 5)
	var g_micro: int = spec.get("micro", 13)
	var crev: float = spec.get("crev", 0.0)
	var mc: float = spec.get("macro_c", 0.35)
	var uc: float = spec.get("micro_c", 1.0)
	var speck: float = spec.get("speck", 0.5)
	var pocket: float = spec.get("pocket", 0.92)
	var solid_cracks: bool = spec.get("cracks", false)
	var tone: float = spec.get("tone", 0.7)
	var glint: Color = Color(spec.get("glint", "00000000"))
	var cs_macro: float = float(TILE) / g_macro
	var cs_micro: float = float(TILE) / g_micro
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y in TILE:
		for x in TILE:
			var p := Vector2(x + 0.5, y + 0.5)
			var big: Array = jvor(p, g_macro, s)
			var small: Array = jvor(p, g_micro, s + 7)
			var pl: Array[Color] = pal2 if mix2 > 0.0 and hash01(big[3], 3, s) < mix2 else pal
			var e: float = (float(big[1]) - float(big[0])) * 0.5
			var w: float = crev * (0.5 + 0.9 * fbm(x, y, s + 21))
			var u_big: Vector2 = (big[2] as Vector2) / (cs_macro * 0.6)
			var u_small: Vector2 = (small[2] as Vector2) / (cs_micro * 0.62)
			var um: float = u_small.length()
			var lit_s: float = clampf(u_small.dot(LIT), -1.0, 1.0)
			var idx: int
			if e < w and (solid_cracks or fbm(x, y, s + 33) > 0.47):
				# Bolsões fundos entre grupos de torrões (não linhas contínuas).
				idx = 0 if e < w * 0.5 else 1
			elif float(small[0]) > cs_micro * 0.62 * pocket:
				# Vãos entre torrões pequenos (onde nenhum torrão chega).
				idx = 1 if float(small[0]) < cs_micro * 0.62 * (pocket + 0.25) else 0
			else:
				var lvl: float = 2.0 + (hash01(big[3], 5, s) - 0.5) * tone
				lvl += clampf(u_big.dot(LIT), -1.0, 1.0) * mc + lit_s * uc
				lvl -= maxf(0.0, um - 0.55) * (1.8 if lit_s < 0.0 else 0.4)
				if e < w + 1.0 and fbm(x, y, s + 33) > 0.47:
					lvl -= 0.7
				idx = clampi(roundi(lvl), 1, 3)
				if (u_small - Vector2(-0.33, -0.38)).length() < 0.2 and hash01(small[3], 11, s) < speck:
					idx = 4
			var col: Color = pl[idx]
			if glint.a > 0.0 and idx >= 2 and hash01(x, y, s + 13) < 0.01:
				col = glint
			img.set_pixel(x, y, col)
	return img


## As 16 texturas do Vale das Raízes (ordem = índice no atlas; ver TerrainSkins.TILES).
static func terrain_tiles() -> Dictionary:
	var t: Dictionary = {}
	var dark_dirt := ["160a06", "34190e", "4a2818", "623826", "946048"]
	t["terra_clara"] = bubbles({"seed": 11, "macro": 5, "micro": 13, "ramp": ["461a08", "963c14", "c0581e", "de7832", "ffb26e"]})
	t["terra_escura"] = bubbles({"seed": 12, "macro": 5, "micro": 13, "ramp": dark_dirt, "speck": 0.35})
	t["argila"] = bubbles({"seed": 13, "macro": 4, "micro": 13, "ramp": ["3a0c06", "862212", "ae341c", "d04e2c", "f28a62"], "speck": 0.4})
	t["solo_compacto"] = bubbles({"seed": 14, "macro": 6, "micro": 16, "ramp": ["3c1e0e", "7c4422", "98582e", "b0703c", "d29a66"],
			"macro_c": 0.35, "micro_c": 0.6, "speck": 0.3})
	t["solo_umido"] = bubbles({"seed": 15, "macro": 5, "micro": 14, "ramp": ["0e0604", "221208", "301a10", "40261a", "6a4c3c"],
			"speck": 0.15, "glint": "8fa6b6"})
	t["solo_com_raizes"] = add_roots(bubbles({"seed": 16, "macro": 5, "micro": 13, "ramp": dark_dirt, "speck": 0.3}), 17, 3)
	t["solo_com_musgo"] = add_moss(bubbles({"seed": 18, "macro": 5, "micro": 13, "ramp": ["1a1208", "38281a", "4c3624", "604630", "8a6a4e"], "speck": 0.3}), 19)
	t["solo_rachado"] = bubbles({"seed": 20, "macro": 4, "micro": 14, "ramp": ["2a0e04", "8e3c16", "b45a24", "cc7438", "eaa266"],
			"crev": 1.6, "cracks": true, "macro_c": 0.7, "micro_c": 0.45, "speck": 0.25, "pocket": 1.6})
	t["pedra_clara"] = bubbles({"seed": 21, "macro": 4, "micro": 9, "ramp": ["383236", "867e82", "a49c9e", "c2bcbc", "eeeae6"]})
	t["pedra_cinza"] = bubbles({"seed": 22, "macro": 4, "micro": 9, "ramp": ["221e2a", "585066", "726a82", "8c849e", "bcb4cc"]})
	t["pedra_escura"] = bubbles({"seed": 23, "macro": 4, "micro": 9, "ramp": ["0e0a10", "28222a", "38303c", "4a4250", "766a7a"]})
	t["rocha_compacta"] = bubbles({"seed": 24, "macro": 3, "micro": 7, "ramp": ["282628", "585660", "706e78", "8a8892", "b8b6be"],
			"crev": 1.5, "macro_c": 0.8, "micro_c": 0.6})
	t["rocha_profunda"] = bubbles({"seed": 25, "macro": 4, "micro": 9, "ramp": ["0a0612", "1c162c", "2a223c", "3a304e", "665888"]})
	t["terra_avermelhada"] = bubbles({"seed": 26, "macro": 5, "micro": 13, "ramp": ["2c0a04", "781e0e", "9e2c16", "c24024", "ea7448"]})
	t["solo_arenoso"] = bubbles({"seed": 27, "macro": 6, "micro": 20, "ramp": ["6a3410", "be6e2c", "d6883e", "eca658", "ffd08a"],
			"macro_c": 0.3, "micro_c": 0.7, "speck": 0.35})
	t["solo_misto"] = bubbles({"seed": 28, "macro": 5, "micro": 14, "ramp": ["28140a", "6c3c1e", "86502a", "a0663a", "c88e62"],
			"ramp2": ["282428", "605a5e", "7a7276", "948c8e", "c0b8b4"], "mix2": 0.35})
	return t


# --- Tela de sprite ----------------------------------------------------------------------

## Tela com índices de paleta (-1 = transparente). Com wrap = true as coordenadas dão a
## volta (para pintar por cima de texturas repetíveis).
class Canvas:
	var w: int
	var h: int
	var wrap: bool
	var buf: PackedInt32Array
	var pal: Array[Color]

	func _init(p_w: int, p_h: int, p_pal: Array[Color], p_wrap: bool = false) -> void:
		w = p_w
		h = p_h
		pal = p_pal
		wrap = p_wrap
		buf.resize(w * h)
		buf.fill(-1)

	func setp(x: int, y: int, i: int) -> void:
		if wrap:
			x = posmod(x, w)
			y = posmod(y, h)
		elif x < 0 or y < 0 or x >= w or y >= h:
			return
		buf[y * w + x] = i

	func getp(x: int, y: int) -> int:
		if wrap:
			return buf[posmod(y, h) * w + posmod(x, w)]
		if x < 0 or y < 0 or x >= w or y >= h:
			return -1
		return buf[y * w + x]

	func _range(lo: float, hi: float, n: int) -> Array[int]:
		if wrap:
			return [floori(lo), ceili(hi) + 1]
		return [maxi(0, floori(lo)), mini(n, ceili(hi) + 1)]

	func poly(pts: PackedVector2Array, shade: Callable) -> void:
		var r := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			r = r.expand(p)
		var ry: Array[int] = _range(r.position.y, r.end.y, h)
		var rx: Array[int] = _range(r.position.x, r.end.x, w)
		for y in range(ry[0], ry[1]):
			for x in range(rx[0], rx[1]):
				var c := Vector2(x + 0.5, y + 0.5)
				if Geometry2D.is_point_in_polygon(c, pts):
					var v: int = shade.call(c)
					if v >= 0:
						setp(x, y, v)

	func disc(center: Vector2, r: float, shade: Callable, ry_scale: float = 1.0) -> void:
		var ry: Array[int] = _range(center.y - r * ry_scale, center.y + r * ry_scale, h)
		var rx: Array[int] = _range(center.x - r, center.x + r, w)
		for y in range(ry[0], ry[1]):
			for x in range(rx[0], rx[1]):
				var c := Vector2(x + 0.5, y + 0.5)
				var d := Vector2(c.x - center.x, (c.y - center.y) / ry_scale)
				if d.length() <= r:
					var v: int = shade.call(c)
					if v >= 0:
						setp(x, y, v)

	## Contorno de 1 px (vizinhança 4) em volta de tudo o que foi pintado.
	func outline(i: int) -> void:
		var add: Array[Vector2i] = []
		for y in h:
			for x in w:
				if getp(x, y) != -1:
					continue
				for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var v: int = getp(x + o.x, y + o.y)
					if v != -1 and v != i:
						add.append(Vector2i(x, y))
						break
		for p in add:
			setp(p.x, p.y, i)

	## Halo translúcido (vizinhança 8) em volta do sprite já contornado.
	func glow(i: int) -> void:
		var add: Array[Vector2i] = []
		for y in h:
			for x in w:
				if getp(x, y) != -1:
					continue
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						var v: int = getp(x + ox, y + oy)
						if v != -1 and v != i:
							add.append(Vector2i(x, y))
							break
		for p in add:
			setp(p.x, p.y, i)

	func image() -> Image:
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var v: int = buf[y * w + x]
				img.set_pixel(x, y, Color(0, 0, 0, 0) if v < 0 else pal[v])
		return img

	## Pinta os pixels marcados por cima de uma imagem (para texturas).
	func over(img: Image) -> Image:
		var out: Image = img.duplicate()
		for y in h:
			for x in w:
				var v: int = buf[y * w + x]
				if v >= 0:
					out.set_pixel(x, y, pal[v])
		return out


static func _pal(hexes: Array) -> Array[Color]:
	return ramp(hexes)


# --- Raízes (texturas e sprites) -----------------------------------------------------------

const ROOT_RAMP := ["120804", "4a2210", "6e3818", "94522a", "c47c46"]


## Caminho suave (curvas por senos, sem tremido) afinando da base à ponta.
static func root_path(start: Vector2, ang: float, length: int, thick: float, s: int, sway: float = 0.45) -> Array:
	var pts := PackedVector2Array()
	var rad := PackedFloat32Array()
	var pos: Vector2 = start
	var f: float = 0.06 + hash01(1, 2, s) * 0.06
	var ph: float = hash01(3, 4, s) * TAU
	for i in length:
		pts.append(pos)
		rad.append(maxf(0.55, thick * 0.5 * (1.0 - float(i) / length * 0.82)))
		var a: float = ang + sin(i * f + ph) * sway + sin(i * f * 2.3 + ph * 1.7) * sway * 0.4
		pos += Vector2(cos(a), sin(a))
	return [pts, rad]


## Raiz principal + ramificações finas.
static func root_tree(start: Vector2, ang: float, length: int, thick: float, s: int, branches: int, sway: float = 0.45) -> Array:
	var out: Array = [root_path(start, ang, length, thick, s, sway)]
	var main: PackedVector2Array = out[0][0]
	for b in branches:
		var k: int = int(main.size() * (0.2 + 0.6 * hash01(b, 5, s)))
		var side: float = 0.75 if hash01(b, 6, s) < 0.5 else -0.75
		out.append(root_path(main[k], ang + side, int(length * (0.3 + 0.25 * hash01(b, 7, s))), thick * 0.45, s + 31 * (b + 1), sway))
	return out


## Pinta raízes numa tela: sombreamento cilíndrico (lado da luz claro com faixa de brilho,
## lado oposto escuro) e contorno. Índices: 1 escuro, 2 médio, 3 claro, 4 brilho; 0 contorno.
static func paint_roots(cv: Canvas, paths: Array) -> void:
	for y in cv.h:
		for x in cv.w:
			var p := Vector2(x + 0.5, y + 0.5)
			var best: float = 1e9
			var n := Vector2.ZERO
			for path: Array in paths:
				var pts: PackedVector2Array = path[0]
				var rad: PackedFloat32Array = path[1]
				for k in pts.size() - 1:
					var a: Vector2 = pts[k]
					var ab: Vector2 = pts[k + 1] - a
					var ap: Vector2 = wrap_delta(p, a) if cv.wrap else p - a
					if absf(ap.x) > 6.0 or absf(ap.y) > 6.0:
						continue
					var t: float = clampf(ap.dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
					var off: Vector2 = ap - ab * t
					var r: float = lerpf(rad[k], rad[k + 1], t)
					var q: float = off.length() / r
					if q < best:
						best = q
						n = off / maxf(0.0001, off.length())
			if best > 1.0:
				continue
			var b: float = n.dot(LIT)
			var idx: int = 2
			if best > 0.8 and b < 0.2:
				idx = 1
			elif b > 0.25 and best > 0.2 and best < 0.7:
				idx = 4
			elif b > -0.15:
				idx = 3
			elif b < -0.55:
				idx = 1
			cv.setp(x, y, idx)
	cv.outline(0)


static func add_roots(img: Image, s: int, count: int) -> Image:
	var cv := Canvas.new(TILE, TILE, _pal(ROOT_RAMP), true)
	var paths: Array = []
	for r in count:
		var start := Vector2(hash01(r, 1, s) * TILE, hash01(r, 2, s) * TILE)
		var ang: float = PI * 0.5 + (hash01(r, 3, s) - 0.5) * 1.2
		paths.append_array(root_tree(start, ang, 52 + int(hash01(r, 4, s) * 30), 4.5 + hash01(r, 5, s) * 2.0, s + r * 17, 3))
	paint_roots(cv, paths)
	return cv.over(img)


# --- Folhagem --------------------------------------------------------------------------------

const LEAF_RAMP := ["0e1606", "2a4210", "456a18", "6a9424", "a6cc48", "8a5a1a"]


## Moita de folhas arredondadas: folhas de cima mais claras; algumas folhas ferrugem.
static func bush(cv: Canvas, cx: float, base_y: float, wd: float, ht: float, s: int, n: int) -> void:
	var leaves: Array = []
	for k in n:
		var t: float = hash01(k, 1, s)
		var hy: float = pow(hash01(k, 2, s), 0.8)
		var spread: float = wd * 0.5 * (1.0 - hy * 0.55)
		leaves.append([Vector2(cx + (t - 0.5) * 2.0 * spread, base_y - 1.5 - hy * (ht - 3.0)), 1.3 + hash01(k, 3, s) * 1.3, hy, hash01(k, 4, s) < 0.12])
	leaves.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2])
	for l: Array in leaves:
		var c: Vector2 = l[0]
		var hy: float = l[2]
		var rust: bool = l[3]
		cv.disc(c, l[1], func(p: Vector2) -> int:
			var u: Vector2 = (p - c) / float(l[1])
			var b: float = u.dot(LIT)
			if rust:
				return 5
			if b > 0.35 and hy > 0.45:
				return 4
			if b > 0.0:
				return 3
			return 2 if b > -0.5 else 1)


static func add_moss(img: Image, s: int) -> Image:
	var cv := Canvas.new(TILE, TILE, _pal(LEAF_RAMP), true)
	for k in 7:
		var x: float = hash01(k, 1, s) * TILE
		var y: float = hash01(k, 2, s) * TILE
		bush(cv, x, y, 9.0 + hash01(k, 3, s) * 7.0, 6.0 + hash01(k, 4, s) * 4.0, s + k * 13, 9 + int(hash01(k, 5, s) * 6))
	cv.outline(0)
	return cv.over(img)


# --- Depósitos minerais (16×16) ---------------------------------------------------------------

## Paleta: 0 contorno, 1 escuro, 2 médio, 3 claro, 4 brilho, 5-7 rocha (escuro, médio, claro), 8 halo.
const ROCK := ["4a4448", "6c6468", "908a8c"]


static func _ore_pal(hexes: Array, halo: String = "") -> Array[Color]:
	var p: Array = hexes.duplicate()
	p.append_array(ROCK)
	var out: Array[Color] = ramp(p)
	var g := Color(halo) if not halo.is_empty() else Color(0, 0, 0, 0)
	g.a = 0.38 if not halo.is_empty() else 0.0
	out.append(g)
	return out


## Lasca facetada: face esquerda clara com faixa de brilho, face do meio, face direita escura;
## terminação pontuda com facetas próprias. translucent = estrias internas claras.
static func shard(cv: Canvas, base: Vector2, tip: Vector2, hw: float, translucent: bool = false, shoulder: float = 0.68) -> void:
	var ax: Vector2 = tip - base
	var ln: float = ax.length()
	var an: Vector2 = ax / ln
	var pp := Vector2(-an.y, an.x)
	if pp.x < 0.0:
		pp = -pp
	var sh: Vector2 = base + ax * shoulder
	var pts := PackedVector2Array([base - pp * hw, sh - pp * hw, tip, sh + pp * hw, base + pp * hw])
	cv.poly(pts, func(c: Vector2) -> int:
		var d: Vector2 = c - base
		var sd: float = d.dot(pp) / hw
		var a: float = d.dot(an)
		if a > ln * shoulder - 0.25:
			return 4 if sd < -0.05 else (3 if sd < 0.45 else 2)
		if sd < -0.55:
			return 3
		if sd < -0.15:
			return 4 if hw >= 1.8 and a > 1.0 else 3
		if translucent and absf(sd - 0.12) < 0.14 and fposmod(a, 4.0) < 2.2:
			return 3
		if sd < 0.38:
			return 2
		return 1)


static func _rock_base(cv: Canvas, c: Vector2, rx: float, ry: float, s: int) -> void:
	cv.disc(c, rx, func(p: Vector2) -> int:
		var u := Vector2((p.x - c.x) / rx, (p.y - c.y) / ry)
		var b: float = u.dot(LIT)
		if hash01(floori(p.x), floori(p.y), s) < 0.15:
			return 5
		return 7 if b > 0.3 else (5 if b < -0.35 else 6), ry / rx)


static func _crystal_cluster(hexes: Array, halo: String, s: int, v: int, specs: Array, translucent: bool) -> Image:
	var cv := Canvas.new(ORE, ORE, _ore_pal(hexes, halo))
	# specs: [x da base, altura, meia-largura, inclinação]; desenhadas de trás para frente.
	for sp: Array in specs:
		var base := Vector2(sp[0], ORE - 2.5)
		var ang: float = sp[3] + (hash01(v, int(sp[0] * 10.0), s) - 0.5) * 0.12
		shard(cv, base, base + Vector2(sin(ang), -cos(ang)) * float(sp[1]), sp[2], translucent)
	_rock_base(cv, Vector2(8.0, ORE - 2.2), 5.2, 1.8, s)
	cv.outline(0)
	if not halo.is_empty():
		cv.glow(8)
	return cv.image()


## Cubos em 3/4 desenhados pixel a pixel: 3/4 = topo (claro, aresta de brilho), 2 = face
## esquerda, 1 = face direita (sombra). Contorno aplicado depois.
const CUBE_L := ["...44...", ".344333.", "34333333", "22333311", "22223111", "22222111", "22222111", ".222111."]
const CUBE_M := ["..443..", ".34333.", "2233311", "2222111", "2222111", ".22111."]
const CUBE_S := [".43.", "3433", "2211", ".21."]


static func _stamp(cv: Canvas, tpl: Array, x: int, y: int) -> void:
	for j in tpl.size():
		var row: String = tpl[j]
		for i in row.length():
			if row[i] != ".":
				cv.setp(x + i, y + j, int(row[i]))


static func _cubes(hexes: Array, s: int, v: int) -> Image:
	var cv := Canvas.new(ORE, ORE, _ore_pal(hexes))
	var layouts: Array = [
		[[CUBE_M, 5, 1], [CUBE_L, 0, 6], [CUBE_M, 8, 7], [CUBE_S, 6, 11]],
		[[CUBE_L, 4, 1], [CUBE_M, 0, 7], [CUBE_M, 8, 8]],
		[[CUBE_S, 3, 2], [CUBE_M, 8, 2], [CUBE_L, 2, 6], [CUBE_S, 11, 9]],
	]
	for c: Array in layouts[v]:
		_stamp(cv, c[0], c[1], c[2])
	for y in cv.h:
		for x in cv.w:
			if cv.getp(x, y) == 2 and hash01(x, y, s) < 0.08:
				cv.setp(x, y, 1)
	cv.outline(0)
	return cv.image()


## Pepitas lisas e compactas (metal, sem pontas): faixas de luz e reflexo branco.
static func _gold(s: int, v: int) -> Image:
	var cv := Canvas.new(ORE, ORE, _ore_pal(["3a2202", "9a6006", "d89a10", "ffd23a", "fff6c8"], "ffd23a"))
	var sets: Array = [
		[[6.0, 9.5, 3.8, 3.0], [10.5, 10.5, 3.0, 2.4], [8.5, 6.0, 2.8, 2.4]],
		[[7.5, 8.5, 4.6, 3.6], [11.5, 11.5, 2.4, 2.0]],
		[[5.0, 10.5, 3.0, 2.6], [9.0, 9.0, 3.6, 3.0], [11.8, 12.0, 2.2, 1.8], [7.0, 5.8, 2.2, 1.9]],
	]
	for n: Array in sets[v]:
		var c := Vector2(n[0], n[1])
		var rx: float = n[2]
		cv.disc(c, rx, func(p: Vector2) -> int:
			var u := Vector2((p.x - c.x) / rx, (p.y - c.y) / float(n[3]))
			var b: float = u.dot(LIT)
			if (u - Vector2(-0.35, -0.45)).length() < 0.25:
				return 4
			if b > 0.25:
				return 3
			return 2 if b > -0.45 else 1, float(n[3]) / rx)
	cv.outline(0)
	return cv.image()


static func _coal(s: int, v: int) -> Image:
	var cv := Canvas.new(ORE, ORE, _ore_pal(["040406", "101016", "1c1c24", "2e2e3a", "98a8c2"]))
	var sets: Array = [[[6.0, 9.5, 4.2, 3.2], [11.0, 10.5, 3.2, 2.6]], [[8.0, 9.0, 5.2, 4.0]], [[5.0, 8.0, 3.2, 2.8], [10.0, 10.5, 4.0, 3.0]]]
	for r: Array in sets[v]:
		var c := Vector2(r[0], r[1])
		var rx: float = r[2]
		cv.disc(c, rx, func(p: Vector2) -> int:
			var u := Vector2((p.x - c.x) / rx, (p.y - c.y) / float(r[3]))
			var cell: Array = jvor(p * 2.0, 16, s)
			var b: float = u.dot(LIT) + ((cell[2] as Vector2).dot(LIT)) * 0.25
			if b > 0.55 and hash01(cell[3], 1, s) < 0.4:
				return 4
			return 3 if b > 0.2 else (2 if b > -0.4 else 1), float(r[3]) / rx)
	cv.outline(0)
	return cv.image()


## Urânio: rocha opaca irregular com mineral verde-limão exposto e brilho fraco (não é cristal).
static func _uranium(s: int, v: int) -> Image:
	var cv := Canvas.new(ORE, ORE, _ore_pal(["080e08", "1c241c", "2c362a", "3e4a3a", "f2ffb6"], "9eff3a"))
	cv.pal.append_array(ramp(["3e7a0c", "7ed01e", "c2ff4e"]))   # 9, 10, 11: mineral exposto
	var sets: Array = [[[8.0, 9.0, 5.8, 4.6]], [[6.0, 9.0, 4.4, 3.8], [11.0, 10.5, 3.6, 3.0]], [[8.0, 8.5, 5.4, 5.0]]]
	for r: Array in sets[v]:
		var c := Vector2(r[0], r[1])
		var rx: float = r[2]
		cv.disc(c, rx, func(p: Vector2) -> int:
			var u := Vector2((p.x - c.x) / rx, (p.y - c.y) / float(r[3]))
			var b: float = u.dot(LIT)
			var cell: Array = jvor(p * 2.5, 12, s + v)
			var veins: float = hash01(cell[3], 2, s + v)
			if veins > 0.62 and float(cell[0]) < 5.0:
				var lb: float = (cell[2] as Vector2).dot(LIT) / 5.0
				return 4 if lb > 0.45 else (11 if lb > 0.0 else (10 if lb > -0.4 else 9))
			return 3 if b > 0.3 else (2 if b > -0.35 else 1), float(r[3]) / rx)
	cv.outline(0)
	cv.glow(8)
	return cv.image()


## Diamante: gema lapidada (mesa, coroa, pavilhão) com facetas geométricas e cintilação.
static func _gem(cv: Canvas, c: Vector2, r: float) -> void:
	var top: float = c.y - r * 0.6
	var mid: float = c.y - r * 0.05
	var bot: float = c.y + r * 1.1
	var pts := PackedVector2Array([Vector2(c.x - r * 0.55, top), Vector2(c.x + r * 0.55, top), Vector2(c.x + r, mid),
			Vector2(c.x, bot), Vector2(c.x - r, mid)])
	cv.poly(pts, func(p: Vector2) -> int:
		if p.y < mid:
			if absf(p.x - c.x) < r * 0.35 and p.y < top + r * 0.32:
				return 4
			if p.x < c.x - r * 0.35:
				return 3
			if p.x > c.x + r * 0.35:
				return 2
			return 3 if p.y < (top + mid) * 0.5 else 2
		var t: float = (p.x - c.x) / maxf(0.5, r * (1.0 - (p.y - mid) / (bot - mid)))
		if t < -0.55:
			return 3
		if t < -0.1:
			return 4 if p.y < mid + 1.5 else 3
		if t < 0.45:
			return 2
		return 1)


static func _sparkle(cv: Canvas, x: int, y: int) -> void:
	for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if cv.getp(x + o.x, y + o.y) == -1 or o == Vector2i.ZERO:
			cv.setp(x + o.x, y + o.y, 4)


static func _diamond(s: int, v: int) -> Image:
	var cv := Canvas.new(ORE, ORE, _ore_pal(["16304e", "5a92c6", "9ed0f4", "dcf4ff", "ffffff"], "dcf4ff"))
	match v:
		0:
			_gem(cv, Vector2(8.0, 7.5), 5.6)
		1:
			_gem(cv, Vector2(6.5, 7.0), 4.6)
			_gem(cv, Vector2(12.0, 11.0), 2.6)
		_:
			_gem(cv, Vector2(9.0, 7.0), 4.8)
			_gem(cv, Vector2(4.0, 11.5), 2.4)
	cv.outline(0)
	cv.glow(8)
	_sparkle(cv, 4 if v != 2 else 12, 3)
	return cv.image()


## Prismas de topázio: corpo hexagonal alongado, terminação em bisel, faces verticais.
static func _topaz(s: int, v: int) -> Image:
	var cv := Canvas.new(ORE, ORE, _ore_pal(["3e1802", "a84a10", "e2761e", "ffaa48", "ffe4ac"]))
	var specs: Array = [[[5.5, 11.0, 2.3, -0.2], [10.5, 8.5, 2.0, 0.28]], [[8.0, 12.5, 2.8, 0.05], [12.0, 6.0, 1.6, 0.45]],
			[[4.0, 7.5, 1.8, -0.4], [8.0, 12.0, 2.4, 0.0], [12.0, 8.0, 1.8, 0.4]]]
	for sp: Array in specs[v]:
		var base := Vector2(sp[0], ORE - 2.5)
		var ang: float = sp[3]
		var an := Vector2(sin(ang), -cos(ang))
		var pp := Vector2(-an.y, an.x)
		var hw: float = sp[2]
		var ln: float = sp[1]
		var body: Vector2 = base + an * ln * 0.8
		var tip: Vector2 = base + an * ln + pp * hw * 0.45
		cv.poly(PackedVector2Array([base - pp * hw, body - pp * hw, tip, body + pp * hw, base + pp * hw]), func(c: Vector2) -> int:
			var sd: float = (c - base).dot(pp) / hw
			var a: float = (c - base).dot(an)
			if a > ln * 0.8 - 0.3:
				return 4 if sd < 0.25 else 3
			if sd < -0.4:
				return 3
			if sd < 0.3:
				return 4 if absf(sd + 0.05) < 0.12 else 2
			return 1)
	_rock_base(cv, Vector2(8.0, ORE - 2.2), 5.0, 1.8, s)
	cv.outline(0)
	return cv.image()


## Ametista: drusa compacta de pontas curtas e facetadas, violeta suave.
static func _amethyst(s: int, v: int) -> Image:
	var xs: Array = [[3.0, 5.2, 7.6, 10.0, 12.4], [2.6, 4.8, 7.0, 9.2, 11.4, 13.4], [3.6, 6.0, 8.4, 10.8, 12.8]][v]
	var specs: Array = []
	for i in xs.size():
		var t: float = float(i) / (xs.size() - 1) - 0.5
		specs.append([xs[i], 5.5 + (1.0 - absf(t) * 1.6) * 3.5 + hash01(i, v, s) * 1.5, 1.15, t * 0.9])
	return _crystal_cluster(["1c0a30", "54309a", "7a54c4", "a88ae8", "eee2ff"], "", s, v, specs, false)


## Baú soterrado (16×16): madeira com cintas douradas e fechadura; variações: baú comum,
## reforçado com ferro e baú antigo coberto de musgo e raízes, entreaberto com brilho.
static func _chest(s: int, v: int) -> Image:
	var pal: Array[Color] = [Color("140a04"), Color("4a2a12"), Color("7a4a22"), Color("a8703a"),
			Color("8a6410"), Color("e0a830"), Color("ffe080"), Color("24242e"), Color("fff2b0"), Color("4a7a28"), Color("8a94a8"), Color("c8d0dc")]
	if v == 1:
		pal[1] = Color("3a2010")
		pal[2] = Color("5e3818")
		pal[3] = Color("82552a")
	var cv := Canvas.new(16, 16, pal)
	var band: int = 10 if v == 1 else 5
	var band_hi: int = 11 if v == 1 else 6
	var top: int = 4 if v == 2 else 3   # tampa entreaberta no antigo
	# Corpo (tábuas horizontais).
	for y in range(7, 14):
		for x in range(2, 14):
			var idx: int = 2
			if y == 7:
				idx = 3
			elif y == 13 or x == 13:
				idx = 1
			elif (y - 7) % 3 == 0:
				idx = 1
			elif x == 2:
				idx = 3
			cv.setp(x, y, idx)
	# Tampa arredondada.
	for y in range(top, 7):
		var inset: int = 1 if y == top else 0
		for x in range(2 + inset, 14 - inset):
			cv.setp(x, y, 3 if y == top else (2 if y < 6 else 1))
	if v == 2:
		# Fresta com brilho dourado sob a tampa.
		for x in range(3, 13):
			cv.setp(x, 7, 8 if x % 3 != 0 else 6)
	# Cintas verticais e cantos.
	for x: int in [4, 11]:
		for y in range(top, 14):
			cv.setp(x, y, band if y > top else band_hi)
		cv.setp(x, 13, 4)
	for y in range(top + 1, 14):
		cv.setp(2, y, band if y % 2 == 0 else cv.getp(2, y))
	# Fechadura.
	cv.setp(7, 7, 7)
	cv.setp(8, 7, 7)
	cv.setp(7, 8, 7)
	cv.setp(8, 8, 7)
	cv.setp(7, 9, band_hi)
	cv.setp(8, 9, band_hi)
	cv.setp(8, 8, 6 if v != 1 else 11)
	if v == 2:
		# Musgo e raízes sobre a tampa e descendo pela lateral.
		for x in range(3, 13):
			if hash01(x, 1, s) < 0.6:
				cv.setp(x, top, 9)
		for y in range(top, 12):
			if hash01(y, 2, s) < 0.55:
				cv.setp(12, y, 9 if y < 9 else 1)
	cv.outline(0)
	if v != 1:
		cv.setp(13, top + 1, 8)  # reflexo
	return cv.image()


## Depósitos: 3 variações por minério (16×16, fundo transparente, halo nos luminosos).
static func ore_sprites() -> Dictionary:
	var out: Dictionary = {}
	for v in 3:
		var s: int = 100 + v * 17
		var n: String = "_%d" % (v + 1)
		out["ferro" + n] = _cubes(["1a1412", "4a3e3a", "6a5e58", "92847c", "d2c4b8"], s, v)
		out["cobre" + n] = _cubes(["1e0804", "922e10", "c84e1e", "f07c3a", "ffcca0"], s + 1, v)
		out["prata" + n] = _cubes(["1e2230", "6e7690", "a0a8be", "d0d8e8", "ffffff"], s + 2, v)
		out["titanio" + n] = _cubes(["10182c", "34466e", "50689c", "80a0d4", "dceaff"], s + 3, v)
		out["ouro" + n] = _gold(s + 4, v)
		out["carvao" + n] = _coal(s + 5, v)
		out["uranio" + n] = _uranium(s + 6, v)
		out["diamante" + n] = _diamond(s + 7, v)
		out["cristal_azul" + n] = _crystal_cluster(["040e3a", "0c2ea6", "1a5ae8", "4e9cff", "d8eeff"], "4e9cff", s + 8, v,
				[[[4.0, 8.0, 1.6, -0.45], [11.5, 9.0, 1.7, 0.4], [8.0, 13.0, 2.3, -0.05]], [[5.0, 12.0, 2.0, -0.25], [10.5, 10.5, 1.9, 0.3], [13.0, 6.0, 1.3, 0.6]],
				[[3.5, 7.0, 1.5, -0.6], [7.0, 12.5, 2.1, -0.15], [11.0, 11.0, 2.0, 0.25], [13.5, 6.0, 1.2, 0.65]]][v], false)
		out["cristal_roxo" + n] = _crystal_cluster(["160220", "640c70", "a41ca6", "ea52e2", "ffd4fc"], "e852e0", s + 11, v,
				[[[4.5, 9.5, 2.0, -0.35], [11.0, 10.0, 2.0, 0.32], [8.0, 13.5, 2.6, 0.0]], [[6.0, 13.5, 2.5, -0.12], [11.0, 11.0, 2.2, 0.28]],
				[[4.0, 11.0, 2.0, -0.3], [8.5, 13.5, 2.5, 0.05], [12.5, 9.0, 1.8, 0.4]]][v], false)
		out["cristal_vermelho" + n] = _crystal_cluster(["280408", "880c1e", "cc1e30", "ff5c64", "ffd8d8"], "", s + 10, v,
				[[[5.0, 8.0, 2.0, -0.3], [10.5, 8.5, 2.0, 0.3], [8.0, 11.0, 2.3, 0.0]], [[6.0, 10.5, 2.4, -0.15], [11.0, 8.0, 2.0, 0.3]],
				[[4.5, 7.0, 1.8, -0.35], [8.0, 10.5, 2.2, 0.0], [11.5, 8.0, 1.9, 0.3]]][v], false)
		out["cristal_verde" + n] = _crystal_cluster(["03281f", "0a6e46", "16a86c", "60e2ac", "e0fff2"], "", s + 9, v,
				[[[5.0, 11.0, 2.2, -0.15], [11.0, 9.0, 2.0, 0.2], [8.0, 13.5, 2.5, 0.0]], [[6.5, 13.5, 2.6, -0.05], [11.5, 10.0, 2.1, 0.22]],
				[[4.0, 9.0, 2.0, -0.25], [8.0, 13.5, 2.4, 0.0], [12.0, 10.5, 2.1, 0.22]]][v], true)
		out["quartzo" + n] = _crystal_cluster(["32323c", "9494a6", "c8c8d6", "ececf4", "ffffff"], "", s + 14, v,
				[[[5.5, 7.5, 1.3, -0.3], [8.5, 10.0, 1.5, 0.05], [11.5, 7.0, 1.3, 0.35]], [[6.0, 9.5, 1.5, -0.15], [10.0, 8.0, 1.4, 0.2]],
				[[4.5, 6.5, 1.2, -0.4], [7.5, 9.5, 1.4, -0.05], [10.5, 8.5, 1.4, 0.2], [13.0, 5.5, 1.1, 0.5]]][v], true)
		out["ametista" + n] = _amethyst(s + 12, v)
		out["topazio" + n] = _topaz(s + 13, v)
		out["bau" + n] = _chest(s + 15, v)
	return out


# --- Vegetação ------------------------------------------------------------------------------

static func _root_sprite(w: int, h: int, s: int, hanging: bool, count: int, thick: float, branches: int) -> Image:
	var cv := Canvas.new(w, h, _pal(ROOT_RAMP))
	var paths: Array = []
	for r in count:
		var start := Vector2(w * (0.3 + 0.4 * hash01(r, 1, s)), 1.0 if hanging else h * (0.1 + 0.15 * hash01(r, 2, s)))
		var ang: float = PI * 0.5 + (hash01(r, 3, s) - 0.5) * (0.3 if hanging else 0.7)
		paths.append_array(root_tree(start, ang, int(h * 0.92), thick, s + r * 7, branches, 0.28 if hanging else 0.32))
	paint_roots(cv, paths)
	return cv.image()


static func _vine(s: int) -> Image:
	var cv := Canvas.new(14, 30, _pal(["0c1606", "2a4210", "456a18", "6a9424", "b0d050", "5a3a1c"]))
	var x: float = 7.0
	for y in 28:
		x = 7.0 + sin(y * 0.35 + s) * 1.6
		cv.setp(floori(x), y + 1, 5)
		if y > 1 and y % 3 == 0:
			var side: float = 1.0 if (y / 3) % 2 == 0 else -1.0
			var c := Vector2(x + side * 2.2, y + 1.0)
			cv.disc(c, 1.5, func(p: Vector2) -> int: return 4 if (p - c).dot(LIT) > 0.4 else (3 if p.y < c.y else 2), 0.75)
	cv.outline(0)
	return cv.image()


static func _bush_sprite(s: int, w: int, h: int, n: int) -> Image:
	var cv := Canvas.new(w, h, _pal(LEAF_RAMP))
	bush(cv, w * 0.5, h - 0.5, w - 3.0, h - 1.0, s, n)
	cv.outline(0)
	return cv.image()


## Palmeirinha/samambaia: caule curto e folhas longas que se arqueiam para baixo.
static func _fern(s: int) -> Image:
	var cv := Canvas.new(20, 18, _pal(["0c1606", "2a4210", "456a18", "6a9424", "a6cc48", "6a3e1a"]))
	var top := Vector2(10.0, 9.0)
	for y in range(9, 18):
		cv.setp(10, y, 5)
		cv.setp(9, y, 5 if y > 12 else 2)
	for f in 7:
		var ang: float = -PI + 0.25 + f * (PI - 0.5) / 6.0
		var p: Vector2 = top
		var dir := Vector2(cos(ang), sin(ang))
		for i in 9:
			dir = (dir + Vector2(0, 0.09 * i * 0.3)).normalized()
			p += dir
			cv.setp(floori(p.x), floori(p.y), 3 if dir.y < 0.2 else 2)
			if i > 1 and i % 2 == 0:
				var pp := Vector2(-dir.y, dir.x)
				cv.setp(floori(p.x + pp.x), floori(p.y + pp.y), 4 if f < 3 else 3)
				cv.setp(floori(p.x - pp.x), floori(p.y - pp.y), 1)
	cv.outline(0)
	return cv.image()


static func _sprout(s: int) -> Image:
	var cv := Canvas.new(14, 16, _pal(["0c1606", "2a4210", "456a18", "6a9424", "a6cc48", "6a3e1a"]))
	for y in range(6, 16):
		cv.setp(7, y, 2)
	for l: Array in [[Vector2(4.0, 8.0), 2.6, -0.6], [Vector2(10.0, 6.5), 2.8, 0.6], [Vector2(6.5, 3.0), 2.2, -0.2]]:
		var c: Vector2 = l[0]
		var r: float = l[1]
		cv.disc(c, r, func(p: Vector2) -> int:
			var u: Vector2 = (p - c) / r
			if absf(u.x * cos(float(l[2])) + u.y * sin(float(l[2]))) < 0.12:
				return 2
			return 4 if u.dot(LIT) > 0.4 else (3 if u.dot(LIT) > -0.2 else 2), 0.62)
	cv.outline(0)
	return cv.image()


static func _mushrooms(caps: Array, hexes: Array, spots: bool) -> Image:
	var cv := Canvas.new(16, 16, _pal(hexes))
	caps.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2])
	for m: Array in caps:
		var x: float = m[0]
		var top: float = m[1]
		var r: float = m[2]
		for y in range(floori(top + r * 0.5), 16):
			cv.setp(floori(x), y, 6)
			cv.setp(floori(x) + 1, y, 7)
			if r > 2.5:
				cv.setp(floori(x) - 1, y, 6)
		var c := Vector2(x + 0.5, top + r * 0.75)
		cv.disc(c, r, func(p: Vector2) -> int:
			if p.y > c.y:
				return -1
			var u: Vector2 = (p - c) / r
			if p.y > c.y - 1.0:
				return 1
			return 4 if (u - Vector2(-0.4, -0.55)).length() < 0.25 else (3 if u.x < 0.1 else 2), 0.8)
		if spots:
			for d: Vector2 in [Vector2(-0.45, -0.35), Vector2(0.3, -0.55), Vector2(0.55, -0.15)]:
				cv.setp(floori(c.x + d.x * r), floori(c.y + d.y * r * 0.8), 5)
	cv.outline(0)
	return cv.image()


# --- Rochas e fósseis ----------------------------------------------------------------------

## Pedra granulada (bolhas pequenas + pontinhos de brilho), como as da referência.
static func _rock(cv: Canvas, c: Vector2, rx: float, ry: float, s: int) -> void:
	cv.disc(c, rx, func(p: Vector2) -> int:
		var u := Vector2((p.x - c.x) / rx, (p.y - c.y) / ry)
		var wob: float = 1.0 + (hash01(int(atan2(u.y, u.x) * 2.5 + 10.0), 0, s) - 0.5) * 0.25
		if u.length() > wob:
			return -1
		var cell: Array = jvor(p * 2.0, 16, s)
		var b: float = u.dot(LIT) * 0.9 + ((cell[2] as Vector2) / 2.5).dot(LIT) * 0.5
		if hash01(cell[3], 4, s) < 0.18 and ((cell[2] as Vector2) / 2.5 - Vector2(-0.3, -0.4)).length() < 0.3:
			return 4
		return 3 if b > 0.3 else (2 if b > -0.3 else 1), ry / rx)


static func _rocks(s: int, w: int, h: int, items: Array, hexes: Array) -> Image:
	var cv := Canvas.new(w, h, _pal(hexes))
	items.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	for r: Array in items:
		_rock(cv, Vector2(r[0], r[1]), r[2], r[3], s + int(r[0]))
	cv.outline(0)
	return cv.image()


## Rochas pontudas (para cima ou estalactites): cones levemente curvos e granulados.
static func _spikes(s: int, w: int, h: int, items: Array, hexes: Array, down: bool) -> Image:
	var cv := Canvas.new(w, h, _pal(hexes))
	for it: Array in items:
		var bx: float = it[0]
		var hw: float = it[1]
		var ln: float = it[2]
		var base_y: float = 0.0 if down else h - 0.5
		var tip := Vector2(bx + it[3], base_y + ln if down else base_y - ln)
		var pts := PackedVector2Array([Vector2(bx - hw, base_y), Vector2(bx - hw * 0.55, lerpf(base_y, tip.y, 0.5)), tip,
				Vector2(bx + hw * 0.5, lerpf(base_y, tip.y, 0.55)), Vector2(bx + hw, base_y)])
		cv.poly(pts, func(c: Vector2) -> int:
			var t: float = (c.y - base_y) / (tip.y - base_y)
			var cx: float = lerpf(bx, tip.x, t)
			var sd: float = (c.x - cx) / maxf(0.6, hw * (1.0 - t))
			var cell: Array = jvor(c * 2.0, 16, s)
			if hash01(cell[3], 6, s) < 0.2 and float(cell[0]) < 1.6:
				return 4 if sd < 0.0 else 3
			return 3 if sd < -0.25 else (1 if sd > 0.45 else 2))
	cv.outline(0)
	return cv.image()


const BONE := ["2a2016", "8a7a60", "bcae8e", "e2d6b6", "fffbea"]


static func _bone() -> Image:
	var cv := Canvas.new(16, 10, _pal(BONE))
	cv.poly(PackedVector2Array([Vector2(3.5, 3.6), Vector2(12.5, 3.6), Vector2(12.5, 6.2), Vector2(3.5, 6.2)]),
			func(c: Vector2) -> int: return 4 if c.y < 4.2 and c.x < 9.0 else (3 if c.y < 5.0 else 2))
	for e: Vector2 in [Vector2(2.6, 3.2), Vector2(2.6, 6.6), Vector2(13.4, 3.2), Vector2(13.4, 6.6)]:
		cv.disc(e, 1.9, func(c: Vector2) -> int: return 3 if (c - e).dot(LIT) > 0.0 else 2)
	cv.outline(0)
	return cv.image()


static func _skull() -> Image:
	var cv := Canvas.new(15, 14, _pal(BONE))
	var c := Vector2(7.5, 6.0)
	cv.disc(c, 5.6, func(p: Vector2) -> int:
		var b: float = ((p - c) / 5.6).dot(LIT)
		return 4 if b > 0.55 else (3 if b > 0.0 else 2), 0.9)
	cv.poly(PackedVector2Array([Vector2(4.0, 8.0), Vector2(11.0, 8.0), Vector2(10.4, 13.0), Vector2(4.6, 13.0)]),
			func(p: Vector2) -> int: return 3 if p.x < 7.0 else 2)
	for e: Vector2i in [Vector2i(4, 7), Vector2i(5, 7), Vector2i(5, 8), Vector2i(4, 8), Vector2i(9, 7), Vector2i(10, 7), Vector2i(9, 8), Vector2i(10, 8)]:
		cv.setp(e.x, e.y, 0)
	cv.setp(7, 9, 0)
	cv.setp(7, 10, 1)
	for x in [5, 7, 9]:
		cv.setp(x, 12, 1)
	cv.outline(0)
	return cv.image()


static func _ammonite() -> Image:
	var cv := Canvas.new(16, 16, _pal(["2a1a10", "6e4a30", "9a7050", "c49a72", "ecd2b0"]))
	var c := Vector2(8.0, 8.0)
	cv.disc(c, 7.0, func(p: Vector2) -> int:
		var d: Vector2 = p - c
		var ang: float = atan2(d.y, d.x)
		var rib: bool = fposmod(ang * 7.0 / PI + d.length() * 0.3, 2.0) < 0.5
		var b: float = (d / 7.0).dot(LIT)
		if rib and d.length() > 2.5:
			return 1 if b < 0.2 else 2
		return 4 if b > 0.5 else (3 if b > 0.0 else 2))
	var a: float = 0.0
	while a < TAU * 2.4:
		var r: float = 0.8 + a / TAU * 2.4
		cv.setp(floori(c.x + cos(a) * r), floori(c.y + sin(a) * r), 1)
		a += 0.06
	cv.outline(0)
	return cv.image()


static func _ribs() -> Image:
	var cv := Canvas.new(16, 12, _pal(BONE))
	for x in range(1, 15):
		cv.setp(x, 2, 4 if x % 3 == 0 else 3)
		cv.setp(x, 3, 2)
	for i in 5:
		var x0: float = 2.5 + i * 2.6
		for k in 8 - absi(i - 2):
			var y: int = 4 + k
			cv.setp(floori(x0 + k * 0.35), y, 3 if k < 3 else 2)
	cv.outline(0)
	return cv.image()


## Vegetação (raízes, cipós, musgo, plantas, fungos) e decorações (pedras, fósseis).
## Tamanhos em pixels de arte (cabem na célula de 32 do atlas; fósseis em 16).
static func vegetation_sprites() -> Dictionary:
	var mush_red := ["1a0806", "781a10", "b8281a", "e24c2c", "ffa078", "f6ecd8", "e0d4ba", "aa9c80"]
	var mush_brown := ["1a0e06", "4a2a14", "7a4a26", "a46c3a", "dcaa76", "efe2c6", "d2c2a0", "988a70"]
	return {
		"raiz_fina_a": _root_sprite(28, 30, 301, false, 2, 2.6, 2),
		"raiz_fina_b": _root_sprite(24, 28, 302, false, 1, 2.8, 3),
		"raiz_retorcida": _root_sprite(30, 30, 303, false, 1, 3.6, 3),
		"raiz_grossa": _root_sprite(32, 32, 304, false, 1, 6.0, 4),
		"raiz_pendente_a": _root_sprite(20, 30, 305, true, 2, 3.2, 2),
		"raiz_pendente_b": _root_sprite(22, 26, 306, true, 1, 4.6, 3),
		"cipo_pendente": _vine(307),
		"musgo_a": _bush_sprite(308, 16, 9, 14),
		"musgo_b": _bush_sprite(309, 12, 8, 10),
		"samambaia": _fern(310),
		"broto": _sprout(311),
		"cogumelo_vermelho": _mushrooms([[6.0, 6.5, 4.6], [12.0, 9.5, 3.0], [2.8, 11.5, 2.1]], mush_red, true),
		"cogumelo_marrom": _mushrooms([[5.5, 9.0, 3.4], [11.0, 11.0, 2.6]], mush_brown, false),
	}


static func decoration_sprites() -> Dictionary:
	var gray := ["1a1618", "585054", "786e72", "9a9294", "d2cac8"]
	var dark := ["0c0a0e", "28222a", "3a323c", "52485a", "7e7084"]
	var brown := ["1e1008", "5a3a22", "7a5232", "9e7048", "caa078"]
	var red := ["220a06", "6a2618", "94392a", "be5640", "e6906c"]
	return {
		"pedrinhas_a": _rocks(401, 12, 8, [[3.5, 4.5, 2.6, 2.0], [8.5, 4.8, 2.8, 2.2]], gray),
		"pedrinhas_b": _rocks(402, 10, 7, [[3.5, 3.8, 2.4, 1.8], [7.0, 4.2, 2.2, 1.7]], brown),
		"pedra_pequena": _rocks(403, 12, 10, [[6.0, 5.5, 4.6, 3.6]], gray),
		"pedra_escura": _rocks(404, 14, 10, [[5.0, 5.5, 3.8, 3.0], [9.5, 6.0, 3.2, 2.6]], dark),
		"monte_pedras": _rocks(405, 22, 12, [[5.5, 7.5, 4.4, 3.6], [11.5, 6.0, 5.0, 4.6], [17.0, 8.0, 3.8, 3.2], [9.0, 9.5, 3.2, 2.2]], gray),
		"rocha_pontuda_a": _spikes(406, 16, 22, [[5.0, 3.0, 14.0, 0.5], [10.5, 3.6, 20.0, -0.4], [14.0, 1.8, 9.0, 0.6]], red, false),
		"rocha_pontuda_b": _spikes(407, 10, 15, [[5.0, 3.6, 13.5, 0.3]], red, false),
		"estalactite": _spikes(408, 12, 20, [[6.0, 3.2, 18.0, 0.4], [10.0, 1.8, 9.0, -0.3]], gray, true),
		"fossil_osso": _bone(),
		"fossil_cranio": _skull(),
		"fossil_amonite": _ammonite(),
		"fossil_costelas": _ribs(),
	}
