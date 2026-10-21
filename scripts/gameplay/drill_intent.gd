class_name DrillIntent
extends RefCounted
## Intenção de controle de um quadro, independente do dispositivo de entrada.

## Direção desejada × aceleração (comprimento 0..1). y nunca é negativo: a broca não sobe.
var aim: Vector2 = Vector2.ZERO
var boost: bool = false   ## Ativar a Sobrecarga (só funciona com a barra cheia).


func clear() -> void:
	aim = Vector2.ZERO
	boost = false


## Normaliza a direção: componente para cima é descartado; comprimento limitado a 1.
static func sanitize(v: Vector2) -> Vector2:
	return Vector2(v.x, maxf(v.y, 0.0)).limit_length(1.0)
