extends RefCounted
## Simulação de balanceamento (sem cena): perfuradora real, mundo real, economia real.
## Estratégias:
##   &"reto"      – cava para baixo (desvia na diagonal quando fica presa);
##   &"minerios"  – vai atrás do minério visível mais próximo (nunca para cima) e, sem
##                  nenhum à vista, cava para baixo.
## Nos dois casos: Sobrecarga quando a barra enche, vende a cada 15 s e compra o upgrade
## mais barato disponível.

const VIEW_COLS: int = 26        ## Alcance lateral de visão (células) — ~meia tela.
const VIEW_ROWS: int = 34        ## Alcance para baixo (células) — ~tela visível abaixo da nave.


static func run(strategy: StringName, minutes: float, world_seed: int = 2024) -> Dictionary:
	var w := WorldModel.new(world_seed)
	w.threaded = false
	var e := Economy.new()
	var d := Drill.new()
	d.stats = Progression.build_stats(e.upgrade_levels)
	d.setup(w, Drill.surface_spawn(), 3)
	var stats: Dictionary = {"overdrives": 0, "first_full": -1.0, "ore_cells": 0, "terrain_cells": 0}
	var clock: Array[float] = [0.0]   # lambdas capturam por valor: tempo compartilhado via array
	d.dug.connect(func(counts: Dictionary, _at: Vector2) -> void:
		for id: int in counts:
			if BlockRegistry.get_def(id).is_terrain():
				stats.terrain_cells += int(counts[id])
			else:
				stats.ore_cells += int(counts[id])
		e.collect(Drill.drops_for(counts), d.stats.collect_mult))
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
	var next_shop: float = 15.0
	var stuck_t: float = 0.0
	var last_depth: int = 0
	var last_pos: Vector2 = d.position
	var target := Vector2i(-1, -1)
	var next_scan: float = 0.0
	while t < minutes * 60.0:
		var aim := Vector2.DOWN
		if strategy == &"minerios":
			var here: Vector2i = WorldModel.world_to_cell(d.position)
			if t >= next_scan or not _is_ore(w.peek_cell(target)):
				target = _nearest_ore(w, here)
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
		if depth > last_depth or d.position.distance_to(last_pos) > 6.0:
			last_depth = maxi(last_depth, depth)
			last_pos = d.position
			stuck_t = 0.0
		else:
			stuck_t += dt
		for m: int in [25, 50, 100, 150, 200, 300]:
			if depth >= m and not marks.has(m):
				marks[m] = t
		if t >= next_shop:
			next_shop += 15.0
			e.sell_all()
			var bought_any: bool = true
			while bought_any:
				bought_any = false
				var best: UpgradeDef = null
				for u in UpgradeRegistry.all():
					if Progression.buy_status(e, u) == Progression.BuyStatus.OK:
						if best == null or Progression.cost(u, e.get_level(u.id)) < Progression.cost(best, e.get_level(best.id)):
							best = u
				if best != null and Progression.try_buy(e, best):
					bought += 1
					bought_any = true
					if best.id in ModuleSystem.ALL and e.get_level(best.id) == 1:
						e.toggle_module(best.id, Balance.MODULE_SLOTS)
			d.stats = Progression.build_stats(e.upgrade_levels)
			d.modules.set_equipped(e.equipped_modules)
		if w.loaded_chunk_indices().size() > 8:
			var ci: int = WorldModel.chunk_index_for_row(floori(d.position.y / Balance.CELL_PX))
			w.unload_outside(ci - 2, ci + 3)
	e.sell_all()
	var out: Dictionary = {
		"depth": d.depth_m(), "earned": e.lifetime_credits, "crystals": e.crystals, "bought": bought,
		"marks": marks, "modules": e.equipped_modules.duplicate(), "levels": e.upgrade_levels.duplicate(),
		"overdrives": stats.overdrives, "first_full": stats.first_full,
		"ore_cells": stats.ore_cells, "terrain_cells": stats.terrain_cells,
	}
	d.free()
	return out


static func _is_ore(id: int) -> bool:
	var def: BlockDef = BlockRegistry.get_def(id)
	return def.solid and def.breakable and not def.is_terrain() and not def.drops.is_empty()


## Minério mais próximo à vista, na altura da nave ou abaixo (a nave não sobe).
static func _nearest_ore(w: WorldModel, here: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d: float = 1e9
	for dy in range(-1, VIEW_ROWS, 2):
		for dx in range(-VIEW_COLS, VIEW_COLS + 1, 2):
			var c := Vector2i(here.x + dx, here.y + dy)
			if c.x < 0 or c.x >= Balance.WORLD_CELLS_X or c.y < 0:
				continue
			if not _is_ore(w.peek_cell(c)):
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
	return "%d m, ganhou %d créditos, %d cristais, %d upgrades, minério %d / terreno %d células, Sobrecargas %d (1ª %.0fs), marcos %s" % [
		r.depth, r.earned, r.crystals, r.bought, r.ore_cells, r.terrain_cells, r.overdrives, r.first_full, ", ".join(parts)]
