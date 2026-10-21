extends "res://tests/test_case.gd"


func test_resource_registry_covers_all_drops() -> void:
	for def: BlockDef in BlockRegistry.all():
		for key: Variant in def.drops:
			check(ResourceRegistry.has(StringName(key)), "drop %s de %s tem ResourceDef" % [key, def.key])
	for key in ResourceRegistry.order():
		var r: ResourceDef = ResourceRegistry.get_def(key)
		check(r.sell_value >= 0, "%s valor >= 0" % key)
		if r.currency == &"":
			check(r.sell_value > 0, "minério %s vendável" % key)


func test_collect_cargo_and_crystals() -> void:
	var e := Economy.new()
	var g: Dictionary = e.collect({&"copper": 2, &"crystal": 1})
	check_eq(int(g.get(&"copper", 0)), 2, "ganhou 2 cobres")
	check_eq(int(e.cargo.get(&"copper", 0)), 2, "cobre na carga")
	check_eq(e.crystals, 1, "cristal vai direto para a carteira")
	check(not e.cargo.has(&"crystal"), "cristal não ocupa a carga")
	check_eq(e.cargo_value(), 2 * ResourceRegistry.get_def(&"copper").sell_value, "valor da carga")
	g = e.collect({&"unknown": 5})
	check(g.is_empty(), "recurso desconhecido ignorado")


func test_collect_multiplier_is_deterministic() -> void:
	var e := Economy.new()
	for i in 10:
		e.collect({&"dirt": 1}, 1.1)
	check_eq(int(e.cargo.get(&"dirt", 0)), 11, "10 blocos com +10% = 11 (frações acumulam)")
	var e2 := Economy.new()
	for i in 4:
		e2.collect({&"stone": 1}, 1.5)
	check_eq(int(e2.cargo.get(&"stone", 0)), 6, "4 × 1,5 = 6")


func test_sell_all_is_exact_and_idempotent() -> void:
	var e := Economy.new()
	e.collect({&"dirt": 3, &"iron": 2, &"gold": 1})
	var expected: int = 3 * ResourceRegistry.get_def(&"dirt").sell_value \
			+ 2 * ResourceRegistry.get_def(&"iron").sell_value + ResourceRegistry.get_def(&"gold").sell_value
	check_eq(e.sell_all(), expected, "venda paga o valor da carga")
	check_eq(e.credits, expected, "créditos creditados")
	check_eq(e.cargo_count(), 0, "carga vazia")
	check_eq(e.sell_all(), 0, "vender de novo não duplica")
	check_eq(e.credits, expected, "saldo inalterado")


func test_spend_never_goes_negative() -> void:
	var e := Economy.new()
	e.credits = 10
	check(not e.spend(Economy.CREDITS, 11), "não gasta além do saldo")
	check_eq(e.credits, 10, "saldo preservado")
	check(e.spend(Economy.CREDITS, 10), "gasta exatamente o saldo")
	check_eq(e.credits, 0, "zerado")
	check(not e.spend(Economy.CREDITS, -5), "valor negativo rejeitado")
