class_name Game
extends Node2D
## Composição do mundo jogável: liga modelo, perfuradora, renderização, FX e câmera.

@onready var background: Background = $Background
@onready var terrain: TerrainView = $TerrainView
@onready var overlay: MiningOverlay = $MiningOverlay
@onready var drill: Drill = $Drill
@onready var fx: DebrisFx = $DebrisFx
@onready var pickups: PickupFx = $PickupFx
@onready var module_fx: ModuleFx = $ModuleFx
@onready var camera: DepthCamera = $DepthCamera
@onready var input: InputController = $InputController

var world: WorldModel
var rig: ElevatorRig
var guardian: FinalGuardian
var creatures: CreatureManager
var fog: FogLayer
var sonar: SonarOverlay
## Extração em andamento (a nave sobe pelo cabo; física parada).
var extracting: bool = false
var _spark_t: float = 0.0
signal extraction_finished
## Guardião da câmara final vencido (casco restante, 0..1).
signal guardian_defeated(hull_ratio: float)


func _ready() -> void:
	drill.dig_hit.connect(_on_dig_hit)
	drill.dug.connect(_on_dug)
	drill.blocked_by_unbreakable.connect(_on_unbreakable)
	drill.blocked_by_hardness.connect(func(p: Vector2, id: int) -> void:
		_on_unbreakable(p)
		EventBus.drill_too_weak.emit(id))
	drill.chest_opened.connect(_on_chest_opened)
	drill.boost_started.connect(_on_boost_started)
	drill.overdrive_ready.connect(func() -> void: EventBus.overdrive_ready.emit())
	drill.refueled.connect(func(amount: float) -> void:
		pickups.show_text(drill.position + Vector2(0, -40), "+%d combustível" % roundi(amount), Color("ffb347")))
	drill.modules.pulse_fired.connect(func(c: Vector2, r: float, crit: bool) -> void:
		camera.add_shake(0.45 if crit else 0.3)
		# O pulso sísmico fere e atordoa criaturas.
		creatures.area_damage(c, r, drill.stats.damage * Balance.PULSE_DAMAGE_RATIO * (6.0 if crit else 4.0), 1.5))
	drill.modules.drone_shot.connect(func(p: Vector2) -> void:
		creatures.area_damage(p, 16.0, drill.stats.damage * Balance.DRONE_DAMAGE_RATIO * 3.0))
	input.drill = drill
	EventBus.stats_changed.connect(_apply_stats)
	EventBus.looks_changed.connect(_apply_look)
	EventBus.resources_collected.connect(_on_resources_collected)
	EventBus.modules_changed.connect(_on_modules_changed)
	module_fx.setup(drill)
	rig = ElevatorRig.new()
	rig.name = "ElevatorRig"
	add_child(rig)
	move_child(rig, drill.get_index())
	guardian = FinalGuardian.new()
	guardian.name = "FinalGuardian"
	add_child(guardian)
	move_child(guardian, rig.get_index())
	creatures = CreatureManager.new()
	creatures.name = "Creatures"
	add_child(creatures)
	move_child(creatures, rig.get_index())
	creatures.ship_bitten.connect(_on_bitten)
	creatures.creature_seen.connect(func(sp: StringName) -> void: GameState.see_creature(sp))
	creatures.creature_defeated.connect(_on_creature_defeated)
	fog = FogLayer.new()
	fog.name = "Fog"
	add_child(fog)
	fog.drill = drill
	fog.creatures = creatures
	fog.guardian = guardian
	sonar = SonarOverlay.new()
	sonar.name = "Sonar"
	add_child(sonar)
	sonar.drill = drill
	sonar.creatures = creatures
	fog.sonar = sonar


## Começa uma expedição: mundo fixo da região (com a escavação salva) e a nave na
## superfície (start_row > 0 só em testes). mods vazio = mundo intocado.
## guardian_defeated: o guardião da câmara final já foi vencido (núcleo aberto).
func start_run(world_seed: int, start_row: int = -1, mods: Dictionary = {}, guardian_defeated: bool = false) -> void:
	if world != null:
		world.shutdown()
	extracting = false
	var region: RegionDef = GameState.region()
	world = WorldModel.new(world_seed, region)
	world.generator.guardian_alive = not guardian_defeated
	creatures.setup(world, region, world_seed)
	sonar.world = world
	sonar.reset()
	guardian.setup(region, not guardian_defeated)
	if not mods.is_empty():
		world.import_modifications(mods)
	background.setup(world_seed, region)
	var spawn: Vector2 = Drill.surface_spawn()
	if start_row > 0:
		spawn.y = (start_row + 0.5) * Balance.BLOCK_PX
		world.fill_circle(spawn, Balance.BIT_RADIUS_PX + 6.0, BlockRegistry.AIR)
	_apply_stats()
	drill.setup(world, spawn, world_seed)
	drill.visible = true
	rig.show_at(spawn, false)
	_on_modules_changed(GameState.economy.equipped_modules)
	camera.target = drill
	camera.combat = false
	camera.zoom = Vector2.ONE
	camera.bottom_limit = (region.target_depth_m + 6) * Balance.BLOCK_PX
	# Abertura: mostra o céu e a base; a câmera desce quando a nave começa a cavar.
	camera.intro = start_row <= 0
	camera.snap_to_target()
	terrain.setup(world, camera)


## Cápsula: o cabo desce até a nave e a puxa para cima; emite extraction_finished.
func play_extraction(duration: float = 1.6) -> void:
	if world == null or extracting:
		return
	extracting = true
	Sfx.drill(false)
	Sfx.engine(false)
	if camera.combat:
		camera.combat = false
		EventBus.guardian_combat.emit(false)
	rig.pull(drill, duration)
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(drill, "position:y", drill.position.y - 900.0, duration - 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		drill.visible = false
		extraction_finished.emit())


func _exit_tree() -> void:
	if world != null:
		world.shutdown()


func _physics_process(delta: float) -> void:
	if world == null or extracting:
		return
	var intent: DrillIntent = input.get_intent()
	drill.physics_step(delta, intent)
	if camera.intro and (drill.depth_m() > 0 or DrillIntent.sanitize(intent.aim).length() > 0.05):
		camera.end_intro()
	GameState.update_depth(drill.depth_m())
	GameState.check_final_chamber(floori(drill.position.x / Balance.BLOCK_PX), drill.depth_m())
	_guardian_step(delta, intent)
	creatures.step(delta, drill, DrillIntent.sanitize(intent.aim).length() > 0.05)
	sonar.step(delta)
	if intent.sonar and not drill.disabled:
		sonar.ping()
	# Som: broca girando ao cavar (mais aguda na Sobrecarga) e motor ao se mover.
	Sfx.drill(drill.digging and not drill.disabled, 1.25 if drill.energy.is_boosting() else 1.0)
	Sfx.engine(drill.velocity.length() > 20.0 and not drill.disabled)


## Depuração/capturas: abre uma caverna à frente da nave com uma criatura de cada espécie.
func debug_creature_showcase() -> void:
	var b: float = Balance.BLOCK_PX
	var c: Vector2 = drill.position + Vector2(0, 4.0 * b)
	world.fill_circle(c, 5.0 * b, BlockRegistry.AIR)
	world.fill_circle(c + Vector2(0, 6.2 * b), 1.8 * b, BlockRegistry.STONE)
	var spots: Dictionary = {&"firefly": c + Vector2(-2.5 * b, -1.5 * b), &"mole": c + Vector2(2.0 * b, 4.3 * b),
			&"spider": c + Vector2(3.0 * b, 0.0), &"worm": c + Vector2(-6.5 * b, 2.0 * b)}
	for sp: StringName in spots:
		creatures.creatures.append(Creature.new(sp, spots[sp], hash(sp)))


## Baú aberto: raridade pela posição; cristais, materiais e talvez uma planta de visual.
func _on_chest_opened(block: Vector2i) -> void:
	var depth: int = block.y
	var rar: int = Chests.rarity(block, world.generator.seed_value, depth)
	var res: Dictionary = Chests.open(rar, block, world.generator.seed_value, depth, GameState.economy.blueprints)
	var at := Vector2((block.x + 0.5) * Balance.BLOCK_PX, (block.y + 0.5) * Balance.BLOCK_PX)
	fx.emit_burst(at, Chests.COLORS[rar], 14 + rar * 14, 300.0, 0.9, 4.0, 200.0)
	camera.add_shake(0.15 + rar * 0.2)
	GameState.open_chest(rar, res, at)
	Sfx.play(&"chest", 1.0 + rar * 0.12)


func _on_bitten(damage: float, _species: StringName) -> void:
	Sfx.play(&"ship_hit")
	drill.apply_hull_damage(damage)
	camera.add_shake(0.5)
	fx.emit_burst(drill.position, Color("ff5a3a"), 10, 240.0, 0.5, 3.0, 300.0)
	EventBus.ship_hit.emit(damage)


func _on_creature_defeated(species: StringName, at: Vector2) -> void:
	fx.emit_burst(at, Color("9bff5a") if species != &"firefly" else Color("e8ff8a"), 18, 260.0, 0.7, 4.0, 400.0)
	camera.add_shake(0.2)
	GameState.defeat_creature(species, at)
	Sfx.play(&"creature", randf_range(0.9, 1.2))


## Combate com o guardião: dentro da arena a câmera entra em modo de combate; raízes que
## sobem de baixo ferem o casco; andar por cima do corpo (movendo-se) o desgasta.
func _guardian_step(delta: float, intent: DrillIntent) -> void:
	var fighting: bool = guardian.alive and guardian.in_arena(drill.position) and not drill.disabled
	if fighting != camera.combat:
		camera.combat = fighting
		camera.combat_anchor = Vector2(guardian.center.x, guardian.floor_y)
		EventBus.guardian_combat.emit(fighting)
	if not guardian.alive or drill.disabled:
		return
	var hit: float = guardian.step(delta, drill.position, drill.radius)
	if hit > 0.0:
		drill.apply_hull_damage(hit)
		camera.add_shake(0.7)
		fx.emit_burst(drill.position, guardian.glow_color, 16, 300.0, 0.6, 4.0, 300.0)
		fx.emit_burst(drill.position, Color("ff5a3a"), 10, 240.0, 0.5, 3.0, 300.0)
		EventBus.ship_hit.emit(hit)
		Sfx.play(&"ship_hit")
	var steering: bool = DrillIntent.sanitize(intent.aim).length() > 0.05
	if not steering or not guardian.on_body(drill.position, drill.radius):
		return
	var s: DrillStats = drill.stats
	var dps: float = s.damage * s.hits_per_second * drill.speed_mult * (1.0 + s.crit_chance * (s.crit_mult - 1.0))
	_spark_t -= delta
	if _spark_t <= 0.0:
		_spark_t = 0.08
		var p := Vector2(drill.position.x, guardian.body_top)
		fx.emit_burst(p, guardian.glow_color, 4, 220.0, 0.35, 3.0, 600.0)
		camera.add_shake(0.05)
	if guardian.take_damage(dps * delta):
		_on_guardian_defeated()


func _on_guardian_defeated() -> void:
	var c: Vector2 = guardian.center + Vector2(0, Balance.BLOCK_PX)
	world.fill_cells(guardian.body_cells(), BlockRegistry.AIR)
	for i in 5:
		fx.emit_burst(Vector2(lerpf(guardian.x0, guardian.x1, i / 4.0), guardian.body_top + 30.0), guardian.glow_color, 20, 420.0, 1.1, 5.0, 400.0)
	fx.emit_burst(c, Color("fff2a8"), 40, 420.0, 1.0, 3.0, 150.0)
	camera.add_shake(1.0)
	camera.combat = false
	EventBus.guardian_combat.emit(false)
	var region: RegionDef = GameState.region()
	GameState.collect_drops(c + Vector2(0, -60), {&"artifact": 1, &"crystal": Balance.GUARDIAN_REWARD_CRYSTALS * region.difficulty})
	guardian_defeated.emit(drill.vitals.hull_ratio())


func _apply_stats() -> void:
	drill.stats = GameState.stats
	_apply_look()


func _apply_look() -> void:
	for c in drill.get_children():
		if c is DrillVisual:
			(c as DrillVisual).look = GameState.ship_look()


func _on_dig_hit(point: Vector2, material_id: int, crit: bool, removed: int) -> void:
	var def: BlockDef = BlockRegistry.get_def(material_id)
	Sfx.play(&"hit", randf_range(0.85, 1.15) * (1.2 if crit else 1.0), -8.0, 0.05)
	if removed > 0:
		Sfx.play(&"break", randf_range(0.8, 1.2) - minf(0.3, def.hardness * 0.02), -6.0, 0.09)
	fx.hit(point, def, -drill.facing, crit)
	if removed > 0:
		fx.emit_burst(point, def.color_base, mini(2 + removed, 10), 200.0, 0.5, 5.0, 900.0)
	overlay.notify_hit(point, crit)
	camera.add_shake(0.16 if crit else 0.05)
	EventBus.block_hit.emit(point, material_id, crit)


func _on_dug(counts: Dictionary, at: Vector2) -> void:
	var removed: int = 0
	var special: bool = false
	for id: int in counts:
		removed += int(counts[id])
		if BlockRegistry.get_def(id).special != &"":
			special = true
	if special:
		fx.emit_burst(at, Color("fff2a8"), 10, 300.0, 0.8, 3.0, 150.0)
		camera.add_shake(0.25)
	GameState.register_cells_dug(removed)
	EventBus.material_dug.emit(at, counts)
	GameState.collect_drops(at, Drill.drops_for(counts))


func _on_unbreakable(point: Vector2) -> void:
	Sfx.play(&"clank", randf_range(0.9, 1.1), -6.0, 0.2)
	fx.sparks(point, 5)
	camera.add_shake(0.08)


func _on_resources_collected(at: Vector2, gained: Dictionary) -> void:
	Sfx.play(&"pickup", randf_range(0.95, 1.1), -8.0, 0.12)
	pickups.show_gain(at + Vector2(0, -16), gained)


func _on_modules_changed(equipped: Array[StringName]) -> void:
	drill.modules.set_equipped(equipped)


func _on_boost_started() -> void:
	Sfx.play(&"boost")
	fx.emit_burst(drill.position, Color(0.5, 0.85, 1.0), 24, 320.0, 0.6, 4.0, 0.0)
	camera.add_shake(0.35)
	EventBus.boost_started.emit()
