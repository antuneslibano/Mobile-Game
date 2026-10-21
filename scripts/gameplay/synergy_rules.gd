class_name SynergyRules
extends RefCounted
## Sinergias declarativas: cada entrada exige módulos equipados e/ou atributos mínimos.
## Novas sinergias entram aqui e são consultadas pelos sistemas com is_active().

const CRITICAL_RESONANCE: StringName = &"critical_resonance"

const DEFS: Array[Dictionary] = [
	{
		"id": CRITICAL_RESONANCE,
		"name": "Ressonância Crítica",
		"modules": [&"seismic"],
		"min_crit": 0.0,
		"description": "Crítico × Pulso sísmico: cada golpe crítico recarrega 0,6 s do pulso, e o pulso pode ser crítico com 1,5× a sua chance de crítico.",
	},
]


static func is_active(id: StringName, equipped: Array[StringName], stats: DrillStats) -> bool:
	for d in DEFS:
		if d["id"] != id:
			continue
		for m: StringName in d["modules"]:
			if not equipped.has(m):
				return false
		return stats.crit_chance > float(d["min_crit"])
	return false


static func active_list(equipped: Array[StringName], stats: DrillStats) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in DEFS:
		if is_active(d["id"], equipped, stats):
			out.append(d)
	return out
