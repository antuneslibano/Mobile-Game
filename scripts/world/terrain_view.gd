class_name TerrainView
extends Node2D
## Mantém ChunkRenderers apenas para chunks próximos à câmera, reciclando-os em pool.

var world: WorldModel
var camera: Camera2D
var _active: Dictionary = {}               ## int → ChunkRenderer
var _pool: Array[ChunkRenderer] = []


func setup(p_world: WorldModel, p_camera: Camera2D) -> void:
	if world != null and world.cells_changed.is_connected(_on_cells_changed):
		world.cells_changed.disconnect(_on_cells_changed)
	for index: int in _active.keys():
		_hide(index)
	world = p_world
	camera = p_camera
	world.cells_changed.connect(_on_cells_changed)
	update_streaming()


func _process(_delta: float) -> void:
	update_streaming()


## Intervalo de chunks atualmente visível pela câmera.
func visible_chunk_range() -> Vector2i:
	var center: Vector2 = camera.get_screen_center_position()
	var half: Vector2 = get_viewport_rect().size / camera.zoom * 0.5
	var top_row: int = floori((center.y - half.y) / Balance.CELL_PX)
	var bottom_row: int = floori((center.y + half.y) / Balance.CELL_PX)
	return Vector2i(WorldModel.chunk_index_for_row(top_row), WorldModel.chunk_index_for_row(bottom_row))


func update_streaming() -> void:
	if world == null or camera == null:
		return
	var vis := visible_chunk_range()
	var want_min: int = vis.x - Balance.CHUNKS_PRELOAD_ABOVE
	var want_max: int = vis.y + Balance.CHUNKS_PRELOAD_BELOW

	world.poll_jobs()
	# Visíveis: síncrono (necessários neste quadro).
	for i in range(vis.x, vis.y + 1):
		world.get_chunk(i)
	# Antecipação: em threads; sem threads, limitada por orçamento por quadro.
	var budget: int = Balance.GEN_CHUNKS_PER_FRAME
	for i in range(want_min, want_max + 1):
		if not world.has_chunk(i) and budget > 0:
			if world.request_chunk(i) and not world.threaded:
				budget -= 1
		if i >= 0 and world.has_chunk(i) and not _active.has(i):
			_show(i)

	for index: int in _active.keys():
		if index < want_min or index > want_max:
			_hide(index)
	world.unload_outside(want_min - Balance.CHUNK_UNLOAD_HYSTERESIS, want_max + Balance.CHUNK_UNLOAD_HYSTERESIS)


func active_count() -> int:
	return _active.size()


func _show(index: int) -> void:
	var r: ChunkRenderer
	if _pool.is_empty():
		r = ChunkRenderer.new()
		r.name = "Chunk"
		add_child(r)
	else:
		r = _pool.pop_back()
	r.setup(world)
	r.assign(index)
	_active[index] = r


func _hide(index: int) -> void:
	var r: ChunkRenderer = _active[index]
	_active.erase(index)
	r.visible = false
	_pool.append(r)


## Células alteradas aparecem no próprio chunk e no halo dos vizinhos.
func _on_cells_changed(cells: Array[Vector2i]) -> void:
	for index: int in _active:
		(_active[index] as ChunkRenderer).update_cells(cells)
