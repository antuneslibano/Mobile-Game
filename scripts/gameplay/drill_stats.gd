class_name DrillStats
extends RefCounted
## Atributos efetivos da perfuradora. Na Fase 2, ProgressionService gera esta instância
## a partir de upgrades e módulos; a Drill só lê estes valores.

var damage: float = Balance.DRILL_BASE_DAMAGE
var hits_per_second: float = Balance.DRILL_BASE_HITS_PER_SEC
var crit_chance: float = Balance.DRILL_BASE_CRIT_CHANCE
var crit_mult: float = Balance.DRILL_BASE_CRIT_MULT
var move_speed_blocks: float = Balance.DRILL_MOVE_SPEED_BLOCKS
var side_drill_mult: float = Balance.SIDE_DRILL_MULT
## Multiplicador global de eficiência (impulso, calor... nas próximas fases).
var efficiency: float = 1.0


static func base() -> DrillStats:
	return DrillStats.new()


func duplicate_stats() -> DrillStats:
	var s := DrillStats.new()
	s.damage = damage
	s.hits_per_second = hits_per_second
	s.crit_chance = crit_chance
	s.crit_mult = crit_mult
	s.move_speed_blocks = move_speed_blocks
	s.side_drill_mult = side_drill_mult
	s.efficiency = efficiency
	return s
