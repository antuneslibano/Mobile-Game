extends "res://tests/test_case.gd"


func test_effective_damage_formula() -> void:
	check_eq(MiningRules.effective_damage(10.0, 3.0), 7.0, "dano - dureza")
	check_eq(MiningRules.effective_damage(10.0, 20.0), 10.0 * Balance.MIN_DAMAGE_RATIO, "piso mínimo de dano")
	check(MiningRules.effective_damage(4.0, 0.0) == 4.0, "sem dureza = dano bruto")


func test_hits_to_break_scale_with_damage() -> void:
	var weak := DrillStats.base()
	var strong := DrillStats.base()
	strong.damage = 40.0
	for id in [BlockRegistry.DIRT, BlockRegistry.STONE, BlockRegistry.BASALT, BlockRegistry.VOIDITE]:
		var a: int = MiningRules.hits_to_break(weak, id)
		var b: int = MiningRules.hits_to_break(strong, id)
		check(a > 0 and b > 0, "golpes positivos para %d" % id)
		check(b < a, "mais dano => menos golpes para %s (%d -> %d)" % [BlockRegistry.get_def(id).key, a, b])
	check_eq(MiningRules.hits_to_break(weak, BlockRegistry.BEDROCK), -1, "rocha-mãe inquebrável")
	note("golpes base: terra %d, pedra %d, basalto %d" % [MiningRules.hits_to_break(weak, BlockRegistry.DIRT),
			MiningRules.hits_to_break(weak, BlockRegistry.STONE), MiningRules.hits_to_break(weak, BlockRegistry.BASALT)])


func test_crit_rate() -> void:
	var s := DrillStats.base()
	s.crit_chance = 0.25
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var crits: int = 0
	var n: int = 4000
	for i in n:
		var hit: Vector2 = MiningRules.roll_hit(s, rng)
		if hit.y > 0.5:
			crits += 1
			check(absf(hit.x - s.damage * s.crit_mult) < 0.001, "dano crítico")
	var rate: float = float(crits) / n
	check(rate > 0.22 and rate < 0.28, "taxa de crítico ~25%% (%.3f)" % rate)
