class_name FogLayer
extends CanvasLayer
## Névoa (0.13): o subsolo fica escuro e só se vê o que a luz da nave alcança
## (LIGHT_RADIUS_BLOCKS), mais a luz de vaga-lumes, da onda do sonar e do guardião.
## Na superfície não há névoa; ela escurece até FOG_FULL_DEPTH_M. Só visual.

var drill: Drill
var creatures: CreatureManager
var guardian: FinalGuardian
var sonar: SonarOverlay
var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	layer = 2
	_rect = ColorRect.new()
	_rect.name = "Fog"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/fog.gdshader") as Shader
	_rect.material = _mat
	add_child(_rect)


## Intensidade da névoa na profundidade (0 na superfície → 1 a partir de FOG_FULL_DEPTH_M).
static func strength_at(depth_m: int) -> float:
	return clampf(float(depth_m) / Balance.FOG_FULL_DEPTH_M, 0.0, 1.0)


func _process(_delta: float) -> void:
	if drill == null or not drill.is_inside_tree():
		_rect.visible = false
		return
	var xf: Transform2D = get_viewport().get_canvas_transform()
	var sc: float = xf.get_scale().x
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var s: float = strength_at(drill.depth_m())
	_rect.visible = s > 0.01 and drill.visible
	if not _rect.visible:
		return
	_mat.set_shader_parameter("rect_size", vp)
	_mat.set_shader_parameter("ship_pos", xf * drill.global_position)
	_mat.set_shader_parameter("radius", Balance.LIGHT_RADIUS_BLOCKS * Balance.BLOCK_PX * sc)
	_mat.set_shader_parameter("strength", 0.94 * s)
	var lights: Array[Vector4] = []
	if guardian != null and guardian.alive and guardian.in_arena(drill.position):
		var gp: Vector2 = xf * (guardian.center + Vector2(0, Balance.BLOCK_PX))
		lights.append(Vector4(gp.x, gp.y, 9.0 * Balance.BLOCK_PX * sc, 0.9))
	if sonar != null and sonar.wave_active():
		var sp: Vector2 = xf * sonar.wave_center
		# A onda do sonar acende um anel fino por onde passa (aproximado por 1 luz larga e fraca).
		lights.append(Vector4(sp.x, sp.y, sonar.wave_radius * sc, 0.18))
	if creatures != null:
		for c in creatures.creatures:
			if lights.size() >= 24:
				break
			if c.species == &"firefly":
				var fp: Vector2 = xf * c.pos
				if fp.x > -100 and fp.y > -100 and fp.x < vp.x + 100 and fp.y < vp.y + 100:
					lights.append(Vector4(fp.x, fp.y, 70.0 * sc, 0.8))
	var arr: Array = []
	for l in lights:
		arr.append(l)
	while arr.size() < 24:
		arr.append(Vector4.ZERO)
	_mat.set_shader_parameter("lights", arr)
	_mat.set_shader_parameter("light_count", lights.size())
