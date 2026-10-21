class_name DrillIntent
extends RefCounted
## Intenção de controle de um quadro, independente do dispositivo de entrada.

var move: float = 0.0     ## -1 (esquerda) .. 1 (direita)
var drill: bool = false   ## Perfuração contínua ativa.
var boost: bool = false   ## Impulso solicitado (Fase 3).


func clear() -> void:
	move = 0.0
	drill = false
	boost = false
