class_name FinalGuardian
extends Node2D
## Guardião da câmara final (marco e chefe de cada região), em modo de combate:
## - o corpo cobre todo o piso da câmara (rocha-mãe no mundo, topo plano); a nave anda por
##   cima dele e o desgasta enquanto se move (dano/s da broca);
## - raízes (Vale, Pântano) ou espinhos de cristal (demais regiões) sobem de baixo, com um
##   aviso brilhando no ponto onde vão sair, sobem, ficam e descem; acertar a nave fere
##   bastante o casco (depois, um instante de invulnerabilidade);
## - três fases conforme a vida cai: ataques mais frequentes, duplos e em onda (com uma
##   brecha para escapar).
## Regras em step()/take_damage()/on_body() (puras e testáveis, com RNG próprio); o desenho
## é pixel art de 3 px montado uma vez em texturas.

signal defeated

const ART: float = 3.0
const SPIKE: int = 0
const SLAM: int = 1
const RISE: float = 0.12
const HOLD: float = 0.45
const FALL: float = 0.3

var region: RegionDef
## Centro do topo do corpo (px) e limites: topo, fundo e faixa caminhável da arena.
var center: Vector2 = Vector2.ZERO
var body_top: float = 0.0
var floor_y: float = 0.0
var x0: float = 0.0
var x1: float = 0.0
var max_hp: float = 1.0
var hp: float = 1.0
var alive: bool = false
var hit_damage: float = 0.0
## Ataques em andamento: {x, w, h, t, warn, kind}. t < warn = aviso; depois sobe/fica/desce.
var attacks: Array[Dictionary] = []
var invuln: float = 0.0
var glow_color: Color = Color.WHITE

var _next: float = 1.4
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0
var _flash: float = 0.0
var _dead_t: float = -1.0
var _body_tex: Texture2D
var _body_rect: Rect2
var _eye_tex: Texture2D
var _spike_tex: Texture2D
var _deco_tex: Texture2D
var _deco_origin: Vector2 = Vector2.ZERO
var _cracks: Array[PackedVector2Array] = []


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(r: RegionDef, is_alive: bool) -> void:
	region = r
	var b: float = Balance.BLOCK_PX
	center = RegionRegistry.guardian_center(r)
	body_top = center.y
	floor_y = r.target_depth_m * b
	x0 = center.x - Balance.GUARDIAN_ARENA_HALF_BLOCKS * b
	x1 = center.x + Balance.GUARDIAN_ARENA_HALF_BLOCKS * b
	max_hp = RegionRegistry.guardian_hp(r)
	hp = max_hp if is_alive else 0.0
	alive = is_alive
	hit_damage = RegionRegistry.guardian_hit_damage(r)
	attacks.clear()
	invuln = 0.0
	_next = 1.4
	_rng.seed = hash(String(r.id)) & 0x7FFFFFFF
	_flash = 0.0
	_dead_t = -1.0 if is_alive else 99.0
	_build_art()
	queue_redraw()


## Arte do núcleo (usada também na perseguição, 0.21).
func eye_texture() -> Texture2D:
	return _eye_tex


func flash_amount() -> float:
	return _flash


func hp_ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)


## Fase 0, 1 ou 2 (a cada terço de vida perdido os ataques ficam mais intensos).
func phase() -> int:
	var k: float = hp_ratio()
	return 0 if k > 0.66 else (1 if k > 0.33 else 2)


## A nave está dentro da câmara final (modo de combate enquanto o guardião vive).
func in_arena(p: Vector2) -> bool:
	if region == null:
		return false
	var top: float = RegionRegistry.chamber_top(region) * Balance.BLOCK_PX
	return p.y > top and p.y < floor_y + 8.0 and absf(p.x - center.x) < (Balance.FINAL_CHAMBER_HALF_WIDTH + 1) * Balance.BLOCK_PX


## A nave (centro p, raio r) está apoiada no corpo do guardião.
func on_body(p: Vector2, r: float) -> bool:
	return alive and p.x > x0 - r and p.x < x1 + r and p.y + r >= body_top - 6.0 and p.y < body_top


## Algum ataque avisando ou ativo (o HUD pisca).
func danger() -> bool:
	for a in attacks:
		if a.t >= 0.0:
			return true
	return false


## Avança ataques e invulnerabilidade. Novos ataques só com a nave na arena. Retorna o dano
## no casco deste passo (0 ou hit_damage).
func step(delta: float, ship: Vector2, ship_r: float) -> float:
	if not alive:
		return 0.0
	invuln = maxf(0.0, invuln - delta)
	var keep: Array[Dictionary] = []
	for a in attacks:
		a.t += delta
		if a.t < float(a.warn) + RISE + HOLD + FALL:
			keep.append(a)
	attacks = keep
	if not in_arena(ship):
		return 0.0
	_next -= delta
	if _next <= 0.0:
		_spawn_pattern(ship.x)
		_next = Balance.GUARDIAN_INTERVALS[phase()]
	if invuln > 0.0:
		return 0.0
	for a in attacks:
		if _hits(a, ship, ship_r):
			invuln = Balance.GUARDIAN_INVULN_SEC
			return hit_damage
	return 0.0


## Dano da broca. Retorna true quando o guardião acabou de ser vencido.
func take_damage(amount: float) -> bool:
	if not alive or amount <= 0.0:
		return false
	hp = maxf(0.0, hp - amount)
	_flash = 1.0
	if hp > 0.0:
		return false
	alive = false
	attacks.clear()
	_dead_t = 0.0
	defeated.emit()
	return true


## Células do corpo (para abrir o piso quando o guardião é vencido).
func body_cells() -> Rect2i:
	var half: int = (Balance.FINAL_CHAMBER_HALF_WIDTH + 1) * Balance.CELL_SUB
	var cx: int = floori(center.x / Balance.CELL_PX)
	var c0: int = maxi(Balance.WALL_CELLS, cx - half)
	var c1: int = mini(Balance.WORLD_CELLS_X - Balance.WALL_CELLS - 1, cx + half)
	var y0: int = roundi(body_top / Balance.CELL_PX)
	var y1: int = roundi(floor_y / Balance.CELL_PX)
	return Rect2i(c0, y0, c1 - c0 + 1, y1 - y0)


## Quanto um ataque está para fora (0..1).
static func extension(a: Dictionary) -> float:
	var t: float = float(a.t) - float(a.warn)
	if t < 0.0:
		return 0.0
	if t < RISE:
		return t / RISE
	if t < RISE + HOLD:
		return 1.0
	return clampf(1.0 - (t - RISE - HOLD) / FALL, 0.0, 1.0)


func attack_rect(a: Dictionary) -> Rect2:
	var e: float = extension(a)
	return Rect2(float(a.x) - float(a.w) * 0.5, body_top - float(a.h) * e, float(a.w), float(a.h) * e)


func _hits(a: Dictionary, p: Vector2, r: float) -> bool:
	if extension(a) < 0.5:
		return false
	var rect: Rect2 = attack_rect(a)
	var q := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
	return q.distance_to(p) < r * 0.8


## Direção lateral segura para quem está na arena (bot de teste e simulação): sai das zonas
## avisadas/ativas pela borda mais próxima; fora delas segue em `dir`, virando antes de
## entrar numa zona ou na parede.
func safe_dir(x: float, dir: float, r: float) -> float:
	var zones: Array[Vector2] = []
	for a in attacks:
		if a.t >= 0.0:
			var m: float = float(a.w) * 0.5 + r + 10.0
			zones.append(Vector2(float(a.x) - m, float(a.x) + m))
	var lo: float = x0 + r
	var hi: float = x1 - r
	for z in zones:
		if x > z.x and x < z.y:
			var best: float = 0.0
			var best_d: float = INF
			for cand: float in [z.x - 2.0, z.y + 2.0]:
				if cand < lo or cand > hi or _in_zones(cand, zones):
					continue
				if absf(cand - x) < best_d:
					best_d = absf(cand - x)
					best = signf(cand - x)
			return best if best != 0.0 else (1.0 if x < center.x else -1.0)
	var ahead: float = x + dir * Balance.BLOCK_PX * 1.2
	if ahead < lo or ahead > hi or _in_zones(ahead, zones):
		return -dir
	return dir


static func _in_zones(x: float, zones: Array[Vector2]) -> bool:
	for z in zones:
		if x > z.x and x < z.y:
			return true
	return false


func _spawn_pattern(ship_x: float) -> void:
	var b: float = Balance.BLOCK_PX
	var ph: int = phase()
	var warn: float = Balance.GUARDIAN_WARNS[ph]
	var roll: float = _rng.randf()
	if ph >= 1 and roll < (0.22 if ph == 1 else 0.38):
		_wave(warn + 0.3)
	elif roll < 0.72:
		_add(SPIKE, ship_x + _rng.randf_range(-0.3, 0.3) * b, 1.3 * b, 4.0 * b, warn)
		if ph >= 1:
			var side: float = 1.0 if _rng.randf() < 0.5 else -1.0
			_add(SPIKE, ship_x + side * _rng.randf_range(2.2, 3.2) * b, 1.3 * b, 4.0 * b, warn + 0.15)
			if ph == 2 and _rng.randf() < 0.5:
				_add(SPIKE, ship_x - side * _rng.randf_range(2.2, 3.2) * b, 1.3 * b, 4.0 * b, warn + 0.3)
	else:
		_add(SLAM, ship_x + _rng.randf_range(-0.8, 0.8) * b, 3.2 * b, 3.2 * b, warn + 0.15)


## Onda de espinhos de um lado ao outro, com uma brecha de dois espinhos.
func _wave(warn: float) -> void:
	var n: int = 10
	var step_x: float = (x1 - x0) / n
	var gap: int = _rng.randi_range(1, n - 3)
	var from_left: bool = _rng.randf() < 0.5
	for i in n:
		if i == gap or i == gap + 1:
			continue
		var k: int = i if from_left else n - 1 - i
		_add(SPIKE, x0 + (k + 0.5) * step_x, 1.3 * Balance.BLOCK_PX, 3.6 * Balance.BLOCK_PX, warn + i * 0.12)


func _add(kind: int, x: float, w: float, h: float, warn: float) -> void:
	x = clampf(x, x0 + w * 0.5, x1 - w * 0.5)
	attacks.append({"x": x, "w": w, "h": h, "t": 0.0, "warn": warn, "kind": kind})


# --- Desenho --------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 6.0)
	if _dead_t >= 0.0 and _dead_t < 99.0:
		_dead_t += delta
	queue_redraw()


func _draw() -> void:
	if region == null:
		return
	var dead: bool = not alive
	# Fundo: escurecido para não se confundir com os ataques.
	var deco_mod := Color(0.55, 0.5, 0.5) if not dead else Color(0.35, 0.32, 0.32)
	draw_texture_rect(_deco_tex, Rect2(_deco_origin, Vector2(_deco_tex.get_size()) * ART), false, deco_mod)
	var eye_c := Vector2(center.x, body_top + Balance.BLOCK_PX * 1.15)
	if dead:
		if _dead_t < 1.4:
			var k: float = _dead_t / 1.4
			draw_texture_rect(_body_tex, _body_rect, false, Color(1.6, 1.4, 1.2, 1.0 - k))
			draw_arc(eye_c, 60.0 + k * 500.0, 0.0, TAU, 64, Color(glow_color.r, glow_color.g, glow_color.b, 1.0 - k), 12.0 * (1.0 - k) + 2.0)
		return
	var danger_k: float = 1.0 if danger() else 0.0
	var beat: float = 0.5 + 0.5 * sin(_t * (3.0 + danger_k * 5.0))
	# Brilho do olho atrás do corpo.
	for i in 3:
		draw_circle(eye_c, Balance.BLOCK_PX * (1.3 + i * 0.5), Color(glow_color.r, glow_color.g, glow_color.b, (0.10 + 0.08 * beat) * (1.0 - i * 0.3)))
	var mod := Color(1, 1, 1).lerp(Color(1.8, 1.8, 1.8), _flash * 0.5)
	draw_texture_rect(_body_tex, _body_rect, false, mod)
	var s: float = 1.0 + 0.05 * beat
	var es: Vector2 = Vector2(_eye_tex.get_size()) * ART * s
	draw_texture_rect(_eye_tex, Rect2(eye_c - es * 0.5, es), false, mod.lerp(Color(1.5, 1.2, 1.0), danger_k * 0.4))
	var n: int = mini(_cracks.size(), int((1.0 - hp_ratio()) * (_cracks.size() + 1)))
	for i in n:
		var pts: PackedVector2Array = _cracks[i]
		for k in pts.size() - 1:
			draw_line(eye_c + pts[k] * s, eye_c + pts[k + 1] * s, Color(0.08, 0.02, 0.02, 0.95), ART)
			draw_line(eye_c + pts[k] * s + Vector2(ART, 0), eye_c + pts[k + 1] * s + Vector2(ART, 0), Color(glow_color.r, glow_color.g, glow_color.b, 0.8), ART * 0.7)
	for a in attacks:
		_draw_attack(a)


func _draw_attack(a: Dictionary) -> void:
	var t: float = float(a.t)
	if t < 0.0:
		return
	var x: float = float(a.x)
	var w: float = float(a.w)
	var h: float = float(a.h)
	var warn: float = float(a.warn)
	if t < warn:
		# Aviso: rachadura brilhando no topo do corpo, coluna de perigo e terra pulando.
		var k: float = t / warn
		var blink: float = 0.5 + 0.5 * sin(t * (14.0 + k * 20.0))
		draw_rect(Rect2(x - w * 0.5, body_top - h, w, h), Color(1.0, 0.15, 0.1, 0.10 + 0.22 * k))
		draw_rect(Rect2(x - w * 0.5, body_top - ART * 3.0, w, ART * 4.0), Color(1.0, 0.3, 0.15, 0.5 + 0.5 * blink * k))
		draw_rect(Rect2(x - w * 0.3, body_top - ART * 2.0, w * 0.6, ART * 2.0), Color(1, 1, 0.85, 0.3 + 0.6 * blink * k))
		# Setas subindo: indicam de onde a raiz vai sair.
		for j in 3:
			var cy: float = body_top - ART * 6.0 - fposmod(t * 90.0 + j * 30.0, 90.0)
			var alpha: float = (0.35 + 0.5 * k) * (1.0 - fposmod(t * 90.0 + j * 30.0, 90.0) / 90.0)
			draw_colored_polygon(PackedVector2Array([Vector2(x - ART * 3.0, cy + ART * 3.0), Vector2(x, cy), Vector2(x + ART * 3.0, cy + ART * 3.0)]), Color(1.0, 0.4, 0.2, alpha))
		for j in 4:
			var px: float = x + (EnvArt.hash01(j, int(x), 3) - 0.5) * w
			var py: float = body_top - absf(sin(t * 18.0 + j * 1.7)) * 14.0 * k - ART
			draw_rect(Rect2(Vector2(px, py).snapped(Vector2(ART, ART)), Vector2(ART, ART)), Color(0.35, 0.2, 0.12, k))
		return
	var e: float = extension(a)
	if e <= 0.0:
		return
	var tex_size: Vector2 = _spike_tex.get_size()
	draw_rect(Rect2(x - w * 0.7, body_top - h * e, w * 1.4, h * e), Color(1.0, 0.2, 0.1, 0.18 * e))
	if int(a.kind) == SLAM:
		for j in 3:
			var off: float = (j - 1) * w * 0.32
			var hh: float = h * (1.0 if j == 1 else 0.75) * e
			var ww: float = w * 0.45
			draw_texture_rect_region(_spike_tex, Rect2(x + off - ww * 0.5, body_top - hh, ww, hh), Rect2(0, 0, tex_size.x, tex_size.y * hh / (h * (1.0 if j == 1 else 0.75))))
	else:
		var hh: float = h * e
		draw_texture_rect_region(_spike_tex, Rect2(x - w * 0.5, body_top - hh, w, hh), Rect2(0, 0, tex_size.x, tex_size.y * e))
	# Poeira na base.
	draw_rect(Rect2(x - w * 0.6, body_top - ART * 2.0, w * 1.2, ART * 2.0), Color(0.3, 0.18, 0.1, 0.6 * e))


# --- Arte ------------------------------------------------------------------------------

func _roots_theme() -> bool:
	return region.theme in [&"savanna", &"swamp"]


func _build_art() -> void:
	var s: int = hash(String(region.id)) & 0xFFFF
	var b: float = Balance.BLOCK_PX
	var core: Array[Color] = _core_palette()
	glow_color = core[3]
	_build_body(s, core)
	# Olho/núcleo embutido no meio do corpo.
	var hr: float = b * 1.0 / ART
	var hn: int = int(ceil(hr * 2.0)) + 4
	var cv := EnvArt.Canvas.new(hn, hn, core)
	var c := Vector2(hn * 0.5, hn * 0.5)
	var lit := Vector2(-0.6, -0.8).normalized()
	cv.disc(c, hr, func(p: Vector2) -> int:
		var d: Vector2 = (p - c) / hr
		var l: float = d.length()
		var bb: float = d.normalized().dot(lit) if l > 0.01 else 0.0
		if l < 0.32:
			return 4 if l < 0.18 else 3
		var vein: float = absf(sin(atan2(d.y, d.x) * 5.0 + l * 7.0 + s))
		if vein < 0.18 and l < 0.9:
			return 3
		if l > 0.8 and bb < 0.0:
			return 1
		return 2 if bb < 0.35 else 3, 1.0)
	cv.outline(0)
	_eye_tex = ImageTexture.create_from_image(cv.image())
	_cracks.clear()
	for i in 6:
		var a: float = TAU * (i / 6.0) + EnvArt.hash01(i, 1, s) * 0.8
		var pts := PackedVector2Array([Vector2.ZERO])
		var p := Vector2.ZERO
		for k in 4:
			a += (EnvArt.hash01(i, k + 3, s) - 0.5) * 1.1
			p += Vector2(cos(a), sin(a)) * b * 0.32
			pts.append(p)
		_cracks.append(pts)
	_build_spike(s, core)
	_build_deco(s)


## Corpo: massa larga cobrindo o piso; topo plano (por onde a nave anda).
func _build_body(s: int, core: Array[Color]) -> void:
	var b: float = Balance.BLOCK_PX
	var half: float = (Balance.FINAL_CHAMBER_HALF_WIDTH + 1) * b
	var bump: int = 5
	var w: int = int(half * 2.0 / ART)
	var h: int = int(Balance.GUARDIAN_BODY_ROWS * b / ART) + bump
	_body_rect = Rect2(Vector2(center.x - half, body_top - bump * ART), Vector2(w, h) * ART)
	var roots: bool = _roots_theme()
	var pal: Array[Color]
	if roots:
		pal = [Color("120604"), Color("3a160c"), Color("6e2a14"), Color("a04a26"), Color("d07a44"), core[3], core[4]]
	else:
		var u: Color = region.ui_color
		pal = [Color("08060c"), u.darkened(0.8), u.darkened(0.6), u.darkened(0.35), u.darkened(0.1), core[3], core[4]]
	var cv := EnvArt.Canvas.new(w, h, pal)
	for y in range(bump, h):
		for x in w:
			var depth: float = float(y - bump) / (h - bump)
			var n: float = 0.5 + 0.25 * sin(x * 0.21 + sin(y * 0.37) * 2.0 + s) + 0.25 * sin(x * 0.053 - y * 0.29 + s * 0.3)
			var idx: int = 3 if y - bump < 2 else (2 if n > 0.45 + depth * 0.3 else 1)
			var vein: float = absf(sin(x * 0.11 + sin(y * 0.45 + x * 0.02) * 2.4 + s))
			if vein < 0.07 and y - bump > 2:
				idx = 5 if EnvArt.hash01(x / 6, y / 6, s) < 0.7 else 6
			cv.setp(x, y, idx)
	if roots:
		# Raízes grossas entrelaçadas ao longo do corpo (algumas saltam um pouco do topo).
		var paths: Array = []
		for i in 5:
			var y0: float = bump + 3.0 + EnvArt.hash01(i, 21, s) * (h - bump - 8)
			paths.append(EnvArt.root_path(Vector2(-4.0, y0), 0.0 + (EnvArt.hash01(i, 22, s) - 0.5) * 0.2, w + 8, lerpf(7.0, 10.0, EnvArt.hash01(i, 23, s)), s + i * 31, 0.18))
		_paint_paths(cv, paths)
	else:
		for i in 22:
			var x: float = w * (0.03 + 0.94 * EnvArt.hash01(i, 24, s))
			var tall: float = lerpf(3.0, float(bump) + 2.0, EnvArt.hash01(i, 25, s))
			EnvArt.shard(cv, Vector2(x, bump + 2.0), Vector2(x + (EnvArt.hash01(i, 26, s) - 0.5) * 3.0, bump + 2.0 - tall), lerpf(1.5, 3.0, EnvArt.hash01(i, 27, s)), true)
		cv.outline(0)
	_body_tex = ImageTexture.create_from_image(cv.image())


## Ataque: raiz-tentáculo afinando para cima ou espinho de cristal (4 blocos de altura).
func _build_spike(s: int, core: Array[Color]) -> void:
	var w: int = 22
	var h: int = int(4.0 * Balance.BLOCK_PX / ART)
	var cv: EnvArt.Canvas
	if _roots_theme():
		# Tentáculo vermelho-vivo (diferente das raízes do cenário), com espinhos.
		var pal: Array[Color] = [Color("1a0406"), Color("5a0e14"), Color("9a1e22"), Color("dc4a2e"), Color("ffb070")]
		cv = EnvArt.Canvas.new(w, h, pal)
		_paint_paths(cv, [EnvArt.root_path(Vector2(w * 0.5, h + 1.0), -PI * 0.5, h + 1, 21.0, s + 5, 0.12)])
		# Espinhos laterais.
		for i in 6:
			var y: float = h * (0.25 + 0.12 * i)
			var side: float = -1.0 if i % 2 == 0 else 1.0
			EnvArt.shard(cv, Vector2(w * 0.5 + side * 3.0, y), Vector2(w * 0.5 + side * 9.0, y - 4.0), 1.2)
		cv.outline(0)
	else:
		var u: Color = region.ui_color
		var pal: Array[Color] = [Color("0b0710"), u.darkened(0.65), u.darkened(0.3), u, u.lightened(0.55)]
		cv = EnvArt.Canvas.new(w, h, pal)
		EnvArt.shard(cv, Vector2(w * 0.5, h + 0.0), Vector2(w * 0.5, 1.0), 9.0, true, 0.82)
		cv.outline(0)
	_spike_tex = ImageTexture.create_from_image(cv.image())


## Raízes/cristais nas paredes da câmara (marco visível ao chegar).
func _build_deco(s: int) -> void:
	var w: int = int((Balance.FINAL_CHAMBER_HALF_WIDTH * 2 + 3) * Balance.BLOCK_PX / ART)
	var h: int = int((Balance.FINAL_CHAMBER_ROWS + 1) * Balance.BLOCK_PX / ART)
	_deco_origin = Vector2(center.x - w * ART * 0.5, body_top - h * ART + 4.0 * ART)
	var hc := (Vector2(center.x, body_top) - _deco_origin) / ART
	var dcv: EnvArt.Canvas
	if _roots_theme():
		dcv = EnvArt.Canvas.new(w, h, EnvArt.ramp(EnvArt.ROOT_RAMP))
		var paths: Array = []
		var n: int = 8
		for i in n:
			var t: float = float(i) / (n - 1)
			# Das bordas do corpo subindo pelas paredes até o teto.
			var x: float = lerpf(hc.x - w * 0.46, hc.x + w * 0.46, t)
			var ang: float = -PI * 0.5 + (t - 0.5) * 1.1 + (EnvArt.hash01(i, 2, s) - 0.5) * 0.3
			var length: int = int(lerpf(70.0, 140.0, EnvArt.hash01(i, 3, s)) * (1.2 - absf(t - 0.5)))
			paths.append_array(EnvArt.root_tree(Vector2(x, hc.y + 2.0), ang, length, lerpf(10.0, 16.0, absf(t - 0.5) * 2.0), s + i * 13, 1, 0.3))
		_paint_paths(dcv, paths)
	else:
		var base: Color = region.ui_color
		var pal: Array[Color] = [Color("0b0710"), base.darkened(0.65), base.darkened(0.3), base, base.lightened(0.55)]
		dcv = EnvArt.Canvas.new(w, h, pal)
		for i in 10:
			var x: float = w * (0.05 + 0.9 * EnvArt.hash01(i, 8, s))
			var tall: float = lerpf(10.0, 26.0, EnvArt.hash01(i, 9, s))
			EnvArt.shard(dcv, Vector2(x, 0.0), Vector2(x + (EnvArt.hash01(i, 10, s) - 0.5) * 8.0, tall), lerpf(2.5, 4.5, EnvArt.hash01(i, 11, s)), true)
		for side: float in [-1.0, 1.0]:
			for i in 4:
				var x: float = hc.x + side * (w * 0.47 - i * 6.0)
				var tall: float = lerpf(18.0, 40.0, EnvArt.hash01(i, 12 + int(side), s))
				EnvArt.shard(dcv, Vector2(x, hc.y + 2.0), Vector2(x - side * tall * 0.3, hc.y - tall), lerpf(3.0, 5.5, EnvArt.hash01(i, 14, s)), true)
		dcv.outline(0)
	_deco_tex = ImageTexture.create_from_image(dcv.image())


## Paleta do núcleo (0 contorno, 1 sombra, 2 corpo, 3 brilho, 4 núcleo).
func _core_palette() -> Array[Color]:
	match region.theme:
		&"savanna":
			return [Color("140806"), Color("5a1a12"), Color("a8341c"), Color("ff7a2e"), Color("ffe08a")]
		&"swamp":
			return [Color("061008"), Color("1e3a1e"), Color("3e7a32"), Color("9bff5a"), Color("eaffb0")]
	var u: Color = region.ui_color
	return [Color("0a0610"), u.darkened(0.7), u.darkened(0.35), u.lightened(0.15), u.lightened(0.7)]


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
					var bb: float = (off / maxf(0.001, off.length())).dot(lit)
					var idx: int = 2
					if d > 0.8 and bb < 0.2:
						idx = 1
					elif bb > 0.25 and d > 0.2 and d < 0.7:
						idx = 4
					elif bb > -0.15:
						idx = 3
					elif bb < -0.55:
						idx = 1
					cv.setp(x, y, idx)
	cv.outline(0)
