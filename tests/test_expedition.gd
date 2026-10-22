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
	check_eq(ShipVitals.heat_dps(Balance.HEAT_SAFE_LEVEL, 0.0), 0.0, "calor até o nível seguro não fere")
	check(ShipVitals.heat_dps(2.0, 0.0) > 0.0, "calor alto fere o casco")
	check(ShipVitals.heat_dps(2.0, 0.5) < ShipVitals.heat_dps(2.0, 0.0), "refrigeração reduz o dano")
	v.reset(s)
	var ended: bool = false
	for i in 400:
		ended = v.step(1.0, s, true, false, 0.0) or ended
	check(ended and v.is_out_of_fuel(), "sem combustível encerra a expedição")


## Guardião da câmara final: pulsos só na arena e no alcance; a broca o vence.
func test_guardian_rules() -> void:
	var vale: RegionDef = RegionRegistry.get_def(RegionRegistry.VALE)
	var g := FinalGuardian.new()
	g.setup(vale, true)
	check(g.alive and is_equal_approx(g.hp, RegionRegistry.guardian_hp(vale)), "guardião começa com vida cheia")
	check(g.center.y < vale.target_depth_m * Balance.BLOCK_PX and g.center.y > RegionRegistry.chamber_top(vale) * Balance.BLOCK_PX, "guardião no piso da câmara final")
	var far: Vector2 = g.center + Vector2(0, -40 * Balance.BLOCK_PX)
	var total: float = 0.0
	for i in 600:
		total += g.step(1.0 / 60.0, far)
	check_eq(total, 0.0, "longe da arena não há pulsos")
	var near: Vector2 = g.center + Vector2(Balance.BLOCK_PX * 2.5, 0)
	total = 0.0
	for i in 60 * 10:
		total += g.step(1.0 / 60.0, near)
	var pulses: int = int(10.0 / Balance.GUARDIAN_PULSE_INTERVAL)
	check(is_equal_approx(total, pulses * RegionRegistry.guardian_pulse_damage(vale)), "pulsos ferem quem está perto (%.0f em 10 s)" % total)
	var edge: Vector2 = g.center + Vector2(Balance.BLOCK_PX * (Balance.GUARDIAN_PULSE_RANGE_BLOCKS + 1.0), 0)
	total = 0.0
	for i in 60 * 10:
		total += g.step(1.0 / 60.0, edge)
	check_eq(total, 0.0, "fora do alcance do pulso não há dano (dá para se proteger)")
	check(g.touches(g.center + Vector2(g.radius + 10.0, 0), Balance.BIT_RADIUS_PX), "broca encostada no coração")
	check(not g.take_damage(g.max_hp * 0.5) and g.alive, "meia vida: ainda vivo")
	check(g.take_damage(g.max_hp) and not g.alive, "vida zerada: guardião vencido")
	check(not g.take_damage(10.0), "vencido não morre de novo")
	var abismo: RegionDef = RegionRegistry.get_def(RegionRegistry.ABISMO)
	check(RegionRegistry.guardian_hp(abismo) > RegionRegistry.guardian_hp(vale) and RegionRegistry.guardian_pulse_damage(abismo) > RegionRegistry.guardian_pulse_damage(vale),
			"guardiões mais fortes nas regiões difíceis")
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
	HeatRules.heat_start_m = abismo.heat_start_m
	var w := WorldModel.new(9, abismo)
	w.threaded = false
	var pos := Vector2(400, 260.5 * Balance.BLOCK_PX)
	w.fill_circle(pos, 40.0, BlockRegistry.AIR)
	var d := _drill(w, pos)
	var heat: float = HeatRules.heat_at(d.depth_m())
	check(heat > Balance.HEAT_SAFE_LEVEL, "260 m no Abismo é quente (%.1f)" % heat)
	var reasons: Array[StringName] = []
	d.stranded.connect(func(r: StringName) -> void: reasons.append(r))
	var it := DrillIntent.new()
	for i in 60 * 60:
		d.physics_step(DT, it)
		if d.disabled:
			break
	check(d.vitals.hull_dps > 0.0 or d.disabled, "o casco sofre com o calor")
	check(reasons.size() == 1 and reasons[0] == &"hull", "casco destruído pelo calor pede resgate")
	HeatRules.heat_start_m = Balance.HEAT_START_M
	d.free()
