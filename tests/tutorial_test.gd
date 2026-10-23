extends Node
## Teste do tutorial jogável (0.18): perfil novo abre o tutorial, cada passo aponta para
## um alvo que existe na tela e avança quando a ação acontece, até EXPLORAR. Depois testa
## o "pular" com confirmação (cancelar e confirmar).
##   godot --headless --path . --fixed-fps 60 res://tests/tutorial_test.tscn

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


func _press(root: Node, node_name: String, child: String = "") -> bool:
	var n: Node = root.find_child(node_name, true, false)
	if n != null and child != "":
		n = n.find_child(child, true, false)
	if not n is BaseButton or (n as BaseButton).disabled:
		return false
	(n as BaseButton).pressed.emit()
	return true


## Captura de tela (só com TUT_SHOTS=pasta e renderização de verdade, para conferir o visual).
func _shot(name: String) -> void:
	var dir: String = OS.get_environment("TUT_SHOTS")
	if dir == "":
		return
	await _frames(20)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])


## Espera o tutorial chegar ao passo `i` (até `limit` quadros).
func _wait_step(t: Tutorial, i: int, limit: int = 400) -> bool:
	var f: int = 0
	while is_instance_valid(t) and t.step < i and f < limit:
		await _frames(1)
		f += 1
	return not is_instance_valid(t) or t.step >= i


func _open_main() -> Node:
	SaveService.enabled = false
	GameState.reset_profile()
	Tutorial.enabled = true
	Transitions.shutter_enabled = false
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var waited: int = 0
	while main.get_node_or_null("Splash") != null and waited < 600:
		await _frames(1)
		waited += 1
	await _frames(3)
	return main


func _target_ok(t: Tutorial) -> bool:
	var s: Dictionary = t._steps[t.step]
	return not s.has("target") or t._target_rect(s).size.x > 0.0


func _run() -> void:
	print("== tutorial_test")
	var main: Node = await _open_main()
	var t: Tutorial = main.get_node_or_null("Tutorial")
	var base: BaseScreen = main.get("base")
	var game: Game = main.get("game")
	var hud: Hud = main.get("hud")
	_check(t != null and not base.is_open() and GameState.expedition_active, "perfil novo começa no tutorial, já na expedição")
	_check(not GameState.tutorial_done, "tutorial ainda não concluído")
	var ext: Button = hud.find_child("ExtractButton", true, false)
	_check(ext.disabled, "EXTRAIR travado até o passo dele")
	_check(t.find_child("TutorialText", true, false).text.contains("Bem-vindo"), "começa pela boas-vindas")
	_check(_press(t, "TutorialOk"), "ENTENDI avança")
	await _wait_step(t, 1)
	# 1: cavar.
	await _shot("01_cavar")
	_check(_target_ok(t), "passo cavar aponta para o controle")
	var drill: Drill = game.drill
	drill.position = Vector2(drill.position.x, 7.5 * Balance.BLOCK_PX)
	_check(await _wait_step(t, 2), "descer 5 m conclui o passo de cavar")
	# 2: cobre plantado.
	await _shot("02_minerio")
	_check(_target_ok(t), "passo do minério aponta para o cobre plantado")
	GameState.collect_drops(drill.position, {&"copper": 2.0})
	_check(await _wait_step(t, 3), "coletar minério conclui o passo")
	# 3: carvão.
	await _shot("03_carvao")
	_check(_target_ok(t), "passo do combustível aponta para o carvão")
	drill.refueled.emit(5.0)
	_check(await _wait_step(t, 4), "reabastecer com carvão conclui o passo")
	# 4: Sobrecarga (o tutorial enche a energia).
	await _frames(2)
	await _shot("04_sobrecarga")
	_check(drill.energy.is_ready() and _target_ok(t), "energia cheia e botão de Sobrecarga apontado")
	drill.energy.step(0.016, drill.stats, true)
	_check(await _wait_step(t, 5), "usar a Sobrecarga conclui o passo")
	# 5: sonar.
	_check(_target_ok(t), "botão do sonar apontado")
	game.sonar.ping()
	_check(await _wait_step(t, 6), "usar o sonar conclui o passo")
	# 6: calor (só leitura).
	await _shot("06_calor")
	_check(_target_ok(t) and _press(t, "TutorialOk"), "passo do calor aponta o termômetro e tem ENTENDI")
	await _wait_step(t, 7)
	# 7: extrair.
	await _frames(2)
	await _shot("07_extrair")
	_check(not ext.disabled and _press(hud, "ExtractButton"), "EXTRAIR liberado no passo dele")
	_check(await _wait_step(t, 8, 600), "extração abre o resumo")
	_check(_target_ok(t) and _press(main.get("report"), "BaseButton"), "resumo: botão BASE apontado e tocado")
	_check(await _wait_step(t, 9), "chega na base")
	# 9..16: base.
	for e: Array in [["Station_market", ""], ["SellSurplusButton", ""], ["CloseButton", ""], ["Station_bench", ""],
			["Card_damage", "Buy"], ["CloseButton", ""], ["Station_map", ""], ["ExploreButton", ""]]:
		var i: int = t.step
		await _frames(2)
		await _shot("%02d_%s" % [i, e[0]])
		var ok_target: bool = _target_ok(t)
		var where: Node = main
		var pressed: bool = _press(where, e[0], e[1])
		await _wait_step(t, i + 1)
		_check(ok_target and pressed and (not is_instance_valid(t) or t.step > i), "passo %d: %s%s apontado e concluído" % [i, e[0], "/" + e[1] if e[1] != "" else ""])
	await _frames(3)
	_check(not is_instance_valid(t) and main.get_node_or_null("Tutorial") == null, "tutorial termina depois de EXPLORAR")
	_check(GameState.tutorial_done and GameState.economy.get_level(&"damage") >= 1 and GameState.expedition_active, "jogo liberado: melhoria construída e nova expedição")
	main.queue_free()
	await _frames(3)

	# Pular, com confirmação.
	main = await _open_main()
	t = main.get_node_or_null("Tutorial")
	_check(_press(t, "TutorialSkip") and t.find_child("SkipConfirm", true, false) != null, "PULAR pede confirmação")
	await _shot("99_pular")
	_check(_press(t, "SkipCancel"), "dá para desistir de pular")
	await _frames(2)
	_check(is_instance_valid(t) and t.find_child("SkipConfirm", true, false) == null and not GameState.tutorial_done, "cancelar mantém o tutorial")
	_press(t, "TutorialSkip")
	await _frames(1)
	_check(_press(t, "SkipConfirmYes"), "confirmar pulo")
	await _frames(3)
	_check(not is_instance_valid(t) and GameState.tutorial_done, "pular encerra e libera o jogo")
	_check(not (main.get("hud").find_child("ExtractButton", true, false) as Button).disabled, "EXTRAIR volta a funcionar depois de pular")
	main.queue_free()
	await _frames(2)

	print("")
	print("%d verificações, %d falhas" % [_checks, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
