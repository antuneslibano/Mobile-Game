class_name MiningOverlay
extends Node2D
## Rachaduras nos blocos danificados e flash de impacto. Redesenha apenas quando há mudança.

const FLASH_TIME: float = 0.07

var world: WorldModel
var _tex: Texture2D
var _flash_cell: Vector2i = Vector2i.ZERO
var _flash_t: float = 0.0


func setup(p_world: WorldModel) -> void:
	world = p_world
	_tex = TileArt.get_texture()
	world.cell_changed.connect(func(_cell: Vector2i) -> void: queue_redraw())
	set_process(false)
	queue_redraw()


func notify_hit(cell: Vector2i) -> void:
	_flash_cell = cell
	_flash_t = FLASH_TIME
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_flash_t -= delta
	if _flash_t <= 0.0:
		_flash_t = 0.0
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var b: float = float(Balance.BLOCK_PX)
	for cell: Vector2i in world.damaged_cells():
		var ratio: float = world.get_damage_ratio(cell)
		if ratio <= 0.0:
			continue
		var stage: int = clampi(int(ratio * 4.0), 0, 3)
		draw_texture_rect_region(_tex, Rect2(Vector2(cell) * b, Vector2(b, b)), TileArt.region(TileArt.ROW_CRACK, stage))
	if _flash_t > 0.0:
		var a: float = 0.32 * (_flash_t / FLASH_TIME)
		draw_rect(Rect2(Vector2(_flash_cell) * b, Vector2(b, b)), Color(1, 1, 1, a))
