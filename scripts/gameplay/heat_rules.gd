class_name HeatRules
extends RefCounted
## Calor (0.18): a temperatura sobe com a profundidade, da superfície até o fundo da região
## (cada região tem a sua faixa: o Vale vai de 25 °C a 140 °C; o Abismo já começa quente).
## A nave aguenta até o seu limite térmico (Balance.TEMP_LIMIT_BASE + Refrigeração). Acima
## dele, a broca perde eficiência e o casco sofre dano, mais quanto mais passa do limite:
## para descer mais é preciso melhorar a Refrigeração.

## Faixa de temperatura da região ativa (°C na superfície e no fundo, profundidade do fundo).
static var temp_surface: float = 25.0
static var temp_bottom: float = 140.0
static var bottom_m: int = 600


static func configure(r: RegionDef) -> void:
	temp_surface = r.temp_surface
	temp_bottom = r.temp_bottom
	bottom_m = maxi(1, r.target_depth_m)


## Temperatura (°C) numa profundidade da região ativa.
static func temp_at(depth_m: int) -> float:
	var k: float = clampf(float(depth_m) / float(bottom_m), 0.0, 1.0)
	return lerpf(temp_surface, temp_bottom, k)


## Graus acima do limite térmico (0 se dentro do limite).
static func over(depth_m: int, limit: float) -> float:
	return maxf(0.0, temp_at(depth_m) - limit)


## Fração de eficiência perdida pela broca (0..HEAT_PENALTY_MAX).
static func penalty(depth_m: int, limit: float) -> float:
	return minf(Balance.HEAT_PENALTY_MAX, over(depth_m, limit) / Balance.HEAT_OVER_SPAN_C)


## Dano no casco por segundo pelo superaquecimento.
static func hull_dps(depth_m: int, limit: float) -> float:
	return over(depth_m, limit) * Balance.HEAT_HULL_DPS_PER_C


## Profundidade em que a temperatura chega ao limite (até onde a nave desce sem sofrer).
static func safe_depth(limit: float) -> int:
	if limit >= temp_bottom:
		return bottom_m
	if limit <= temp_surface:
		return 0
	return int((limit - temp_surface) / (temp_bottom - temp_surface) * bottom_m)
