extends "res://tests/test_case.gd"


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


## Simulação de balanceamento: jogador que cava para baixo (desviando de vez em quando),
## usa a Sobrecarga quando a barra enche, vende a cada 15 s e compra o upgrade mais barato.
func test_balance_simulation_greedy_player() -> void:
	var w := WorldModel.new(2024)
	w.threaded = false
	var e := Economy.new()
	var d := Drill.new()
	d.stats = Progression.build_stats(e.upgrade_levels)
	d.setup(w, Drill.surface_spawn(), 3)
	var overdrives: Array[int] = [0]
	var first_full: Array[float] = [-1.0]
	var clock: Array[float] = [0.0]   # lambdas capturam por valor: tempo compartilhado via array
	var t: float = 0.0
	d.dug.connect(func(counts: Dictionary, _at: Vector2) -> void:
		e.collect(Drill.drops_for(counts), d.stats.collect_mult))
	d.boost_started.connect(func() -> void: overdrives[0] += 1)
	d.overdrive_ready.connect(func() -> void:
		if first_full[0] < 0.0:
			first_full[0] = clock[0])
	var intent := DrillIntent.new()
	intent.boost = true
	var dt: float = 1.0 / 60.0
	var marks: Dictionary = {}
	var bought: int = 0
	var next_shop: float = 15.0
	var minutes: float = 10.0
	var stuck_t: float = 0.0
	var last_depth: int = 0
	while t < minutes * 60.0:
		# Preso por 4 s: tenta 1,5 s na diagonal (alternando lados) e volta a cavar para baixo.
		intent.aim = Vector2.DOWN
		if stuck_t > 4.0:
			intent.aim = Vector2(1, 1).normalized() if int(t / 11.0) % 2 == 0 else Vector2(-1, 1).normalized()
			if stuck_t > 5.5:
				stuck_t = 0.0
		d.physics_step(dt, intent)
		t += dt
		clock[0] = t
		var depth: int = d.depth_m()
		if depth > last_depth:
			last_depth = depth
			stuck_t = 0.0
		else:
			stuck_t += dt
		for m: int in [25, 50, 100, 150, 200, 300]:
			if depth >= m and not marks.has(m):
				marks[m] = t
		if t >= next_shop:
			next_shop += 15.0
			e.sell_all()
			var bought_any: bool = true
			while bought_any:
				bought_any = false
				var best: UpgradeDef = null
				for u in UpgradeRegistry.all():
					if Progression.buy_status(e, u) == Progression.BuyStatus.OK:
						if best == null or Progression.cost(u, e.get_level(u.id)) < Progression.cost(best, e.get_level(best.id)):
							best = u
				if best != null and Progression.try_buy(e, best):
					bought += 1
					bought_any = true
					if best.id in ModuleSystem.ALL and e.get_level(best.id) == 1:
						e.toggle_module(best.id, Balance.MODULE_SLOTS)
			d.stats = Progression.build_stats(e.upgrade_levels)
			d.modules.set_equipped(e.equipped_modules)
		if w.loaded_chunk_indices().size() > 8:
			var ci: int = WorldModel.chunk_index_for_row(floori(d.position.y / Balance.CELL_PX))
			w.unload_outside(ci - 2, ci + 3)
	var parts: PackedStringArray = []
	for m: int in marks:
		parts.append("%dm@%.0fs" % [m, float(marks[m])])
	note("10 min simulados: %d m, %d upgrades, %d cristais, módulos %s, níveis %s" % [d.depth_m(), bought, e.crystals, str(e.equipped_modules), str(e.upgrade_levels)])
	note("marcos: %s · 1ª Sobrecarga pronta em %.0fs · %d Sobrecargas" % [", ".join(parts), first_full[0], overdrives[0]])
	# Faixas-alvo (GAME_DESIGN.md §7.2.1).
	check(marks.has(50) and float(marks[50]) > 20.0 and float(marks[50]) < 300.0, "50 m entre 20 s e 5 min")
	check(d.depth_m() >= 120 and d.depth_m() <= 450, "10 min levam a 120–450 m (%d m)" % d.depth_m())
	check(bought >= 10, "compra ao menos 10 upgrades em 10 minutos (%d)" % bought)
	check(not e.equipped_modules.is_empty(), "adquire e equipa ao menos um módulo em 10 minutos")
	check(first_full[0] > 30.0, "a energia exige esforço: 1ª Sobrecarga após 30 s (%.0f s)" % first_full[0])
	check(overdrives[0] >= 2 and overdrives[0] <= 25, "Sobrecargas são eventos, não spam (%d em 10 min)" % overdrives[0])
	d.free()
