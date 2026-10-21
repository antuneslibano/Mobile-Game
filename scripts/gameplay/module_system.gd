class_name ModuleSystem
extends RefCounted
## Módulos equipados na perfuradora: Broca lateral, Drone minerador e Pulso sísmico.
## Escavam via Drill.apply_external_dig() — drops, carga de energia, FX e eventos seguem o
## mesmo fluxo da broca principal. Nunca escavam acima da máquina. Visuais escutam os sinais.

signal drone_shot(point: Vector2)
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


static func side_drill_bonus(s: DrillStats) -> float:
	var lvl: int = level(s, SIDE_DRILL)
	return 0.0 if lvl <= 0 else Balance.SIDE_DRILL_RADIUS_PX + Balance.SIDE_DRILL_RADIUS_PER_LEVEL * (lvl - 1)


static func drone_interval(s: DrillStats) -> float:
	return maxf(0.5, Balance.DRONE_INTERVAL - Balance.DRONE_INTERVAL_PER_LEVEL * (level(s, DRONE) - 1))


static func pulse_interval(s: DrillStats) -> float:
	return maxf(2.5, Balance.PULSE_INTERVAL - Balance.PULSE_INTERVAL_PER_LEVEL * (level(s, SEISMIC) - 1))


static func pulse_radius_px(s: DrillStats) -> float:
	return (Balance.PULSE_RADIUS_CELLS + Balance.PULSE_RADIUS_PER_LEVEL * (level(s, SEISMIC) - 1)) * Balance.BLOCK_PX


## Alargamento da broca (só se a Broca lateral estiver equipada).
func side_bonus(s: DrillStats) -> float:
	return side_drill_bonus(s) if has(SIDE_DRILL) else 0.0


## Chamado pela Drill após cada golpe próprio que atingiu material.
func on_drill_hit(drill: Drill, crit: bool) -> void:
	if crit and has(SEISMIC) and SynergyRules.is_active(SynergyRules.CRITICAL_RESONANCE, equipped, drill.stats):
		pulse_cd -= Balance.SYNERGY_CRIT_PULSE_REFUND


func step(delta: float, drill: Drill) -> void:
	var s: DrillStats = drill.stats
	if has(DRONE) and level(s, DRONE) > 0:
		drone_cd -= delta
		if drone_cd <= 0.0:
			drone_cd = drone_interval(s)
			var target: Vector2 = find_drone_target(drill)
			if target != Vector2.INF:
				var ratio: float = Balance.DRONE_DAMAGE_RATIO + Balance.DRONE_DAMAGE_PER_LEVEL * (level(s, DRONE) - 1)
				drone_shot.emit(target)
				drill.apply_external_dig(target, Balance.DRONE_LASER_RADIUS_PX, s.damage * ratio, false)
	if has(SEISMIC) and level(s, SEISMIC) > 0 and drill.digging:
		pulse_cd -= delta
		if pulse_cd <= 0.0:
			pulse_cd = pulse_interval(s)
			fire_pulse(drill)


## Alvo do drone: célula de minério/cristal/especial mais próxima no alcance; senão a célula
## quebrável mais próxima. Nunca acima da máquina. Retorna o centro em pixels ou INF.
func find_drone_target(drill: Drill) -> Vector2:
	var cp: float = float(Balance.CELL_PX)
	var r: float = Balance.DRONE_RANGE_PX
	var top: float = drill.dig_ceiling()
	var x0: int = floori((drill.position.x - r) / cp)
	var x1: int = floori((drill.position.x + r) / cp)
	var y0: int = floori(maxf(drill.position.y - r, top) / cp)
	var y1: int = floori((drill.position.y + r) / cp)
	var best := Vector2.INF
	var best_score: float = INF
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var c := Vector2i(cx, cy)
			var p: Vector2 = WorldModel.cell_center(c)
			if p.y < top:
				continue
			var d: float = p.distance_to(drill.position)
			if d > r:
				continue
			var def: BlockDef = BlockRegistry.get_def(drill.world.get_cell(c))
			if not def.solid or not def.breakable:
				continue
			var score: float = d
			if def.art in [BlockDef.Art.ORE, BlockDef.Art.CRYSTAL, BlockDef.Art.CHEST, BlockDef.Art.ARTIFACT]:
				score -= 1000.0
			if score < best_score:
				best_score = score
				best = p
	return best


func fire_pulse(drill: Drill) -> void:
	var s: DrillStats = drill.stats
	var synergy: bool = SynergyRules.is_active(SynergyRules.CRITICAL_RESONANCE, equipped, s)
	var crit: bool = synergy and rng.randf() < s.crit_chance * Balance.SYNERGY_PULSE_CRIT_MULT
	var dmg: float = s.damage * (Balance.PULSE_DAMAGE_RATIO + Balance.PULSE_DAMAGE_PER_LEVEL * (level(s, SEISMIC) - 1))
	if crit:
		dmg *= s.crit_mult
	var r: float = pulse_radius_px(s)
	pulse_fired.emit(drill.position, r, crit)
	drill.apply_external_dig(drill.position, r, dmg, crit)
