extends Node
## Estado do jogo: perfil (economia, upgrades, progresso por região) e a exploração atual
## (região, seed, profundidade). Toda mutação passa por aqui para que os eventos sejam
## publicados no EventBus. O perfil é salvo pelo SaveService.

var world_seed: int = 0
var depth_m: int = 0
var max_depth_m: int = 0
var biome_id: int = BiomeRegistry.CRUST
var blocks_broken: int = 0     ## Volume escavado em blocos (células ÷ CELLS_PER_BLOCK).
var cells_dug: int = 0
var economy := Economy.new()
var stats: DrillStats = DrillStats.base()
## Região da exploração atual.
var region_id: StringName = RegionRegistry.VALE
## Profundidade máxima alcançada em cada região: { id: metros }.
var region_progress: Dictionary = {}
## Verdadeiro depois que uma exploração começou nesta sessão.
var dive_active: bool = false


## Perfil novo (sem salvamento): economia zerada, apenas a primeira região liberada.
func reset_profile() -> void:
	economy = Economy.new()
	region_progress = {}
	region_id = RegionRegistry.VALE
	_refresh_stats()


## Inicia uma exploração na região (mundo novo; mantém economia, upgrades e progresso).
## Compatibilidade: new_run(seed) explora a região atual.
func new_run(p_seed: int = -1) -> void:
	start_dive(region_id, p_seed)


func start_dive(id: StringName, p_seed: int = -1) -> void:
	if p_seed < 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		p_seed = rng.randi() & 0x7FFFFFFF
	region_id = RegionRegistry.get_def(id).id
	apply_region()
	world_seed = p_seed
	depth_m = 0
	max_depth_m = 0
	blocks_broken = 0
	cells_dug = 0
	biome_id = BiomeRegistry.CRUST
	dive_active = true
	EventBus.run_started.emit(world_seed)
	EventBus.region_changed.emit(region_id)
	EventBus.depth_changed.emit(depth_m, max_depth_m)
	EventBus.biome_changed.emit(biome_id)
	_refresh_stats()


func region() -> RegionDef:
	return RegionRegistry.get_def(region_id)


## Ativa camadas, calor e cores da região atual.
func apply_region() -> void:
	var r: RegionDef = region()
	BiomeRegistry.set_layers(r.layers)
	HeatRules.heat_start_m = r.heat_start_m
	TerrainTextures.apply_layers(r.layers)


func region_depth(id: StringName) -> int:
	return int(region_progress.get(id, 0))


func is_region_unlocked(id: StringName) -> bool:
	return RegionRegistry.is_unlocked(RegionRegistry.get_def(id), region_progress)


func _refresh_stats() -> void:
	stats = Progression.build_stats(economy.upgrade_levels)
	_emit_economy()
	EventBus.stats_changed.emit()
	EventBus.modules_changed.emit(economy.equipped_modules)


# --- Perfil (salvamento) ---------------------------------------------------------

func to_profile() -> Dictionary:
	var prog: Dictionary = {}
	for k: StringName in region_progress:
		prog[String(k)] = int(region_progress[k])
	return {
		"schema": SaveFile.SCHEMA_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"economy": economy.to_dict(),
		"region": String(region_id),
		"regions": prog,
	}


## Aplica um perfil já validado por SaveFile (valores desconhecidos são descartados).
func apply_profile(d: Dictionary) -> void:
	economy = Economy.from_dict(d.get("economy", {}))
	region_progress = {}
	var prog: Variant = d.get("regions", {})
	if prog is Dictionary:
		for k: Variant in prog:
			var id := StringName(str(k))
			if RegionRegistry.get_def(id).id == id:
				region_progress[id] = clampi(int(prog[k]), 0, Balance.MAX_DEPTH_ROWS)
	var rid := StringName(str(d.get("region", "")))
	region_id = rid if RegionRegistry.get_def(rid).id == rid and is_region_unlocked(rid) else RegionRegistry.VALE
	_refresh_stats()


func update_depth(d: int) -> void:
	if d == depth_m:
		return
	depth_m = d
	max_depth_m = maxi(max_depth_m, d)
	EventBus.depth_changed.emit(depth_m, max_depth_m)
	if d > region_depth(region_id):
		var before: int = region_depth(region_id)
		region_progress[region_id] = d
		# Avisa a cada 10 m de recorde (salvamento) e quando desbloqueia uma região.
		if d / 10 != before / 10:
			EventBus.region_progress_changed.emit(region_id, d)
		for r in RegionRegistry.all():
			if r.unlock_region == region_id and before < r.unlock_depth_m and d >= r.unlock_depth_m:
				EventBus.region_unlocked.emit(r.id)
	var b: int = BiomeRegistry.id_for_row(d)
	if b != biome_id:
		biome_id = b
		EventBus.biome_changed.emit(biome_id)


func register_cells_dug(n: int) -> void:
	cells_dug += n
	blocks_broken = cells_dug / Balance.CELLS_PER_BLOCK


# --- Economia -------------------------------------------------------------------

## Coleta os drops de um bloco aplicando o multiplicador de Coleta.
func collect_drops(at: Vector2, drops: Dictionary) -> Dictionary:
	var gained: Dictionary = economy.collect(drops, stats.collect_mult)
	if not gained.is_empty():
		EventBus.resources_collected.emit(at, gained)
		_emit_economy()
	return gained


func sell_cargo() -> int:
	var value: int = economy.sell_all()
	if value > 0:
		EventBus.cargo_sold.emit(value)
	_emit_economy()
	return value


func buy_upgrade(id: StringName) -> bool:
	var def: UpgradeDef = UpgradeRegistry.get_def(id)
	if def == null or not Progression.try_buy(economy, def):
		return false
	stats = Progression.build_stats(economy.upgrade_levels)
	# Primeiro nível de um módulo: equipa automaticamente se houver slot livre.
	if id in ModuleSystem.ALL and economy.get_level(id) == 1 and not economy.equipped_modules.has(id):
		if economy.toggle_module(id, Balance.MODULE_SLOTS):
			EventBus.modules_changed.emit(economy.equipped_modules)
	EventBus.upgrade_purchased.emit(id, economy.get_level(id))
	EventBus.stats_changed.emit()
	_emit_economy()
	return true


func toggle_module(id: StringName) -> bool:
	if not economy.toggle_module(id, Balance.MODULE_SLOTS):
		return false
	EventBus.modules_changed.emit(economy.equipped_modules)
	return true


func _emit_economy() -> void:
	EventBus.wallet_changed.emit(economy.credits, economy.crystals)
	EventBus.cargo_changed.emit(economy.cargo_count(), economy.cargo_value())
