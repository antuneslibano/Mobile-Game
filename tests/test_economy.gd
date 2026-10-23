extends "res://tests/test_case.gd"


func test_resource_registry_covers_all_drops() -> void:
	for def: BlockDef in BlockRegistry.all():
		for key: Variant in def.drops:
			check(ResourceRegistry.has(StringName(key)), "drop %s de %s tem ResourceDef" % [key, def.key])
	for key in ResourceRegistry.order():
		var r: ResourceDef = ResourceRegistry.get_def(key)
		check(r.sell_value >= 0, "%s valor >= 0" % key)
		if r.currency == &"" and key != &"bio_sample":
			check(r.sell_value > 0, "minério %s vendável" % key)
	# 0.18: criaturas rendem couro, que vende; amostras de salvamentos antigos viram couro.
	check(ResourceRegistry.get_def(&"leather").sell_value > 0, "couro tem valor de venda")
	var old := Economy.from_dict({"cargo": {"bio_sample": 3, "leather": 1}, "discovered": ["bio_sample"]})
	check(int(old.cargo.get(&"leather", 0)) == 4 and not old.cargo.has(&"bio_sample") and old.discovered.has(&"leather"), "amostras antigas viram couro")


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


## 0.19: relíquia única por região, numa câmara escondida; bônus ao instalar.
func test_relics() -> void:
	for r: StringName in Relics.REGION_ORDER:
		var id: int = Relics.block_for(r)
		var key: StringName = Relics.for_region(r)[0]
		check(Relics.is_relic_block(id) and BlockRegistry.get_def(id).drops.has(key), "bloco da relíquia de %s solta %s" % [r, key])
		check(ResourceRegistry.get_def(key).sell_value >= 6000, "relíquia %s vale muito" % key)
	var region: RegionDef = RegionRegistry.get_def(RegionRegistry.VALE)
	var w := WorldModel.new(91, region)
	var rb: Vector2i = w.generator.relic_block
	check(rb.y >= int(region.target_depth_m * 0.45) and rb.y < RegionRegistry.chamber_top(region), "relíquia no fundo, antes da câmara")
	var sub: int = Balance.CELL_SUB
	var found: int = 0
	var relic_id: int = Relics.block_for(&"vale")
	for y in range(0, region.target_depth_m + 20):
		for x in Balance.WORLD_WIDTH:
			if w.peek_cell(Vector2i(x * sub + 1, y * sub + 1)) == relic_id:
				found += 1
	check_eq(found, 1, "uma só relíquia no mapa todo")
	check_eq(w.peek_cell(Vector2i(rb.x * sub - 1, rb.y * sub + 1)), BlockRegistry.AIR, "câmara aberta em volta")
	check(WorldModel.new(92, region).generator.relic_block != rb, "outra semente, outro lugar")
	var s := DrillStats.base()
	var before: float = s.collect_mult
	Relics.apply(s, {&"relic_seed": true})
	check(is_equal_approx(s.collect_mult, before + 0.15), "Semente Primordial: +15% de coleta")
	var e := Economy.new()
	e.cargo = {&"relic_seed": 1, &"copper": 2}
	check_eq(e.cargo_value(), 2 * ResourceRegistry.get_def(&"copper").sell_value, "relíquia fora do valor da carga")
	e.sell_all()
	check(e.cargo.has(&"relic_seed"), "vender tudo não vende a relíquia")
	e.relics[&"relic_amber"] = true
	var back := Economy.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	check(back.relics.has(&"relic_amber") and back.cargo.has(&"relic_seed"), "relíquias salvas")
