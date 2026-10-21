class_name ResourceDef
extends Resource
## Recurso coletável. Minérios vão para a carga e são vendidos na garagem;
## recursos com `currency` vão direto para a carteira (ex.: Cristais).

@export var key: StringName = &""
@export var display_name: String = ""
## Preço de venda em Créditos por unidade.
@export var sell_value: int = 0
## Se definido (&"crystals"), a coleta credita essa moeda em vez de ir para a carga.
@export var currency: StringName = &""
@export var color: Color = Color.WHITE
