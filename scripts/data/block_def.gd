class_name BlockDef
extends Resource
## Definição imutável de um tipo de bloco. Instâncias são criadas pelo BlockRegistry.

## Estilo de desenho no shader de terreno (o valor numérico vai para a paleta).
## Terreno: DIRT, STONE, BEDROCK, MAGMA, SAND, CLAY, ICE, MUD.
## Depósitos coletáveis: ORE (pepitas metálicas), CRYSTAL (lascas), VEINED (rocha com veios
## brilhantes), PRISM (cristal multicolorido), FOSSIL, CHEST, ARTIFACT.
enum Art { NONE, DIRT, STONE, ORE, CRYSTAL, BEDROCK, CHEST, ARTIFACT, MAGMA, SAND, CLAY, ICE, MUD, FOSSIL, VEINED, PRISM }

@export var id: int = 0
@export var key: StringName = &""
@export var display_name: String = ""
@export var solid: bool = true
@export var breakable: bool = true
@export var max_hp: float = 1.0
@export var hardness: float = 0.0
## Recursos concedidos ao destruir: { &"recurso": quantidade }.
@export var drops: Dictionary = {}
## Evento especial opcional (ex.: &"treasure"). Vazio = nenhum.
@export var special: StringName = &""
@export var art: Art = Art.STONE
@export var color_base: Color = Color.GRAY
@export var color_dark: Color = Color.DIM_GRAY
@export var color_accent: Color = Color.WHITE


## Material que forma o cenário (não é depósito coletável), mesmo que conte na carga.
func is_terrain() -> bool:
	return art in [Art.DIRT, Art.STONE, Art.BEDROCK, Art.MAGMA, Art.SAND, Art.CLAY, Art.ICE, Art.MUD]


static func make(p_id: int, p_key: StringName, p_name: String, p_hp: float, p_hardness: float,
		p_drops: Dictionary, p_art: Art, p_base: Color, p_dark: Color, p_accent: Color) -> BlockDef:
	var d := BlockDef.new()
	d.id = p_id
	d.key = p_key
	d.display_name = p_name
	d.max_hp = p_hp
	d.hardness = p_hardness
	d.drops = p_drops
	d.art = p_art
	d.color_base = p_base
	d.color_dark = p_dark
	d.color_accent = p_accent
	return d
