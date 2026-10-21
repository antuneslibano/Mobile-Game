class_name UpgradeDef
extends Resource
## Definição de upgrade (arquivos .tres em res://data/upgrades/).
## Custo do próximo nível: round(base_cost × cost_growth^nível).
## Bônus no nível n: step × n (interpretado por Progression conforme `stat`).

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## &"credits" ou &"crystals".
@export var currency: StringName = &"credits"
@export var base_cost: float = 10.0
@export var cost_growth: float = 1.4
@export var max_level: int = 10
## Atributo afetado (ver Progression.apply_upgrade).
@export var stat: StringName = &""
@export var step: float = 1.0
## Fase em que o efeito está implementado; upgrades de fases futuras aparecem bloqueados.
@export var available_from_phase: int = 2
## Compras "importantes" disparam salvamento imediato (Fase 4).
@export var important: bool = false
@export var color: Color = Color("f2b33d")
