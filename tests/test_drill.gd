extends "res://tests/test_case.gd"
## Simula a perfuradora sem cena: física em grade, perfuração e invariantes de colisão.

const DT: float = 1.0 / 60.0


func _model(p_seed: int) -> WorldModel:
	var w := WorldModel.new(p_seed)
	w.threaded = false
	return w


## Preenche um retângulo de células com um bloco.
func _fill(w: WorldModel, from: Vector2i, to: Vector2i, id: int) -> void:
	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			w.set_block(Vector2i(x, y), id)


func _new_drill(w: WorldModel, cell: Vector2i) -> Drill:
	var d := Drill.new()
	d.setup(w, cell, 7)
	return d


## Avança N passos verificando a invariante; retorna o número de violações.
func _run(d: Drill, intent: DrillIntent, seconds: float, dt: float = DT) -> int:
	var bad: int = 0
	var steps: int = int(seconds / dt)
	for i in steps:
		d.physics_step(dt, intent)
		if d.is_overlapping_solid():
			bad += 1
	return bad


func test_spawn_lands_on_surface() -> void:
	var w := _model(10)
	var d := _new_drill(w, Vector2i(12, -1))
	var bad: int = _run(d, DrillIntent.new(), 1.0)
	check_eq(bad, 0, "sem sobreposição ao pousar")
	check(d.grounded, "apoiada na superfície")
	check_eq(d.depth_m(), 0, "profundidade 0 na superfície")
	d.free()


func test_drilling_down_progresses() -> void:
	var w := _model(11)
	var d := _new_drill(w, Vector2i(12, -1))
	var intent := DrillIntent.new()
	intent.drill = true
	var broken: Array[int] = [0]
	d.block_destroyed.connect(func(_c: Vector2i, _id: int) -> void: broken[0] += 1)
	var bad: int = _run(d, intent, 20.0)
	check_eq(bad, 0, "sem atravessar blocos durante 20 s de perfuração")
	check(d.depth_m() >= 10, "desce pelo menos 10 m em 20 s (%d m)" % d.depth_m())
	check(broken[0] >= 8, "quebrou blocos (%d)" % broken[0])
	note("20 s perfurando: %d m, %d blocos" % [d.depth_m(), broken[0]])
	d.free()


func test_no_tunneling_when_falling_fast() -> void:
	for dt: float in [1.0 / 60.0, 1.0 / 30.0, 1.0 / 20.0]:
		var w := _model(12)
		# Poço profundo de 60 linhas terminando em um piso sólido.
		_fill(w, Vector2i(1, 0), Vector2i(22, 80), BlockRegistry.STONE)
		_fill(w, Vector2i(10, 0), Vector2i(12, 60), BlockRegistry.AIR)
		var d := _new_drill(w, Vector2i(11, -1))
		var bad: int = _run(d, DrillIntent.new(), 6.0, dt)
		check_eq(bad, 0, "queda rápida sem atravessar (dt=%.3f)" % dt)
		check_eq(d.feet_row(), 60, "parou exatamente sobre o piso (dt=%.3f)" % dt)
		check(d.grounded, "apoiada após a queda (dt=%.3f)" % dt)
		d.free()


func test_walls_block_horizontal_movement() -> void:
	var w := _model(13)
	_fill(w, Vector2i(1, 0), Vector2i(22, 10), BlockRegistry.STONE)
	_fill(w, Vector2i(8, 0), Vector2i(14, 3), BlockRegistry.AIR)   # sala de 7×4
	var d := _new_drill(w, Vector2i(11, 3))
	var intent := DrillIntent.new()
	intent.move = 1.0
	var bad: int = _run(d, intent, 3.0)
	check_eq(bad, 0, "sem sobreposição empurrando a parede")
	check(d.get_rect().end.x <= 15.0 * Balance.BLOCK_PX + 0.01, "parou na parede direita")
	intent.move = -1.0
	bad = _run(d, intent, 3.0)
	check_eq(bad, 0, "sem sobreposição na parede esquerda")
	check(d.get_rect().position.x >= 8.0 * Balance.BLOCK_PX - 0.01, "parou na parede esquerda")
	d.free()


func test_side_drilling_breaks_wall() -> void:
	var w := _model(14)
	_fill(w, Vector2i(1, 0), Vector2i(22, 10), BlockRegistry.STONE)
	_fill(w, Vector2i(8, 0), Vector2i(11, 4), BlockRegistry.AIR)   # sala alta: sem pulo
	var d := _new_drill(w, Vector2i(10, 4))
	var intent := DrillIntent.new()
	intent.move = 1.0
	intent.drill = true
	var bad: int = _run(d, intent, 4.0)
	check_eq(bad, 0, "sem sobreposição perfurando lateralmente")
	check_eq(w.get_block(Vector2i(12, 4)), BlockRegistry.AIR, "parede lateral perfurada")
	check(d.center_col() >= 12, "avançou pela abertura (coluna %d)" % d.center_col())
	d.free()


func test_auto_hop_over_single_step() -> void:
	var w := _model(15)
	_fill(w, Vector2i(1, 0), Vector2i(22, 10), BlockRegistry.STONE)
	_fill(w, Vector2i(4, 0), Vector2i(20, 4), BlockRegistry.AIR)
	w.set_block(Vector2i(12, 4), BlockRegistry.STONE)              # degrau de 1 bloco
	var d := _new_drill(w, Vector2i(9, 4))
	var hops: Array[int] = [0]
	d.hopped.connect(func() -> void: hops[0] += 1)
	var intent := DrillIntent.new()
	intent.move = 1.0
	var bad: int = _run(d, intent, 2.5)
	check_eq(bad, 0, "sem sobreposição ao pular")
	check(hops[0] >= 1, "pulou o degrau")
	check(d.center_col() > 12, "passou do degrau (coluna %d)" % d.center_col())
	d.free()


func test_bedrock_walls_hold_and_signal() -> void:
	var w := _model(16)
	_fill(w, Vector2i(1, 0), Vector2i(3, 3), BlockRegistry.AIR)
	_fill(w, Vector2i(1, 4), Vector2i(3, 4), BlockRegistry.STONE)
	var d := _new_drill(w, Vector2i(2, 3))
	var signals: Array[int] = [0]
	d.blocked_by_unbreakable.connect(func(_c: Vector2i) -> void: signals[0] += 1)
	var intent := DrillIntent.new()
	intent.move = -1.0
	intent.drill = true
	var bad: int = _run(d, intent, 3.0)
	check_eq(bad, 0, "sem sobreposição contra rocha-mãe")
	check(d.get_rect().position.x >= Balance.BLOCK_PX - 0.01, "não atravessou a parede")
	check_eq(w.get_block(Vector2i(0, 3)), BlockRegistry.BEDROCK, "parede intacta")
	check(signals[0] > 0, "feedback de bloco indestrutível emitido")
	d.free()


func test_more_damage_digs_faster() -> void:
	var results: Array[int] = []
	for dmg: float in [4.0, 20.0]:
		var w := _model(17)
		_fill(w, Vector2i(11, 0), Vector2i(13, 40), BlockRegistry.STONE)
		var d := _new_drill(w, Vector2i(12, -1))
		d.stats.damage = dmg
		var intent := DrillIntent.new()
		intent.drill = true
		_run(d, intent, 8.0)
		results.append(d.depth_m())
		d.free()
	check(results[1] > results[0], "upgrade de dano é perceptível (%d m vs %d m)" % [results[0], results[1]])
	note("8 s em pedra: dano 4 → %d m, dano 20 → %d m" % [results[0], results[1]])


func test_drill_does_not_mine_upwards() -> void:
	var w := _model(18)
	_fill(w, Vector2i(1, 0), Vector2i(22, 10), BlockRegistry.STONE)
	w.set_block(Vector2i(12, 5), BlockRegistry.AIR)
	var d := _new_drill(w, Vector2i(12, 5))
	var intent := DrillIntent.new()
	intent.drill = true
	var hit_cells: Array[Vector2i] = []
	d.block_hit.connect(func(c: Vector2i, _id: int, _dm: float, _cr: bool, _de: bool) -> void: hit_cells.append(c))
	_run(d, intent, 1.0)
	for c in hit_cells:
		check(c.y > 5, "golpe abaixo da máquina, nunca acima (%s)" % c)
	check(not hit_cells.is_empty(), "golpeou o bloco abaixo")
	d.free()
