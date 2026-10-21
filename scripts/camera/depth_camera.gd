class_name DepthCamera
extends Camera2D
## Câmera que acompanha a profundidade com suavização exponencial, limites e tremor.

var target: Node2D
var _trauma: float = 0.0


func snap_to_target() -> void:
	if target != null:
		global_position = _desired()
	reset_smoothing()


func add_shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if target == null:
		return
	var k: float = 1.0 - exp(-Balance.CAMERA_FOLLOW_SPEED * delta)
	global_position = global_position.lerp(_desired(), k)
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - Balance.CAMERA_SHAKE_DECAY * delta)
		var s: float = _trauma * _trauma * Balance.CAMERA_SHAKE_MAX_PX
		offset = Vector2(randf_range(-s, s), randf_range(-s, s))
	else:
		offset = Vector2.ZERO


func _desired() -> Vector2:
	var view: Vector2 = get_viewport_rect().size / zoom
	var p: Vector2 = target.global_position + Vector2(0.0, view.y * Balance.CAMERA_LOOK_AHEAD_RATIO)
	var world_w: float = float(Balance.WORLD_WIDTH * Balance.BLOCK_PX)
	if view.x >= world_w:
		p.x = world_w * 0.5
	else:
		p.x = clampf(p.x, view.x * 0.5, world_w - view.x * 0.5)
	p.y = maxf(p.y, -Balance.SKY_ROWS_VISIBLE * Balance.BLOCK_PX + view.y * 0.5)
	return p
