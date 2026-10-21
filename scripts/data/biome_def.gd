class_name BiomeDef
extends Resource
## Camada de profundidade de uma região: faixa, materiais, cavernas, minérios e paleta.

@export var id: int = 0
@export var display_name: String = ""
## Texto curto da camada (painel do mapa: "Areia instável e areia movediça.").
@export var description: String = ""
@export var start_row: int = 0
@export var end_row: int = 100
@export var cave_threshold: float = 0.6
## Material principal e secundário (misturados por ruído).
@export var primary_block: int = 0
@export var secondary_block: int = 0
## Fração aproximada do material secundário (0..1).
@export var secondary_ratio: float = 0.3
## Tabela de minérios: Array de [block_id, chance_base, linha_mínima].
@export var ore_table: Array = []
@export var heat: float = 0.0
@export var back_color: Color = Color.BLACK
@export var fog_color: Color = Color.BLACK
@export var ui_color: Color = Color.WHITE
