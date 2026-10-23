class_name Drill
extends Node2D
## Perfuradora de movimento livre. Corpo = círculo de colisão; broca = círculo à frente que
## escava micro-células na direção do joystick. Move-se em qualquer direção da metade de
## baixo (lados, diagonais, baixo) e cai pela gravidade no vazio. Não sobe na vertical:
## só em rampa (0.12), com a subida limitada a CLIMB_SLOPE do movimento lateral; parada ou
## mirando reto para cima, não sobe nem escava acima da máquina. A broca só quebra
## minérios até o seu nível (MiningRules.required_tier).

signal dig_hit(point: Vector2, material_id: int, crit: bool, removed: int)
signal dug(counts: Dictionary, at: Vector2)
signal blocked_by_unbreakable(point: Vector2)
## Minério acima do nível da broca (precisa aprimorar a Broca).
signal blocked_by_hardness(point: Vector2, block_id: int)
## Um baú foi aberto (bloco do baú, em blocos).
signal chest_opened(block: Vector2i)
signal boost_started
signal overdrive_ready
## Combustível ou casco zerou: fim da expedição (resgate de emergência).
signal stranded(reason: StringName)
signal refueled(amount: float)

const MAX_STEP_PX: float = 4.0
const CONTACT_PROBE_PX: float = 1.5
## Folga escavada acima do corpo (túneis horizontais não raspam o teto).
const HEADROOM_PX: float = 6.0
const UNBREAKABLE_FEEDBACK_SEC: float = 0.25
const DIG_VISUAL_SEC: float = 0.25
## O corpo tritura o que o bloqueia a esta distância à frente (bordas que a broca não cobre).
const PLOW_PX: float = 3.0

var world: WorldModel
var stats: DrillStats = DrillStats.base()
var velocity: Vector2 = Vector2.ZERO
## Direção atual da broca (unitária, y ≥ 0). Suavizada para curvas naturais.
var facing: Vector2 = Vector2.DOWN
var grounded: bool = false
## Verdadeiro enquanto a broca está atingindo material (visual e módulos).
var digging: bool = false
var rng := RandomNumberGenerator.new()
var energy := EnergySystem.new()
var modules := ModuleSystem.new()
var vitals := ShipVitals.new()
## Parada (sem combustível ou casco): não se move nem cava até a extração.
var disabled: bool = false
## Multiplicador atual de golpes/s (Sobrecarga × calor).
var speed_mult: float = 1.0
var heat_penalty: float = 0.0
var radius: float = Balance.DRILL_RADIUS_PX
## Tensão da broca (0.13): sobe ao forçar minério duro demais; acima de 1 fere o casco.
var strain: float = 0.0

var _hit_timer: float = 0.5
var _unbreakable_cd: float = 0.0
var _dig_visual_t: float = 0.0
var _b: float = float(Balance.BLOCK_PX)


func setup(p_world: WorldModel, spawn: Vector2, p_seed: int = 0) -> void:
	world = p_world
	rng.seed = p_seed
	position = spawn
	velocity = Vector2.ZERO
	facing = Vector2.DOWN
	grounded = false
	digging = false
	energy.reset(stats)
	vitals.reset(stats)
	disabled = false
	strain = 0.0
	modules.rng.seed = p_seed + 17


## Posição de partida sobre a superfície, no centro do mundo.
static func surface_spawn() -> Vector2:
	return Vector2(Balance.WORLD_CELLS_X * Balance.CELL_PX * 0.5, -Balance.DRILL_RADIUS_PX - 0.5)


# --- Consultas ----------------------------------------------------------------

## Profundidade em metros (base do corpo; 0 na superfície).
func depth_m() -> int:
	return maxi(0, floori((position.y + radius) / _b * Balance.METERS_PER_BLOCK))


func is_overlapping_solid() -> bool:
	return world.circle_hits_solid(position, radius - 0.25)


func bit_radius() -> float:
	var r: float = Balance.BIT_RADIUS_PX + modules.side_bonus(stats)
	return r * (Balance.OVERDRIVE_BIT_MULT if energy.is_boosting() else 1.0)


## Centro da broca: à frente do corpo; em movimento lateral, sobe o suficiente para o piso
## do túnel ficar rente à base do corpo (túneis horizontais não afundam sozinhos).
func bit_center() -> Vector2:
	var c: Vector2 = position + facing * Balance.BIT_OFFSET_PX
	c.y -= (bit_radius() - radius) * (1.0 - maxf(facing.y, 0.0))
	return c


## Nada acima desta altura é escavado.
func dig_ceiling() -> float:
	if facing.y < -0.05:
		return -INF  # subindo em rampa: a broca abre a rampa à frente
	return position.y - radius - HEADROOM_PX


# --- Simulação ------------------------------------------------------------------

func physics_step(delta: float, intent: DrillIntent) -> void:
	if world == null:
		return
	_unbreakable_cd = maxf(0.0, _unbreakable_cd - delta)
	# Broca forçada: a tensão esfria com o tempo; acima de 1, superaquece e fere o casco.
	strain = maxf(0.0, strain - Balance.STRAIN_DECAY * delta)
	if strain > 1.0 and not disabled:
		apply_hull_damage(Balance.STRAIN_HULL_DPS * delta)
	_dig_visual_t = maxf(0.0, _dig_visual_t - delta)
	if energy.step(delta, stats, intent.boost):
		boost_started.emit()
	heat_penalty = HeatRules.penalty(depth_m(), stats.temp_limit)
	speed_mult = energy.speed_mult(stats) * (1.0 - heat_penalty)

	var a: Vector2 = DrillIntent.sanitize(intent.aim) if not disabled else Vector2.ZERO
	var throttle: float = a.length()
	var steering: bool = throttle > 0.05
	if not disabled and vitals.step(delta, stats, steering or digging, energy.is_boosting(), HeatRules.over(depth_m(), stats.temp_limit)):
		disabled = true
		stranded.emit(&"fuel" if vitals.is_out_of_fuel() else &"hull")
	if steering:
		# A broca gira sempre por baixo (nunca passa pelo alto): ângulos medidos de -90°
		# a 270°, então ir da direita-para-cima à esquerda-para-cima passa pelo "para baixo".
		var target: Vector2 = a / throttle
		var af: float = _low_angle(facing)
		var at: float = _low_angle(target)
		facing = Vector2.from_angle(lerpf(af, at, clampf(delta * 14.0, 0.0, 1.0)))
		facing.y = maxf(facing.y, -absf(facing.x) * Balance.CLIMB_SLOPE)
		facing = facing.normalized() if facing.length() > 0.01 else target

	var move_mult: float = Balance.OVERDRIVE_MOVE_MULT if energy.is_boosting() else 1.0
	var desired: Vector2 = Vector2.ZERO
	if steering:
		desired = a / throttle * stats.move_speed_blocks * _b * move_mult * throttle
		# Subir só em rampa de verdade: com a broca já virada para esse lado e a nave
		# apoiada (no chão ou cavando à frente). No ar, sem apoio, ela não voa.
		if desired.y < 0.0 and not (facing.y < -0.05 and signf(facing.x) == signf(desired.x) and _supported()):
			desired.y = 0.0
	velocity.x = move_toward(velocity.x, desired.x, Balance.DRILL_ACCEL_BLOCKS * _b * delta)
	# Vertical: gravidade e empurrão para baixo; subir só em rampa (propulsores vencem a
	# gravidade enquanto a nave mira para cima na diagonal).
	if desired.y < 0.0:
		velocity.y = move_toward(velocity.y, desired.y, Balance.DRILL_ACCEL_BLOCKS * _b * delta)
		# Nunca mais íngreme que a rampa: sobe só na proporção do avanço lateral.
		velocity.y = maxf(velocity.y, -absf(velocity.x) * Balance.CLIMB_SLOPE)
	else:
		velocity.y = clampf(maxf(velocity.y + Balance.GRAVITY_BLOCKS * _b * delta, desired.y), 0.0, Balance.MAX_FALL_BLOCKS * _b)

	_move(velocity * delta)
	_update_dig(delta, steering)
	digging = _dig_visual_t > 0.0
	modules.step(delta, self)


## Ângulo de -90° a 270° (o "para baixo" fica no meio): interpolar nele gira por baixo.
static func _low_angle(v: Vector2) -> float:
	var ang: float = v.angle()
	return ang + TAU if ang < -PI * 0.5 else ang


## Apoiada: tocando o chão, cavando ou encostada no terreno à frente.
func _supported() -> bool:
	return grounded or _dig_visual_t > 0.0 or world.circle_hits_solid(position + facing * 6.0, radius)


## Movimento com colisão contínua (subpassos) e deslizamento por eixo.
func _move(motion: Vector2) -> void:
	var dist: float = motion.length()
	if dist > 0.0:
		var steps: int = maxi(1, ceili(dist / MAX_STEP_PX))
		var step: Vector2 = motion / float(steps)
		for i in steps:
			if not world.circle_hits_solid(position + step, radius):
				position += step
				continue
			var moved: bool = false
			if step.x != 0.0 and not world.circle_hits_solid(position + Vector2(step.x, 0.0), radius):
				position.x += step.x
				velocity.y = 0.0
				moved = true
			elif step.y > 0.0 and not world.circle_hits_solid(position + Vector2(0.0, step.y), radius):
				# (Subida só junto com o avanço lateral: travou do lado, não sobe na vertical.)
				position.y += step.y
				velocity.x = 0.0
				moved = true
			if not moved:
				if step.y > 0.0:
					velocity.y = 0.0
				if step.x != 0.0:
					velocity.x = 0.0
				break
	grounded = world.circle_hits_solid(position + Vector2(0.0, CONTACT_PROBE_PX), radius)
	if grounded and velocity.y > 0.0 and world.circle_hits_solid(position + Vector2(0.0, maxf(velocity.y * 0.002, CONTACT_PROBE_PX)), radius):
		velocity.y = 0.0


func _update_dig(delta: float, steering: bool) -> void:
	if not steering:
		_hit_timer = minf(_hit_timer, 0.5)
		return
	_hit_timer += delta * stats.hits_per_second * speed_mult
	while _hit_timer >= 1.0:
		_hit_timer -= 1.0
		if not _do_hit():
			# Nada à frente: não acumula golpes "guardados".
			_hit_timer = minf(_hit_timer, 0.5)
			break


func _do_hit() -> bool:
	var roll: Vector2 = MiningRules.roll_hit(stats, rng)
	var crit: bool = roll.y > 0.5
	var c: Vector2 = bit_center()
	var rb: float = bit_radius()
	var cells: Array[Vector2i] = world.cells_in_circle(c, rb, dig_ceiling())
	cells.append_array(world.blocking_cells(position + facing * PLOW_PX, radius))
	var res: WorldModel.DigResult = world.dig_cells(cells, roll.x, dig_ceiling(), stats.drill_tier)
	if res.too_hard >= 0:
		strain = minf(Balance.STRAIN_MAX, strain + Balance.STRAIN_PER_HIT)
		if _unbreakable_cd <= 0.0:
			_unbreakable_cd = UNBREAKABLE_FEEDBACK_SEC
			blocked_by_hardness.emit(c + facing * rb * 0.6, res.too_hard)
	if res.touched == 0:
		if res.unbreakable and _unbreakable_cd <= 0.0:
			_unbreakable_cd = UNBREAKABLE_FEEDBACK_SEC
			blocked_by_unbreakable.emit(c + facing * rb * 0.6)
		return false
	var point: Vector2 = c + facing * rb * 0.55
	_dig_visual_t = DIG_VISUAL_SEC
	dig_hit.emit(point, res.main_id, crit, res.removed())
	_on_dug(res, point)
	modules.on_drill_hit(self, crit)
	return true


## Escavação vinda de módulos (drone, pulso). Mesmos sinais, drops e carga dos golpes
## normais; respeita o teto (nada acima da máquina).
func apply_external_dig(center: Vector2, r: float, raw_damage: float, crit: bool) -> WorldModel.DigResult:
	var res: WorldModel.DigResult = world.dig_circle(center, r, raw_damage, dig_ceiling(), stats.drill_tier)
	if res.touched > 0:
		dig_hit.emit(center, res.main_id, crit, res.removed())
		_on_dug(res, center)
	return res


## Escava um anel (onda de choque): células entre r_in e r_out do centro.
## top: teto da onda (o da nave quando ela foi disparada).
func apply_external_ring(center: Vector2, r_in: float, r_out: float, raw_damage: float, crit: bool, top: float) -> void:
	var cells: Array[Vector2i] = []
	for c in world.cells_in_circle(center, r_out, top):
		if WorldModel.cell_center(c).distance_to(center) >= r_in:
			cells.append(c)
	var res: WorldModel.DigResult = world.dig_cells(cells, raw_damage, top, stats.drill_tier)
	if res.touched > 0:
		dig_hit.emit(center + (Vector2.RIGHT * r_out).rotated(rng.randf() * TAU), res.main_id, crit, res.removed())
		_on_dug(res, center)


## Dano externo no casco (ex.: pulso do guardião). Zerado → resgate de emergência.
func apply_hull_damage(amount: float) -> void:
	if not disabled and vitals.damage(amount):
		disabled = true
		stranded.emit(&"hull")


func _on_dug(res: WorldModel.DigResult, at: Vector2) -> void:
	for blk in res.chest_blocks:
		chest_opened.emit(blk)
	if res.counts.is_empty():
		return
	dug.emit(res.drop_counts(), at)
	var fuel: float = fuel_for(res.counts)
	if fuel > 0.0:
		vitals.refuel(fuel)
		refueled.emit(fuel)
	var value: Vector2 = volume_value(res.counts)
	if energy.add_charge(EnergySystem.charge_for(value.x, value.y, depth_m(), stats)):
		overdrive_ready.emit()


## Valor do material removido: x = Créditos, y = Cristais (antes do upgrade de Coleta).
static func volume_value(counts: Dictionary) -> Vector2:
	var credits: float = 0.0
	var crystals: float = 0.0
	for id: int in counts:
		var vol: float = float(counts[id]) / Balance.CELLS_PER_BLOCK
		var drops: Dictionary = BlockRegistry.get_def(id).drops
		for key: Variant in drops:
			var r: ResourceDef = ResourceRegistry.get_def(StringName(key))
			if r == null:
				continue
			var amount: float = float(drops[key]) * vol
			if r.currency == Economy.CRYSTALS:
				crystals += amount
			else:
				credits += amount * r.sell_value
	return Vector2(credits, crystals)


## Combustível abastecido pelas células removidas (carvão).
static func fuel_for(counts: Dictionary) -> float:
	var f: float = 0.0
	for id: int in counts:
		f += BlockRegistry.get_def(id).fuel * float(counts[id]) / Balance.CELLS_PER_BLOCK
	return f


## Drops (fracionários) correspondentes às células removidas.
static func drops_for(counts: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id: int in counts:
		var vol: float = float(counts[id]) / Balance.CELLS_PER_BLOCK
		var drops: Dictionary = BlockRegistry.get_def(id).drops
		for key: Variant in drops:
			var k := StringName(key)
			out[k] = float(out.get(k, 0.0)) + float(drops[key]) * vol
	return out
