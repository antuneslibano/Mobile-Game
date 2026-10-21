class_name Background
extends Node2D
## Céu, horizonte e base de superfície. Desenhado uma vez (estático).

const SKY_TOP := Color("1b1530")
const SKY_BOTTOM := Color("d9774a")
const HILLS_FAR := Color("3a2440")
const HILLS_NEAR := Color("2a1a2c")
const ROCK_OUTSIDE := Color("120e14")

var _seed: int = 0
var _sky_top: Color = SKY_TOP
var _sky_bottom: Color = SKY_BOTTOM
var _hill_far: Color = HILLS_FAR
var _hill_near: Color = HILLS_NEAR


## Cores do céu e das colinas vêm da região explorada.
func setup(p_seed: int, region: RegionDef = null) -> void:
	_seed = p_seed
	if region != null:
		_sky_top = region.sky_top
		_sky_bottom = region.sky_bottom
		_hill_far = region.hill_far
		_hill_near = region.hill_near
	queue_redraw()


func _draw() -> void:
	var b: float = float(Balance.BLOCK_PX)
	var w: float = Balance.WORLD_WIDTH * b
	var margin: float = 1200.0
	var sky_h: float = (Balance.SKY_ROWS_VISIBLE + 20) * b
	# Céu em degradê.
	var left: float = -margin
	var right: float = w + margin
	draw_polygon(PackedVector2Array([Vector2(left, -sky_h), Vector2(right, -sky_h), Vector2(right, 0), Vector2(left, 0)]),
			PackedColorArray([_sky_top, _sky_top, _sky_bottom, _sky_bottom]))
	# Sol industrial baixo.
	draw_circle(Vector2(w * 0.72, -2.2 * b), 1.4 * b, Color("ffb46b", 0.35))
	draw_circle(Vector2(w * 0.72, -2.2 * b), 0.9 * b, Color("ffd59a", 0.8))
	# Colinas (silhuetas por hash, determinísticas).
	_hills(left, right, 3.6 * b, 1.6 * b, _hill_far, 61)
	_hills(left, right, 1.6 * b, 0.9 * b, _hill_near, 97)
	# Rocha fora do mundo jogável (telas muito largas).
	draw_rect(Rect2(left, 0, margin, Balance.MAX_DEPTH_ROWS * b + 2000), ROCK_OUTSIDE)
	draw_rect(Rect2(w, 0, margin, Balance.MAX_DEPTH_ROWS * b + 2000), ROCK_OUTSIDE)
	_base_station(b)


func _hills(left: float, right: float, height: float, var_h: float, color: Color, salt: int) -> void:
	var pts := PackedVector2Array()
	pts.append(Vector2(left, 0))
	var step: float = 24.0
	var x: float = left
	var i: int = 0
	while x <= right:
		var n: float = WorldGenerator.hash01(i >> 2, 0, _seed + salt)
		var n2: float = WorldGenerator.hash01((i >> 2) + 1, 0, _seed + salt)
		var f: float = float(i % 4) / 4.0
		var h: float = height + lerpf(n, n2, smoothstep(0.0, 1.0, f)) * var_h
		pts.append(Vector2(x, -h))
		x += step
		i += 1
	pts.append(Vector2(right, 0))
	draw_colored_polygon(pts, color)


## Base de superfície (futura entrada da garagem), à esquerda do ponto de partida.
func _base_station(b: float) -> void:
	var x0: float = 2.0 * b
	var ground: float = 0.0
	var steel := Color("3a3f47")
	var steel_l := Color("6e7a86")
	var yellow := Color("f2b33d")
	# Galpão.
	draw_rect(Rect2(x0, ground - 2.6 * b, 5.0 * b, 2.6 * b), steel)
	draw_rect(Rect2(x0, ground - 2.6 * b, 5.0 * b, 6), steel_l)
	for i in 6:
		draw_rect(Rect2(x0 + 8 + i * 0.8 * b, ground - 2.4 * b, 3, 2.4 * b), Color(0, 0, 0, 0.25))
	# Portão.
	draw_rect(Rect2(x0 + 1.4 * b, ground - 1.7 * b, 2.2 * b, 1.7 * b), Color("1d2026"))
	for i in 5:
		draw_rect(Rect2(x0 + 1.4 * b, ground - 1.7 * b + i * 0.34 * b, 2.2 * b, 3), steel_l.darkened(0.3))
	# Faixa de advertência.
	for i in 10:
		var c: Color = yellow if i % 2 == 0 else Color("2a2026")
		draw_rect(Rect2(x0 + i * 0.5 * b, ground - 2.9 * b, 0.5 * b, 0.3 * b), c)
	# Luz azul de sinalização.
	draw_circle(Vector2(x0 + 4.6 * b, ground - 3.15 * b), 10.0, Color(0.31, 0.76, 1.0, 0.25))
	draw_circle(Vector2(x0 + 4.6 * b, ground - 3.15 * b), 4.0, Color("4fc3ff"))
	# Torre de perfuração sobre o poço inicial.
	var cx: float = (float(Balance.WORLD_WIDTH >> 1) + 0.5) * b
	var top: float = ground - 4.2 * b
	draw_line(Vector2(cx - 1.4 * b, ground), Vector2(cx - 0.2 * b, top), steel_l, 5.0)
	draw_line(Vector2(cx + 1.4 * b, ground), Vector2(cx + 0.2 * b, top), steel_l, 5.0)
	for k in 4:
		var t: float = float(k + 1) / 5.0
		var y: float = lerpf(ground, top, t)
		var hw: float = lerpf(1.4 * b, 0.2 * b, t)
		draw_line(Vector2(cx - hw, y), Vector2(cx + hw, y - 0.3 * b), steel, 3.0)
	draw_rect(Rect2(cx - 0.35 * b, top - 10, 0.7 * b, 12), yellow)
