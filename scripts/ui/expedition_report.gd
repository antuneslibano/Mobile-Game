class_name ExpeditionReport
extends CanvasLayer
## Resultado de uma expedição: extração (toda a carga) ou resgate de emergência (metade da
## carga desta expedição), profundidade, carga trazida/perdida e conquistas (objetivos,
## elevadores). "IR PARA A BASE" fecha e volta ao mapa. Pausa o jogo enquanto aberta.

signal closed

var _root: Control
var _box: VBoxContainer


func _ready() -> void:
	layer = 28
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func is_open() -> bool:
	return visible


func show_report(r: Dictionary) -> void:
	if _root != null:
		_root.queue_free()
	_build(r)
	visible = true
	Transitions.slide_in(_root)
	get_tree().paused = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _build(r: Dictionary) -> void:
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var margin := SafeMargin.new(18.0, 90.0, 90.0, 700.0)
	_root.add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelArt.style(&"frame"))
	margin.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var rescued: bool = bool(r.get("rescued", false))
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", PixelArt.style(&"plate" if not rescued else &"red_pressed"))
	v.add_child(plate)
	var title := UiTheme.label("RESGATE DE EMERGÊNCIA" if rescued else "EXTRAÇÃO CONCLUÍDA", 34, Color("2a1606") if not rescued else UiTheme.TEXT, 700)
	title.name = "Title"
	title.add_theme_constant_override("outline_size", 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(title)
	if rescued:
		var why: String = {&"fuel": "Acabou o combustível.", &"hull": "O casco não aguentou.",
				&"interrupted": "A expedição foi interrompida."}.get(StringName(r.get("reason", "")), "")
		v.add_child(_wrap("%s Resgate: metade da carga perdida." % why, 25, UiTheme.TEXT))
	var region: RegionDef = RegionRegistry.get_def(StringName(r.get("region", "")))
	v.add_child(UiTheme.label("%s  ·  máx %d m" % [region.display_name, int(r.get("depth", 0))], 26, UiTheme.TEXT_DIM, 600))

	var scroll := TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_box)

	_section("CARGA TRAZIDA")
	var kept: Dictionary = r.get("kept", {})
	if kept.is_empty():
		_box.add_child(UiTheme.label("Nada coletado nesta expedição.", 25, UiTheme.TEXT_DIM, 500))
	for k: Variant in kept:
		if int(kept[k]) > 0:
			_item(StringName(k), int(kept[k]), UiTheme.GREEN, "+")
	_box.add_child(UiTheme.label("Valor: %d créditos" % int(r.get("value_kept", 0)), 27, UiTheme.CREDITS, 700))
	var lost: Dictionary = r.get("lost", {})
	if not lost.is_empty():
		_section("PERDIDO NO RESGATE")
		for k: Variant in lost:
			_item(StringName(k), int(lost[k]), UiTheme.RED, "−")
		_box.add_child(UiTheme.label("−%d créditos" % int(r.get("value_lost", 0)), 25, UiTheme.RED, 700))
	if bool(r.get("reset", false)):
		v.add_child(_wrap("...mas ele retornará. Região refeita.", 22, Color("ff7a6a")))
	# Desgaste (0.19): avisa quando a nave voltou precisando de cuidado.
	var wear: Dictionary = WearRules.from_dict(r.get("wear", {}))
	if WearRules.needs_care(wear):
		v.add_child(_wrap("Nave desgastada (%d%% · %d%% · %d%%): limpe no Hangar." % [
				roundi(float(wear[&"dirt"]) * 100.0), roundi(float(wear[&"rust"]) * 100.0), roundi(float(wear[&"dents"]) * 100.0)], 22, Color("ffb347")))
	var events: Array = Array(r.get("events", []))
	if not events.is_empty():
		_section("CONQUISTAS")
		for e: Variant in events:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.add_child(UiTheme.icon_rect(&"star", 30))
			var l := _wrap(str(e), 24, UiTheme.TEXT)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			_box.add_child(row)

	var back := Button.new()
	back.name = "BaseButton"
	back.text = UiTheme.display_text("IR PARA A BASE")
	back.custom_minimum_size = Vector2(0, 88)
	back.add_theme_font_size_override("font_size", UiTheme.font_size(34, 700))
	UiTheme.style_button(back, &"green")
	back.pressed.connect(close)
	v.add_child(back)


func _section(text: String) -> void:
	_box.add_child(UiTheme.label(text, 28, UiTheme.ORANGE, 700))


func _item(key: StringName, n: int, color: Color, sign: String) -> void:
	var rd: ResourceDef = ResourceRegistry.get_def(key)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.texture = PixelArt.ore_icon(key)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(44, 40)
	row.add_child(icon)
	var name_l := UiTheme.label(rd.display_name if rd != null else String(key), 25, UiTheme.TEXT, 500)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	row.add_child(UiTheme.label("%s%d" % [sign, n], 26, color, 700))
	_box.add_child(row)


func _wrap(text: String, size: int, color: Color) -> Label:
	var l := UiTheme.label(text, size, color, 500)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(200, 0)
	return l
