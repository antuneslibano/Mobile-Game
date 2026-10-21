class_name GemIcon
extends Control
## Ícone vetorial simples de moeda (losango facetado). Evita depender de glifos da fonte.

@export var color: Color = UiTheme.CREDITS


func _init(p_color: Color = UiTheme.CREDITS) -> void:
	color = p_color
	custom_minimum_size = Vector2(30, 30)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.45
	var outline := PackedVector2Array([c + Vector2(0, -r - 2), c + Vector2(r + 2, 0), c + Vector2(0, r + 2), c + Vector2(-r - 2, 0)])
	draw_colored_polygon(outline, Color(0, 0, 0, 0.8))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), color)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c, c + Vector2(-r, 0)]), color.lightened(0.35))
	draw_rect(Rect2(c + Vector2(-r * 0.35, -r * 0.55), Vector2(3, 3)), Color.WHITE)
