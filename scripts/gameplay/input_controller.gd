class_name InputController
extends Node
## Converte toque (joystick flutuante + botão de impulso, multitoque), mouse (emulado como
## toque) e teclado em DrillIntent. A broca nunca sobe: empurrar para cima não faz nada.

var hud: Hud
var drill: Drill
## Quando definido (bot de teste), substitui a entrada do jogador.
var override_intent: DrillIntent = null

var _intent := DrillIntent.new()
var _touches: Dictionary = {}   ## índice → { "kind": StringName, "origin": Vector2, "pos": Vector2 }
var _stick_index: int = -1


func _ready() -> void:
	# A garagem pausa o jogo: toques soltos durante a pausa não chegariam aqui.
	EventBus.garage_opened.connect(func() -> void:
		_touches.clear()
		_stick_index = -1)


func get_intent() -> DrillIntent:
	return override_intent if override_intent != null else _intent


## Vetor do joystick (x direita, y para baixo, comprimento 0..1) → intenção.
## - zona morta: nada;
## - para baixo (dominante): perfura para baixo, sem mover;
## - lateral: move (analógico) e perfura de lado se houver parede;
## - para cima: nada — a broca não sobe.
static func joystick_to_intent(v: Vector2, out: DrillIntent) -> void:
	out.move = 0.0
	out.drill = false
	if v.length() < Balance.JOYSTICK_DEADZONE:
		return
	if v.y > 0.0 and v.y >= absf(v.x) * Balance.JOYSTICK_DOWN_BIAS:
		out.drill = true
		return
	var ax: float = absf(v.x)
	if ax >= Balance.JOYSTICK_SIDE_MIN:
		out.move = signf(v.x) * remap(clampf(ax, Balance.JOYSTICK_SIDE_MIN, 0.9), Balance.JOYSTICK_SIDE_MIN, 0.9, 0.45, 1.0)
		out.drill = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_touches.clear()
		_stick_index = -1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if hud != null and hud.is_point_blocking(t.position):
				return
			var kind: StringName = hud.pad_action_at(t.position) if hud != null else &""
			if kind == &"":
				if _stick_index >= 0:
					return  # já há um joystick ativo
				kind = &"stick"
				_stick_index = t.index
			_touches[t.index] = {"kind": kind, "origin": t.position, "pos": t.position}
			get_viewport().set_input_as_handled()
		elif _touches.has(t.index):
			_touches.erase(t.index)
			if t.index == _stick_index:
				_stick_index = -1
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _touches.has(d.index):
			(_touches[d.index] as Dictionary)["pos"] = d.position
			get_viewport().set_input_as_handled()


func stick_vector() -> Vector2:
	if _stick_index < 0 or not _touches.has(_stick_index):
		return Vector2.ZERO
	var e: Dictionary = _touches[_stick_index]
	var raw: Vector2 = ((e["pos"] as Vector2) - (e["origin"] as Vector2)) / Balance.JOYSTICK_RADIUS_PX
	return raw.limit_length(1.0)


func _process(_delta: float) -> void:
	var v: Vector2 = stick_vector()
	joystick_to_intent(v, _intent)
	_intent.boost = false
	var pressed: Dictionary = {}
	for index: int in _touches:
		var kind: StringName = (_touches[index] as Dictionary)["kind"]
		pressed[kind] = true
		if kind == &"boost":
			_intent.boost = true
	# Teclado (desktop): ←/→ movem (perfurando de lado contra paredes), ↓ perfura.
	var kx: float = 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		kx -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		kx += 1.0
	if kx != 0.0:
		_intent.move = kx
		_intent.drill = true
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_SPACE):
		_intent.drill = true
	if Input.is_key_pressed(KEY_SHIFT):
		_intent.boost = true
	if hud != null:
		hud.set_pad_pressed(pressed)
		if _stick_index >= 0 and _touches.has(_stick_index):
			var e: Dictionary = _touches[_stick_index]
			hud.show_joystick(e["origin"], e["origin"] + v * Balance.JOYSTICK_RADIUS_PX)
		else:
			hud.hide_joystick()


func active_touch_count() -> int:
	return _touches.size()
