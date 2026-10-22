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
	if not is_hostile() or attack_cd > 0.0:
		return 0.0
	for p in body_points():
		if p.distance_to(ship) < ship_r + radius * 0.8:
			attack_cd = ATTACK_CD
			retreat = 0.9
			return float(def().dmg)
	return 0.0


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


func _step_mole(delta: float, w: WorldModel, ship: Vector2, speed: float, b: float) -> void:
	var on_floor: bool = _solid(w, pos + Vector2(0, radius + 2.0))
	if not on_floor:
		vel.y = minf(vel.y + Balance.GRAVITY_BLOCKS * b * delta, 10.0 * b)
		var nx: Vector2 = pos + Vector2(0, vel.y * delta)
		if _solid(w, nx + Vector2(0, radius)):
			vel.y = 0.0
		else:
			pos = nx
		return
	vel.y = 0.0
	var s: float = speed
	if pos.distance_to(ship) < FLEE_BLOCKS * b:
		dir = signf(pos.x - ship.x) if absf(pos.x - ship.x) > 1.0 else dir
		s *= 1.8
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = _rng.randf_range(1.5, 4.0)
			if _rng.randf() < 0.35:
				dir = -dir
	var ahead: Vector2 = pos + Vector2(dir * (radius + 3.0), 0)
	var floor_ahead: bool = _solid(w, pos + Vector2(dir * (radius + 4.0), radius + 6.0))
	if _solid(w, ahead) or not floor_ahead:
		dir = -dir
		return
	pos.x += dir * s * delta


func _step_spider(delta: float, w: WorldModel, ship: Vector2, speed: float, b: float, ship_r: float) -> void:
	var d: float = pos.distance_to(ship)
	var goal: Vector2 = home
	if retreat > 0.0:
		retreat -= delta
		goal = pos + (pos - ship).normalized() * b
	elif d < AGGRO_BLOCKS * b and home.distance_to(ship) < LEASH_BLOCKS * b:
		goal = ship
	var to: Vector2 = goal - pos
	if to.length() < 2.0:
		return
	var v: Vector2 = to.normalized() * speed * (1.0 if goal != home else 0.6)
	var full: Vector2 = pos + v * delta
	if not _solid(w, full):
		pos = full
	elif not _solid(w, pos + Vector2(v.x * delta, 0)):
		pos.x += v.x * delta
	elif not _solid(w, pos + Vector2(0, v.y * delta)):
		pos.y += v.y * delta
	if absf(v.x) > 1.0:
		dir = signf(v.x)


func _step_worm(delta: float, w: WorldModel, ship: Vector2, speed: float, b: float) -> void:
	var to_ship: Vector2 = ship - pos
	if to_ship.length() < WORM_CHASE_BLOCKS * b and retreat <= 0.0:
		heading = lerp_angle(heading, to_ship.angle(), clampf(delta * 1.4, 0.0, 1.0))
	else:
		retreat = maxf(0.0, retreat - delta)
		heading += sin(t * 0.7) * delta * 1.2
	var next: Vector2 = pos + Vector2.from_angle(heading) * speed * delta
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
