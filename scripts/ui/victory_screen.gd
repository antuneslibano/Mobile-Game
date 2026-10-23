class_name VictoryScreen
extends CanvasLayer
## Vitória sobre o guardião (0.19). Três tempos:
##   1) "VITÓRIA!" com o nome do guardião e a região liberada;
##   2) a tela escurece, um coração pulsa fraco e aparece, letra por letra,
##      "...mas ele retornará." — a região vai ser refeita, com o guardião de volta;
##   3) contagem de COUNTDOWN segundos para voltar à base, com os botões PRÓXIMA REGIÃO e
##      BASE AGORA. O jogo fica pausado enquanto a tela está aberta.

signal chosen(next_region: StringName)   ## &"" = base

const COUNTDOWN: float = 5.0
const T_OMEN: float = 2.2      ## Começa o "ele retornará".
const T_CHOICE: float = 4.6    ## Aparecem a contagem e os botões.
const OMEN: String = "...mas ele retornará."

var guardian_name: String = ""
var unlocked_name: String = ""
var next_region: StringName = &""
var _t: float = 0.0
var _root: Control
var _art: Control
var _title: Label
var _sub: Label
var _omen: Label
var _count: Label
var _row: HBoxContainer
var _done: bool = false
var _beats: int = 0


func _ready() -> void:
	layer = 32
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_art = Control.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_STOP
	_art.draw.connect(_draw_art)
	_root.add_child(_art)
	var safe := SafeMargin.new(24.0, 40.0, 40.0, 680.0)
	_root.add_child(safe)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(v)
	_title = UiTheme.label(UiTheme.display_text("VITÓRIA!"), 64, Color("ffd23f"), 700)
	_title.name = "VictoryTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	var sub_text: String = "Você venceu %s!" % guardian_name
	if unlocked_name != "":
		sub_text += "\nNova região liberada: %s." % unlocked_name
	_sub = UiTheme.label(sub_text, 26, UiTheme.TEXT, 600)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 220)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gap)
	_omen = UiTheme.label("", 40, Color("ff4a3a"), 700)
	_omen.name = "VictoryOmen"
	_omen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_omen.add_theme_constant_override("outline_size", 8)
	v.add_child(_omen)
	_count = UiTheme.label("", 24, UiTheme.TEXT_DIM, 600)
	_count.name = "VictoryCount"
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_count)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 12)
	_row.modulate.a = 0.0
	v.add_child(_row)
	if next_region != &"":
		var nb := _button("NextRegionButton", "PRÓXIMA REGIÃO  >", &"green")
		nb.pressed.connect(func() -> void: _choose(next_region))
		_row.add_child(nb)
	var bb := _button("VictoryBaseButton", "BASE AGORA", &"gold")
	bb.pressed.connect(func() -> void: _choose(&""))
	_row.add_child(bb)
	Sfx.play(&"chest", 0.9)
	Sfx.play(&"boost", 0.8, -4.0)


func _button(node_name: String, text: String, style: StringName) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = UiTheme.display_text(text)
	b.custom_minimum_size = Vector2(0, 84)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", UiTheme.font_size(24, 700))
	UiTheme.style_button(b, style)
	b.disabled = true
	return b


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	# 2) "ele retornará": as letras aparecem uma a uma; batidas fracas de coração.
	if _t >= T_OMEN:
		var n: int = clampi(int((_t - T_OMEN) / 0.07), 0, OMEN.length())
		_omen.text = UiTheme.display_text(OMEN.substr(0, n))
		_title.modulate.a = clampf(1.0 - (_t - T_OMEN) * 0.6, 0.35, 1.0)
		var beat: int = int((_t - T_OMEN) / 1.1)
		if beat >= _beats:
			_beats = beat + 1
			Sfx.play(&"boss_hit", 0.55, -10.0)
	# 3) contagem e botões.
	if _t >= T_CHOICE:
		_row.modulate.a = minf(1.0, (_t - T_CHOICE) * 3.0)
		for b in _row.get_children():
			(b as Button).disabled = false
		var left: float = COUNTDOWN - (_t - T_CHOICE)
		_count.text = "A região será refeita. Voltando à base em %d..." % ceili(maxf(0.0, left))
		if left <= 0.0:
			_choose(&"")
	_art.queue_redraw()


func _choose(region_id: StringName) -> void:
	if _done:
		return
	_done = true
	Sfx.play(&"click")
	get_tree().paused = false
	chosen.emit(region_id)
	queue_free()


## Fundo: escurece aos poucos; raios dourados na vitória; coração pulsando no "retornará".
func _draw_art() -> void:
	var sz: Vector2 = _art.size
	var dark: float = clampf(0.72 + (_t - T_OMEN) * 0.2, 0.72, 0.9) if _t >= T_OMEN else 0.72
	_art.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.02, 0.01, 0.03, dark))
	var c: Vector2 = sz * Vector2(0.5, 0.5)
	if _t < T_OMEN + 0.6:
		var a: float = clampf(1.0 - (_t - T_OMEN) / 0.6, 0.0, 1.0) if _t >= T_OMEN else 1.0
		for i in 12:
			var ang: float = _t * 0.4 + i * TAU / 12.0
			var p1: Vector2 = c + Vector2.from_angle(ang) * 80.0
			var p2: Vector2 = c + Vector2.from_angle(ang + 0.12) * 900.0
			var p3: Vector2 = c + Vector2.from_angle(ang - 0.12) * 900.0
			_art.draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color(1.0, 0.85, 0.3, 0.07 * a))
	if _t >= T_OMEN:
		# Coração em pixel art (quadrados de 12 px), pulsando fraco a cada batida.
		var ph: float = fposmod(_t - T_OMEN, 1.1)
		var pulse: float = 1.0 + 0.12 * exp(-ph * 6.0)
		var glow: float = clampf((_t - T_OMEN) * 0.8, 0.0, 1.0)
		var heart: Array[String] = [
			".XX...XX.",
			"XXXX.XXXX",
			"XXXXXXXXX",
			"XXXXXXXXX",
			".XXXXXXX.",
			"..XXXXX..",
			"...XXX...",
			"....X....",
		]
		var px: float = 12.0 * pulse
		var origin: Vector2 = c + Vector2(-4.5 * px, -4.0 * px)
		_art.draw_circle(c, 120.0 * pulse, Color(0.8, 0.1, 0.1, 0.12 * glow))
		for y in heart.size():
			for x in heart[y].length():
				if heart[y][x] == "X":
					var col := Color(0.55, 0.06, 0.08, glow) if (x + y) % 3 != 0 else Color(0.8, 0.15, 0.12, glow)
					_art.draw_rect(Rect2(origin + Vector2(x, y) * px, Vector2(px, px)), col)
