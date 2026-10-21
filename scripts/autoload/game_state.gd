extends Node
## Estado da corrida atual (profundidade, economia, upgrades).
## Toda mutação passa por aqui para que os eventos sejam publicados no EventBus.
## Na Fase 4 é serializado pelo SaveService.

var world_seed: int = 0
var depth_m: int = 0
var max_depth_m: int = 0
var biome_id: int = BiomeRegistry.CRUST
var blocks_broken: int = 0
var economy := Economy.new()
var stats: DrillStats = DrillStats.base()


## Inicia uma nova corrida. seed < 0 = aleatória.
func new_run(p_seed: int = -1) -> void:
	if p_seed < 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		p_seed = rng.randi() & 0x7FFFFFFF
	world_seed = p_seed
	depth_m = 0
	max_depth_m = 0
	blocks_broken = 0
	biome_id = BiomeRegistry.CRUST
	economy = Economy.new()
	stats = Progression.build_stats(economy.upgrade_levels)
	EventBus.run_started.emit(world_seed)
	EventBus.depth_changed.emit(depth_m, max_depth_m)
	EventBus.biome_changed.emit(biome_id)
	_emit_economy()
	EventBus.stats_changed.emit()
	EventBus.modules_changed.emit(economy.equipped_modules)


func update_depth(d: int) -> void:
	if d == depth_m:
		return
	depth_m = d
	max_depth_m = maxi(max_depth_m, d)
	EventBus.depth_changed.emit(depth_m, max_depth_m)
	var b: int = BiomeRegistry.id_for_row(d)
	if b != biome_id:
		biome_id = b
		EventBus.biome_changed.emit(biome_id)


func register_block_broken() -> void:
	blocks_broken += 1


# --- Economia -------------------------------------------------------------------

## Coleta os drops de um bloco aplicando o multiplicador de Coleta.
func collect_drops(cell: Vector2i, drops: Dictionary) -> Dictionary:
	var gained: Dictionary = economy.collect(drops, stats.collect_mult)
	if not gained.is_empty():
		EventBus.resources_collected.emit(cell, gained)
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
