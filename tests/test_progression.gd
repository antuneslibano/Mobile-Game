extends "res://tests/test_case.gd"

const Sim = preload("res://tests/balance_sim.gd")


func test_upgrade_definitions_are_valid() -> void:
	var defs: Array[UpgradeDef] = UpgradeRegistry.all()
	check_eq(defs.size(), UpgradeRegistry.PATHS.size(), "todos os .tres carregam")
	var ids: Dictionary = {}
	for d in defs:
		check(not ids.has(d.id), "id único %s" % d.id)
		ids[d.id] = true
		check(d.display_name != "" and d.description != "", "%s com nome e descrição" % d.id)
		check(d.currency in [Economy.CREDITS, Economy.CRYSTALS], "%s moeda válida" % d.id)
		check(d.base_cost > 0.0 and d.cost_growth > 1.0 and d.max_level > 0, "%s custo/limite válidos" % d.id)
	for id: StringName in [&"damage", &"speed", &"crit", &"energy", &"collect", &"boost", &"side_drill", &"drone", &"seismic", &"cooling"]:
		check(ids.has(id), "upgrade inicial %s existe" % id)


func test_costs_grow_monotonically() -> void:
	for d in UpgradeRegistry.all():
		var prev: int = 0
		for lvl in d.max_level:
			var c: int = Progression.cost(d, lvl)
			check(c >= prev, "%s custo não decresce no nível %d" % [d.id, lvl])
			prev = c
		check(Progression.cost(d, d.max_level - 1) > Progression.cost(d, 0), "%s custo cresce" % d.id)


func test_buy_is_atomic_and_respects_limits() -> void:
	var e := Economy.new()
	var dmg: UpgradeDef = UpgradeRegistry.get_def(&"damage")
	check_eq(Progression.buy_status(e, dmg), Progression.BuyStatus.NO_FUNDS, "sem saldo")
	check(not Progression.try_buy(e, dmg), "compra recusada sem saldo")
	check_eq(e.get_level(&"damage"), 0, "nível inalterado")
	var c0: int = Progression.cost(dmg, 0)
	e.credits = c0 + 5
	check(Progression.try_buy(e, dmg), "compra com saldo")
	check_eq(e.credits, 5, "debitou exatamente o custo")
	check_eq(e.get_level(&"damage"), 1, "subiu um nível")
	e.set_level(&"damage", dmg.max_level)
	e.credits = 999999999
	check_eq(Progression.buy_status(e, dmg), Progression.BuyStatus.MAXED, "limite máximo")
	check(not Progression.try_buy(e, dmg), "não passa do máximo")
	var locked: UpgradeDef = UpgradeRegistry.get_def(&"drone").duplicate()
	locked.available_from_phase = UpgradeRegistry.CURRENT_PHASE + 1
	e.crystals = 999
	check_eq(Progression.buy_status(e, locked), Progression.BuyStatus.LOCKED, "upgrade de fase futura bloqueado")
	check(not Progression.try_buy(e, locked), "bloqueado não compra")
	check_eq(e.crystals, 999, "cristais preservados")


func test_stats_reflect_levels_and_preview() -> void:
	var base := Progression.build_stats({})
	var s := Progression.build_stats({&"damage": 3, &"speed": 5, &"crit": 4, &"collect": 2})
	check(absf(s.damage - (base.damage + 6.0)) < 0.001, "dano +2/nível")
	check(absf(s.hits_per_second - base.hits_per_second * 1.4) < 0.001, "velocidade +8%/nível")
	check(absf(s.crit_chance - (base.crit_chance + 0.08)) < 0.001, "crítico +2%/nível")
	check(absf(s.collect_mult - 1.2) < 0.001, "coleta +10%/nível")
	var p3 := Progression.build_stats({&"drone": 3, &"cooling": 2, &"energy": 2, &"boost": 1})
	check(int(p3.module_levels.get(&"drone", 0)) == 3, "nível do módulo nos atributos")
	check(absf(p3.cooling - 0.12) < 0.001, "refrigeração −6%/nível")
	check(absf(p3.energy_gain - (1.0 + 2.0 * Balance.ENERGY_GAIN_PER_LEVEL)) < 0.001, "bateria +10%/nível")
	check_eq(p3.boost_level, 1, "nível de impulso")
	for u in UpgradeRegistry.all():
		check(UpgradeRegistry.is_available(u), "%s liberado na Fase 3" % u.id)
	for d in UpgradeRegistry.all():
		var p: PackedStringArray = Progression.preview(d, {})
		check(p.size() == 2 and p[0] != p[1], "%s mostra antes → depois (%s → %s)" % [d.id, p[0], p[1]])
	note("dano: %s" % " → ".join(Progression.preview(UpgradeRegistry.get_def(&"damage"), {})))


## Simulação de balanceamento com expedições (tests/balance_sim.gd): o jogador que vai atrás
## dos minérios conclui o Vale das Raízes (vence o guardião) e progride nas faixas-alvo.
func test_balance_simulation_greedy_player() -> void:
	var r: Dictionary = Sim.run(&"minerios", 16.0)
	note("16 min buscando minérios: " + Sim.summary(r))
	var marks: Dictionary = r.marks
	# Faixas-alvo (GAME_DESIGN.md §7.2.1).
	check(marks.has(50) and float(marks[50]) > 20.0 and float(marks[50]) < 300.0, "50 m entre 20 s e 5 min")
	check(float(r.final_at) > 360.0 and float(r.final_at) < 900.0, "câmara final do Vale entre 6 e 15 min (%.0f s)" % float(r.final_at))
	check(float(r.guardian_at) > float(r.final_at) + 5.0, "o guardião resiste a mais de 5 s de broca (%.0f s)" % (float(r.guardian_at) - float(r.final_at)))
	check(int(r.expeditions) >= 3, "o combustível divide o jogo em expedições (%d)" % int(r.expeditions))
	check(int(r.first_trip_depth) < r_target(), "a 1ª expedição não chega ao fundo (%d m)" % int(r.first_trip_depth))
	check(int(r.fuel_outs) >= 2, "o combustível acaba de verdade (%d expedições no limite)" % int(r.fuel_outs))
	check(r.bought >= 10, "compra ao menos 10 upgrades (%d)" % r.bought)
	check(not (r.modules as Array).is_empty(), "adquire e equipa ao menos um módulo")
	check(r.first_full > 20.0, "a energia exige esforço: 1ª Sobrecarga após 20 s (%.0f s)" % r.first_full)
	check(r.overdrives >= 2 and r.overdrives <= 30, "Sobrecargas são eventos, não spam (%d)" % r.overdrives)
	check(float(r.refuel) > 0.0, "carvão abastece o tanque")


func r_target() -> int:
	return RegionRegistry.get_def(RegionRegistry.VALE).target_depth_m / 2


## O dinheiro está nos minérios: desviar até eles rende muito mais do que cavar reto.
func test_seeking_ores_beats_digging_straight() -> void:
	var reto: Dictionary = Sim.run(&"reto", 6.0)
	var busca: Dictionary = Sim.run(&"minerios", 6.0)
	note("6 min cavando reto: " + Sim.summary(reto))
	note("6 min buscando minérios: " + Sim.summary(busca))
	check(busca.earned >= reto.earned * 4, "buscar minérios rende ≥ 4× cavar reto (%d × %d)" % [busca.earned, reto.earned])
	check(reto.earned > 0, "cavar reto ainda encontra algum minério (%d)" % reto.earned)
