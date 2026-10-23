extends "res://tests/test_case.gd"
## 0.11: criaturas do Vale (surgimento, comportamento, dano, amostras) e visual da nave.

const DT: float = 1.0 / 60.0


func _world() -> WorldModel:
	var vale: RegionDef = RegionRegistry.get_def(RegionRegistry.VALE)
	var w := WorldModel.new(2024, vale)
	w.threaded = false
	return w


func test_spawns_are_deterministic_and_by_depth() -> void:
	var vale: RegionDef = RegionRegistry.get_def(RegionRegistry.VALE)
	var w := _world()
	var total: Dictionary = {}
	for i in 30:
		w.get_chunk(i)
		var a: Array[Dictionary] = CreatureManager.plan(w, i, vale, 77)
		var b: Array[Dictionary] = CreatureManager.plan(w, i, vale, 77)
		check_eq(a.size(), b.size(), "chunk %d: mesmo plano com a mesma seed" % i)
		for e: Dictionary in a:
			total[e.species] = int(total.get(e.species, 0)) + 1
			var depth: int = int(e.pos.y / Balance.BLOCK_PX)
			check(depth >= int(CreatureManager.SPAWNS[&"vale"][e.species]) - 1, "%s nasce na profundidade certa (%d m)" % [e.species, depth])
		w.unload_outside(i - 1, i + 1)
	note("criaturas em 30 chunks do Vale: %s" % str(total))
	for sp in Creature.ORDER:
		check(int(total.get(sp, 0)) > 0, "o Vale tem %s" % sp)
	check(CreatureManager.plan(w, 3, RegionRegistry.get_def(RegionRegistry.DUNAS), 77).is_empty(), "outras regiões ainda sem criaturas")


func test_behaviours() -> void:
	var w := _world()
	var b: float = Balance.BLOCK_PX
	# Caverna aberta artificial a 100 m.
	var cave := Vector2(12 * b, 100 * b)
	for i in 6:
		w.get_chunk(WorldModel.chunk_index_for_row(int(cave.y / Balance.CELL_PX)) - 1 + i / 2)
	w.fill_circle(cave, 6.0 * b, BlockRegistry.AIR)
	w.fill_circle(cave + Vector2(0, 7.5 * b), 1.6 * b, BlockRegistry.STONE)
	# Vaga-lume foge da nave.
	var ff := Creature.new(&"firefly", cave, 1)
	var ship: Vector2 = cave + Vector2(1.5 * b, 0)
	var d0: float = ff.pos.distance_to(ship)
	for i in 60:
		ff.step(DT, w, ship, Balance.DRILL_RADIUS_PX)
	check(ff.pos.distance_to(ship) > d0, "vaga-lume foge da nave")
	# Aranha ataca quem chega perto e morde (com recarga).
	var sp := Creature.new(&"spider", cave + Vector2(-2.0 * b, 0), 2)
	var bites: float = 0.0
	for i in 240:
		bites += sp.step(DT, w, cave + Vector2(1.0 * b, 0), Balance.DRILL_RADIUS_PX)
	check(bites > 0.0 and bites <= 4.0 * float(Creature.DEFS[&"spider"].dmg) + 0.01, "aranha morde a nave e espera a recarga (%.0f)" % bites)
	var far := Creature.new(&"spider", cave, 3)
	for i in 120:
		far.step(DT, w, cave + Vector2(20.0 * b, 0), Balance.DRILL_RADIUS_PX)
	check(far.pos.distance_to(cave) < 2.0, "aranha fica no veio quando a nave está longe")
	# Minhoca abre túneis no terreno (mas não na rocha-mãe).
	var deep := Vector2(12 * b, 300 * b)
	w.get_chunk(WorldModel.chunk_index_for_row(int(deep.y / Balance.CELL_PX)))
	var wm := Creature.new(&"worm", deep, 4)
	var before: int = w.modified_cell_count()
	for i in 180:
		wm.step(DT, w, deep + Vector2(40.0 * b, 0), Balance.DRILL_RADIUS_PX)
	check(w.modified_cell_count() > before + 10, "minhoca escava o próprio túnel")
	check(wm.segments.size() == Creature.WORM_SEGMENTS, "minhoca tem corpo segmentado")
	# Dano e morte.
	check(not wm.take_damage(10.0) and wm.alive, "minhoca aguenta um golpe")
	check(wm.take_damage(9999.0) and not wm.alive, "minhoca derrotada")


func test_manager_damage_and_samples() -> void:
	var w := _world()
	var b: float = Balance.BLOCK_PX
	var m := CreatureManager.new()
	m.setup(w, RegionRegistry.get_def(RegionRegistry.VALE), 5)
	var pos := Vector2(12 * b, 80 * b)
	w.get_chunk(WorldModel.chunk_index_for_row(int(pos.y / Balance.CELL_PX)))
	w.fill_circle(pos, 4.0 * b, BlockRegistry.AIR)
	m.creatures.clear()
	m.creatures.append(Creature.new(&"mole", pos, 9))
	var killed: Array[StringName] = []
	m.creature_defeated.connect(func(sp: StringName, _at: Vector2) -> void: killed.append(sp))
	m.area_damage(pos, 20.0, 9999.0, 1.0)
	check(killed.size() == 1 and killed[0] == &"mole", "pulso/drone vencem criaturas")
	check_eq(m.alive_count(), 0, "criatura vencida sai do mundo")
	m.free()
	check(Creature.DEFS[&"spider"].samples > 0 and Creature.DEFS[&"firefly"].samples == 0, "amostras: hostis rendem, vaga-lume só cataloga")
	var drone: UpgradeDef = UpgradeRegistry.get_def(&"drone")
	check(Recipes.materials(drone, 5).has(&"leather"), "peças orgânicas pedem couro")


func test_ship_looks() -> void:
	var e := Economy.new()
	var base: Dictionary = ShipLooks.resolve({}, e, {})
	check_eq(base[&"drill"], &"steel", "broca de aço no começo")
	e.set_level(&"damage", 8)
	e.set_level(&"hull", 4)
	var auto: Dictionary = ShipLooks.resolve({}, e, {})
	check_eq(auto[&"drill"], &"crystal", "a broca evolui sozinha com o nível")
	check_eq(auto[&"hull"], &"armored", "casco blindado com Blindagem Nv. 4")
	var chosen: Dictionary = ShipLooks.resolve({&"drill": &"gold"}, e, {})
	check_eq(chosen[&"drill"], &"gold", "escolha do Hangar vale se liberada")
	check_eq(ShipLooks.resolve({&"drill": &"plasma"}, e, {})[&"drill"], &"crystal", "opção bloqueada não vale")
	check_eq(ShipLooks.resolve({}, e, {&"vale": true})[&"drill"], &"root", "guardião do Vale libera a broca de raiz")
	e.discovered[&"ruby"] = true
	check_eq(ShipLooks.resolve({&"paint": &"ruby"}, e, {})[&"paint"], &"ruby", "pintura de rubi ao descobrir rubi")
	var a: Image = ShipArt.build(0, base)
	var c: Image = ShipArt.build(0, auto)
	check(a.get_data() != c.get_data(), "visual diferente muda o sprite")
	check(ShipArt.frame(0, auto) == ShipArt.frame(0, auto), "sprite do visual em cache")


## 0.12: a broca só quebra minérios até o seu nível.
func test_drill_tiers() -> void:
	check_eq(MiningRules.tier_for_level(0), 0, "broca inicial: nível 0")
	check(MiningRules.can_break(BlockRegistry.COPPER, 0) and not MiningRules.can_break(BlockRegistry.IRON, 0), "broca inicial quebra cobre, não ferro")
	var t: int = MiningRules.tier_for_level(Balance.DRILL_TIER_LEVELS[1])
	check(MiningRules.can_break(BlockRegistry.IRON, t) and not MiningRules.can_break(BlockRegistry.GOLD, t), "aprimorada quebra ferro, não ouro")
	check(MiningRules.can_break(BlockRegistry.DIRT, 0) and MiningRules.can_break(BlockRegistry.CHEST, 0), "terreno e baús com qualquer broca")
	check_eq(Progression.build_stats({&"damage": Balance.DRILL_TIER_LEVELS[2]}).drill_tier, 2, "nível da Broca define o nível de corte")
	var w := WorldModel.new(5, RegionRegistry.get_def(RegionRegistry.VALE))
	w.threaded = false
	var c := Vector2i(40, 200)
	w.get_chunk(WorldModel.chunk_index_for_row(c.y))
	w.set_cell(c, BlockRegistry.GOLD)
	var res: WorldModel.DigResult = w.dig_cells([c] as Array[Vector2i], 9999.0, -INF, 1)
	check(res.too_hard == BlockRegistry.GOLD and w.get_cell(c) == BlockRegistry.GOLD, "ouro resiste à broca fraca")
	res = w.dig_cells([c] as Array[Vector2i], 9999.0, -INF, 2)
	check(w.get_cell(c) == BlockRegistry.AIR, "broca dourada quebra o ouro")


## 0.12: baús com raridade (cor) e plantas de visual exclusivo.
func test_chests_and_blueprints() -> void:
	var counts: Array[int] = [0, 0, 0]
	for i in 2000:
		counts[Chests.rarity(Vector2i(i % 24, i / 24), 99, 300)] += 1
	note("raridade em 2000 baús a 300 m: %s" % str(counts))
	check(counts[0] > counts[1] and counts[1] > counts[2] and counts[2] > 0, "comum > raro > lendário")
	var deep: int = 0
	var shallow: int = 0
	for i in 2000:
		if Chests.rarity(Vector2i(i % 24, i / 24), 99, 590) == Chests.LEGENDARY:
			deep += 1
		if Chests.rarity(Vector2i(i % 24, i / 24), 99, 20) == Chests.LEGENDARY:
			shallow += 1
	check(deep > shallow, "mais fundo, mais lendários (%d × %d)" % [deep, shallow])
	var owned: Dictionary = {}
	var r: Dictionary = Chests.open(Chests.LEGENDARY, Vector2i(3, 40), 1, 40, owned)
	check(StringName(r.blueprint) != &"" and int(r.drops.get(&"crystal", 0)) > 0, "lendário traz planta e cristais")
	for id: StringName in Chests.BLUEPRINTS:
		owned[id] = true
	r = Chests.open(Chests.LEGENDARY, Vector2i(3, 40), 1, 40, owned)
	check(StringName(r.blueprint) == &"", "com todas as plantas, vira bônus de cristais")
	var e := Economy.new()
	e.blueprints[&"bp_ember"] = true
	check_eq(ShipLooks.resolve({&"drill": &"ember"}, e, {})[&"drill"], &"ember", "planta libera o visual no Hangar")
	check_eq(ShipLooks.resolve({}, e, {})[&"drill"], &"steel", "planta não troca o visual sozinha")
	check(Economy.from_dict(e.to_dict()).blueprints.has(&"bp_ember"), "plantas salvas")
	check(ShipArt.build(0, {&"drill": &"ember", &"hull": &"gilded", &"engine": &"firefly", &"paint": &"chrome"}).get_width() == ShipArt.W, "visuais de planta desenham")
	# 0.14: tocar no baú coleta o bloco inteiro de uma vez (não precisa quebrar aos poucos).
	var w := WorldModel.new(12, RegionRegistry.get_def(RegionRegistry.VALE))
	var sub: int = Balance.CELL_SUB
	var blk := Vector2i(10, 30)
	w.get_chunk(WorldModel.chunk_index_for_row(blk.y * sub))
	for y in sub:
		for x in sub:
			w.set_cell(blk * sub + Vector2i(x, y), BlockRegistry.CHEST)
	var one: Array[Vector2i] = [blk * sub]
	var dr: WorldModel.DigResult = w.dig_cells(one, 0.01)
	var left: int = 0
	for y in sub:
		for x in sub:
			if w.peek_cell(blk * sub + Vector2i(x, y)) == BlockRegistry.CHEST:
				left += 1
	check(left == 0 and dr.chest_blocks == [blk], "um toque coleta o baú inteiro (%d células restantes)" % left)


## 0.12: sons sintetizados existem e têm o formato certo.
func test_sounds() -> void:
	var s := load("res://scripts/audio/sfx.gd").new() as Node
	s.call("_build_all")
	for n: StringName in [&"drill", &"engine", &"hit", &"break", &"clank", &"pickup", &"chest", &"ship_hit", &"creature", &"boost", &"click", &"whoosh", &"firefly", &"mole", &"spider", &"worm", &"bite", &"boss_hit"]:
		var st: AudioStreamWAV = (s.get("_streams") as Dictionary).get(n)
		check(st != null and st.data.size() > 100, "som %s gerado" % n)
	for n: StringName in [&"shutter", &"door_slam"]:
		check((s.get("_streams") as Dictionary).has(n), "som %s gerado" % n)
	# 0.15: trilha normalizada (pico ~90%) tocando a 25% do volume da broca.
	s.call("_build_music_thread")
	var music: AudioStreamWAV = s.get("_music_wav")
	var peak: int = 0
	for i in range(0, music.data.size() / 2, 7):
		peak = maxi(peak, absi(music.data.decode_s16(i * 2)))
	check(peak > 26000, "trilha normalizada (pico %d)" % peak)
	check(is_equal_approx(db_to_linear(float(s.get("music_db"))) / db_to_linear(float(s.get("DRILL_DB"))), 0.25), "trilha a 25% do volume da broca")
	var drill: AudioStreamWAV = (s.get("_streams") as Dictionary)[&"drill"]
	check(drill.loop_mode == AudioStreamWAV.LOOP_FORWARD, "broca em loop")
	s.free()


## 0.16: quebrar qualquer pedaço de minério rende pelo menos um item.
func test_ore_drops_whole() -> void:
	var w := WorldModel.new(77, RegionRegistry.get_def(RegionRegistry.VALE))
	var tested: int = 0
	var bad: int = 0
	for cy in range(Balance.CHUNK_CELLS_Y, Balance.CHUNK_CELLS_Y * 8):
		if tested >= 25:
			break
		for cx in range(2, Balance.WORLD_CELLS_X - 2, 3):
			var c := Vector2i(cx, cy)
			var def: BlockDef = BlockRegistry.get_def(w.peek_cell(c))
			if not WorldModel._whole_block(def) or def.drops.is_empty():
				continue
			var cells: Array[Vector2i] = [c]
			var r: WorldModel.DigResult = w.dig_cells(cells, 99999.0)
			var drops: Dictionary = Drill.drops_for(r.drop_counts())
			var best: float = 0.0
			for k: StringName in drops:
				best = maxf(best, float(drops[k]))
			tested += 1
			if best < 1.0 and r.removed() >= Balance.CELLS_PER_BLOCK / 2:
				bad += 1
			if tested >= 25:
				break
	check(tested >= 10, "achou minérios para testar (%d)" % tested)
	check(bad == 0, "golpe em minério rende item inteiro (%d sem drop)" % bad)


## 0.17: trilha gerada aos poucos (modo de compatibilidade) igual à gerada de uma vez.
func test_music_synth_chunked() -> void:
	var whole := MusicSynth.new()
	whole.fill(whole.n * 8)
	whole.fill(whole.n * 8)
	var parts := MusicSynth.new()
	var steps: int = 0
	while not parts.fill(3000) and steps < 1000:
		steps += 1
	check(whole.done() and parts.done(), "as duas gerações terminam (%d passos)" % steps)
	check(whole.result().data == parts.result().data, "mesmo áudio gerando aos poucos")
	# 0.18: tema do guardião (loop de 16 s, diferente da trilha principal).
	var boss := BossSynth.new()
	var bs: int = 0
	while not boss.fill(4000) and bs < 1000:
		bs += 1
	var bw: AudioStreamWAV = boss.result()
	check(boss.done() and bw.loop_mode == AudioStreamWAV.LOOP_FORWARD and bw.loop_end == int(BossSynth.BOSS_SECONDS * MusicSynth.RATE), "tema do guardião em loop de 16 s")
	check(bw.data != whole.result().data.slice(0, bw.data.size()), "tema do guardião é outra música")


## 0.17: área segura e largura máxima do conteúdo.
func test_safe_area_margins() -> void:
	var old: Vector4 = SafeArea.debug_insets
	SafeArea.debug_insets = Vector4(90, 60, 0, 0)
	var vp := SubViewport.new()
	vp.size = Vector2i(720, 1280)
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(vp)
	check_eq(SafeArea.insets(vp), Vector4(90, 60, 0, 0), "margens simuladas")
	var r: Rect2 = SafeArea.rect(vp)
	check(r.position.y == 90.0 and r.end.y == 1220.0, "retângulo seguro desconta notch e barra")
	check_eq(SafeArea.side_margins(vp, 4.0), Vector2(4, 4), "celular: só a margem base nas laterais")
	vp.size = Vector2i(1200, 1280)
	var lr: Vector2 = SafeArea.side_margins(vp, 4.0)
	check(is_equal_approx(1200.0 - lr.x - lr.y, SafeArea.MAX_CONTENT_W) and is_equal_approx(lr.x, lr.y), "tablet: conteúdo centralizado com largura máxima")
	vp.queue_free()
	SafeArea.debug_insets = old


## 0.19: desgaste da nave (sujeira, ferrugem, amassados).
func test_wear_rules() -> void:
	var w: Dictionary = WearRules.fresh()
	check_eq(WearRules.penalty(w), 0.0, "nave nova sem perda")
	WearRules.add_dig(w, 200 * Balance.CELLS_PER_BLOCK)
	check(float(w[&"dirt"]) > float(w[&"rust"]) and float(w[&"rust"]) > 0.0, "cavar suja mais do que enferruja")
	WearRules.add_dig(w, 100000 * Balance.CELLS_PER_BLOCK)
	check(is_equal_approx(float(w[&"dirt"]), 1.0) and is_equal_approx(WearRules.penalty(w), Balance.WEAR_PENALTY_MAX), "desgaste limitado")
	WearRules.add_damage(w, 50.0, 100.0)
	check(float(w[&"dents"]) > 0.0 and WearRules.hull_start_ratio(w) < 1.0, "dano amassa e o casco começa ferido")
	check(WearRules.needs_care(w), "nave desgastada pede cuidado")
	var back: Dictionary = WearRules.from_dict(JSON.parse_string(JSON.stringify(WearRules.to_dict(w))))
	check(absf(float(back[&"dents"]) - float(w[&"dents"])) < 0.01, "desgaste salvo e restaurado")


## 0.15: plantas bioluminescentes nas cavernas do Vale (e só no Vale), espaçadas.
func test_bio_plants() -> void:
	var total: int = 0
	var other: int = 0
	var too_close: bool = false
	var w := WorldModel.new(77, RegionRegistry.get_def(RegionRegistry.VALE))
	var w2 := WorldModel.new(77, RegionRegistry.get_def(&"dunas"))
	for idx in range(2, 20):
		var bios: Array[Vector2i] = []
		var plan: Dictionary = CaveDecor.plan(w, idx, &"vale")
		for c: Vector2i in plan:
			if CaveDecor.is_bio(plan[c]):
				for o in bios:
					if absi(o.x - c.x) < CaveDecor.BIO_SPACING and absi(o.y - c.y) < CaveDecor.BIO_SPACING:
						too_close = true
				bios.append(c)
		total += bios.size()
		var plan2: Dictionary = CaveDecor.plan(w2, idx, &"dunas")
		for c: Vector2i in plan2:
			if CaveDecor.is_bio(plan2[c]):
				other += 1
	note("plantas bioluminescentes em 18 chunks do Vale: %d" % total)
	check(total >= 5 and total <= 120, "Vale tem plantas bioluminescentes, mas poucas (%d)" % total)
	check(not too_close, "plantas espaçadas")
	check_eq(other, 0, "nenhuma planta bioluminescente fora do Vale")


## 0.13: forçar minério duro demais esquenta a broca e fere o casco.
func test_drill_strain() -> void:
	var w := WorldModel.new(8, RegionRegistry.get_def(RegionRegistry.VALE))
	w.threaded = false
	var b: float = Balance.BLOCK_PX
	var p := Vector2(12 * b, 120 * b)
	w.get_chunk(WorldModel.chunk_index_for_row(int(p.y / Balance.CELL_PX)))
	w.fill_circle(p, 3.0 * b, BlockRegistry.GOLD)
	w.fill_circle(p, 30.0, BlockRegistry.AIR)
	var d := Drill.new()
	d.stats = Progression.build_stats({})
	d.setup(w, p, 1)
	var it := DrillIntent.new()
	it.aim = Vector2.DOWN
	var hull0: float = d.vitals.hull
	for i in 60 * 6:
		d.physics_step(1.0 / 60.0, it)
	check(d.strain > 1.0, "forçar ouro com broca fraca superaquece (%.2f)" % d.strain)
	check(d.vitals.hull < hull0, "broca superaquecida fere o casco (%.0f)" % d.vitals.hull)
	it.aim = Vector2.ZERO
	for i in 60 * 5:
		d.physics_step(1.0 / 60.0, it)
	check(d.strain < 0.2, "parando de forçar, a broca esfria")
	d.free()


## 0.13: no ar, alternar diagonais para cima não faz a nave voar.
func test_no_flying_zigzag() -> void:
	var w := WorldModel.new(9, RegionRegistry.get_def(RegionRegistry.VALE))
	w.threaded = false
	var b: float = Balance.BLOCK_PX
	var p := Vector2(12 * b, 200 * b)
	w.get_chunk(WorldModel.chunk_index_for_row(int(p.y / Balance.CELL_PX)))
	w.get_chunk(WorldModel.chunk_index_for_row(int(p.y / Balance.CELL_PX)) - 1)
	w.fill_circle(p, 7.0 * b, BlockRegistry.AIR)
	var d := Drill.new()
	d.stats = Progression.build_stats({})
	d.setup(w, p + Vector2(0, 5.0 * b), 1)
	var it := DrillIntent.new()
	var low: float = d.position.y
	for i in 60 * 6:
		it.aim = Vector2(1, -1).normalized() if (i / 20) % 2 == 0 else Vector2(-1, -1).normalized()
		d.physics_step(1.0 / 60.0, it)
		low = minf(low, d.position.y)
	check(low > p.y + 5.0 * b - 2.0 * b, "zigue-zague no ar não sobe (topo %.0f, partida %.0f)" % [low, p.y + 5.0 * b])
	d.free()


## 0.13: névoa por profundidade e sonar marcando minérios.
func test_fog_and_sonar() -> void:
	check_eq(FogLayer.strength_at(0), 0.0, "superfície sem névoa")
	check_eq(FogLayer.strength_at(int(Balance.FOG_FULL_DEPTH_M) + 5), 1.0, "subsolo no escuro")
	var w := WorldModel.new(10, RegionRegistry.get_def(RegionRegistry.VALE))
	w.threaded = false
	var b: float = Balance.BLOCK_PX
	var p := Vector2(12 * b, 60 * b)
	for i in range(2, 7):
		w.get_chunk(i)
	w.set_cell(WorldModel.world_to_cell(p + Vector2(4 * b, 0)), BlockRegistry.COPPER)
	for dx in range(-2, 2):
		for dy in range(-2, 2):
			w.set_cell(WorldModel.world_to_cell(p + Vector2(4 * b, 0)) + Vector2i(dx, dy), BlockRegistry.COPPER)
	var d := Drill.new()
	d.stats = Progression.build_stats({})
	d.setup(w, p, 1)
	var s := SonarOverlay.new()
	s.world = w
	s.drill = d
	check(s.is_ready(), "sonar pronto")
	check(s.ping() and not s.is_ready(), "sonar dispara e entra em recarga")
	check(not s.ping(), "na recarga não dispara de novo")
	for i in 120:
		s.step(1.0 / 60.0)
	var found: bool = false
	for bl: Dictionary in s.blips:
		if (bl.pos as Vector2).distance_to(p + Vector2(4.5 * b, 0.5 * b)) < 2.0 * b:
			found = true
	check(found, "sonar marca o minério próximo (%d sinais)" % s.blips.size())
	for i in 60 * int(Balance.SONAR_COOLDOWN + 1):
		s.step(1.0 / 60.0)
	check(s.is_ready() and s.blips.is_empty(), "recarga volta e os sinais somem")
	s.free()
	d.free()
