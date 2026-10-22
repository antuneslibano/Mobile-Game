class_name TerrainSkins
extends RefCounted
## Aparência do ambiente (só visual): qual textura cada material usa em cada camada,
## qual sprite representa cada depósito e quais decorações aparecem em cada camada.
## Os PNGs ficam em assets/environment/ (gerados por tools/gen_env_assets.gd).
## Mudar este arquivo não altera geração, mineração, colisão nem economia.

const ROOT: String = "res://assets/environment"
const NONE: int = 255

## Texturas de terreno (64×64 pixels de arte, repetíveis). Índice = posição no atlas.
const TILES: Array[String] = [
	"terra_clara", "terra_escura", "argila", "solo_compacto", "solo_umido", "solo_com_raizes",
	"solo_com_musgo", "solo_rachado", "pedra_clara", "pedra_cinza", "pedra_escura",
	"rocha_compacta", "rocha_profunda", "terra_avermelhada", "solo_arenoso", "solo_misto",
]

## Sprites de depósito (16×16, 3 variações cada). Índice = linha no atlas de minérios.
const ORES: Array[String] = [
	"cobre", "ferro", "prata", "ouro", "carvao", "titanio", "uranio", "quartzo", "cristal_azul",
	"ametista", "cristal_verde", "diamante", "cristal_vermelho", "cristal_roxo", "topazio",
]
const ORE_VARIANTS: int = 3

## Bloco → sprite de depósito. Topázio não tem bloco no jogo (arte pronta, não usada).
static func ore_sprite_for(block_id: int) -> String:
	var B := BlockRegistry
	match block_id:
		B.COPPER: return "cobre"
		B.IRON: return "ferro"
		B.SILVER: return "prata"
		B.GOLD: return "ouro"
		B.COAL: return "carvao"
		B.TITANIUM: return "titanio"
		B.URANIUM: return "uranio"
		B.QUARTZ: return "quartzo"
		B.CRYSTAL: return "cristal_azul"
		B.AMETHYST: return "ametista"
		B.EMERALD: return "cristal_verde"
		B.DIAMOND: return "diamante"
		B.RUBY: return "cristal_vermelho"
		B.RARE_CRYSTAL: return "cristal_roxo"
	return ""


## Decorações (célula de 32×32 no atlas). kind: embed = dentro do solo (cortada pelos
## túneis), floor = no chão de cavernas naturais, ceil = pendurada no teto, fossil = bloco Fóssil.
const DECOR: Array = [
	["vegetation", "raiz_fina_a", &"embed"], ["vegetation", "raiz_fina_b", &"embed"],
	["vegetation", "raiz_retorcida", &"embed"], ["vegetation", "raiz_grossa", &"embed"],
	["decorations", "pedrinhas_a", &"embed"], ["decorations", "pedrinhas_b", &"embed"],
	["decorations", "pedra_pequena", &"embed"], ["decorations", "pedra_escura", &"embed"],
	["vegetation", "musgo_a", &"floor"], ["vegetation", "musgo_b", &"floor"],
	["vegetation", "samambaia", &"floor"], ["vegetation", "broto", &"floor"],
	["vegetation", "cogumelo_vermelho", &"floor"], ["vegetation", "cogumelo_marrom", &"floor"],
	["decorations", "monte_pedras", &"floor"], ["decorations", "rocha_pontuda_a", &"floor"],
	["decorations", "rocha_pontuda_b", &"floor"],
	["vegetation", "raiz_pendente_a", &"ceil"], ["vegetation", "raiz_pendente_b", &"ceil"],
	["vegetation", "cipo_pendente", &"ceil"], ["decorations", "estalactite", &"ceil"],
	["decorations", "fossil_osso", &"fossil"], ["decorations", "fossil_cranio", &"fossil"],
	["decorations", "fossil_amonite", &"fossil"], ["decorations", "fossil_costelas", &"fossil"],
]
const DECOR_CELL: int = 32
const DECOR_COLS: int = 8


static func decor_index(name: String) -> int:
	for i in DECOR.size():
		if DECOR[i][1] == name:
			return i
	return -1


static func fossil_indices() -> Array[int]:
	var out: Array[int] = []
	for i in DECOR.size():
		if DECOR[i][2] == &"fossil":
			out.append(i)
	return out


static func tile(name: String) -> int:
	return TILES.find(name)


## Até 4 texturas por material: [principal, variação (manchas grandes), manchas, manchas raras].
## Material sem entrada usa o desenho procedural do shader (areia das Dunas, gelo, lama...).
static func _default_skins() -> Dictionary:
	var B := BlockRegistry
	return {
		B.DIRT: ["terra_clara", "terra_escura", "solo_com_raizes"],
		B.STONE: ["pedra_cinza", "pedra_clara"],
		B.CLAY: ["argila", "terra_avermelhada", "solo_rachado"],
		B.HARD_ROCK: ["rocha_compacta", "pedra_escura"],
		B.CRYSTAL_ROCK: ["pedra_cinza", "rocha_compacta"],
		B.BASALT: ["pedra_escura", "rocha_profunda"],
		B.ABYSS_STONE: ["rocha_profunda", "pedra_escura"],
	}


## Por região e camada (índice da camada) → { bloco: [texturas] } que substituem o padrão.
static func _region_skins(region_id: StringName) -> Array:
	var B := BlockRegistry
	match region_id:
		RegionRegistry.VALE:
			return [
				{B.DIRT: ["terra_clara", "solo_compacto"],
					B.STONE: ["pedra_clara", "pedra_cinza"]},
				{B.SAND: ["solo_arenoso", "solo_misto"],
					B.DIRT: ["terra_escura", "solo_umido", "solo_com_raizes", "solo_com_musgo"]},
				{B.CLAY: ["argila", "terra_avermelhada", "solo_rachado"],
					B.STONE: ["pedra_cinza", "pedra_clara"]},
				{B.STONE: ["pedra_cinza", "pedra_escura"], B.HARD_ROCK: ["rocha_compacta", "pedra_escura"]},
				{B.ABYSS_STONE: ["rocha_profunda", "pedra_escura"], B.BASALT: ["pedra_escura", "rocha_profunda"]},
			]
		RegionRegistry.PANTANO:
			return [{}, {B.DIRT: ["terra_escura", "solo_umido", "solo_com_musgo"]}]
	return []


## Texturas do material na camada (índices; NONE = procedural).
static func skin_for(region_id: StringName, layer: int, block_id: int) -> PackedByteArray:
	var names: Array = _default_skins().get(block_id, [])
	# Camada da região que define o material; se a camada não define, a mais próxima que
	# define (perto das fronteiras um material pode aparecer marcado com a camada vizinha).
	var per_layer: Array = _region_skins(region_id)
	for dist in per_layer.size():
		var found: bool = false
		for l: int in [layer - dist, layer + dist]:
			if l >= 0 and l < per_layer.size() and (per_layer[l] as Dictionary).has(block_id):
				names = per_layer[l][block_id]
				found = true
				break
		if found:
			break
	var out := PackedByteArray([NONE, NONE, NONE, NONE])
	for i in mini(4, names.size()):
		out[i] = tile(names[i])
	return out


## Decorações por camada: { "embed"/"floor"/"ceil": [densidade, [nome, peso]...] }.
## Só o Vale das Raízes tem decorações por enquanto (outras regiões: vazio).
static func decor_for(region_id: StringName, layer: int) -> Dictionary:
	if region_id != RegionRegistry.VALE:
		return {}
	var tables: Array = [
		{"embed": [0.26, ["raiz_fina_a", 3], ["raiz_fina_b", 3], ["raiz_retorcida", 2], ["raiz_grossa", 1], ["pedrinhas_a", 2], ["pedrinhas_b", 2]],
			"floor": [0.5, ["musgo_a", 3], ["musgo_b", 3], ["samambaia", 2], ["broto", 2], ["cogumelo_vermelho", 1]],
			"ceil": [0.45, ["raiz_pendente_a", 3], ["raiz_pendente_b", 2], ["cipo_pendente", 2]]},
		{"embed": [0.2, ["raiz_fina_a", 2], ["raiz_fina_b", 2], ["raiz_retorcida", 1], ["pedrinhas_a", 2], ["pedrinhas_b", 3]],
			"floor": [0.4, ["musgo_b", 2], ["broto", 2], ["cogumelo_marrom", 2], ["monte_pedras", 1]],
			"ceil": [0.35, ["raiz_pendente_a", 2], ["raiz_pendente_b", 2], ["cipo_pendente", 1]]},
		{"embed": [0.22, ["pedrinhas_a", 2], ["pedra_pequena", 2], ["raiz_fina_b", 1]],
			"floor": [0.35, ["cogumelo_marrom", 2], ["cogumelo_vermelho", 1], ["monte_pedras", 2], ["rocha_pontuda_b", 1]],
			"ceil": [0.25, ["raiz_pendente_b", 1], ["estalactite", 2]]},
		{"embed": [0.2, ["pedra_pequena", 2], ["pedra_escura", 2], ["pedrinhas_a", 1]],
			"floor": [0.35, ["rocha_pontuda_a", 2], ["rocha_pontuda_b", 2], ["monte_pedras", 1], ["cogumelo_marrom", 1]],
			"ceil": [0.3, ["estalactite", 3]]},
		{"embed": [0.15, ["pedra_escura", 1]],
			"floor": [0.25, ["rocha_pontuda_a", 1], ["rocha_pontuda_b", 1]],
			"ceil": [0.2, ["estalactite", 1]]},
	]
	return tables[layer] if layer < tables.size() else {}


## Escolhe uma decoração da tabela com um valor 0..1 (pesos).
static func pick(table: Array, r: float) -> int:
	var total: float = 0.0
	for i in range(1, table.size()):
		total += float(table[i][1])
	var acc: float = 0.0
	for i in range(1, table.size()):
		acc += float(table[i][1]) / total
		if r <= acc:
			return decor_index(table[i][0])
	return decor_index(table[table.size() - 1][0])
