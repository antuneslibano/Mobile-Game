class_name WorldModel
extends RefCounted
## Terreno em micro-células (Balance.CELL_PX): cache de chunks, modificações persistentes,
## desgaste parcial e escavação por círculos (a broca "desenha" o túnel).
## Não depende de nós nem de renderização.

## Células alteradas (escavadas ou desgastadas) em um lote.
signal cells_changed(cells: Array[Vector2i])
signal chunk_loaded(index: int)
signal chunk_unloaded(index: int)


## Resultado de uma escavação.
class DigResult:
	var counts: Dictionary = {}      ## id do material → células removidas
	var touched: int = 0             ## células quebráveis atingidas
	var main_id: int = BlockRegistry.AIR  ## material mais atingido (para FX)
	var unbreakable: bool = false    ## tocou rocha-mãe
	var too_hard: int = -1           ## minério acima do nível da broca (id), se tocou
	var chest_blocks: Array[Vector2i] = []  ## blocos de baú com células removidas agora

	func removed() -> int:
		var n: int = 0
		for id: int in counts:
			n += int(counts[id])
		return n


## Trabalho de geração em segundo plano (WorkerThreadPool).
class _Job:
	var index: int = 0
	var ids: PackedByteArray
	var usec: int = 0
	var task_id: int = -1


const NO_CELL := Vector2i(-99999, -99999)

var generator: WorldGenerator
## Geração antecipada em threads de trabalho. Desligue para testes determinísticos de quadro.
var threaded: bool = true
var _chunks: Dictionary = {}       ## int → ChunkData
var _pending: Dictionary = {}      ## int → _Job
var _mods: Dictionary = {}         ## int (chunk) → Dictionary[int (local), int (id)]

# Estatísticas para perfil/testes.
var stats_generated: int = 0
var stats_gen_usec: int = 0
var stats_gen_max_usec: int = 0


func _init(p_seed: int, region: RegionDef = null) -> void:
	generator = WorldGenerator.new(p_seed, region)


# --- Conversões ----------------------------------------------------------------

static func chunk_index_for_row(cy: int) -> int:
	return floori(float(cy) / float(Balance.CHUNK_CELLS_Y))


static func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / Balance.CELL_PX), floori(p.y / Balance.CELL_PX))


static func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * Balance.CELL_PX


static func _local_index(c: Vector2i) -> int:
	var ly: int = c.y - chunk_index_for_row(c.y) * Balance.CHUNK_CELLS_Y
	return ly * Balance.WORLD_CELLS_X + c.x


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

func _in_x(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < Balance.WORLD_CELLS_X


## Lê uma célula, gerando o chunk se necessário. Fora do mundo = rocha-mãe; céu = ar.
func get_cell(c: Vector2i) -> int:
	if not _in_x(c):
		return BlockRegistry.BEDROCK
	if c.y < 0:
		return BlockRegistry.AIR
	return get_chunk(chunk_index_for_row(c.y)).ids[_local_index(c)]


## Lê uma célula sem forçar geração de chunk.
func peek_cell(c: Vector2i) -> int:
	if not _in_x(c):
		return BlockRegistry.BEDROCK
	if c.y < 0:
		return BlockRegistry.AIR
	var index: int = chunk_index_for_row(c.y)
	var ch: ChunkData = _chunks.get(index)
	if ch != null:
		return ch.ids[_local_index(c)]
	var mods: Dictionary = _mods.get(index, {})
	var local: int = _local_index(c)
	if mods.has(local):
		return int(mods[local])
	return generator.generate_cell(c.x, c.y)


## Verdadeiro se a célula foi alterada pela escavação (ar de túnel, não de caverna).
func is_modified(c: Vector2i) -> bool:
	if c.y < 0 or not _in_x(c):
		return false
	var mods: Dictionary = _mods.get(chunk_index_for_row(c.y), {})
	return mods.has(_local_index(c))


func is_solid(c: Vector2i) -> bool:
	return BlockRegistry.is_solid(get_cell(c))


## Desgaste parcial 0..1 (0 = intacta).
func get_damage(c: Vector2i) -> float:
	if not _in_x(c) or c.y < 0:
		return 0.0
	var ch: ChunkData = _chunks.get(chunk_index_for_row(c.y))
	if ch == null:
		return 0.0
	return float(ch.dmg[_local_index(c)]) / 255.0


func set_cell(c: Vector2i, id: int) -> void:
	if _set_raw(c, id):
		var changed: Array[Vector2i] = [c]
		cells_changed.emit(changed)


## Escava só terreno (terra, pedra...) num círculo: minérios, especiais e rocha-mãe ficam
## (túneis das minhocas escavadoras).
func carve_terrain(center: Vector2, radius: float) -> void:
	var changed: Array[Vector2i] = []
	for c in cells_in_circle(center, radius):
		var id: int = get_cell(c)
		if id != BlockRegistry.AIR and id != BlockRegistry.BEDROCK and BlockRegistry.get_def(id).is_terrain() and _set_raw(c, BlockRegistry.AIR):
			changed.append(c)
	if not changed.is_empty():
		cells_changed.emit(changed)


## Preenche um retângulo de células com um material (ex.: corpo do guardião vencido).
func fill_cells(rect: Rect2i, id: int) -> void:
	var changed: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if _set_raw(c, id):
				changed.append(c)
	if not changed.is_empty():
		cells_changed.emit(changed)


## Preenche um círculo com um material (debug/testes: abrir bolsões).
func fill_circle(center: Vector2, radius: float, id: int) -> void:
	var changed: Array[Vector2i] = []
	for c in cells_in_circle(center, radius):
		if _set_raw(c, id):
			changed.append(c)
	if not changed.is_empty():
		cells_changed.emit(changed)


func _set_raw(c: Vector2i, id: int) -> bool:
	if not _in_x(c) or c.y < 0:
		return false
	var index: int = chunk_index_for_row(c.y)
	var ch: ChunkData = get_chunk(index)
	var local: int = _local_index(c)
	ch.dmg[local] = 0
	if ch.ids[local] == id:
		return false
	ch.ids[local] = id
	var mods: Dictionary = _mods.get(index, {})
	if generator.generate_cell(c.x, c.y) == id:
		mods.erase(local)
	else:
		mods[local] = id
	if mods.is_empty():
		_mods.erase(index)
	else:
		_mods[index] = mods
	return true


## Células cujo centro está dentro do círculo (e abaixo de min_y, se dado).
func cells_in_circle(center: Vector2, radius: float, min_y: float = -INF) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var cp: float = float(Balance.CELL_PX)
	var x0: int = floori((center.x - radius) / cp)
	var x1: int = floori((center.x + radius) / cp)
	var y0: int = floori((maxf(center.y - radius, min_y)) / cp)
	var y1: int = floori((center.y + radius) / cp)
	var r2: float = radius * radius
	for cy in range(y0, y1 + 1):
		var py: float = (cy + 0.5) * cp
		if py < min_y:
			continue
		for cx in range(x0, x1 + 1):
			var px: float = (cx + 0.5) * cp
			if (px - center.x) * (px - center.x) + (py - center.y) * (py - center.y) <= r2:
				out.append(Vector2i(cx, cy))
	return out


## Verdadeiro se algum retângulo de célula sólida intersecta o círculo (colisão do corpo).
func circle_hits_solid(center: Vector2, radius: float) -> bool:
	var cp: float = float(Balance.CELL_PX)
	var x0: int = floori((center.x - radius) / cp)
	var x1: int = floori((center.x + radius) / cp)
	var y0: int = floori((center.y - radius) / cp)
	var y1: int = floori((center.y + radius) / cp)
	var r2: float = radius * radius
	for cy in range(y0, y1 + 1):
		var ry0: float = cy * cp
		var qy: float = clampf(center.y, ry0, ry0 + cp)
		for cx in range(x0, x1 + 1):
			var rx0: float = cx * cp
			var qx: float = clampf(center.x, rx0, rx0 + cp)
			if (qx - center.x) * (qx - center.x) + (qy - center.y) * (qy - center.y) < r2:
				if is_solid(Vector2i(cx, cy)):
					return true
	return false


## Células sólidas cujo retângulo intersecta o círculo (o que bloqueia um corpo ali).
func blocking_cells(center: Vector2, radius: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var cp: float = float(Balance.CELL_PX)
	var r2: float = radius * radius
	for cy in range(floori((center.y - radius) / cp), floori((center.y + radius) / cp) + 1):
		var qy: float = clampf(center.y, cy * cp, cy * cp + cp)
		for cx in range(floori((center.x - radius) / cp), floori((center.x + radius) / cp) + 1):
			var qx: float = clampf(center.x, cx * cp, cx * cp + cp)
			if (qx - center.x) * (qx - center.x) + (qy - center.y) * (qy - center.y) < r2:
				var c := Vector2i(cx, cy)
				if is_solid(c):
					out.append(c)
	return out


## Escava um círculo: cada célula sólida quebrável cujo centro está no círculo recebe o golpe.
## min_y: não afeta células acima dessa altura (a broca nunca abre caminho para cima).
func dig_circle(center: Vector2, radius: float, raw_damage: float, min_y: float = -INF, drill_tier: int = 99) -> DigResult:
	return dig_cells(cells_in_circle(center, radius, min_y), raw_damage, min_y, drill_tier)


## Aplica um golpe a uma lista de células (com dureza). Vida da célula = vida do bloco /
## CELL_SUB, então atravessar 1 bloco custa o mesmo número de golpes que um bloco inteiro.
func dig_cells(cells: Array[Vector2i], raw_damage: float, min_y: float = -INF, drill_tier: int = 99) -> DigResult:
	var res := DigResult.new()
	var changed: Array[Vector2i] = []
	var touched_by_id: Dictionary = {}
	var seen: Dictionary = {}
	for c in cells:
		if seen.has(c) or not _in_x(c) or c.y < 0 or cell_center(c).y < min_y:
			continue
		seen[c] = true
		var ch: ChunkData = get_chunk(chunk_index_for_row(c.y))
		var local: int = _local_index(c)
		var id: int = ch.ids[local]
		var def: BlockDef = BlockRegistry.get_def(id)
		if not def.solid:
			continue
		if not def.breakable:
			res.unbreakable = true
			continue
		if not MiningRules.can_break(id, drill_tier):
			res.too_hard = id
			continue
		if id == BlockRegistry.CHEST:
			# Baú é coletável (0.14): ao ser tocado sai inteiro (as 16 células do bloco),
			# nunca fica um pedaço preso no cenário.
			var blk := Vector2i(c.x / Balance.CELL_SUB, c.y / Balance.CELL_SUB)
			if not res.chest_blocks.has(blk):
				res.chest_blocks.append(blk)
				for oy in Balance.CELL_SUB:
					for ox in Balance.CELL_SUB:
						var cc := Vector2i(blk.x * Balance.CELL_SUB + ox, blk.y * Balance.CELL_SUB + oy)
						if get_cell(cc) == BlockRegistry.CHEST and _set_raw(cc, BlockRegistry.AIR):
							res.counts[id] = int(res.counts.get(id, 0)) + 1
							changed.append(cc)
							seen[cc] = true
			res.touched += 1
			continue
		res.touched += 1
		touched_by_id[id] = int(touched_by_id.get(id, 0)) + 1
		var cell_hp: float = def.max_hp / Balance.CELL_SUB
		var frac: float = float(ch.dmg[local]) / 255.0 + MiningRules.effective_damage(raw_damage, def.hardness) / cell_hp
		if frac >= 1.0:
			_set_raw(c, BlockRegistry.AIR)
			res.counts[id] = int(res.counts.get(id, 0)) + 1

		else:
			ch.dmg[local] = mini(254, ceili(frac * 255.0))
		changed.append(c)
	var best: int = 0
	for id: int in touched_by_id:
		if int(touched_by_id[id]) > best:
			best = int(touched_by_id[id])
			res.main_id = id
	if not changed.is_empty():
		cells_changed.emit(changed)
	return res


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
	var max_local: int = Balance.WORLD_CELLS_X * Balance.CHUNK_CELLS_Y
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
