class_name FinalGuardian
extends Node2D
## Guardião da câmara final (marco e chefe de cada região): um coração pulsante no piso da
## câmara, preso por raízes (Vale, Pântano) ou cercado de cristais (demais regiões).
## O núcleo é rocha-mãe no mundo (a nave encosta nele); a broca o desgasta por contato.
## A cada GUARDIAN_PULSE_INTERVAL ele brilha e solta um pulso que fere o casco de quem
## estiver no alcance. Vencido, o coração some e as raízes/cristais ficam apagados como
## marco. Regras em step()/take_damage() (testáveis); o desenho é pixel art de 3 px.

signal defeated

const ART: float = 3.0
const RING_TIME: float = 0.55

var region: RegionDef
var center: Vector2 = Vector2.ZERO
var radius: float = 0.0
var max_hp: float = 1.0
var hp: float = 1.0
var alive: bool = false
var pulse_damage: float = 0.0
var pulse_range: float = 0.0

var _pulse_t: float = 0.0
var _ring_t: float = -1.0
var _flash: float = 0.0
var _t: float = 0.0
var _dead_t: float = -1.0
var _heart_tex: Texture2D
var _deco_tex: Texture2D
var _deco_origin: Vector2 = Vector2.ZERO
var _cracks: Array[PackedVector2Array] = []
var glow_color: Color = Color.WHITE


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(r: RegionDef, is_alive: bool) -> void:
	region = r
	center = RegionRegistry.guardian_center(r)
	radius = Balance.GUARDIAN_RADIUS_BLOCKS * Balance.BLOCK_PX
	max_hp = RegionRegistry.guardian_hp(r)
	hp = max_hp if is_alive else 0.0
	alive = is_alive
	pulse_damage = RegionRegistry.guardian_pulse_damage(r)
	pulse_range = Balance.GUARDIAN_PULSE_RANGE_BLOCKS * Balance.BLOCK_PX
	_pulse_t = 0.0
	_ring_t = -1.0
	_flash = 0.0
	_dead_t = -1.0 if is_alive else 99.0
	_build_art()
	queue_redraw()


func hp_ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)


## A nave está na arena (perto o bastante para a barra de vida aparecer).
func in_arena(p: Vector2) -> bool:
	return region != null and p.distance_to(center) < (Balance.FINAL_CHAMBER_HALF_WIDTH + 2) * Balance.BLOCK_PX


## A broca (centro bc, raio br) encosta no coração.
func touches(bc: Vector2, br: float) -> bool:
	return alive and bc.distance_to(center) <= radius + br * 0.6 + 4.0


## Avança o relógio dos pulsos (só com a nave na arena). Retorna o dano no casco deste passo.
func step(delta: float, ship: Vector2) -> float:
	if not alive or not in_arena(ship):
		_pulse_t = 0.0
		return 0.0
	_pulse_t += delta
	if _pulse_t < Balance.GUARDIAN_PULSE_INTERVAL:
		return 0.0
	_pulse_t = 0.0
	_ring_t = 0.0
	return pulse_damage if ship.distance_to(center) <= pulse_range else 0.0


## Dano da broca. Retorna true quando o guardião acabou de ser vencido.
func take_damage(amount: float) -> bool:
	if not alive or amount <= 0.0:
		return false
	hp = maxf(0.0, hp - amount)
	_flash = 1.0
	if hp > 0.0:
		return false
	alive = false
	_dead_t = 0.0
	defeated.emit()
	return true


## 0..1: quanto falta para o próximo pulso (o coração brilha no aviso).
func warn_ratio() -> float:
	var left: float = Balance.GUARDIAN_PULSE_INTERVAL - _pulse_t
	return clampf(1.0 - left / Balance.GUARDIAN_PULSE_WARN, 0.0, 1.0) if alive and _pulse_t > 0.0 else 0.0


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 6.0)
	if _ring_t >= 0.0:
		_ring_t += delta
		if _ring_t > RING_TIME:
			_ring_t = -1.0
	if _dead_t >= 0.0 and _dead_t < 99.0:
		_dead_t += delta
	queue_redraw()


func _draw() -> void:
	if region == null:
		return
	var dead: bool = not alive
	# Raízes / cristais: marco permanente; apagados depois da vitória.
	var deco_mod := Color(1, 1, 1) if not dead else Color(0.5, 0.45, 0.45)
	draw_texture_rect(_deco_tex, Rect2(_deco_origin, Vector2(_deco_tex.get_size()) * ART), false, deco_mod)
	if dead:
		# Explosão final: anel claro que se abre e some.
		if _dead_t < 1.2:
			var k: float = _dead_t / 1.2
			draw_arc(center, radius * (1.0 + k * 3.0), 0.0, TAU, 48, Color(glow_color.r, glow_color.g, glow_color.b, 1.0 - k), 10.0 * (1.0 - k) + 2.0)
			draw_circle(center, radius * (1.0 - k), Color(1, 0.95, 0.8, (1.0 - k) * 0.8))
		return
	var warn: float = warn_ratio()
	var beat: float = 0.5 + 0.5 * sin(_t * (3.0 + warn * 9.0))
	# Brilho de fundo (pulsante; forte no aviso de pulso).
	for i in 3:
		var a: float = (0.10 + 0.10 * beat + 0.25 * warn) * (1.0 - i * 0.3)
		draw_circle(center, radius * (1.25 + i * 0.35), Color(glow_color.r, glow_color.g, glow_color.b, a))
	var s: float = 1.0 + 0.03 * beat + 0.05 * warn
	var size: Vector2 = Vector2(_heart_tex.get_size()) * ART * s
	var mod := Color(1, 1, 1).lerp(Color(2.0, 2.0, 2.0), _flash * 0.6).lerp(Color(1.6, 1.3, 1.1), warn * 0.5)
	draw_texture_rect(_heart_tex, Rect2(center - size * 0.5, size), false, mod)
	# Rachaduras conforme perde vida.
	var n: int = mini(_cracks.size(), int((1.0 - hp_ratio()) * (_cracks.size() + 1)))
	for i in n:
		var pts: PackedVector2Array = _cracks[i]
		for k in pts.size() - 1:
			draw_line(center + pts[k] * s, center + pts[k + 1] * s, Color(0.08, 0.02, 0.02, 0.95), ART)
			draw_line(center + pts[k] * s + Vector2(ART, 0), center + pts[k + 1] * s + Vector2(ART, 0), Color(glow_color.r, glow_color.g, glow_color.b, 0.7), ART * 0.7)
	# Pulso: anel que se abre até o alcance.
	if _ring_t >= 0.0:
		var k: float = _ring_t / RING_TIME
		var rr: float = lerpf(radius, pulse_range, k)
		draw_arc(center, rr, 0.0, TAU, 64, Color(glow_color.r, glow_color.g, glow_color.b, 0.9 * (1.0 - k)), 12.0 * (1.0 - k) + 3.0)
		draw_arc(center, rr * 0.92, 0.0, TAU, 64, Color(1, 1, 1, 0.5 * (1.0 - k)), 3.0)


# --- Arte ------------------------------------------------------------------------------

func _roots_theme() -> bool:
	return region.theme in [&"savanna", &"swamp"]


func _build_art() -> void:
	var s: int = hash(String(region.id)) & 0xFFFF
	var core: Array = _core_palette()
	glow_color = core[3]
	# Coração: disco sombreado com veias brilhantes e um núcleo claro.
	var hr: float = radius / ART
	var hn: int = int(ceil(hr * 2.0)) + 4
	var cv := EnvArt.Canvas.new(hn, hn, core)
	var c := Vector2(hn * 0.5, hn * 0.5)
	var lit := Vector2(-0.6, -0.8).normalized()
	cv.disc(c, hr, func(p: Vector2) -> int:
		var d: Vector2 = (p - c) / hr
		var l: float = d.length()
		var b: float = d.normalized().dot(lit) if l > 0.01 else 0.0
		if l < 0.3:
			return 4 if l < 0.18 else 3
		var vein: float = absf(sin(atan2(d.y, d.x) * 5.0 + l * 7.0 + s))
		if vein < 0.16 and l < 0.9:
			return 3
		if l > 0.82 and b < 0.0:
			return 1
		return 2 if b < 0.35 else 3, 1.0)
	cv.outline(0)
	_heart_tex = ImageTexture.create_from_image(cv.image())
	# Rachaduras (px, relativas ao centro).
	_cracks.clear()
	for i in 6:
		var a: float = TAU * (i / 6.0) + EnvArt.hash01(i, 1, s) * 0.8
		var pts := PackedVector2Array([Vector2.ZERO])
		var p := Vector2.ZERO
		for k in 4:
			a += (EnvArt.hash01(i, k + 3, s) - 0.5) * 1.1
			p += Vector2(cos(a), sin(a)) * radius * 0.24
			pts.append(p)
		_cracks.append(pts)
	# Raízes/cristais ocupando a câmara (marco visível ao chegar).
	var w: int = int((Balance.FINAL_CHAMBER_HALF_WIDTH * 2 + 3) * Balance.BLOCK_PX / ART)
	var h: int = int((Balance.FINAL_CHAMBER_ROWS + 2) * Balance.BLOCK_PX / ART)
	_deco_origin = Vector2(center.x - w * ART * 0.5, center.y + radius - h * ART + 2.0 * ART)
	var hc := (center - _deco_origin) / ART
	var dcv: EnvArt.Canvas
	if _roots_theme():
		dcv = EnvArt.Canvas.new(w, h, EnvArt.ramp(EnvArt.ROOT_RAMP))
		var paths: Array = []
		var n: int = 7
		for i in n:
			var t: float = float(i) / (n - 1)
			var ang: float = lerpf(PI + 0.1, TAU - 0.1, t) + (EnvArt.hash01(i, 2, s) - 0.5) * 0.25
			var start: Vector2 = hc + Vector2(cos(ang), sin(ang)) * hr * 0.6
			var length: int = int(lerpf(90.0, 150.0, EnvArt.hash01(i, 3, s)))
			# Raízes grossas (mais ainda nas laterais, que seguram o coração no piso).
			var thick: float = lerpf(15.0, 22.0, absf(t - 0.5) * 2.0)
			paths.append_array(EnvArt.root_tree(start, ang, length, thick, s + i * 13, 1, 0.3))
		_paint_paths(dcv, paths)
	else:
		var base: Color = region.ui_color
		var pal: Array[Color] = [Color("0b0710"), base.darkened(0.65), base.darkened(0.3), base, base.lightened(0.55)]
		dcv = EnvArt.Canvas.new(w, h, pal)
		for i in 14:
			var side: float = -1.0 if i % 2 == 0 else 1.0
			var x: float = hc.x + side * (hr * 1.2 + EnvArt.hash01(i, 4, s) * w * 0.38)
			var floor_y: float = hc.y + hr * 0.85
			var tall: float = lerpf(14.0, 40.0, EnvArt.hash01(i, 5, s))
			var lean: float = (EnvArt.hash01(i, 6, s) - 0.5) * 0.7 + side * 0.25
			EnvArt.shard(dcv, Vector2(x, floor_y + 2.0), Vector2(x + lean * tall, floor_y - tall), lerpf(3.0, 6.0, EnvArt.hash01(i, 7, s)), true)
		for i in 8:
			var x: float = w * (0.12 + 0.76 * EnvArt.hash01(i, 8, s))
			var tall: float = lerpf(10.0, 26.0, EnvArt.hash01(i, 9, s))
			EnvArt.shard(dcv, Vector2(x, 0.0), Vector2(x + (EnvArt.hash01(i, 10, s) - 0.5) * 8.0, tall), lerpf(2.5, 4.5, EnvArt.hash01(i, 11, s)), true)
		dcv.outline(0)
	_deco_tex = ImageTexture.create_from_image(dcv.image())


## Paleta do coração (0 contorno, 1 sombra, 2 corpo, 3 brilho, 4 núcleo).
func _core_palette() -> Array[Color]:
	match region.theme:
		&"savanna":
			return [Color("140806"), Color("5a1a12"), Color("a8341c"), Color("ff7a2e"), Color("ffe08a")]
		&"swamp":
			return [Color("061008"), Color("1e3a1e"), Color("3e7a32"), Color("9bff5a"), Color("eaffb0")]
	var b: Color = region.ui_color
	return [Color("0a0610"), b.darkened(0.7), b.darkened(0.35), b.lightened(0.15), b.lightened(0.7)]


## Raízes com sombreamento cilíndrico, carimbando discos ao longo de cada caminho
## (rápido mesmo numa tela grande). Índices: 0 contorno, 1 escuro, 2 médio, 3 claro, 4 brilho.
static func _paint_paths(cv: EnvArt.Canvas, paths: Array) -> void:
	var q := PackedFloat32Array()
	q.resize(cv.w * cv.h)
	q.fill(9.0)
	var lit := Vector2(-0.6, -0.8).normalized()
	for path: Array in paths:
		var pts: PackedVector2Array = path[0]
		var rad: PackedFloat32Array = path[1]
		for k in pts.size():
			var p: Vector2 = pts[k]
			var r: float = rad[k]
			for y in range(floori(p.y - r - 1), ceili(p.y + r + 1)):
				for x in range(floori(p.x - r - 1), ceili(p.x + r + 1)):
					if x < 0 or y < 0 or x >= cv.w or y >= cv.h:
						continue
					var off := Vector2(x + 0.5, y + 0.5) - p
					var d: float = off.length() / r
					if d > 1.0 or d >= q[y * cv.w + x]:
						continue
					q[y * cv.w + x] = d
					var b: float = (off / maxf(0.001, off.length())).dot(lit)
					var idx: int = 2
					if d > 0.8 and b < 0.2:
						idx = 1
					elif b > 0.25 and d > 0.2 and d < 0.7:
						idx = 4
					elif b > -0.15:
						idx = 3
					elif b < -0.55:
						idx = 1
					cv.setp(x, y, idx)
	cv.outline(0)
