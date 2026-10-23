class_name ShipCarePanel
extends VBoxContainer
## Seção "CUIDAR DA NAVE" do Hangar (0.19): a nave grande (ShipCare), as três ferramentas
## (esponja → sujeira, lixa → ferrugem, solda → amassados) com o quanto falta de cada uma,
## e uma dica curta. Grava o desgaste em GameState.wear enquanto o jogador limpa.

const TOOLS: Array = [
	[&"dirt", &"sponge", "ESPONJA", "Sujeira"],
	[&"rust", &"sandpaper", "LIXA", "Ferrugem"],
	[&"dents", &"welder", "SOLDA", "Amassados"],
]

var care: ShipCare
var _buttons: Dictionary = {}   ## tipo → Button
var _bars: Dictionary = {}      ## tipo → SegmentedBar
var _status: Label
var _effect: Label


func _init() -> void:
	name = "ShipCarePanel"
	add_theme_constant_override("separation", 8)
	add_child(UiTheme.label("CUIDAR DA NAVE", 32, UiTheme.ORANGE, 700))
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", PixelArt.style(&"inset"))
	add_child(frame)
	care = ShipCare.new()
	care.name = "ShipCare"
	frame.add_child(care)
	care.changed.connect(func(_k: StringName, _l: float) -> void: _sync())
	care.cleaned.connect(func(kind: StringName) -> void:
		_sync()
		_status.text = "%s: LIMPO!" % WearRules.NAMES[kind] if kind != &"dents" else "Amassados: CONSERTADO!"
		Transitions.bump(_status))
	_status = UiTheme.label("", 24, UiTheme.GREEN, 700)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for t: Array in TOOLS:
		var kind: StringName = t[0]
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 4)
		row.add_child(cell)
		var b := Button.new()
		b.name = "Tool_" + String(kind)
		b.text = UiTheme.display_text(String(t[2]))
		b.icon = PixelArt.icon(t[1])
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 40)
		b.custom_minimum_size = Vector2(0, 72)
		b.add_theme_font_size_override("font_size", UiTheme.font_size(18, 700))
		b.pressed.connect(func() -> void:
			Sfx.play(&"click")
			select(kind))
		cell.add_child(b)
		_buttons[kind] = b
		var bar := SegmentedBar.new(8, ShipCare.COLORS[kind][1], 18.0)
		cell.add_child(bar)
		_bars[kind] = bar
		var l := UiTheme.label(String(t[3]), 17, UiTheme.TEXT_DIM, 500)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(l)
	_effect = UiTheme.label("", 20, UiTheme.TEXT_DIM, 500)
	_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect.custom_minimum_size = Vector2(300, 0)
	add_child(_effect)


## Recarrega a nave e as manchas a partir do desgaste salvo (ao abrir o Hangar).
func reload() -> void:
	care.reload(GameState.wear, GameState.ship_look())
	_status.text = ""
	# Começa pela ferramenta do desgaste maior.
	var best: StringName = &"dirt"
	for k in WearRules.KINDS:
		if float(GameState.wear.get(k, 0.0)) > float(GameState.wear.get(best, 0.0)):
			best = k
	select(best)
	_sync()


func select(kind: StringName) -> void:
	care.tool = kind
	for k: StringName in _buttons:
		UiTheme.style_button(_buttons[k], &"green" if k == kind else &"steel")


func _sync() -> void:
	for k in WearRules.KINDS:
		var lv: float = care.level(k)
		GameState.wear[k] = lv
		(_bars[k] as SegmentedBar).value = lv
	var pen: float = WearRules.penalty(GameState.wear)
	var dents: float = float(GameState.wear.get(&"dents", 0.0))
	if pen <= 0.001 and dents <= 0.001:
		_effect.text = "Nave novinha! Broca no máximo e casco inteiro."
		_effect.add_theme_color_override("font_color", UiTheme.GREEN)
	else:
		_effect.text = "Escolha a ferramenta e arraste o dedo na nave. Agora: broca −%d%%, casco começa com %d%%." % [
				roundi(pen * 100.0), roundi(WearRules.hull_start_ratio(GameState.wear) * 100.0)]
		_effect.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
	SaveService.mark_dirty()
