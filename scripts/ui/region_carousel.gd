class_name RegionCarousel
extends Control
## Carrossel de regiões: uma ilustração grande por página, navegação por deslizamento
## horizontal com encaixe suave (e setas/indicadores de página). Desenhado em um único
## Control; as ilustrações vêm de RegionArt.

signal page_changed(index: int)

const SNAP_SPEED: float = 12.0
const SWIPE_FRACTION: float = 0.18     ## Arrasto mínimo (fração da largura) para trocar.
const FLICK_SPEED: float = 900.0        ## Velocidade (px/s) que também troca de página…
const FLICK_MIN_FRACTION: float = 0.06  ## …desde que o arrasto passe desta fração da largura.
const DOTS_H: float = 34.0

var regions: Array[RegionDef] = []
## Página exibida (contínua durante o arrasto/animação) e página alvo.
var pos: float = 0.0
var target: int = 0
var _dragging: bool = false
var _start_x: float = 0.0
var _start_pos: float = 0.0
var _last_x: float = 0.0
var _last_t: float = 0.0
var _vel: float = 0.0
var _t: float = 0.0
var _prev_btn: Button
var _next_btn: Button


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _ready() -> void:
	_prev_btn = _arrow_button(&"arrow_left", -1)
	_next_btn = _arrow_button(&"arrow_right", 1)
	resized.connect(_place_arrows)
	_place_arrows()


func setup(list: Array[RegionDef], start: int) -> void:
	regions = list
	target = clampi(start, 0, regions.size() - 1)
	pos = float(target)
	queue_redraw()


func go_to(index: int, instant: bool = false) -> void:
	var t: int = clampi(index, 0, regions.size() - 1)
	if instant:
		pos = float(t)
	if t != target:
		target = t
		page_changed.emit(target)
	queue_redraw()


func _arrow_button(icon_id: StringName, dir: int) -> Button:
	var b := Button.new()
	b.name = "Prev" if dir < 0 else "Next"
	b.icon = PixelArt.icon(icon_id)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 26)
	b.custom_minimum_size = Vector2(56, 72)
	b.size = b.custom_minimum_size
	UiTheme.style_button(b, &"steel")
	b.pressed.connect(func() -> void: go_to(target + dir))
	add_child(b)
	return b


func _place_arrows() -> void:
	if _prev_btn == null:
		return
	var y: float = (size.y - DOTS_H) * 0.5 - 36.0
	_prev_btn.position = Vector2(14, y)
	_next_btn.position = Vector2(size.x - 70, y)


func _process(delta: float) -> void:
	_t += delta
	if not _dragging and not is_equal_approx(pos, float(target)):
		pos = lerpf(pos, float(target), 1.0 - exp(-SNAP_SPEED * delta))
		if absf(pos - float(target)) < 0.002:
			pos = float(target)
	if _prev_btn != null:
		_prev_btn.visible = target > 0
		_next_btn.visible = target < regions.size() - 1
	queue_redraw()


# --- Entrada (toque e mouse; eventos duplicados são idempotentes) ------------------

func _gui_input(event: InputEvent) -> void:
	var press: int = 0     # 1 = apertou, -1 = soltou
	var x: float = 0.0
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		press = 1 if t.pressed else -1
		x = t.position.x
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m := event as InputEventMouseButton
		press = 1 if m.pressed else -1
		x = m.position.x
	elif event is InputEventScreenDrag:
		_drag_to((event as InputEventScreenDrag).position.x)
		return
	elif event is InputEventMouseMotion and _dragging:
		_drag_to((event as InputEventMouseMotion).position.x)
		return
	if press == 1:
		if not _dragging:
			_dragging = true
			_start_x = x
			_start_pos = pos
			_last_x = x
			_last_t = Time.get_ticks_msec() / 1000.0
			_vel = 0.0
		accept_event()
	elif press == -1 and _dragging:
		_dragging = false
		var dx: float = x - _start_x
		var w: float = maxf(1.0, size.x)
		var dest: int = target
		var flick: bool = absf(dx) > w * FLICK_MIN_FRACTION
		if dx < -w * SWIPE_FRACTION or (flick and dx < 0.0 and _vel < -FLICK_SPEED):
			dest = target + 1
		elif dx > w * SWIPE_FRACTION or (flick and dx > 0.0 and _vel > FLICK_SPEED):
			dest = target - 1
		go_to(dest)
		accept_event()


func _drag_to(x: float) -> void:
	if not _dragging:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now > _last_t:
		_vel = lerpf(_vel, (x - _last_x) / (now - _last_t), 0.5)
	_last_x = x
	_last_t = now
	var p: float = _start_pos - (x - _start_x) / maxf(1.0, size.x)
	# Resistência elástica além das pontas.
	var lo: float = 0.0
	var hi: float = float(regions.size() - 1)
	if p < lo:
		p = lo - (lo - p) * 0.3
	elif p > hi:
		p = hi + (p - hi) * 0.3
	pos = p
	queue_redraw()


# --- Desenho ------------------------------------------------------------------------

func _draw() -> void:
	if regions.is_empty():
		return
	var w: float = size.x
	var card_h: float = size.y - DOTS_H
	var first: int = maxi(0, floori(pos) - 1)
	var last: int = mini(regions.size() - 1, ceili(pos) + 1)
	for i in range(first, last + 1):
		var off: float = (float(i) - pos) * w
		if absf(off) >= w:
			continue
		_draw_page(i, Rect2(off + 8.0, 0.0, w - 16.0, card_h))
	# Indicadores de página.
	var n: int = regions.size()
	var dot: float = 14.0
	var gap: float = 12.0
	var total: float = n * dot + (n - 1) * gap
	var x0: float = (w - total) * 0.5
	for i in n:
		var r := Rect2(x0 + i * (dot + gap), card_h + 12.0, dot, dot)
		draw_rect(r, PixelArt.OUTLINE)
		var active: bool = i == target
		draw_rect(r.grow(-3.0), PixelArt.ORANGE if active else (Color("6a7488") if GameState.is_region_unlocked(regions[i].id) else Color("3a3f4c")))


func _draw_page(i: int, card: Rect2) -> void:
	var r: RegionDef = regions[i]
	var unlocked: bool = GameState.is_region_unlocked(r.id)
	draw_style_box(PixelArt.style(&"frame"), card)
	var inner: Rect2 = card.grow(-float(PixelArt.SCALE) * 7.0)
	# Mar de nuvens do mapa.
	draw_rect(inner, Color("13213a"))
	for k in 9:
		var h1: float = WorldGenerator.hash01(i, k, 91)
		var h2: float = WorldGenerator.hash01(i, k, 92)
		var c := Vector2(inner.position.x + h1 * inner.size.x, inner.position.y + 20.0 + h2 * (inner.size.y - 40.0))
		var rad: float = 14.0 + WorldGenerator.hash01(i, k, 93) * 18.0
		# Nuvem achatada: base reta + três "bolas" em cima.
		draw_rect(Rect2(c.x - rad * 2.2, c.y, rad * 4.4, rad * 0.7), Color("182844"))
		for j in 3:
			draw_circle(c + Vector2((j - 1) * rad * 1.2, 0.0), rad * (1.0 if j == 1 else 0.75), Color("182844"))
		draw_circle(c + Vector2(-rad * 0.3, -rad * 0.3), rad * 0.55, Color("1e3354"))
	var gx: float = inner.position.x
	while gx < inner.end.x:
		draw_rect(Rect2(gx, inner.position.y, 1, inner.size.y), Color(1, 1, 1, 0.03))
		gx += 32.0
	# Ilha da região (flutuando).
	var tex: Texture2D = RegionArt.texture(r)
	var k: float = floorf(minf(inner.size.x * 0.95 / RegionArt.W, (inner.size.y - 16.0) / RegionArt.H))
	k = maxf(k, 1.0)
	var sz := Vector2(RegionArt.W, RegionArt.H) * k
	var bob: float = roundf(sin(_t * 1.6 + i) * 2.0) * k * 0.5
	var p: Vector2 = Vector2(inner.get_center().x - sz.x * 0.5, inner.position.y + 8.0 + bob)
	draw_texture_rect(tex, Rect2(p, sz), false, Color.WHITE if unlocked else Color(0.58, 0.58, 0.68))
	# Placa com o nome + progresso ou cadeado.
	var f: Font = UiTheme.font(700)
	var name: String = UiTheme.display_text(r.display_name.to_upper())
	var fs: int = UiTheme.fit_size(f, name, UiTheme.font_size(26, 700), inner.size.x - 70.0)
	var tw: float = f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var plate := Rect2(inner.get_center().x - tw * 0.5 - 22.0, inner.end.y - 92.0, tw + 44.0, 46.0)
	draw_style_box(PixelArt.style(&"plate" if (unlocked and i == target) else &"inset"), plate)
	var text_col: Color = Color("2a1606") if (unlocked and i == target) else UiTheme.TEXT
	draw_string(f, Vector2(plate.position.x + 22.0, plate.position.y + 31.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_col)
	var badge := Rect2(inner.get_center().x - 110.0, plate.end.y + 4.0, 220.0, 34.0)
	draw_style_box(PixelArt.style(&"slot"), badge)
	if unlocked:
		var ratio: float = GameState.region_completion(r.id)
		var bar := Rect2(badge.position + Vector2(12, 11), Vector2(120, 12))
		draw_rect(bar, Color("262c3a"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), PixelArt.GOLD)
		draw_string(UiTheme.font(700), Vector2(badge.position.x + 142.0, badge.position.y + 24.0), "%d%%" % int(ratio * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.font_size(20, 700), UiTheme.TEXT)
	else:
		draw_texture_rect(PixelArt.icon(&"lock"), Rect2(badge.position + Vector2(14, 4), Vector2(26, 26)), false)
		draw_string(UiTheme.font(700), Vector2(badge.position.x + 50.0, badge.position.y + 24.0), "BLOQUEADO", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.font_size(20, 700), UiTheme.RED)
		var lock_sz: float = 22.0 * k * 0.3 + 40.0
		draw_texture_rect(PixelArt.icon(&"lock"), Rect2(Vector2(inner.get_center().x - lock_sz * 0.5, p.y + sz.y * 0.32), Vector2(lock_sz, lock_sz)), false)
	# Destaque da região em que o jogador está explorando.
	if r.id == GameState.region_id and GameState.expedition_active:
		var pin := Vector2(p.x + sz.x * 0.22, p.y + 4.0)
		draw_circle(pin, 12.0, PixelArt.OUTLINE)
		draw_circle(pin, 9.0, PixelArt.GOLD)
		draw_circle(pin, 4.0, Color("2a1606"))
