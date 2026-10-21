class_name MiningOverlay
extends Node2D
## Brilho de impacto no ponto perfurado. Rachaduras são desenhadas pelo shader de terreno.

const FLASH_TIME: float = 0.08

var _point: Vector2 = Vector2.ZERO
var _flash_t: float = 0.0
var _strength: float = 1.0


func _ready() -> void:
	set_process(false)


func notify_hit(point: Vector2, crit: bool) -> void:
	_point = point
	_flash_t = FLASH_TIME
	_strength = 1.6 if crit else 1.0
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_flash_t -= delta
	if _flash_t <= 0.0:
		_flash_t = 0.0
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _flash_t <= 0.0:
		return
	var k: float = _flash_t / FLASH_TIME
	draw_circle(_point, 16.0 * _strength, Color(1.0, 0.85, 0.55, 0.22 * k))
	draw_circle(_point, 7.0 * _strength, Color(1.0, 0.95, 0.8, 0.5 * k))
