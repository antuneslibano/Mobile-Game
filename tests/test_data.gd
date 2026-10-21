extends "res://tests/test_case.gd"


func test_block_registry_is_consistent() -> void:
	var defs: Array[BlockDef] = BlockRegistry.all()
	check_eq(defs.size(), BlockRegistry.COUNT, "quantidade de blocos")
	check(BlockRegistry.COUNT <= 256, "ids cabem em um byte")
	for i in defs.size():
		var d: BlockDef = defs[i]
		check(d != null, "bloco %d definido" % i)
		if d == null:
			continue
		check_eq(d.id, i, "id do bloco %s" % d.key)
		check(d.display_name != "", "nome do bloco %d" % i)
		if d.breakable:
			check(d.solid, "%s quebrável deve ser sólido" % d.key)
			check(d.max_hp > 0.0 and not is_inf(d.max_hp), "%s com vida finita > 0" % d.key)
			check(d.hardness >= 0.0, "%s dureza >= 0" % d.key)
		for k: Variant in d.drops:
			check(int(d.drops[k]) > 0, "%s drop %s positivo" % [d.key, k])
	check(not BlockRegistry.get_def(BlockRegistry.BEDROCK).breakable, "rocha-mãe indestrutível")
	check(not BlockRegistry.is_solid(BlockRegistry.AIR), "ar não é sólido")


func test_biomes_are_contiguous() -> void:
	var prev_end: int = 0
	for b in BiomeRegistry.COUNT:
		var biome: BiomeDef = BiomeRegistry.get_def(b)
		check_eq(biome.start_row, prev_end, "início do bioma %s" % biome.display_name)
		check(biome.end_row > biome.start_row, "faixa válida %s" % biome.display_name)
		prev_end = biome.end_row
		for entry: Array in biome.ore_table:
			check(entry.size() == 3, "entrada de minério com 3 campos")
	check_eq(prev_end, Balance.MAX_DEPTH_ROWS, "último bioma termina na profundidade máxima")
	check_eq(BiomeRegistry.id_for_row(0), BiomeRegistry.CRUST, "0 m é Crosta")
	check_eq(BiomeRegistry.id_for_row(150), BiomeRegistry.CRYSTAL_CAVES, "150 m é Cavernas")
	check_eq(BiomeRegistry.id_for_row(450), BiomeRegistry.MAGMA_ZONE, "450 m é Magmática")
	check_eq(BiomeRegistry.id_for_row(800), BiomeRegistry.ANCIENT_ABYSS, "800 m é Abismo")
