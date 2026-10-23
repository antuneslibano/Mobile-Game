class_name SafeMargin
extends MarginContainer
## MarginContainer de tela cheia que soma as margens base à área segura do aparelho e
## limita a largura do conteúdo (SafeArea.MAX_CONTENT_W, centralizado). Atualiza sozinho
## quando a tela muda de tamanho (rotação, dobrável, janela).

var base_side: float = 4.0
var base_top: float = 10.0
var base_bottom: float = 10.0
var max_w: float = SafeArea.MAX_CONTENT_W


func _init(p_side: float = 4.0, p_top: float = 10.0, p_bottom: float = 10.0, p_max_w: float = SafeArea.MAX_CONTENT_W) -> void:
	base_side = p_side
	base_top = p_top
	base_bottom = p_bottom
	max_w = p_max_w
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	get_viewport().size_changed.connect(refresh)
	refresh()


func refresh() -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var i: Vector4 = SafeArea.insets(vp)
	var lr: Vector2 = SafeArea.side_margins(vp, base_side, max_w)
	add_theme_constant_override("margin_top", int(base_top + i.x))
	add_theme_constant_override("margin_bottom", int(base_bottom + i.y))
	add_theme_constant_override("margin_left", int(lr.x))
	add_theme_constant_override("margin_right", int(lr.y))
