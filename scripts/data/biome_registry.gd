class_name BiomeRegistry
extends RefCounted
## Biomas por profundidade (linhas = metros). Ver GAME_DESIGN.md §5.3.

const CRUST: int = 0
const CRYSTAL_CAVES: int = 1
const MAGMA_ZONE: int = 2
const ANCIENT_ABYSS: int = 3
const COUNT: int = 4

## Amplitude (linhas) da borda serrilhada entre biomas.
const BORDER_JITTER_ROWS: int = 4

static var _defs: Array[BiomeDef] = []


static func _build() -> void:
	var list: Array[BiomeDef] = []

	var crust := BiomeDef.new()
	crust.id = CRUST
	crust.display_name = "Crosta"
	crust.start_row = 0
	crust.end_row = 100
	crust.cave_threshold = 0.67
	crust.primary_block = BlockRegistry.DIRT
	crust.secondary_block = BlockRegistry.STONE
	crust.secondary_ratio = 0.35
	crust.ore_table = [[BlockRegistry.COPPER, 0.050, 3], [BlockRegistry.IRON, 0.030, 25], [BlockRegistry.CHEST, 0.0025, 15]]
	crust.back_color = Color("2a1d16")
	crust.fog_color = Color("1a120d")
	crust.ui_color = Color("e0a96d")
	list.append(crust)

	var caves := BiomeDef.new()
	caves.id = CRYSTAL_CAVES
	caves.display_name = "Cavernas Cristalinas"
	caves.start_row = 100
	caves.end_row = 300
	caves.cave_threshold = 0.6
	caves.primary_block = BlockRegistry.CRYSTAL_ROCK
	caves.secondary_block = BlockRegistry.HARD_ROCK
	caves.secondary_ratio = 0.4
	caves.ore_table = [[BlockRegistry.IRON, 0.025, 100], [BlockRegistry.CRYSTAL, 0.045, 100], [BlockRegistry.AMETHYST, 0.018, 160]]
	caves.back_color = Color("181a2c")
	caves.fog_color = Color("0e0f1c")
	caves.ui_color = Color("8fb4ff")
	list.append(caves)

	var magma := BiomeDef.new()
	magma.id = MAGMA_ZONE
	magma.display_name = "Zona Magmática"
	magma.start_row = 300
	magma.end_row = 600
	magma.cave_threshold = 0.65
	magma.primary_block = BlockRegistry.BASALT
	magma.secondary_block = BlockRegistry.MAGMA_ROCK
	magma.secondary_ratio = 0.3
	magma.ore_table = [[BlockRegistry.GOLD, 0.030, 300], [BlockRegistry.RUBY, 0.012, 380], [BlockRegistry.CRYSTAL, 0.010, 300]]
	magma.heat = 1.0
	magma.back_color = Color("1e1210")
	magma.fog_color = Color("140a08")
	magma.ui_color = Color("ff8a4a")
	list.append(magma)

	var abyss := BiomeDef.new()
	abyss.id = ANCIENT_ABYSS
	abyss.display_name = "Abismo Ancestral"
	abyss.start_row = 600
	abyss.end_row = 1000
	abyss.cave_threshold = 0.63
	abyss.primary_block = BlockRegistry.ABYSS_STONE
	abyss.secondary_block = BlockRegistry.BASALT
	abyss.secondary_ratio = 0.15
	abyss.ore_table = [[BlockRegistry.VOIDITE, 0.025, 600], [BlockRegistry.ARTIFACT, 0.004, 650], [BlockRegistry.GOLD, 0.012, 600]]
	abyss.heat = 3.0
	abyss.back_color = Color("0c1a1c")
	abyss.fog_color = Color("061012")
	abyss.ui_color = Color("6fffd8")
	list.append(abyss)

	_defs = list


static func get_def(id: int) -> BiomeDef:
	if _defs.is_empty():
		_build()
	return _defs[clampi(id, 0, COUNT - 1)]


## Bioma "nominal" de uma linha (sem serrilhado). Use o WorldGenerator para o bioma real.
static func id_for_row(row: int) -> int:
	if _defs.is_empty():
		_build()
	for i in range(COUNT - 1, -1, -1):
		if row >= _defs[i].start_row:
			return i
	return CRUST
