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
## Fundo da região: rocha-mãe a partir daqui, com a câmara final logo acima.
@export var target_depth_m: int = 250
## Nome da câmara final e do guardião que a protege (objetivo principal: vencê-lo).
@export var final_name: String = ""
@export var guardian_name: String = ""
## Objetivos: [{id, group (&"main"/&"research"/&"star"), kind, key, target, text}].
@export var objectives: Array[Dictionary] = []
## Profundidade a partir da qual o calor aparecia (regra antiga, até a 0.17).
@export var heat_start_m: int = 300
## Calor (0.18): temperatura na superfície e no fundo da região (°C).
@export var temp_surface: float = 25.0
@export var temp_bottom: float = 140.0
@export var layers: Array[BiomeDef] = []
## Recursos principais (chaves do ResourceRegistry).
@export var resources: Array[StringName] = []
## Riscos ambientais (chaves de RegionRegistry.HAZARDS).
@export var hazards: Array[StringName] = []
## Upgrades recomendados (ids do UpgradeRegistry).
@export var recommended: Array[StringName] = []
## Requisito (0.9): concluir a câmara final de unlock_region (vazio = livre).
## unlock_depth_m é a regra antiga (só para migrar salvamentos anteriores à 0.9).
@export var unlock_region: StringName = &""
@export var unlock_depth_m: int = 0
@export var sky_top: Color = Color("1b1530")
@export var sky_bottom: Color = Color("d9774a")
@export var hill_far: Color = Color("3a2440")
@export var hill_near: Color = Color("2a1a2c")
@export var ui_color: Color = Color("f5a623")
