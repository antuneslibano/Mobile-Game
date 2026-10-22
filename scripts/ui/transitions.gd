class_name Transitions
extends RefCounted
## Transições de tela (0.14): animações curtas que funcionam com o jogo pausado.

## Tela inteira entrando: sobe um pouco e aparece (estações, mapa, relatório).
static func slide_in(root: Control, dur: float = 0.28) -> void:
	root.position.y = 90.0
	root.modulate.a = 0.0
	var tw: Tween = root.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel()
	tw.tween_property(root, "position:y", 0.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "modulate:a", 1.0, dur * 0.8)


## Só aparecer (troca de página, base).
static func fade_in(root: CanvasItem, dur: float = 0.25) -> void:
	root.modulate.a = 0.0
	root.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(root, "modulate:a", 1.0, dur)


## Cartão surgindo do centro com um leve "pulo".
static func pop_in(c: Control, dur: float = 0.24) -> void:
	c.modulate.a = 0.0
	c.scale = Vector2(0.85, 0.85)
	var tw: Tween = c.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_callback(func() -> void: c.pivot_offset = c.size * 0.5)
	tw.tween_property(c, "modulate:a", 1.0, dur * 0.7)
	tw.parallel().tween_property(c, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Toque num elemento: aperta e volta (feedback).
static func bump(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var tw: Tween = c.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(c, "scale", Vector2(0.92, 0.92), 0.06)
	tw.tween_property(c, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Porta de metal (0.15) -------------------------------------------------------------

## Desligada nos testes de cena que trocam de tela muitas vezes (a troca fica imediata).
static var shutter_enabled: bool = true
static var _door: ShutterDoor = null


## Troca de tela com a porta de metal: desce batendo nos trilhos, fecha com um "clank",
## on_closed troca a tela por trás dela, e ela sobe de novo. Sem porta: troca na hora.
static func shutter(tree: SceneTree, on_closed: Callable) -> void:
	if not shutter_enabled or tree == null or is_instance_valid(_door):
		on_closed.call()
		return
	_door = ShutterDoor.new()
	_door.on_closed = on_closed
	tree.root.add_child(_door)


static func shutter_busy() -> bool:
	return is_instance_valid(_door)
