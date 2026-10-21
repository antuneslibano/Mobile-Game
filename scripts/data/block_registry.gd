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
const COUNT: int = 18

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
			{&"copper": 3, &"iron": 2, &"crystal": 1}, BlockDef.Art.CHEST, Color("8b5a2b"), Color("4f3218"), Color("f2c14e"))
	chest.special = &"treasure"
	list[CHEST] = chest

	list[CRYSTAL_ROCK] = BlockDef.make(CRYSTAL_ROCK, &"crystal_rock", "Rocha cristalina", 60.0, 4.0,
			{&"stone": 3}, BlockDef.Art.STONE, Color("4a4f72"), Color("31344f"), Color("6c74a3"))
	list[HARD_ROCK] = BlockDef.make(HARD_ROCK, &"hard_rock", "Rocha dura", 110.0, 7.0,
			{&"stone": 5}, BlockDef.Art.STONE, Color("5b5468"), Color("3d374a"), Color("7a7290"))
	list[CRYSTAL] = BlockDef.make(CRYSTAL, &"crystal", "Cristal", 70.0, 4.0,
			{&"crystal": 1}, BlockDef.Art.CRYSTAL, Color("4a4f72"), Color("31344f"), Color("6fe3ff"))
	list[AMETHYST] = BlockDef.make(AMETHYST, &"amethyst", "Ametista", 100.0, 6.0,
			{&"amethyst": 1, &"crystal": 1}, BlockDef.Art.CRYSTAL, Color("3b3d52"), Color("26273a"), Color("c57bff"))

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
	list[VOIDITE] = BlockDef.make(VOIDITE, &"voidite", "Vazionita", 1000.0, 34.0,
			{&"voidite": 1}, BlockDef.Art.CRYSTAL, Color("1f3a3c"), Color("122426"), Color("9d5cff"))
	var artifact := BlockDef.make(ARTIFACT, &"artifact", "Artefato", 500.0, 24.0,
			{&"artifact": 1, &"crystal": 3}, BlockDef.Art.ARTIFACT, Color("1f3a3c"), Color("122426"), Color("5effc9"))
	artifact.special = &"artifact"
	list[ARTIFACT] = artifact

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
