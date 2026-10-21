class_name EnergySystem
extends RefCounted
## Energia e impulso. A energia só alimenta o impulso: a mineração normal nunca depende dela.

var energy: float = Balance.ENERGY_BASE_MAX
var max_energy: float = Balance.ENERGY_BASE_MAX
var boost_left: float = 0.0


static func boost_duration(s: DrillStats) -> float:
	return Balance.BOOST_DURATION + Balance.BOOST_DURATION_PER_LEVEL * s.boost_level


static func boost_mult(s: DrillStats) -> float:
	return Balance.BOOST_SPEED_MULT + Balance.BOOST_SPEED_PER_LEVEL * s.boost_level


func reset(s: DrillStats) -> void:
	max_energy = s.max_energy
	energy = max_energy
	boost_left = 0.0


func is_boosting() -> bool:
	return boost_left > 0.0


func can_boost() -> bool:
	return not is_boosting() and energy >= Balance.BOOST_COST


## Avança o tempo. Retorna true se um impulso começou neste passo.
func step(delta: float, s: DrillStats, want_boost: bool) -> bool:
	max_energy = s.max_energy
	var started: bool = false
	if want_boost and can_boost():
		energy -= Balance.BOOST_COST
		boost_left = boost_duration(s)
		started = true
	if boost_left > 0.0:
		boost_left = maxf(0.0, boost_left - delta)
	energy = minf(max_energy, energy + Balance.ENERGY_REGEN_PER_SEC * delta)
	return started


func speed_mult(s: DrillStats) -> float:
	return boost_mult(s) if is_boosting() else 1.0
