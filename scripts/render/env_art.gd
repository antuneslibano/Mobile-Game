class_name EnvArt
extends RefCounted
## Gerador da pixel art do ambiente: texturas de terreno repetíveis (64×64 pixels de arte),
## depósitos minerais (12×12), vegetação e decorações. Roda offline em
## tools/gen_env_assets.gd e grava PNGs em assets/environment/; o jogo usa só os PNGs
## (que podem ser retocados à mão). Escala: 1 pixel de arte = 3 px na tela (art_px).
##
## Tudo é determinístico (mesmas seeds → mesmos arquivos) e as texturas de terreno são
## periódicas (ruído e Voronoi com envoltório), então repetem sem emendas.

const TILE: int = 64
const ORE: int = 12
const LIGHT := Vector2(-0.6, -0.8)


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


static func ramp(hexes: Array) -> Array[Color]:
	var out: Array[Color] = []
	for h: String in hexes:
		out.append(Color(h))
	return out


## Pontos espalhados com distância mínima (no toro do tile).
static func scatter(n: int, s: int, min_d: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var tries: int = 0
	while pts.size() < n and tries < n * 60:
		tries += 1
		var p := Vector2(hash01(tries, 1, s) * TILE, hash01(tries, 2, s) * TILE)
		var ok: bool = true
		for q in pts:
			if wrap_delta(p, q).length() < min_d:
				ok = false
				break
		if ok:
			pts.append(p)
	return pts


# --- Texturas de terreno ---------------------------------------------------------------

## Torrões/pedras: Voronoi periódico com luz no topo-esquerda, frestas escuras entre os
## torrões e pontinhos de brilho. ramp = [fresta, escuro, médio, claro, brilho].
static func clumps(spec: Dictionary) -> Image:
	var s: int = spec.get("seed", 1)
	var n: int = spec.get("n", 40)
	var pal: Array[Color] = ramp(spec.ramp)
	var pal2: Array[Color] = ramp(spec.get("ramp2", spec.ramp))
	var mix2: float = spec.get("mix2", 0.0)
	var crack: float = spec.get("crack", 0.9)
	var contrast: float = spec.get("contrast", 1.0)
	var speck: float = spec.get("speck", 0.02)
	var flat: float = spec.get("flat", 0.0)
	var grain: float = spec.get("grain", 0.5)
	var glint: Color = Color(spec.get("glint", "00000000"))
	var spacing: float = sqrt(float(TILE * TILE) / n) * 0.8
	var pts: PackedVector2Array = scatter(n, s, spacing)
	var rad := PackedFloat32Array()
	var tone := PackedFloat32Array()
	var alt := PackedByteArray()
	for i in pts.size():
		var best: float = 1e9
		for j in pts.size():
			if i != j:
				best = minf(best, wrap_delta(pts[i], pts[j]).length())
		rad.append(best * 0.55)
		var t: float = hash01(i, 7, s)
		tone.append(-0.6 if t < 0.25 else (0.5 if t > 0.8 else 0.0))
		alt.append(1 if hash01(i, 9, s) < mix2 else 0)
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y in TILE:
		for x in TILE:
			var p := Vector2(x + 0.5, y + 0.5)
			var d1: float = 1e9
			var d2: float = 1e9
			var k: int = 0
			var rel := Vector2.ZERO
			for i in pts.size():
				var dv: Vector2 = wrap_delta(p, pts[i])
				var d: float = dv.length()
				if d < d1:
					d2 = d1
					d1 = d
					k = i
					rel = dv
				elif d < d2:
					d2 = d
			var pl: Array[Color] = pal2 if alt[k] == 1 else pal
			var e: float = (d2 - d1) * 0.5
			var u: Vector2 = rel / rad[k]
			var m: float = u.length()
			var lit: float = -(u.x * LIGHT.x + u.y * LIGHT.y)
			var idx: int
			if crack >= 1.0 and e < crack:
				# Placas (solo rachado): rachaduras contínuas.
				idx = 0
			elif crack < 1.0 and m > 0.95 + (fbm(x, y, s + 21) - 0.5) * 0.35:
				# Torrões: bolsões entre torrões (mais fundos onde há espaço).
				idx = 0 if (m > 1.12 or e < crack * 0.6) else 1
			else:
				var lvl: float = 2.0 + tone[k] - lit * contrast
				lvl -= maxf(0.0, m - 0.62) * (2.4 if lit > 0.0 else 0.8) * (1.0 - flat)
				lvl += (fbm(x, y, s + 40) - 0.5) * grain
				if crack >= 1.0 and e < crack + 1.0:
					lvl -= 0.7
				idx = clampi(roundi(lvl), 1, 3)
				if lit < -0.45 and m < 0.7 and hash01(x, y, s + 3) < 0.3 + contrast * 0.15:
					idx = 3
				if idx >= 2 and hash01(x, y, s + 5) < speck:
					idx = 4
			var col: Color = pl[idx]
			if glint.a > 0.0 and idx >= 2 and hash01(x, y, s + 11) < 0.012:
				col = glint
			img.set_pixel(x, y, col)
	return img


## Placas de solo ressecado: placas grandes e lisas, rachaduras grossas, borda iluminada.
static func cracked(spec: Dictionary) -> Image:
	var d := spec.duplicate()
	d["n"] = spec.get("n", 11)
	d["crack"] = 1.25  # >= 1: rachaduras contínuas
	d["contrast"] = 0.55
	d["flat"] = 0.85
	return clumps(d)


## Raízes por cima de uma textura: caminhadas aleatórias com envoltório, afinando.
static func add_roots(img: Image, spec: Dictionary) -> Image:
	var s: int = spec.get("seed", 1)
	var pal: Array[Color] = ramp(spec.ramp)
	var mask := PackedByteArray()
	mask.resize(TILE * TILE)
	var count: int = spec.get("count", 4)
	for r in count:
		var pos := Vector2(hash01(r, 1, s) * TILE, hash01(r, 2, s) * TILE)
		var ang: float = PI * 0.5 + (hash01(r, 3, s) - 0.5) * 1.6
		var steps: int = 40 + int(hash01(r, 4, s) * 50)
		var thick: float = spec.get("thick", 2.6) * (0.6 + 0.6 * hash01(r, 5, s))
		_walk(mask, pos, ang, steps, thick, s + r * 31, 2)
	return _paint_mask(img, mask, pal)


static func _walk(mask: PackedByteArray, pos: Vector2, ang: float, steps: int, thick: float, s: int, depth: int) -> void:
	for i in steps:
		var t: float = thick * (1.0 - float(i) / steps * 0.7)
		var rr: float = maxf(0.5, t * 0.5)
		for oy in range(-2, 3):
			for ox in range(-2, 3):
				if Vector2(ox, oy).length() <= rr:
					var x: int = posmod(roundi(pos.x) + ox, TILE)
					var y: int = posmod(roundi(pos.y) + oy, TILE)
					mask[y * TILE + x] = 1
		ang += (hash01(i, depth, s) - 0.5) * 0.55
		ang = lerpf(ang, PI * 0.5, 0.04)
		pos += Vector2(cos(ang), sin(ang))
		if depth > 0 and i > 6 and hash01(i, 77, s) < 0.035:
			_walk(mask, pos, ang + (0.9 if hash01(i, 78, s) < 0.5 else -0.9), int(steps * 0.4), t * 0.6, s + i * 13, depth - 1)


## Pinta uma máscara com sombreamento (luz topo-esquerda) e contorno escuro.
## pal = [contorno, escuro, médio, claro].
static func _paint_mask(img: Image, mask: PackedByteArray, pal: Array[Color]) -> Image:
	var out: Image = img.duplicate()
	for y in TILE:
		for x in TILE:
			var m: int = mask[y * TILE + x]
			var up: int = mask[posmod(y - 1, TILE) * TILE + x]
			var left: int = mask[y * TILE + posmod(x - 1, TILE)]
			var down: int = mask[posmod(y + 1, TILE) * TILE + x]
			var right: int = mask[y * TILE + posmod(x + 1, TILE)]
			if m == 1:
				var c: Color = pal[2]
				if up == 0 or left == 0:
					c = pal[3]
				elif down == 0 or right == 0:
					c = pal[1]
				out.set_pixel(x, y, c)
			elif up + left + down + right > 0:
				out.set_pixel(x, y, pal[0])
	return out


## Musgo por cima de uma textura: manchas verdes em torrões pequenos, com contorno.
static func add_moss(img: Image, spec: Dictionary) -> Image:
	var s: int = spec.get("seed", 1)
	var green: Image = clumps({"seed": s + 1, "n": 90, "ramp": spec.ramp, "crack": 0.45, "contrast": 1.1, "speck": 0.06})
	var mask := PackedByteArray()
	mask.resize(TILE * TILE)
	for y in TILE:
		for x in TILE:
			if fbm(x, y, s + 9) > spec.get("threshold", 0.56):
				mask[y * TILE + x] = 1
	var out: Image = img.duplicate()
	var dark: Color = Color(spec.ramp[0])
	for y in TILE:
		for x in TILE:
			var m: int = mask[y * TILE + x]
			if m == 1:
				out.set_pixel(x, y, green.get_pixel(x, y))
			elif mask[posmod(y - 1, TILE) * TILE + x] + mask[y * TILE + posmod(x - 1, TILE)] \
					+ mask[posmod(y + 1, TILE) * TILE + x] + mask[y * TILE + posmod(x + 1, TILE)] > 0:
				out.set_pixel(x, y, dark)
	return out


## As 16 texturas do Vale das Raízes (ordem = índice no atlas; ver TerrainSkins.TILES).
static func terrain_tiles() -> Dictionary:
	var dirt_dark := ["1e0f0a", "3e2216", "573222", "6e4430", "9a6a4a"]
	var t: Dictionary = {}
	t["terra_clara"] = clumps({"seed": 11, "n": 46, "ramp": ["3a1a0c", "8a3e18", "b05428", "cf7236", "eaa66a"], "speck": 0.03})
	t["terra_escura"] = clumps({"seed": 12, "n": 46, "ramp": dirt_dark, "speck": 0.02})
	t["argila"] = clumps({"seed": 13, "n": 30, "ramp": ["3a120c", "862818", "a83620", "c64c2e", "e2825c"], "contrast": 0.8, "speck": 0.015})
	t["solo_compacto"] = clumps({"seed": 14, "n": 70, "ramp": ["3e2212", "7a4626", "8f5636", "a46a46", "c4926a"], "contrast": 0.55, "flat": 0.5, "speck": 0.01})
	t["solo_umido"] = clumps({"seed": 15, "n": 50, "ramp": ["140a08", "2c1812", "3c221a", "4e3024", "6e4a38"], "contrast": 0.8, "speck": 0.0, "glint": "9db4c4"})
	t["solo_com_raizes"] = add_roots(clumps({"seed": 16, "n": 50, "ramp": ["24120a", "4a2818", "623826", "7a4a32", "a07050"]}),
			{"seed": 17, "count": 3, "thick": 2.6, "ramp": ["160a04", "5a2e14", "7c4420", "a2622e"]})
	t["solo_com_musgo"] = add_moss(clumps({"seed": 18, "n": 50, "ramp": ["22140c", "4a3020", "5e3e2a", "725038", "947056"]}),
			{"seed": 19, "ramp": ["12240c", "2a5216", "3f7420", "5e9a2c", "9cd050"], "threshold": 0.6})
	t["solo_rachado"] = cracked({"seed": 20, "ramp": ["2a1208", "94461c", "b2602c", "c87a44", "e4a46a"]})
	t["pedra_clara"] = clumps({"seed": 21, "n": 22, "ramp": ["3a3438", "847a7e", "a0969a", "bab2b2", "dedad6"], "speck": 0.02})
	t["pedra_cinza"] = clumps({"seed": 22, "n": 24, "ramp": ["26222e", "5c5468", "736a82", "8c849c", "b8b0c8"], "speck": 0.02})
	t["pedra_escura"] = clumps({"seed": 23, "n": 26, "ramp": ["120e14", "2c262e", "3a323e", "4c4450", "726672"], "speck": 0.015})
	t["rocha_compacta"] = clumps({"seed": 24, "n": 11, "ramp": ["262428", "565458", "6c6a70", "868488", "aeacb2"], "contrast": 1.2, "speck": 0.01})
	t["rocha_profunda"] = clumps({"seed": 25, "n": 18, "ramp": ["0c0812", "201a2c", "2e2639", "3e344a", "62547a"], "speck": 0.012})
	t["terra_avermelhada"] = clumps({"seed": 26, "n": 40, "ramp": ["2e0e08", "742214", "962e1a", "b44026", "d8704a"], "speck": 0.02})
	t["solo_arenoso"] = clumps({"seed": 27, "n": 150, "ramp": ["6a3a16", "b8743a", "cc8a4c", "e0a466", "f6cc94"], "crack": 0.35, "contrast": 0.7, "speck": 0.05, "grain": 0.8})
	t["solo_misto"] = clumps({"seed": 28, "n": 44, "ramp": ["2a160c", "6c3e22", "84502e", "9c643c", "c08c62"],
			"ramp2": ["2a2628", "625c5e", "7a7274", "948c8c", "bcb4b0"], "mix2": 0.3, "speck": 0.02})
	return t


# --- Sprites (minérios, vegetação, decorações) -------------------------------------------

## Tela de sprite com índices de paleta (-1 = transparente).
class Canvas:
	var w: int
	var h: int
	var buf: PackedInt32Array
	var pal: Array[Color]

	func _init(p_w: int, p_h: int, p_pal: Array[Color]) -> void:
		w = p_w
		h = p_h
		pal = p_pal
		buf.resize(w * h)
		buf.fill(-1)

	func setp(x: int, y: int, i: int) -> void:
		if x >= 0 and y >= 0 and x < w and y < h:
			buf[y * w + x] = i

	func getp(x: int, y: int) -> int:
		if x < 0 or y < 0 or x >= w or y >= h:
			return -1
		return buf[y * w + x]

	func poly(pts: PackedVector2Array, shade: Callable) -> void:
		var r := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			r = r.expand(p)
		for y in range(maxi(0, floori(r.position.y)), mini(h, ceili(r.end.y) + 1)):
			for x in range(maxi(0, floori(r.position.x)), mini(w, ceili(r.end.x) + 1)):
				var c := Vector2(x + 0.5, y + 0.5)
				if Geometry2D.is_point_in_polygon(c, pts):
					setp(x, y, shade.call(c))

	func disc(center: Vector2, r: float, shade: Callable) -> void:
		for y in range(maxi(0, floori(center.y - r)), mini(h, ceili(center.y + r) + 1)):
			for x in range(maxi(0, floori(center.x - r)), mini(w, ceili(center.x + r) + 1)):
				var c := Vector2(x + 0.5, y + 0.5)
				if c.distance_to(center) <= r:
					setp(x, y, shade.call(c))

	## Contorno de 1 px (vizinhança 4) em volta de tudo o que foi pintado.
	func outline(i: int) -> void:
		var add: Array[int] = []
		for y in h:
			for x in w:
				if getp(x, y) != -1:
					continue
				for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var v: int = getp(x + o.x, y + o.y)
					if v != -1 and v != i:
						add.append(y * w + x)
						break
		for k in add:
			buf[k] = i

	func image() -> Image:
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var v: int = buf[y * w + x]
				img.set_pixel(x, y, Color(0, 0, 0, 0) if v < 0 else pal[v])
		return img


## Paleta de sprite: 0 contorno, 1 escuro, 2 médio, 3 claro, 4 brilho, (5+ extras).
static func _pal(hexes: Array) -> Array[Color]:
	return ramp(hexes)


## Lasca de cristal: corpo + terminação pontuda; face esquerda clara, direita escura,
## crista central de brilho (translúcido = faixa interna clara).
static func shard(cv: Canvas, base: Vector2, tip: Vector2, hw: float, translucent: bool = false, shoulder: float = 0.62) -> void:
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
		var sd: float = d.dot(pp)
		var a: float = d.dot(an)
		if a > ln * shoulder - 0.3:
			return 4 if sd < 0.0 else 3
		if translucent and absf(sd + hw * 0.35) < 0.55:
			return 4
		if absf(sd) < 0.5 and hw >= 1.8:
			return 4
		if sd < 0.0:
			return 3
		return 1 if a < 1.2 else 2)


## Cubo isométrico (pepitas metálicas como na referência).
static func cube(cv: Canvas, x: float, y: float, s: float) -> void:
	var d: float = s * 0.9
	cv.poly(PackedVector2Array([Vector2(x, y + s * 0.5), Vector2(x + s, y + s), Vector2(x + s, y + s + d), Vector2(x, y + s * 0.5 + d)]),
			func(_c: Vector2) -> int: return 2)
	cv.poly(PackedVector2Array([Vector2(x + s, y + s), Vector2(x + 2 * s, y + s * 0.5), Vector2(x + 2 * s, y + s * 0.5 + d), Vector2(x + s, y + s + d)]),
			func(_c: Vector2) -> int: return 1)
	cv.poly(PackedVector2Array([Vector2(x, y + s * 0.5), Vector2(x + s, y), Vector2(x + 2 * s, y + s * 0.5), Vector2(x + s, y + s)]),
			func(_c: Vector2) -> int: return 3)
	cv.setp(floori(x + s * 0.7), floori(y + s * 0.45), 4)


## Pepita arredondada (metal liso): luz topo-esquerda + reflexo.
static func nugget(cv: Canvas, c: Vector2, r: float) -> void:
	cv.disc(c, r, func(p: Vector2) -> int:
		var u: Vector2 = (p - c) / r
		var lit: float = -(u.x * LIGHT.x + u.y * LIGHT.y)
		if lit < -0.45 and u.length() < 0.75:
			return 3
		if lit > 0.35:
			return 1
		return 2)
	cv.setp(floori(c.x - r * 0.4), floori(c.y - r * 0.45), 4)


## Rocha irregular (para urânio, carvão, bases de cristais).
static func rock(cv: Canvas, c: Vector2, rx: float, ry: float, s: int, dark: int, mid: int, light: int) -> void:
	for y in cv.h:
		for x in cv.w:
			var p := Vector2(x + 0.5, y + 0.5)
			var u := Vector2((p.x - c.x) / rx, (p.y - c.y) / ry)
			var wob: float = 1.0 + (hash01(int(atan2(u.y, u.x) * 3.0 + 10.0), 0, s) - 0.5) * 0.35
			if u.length() <= wob:
				var lit: float = -(u.x * LIGHT.x + u.y * LIGHT.y)
				cv.setp(x, y, light if lit < -0.35 else (dark if lit > 0.4 else mid))


static func _cluster_base(cv: Canvas, cx: float, s: int) -> void:
	rock(cv, Vector2(cx, cv.h - 2.2), 3.4, 1.6, s, 5, 6, 7)


const ROCK_GRAY := ["5a5458", "7a7276", "9a9296"]


## Depósitos: 3 variações por minério (12×12, fundo transparente).
static func ore_sprites() -> Dictionary:
	var out: Dictionary = {}
	for v in 3:
		var s: int = 100 + v * 17
		out["ferro_%d" % (v + 1)] = _cubes(["1e1816", "4e4440", "6c605a", "968a80", "d0c4b8"], s, v)
		out["cobre_%d" % (v + 1)] = _cubes(["1e0804", "a03a1a", "e0603a", "ff9a6a", "ffe2c8"], s + 1, v)
		out["prata_%d" % (v + 1)] = _cubes(["262a36", "7e8698", "aab2c4", "d8e0ee", "ffffff"], s + 2, v)
		out["titanio_%d" % (v + 1)] = _cubes(["141c32", "3e4e78", "5c72a8", "8ea8dc", "e0ecff"], s + 3, v)
		out["ouro_%d" % (v + 1)] = _gold(s + 4, v)
		out["carvao_%d" % (v + 1)] = _coal(s + 5, v)
		out["uranio_%d" % (v + 1)] = _uranium(s + 6, v)
		out["diamante_%d" % (v + 1)] = _diamond(s + 7, v)
		out["cristal_azul_%d" % (v + 1)] = _crystals(["06144a", "1438b4", "2466f0", "6eaaff", "dcecff"], s + 8, v, 4, 9.5, 1.5, false, true)
		out["cristal_verde_%d" % (v + 1)] = _crystals(["05302a", "0e7a52", "1cb880", "7cecc0", "e6fff4"], s + 9, v, 3, 10.0, 2.0, true, false)
		out["cristal_vermelho_%d" % (v + 1)] = _crystals(["36060e", "960e24", "d82236", "ff767c", "ffdcdc"], s + 10, v, 3, 8.0, 1.8, false, false)
		out["cristal_roxo_%d" % (v + 1)] = _crystals(["22042a", "7a1484", "b824b4", "f264e8", "ffd4ff"], s + 11, v, 3, 10.5, 2.1, false, true)
		out["ametista_%d" % (v + 1)] = _amethyst(s + 12, v)
		out["topazio_%d" % (v + 1)] = _topaz(s + 13, v)
		out["quartzo_%d" % (v + 1)] = _crystals(["3a3a48", "9c9cae", "cfcfdc", "f0f0f6", "ffffff"], s + 14, v, 3, 7.0, 1.2, true, false)
	return out


static func _with_rock(hexes: Array) -> Array[Color]:
	var p: Array = hexes.duplicate()
	p.append_array(ROCK_GRAY)
	return _pal(p)


## Cubos em 3/4 desenhados pixel a pixel (3 = topo claro, 4 = brilho, 2 = face esquerda,
## 1 = face direita escura). Contorno aplicado depois.
const CUBE_BIG := [".333.", "34333", "22211", "22211", ".221."]
const CUBE_SMALL := [".33.", "3433", "2211", ".21."]


static func _stamp(cv: Canvas, tpl: Array, x: int, y: int) -> void:
	for j in tpl.size():
		var row: String = tpl[j]
		for i in row.length():
			if row[i] != ".":
				cv.setp(x + i, y + j, int(row[i]))


static func _cubes(hexes: Array, s: int, v: int) -> Image:
	var cv := Canvas.new(ORE, ORE, _pal(hexes))
	var layouts: Array = [
		[[CUBE_SMALL, 3, 2], [CUBE_BIG, 1, 5], [CUBE_SMALL, 6, 6]],
		[[CUBE_BIG, 4, 2], [CUBE_SMALL, 1, 6], [CUBE_BIG, 5, 6]],
		[[CUBE_SMALL, 2, 3], [CUBE_SMALL, 6, 3], [CUBE_BIG, 3, 6]],
	]
	for c: Array in layouts[v]:
		_stamp(cv, c[0], c[1], c[2])
	# Alguns pixels de impureza (ferrugem/veio) na face escura.
	if hash01(v, 1, s) < 0.7:
		for y in cv.h:
			for x in cv.w:
				if cv.getp(x, y) == 2 and hash01(x, y, s) < 0.08:
					cv.setp(x, y, 1)
	cv.outline(0)
	return cv.image()


static func _gold(s: int, v: int) -> Image:
	var cv := Canvas.new(ORE, ORE, _pal(["3e2804", "a06c08", "dca416", "ffd84a", "fff6c8"]))
	var sets: Array = [
		[[4.5, 6.5, 2.8], [7.6, 7.4, 2.2], [6.0, 4.2, 2.0]],
		[[5.5, 6.0, 3.3], [8.4, 8.0, 1.6]],
		[[3.8, 7.2, 2.2], [6.6, 6.2, 2.6], [8.6, 8.4, 1.5], [5.0, 4.0, 1.5]],
	]
	for n: Array in sets[v]:
		nugget(cv, Vector2(n[0], n[1]), n[2])
	cv.outline(0)
	return cv.image()


static func _coal(s: int, v: int) -> Image:
	var cv := Canvas.new(ORE, ORE, _pal(["08080c", "16161e", "26262f", "3a3a48", "a8b8d0"]))
	var sets: Array = [[[4.5, 6.5, 3.2, 2.4], [7.8, 7.0, 2.4, 2.0]], [[6.0, 6.0, 3.6, 2.8]], [[3.8, 5.0, 2.4, 2.0], [7.0, 7.4, 3.0, 2.2]]]
	for r: Array in sets[v]:
		rock(cv, Vector2(r[0], r[1]), r[2], r[3], s, 1, 2, 3)
	for k in 3:
		var x: int = 3 + int(hash01(k, v, s) * 6)
		var y: int = 4 + int(hash01(k, v + 9, s) * 4)
		if cv.getp(x, y) >= 0:
			cv.setp(x, y, 4)
	cv.outline(0)
	return cv.image()


## Urânio: rocha opaca com partes minerais expostas em verde-limão (não é cristal).
static func _uranium(s: int, v: int) -> Image:
	var cv := Canvas.new(ORE, ORE, _pal(["0c140c", "222a22", "343e32", "4a5646", "f4ffb4", "4e8a12", "8ed626", "c8ff58"]))
	var sets: Array = [[[6.0, 6.5, 4.4, 3.4]], [[4.6, 6.2, 3.2, 2.8], [8.0, 7.2, 2.6, 2.4]], [[6.2, 6.0, 4.0, 3.8]]]
	for r: Array in sets[v]:
		rock(cv, Vector2(r[0], r[1]), r[2], r[3], s, 1, 2, 3)
	for y in cv.h:
		for x in cv.w:
			if cv.getp(x, y) < 0:
				continue
			var n: float = hash01(x / 2, y / 2, s) * 0.6 + hash01(x, y, s + 1) * 0.4
			if n > 0.62:
				cv.setp(x, y, 7 if hash01(x, y, s + 2) > 0.55 else 6)
				if n > 0.86:
					cv.setp(x, y, 4)
			elif n > 0.55:
				cv.setp(x, y, 5)
	cv.outline(0)
	return cv.image()


## Diamante: gema lapidada compacta (coroa, mesa, pavilhão) + gemas menores.
static func _diamond(s: int, v: int) -> Image:
	var cv := Canvas.new(ORE, ORE, _pal(["1e3a5a", "6aa2d6", "a8d8fa", "e2f6ff", "ffffff"]))
	match v:
		0:
			_gem(cv, Vector2(6.0, 5.2), 4.4)
		1:
			_gem(cv, Vector2(5.0, 4.6), 3.6)
			_octa(cv, Vector2(9.0, 8.6), 2.2)
		_:
			_octa(cv, Vector2(3.6, 7.6), 2.4)
			_gem(cv, Vector2(7.2, 5.0), 3.4)
	cv.outline(0)
	return cv.image()


## Octaedro pequeno: losango com quatro facetas.
static func _octa(cv: Canvas, c: Vector2, r: float) -> void:
	cv.poly(PackedVector2Array([Vector2(c.x, c.y - r * 1.2), Vector2(c.x + r, c.y), Vector2(c.x, c.y + r * 1.2), Vector2(c.x - r, c.y)]),
			func(p: Vector2) -> int:
				if p.y < c.y:
					return 4 if p.x < c.x else 3
				return 2 if p.x < c.x else 1)


static func _gem(cv: Canvas, c: Vector2, r: float) -> void:
	var top: float = c.y - r * 0.55
	var mid: float = c.y
	var bot: float = c.y + r * 1.15
	var pts := PackedVector2Array([Vector2(c.x - r * 0.55, top), Vector2(c.x + r * 0.55, top), Vector2(c.x + r, mid),
			Vector2(c.x, bot), Vector2(c.x - r, mid)])
	cv.poly(pts, func(p: Vector2) -> int:
		if p.y < mid:
			if absf(p.x - c.x) < r * 0.4 and p.y < top + r * 0.35:
				return 4
			return 3 if p.x < c.x else 2
		var t: float = (p.x - c.x) / maxf(0.5, r * (1.0 - (p.y - mid) / (bot - mid)))
		if t < -0.5:
			return 3
		if t < 0.0:
			return 4
		if t < 0.5:
			return 2
		return 1)


static func _crystals(hexes: Array, s: int, v: int, n: int, tall: float, hw: float, translucent: bool, irregular: bool) -> Image:
	var cv := Canvas.new(ORE, ORE, _with_rock(hexes))
	var cx: float = 6.0 + (hash01(v, 1, s) - 0.5) * 1.5
	_cluster_base(cv, cx, s)
	for i in n:
		var t: float = (float(i) / maxf(1.0, n - 1)) - 0.5
		var spread: float = 0.9 if irregular else 0.6
		var ang: float = t * spread + (hash01(i, v, s) - 0.5) * (0.5 if irregular else 0.2)
		var ln: float = tall * (0.65 + 0.35 * hash01(i, v + 3, s))
		if i == n / 2:
			ln = tall
		var base := Vector2(cx + t * 3.2, cv.h - 1.5)
		var tip: Vector2 = base + Vector2(sin(ang), -cos(ang)) * ln
		var w: float = hw * (0.75 + 0.35 * hash01(i, v + 5, s))
		shard(cv, base, tip, w, translucent, 0.55 if irregular else 0.62)
	cv.outline(0)
	return cv.image()


## Ametista: drusa compacta de pontas curtas, violeta suave.
static func _amethyst(s: int, v: int) -> Image:
	var cv := Canvas.new(ORE, ORE, _with_rock(["24103a", "60349c", "845ac6", "b08ee8", "eadcff"]))
	rock(cv, Vector2(6.0, cv.h - 1.8), 4.2, 1.5, s, 5, 6, 7)
	# Pontas separadas por 1 px (o contorno as destaca): drusa compacta e natural.
	var xs: Array = [[2.6, 5.4, 8.2], [2.2, 4.8, 7.4, 10.0], [3.4, 6.2, 9.0]][v]
	var hs: Array = [[4.5, 6.5, 5.0], [4.0, 6.0, 5.5, 3.6], [5.6, 7.0, 4.4]][v]
	for i in xs.size():
		var t: float = float(i) / maxf(1.0, xs.size() - 1) - 0.5
		var base := Vector2(xs[i], cv.h - 2.4)
		var ang: float = t * 0.7
		shard(cv, base, base + Vector2(sin(ang), -cos(ang)) * hs[i], 1.0)
	cv.outline(0)
	return cv.image()


## Topázio: prismas alongados âmbar com terminação em bisel (faces verticais).
static func _topaz(s: int, v: int) -> Image:
	var cv := Canvas.new(ORE, ORE, _with_rock(["4a2004", "b8561a", "e8802a", "ffb456", "ffe4ac"]))
	_cluster_base(cv, 6.0, s)
	var specs: Array = [[[4.4, 9.0, 1.8, -0.15], [7.6, 7.0, 1.6, 0.25]], [[6.0, 9.5, 2.1, 0.05]], [[3.8, 6.0, 1.5, -0.35], [6.2, 9.4, 1.9, 0.0], [8.6, 6.4, 1.4, 0.4]]]
	for sp: Array in specs[v]:
		var base := Vector2(sp[0], cv.h - 1.5)
		var ang: float = sp[3]
		var an := Vector2(sin(ang), -cos(ang))
		var pp := Vector2(-an.y, an.x)
		var hw: float = sp[2]
		var body: Vector2 = base + an * sp[1] * 0.78
		var tip: Vector2 = base + an * sp[1] + pp * hw * 0.5
		var pts := PackedVector2Array([base - pp * hw, body - pp * hw, tip, body + pp * hw, base + pp * hw])
		cv.poly(pts, func(c: Vector2) -> int:
			var sd: float = (c - base).dot(pp) / hw
			var a: float = (c - base).dot(an)
			if a > sp[1] * 0.78 - 0.3:
				return 4 if sd < 0.2 else 3
			if sd < -0.35:
				return 3
			if sd < 0.35:
				return 4 if absf(sd) < 0.12 else 2
			return 1)
	cv.outline(0)
	return cv.image()


# --- Vegetação e decorações --------------------------------------------------------------

const ROOT_PAL := ["140904", "4e2812", "723c1c", "985628", "c07a40"]


static func _root_sprite(w: int, h: int, s: int, count: int, thick: float, hanging: bool, branchy: float) -> Image:
	var cv := Canvas.new(w, h, _pal(ROOT_PAL))
	for r in count:
		var pos := Vector2(w * (0.3 + 0.4 * hash01(r, 1, s)), 1.0 if hanging else h * (0.15 + 0.2 * hash01(r, 2, s)))
		var ang: float = PI * 0.5 + (hash01(r, 3, s) - 0.5) * (0.6 if hanging else 1.8)
		var steps: int = int(h * (0.8 if hanging else 0.75))
		_sprite_walk(cv, pos, ang, steps, thick * (0.7 + 0.5 * hash01(r, 4, s)), s + r * 7, 2, branchy)
	cv.outline(0)
	return _shade_mask(cv)


static func _sprite_walk(cv: Canvas, pos: Vector2, ang: float, steps: int, thick: float, s: int, depth: int, branchy: float) -> void:
	for i in steps:
		var t: float = thick * (1.0 - float(i) / steps * 0.75)
		cv.disc(pos, maxf(0.55, t * 0.5), func(_c: Vector2) -> int: return 2)
		ang += (hash01(i, depth, s) - 0.5) * 0.5
		ang = lerpf(ang, PI * 0.5, 0.06)
		pos += Vector2(cos(ang), sin(ang))
		if pos.x < 1.0 or pos.x > cv.w - 2 or pos.y > cv.h - 2:
			return
		if depth > 0 and i > 3 and hash01(i, 55, s) < branchy:
			_sprite_walk(cv, pos, ang + (0.8 if hash01(i, 56, s) < 0.5 else -0.8), int((steps - i) * 0.55), t * 0.6, s + i * 11, depth - 1, branchy)


## Sombreamento de formas pintadas com índice 2: borda de cima/esquerda clara, baixo/direita escura.
static func _shade_mask(cv: Canvas) -> Image:
	var src: PackedInt32Array = cv.buf.duplicate()
	for y in cv.h:
		for x in cv.w:
			if src[y * cv.w + x] != 2:
				continue
			var up: int = src[y * cv.w + x - cv.w] if y > 0 else 0
			var left: int = src[y * cv.w + x - 1] if x > 0 else 0
			var down: int = src[y * cv.w + x + cv.w] if y < cv.h - 1 else 0
			var right: int = src[y * cv.w + x + 1] if x < cv.w - 1 else 0
			if up <= 0 or left <= 0:
				cv.buf[y * cv.w + x] = 3
			elif down <= 0 or right <= 0:
				cv.buf[y * cv.w + x] = 1
	return cv.image()


static func _vine(s: int) -> Image:
	var cv := Canvas.new(12, 24, _pal(["0c1a08", "264a14", "3a6c1c", "5a9a2a", "9cd050", "5a3a1c"]))
	var x: float = 6.0
	for y in 22:
		x += (hash01(y, 0, s) - 0.5) * 0.9
		x = clampf(x, 3.0, 8.0)
		cv.setp(floori(x), y + 1, 5)
		if y > 2 and y % 3 == 0:
			var side: int = 1 if (y / 3) % 2 == 0 else -1
			cv.setp(floori(x) + side, y, 3)
			cv.setp(floori(x) + side * 2, y, 2)
			cv.setp(floori(x) + side, y + 1, 4 if side < 0 else 2)
	cv.outline(0)
	return cv.image()


static func _moss(s: int, w: int) -> Image:
	var cv := Canvas.new(w, 7, _pal(["0e1c08", "2a5216", "3f7420", "5e9a2c", "9cd050"]))
	for x in range(1, w - 1):
		var edge: float = 1.0 - absf((x + 0.5) / w - 0.5) * 1.6
		var hgt: int = clampi(roundi((1.0 + hash01(x, 1, s) * 3.5) * edge + hash01(x / 2, 2, s)), 1, 6)
		for k in hgt:
			cv.setp(x, 6 - k, 3 if k == hgt - 1 else (1 if k == 0 else 2))
		if hgt >= 3 and hash01(x, 3, s) < 0.35:
			cv.setp(x, 6 - hgt + 1, 4)
	cv.outline(0)
	return cv.image()


static func _fern(s: int) -> Image:
	var cv := Canvas.new(15, 13, _pal(["0c1a08", "2a5216", "3f7420", "5e9a2c", "9cd050"]))
	for f in 5:
		var ang: float = -PI * 0.5 + (float(f) / 4.0 - 0.5) * 2.2
		var p := Vector2(7.5, 12.0)
		for i in 9 - absi(f - 2):
			var q: Vector2 = p + Vector2(cos(ang), sin(ang)) * i
			cv.setp(floori(q.x), floori(q.y), 3 if f < 2 else 2)
			if i > 1 and i % 2 == 0:
				cv.setp(floori(q.x) - 1, floori(q.y) + 1, 2)
				cv.setp(floori(q.x) + 1, floori(q.y) + 1, 1)
			ang += 0.06 * signf(float(f) - 2.0)
	cv.setp(7, 12, 1)
	cv.outline(0)
	return cv.image()


static func _sprout(s: int) -> Image:
	var cv := Canvas.new(10, 11, _pal(["0c1a08", "2a5216", "3f7420", "6aa82e", "a8dc5a"]))
	for y in range(4, 11):
		cv.setp(5, y, 2)
	cv.disc(Vector2(3.0, 4.5), 2.3, func(c: Vector2) -> int: return 3 if c.y < 4.3 else 2)
	cv.disc(Vector2(7.2, 3.2), 2.2, func(c: Vector2) -> int: return 4 if c.x < 7.0 and c.y < 3.0 else 3)
	cv.disc(Vector2(5.0, 1.8), 1.3, func(_c: Vector2) -> int: return 3)
	cv.outline(0)
	return cv.image()


static func _mushroom(caps: Array, hexes: Array, spots: bool) -> Image:
	var cv := Canvas.new(11, 11, _pal(hexes))
	for m: Array in caps:
		var x: float = m[0]
		var top: float = m[1]
		var r: float = m[2]
		for y in range(ceili(top + r * 0.6), 11):
			cv.setp(floori(x), y, 6)
			cv.setp(floori(x) - 1, y, 7)
		cv.poly(PackedVector2Array([Vector2(x - r, top + r * 0.8), Vector2(x - r * 0.6, top), Vector2(x + r * 0.6, top), Vector2(x + r, top + r * 0.8)]),
				func(c: Vector2) -> int: return 3 if c.x < x - 0.5 else 2)
		if spots:
			cv.setp(floori(x - r * 0.3), floori(top + 1.0), 5)
			cv.setp(floori(x + r * 0.45), floori(top + r * 0.5), 5)
	cv.outline(0)
	return cv.image()


static func _pebbles(s: int, w: int, h: int, n: int, hexes: Array) -> Image:
	var cv := Canvas.new(w, h, _pal(hexes))
	for i in n:
		var c := Vector2(2.0 + hash01(i, 0, s) * (w - 4), 2.0 + hash01(i, 1, s) * (h - 4))
		var r: float = 1.4 + hash01(i, 2, s) * 1.5
		rock(cv, c, r * 1.25, r, s + i, 1, 2, 3)
	cv.outline(0)
	return cv.image()


static func _spike(s: int, w: int, h: int, hexes: Array, down: bool) -> Image:
	var cv := Canvas.new(w, h, _pal(hexes))
	var n: int = 2 if w > 8 else 1
	for i in n:
		var bx: float = w * (0.5 if n == 1 else (0.35 + 0.35 * i))
		var hw: float = (w * 0.38) / n * (1.2 if i == 0 else 0.9)
		var ln: float = (h - 1.5) * (1.0 if i == 0 else 0.6)
		var base := Vector2(bx, 0.5 if down else h - 1.0)
		var tip: Vector2 = base + Vector2(hash01(i, 1, s) - 0.5, ln if down else -ln)
		cv.poly(PackedVector2Array([base - Vector2(hw, 0), tip, base + Vector2(hw, 0)]), func(c: Vector2) -> int:
			var t: float = (c.y - base.y) / (tip.y - base.y)
			var sd: float = (c.x - lerpf(base.x, tip.x, t)) / maxf(0.5, hw * (1.0 - t))
			if hash01(floori(c.x), floori(c.y), s) < 0.12:
				return 1
			return 3 if sd < -0.2 else (1 if sd > 0.45 else 2))
	cv.outline(0)
	return cv.image()


const BONE_PAL := ["2a2016", "8a7a60", "bcae8e", "e2d6b6", "fffbea"]


static func _bone() -> Image:
	var cv := Canvas.new(15, 8, _pal(BONE_PAL))
	cv.poly(PackedVector2Array([Vector2(3, 3), Vector2(12, 3), Vector2(12, 5), Vector2(3, 5)]), func(c: Vector2) -> int: return 3 if c.y < 4.0 else 2)
	for e: Vector2 in [Vector2(2.4, 2.6), Vector2(2.4, 5.4), Vector2(12.6, 2.6), Vector2(12.6, 5.4)]:
		cv.disc(e, 1.6, func(c: Vector2) -> int: return 3 if c.y < e.y else 2)
	cv.setp(6, 3, 4)
	cv.outline(0)
	return cv.image()


static func _skull() -> Image:
	var cv := Canvas.new(12, 11, _pal(BONE_PAL))
	cv.disc(Vector2(6.0, 4.6), 4.2, func(c: Vector2) -> int: return 3 if c.y < 4.0 and c.x < 6.5 else 2)
	cv.poly(PackedVector2Array([Vector2(3.4, 6.0), Vector2(8.6, 6.0), Vector2(8.0, 10.0), Vector2(4.0, 10.0)]), func(_c: Vector2) -> int: return 2)
	for e: Vector2i in [Vector2i(4, 5), Vector2i(5, 5), Vector2i(7, 5), Vector2i(8, 5), Vector2i(4, 6), Vector2i(8, 6)]:
		cv.setp(e.x, e.y, 0)
	cv.setp(6, 7, 1)
	for x in [5, 7]:
		cv.setp(x, 9, 1)
	cv.setp(4, 2, 4)
	cv.outline(0)
	return cv.image()


static func _ammonite() -> Image:
	var cv := Canvas.new(13, 13, _pal(["2a1a10", "6e4a30", "9a7050", "c49a72", "ecd2b0"]))
	var c := Vector2(6.5, 6.5)
	cv.disc(c, 5.6, func(p: Vector2) -> int:
		var d: Vector2 = p - c
		return 3 if d.y < -0.5 and d.x < 1.0 else 2)
	var a: float = 0.0
	while a < TAU * 2.6:
		var r: float = 0.6 + a / TAU * 1.9
		cv.setp(floori(c.x + cos(a) * r), floori(c.y + sin(a) * r), 1)
		a += 0.08
	cv.setp(4, 2, 4)
	cv.setp(9, 3, 4)
	cv.outline(0)
	return cv.image()


static func _ribs() -> Image:
	var cv := Canvas.new(16, 12, _pal(BONE_PAL))
	for x in range(2, 15):
		cv.setp(x, 2, 3)
		cv.setp(x, 3, 2)
	for i in 5:
		var x: float = 3.0 + i * 2.6
		for y in range(4, 10 - absi(i - 2)):
			cv.setp(floori(x + (y - 4) * 0.25), y, 3 if y < 6 else 2)
	cv.outline(0)
	return cv.image()


## Vegetação (raízes, cipós, musgo, plantas, fungos) e decorações (pedras, fósseis).
static func vegetation_sprites() -> Dictionary:
	return {
		"raiz_fina_a": _root_sprite(24, 24, 301, 2, 1.6, false, 0.04),
		"raiz_fina_b": _root_sprite(24, 24, 302, 1, 1.8, false, 0.08),
		"raiz_retorcida": _root_sprite(24, 24, 303, 1, 2.4, false, 0.12),
		"raiz_grossa": _root_sprite(24, 24, 304, 1, 3.8, false, 0.06),
		"raiz_pendente_a": _root_sprite(16, 24, 305, 2, 2.2, true, 0.06),
		"raiz_pendente_b": _root_sprite(16, 22, 306, 1, 3.0, true, 0.1),
		"cipo_pendente": _vine(307),
		"musgo_a": _moss(308, 12),
		"musgo_b": _moss(309, 9),
		"samambaia": _fern(310),
		"broto": _sprout(311),
		"cogumelo_vermelho": _mushroom([[4.0, 3.0, 3.0], [8.5, 6.0, 1.8]], ["1a0a08", "6a1810", "b02a1a", "e04a2a", "ff9a70", "f4ead6", "d8ccb4", "a89a80"], true),
		"cogumelo_marrom": _mushroom([[3.5, 5.0, 2.2], [7.0, 6.5, 1.8]], ["1a0e08", "4a2c18", "7a4a28", "a06a3a", "d8a874", "e8dcc0", "c8b898", "988a70"], false),
	}


static func decoration_sprites() -> Dictionary:
	return {
		"pedrinhas_a": _pebbles(401, 9, 6, 3, ["1a1618", "5a5254", "7a7072", "9c9294"]),
		"pedrinhas_b": _pebbles(402, 8, 6, 2, ["1e140e", "5e4432", "7c5c44", "a07c5e"]),
		"pedra_pequena": _pebbles(403, 11, 9, 2, ["1a1618", "5a5254", "766e70", "a0989a"]),
		"pedra_escura": _pebbles(404, 10, 8, 2, ["0c0a0e", "2a242c", "3a323c", "564c58"]),
		"monte_pedras": _pebbles(405, 15, 8, 5, ["1a1618", "5a5254", "7a7072", "a09698"]),
		"rocha_pontuda_a": _spike(406, 11, 16, ["240c08", "6a2a1c", "984030", "c06248"], false),
		"rocha_pontuda_b": _spike(407, 7, 12, ["240c08", "6a2a1c", "984030", "c06248"], false),
		"estalactite": _spike(408, 7, 14, ["161216", "4a4048", "665a64", "8a7e88"], true),
		"fossil_osso": _bone(),
		"fossil_cranio": _skull(),
		"fossil_amonite": _ammonite(),
		"fossil_costelas": _ribs(),
	}
