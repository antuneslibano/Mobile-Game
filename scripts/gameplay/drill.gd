class_name Drill
extends Node2D
## Lógica da perfuradora: física em grade (sem colisores), escolha do alvo e golpes.
## A posição é o centro do AABB, em pixels do mundo. Avançada por physics_step().

signal block_hit(cell: Vector2i, block_id: int, damage: float, crit: bool, destroyed: bool)
signal block_destroyed(cell: Vector2i, block_id: int)
signal blocked_by_unbreakable(cell: Vector2i)
signal hopped

enum Mode { IDLE, MOVING, AIRBORNE, DRILL_DOWN, DRILL_SIDE }

const EPS: float = 0.01
const CONTACT_PX: float = 3.0
const MAX_SUBSTEP_BLOCKS: float = 0.4
const UNBREAKABLE_FEEDBACK_SEC: float = 0.22

var world: WorldModel
var stats: DrillStats = DrillStats.base()
var velocity: Vector2 = Vector2.ZERO
var grounded: bool = false
var mode: Mode = Mode.IDLE
var drill_dir: Vector2i = Vector2i.DOWN   ## Direção da broca (visual).
var has_target: bool = false
var target_cell: Vector2i = Vector2i.ZERO
var rng := RandomNumberGenerator.new()
var half: Vector2 = Balance.DRILL_SIZE_BLOCKS * Balance.BLOCK_PX * 0.5

var _hit_timer: float = 0.5
var _unbreakable_cd: float = 0.0
var _b: float = float(Balance.BLOCK_PX)


func setup(p_world: WorldModel, spawn_cell: Vector2i, p_seed: int = 0) -> void:
	world = p_world
	rng.seed = p_seed
	velocity = Vector2.ZERO
	position = Vector2((spawn_cell.x + 0.5) * _b, (spawn_cell.y + 1) * _b - half.y - EPS)
	grounded = false
	has_target = false
	mode = Mode.IDLE


# --- Consultas ----------------------------------------------------------------

func feet_row() -> int:
	return floori((position.y + half.y - 1.0) / _b)


func center_col() -> int:
	return floori(position.x / _b)


## Profundidade em metros (0 na superfície).
func depth_m() -> int:
	return maxi(0, int(float(feet_row() + 1) * Balance.METERS_PER_BLOCK))


func get_rect() -> Rect2:
	return Rect2(position - half, half * 2.0)


## Verdadeiro se o AABB intersecta qualquer célula sólida (invariante: deve ser sempre falso).
func is_overlapping_solid() -> bool:
	return _first_overlap(position) != Vector2i(-9999, -9999)


# --- Simulação ------------------------------------------------------------------

func physics_step(delta: float, intent: DrillIntent) -> void:
	if world == null:
		return
	_unbreakable_cd = maxf(0.0, _unbreakable_cd - delta)
	var move: float = clampf(intent.move, -1.0, 1.0)
	var steering: bool = absf(move) > 0.01
	var speed: float = stats.move_speed_blocks * _b

	# Horizontal: segue a intenção ou se auto-alinha à coluna.
	if steering:
		velocity.x = move_toward(velocity.x, move * speed, Balance.DRILL_ACCEL_BLOCKS * _b * delta)
	else:
		var col_center: float = (float(center_col()) + 0.5) * _b
		velocity.x = clampf((col_center - position.x) * Balance.ALIGN_GAIN, -speed, speed)

	# Pulo automático em degraus de 1 bloco.
	if steering and grounded:
		var dir: int = 1 if move > 0.0 else -1
		if _can_hop(dir):
			velocity.y = -sqrt(2.0 * Balance.GRAVITY_BLOCKS * Balance.HOP_HEIGHT_BLOCKS) * _b
			grounded = false
			hopped.emit()

	velocity.y = minf(velocity.y + Balance.GRAVITY_BLOCKS * _b * delta, Balance.MAX_FALL_BLOCKS * _b)

	if _move_axis(Vector2(velocity.x * delta, 0.0)):
		velocity.x = 0.0
	var was_falling: bool = velocity.y > 0.0
	if _move_axis(Vector2(0.0, velocity.y * delta)):
		grounded = was_falling
		velocity.y = 0.0
	else:
		grounded = _probe_ground()
		if grounded and velocity.y > 0.0:
			velocity.y = 0.0

	_update_target(intent, move, steering)
	_update_mining(delta)


func _update_target(intent: DrillIntent, move: float, steering: bool) -> void:
	has_target = false
	if not intent.drill:
		mode = Mode.MOVING if steering else (Mode.IDLE if grounded else Mode.AIRBORNE)
		return
	if steering:
		var dir: int = 1 if move > 0.0 else -1
		drill_dir = Vector2i(dir, 0)
		var side := _side_cell(dir)
		if _touching_side(dir) and world.is_solid(side) and not _can_hop(dir):
			target_cell = side
			has_target = true
			mode = Mode.DRILL_SIDE
		else:
			mode = Mode.MOVING
		return
	drill_dir = Vector2i.DOWN
	if not grounded:
		mode = Mode.AIRBORNE
		return
	var col: int = center_col()
	var aligned: bool = absf(position.x - (float(col) + 0.5) * _b) <= Balance.ALIGN_TOLERANCE_BLOCKS * _b
	var below := Vector2i(col, feet_row() + 1)
	if aligned and world.is_solid(below):
		target_cell = below
		has_target = true
	mode = Mode.DRILL_DOWN


func _update_mining(delta: float) -> void:
	if not has_target:
		_hit_timer = minf(_hit_timer, 0.5)
		return
	_hit_timer += delta * stats.hits_per_second
	while _hit_timer >= 1.0 and has_target:
		_hit_timer -= 1.0
		_do_hit()


func _do_hit() -> void:
	var id: int = world.get_block(target_cell)
	var def: BlockDef = BlockRegistry.get_def(id)
	if not def.solid:
		has_target = false
		return
	if not def.breakable:
		if _unbreakable_cd <= 0.0:
			_unbreakable_cd = UNBREAKABLE_FEEDBACK_SEC
			blocked_by_unbreakable.emit(target_cell)
		return
	var roll: Vector2 = MiningRules.roll_hit(stats, def.hardness, mode == Mode.DRILL_SIDE, rng)
	var res: WorldModel.DamageResult = world.damage_cell(target_cell, roll.x)
	block_hit.emit(target_cell, id, roll.x, roll.y > 0.5, res.destroyed)
	if res.destroyed:
		has_target = false
		block_destroyed.emit(target_cell, id)


# --- Colisão em grade -------------------------------------------------------------

## Move ao longo de um eixo em subpassos; retorna true se colidiu.
func _move_axis(motion: Vector2) -> bool:
	var dist: float = motion.length()
	if dist <= 0.0:
		return false
	var steps: int = maxi(1, ceili(dist / (MAX_SUBSTEP_BLOCKS * _b)))
	var step: Vector2 = motion / float(steps)
	for i in steps:
		position += step
		_clamp_to_world()
		var hit := _first_overlap(position)
		if hit != Vector2i(-9999, -9999):
			_resolve(step, hit)
			return true
	return false


func _resolve(step: Vector2, _hit: Vector2i) -> void:
	# Recuo ao limite da célula mais próxima no sentido do movimento.
	if step.x > 0.0:
		var edge: float = INF
		for c in _overlapping_solids(position):
			edge = minf(edge, c.x * _b)
		position.x = edge - half.x - EPS
	elif step.x < 0.0:
		var edge: float = -INF
		for c in _overlapping_solids(position):
			edge = maxf(edge, (c.x + 1) * _b)
		position.x = edge + half.x + EPS
	elif step.y > 0.0:
		var edge: float = INF
		for c in _overlapping_solids(position):
			edge = minf(edge, c.y * _b)
		position.y = edge - half.y - EPS
	elif step.y < 0.0:
		var edge: float = -INF
		for c in _overlapping_solids(position):
			edge = maxf(edge, (c.y + 1) * _b)
		position.y = edge + half.y + EPS


func _clamp_to_world() -> void:
	position.x = clampf(position.x, _b + half.x + EPS, (Balance.WORLD_WIDTH - 1) * _b - half.x - EPS)


func _cell_range(p: Vector2) -> Rect2i:
	var x0: int = floori((p.x - half.x) / _b)
	var x1: int = floori((p.x + half.x) / _b)
	var y0: int = floori((p.y - half.y) / _b)
	var y1: int = floori((p.y + half.y) / _b)
	return Rect2i(x0, y0, x1 - x0, y1 - y0)


func _overlapping_solids(p: Vector2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := _cell_range(p)
	for y in range(r.position.y, r.end.y + 1):
		for x in range(r.position.x, r.end.x + 1):
			var c := Vector2i(x, y)
			if world.is_solid(c):
				out.append(c)
	return out


func _first_overlap(p: Vector2) -> Vector2i:
	var r := _cell_range(p)
	for y in range(r.position.y, r.end.y + 1):
		for x in range(r.position.x, r.end.x + 1):
			var c := Vector2i(x, y)
			if world.is_solid(c):
				return c
	return Vector2i(-9999, -9999)


func _probe_ground() -> bool:
	return _first_overlap(position + Vector2(0.0, 1.0)) != Vector2i(-9999, -9999)


func _side_cell(dir: int) -> Vector2i:
	var x: float = position.x + (half.x + CONTACT_PX) * dir
	return Vector2i(floori(x / _b), feet_row())


func _touching_side(dir: int) -> bool:
	return _first_overlap(position + Vector2(CONTACT_PX * dir, 0.0)) != Vector2i(-9999, -9999)


func _can_hop(dir: int) -> bool:
	if not _touching_side(dir):
		return false
	var side := _side_cell(dir)
	if not world.is_solid(side):
		return false
	var above_side := side + Vector2i.UP
	var above_self := Vector2i(center_col(), feet_row() - 1)
	return not world.is_solid(above_side) and not world.is_solid(above_self) \
			and not world.is_solid(Vector2i(floori((position.x - half.x) / _b), feet_row() - 1)) \
			and not world.is_solid(Vector2i(floori((position.x + half.x) / _b), feet_row() - 1))
