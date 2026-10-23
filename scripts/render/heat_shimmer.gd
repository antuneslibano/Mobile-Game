class_name HeatShimmer
extends CanvasLayer
## Tela tremulando com o calor (0.19): quando a nave passa do limite térmico, o mundo
## ondula como ar quente (shader heat_shimmer). Fica entre a névoa e o HUD, então os
## botões continuam nítidos. Desligado no modo de compatibilidade 2 ou mais.

var drill: Drill
var _rect: ColorRect
var _mat: ShaderMaterial
var _strength: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	layer = 4
	# Copia a tela aqui (já com o mundo e a névoa desenhados) para o shader ler.
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)
	_rect = ColorRect.new()
	_rect.name = "HeatShimmer"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/heat_shimmer.gdshader") as Shader
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


## Intensidade desejada (0..1) a partir da perda de eficiência pelo calor.
static func target_strength(penalty: float) -> float:
	return clampf(penalty / Balance.HEAT_PENALTY_MAX, 0.0, 1.0)


func _process(delta: float) -> void:
	if drill == null or Guard.compat_level >= 2:
		_rect.visible = false
		return
	var target: float = target_strength(drill.heat_penalty) if drill.is_inside_tree() and drill.visible else 0.0
	# Entra devagar e sai devagar (sem "piscar" ao cruzar o limite).
	_strength = move_toward(_strength, target, delta * 0.8)
	_rect.visible = _strength > 0.01
	if not _rect.visible:
		return
	_t += delta
	_mat.set_shader_parameter("strength", 0.25 + 0.75 * _strength)
	_mat.set_shader_parameter("time", _t)
	_mat.set_shader_parameter("rect_size", _rect.get_viewport_rect().size)
