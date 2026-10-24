extends "res://tests/test_case.gd"
## Expedições (0.9): combustível, casco, calor, carvão e upgrades novos.

const DT: float = 1.0 / 60.0


func _drill(w: WorldModel, pos: Vector2, levels: Dictionary = {}) -> Drill:
	var d := Drill.new()
	d.stats = Progression.build_stats(levels)
	d.setup(w, pos, 3)
	return d


func test_vitals_rules() -> void:
	var s := DrillStats.base()
	var v := ShipVitals.new()
	v.reset(s)
	check_eq(v.fuel, Balance.FUEL_BASE, "tanque cheio")
	v.step(10.0, s, false, false, 0.0)
	check_eq(v.fuel, Balance.FUEL_BASE, "parada não gasta combustível")
	v.step(10.0, s, true, false, 0.0)
	check(absf(v.fuel - (Balance.FUEL_BASE - 10.0 * Balance.FUEL_USE_PER_SEC)) < 0.01, "ativa gasta %.1f/s" % Balance.FUEL_USE_PER_SEC)
	var before: float = v.fuel
	v.step(1.0, s, true, true, 0.0)
	check(absf((before - v.fuel) - Balance.FUEL_USE_PER_SEC * Balance.FUEL_BOOST_MULT) < 0.01, "Sobrecarga gasta mais")
	v.refuel(10000.0)
	check_eq(v.fuel, v.fuel_max, "abastecer não passa do tanque")
	check_eq(ShipVitals.heat_dps(0.0), 0.0, "dentro do limite térmico não fere")
	check(ShipVitals.heat_dps(20.0) > ShipVitals.heat_dps(5.0) and ShipVitals.heat_dps(5.0) > 0.0, "quanto mais acima do limite, mais dano")
	v.reset(s)
	var ended: bool = false
	for i in 400:
		ended = v.step(1.0, s, true, false, 0.0) or ended
	check(ended and v.is_out_of_fuel(), "sem combustível encerra a expedição")


## Guardião da câmara final: arena, ataques avisados que sobem de baixo, invulnerabilidade
## após o acerto, desvio funciona, fases e vitória.
func test_guardian_rules() -> void:
	var vale: RegionDef = RegionRegistry.get_def(RegionRegistry.VALE)
	var b: float = Balance.BLOCK_PX
	var g := FinalGuardian.new()
	g.setup(vale, true)
	check(g.alive and is_equal_approx(g.hp, RegionRegistry.guardian_hp(vale)), "guardião começa com vida cheia")
	check(g.x1 - g.x0 >= 14.0 * b, "arena larga (%.0f blocos)" % ((g.x1 - g.x0) / b))
	var r: float = Balance.DRILL_RADIUS_PX
	var standing := Vector2(g.center.x, g.body_top - r)
	check(g.on_body(standing, r), "nave apoiada no corpo")
	check(not g.on_body(standing + Vector2(0, -3.0 * b), r), "no ar acima do corpo não conta")
	var far := Vector2(g.center.x, g.body_top - 40.0 * b)
	var total: float = 0.0
	for i in 600:
		total += g.step(1.0 / 60.0, far, r)
	check(total == 0.0 and g.attacks.is_empty(), "fora da arena não há ataques")
	# Parada no meio: os ataques miram a nave e acertam (com invulnerabilidade entre acertos).
	var hits_still: int = 0
	for i in 60 * 20:
		if g.step(1.0 / 60.0, standing, r) > 0.0:
			hits_still += 1
	check(hits_still >= 4, "parada, a nave é acertada (%d acertos em 20 s)" % hits_still)
	check(hits_still <= int(20.0 / Balance.GUARDIAN_INVULN_SEC), "invulnerabilidade entre acertos")
	# Desviando (velocidade real da nave): bem menos acertos.
	g.setup(vale, true)
	var x: float = g.center.x
	var dir: float = 1.0
	var hits_dodge: int = 0
	var speed: float = Balance.DRILL_MOVE_SPEED_BLOCKS * b
	for i in 60 * 20:
		dir = g.safe_dir(x, dir, r)
		x = clampf(x + dir * speed / 60.0, g.x0 + r, g.x1 - r)
		if g.step(1.0 / 60.0, Vector2(x, g.body_top - r), r) > 0.0:
			hits_dodge += 1
	check(hits_dodge * 3 <= hits_still, "desviando, acertos caem a ≤ 1/3 (%d × %d)" % [hits_dodge, hits_still])
	check_eq(g.phase(), 0, "fase 1 com vida cheia")
	g.take_damage(g.max_hp * 0.5)
	check_eq(g.phase(), 1, "fase 2 com meia vida")
	check(not g.take_damage(g.max_hp * 0.2) and g.phase() == 2, "fase 3 no fim")
	check(g.take_damage(g.max_hp) and not g.alive and g.attacks.is_empty(), "vida zerada: guardião vencido")
	check(not g.take_damage(10.0), "vencido não morre de novo")
	var abismo: RegionDef = RegionRegistry.get_def(RegionRegistry.ABISMO)
	check(RegionRegistry.guardian_hp(abismo) > RegionRegistry.guardian_hp(vale) and RegionRegistry.guardian_hit_damage(abismo) > RegionRegistry.guardian_hit_damage(vale),
			"guardiões mais fortes nas regiões difíceis")
	g.free()


## 0.21: perseguição na arena: sementes ferem o guardião, espinhos acertam quem fica
## parado, batimento e arena só com terra macia e sementes.
func test_boss_chase() -> void:
	var vale: RegionDef = RegionRegistry.get_def(RegionRegistry.VALE)
	var b: float = Balance.BLOCK_PX
	var g := FinalGuardian.new()
	g.setup(vale, true)
	var c := BossChase.new()
	var view := Rect2(Vector2(0, 0), Vector2(720, 1280))
	var ship := Vector2(12 * b, 900)
	c.start(g, ship, view)
	check(c.active and c.seeds_needed == BossChase.seeds_for(vale), "perseguição começa (%d sementes)" % c.seeds_needed)
	var beats: Array[int] = [0]
	c.beat.connect(func(_s: float) -> void: beats[0] += 1)
	var hits: int = 0
	for i in 60 * 20:
		if c.step(1.0 / 60.0, ship, Vector2.ZERO, Balance.DRILL_RADIUS_PX, view) > 0.0:
			hits += 1
	check(hits >= 3, "parada, a nave leva espinhos (%d)" % hits)
	check(hits <= int(20.0 / Balance.GUARDIAN_INVULN_SEC), "invulnerabilidade entre acertos")
	check(beats[0] >= 12, "o núcleo bate como um coração (%d batidas)" % beats[0])
	check(c.core.y < ship.y, "o guardião fica em cima da nave")
	var killed: bool = false
	for i in c.seeds_needed:
		killed = c.seed_broken()
	check(killed and not g.alive, "quebrar todas as sementes vence o guardião")
	# Arena: salão aberto em cima, só terra macia e uma semente a cada ARENA_SEED_GAP fileiras.
	var w := WorldModel.new(77, vale)
	w.generator.arena = true
	var seeds: int = 0
	var other: int = 0
	for y in range(0, 120):
		for x in range(1, Balance.WORLD_WIDTH - 1):
			var id: int = w.generator.arena_block(x, y)
			if id == BlockRegistry.BOSS_SEED:
				seeds += 1
			elif not id in [BlockRegistry.AIR, BlockRegistry.ARENA_SOIL]:
				other += 1
	check(seeds == (120 - WorldGenerator.ARENA_FIRST_SEED_ROW - 1) / WorldGenerator.ARENA_SEED_GAP + 1 and other == 0, "arena: só terra e %d sementes" % seeds)
	check(w.peek_cell(Vector2i(Balance.WORLD_CELLS_X / 2, 2)) == BlockRegistry.AIR, "arena aberta no topo")
	check(BlockRegistry.get_def(BlockRegistry.ARENA_SOIL).max_hp < BlockRegistry.get_def(BlockRegistry.DIRT).max_hp, "terra da arena é macia")
	# 0.22.1: 20 sementes, duras (vários golpes), mais duras nas regiões difíceis.
	check_eq(BossChase.seeds_for(vale), 20, "20 sementes para vencer")
	var abismo: RegionDef = RegionRegistry.get_def(RegionRegistry.ABISMO)
	check(BossChase.seed_hp_mult(abismo) > BossChase.seed_hp_mult(vale), "sementes mais duras no Abismo")
	var y0: int = WorldGenerator.ARENA_FIRST_SEED_ROW
	var sx: int = w.generator.arena_seed_x(y0)
	var core := Vector2i(sx * Balance.CELL_SUB + 2, y0 * Balance.CELL_SUB + 2)
	w.get_chunk(WorldModel.chunk_index_for_row(core.y))
	w.hp_scale = {BlockRegistry.BOSS_SEED: BossChase.seed_hp_mult(vale)}
	var seed_hits: int = 0
	var dmg: float = 15.0  # broca típica ao chegar no guardião do Vale
	while w.peek_cell(core) == BlockRegistry.BOSS_SEED and seed_hits < 200:
		w.dig_cells([core] as Array[Vector2i], dmg)
		seed_hits += 1
	check(seed_hits >= 8 and seed_hits <= 30, "semente pede vários golpes (%d com dano %.0f)" % [seed_hits, dmg])
	var hits_strong: int = 0
	w.set_cell(core, BlockRegistry.BOSS_SEED)
	while w.peek_cell(core) == BlockRegistry.BOSS_SEED and hits_strong < 200:
		w.dig_cells([core] as Array[Vector2i], dmg * 3.0)
		hits_strong += 1
	check(hits_strong < seed_hits, "broca mais forte quebra mais rápido (%d × %d)" % [hits_strong, seed_hits])
	c.free()
	g.free()


func test_fuel_upgrades() -> void:
	var s: DrillStats = Progression.build_stats({&"fuel_tank": 2, &"fuel_eff": 2, &"hull": 3})
	check(s.fuel_max > Balance.FUEL_BASE, "Tanque aumenta o combustível (%.0f)" % s.fuel_max)
	check(s.fuel_use < 1.0, "Eficiência reduz o consumo (%.2f)" % s.fuel_use)
	check(s.hull_max > Balance.HULL_BASE, "Blindagem aumenta o casco (%.0f)" % s.hull_max)
	for id: StringName in [&"fuel_tank", &"fuel_eff", &"hull"]:
		check(UpgradeRegistry.get_def(id) != null, "upgrade %s registrado" % id)


func test_coal_refuels_and_drill_strands() -> void:
	var w := WorldModel.new(5)
	w.threaded = false
	var start := Vector2(400, 300)
	for x in range(-5, 6):
		for y in range(-3, 14):
			w.set_cell(WorldModel.world_to_cell(start) + Vector2i(x, y), BlockRegistry.COAL)
	w.fill_circle(start, 30.0, BlockRegistry.AIR)
	var d := _drill(w, start)
	d.vitals.fuel = 20.0
	var gained: Array[float] = [0.0]
	d.refueled.connect(func(f: float) -> void: gained[0] += f)
	var it := DrillIntent.new()
	it.aim = Vector2.DOWN
	for i in 240:
		d.physics_step(DT, it)
	check(gained[0] > 0.0, "carvão abastece (+%.1f)" % gained[0])
	check(Drill.fuel_for({BlockRegistry.COAL: Balance.CELLS_PER_BLOCK}) == BlockRegistry.get_def(BlockRegistry.COAL).fuel, "um bloco de carvão = combustível do bloco")
	# Sem combustível: para e avisa (resgate).
	var reasons: Array[StringName] = []
	d.stranded.connect(func(r: StringName) -> void: reasons.append(r))
	d.vitals.fuel = 0.01
	for i in 30:
		d.physics_step(DT, it)
	check(d.disabled and reasons.size() == 1 and reasons[0] == &"fuel", "sem combustível: nave parada e resgate pedido")
	var y: float = d.position.y
	for i in 60:
		d.physics_step(DT, it)
	check(d.position.y <= y + 30.0, "parada não cava mais")
	d.free()


func test_heat_damages_hull_in_abismo() -> void:
	var abismo: RegionDef = RegionRegistry.get_def(RegionRegistry.ABISMO)
	HeatRules.configure(abismo)
	var w := WorldModel.new(9, abismo)
	w.threaded = false
	var pos := Vector2(400, 260.5 * Balance.BLOCK_PX)
	w.fill_circle(pos, 40.0, BlockRegistry.AIR)
	var d := _drill(w, pos)
	var temp: float = HeatRules.temp_at(d.depth_m())
	check(temp > d.stats.temp_limit + 20.0, "260 m no Abismo passa do limite da nave sem Refrigeração (%.0f °C)" % temp)
	var reasons: Array[StringName] = []
	d.stranded.connect(func(r: StringName) -> void: reasons.append(r))
	var it := DrillIntent.new()
	for i in 60 * 60:
		d.physics_step(DT, it)
		if d.disabled:
			break
	check(d.vitals.hull_dps > 0.0 or d.disabled, "o casco sofre com o calor")
	check(reasons.size() == 1 and reasons[0] == &"hull", "casco destruído pelo calor pede resgate")
	HeatRules.configure(RegionRegistry.get_def(RegionRegistry.VALE))
	d.free()
