extends Node
## Teste de integração da cena principal com toques simulados (caminho real de entrada).
##   godot --headless --path . --fixed-fps 60 res://tests/scene_test.tscn

var _fail: int = 0
var _checks: int = 0


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if cond:
		print("  ok    %s" % msg)
	else:
		_fail += 1
		print("  FALHA %s" % msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	get_viewport().push_input(ev, true)


func _mouse(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev, true)


func _drag(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	get_viewport().push_input(ev, true)


func _run() -> void:
	print("== scene_test")
	# Não toca no salvamento real do jogador; começa de um perfil novo.
	SaveService.enabled = false
	GameState.reset_profile()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(10)
	var world_map: WorldMap = main.get("world_map")
	_check(world_map != null and world_map.is_open() and get_tree().paused, "mapa mundial abre ao iniciar")
	_check(world_map.current_region().id == RegionRegistry.VALE, "carrossel começa no Vale das Raízes")
	_check(world_map.explore() and not world_map.is_open() and not get_tree().paused, "EXPLORAR fecha o mapa e inicia")
	await _frames(4)
	var game: Game = main.get_node("Game")
	var hud: Hud = main.get_node("Hud")
	var input: InputController = game.input
	var destroyed: Array[int] = [0]
	var drops_ok: Array[bool] = [true]
	EventBus.material_dug.connect(func(_at: Vector2, counts: Dictionary) -> void:
		for id: int in counts:
			destroyed[0] += int(counts[id])
			if BlockRegistry.get_def(id).drops.is_empty() and id != BlockRegistry.AIR:
				drops_ok[0] = false)


	_check(game.world != null, "mundo criado")
	_check(game.terrain.active_count() > 0, "chunks renderizados (%d)" % game.terrain.active_count())
	var dig: Rect2 = hud.dig_area()
	_check(dig.size.y > 600.0, "área de escavação ampla (%.0f px)" % dig.size.y)

	# Joystick flutuante: nasce onde o dedo toca; a direção relativa define a intenção.
	var o := Vector2(dig.get_center().x - 120.0, dig.get_center().y)
	var r: float = Balance.JOYSTICK_RADIUS_PX
	var it: DrillIntent = input.get_intent()
	_touch(0, o, true)
	await _frames(2)
	_check(it.aim == Vector2.ZERO, "toque parado (zona morta): nada")
	var stick: VirtualJoystick = hud.find_child("Joystick", true, false)
	_check(stick != null and stick.active and stick.base_pos == o, "joystick aparece onde o dedo tocou")
	_drag(0, o + Vector2(0, r))
	await _frames(2)
	_check(it.aim.y > 0.9 and absf(it.aim.x) < 0.01, "joystick para baixo: cava para baixo")
	_drag(0, o + Vector2(r, 0))
	await _frames(2)
	_check(it.aim.x > 0.9 and it.aim.y == 0.0, "joystick à direita: cava para a direita (%s)" % it.aim)
	_drag(0, o + Vector2(r, r) * 0.707)
	await _frames(2)
	_check(it.aim.x > 0.6 and it.aim.y > 0.6, "joystick na diagonal: cava na diagonal (%s)" % it.aim)
	_drag(0, o + Vector2(-r * 0.5, 0))
	await _frames(2)
	_check(it.aim.x < -0.3 and it.aim.x > -0.9, "joystick analógico à esquerda (%.2f)" % it.aim.x)
	_drag(0, o + Vector2(0, -r))
	await _frames(2)
	_check(it.aim == Vector2.ZERO, "joystick para cima: nada (a broca não sobe)")
	# Multitoque: joystick + impulso.
	var boost_b: Control = hud.find_child("BoostButton", true, false)
	_check(boost_b != null, "botão de impulso existe")
	_drag(0, o + Vector2(0, r))
	_touch(1, boost_b.get_global_rect().get_center(), true)
	await _frames(2)
	_check(it.aim.y > 0.9 and it.boost, "multitoque: joystick + Sobrecarga")
	_touch(1, boost_b.get_global_rect().get_center(), false)
	_touch(0, o + Vector2(0, r), false)
	await _frames(2)
	_check(it.aim == Vector2.ZERO and not it.boost, "soltar: para")
	_check(not stick.active, "joystick volta ao repouso")
	_check(hud.find_child("Pad_left", true, false) == null and hud.find_child("Pad_drill", true, false) == null, "setas e PERFURAR removidos")

	# Barra superior não aciona perfuração.
	_touch(3, Vector2(100, 60), true)
	await _frames(2)
	_check(it.aim == Vector2.ZERO, "toque na barra superior é ignorado")
	_touch(3, Vector2(100, 60), false)

	# Sessão curta com o joystick para baixo: precisa descer e coletar.
	_touch(0, o, true)
	_drag(0, o + Vector2(0, r))
	await _frames(600)
	_touch(0, o + Vector2(0, r), false)
	await _frames(5)
	var max_depth: int = GameState.max_depth_m
	_check(max_depth >= 5, "desceu segurando o toque (%d m)" % max_depth)
	_check(destroyed[0] >= 40, "material escavado via EventBus (%d células)" % destroyed[0])
	_check(drops_ok[0], "drops emitidos conforme definição")
	_check(not game.drill.is_overlapping_solid(), "perfuradora fora de blocos sólidos")
	var cam_y: float = game.camera.get_screen_center_position().y
	_check(cam_y > 0.0 and absf(cam_y - game.drill.global_position.y) < 700.0, "câmera acompanha a profundidade")
	_check(hud.get_node("Root").find_child("*", true, false) != null, "HUD construído")

	# --- Garagem / economia (Fase 2) ---
	var econ: Economy = GameState.economy
	_check(econ.cargo_count() > 0, "carga coletada ao quebrar blocos (%d itens)" % econ.cargo_count())
	var garage: Garage = main.get("garage")
	var gbutton: Button = hud.find_child("GarageButton", true, false)
	_check(gbutton != null and gbutton.text.begins_with("GARAGEM  +"), "botão da garagem mostra valor da carga (%s)" % gbutton.text)
	gbutton.pressed.emit()
	await _frames(2)
	_check(garage.is_open() and get_tree().paused, "garagem abre e pausa o jogo")
	var value: int = econ.cargo_value()
	var sell: Button = garage.find_child("SellButton", true, false)
	sell.pressed.emit()
	await _frames(1)
	_check(econ.credits == value and econ.cargo_count() == 0, "vender tudo credita %d Créditos" % value)
	sell.pressed.emit()
	_check(econ.credits == value, "vender de novo não duplica")
	econ.credits += 1000
	var dmg_before: float = game.drill.stats.damage
	var card: UpgradeCard = garage.find_child("Card_damage", true, false)
	_check(card != null, "cartão de upgrade de dano existe")
	# Toque simples no preço compra; arrastar começando no mesmo botão só rola a lista.
	garage.call("_refresh")
	await _frames(2)
	var scroll: TouchScroll = garage.find_child("Scroll", true, false)
	var price: Button = garage.find_child("Card_speed", true, false).find_child("Price", true, false)
	var pc: Vector2 = price.get_global_rect().get_center()
	_mouse(pc, true)
	_mouse(pc, false)
	await _frames(2)
	_check(econ.get_level(&"speed") == 1, "toque no preço compra (Turbina Nv. 1)")
	var before: int = scroll.scroll_vertical
	pc = price.get_global_rect().get_center()
	_touch(0, pc, true)
	_mouse(pc, true)
	for k in 10:
		_drag(0, pc - Vector2(0, 30.0 * (k + 1)))
		await _frames(1)
	_touch(0, pc - Vector2(0, 300), false)
	_mouse(pc - Vector2(0, 300), false)
	await _frames(2)
	_check(scroll.scroll_vertical > before + 100, "arrastar sobre os cartões rola a lista (%d → %d)" % [before, scroll.scroll_vertical])
	_check(econ.get_level(&"speed") == 1, "arrastar começando no botão não compra")
	await _frames(30)
	scroll.scroll_vertical = 0
	var bought: bool = garage.buy(&"damage")
	await _frames(1)
	_check(bought and econ.get_level(&"damage") == 1, "comprou Dano nível 1")
	_check(game.drill.stats.damage > dmg_before, "perfuradora recebeu o novo dano (%.0f → %.0f)" % [dmg_before, game.drill.stats.damage])
	# Módulos (Fase 3): comprar equipa automaticamente; slots limitados; remover/equipar.
	econ.crystals += 500
	econ.credits += 5000
	_check(garage.buy(&"seismic"), "comprou Pulso sísmico")
	_check(econ.equipped_modules.has(&"seismic") and game.drill.modules.has(&"seismic"), "pulso equipado na máquina")
	_check(garage.buy(&"drone") and garage.buy(&"side_drill"), "comprou drone e broca lateral")
	_check(econ.equipped_modules.size() == Balance.MODULE_SLOTS, "slots respeitados (%d)" % econ.equipped_modules.size())
	_check(not econ.equipped_modules.has(&"side_drill"), "terceiro módulo fica na garagem")
	_check(garage.toggle_module(&"seismic") and not game.drill.modules.has(&"seismic"), "remover módulo")
	_check(garage.toggle_module(&"side_drill") and game.drill.modules.has(&"side_drill"), "equipar no slot livre")
	var close_b: Button = garage.find_child("CloseButton", true, false)
	close_b.pressed.emit()
	await _frames(2)
	_check(not garage.is_open() and not get_tree().paused, "garagem fecha e retoma o jogo")

	# --- Mapa mundial: carrossel, bloqueio, desbloqueio e troca de região ---
	var map_b: Button = hud.find_child("MapButton", true, false)
	_check(map_b != null, "botão do mapa no HUD")
	map_b.pressed.emit()
	await _frames(2)
	_check(world_map.is_open() and get_tree().paused, "mapa abre pelo HUD e pausa o jogo")
	var carousel: RegionCarousel = world_map.find_child("Carousel", true, false)
	var rect: Rect2 = carousel.get_global_rect()
	var c: Vector2 = rect.get_center()
	_touch(0, c, true)
	for k in 8:
		_drag(0, c - Vector2(40.0 * (k + 1), 0))
		await _frames(1)
	_touch(0, c - Vector2(320, 0), false)
	await _frames(40)
	_check(carousel.target == 1 and absf(carousel.pos - 1.0) < 0.01, "deslizar para a esquerda encaixa na página 2 (%.2f)" % carousel.pos)
	var dunas: RegionDef = world_map.current_region()
	_check(dunas.id == RegionRegistry.DUNAS, "página 2 é Dunas de Âmbar")
	var explore_b: Button = world_map.find_child("ExploreButton", true, false)
	_check(explore_b.disabled and not world_map.explore(), "região bloqueada: EXPLORAR desativado")
	_touch(0, c, true)
	for k in 8:
		_drag(0, c + Vector2(40.0 * (k + 1), 0))
		await _frames(1)
	_touch(0, c + Vector2(320, 0), false)
	await _frames(40)
	_check(carousel.target == 0, "deslizar para a direita volta à página 1")
	_touch(0, c, true)
	_drag(0, c - Vector2(30, 0))
	_touch(0, c - Vector2(30, 0), false)
	await _frames(30)
	_check(carousel.target == 0, "arrasto curto não troca de página")
	var next_b: Button = carousel.find_child("Next", true, false)
	next_b.pressed.emit()
	await _frames(30)
	_check(carousel.target == 1, "seta avança a página")

	GameState.region_progress[RegionRegistry.VALE] = dunas.unlock_depth_m
	world_map.go_to_page(1)
	_check(not explore_b.disabled, "requisito cumprido: Dunas liberadas")
	var vale_progress: int = GameState.region_depth(RegionRegistry.VALE)
	_check(world_map.explore(), "explorar Dunas")
	await _frames(6)
	_check(GameState.region_id == RegionRegistry.DUNAS and not world_map.is_open() and not get_tree().paused, "mergulho nas Dunas iniciado")
	_check(BiomeRegistry.get_def(0).display_name == dunas.layers[0].display_name, "camadas da região aplicadas")
	_check(game.world != null and game.drill.depth_m() <= 1, "novo mundo, perfuradora na superfície")
	_check(GameState.region_depth(RegionRegistry.VALE) == vale_progress, "progresso do Vale preservado")
	var start_y: float = game.drill.position.y
	var jc: Vector2 = o
	_touch(0, jc, true)
	_drag(0, jc + Vector2(0, 90))
	await _frames(150)
	_touch(0, jc + Vector2(0, 90), false)
	_check(game.drill.position.y > start_y + 12.0, "mineração funciona na nova região")

	# Perfil salvo e restaurado (progresso por região e região atual).
	var prof: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_profile()))
	_check(SaveFile.is_valid(prof), "perfil válido")
	GameState.reset_profile()
	GameState.apply_profile(prof)
	_check(GameState.region_id == RegionRegistry.DUNAS and GameState.region_depth(RegionRegistry.VALE) == vale_progress,
			"perfil restaura região e progresso")

	print("")
	print("%d verificações, %d falhas" % [_checks, _fail])
	main.queue_free()
	await _frames(2)
	get_tree().quit(1 if _fail > 0 else 0)
