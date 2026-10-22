class_name DrillStats
extends RefCounted
## Atributos efetivos da perfuradora. Na Fase 2, ProgressionService gera esta instância
## a partir de upgrades e módulos; a Drill só lê estes valores.

var damage: float = Balance.DRILL_BASE_DAMAGE
var hits_per_second: float = Balance.DRILL_BASE_HITS_PER_SEC
var crit_chance: float = Balance.DRILL_BASE_CRIT_CHANCE
var crit_mult: float = Balance.DRILL_BASE_CRIT_MULT
var move_speed_blocks: float = Balance.DRILL_MOVE_SPEED_BLOCKS
## Multiplicador global de eficiência (impulso, calor... nas próximas fases).
var efficiency: float = 1.0
## Multiplicador de recursos coletados (upgrade Coleta).
var collect_mult: float = 1.0
## Multiplicador de carga de energia (upgrade Bateria).
var energy_gain: float = 1.0
## Redução da penalidade de calor, 0..0.9 (Fase 3).
var cooling: float = 0.0
## Nível do upgrade de impulso.
var boost_level: int = 0
## Expedição (0.9): tanque, consumo (multiplicador) e casco.
var fuel_max: float = Balance.FUEL_BASE
var fuel_use: float = 1.0
var hull_max: float = Balance.HULL_BASE
## Nível da broca (0.12): quais minérios ela consegue quebrar (MiningRules.required_tier).
var drill_tier: int = 0
## Níveis de módulos: StringName → int (Fase 3).
var module_levels: Dictionary = {}


static func base() -> DrillStats:
	return DrillStats.new()


func duplicate_stats() -> DrillStats:
	var s := DrillStats.new()
	s.damage = damage
	s.hits_per_second = hits_per_second
	s.crit_chance = crit_chance
	s.crit_mult = crit_mult
	s.move_speed_blocks = move_speed_blocks
	s.efficiency = efficiency
	s.collect_mult = collect_mult
	s.energy_gain = energy_gain
	s.cooling = cooling
	s.boost_level = boost_level
	s.fuel_max = fuel_max
	s.fuel_use = fuel_use
	s.hull_max = hull_max
	s.module_levels = module_levels.duplicate()
	return s
