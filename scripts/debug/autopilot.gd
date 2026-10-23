class_name Autopilot
extends Node
## Bot de teste de sessão (ativado com --autotest=SEGUNDOS). Pilota a perfuradora,
## verifica invariantes a cada passo de física, captura telas e encerra com código de saída.

const MIN_DEPTH_M: int = 8
const MIN_BLOCKS: int = 8

var game: Game
var duration: float = 30.0
## Capturas: Array de [tempo_s, caminho_png].
var shots: Array = []
var drive: bool = true
## Vende e compra o upgrade mais barato periodicamente (simula a garagem).
var shop: bool = true
## Abre a garagem neste instante (s) para capturas; < 0 = nunca.
var open_garage_at: float = -1.0
var garage_tab_modules: bool = false
var world_map: WorldMap
var open_map_at: float = -1.0
var map_page: int = -1
var garage: Garage

var _t: float = 0.0
var _intent := DrillIntent.new()
var _plan_left: float = 0.0
var _violations: int = 0
var _frames: int = 0
var _hits: int = 0
var _crits: int = 0
var _finished: bool = false
var _rng := RandomNumberGenerator.new()
var _next_shop: float = 12.0
var _bought: int = 0
var _rises: int = 0
var _last_y: float = -INF


var _fight_dir: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1234
	if drive:
		game.input.override_intent = _intent
	game.drill.dig_hit.connect(func(_p: Vector2, _id: int, crit: bool, _r: int) -> void:
		_hits += 1
		if crit:
			_crits += 1)
	print("[autotest] início: seed=%d duração=%.0fs" % [GameState.world_seed, duration])


func _physics_process(delta: float) -> void:
	if _finished:
		return
	_t += delta
	if game.drill.is_overlapping_solid():
		_violations += 1
		push_error("[autotest] perfuradora sobreposta a material sólido em %s" % [game.drill.position])
	if game.drill.position.y < _last_y - 0.01:
		_rises += 1
		push_error("[autotest] a perfuradora subiu (%.2f → %.2f)" % [_last_y, game.drill.position.y])
	_last_y = game.drill.position.y
	var g: FinalGuardian = game.guardian
	if drive and g != null and g.alive and g.in_arena(game.drill.position):
		# Na câmara final: anda por cima do guardião desviando das raízes avisadas.
		_fight_dir = g.safe_dir(game.drill.position.x, _fight_dir, game.drill.radius)
		_intent.aim = Vector2(_fight_dir, 0.35).normalized()
		_intent.boost = true
	elif drive:
		_plan_left -= delta
		if _plan_left <= 0.0:
			# Direções livres: majoritariamente para baixo, com diagonais e laterais.
			var ang: float = PI * 0.5 + _rng.randf_range(-1.1, 1.1)
			if _rng.randf() < 0.2:
				ang = 0.0 if _rng.randf() < 0.5 else PI
			_intent.aim = Vector2.from_angle(ang)
			_plan_left = _rng.randf_range(0.8, 2.5)
		_intent.boost = true
	if shop and _t >= _next_shop:
		_next_shop += 12.0
		_shop()
	if open_map_at >= 0.0 and _t >= open_map_at and world_map != null:
		open_map_at = -1.0
		world_map.open()
		if map_page >= 0:
			world_map.go_to_page(map_page, true)
	if open_garage_at >= 0.0 and _t >= open_garage_at and garage != null:
		open_garage_at = -1.0
		garage.open()
		if garage_tab_modules:
			garage.show_modules_tab()
	if _t >= duration:
		_finish()


func _shop() -> void:
	GameState.sell_cargo()
	var progress: bool = true
	while progress:
		progress = false
		var best: UpgradeDef = null
		for u in UpgradeRegistry.all():
			if Progression.buy_status(GameState.economy, u) == Progression.BuyStatus.OK:
				if best == null or Progression.cost(u, GameState.economy.get_level(u.id)) < Progression.cost(best, GameState.economy.get_level(best.id)):
					best = u
		if best != null and GameState.buy_upgrade(best.id):
			_bought += 1
			progress = true


func _process(_delta: float) -> void:
	_frames += 1
	for shot: Array in shots:
		if shot.size() == 2 and _t >= float(shot[0]):
			var path: String = shot[1]
			shot.append(true)
			_capture(path)


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		push_warning("[autotest] captura indisponível (renderer headless?)")
		return
	var err: Error = img.save_png(path)
	print("[autotest] captura %s -> %s" % [path, error_string(err)])


func _finish() -> void:
	_finished = true
	var w: WorldModel = game.world
	var avg_ms: float = float(w.stats_gen_usec) / maxf(1.0, float(w.stats_generated)) / 1000.0
	var ok: bool = _violations == 0 and GameState.max_depth_m >= MIN_DEPTH_M and GameState.blocks_broken >= MIN_BLOCKS and _rises == 0
	print("[autotest] profundidade=%dm máx=%dm blocos=%d golpes=%d críticos=%d" % [
			GameState.depth_m, GameState.max_depth_m, GameState.blocks_broken, _hits, _crits])
	print("[autotest] chunks_gerados=%d geração_média=%.3fms geração_máx=%.3fms carregados=%d renderers=%d mods=%d" % [
			w.stats_generated, avg_ms, float(w.stats_gen_max_usec) / 1000.0, w.loaded_chunk_indices().size(),
			game.terrain.active_count(), w.modified_cell_count()])
	print("[autotest] créditos=%d cristais=%d carga=%d upgrades_comprados=%d níveis=%s" % [
			GameState.economy.credits, GameState.economy.crystals, GameState.economy.cargo_count(), _bought,
			str(GameState.economy.upgrade_levels)])
	print("[autotest] quadros=%d partículas_vivas=%d violações=%d subidas=%d energia=%.0f%%" % [_frames, game.fx.alive_count(), _violations, _rises, game.drill.energy.fill_ratio() * 100.0])
	print("[autotest] memória: estática=%.1fMB pico=%.1fMB vídeo=%.1fMB texturas=%.1fMB objetos=%d nós=%d" % [
			OS.get_static_memory_usage() / 1048576.0, OS.get_static_memory_peak_usage() / 1048576.0,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
			int(Performance.get_monitor(Performance.OBJECT_COUNT)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	print("[autotest] música: %s (tema do guardião %s)" % ["guardião" if Sfx.boss_mode else "normal", "pronto" if Sfx.boss_ready else "gerando"])
	print("[autotest] RESULTADO: %s" % ("PASSOU" if ok else "FALHOU"))
	# Aguarda capturas pendentes.
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)
