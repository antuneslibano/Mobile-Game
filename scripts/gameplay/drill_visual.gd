class_name DrillVisual
extends Node2D
## Desenho da nave de perfuração (sprite pixel art de ShipArt) + efeitos: chama dos
## propulsores, espiral da broca girando, aura de Sobrecarga e acessórios dos módulos.
## Apenas lê o estado do nó Drill pai; nenhuma regra de jogo aqui.

## Tamanho do pixel de arte da nave em jogo.
const ART_SCALE: float = 3.0  ## 1 pixel do sprite = 3 px (mesmo pixel de arte do terreno).

var drill: Drill
var _t: float = 0.0
var _kick: float = 0.0
var _spin: float = 0.0
var _boost_flash: float = 0.0


func _ready() -> void:
	drill = get_parent() as Drill
	if drill != null:
		drill.dig_hit.connect(_on_hit)
		drill.boost_started.connect(func() -> void: _boost_flash = 1.0)


func _on_hit(_point: Vector2, _id: int, crit: bool, removed: int) -> void:
	_kick = 1.0 if (crit or removed > 0) else maxf(_kick, 0.6)


func _process(delta: float) -> void:
	_t += delta
	_kick = maxf(0.0, _kick - delta * 7.0)
	_boost_flash = maxf(0.0, _boost_flash - delta * 2.0)
	var digging: bool = drill != null and drill.digging
	_spin += delta * (18.0 if digging else 3.0)
	if drill != null:
		# Aponta a broca para onde está cavando; espelha para a cabine ficar sempre em cima.
		var target: float = drill.facing.angle()
		rotation = lerp_angle(rotation, target, 1.0 - exp(-12.0 * delta))
		scale.y = -1.0 if cos(rotation) < -0.05 else 1.0
	if digging:
		position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (1.0 + _kick * 1.5)
	else:
		position = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var boosting: bool = drill != null and drill.energy.is_boosting()
	var moving: bool = drill != null and drill.velocity.length() > 10.0
	var mods: Array[StringName] = drill.modules.equipped if drill != null else ([] as Array[StringName])
	var s: float = ART_SCALE
	var o: Vector2 = -ShipArt.ORIGIN * s   # canto superior esquerdo do sprite

	# Aura de Sobrecarga.
	if boosting:
		var a: float = 0.22 + 0.1 * sin(_t * 18.0)
		draw_circle(Vector2(4, 0), 48.0, Color(0.31, 0.76, 1.0, a * 0.6))
		draw_circle(Vector2(4, 0), 36.0, Color(0.6, 0.9, 1.0, a))
	if _boost_flash > 0.0:
		draw_arc(Vector2.ZERO, 30.0 + (1.0 - _boost_flash) * 50.0, 0.0, TAU, 40, Color(0.7, 0.95, 1.0, _boost_flash), 4.0)

	# Chamas dos bocais traseiros (azul; maiores na Sobrecarga).
	if moving or boosting or (drill != null and drill.digging):
		var length: float = (16.0 if boosting else 8.0) + 3.0 * sin(_t * 40.0)
		var col_out := Color(0.35, 0.75, 1.0, 0.85)
		var col_in := Color(0.85, 0.97, 1.0, 0.95)
		for ny: float in [7.0, 13.0]:
			var y: float = o.y + ny * s
			var x0: float = o.x
			draw_colored_polygon(PackedVector2Array([Vector2(x0, y - 3.5), Vector2(x0 - length, y), Vector2(x0, y + 3.5)]), col_out)
			draw_colored_polygon(PackedVector2Array([Vector2(x0, y - 1.5), Vector2(x0 - length * 0.55, y), Vector2(x0, y + 1.5)]), col_in)

	# Brocas laterais (módulo) na frente dos pods.
	if mods.has(ModuleSystem.SIDE_DRILL):
		for ny: float in [3.0, 17.0]:
			var y: float = o.y + ny * s
			var x0: float = o.x + 18.0 * s
			var ph: float = fposmod(_spin, 1.0) * 4.0
			draw_colored_polygon(PackedVector2Array([Vector2(x0, y - 5), Vector2(x0 + 14, y), Vector2(x0, y + 5)]), PixelArt.OUTLINE)
			draw_colored_polygon(PackedVector2Array([Vector2(x0, y - 3.5), Vector2(x0 + 11, y), Vector2(x0, y + 3.5)]), Color("c4cbd7"))
			draw_line(Vector2(x0 + 2 + ph, y - 3), Vector2(x0 + 2 + ph, y + 3), Color("5e6677"), 1.5)

	# Sprite da nave (quadro da espiral conforme a rotação da broca).
	var frame: int = int(_spin * 3.0)
	draw_set_transform(o, 0.0, Vector2(s, s))
	draw_texture(ShipArt.frame(frame), Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Emissor sísmico (módulo): antena no pod superior com anel de recarga.
	if mods.has(ModuleSystem.SEISMIC) and drill != null:
		var ex: Vector2 = o + Vector2(11.0, 0.0) * s
		draw_line(ex, ex + Vector2(0, -8), PixelArt.OUTLINE, 3.0)
		draw_circle(ex + Vector2(0, -10), 4.0, Color("c57bff"))
		var charge: float = 1.0 - clampf(drill.modules.pulse_cd / ModuleSystem.pulse_interval(drill.stats), 0.0, 1.0)
		draw_arc(ex + Vector2(0, -10), 7.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 16, Color("e3c2ff"), 2.0)
	# Luz da doca do drone (módulo).
	if mods.has(ModuleSystem.DRONE):
		var dx: Vector2 = o + Vector2(13.0, 17.0) * s
		draw_rect(Rect2(dx, Vector2(4, 3)), Color(0.31, 0.95, 1.0, 0.6 + 0.4 * sin(_t * 6.0)))

	# Faísca na ponta da broca ao cavar.
	if drill != null and drill.digging:
		var tip: Vector2 = o + Vector2(ShipArt.W - 1, 10) * s
		draw_circle(tip, 3.0 + _kick * 3.0, Color(1.0, 0.85, 0.5, 0.55))
