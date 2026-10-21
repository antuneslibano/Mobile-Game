class_name InputController
extends Node
## Converte toque (multitoque), mouse (emulado como toque) e teclado em DrillIntent.

## Interface mínima esperada do HUD (duck typing evitado: tipado como Hud).
var hud: Hud
var drill: Drill
## Quando definido (bot de teste), substitui a entrada do jogador.
var override_intent: DrillIntent = null

var _intent := DrillIntent.new()
var _touches: Dictionary = {}   ## índice → { "kind": StringName, "pos": Vector2 }


func _ready() -> void:
	# A garagem pausa o jogo: toques soltos durante a pausa não chegariam aqui.
	EventBus.garage_opened.connect(func() -> void: _touches.clear())


func get_intent() -> DrillIntent:
	return override_intent if override_intent != null else _intent


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_touches.clear()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if hud != null and hud.is_point_blocking(t.position):
				return
			var kind: StringName = hud.pad_action_at(t.position) if hud != null else &""
			_touches[t.index] = {"kind": kind if kind != &"" else &"steer", "pos": t.position}
			get_viewport().set_input_as_handled()
		elif _touches.has(t.index):
			_touches.erase(t.index)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _touches.has(d.index):
			var entry: Dictionary = _touches[d.index]
			entry["pos"] = d.position
			if entry["kind"] != &"steer" and hud != null:
				# Deslizar entre botões inferiores troca a ação (ex.: ◀ → ▶).
				var kind: StringName = hud.pad_action_at(d.position)
				if kind != &"":
					entry["kind"] = kind
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_intent.clear()
	var drill_screen_x: float = drill.get_global_transform_with_canvas().origin.x if drill != null else 0.0
	var pressed: Dictionary = {}
	for index: int in _touches:
		var entry: Dictionary = _touches[index]
		var kind: StringName = entry["kind"]
		pressed[kind] = true
		match kind:
			&"left":
				_intent.move -= 1.0
			&"right":
				_intent.move += 1.0
			&"drill":
				_intent.drill = true
			&"boost":
				_intent.boost = true
			&"steer":
				_intent.drill = true
				var pos: Vector2 = entry["pos"]
				var dx: float = pos.x - drill_screen_x
				var dz: float = Balance.STEER_DEADZONE_PX
				if absf(dx) > dz:
					_intent.move += signf(dx) * clampf((absf(dx) - dz) / 80.0 + 0.4, 0.4, 1.0)
	# Teclado (desktop).
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		_intent.move -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		_intent.move += 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_SPACE):
		_intent.drill = true
	if Input.is_key_pressed(KEY_SHIFT):
		_intent.boost = true
	_intent.move = clampf(_intent.move, -1.0, 1.0)
	if hud != null:
		hud.set_pad_pressed(pressed)


func active_touch_count() -> int:
	return _touches.size()
