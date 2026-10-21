class_name GemIcon
extends TextureRect
## Ícone de moeda em pixel art: moeda dourada (Créditos) ou cristal azul (Cristais).


func _init(p_color: Color = UiTheme.CREDITS) -> void:
	texture = PixelArt.icon(&"crystal" if p_color == UiTheme.CRYSTALS else &"coin")
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(34, 34)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
