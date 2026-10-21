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
## Módulos equipados (ordem = slot). Limite em Balance.MODULE_SLOTS.
var equipped_modules: Array[StringName] = []
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


## Serialização para o salvamento (tipos simples, compatível com JSON).
func to_dict() -> Dictionary:
	var cargo_out: Dictionary = {}
	for k: StringName in cargo:
		cargo_out[String(k)] = int(cargo[k])
	var levels: Dictionary = {}
	for k: StringName in upgrade_levels:
		levels[String(k)] = int(upgrade_levels[k])
	var eq: Array = []
	for m in equipped_modules:
		eq.append(String(m))
	return {
		"credits": credits, "crystals": crystals, "lifetime_credits": lifetime_credits,
		"cargo": cargo_out, "upgrades": levels, "equipped": eq,
	}


## Restaura a partir do salvamento, validando tudo (valores inválidos são descartados).
static func from_dict(d: Dictionary) -> Economy:
	var e := Economy.new()
	e.credits = maxi(0, int(d.get("credits", 0)))
	e.crystals = maxi(0, int(d.get("crystals", 0)))
	e.lifetime_credits = maxi(0, int(d.get("lifetime_credits", 0)))
	var cargo_in: Variant = d.get("cargo", {})
	if cargo_in is Dictionary:
		for k: Variant in cargo_in:
			var key := StringName(str(k))
			var r: ResourceDef = ResourceRegistry.get_def(key)
			if r != null and r.currency == &"" and int(cargo_in[k]) > 0:
				e.cargo[key] = int(cargo_in[k])
	var up_in: Variant = d.get("upgrades", {})
	if up_in is Dictionary:
		for k: Variant in up_in:
			var def: UpgradeDef = UpgradeRegistry.get_def(StringName(str(k)))
			if def != null:
				e.upgrade_levels[def.id] = clampi(int(up_in[k]), 0, def.max_level)
	var eq_in: Variant = d.get("equipped", [])
	if eq_in is Array:
		for m: Variant in eq_in:
			var id := StringName(str(m))
			if id in ModuleSystem.ALL and e.owns_module(id) and not e.equipped_modules.has(id) \
					and e.equipped_modules.size() < Balance.MODULE_SLOTS:
				e.equipped_modules.append(id)
	return e


func owns_module(id: StringName) -> bool:
	return get_level(id) > 0


## Equipa/remove um módulo. Retorna false se não possuído ou sem slot livre.
func toggle_module(id: StringName, slots: int) -> bool:
	if equipped_modules.has(id):
		equipped_modules.erase(id)
		return true
	if not owns_module(id) or equipped_modules.size() >= slots:
		return false
	equipped_modules.append(id)
	return true
