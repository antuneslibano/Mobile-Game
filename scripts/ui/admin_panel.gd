class_name AdminPanel
extends Control
## Modo teste (0.19.1): atalhos para testar o jogo sem jogar tudo de novo. Abre pelas
## Configurações. Tudo o que é dado aqui vai para o salvamento normal.

const ACTIONS: Array = [
	[&"credits", "+10.000 CRÉDITOS", &"gold"],
	[&"crystals", "+100 CRISTAIS", &"gold"],
	[&"resources", "+50 DE CADA RECURSO", &"green"],
	[&"relics", "TODAS AS RELÍQUIAS", &"green"],
	[&"regions", "LIBERAR REGIÕES", &"green"],
	[&"upgrades", "MELHORIAS NO MÁXIMO", &"green"],
	[&"wear", "SUJAR A NAVE", &"steel"],
	[&"clean", "LIMPAR A NAVE", &"steel"],
	[&"invincible", "", &"steel"],
	[&"jump_relic", "IR ATÉ A RELÍQUIA", &"steel"],
	[&"jump_guardian", "IR AO GUARDIÃO", &"steel"],
	[&"refill", "ENCHER TANQUE E CASCO", &"steel"],
]

signal jumped

var _status: Label
var _buttons: Dictionary = {}


func _ready() -> void:
	name = "AdminPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var safe := SafeMargin.new(16.0, 16.0, 16.0)
	add_child(safe)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelArt.style(&"frame"))
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	v.add_child(UiTheme.label(UiTheme.display_text("MODO TESTE"), 30, UiTheme.ORANGE, 700))
	var hint := UiTheme.label("Atalhos para testar. O que for dado aqui fica no seu salvamento.", 19, UiTheme.TEXT_DIM, 500)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(300, 0)
	v.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for a: Array in ACTIONS:
		var id: StringName = a[0]
		var b := Button.new()
		b.name = "Admin_" + String(id)
		b.custom_minimum_size = Vector2(0, 74)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", UiTheme.font_size(18, 700))
		b.text = UiTheme.display_text(String(a[1]))
		UiTheme.style_button(b, a[2])
		b.pressed.connect(func() -> void: run(id))
		grid.add_child(b)
		_buttons[id] = b
	_status = UiTheme.label("", 21, UiTheme.GREEN, 700)
	_status.name = "AdminStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(300, 0)
	v.add_child(_status)
	var back := Button.new()
	back.name = "AdminClose"
	back.text = UiTheme.display_text("FECHAR")
	back.custom_minimum_size = Vector2(0, 72)
	back.add_theme_font_size_override("font_size", UiTheme.font_size(24, 700))
	UiTheme.style_button(back, &"steel")
	back.pressed.connect(queue_free)
	v.add_child(back)
	_refresh()
	Transitions.pop_in(panel)


func _refresh() -> void:
	var inv: Button = _buttons[&"invincible"]
	inv.text = UiTheme.display_text("INVENCÍVEL: " + ("LIGADO" if ShipVitals.invincible else "DESLIGADO"))
	UiTheme.style_button(inv, &"green" if ShipVitals.invincible else &"steel")
	var in_run: bool = GameState.expedition_active
	for id: StringName in [&"jump_relic", &"jump_guardian", &"refill"]:
		(_buttons[id] as Button).disabled = not in_run


## Executa um atalho. Retorna o texto mostrado (também usado pelos testes).
func run(id: StringName) -> String:
	var e: Economy = GameState.economy
	var msg: String = ""
	match id:
		&"credits":
			e.credits += 10000
			msg = "+10.000 créditos"
		&"crystals":
			e.crystals += 100
			msg = "+100 cristais"
		&"resources":
			var gift: Dictionary = {}
			for key: StringName in ResourceRegistry.order():
				var def: ResourceDef = ResourceRegistry.get_def(key)
				if def.currency == &"" and not Relics.is_relic_key(key) and key != &"bio_sample":
					gift[key] = 50
			for key: StringName in gift:
				e.cargo[key] = int(e.cargo.get(key, 0)) + 50
				e.discovered[key] = true
			msg = "+50 de %d recursos no armazém" % gift.size()
		&"relics":
			for r: StringName in Relics.REGION_ORDER:
				var key: StringName = Relics.for_region(r)[0]
				e.cargo[key] = int(e.cargo.get(key, 0)) + 1
				e.discovered[key] = true
			msg = "Relíquias no armazém: instale ou venda no Laboratório (Planos › Relíquias)"
		&"regions":
			for r in RegionRegistry.all():
				GameState.unlocked[r.id] = true
			msg = "Todas as regiões liberadas"
		&"upgrades":
			for def: UpgradeDef in UpgradeRegistry.all():
				e.set_level(def.id, def.max_level)
			GameState._refresh_stats()
			EventBus.stats_changed.emit()
			msg = "Melhorias no nível máximo"
		&"wear":
			for k in WearRules.KINDS:
				GameState.wear[k] = 0.85
			msg = "Nave suja: limpe no Hangar"
		&"clean":
			GameState.wear = WearRules.fresh()
			msg = "Nave novinha"
		&"invincible":
			ShipVitals.invincible = not ShipVitals.invincible
			msg = "Invencível: sem gastar combustível e sem dano" if ShipVitals.invincible else "Invencível desligado"
		&"jump_relic", &"jump_guardian", &"refill":
			var main: Node = get_tree().current_scene
			if main == null or not main.has_method("admin_jump") or not bool(main.call("admin_jump", id)):
				msg = "Só durante uma expedição"
			else:
				msg = "Pronto!"
				jumped.emit()
	GameState._emit_economy()
	SaveService.mark_dirty()
	Sfx.play(&"pickup")
	if _status != null:
		_status.text = msg
		Transitions.bump(_status)
	_refresh()
	return msg
