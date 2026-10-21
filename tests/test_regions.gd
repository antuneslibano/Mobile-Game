extends "res://tests/test_case.gd"
## Regiões do mapa mundial, classificação terreno × depósito e regras de desbloqueio.


func test_region_registry_is_valid() -> void:
	var list: Array[RegionDef] = RegionRegistry.all()
	check_eq(list.size(), 6, "seis regiões no mapa")
	var seen: Dictionary = {}
	for i in list.size():
		var r: RegionDef = list[i]
		check(not seen.has(r.id), "id único %s" % r.id)
		seen[r.id] = true
		check(not r.display_name.is_empty() and not r.description.is_empty(), "%s tem nome e descrição" % r.id)
		check(r.difficulty >= 1 and r.difficulty <= 5, "%s: dificuldade 1..5" % r.id)
		check(r.target_depth_m > 0, "%s: profundidade alvo positiva" % r.id)
		check(r.layers.size() >= 2 and r.layers.size() <= BiomeRegistry.MAX_LAYERS, "%s: 2..%d camadas" % [r.id, BiomeRegistry.MAX_LAYERS])
		check(not r.resources.is_empty(), "%s: recursos principais" % r.id)
		for k in r.resources:
			check(ResourceRegistry.get_def(k) != null, "%s: recurso %s existe" % [r.id, k])
		for h in r.hazards:
			check(RegionRegistry.HAZARDS.has(h), "%s: risco %s conhecido" % [r.id, h])
		for u in r.recommended:
			check(UpgradeRegistry.get_def(u) != null, "%s: upgrade recomendado %s existe" % [r.id, u])
		check_eq(RegionRegistry.index_of(r.id), i, "%s: índice no carrossel" % r.id)
		# Desbloqueio encadeado: cada região depende da anterior (sem moedas novas).
		if i == 0:
			check_eq(r.unlock_region, &"", "primeira região livre")
		else:
			check_eq(r.unlock_region, list[i - 1].id, "%s depende da região anterior" % r.id)
			check(r.unlock_depth_m > 0 and r.unlock_depth_m <= list[i - 1].target_depth_m, "%s: requisito alcançável" % r.id)


func test_unlock_rules_and_progress() -> void:
	var dunas: RegionDef = RegionRegistry.get_def(RegionRegistry.DUNAS)
	var vale: RegionDef = RegionRegistry.get_def(RegionRegistry.VALE)
	check(RegionRegistry.is_unlocked(vale, {}), "Vale liberado desde o início")
	check(not RegionRegistry.is_unlocked(dunas, {}), "Dunas bloqueadas sem progresso")
	check(not RegionRegistry.is_unlocked(dunas, {&"vale": dunas.unlock_depth_m - 1}), "Dunas bloqueadas 1 m antes")
	check(RegionRegistry.is_unlocked(dunas, {&"vale": dunas.unlock_depth_m}), "Dunas liberadas no requisito")
	check(RegionRegistry.requirement_text(dunas).contains(vale.display_name), "texto do requisito cita a região")
	check_eq(RegionRegistry.progress_ratio(vale, 0), 0.0, "progresso 0%")
	check_eq(RegionRegistry.progress_ratio(vale, vale.target_depth_m * 2), 1.0, "progresso limitado a 100%")
	check(absf(RegionRegistry.progress_ratio(vale, vale.target_depth_m / 2) - 0.5) < 0.01, "progresso 50%")
	check_eq(RegionRegistry.get_def(&"inexistente").id, RegionRegistry.VALE, "id desconhecido cai no Vale")


func test_terrain_is_not_collectible() -> void:
	# Terrenos não viram depósitos: no máximo mantêm a recompensa de entulho que já existia
	# (terra/pedra/basalto/pedra abissal); os terrenos novos não rendem nada.
	const BULK: Array[StringName] = [&"dirt", &"stone", &"basalt", &"abyss_stone"]
	for id in BlockRegistry.COUNT:
		var d: BlockDef = BlockRegistry.get_def(id)
		if not d.is_terrain():
			continue
		for k: StringName in d.drops:
			check(k in BULK, "%s só rende entulho (%s)" % [d.key, k])
	for key: int in [BlockRegistry.SAND, BlockRegistry.CLAY, BlockRegistry.ICE, BlockRegistry.MUD]:
		check(BlockRegistry.get_def(key).is_terrain() and BlockRegistry.get_def(key).drops.is_empty(),
				"%s é terreno sem coleta" % BlockRegistry.get_def(key).key)
	for key: int in [BlockRegistry.DIRT, BlockRegistry.STONE, BlockRegistry.MAGMA_ROCK]:
		check(BlockRegistry.get_def(key).is_terrain(), "%s é terreno" % BlockRegistry.get_def(key).key)
	# Depósitos (cobre em diante) e fóssil: coletáveis, nunca terreno.
	for key: int in [BlockRegistry.COPPER, BlockRegistry.COAL, BlockRegistry.SILVER, BlockRegistry.EMERALD,
			BlockRegistry.DIAMOND, BlockRegistry.URANIUM, BlockRegistry.FOSSIL, BlockRegistry.METEORITE]:
		var d: BlockDef = BlockRegistry.get_def(key)
		check(not d.is_terrain(), "%s é depósito" % d.key)
		check(not d.drops.is_empty(), "%s gera recurso" % d.key)
		for k: StringName in d.drops:
			check(ResourceRegistry.get_def(k) != null, "%s → recurso %s registrado" % [d.key, k])


func test_generator_follows_region_layers() -> void:
	for r in RegionRegistry.all():
		var g := WorldGenerator.new(77, r)
		var layer: BiomeDef = r.layers[1]
		var counts: Dictionary = {}
		for y in range(layer.start_row + 3, layer.start_row + 20):
			for x in range(1, Balance.WORLD_WIDTH - 1):
				var id: int = g.generate_block(x, y)
				counts[id] = int(counts.get(id, 0)) + 1
		var best: int = -1
		var best_n: int = 0
		for id: int in counts:
			if id != BlockRegistry.AIR and int(counts[id]) > best_n:
				best = id
				best_n = counts[id]
		check(best == layer.primary_block or best == layer.secondary_block,
				"%s: camada 2 dominada pelo seu material (%s)" % [r.display_name, BlockRegistry.get_def(best).key])


func test_catalog_icons_exist() -> void:
	for r in RegionRegistry.all():
		for k in r.resources:
			var tex: Texture2D = PixelArt.ore_icon(k)
			check(tex != null and tex.get_width() > 0, "ícone do catálogo para %s" % k)
		var art: Texture2D = RegionArt.texture(r)
		check(art != null and art.get_width() == RegionArt.W, "ilustração de %s" % r.display_name)
