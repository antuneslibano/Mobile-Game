extends Node
## Sons do jogo (0.12), sintetizados em código na inicialização (sem arquivos de áudio):
## loop da broca (motor + dentes triturando), zumbido do motor, golpes, bloco quebrando,
## batida metálica (rocha-mãe / minério duro demais), coleta, baú, casco atingido,
## criatura vencida e Sobrecarga. Autoload "Sfx": play(nome) e drill(ativa, tom).

const RATE: int = 22050
const VOICES: int = 10

var _streams: Dictionary = {}          ## nome → AudioStreamWAV
var _voices: Array[AudioStreamPlayer] = []
var _next: int = 0
var _drill: AudioStreamPlayer
var _engine: AudioStreamPlayer
var _drill_on: bool = false
var _drill_pitch: float = 1.0
var _engine_on: bool = false
var _last: Dictionary = {}             ## nome → último tempo tocado (limite de repetição)
var enabled: bool = true
var _music: AudioStreamPlayer
## Trilha pronta (gerada numa thread na abertura).
var music_ready: bool = false
var _music_task: int = -1
var _music_synth: MusicSynth = null
var _music_wav: AudioStreamWAV = null  ## Escrita pela thread; lida depois que ela termina.
## Tema do guardião (0.18): gerado depois da trilha principal; toca em crossfade quando a
## nave chega perto da câmara final (set_boss_mode).
var _boss: AudioStreamPlayer
var _boss_task: int = -1
var _boss_synth: BossSynth = null
var _boss_wav: AudioStreamWAV = null
var boss_ready: bool = false
var boss_mode: bool = false
const BOSS_DB_BOOST: float = 3.0   ## O tema do guardião um pouco mais alto que a trilha.
## Volume da máquina (loops da broca e do motor). 0.15: metade do que era (-6 dB).
const DRILL_DB: float = -12.0
const ENGINE_DB: float = -22.0
## A trilha (normalizada) toca com 25% do volume da broca: -12 dB abaixo dela.
const MUSIC_REL: float = 0.25
var music_db: float = DRILL_DB + linear_to_db(MUSIC_REL)

## Configurações (0.16): volume por canal de áudio, 0..1, salvo à parte do perfil.
const SETTINGS_PATH: String = "user://deepforge_settings.json"
const CHANNELS: Array[StringName] = [&"music", &"sfx", &"machine"]
const BUS_NAMES: Dictionary = {&"music": "Musica", &"sfx": "Efeitos", &"machine": "Maquina"}
var volumes: Dictionary = {&"music": 1.0, &"sfx": 1.0, &"machine": 1.0}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	load_settings()
	_build_all()
	EventBus.cargo_sold.connect(func(_v: int) -> void: play(&"coin", randf_range(0.97, 1.03)))
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_NAMES[&"sfx"]
		add_child(p)
		_voices.append(p)
	_drill = _loop_player(&"drill")
	_engine = _loop_player(&"engine")
	_drill.bus = BUS_NAMES[&"machine"]
	_engine.bus = BUS_NAMES[&"machine"]
	_music = AudioStreamPlayer.new()
	_music.volume_db = -80.0
	_music.bus = BUS_NAMES[&"music"]
	add_child(_music)
	_boss = AudioStreamPlayer.new()
	_boss.volume_db = -80.0
	_boss.bus = BUS_NAMES[&"music"]
	add_child(_boss)
	if Guard.compat_level >= 2:
		# Compatibilidade nível 2+: sem trilha sonora.
		music_ready = true
	elif Guard.compat:
		# Modo de compatibilidade: sem threads; a trilha é gerada aos poucos, por quadro.
		_music_synth = MusicSynth.new()
	else:
		_music_task = WorkerThreadPool.add_task(_build_music_thread)
		_boss_task = WorkerThreadPool.add_task(_build_boss_thread)


## Tema do guardião gerado de uma vez, numa thread de trabalho.
func _build_boss_thread() -> void:
	var m := BossSynth.new()
	m.fill(m.n * 8)
	m.fill(m.n * 8)
	_boss_wav = m.result()


## Liga/desliga o tema do guardião (a troca é um crossfade de ~2 s).
func set_boss_mode(on: bool) -> void:
	if on:
		Guard.mark("tema do guardião")
	boss_mode = on


## Trilha ambiente (MusicSynth) gerada de uma vez, numa thread de trabalho.
func _build_music_thread() -> void:
	var m := MusicSynth.new()
	m.fill(m.n * 8)
	m.fill(m.n * 8)
	_music_wav = m.result()


# --- Volume por canal ------------------------------------------------------------------

func _make_buses() -> void:
	for ch in CHANNELS:
		var name: String = BUS_NAMES[ch]
		if AudioServer.get_bus_index(name) >= 0:
			continue
		AudioServer.add_bus()
		var i: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, "Master")


## Muda o volume de um canal (0..1). Não salva sozinho (veja save_settings).
func set_volume(channel: StringName, v: float) -> void:
	if not volumes.has(channel):
		return
	volumes[channel] = clampf(v, 0.0, 1.0)
	_apply_volume(channel)


func get_volume(channel: StringName) -> float:
	return float(volumes.get(channel, 1.0))


func _apply_volume(channel: StringName) -> void:
	var i: int = AudioServer.get_bus_index(BUS_NAMES[channel])
	if i < 0:
		return
	var v: float = float(volumes[channel])
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


## Toca um som uma vez num canal específico (amostra na tela de Configurações).
func play_on_bus(name: StringName, channel: StringName, seconds: float = 0.6) -> void:
	if not _streams.has(name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = _streams[name]
	p.bus = BUS_NAMES.get(channel, "Master")
	p.volume_db = ENGINE_DB + 8.0 if channel == &"machine" else 0.0
	add_child(p)
	p.play()
	get_tree().create_timer(seconds, true).timeout.connect(p.queue_free)


func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if parsed is Dictionary:
			var vol: Variant = (parsed as Dictionary).get("volume", {})
			if vol is Dictionary:
				for ch in CHANNELS:
					if (vol as Dictionary).has(String(ch)):
						volumes[ch] = clampf(float(vol[String(ch)]), 0.0, 1.0)
	for ch in CHANNELS:
		_apply_volume(ch)


func save_settings() -> void:
	var vol: Dictionary = {}
	for ch in CHANNELS:
		vol[String(ch)] = snappedf(float(volumes[ch]), 0.01)
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"volume": vol}))


func _exit_tree() -> void:
	# Ao fechar o jogo: espera a trilha terminar de ser gerada antes de liberar o nó.
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
	if _boss_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_boss_task)
		_boss_task = -1


func _start_music(w: AudioStreamWAV) -> void:
	Guard.mark("trilha")
	_music.stream = w
	_music.play()
	music_ready = true


func _loop_player(name: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _streams[name]
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


## Toca um efeito. min_gap: intervalo mínimo entre repetições do mesmo som (s).
func play(name: StringName, pitch: float = 1.0, volume_db: float = 0.0, min_gap: float = 0.0) -> void:
	if not enabled or not _streams.has(name):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if min_gap > 0.0 and now - float(_last.get(name, -99.0)) < min_gap:
		return
	if not _last.has(name):
		Guard.mark("som " + String(name))  # diagnóstico: primeira vez de cada som
	_last[name] = now
	var p: AudioStreamPlayer = _voices[_next]
	_next = (_next + 1) % _voices.size()
	p.stream = _streams[name]
	p.pitch_scale = clampf(pitch, 0.3, 3.0)
	p.volume_db = volume_db
	p.play()


## Loop da broca: ligado enquanto cava; tom mais grave em material duro, agudo na Sobrecarga.
func drill(active: bool, pitch: float = 1.0) -> void:
	_drill_on = active and enabled
	_drill_pitch = pitch


func engine(active: bool) -> void:
	_engine_on = active and enabled


func _process(delta: float) -> void:
	if _music_synth != null and _music_synth.fill(3000):
		_start_music(_music_synth.result())
		_music_synth = null
		# Compatibilidade nível 1: o tema do guardião é gerado em seguida, também por quadro.
		_boss_synth = BossSynth.new()
	elif _boss_synth != null and _boss_synth.fill(3000):
		_boss.stream = _boss_synth.result()
		boss_ready = true
		_boss_synth = null
	if _boss_task >= 0 and WorkerThreadPool.is_task_completed(_boss_task):
		WorkerThreadPool.wait_for_task_completion(_boss_task)
		_boss_task = -1
		if _boss_wav != null:
			_boss.stream = _boss_wav
			boss_ready = true
	if _music_task >= 0 and WorkerThreadPool.is_task_completed(_music_task):
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
		if _music_wav != null:
			_start_music(_music_wav)
	var paused: bool = get_tree().paused
	var dt: float = clampf(delta * 8.0, 0.0, 1.0)
	var dv: float = DRILL_DB if (_drill_on and not paused) else -60.0
	_drill.volume_db = lerpf(_drill.volume_db, dv, dt)
	_drill.pitch_scale = lerpf(_drill.pitch_scale, _drill_pitch, dt)
	var ev: float = ENGINE_DB if (_engine_on and not paused) else -60.0
	_engine.volume_db = lerpf(_engine.volume_db, ev, dt)
	if music_ready:
		var boss_on: bool = boss_mode and boss_ready and enabled
		var fade: float = clampf(delta * 1.2, 0.0, 1.0)
		_music.volume_db = lerpf(_music.volume_db, -80.0 if (boss_on or not enabled) else music_db, fade)
		if boss_ready:
			if boss_on and not _boss.playing:
				_boss.play()
			_boss.volume_db = lerpf(_boss.volume_db, music_db + BOSS_DB_BOOST if boss_on else -80.0, fade)
			if not boss_on and _boss.playing and _boss.volume_db < -60.0:
				_boss.stop()


# --- Síntese -------------------------------------------------------------------------

func _build_all() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Broca: motor (serra 55/110 Hz) + dentes triturando (ruído pulsado a 25 Hz). 0,6 s, loop.
	_streams[&"drill"] = _synth(0.6, true, func(t: float, _i: int) -> float:
		var motor: float = _saw(t * 55.0) * 0.28 + _saw(t * 110.0) * 0.16 + sin(TAU * 220.0 * t) * 0.05
		var teeth: float = pow(absf(sin(PI * 25.0 * t)), 3.0)
		return motor + (rng.randf() * 2.0 - 1.0) * (0.25 + 0.45 * teeth), 0.35)
	# Motor em movimento: zumbido grave com leve ondulação. 0,5 s, loop.
	_streams[&"engine"] = _synth(0.5, true, func(t: float, _i: int) -> float:
		return (_saw(t * 45.0) * 0.4 + sin(TAU * 90.0 * t) * 0.3) * (0.8 + 0.2 * sin(TAU * 4.0 * t)), 0.2)
	# Golpe: estalo curto de ruído.
	_streams[&"hit"] = _synth(0.07, false, func(t: float, _i: int) -> float:
		return (rng.randf() * 2.0 - 1.0) * exp(-t * 60.0), 0.5)
	# Bloco quebrando: ruído grave caindo.
	_streams[&"break"] = _synth(0.16, false, func(t: float, _i: int) -> float:
		return ((rng.randf() * 2.0 - 1.0) * 0.6 + sin(TAU * (160.0 - 500.0 * t) * t) * 0.5) * exp(-t * 22.0), 0.6)
	# Batida metálica: rocha-mãe ou minério duro demais.
	_streams[&"clank"] = _synth(0.3, false, func(t: float, _i: int) -> float:
		return (sin(TAU * 900.0 * t) * 0.5 + sin(TAU * 1340.0 * t) * 0.35 + sin(TAU * 2110.0 * t) * 0.2) * exp(-t * 16.0), 0.55)
	# Ferramentas do Hangar (0.19): esponja (chiado molhado), lixa (raspar) e solda.
	_streams[&"scrub"] = _synth(0.16, false, func(t: float, _i: int) -> float:
		var n: float = rng.randf() * 2.0 - 1.0
		return (n * 0.5 + sin(TAU * (900.0 + 600.0 * sin(TAU * 18.0 * t)) * t) * 0.15) * sin(PI * t / 0.16), 0.5)
	_streams[&"sand"] = _synth(0.14, false, func(t: float, _i: int) -> float:
		var n: float = rng.randf() * 2.0 - 1.0
		var grit: float = 1.0 if fposmod(t, 0.012) < 0.006 else 0.4
		return n * grit * sin(PI * t / 0.14), 0.55)
	_streams[&"weld"] = _synth(0.12, false, func(t: float, _i: int) -> float:
		var n: float = rng.randf() * 2.0 - 1.0
		var crackle: float = 1.0 if rng.randf() < 0.15 else 0.25
		return (n * crackle + sin(TAU * 2400.0 * t) * 0.2) * exp(-t * 6.0), 0.5)
	# Acerto no guardião (0.19): baque grosso de carne-mineral (tom que cai, com
	# harmônicos que o alto-falante toca), estalo úmido e um anel de cristal rachando.
	_streams[&"boss_hit"] = _synth(0.42, false, func(t: float, _i: int) -> float:
		var f: float = 170.0 - 100.0 * minf(1.0, t * 6.0)
		var thump: float = (sin(TAU * f * t) + 0.7 * sin(TAU * f * 2.0 * t) + 0.4 * sin(TAU * f * 3.0 * t)) * exp(-t * 9.0)
		var squelch: float = (rng.randf() * 2.0 - 1.0) * exp(-t * 30.0) * 0.6
		var ring: float = (sin(TAU * 1480.0 * t) * 0.5 + sin(TAU * 2230.0 * t) * 0.3) * exp(-t * 7.0) * minf(1.0, t * 40.0)
		return thump * 0.7 + squelch + ring * 0.45, 0.75)
	# Coleta: dois toques subindo.
	_streams[&"pickup"] = _synth(0.16, false, func(t: float, _i: int) -> float:
		var f: float = 880.0 if t < 0.07 else 1320.0
		return _square(t * f) * 0.35 * exp(-fposmod(t, 0.07) * 30.0), 0.5)
	# Moedas (0.20): "tlin-tlin" metálico (dois toques agudos com parciais inarmônicas
	# e um chiado de moedas batendo).
	_streams[&"coin"] = _synth(0.42, false, func(t: float, _i: int) -> float:
		var out: float = 0.0
		for hit: Array in [[0.0, 1975.5], [0.085, 2637.0]]:
			var lt: float = t - float(hit[0])
			if lt < 0.0:
				continue
			var f: float = hit[1]
			out += (sin(TAU * f * lt) * 0.5 + sin(TAU * f * 2.76 * lt) * 0.22 + sin(TAU * f * 5.4 * lt) * 0.1) * exp(-lt * 11.0)
		var jingle: float = (rng.randf() * 2.0 - 1.0) * exp(-t * 18.0) * 0.12
		return out + jingle, 0.55)
	# Baú: arpejo brilhante.
	_streams[&"chest"] = _synth(0.5, false, func(t: float, _i: int) -> float:
		var notes: Array[float] = [523.3, 659.3, 784.0, 1046.5]
		var k: int = mini(3, int(t / 0.09))
		var lt: float = t - k * 0.09
		return (sin(TAU * notes[k] * t) * 0.5 + sin(TAU * notes[k] * 2.0 * t) * 0.15) * exp(-lt * 9.0), 0.6)
	# Casco atingido: baque grave.
	_streams[&"ship_hit"] = _synth(0.3, false, func(t: float, _i: int) -> float:
		return (sin(TAU * (90.0 - 120.0 * t) * t) * 0.8 + (rng.randf() * 2.0 - 1.0) * 0.4 * exp(-t * 30.0)) * exp(-t * 9.0), 0.8)
	# Criatura vencida: guincho descendo.
	_streams[&"creature"] = _synth(0.18, false, func(t: float, _i: int) -> float:
		return _square(t * (1300.0 - 4500.0 * t)) * 0.3 * exp(-t * 14.0), 0.45)
	# Sobrecarga: varredura subindo.
	_streams[&"boost"] = _synth(0.45, false, func(t: float, _i: int) -> float:
		return (_saw(t * (180.0 + 900.0 * t)) * 0.4) * (1.0 - t / 0.45), 0.5)
	# Sonar: "ping" de submarino com ecos.
	_streams[&"sonar"] = _synth(1.4, false, func(t: float, _i: int) -> float:
		var v: float = 0.0
		for k in 4:
			var tt: float = t - k * 0.3
			if tt >= 0.0:
				v += sin(TAU * 1150.0 * tt) * exp(-tt * 9.0) * pow(0.45, k)
		return v * 0.7, 0.6)
	# Sinal do sonar encontrando algo.
	_streams[&"blip"] = _synth(0.09, false, func(t: float, _i: int) -> float:
		return sin(TAU * 1600.0 * t) * exp(-t * 35.0), 0.45)
	# Transição de tela: sopro de ar.
	_streams[&"whoosh"] = _synth(0.28, false, func(t: float, _i: int) -> float:
		return (rng.randf() * 2.0 - 1.0) * sin(PI * t / 0.28) * 0.5, 0.35)
	# Porta de metal (0.15): chapas batendo nos trilhos ("tududu") ao descer/subir.
	_streams[&"shutter"] = _synth(0.3, false, func(t: float, _i: int) -> float:
		var ph: float = fposmod(t, 0.045)
		var tick: float = exp(-ph * 90.0)
		return ((rng.randf() * 2.0 - 1.0) * 0.6 + sin(TAU * 180.0 * t) * 0.6) * tick, 0.7)
	# Porta fechando: batida grave de metal.
	_streams[&"door_slam"] = _synth(0.35, false, func(t: float, _i: int) -> float:
		var n: float = (rng.randf() * 2.0 - 1.0) * exp(-t * 40.0)
		return (n + sin(TAU * 95.0 * t) * 0.9 + sin(TAU * 263.0 * t) * 0.35) * exp(-t * 11.0), 0.85)
	# Criaturas.
	_streams[&"firefly"] = _synth(0.22, false, func(t: float, _i: int) -> float:
		var on: float = 1.0 if fposmod(t, 0.11) < 0.05 else 0.0
		return sin(TAU * 2600.0 * t) * on * exp(-t * 6.0), 0.25)
	_streams[&"mole"] = _synth(0.2, false, func(t: float, _i: int) -> float:
		return _square(t * (800.0 + 2200.0 * t)) * 0.35 * sin(PI * t / 0.2), 0.4)
	_streams[&"spider"] = _synth(0.45, false, func(t: float, _i: int) -> float:
		var n: float = rng.randf() * 2.0 - 1.0
		return (n - lerpf(0.0, n, 0.6)) * sin(PI * t / 0.45) + sin(TAU * 3200.0 * t) * 0.05, 0.6)
	_streams[&"worm"] = _synth(0.8, false, func(t: float, _i: int) -> float:
		return (_saw(t * (55.0 + 15.0 * sin(TAU * 3.0 * t))) * 0.6 + (rng.randf() * 2.0 - 1.0) * 0.3) * sin(PI * t / 0.8), 0.55)
	_streams[&"bite"] = _synth(0.15, false, func(t: float, _i: int) -> float:
		return ((rng.randf() * 2.0 - 1.0) * 0.7 + _square(t * 180.0) * 0.3) * exp(-t * 25.0), 0.7)
	# Toque de interface.
	_streams[&"click"] = _synth(0.05, false, func(t: float, _i: int) -> float:
		return _square(t * 1200.0) * 0.3 * exp(-t * 70.0), 0.4)


static func _saw(phase: float) -> float:
	return 2.0 * fposmod(phase, 1.0) - 1.0


static func _square(phase: float) -> float:
	return 1.0 if fposmod(phase, 1.0) < 0.5 else -1.0


## Gera um AudioStreamWAV de 16 bits a partir de f(t, i) -> amostra; gain = volume final.
static func _synth(seconds: float, loop: bool, f: Callable, gain: float) -> AudioStreamWAV:
	var n: int = int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp: float = 0.0
	for i in n:
		var t: float = float(i) / RATE
		var v: float = float(f.call(t, i))
		lp += (v - lp) * 0.55   # filtro passa-baixa suave (menos chiado)
		var s: int = clampi(int(lp * gain * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w
