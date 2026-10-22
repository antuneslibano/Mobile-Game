class_name DrillIntent
extends RefCounted
## Intenção de controle de um quadro, independente do dispositivo de entrada.

## Direção desejada × aceleração (comprimento 0..1). Para cima só em rampa: y ≥ −|x|·CLIMB_SLOPE.
var aim: Vector2 = Vector2.ZERO
var boost: bool = false   ## Ativar a Sobrecarga (só funciona com a barra cheia).
var sonar: bool = false   ## Disparar o sonar (0.13; só com a recarga pronta).


func clear() -> void:
	aim = Vector2.ZERO
	boost = false
	sonar = false


## Normaliza a direção: a subida é limitada à rampa (reto para cima = parado);
## comprimento limitado a 1.
static func sanitize(v: Vector2) -> Vector2:
	if v.y < 0.0 and absf(v.x) < -v.y * 0.6:
		return Vector2.ZERO  # quase reto para cima: não faz nada
	return Vector2(v.x, maxf(v.y, -absf(v.x) * Balance.CLIMB_SLOPE)).limit_length(1.0)
