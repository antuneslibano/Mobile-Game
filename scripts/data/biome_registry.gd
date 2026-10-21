class_name BiomeRegistry
extends RefCounted
## Camadas de profundidade da região ATIVA (Fase "regiões"): cada região define as suas.
## O "id" de bioma usado pelo jogo (HUD, fundo do shader) é o índice da camada.

## Primeira camada (superfície).
const CRUST: int = 0
## Limite de camadas por região (linhas reservadas na paleta do shader).
const MAX_LAYERS: int = 6
## Amplitude (linhas) da borda serrilhada entre camadas.
const BORDER_JITTER_ROWS: int = 4

static var _defs: Array[BiomeDef] = []


## Define as camadas ativas (chamado ao aplicar uma região).
static func set_layers(layers: Array[BiomeDef]) -> void:
	_defs = layers


static func layers() -> Array[BiomeDef]:
	if _defs.is_empty():
		_defs = RegionRegistry.all()[0].layers
	return _defs


static func layer_count() -> int:
	return layers().size()


static func get_def(id: int) -> BiomeDef:
	var l: Array[BiomeDef] = layers()
	return l[clampi(id, 0, l.size() - 1)]


## Camada "nominal" de uma linha (sem serrilhado). Use o WorldGenerator para a camada real.
static func id_for_row(row: int) -> int:
	return id_for_row_in(layers(), row)


static func id_for_row_in(l: Array[BiomeDef], row: int) -> int:
	for i in range(l.size() - 1, -1, -1):
		if row >= l[i].start_row:
			return i
	return 0
