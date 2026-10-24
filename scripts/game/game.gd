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


var shimmer: HeatShimmer
var _last_hull: float = 0.0
var _crumb_depth: int = -1
## Queda livre (0.20): tempo caindo rápido e intensidade do efeito (0..1).
var _fall_t: float = 0.0
var _fall: float = 0.0
var fall_fx: FallFx
## Combate do guardião (0.21): perseguição numa arena (mundo à parte). _region_world guarda
## o mundo da região enquanto a nave está na arena.
var chase: BossChase
var pulse: PulseOverlay
var _region_world: WorldModel
var _flash_layer: CanvasLayer
var _flash_rect: ColorRect
const FALL_SPEED_BLOCKS: float = 8.0   ## Acima disto (blocos/s, para baixo) conta como queda.
const FALL_DELAY_SEC: float = 0.3      ## Só depois deste tempo caindo o efeito começa.

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
	shimmer = HeatShimmer.new()
	shimmer.name = "HeatShimmer"
	add_child(shimmer)
	shimmer.drill = drill
	fall_fx = FallFx.new()
	fall_fx.name = "FallFx"
	drill.add_child(fall_fx)
	chase = BossChase.new()
	chase.name = "BossChase"
	chase.visible = false
	add_child(chase)
	chase.beat.connect(_on_boss_beat)
	pulse = PulseOverlay.new()
	pulse.name = "PulseOverlay"
	add_child(pulse)
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 30
	add_child(_flash_layer)
	_flash_rect = ColorRect.new()
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_layer.add_child(_flash_rect)


## Começa uma expedição: mundo fixo da região (com a escavação salva) e a nave na
## superfície (start_row > 0 só em testes). mods vazio = mundo intocado.
## guardian_defeated: o guardião da câmara final já foi vencido (núcleo aberto).
func start_run(world_seed: int, start_row: int = -1, mods: Dictionary = {}, guardian_defeated: bool = false, start_x: int = -1) -> void:
	_leave_arena()
	if world != null:
		world.shutdown()
	extracting = false
	Sfx.set_boss_mode(false)
	var region: RegionDef = GameState.region()
	world = WorldModel.new(world_seed, region)
	# Modo de compatibilidade: gera o mundo na thread principal (sem threads de trabalho).
	world.threaded = not Guard.compat
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
		if start_x > 0:
			spawn.x = (start_x + 0.5) * Balance.BLOCK_PX
		world.fill_circle(spawn, Balance.BIT_RADIUS_PX + 6.0, BlockRegistry.AIR)
	_apply_stats()
	drill.shape = GameState.ship_look().get(&"shape", &"cone")
	drill.setup(world, spawn, world_seed)
	# Desgaste (0.19): amassados fazem começar com o casco ferido; sujeira e ferrugem
	# deixam a broca mais lenta.
	drill.vitals.hull = drill.vitals.hull_max * WearRules.hull_start_ratio(GameState.wear)
	drill.wear_penalty = WearRules.penalty(GameState.wear)
	_last_hull = drill.vitals.hull
	if drill.wear_penalty >= 0.08 and start_row <= 0:
		get_tree().create_timer(2.5).timeout.connect(func() -> void:
			EventBus.wear_alert.emit(drill.wear_penalty))
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
	Guard.step("extraindo")
	Sfx.set_boss_mode(false)
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
	# Amassados: toda perda de casco (pancadas, calor, mordidas, guardião) conta.
	if drill.vitals.hull < _last_hull:
		WearRules.add_damage(GameState.wear, _last_hull - drill.vitals.hull, drill.vitals.hull_max)
	_last_hull = drill.vitals.hull
	# Diagnóstico: onde a nave está (gravado de tempos em tempos pelo Guard).
	var dm: int = drill.depth_m() / 10 * 10
	if dm != _crumb_depth:
		_crumb_depth = dm
		Guard.detail("%d m%s" % [dm, " · combate" if camera.combat else ""])
	if camera.intro and (drill.depth_m() > 0 or DrillIntent.sanitize(intent.aim).length() > 0.05):
		camera.end_intro()
	_update_fall(delta)
	if in_arena():
		_chase_step(delta)
	else:
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
	_update_boss_music()
	# 0.21: ao chegar à câmara final com o guardião vivo, a nave vai para a arena.
	if guardian.alive and not drill.disabled and not extracting and _flash_t < 0.0 and guardian.in_arena(drill.position):
		_begin_arena_transition()


## Tema do guardião (0.18): começa antes de vê-lo, a BOSS_MUSIC_RANGE_M acima da câmara
## final; para ao subir de volta (com folga, para não ficar alternando), ao vencê-lo ou
## ao extrair.
func _update_boss_music() -> void:
	var on: bool = Sfx.boss_mode
	if not guardian.alive or drill.disabled or extracting:
		on = false
	else:
		var start_m: int = RegionRegistry.chamber_top(GameState.region()) - Balance.BOSS_MUSIC_RANGE_M
		var d: int = drill.depth_m()
		if d >= start_m:
			on = true
		elif d < start_m - 15:
			on = false
	if on != Sfx.boss_mode:
		Sfx.set_boss_mode(on)


func _on_guardian_defeated() -> void:
	var c: Vector2 = chase.core if chase.active else guardian.center + Vector2(0, Balance.BLOCK_PX)
	region_world().fill_cells(guardian.body_cells(), BlockRegistry.AIR)
	for i in 5:
		fx.emit_burst(c + Vector2.from_angle(i * TAU / 5.0) * 60.0, guardian.glow_color, 20, 420.0, 1.1, 5.0, 400.0)
	fx.emit_burst(c, Color("fff2a8"), 40, 420.0, 1.0, 3.0, 150.0)
	Sfx.play(&"heartbeat", 0.7, 4.0)
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
	_apply_wear_visual()


## Nave suja e enferrujada fica mais escura e amarronzada no jogo também.
func _apply_wear_visual() -> void:
	var dirt: float = float(GameState.wear.get(&"dirt", 0.0))
	var rust: float = float(GameState.wear.get(&"rust", 0.0))
	var tint := Color.WHITE.lerp(Color(0.72, 0.62, 0.5), clampf(dirt * 0.6 + rust * 0.4, 0.0, 1.0) * 0.25)
	for c in drill.get_children():
		if c is DrillVisual:
			(c as DrillVisual).modulate = tint
			(c as DrillVisual).wear = GameState.wear


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
	# Desgaste (0.19): cada bloco quebrado suja e enferruja um pouco a nave.
	WearRules.add_dig(GameState.wear, removed)
	drill.wear_penalty = WearRules.penalty(GameState.wear)
	_apply_wear_visual()
	if special:
		fx.emit_burst(at, Color("fff2a8"), 10, 300.0, 0.8, 3.0, 150.0)
		camera.add_shake(0.25)
	# Semente do guardião (arena): cada uma quebrada fere o guardião.
	if counts.has(BlockRegistry.BOSS_SEED) and chase.active:
		Sfx.play(&"seed_pop", randf_range(0.95, 1.05))
		fx.emit_burst(at, guardian.glow_color, 30, 380.0, 0.9, 4.0, 200.0)
		camera.add_shake(0.45)
		pickups.show_text(at + Vector2(0, -40), "%d/%d" % [chase.seeds_broken + 1, chase.seeds_needed], guardian.glow_color)
		if chase.seed_broken():
			_on_guardian_defeated()
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


## Queda livre: depois de um tempo caindo rápido, a câmera aproxima, olha para baixo e
## treme de leve, com riscos de vento; ao bater no chão, um tranco.
func _update_fall(delta: float) -> void:
	var falling: bool = not drill.grounded and drill.velocity.y > FALL_SPEED_BLOCKS * Balance.BLOCK_PX and not camera.combat
	if falling:
		_fall_t += delta
	else:
		if _fall > 0.4:
			camera.add_shake(0.25 * _fall)
		_fall_t = 0.0
	var target: float = clampf((_fall_t - FALL_DELAY_SEC) / 0.8, 0.0, 1.0) if falling else 0.0
	_fall = move_toward(_fall, target, delta * (1.5 if falling else 4.0))
	camera.fall = _fall
	fall_fx.amount = _fall


# --- Arena do guardião (0.21) -----------------------------------------------------------

var _flash_t: float = -1.0
const FLASH_SEC: float = 0.7


## A nave está na arena (perseguição do guardião).
func in_arena() -> bool:
	return _region_world != null


## Mundo da região (o da arena fica à parte): é ele que vai para o salvamento.
func region_world() -> WorldModel:
	return _region_world if _region_world != null else world


## Clarão com batimento; no auge a nave passa para a arena (a troca fica escondida).
func _begin_arena_transition() -> void:
	_flash_t = 0.0
	Sfx.play(&"heartbeat", 0.85, 2.0)
	camera.add_shake(0.6)
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color:a", 1.0, FLASH_SEC * 0.45).set_ease(Tween.EASE_IN)
	tw.tween_callback(_enter_arena)
	tw.tween_property(_flash_rect, "color:a", 0.0, FLASH_SEC * 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _flash_t = -1.0)
	_flash_rect.color = Color(guardian.glow_color.lightened(0.6), 0.0)


func _enter_arena() -> void:
	if not guardian.alive or extracting or in_arena():
		return
	Guard.mark("arena do guardião")
	var depth: int = drill.depth_m()
	_region_world = world
	world = WorldModel.new(hash([GameState.world_seed, GameState.region_id, "arena"]) & 0x7FFFFFFF, GameState.region())
	world.generator.arena = true
	world.threaded = not Guard.compat
	creatures.creatures.clear()
	sonar.world = world
	sonar.reset()
	var spawn := Vector2(Balance.WORLD_CELLS_X * Balance.CELL_PX * 0.5, (WorldGenerator.ARENA_OPEN_ROWS - 2) * Balance.BLOCK_PX)
	drill.world = world
	drill.position = spawn
	drill.velocity = Vector2.ZERO
	drill.arena = true
	drill.depth_offset_m = depth - (WorldGenerator.ARENA_OPEN_ROWS - 2)
	camera.combat = false
	camera.bottom_limit = INF
	camera.arena = true
	camera.snap_to_target()
	terrain.setup(world, camera)
	var view: Rect2 = _view_rect()
	chase.start(guardian, drill.position, view)
	EventBus.guardian_combat.emit(true)


func _leave_arena() -> void:
	if _region_world == null:
		return
	if world != null:
		world.shutdown()
	world = _region_world
	_region_world = null
	chase.stop()
	camera.arena = false
	drill.arena = false
	drill.depth_offset_m = 0


func _view_rect() -> Rect2:
	var vs: Vector2 = get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - vs * 0.5, vs)


func _chase_step(delta: float) -> void:
	_update_boss_music()
	EventBus.depth_changed.emit(drill.depth_m(), maxi(GameState.max_depth_m, drill.depth_m()))
	if drill.disabled:
		return
	var hit: float = chase.step(delta, drill.position, drill.velocity, drill.radius, _view_rect())
	if hit > 0.0:
		drill.apply_hull_damage(hit)
		camera.add_shake(0.7)
		fx.emit_burst(drill.position, guardian.glow_color, 16, 300.0, 0.6, 4.0, 300.0)
		fx.emit_burst(drill.position, Color("ff5a3a"), 10, 240.0, 0.5, 3.0, 300.0)
		EventBus.ship_hit.emit(hit)
		Sfx.play(&"ship_hit")


func _on_boss_beat(strength: float) -> void:
	Sfx.play(&"heartbeat", randf_range(0.97, 1.03), -2.0 + 4.0 * strength)
	camera.add_shake(0.12 * strength)
	var screen: Vector2 = get_viewport().get_canvas_transform() * chase.core
	pulse.pulse(strength, guardian.glow_color, screen)

