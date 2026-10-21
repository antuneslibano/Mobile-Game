class_name UpgradeRegistry
extends RefCounted
## Lista ordenada de upgrades. Caminhos explícitos (funciona em builds exportadas,
## onde listar diretórios de recursos não é confiável).

const PATHS: Array[String] = [
	"res://data/upgrades/damage.tres",
	"res://data/upgrades/speed.tres",
	"res://data/upgrades/crit.tres",
	"res://data/upgrades/collect.tres",
	"res://data/upgrades/energy.tres",
	"res://data/upgrades/boost.tres",
	"res://data/upgrades/side_drill.tres",
	"res://data/upgrades/drone.tres",
	"res://data/upgrades/seismic.tres",
	"res://data/upgrades/cooling.tres",
]

## Fase atual do jogo: upgrades com available_from_phase maior aparecem bloqueados.
const CURRENT_PHASE: int = 3

static var _list: Array[UpgradeDef] = []
static var _by_id: Dictionary = {}


static func all() -> Array[UpgradeDef]:
	if _list.is_empty():
		for p in PATHS:
			var def: UpgradeDef = load(p) as UpgradeDef
			if def == null:
				push_error("Upgrade inválido: %s" % p)
				continue
			_list.append(def)
			_by_id[def.id] = def
	return _list


static func get_def(id: StringName) -> UpgradeDef:
	all()
	return _by_id.get(id)


static func is_available(def: UpgradeDef) -> bool:
	return def.available_from_phase <= CURRENT_PHASE
