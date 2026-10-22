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

# --- Expedições (0.9) ---
## Seed do perfil: cada região tem mapa fixo derivado dela (mundo persistente).
var profile_seed: int = 0
## Regiões liberadas e regiões com a câmara final concluída: { id: true }.
var unlocked: Dictionary = {}
var done: Dictionary = {}
## Objetivos concluídos: { id: { objetivo: true } }.
var objectives_done: Dictionary = {}
## Estatísticas por região: { id: { "res": { recurso: n }, "clean": n } }.
var region_stats: Dictionary = {}
## Escavação salva por região (codificada): { id: { chunk: base64 } }.
var world_mods: Dictionary = {}
## Expedição em andamento.
var expedition_active: bool = false
var expedition_start_cargo: Dictionary = {}
var expedition_events: PackedStringArray = []
var expedition_reached_final: bool = false
## Aviso para mostrar na base ao carregar (ex.: expedição interrompida).
var pending_notice: String = ""
## Entradas do diário já vistas no Laboratório (o resto aparece como novidade na base).
var journal_seen: int = 0
## Visual escolhido no Hangar ({encaixe: opção}; vazio = automático) e quantas opções o
## jogador já viu liberadas (alerta do Hangar).
var looks: Dictionary = {}
var looks_seen: int = 0
## Criaturas catalogadas: { espécie: { "seen": true, "defeated": n } }.
var creatures: Dictionary = {}
## Quantas vezes cada região foi trocada por uma área nova ({id: n}).
var region_variant: Dictionary = {}


## Perfil novo (sem salvamento): economia zerada, apenas a primeira região liberada.
func reset_profile() -> void:
	economy = Economy.new()
	region_progress = {}
	region_id = RegionRegistry.VALE
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	profile_seed = rng.randi() & 0x7FFFFFFF
	unlocked = {RegionRegistry.VALE: true}
	done = {}
	objectives_done = {}
	region_stats = {}
	world_mods = {}
	expedition_active = false
	pending_notice = ""
	journal_seen = 0
	looks = {}
	_look_cache = {}
	looks_seen = 0
	creatures = {}
	region_variant = {}
	_refresh_stats()


## Inicia uma exploração na região (mundo novo; mantém economia, upgrades e progresso).
## Compatibilidade: new_run(seed) explora a região atual.
func new_run(p_seed: int = -1) -> void:
	start_dive(region_id, p_seed)


func start_dive(id: StringName, p_seed: int = -1) -> void:
	region_id = RegionRegistry.get_def(id).id
	if p_seed < 0:
		p_seed = region_seed(region_id)
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
	TerrainTextures.apply_region(r)


func region_depth(id: StringName) -> int:
	return int(region_progress.get(id, 0))


func is_region_unlocked(id: StringName) -> bool:
	return unlocked.has(id) or RegionRegistry.is_unlocked(RegionRegistry.get_def(id), done)


## Mapa fixo de cada região, derivado da seed do perfil (mundo persistente).
func region_seed(id: StringName) -> int:
	var v: int = int(region_variant.get(id, 0))
	if v == 0:
		return (hash([profile_seed, String(id)]) & 0x7FFFFFFF)
	return (hash([profile_seed, String(id), v]) & 0x7FFFFFFF)


## "Explorar nova área" (0.12): troca o mapa da região por um novo. A escavação e o recorde
## de profundidade da área anterior são apagados; objetivos, guardião vencido, catálogo e
## o que já está no armazém continuam.
func new_area(id: StringName) -> void:
	region_variant[id] = int(region_variant.get(id, 0)) + 1
	world_mods.erase(id)
	region_progress.erase(id)
	SaveService.mark_dirty()


func is_objective_done(id: StringName, obj_id: StringName) -> bool:
	return (objectives_done.get(id, {}) as Dictionary).has(obj_id)


## Progresso de um objetivo: x = atual, y = alvo.
func objective_progress(id: StringName, o: Dictionary) -> Vector2:
	var target: float = float(o.target)
	if is_objective_done(id, o.id):
		return Vector2(target, target)
	match o.kind:
		&"collect":
			return Vector2(minf(target, float(_rstats(id).res.get(String(o.key), 0))), target)
		&"clean":
			return Vector2(minf(target, float(_rstats(id).clean)), target)
	return Vector2(0.0, target)


## Fração dos objetivos concluídos na região (barra do mapa).
func region_completion(id: StringName) -> float:
	var r: RegionDef = RegionRegistry.get_def(id)
	if r.objectives.is_empty():
		return 0.0
	return float((objectives_done.get(id, {}) as Dictionary).size()) / r.objectives.size()


func stars(id: StringName) -> int:
	var n: int = 0
	for o: Dictionary in RegionRegistry.get_def(id).objectives:
		if o.group == &"star" and is_objective_done(id, o.id):
			n += 1
	return n


func _rstats(id: StringName) -> Dictionary:
	if not region_stats.has(id):
		region_stats[id] = {"res": {}, "clean": 0}
	return region_stats[id]


func complete_objective(id: StringName, obj_id: StringName) -> void:
	if is_objective_done(id, obj_id):
		return
	var o: Dictionary = RegionRegistry.objective(RegionRegistry.get_def(id), obj_id)
	if o.is_empty():
		return
	if not objectives_done.has(id):
		objectives_done[id] = {}
	objectives_done[id][obj_id] = true
	expedition_events.append(String(o.text))
	EventBus.objective_completed.emit(id, obj_id, String(o.text))


# --- Expedição ------------------------------------------------------------------

func begin_expedition() -> void:
	expedition_active = true
	expedition_start_cargo = economy.cargo.duplicate()
	expedition_events = PackedStringArray()
	expedition_reached_final = false
	EventBus.expedition_started.emit(region_id)


## Nave em (blocos x, profundidade): avisa uma vez por expedição ao entrar na câmara final.
func check_final_chamber(block_x: int, depth: int) -> void:
	var r: RegionDef = region()
	if expedition_reached_final or depth < RegionRegistry.chamber_top(r) + 1:
		return
	if absi(block_x - RegionRegistry.chamber_center_x()) > Balance.FINAL_CHAMBER_HALF_WIDTH:
		return
	expedition_reached_final = true
	EventBus.final_chamber_reached.emit(r.id, not done.has(r.id))


## Guardião da câmara final vencido: conclui a região e libera a próxima.
## hull_ratio = casco restante (estrela "guardian" com mais da metade).
func complete_region(hull_ratio: float) -> void:
	var r: RegionDef = region()
	if done.has(r.id):
		return
	done[r.id] = true
	economy.tech = done.size()
	complete_objective(r.id, &"final")
	if hull_ratio >= 0.5:
		complete_objective(r.id, &"guardian")
	EventBus.region_completed.emit(r.id)
	for nr in RegionRegistry.all():
		if nr.unlock_region == r.id and not unlocked.has(nr.id):
			unlocked[nr.id] = true
			EventBus.region_unlocked.emit(nr.id)


## Fecha a expedição. rescued = resgate de emergência (perde parte da carga desta
## expedição). mods = escavação do mundo (salva por região). Retorna o relatório.
func end_expedition(rescued: bool, reason: StringName = &"extract", mods: Dictionary = {}) -> Dictionary:
	var kept: Dictionary = {}
	var lost: Dictionary = {}
	var value_kept: int = 0
	var value_lost: int = 0
	for k: StringName in economy.cargo.keys():
		var gained: int = int(economy.cargo[k]) - int(expedition_start_cargo.get(k, 0))
		if gained <= 0:
			continue
		var loss: int = floori(gained * (1.0 - Balance.RESCUE_KEEP_RATIO)) if rescued else 0
		var price: int = ResourceRegistry.get_def(k).sell_value
		if loss > 0:
			economy.cargo[k] = int(economy.cargo[k]) - loss
			if int(economy.cargo[k]) <= 0:
				economy.cargo.erase(k)
			lost[k] = loss
			value_lost += loss * price
		kept[k] = gained - loss
		value_kept += (gained - loss) * price
	if expedition_active:
		var r: RegionDef = region()
		if not rescued:
			_rstats(r.id).clean = int(_rstats(r.id).clean) + 1
			var clean: Dictionary = RegionRegistry.objective(r, &"clean")
			if int(_rstats(r.id).clean) >= int(clean.get("target", 5)):
				complete_objective(r.id, &"clean")
			var haul: Dictionary = RegionRegistry.objective(r, &"haul")
			if value_kept >= int(haul.get("target", 1 << 30)):
				complete_objective(r.id, &"haul")
	if not mods.is_empty():
		world_mods[region_id] = encode_mods(mods)
	var report: Dictionary = {
		"region": region_id, "rescued": rescued, "reason": reason, "kept": kept, "lost": lost,
		"value_kept": value_kept, "value_lost": value_lost, "depth": max_depth_m,
		"events": expedition_events.duplicate(),
	}
	expedition_active = false
	expedition_start_cargo = {}
	_emit_economy()
	EventBus.expedition_ended.emit(report)
	return report


## Escavação → texto compacto: por chunk, base64 de (índice local u16, material u8).
static func encode_mods(mods: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for chunk: Variant in mods:
		var m: Dictionary = mods[chunk]
		var bytes := PackedByteArray()
		bytes.resize(m.size() * 3)
		var i: int = 0
		for local: Variant in m:
			var l: int = int(str(local))
			bytes[i] = l & 0xFF
			bytes[i + 1] = (l >> 8) & 0xFF
			bytes[i + 2] = int(m[local]) & 0xFF
			i += 3
		out[str(chunk)] = Marshalls.raw_to_base64(bytes)
	return out


static func decode_mods(enc: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for chunk: Variant in enc:
		var bytes: PackedByteArray = Marshalls.base64_to_raw(str(enc[chunk]))
		var m: Dictionary = {}
		for i in range(0, bytes.size() - 2, 3):
			m[str(bytes[i] | (bytes[i + 1] << 8))] = int(bytes[i + 2])
		out[str(chunk)] = m
	return out


func region_mods(id: StringName) -> Dictionary:
	return decode_mods(world_mods.get(id, {}))


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
	var objs: Dictionary = {}
	for k: StringName in objectives_done:
		var list: Array = []
		for o: Variant in objectives_done[k]:
			list.append(String(o))
		objs[String(k)] = list
	var stats_out: Dictionary = {}
	for k: StringName in region_stats:
		stats_out[String(k)] = region_stats[k]
	var exp: Dictionary = {}
	if expedition_active:
		var sc: Dictionary = {}
		for k: StringName in expedition_start_cargo:
			sc[String(k)] = int(expedition_start_cargo[k])
		exp = {"active": true, "region": String(region_id), "start_cargo": sc}
	return {
		"schema": SaveFile.SCHEMA_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"economy": economy.to_dict(),
		"region": String(region_id),
		"regions": prog,
		"seed": profile_seed,
		"unlocked": _keys(unlocked),
		"done": _keys(done),
		"objectives": objs,
		"rstats": stats_out,
		"worlds": _string_keys(world_mods),
		"expedition": exp,
		"journal_seen": journal_seen,
		"looks": _string_keys(looks),
		"looks_seen": looks_seen,
		"creatures": _string_keys(creatures),
		"variants": _string_keys(region_variant),
	}


static func _keys(d: Dictionary) -> Array:
	var out: Array = []
	for k: Variant in d:
		out.append(String(k))
	return out


static func _string_keys(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in d:
		out[String(k)] = d[k]
	return out


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
	profile_seed = int(d.get("seed", 0)) if d.has("seed") else (hash(JSON.stringify(d.get("economy", {}))) & 0x7FFFFFFF)
	done = {}
	for k: Variant in _arr(d.get("done")):
		if _valid_region(k):
			done[StringName(str(k))] = true
	unlocked = {RegionRegistry.VALE: true}
	if d.has("unlocked"):
		for k: Variant in _arr(d.get("unlocked")):
			if _valid_region(k):
				unlocked[StringName(str(k))] = true
	else:
		# Salvamento anterior à 0.9: mantém liberadas as regiões da regra antiga.
		for r in RegionRegistry.all():
			if RegionRegistry.was_unlocked_by_depth(r, region_progress):
				unlocked[r.id] = true
	objectives_done = {}
	var ob: Variant = d.get("objectives", {})
	if ob is Dictionary:
		for k: Variant in ob:
			if _valid_region(k):
				var set_: Dictionary = {}
				for o: Variant in _arr(ob[k]):
					set_[StringName(str(o))] = true
				objectives_done[StringName(str(k))] = set_
	region_stats = {}
	var rs: Variant = d.get("rstats", {})
	if rs is Dictionary:
		for k: Variant in rs:
			if _valid_region(k) and rs[k] is Dictionary:
				var res: Dictionary = {}
				var src: Variant = (rs[k] as Dictionary).get("res", {})
				if src is Dictionary:
					for rk: Variant in src:
						res[str(rk)] = maxi(0, int(src[rk]))
				region_stats[StringName(str(k))] = {"res": res, "clean": maxi(0, int((rs[k] as Dictionary).get("clean", 0)))}
	world_mods = {}
	var wm: Variant = d.get("worlds", {})
	if wm is Dictionary:
		for k: Variant in wm:
			if _valid_region(k) and wm[k] is Dictionary:
				world_mods[StringName(str(k))] = wm[k]
	var rid := StringName(str(d.get("region", "")))
	region_id = rid if RegionRegistry.get_def(rid).id == rid and is_region_unlocked(rid) else RegionRegistry.VALE
	# Expedição interrompida (app fechado no meio): conta como resgate de emergência.
	expedition_active = false
	pending_notice = ""
	var exp: Variant = d.get("expedition", {})
	if exp is Dictionary and bool((exp as Dictionary).get("active", false)):
		expedition_active = true
		expedition_start_cargo = {}
		var sc: Variant = (exp as Dictionary).get("start_cargo", {})
		if sc is Dictionary:
			for k: Variant in sc:
				expedition_start_cargo[StringName(str(k))] = maxi(0, int(sc[k]))
		var report: Dictionary = end_expedition(true, &"interrupted")
		if int(report.value_lost) > 0:
			pending_notice = "Expedição interrompida: resgate de emergência (−%d créditos em carga)." % int(report.value_lost)
	economy.tech = done.size()
	journal_seen = maxi(0, int(d.get("journal_seen", 0)))
	looks_seen = maxi(0, int(d.get("looks_seen", 0)))
	region_variant = {}
	var rv: Variant = d.get("variants", {})
	if rv is Dictionary:
		for k: Variant in rv:
			if _valid_region(k):
				region_variant[StringName(str(k))] = maxi(0, int(rv[k]))
	creatures = {}
	var cr: Variant = d.get("creatures", {})
	if cr is Dictionary:
		for k: Variant in cr:
			if Creature.DEFS.has(StringName(str(k))) and cr[k] is Dictionary:
				creatures[StringName(str(k))] = {"seen": true, "defeated": maxi(0, int((cr[k] as Dictionary).get("defeated", 0)))}
	looks = {}
	_look_cache = {}
	var lk: Variant = d.get("looks", {})
	if lk is Dictionary:
		for k: Variant in lk:
			if StringName(str(k)) in ShipLooks.SLOTS:
				looks[StringName(str(k))] = StringName(str(lk[k]))
	# Salvamento anterior à 0.10: o que já foi coletado na região conta como descoberto.
	for stats_id: StringName in region_stats:
		for k: Variant in (region_stats[stats_id] as Dictionary).get("res", {}):
			if ResourceRegistry.get_def(StringName(str(k))) != null:
				economy.discovered[StringName(str(k))] = true
	_refresh_stats()


static func _arr(v: Variant) -> Array:
	return v if v is Array else []


static func _valid_region(k: Variant) -> bool:
	var id := StringName(str(k))
	return RegionRegistry.get_def(id).id == id


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
		_count_research(gained)
		EventBus.resources_collected.emit(at, gained)
		_emit_economy()
	return gained


## Objetivos de pesquisa: recursos acumulados na região (inclusive Cristais).
func _count_research(gained: Dictionary) -> void:
	var res: Dictionary = _rstats(region_id).res
	for k: Variant in gained:
		res[str(k)] = int(res.get(str(k), 0)) + int(gained[k])
	for o: Dictionary in region().objectives:
		if o.kind == &"collect" and not is_objective_done(region_id, o.id) and int(res.get(String(o.key), 0)) >= int(o.target):
			complete_objective(region_id, o.id)


## Baú aberto (Chests.open): recompensa e, se houver, planta de visual exclusivo.
func open_chest(rarity: int, res: Dictionary, at: Vector2) -> void:
	var drops: Dictionary = {}
	for k: Variant in res.drops:
		drops[k] = float(res.drops[k])
	collect_drops(at, drops)
	var bp: StringName = StringName(res.get("blueprint", &""))
	if bp != &"":
		economy.blueprints[bp] = true
		expedition_events.append("Planta encontrada: %s" % Chests.BLUEPRINTS[bp][1])
		SaveService.mark_dirty()
	EventBus.chest_opened.emit(rarity, bp)


## Criatura avistada (catálogo). Retorna true na primeira vez.
func see_creature(species: StringName) -> bool:
	if creatures.has(species):
		return false
	creatures[species] = {"seen": true, "defeated": 0}
	expedition_events.append("Nova criatura catalogada: %s" % Creature.DEFS[species].name)
	EventBus.creature_discovered.emit(species)
	return true


## Criatura vencida: conta no catálogo e rende amostras biológicas.
func defeat_creature(species: StringName, at: Vector2) -> void:
	see_creature(species)
	creatures[species].defeated = int(creatures[species].defeated) + 1
	var n: int = int(Creature.DEFS[species].samples)
	if n > 0:
		collect_drops(at, {&"bio_sample": float(n)})
	EventBus.creature_defeated.emit(species)


## Visual efetivo da nave (escolhas do Hangar + melhor opção liberada).
## Guardado por meio segundo (desempenho: as telas pedem isto a cada quadro).
func ship_look() -> Dictionary:
	var now: int = Time.get_ticks_msec()
	if _look_cache.is_empty() or now - _look_at > 500:
		_look_cache = ShipLooks.resolve(looks, economy, done)
		_look_at = now
	return _look_cache


var _look_cache: Dictionary = {}
var _look_at: int = 0


func set_look(slot: StringName, option: StringName) -> bool:
	for o: Array in ShipLooks.OPTIONS.get(slot, []):
		if o[0] == option and ShipLooks.is_unlocked(String(o[2]), economy, done):
			looks[slot] = option
			_look_cache = {}
			EventBus.looks_changed.emit()
			SaveService.mark_dirty()
			return true
	return false


## Mercado: vende um recurso (n unidades; -1 = tudo).
func sell_resource(key: StringName, n: int = -1) -> int:
	var value: int = economy.sell(key, int(economy.cargo.get(key, 0)) if n < 0 else n)
	if value > 0:
		EventBus.cargo_sold.emit(value)
	_emit_economy()
	return value


## Mercado: vende só o que a Bancada não precisa (reserva do próximo nível de cada peça).
func sell_surplus() -> int:
	var value: int = economy.sell_surplus(Recipes.reserve(economy.upgrade_levels))
	if value > 0:
		EventBus.cargo_sold.emit(value)
	_emit_economy()
	return value


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
