extends Node
## Barramento global de eventos de jogo. Só declara sinais; não guarda estado.

signal run_started(world_seed: int)
signal block_hit(cell: Vector2i, block_id: int, damage: float, crit: bool)
signal block_destroyed(cell: Vector2i, block_id: int, drops: Dictionary)
signal depth_changed(depth_m: int, max_depth_m: int)
signal biome_changed(biome_id: int)
