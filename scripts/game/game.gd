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
	drill.block_hit.connect(_on_block_hit)
	drill.block_destroyed.connect(_on_block_destroyed)
	drill.blocked_by_unbreakable.connect(_on_unbreakable)
	input.drill = drill
	EventBus.stats_changed.connect(_apply_stats)
	EventBus.resources_collected.connect(_on_resources_collected)
	EventBus.modules_changed.connect(_on_modules_changed)
	drill.boost_started.connect(_on_boost_started)
	drill.modules.pulse_fired.connect(func(_c: Vector2, _r: float, crit: bool) -> void:
		camera.add_shake(0.45 if crit else 0.3))
	module_fx.setup(drill)


## start_row >= 0 (apenas debug) abre um bolsão e começa naquela profundidade.
func start_run(world_seed: int, start_row: int = -1) -> void:
	if world != null:
		world.shutdown()
	world = WorldModel.new(world_seed)
	background.setup(world_seed)
	var spawn := Vector2i(Balance.WORLD_WIDTH >> 1, -1)
	if start_row >= 0:
		spawn.y = start_row
		world.set_block(spawn, BlockRegistry.AIR)
		world.set_block(spawn + Vector2i.UP, BlockRegistry.AIR)
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


func _on_block_hit(cell: Vector2i, block_id: int, damage: float, crit: bool, destroyed: bool) -> void:
	var def: BlockDef = BlockRegistry.get_def(block_id)
	var center: Vector2 = WorldModel.cell_center(cell)
	var dir := Vector2(drill.drill_dir)
	if not destroyed:
		fx.hit(center - dir * Balance.BLOCK_PX * 0.45, def, dir, crit)
		overlay.notify_hit(center - dir * Balance.BLOCK_PX * 0.42, crit)
	if crit:
		camera.add_shake(0.18)
	EventBus.block_hit.emit(cell, block_id, damage, crit)


func _on_block_destroyed(cell: Vector2i, block_id: int) -> void:
	var def: BlockDef = BlockRegistry.get_def(block_id)
	fx.break_block(WorldModel.cell_center(cell), def)
	camera.add_shake(0.32 if def.special != &"" else 0.22)
	GameState.register_block_broken()
	EventBus.block_destroyed.emit(cell, block_id, def.drops.duplicate())
	GameState.collect_drops(cell, def.drops)


func _on_unbreakable(cell: Vector2i) -> void:
	var dir := Vector2(drill.drill_dir)
	fx.sparks(WorldModel.cell_center(cell) - dir * Balance.BLOCK_PX * 0.5, 5)
	camera.add_shake(0.08)


func _apply_stats() -> void:
	drill.stats = GameState.stats


func _on_resources_collected(cell: Vector2i, gained: Dictionary) -> void:
	pickups.show_gain(WorldModel.cell_center(cell) + Vector2(0, -Balance.BLOCK_PX * 0.3), gained)


func _on_modules_changed(equipped: Array[StringName]) -> void:
	drill.modules.set_equipped(equipped)


func _on_boost_started() -> void:
	fx.emit_burst(drill.position, Color(0.5, 0.85, 1.0), 16, 260.0, 0.5, 4.0, 0.0)
	camera.add_shake(0.2)
	EventBus.boost_started.emit()
