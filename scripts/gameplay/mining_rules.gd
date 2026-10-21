class_name MiningRules
extends RefCounted
## Fórmulas de mineração centralizadas (GAME_DESIGN.md §6).


## Dano efetivo de um golpe contra um bloco com determinada dureza.
static func effective_damage(raw: float, hardness: float) -> float:
	return maxf(raw - hardness, raw * Balance.MIN_DAMAGE_RATIO)


## Rola um golpe. Retorna Vector2(dano_efetivo, 1.0 se crítico senão 0.0).
static func roll_hit(stats: DrillStats, hardness: float, side: bool, rng: RandomNumberGenerator) -> Vector2:
	var crit: bool = rng.randf() < stats.crit_chance
	var raw: float = stats.damage * (stats.crit_mult if crit else 1.0) * stats.efficiency
	var dmg: float = effective_damage(raw, hardness)
	if side:
		dmg *= stats.side_drill_mult
	return Vector2(dmg, 1.0 if crit else 0.0)


## Golpes necessários (sem crítico) para quebrar um bloco — usado em testes e na UI.
static func hits_to_break(stats: DrillStats, block_id: int) -> int:
	var def: BlockDef = BlockRegistry.get_def(block_id)
	if not def.breakable:
		return -1
	var dmg: float = effective_damage(stats.damage * stats.efficiency, def.hardness)
	return ceili(def.max_hp / dmg)
