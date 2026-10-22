class_name Chests
extends RefCounted
## Baús soterrados (0.12): cada baú tem raridade fixa (pela posição e seed do mundo) que
## aparece na cor da aura — comum (dourada), raro (azul) e lendário (roxa, com brilho).
## Abrir rende cristais e materiais conforme a profundidade e pode trazer uma **planta**:
## um visual exclusivo da nave (só sai de baú), escolhido depois no Hangar.
## Lendário sempre traz planta (se ainda houver alguma para achar); raro, às vezes.

const COMMON: int = 0
const RARE: int = 1
const LEGENDARY: int = 2
const NAMES: Array[String] = ["COMUM", "RARO", "LENDÁRIO"]
const COLORS: Array[Color] = [Color("ffd56a"), Color("5ab8ff"), Color("d070ff")]
const RARE_BLUEPRINT_CHANCE: float = 0.5

## Plantas de visual exclusivo: id → [encaixe, nome].
const BLUEPRINTS: Dictionary = {
	&"bp_fossil": [&"drill", "Broca Fóssil"],
	&"bp_ember": [&"drill", "Broca Brasa"],
	&"bp_bark": [&"hull", "Casco de Casca"],
	&"bp_gilded": [&"hull", "Casco Dourado"],
	&"bp_firefly": [&"engine", "Motor Vaga-lume"],
	&"bp_amber": [&"paint", "Pintura Âmbar"],
	&"bp_midnight": [&"paint", "Pintura Meia-noite"],
	&"bp_chrome": [&"paint", "Pintura Cromada"],
}


## Raridade de um baú (bloco em blocos, profundidade em m). Mais fundo = melhores baús.
static func rarity(block: Vector2i, world_seed: int, depth_m: int) -> int:
	var r: float = WorldGenerator.hash01(block.x, block.y, world_seed + 0xC0FFEE)
	var k: float = clampf(depth_m / 600.0, 0.0, 1.0)
	var legend: float = 0.04 + 0.08 * k
	var rare: float = 0.22 + 0.13 * k
	if r < legend:
		return LEGENDARY
	return RARE if r < legend + rare else COMMON


## Conteúdo extra ao abrir (além dos materiais do próprio bloco):
## {"drops": {recurso: n}, "blueprint": id ou &""}. owned = plantas já encontradas.
static func open(rar: int, block: Vector2i, world_seed: int, depth_m: int, owned: Dictionary) -> Dictionary:
	var mat: StringName = &"copper" if depth_m < 150 else (&"iron" if depth_m < 330 else &"silver")
	var drops: Dictionary = {}
	match rar:
		COMMON:
			drops = {&"crystal": 2, mat: 3}
		RARE:
			drops = {&"crystal": 5, mat: 5, &"quartz": 3}
		_:
			drops = {&"crystal": 10, mat: 6, &"gold": 2}
	var bp: StringName = &""
	var roll: float = WorldGenerator.hash01(block.y, block.x, world_seed + 0xB1E)
	if rar == LEGENDARY or (rar == RARE and roll < RARE_BLUEPRINT_CHANCE):
		var free: Array[StringName] = []
		for id: StringName in BLUEPRINTS:
			if not owned.has(id):
				free.append(id)
		if not free.is_empty():
			bp = free[int(roll * 997.0) % free.size()]
		else:
			drops[&"crystal"] = int(drops[&"crystal"]) + 5
	return {"drops": drops, "blueprint": bp}
