class_name WorldModel
extends RefCounted
## Modelo do terreno: cache de chunks gerados, modificações persistentes e dano parcial.
## Não depende de nós nem de renderização.

signal cell_changed(cell: Vector2i)
## Dano parcial mudou (ou expirou) numa célula — usado para desenhar rachaduras.
signal cell_damaged(cell: Vector2i)
signal chunk_loaded(index: int)
signal chunk_unloaded(index: int)


## Resultado de um golpe em uma célula.
class DamageResult:
	var block_id: int = BlockRegistry.AIR
	var applied: bool = false      ## false = célula vazia ou indestrutível.
	var destroyed: bool = false
	var damage: float = 0.0
	var hp_ratio: float = 0.0      ## Vida restante (0..1).


## Trabalho de geração em segundo plano (WorkerThreadPool).
class _Job:
	var index: int = 0
	var ids: PackedByteArray
	var usec: int = 0
	var task_id: int = -1


var generator: WorldGenerator
## Geração antecipada em threads de trabalho. Desligue para depuração determinística de quadro.
var threaded: bool = true
var _chunks: Dictionary = {}       ## int → ChunkData
var _pending: Dictionary = {}      ## int → _Job
var _mods: Dictionary = {}         ## int (chunk) → Dictionary[int (local), int (id)]
var _damage: Dictionary = {}       ## Vector2i → float (dano acumulado)
var _damage_order: Array[Vector2i] = []

# Estatísticas para perfil/testes.
var stats_generated: int = 0
var stats_gen_usec: int = 0
var stats_gen_max_usec: int = 0


func _init(p_seed: int) -> void:
	generator = WorldGenerator.new(p_seed)


# --- Conversões ----------------------------------------------------------------

static func chunk_index_for_row(y: int) -> int:
	return floori(float(y) / float(Balance.CHUNK_HEIGHT))


static func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / Balance.BLOCK_PX), floori(p.y / Balance.BLOCK_PX))


static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * Balance.BLOCK_PX


static func _local_index(cell: Vector2i) -> int:
	var ly: int = cell.y - chunk_index_for_row(cell.y) * Balance.CHUNK_HEIGHT
	return ly * Balance.WORLD_WIDTH + cell.x


# --- Chunks --------------------------------------------------------------------

func has_chunk(index: int) -> bool:
	return _chunks.has(index)


## Retorna o chunk, gerando de forma síncrona (ou aguardando o trabalho pendente).
func get_chunk(index: int) -> ChunkData:
	var c: ChunkData = _chunks.get(index)
	if c != null:
		return c
	var job: _Job = _pending.get(index)
	if job != null:
		WorkerThreadPool.wait_for_task_completion(job.task_id)
		_pending.erase(index)
		return _integrate(index, job.ids, job.usec)
	var t0: int = Time.get_ticks_usec()
	var ids: PackedByteArray = generator.generate_chunk(index)
	return _integrate(index, ids, Time.get_ticks_usec() - t0)


## Agenda a geração de um chunk sem bloquear. Retorna false se já existe/pendente.
func request_chunk(index: int) -> bool:
	if _chunks.has(index) or _pending.has(index):
		return false
	if not threaded:
		get_chunk(index)
		return true
	var job := _Job.new()
	job.index = index
	job.task_id = WorkerThreadPool.add_task(_run_job.bind(job), false, "DEEPFORGE chunk")
	_pending[index] = job
	return true


func pending_count() -> int:
	return _pending.size()


## Integra trabalhos concluídos (chamar uma vez por quadro, na thread principal).
func poll_jobs() -> int:
	var done: int = 0
	for index: int in _pending.keys():
		var job: _Job = _pending[index]
		if WorkerThreadPool.is_task_completed(job.task_id):
			WorkerThreadPool.wait_for_task_completion(job.task_id)
			_pending.erase(index)
			_integrate(index, job.ids, job.usec)
			done += 1
	return done


## Aguarda todos os trabalhos (antes de descartar o modelo).
func shutdown() -> void:
	for index: int in _pending.keys():
		var job: _Job = _pending[index]
		WorkerThreadPool.wait_for_task_completion(job.task_id)
	_pending.clear()


func _run_job(job: _Job) -> void:
	var t0: int = Time.get_ticks_usec()
	job.ids = generator.generate_chunk(job.index)
	job.usec = Time.get_ticks_usec() - t0


func loaded_chunk_indices() -> Array:
	return _chunks.keys()


func _integrate(index: int, ids: PackedByteArray, dt: int) -> ChunkData:
	if _chunks.has(index):
		return _chunks[index]
	var mods: Dictionary = _mods.get(index, {})
	for local: int in mods:
		ids[local] = int(mods[local])
	var c := ChunkData.new(index, ids)
	_chunks[index] = c
	stats_generated += 1
	stats_gen_usec += dt
	stats_gen_max_usec = maxi(stats_gen_max_usec, dt)
	chunk_loaded.emit(index)
	return c


## Descarrega chunks fora de [min_index, max_index]. Modificações são preservadas.
func unload_outside(min_index: int, max_index: int) -> void:
	for index: int in _chunks.keys():
		if index < min_index or index > max_index:
			_chunks.erase(index)
			chunk_unloaded.emit(index)


# --- Células -------------------------------------------------------------------

## Lê uma célula, gerando o chunk se necessário.
func get_block(cell: Vector2i) -> int:
	if cell.x < 0 or cell.x >= Balance.WORLD_WIDTH:
		return BlockRegistry.BEDROCK
	return get_chunk(chunk_index_for_row(cell.y)).ids[_local_index(cell)]


## Lê uma célula sem forçar geração de chunk (para vizinhos na renderização).
func peek_block(cell: Vector2i) -> int:
	if cell.x < 0 or cell.x >= Balance.WORLD_WIDTH:
		return BlockRegistry.BEDROCK
	var index: int = chunk_index_for_row(cell.y)
	var c: ChunkData = _chunks.get(index)
	if c != null:
		return c.ids[_local_index(cell)]
	var mods: Dictionary = _mods.get(index, {})
	var local: int = _local_index(cell)
	if mods.has(local):
		return int(mods[local])
	return generator.generate_cell(cell.x, cell.y)


func is_solid(cell: Vector2i) -> bool:
	return BlockRegistry.is_solid(get_block(cell))


func set_block(cell: Vector2i, id: int) -> void:
	if cell.x < 0 or cell.x >= Balance.WORLD_WIDTH:
		return
	var index: int = chunk_index_for_row(cell.y)
	var c: ChunkData = get_chunk(index)
	var local: int = _local_index(cell)
	if c.ids[local] == id:
		return
	c.ids[local] = id
	var mods: Dictionary = _mods.get(index, {})
	if generator.generate_cell(cell.x, cell.y) == id:
		mods.erase(local)
	else:
		mods[local] = id
	if mods.is_empty():
		_mods.erase(index)
	else:
		_mods[index] = mods
	_clear_damage(cell)
	cell_changed.emit(cell)


# --- Dano ----------------------------------------------------------------------

func damage_cell(cell: Vector2i, amount: float) -> DamageResult:
	var r := DamageResult.new()
	r.block_id = get_block(cell)
	var def: BlockDef = BlockRegistry.get_def(r.block_id)
	if not def.solid or not def.breakable or amount <= 0.0:
		return r
	r.applied = true
	r.damage = amount
	var taken: float = float(_damage.get(cell, 0.0)) + amount
	if taken >= def.max_hp:
		r.destroyed = true
		r.hp_ratio = 0.0
		set_block(cell, BlockRegistry.AIR)
		return r
	if not _damage.has(cell):
		_damage_order.append(cell)
		if _damage_order.size() > Balance.MAX_DAMAGED_CELLS:
			var expired: Vector2i = _damage_order.pop_front()
			_damage.erase(expired)
			cell_damaged.emit(expired)
	_damage[cell] = taken
	cell_damaged.emit(cell)
	r.hp_ratio = 1.0 - taken / def.max_hp
	return r


## Fração de dano (0 = intacto, 1 = quase quebrado).
func get_damage_ratio(cell: Vector2i) -> float:
	if not _damage.has(cell):
		return 0.0
	var def: BlockDef = BlockRegistry.get_def(peek_block(cell))
	if def.max_hp <= 0.0 or is_inf(def.max_hp):
		return 0.0
	return clampf(float(_damage[cell]) / def.max_hp, 0.0, 1.0)


func damaged_cells() -> Array[Vector2i]:
	return _damage_order


func _clear_damage(cell: Vector2i) -> void:
	if _damage.erase(cell):
		_damage_order.erase(cell)


# --- Persistência (consumida pelo SaveService na Fase 4) -------------------------

## Exporta modificações em formato JSON-compatível: { "chunk": { "local": id } }.
func export_modifications() -> Dictionary:
	var out: Dictionary = {}
	for index: int in _mods:
		var m: Dictionary = _mods[index]
		var d: Dictionary = {}
		for local: int in m:
			d[str(local)] = int(m[local])
		out[str(index)] = d
	return out


## Importa modificações (descarta chunks em cache para reaplicar).
func import_modifications(data: Dictionary) -> void:
	_mods.clear()
	_damage.clear()
	_damage_order.clear()
	var max_local: int = Balance.WORLD_WIDTH * Balance.CHUNK_HEIGHT
	for key: Variant in data:
		var s := str(key)
		if not s.is_valid_int() or not (data[key] is Dictionary):
			continue
		var src: Dictionary = data[key]
		var m: Dictionary = {}
		for lk: Variant in src:
			var ls := str(lk)
			if not ls.is_valid_int():
				continue
			var local: int = ls.to_int()
			var id: int = int(src[lk])
			if local >= 0 and local < max_local and id >= 0 and id < BlockRegistry.COUNT:
				m[local] = id
		if not m.is_empty():
			_mods[s.to_int()] = m
	for index: int in _chunks.keys():
		_chunks.erase(index)
		chunk_unloaded.emit(index)


func modified_cell_count() -> int:
	var n: int = 0
	for index: int in _mods:
		n += (_mods[index] as Dictionary).size()
	return n
