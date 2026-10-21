class_name MiningRules
extends RefCounted
## Fórmulas de mineração centralizadas (GAME_DESIGN.md §6).


## Dano efetivo de um golpe contra um material com determinada dureza.
static func effective_damage(raw: float, hardness: float) -> float:
	return maxf(raw - hardness, raw * Balance.MIN_DAMAGE_RATIO)


## Rola um golpe. Retorna Vector2(dano_bruto, 1.0 se crítico senão 0.0).
## A dureza é aplicada por célula em WorldModel.dig_circle.
static func roll_hit(stats: DrillStats, rng: RandomNumberGenerator) -> Vector2:
	var crit: bool = rng.randf() < stats.crit_chance
	var raw: float = stats.damage * (stats.crit_mult if crit else 1.0) * stats.efficiency
	return Vector2(raw, 1.0 if crit else 0.0)


## Golpes necessários (sem crítico) para atravessar 1 bloco de um material.
static func hits_to_break(stats: DrillStats, block_id: int) -> int:
	var def: BlockDef = BlockRegistry.get_def(block_id)
	if not def.breakable:
		return -1
	var dmg: float = effective_damage(stats.damage * stats.efficiency, def.hardness)
	return ceili(def.max_hp / dmg)
