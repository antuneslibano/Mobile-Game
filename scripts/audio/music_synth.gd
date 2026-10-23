class_name MusicSynth
extends RefCounted
## Gera a trilha ambiente (24 s em loop): acordes lentos (Lá menor, Fá, Dó, Sol) uma
## oitava acima (alto-falante de celular quase não toca graves), com harmônicos médios e
## notas de sino da pentatônica. Pode gerar tudo de uma vez (numa thread) ou aos poucos,
## alguns milhares de amostras por quadro (modo de compatibilidade, sem threads).

const RATE: int = 11025
const SECONDS: float = 24.0
const CHORDS: Array = [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [261.63, 329.63, 392.0], [196.0, 246.94, 293.66]]
const BELLS: Array[float] = [440.0, 523.25, 587.33, 659.25, 783.99]
const BELL_SEQ: Array[int] = [0, 2, 4, 3, -1, 1, 0, -1, 2, 4, -1, 3, 1, -1, 0, 2]

var seconds: float = SECONDS
var n: int = int(SECONDS * RATE)
var _buf := PackedFloat32Array()
var _data := PackedByteArray()
var _i: int = 0          ## Próxima amostra a sintetizar (fase 1) ou a gravar (fase 2).
var _phase: int = 1
var _peak: float = 0.001
var _lp: float = 0.0
## Suavização do passa-baixa (subclasses mais "agressivas" usam um valor maior).
var smooth: float = 0.35


func _init(p_seconds: float = SECONDS) -> void:
	seconds = p_seconds
	n = int(seconds * RATE)
	_buf.resize(n)
	_data.resize(n * 2)


func done() -> bool:
	return _phase > 2


## Uma amostra (antes do passa-baixa e da normalização) no tempo t (s). Subclasses trocam
## isto para gerar outras trilhas (ex.: BossSynth).
func _sample(t: float) -> float:
	var seg: float = seconds / CHORDS.size()
	var bell_step: float = seconds / BELL_SEQ.size()
	var v: float = 0.0
	for c in CHORDS.size():
		# Envelope do acorde com sobreposição cíclica (loop sem emenda).
		var dt: float = fposmod(t - c * seg + seg * 0.5, seconds) - seg * 0.5
		var env: float = clampf(1.0 - absf(dt - seg * 0.5) / (seg * 0.75), 0.0, 1.0)
		if env <= 0.0:
			continue
		env = env * env * (3.0 - 2.0 * env)
		for f: float in CHORDS[c]:
			v += (sin(TAU * f * t) + 0.45 * sin(TAU * f * 2.0 * t + 0.5) + 0.25 * sin(TAU * f * 3.0 * t + 1.1) + 0.12 * sin(TAU * f * 4.0 * t + 2.0)) * env * 0.1
	var k: int = int(t / bell_step) % BELL_SEQ.size()
	if BELL_SEQ[k] >= 0:
		var bt: float = t - k * bell_step
		var bf: float = BELLS[BELL_SEQ[k]]
		v += (sin(TAU * bf * bt) + 0.3 * sin(TAU * bf * 3.01 * bt)) * exp(-bt * 2.2) * 0.12
	return v


## Processa até `budget` amostras. Retorna true quando terminou.
func fill(budget: int) -> bool:
	if _phase == 1:
		var end: int = mini(n, _i + budget)
		while _i < end:
			_lp += (_sample(float(_i) / RATE) - _lp) * smooth
			_buf[_i] = _lp
			_peak = maxf(_peak, absf(_lp))
			_i += 1
		if _i >= n:
			_phase = 2
			_i = 0
		return false
	if _phase == 2:
		# Normaliza (pico em 90%); o volume final vem do canal de música.
		var end2: int = mini(n, _i + budget * 4)
		var g: float = 0.9 * 32767.0 / _peak
		while _i < end2:
			_data.encode_s16(_i * 2, clampi(int(_buf[_i] * g), -32768, 32767))
			_i += 1
		if _i >= n:
			_phase = 3
			_buf = PackedFloat32Array()
	return done()


func result() -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = _data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w
