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


func _ready() -> void:
	drill.dig_hit.connect(_on_dig_hit)
	drill.dug.connect(_on_dug)
	drill.blocked_by_unbreakable.connect(_on_unbreakable)
	drill.boost_started.connect(_on_boost_started)
	drill.overdrive_ready.connect(func() -> void: EventBus.overdrive_ready.emit())
	drill.modules.pulse_fired.connect(func(_c: Vector2, _r: float, crit: bool) -> void:
		camera.add_shake(0.45 if crit else 0.3))
	input.drill = drill
	EventBus.stats_changed.connect(_apply_stats)
	EventBus.resources_collected.connect(_on_resources_collected)
	EventBus.modules_changed.connect(_on_modules_changed)
	module_fx.setup(drill)


## start_row >= 0 (apenas debug) abre um bolsão e começa naquela profundidade (em metros).
func start_run(world_seed: int, start_row: int = -1) -> void:
	if world != null:
		world.shutdown()
	world = WorldModel.new(world_seed)
	background.setup(world_seed)
	var spawn: Vector2 = Drill.surface_spawn()
	if start_row >= 0:
		spawn.y = (start_row + 0.5) * Balance.BLOCK_PX
		world.fill_circle(spawn, Balance.BIT_RADIUS_PX + 4.0, BlockRegistry.AIR)
	_apply_stats()
	drill.setup(world, spawn, world_seed)
	_on_modules_changed(GameState.economy.equipped_modules)
	camera.target = drill
	camera.snap_to_target()
	terrain.setup(world, camera)


func _exit_tree() -> void:
	if world != null:
		world.shutdown()


func _physics_process(delta: float) -> void:
	if world == null:
		return
	drill.physics_step(delta, input.get_intent())
	GameState.update_depth(drill.depth_m())


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
