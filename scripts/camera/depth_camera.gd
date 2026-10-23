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
## Abertura da expedição: enquadra o céu e a base com a nave na parte de baixo da tela
## (abaixo do HUD). end_intro() devolve a câmera ao acompanhamento normal, devagar.
var intro: bool = false
## Limite inferior (px do mundo) que a câmera pode mostrar: o fundo da região, para a
## câmara final ficar enquadrada em vez de mostrar rocha-mãe. INF = sem limite.
var bottom_limit: float = INF
## Modo de combate (arena do guardião): a câmera se afasta (zoom) e fica fixa na arena,
## com o piso (combat_anchor.y) na parte de baixo da tela.
var combat: bool = false
var combat_anchor: Vector2 = Vector2.ZERO
const COMBAT_ZOOM: float = 0.75
const COMBAT_FLOOR_SCREEN_Y: float = 0.8
## Queda livre (0.20), 0..1: aproxima a câmera, olha mais para baixo e treme de leve.
var fall: float = 0.0
const FALL_ZOOM: float = 0.14
const FALL_LOOK: float = 0.1
var _ease_t: float = 0.0
var _trauma: float = 0.0
var _pos: Vector2 = Vector2.ZERO
var _shake: Vector2 = Vector2.ZERO


func snap_to_target() -> void:
	if is_inside_tree():
		zoom = Vector2.ONE * target_zoom()
	if target != null:
		_pos = _desired()
		global_position = _pos.snapped(Vector2.ONE * snap_step())
	reset_smoothing()


func end_intro() -> void:
	if intro:
		intro = false
		_ease_t = INTRO_EASE_SEC


const INTRO_EASE_SEC: float = 1.4
const INTRO_SURFACE_SCREEN_Y: float = 0.64  ## Altura da superfície na tela durante a abertura.


## Zoom desejado. Em telas mais largas que o mundo (tablets, dobráveis abertos) aproxima
## o suficiente para a largura visível nunca passar das paredes do mapa.
func target_zoom() -> float:
	var z: float = COMBAT_ZOOM if combat else 1.0 + FALL_ZOOM * fall
	var world_w: float = float(Balance.WORLD_WIDTH * Balance.BLOCK_PX)
	return maxf(z, get_viewport_rect().size.x / world_w) if is_inside_tree() else z


func add_shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if target == null:
		return
	var speed: float = Balance.CAMERA_FOLLOW_SPEED
	if _ease_t > 0.0:
		# Saída da abertura: desce suave antes de voltar ao acompanhamento normal.
		_ease_t = maxf(0.0, _ease_t - delta)
		speed = lerpf(Balance.CAMERA_FOLLOW_SPEED, 1.6, _ease_t / INTRO_EASE_SEC)
	var zt: float = target_zoom()
	if not is_equal_approx(zoom.x, zt):
		zoom = Vector2.ONE * move_toward(zoom.x, zt, delta * (0.5 if fall <= 0.01 else 0.3))
		speed = minf(speed, 4.0)
	var k: float = 1.0 - exp(-speed * delta)
	_pos = _pos.lerp(_desired(), k)
	_shake = Vector2.ZERO
	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - Balance.CAMERA_SHAKE_DECAY * delta)
		var s: float = _trauma * _trauma * Balance.CAMERA_SHAKE_MAX_PX
		_shake = Vector2(randf_range(-s, s), randf_range(-s, s))
	if fall > 0.3 and not combat:
		var r: float = (fall - 0.3) * 3.0
		_shake += Vector2(randf_range(-r, r), randf_range(-r, r))
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
	var p: Vector2 = target.global_position + Vector2(0.0, view.y * (Balance.CAMERA_LOOK_AHEAD_RATIO + FALL_LOOK * fall))
	if intro:
		p.y = -view.y * (INTRO_SURFACE_SCREEN_Y - 0.5)
	if combat:
		return Vector2(combat_anchor.x, combat_anchor.y - view.y * (COMBAT_FLOOR_SCREEN_Y - 0.5))
	var world_w: float = float(Balance.WORLD_WIDTH * Balance.BLOCK_PX)
	if view.x >= world_w:
		p.x = world_w * 0.5
	else:
		p.x = clampf(p.x, view.x * 0.5, world_w - view.x * 0.5)
	if not intro:
		p.y = minf(p.y, bottom_limit - view.y * 0.5)
		p.y = maxf(p.y, -Balance.SKY_ROWS_VISIBLE * Balance.BLOCK_PX + view.y * 0.5)
	return p
