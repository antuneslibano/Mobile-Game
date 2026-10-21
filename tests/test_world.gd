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
	for index: int in [0, 1, 5, 12, 25, 40, 61]:
		var ia: PackedByteArray = a.generate_chunk(index)
		check(ia == b.generate_chunk(index), "chunk %d idêntico com a mesma seed" % index)
		if ia != c.generate_chunk(index):
			differs = true
	check(differs, "seeds diferentes geram mundos diferentes")


func test_hash_is_stable() -> void:
	# Valores fixos garantem o mesmo mundo em qualquer plataforma/versão.
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
	for y in range(0, Balance.MAX_DEPTH_ROWS, 7):
		check_eq(g.generate_cell(0, y), BlockRegistry.BEDROCK, "parede esquerda em y=%d" % y)
		check_eq(g.generate_cell(Balance.WORLD_WIDTH - 1, y), BlockRegistry.BEDROCK, "parede direita em y=%d" % y)
	for x in Balance.WORLD_WIDTH:
		check_eq(g.generate_cell(x, -1), BlockRegistry.AIR, "céu em x=%d" % x)
		check_eq(g.generate_cell(x, Balance.MAX_DEPTH_ROWS), BlockRegistry.BEDROCK, "fundo em x=%d" % x)
	for y in Balance.SAFE_SURFACE_ROWS:
		for x in range(1, Balance.WORLD_WIDTH - 1):
			check(BlockRegistry.is_solid(g.generate_cell(x, y)), "superfície sem cavernas (%d,%d)" % [x, y])


func test_biome_content_and_caves() -> void:
	var g := WorldGenerator.new(2024)
	var expect: Dictionary = {
		BiomeRegistry.CRUST: [BlockRegistry.DIRT, BlockRegistry.STONE, BlockRegistry.COPPER, BlockRegistry.IRON],
		BiomeRegistry.CRYSTAL_CAVES: [BlockRegistry.CRYSTAL_ROCK, BlockRegistry.CRYSTAL, BlockRegistry.AMETHYST],
		BiomeRegistry.MAGMA_ZONE: [BlockRegistry.BASALT, BlockRegistry.MAGMA_ROCK, BlockRegistry.GOLD, BlockRegistry.RUBY],
		BiomeRegistry.ANCIENT_ABYSS: [BlockRegistry.ABYSS_STONE, BlockRegistry.VOIDITE],
	}
	for b: int in expect:
		var biome: BiomeDef = BiomeRegistry.get_def(b)
		var counts: Dictionary = {}
		var air: int = 0
		var total: int = 0
		for y in range(biome.start_row + 10, biome.end_row - 5):
			for x in range(1, Balance.WORLD_WIDTH - 1):
				var id: int = g.generate_cell(x, y)
				counts[id] = int(counts.get(id, 0)) + 1
				total += 1
				if id == BlockRegistry.AIR:
					air += 1
		var cave_ratio: float = float(air) / float(total)
		check(cave_ratio > 0.04 and cave_ratio < 0.45, "%s: proporção de cavernas %.2f" % [biome.display_name, cave_ratio])
		for id: int in expect[b]:
			check(int(counts.get(id, 0)) > 0, "%s contém %s" % [biome.display_name, BlockRegistry.get_def(id).key])
		note("%s: cavernas %.0f%%, tipos %d" % [biome.display_name, cave_ratio * 100.0, counts.size()])


func test_generation_time_budget() -> void:
	var g := WorldGenerator.new(5)
	var t0: int = Time.get_ticks_usec()
	var n: int = 30
	for i in n:
		g.generate_chunk(i * 2)
	var avg_ms: float = float(Time.get_ticks_usec() - t0) / n / 1000.0
	note("geração média por chunk: %.3f ms (%d células)" % [avg_ms, Balance.WORLD_WIDTH * Balance.CHUNK_HEIGHT])
	check(avg_ms < 3.0, "geração de chunk abaixo de 3 ms no desktop (%.3f ms)" % avg_ms)


func test_threaded_generation_matches_sync() -> void:
	var sync := _model(31)
	var thr := WorldModel.new(31)
	for i in range(0, 6):
		check(thr.request_chunk(i), "agenda chunk %d" % i)
	check(not thr.request_chunk(0), "não agenda duplicado")
	var guard: int = 0
	while thr.pending_count() > 0 and guard < 2000:
		thr.poll_jobs()
		OS.delay_usec(500)
		guard += 1
	check_eq(thr.pending_count(), 0, "trabalhos concluídos")
	for i in range(0, 6):
		check(thr.get_chunk(i).ids == sync.get_chunk(i).ids, "chunk %d igual em thread e síncrono" % i)
	# get_chunk aguarda trabalhos pendentes.
	thr.request_chunk(30)
	check(thr.get_chunk(30).ids == sync.get_chunk(30).ids, "get_chunk aguarda pendente")
	thr.shutdown()


func test_modifications_survive_unload_and_export() -> void:
	var w := _model(808)
	var cell := Vector2i(5, 20)
	var original: int = w.get_block(cell)
	check(BlockRegistry.is_solid(original), "célula de teste sólida inicialmente (id %d)" % original)
	w.set_block(cell, BlockRegistry.AIR)
	check_eq(w.get_block(cell), BlockRegistry.AIR, "bloco removido")
	w.unload_outside(100, 200)
	check(not w.has_chunk(WorldModel.chunk_index_for_row(cell.y)), "chunk descarregado")
	check_eq(w.peek_block(cell), BlockRegistry.AIR, "peek respeita modificação sem carregar")
	check_eq(w.get_block(cell), BlockRegistry.AIR, "modificação reaplicada ao regenerar")

	var data: Dictionary = w.export_modifications()
	var json: String = JSON.stringify(data)
	var parsed: Variant = JSON.parse_string(json)
	check(parsed is Dictionary, "exportação é JSON válido")
	var w2 := _model(808)
	w2.import_modifications(parsed)
	check_eq(w2.get_block(cell), BlockRegistry.AIR, "importação preserva escavação")
	check_eq(w2.modified_cell_count(), 1, "uma modificação")

	w.set_block(cell, original)
	check_eq(w.modified_cell_count(), 0, "restaurar o original remove a modificação")
	# Entrada inválida é ignorada sem erro.
	w2.import_modifications({"x": 1, "3": {"abc": 2, "99999": 1, "4": 250}})
	check_eq(w2.modified_cell_count(), 0, "dados inválidos descartados")


func test_peek_matches_get() -> void:
	var w := _model(4242)
	var w2 := _model(4242)
	for y in range(0, 80, 3):
		for x in range(-1, Balance.WORLD_WIDTH + 1):
			var c := Vector2i(x, y)
			check_eq(w.peek_block(c), w2.get_block(c), "peek == get em %s" % c)


func test_damage_and_destroy() -> void:
	var w := _model(1)
	var cell := Vector2i(6, 2)
	w.set_block(cell, BlockRegistry.STONE)
	var def: BlockDef = BlockRegistry.get_def(BlockRegistry.STONE)
	var r: WorldModel.DamageResult = w.damage_cell(cell, def.max_hp * 0.5)
	check(r.applied and not r.destroyed, "dano parcial aplicado")
	check(absf(w.get_damage_ratio(cell) - 0.5) < 0.001, "50%% de dano registrado")
	check(w.damaged_cells().has(cell), "célula listada como danificada")
	r = w.damage_cell(cell, def.max_hp)
	check(r.destroyed, "bloco destruído")
	check_eq(w.get_block(cell), BlockRegistry.AIR, "vira ar")
	check(not w.damaged_cells().has(cell), "dano limpo após destruição")
	var wall := Vector2i(0, 10)
	r = w.damage_cell(wall, 99999.0)
	check(not r.applied, "rocha-mãe não recebe dano")
	check_eq(w.get_block(wall), BlockRegistry.BEDROCK, "parede intacta")
	r = w.damage_cell(Vector2i(5, -3), 10.0)
	check(not r.applied, "ar não recebe dano")


func test_damaged_cells_are_bounded() -> void:
	var w := _model(2)
	for i in Balance.MAX_DAMAGED_CELLS + 20:
		var c := Vector2i(1 + i % (Balance.WORLD_WIDTH - 2), 1 + i / (Balance.WORLD_WIDTH - 2))
		w.set_block(c, BlockRegistry.IRON)
		w.damage_cell(c, 1.0)
	check(w.damaged_cells().size() <= Balance.MAX_DAMAGED_CELLS, "lista de dano limitada")
