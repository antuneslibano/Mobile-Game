class_name Creature
extends RefCounted
## Uma criatura do subsolo (0.11). Regras puras sobre a grade de células (sem nós):
## step() move e decide; quem a possui (CreatureManager) aplica dano na nave e desenha.
## Espécies (DEFS):
##   firefly – vaga-lume: voa pelas cavernas, foge da nave, inofensivo (catálogo);
##   mole    – toupeira de raiz: anda pelo chão das cavernas e foge; amostra biológica;
##   spider  – aranha de raiz: guarda um veio brilhante e ataca quem chega perto;
##   worm    – minhoca escavadora: abre os próprios túneis e persegue a nave; morde.

## nome, vida, raio (px), velocidade (blocos/s), dano por contato, amostras, hostil
const DEFS: Dictionary = {
	&"firefly": {"name": "Vaga-lume", "hp": 4.0, "r": 7.0, "speed": 2.4, "dmg": 0.0, "samples": 0, "hostile": false},
	&"mole": {"name": "Toupeira de raiz", "hp": 30.0, "r": 14.0, "speed": 1.6, "dmg": 0.0, "samples": 1, "hostile": false},
	&"spider": {"name": "Aranha de raiz", "hp": 70.0, "r": 16.0, "speed": 3.0, "dmg": 10.0, "samples": 2, "hostile": true},
	&"worm": {"name": "Minhoca escavadora", "hp": 160.0, "r": 15.0, "speed": 2.0, "dmg": 14.0, "samples": 3, "hostile": true},
}
const ORDER: Array[StringName] = [&"firefly", &"mole", &"spider", &"worm"]
const AGGRO_BLOCKS: float = 5.0       ## Aranha: distância que dispara o ataque.
const LEASH_BLOCKS: float = 9.0       ## Aranha: desiste e volta para o veio.
const WORM_CHASE_BLOCKS: float = 8.0
const FLEE_BLOCKS: float = 4.0
const ATTACK_CD: float = 1.0
const WORM_SEGMENTS: int = 8
const WORM_GAP: float = 11.0
## Combate (0.21): hostis rondam a nave, dão um bote, batem e são jogados para trás.
const ORBIT_BLOCKS: float = 3.0       ## Raio da ronda em volta da nave.
const DASH_MULT: float = 2.2          ## Velocidade do bote (× velocidade normal).
const RECOIL_SEC: float = 0.55        ## Tempo sendo arremessada depois de bater.
const KNOCKBACK_BLOCKS: float = 7.0   ## Velocidade do arremesso (blocos/s).

var species: StringName
var pos: Vector2
var vel: Vector2 = Vector2.ZERO
var home: Vector2
var hp: float
var max_hp: float
var radius: float
var dir: float = 1.0
var alive: bool = true
var attack_cd: float = 0.0
var stun: float = 0.0
var flash: float = 0.0
var t: float = 0.0
var retreat: float = 0.0
var heading: float = 0.0
var segments: PackedVector2Array = PackedVector2Array()
var _wander_t: float = 0.0
var _target: Vector2
var _rng := RandomNumberGenerator.new()
var _carve_t: float = 0.0
## Toupeira: tempo restante escalando uma parede.
var climbing: float = 0.0
## Combate: &"orbit" (rondando), &"dash" (bote), &"recoil" (arremessada).
var mode: StringName = &"orbit"
var mode_t: float = 0.0
var orbit_angle: float = 0.0
var orbit_dir: float = 1.0
## Toupeira: detecção de travada.
var _stuck_t: float = 0.0
var _stuck_from: Vector2 = Vector2.ZERO
var _hop_t: float = 0.0
## Tempo até poder fazer som de novo (CreatureManager).
var sound_cd: float = 0.0


func _init(p_species: StringName, p_pos: Vector2, p_seed: int) -> void:
	species = p_species
	pos = p_pos
	home = p_pos
	_target = p_pos
	var d: Dictionary = DEFS[species]
	hp = float(d.hp)
	max_hp = hp
	radius = float(d.r)
	_rng.seed = p_seed
	dir = 1.0 if _rng.randf() < 0.5 else -1.0
	t = _rng.randf() * 10.0
	heading = _rng.randf() * TAU
	orbit_angle = _rng.randf() * TAU
	orbit_dir = 1.0 if _rng.randf() < 0.5 else -1.0
	mode_t = _rng.randf_range(1.0, 2.2)
	_hop_t = _rng.randf_range(1.5, 3.5)
	if species == &"worm":
		for i in WORM_SEGMENTS:
			segments.append(pos - Vector2.from_angle(heading) * WORM_GAP * i)


func def() -> Dictionary:
	return DEFS[species]


func is_hostile() -> bool:
	return bool(def().hostile)


## Pontos que podem tocar a nave (minhoca: corpo inteiro).
func body_points() -> PackedVector2Array:
	return segments if species == &"worm" else PackedVector2Array([pos])


## Dano recebido. Retorna true se morreu agora.
func take_damage(amount: float) -> bool:
	if not alive or amount <= 0.0:
		return false
	hp -= amount
	flash = 1.0
	if hp > 0.0:
		return false
	alive = false
	return true


func _solid(w: WorldModel, p: Vector2) -> bool:
	return BlockRegistry.is_solid(w.peek_cell(WorldModel.world_to_cell(p)))


## Avança um passo. Retorna o dano de contato na nave neste passo (0 se nenhum).
func step(delta: float, w: WorldModel, ship: Vector2, ship_r: float) -> float:
	t += delta
	flash = maxf(0.0, flash - delta * 5.0)
	attack_cd = maxf(0.0, attack_cd - delta)
	if stun > 0.0:
		stun -= delta
		return 0.0
	var b: float = Balance.BLOCK_PX
	var speed: float = float(def().speed) * b
	match species:
		&"firefly":
			_step_firefly(delta, w, ship, speed, b)
		&"mole":
			_step_mole(delta, w, ship, speed, b)
		&"spider":
			_step_spider(delta, w, ship, speed, b, ship_r)
		&"worm":
			_step_worm(delta, w, ship, speed, b)
	# Corpo sólido (0.21): ninguém atravessa a nave. Hostil em bote que encosta bate e é
	# arremessado para trás.
	var bite: float = 0.0
	for i in body_points().size():
		var p: Vector2 = body_points()[i]
		var min_d: float = ship_r + radius * 0.9
		var d: float = p.distance_to(ship)
		if d >= min_d:
			continue
		var away: Vector2 = (p - ship).normalized() if d > 0.5 else Vector2.UP
		if is_hostile() and attack_cd <= 0.0 and mode == &"dash":
			attack_cd = ATTACK_CD
			bite = float(def().dmg)
			knock(away)
		_push_out(i, ship + away * min_d)
	return bite


## Arremessa a criatura na direção dada (bateu na nave ou levou um golpe da broca).
func knock(away: Vector2, strength: float = 1.0) -> void:
	mode = &"recoil"
	mode_t = RECOIL_SEC * strength
	vel = away.normalized() * KNOCKBACK_BLOCKS * Balance.BLOCK_PX * strength
	if species == &"worm":
		heading = away.angle()


func _push_out(i: int, to: Vector2) -> void:
	if species == &"worm":
		segments[i] = to
		if i == 0:
			pos = to
	else:
		pos = to


## Ronda/bote/arremesso comum aos hostis. Retorna a velocidade desejada (px/s).
func _combat_vel(delta: float, ship: Vector2, speed: float, b: float) -> Vector2:
	mode_t -= delta
	match mode:
		&"recoil":
			vel = vel.move_toward(Vector2.ZERO, KNOCKBACK_BLOCKS * b * 2.0 * delta)
			if mode_t <= 0.0:
				mode = &"orbit"
				mode_t = _rng.randf_range(1.0, 2.4)
				if _rng.randf() < 0.35:
					orbit_dir = -orbit_dir
			return vel
		&"dash":
			if mode_t <= 0.0:
				mode = &"orbit"
				mode_t = _rng.randf_range(1.0, 2.4)
			return (ship - pos).normalized() * speed * DASH_MULT
		_:
			orbit_angle += orbit_dir * speed / (ORBIT_BLOCKS * b) * delta
			var wobble: float = 1.0 + 0.18 * sin(t * 2.3)
			var goal: Vector2 = ship + Vector2.from_angle(orbit_angle) * ORBIT_BLOCKS * b * wobble
			if mode_t <= 0.0:
				mode = &"dash"
				mode_t = 1.1
			return (goal - pos).limit_length(speed * 1.2) * 3.0 if pos.distance_to(goal) < b else (goal - pos).normalized() * speed


func _step_firefly(delta: float, w: WorldModel, ship: Vector2, speed: float, b: float) -> void:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = _rng.randf_range(1.2, 2.6)
		_target = home + Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-2.0, 2.0)) * b
	var want: Vector2 = (_target - pos).limit_length(speed * 0.6)
	if pos.distance_to(ship) < FLEE_BLOCKS * b:
		want = (pos - ship).normalized() * speed
	want.y += sin(t * 4.0) * 20.0
	vel = vel.lerp(want, clampf(delta * 3.0, 0.0, 1.0))
	var next: Vector2 = pos + vel * delta
	if _solid(w, next):
		vel = -vel.rotated(_rng.randf_range(-0.6, 0.6))
		_target = home
	else:
		pos = next
	if vel.x != 0.0:
		dir = signf(vel.x)


## Toupeira: anda pelo chão; pula degraus de até ~2 blocos, escala paredes (até 3 blocos)
## e desce de bordas baixas; foge da nave.
func _step_mole(delta: float, w: WorldModel, ship: Vector2, speed: float, b: float) -> void:
	var s: float = speed
	if pos.distance_to(ship) < FLEE_BLOCKS * b:
		if absf(pos.x - ship.x) > 1.0:
			dir = signf(pos.x - ship.x)
		s *= 1.8
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = _rng.randf_range(2.0, 5.0)
			if _rng.randf() < 0.3:
				dir = -dir
	if mode == &"recoil":
		# Golpe da broca: foge para o lado oposto, aos pulos.
		mode_t -= delta
		if absf(vel.x) > 1.0:
			dir = signf(vel.x)
		if mode_t <= 0.0:
			mode = &"orbit"
		s *= 1.8
	var feet := Vector2(0, radius * 0.6 + 2.0)
	var on_floor: bool = _solid(w, pos + feet)
	# Travada (0.21): se quase não saiu do lugar, pula e muda de lado.
	_stuck_t += delta
	if _stuck_t >= 1.2:
		if pos.distance_to(_stuck_from) < b * 0.4 and on_floor and climbing <= 0.0:
			vel.y = -b * 8.0
			dir = -dir if _rng.randf() < 0.5 else dir
		_stuck_t = 0.0
		_stuck_from = pos
	# Pulinhos de vez em quando, mesmo sem obstáculo.
	_hop_t -= delta
	if _hop_t <= 0.0:
		_hop_t = _rng.randf_range(1.6, 3.8)
		if on_floor and climbing <= 0.0 and not _solid(w, pos + Vector2(0, -b * 1.4)):
			vel.y = -b * 6.0
	var wall: bool = _solid(w, pos + Vector2(dir * (radius + 2.0), 0)) or _solid(w, pos + Vector2(dir * (radius + 2.0), radius * 0.4))
	# Escalando: sobe colado na parede enquanto houver parede à frente e teto livre.
	if climbing > 0.0:
		climbing -= delta
		if wall and not _solid(w, pos + Vector2(0, -radius - 3.0)):
			pos.y -= s * 1.1 * delta
			return
		# Chegou ao topo da parede: impulso para cima e para frente (sobe na borda).
		climbing = 0.0
		if not _solid(w, pos + Vector2(0, -radius - 3.0)):
			vel.y = -b * 4.0
		pos.x += dir * radius * 0.8
		return
	if on_floor:
		vel.y = 0.0
		if wall:
			# Degrau baixo: pula; parede alta: escala; teto baixo: volta.
			if not _solid(w, pos + Vector2(dir * (radius + 2.0), -b * 1.1)) and not _solid(w, pos + Vector2(0, -b * 1.2)):
				vel.y = -b * 7.5
			elif not _solid(w, pos + Vector2(0, -radius - 3.0)):
				climbing = 5.0 * b / (s * 1.1)
				return
			else:
				dir = -dir
				return
		elif not _solid(w, pos + Vector2(dir * (radius + 4.0), radius + 6.0)):
			# Borda: desce se a queda for baixa (até ~4 blocos), senão volta.
			var drop_ok: bool = false
			for k in range(1, 7):
				if _solid(w, pos + Vector2(dir * (radius + 6.0), k * b)):
					drop_ok = true
					break
			if not drop_ok:
				dir = -dir
				return
	else:
		vel.y = minf(vel.y + Balance.GRAVITY_BLOCKS * b * delta, 10.0 * b)
	# Vertical (pulo/queda) com colisão.
	var ny: Vector2 = pos + Vector2(0, vel.y * delta)
	if vel.y < 0.0 and _solid(w, ny + Vector2(0, -radius * 0.6)):
		vel.y = 0.0
	elif vel.y > 0.0 and _solid(w, ny + feet):
		vel.y = 0.0
	else:
		pos = ny
	# Horizontal.
	if not _solid(w, pos + Vector2(dir * (radius + 2.0), 0)):
		pos.x += dir * s * delta


func _step_spider(delta: float, w: WorldModel, ship: Vector2, speed: float, b: float, _ship_r: float) -> void:
	var d: float = pos.distance_to(ship)
	var v: Vector2
	if mode == &"recoil" or (d < AGGRO_BLOCKS * b and home.distance_to(ship) < LEASH_BLOCKS * b):
		v = _combat_vel(delta, ship, speed, b)
	else:
		# Longe ou fora da área do veio: volta para casa.
		mode = &"orbit"
		var to: Vector2 = home - pos
		if to.length() < 2.0:
			return
		v = to.normalized() * speed * 0.6
	var full: Vector2 = pos + v * delta
	if not _solid(w, full):
		pos = full
	elif not _solid(w, pos + Vector2(v.x * delta, 0)):
		pos.x += v.x * delta
	elif not _solid(w, pos + Vector2(0, v.y * delta)):
		pos.y += v.y * delta
	elif mode == &"orbit":
		orbit_dir = -orbit_dir  # bateu na rocha rondando: inverte a volta
	if absf(v.x) > 1.0:
		dir = signf(v.x)


func _step_worm(delta: float, w: WorldModel, ship: Vector2, speed: float, b: float) -> void:
	var to_ship: Vector2 = ship - pos
	var spd: float = speed
	if to_ship.length() < WORM_CHASE_BLOCKS * b or mode == &"recoil":
		var want: Vector2 = _combat_vel(delta, ship, speed, b)
		if want.length() > 1.0:
			heading = lerp_angle(heading, want.angle(), clampf(delta * (6.0 if mode == &"recoil" else 2.6), 0.0, 1.0))
			spd = clampf(want.length(), speed * 0.6, speed * DASH_MULT)
	else:
		heading += sin(t * 0.7) * delta * 1.2
	var next: Vector2 = pos + Vector2.from_angle(heading) * spd * delta
	var c: Vector2i = WorldModel.world_to_cell(next)
	var id: int = w.peek_cell(c)
	var top: float = 6.0 * b
	if id == BlockRegistry.BEDROCK or next.y < top or not BlockRegistry.get_def(id).breakable and BlockRegistry.is_solid(id):
		heading += PI * 0.6
		return
	pos = next
	if pos.x != segments[0].x:
		dir = signf(pos.x - segments[0].x)
	segments[0] = pos
	for i in range(1, segments.size()):
		var prev: Vector2 = segments[i - 1]
		var cur: Vector2 = segments[i]
		if cur.distance_to(prev) > WORM_GAP:
			segments[i] = prev + (cur - prev).normalized() * WORM_GAP
	_carve_t -= delta
	if _carve_t <= 0.0:
		_carve_t = 0.08
		w.carve_terrain(pos, radius + 2.0)
