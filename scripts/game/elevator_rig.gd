class_name ElevatorRig
extends Node2D
## Elevador e cápsula de extração (só visual): um cabo de aço que vem de cima até a nave,
## com uma plataforma onde a expedição começa. Na extração, o cabo desce, engata na nave
## e a puxa para cima. Pixels de arte de 3 px.

const ART: float = 3.0
const CABLE_TOP: float = -2400.0

var _anchor: Vector2 = Vector2.ZERO
var _platform: bool = false
var _pull_target: Node2D
var _pull_t: float = 0.0
var _pull_len: float = 0.0
var _visible_cable: bool = false


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Plataforma do elevador no ponto de partida (abaixo da superfície).
func show_at(spawn: Vector2, platform: bool) -> void:
	_anchor = spawn
	_platform = platform
	_visible_cable = platform
	_pull_target = null
	set_process(false)
	queue_redraw()


func pull(target: Node2D, duration: float) -> void:
	_pull_target = target
	_pull_t = 0.0
	_pull_len = duration
	_visible_cable = true
	set_process(true)


func _process(delta: float) -> void:
	_pull_t += delta
	queue_redraw()
	if _pull_t > _pull_len + 0.5:
		set_process(false)


func _draw() -> void:
	var steel := Color("c3cad6")
	var dark := Color("3a4150")
	if _pull_target != null:
		# Cabo descendo até a nave (0,35 s) e depois subindo com ela.
		var p: Vector2 = _pull_target.position
		var k: float = clampf(_pull_t / 0.35, 0.0, 1.0)
		var hook_y: float = lerpf(p.y - 700.0, p.y - 26.0, k)
		_cable(Vector2(p.x, CABLE_TOP + p.y), Vector2(p.x, hook_y), steel, dark)
		draw_rect(Rect2(Vector2(p.x - 9, hook_y - 3), Vector2(18, 9)), PixelArt.GOLD)
		draw_rect(Rect2(Vector2(p.x - 9, hook_y - 3), Vector2(18, 3)), PixelArt.GOLD_HI)
		return
	if not _visible_cable:
		return
	# Elevador: cabo + plataforma sob a nave.
	var base: Vector2 = _anchor + Vector2(0, Balance.DRILL_RADIUS_PX + 4.0)
	_cable(Vector2(_anchor.x, _anchor.y + CABLE_TOP), Vector2(_anchor.x, base.y - 12.0), steel, dark)
	if _platform:
		draw_rect(Rect2(Vector2(base.x - 42, base.y - 3), Vector2(84, 9)), dark)
		draw_rect(Rect2(Vector2(base.x - 42, base.y - 3), Vector2(84, 3)), PixelArt.GOLD)
		for i in 7:
			draw_rect(Rect2(Vector2(base.x - 39 + i * 12, base.y + 3), Vector2(6, 3)), Color("1a1d24") if i % 2 == 0 else PixelArt.GOLD)


func _cable(a: Vector2, b: Vector2, steel: Color, dark: Color) -> void:
	draw_rect(Rect2(Vector2(a.x - ART, a.y), Vector2(ART * 2.0, b.y - a.y)), dark)
	draw_rect(Rect2(Vector2(a.x - ART, a.y), Vector2(ART, b.y - a.y)), steel)
