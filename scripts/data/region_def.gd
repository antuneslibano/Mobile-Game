class_name RegionDef
extends Resource
## Região do mapa mundial: identidade visual, camadas de profundidade, recursos, riscos,
## equipamentos recomendados e requisito de desbloqueio. Cada exploração gera um mundo
## com as camadas da região (o mesmo gerador, mineração e economia do jogo).

@export var id: StringName = &""
@export var display_name: String = ""
## Tema visual da ilustração e do céu: &"savanna", &"desert", &"mountain", &"swamp", &"volcanic", &"crystal".
@export var theme: StringName = &""
@export_multiline var description: String = ""
@export_range(1, 5) var difficulty: int = 1
## Profundidade que conta como 100% explorado.
@export var target_depth_m: int = 250
## Profundidade a partir da qual o calor aparece (vulcânico: desde a superfície).
@export var heat_start_m: int = 300
@export var layers: Array[BiomeDef] = []
## Recursos principais (chaves do ResourceRegistry).
@export var resources: Array[StringName] = []
## Riscos ambientais (chaves de RegionRegistry.HAZARDS).
@export var hazards: Array[StringName] = []
## Upgrades recomendados (ids do UpgradeRegistry).
@export var recommended: Array[StringName] = []
## Requisito: alcançar unlock_depth_m em unlock_region (vazio = livre).
@export var unlock_region: StringName = &""
@export var unlock_depth_m: int = 0
@export var sky_top: Color = Color("1b1530")
@export var sky_bottom: Color = Color("d9774a")
@export var hill_far: Color = Color("3a2440")
@export var hill_near: Color = Color("2a1a2c")
@export var ui_color: Color = Color("f5a623")
