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
