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
const MAX_LIGHTS: int = 12
var _lite: bool = false
var _mat: ShaderMaterial


func _ready() -> void:
	layer = 2
	_rect = ColorRect.new()
	_rect.name = "Fog"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	# Modo de compatibilidade: névoa simples (sem laço de luzes extras).
	_lite = Guard.compat
	_mat.shader = load("res://shaders/fog_lite.gdshader" if _lite else "res://shaders/fog.gdshader") as Shader
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
	var s: float = strength_at(drill.depth_m()) * (0.45 if drill.arena else 1.0)
	_rect.visible = s > 0.01 and drill.visible
	if not _rect.visible:
		return
	_mat.set_shader_parameter("rect_size", vp)
	_mat.set_shader_parameter("ship_pos", xf * drill.global_position)
	_mat.set_shader_parameter("radius", Balance.LIGHT_RADIUS_BLOCKS * Balance.BLOCK_PX * sc)
	_mat.set_shader_parameter("strength", 0.86 * s)
	if _lite:
		return
	var lights: Array[Vector4] = []
	if guardian != null and guardian.alive and guardian.in_arena(drill.position):
		var gp: Vector2 = xf * (guardian.center + Vector2(0, Balance.BLOCK_PX))
		lights.append(Vector4(gp.x, gp.y, 9.0 * Balance.BLOCK_PX * sc, 0.9))
	var glow: float = sonar.light_level() if sonar != null else 0.0
	if glow > 0.01:
		var sp: Vector2 = xf * sonar.wave_center
		# A onda do sonar clareia por onde passa e depois apaga devagar (fade).
		lights.append(Vector4(sp.x, sp.y, sonar.wave_radius * sc, 0.2 * glow))
	if creatures != null:
		for c in creatures.creatures:
			if lights.size() >= MAX_LIGHTS - 4:  # deixa vaga para as plantas
				break
			if c.species == &"firefly":
				var fp: Vector2 = xf * c.pos
				if fp.x > -100 and fp.y > -100 and fp.x < vp.x + 100 and fp.y < vp.y + 100:
					lights.append(Vector4(fp.x, fp.y, 70.0 * sc, 0.8))
	# Plantas bioluminescentes (0.15): luz fraca e pulsando devagar, só para guiar.
	var now: float = Time.get_ticks_msec() / 1000.0
	for d in CaveDecor.live:
		if lights.size() >= MAX_LIGHTS:
			break
		for wp in d.bio_lights():
			if lights.size() >= MAX_LIGHTS:
				break
			var bp: Vector2 = xf * wp
			if bp.x > -120 and bp.y > -120 and bp.x < vp.x + 120 and bp.y < vp.y + 120:
				lights.append(Vector4(bp.x, bp.y, Balance.BIO_LIGHT_BLOCKS * Balance.BLOCK_PX * sc, 0.7 + 0.08 * sin(now * 1.6 + wp.x * 0.05)))
	var arr: Array = []
	for l in lights:
		arr.append(l)
	while arr.size() < MAX_LIGHTS:
		arr.append(Vector4.ZERO)
	_mat.set_shader_parameter("lights", arr)
	_mat.set_shader_parameter("light_count", lights.size())
