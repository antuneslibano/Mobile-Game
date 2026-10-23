class_name ShipLooks
extends RefCounted
## Visual da nave (0.11): a nave muda de aparência conforme evolui. Cada encaixe tem
## opções liberadas por níveis de peça, minerais descobertos ou guardiões vencidos; o
## jogador escolhe no Hangar. Sem escolha, usa a melhor opção liberada (a nave "cresce"
## sozinha). Só visual: não altera atributos.

const SLOTS: Array[StringName] = [&"shape", &"drill", &"hull", &"engine", &"paint"]
const SLOT_NAMES: Dictionary = {&"shape": "FORMATO DA BROCA", &"drill": "MATERIAL DA BROCA", &"hull": "CASCO", &"engine": "MOTORES", &"paint": "PINTURA"}

## slot → [[id, nome, requisito]]; requisito: "" (sempre), "lvl:<peça>:<n>",
## "res:<recurso>" ou "guardian:<região>". Ordem = do básico ao mais avançado.
const OPTIONS: Dictionary = {
	# Formato da broca (0.19): muda o desenho de verdade (não só a cor).
	&"shape": [
		[&"cone", "Padrão", ""],
		[&"needle", "Agulha", "lvl:speed:3"],
		[&"fat", "Robusta", "lvl:damage:3"],
		[&"twin", "Dupla", "lvl:damage:7"],
		[&"crown", "Coroa", "guardian:vale"],
	],
	&"drill": [
		[&"steel", "Aço", ""],
		[&"gold", "Dourada", "lvl:damage:4"],
		[&"crystal", "Cristal", "lvl:damage:8"],
		[&"root", "Raiz-Mãe", "guardian:vale"],
		[&"plasma", "Plasma", "lvl:damage:12"],
		[&"fossil", "Fóssil", "bp:bp_fossil"],
		[&"ember", "Brasa", "bp:bp_ember"],
	],
	&"hull": [
		[&"standard", "Padrão", ""],
		[&"armored", "Blindado", "lvl:hull:4"],
		[&"titanium", "Titânio", "lvl:hull:8"],
		[&"bark", "Casca", "bp:bp_bark"],
		[&"gilded", "Dourado", "bp:bp_gilded"],
	],
	&"engine": [
		[&"standard", "Padrão", ""],
		[&"turbo", "Turbo", "lvl:speed:4"],
		[&"tanks", "Tanques extras", "lvl:fuel_tank:4"],
		[&"reactor", "Reator", "lvl:energy:6"],
		[&"firefly", "Vaga-lume", "bp:bp_firefly"],
	],
	&"paint": [
		[&"yellow", "Amarelo", ""],
		[&"copper", "Cobre", "res:copper"],
		[&"emerald", "Esmeralda", "res:emerald"],
		[&"ruby", "Rubi", "res:ruby"],
		[&"amethyst", "Ametista", "res:amethyst"],
		[&"amber", "Âmbar", "bp:bp_amber"],
		[&"midnight", "Meia-noite", "bp:bp_midnight"],
		[&"chrome", "Cromada", "bp:bp_chrome"],
	],
}

## Cores de destaque de cada pintura: [claro, médio, escuro].
const PAINTS: Dictionary = {
	&"yellow": [Color("ffd970"), Color("f7b52c"), Color("c47a10")],
	&"copper": [Color("ffb080"), Color("e07a3a"), Color("8a3a14")],
	&"emerald": [Color("8affc0"), Color("2fd46a"), Color("10703a")],
	&"ruby": [Color("ff9aa8"), Color("ff3d5a"), Color("8a1024")],
	&"amethyst": [Color("e2c2ff"), Color("b07cff"), Color("5a2a9a")],
	&"amber": [Color("ffe0a0"), Color("ff9a1a"), Color("a04a00")],
	&"midnight": [Color("8a9cff"), Color("3a4aa8"), Color("181e48")],
	&"chrome": [Color("ffffff"), Color("c8d4e4"), Color("6a7890")],
}


static func is_unlocked(req: String, econ: Economy, done: Dictionary) -> bool:
	if req == "":
		return true
	var p: PackedStringArray = req.split(":")
	match p[0]:
		"lvl":
			return econ.get_level(StringName(p[1])) >= int(p[2])
		"res":
			return econ.discovered.has(StringName(p[1]))
		"guardian":
			return done.has(StringName(p[1]))
		"bp":
			return econ.blueprints.has(StringName(p[1]))
	return false


## Texto do requisito para o Hangar.
static func requirement_text(req: String) -> String:
	var p: PackedStringArray = req.split(":")
	match p[0]:
		"lvl":
			var def: UpgradeDef = UpgradeRegistry.get_def(StringName(p[1]))
			return "%s Nv. %s" % [def.display_name if def != null else p[1], p[2]]
		"res":
			var rd: ResourceDef = ResourceRegistry.get_def(StringName(p[1]))
			return "Descobrir %s" % (rd.display_name if rd != null else p[1])
		"guardian":
			return "Vencer o guardião de %s" % RegionRegistry.get_def(StringName(p[1])).display_name
		"bp":
			return "Planta em baú raro"
	return ""


## Visual efetivo: escolha salva (se ainda liberada) ou a melhor opção liberada.
static func resolve(chosen: Dictionary, econ: Economy, done: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for slot in SLOTS:
		var best: StringName = OPTIONS[slot][0][0]
		var pick: StringName = StringName(chosen.get(slot, &""))
		var pick_ok: bool = false
		for o: Array in OPTIONS[slot]:
			if is_unlocked(String(o[2]), econ, done):
				if slot not in [&"paint", &"shape"] and not String(o[2]).begins_with("bp:"):
					best = o[0]
				if o[0] == pick:
					pick_ok = true
		out[slot] = pick if pick_ok else best
	return out


## Chave estável para cache de sprites.
static func key(look: Dictionary) -> String:
	var parts: PackedStringArray = []
	for slot in SLOTS:
		parts.append(String(look.get(slot, OPTIONS[slot][0][0])))
	return "|".join(parts)


## Quantas opções estão liberadas (alerta do Hangar quando aumenta).
static func unlocked_count(econ: Economy, done: Dictionary) -> int:
	var n: int = 0
	for slot in SLOTS:
		for o: Array in OPTIONS[slot]:
			if is_unlocked(String(o[2]), econ, done):
				n += 1
	return n
