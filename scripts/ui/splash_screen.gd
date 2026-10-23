class_name SplashScreen
extends CanvasLayer
## Tela de abertura (0.14): nome do jogo e a nave furando camadas de terra enquanto o
## jogo termina de carregar (a trilha sonora é gerada nesse meio-tempo). Fica pelo menos
## MIN_SEC, no máximo MAX_SEC, e some com um fade. Bloqueia toques enquanto aparece.

signal finished

const MIN_SEC: float = 1.8
const MAX_SEC: float = 4.0
const P: float = 6.0   ## Pixel de arte da cena.

var _t: float = 0.0
var _leaving: bool = false
var _root: Control
var _scene: Control
var _bar: SegmentedBar


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_scene = Control.new()
	_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene.draw.connect(_draw_scene)
	_root.add_child(_scene)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 10)
	_root.add_child(v)
	var top := Control.new()
	top.custom_minimum_size = Vector2(0, 150.0 + SafeArea.top(get_viewport()))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", PixelArt.style(&"plate"))
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(plate)
	var title := UiTheme.label("DEEPFORGE", 64, Color("2a1606"), 700)
	title.add_theme_constant_override("outline_size", 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(title)
	var sub := UiTheme.label(UiTheme.display_text("RUMO AO NÚCLEO"), 30, UiTheme.ORANGE, 700)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)
	var bar_box := MarginContainer.new()
	for side: String in ["left", "right"]:
		bar_box.add_theme_constant_override("margin_" + side, 90)
	bar_box.add_theme_constant_override("margin_bottom", 40)
	bar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bar_box)
	var bv := VBoxContainer.new()
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_box.add_child(bv)
	var loading := UiTheme.label("Perfurando...", 24, UiTheme.TEXT_DIM, 500)
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(loading)
	_bar = SegmentedBar.new(12, UiTheme.ORANGE, 28.0)
	bv.add_child(_bar)
	var tail := Control.new()
	tail.custom_minimum_size = Vector2(0, 60.0 + SafeArea.bottom(get_viewport()))
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tail)


func _process(delta: float) -> void:
	_t += delta
	_scene.queue_redraw()
	var done: bool = _t >= MIN_SEC and (Sfx.music_ready or _t >= MAX_SEC)
	_bar.value = clampf(_t / MIN_SEC, 0.0, 0.95) if not done else 1.0
	if done and not _leaving:
		_leaving = true
		var tw: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(_root, "modulate:a", 0.0, 0.45)
		tw.tween_callback(func() -> void:
			finished.emit()
			queue_free())


## Cena: camadas de terra subindo (a nave desce), túnel atrás da nave, entulho voando.
func _draw_scene() -> void:
	var sz: Vector2 = _scene.size
	_scene.draw_rect(Rect2(Vector2.ZERO, sz), Color("0b0e16"))
	var layers: Array[Color] = [Color("8a5a32"), Color("a8703a"), Color("c9a464"), Color("7a6a5a"), Color("5a4a44"), Color("3a3440")]
	var speed: float = 220.0
	var band_h: float = 160.0
	var off: float = fposmod(_t * speed, band_h * layers.size())
	var cx: float = sz.x * 0.5
	var ship_y: float = sz.y * 0.56
	var y: float = -off
	var i: int = 0
	while y < sz.y:
		var col: Color = layers[i % layers.size()]
		_scene.draw_rect(Rect2(0, y, sz.x, band_h), col.darkened(0.35))
		# Textura de pixels (pedrinhas) por camada.
		for k in 18:
			var px: float = fposmod(k * 97.0 + i * 53.0, sz.x)
			var py: float = y + fposmod(k * 37.0 + i * 29.0, band_h)
			_scene.draw_rect(Rect2(Vector2(px, py).snapped(Vector2(P, P)), Vector2(P * 2, P)), col.darkened(0.15))
		y += band_h
		i += 1
	# Túnel aberto acima da nave.
	_scene.draw_rect(Rect2(cx - 54, 0, 108, ship_y), Color("120e14"))
	_scene.draw_rect(Rect2(cx - 54, 0, P, ship_y), Color(0, 0, 0, 0.4))
	_scene.draw_rect(Rect2(cx + 48, 0, P, ship_y), Color(0, 0, 0, 0.4))
	# Nave apontando para baixo, tremendo.
	var tex: Texture2D = ShipArt.frame(int(_t * 12.0))
	var k2: float = 5.0
	var ssz := Vector2(ShipArt.W, ShipArt.H) * k2
	var shake := Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
	_scene.draw_set_transform(Vector2(cx, ship_y) + shake, PI * 0.5, Vector2.ONE)
	_scene.draw_texture_rect(tex, Rect2(-ssz * 0.5, ssz), false)
	_scene.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Faíscas e terra voando na ponta da broca.
	var tip := Vector2(cx, ship_y + ssz.x * 0.5)
	_scene.draw_circle(tip, 14.0, Color(1.0, 0.8, 0.4, 0.35))
	for k in 10:
		var ph: float = fposmod(_t * 2.5 + k / 10.0, 1.0)
		var ang: float = -PI * 0.5 + (k / 9.0 - 0.5) * 2.4
		var p: Vector2 = tip + Vector2(cos(ang), sin(ang)) * ph * 90.0 + Vector2(0, ph * ph * 60.0)
		var c: Color = Color(1.0, 0.85, 0.4) if k % 3 == 0 else layers[k % layers.size()]
		_scene.draw_rect(Rect2(p.snapped(Vector2(P, P)), Vector2(P, P)), Color(c.r, c.g, c.b, 1.0 - ph))
	# Escurece as bordas (foco na nave).
	_scene.draw_rect(Rect2(0, 0, sz.x, sz.y * 0.12), Color(0, 0, 0, 0.35))
