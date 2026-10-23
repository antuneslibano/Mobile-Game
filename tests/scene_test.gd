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
	Tutorial.enabled = false  # o tutorial tem o próprio teste (tutorial_test)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(10)
	_check(main.get_node_or_null("Splash") != null, "tela de abertura aparece ao abrir o jogo")
	var waited: int = 0
	while main.get_node_or_null("Splash") != null and waited < 600:
		await _frames(1)
		waited += 1
	_check(main.get_node_or_null("Splash") == null, "tela de abertura some sozinha (%d quadros)" % waited)
	var world_map: WorldMap = main.get("world_map")
	var base: BaseScreen = main.get("base")
	_check(base != null and base.is_open() and get_tree().paused and not world_map.is_open(), "a base abre ao iniciar")
	for kind: String in ["map", "lab", "bench", "hangar", "market"]:
		_check(base.find_child("Station_" + kind, true, false) != null, "estação %s tocável" % kind)
	_check(base.has_badge(&"lab"), "laboratório avisa a primeira entrada do diário")
	# Porta de metal (só no Laboratório): desce, troca a tela por trás e sobe.
	(base.find_child("Station_lab", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(Transitions.shutter_busy() and not main.get_node("Garage").call("is_open"), "porta de metal desce antes de trocar de tela")
	var door_frames: int = 0
	while Transitions.shutter_busy() and door_frames < 300:
		await _frames(1)
		door_frames += 1
	_check(main.get_node("Garage").call("is_open") and not Transitions.shutter_busy(), "a porta sobe com o Laboratório aberto (%d quadros)" % door_frames)
	main.get_node("Garage").call("close")
	await _frames(2)
	(base.find_child("Station_bench", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(not Transitions.shutter_busy() and main.get_node("Garage").call("is_open"), "Bancada abre direto, sem porta")
	main.get_node("Garage").call("close")
	await _frames(2)
	# Configurações: engrenagem da base abre; o controle muda o volume do canal.
	var settings: SettingsScreen = main.get("settings")
	(base.find_child("SettingsButton", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(settings.is_open() and get_tree().paused, "engrenagem abre as configurações")
	var music_slider: HSlider = settings.find_child("Volume_music", true, false)
	music_slider.value = 40.0
	_check(is_equal_approx(Sfx.get_volume(&"music"), 0.4) and AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Musica")) < -7.0, "volume da música muda no canal Musica")
	music_slider.value = 100.0
	(settings.find_child("SettingsClose", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(not settings.is_open() and base.is_open(), "PRONTO fecha as configurações")
	# O resto do teste troca de tela muitas vezes: sem porta, a troca é imediata.
	Transitions.shutter_enabled = false
	(base.find_child("Station_map", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(world_map.is_open() and get_tree().paused, "mesa de mapas abre o mapa mundial")
	_check(world_map.current_region().id == RegionRegistry.VALE, "carrossel começa no Vale das Raízes")
	_check(world_map.explore() and not world_map.is_open() and not base.is_open() and not get_tree().paused, "EXPLORAR fecha o mapa e a base e inicia")
	await _frames(4)
	var game: Game = main.get_node("Game")
	var hud: Hud = main.get_node("Hud")
	var input: InputController = game.input
	var destroyed: Array[int] = [0]
	var drops_ok: Array[bool] = [true]
	EventBus.material_dug.connect(func(_at: Vector2, counts: Dictionary) -> void:
		for id: int in counts:
			destroyed[0] += int(counts[id])
			var def: BlockDef = BlockRegistry.get_def(id)
			if def.drops.is_empty() and id != BlockRegistry.AIR and not def.is_terrain() and def.fuel <= 0.0:
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

	# Sessão curta com o joystick para baixo: precisa descer e coletar. Terra não rende
	# nada; um bolsão de cobre no caminho rende carga.
	game.world.fill_circle(game.drill.position + Vector2(0, 90), 40.0, BlockRegistry.COPPER)
	_touch(0, o, true)
	_drag(0, o + Vector2(0, r))
	await _frames(600)
	_touch(0, o + Vector2(0, r), false)
	await _frames(5)
	var max_depth: int = GameState.max_depth_m
	_check(max_depth >= 5, "desceu segurando o toque (%d m)" % max_depth)
	_check(destroyed[0] >= 40, "material escavado via EventBus (%d células)" % destroyed[0])
	_check(drops_ok[0], "só terreno sai sem drops (minérios sempre rendem)")
	_check(not game.drill.is_overlapping_solid(), "perfuradora fora de blocos sólidos")
	var cam_y: float = game.camera.get_screen_center_position().y
	_check(cam_y > 0.0 and absf(cam_y - game.drill.global_position.y) < 700.0, "câmera acompanha a profundidade")
	_check(hud.get_node("Root").find_child("*", true, false) != null, "HUD construído")

	# --- Garagem / economia (Fase 2) ---
	var econ: Economy = GameState.economy
	_check(econ.cargo_count() > 0, "carga coletada ao quebrar blocos (%d itens)" % econ.cargo_count())
	var last_report: Array[Dictionary] = [{}]
	EventBus.expedition_ended.connect(func(r: Dictionary) -> void: last_report[0] = r)

	# --- Extração (0.9): a cápsula leva a nave e TODA a carga; relatório; base ---
	var cargo_before: int = econ.cargo_count()
	var extract_b: Button = hud.find_child("ExtractButton", true, false)
	_check(extract_b != null and hud.find_child("GarageButton", true, false) == null, "HUD tem EXTRAIR (garagem só na base)")
	extract_b.pressed.emit()
	await _frames(140)
	var rep: ExpeditionReport = main.get("report")
	_check(rep.is_open() and get_tree().paused, "extração termina no relatório da expedição")
	var title: Label = rep.find_child("Title", true, false)
	_check(title != null and title.text.contains("EXTRA"), "relatório: extração concluída")
	_check(econ.cargo_count() == cargo_before and not bool(last_report[0].get("rescued", true)), "extração mantém toda a carga")
	_check(not GameState.expedition_active, "expedição encerrada")
	(rep.find_child("BaseButton", true, false) as Button).pressed.emit()
	await _frames(3)
	_check(base.is_open() and not world_map.is_open() and get_tree().paused, "volta para a base")
	var garage: Garage = main.get("garage")
	GameState.collect_drops(Vector2.ZERO, {&"copper": 60.0})  # bem mais que a reserva da Bancada
	_check(base.has_badge(&"market"), "mercado avisa que há carga para vender")
	(base.find_child("Station_market", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(garage.is_open() and garage.station() == &"market" and get_tree().paused, "mercado abre pela base e pausa o jogo")
	var value: int = econ.cargo_value()
	var sell: Button = garage.find_child("SellButton", true, false)
	sell.pressed.emit()
	await _frames(1)
	_check(econ.credits == value and econ.cargo_count() == 0, "vender tudo credita %d Créditos" % value)
	sell.pressed.emit()
	_check(econ.credits == value, "vender de novo não duplica")
	# Bancada: construir pede materiais + moeda; projeto bloqueado sem descobrir o material.
	(garage.find_child("CloseButton", true, false) as Button).pressed.emit()
	await _frames(1)
	(base.find_child("Station_bench", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(garage.station() == &"bench", "bancada abre pela base")
	econ.credits += 1000
	_check(not garage.buy(&"speed") and econ.get_level(&"speed") == 0, "sem materiais não constrói")
	GameState.collect_drops(Vector2.ZERO, {&"copper": 12.0, &"quartz": 12.0, &"iron": 12.0})
	var copper_before: int = int(econ.cargo.get(&"copper", 0))
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
	_check(econ.get_level(&"speed") == 1, "toque no preço constrói (Turbina Nv. 1)")
	_check(int(econ.cargo.get(&"copper", 0)) == copper_before - int(Recipes.materials(UpgradeRegistry.get_def(&"speed"), 0).get(&"copper", 0)), "construir gasta os materiais da receita")
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
	# Mercado: vender só o excedente mantém a reserva da Bancada.
	GameState.collect_drops(Vector2.ZERO, {&"iron": 30.0})
	garage.open_station(&"market")
	await _frames(1)
	garage.sell_surplus()
	var reserve: Dictionary = Recipes.reserve(econ.upgrade_levels)
	_check(int(econ.cargo.get(&"iron", 0)) == int(reserve.get(&"iron", 0)), "vender excedente guarda o que a Bancada usa (ferro %d)" % int(econ.cargo.get(&"iron", 0)))
	# Cuidar da nave (0.19): arrastar as ferramentas limpa e conserta.
	for k in WearRules.KINDS:
		GameState.wear[k] = 0.6
	garage.open_station(&"hangar")
	await _frames(3)
	var care: ShipCare = garage.find_child("ShipCare", true, false)
	var hscroll: ScrollContainer = garage.find_child("Scroll", true, false)
	_check(care != null and care.level(&"dirt") > 0.5, "Hangar mostra a nave suja")
	hscroll.scroll_vertical = int(care.get_global_rect().position.y - hscroll.get_global_rect().position.y) - 20
	await _frames(2)
	var scroll_before: int = hscroll.scroll_vertical
	for k in WearRules.KINDS:
		(garage.find_child("Tool_" + String(k), true, false) as Button).pressed.emit()
		await _frames(1)
		var origin: Vector2 = care.get_global_rect().position + care.ship_rect().position
		var area: Vector2 = care.ship_rect().size
		var py: float = 0.0
		while py <= area.y:
			_touch(0, origin + Vector2(0.0, py), true)
			var px: float = 0.0
			while px <= area.x:
				px += 14.0
				_drag(0, origin + Vector2(px, py))
			_touch(0, origin + Vector2(px, py), false)
			py += 10.0
		await _frames(1)
	_check(care.level(&"dirt") < 0.01 and care.level(&"rust") < 0.01 and care.level(&"dents") < 0.01, "esponja, lixa e solda limpam tudo (sujeira %.2f, ferrugem %.2f, amassados %.2f)" % [care.level(&"dirt"), care.level(&"rust"), care.level(&"dents")])
	_check(WearRules.penalty(GameState.wear) < 0.01 and WearRules.hull_start_ratio(GameState.wear) > 0.99, "desgaste do perfil zerado")
	_check(hscroll.scroll_vertical == scroll_before, "arrastar na nave não rola a lista")
	garage.open_station(&"lab")
	await _frames(1)
	_check(garage.find_child("Catalog", true, false) != null and not base.has_badge(&"lab"), "laboratório mostra catálogo e marca o diário como lido")
	var cat: Node = garage.find_child("Catalog", true, false)
	(cat.get_child(0) as Button).pressed.emit()
	await _frames(2)
	_check(garage.find_child("LabDetail", true, false) != null, "tocar num item do catálogo abre o cartão de detalhes")
	(garage.find_child("DetailClose", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(garage.find_child("LabDetail", true, false) == null, "FECHAR some com o cartão")
	var close_b: Button = garage.find_child("CloseButton", true, false)
	close_b.pressed.emit()
	await _frames(2)
	_check(not garage.is_open() and base.is_open() and get_tree().paused, "estação fecha e volta à base")
	(base.find_child("Station_map", true, false) as Button).pressed.emit()
	await _frames(2)

	# --- Mapa mundial: carrossel, bloqueio, desbloqueio e troca de região ---
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

	_check(not GameState.is_region_unlocked(RegionRegistry.DUNAS), "Dunas pedem a câmara final do Vale")
	GameState.done[RegionRegistry.VALE] = true
	world_map.go_to_page(1)
	_check(not explore_b.disabled, "câmara final do Vale concluída: Dunas liberadas")
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

	# --- Combustível: alerta e resgate de emergência (metade da carga desta expedição) ---
	GameState.collect_drops(game.drill.position, {&"gold": 4.0})
	var gold_before: int = int(GameState.economy.cargo.get(&"gold", 0))
	game.drill.vitals.fuel = game.drill.vitals.fuel_max * 0.2
	await _frames(3)
	var warn: Label = hud.find_child("Warning", true, false)
	_check(warn.visible and warn.text.contains("COMBUST"), "alerta visual de combustível baixo (%s)" % warn.text)
	var vig: ColorRect = hud.find_child("AlertVignette", true, false)
	_check(float((vig.material as ShaderMaterial).get_shader_parameter("strength")) > 0.05, "vinheta de alerta acesa")
	game.drill.vitals.fuel = 0.05
	_touch(0, jc, true)
	_drag(0, jc + Vector2(0, 90))
	await _frames(20)
	_touch(0, jc + Vector2(0, 90), false)
	_check(game.drill.disabled, "sem combustível: a nave para")
	await _frames(220)
	_check(rep.is_open(), "resgate termina no relatório")
	var title2: Label = rep.find_child("Title", true, false)
	_check(title2.text.contains("RESGATE"), "relatório: resgate de emergência")
	var lost_gold: int = int((last_report[0].get("lost", {}) as Dictionary).get(&"gold", 0))
	_check(bool(last_report[0].get("rescued", false)) and lost_gold >= 2 and int(GameState.economy.cargo.get(&"gold", 0)) == gold_before - lost_gold,
			"resgate perde metade da carga desta expedição (−%d ouro)" % lost_gold)
	(rep.find_child("BaseButton", true, false) as Button).pressed.emit()
	await _frames(3)
	_check(base.is_open(), "depois do resgate, volta à base")
	var prof_before_rules: Dictionary = GameState.to_profile()

	# --- Regras de expedição no GameState ---
	var vale_def: RegionDef = RegionRegistry.get_def(RegionRegistry.VALE)
	GameState.done.erase(RegionRegistry.VALE)
	GameState.unlocked.erase(RegionRegistry.DUNAS)
	GameState.start_dive(RegionRegistry.VALE)
	GameState.begin_expedition()
	GameState.check_final_chamber(RegionRegistry.chamber_center_x() + 20, vale_def.target_depth_m - 1)
	_check(not GameState.expedition_reached_final, "fora da câmara (lateral) não conta")
	GameState.check_final_chamber(RegionRegistry.chamber_center_x(), vale_def.target_depth_m - 1)
	_check(GameState.expedition_reached_final and not GameState.done.has(RegionRegistry.VALE), "chegar à câmara não conclui: falta vencer o guardião")
	GameState.complete_region(0.8)
	_check(GameState.done.has(RegionRegistry.VALE) and GameState.is_region_unlocked(RegionRegistry.DUNAS), "vencer o guardião conclui o Vale e libera as Dunas")
	_check(GameState.is_objective_done(RegionRegistry.VALE, &"final"), "objetivo principal concluído")
	var copper_obj: Dictionary = RegionRegistry.objective(vale_def, &"res_copper")
	GameState.collect_drops(Vector2.ZERO, {&"copper": float(copper_obj.target) + 1.0})
	_check(GameState.is_objective_done(RegionRegistry.VALE, &"res_copper"), "pesquisa: coletar cobre conclui o objetivo")
	GameState.collect_drops(Vector2.ZERO, {&"diamond": 3.0})
	var rep2: Dictionary = GameState.end_expedition(false)
	# 0.19: vencido o guardião, a expedição termina refazendo a região (o progresso zera).
	_check(bool(rep2.get("reset", false)) and GameState.region_depth(RegionRegistry.VALE) == 0, "vencer o guardião refaz o Vale ao fim da expedição")
	vale_progress = 0
	_check(GameState.is_objective_done(RegionRegistry.VALE, &"guardian"), "estrela: guardião vencido com mais da metade do casco")
	_check(GameState.is_objective_done(RegionRegistry.VALE, &"haul") == (int(rep2.value_kept) >= int(RegionRegistry.objective(vale_def, &"haul").target)), "estrela: carga grande")
	_check(GameState.stars(RegionRegistry.VALE) >= 1 and GameState.region_completion(RegionRegistry.VALE) > 0.3, "estrelas e conclusão da região")
	# Nova área (0.12): mapa novo, escavação e recorde apagados, progresso mantido.
	var seed_before: int = GameState.region_seed(RegionRegistry.VALE)
	GameState.world_mods[RegionRegistry.VALE] = {"1": "AAAA"}
	GameState.region_progress[RegionRegistry.VALE] = 99
	GameState.new_area(RegionRegistry.VALE)
	_check(GameState.region_seed(RegionRegistry.VALE) != seed_before and not GameState.world_mods.has(RegionRegistry.VALE)
			and GameState.region_depth(RegionRegistry.VALE) == 0 and GameState.done.has(RegionRegistry.VALE), "nova área: mapa novo, progresso da região mantido")
	var mods := {"3": {"17": 0, "4000": 9}}
	var round_trip: Dictionary = GameState.decode_mods(GameState.encode_mods(mods))
	_check(int(round_trip["3"]["17"]) == 0 and int(round_trip["3"]["4000"]) == 9, "escavação salva codifica e decodifica")
	# Migração de salvamento anterior à 0.9 (sem "unlocked"): regra antiga por profundidade.
	var old_prof: Dictionary = {"schema": SaveFile.SCHEMA_VERSION, "economy": Economy.new().to_dict(), "region": "dunas", "regions": {"vale": 120}}
	GameState.apply_profile(old_prof)
	_check(GameState.is_region_unlocked(RegionRegistry.DUNAS) and GameState.region_id == RegionRegistry.DUNAS, "salvamento antigo mantém regiões liberadas")
	# App fechado no meio da expedição: conta como resgate.
	var mid: Dictionary = {"schema": SaveFile.SCHEMA_VERSION, "economy": {"cargo": {"gold": 10}}, "region": "vale", "regions": {},
			"unlocked": ["vale"], "expedition": {"active": true, "region": "vale", "start_cargo": {"gold": 4}}}
	GameState.apply_profile(mid)
	_check(int(GameState.economy.cargo.get(&"gold", 0)) == 7 and not GameState.expedition_active and GameState.pending_notice != "",
			"expedição interrompida: resgate (perde metade do ganho)")
	GameState.apply_profile(JSON.parse_string(JSON.stringify(prof_before_rules)))

	# Perfil salvo e restaurado (progresso por região e região atual).
	var prof: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_profile()))
	_check(SaveFile.is_valid(prof), "perfil válido")
	GameState.reset_profile()
	GameState.apply_profile(prof)
	_check(GameState.region_id == RegionRegistry.DUNAS and GameState.region_depth(RegionRegistry.VALE) == vale_progress,
			"perfil restaura região e progresso")

	# Vitória (0.19): "ele retornará", próxima região e a região refeita.
	GameState.region_id = RegionRegistry.VALE
	main.call("_start_expedition", RegionRegistry.VALE, 0)
	await _frames(3)
	var variant_before: int = int(GameState.region_variant.get(RegionRegistry.VALE, 0))
	main.call("_on_guardian_defeated", 0.8)
	await _frames(2)
	var vic: Node = main.get_node_or_null("Victory")
	_check(vic != null and get_tree().paused, "vitória abre a tela e pausa o jogo")
	var vf: int = 0
	while vic != null and is_instance_valid(vic) and (vic.find_child("NextRegionButton", true, false) as Button).disabled and vf < 600:
		await _frames(1)
		vf += 1
	_check(String(vic.find_child("VictoryOmen", true, false).text).contains("retornar"), "aparece \"...mas ele retornará\"")
	(vic.find_child("NextRegionButton", true, false) as Button).pressed.emit()
	var vrep: ExpeditionReport = main.get("report")
	var rf: int = 0
	while not vrep.is_open() and rf < 600:
		await _frames(1)
		rf += 1
	_check(vrep.is_open(), "depois da escolha: extração e relatório")
	_check(int(GameState.region_variant.get(RegionRegistry.VALE, 0)) == variant_before + 1 and not GameState.world_mods.has(RegionRegistry.VALE), "a região do guardião foi refeita")
	(vrep.find_child("BaseButton", true, false) as Button).pressed.emit()
	await _frames(3)
	_check(world_map.is_open() and world_map.current_region().id == RegionRegistry.DUNAS, "PRÓXIMA REGIÃO abre o mapa nas Dunas")
	world_map.close()

	print("")
	print("%d verificações, %d falhas" % [_checks, _fail])
	main.queue_free()
	await _frames(2)
	get_tree().quit(1 if _fail > 0 else 0)
