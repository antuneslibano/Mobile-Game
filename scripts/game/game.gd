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
## Extração em andamento (a nave sobe pelo cabo; física parada).
var extracting: bool = false
signal extraction_finished


func _ready() -> void:
	drill.dig_hit.connect(_on_dig_hit)
	drill.dug.connect(_on_dug)
	drill.blocked_by_unbreakable.connect(_on_unbreakable)
	drill.boost_started.connect(_on_boost_started)
	drill.overdrive_ready.connect(func() -> void: EventBus.overdrive_ready.emit())
	drill.refueled.connect(func(amount: float) -> void:
		pickups.show_text(drill.position + Vector2(0, -40), "+%d combustível" % roundi(amount), Color("ffb347")))
	drill.modules.pulse_fired.connect(func(_c: Vector2, _r: float, crit: bool) -> void:
		camera.add_shake(0.45 if crit else 0.3))
	input.drill = drill
	EventBus.stats_changed.connect(_apply_stats)
	EventBus.resources_collected.connect(_on_resources_collected)
	EventBus.modules_changed.connect(_on_modules_changed)
	module_fx.setup(drill)
	rig = ElevatorRig.new()
	rig.name = "ElevatorRig"
	add_child(rig)
	move_child(rig, drill.get_index())


## Começa uma expedição: mundo fixo da região (com a escavação salva) e a nave na
## superfície ou num elevador (start_row em metros, com o combustível já descontado).
## mods vazio = mundo intocado.
func start_run(world_seed: int, start_row: int = -1, mods: Dictionary = {}, fuel_ratio: float = 1.0) -> void:
	if world != null:
		world.shutdown()
	extracting = false
	var region: RegionDef = GameState.region()
	world = WorldModel.new(world_seed, region)
	if not mods.is_empty():
		world.import_modifications(mods)
	background.setup(world_seed, region)
	var spawn: Vector2 = Drill.surface_spawn()
	if start_row > 0:
		spawn.y = (start_row + 0.5) * Balance.BLOCK_PX
		world.fill_circle(spawn, Balance.BIT_RADIUS_PX + 6.0, BlockRegistry.AIR)
	_apply_stats()
	drill.setup(world, spawn, world_seed)
	drill.vitals.reset(drill.stats, fuel_ratio)
	drill.visible = true
	rig.show_at(spawn, start_row > 0)
	_on_modules_changed(GameState.economy.equipped_modules)
	camera.target = drill
	camera.snap_to_target()
	terrain.setup(world, camera)


## Cápsula: o cabo desce até a nave e a puxa para cima; emite extraction_finished.
func play_extraction(duration: float = 1.6) -> void:
	if world == null or extracting:
		return
	extracting = true
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
	drill.physics_step(delta, input.get_intent())
	GameState.update_depth(drill.depth_m())
	GameState.check_final_chamber(floori(drill.position.x / Balance.BLOCK_PX), drill.depth_m())


func _apply_stats() -> void:
	drill.stats = GameState.stats


func _on_dig_hit(point: Vector2, material_id: int, crit: bool, removed: int) -> void:
	var def: BlockDef = BlockRegistry.get_def(material_id)
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
	fx.sparks(point, 5)
	camera.add_shake(0.08)


func _on_resources_collected(at: Vector2, gained: Dictionary) -> void:
	pickups.show_gain(at + Vector2(0, -16), gained)


func _on_modules_changed(equipped: Array[StringName]) -> void:
	drill.modules.set_equipped(equipped)


func _on_boost_started() -> void:
	fx.emit_burst(drill.position, Color(0.5, 0.85, 1.0), 24, 320.0, 0.6, 4.0, 0.0)
	camera.add_shake(0.35)
	EventBus.boost_started.emit()
