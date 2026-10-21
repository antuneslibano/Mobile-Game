class_name PickupFx
extends Node2D
## Textos flutuantes de coleta ("+2 Cobre"), desenhados em um único nó com pool limitado.

const LIFE: float = 1.1
const RISE_PX: float = 70.0
const FONT_SIZE: int = 24
const LINE_PX: float = 26.0
## Ganhos do mesmo recurso dentro desta janela somam no mesmo texto (sem amontoar).
const MERGE_SEC: float = 0.5

var _items: Array[Dictionary] = []


func _ready() -> void:
	set_process(false)


func show_gain(origin: Vector2, gained: Dictionary) -> void:
	for key: StringName in gained:
		var def: ResourceDef = ResourceRegistry.get_def(key)
		if def == null:
			continue
		var merged: bool = false
		for it in _items:
			if it["key"] == key and float(it["t"]) < MERGE_SEC:
				it["amount"] = int(it["amount"]) + int(gained[key])
				it["text"] = "+%d %s" % [int(it["amount"]), def.display_name]
				it["t"] = 0.0
				merged = true
				break
		if merged:
			continue
		var line: int = 0
		for it in _items:
			if float(it["t"]) < 0.3:
				line += 1
		_items.append({
			"key": key,
			"amount": int(gained[key]),
			"pos": origin + Vector2(0.0, -LINE_PX * line),
			"t": 0.0,
			"text": "+%d %s" % [int(gained[key]), def.display_name],
			"color": def.color,
		})
	while _items.size() > Balance.PICKUP_TEXT_MAX:
		_items.pop_front()
	set_process(not _items.is_empty())
	queue_redraw()


func active_count() -> int:
	return _items.size()


func _process(delta: float) -> void:
	var i: int = 0
	while i < _items.size():
		var it: Dictionary = _items[i]
		it["t"] = float(it["t"]) + delta
		if float(it["t"]) >= LIFE:
			_items.remove_at(i)
			continue
		i += 1
	if _items.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for it in _items:
		var t: float = float(it["t"]) / LIFE
		var text: String = it["text"]
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var p: Vector2 = (it["pos"] as Vector2) + Vector2(-w * 0.5, -RISE_PX * ease(t, 0.5))
		var a: float = clampf((1.0 - t) * 3.0, 0.0, 1.0)
		var c: Color = it["color"]
		draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 6, Color(0, 0, 0, 0.85 * a))
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(c.lightened(0.25), a))
