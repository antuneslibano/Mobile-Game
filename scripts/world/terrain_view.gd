class_name TerrainView
extends Node2D
## Mantém ChunkRenderers apenas para chunks próximos à câmera, reciclando-os em pool.

var world: WorldModel
var camera: Camera2D
var _active: Dictionary = {}               ## int → ChunkRenderer
var _pool: Array[ChunkRenderer] = []
var _tex: Texture2D


func setup(p_world: WorldModel, p_camera: Camera2D) -> void:
	if world != null and world.cell_changed.is_connected(_on_cell_changed):
		world.cell_changed.disconnect(_on_cell_changed)
	for index: int in _active.keys():
		_hide(index)
	world = p_world
	camera = p_camera
	_tex = TileArt.get_texture()
	world.cell_changed.connect(_on_cell_changed)
	update_streaming()


func _process(_delta: float) -> void:
	update_streaming()


## Intervalo de chunks atualmente visível pela câmera.
func visible_chunk_range() -> Vector2i:
	var center: Vector2 = camera.get_screen_center_position()
	var half: Vector2 = get_viewport_rect().size / camera.zoom * 0.5
	var top_row: int = floori((center.y - half.y) / Balance.BLOCK_PX)
	var bottom_row: int = floori((center.y + half.y) / Balance.BLOCK_PX)
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
	r.setup(world, _tex)
	r.assign(index)
	_active[index] = r


func _hide(index: int) -> void:
	var r: ChunkRenderer = _active[index]
	_active.erase(index)
	r.visible = false
	_pool.append(r)


func _on_cell_changed(cell: Vector2i) -> void:
	var index: int = WorldModel.chunk_index_for_row(cell.y)
	_redraw(index)
	var ly: int = cell.y - index * Balance.CHUNK_HEIGHT
	if ly == 0:
		_redraw(index - 1)
	elif ly == Balance.CHUNK_HEIGHT - 1:
		_redraw(index + 1)


func _redraw(index: int) -> void:
	var r: ChunkRenderer = _active.get(index)
	if r != null:
		r.queue_redraw()
