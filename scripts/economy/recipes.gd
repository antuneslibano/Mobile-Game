class_name Recipes
extends RefCounted
## Receitas da Bancada (0.10): cada nível de uma peça custa Créditos (ou Cristais) **e
## materiais** trazidos das expedições. Cada peça tem uma trilha de materiais em três
## níveis tecnológicos (níveis 1–4, 5–8 e 9+); o 3º é um **projeto grande**, liberado ao
## vencer o primeiro guardião. Um nível só aparece como projeto quando todos os materiais
## dele já foram descobertos (coletados alguma vez). Valores `[T]` ajustáveis aqui.

const TIER_LEVELS: Array[int] = [4, 8]   ## Níveis em que a trilha passa para o tier seguinte.
const BIG_PROJECT_TECH: int = 1          ## Guardiões vencidos para o 3º tier.

## id da peça → [tier 1, tier 2, tier 3]; cada tier = [material principal, secundário?].
const TRACKS: Dictionary = {
	&"damage": [[&"copper"], [&"iron", &"silver"], [&"gold", &"titanium"]],
	&"speed": [[&"copper"], [&"quartz", &"silver"], [&"gold", &"emerald"]],
	&"crit": [[&"quartz"], [&"amethyst"], [&"ruby", &"diamond"]],
	&"collect": [[&"iron"], [&"silver", &"bio_sample"], [&"gold", &"fossil"]],
	&"energy": [[&"quartz"], [&"silver", &"bio_sample"], [&"amethyst", &"uranium"]],
	&"cooling": [[&"iron"], [&"silver"], [&"titanium", &"obsidian"]],
	&"fuel_tank": [[&"iron"], [&"silver"], [&"titanium"]],
	&"fuel_eff": [[&"iron"], [&"quartz"], [&"emerald"]],
	&"hull": [[&"iron"], [&"iron", &"silver"], [&"titanium", &"obsidian"]],
	&"side_drill": [[&"iron"], [&"silver"], [&"titanium"]],
	&"drone": [[&"copper", &"quartz"], [&"silver", &"bio_sample"], [&"gold"]],
	&"seismic": [[&"quartz"], [&"amethyst"], [&"ruby"]],
	&"boost": [[&"quartz"], [&"amethyst"], [&"voidite"]],
}


## Tier tecnológico (0, 1, 2) do próximo nível a partir do nível atual.
static func tier(level: int) -> int:
	if level < TIER_LEVELS[0]:
		return 0
	return 1 if level < TIER_LEVELS[1] else 2


## Materiais do próximo nível ({recurso: quantidade}); vazio = só moeda.
static func materials(def: UpgradeDef, level: int) -> Dictionary:
	var track: Array = TRACKS.get(def.id, [])
	if track.is_empty():
		return {}
	var t: int = tier(level)
	var keys: Array = track[mini(t, track.size() - 1)]
	var n: int
	match t:
		# Gradual (0.14): cada nível pede mais que o anterior dentro do tier.
		0:
			n = 2 + level * 3 / 2                                 # 2, 3, 5, 6
		1:
			n = 3 + (level - TIER_LEVELS[0]) * 3 / 2              # 3, 4, 6, 7…
		_:
			n = 3 + (level - TIER_LEVELS[1])                      # 3, 4, 5, 6…
	var out: Dictionary = {}
	for i in keys.size():
		out[keys[i]] = n if i == 0 else ceili(n * 0.5)
	return out


## Motivo de bloqueio do próximo nível ("" = liberado): projeto grande ou materiais nunca
## descobertos.
static func requirement(def: UpgradeDef, level: int, discovered: Dictionary, tech: int) -> String:
	if tier(level) >= 2 and tech < BIG_PROJECT_TECH:
		return "Projeto grande: vença um guardião de câmara final"
	var missing: PackedStringArray = []
	for k: StringName in materials(def, level):
		if not discovered.has(k):
			missing.append(ResourceRegistry.get_def(k).display_name)
	if not missing.is_empty():
		return "Descubra: " + ", ".join(missing)
	return ""


## Reserva da Bancada: maior quantidade de cada material pedida pelo próximo nível de
## alguma peça (o "excedente" é o que passa disso).
static func reserve(levels: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for def in UpgradeRegistry.all():
		if int(levels.get(def.id, 0)) >= def.max_level:
			continue
		var m: Dictionary = materials(def, int(levels.get(def.id, 0)))
		for k: StringName in m:
			out[k] = maxi(int(out.get(k, 0)), int(m[k]))
	return out
