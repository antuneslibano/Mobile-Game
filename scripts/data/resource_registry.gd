class_name ResourceRegistry
extends RefCounted
## Recursos e preços de venda (GAME_DESIGN.md §7.1). Valores ajustáveis aqui.

static var _defs: Dictionary = {}     ## StringName → ResourceDef
static var _order: Array[StringName] = []


static func _add(key: StringName, name: String, value: int, color: Color, currency: StringName = &"") -> void:
	var d := ResourceDef.new()
	d.key = key
	d.display_name = name
	d.sell_value = value
	d.color = color
	d.currency = currency
	_defs[key] = d
	_order.append(key)


static func _build() -> void:
	_add(&"dirt", "Terra", 1, Color("a7744d"))
	_add(&"stone", "Pedra", 2, Color("b0a8a0"))
	_add(&"copper", "Cobre", 8, Color("e08a4f"))
	_add(&"iron", "Ferro", 15, Color("d7c3b0"))
	_add(&"amethyst", "Ametista", 40, Color("c57bff"))
	_add(&"basalt", "Basalto", 30, Color("8a817e"))
	_add(&"gold", "Ouro", 60, Color("ffd54a"))
	_add(&"ruby", "Rubi", 120, Color("ff3d5a"))
	_add(&"abyss_stone", "Pedra abissal", 90, Color("4f8a8c"))
	_add(&"voidite", "Vazionita", 200, Color("9d5cff"))
	_add(&"artifact", "Artefato", 500, Color("5effc9"))
	_add(&"crystal", "Cristal", 0, Color("6fe3ff"), &"crystals")


static func get_def(key: StringName) -> ResourceDef:
	if _defs.is_empty():
		_build()
	return _defs.get(key)


static func has(key: StringName) -> bool:
	return get_def(key) != null


## Ordem de exibição (do mais comum ao mais raro).
static func order() -> Array[StringName]:
	if _defs.is_empty():
		_build()
	return _order
