class_name HeatRules
extends RefCounted
## Calor ambiental a partir de 300 m (GAME_DESIGN.md §7.5). Reduz a velocidade de
## perfuração; nunca destrói recursos. Refrigeração reduz a penalidade.


static func heat_at(depth_m: int) -> float:
	if depth_m < Balance.HEAT_START_M:
		return 0.0
	return clampf(float(depth_m - Balance.HEAT_START_M) * Balance.HEAT_PER_M, 0.0, Balance.HEAT_MAX)


## Fração de eficiência perdida (0..HEAT_PENALTY_MAX), já com a refrigeração aplicada.
static func penalty(depth_m: int, cooling: float) -> float:
	var raw: float = minf(Balance.HEAT_PENALTY_MAX, heat_at(depth_m) * Balance.HEAT_PENALTY_PER_LEVEL)
	return raw * (1.0 - clampf(cooling, 0.0, 1.0))


static func efficiency(depth_m: int, cooling: float) -> float:
	return 1.0 - penalty(depth_m, cooling)
