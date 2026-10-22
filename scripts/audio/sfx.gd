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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_all()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_drill = _loop_player(&"drill")
	_engine = _loop_player(&"engine")


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
	var paused: bool = get_tree().paused
	var dt: float = clampf(delta * 8.0, 0.0, 1.0)
	var dv: float = -6.0 if (_drill_on and not paused) else -60.0
	_drill.volume_db = lerpf(_drill.volume_db, dv, dt)
	_drill.pitch_scale = lerpf(_drill.pitch_scale, _drill_pitch, dt)
	var ev: float = -16.0 if (_engine_on and not paused) else -60.0
	_engine.volume_db = lerpf(_engine.volume_db, ev, dt)


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
	# Coleta: dois toques subindo.
	_streams[&"pickup"] = _synth(0.16, false, func(t: float, _i: int) -> float:
		var f: float = 880.0 if t < 0.07 else 1320.0
		return _square(t * f) * 0.35 * exp(-fposmod(t, 0.07) * 30.0), 0.5)
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
