extends RefCounted
## Simulação de balanceamento (sem cena): perfuradora real, mundo real, economia real, com
## expedições: cada uma parte da superfície (o mundo persiste: cai pelos túneis antigos sem
## gastar combustível), termina extraindo com 10% de combustível (toda a carga) ou em
## resgate de emergência (metade da carga da expedição). Na câmara final, enfrenta o
## guardião (mesmas regras do jogo). Entre expedições: vende tudo e compra o upgrade mais
## barato.
## Estratégias:
##   &"reto"      – cava para baixo (desvia na diagonal quando fica presa);
##   &"minerios"  – vai até o minério visível mais próximo (nunca para cima); com menos de
##                  meio tanque também busca carvão; sem nada à vista, cava para baixo.

const VIEW_COLS: int = 26        ## Alcance lateral de visão (células) — ~meia tela.
const VIEW_ROWS: int = 34        ## Alcance para baixo (células) — ~tela visível abaixo da nave.
const EXTRACT_AT: float = 0.10   ## Extrai com esta fração de combustível.
const BASE_TIME: float = 8.0     ## Tempo gasto na base entre expedições (s).


static func run(strategy: StringName, minutes: float, world_seed: int = 2024, region_id: StringName = RegionRegistry.VALE) -> Dictionary:
	var region: RegionDef = RegionRegistry.get_def(region_id)
	HeatRules.heat_start_m = region.heat_start_m
	var w := WorldModel.new(world_seed, region)
	w.threaded = false
	var e := Economy.new()
	var d := Drill.new()
	var stats: Dictionary = {"overdrives": 0, "first_full": -1.0, "ore_cells": 0, "terrain_cells": 0,
			"expeditions": 0, "rescues": 0, "final_at": -1.0, "refuel": 0.0, "guardian_at": -1.0, "guardian_hits": 0,
			"fuel_outs": 0, "first_trip_depth": 0}
	var guardian := FinalGuardian.new()
	guardian.setup(region, true)
	var clock: Array[float] = [0.0]   # lambdas capturam por valor: tempo compartilhado via array
	d.dug.connect(func(counts: Dictionary, _at: Vector2) -> void:
		for id: int in counts:
			if BlockRegistry.get_def(id).is_terrain():
				stats.terrain_cells += int(counts[id])
			else:
				stats.ore_cells += int(counts[id])
		e.collect(Drill.drops_for(counts), d.stats.collect_mult))
	d.refueled.connect(func(f: float) -> void: stats.refuel += f)
	d.boost_started.connect(func() -> void: stats.overdrives += 1)
	d.overdrive_ready.connect(func() -> void:
		if stats.first_full < 0.0:
			stats.first_full = clock[0])
	var intent := DrillIntent.new()
	intent.boost = true
	var dt: float = 1.0 / 60.0
	var t: float = 0.0
	var marks: Dictionary = {}
	var bought: int = 0
	var fight_dir: float = 1.0
	var max_depth: int = 0
	var limit: float = minutes * 60.0
	while t < limit:
		# --- Nova expedição (sempre da superfície) ---
		d.stats = Progression.build_stats(e.upgrade_levels)
		d.setup(w, Drill.surface_spawn(), world_seed + int(stats.expeditions))
		d.modules.set_equipped(e.equipped_modules)
		d.vitals.reset(d.stats)
		var start_cargo: Dictionary = e.cargo.duplicate()
		stats.expeditions += 1
		var stuck_t: float = 0.0
		var last_depth: int = d.depth_m()
		var last_pos: Vector2 = d.position
		var target := Vector2i(-1, -1)
		var next_scan: float = 0.0
		while t < limit:
			var aim := Vector2.DOWN
			var in_chamber: bool = guardian.alive and guardian.in_arena(d.position)
			if in_chamber:
				# Combate: anda por cima do guardião desviando das raízes avisadas.
				fight_dir = guardian.safe_dir(d.position.x, fight_dir, d.radius)
				aim = Vector2(fight_dir, 0.35).normalized()
			elif strategy == &"minerios":
				var want_fuel: bool = d.vitals.fuel_ratio() < 0.5
				var here: Vector2i = WorldModel.world_to_cell(d.position)
				if t >= next_scan or not _is_target(w.peek_cell(target), want_fuel, d.stats.drill_tier):
					target = _nearest(w, here, want_fuel, d.stats.drill_tier)
					next_scan = t + 1.0
				if target.x >= 0:
					var to: Vector2 = WorldModel.cell_center(target) - d.position
					aim = to.normalized()
					if aim.y < 0.0:
						aim = Vector2(signf(to.x), 0.0)
			if stuck_t > 4.0:
				aim = Vector2(1, 1).normalized() if int(t / 11.0) % 2 == 0 else Vector2(-1, 1).normalized()
				if stuck_t > 5.5:
					stuck_t = 0.0
					target = Vector2i(-1, -1)
					next_scan = t + 3.0
			intent.aim = aim
			d.physics_step(dt, intent)
			t += dt
			clock[0] = t
			var depth: int = d.depth_m()
			max_depth = maxi(max_depth, depth)
			if int(stats.expeditions) == 1:
				stats.first_trip_depth = maxi(int(stats.first_trip_depth), depth)
			if guardian.alive and not d.disabled:
				var hit: float = guardian.step(dt, d.position, d.radius)
				if hit > 0.0:
					d.apply_hull_damage(hit)
					stats.guardian_hits += 1
				if guardian.on_body(d.position, d.radius):
					var s: DrillStats = d.stats
					if guardian.take_damage(s.damage * s.hits_per_second * d.speed_mult * (1.0 + s.crit_chance * (s.crit_mult - 1.0)) * dt):
						stats.guardian_at = t
						w.fill_cells(guardian.body_cells(), BlockRegistry.AIR)
			if float(stats.final_at) < 0.0 and depth >= RegionRegistry.chamber_top(region) + 1 \
					and absi(floori(d.position.x / Balance.BLOCK_PX) - RegionRegistry.chamber_center_x()) <= Balance.FINAL_CHAMBER_HALF_WIDTH:
				stats.final_at = t
			if depth > last_depth or d.position.distance_to(last_pos) > 6.0:
				last_depth = maxi(last_depth, depth)
				last_pos = d.position
				stuck_t = 0.0
			else:
				stuck_t += dt
			for m: int in [25, 50, 100, 200, 300, 400, 500, 600]:
				if depth >= m and not marks.has(m):
					marks[m] = t
			if w.loaded_chunk_indices().size() > 8:
				var ci: int = WorldModel.chunk_index_for_row(floori(d.position.y / Balance.CELL_PX))
				w.unload_outside(ci - 2, ci + 3)
			if d.disabled or d.vitals.fuel_ratio() <= EXTRACT_AT or float(stats.guardian_at) == t:
				break
		# --- Fim da expedição ---
		if d.vitals.fuel_ratio() <= EXTRACT_AT or d.vitals.is_out_of_fuel():
			stats.fuel_outs += 1
		if d.disabled:
			stats.rescues += 1
			for k: StringName in e.cargo.keys():
				var gained: int = int(e.cargo[k]) - int(start_cargo.get(k, 0))
				if gained > 0:
					e.cargo[k] = int(e.cargo[k]) - floori(gained * (1.0 - Balance.RESCUE_KEEP_RATIO))
		t += BASE_TIME
		if float(stats.guardian_at) >= 0.0:
			e.tech = 1
		# Base (0.10): constrói o que der com materiais + moeda, vende só o excedente e
		# constrói de novo com os Créditos.
		bought += _build_all(e)
		e.sell_surplus(Recipes.reserve(e.upgrade_levels))
		bought += _build_all(e)
	var out: Dictionary = {
		"depth": max_depth, "earned": e.lifetime_credits, "crystals": e.crystals, "bought": bought,
		"marks": marks, "modules": e.equipped_modules.duplicate(), "levels": e.upgrade_levels.duplicate(),
		"overdrives": stats.overdrives, "first_full": stats.first_full,
		"ore_cells": stats.ore_cells, "terrain_cells": stats.terrain_cells,
		"expeditions": stats.expeditions, "rescues": stats.rescues, "final_at": stats.final_at,
		"refuel": stats.refuel, "guardian_at": stats.guardian_at, "fuel_outs": stats.fuel_outs,
		"first_trip_depth": stats.first_trip_depth, "guardian_hp": guardian.hp_ratio(), "guardian_hits": stats.guardian_hits,
	}
	d.free()
	guardian.free()
	return out


## Constrói a peça mais barata disponível, repetidamente. Retorna quantas construiu.
static func _build_all(e: Economy) -> int:
	var n: int = 0
	while true:
		var best: UpgradeDef = null
		for u in UpgradeRegistry.all():
			if Progression.buy_status(e, u) == Progression.BuyStatus.OK:
				if best == null or Progression.cost(u, e.get_level(u.id)) < Progression.cost(best, e.get_level(best.id)):
					best = u
		if best == null or not Progression.try_buy(e, best):
			return n
		n += 1
		if best.id in ModuleSystem.ALL and e.get_level(best.id) == 1:
			e.toggle_module(best.id, Balance.MODULE_SLOTS)
	return n


static func _is_ore(id: int) -> bool:
	var def: BlockDef = BlockRegistry.get_def(id)
	return def.solid and def.breakable and not def.is_terrain() and not def.drops.is_empty()


static func _is_target(id: int, want_fuel: bool, tier: int = 99) -> bool:
	if not MiningRules.can_break(id, tier):
		return false
	return _is_ore(id) or (want_fuel and BlockRegistry.get_def(id).fuel > 0.0)


## Alvo mais próximo à vista, na altura da nave ou abaixo (a nave não sobe).
static func _nearest(w: WorldModel, here: Vector2i, want_fuel: bool, tier: int = 99) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d: float = 1e9
	for dy in range(-1, VIEW_ROWS, 2):
		for dx in range(-VIEW_COLS, VIEW_COLS + 1, 2):
			var c := Vector2i(here.x + dx, here.y + dy)
			if c.x < 0 or c.x >= Balance.WORLD_CELLS_X or c.y < 0:
				continue
			if not _is_target(w.peek_cell(c), want_fuel, tier):
				continue
			var dd: float = Vector2(dx, dy * 0.8).length()
			if dd < best_d:
				best_d = dd
				best = c
	return best


static func summary(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	for m: int in r.marks:
		parts.append("%dm@%.0fs" % [m, float(r.marks[m])])
	return "%d m, ganhou %d créditos, %d upgrades, %d expedições (%d resgates, %d no limite do combustível), 1ª expedição até %d m, câmara final %s, guardião %s, combustível de carvão %.0f, Sobrecargas %d (1ª %.0fs), marcos %s" % [
		r.depth, r.earned, r.bought, r.expeditions, r.rescues, r.fuel_outs, r.first_trip_depth,
		("%.0fs" % float(r.final_at)) if float(r.final_at) >= 0.0 else "não",
		("vencido %.0fs, %d acertos na nave" % [float(r.guardian_at), int(r.guardian_hits)]) if float(r.guardian_at) >= 0.0 else ("vida %.0f%%, %d acertos" % [float(r.guardian_hp) * 100.0, int(r.guardian_hits)]),
		float(r.refuel), r.overdrives, r.first_full, ", ".join(parts)]
