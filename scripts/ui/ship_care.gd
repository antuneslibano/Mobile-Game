class_name ShipCare
extends Control
## Cuidar da nave (0.19): a nave grande, com manchas de sujeira, ferrugem e amassados
## proporcionais ao desgaste (GameState.wear). Com a ferramenta escolhida, arrastar o dedo
## por cima remove as manchas daquele tipo (espuma, poeira laranja ou faíscas, com som).
## Ao limpar tudo de um tipo, um brilho passa pela nave.
##
## Cada tipo é uma máscara em meio-pixel de arte (2×2 por pixel da nave): o nível atual é
## nível_inicial × (pixels restantes / pixels iniciais). Ao reabrir, a máscara é gerada de
## novo a partir do nível salvo (as manchas que sobram são as "mais profundas" do ruído).

signal changed(kind: StringName, level: float)
signal cleaned(kind: StringName)

const SUB: int = 2                      ## Meio-pixel de arte por pixel da máscara.
const BRUSH: float = 4.2                ## Raio do pincel em pixels da máscara.
const FINISH_AT: float = 0.03           ## Abaixo disso, o resto sai sozinho.
const COLORS: Dictionary = {
	&"dirt": [Color("5e3f22"), Color("7a5530"), Color("3e2814")],
	&"rust": [Color("a2501e"), Color("c8682a"), Color("6e3412")],
	&"dents": [Color("23262e"), Color("3a3f4a"), Color("8a94a4")],
}

var tool: StringName = &"dirt"
var look: Dictionary = {}
var _ship: Image
var _ship_tex: ImageTexture
var _mw: int = 0
var _mh: int = 0
var _mask: Dictionary = {}       ## tipo → PackedByteArray (1 = mancha)
var _initial: Dictionary = {}    ## tipo → pixels no início
var _remaining: Dictionary = {}  ## tipo → pixels restantes
var _level0: Dictionary = {}     ## tipo → nível quando a máscara foi gerada
var _img: Dictionary = {}        ## tipo → Image
var _tex: Dictionary = {}        ## tipo → ImageTexture
var _parts: Array[Dictionary] = []
var _shine: float = -1.0
var _pressed: bool = false
var _last_p: Vector2 = Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 380)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _enter_tree() -> void:
	TouchScroll.no_scroll.append(self)


func _exit_tree() -> void:
	TouchScroll.no_scroll.erase(self)


## Gera as máscaras a partir do desgaste salvo e do visual atual da nave.
func reload(wear: Dictionary, p_look: Dictionary) -> void:
	look = p_look
	_ship = ShipArt.build(0, look)
	_ship_tex = ImageTexture.create_from_image(_ship)
	_mw = _ship.get_width() * SUB
	_mh = _ship.get_height() * SUB
	for k in WearRules.KINDS:
		_level0[k] = float(wear.get(k, 0.0))
		_build_mask(k, float(_level0[k]))
	_parts.clear()
	queue_redraw()


func level(kind: StringName) -> float:
	var init: int = int(_initial.get(kind, 0))
	if init <= 0:
		return 0.0
	return float(_level0[kind]) * float(_remaining[kind]) / float(init)


func _inside(mx: int, my: int) -> bool:
	return _ship.get_pixel(mx / SUB, my / SUB).a > 0.5


func _build_mask(kind: StringName, lvl: float) -> void:
	var m := PackedByteArray()
	m.resize(_mw * _mh)
	var img := Image.create(_mw, _mh, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var n := FastNoiseLite.new()
	n.seed = int(hash(String(kind))) & 0xffff
	n.frequency = 0.16 if kind == &"dirt" else 0.09
	var count: int = 0
	if lvl > 0.0:
		if kind == &"dents":
			# Amassados: riscos curtos espalhados pelo casco (mais com mais dano).
			var segs: int = ceili(lvl * 12.0)
			var tries: int = 0
			while segs > 0 and tries < 400:
				tries += 1
				var x: int = rng.randi_range(0, _mw - 1)
				var y: int = rng.randi_range(0, _mh - 1)
				if not _inside(x, y):
					continue
				var dir := Vector2.from_angle(rng.randf() * TAU)
				var length: int = rng.randi_range(4, 9)
				for i in length:
					var p := Vector2(x, y) + dir * i
					var px: int = int(p.x)
					var py: int = int(p.y)
					if px >= 0 and py >= 0 and px < _mw and py < _mh and _inside(px, py) and m[py * _mw + px] == 0:
						m[py * _mw + px] = 1
						count += 1
				segs -= 1
		else:
			# Sujeira e ferrugem: as regiões de menor ruído, cobrindo ~nível da nave.
			var vals: Array[float] = []
			var cells: Array[int] = []
			for y in _mh:
				for x in _mw:
					if not _inside(x, y):
						continue
					var v: float = n.get_noise_2d(x, y)
					if kind == &"rust":
						v -= float(y) / _mh * 0.5  # ferrugem gosta da parte de baixo
					vals.append(v)
					cells.append(y * _mw + x)
			var order: Array = range(vals.size())
			order.sort_custom(func(a: int, b: int) -> bool: return vals[a] < vals[b])
			# Cobertura máxima ~55% (sujeira) / ~40% (ferrugem): a nave continua reconhecível.
			var cover: float = 0.55 if kind == &"dirt" else 0.4
			var take: int = int(order.size() * clampf(lvl, 0.0, 1.0) * cover)
			for i in take:
				m[cells[order[i]]] = 1
				count += 1
	var cols: Array = COLORS[kind]
	for y in _mh:
		for x in _mw:
			if m[y * _mw + x] == 1:
				var r: float = rng.randf()
				var col: Color = cols[0] if r < 0.6 else (cols[1] if r < 0.85 else cols[2])
				if kind == &"dirt":
					col.a = 0.82
				img.set_pixel(x, y, col)
	_mask[kind] = m
	_initial[kind] = count
	_remaining[kind] = count
	_img[kind] = img
	_tex[kind] = ImageTexture.create_from_image(img)


## Retângulo da nave na tela do controle (escala inteira, centralizada).
func ship_rect() -> Rect2:
	if _ship == null:
		return Rect2()
	var k: float = floorf(minf(size.x / _ship.get_width(), size.y / _ship.get_height()))
	k = maxf(k, 1.0)
	var s := Vector2(_ship.get_width(), _ship.get_height()) * k
	return Rect2((size - s) * 0.5, s)


func _gui_input(event: InputEvent) -> void:
	var p: Vector2 = Vector2.INF
	var down: bool = _pressed
	if event is InputEventScreenTouch:
		down = (event as InputEventScreenTouch).pressed
		p = (event as InputEventScreenTouch).position
	elif event is InputEventScreenDrag:
		p = (event as InputEventScreenDrag).position
		down = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		down = (event as InputEventMouseButton).pressed
		p = (event as InputEventMouseButton).position
	elif event is InputEventMouseMotion and _pressed:
		p = (event as InputEventMouseMotion).position
	if p == Vector2.INF:
		return
	if down and _pressed:
		# Varre o caminho entre os dois pontos (dedo rápido não pula manchas).
		var steps: int = maxi(1, int(_last_p.distance_to(p) / 6.0))
		for i in steps:
			scrub(_last_p.lerp(p, float(i + 1) / steps))
	elif down:
		scrub(p)
	_pressed = down
	_last_p = p
	accept_event()


## Esfrega no ponto (coordenadas locais do controle). Retorna quantos pixels saíram.
func scrub(local: Vector2) -> int:
	var r: Rect2 = ship_rect()
	if r.size.x <= 0.0 or not _mask.has(tool):
		return 0
	var k: float = r.size.x / _mw
	var c: Vector2 = (local - r.position) / k
	var m: PackedByteArray = _mask[tool]
	var img: Image = _img[tool]
	var removed: int = 0
	var rr: int = ceili(BRUSH)
	for dy in range(-rr, rr + 1):
		for dx in range(-rr, rr + 1):
			if dx * dx + dy * dy > BRUSH * BRUSH:
				continue
			var x: int = int(c.x) + dx
			var y: int = int(c.y) + dy
			if x < 0 or y < 0 or x >= _mw or y >= _mh or m[y * _mw + x] == 0:
				continue
			m[y * _mw + x] = 0
			img.set_pixel(x, y, Color(0, 0, 0, 0))
			removed += 1
			if randf() < 0.35:
				_spawn_part(r.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * k)
	if removed == 0:
		return 0
	_remaining[tool] = int(_remaining[tool]) - removed
	if float(_remaining[tool]) <= float(_initial[tool]) * FINISH_AT:
		_clear_all(tool)
	(_tex[tool] as ImageTexture).update(img)
	_sound()
	changed.emit(tool, level(tool))
	queue_redraw()
	return removed


func _clear_all(kind: StringName) -> void:
	var m: PackedByteArray = _mask[kind]
	m.fill(0)
	(_img[kind] as Image).fill(Color(0, 0, 0, 0))
	_remaining[kind] = 0
	_shine = 0.0
	Sfx.play(&"chest", 1.4, -4.0)
	cleaned.emit(kind)


func _sound() -> void:
	match tool:
		&"dirt":
			Sfx.play(&"scrub", randf_range(0.9, 1.2), -8.0, 0.09)
		&"rust":
			Sfx.play(&"sand", randf_range(0.9, 1.15), -8.0, 0.08)
		&"dents":
			Sfx.play(&"weld", randf_range(0.9, 1.1), -9.0, 0.07)


func _spawn_part(p: Vector2) -> void:
	if _parts.size() > 160:
		return
	var v: Vector2
	match tool:
		&"dirt":
			v = Vector2(randf_range(-30, 30), randf_range(-90, -40))   # bolhas sobem
		&"rust":
			v = Vector2(randf_range(-60, 60), randf_range(20, 90))     # poeira cai
		_:
			v = Vector2.from_angle(randf() * TAU) * randf_range(80, 220)  # faíscas
	_parts.append({"p": p, "v": v, "t": 0.0, "life": randf_range(0.35, 0.8)})


func _process(delta: float) -> void:
	if _parts.is_empty() and _shine < 0.0:
		return
	var i: int = 0
	while i < _parts.size():
		var q: Dictionary = _parts[i]
		q.t = float(q.t) + delta
		q.p = (q.p as Vector2) + (q.v as Vector2) * delta
		if tool == &"dents":
			q.v = (q.v as Vector2) + Vector2(0, 400) * delta
		if float(q.t) >= float(q.life):
			_parts.remove_at(i)
		else:
			i += 1
	if _shine >= 0.0:
		_shine += delta
		if _shine > 0.8:
			_shine = -1.0
	queue_redraw()


func _draw() -> void:
	var r: Rect2 = ship_rect()
	if r.size.x <= 0.0:
		return
	# Sombra no chão e a nave.
	draw_rect(Rect2(r.position + Vector2(r.size.x * 0.1, r.size.y * 0.92), Vector2(r.size.x * 0.8, r.size.y * 0.1)), Color(0, 0, 0, 0.35))
	draw_texture_rect(_ship_tex, r, false)
	# Ordem física: amassados no metal, ferrugem por cima, sujeira por último.
	for k: StringName in [&"dents", &"rust", &"dirt"]:
		if _tex.has(k):
			draw_texture_rect(_tex[k], r, false)
	# Brilho atravessando a nave ao terminar um tipo.
	if _shine >= 0.0:
		var x: float = r.position.x - 120.0 + (r.size.x + 240.0) * (_shine / 0.8)
		var pts := PackedVector2Array([Vector2(x, r.position.y), Vector2(x + 50, r.position.y), Vector2(x - 10, r.end.y), Vector2(x - 60, r.end.y)])
		draw_colored_polygon(pts, Color(1, 1, 1, 0.35 * (1.0 - _shine / 0.8)))
	for q in _parts:
		var a: float = 1.0 - float(q.t) / float(q.life)
		var p: Vector2 = q.p
		match tool:
			&"dirt":
				draw_arc(p, 5.0 + 6.0 * float(q.t), 0.0, TAU, 12, Color(0.85, 0.95, 1.0, 0.8 * a), 2.0)
			&"rust":
				draw_rect(Rect2(p, Vector2(5, 5)), Color(0.85, 0.45, 0.15, a))
			_:
				draw_rect(Rect2(p, Vector2(4, 4)), Color(1.0, 0.9, 0.4, a))
