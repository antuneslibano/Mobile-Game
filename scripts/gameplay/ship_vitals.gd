class_name ShipVitals
extends RefCounted
## Combustível e casco da nave durante uma expedição (regras puras, testáveis).
## Combustível: gasta enquanto a nave se move ou cava (×1,5 na Sobrecarga); parada não gasta.
## Carvão abastece. Casco: sofre com calor acima do nível seguro (a refrigeração reduz) e,
## nas próximas versões, com criaturas e desmoronamentos. Qualquer um dos dois zerado
## encerra a expedição com resgate de emergência.

var fuel: float = Balance.FUEL_BASE
var fuel_max: float = Balance.FUEL_BASE
var hull: float = Balance.HULL_BASE
var hull_max: float = Balance.HULL_BASE
## Dano de casco por segundo no último passo (para alertas visuais).
var hull_dps: float = 0.0


func reset(s: DrillStats, fuel_ratio: float = 1.0) -> void:
	fuel_max = s.fuel_max
	fuel = fuel_max * clampf(fuel_ratio, 0.0, 1.0)
	hull_max = s.hull_max
	hull = hull_max
	hull_dps = 0.0


func fuel_ratio() -> float:
	return fuel / fuel_max if fuel_max > 0.0 else 0.0


func hull_ratio() -> float:
	return hull / hull_max if hull_max > 0.0 else 0.0


func is_out_of_fuel() -> bool:
	return fuel <= 0.0


func is_destroyed() -> bool:
	return hull <= 0.0


## Consumo por segundo de atividade (já com eficiência e Sobrecarga).
static func use_per_sec(s: DrillStats, boosting: bool) -> float:
	return Balance.FUEL_USE_PER_SEC * s.fuel_use * (Balance.FUEL_BOOST_MULT if boosting else 1.0)


## Dano de casco por segundo pelo calor: °C acima do limite térmico (0.18).
static func heat_dps(over_c: float) -> float:
	return maxf(0.0, over_c) * Balance.HEAT_HULL_DPS_PER_C


## Avança um passo. Retorna true se algo acabou de zerar (fim da expedição).
## over_c: graus acima do limite térmico da nave.
func step(delta: float, s: DrillStats, active: bool, boosting: bool, over_c: float) -> bool:
	var was_ok: bool = not is_out_of_fuel() and not is_destroyed()
	if active:
		fuel = maxf(0.0, fuel - use_per_sec(s, boosting) * delta)
	hull_dps = heat_dps(over_c)
	hull = maxf(0.0, hull - hull_dps * delta)
	return was_ok and (is_out_of_fuel() or is_destroyed())


func refuel(amount: float) -> void:
	fuel = minf(fuel_max, fuel + maxf(0.0, amount))


func damage(amount: float) -> bool:
	var was_ok: bool = hull > 0.0
	hull = maxf(0.0, hull - maxf(0.0, amount))
	return was_ok and hull <= 0.0
