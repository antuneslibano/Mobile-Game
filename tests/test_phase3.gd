extends "res://tests/test_case.gd"
## Fase 3 (revisada): joystick livre, energia conquistada/Sobrecarga, calor, módulos, sinergia.

const DT: float = 1.0 / 60.0


func _model(p_seed: int) -> WorldModel:
	var w := WorldModel.new(p_seed)
	w.threaded = false
	return w


func _rect(w: WorldModel, from_px: Vector2, to_px: Vector2, id: int) -> void:
	var cp: float = float(Balance.CELL_PX)
	for cy in range(floori(from_px.y / cp), floori(to_px.y / cp)):
		for cx in range(floori(from_px.x / cp), floori(to_px.x / cp)):
			w.set_cell(Vector2i(cx, cy), id)


func _drill(w: WorldModel, pos: Vector2, levels: Dictionary = {}) -> Drill:
	var d := Drill.new()
	d.stats = Progression.build_stats(levels)
	d.setup(w, pos, 5)
	return d


func test_joystick_free_directions_never_up() -> void:
	var it := DrillIntent.new()
	InputController.joystick_to_intent(Vector2.ZERO, it)
	check(it.aim == Vector2.ZERO, "centro: nada")
	InputController.joystick_to_intent(Vector2(0.1, 0.1), it)
	check(it.aim == Vector2.ZERO, "zona morta")
	for v: Vector2 in [Vector2(0, 1), Vector2(1, 1).normalized(), Vector2(-0.4, 0.9).normalized(), Vector2(1, 0), Vector2(-1, 0.2).normalized()]:
		InputController.joystick_to_intent(v, it)
		check(it.aim.length() > 0.9 and absf(it.aim.angle() - v.angle()) < 0.01, "direção livre %s preservada" % v)
	InputController.joystick_to_intent(Vector2(0.5, 0.0), it)
	check(it.aim.length() > 0.3 and it.aim.length() < 0.8, "aceleração analógica (%.2f)" % it.aim.length())
	for v: Vector2 in [Vector2(0, -1), Vector2(0.15, -1.0).normalized(), Vector2(-0.1, -0.9)]:
		InputController.joystick_to_intent(v, it)
		check(it.aim == Vector2.ZERO, "para cima %s: nada" % v)
	InputController.joystick_to_intent(Vector2(1, -1).normalized(), it)
	check(it.aim.y == 0.0 and it.aim.x > 0.0, "diagonal para cima vira lateral (sem subir)")


func test_energy_is_earned_not_regenerated() -> void:
	var s := DrillStats.base()
	var e := EnergySystem.new()
	e.reset(s)
	check_eq(e.energy, 0.0, "começa vazia")
	for i in 600:
		e.step(DT, s, false)
	check_eq(e.energy, 0.0, "não regenera com o tempo")
	check(not e.step(DT, s, true), "não ativa sem carga")
	e.add_charge(e.max_energy * 0.6)
	check(not e.step(DT, s, true), "não ativa com barra parcial (60%)")
	check(e.add_charge(e.max_energy), "avisa quando enche")
	check(e.is_ready(), "pronta com a barra cheia")
	check(e.step(DT, s, true), "Sobrecarga ativa com a barra cheia")
	check(e.is_boosting() and e.speed_mult(s) >= Balance.OVERDRIVE_DIG_MULT, "acelera a escavação")
	check(not e.add_charge(50.0) and e.energy < e.max_energy, "não carrega durante a Sobrecarga")
	for i in int(EnergySystem.boost_duration(s) / DT) + 2:
		e.step(DT, s, true)
	check(not e.is_boosting() and e.energy < 0.01, "termina e consome tudo (sem spam)")
	check(not e.step(DT, s, true), "insistir no botão não reativa")


func test_charge_rewards_valuable_material() -> void:
	var s := DrillStats.base()
	var dirt: float = EnergySystem.charge_for(Drill.volume_value({BlockRegistry.DIRT: 16}).x, 0.0, 10, s)
	var copper: float = EnergySystem.charge_for(Drill.volume_value({BlockRegistry.COPPER: 16}).x, 0.0, 10, s)
	var crystal_v: Vector2 = Drill.volume_value({BlockRegistry.CRYSTAL: 16})
	var crystal: float = EnergySystem.charge_for(crystal_v.x, crystal_v.y, 10, s)
	check(copper > dirt * 5.0, "cobre carrega muito mais que terra (%.1f vs %.1f)" % [copper, dirt])
	check(crystal > copper, "cristal carrega ainda mais (%.1f)" % crystal)
	var s2 := Progression.build_stats({&"energy": 5})
	check(EnergySystem.charge_for(10.0, 0.0, 10, s2) > EnergySystem.charge_for(10.0, 0.0, 10, s) * 1.4, "Bateria aumenta a carga")
	note("carga por bloco: terra %.1f, cobre %.1f, cristal %.1f (de 100)" % [dirt, copper, crystal])


func test_mining_works_without_energy() -> void:
	var w := _model(41)
	var d := _drill(w, Drill.surface_spawn())
	var it := DrillIntent.new()
	it.aim = Vector2.DOWN
	it.boost = true
	for i in 600:
		d.physics_step(DT, it)
		d.energy.energy = 0.0
	check(d.depth_m() >= 4, "energia zerada não impede a mineração (%d m)" % d.depth_m())
	d.free()


func test_overdrive_digs_faster_and_wider() -> void:
	var depths: Array[float] = []
	for boost: bool in [false, true]:
		var w := _model(42)
		_rect(w, Vector2(60, 0), Vector2(1100, 1500), BlockRegistry.STONE)
		var d := _drill(w, Vector2(540, -20))
		if boost:
			d.energy.add_charge(1000.0)
		var it := DrillIntent.new()
		it.aim = Vector2.DOWN
		it.boost = boost
		var wide: float = d.bit_radius()
		for i in int(4.0 / DT):
			d.physics_step(DT, it)
			wide = maxf(wide, d.bit_radius())
		depths.append(d.position.y)
		if boost:
			check(wide > Balance.BIT_RADIUS_PX * 1.2, "túnel mais largo na Sobrecarga")
		d.free()
	check(depths[1] > depths[0] * 1.5, "Sobrecarga cava bem mais rápido (%.0f vs %.0f px)" % [depths[1], depths[0]])


func test_heat_rules() -> void:
	HeatRules.heat_start_m = Balance.HEAT_START_M
	check_eq(HeatRules.heat_at(299), 0.0, "sem calor antes de 300 m")
	check(absf(HeatRules.heat_at(400) - 1.0) < 0.001, "calor 1 em 400 m")
	check_eq(HeatRules.heat_at(2000), Balance.HEAT_MAX, "calor limitado")
	check(absf(HeatRules.penalty(500, 0.0) - 0.2) < 0.001, "penalidade 20% em 500 m")
	check(absf(HeatRules.penalty(900, 0.0) - Balance.HEAT_PENALTY_MAX) < 0.001, "penalidade máxima 30%")
	check(HeatRules.penalty(500, 0.5) < HeatRules.penalty(500, 0.0), "refrigeração reduz a penalidade")


func test_side_drill_widens_tunnel() -> void:
	var widths: Array[int] = []
	for equip: bool in [false, true]:
		var w := _model(43)
		_rect(w, Vector2(60, 0), Vector2(1100, 900), BlockRegistry.DIRT)
		var d := _drill(w, Vector2(540, -20), {&"side_drill": 5})
		if equip:
			d.modules.set_equipped([&"side_drill"] as Array[StringName])
		var it := DrillIntent.new()
		it.aim = Vector2.DOWN
		for i in int(4.0 / DT):
			d.physics_step(DT, it)
		var y: float = d.position.y * 0.5
		var n: int = 0
		for cx in Balance.WORLD_CELLS_X:
			if not w.is_solid(Vector2i(cx, floori(y / Balance.CELL_PX))):
				n += 1
		widths.append(n)
		d.free()
	check(widths[1] > widths[0], "broca lateral alarga o túnel (%d → %d células)" % widths)


func test_drone_targets_ore_in_range() -> void:
	var w := _model(44)
	_rect(w, Vector2(60, 0), Vector2(1100, 900), BlockRegistry.STONE)
	var p := Vector2(500, 400)
	w.fill_circle(p, 40.0, BlockRegistry.AIR)
	w.fill_circle(p + Vector2(90, 30), 10.0, BlockRegistry.GOLD)
	var d := _drill(w, p, {&"drone": 1})
	d.modules.set_equipped([&"drone"] as Array[StringName])
	var target: Vector2 = d.modules.find_drone_target(d)
	check(target.distance_to(p + Vector2(90, 30)) < 16.0, "drone prioriza minério (%s)" % target)
	var shots: Array[int] = [0]
	d.modules.drone_shot.connect(func(_pt: Vector2) -> void: shots[0] += 1)
	var it := DrillIntent.new()
	for i in int(5.0 / DT):
		d.physics_step(DT, it)
	check(shots[0] >= 2, "drone dispara periodicamente (%d)" % shots[0])
	d.free()


func test_seismic_pulse_and_crit_synergy() -> void:
	var w := _model(45)
	_rect(w, Vector2(60, 0), Vector2(1100, 900), BlockRegistry.DIRT)
	var p := Vector2(500, 300)
	w.fill_circle(p, 22.0, BlockRegistry.AIR)
	var d := _drill(w, p, {&"seismic": 1})
	d.modules.set_equipped([&"seismic"] as Array[StringName])
	var pulses: Array[int] = [0]
	var centers: Array[Vector2] = []
	d.modules.pulse_fired.connect(func(c: Vector2, _r: float, _crit: bool) -> void:
		pulses[0] += 1
		centers.append(c))
	d.modules.pulse_cd = 0.01
	var it := DrillIntent.new()
	it.aim = Vector2.DOWN
	for i in 20:
		d.physics_step(DT, it)
	check(pulses[0] >= 1, "pulso dispara enquanto cava")
	check(not centers.is_empty() and not w.is_solid(WorldModel.world_to_cell(centers[0] + Vector2(50, 10))), "pulso abre área ao lado")
	check(SynergyRules.is_active(SynergyRules.CRITICAL_RESONANCE, d.modules.equipped, d.stats), "Ressonância Crítica ativa com pulso")
	check(not SynergyRules.is_active(SynergyRules.CRITICAL_RESONANCE, [&"drone"] as Array[StringName], d.stats), "inativa sem pulso")
	d.modules.pulse_cd = 5.0
	d.modules.on_drill_hit(d, true)
	check(absf(d.modules.pulse_cd - (5.0 - Balance.SYNERGY_CRIT_PULSE_REFUND)) < 0.001, "crítico reduz a recarga do pulso")
	d.modules.pulse_cd = 5.0
	d.modules.on_drill_hit(d, false)
	check_eq(d.modules.pulse_cd, 5.0, "golpe normal não reduz")
	d.free()


func test_module_slots() -> void:
	var e := Economy.new()
	check(not e.toggle_module(&"drone", 2), "não equipa módulo não adquirido")
	for id in ModuleSystem.ALL:
		e.set_level(id, 1)
	check(e.toggle_module(&"drone", 2) and e.toggle_module(&"seismic", 2), "equipa dois")
	check(not e.toggle_module(&"side_drill", 2), "terceiro excede os slots")
	check(e.toggle_module(&"drone", 2) and not e.equipped_modules.has(&"drone"), "remove")
	check(e.toggle_module(&"side_drill", 2), "equipa no slot liberado")
