class_name BlockRegistry
extends RefCounted
## Tabela central de blocos. IDs cabem em um byte (PackedByteArray nos chunks).

const AIR: int = 0
const DIRT: int = 1
const STONE: int = 2
const COPPER: int = 3
const IRON: int = 4
const BEDROCK: int = 5
const CHEST: int = 6
const CRYSTAL_ROCK: int = 7
const HARD_ROCK: int = 8
const CRYSTAL: int = 9
const AMETHYST: int = 10
const BASALT: int = 11
const MAGMA_ROCK: int = 12
const GOLD: int = 13
const RUBY: int = 14
const ABYSS_STONE: int = 15
const VOIDITE: int = 16
const ARTIFACT: int = 17
# Terrenos novos (não coletáveis).
const SAND: int = 18
const CLAY: int = 19
const ICE: int = 20
const MUD: int = 21
# Depósitos coletáveis novos.
const SILVER: int = 22
const COAL: int = 23
const EMERALD: int = 24
const DIAMOND: int = 25
const QUARTZ: int = 26
const OBSIDIAN: int = 27
const URANIUM: int = 28
const TITANIUM: int = 29
const RARE_CRYSTAL: int = 30
const FOSSIL: int = 31
const METEORITE: int = 32
const COUNT: int = 33

static var _defs: Array[BlockDef] = []


static func _build() -> void:
	var list: Array[BlockDef] = []
	list.resize(COUNT)

	var air := BlockDef.make(AIR, &"air", "Ar", 0.0, 0.0, {}, BlockDef.Art.NONE,
			Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT)
	air.solid = false
	air.breakable = false
	list[AIR] = air

	list[DIRT] = BlockDef.make(DIRT, &"dirt", "Terra", 12.0, 0.0, {&"dirt": 1}, BlockDef.Art.DIRT,
			Color("8a5a3b"), Color("5e3b26"), Color("a7744d"))
	list[STONE] = BlockDef.make(STONE, &"stone", "Pedra", 30.0, 1.0, {&"stone": 1}, BlockDef.Art.STONE,
			Color("7d7570"), Color("57504c"), Color("9d958f"))
	list[COPPER] = BlockDef.make(COPPER, &"copper", "Cobre", 36.0, 1.0, {&"copper": 1}, BlockDef.Art.ORE,
			Color("7d7570"), Color("57504c"), Color("e08a4f"))
	list[IRON] = BlockDef.make(IRON, &"iron", "Ferro", 48.0, 2.0, {&"iron": 1}, BlockDef.Art.ORE,
			Color("6f6a68"), Color("4c4745"), Color("d7c3b0"))

	var bedrock := BlockDef.make(BEDROCK, &"bedrock", "Rocha-mãe", INF, 0.0, {}, BlockDef.Art.BEDROCK,
			Color("2c2830"), Color("1a171d"), Color("433d48"))
	bedrock.breakable = false
	list[BEDROCK] = bedrock

	var chest := BlockDef.make(CHEST, &"chest", "Baú soterrado", 14.0, 0.0,
			{&"copper": 3, &"iron": 2, &"crystal": 2}, BlockDef.Art.CHEST, Color("8b5a2b"), Color("4f3218"), Color("f2c14e"))
	chest.special = &"treasure"
	list[CHEST] = chest

	list[CRYSTAL_ROCK] = BlockDef.make(CRYSTAL_ROCK, &"crystal_rock", "Rocha cristalina", 60.0, 4.0,
			{&"stone": 3}, BlockDef.Art.STONE, Color("4a4f72"), Color("31344f"), Color("6c74a3"))
	list[HARD_ROCK] = BlockDef.make(HARD_ROCK, &"hard_rock", "Rocha dura", 110.0, 7.0,
			{&"stone": 5}, BlockDef.Art.STONE, Color("5b5468"), Color("3d374a"), Color("7a7290"))
	list[CRYSTAL] = BlockDef.make(CRYSTAL, &"crystal", "Cristal", 70.0, 4.0,
			{&"crystal": 2}, BlockDef.Art.CRYSTAL, Color("4a4f72"), Color("31344f"), Color("6fe3ff"))
	list[AMETHYST] = BlockDef.make(AMETHYST, &"amethyst", "Ametista", 100.0, 6.0,
			{&"amethyst": 1, &"crystal": 2}, BlockDef.Art.CRYSTAL, Color("3b3d52"), Color("26273a"), Color("c57bff"))

	list[BASALT] = BlockDef.make(BASALT, &"basalt", "Basalto", 220.0, 14.0,
			{&"basalt": 1}, BlockDef.Art.STONE, Color("35302f"), Color("1f1b1b"), Color("4d4644"))
	list[MAGMA_ROCK] = BlockDef.make(MAGMA_ROCK, &"magma_rock", "Rocha magmática", 320.0, 18.0,
			{&"basalt": 1}, BlockDef.Art.MAGMA, Color("3a2522"), Color("221514"), Color("ff7a2e"))
	list[GOLD] = BlockDef.make(GOLD, &"gold", "Ouro", 260.0, 16.0,
			{&"gold": 1}, BlockDef.Art.ORE, Color("35302f"), Color("1f1b1b"), Color("ffd54a"))
	list[RUBY] = BlockDef.make(RUBY, &"ruby", "Rubi", 360.0, 20.0,
			{&"ruby": 1}, BlockDef.Art.CRYSTAL, Color("35302f"), Color("1f1b1b"), Color("ff3d5a"))

	list[ABYSS_STONE] = BlockDef.make(ABYSS_STONE, &"abyss_stone", "Pedra abissal", 700.0, 30.0,
			{&"abyss_stone": 1}, BlockDef.Art.STONE, Color("1f3a3c"), Color("122426"), Color("2f5658"))
	list[VOIDITE] = BlockDef.make(VOIDITE, &"voidite", "Minério arcano", 1000.0, 34.0,
			{&"voidite": 1}, BlockDef.Art.VEINED, Color("221a30"), Color("120d1c"), Color("b06cff"))
	var artifact := BlockDef.make(ARTIFACT, &"artifact", "Artefato", 500.0, 24.0,
			{&"artifact": 1, &"crystal": 3}, BlockDef.Art.ARTIFACT, Color("1f3a3c"), Color("122426"), Color("5effc9"))
	artifact.special = &"artifact"
	list[ARTIFACT] = artifact

	# --- Terrenos (formam o cenário; sem depósito coletável) ---
	list[SAND] = BlockDef.make(SAND, &"sand", "Areia", 10.0, 0.0, {}, BlockDef.Art.SAND,
			Color("d8b878"), Color("b08c52"), Color("ecd39a"))
	list[CLAY] = BlockDef.make(CLAY, &"clay", "Argila", 34.0, 1.0, {}, BlockDef.Art.CLAY,
			Color("b0603c"), Color("7e3f26"), Color("cf7c52"))
	list[ICE] = BlockDef.make(ICE, &"ice", "Gelo", 60.0, 3.0, {}, BlockDef.Art.ICE,
			Color("6aa6d4"), Color("3f6fa3"), Color("b9e3ff"))
	list[MUD] = BlockDef.make(MUD, &"mud", "Lama", 14.0, 0.0, {}, BlockDef.Art.MUD,
			Color("4d4a2c"), Color("33311c"), Color("6a6640"))

	# --- Depósitos coletáveis (base = rocha hospedeira; destaque = cor do minério) ---
	list[SILVER] = BlockDef.make(SILVER, &"silver", "Prata", 70.0, 4.0, {&"silver": 1}, BlockDef.Art.ORE,
			Color("6f6a68"), Color("4c4745"), Color("d9e2ee"))
	list[COAL] = BlockDef.make(COAL, &"coal", "Carvão", 30.0, 1.0, {&"coal": 1}, BlockDef.Art.ORE,
			Color("6f6a68"), Color("4c4745"), Color("3a3946"))
	list[EMERALD] = BlockDef.make(EMERALD, &"emerald", "Esmeralda", 180.0, 10.0, {&"emerald": 1, &"crystal": 1}, BlockDef.Art.CRYSTAL,
			Color("3b3d52"), Color("26273a"), Color("2fd46a"))
	list[DIAMOND] = BlockDef.make(DIAMOND, &"diamond", "Diamante", 600.0, 26.0, {&"diamond": 1, &"crystal": 2}, BlockDef.Art.CRYSTAL,
			Color("3b3d52"), Color("26273a"), Color("7fe0ff"))
	list[QUARTZ] = BlockDef.make(QUARTZ, &"quartz", "Quartzo", 60.0, 3.0, {&"quartz": 1}, BlockDef.Art.CRYSTAL,
			Color("6f6a68"), Color("4c4745"), Color("f1f1f4"))
	list[OBSIDIAN] = BlockDef.make(OBSIDIAN, &"obsidian", "Obsidiana", 420.0, 20.0, {&"obsidian": 1}, BlockDef.Art.VEINED,
			Color("1b1622"), Color("0d0a12"), Color("9a5cff"))
	list[URANIUM] = BlockDef.make(URANIUM, &"uranium", "Urânio", 380.0, 18.0, {&"uranium": 1}, BlockDef.Art.ORE,
			Color("35302f"), Color("1f1b1b"), Color("a6f23a"))
	list[TITANIUM] = BlockDef.make(TITANIUM, &"titanium", "Titânio", 300.0, 15.0, {&"titanium": 1}, BlockDef.Art.ORE,
			Color("35302f"), Color("1f1b1b"), Color("5f8fdf"))
	list[RARE_CRYSTAL] = BlockDef.make(RARE_CRYSTAL, &"rare_crystal", "Cristal raro", 800.0, 28.0, {&"rare_crystal": 1, &"crystal": 4}, BlockDef.Art.PRISM,
			Color("3b3d52"), Color("26273a"), Color("ff9ff3"))
	var fossil := BlockDef.make(FOSSIL, &"fossil", "Fóssil", 40.0, 2.0, {&"fossil": 1}, BlockDef.Art.FOSSIL,
			Color("7d7570"), Color("57504c"), Color("e3d3b0"))
	fossil.special = &"fossil"
	list[FOSSIL] = fossil
	var meteor := BlockDef.make(METEORITE, &"meteorite", "Meteorito", 700.0, 24.0, {&"meteorite": 1, &"crystal": 2}, BlockDef.Art.VEINED,
			Color("2a2226"), Color("140f12"), Color("ff3a26"))
	meteor.special = &"meteorite"
	list[METEORITE] = meteor

	_defs = list


static func get_def(id: int) -> BlockDef:
	if _defs.is_empty():
		_build()
	if id < 0 or id >= _defs.size():
		return _defs[BEDROCK]
	return _defs[id]


static func all() -> Array[BlockDef]:
	if _defs.is_empty():
		_build()
	return _defs


static func is_solid(id: int) -> bool:
	return get_def(id).solid
