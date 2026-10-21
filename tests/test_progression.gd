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
	var locked: UpgradeDef = UpgradeRegistry.get_def(&"drone")
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
	var locked := Progression.build_stats({&"drone": 3, &"cooling": 2})
	check(locked.module_levels.is_empty() and locked.cooling == 0.0, "upgrades bloqueados não afetam atributos")
	for d in UpgradeRegistry.all():
		var p: PackedStringArray = Progression.preview(d, {})
		check(p.size() == 2 and p[0] != p[1], "%s mostra antes → depois (%s → %s)" % [d.id, p[0], p[1]])
	note("dano: %s" % " → ".join(Progression.preview(UpgradeRegistry.get_def(&"damage"), {})))


## Simulação de balanceamento: jogador guloso que vende e compra o upgrade mais barato.
func test_balance_simulation_greedy_player() -> void:
	var w := WorldModel.new(2024)
	w.threaded = false
	var e := Economy.new()
	var d := Drill.new()
	d.setup(w, Vector2i(12, -1), 3)
	d.stats = Progression.build_stats(e.upgrade_levels)
	d.block_destroyed.connect(func(_c: Vector2i, id: int) -> void:
		e.collect(BlockRegistry.get_def(id).drops, d.stats.collect_mult))
	var intent := DrillIntent.new()
	intent.drill = true
	var dt: float = 1.0 / 60.0
	var t: float = 0.0
	var marks: Dictionary = {}
	var bought: int = 0
	var shop_every: float = 15.0
	var next_shop: float = shop_every
	var minutes: float = 10.0
	var stuck_t: float = 0.0
	var last_depth: int = 0
	while t < minutes * 60.0:
		# Desvia lateralmente de vez em quando para não ficar preso em cavernas fechadas.
		intent.move = 0.0
		if stuck_t > 4.0:
			intent.move = 1.0 if int(t / 5.0) % 2 == 0 else -1.0
		d.physics_step(dt, intent)
		t += dt
		var depth: int = d.depth_m()
		if depth > last_depth:
			last_depth = depth
			stuck_t = 0.0
		else:
			stuck_t += dt
		for m: int in [25, 50, 100, 150, 200]:
			if depth >= m and not marks.has(m):
				marks[m] = t
		if t >= next_shop:
			next_shop += shop_every
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
			d.stats = Progression.build_stats(e.upgrade_levels)
		if w.loaded_chunk_indices().size() > 12:
			var ci: int = WorldModel.chunk_index_for_row(d.feet_row())
			w.unload_outside(ci - 2, ci + 3)
	var parts: PackedStringArray = []
	for m: int in marks:
		parts.append("%dm@%.0fs" % [m, float(marks[m])])
	note("10 min simulados: %d m, %d upgrades, níveis %s" % [d.depth_m(), bought, str(e.upgrade_levels)])
	note("marcos: %s" % ", ".join(parts))
	# Faixas-alvo (GAME_DESIGN.md §7.2): progresso rápido no início, desaceleração por bioma.
	check(marks.has(50) and float(marks[50]) > 30.0 and float(marks[50]) < 300.0, "50 m entre 30 s e 5 min")
	check(d.depth_m() >= 120 and d.depth_m() <= 450, "10 min levam a 120–450 m (%d m)" % d.depth_m())
	check(bought >= 10, "compra ao menos 10 upgrades em 10 minutos (%d)" % bought)
	d.free()
