class_name DepthCamera
extends Camera2D
## Câmera que acompanha a profundidade com suavização exponencial, limites e tremor.
##
## Anti-cintilação: a suavização roda em ponto flutuante (_pos), mas a posição desenhada é
## encaixada num passo inteiro tanto em pixels do jogo quanto em pixels do aparelho. Com
## escala de tela fracionária (ex.: 720 → 1080 = 1,5×) cada pixel de arte de 3 px ocupa
## 4 ou 5 pixels reais; se a câmera anda em frações, essa distribuição muda a cada quadro
## e os detalhes "piscam". Andando em passos inteiros, cada pixel mantém sua largura.

var target: Node2D
var _trauma: float = 0.0
var _pos: Vector2 = Vector2.ZERO
var _shake: Vector2 = Vector2.ZERO


func snap_to_target() -> void:
	if target != null:
		_pos = _desired()
		global_position = _pos.snapped(Vector2.ONE * snap_step())
	reset_smoothing()


func add_shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if target == null:
		return
	var k: float = 1.0 - exp(-Balance.CAMERA_FOLLOW_SPEED * delta)
	_pos = _pos.lerp(_desired(), k)
	_shake = Vector2.ZERO
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - Balance.CAMERA_SHAKE_DECAY * delta)
		var s: float = _trauma * _trauma * Balance.CAMERA_SHAKE_MAX_PX
		_shake = Vector2(randf_range(-s, s), randf_range(-s, s))
	offset = Vector2.ZERO
	global_position = (_pos + _shake).snapped(Vector2.ONE * snap_step())


## Menor passo (em px do jogo, inteiro) que também é inteiro em pixels do aparelho.
func snap_step() -> float:
	var sc: float = get_viewport().get_final_transform().x.x * zoom.x if is_inside_tree() else 1.0
	return step_for_scale(sc)


static func step_for_scale(sc: float) -> float:
	for d in range(1, 13):
		var dev: float = d * sc
		if absf(dev - roundf(dev)) < 0.01:
			return float(d)
	return 1.0


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
