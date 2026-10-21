class_name EnergySystem
extends RefCounted
## Energia conquistada e Sobrecarga.
## - A energia NÃO regenera com o tempo: enche cavando, proporcional ao valor do material
##   (minérios valiosos e Cristais enchem muito mais) e ao upgrade Bateria.
## - A Sobrecarga só pode ser ativada com a barra CHEIA e consome tudo — não há como
##   ficar acionando repetidamente. Durante ela a barra esvazia e nada é carregado.
## - A mineração normal nunca depende de energia.

var energy: float = 0.0
var max_energy: float = Balance.ENERGY_MAX
var boost_left: float = 0.0
var boost_total: float = 0.0


static func boost_duration(s: DrillStats) -> float:
	return Balance.OVERDRIVE_DURATION + Balance.OVERDRIVE_DURATION_PER_LEVEL * s.boost_level


static func boost_mult(s: DrillStats) -> float:
	return Balance.OVERDRIVE_DIG_MULT + Balance.OVERDRIVE_DIG_PER_LEVEL * s.boost_level


## Carga obtida por um valor em Créditos e Cristais coletados a uma profundidade.
static func charge_for(credits_value: float, crystals: float, depth_m: int, s: DrillStats) -> float:
	var raw: float = credits_value * Balance.ENERGY_PER_CREDIT + crystals * Balance.ENERGY_PER_CRYSTAL
	return raw * s.energy_gain / (1.0 + float(maxi(depth_m, 0)) / Balance.ENERGY_DEPTH_SCALE_M)


func reset(_s: DrillStats) -> void:
	energy = 0.0
	boost_left = 0.0
	boost_total = 0.0


func is_boosting() -> bool:
	return boost_left > 0.0


func is_ready() -> bool:
	return not is_boosting() and energy >= max_energy - 0.001


func fill_ratio() -> float:
	return clampf(energy / max_energy, 0.0, 1.0)


## Adiciona carga (ignorada durante a Sobrecarga). Retorna true se a barra acabou de encher.
func add_charge(amount: float) -> bool:
	if is_boosting() or amount <= 0.0:
		return false
	var was_full: bool = energy >= max_energy - 0.001
	energy = minf(max_energy, energy + amount)
	return not was_full and energy >= max_energy - 0.001


## Avança o tempo. Retorna true se a Sobrecarga começou neste passo.
func step(delta: float, s: DrillStats, want_boost: bool) -> bool:
	var started: bool = false
	if want_boost and is_ready():
		boost_total = boost_duration(s)
		boost_left = boost_total
		started = true
	if boost_left > 0.0:
		boost_left = maxf(0.0, boost_left - delta)
		energy = max_energy * (boost_left / boost_total)
	return started


func speed_mult(s: DrillStats) -> float:
	return boost_mult(s) if is_boosting() else 1.0
