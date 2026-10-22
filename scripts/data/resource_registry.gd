class_name ResourceRegistry
extends RefCounted
## Recursos e preços de venda (GAME_DESIGN.md §7.1). Valores ajustáveis aqui.
## Minérios são raros e valiosos (vale desviar até eles); terra/pedra/basalto/pedra abissal
## ficam registrados só para salvamentos antigos — o terreno não rende mais nada.

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
	_add(&"copper", "Cobre", 30, Color("e08a4f"))
	_add(&"iron", "Ferro", 50, Color("d7c3b0"))
	_add(&"amethyst", "Ametista", 130, Color("c57bff"))
	_add(&"basalt", "Basalto", 30, Color("8a817e"))
	_add(&"gold", "Ouro", 200, Color("ffd54a"))
	_add(&"ruby", "Rubi", 380, Color("ff3d5a"))
	_add(&"abyss_stone", "Pedra abissal", 90, Color("4f8a8c"))
	_add(&"voidite", "Minério arcano", 600, Color("b06cff"))
	_add(&"artifact", "Artefato", 1500, Color("5effc9"))
	_add(&"silver", "Prata", 80, Color("d9e2ee"))
	_add(&"coal", "Carvão", 18, Color("8a8a9a"))
	_add(&"quartz", "Quartzo", 60, Color("f1f1f4"))
	_add(&"emerald", "Esmeralda", 280, Color("2fd46a"))
	_add(&"titanium", "Titânio", 340, Color("5f8fdf"))
	_add(&"uranium", "Urânio", 450, Color("a6f23a"))
	_add(&"obsidian", "Obsidiana", 220, Color("9a5cff"))
	_add(&"diamond", "Diamante", 900, Color("7fe0ff"))
	_add(&"fossil", "Fóssil", 350, Color("e3d3b0"))
	_add(&"meteorite", "Meteorito", 1200, Color("ff3a26"))
	_add(&"rare_crystal", "Cristal raro", 1800, Color("ff9ff3"))
	_add(&"crystal", "Cristal", 0, Color("6fe3ff"), &"crystals")
	_add(&"bio_sample", "Amostra biológica", 0, Color("9bff5a"))


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
