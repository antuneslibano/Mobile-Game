extends Node
## Checagem de telas cortadas (0.20): abre cada tela e lista controles visíveis que
## passam das bordas laterais da tela. Rodar com tests/overflow_check.tscn.

var main: Node
var _bad: int = 0


func _ready() -> void:
	Tutorial.enabled = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(20)
	var w: Vector2 = get_viewport().get_visible_rect().size
	print("viewport ", w)
	GameState.economy.credits = 98765432
	GameState.economy.crystals = 123456
	GameState._emit_economy()
	var base: BaseScreen = main.get("base")
	base.open()
	await _frames(10)
	_scan("base", base)
	var garage: Garage = main.get("garage")
	GameState.collect_drops(Vector2.ZERO, {&"copper": 40, &"iron": 40, &"gold": 10, &"leather": 3})
	for st in [&"bench", &"hangar", &"market", &"lab"]:
		garage.open_station(st)
		await _frames(10)
		_scan(String(st), garage)
		if st == &"market":
			garage.open_sell(&"copper")
			await _frames(10)
			_scan("venda", garage)
		if st == &"lab":
			for k: StringName in ResourceRegistry.order():
				GameState.economy.discovered[k] = true
			for sp in Creature.ORDER:
				GameState.creatures[sp] = {"seen": true, "defeated": 1}
			for k: StringName in ResourceRegistry.order():
				if not k in Garage.CATALOG_SKIP and not Relics.is_relic_key(k):
					garage.call("_mineral_card", k, true)
					await _frames(2)
					_scan("ficha/" + String(k), garage)
			for sp in Creature.ORDER:
				garage.call("_creature_card", sp, true)
				await _frames(2)
				_scan("ficha/" + String(sp), garage)
			for r in Relics.REGION_ORDER:
				garage.call("_relic_card", r)
				await _frames(2)
				_scan("ficha/" + String(r), garage)
			garage.call("_refresh")
			for t in [&"creatures", &"plans", &"diary"]:
				garage.set("_lab_tab", t)
				garage.call("_refresh")
				await _frames(6)
				_scan("lab/" + String(t), garage)
		garage.close()
		await _frames(3)
	var wm: Node = main.get("world_map")
	for r in RegionRegistry.all():
		GameState.unlocked[r.id] = true
	wm.call("open")
	for i in RegionRegistry.all().size():
		wm.call("go_to_page", i, true)
		await _frames(8)
		_scan("mapa/" + String(RegionRegistry.all()[i].id), wm)
	wm.call("close")
	var st2: SettingsScreen = main.get("settings")
	st2.open()
	await _frames(6)
	_scan("config", st2)
	st2.show_admin()
	await _frames(6)
	_scan("admin", st2)
	st2.show_diagnostics()
	await _frames(6)
	_scan("diag", st2)
	st2.close()
	base.close()
	main.call("_start_expedition", RegionRegistry.VALE, 0)
	await _frames(10)
	_scan("hud", main.get("hud"))
	var hud: Node = main.get("hud")
	var alerts: Array[String] = []
	for sp in Creature.ORDER:
		alerts.append(("Nova criatura: " + String(Creature.DEFS[sp].name)).to_upper())
	for r in Relics.REGION_ORDER:
		alerts.append("RELÍQUIA: %s!" % String(Relics.DEFS[r][1]).to_upper())
	for rr in RegionRegistry.all():
		alerts.append(("Câmara final: " + rr.display_name).to_upper())
	alerts.append("SUPERAQUECENDO 320°/150°\nBROCA −50%  ·  CASCO −12/s")
	for t in alerts:
		hud.call("show_alert", t, Color.WHITE)
		await _frames(2)
		_scan("alerta: " + t.left(30), hud)
	var rep: ExpeditionReport = main.get("report")
	GameState.collect_drops(Vector2.ZERO, {&"copper": 40, &"gold": 9, &"leather": 2})
	rep.show_report(GameState.end_expedition(false))
	await _frames(10)
	_scan("resumo", rep)
	for rr in RegionRegistry.all():
		var vic := VictoryScreen.new()
		vic.guardian_name = rr.guardian_name
		vic.unlocked_name = rr.display_name
		vic.next_region = &"dunas"
		main.add_child(vic)
		for i in 4:
			await get_tree().process_frame
		_scan("vitória/" + String(rr.id), vic)
		vic.queue_free()
		await get_tree().process_frame
	get_tree().paused = false
	GameState.economy.cargo[&"relic_seed"] = 1
	main.call("show_relic_choice", &"relic_seed")
	await _frames(6)
	_scan("relíquia", main.get_node("RelicChoice"))
	print("TOTAL cortes: %d" % _bad)
	get_tree().quit(1 if _bad > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scan(label: String, root: Node) -> void:
	var w: float = get_viewport().get_visible_rect().size.x
	var found: Array[String] = []
	for c in _all(root):
		if not (c is Control) or not (c as Control).is_visible_in_tree():
			continue
		var ctl := c as Control
		if ctl is ScrollContainer or ctl.size.x <= 0.0:
			continue
		var r: Rect2 = ctl.get_global_rect()
		# Texto maior que a própria caixa (sem quebra de linha nem corte): vaza na tela.
		if ctl is Label:
			var lb := ctl as Label
			if lb.autowrap_mode == TextServer.AUTOWRAP_OFF and not lb.clip_text and lb.text != "":
				var f: Font = lb.get_theme_font("font")
				var fs: int = lb.get_theme_font_size("font_size")
				var widest: float = 0.0
				for line in lb.text.split("\n"):
					widest = maxf(widest, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
				var cx: float = r.get_center().x
				if cx - widest * 0.5 < -1.0 and lb.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER or cx + widest * 0.5 > w + 1.0 and lb.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER or (lb.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER and r.position.x + widest > w + 1.0):
					found.append("TEXTO '%s' (%.0f px) x=%.0f" % [lb.text.left(30), widest, r.position.x])
					continue
		if r.position.x < -1.0 or r.end.x > w + 1.0:
			if _clipped_by_parent(ctl):
				continue
			found.append("%s [%s] x=%.0f..%.0f" % [ctl.name, ctl.get_class(), r.position.x, r.end.x])
	print("== %s: %d" % [label, found.size()])
	for f in found.slice(0, 12):
		print("   ", f)
	_bad += found.size()


func _clipped_by_parent(c: Control) -> bool:
	var p: Node = c.get_parent()
	while p != null:
		if p is ScrollContainer and (p as ScrollContainer).horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			return true
		p = p.get_parent()
	return false


func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = []
	for ch in n.get_children():
		out.append(ch)
		out.append_array(_all(ch))
	return out
