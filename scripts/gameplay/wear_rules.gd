class_name WearRules
extends RefCounted
## Desgaste da nave (0.19): quebrar blocos suja e enferruja a nave; levar dano amassa o
## casco. Sujeira e ferrugem deixam a broca mais lenta; amassados fazem a expedição
## começar com o casco já ferido. Limpa e conserta no Hangar (arrastando as ferramentas).
## Estado: {"dirt": 0..1, "rust": 0..1, "dents": 0..1}.

const KINDS: Array[StringName] = [&"dirt", &"rust", &"dents"]
const NAMES: Dictionary = {&"dirt": "Sujeira", &"rust": "Ferrugem", &"dents": "Amassados"}


static func fresh() -> Dictionary:
	return {&"dirt": 0.0, &"rust": 0.0, &"dents": 0.0}


## Células removidas pela broca (16 = 1 bloco).
static func add_dig(w: Dictionary, cells: int) -> void:
	var blocks: float = float(cells) / Balance.CELLS_PER_BLOCK
	w[&"dirt"] = minf(1.0, float(w.get(&"dirt", 0.0)) + blocks * Balance.WEAR_DIRT_PER_BLOCK)
	w[&"rust"] = minf(1.0, float(w.get(&"rust", 0.0)) + blocks * Balance.WEAR_RUST_PER_BLOCK)


## Dano no casco (amassados proporcionais à fração do casco perdida).
static func add_damage(w: Dictionary, amount: float, hull_max: float) -> void:
	if amount <= 0.0 or hull_max <= 0.0:
		return
	w[&"dents"] = minf(1.0, float(w.get(&"dents", 0.0)) + amount / hull_max * Balance.WEAR_DENTS_PER_HULL)


## Fração de eficiência perdida pela broca (sujeira + ferrugem).
static func penalty(w: Dictionary) -> float:
	return minf(Balance.WEAR_PENALTY_MAX, float(w.get(&"dirt", 0.0)) * Balance.WEAR_DIRT_PENALTY + float(w.get(&"rust", 0.0)) * Balance.WEAR_RUST_PENALTY)


## Fração do casco com que a expedição começa (amassados).
static func hull_start_ratio(w: Dictionary) -> float:
	return 1.0 - float(w.get(&"dents", 0.0)) * Balance.WEAR_DENTS_HULL


## Algo para cuidar (aviso do Hangar).
static func needs_care(w: Dictionary) -> bool:
	for k in KINDS:
		if float(w.get(k, 0.0)) >= Balance.WEAR_CARE_ALERT:
			return true
	return false


## Nave limpa e consertada (0.20): só assim dá para trocar o visual.
static func is_clean(w: Dictionary) -> bool:
	for k in KINDS:
		if float(w.get(k, 0.0)) > Balance.WEAR_CLEAN_MAX:
			return false
	return true


static func from_dict(d: Variant) -> Dictionary:
	var w: Dictionary = fresh()
	if d is Dictionary:
		for k in KINDS:
			w[k] = clampf(float((d as Dictionary).get(String(k), 0.0)), 0.0, 1.0)
	return w


static func to_dict(w: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in KINDS:
		out[String(k)] = snappedf(float(w.get(k, 0.0)), 0.001)
	return out
