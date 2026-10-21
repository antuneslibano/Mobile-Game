extends "res://tests/test_case.gd"
## Fase 3: joystick, energia/impulso, calor, módulos, sinergia e "a broca não sobe".

const DT: float = 1.0 / 60.0


func _model(p_seed: int) -> WorldModel:
	var w := WorldModel.new(p_seed)
	w.threaded = false
	return w


func _fill(w: WorldModel, from: Vector2i, to: Vector2i, id: int) -> void:
	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			w.set_block(Vector2i(x, y), id)


func _drill(w: WorldModel, cell: Vector2i, levels: Dictionary = {}) -> Drill:
	var d := Drill.new()
	d.stats = Progression.build_stats(levels)
	d.setup(w, cell, 5)
	return d


func test_joystick_mapping_never_goes_up() -> void:
	var it := DrillIntent.new()
	InputController.joystick_to_intent(Vector2.ZERO, it)
	check(not it.drill and it.move == 0.0, "centro: nada")
	InputController.joystick_to_intent(Vector2(0.1, 0.1), it)
	check(not it.drill, "zona morta")
	InputController.joystick_to_intent(Vector2(0.0, 1.0), it)
	check(it.drill and it.move == 0.0, "baixo: perfura para baixo")
	InputController.joystick_to_intent(Vector2(0.5, 0.6), it)
	check(it.drill and it.move == 0.0, "diagonal baixa: perfura para baixo")
	InputController.joystick_to_intent(Vector2(1.0, 0.0), it)
	check(it.drill and absf(it.move - 1.0) < 0.001, "direita: move e perfura de lado")
	InputController.joystick_to_intent(Vector2(-0.4, 0.0), it)
	check(it.move < 0.0 and it.move > -0.9, "esquerda analógica (%.2f)" % it.move)
	for v: Vector2 in [Vector2(0, -1), Vector2(0.15, -1.0), Vector2(-0.2, -0.9)]:
		InputController.joystick_to_intent(v, it)
		check(not it.drill and it.move == 0.0, "para cima %s: nada" % v)


func test_drill_never_rises_with_any_input() -> void:
	# Sala aberta: nenhuma combinação de entradas faz a máquina subir ou golpear acima.
	var w := _model(40)
	_fill(w, Vector2i(1, 0), Vector2i(22, 12), BlockRegistry.STONE)
	_fill(w, Vector2i(6, 2), Vector2i(17, 6), BlockRegistry.AIR)
	var d := _drill(w, Vector2i(11, 6), {&"seismic": 3, &"drone": 3, &"side_drill": 3})
	d.modules.set_equipped([&"seismic", &"drone"] as Array[StringName])
	var start_row: int = d.feet_row()
	var above_hits: Array[int] = [0]
	d.block_hit.connect(func(c: Vector2i, _id: int, _dm: float, _cr: bool, _de: bool) -> void:
		if c.y < start_row:
			above_hits[0] += 1)
	var it := DrillIntent.new()
	for v: Vector2 in [Vector2(0, -1), Vector2(0.2, -1), Vector2(-0.2, -1), Vector2(0, -1)]:
		InputController.joystick_to_intent(v, it)
		it.boost = true
		var min_top: float = d.position.y
		for i in 240:
			d.physics_step(DT, it)
			min_top = minf(min_top, d.position.y)
		check(min_top >= d.position.y - 0.01 and d.feet_row() == start_row, "joystick %s não eleva a máquina" % v)
	check_eq(above_hits[0], 0, "nenhum golpe acima da máquina (inclui módulos)")
	d.free()


func test_energy_and_boost() -> void:
	var s := DrillStats.base()
	var e := EnergySystem.new()
	e.reset(s)
	check_eq(e.energy, s.max_energy, "começa cheia")
	check(e.step(DT, s, true), "impulso inicia")
	check(e.is_boosting() and absf(e.energy - (s.max_energy - Balance.BOOST_COST + Balance.ENERGY_REGEN_PER_SEC * DT)) < 0.01, "consome energia")
	check(absf(e.speed_mult(s) - Balance.BOOST_SPEED_MULT) < 0.001, "acelera a mineração")
	check(not e.step(DT, s, true), "não reinicia durante o impulso")
	for i in int(EnergySystem.boost_duration(s) / DT) + 2:
		e.step(DT, s, false)
	check(not e.is_boosting() and e.speed_mult(s) == 1.0, "impulso termina")
	e.energy = 0.0
	check(not e.step(DT, s, true), "sem energia, sem impulso")
	for i in int((s.max_energy / Balance.ENERGY_REGEN_PER_SEC + 1.0) / DT):
		e.step(DT, s, false)
	check(absf(e.energy - s.max_energy) < 0.01, "regenera até o máximo")


func test_mining_works_without_energy() -> void:
	var w := _model(41)
	var d := _drill(w, Vector2i(12, -1))
	d.energy.energy = 0.0
	var it := DrillIntent.new()
	it.drill = true
	it.boost = true
	for i in 600:
		d.physics_step(DT, it)
		d.energy.energy = 0.0
	check(d.depth_m() >= 3, "energia zerada não impede a mineração (%d m)" % d.depth_m())
	d.free()


func test_boost_digs_faster() -> void:
	var depths: Array[int] = []
	for boost: bool in [false, true]:
		var w := _model(42)
		_fill(w, Vector2i(11, 0), Vector2i(13, 30), BlockRegistry.STONE)
		var d := _drill(w, Vector2i(12, -1))
		var it := DrillIntent.new()
		it.drill = true
		it.boost = boost
		for i in int(3.0 / DT):
			d.physics_step(DT, it)
		depths.append(d.depth_m())
		d.free()
	check(depths[1] > depths[0], "impulso cava mais rápido (%d m vs %d m)" % [depths[1], depths[0]])


func test_heat_rules() -> void:
	check_eq(HeatRules.heat_at(299), 0.0, "sem calor antes de 300 m")
	check(absf(HeatRules.heat_at(400) - 1.0) < 0.001, "calor 1 em 400 m")
	check_eq(HeatRules.heat_at(2000), Balance.HEAT_MAX, "calor limitado")
	check(absf(HeatRules.penalty(500, 0.0) - 0.2) < 0.001, "penalidade 20% em 500 m")
	check(absf(HeatRules.penalty(900, 0.0) - Balance.HEAT_PENALTY_MAX) < 0.001, "penalidade máxima 30%")
	check(HeatRules.penalty(500, 0.5) < HeatRules.penalty(500, 0.0), "refrigeração reduz a penalidade")
	check(HeatRules.efficiency(500, 0.9) > 0.97, "refrigeração alta quase anula o calor")


func test_side_drill_widens_shaft() -> void:
	var w := _model(43)
	_fill(w, Vector2i(1, 0), Vector2i(22, 20), BlockRegistry.DIRT)
	w.set_block(Vector2i(12, 0), BlockRegistry.AIR)
	var d := _drill(w, Vector2i(12, 0), {&"side_drill": 10})
	d.modules.set_equipped([&"side_drill"] as Array[StringName])
	var it := DrillIntent.new()
	it.drill = true
	for i in int(4.0 / DT):
		d.physics_step(DT, it)
	var widened: int = 0
	for y in range(1, d.feet_row()):
		if w.get_block(Vector2i(11, y)) == BlockRegistry.AIR or w.get_block(Vector2i(13, y)) == BlockRegistry.AIR:
			widened += 1
	check(widened >= 2, "broca lateral abre as células vizinhas (%d linhas)" % widened)
	d.free()


func test_drone_targets_ore_in_range() -> void:
	var w := _model(44)
	_fill(w, Vector2i(1, 0), Vector2i(22, 20), BlockRegistry.STONE)
	_fill(w, Vector2i(10, 2), Vector2i(14, 4), BlockRegistry.AIR)
	w.set_block(Vector2i(14, 5), BlockRegistry.GOLD)
	var d := _drill(w, Vector2i(12, 4), {&"drone": 1})
	d.modules.set_equipped([&"drone"] as Array[StringName])
	check_eq(d.modules.find_drone_target(d), Vector2i(14, 5), "drone prioriza minério")
	var shots: Array[int] = [0]
	d.modules.drone_shot.connect(func(_c: Vector2i) -> void: shots[0] += 1)
	var it := DrillIntent.new()
	for i in int(5.0 / DT):
		d.physics_step(DT, it)
	check(shots[0] >= 2, "drone dispara periodicamente (%d)" % shots[0])
	d.free()


func test_seismic_pulse_and_crit_synergy() -> void:
	var w := _model(45)
	_fill(w, Vector2i(1, 0), Vector2i(22, 20), BlockRegistry.DIRT)
	w.set_block(Vector2i(12, 2), BlockRegistry.AIR)
	var d := _drill(w, Vector2i(12, 2), {&"seismic": 1})
	d.modules.set_equipped([&"seismic"] as Array[StringName])
	var pulses: Array[int] = [0]
	d.modules.pulse_fired.connect(func(_c: Vector2, _r: float, _crit: bool) -> void: pulses[0] += 1)
	d.modules.pulse_cd = 0.01
	var it := DrillIntent.new()
	it.drill = true
	d.physics_step(DT, it)
	d.physics_step(DT, it)
	check(pulses[0] >= 1, "pulso dispara enquanto perfura")
	check(w.get_block(Vector2i(11, 2)) == BlockRegistry.AIR or w.get_damage_ratio(Vector2i(11, 2)) > 0.0, "pulso atinge blocos ao lado")
	# Sinergia: crítico devolve recarga do pulso.
	check(SynergyRules.is_active(SynergyRules.CRITICAL_RESONANCE, d.modules.equipped, d.stats), "Ressonância Crítica ativa com pulso equipado")
	check(not SynergyRules.is_active(SynergyRules.CRITICAL_RESONANCE, [&"drone"] as Array[StringName], d.stats), "inativa sem pulso")
	d.modules.pulse_cd = 5.0
	d.modules.on_drill_hit(d, Vector2i(12, 3), 1.0, true)
	check(absf(d.modules.pulse_cd - (5.0 - Balance.SYNERGY_CRIT_PULSE_REFUND)) < 0.001, "crítico reduz a recarga do pulso")
	d.modules.pulse_cd = 5.0
	d.modules.on_drill_hit(d, Vector2i(12, 3), 1.0, false)
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
