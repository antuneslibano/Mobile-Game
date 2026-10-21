class_name Economy
extends RefCounted
## Carteira, carga e níveis de upgrade. Modelo puro (sem nós nem sinais globais):
## GameState o envolve e publica eventos no EventBus.

const CREDITS: StringName = &"credits"
const CRYSTALS: StringName = &"crystals"

var credits: int = 0
var crystals: int = 0
var cargo: Dictionary = {}            ## StringName → int
var upgrade_levels: Dictionary = {}   ## StringName → int
var lifetime_credits: int = 0
var _fraction: Dictionary = {}        ## StringName → float (sobra do multiplicador de coleta)


## Adiciona drops aplicando o multiplicador de coleta. Frações acumulam entre coletas
## (determinístico, sem aleatoriedade). Retorna o que foi efetivamente ganho.
func collect(drops: Dictionary, mult: float = 1.0) -> Dictionary:
	var gained: Dictionary = {}
	for k: Variant in drops:
		var key := StringName(k)
		var def: ResourceDef = ResourceRegistry.get_def(key)
		if def == null:
			continue
		var exact: float = float(drops[k]) * maxf(mult, 0.0) + float(_fraction.get(key, 0.0))
		var n: int = floori(exact + 0.0001)
		_fraction[key] = maxf(0.0, exact - n)
		if n <= 0:
			continue
		gained[key] = n
		if def.currency == CRYSTALS:
			crystals += n
		else:
			cargo[key] = int(cargo.get(key, 0)) + n
	return gained


func cargo_count() -> int:
	var n: int = 0
	for key: StringName in cargo:
		n += int(cargo[key])
	return n


func cargo_value() -> int:
	var v: int = 0
	for key: StringName in cargo:
		var def: ResourceDef = ResourceRegistry.get_def(key)
		if def != null:
			v += def.sell_value * int(cargo[key])
	return v


## Vende toda a carga. Retorna os Créditos recebidos.
func sell_all() -> int:
	var value: int = cargo_value()
	cargo.clear()
	credits += value
	lifetime_credits += value
	return value


func balance(currency: StringName) -> int:
	return crystals if currency == CRYSTALS else credits


func can_afford(currency: StringName, amount: int) -> bool:
	return amount >= 0 and balance(currency) >= amount


func spend(currency: StringName, amount: int) -> bool:
	if not can_afford(currency, amount):
		return false
	if currency == CRYSTALS:
		crystals -= amount
	else:
		credits -= amount
	return true


func get_level(id: StringName) -> int:
	return int(upgrade_levels.get(id, 0))


func set_level(id: StringName, level: int) -> void:
	upgrade_levels[id] = maxi(0, level)
