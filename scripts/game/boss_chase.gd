class_name BossChase
extends Node2D
## Combate do guardião (0.21): perseguição num poço de terra macia (arena).
## - o guardião aparece em cima da nave (núcleo pulsando + tentáculos) e a acompanha;
## - dispara espinhos que vêm atrás da nave (com aviso antes), atravessando a terra;
## - o núcleo bate como um coração (sinal beat): som e onda na tela;
## - sementes no caminho: cada uma quebrada com a broca tira 1/seeds_needed da vida.
## Regras em step()/seed_broken() (testáveis, RNG próprio); desenho em _draw().

signal beat(strength: float)

const SPIKE_SPEED: float = 820.0       ## px/s
const SPIKE_LEN: float = 78.0
const SPIKE_HIT_R: float = 10.0
const APPEAR_SEC: float = 1.8
const CORE_SCREEN_Y: float = 530.0     ## Altura do núcleo a partir do topo da tela (px).
const INTERVALS: Array[float] = [1.7, 1.25, 0.9]
const WARNS: Array[float] = [0.75, 0.62, 0.5]
const TENTACLES: int = 6
const TENTACLE_SEGS: int = 9

var guardian: FinalGuardian
var active: bool = false
var seeds_needed: int = 6
var seeds_broken: int = 0
## Espinhos: {pos, dir, t, warn, from} (t < warn = aviso; depois voando).
var spikes: Array[Dictionary] = []
var appear: float = 0.0
var core: Vector2 = Vector2.ZERO
var invuln: float = 0.0
var dying: float = -1.0
var _t: float = 0.0
var _beat_t: float = 0.0
var _pulse: float = 0.0
var _next: float = 2.4
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 20


static func seeds_for(r: RegionDef) -> int:
	return 5 + r.difficulty


func start(g: FinalGuardian, ship: Vector2, view: Rect2) -> void:
	guardian = g
	active = true
	seeds_needed = seeds_for(g.region)
	seeds_broken = 0
	spikes.clear()
	appear = 0.0
	invuln = 0.0
	dying = -1.0
	_t = 0.0
	_beat_t = 0.6
	_next = 2.6
	_rng.seed = hash(String(g.region.id)) & 0x7FFFFFFF
	core = Vector2(ship.x, view.position.y + CORE_SCREEN_Y)
	visible = true


func stop() -> void:
	active = false
	spikes.clear()
	visible = false


## Avança um passo. view = retângulo visível do mundo. Retorna o dano no casco (0 ou o
## dano de um acerto).
func step(delta: float, ship: Vector2, ship_vel: Vector2, ship_r: float, view: Rect2) -> float:
	if not active:
		return 0.0
	_t += delta
	_pulse = maxf(0.0, _pulse - delta * 3.0)
	if dying >= 0.0:
		dying += delta
		if dying > 1.6:
			stop()
		return 0.0
	appear = minf(1.0, appear + delta / APPEAR_SEC)
	# O núcleo acompanha a nave por cima, com atraso.
	var goal := Vector2(ship.x, view.position.y + CORE_SCREEN_Y)
	core.x = lerpf(core.x, goal.x, clampf(delta * 1.6, 0.0, 1.0))
	core.y = goal.y - (1.0 - _ease(appear)) * 520.0
	# Batimento: mais rápido conforme a vida cai.
	_beat_t -= delta
	if _beat_t <= 0.0:
		_beat_t = lerpf(1.25, 0.65, 1.0 - guardian.hp_ratio())
		_pulse = 1.0
		beat.emit(0.6 + 0.4 * (1.0 - guardian.hp_ratio()))
	invuln = maxf(0.0, invuln - delta)
	# Espinhos.
	var keep: Array[Dictionary] = []
	var dmg: float = 0.0
	for sp in spikes:
		sp.t += delta
		if sp.t >= sp.warn:
			sp.pos += sp.dir * SPIKE_SPEED * delta
			if invuln <= 0.0 and dmg == 0.0 and _spike_hits(sp, ship, ship_r):
				dmg = guardian.hit_damage
				invuln = Balance.GUARDIAN_INVULN_SEC
		if sp.pos.y < view.end.y + 300.0 and sp.pos.y > view.position.y - 400.0 and sp.t < 6.0:
			keep.append(sp)
	spikes = keep
	if appear >= 1.0:
		_next -= delta
		if _next <= 0.0:
			_attack(ship, ship_vel, view)
			_next = INTERVALS[guardian.phase()]
	return dmg


## Algum espinho avisando ou voando (o HUD pisca).
func danger() -> bool:
	return not spikes.is_empty()


## Semente quebrada pela broca. Retorna true se o guardião foi vencido agora.
func seed_broken() -> bool:
	if not active or dying >= 0.0:
		return false
	seeds_broken += 1
	_pulse = 1.0
	var dead: bool = guardian.take_damage(guardian.max_hp / seeds_needed + 0.01)
	if dead:
		dying = 0.0
		spikes.clear()
	return dead


func _spike_hits(sp: Dictionary, ship: Vector2, ship_r: float) -> bool:
	var tip: Vector2 = sp.pos
	var tail: Vector2 = tip - sp.dir * SPIKE_LEN
	return Geometry2D.get_closest_point_to_segment(ship, tail, tip).distance_to(ship) < ship_r + SPIKE_HIT_R


func _attack(ship: Vector2, ship_vel: Vector2, view: Rect2) -> void:
	var ph: int = guardian.phase()
	var warn: float = WARNS[ph]
	var aim: Vector2 = ship + ship_vel * (warn * 0.6)
	var roll: float = _rng.randf()
	if ph >= 2 and roll < 0.35:
		# Chuva: espinhos caindo em colunas, com uma brecha perto da nave.
		var gap: int = _rng.randi_range(-1, 1)
		for i in range(-3, 4):
			if i == gap or i == gap + 1:
				continue
			var x: float = ship.x + i * Balance.BLOCK_PX * 1.6
			_add_spike(Vector2(x, view.position.y + 120.0), Vector2.DOWN, warn + 0.15)
	elif ph >= 1 and roll < 0.6:
		# Leque de três.
		var base: Vector2 = (aim - core).normalized()
		for a in [-0.28, 0.0, 0.28]:
			_add_spike(core, base.rotated(a), warn)
	else:
		_add_spike(core, (aim - core).normalized(), warn)


func _add_spike(from: Vector2, dir: Vector2, warn: float) -> void:
	spikes.append({"pos": from, "dir": dir.normalized(), "t": 0.0, "warn": warn, "from": from})


static func _ease(k: float) -> float:
	return 1.0 - pow(1.0 - k, 3.0)


func _process(_delta: float) -> void:
	if active:
		queue_redraw()


# --- Desenho -----------------------------------------------------------------------------

func _draw() -> void:
	if not active or guardian == null:
		return
	var glow: Color = guardian.glow_color
	var a: float = _ease(appear)
	var dk: float = clampf(dying / 1.2, 0.0, 1.0) if dying >= 0.0 else 0.0
	# Avisos e espinhos.
	for sp in spikes:
		var from: Vector2 = sp.from
		if sp.t < sp.warn:
			var k: float = sp.t / sp.warn
			var blink: float = 0.5 + 0.5 * sin(sp.t * (16.0 + k * 24.0))
			var end: Vector2 = from + sp.dir * 1600.0
			draw_line(from, end, Color(1.0, 0.2, 0.15, 0.12 + 0.3 * k * blink), 6.0 + 10.0 * k)
			draw_line(from, end, Color(1.0, 0.85, 0.7, 0.25 * k * blink), 2.0)
		else:
			_draw_spike(sp.pos, sp.dir, glow)
	# Tentáculos.
	var len_k: float = a * (1.0 - dk)
	for i in TENTACLES:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var spread: float = (float(i / 2) + 1.0) / (TENTACLES / 2.0 + 0.5)
		var ang: float = PI * 0.5 - side * (0.35 + spread * 0.95)
		var p: Vector2 = core
		var pts := PackedVector2Array([p])
		for s in TENTACLE_SEGS:
			var wave: float = sin(_t * 2.4 + i * 1.3 + s * 0.6) * 0.32
			ang += wave * 0.25 + side * 0.04
			p += Vector2.from_angle(ang) * 22.0 * len_k
			pts.append(p)
		for s in pts.size() - 1:
			var w: float = lerpf(20.0, 5.0, float(s) / TENTACLE_SEGS)
			draw_line(pts[s], pts[s + 1], Color(0.05, 0.02, 0.03), w + 6.0)
		for s in pts.size() - 1:
			var w: float = lerpf(20.0, 5.0, float(s) / TENTACLE_SEGS)
			var c: Color = glow.darkened(0.55).lerp(glow, float(s) / TENTACLE_SEGS * 0.6)
			draw_line(pts[s], pts[s + 1], c, w)
		draw_circle(pts[pts.size() - 1], 5.0, Color(glow.r, glow.g, glow.b, 0.8 * len_k))
	# Núcleo: brilho, olho grande e anel do batimento.
	var beat_s: float = 1.0 + 0.12 * _pulse
	for k in 3:
		draw_circle(core, (70.0 + k * 34.0) * beat_s, Color(glow.r, glow.g, glow.b, (0.10 + 0.12 * _pulse) * (1.0 - k * 0.3) * a))
	if _pulse > 0.0:
		draw_arc(core, 90.0 + (1.0 - _pulse) * 260.0, 0.0, TAU, 48, Color(glow.r, glow.g, glow.b, 0.45 * _pulse), 6.0)
	var tex: Texture2D = guardian.eye_texture()
	if tex != null:
		var es: Vector2 = Vector2(tex.get_size()) * FinalGuardian.ART * 2.2 * beat_s * (1.0 + dk * 0.6)
		var mod := Color(1, 1, 1, a * (1.0 - dk)).lerp(Color(1.8, 1.6, 1.4, a * (1.0 - dk)), guardian.flash_amount())
		draw_texture_rect(tex, Rect2(core - es * 0.5, es), false, mod)
	if dk > 0.0:
		draw_arc(core, 60.0 + dk * 700.0, 0.0, TAU, 64, Color(glow.r, glow.g, glow.b, 1.0 - dk), 14.0 * (1.0 - dk) + 2.0)


func _draw_spike(tip: Vector2, dir: Vector2, glow: Color) -> void:
	var n: Vector2 = dir.orthogonal()
	var tail: Vector2 = tip - dir * SPIKE_LEN
	var pts := PackedVector2Array([tip, tail + n * 11.0, tail - n * 11.0])
	draw_line(tail - dir * 40.0, tail, Color(glow.r, glow.g, glow.b, 0.25), 8.0)
	draw_colored_polygon(pts, Color(0.08, 0.03, 0.04))
	var inner := PackedVector2Array([tip - dir * 6.0, tail + n * 6.0 + dir * 6.0, tail - n * 6.0 + dir * 6.0])
	draw_colored_polygon(inner, glow.lerp(Color.WHITE, 0.25))
