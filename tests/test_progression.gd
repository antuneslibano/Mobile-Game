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
	var mats: Dictionary = Recipes.materials(dmg, 0)
	check(not mats.is_empty(), "nível 1 da broca pede materiais (%s)" % str(mats))
	check_eq(Progression.buy_status(e, dmg), Progression.BuyStatus.RESEARCH, "material nunca visto: projeto bloqueado")
	e.collect({&"copper": 1})
	e.cargo.erase(&"copper")
	check_eq(Progression.buy_status(e, dmg), Progression.BuyStatus.NO_MATERIALS, "descoberto mas sem material no armazém")
	for k: StringName in mats:
		e.cargo[k] = int(mats[k]) + 2
	check_eq(Progression.buy_status(e, dmg), Progression.BuyStatus.NO_FUNDS, "sem saldo")
	check(not Progression.try_buy(e, dmg), "compra recusada sem saldo")
	check_eq(e.get_level(&"damage"), 0, "nível inalterado")
	check_eq(int(e.cargo[&"copper"]), int(mats[&"copper"]) + 2, "materiais preservados quando falha")
	var c0: int = Progression.cost(dmg, 0)
	e.credits = c0 + 5
	check(Progression.try_buy(e, dmg), "constrói com saldo e materiais")
	check_eq(e.credits, 5, "debitou exatamente o custo")
	check_eq(int(e.cargo[&"copper"]), 2, "gastou exatamente os materiais")
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


## Bancada (0.10): trilhas de materiais por tier, projeto grande após o guardião, reserva e
## venda do excedente.
func test_recipes_and_market() -> void:
	for u in UpgradeRegistry.all():
		check(Recipes.TRACKS.has(u.id), "%s tem receita" % u.id)
		for lvl in [0, 4, 8, 12]:
			for k: StringName in Recipes.materials(u, lvl):
				check(ResourceRegistry.get_def(k) != null and ResourceRegistry.get_def(k).currency == &"", "%s nv %d: material %s existe e vai para o armazém" % [u.id, lvl, k])
	var dmg: UpgradeDef = UpgradeRegistry.get_def(&"damage")
	check(Recipes.materials(dmg, 0).keys() != Recipes.materials(dmg, 5).keys(), "a trilha muda de material no 2º tier")
	var all_found: Dictionary = {}
	for k in ResourceRegistry.order():
		all_found[k] = true
	check(Recipes.requirement(dmg, 9, all_found, 0).contains("guardião"), "3º tier pede vencer um guardião")
	check_eq(Recipes.requirement(dmg, 9, all_found, 1), "", "guardião vencido libera o projeto grande")
	var e := Economy.new()
	e.collect({&"iron": 40, &"gold": 3})
	var reserve: Dictionary = Recipes.reserve(e.upgrade_levels)
	check(int(reserve.get(&"iron", 0)) > 0, "a Bancada reserva ferro")
	var gained: int = e.sell_surplus(reserve)
	check(gained > 0 and int(e.cargo.get(&"iron", 0)) == int(reserve[&"iron"]), "excedente vendido, reserva mantida")
	check(not e.cargo.has(&"gold"), "ouro sem uso no próximo nível é excedente")
	check_eq(e.sell(&"iron", 999), int(reserve[&"iron"]) * ResourceRegistry.get_def(&"iron").sell_value, "vender por recurso")
	check(e.discovered.has(&"gold") and Economy.from_dict(e.to_dict()).discovered.has(&"gold"), "descobertas salvas")


## Diário do Laboratório: entradas por descoberta e por guardião.
func test_journal() -> void:
	check_eq(Journal.unlocked({}, {}).size(), 1, "só a entrada inicial num perfil novo")
	check(Journal.unlocked({&"copper": true}, {}).size() == 2, "descobrir cobre libera uma entrada")
	check(Journal.unlocked({}, {&"vale": true}).size() == 2, "vencer o guardião do Vale libera uma entrada")
	for e: Array in Journal.ENTRIES:
		var trig: String = String(e[1])
		if trig.begins_with("res:"):
			check(ResourceRegistry.get_def(StringName(trig.substr(4))) != null, "entrada %s cita recurso existente" % e[0])


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
	var r: Dictionary = Sim.run(&"minerios", 20.0)
	note("20 min buscando minérios: " + Sim.summary(r))
	var marks: Dictionary = r.marks
	# Faixas-alvo (GAME_DESIGN.md §7.2.1).
	check(marks.has(50) and float(marks[50]) > 20.0 and float(marks[50]) < 300.0, "50 m entre 20 s e 5 min")
	check(float(r.final_at) > 360.0 and float(r.final_at) < 1020.0, "câmara final do Vale entre 6 e 17 min (%.0f s)" % float(r.final_at))
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
	check(busca.earned >= 1000, "buscando minérios a economia anda (%d créditos em 6 min)" % busca.earned)
