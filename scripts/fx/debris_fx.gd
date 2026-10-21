class_name DebrisFx
extends Node2D
## Sistema de partículas leve em um único nó (struct-of-arrays, pool fixo).
## Desligado (sem _process) quando não há partículas vivas.

var max_particles: int = Balance.MAX_PARTICLES
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _max_life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _grav := PackedFloat32Array()
var _col := PackedColorArray()
var _count: int = 0


func _ready() -> void:
	set_capacity(max_particles)


func set_capacity(n: int) -> void:
	max_particles = n
	_pos.resize(n)
	_vel.resize(n)
	_life.resize(n)
	_max_life.resize(n)
	_size.resize(n)
	_grav.resize(n)
	_col.resize(n)
	_count = mini(_count, n)
	set_process(_count > 0)


func alive_count() -> int:
	return _count


func emit_burst(origin: Vector2, color: Color, count: int, speed: float, life: float,
		size: float, gravity: float, dir: Vector2 = Vector2.ZERO, spread: float = PI) -> void:
	for i in count:
		if _count >= max_particles:
			break
		var base_angle: float = dir.angle() if dir != Vector2.ZERO else randf() * TAU
		var a: float = base_angle + randf_range(-spread, spread)
		var j: int = _count
		_pos[j] = origin + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		_vel[j] = Vector2.from_angle(a) * speed * randf_range(0.4, 1.0)
		_max_life[j] = life * randf_range(0.6, 1.0)
		_life[j] = _max_life[j]
		_size[j] = size * randf_range(0.6, 1.2)
		_grav[j] = gravity
		_col[j] = color.lightened(randf_range(-0.15, 0.15))
		_count += 1
	if _count > 0:
		set_process(true)


# --- Atalhos de jogo -------------------------------------------------------------

func hit(point: Vector2, def: BlockDef, dir: Vector2, crit: bool) -> void:
	emit_burst(point, def.color_base, Balance.HIT_PARTICLES, 140.0, 0.35, 4.0, 600.0, -dir, 1.1)
	emit_burst(point, Color(0.85, 0.8, 0.7, 0.5), 1, 40.0, 0.5, 7.0, -40.0)
	if crit:
		sparks(point, 6)


func break_block(center: Vector2, def: BlockDef) -> void:
	emit_burst(center, def.color_base, Balance.BREAK_PARTICLES, 260.0, 0.6, 6.0, 900.0)
	emit_burst(center, def.color_dark, 4, 160.0, 0.5, 5.0, 900.0)
	if def.art in [BlockDef.Art.ORE, BlockDef.Art.CRYSTAL, BlockDef.Art.ARTIFACT, BlockDef.Art.CHEST]:
		emit_burst(center, def.color_accent, 8, 220.0, 0.7, 4.0, 500.0)
	if def.special != &"":
		emit_burst(center, Color("fff2a8"), 12, 320.0, 0.9, 3.0, 150.0)
	emit_burst(center, Color(0.8, 0.75, 0.65, 0.35), 3, 50.0, 0.8, 12.0, -30.0)


func sparks(point: Vector2, count: int) -> void:
	emit_burst(point, Color("ffd36b"), count, 380.0, 0.25, 3.0, 400.0)


func _process(delta: float) -> void:
	var i: int = 0
	while i < _count:
		_life[i] -= delta
		if _life[i] <= 0.0:
			_count -= 1
			_pos[i] = _pos[_count]
			_vel[i] = _vel[_count]
			_life[i] = _life[_count]
			_max_life[i] = _max_life[_count]
			_size[i] = _size[_count]
			_grav[i] = _grav[_count]
			_col[i] = _col[_count]
			continue
		var v: Vector2 = _vel[i]
		v.y += _grav[i] * delta
		v *= 1.0 - 1.5 * delta
		_vel[i] = v
		_pos[i] += v * delta
		i += 1
	if _count == 0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for i in _count:
		var t: float = _life[i] / _max_life[i]
		var s: float = _size[i] * (0.5 + 0.5 * t)
		var c: Color = _col[i]
		c.a *= minf(1.0, t * 2.0)
		draw_rect(Rect2(_pos[i] - Vector2(s, s) * 0.5, Vector2(s, s)), c)
