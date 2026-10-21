class_name ModuleSystem
extends RefCounted
## Módulos equipados na perfuradora: Broca lateral, Drone minerador e Pulso sísmico.
## Aplica dano via Drill.apply_external_hit() — drops, FX e eventos seguem o mesmo fluxo
## dos golpes normais. Visuais escutam os sinais.

signal drone_shot(cell: Vector2i)
signal pulse_fired(center: Vector2, radius_px: float, crit: bool)
signal equipped_changed

const SIDE_DRILL: StringName = &"side_drill"
const DRONE: StringName = &"drone"
const SEISMIC: StringName = &"seismic"
const ALL: Array[StringName] = [SIDE_DRILL, DRONE, SEISMIC]

var equipped: Array[StringName] = []
var drone_cd: float = Balance.DRONE_INTERVAL
var pulse_cd: float = Balance.PULSE_INTERVAL
var rng := RandomNumberGenerator.new()


func set_equipped(list: Array[StringName]) -> void:
	equipped = list.duplicate()
	equipped_changed.emit()


func has(id: StringName) -> bool:
	return equipped.has(id)


static func level(s: DrillStats, id: StringName) -> int:
	return int(s.module_levels.get(id, 0))


static func drone_interval(s: DrillStats) -> float:
	return maxf(0.5, Balance.DRONE_INTERVAL - Balance.DRONE_INTERVAL_PER_LEVEL * (level(s, DRONE) - 1))


static func pulse_interval(s: DrillStats) -> float:
	return maxf(2.5, Balance.PULSE_INTERVAL - Balance.PULSE_INTERVAL_PER_LEVEL * (level(s, SEISMIC) - 1))


static func pulse_radius(s: DrillStats) -> float:
	return Balance.PULSE_RADIUS_CELLS + Balance.PULSE_RADIUS_PER_LEVEL * (level(s, SEISMIC) - 1)


static func side_drill_chance(s: DrillStats) -> float:
	return minf(1.0, Balance.SIDE_DRILL_CHANCE + Balance.SIDE_DRILL_CHANCE_PER_LEVEL * (level(s, SIDE_DRILL) - 1))


## Chamado pela Drill após cada golpe próprio (não por golpes de módulos).
func on_drill_hit(drill: Drill, cell: Vector2i, damage: float, crit: bool, destroyed: bool = false) -> void:
	var s: DrillStats = drill.stats
	if destroyed and has(SIDE_DRILL) and level(s, SIDE_DRILL) > 0:
		# Descendo: chance de quebrar os vizinhos laterais. De lado: o de baixo. Nunca acima.
		var offsets: Array[Vector2i] = [Vector2i.DOWN]
		if drill.drill_dir == Vector2i.DOWN:
			offsets = [Vector2i.LEFT, Vector2i.RIGHT]
		var chance: float = side_drill_chance(s)
		for o in offsets:
			if rng.randf() < chance:
				drill.break_external(cell + o)
	if crit and has(SEISMIC) and SynergyRules.is_active(SynergyRules.CRITICAL_RESONANCE, equipped, s):
		pulse_cd -= Balance.SYNERGY_CRIT_PULSE_REFUND


func step(delta: float, drill: Drill) -> void:
	var s: DrillStats = drill.stats
	if has(DRONE) and level(s, DRONE) > 0:
		drone_cd -= delta
		if drone_cd <= 0.0:
			drone_cd = drone_interval(s)
			var target: Vector2i = find_drone_target(drill)
			if target != Vector2i(-9999, -9999):
				var ratio: float = Balance.DRONE_DAMAGE_RATIO + Balance.DRONE_DAMAGE_PER_LEVEL * (level(s, DRONE) - 1)
				drone_shot.emit(target)
				drill.apply_external_hit(target, s.damage * ratio, false)
	if has(SEISMIC) and level(s, SEISMIC) > 0 and drill.has_target:
		pulse_cd -= delta
		if pulse_cd <= 0.0:
			pulse_cd = pulse_interval(s)
			fire_pulse(drill)


## Alvo do drone: minério/cristal mais próximo no alcance; senão o bloco quebrável mais próximo.
## Nunca acima da linha da máquina (o drone também não "abre caminho para cima").
func find_drone_target(drill: Drill) -> Vector2i:
	var origin := Vector2i(drill.center_col(), drill.feet_row())
	var r: int = Balance.DRONE_RANGE_CELLS
	var best := Vector2i(-9999, -9999)
	var best_score: float = INF
	for dy in range(0, r + 1):
		for dx in range(-r, r + 1):
			var c: Vector2i = origin + Vector2i(dx, dy)
			if c == drill.target_cell and drill.has_target:
				continue
			var def: BlockDef = BlockRegistry.get_def(drill.world.get_block(c))
			if not def.solid or not def.breakable:
				continue
			var score: float = Vector2(dx, dy).length()
			if def.art in [BlockDef.Art.ORE, BlockDef.Art.CRYSTAL, BlockDef.Art.CHEST, BlockDef.Art.ARTIFACT]:
				score -= 10.0
			if score < best_score:
				best_score = score
				best = c
	return best


func fire_pulse(drill: Drill) -> void:
	var s: DrillStats = drill.stats
	var radius: float = pulse_radius(s)
	var synergy: bool = SynergyRules.is_active(SynergyRules.CRITICAL_RESONANCE, equipped, s)
	var crit_chance: float = s.crit_chance * (Balance.SYNERGY_PULSE_CRIT_MULT if synergy else 0.0)
	var crit: bool = synergy and rng.randf() < crit_chance
	var dmg: float = s.damage * (Balance.PULSE_DAMAGE_RATIO + Balance.PULSE_DAMAGE_PER_LEVEL * (level(s, SEISMIC) - 1))
	if crit:
		dmg *= s.crit_mult
	var center: Vector2 = drill.position
	var origin := Vector2i(drill.center_col(), drill.feet_row())
	var ri: int = ceili(radius)
	pulse_fired.emit(center, radius * Balance.BLOCK_PX, crit)
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			if Vector2(dx, dy).length() > radius:
				continue
			var c: Vector2i = origin + Vector2i(dx, dy)
			if c.y <= origin.y - 1:
				continue  # o pulso não abre caminho acima da máquina
			drill.apply_external_hit(c, dmg, crit)
