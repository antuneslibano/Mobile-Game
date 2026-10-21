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


func _drag(index: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	get_viewport().push_input(ev, true)


func _run() -> void:
	print("== scene_test")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(10)
	var game: Game = main.get_node("Game")
	var hud: Hud = main.get_node("Hud")
	var input: InputController = game.input
	var destroyed: Array[int] = [0]
	var drops_ok: Array[bool] = [true]
	EventBus.block_destroyed.connect(func(_c: Vector2i, id: int, drops: Dictionary) -> void:
		destroyed[0] += 1
		if drops != BlockRegistry.get_def(id).drops:
			drops_ok[0] = false)


	_check(game.world != null, "mundo criado")
	_check(game.terrain.active_count() > 0, "chunks renderizados (%d)" % game.terrain.active_count())
	var dig: Rect2 = hud.dig_area()
	_check(dig.size.y > 600.0, "área de escavação ampla (%.0f px)" % dig.size.y)

	var dx: float = game.drill.get_global_transform_with_canvas().origin.x
	var y: float = dig.get_center().y
	_touch(0, Vector2(dx, y), true)
	await _frames(2)
	var it: DrillIntent = input.get_intent()
	_check(it.drill and absf(it.move) < 0.01, "toque alinhado: perfura para baixo")
	_drag(0, Vector2(dx + 250.0, y))
	await _frames(2)
	_check(it.drill and it.move > 0.3, "arrastar à direita: move à direita (%.2f)" % it.move)
	_drag(0, Vector2(dx - 250.0, y))
	await _frames(2)
	_check(it.move < -0.3, "arrastar à esquerda: move à esquerda (%.2f)" % it.move)
	_touch(0, Vector2(dx - 250.0, y), false)
	await _frames(2)
	_check(not it.drill and it.move == 0.0, "soltar: para")

	# Botões inferiores com multitoque.
	var left_pad: Control = hud.find_child("Pad_left", true, false)
	var drill_pad: Control = hud.find_child("Pad_drill", true, false)
	var right_pad: Control = hud.find_child("Pad_right", true, false)
	_touch(1, left_pad.get_global_rect().get_center(), true)
	await _frames(2)
	_check(it.move < -0.99 and not it.drill, "botão ◀ move sem perfurar")
	_touch(2, drill_pad.get_global_rect().get_center(), true)
	await _frames(2)
	_check(it.move < -0.99 and it.drill, "multitoque ◀ + PERFURAR")
	_check((left_pad as PadButton).pressed and (drill_pad as PadButton).pressed, "botões mostram estado pressionado")
	_drag(1, right_pad.get_global_rect().get_center())
	await _frames(2)
	_check(it.move > 0.99, "deslizar de ◀ para ▶ troca a direção")
	_touch(1, right_pad.get_global_rect().get_center(), false)
	_touch(2, drill_pad.get_global_rect().get_center(), false)
	await _frames(2)
	_check(not it.drill and it.move == 0.0, "soltar botões: para")

	# Barra superior não aciona perfuração.
	_touch(3, Vector2(100, 60), true)
	await _frames(2)
	_check(not it.drill, "toque na barra superior é ignorado")
	_touch(3, Vector2(100, 60), false)

	# Sessão curta segurando o dedo: precisa descer e coletar.
	dx = game.drill.get_global_transform_with_canvas().origin.x
	_touch(0, Vector2(dx, y), true)
	await _frames(600)
	_touch(0, Vector2(dx, y), false)
	await _frames(5)
	var max_depth: int = GameState.max_depth_m
	_check(max_depth >= 5, "desceu segurando o toque (%d m)" % max_depth)
	_check(destroyed[0] >= 5, "blocos destruídos via EventBus (%d)" % destroyed[0])
	_check(drops_ok[0], "drops emitidos conforme definição")
	_check(not game.drill.is_overlapping_solid(), "perfuradora fora de blocos sólidos")
	var cam_y: float = game.camera.get_screen_center_position().y
	_check(cam_y > 0.0 and absf(cam_y - game.drill.global_position.y) < 700.0, "câmera acompanha a profundidade")
	_check(hud.get_node("Root").find_child("*", true, false) != null, "HUD construído")

	print("")
	print("%d verificações, %d falhas" % [_checks, _fail])
	main.queue_free()
	await _frames(2)
	get_tree().quit(1 if _fail > 0 else 0)
