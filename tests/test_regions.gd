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


func test_unlock_rules_and_objectives() -> void:
	var dunas: RegionDef = RegionRegistry.get_def(RegionRegistry.DUNAS)
	var vale: RegionDef = RegionRegistry.get_def(RegionRegistry.VALE)
	check(RegionRegistry.is_unlocked(vale, {}), "Vale liberado desde o início")
	check(not RegionRegistry.is_unlocked(dunas, {}), "Dunas bloqueadas sem a câmara final do Vale")
	check(RegionRegistry.is_unlocked(dunas, {&"vale": true}), "Dunas liberadas com o Vale concluído")
	check(RegionRegistry.requirement_text(dunas).contains(vale.final_name), "requisito cita a câmara final")
	# Migração (salvamentos anteriores à 0.9): regra antiga por profundidade.
	check(RegionRegistry.was_unlocked_by_depth(dunas, {&"vale": dunas.unlock_depth_m}), "regra antiga reconhecida")
	check_eq(RegionRegistry.get_def(&"inexistente").id, RegionRegistry.VALE, "id desconhecido cai no Vale")
	for r in RegionRegistry.all():
		check(not r.final_name.is_empty(), "%s tem câmara final" % r.id)
		check_eq(r.objectives.size(), 7, "%s: 1 principal + 3 pesquisa + 3 estrelas" % r.id)
		var groups: Dictionary = {}
		for o: Dictionary in r.objectives:
			groups[o.group] = int(groups.get(o.group, 0)) + 1
			if o.kind == &"collect":
				check(ResourceRegistry.get_def(o.key) != null, "%s: recurso %s existe" % [r.id, o.key])
		check(groups.get(&"main", 0) == 1 and groups.get(&"research", 0) == 3 and groups.get(&"star", 0) == 3, "%s: grupos de objetivos" % r.id)
		var reach: Array[BiomeDef] = RegionRegistry.reachable_layers(r)
		check(not reach.is_empty() and reach[-1].start_row < r.target_depth_m, "%s: camadas até o fundo" % r.id)


## Fundo da região: rocha-mãe a partir do target_depth_m, com a câmara final (salão e
## relíquia no piso) no centro, logo acima.
func test_region_bottom_and_final_chamber() -> void:
	for r in RegionRegistry.all():
		var g := WorldGenerator.new(31, r)
		var cx: int = RegionRegistry.chamber_center_x()
		for x in range(1, Balance.WORLD_WIDTH - 1):
			check_eq(g.generate_block(x, r.target_depth_m), BlockRegistry.BEDROCK, "%s: fundo é rocha-mãe" % r.id)
		var mid: int = RegionRegistry.chamber_top(r) + Balance.FINAL_CHAMBER_ROWS / 2
		check_eq(g.generate_block(cx, mid), BlockRegistry.AIR, "%s: câmara final aberta" % r.id)
		check_eq(g.generate_block(cx, r.target_depth_m - 1), BlockRegistry.ARTIFACT, "%s: relíquia no piso da câmara" % r.id)


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
		check(not d.drops.is_empty() or d.fuel > 0.0, "%s gera recurso (ou combustível)" % d.key)
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
