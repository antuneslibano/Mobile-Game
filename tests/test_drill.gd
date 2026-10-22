extends "res://tests/test_case.gd"
## Perfuradora de movimento livre, sem cena: física, escavação e invariantes.

const DT: float = 1.0 / 60.0
const B: float = 48.0


func _model(p_seed: int) -> WorldModel:
	var w := WorldModel.new(p_seed)
	w.threaded = false
	return w


## Retângulo de material em pixels (preenche as micro-células).
func _rect(w: WorldModel, from_px: Vector2, to_px: Vector2, id: int) -> void:
	var cp: float = float(Balance.CELL_PX)
	for cy in range(floori(from_px.y / cp), floori(to_px.y / cp)):
		for cx in range(floori(from_px.x / cp), floori(to_px.x / cp)):
			w.set_cell(Vector2i(cx, cy), id)


func _new_drill(w: WorldModel, pos: Vector2, levels: Dictionary = {}) -> Drill:
	var d := Drill.new()
	d.stats = Progression.build_stats(levels)
	d.setup(w, pos, 7)
	return d


func _aim(v: Vector2) -> DrillIntent:
	var it := DrillIntent.new()
	it.aim = v
	return it


## Avança verificando invariantes: nunca sobrepõe material e nunca sobe.
func _run(d: Drill, intent: DrillIntent, seconds: float, dt: float = DT) -> Vector2i:
	var overlaps: int = 0
	var rises: int = 0
	for i in int(seconds / dt):
		var y0: float = d.position.y
		d.physics_step(dt, intent)
		if d.is_overlapping_solid():
			overlaps += 1
		if d.position.y < y0 - 0.001:
			rises += 1
	return Vector2i(overlaps, rises)


func test_spawn_rests_on_surface() -> void:
	var w := _model(10)
	var d := _new_drill(w, Drill.surface_spawn())
	var r := _run(d, DrillIntent.new(), 1.5)
	check_eq(r, Vector2i.ZERO, "sem sobreposição nem subida ao pousar")
	check(d.grounded, "apoiada na superfície")
	check(d.depth_m() <= 1, "profundidade ~0 na superfície (%d)" % d.depth_m())
	d.free()


func test_digging_down_progresses() -> void:
	var w := _model(11)
	var d := _new_drill(w, Drill.surface_spawn())
	var dug: Array[int] = [0]
	d.dug.connect(func(counts: Dictionary, _at: Vector2) -> void:
		for id: int in counts:
			dug[0] += int(counts[id]))
	var r := _run(d, _aim(Vector2.DOWN), 20.0)
	check_eq(r, Vector2i.ZERO, "20 s cavando: sem atravessar nem subir")
	check(d.depth_m() >= 10, "desce ao menos 10 m em 20 s (%d m)" % d.depth_m())
	check(dug[0] > 0, "remove micro-células")
	note("20 s para baixo: %d m, %.1f blocos de volume" % [d.depth_m(), dug[0] / 16.0])
	d.free()


func test_diagonal_draws_its_own_path() -> void:
	var w := _model(12)
	_rect(w, Vector2(60, 0), Vector2(1100, 900), BlockRegistry.DIRT)
	var start := Vector2(300, -Balance.DRILL_RADIUS_PX - 5.0)
	var d := _new_drill(w, start)
	_run(d, DrillIntent.new(), 0.5)
	var p0: Vector2 = d.position
	var r := _run(d, _aim(Vector2(1, 1).normalized()), 6.0)
	check_eq(r, Vector2i.ZERO, "diagonal: sem atravessar nem subir")
	var delta: Vector2 = d.position - p0
	check(delta.x > 60.0 and delta.y > 60.0, "avançou na diagonal (%s)" % delta)
	var ang: float = rad_to_deg(delta.angle())
	check(ang > 30.0 and ang < 60.0, "trajetória ~45° (%.0f°)" % ang)
	# O túnel segue o caminho: pontos no meio da trajetória ficaram vazios.
	for k: float in [0.3, 0.6, 0.9]:
		var p: Vector2 = p0 + delta * k
		check(not w.is_solid(WorldModel.world_to_cell(p)), "túnel aberto em %.0f%% do caminho" % (k * 100.0))
	note("diagonal 6 s em terra: %s px" % delta)
	d.free()


func test_horizontal_tunnel_stays_level() -> void:
	var w := _model(13)
	_rect(w, Vector2(60, 0), Vector2(1100, 900), BlockRegistry.DIRT)
	var start := Vector2(200, 400)
	w.fill_circle(start, 30.0, BlockRegistry.AIR)
	var d := _new_drill(w, start)
	_run(d, DrillIntent.new(), 0.6)
	var r := _run(d, _aim(Vector2.RIGHT), 1.0)
	var p0: Vector2 = d.position
	r += _run(d, _aim(Vector2.RIGHT), 5.0)
	check_eq(r, Vector2i.ZERO, "horizontal: sem atravessar nem subir")
	check(d.position.x - p0.x > 120.0, "avançou para a direita (%.0f px)" % (d.position.x - p0.x))
	# Pode assentar até uma célula no início; depois o túnel não afunda.
	check(absf(d.position.y - p0.y) <= float(Balance.CELL_PX) * 0.5, "túnel nivelado (Δy %.1f px)" % (d.position.y - p0.y))
	d.free()


func test_never_digs_above_the_machine() -> void:
	var w := _model(14)
	_rect(w, Vector2(60, 0), Vector2(1100, 900), BlockRegistry.STONE)
	var start := Vector2(500, 450)
	w.fill_circle(start, 30.0, BlockRegistry.AIR)
	var d := _new_drill(w, start, {&"seismic": 5, &"drone": 5, &"side_drill": 5})
	d.modules.set_equipped([&"seismic", &"drone"] as Array[StringName])
	var bad: Array[int] = [0]
	w.cells_changed.connect(func(cells: Array[Vector2i]) -> void:
		for c in cells:
			if WorldModel.cell_center(c).y < d.dig_ceiling() - 0.01:
				bad[0] += 1)
	for v: Vector2 in [Vector2.LEFT, Vector2(-1, 1), Vector2.DOWN, Vector2(1, 1), Vector2.RIGHT, Vector2(0.3, -1), Vector2.UP]:
		var it := _aim(v)
		it.boost = true
		var r := _run(d, it, 1.5)
		check_eq(r.y, 0, "aim %s não eleva a máquina" % v)
	check_eq(bad[0], 0, "nada é escavado acima da máquina (broca e módulos)")
	d.free()


func test_up_input_does_nothing() -> void:
	var w := _model(15)
	_rect(w, Vector2(60, 0), Vector2(1100, 900), BlockRegistry.STONE)
	var start := Vector2(500, 450)
	w.fill_circle(start, 60.0, BlockRegistry.AIR)
	var d := _new_drill(w, start)
	_run(d, DrillIntent.new(), 1.0)
	var p0: Vector2 = d.position
	var r := _run(d, _aim(Vector2.UP), 3.0)
	check_eq(r, Vector2i.ZERO, "para cima: sem subir")
	check(d.position.distance_to(p0) < 0.5, "para cima: não se move (%s)" % (d.position - p0))
	d.free()


## 0.12: a nave sobe em rampa (diagonal para cima), nunca na vertical.
func test_climbs_ramps() -> void:
	var w := _model(18)
	_rect(w, Vector2(60, 0), Vector2(1100, 900), BlockRegistry.STONE)
	var start := Vector2(300, 600)
	w.fill_circle(start, 40.0, BlockRegistry.AIR)
	var d := _new_drill(w, start)
	_run(d, DrillIntent.new(), 0.5)
	var p0: Vector2 = d.position
	_run(d, _aim(Vector2(1, -1)), 2.0)
	var climbed: Vector2 = d.position - p0
	check(climbed.y < -20.0 and climbed.x > 0.0, "diagonal para cima: sobe cavando a rampa (%s)" % climbed)
	check(absf(climbed.y) <= climbed.x * Balance.CLIMB_SLOPE + 4.0, "subida limitada à inclinação da rampa (%s)" % climbed)
	d.free()


func test_no_tunneling_when_falling_fast() -> void:
	for dt: float in [1.0 / 60.0, 1.0 / 30.0, 1.0 / 20.0]:
		var w := _model(16)
		_rect(w, Vector2(60, 0), Vector2(1100, 3000), BlockRegistry.STONE)
		_rect(w, Vector2(480, 0), Vector2(600, 2400), BlockRegistry.AIR)
		var d := _new_drill(w, Vector2(540, -Balance.DRILL_RADIUS_PX - 5.0))
		var r := _run(d, DrillIntent.new(), 5.0, dt)
		check_eq(r.x, 0, "queda rápida sem atravessar (dt=%.3f)" % dt)
		check(absf(d.position.y + d.radius - 2400.0) < 2.0, "parou sobre o piso (dt=%.3f, base %.1f)" % [dt, d.position.y + d.radius])
		d.free()


func test_bedrock_walls_hold() -> void:
	var w := _model(17)
	var start := Vector2(70, 300)
	w.fill_circle(start, 30.0, BlockRegistry.AIR)
	var d := _new_drill(w, start)
	var signals: Array[int] = [0]
	d.blocked_by_unbreakable.connect(func(_p: Vector2) -> void: signals[0] += 1)
	var r := _run(d, _aim(Vector2.LEFT), 4.0)
	check_eq(r, Vector2i.ZERO, "contra a parede: sem atravessar")
	check(d.position.x - d.radius >= 0.0, "não saiu do mundo")
	check(w.get_cell(Vector2i(0, 25)) == BlockRegistry.BEDROCK, "rocha-mãe intacta")
	check(signals[0] > 0, "feedback de rocha indestrutível")
	d.free()


func test_more_damage_digs_faster() -> void:
	var depths: Array[float] = []
	for dmg: float in [4.0, 20.0]:
		var w := _model(18)
		_rect(w, Vector2(60, 0), Vector2(1100, 2000), BlockRegistry.STONE)
		var d := _new_drill(w, Vector2(540, -Balance.DRILL_RADIUS_PX - 5.0))
		d.stats.damage = dmg
		_run(d, _aim(Vector2.DOWN), 6.0)
		depths.append(d.position.y)
		d.free()
	check(depths[1] > depths[0] + 48.0, "upgrade de dano é perceptível (%.0f vs %.0f px)" % [depths[0], depths[1]])
	note("6 s em pedra: dano 4 → %.1f m, dano 20 → %.1f m" % [depths[0] / B, depths[1] / B])
