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
	check(Recipes.materials(drone, 5).has(&"bio_sample"), "peças orgânicas pedem amostras biológicas")


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


## 0.12: sons sintetizados existem e têm o formato certo.
func test_sounds() -> void:
	var s := load("res://scripts/audio/sfx.gd").new() as Node
	s.call("_build_all")
	for n: StringName in [&"drill", &"engine", &"hit", &"break", &"clank", &"pickup", &"chest", &"ship_hit", &"creature", &"boost", &"click"]:
		var st: AudioStreamWAV = (s.get("_streams") as Dictionary).get(n)
		check(st != null and st.data.size() > 100, "som %s gerado" % n)
	var drill: AudioStreamWAV = (s.get("_streams") as Dictionary)[&"drill"]
	check(drill.loop_mode == AudioStreamWAV.LOOP_FORWARD, "broca em loop")
	s.free()
