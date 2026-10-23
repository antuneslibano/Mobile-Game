class_name BossSynth
extends MusicSynth
## Tema do guardião (0.18): 16 s em loop, 120 bpm, tenso. Ostinato em escala frígia de Mi
## (cordas curtas), batida de "coração" em dois tempos, acorde dissonante (trítono) que
## cresce e diminui, e um trêmulo agudo no fim de cada frase. Tudo em médios e agudos
## (alto-falante de celular quase não toca graves).

const BOSS_SECONDS: float = 16.0
const BEAT: float = 0.5                       ## 120 bpm.
## Ostinato (Hz, 0 = pausa), uma nota por colcheia: Mi frígio com o Fá "pesando".
const RIFF: Array[float] = [329.63, 329.63, 349.23, 329.63, 392.0, 349.23, 329.63, 293.66,
		329.63, 329.63, 349.23, 329.63, 415.3, 392.0, 349.23, 0.0]
## Acordes de fundo por compasso (4 compassos de 4 s): Mi menor, Fá, Mi com trítono, Fá.
const PADS: Array = [[329.63, 392.0, 493.88], [349.23, 440.0, 523.25], [329.63, 392.0, 466.16], [349.23, 415.3, 523.25]]


func _init() -> void:
	super(BOSS_SECONDS)
	smooth = 0.5


func _sample(t: float) -> float:
	var v: float = 0.0
	# Ostinato: notas curtas com ataque rápido (cordas em staccato), 3 harmônicos.
	var eighth: float = BEAT * 0.5
	var step: int = int(t / eighth)
	var f: float = RIFF[step % RIFF.size()]
	if f > 0.0:
		var nt: float = t - step * eighth
		var env: float = minf(1.0, nt * 80.0) * exp(-nt * 9.0)
		v += (sin(TAU * f * t) + 0.6 * sin(TAU * f * 2.0 * t) + 0.35 * sin(TAU * f * 3.0 * t) + 0.2 * sin(TAU * f * 5.0 * t)) * env * 0.22
	# Coração: duas batidas por compasso (tum-tum), tom que cai de 180 Hz e um "clique".
	var bar_t: float = fposmod(t, BEAT * 4.0)
	for hit: float in [0.0, 0.28, 2.0, 2.28]:
		var ht: float = bar_t - hit
		if ht >= 0.0 and ht < 0.35:
			var hf: float = 180.0 - 110.0 * minf(1.0, ht * 8.0)
			v += (sin(TAU * hf * ht) + 0.5 * sin(TAU * hf * 2.0 * ht)) * exp(-ht * 14.0) * (0.55 if hit < 0.1 or absf(hit - 2.0) < 0.1 else 0.35)
	# Acorde de fundo que cresce ao longo do compasso.
	var bar: int = int(t / 4.0) % PADS.size()
	var swell: float = 0.35 + 0.65 * sin(PI * fposmod(t, 4.0) / 4.0)
	for pf: float in PADS[bar]:
		v += (sin(TAU * pf * t) + 0.3 * sin(TAU * pf * 2.0 * t + 0.7)) * swell * 0.06
	# Trêmulo agudo nos últimos 2 tempos de cada 2 compassos (tensão antes de repetir).
	var phrase_t: float = fposmod(t, 8.0)
	if phrase_t > 7.0:
		var trem: float = 0.5 + 0.5 * sin(TAU * 12.0 * t)
		v += sin(TAU * 987.77 * t) * trem * (phrase_t - 7.0) * 0.1
	return v
