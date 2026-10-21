extends Node
## Barramento global de eventos de jogo. Só declara sinais; não guarda estado.

signal run_started(world_seed: int)
signal block_hit(cell: Vector2i, block_id: int, damage: float, crit: bool)
signal block_destroyed(cell: Vector2i, block_id: int, drops: Dictionary)
signal depth_changed(depth_m: int, max_depth_m: int)
signal biome_changed(biome_id: int)

# Fase 2 — economia
signal resources_collected(cell: Vector2i, gained: Dictionary)
signal wallet_changed(credits: int, crystals: int)
signal cargo_changed(item_count: int, value: int)
signal cargo_sold(credits_gained: int)
signal upgrade_purchased(id: StringName, new_level: int)
signal stats_changed
signal garage_opened
signal garage_closed
