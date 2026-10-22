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


# --- Níveis de broca (0.12) -----------------------------------------------------------
## A broca só quebra minérios até o seu nível: a inicial não fura ferro; aprimorando a
## Broca (dano) ela passa a quebrar ferro e prata, depois ouro, e assim por diante.
## Terreno e baús quebram com qualquer broca. Valores `[T]` em Balance.DRILL_TIER_LEVELS.
const TIER_NAMES: Array[String] = ["Aço", "Reforçada", "Dourada", "Cristal", "Diamante"]


## Nível de broca necessário para quebrar um bloco (0 = qualquer broca).
static func required_tier(block_id: int) -> int:
	var B := BlockRegistry
	match block_id:
		B.IRON, B.SILVER, B.CRYSTAL, B.FOSSIL:
			return 1
		B.GOLD, B.AMETHYST:
			return 2
		B.RUBY, B.EMERALD, B.TITANIUM, B.URANIUM, B.OBSIDIAN:
			return 3
		B.DIAMOND, B.METEORITE, B.VOIDITE, B.RARE_CRYSTAL, B.ARTIFACT:
			return 4
	return 0


## Nível da broca a partir do nível do aprimoramento Broca (dano).
static func tier_for_level(damage_level: int) -> int:
	var t: int = 0
	for i in Balance.DRILL_TIER_LEVELS.size():
		if damage_level >= Balance.DRILL_TIER_LEVELS[i]:
			t = i
	return t


static func can_break(block_id: int, drill_tier: int) -> bool:
	return required_tier(block_id) <= drill_tier
