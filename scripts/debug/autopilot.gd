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

var _t: float = 0.0
var _intent := DrillIntent.new()
var _plan_left: float = 0.0
var _violations: int = 0
var _frames: int = 0
var _hits: int = 0
var _crits: int = 0
var _finished: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1234
	if drive:
		game.input.override_intent = _intent
	game.drill.block_hit.connect(func(_c: Vector2i, _id: int, _d: float, crit: bool, _x: bool) -> void:
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
		push_error("[autotest] perfuradora sobreposta a bloco sólido em %s" % [game.drill.position])
	if drive:
		_plan_left -= delta
		if _plan_left <= 0.0:
			var r: float = _rng.randf()
			_intent.drill = true
			if r < 0.72:
				_intent.move = 0.0
				_plan_left = 2.5
			else:
				_intent.move = -1.0 if _rng.randf() < 0.5 else 1.0
				_plan_left = 0.9
	if _t >= duration:
		_finish()


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
	var ok: bool = _violations == 0 and GameState.max_depth_m >= MIN_DEPTH_M and GameState.blocks_broken >= MIN_BLOCKS
	print("[autotest] profundidade=%dm máx=%dm blocos=%d golpes=%d críticos=%d" % [
			GameState.depth_m, GameState.max_depth_m, GameState.blocks_broken, _hits, _crits])
	print("[autotest] chunks_gerados=%d geração_média=%.3fms geração_máx=%.3fms carregados=%d renderers=%d mods=%d" % [
			w.stats_generated, avg_ms, float(w.stats_gen_max_usec) / 1000.0, w.loaded_chunk_indices().size(),
			game.terrain.active_count(), w.modified_cell_count()])
	print("[autotest] quadros=%d partículas_vivas=%d violações=%d" % [_frames, game.fx.alive_count(), _violations])
	print("[autotest] RESULTADO: %s" % ("PASSOU" if ok else "FALHOU"))
	# Aguarda capturas pendentes.
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)
