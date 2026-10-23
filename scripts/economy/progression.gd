class_name Progression
extends RefCounted
## Serviço de progressão: fórmulas de custo, aplicação de upgrades nos atributos e textos
## de antes/depois. Único lugar onde upgrades viram números de jogo.

const MAX_CRIT_CHANCE: float = 0.75
const MAX_COOLING: float = 0.9


static func cost(def: UpgradeDef, level: int) -> int:
	var mult: float = Balance.UPGRADE_CREDIT_COST_MULT if def.currency == Economy.CREDITS else 1.0
	return maxi(1, roundi(def.base_cost * mult * pow(def.cost_growth, level)))


static func is_maxed(def: UpgradeDef, level: int) -> bool:
	return level >= def.max_level


## LOCKED = fase futura; RESEARCH = projeto ainda não liberado (Recipes.requirement);
## NO_MATERIALS = faltam materiais no armazém; NO_FUNDS = falta moeda.
enum BuyStatus { OK, LOCKED, MAXED, NO_FUNDS, NO_MATERIALS, RESEARCH }


## Materiais do próximo nível (receita da Bancada).
static func materials(def: UpgradeDef, level: int) -> Dictionary:
	return Recipes.materials(def, level)


static func buy_status(econ: Economy, def: UpgradeDef) -> BuyStatus:
	if not UpgradeRegistry.is_available(def):
		return BuyStatus.LOCKED
	var level: int = econ.get_level(def.id)
	if is_maxed(def, level):
		return BuyStatus.MAXED
	if Recipes.requirement(def, level, econ.discovered, econ.tech) != "":
		return BuyStatus.RESEARCH
	if not econ.has_materials(materials(def, level)):
		return BuyStatus.NO_MATERIALS
	if not econ.can_afford(def.currency, cost(def, level)):
		return BuyStatus.NO_FUNDS
	return BuyStatus.OK


## Constrói um nível. Operação atômica: ou debita moeda e materiais e sobe o nível, ou não
## altera nada.
static func try_buy(econ: Economy, def: UpgradeDef) -> bool:
	if buy_status(econ, def) != BuyStatus.OK:
		return false
	var level: int = econ.get_level(def.id)
	if not econ.spend(def.currency, cost(def, level)):
		return false
	econ.spend_materials(materials(def, level))
	econ.set_level(def.id, level + 1)
	return true


static func build_stats(levels: Dictionary) -> DrillStats:
	var s := DrillStats.base()
	for def in UpgradeRegistry.all():
		var lvl: int = int(levels.get(def.id, 0))
		if lvl > 0 and UpgradeRegistry.is_available(def):
			apply_upgrade(s, def, lvl)
	s.drill_tier = MiningRules.tier_for_level(int(levels.get(&"damage", 0)))
	return s


static func apply_upgrade(s: DrillStats, def: UpgradeDef, lvl: int) -> void:
	var bonus: float = def.step * lvl
	match def.stat:
		&"damage":
			s.damage += bonus
		&"speed":
			s.hits_per_second *= 1.0 + bonus / 100.0
		&"crit":
			s.crit_chance = minf(MAX_CRIT_CHANCE, s.crit_chance + bonus / 100.0)
		&"collect":
			s.collect_mult += bonus / 100.0
		&"energy":
			s.energy_gain += Balance.ENERGY_GAIN_PER_LEVEL * lvl
		&"cooling":
			s.cooling = minf(MAX_COOLING, bonus / 100.0)
			s.temp_limit = Balance.TEMP_LIMIT_BASE + Balance.TEMP_PER_COOLING * lvl
		&"boost":
			s.boost_level = lvl
		&"fuel_tank":
			s.fuel_max = Balance.FUEL_BASE * (1.0 + bonus / 100.0)
		&"fuel_eff":
			s.fuel_use = maxf(0.4, 1.0 - bonus / 100.0)
		&"hull":
			s.hull_max = Balance.HULL_BASE + bonus
		_:
			s.module_levels[def.stat] = lvl


## Texto do valor efetivo de um atributo (para antes → depois).
static func stat_text(s: DrillStats, stat: StringName) -> String:
	match stat:
		&"damage":
			return "%.0f dano" % s.damage
		&"speed":
			return "%.1f golpes/s" % s.hits_per_second
		&"crit":
			return "%.0f%% crítico" % (s.crit_chance * 100.0)
		&"collect":
			return "+%.0f%% recursos" % ((s.collect_mult - 1.0) * 100.0)
		&"energy":
			return "+%.0f%% carga" % ((s.energy_gain - 1.0) * 100.0)
		&"cooling":
			return "aguenta %.0f °C" % s.temp_limit
		&"boost":
			return "%.1fs ×%.1f" % [EnergySystem.boost_duration(s), EnergySystem.boost_mult(s)]
		&"fuel_tank":
			return "%.0f de combustível" % s.fuel_max
		&"fuel_eff":
			return "%.2f/s de consumo" % (Balance.FUEL_USE_PER_SEC * s.fuel_use)
		&"hull":
			return "%.0f de casco" % s.hull_max
		&"side_drill":
			return "+%.0f px de túnel" % ModuleSystem.side_drill_bonus(s) if ModuleSystem.level(s, ModuleSystem.SIDE_DRILL) > 0 else "não adquirido"
		&"drone":
			return "a cada %.1fs" % ModuleSystem.drone_interval(s) if ModuleSystem.level(s, ModuleSystem.DRONE) > 0 else "não adquirido"
		&"seismic":
			return "a cada %.1fs" % ModuleSystem.pulse_interval(s) if ModuleSystem.level(s, ModuleSystem.SEISMIC) > 0 else "não adquirido"
		_:
			return "nível %d" % int(s.module_levels.get(stat, 0))


## [antes, depois] para o próximo nível do upgrade.
static func preview(def: UpgradeDef, levels: Dictionary) -> PackedStringArray:
	var next_levels: Dictionary = levels.duplicate()
	next_levels[def.id] = int(levels.get(def.id, 0)) + 1
	return PackedStringArray([
		stat_text(_stats_for(def, levels), def.stat),
		stat_text(_stats_for(def, next_levels), def.stat),
	])


## Atributos com os níveis dados; inclui o upgrade mesmo se bloqueado (apenas para exibição).
static func _stats_for(def: UpgradeDef, levels: Dictionary) -> DrillStats:
	var s := build_stats(levels)
	var lvl: int = int(levels.get(def.id, 0))
	if lvl > 0 and not UpgradeRegistry.is_available(def):
		apply_upgrade(s, def, lvl)
	return s
