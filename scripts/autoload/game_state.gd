extends Node
## Estado da corrida atual. Na Fase 4 é serializado pelo SaveService.

var world_seed: int = 0
var depth_m: int = 0
var max_depth_m: int = 0
var biome_id: int = BiomeRegistry.CRUST
var blocks_broken: int = 0


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
	EventBus.run_started.emit(world_seed)
	EventBus.depth_changed.emit(depth_m, max_depth_m)
	EventBus.biome_changed.emit(biome_id)


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
