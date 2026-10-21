extends "res://tests/test_case.gd"


func _model(p_seed: int) -> WorldModel:
	var w := WorldModel.new(p_seed)
	w.threaded = false
	return w


func test_generator_is_deterministic() -> void:
	var a := WorldGenerator.new(1234)
	var b := WorldGenerator.new(1234)
	var c := WorldGenerator.new(9999)
	var differs: bool = false
	for index: int in [0, 1, 5, 12, 25, 40]:
		var ia: PackedByteArray = a.generate_chunk(index)
		check(ia == b.generate_chunk(index), "chunk %d idêntico com a mesma seed" % index)
		if ia != c.generate_chunk(index):
			differs = true
	check(differs, "seeds diferentes geram mundos diferentes")


func test_chunk_matches_single_cell_generation() -> void:
	var g := WorldGenerator.new(77)
	var ids: PackedByteArray = g.generate_chunk(3)
	var cy0: int = 3 * Balance.CHUNK_CELLS_Y
	for i in 300:
		var cx: int = (i * 37) % Balance.WORLD_CELLS_X
		var ly: int = (i * 53) % Balance.CHUNK_CELLS_Y
		check_eq(int(ids[ly * Balance.WORLD_CELLS_X + cx]), g.generate_cell(cx, cy0 + ly), "célula (%d,%d) igual em chunk e avulsa" % [cx, cy0 + ly])


func test_hash_is_stable() -> void:
	var h1: float = WorldGenerator.hash01(3, 7, 42)
	check(h1 >= 0.0 and h1 < 1.0, "hash no intervalo")
	check_eq(WorldGenerator.hash01(3, 7, 42), h1, "hash repetível")
	check(WorldGenerator.hash01(3, 8, 42) != h1, "hash varia com y")
	var sum: float = 0.0
	for i in 2000:
		sum += WorldGenerator.hash01(i % 37, i / 37, 5)
	var mean: float = sum / 2000.0
	check(mean > 0.45 and mean < 0.55, "hash aproximadamente uniforme (média %.3f)" % mean)


func test_bounds_walls_and_surface() -> void:
	var g := WorldGenerator.new(77)
	var max_cy: int = Balance.MAX_DEPTH_ROWS * Balance.CELL_SUB
	for cy in range(0, max_cy, 29):
		check_eq(g.generate_cell(0, cy), BlockRegistry.BEDROCK, "parede esquerda em y=%d" % cy)
		check_eq(g.generate_cell(Balance.WORLD_CELLS_X - 1, cy), BlockRegistry.BEDROCK, "parede direita em y=%d" % cy)
	for cx in Balance.WORLD_CELLS_X:
		check_eq(g.generate_cell(cx, -1), BlockRegistry.AIR, "céu em x=%d" % cx)
		check_eq(g.generate_cell(cx, max_cy), BlockRegistry.BEDROCK, "fundo em x=%d" % cx)
	# Abaixo da borda irregular da superfície, o solo inicial é sólido (sem cavernas).
	for cy in range(Balance.CELL_SUB, Balance.SAFE_SURFACE_ROWS * Balance.CELL_SUB - Balance.CELL_SUB):
		for cx in range(Balance.WALL_CELLS, Balance.WORLD_CELLS_X - Balance.WALL_CELLS):
			check(BlockRegistry.is_solid(g.generate_cell(cx, cy)), "superfície sem cavernas (%d,%d)" % [cx, cy])


func test_biome_content_and_caves() -> void:
	# Cada camada de cada região gera o seu material principal, os minérios da tabela e cavernas.
	for r in RegionRegistry.all():
		var g := WorldGenerator.new(2024, r)
		for biome in r.layers:
			if biome.end_row - biome.start_row < 30:
				continue
			var counts: Dictionary = {}
			var air: int = 0
			var total: int = 0
			for y in range(biome.start_row + 5, mini(biome.end_row - 5, biome.start_row + 125)):
				for x in range(1, Balance.WORLD_WIDTH - 1):
					var id: int = g.generate_block(x, y)
					counts[id] = int(counts.get(id, 0)) + 1
					total += 1
					if id == BlockRegistry.AIR:
						air += 1
			var cave_ratio: float = float(air) / float(total)
			var tag: String = "%s/%s" % [r.display_name, biome.display_name]
			check(cave_ratio > 0.03 and cave_ratio < 0.5, "%s: proporção de cavernas %.2f" % [tag, cave_ratio])
			check(int(counts.get(biome.primary_block, 0)) > 0, "%s contém o material principal" % tag)
			for entry: Array in biome.ore_table:
				var ore: int = entry[0]
				if float(entry[1]) >= 0.01:
					check(int(counts.get(ore, 0)) > 0, "%s contém %s" % [tag, BlockRegistry.get_def(ore).key])


func test_generation_time_budget() -> void:
	var g := WorldGenerator.new(5)
	var t0: int = Time.get_ticks_usec()
	var n: int = 12
	for i in n:
		g.generate_chunk(i * 2)
	var avg_ms: float = float(Time.get_ticks_usec() - t0) / n / 1000.0
	note("geração média por chunk: %.2f ms (%d micro-células, em thread de trabalho no jogo)" % [avg_ms, Balance.WORLD_CELLS_X * Balance.CHUNK_CELLS_Y])
	check(avg_ms < 30.0, "geração de chunk abaixo de 30 ms no desktop (%.2f ms)" % avg_ms)


func test_threaded_generation_matches_sync() -> void:
	var sync := _model(31)
	var thr := WorldModel.new(31)
	for i in range(0, 4):
		check(thr.request_chunk(i), "agenda chunk %d" % i)
	check(not thr.request_chunk(0), "não agenda duplicado")
	var guard: int = 0
	while thr.pending_count() > 0 and guard < 4000:
		thr.poll_jobs()
		OS.delay_usec(500)
		guard += 1
	check_eq(thr.pending_count(), 0, "trabalhos concluídos")
	for i in range(0, 4):
		check(thr.get_chunk(i).ids == sync.get_chunk(i).ids, "chunk %d igual em thread e síncrono" % i)
	thr.request_chunk(30)
	check(thr.get_chunk(30).ids == sync.get_chunk(30).ids, "get_chunk aguarda pendente")
	thr.shutdown()


func test_modifications_survive_unload_and_export() -> void:
	var w := _model(808)
	var cell := Vector2i(40, 90)
	var original: int = w.get_cell(cell)
	w.set_cell(cell, BlockRegistry.STONE)
	w.set_cell(cell, BlockRegistry.AIR)
	check_eq(w.get_cell(cell), BlockRegistry.AIR, "célula removida")
	w.unload_outside(100, 200)
	check(not w.has_chunk(WorldModel.chunk_index_for_row(cell.y)), "chunk descarregado")
	check_eq(w.peek_cell(cell), BlockRegistry.AIR, "peek respeita modificação sem carregar")
	check_eq(w.get_cell(cell), BlockRegistry.AIR, "modificação reaplicada ao regenerar")
	var parsed: Variant = JSON.parse_string(JSON.stringify(w.export_modifications()))
	check(parsed is Dictionary, "exportação é JSON válido")
	var w2 := _model(808)
	w2.import_modifications(parsed)
	check_eq(w2.get_cell(cell), BlockRegistry.AIR, "importação preserva escavação")
	w.set_cell(cell, original)
	check_eq(w.modified_cell_count(), 0, "restaurar o original remove a modificação")
	w2.import_modifications({"x": 1, "3": {"abc": 2, "99999": 1, "4": 250}})
	check_eq(w2.modified_cell_count(), 0, "dados inválidos descartados")


func test_peek_matches_get() -> void:
	var w := _model(4242)
	var w2 := _model(4242)
	for cy in range(0, 300, 7):
		for cx in range(-1, Balance.WORLD_CELLS_X + 1, 5):
			var c := Vector2i(cx, cy)
			check_eq(w.peek_cell(c), w2.get_cell(c), "peek == get em %s" % c)


func test_dig_circle_wear_and_removal() -> void:
	var w := _model(1)
	var center := Vector2(480, 300)
	w.fill_circle(center, 40.0, BlockRegistry.STONE)
	var def: BlockDef = BlockRegistry.get_def(BlockRegistry.STONE)
	var cell_hp: float = def.max_hp / Balance.CELL_SUB
	# Golpe que tira ~metade da vida da célula: desgasta sem remover.
	var raw: float = cell_hp * 0.5 + def.hardness
	var r: WorldModel.DigResult = w.dig_circle(center, 20.0, raw)
	check(r.touched > 0 and r.removed() == 0, "desgaste parcial sem remover (%d tocadas)" % r.touched)
	var c := WorldModel.world_to_cell(center)
	check(w.get_damage(c) > 0.4 and w.get_damage(c) < 0.6, "desgaste ~50%% (%.2f)" % w.get_damage(c))
	r = w.dig_circle(center, 20.0, raw)
	check(r.removed() == r.touched and r.removed() > 0, "segundo golpe remove as células")
	check_eq(r.main_id, BlockRegistry.STONE, "material principal identificado")
	check(not w.is_solid(c), "centro vazio")
	check(w.is_solid(WorldModel.world_to_cell(center + Vector2(34, 0))), "fora do raio intacto")
	# min_y: nada acima do teto.
	w.fill_circle(center, 40.0, BlockRegistry.DIRT)
	w.dig_circle(center, 36.0, 999.0, center.y)
	check(w.is_solid(WorldModel.world_to_cell(center + Vector2(0, -20))), "teto respeitado")
	check(not w.is_solid(WorldModel.world_to_cell(center + Vector2(0, 20))), "abaixo do teto escavado")
	# Rocha-mãe não é afetada.
	r = w.dig_circle(Vector2(12, 300), 20.0, 9999.0)
	check(r.unbreakable, "rocha-mãe sinalizada")
	check_eq(w.get_cell(Vector2i(0, 25)), BlockRegistry.BEDROCK, "parede intacta")


func test_circle_collision() -> void:
	var w := _model(2)
	var p := Vector2(480, 300)
	w.fill_circle(p, 60.0, BlockRegistry.AIR)
	check(not w.circle_hits_solid(p, 19.0), "bolsão livre")
	check(w.circle_hits_solid(p, 70.0), "círculo maior toca a rocha")
