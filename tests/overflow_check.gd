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
			for t in [&"creatures", &"plans", &"diary"]:
				garage.set("_lab_tab", t)
				garage.call("_refresh")
				await _frames(6)
				_scan("lab/" + String(t), garage)
		garage.close()
		await _frames(3)
	var wm: Node = main.get("world_map")
	wm.call("open")
	await _frames(10)
	_scan("mapa", wm)
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
	var rep: ExpeditionReport = main.get("report")
	GameState.collect_drops(Vector2.ZERO, {&"copper": 40, &"gold": 9, &"leather": 2})
	rep.show_report(GameState.end_expedition(false))
	await _frames(10)
	_scan("resumo", rep)
	var vic := VictoryScreen.new()
	vic.guardian_name = "o Coração da Raiz-Mãe"
	vic.unlocked_name = "Dunas Escaldantes"
	vic.next_region = &"dunas"
	main.add_child(vic)
	for i in 330:
		await get_tree().process_frame
	if is_instance_valid(vic):
		_scan("vitória", vic)
		vic.queue_free()
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
		# Dentro de rolagem horizontal não conta.
		var r: Rect2 = ctl.get_global_rect()
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
