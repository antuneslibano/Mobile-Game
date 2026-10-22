extends Node
## Barramento global de eventos de jogo. Só declara sinais; não guarda estado.

signal run_started(world_seed: int)
## Golpe da broca (ou de módulo) em material.
signal block_hit(point: Vector2, material_id: int, crit: bool)
## Células removidas: material → quantidade (volume de 1 bloco = CELLS_PER_BLOCK).
signal material_dug(at: Vector2, counts: Dictionary)
signal depth_changed(depth_m: int, max_depth_m: int)
signal biome_changed(biome_id: int)

# Fase 2 — economia
signal resources_collected(at: Vector2, gained: Dictionary)
signal wallet_changed(credits: int, crystals: int)
signal cargo_changed(item_count: int, value: int)
signal cargo_sold(credits_gained: int)
signal upgrade_purchased(id: StringName, new_level: int)
signal stats_changed
signal garage_opened
signal garage_closed

# Fase 3 — módulos, energia, calor
signal modules_changed(equipped: Array[StringName])
signal boost_started
signal overdrive_ready
signal heat_changed(heat: float, penalty: float)

# Regiões e salvamento
signal region_changed(region_id: StringName)
signal region_progress_changed(region_id: StringName, max_depth_m: int)
signal region_unlocked(region_id: StringName)
signal map_opened
signal map_closed

# Expedições (0.9)
signal expedition_started(region_id: StringName)
signal expedition_ended(report: Dictionary)
## A nave entrou na câmara final (uma vez por expedição); guardian_alive = o guardião ainda vive.
signal final_chamber_reached(region_id: StringName, guardian_alive: bool)
## Algo acertou a nave (guardião ou criatura; dano no casco).
signal ship_hit(damage: float)
## A nave entrou/saiu do modo de combate (arena do guardião).
signal guardian_combat(active: bool)
signal objective_completed(region_id: StringName, objective_id: StringName, text: String)
signal region_completed(region_id: StringName)

# Visual da nave (0.11)
signal looks_changed

# Criaturas (0.11)
signal creature_discovered(species: StringName)
signal creature_defeated(species: StringName)

# 0.12
## Minério acima do nível da broca (id do bloco).
signal drill_too_weak(block_id: int)
## Baú aberto: raridade (0 comum, 1 raro, 2 lendário), recompensa e planta (ou &"").
signal chest_opened(rarity: int, blueprint: StringName)
