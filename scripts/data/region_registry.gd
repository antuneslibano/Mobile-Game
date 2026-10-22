class_name RegionRegistry
extends RefCounted
## As seis regiões do mapa mundial (ordem do carrossel = ordem de desbloqueio).
## Valores ajustáveis aqui (GAME_DESIGN.md §5.6).

const VALE: StringName = &"vale"
const DUNAS: StringName = &"dunas"
const CORDILHEIRA: StringName = &"cordilheira"
const PANTANO: StringName = &"pantano"
const ABISMO: StringName = &"abismo"
const VAZIO: StringName = &"vazio"

## Riscos ambientais: nome exibido e ícone. "Calor" usa a mecânica real de calor; os demais
## descrevem o comportamento das camadas (materiais instáveis, duros etc.).
const HAZARDS: Dictionary = {
	&"quicksand": "Areia movediça",
	&"cave_in": "Desmoronamentos",
	&"unstable": "Solo instável",
	&"heat": "Calor",
	&"mud": "Lama",
	&"hard_rock": "Pedras resistentes",
	&"ice": "Gelo",
	&"magma": "Magma",
}

const DIFFICULTY_NAMES: Array[String] = ["", "Fácil", "Moderada", "Difícil", "Muito difícil", "Extrema"]

static var _list: Array[RegionDef] = []
static var _by_id: Dictionary = {}


static func all() -> Array[RegionDef]:
	if _list.is_empty():
		_build()
	return _list


static func get_def(id: StringName) -> RegionDef:
	all()
	return _by_id.get(id, _list[0])


static func index_of(id: StringName) -> int:
	all()
	for i in _list.size():
		if _list[i].id == id:
			return i
	return 0


## done: { region_id: true } das regiões com a câmara final concluída.
static func is_unlocked(r: RegionDef, done: Dictionary) -> bool:
	if r.unlock_region == &"":
		return true
	return done.has(r.unlock_region)


## Regra antiga (antes da 0.9): profundidade na região anterior. Só para migração.
static func was_unlocked_by_depth(r: RegionDef, progress: Dictionary) -> bool:
	return r.unlock_region == &"" or int(progress.get(r.unlock_region, 0)) >= r.unlock_depth_m


static func requirement_text(r: RegionDef) -> String:
	if r.unlock_region == &"":
		return "Disponível desde o início."
	var prev: RegionDef = get_def(r.unlock_region)
	return "Vença %s na câmara final de %s (%d m)." % [prev.guardian_name, prev.display_name, prev.target_depth_m]


## Camadas alcançáveis (as que começam acima do fundo).
static func reachable_layers(r: RegionDef) -> Array[BiomeDef]:
	var out: Array[BiomeDef] = []
	for b in r.layers:
		if b.start_row < r.target_depth_m:
			out.append(b)
	return out


## Primeira linha (blocos) da câmara final e coluna central.
static func chamber_top(r: RegionDef) -> int:
	return r.target_depth_m - Balance.FINAL_CHAMBER_ROWS


static func chamber_center_x() -> int:
	return Balance.WORLD_WIDTH / 2


## Topo do corpo do guardião (px): plano, GUARDIAN_BODY_ROWS acima do fundo.
static func guardian_body_top(r: RegionDef) -> float:
	return (r.target_depth_m - Balance.GUARDIAN_BODY_ROWS) * Balance.BLOCK_PX


## Centro (px) do topo do corpo do guardião (meio da arena).
static func guardian_center(r: RegionDef) -> Vector2:
	return Vector2((chamber_center_x() + 0.5) * Balance.BLOCK_PX, guardian_body_top(r))


static func guardian_hp(r: RegionDef) -> float:
	return Balance.GUARDIAN_HP * (1.0 + Balance.GUARDIAN_HP_PER_DIFFICULTY * (r.difficulty - 1))


static func guardian_hit_damage(r: RegionDef) -> float:
	return Balance.GUARDIAN_HIT_DAMAGE + Balance.GUARDIAN_HIT_DAMAGE_PER_DIFFICULTY * (r.difficulty - 1)


static func objective(r: RegionDef, obj_id: StringName) -> Dictionary:
	for o: Dictionary in r.objectives:
		if o.id == obj_id:
			return o
	return {}


## Objetivos: 1 principal (vencer o guardião da câmara final), 3 de pesquisa e 3 desafios.
## Pesquisa: kind &"collect" (recurso, quantidade acumulada na região).
## Estrelas: &"guardian" (vencer o guardião com mais da metade do casco),
## &"haul" (extrair com carga ≥ valor), &"clean" (extrações sem resgate).
static func _objectives(r: RegionDef, research: Array, haul: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"id": &"final", "group": &"main", "kind": &"final", "key": &"", "target": 1,
			"text": "Vencer %s na câmara final (%d m)" % [r.guardian_name, r.target_depth_m]}]
	for e: Array in research:
		var rd: ResourceDef = ResourceRegistry.get_def(e[0])
		out.append({"id": StringName("res_" + String(e[0])), "group": &"research", "kind": &"collect", "key": e[0],
				"target": e[1], "text": "Coletar %d de %s" % [e[1], rd.display_name if rd != null else String(e[0])]})
	out.append({"id": &"guardian", "group": &"star", "kind": &"guardian", "key": &"", "target": 1,
			"text": "Vencer o guardião com mais da metade do casco"})
	out.append({"id": &"haul", "group": &"star", "kind": &"haul", "key": &"", "target": haul,
			"text": "Extrair com carga de pelo menos %d créditos" % haul})
	out.append({"id": &"clean", "group": &"star", "kind": &"clean", "key": &"", "target": 5,
			"text": "Fazer 5 extrações sem resgate de emergência"})
	return out


# --- Construção ------------------------------------------------------------------

## Camada: [inicio_m, fim_m, nome, descrição, primário, secundário, proporção, limiar_caverna, minérios]
static func _layers(spec: Array) -> Array[BiomeDef]:
	var out: Array[BiomeDef] = []
	for i in spec.size():
		var e: Array = spec[i]
		var b := BiomeDef.new()
		b.id = i
		b.start_row = e[0]
		b.end_row = e[1]
		b.display_name = e[2]
		b.description = e[3]
		b.primary_block = e[4]
		b.secondary_block = e[5]
		b.secondary_ratio = e[6]
		b.cave_threshold = e[7]
		b.ore_table = e[8]
		var prim: BlockDef = BlockRegistry.get_def(b.primary_block)
		b.back_color = prim.color_dark.darkened(0.55)
		b.fog_color = b.back_color.darkened(0.3)
		b.ui_color = prim.color_base.lightened(0.35)
		out.append(b)
	return out


static func _region(id: StringName, name: String, theme: StringName, desc: String, diff: int,
		target: int, heat: int, unlock: StringName, unlock_m: int, layers: Array[BiomeDef],
		res: Array[StringName], haz: Array[StringName], rec: Array[StringName], sky: Array) -> RegionDef:
	var r := RegionDef.new()
	r.id = id
	r.display_name = name
	r.theme = theme
	r.description = desc
	r.difficulty = diff
	r.target_depth_m = target
	r.heat_start_m = heat
	r.unlock_region = unlock
	r.unlock_depth_m = unlock_m
	r.layers = layers
	r.resources = res
	r.hazards = haz
	r.recommended = rec
	r.sky_top = sky[0]
	r.sky_bottom = sky[1]
	r.hill_far = sky[2]
	r.hill_near = sky[3]
	r.ui_color = sky[4]
	return r


static func _build() -> void:
	var B := BlockRegistry
	var M: int = Balance.MAX_DEPTH_ROWS
	_list = [
		_region(VALE, "Vale das Raízes", &"savanna",
			"Uma vasta região de solo avermelhado, raízes antigas e formações orgânicas enterradas.",
			1, 600, 800, &"", 0, _layers([
				[0, 70, "Solo superficial", "Solo superficial e raízes.", B.DIRT, B.STONE, 0.15, 0.7,
					[[B.COPPER, 0.05, 3], [B.COAL, 0.018, 5], [B.CHEST, 0.002, 10]]],
				[70, 190, "Areia instável", "Areia instável e areia movediça.", B.SAND, B.DIRT, 0.3, 0.66,
					[[B.COPPER, 0.04, 70], [B.COAL, 0.009, 70], [B.IRON, 0.025, 70], [B.QUARTZ, 0.02, 70], [B.FOSSIL, 0.006, 70]]],
				[190, 360, "Argila compactada", "Argila compactada.", B.CLAY, B.STONE, 0.3, 0.66,
					[[B.IRON, 0.035, 190], [B.COAL, 0.0067, 190], [B.SILVER, 0.02, 190], [B.CRYSTAL, 0.04, 210], [B.QUARTZ, 0.02, 190], [B.CHEST, 0.002, 190]]],
				[360, 600, "Cavernas fossilizadas", "Cavernas fossilizadas.", B.STONE, B.HARD_ROCK, 0.35, 0.6,
					[[B.GOLD, 0.025, 360], [B.COAL, 0.0054, 360], [B.CRYSTAL, 0.04, 360], [B.FOSSIL, 0.01, 360], [B.AMETHYST, 0.012, 360], [B.SILVER, 0.02, 360]]],
				[600, M, "Zona abissal", "Zona abissal misteriosa.", B.ABYSS_STONE, B.BASALT, 0.2, 0.62,
					[[B.VOIDITE, 0.02, 600], [B.RUBY, 0.012, 600], [B.ARTIFACT, 0.003, 600]]],
			]), [&"copper", &"quartz", &"fossil", &"gold", &"amethyst"],
			[&"quicksand", &"cave_in", &"unstable"], [&"damage", &"speed", &"energy", &"collect"],
			[Color("2a1a3a"), Color("e8894a"), Color("7a3e2a"), Color("4e2a1e"), Color("f0a050")]),
		_region(DUNAS, "Dunas de Âmbar", &"desert",
			"Um mar de areia dourada que esconde arenito, argila vermelha e ossadas de criaturas antigas.",
			2, 700, 600, VALE, 80, _layers([
				[0, 90, "Dunas", "Dunas de areia fina e solta.", B.SAND, B.DIRT, 0.1, 0.72,
					[[B.COPPER, 0.04, 3], [B.COAL, 0.0113, 5], [B.QUARTZ, 0.03, 3], [B.FOSSIL, 0.008, 6]]],
				[90, 280, "Arenito", "Arenito compactado e veios de quartzo.", B.STONE, B.SAND, 0.35, 0.66,
					[[B.COPPER, 0.03, 90], [B.COAL, 0.009, 90], [B.GOLD, 0.015, 90], [B.QUARTZ, 0.03, 90], [B.CHEST, 0.003, 90]]],
				[280, 510, "Argila vermelha", "Argila vermelha e rochas duras.", B.CLAY, B.HARD_ROCK, 0.3, 0.64,
					[[B.GOLD, 0.025, 280], [B.COAL, 0.0054, 280], [B.RUBY, 0.01, 280], [B.FOSSIL, 0.01, 280]]],
				[510, M, "Rocha queimada", "Rocha queimada pelo calor profundo.", B.BASALT, B.MAGMA_ROCK, 0.25, 0.64,
					[[B.RUBY, 0.015, 510], [B.COAL, 0.0045, 510], [B.GOLD, 0.02, 510], [B.METEORITE, 0.003, 510]]],
			]), [&"gold", &"quartz", &"fossil", &"ruby", &"copper"],
			[&"quicksand", &"heat", &"cave_in"], [&"cooling", &"speed", &"damage", &"collect"],
			[Color("3a2a20"), Color("f2b25a"), Color("c88a3a"), Color("9a6428"), Color("ffc65a")]),
		_region(CORDILHEIRA, "Cordilheira de Ferro", &"mountain",
			"Montanhas de rocha maciça cortadas por veios de ferro, prata e titânio.",
			3, 800, 720, DUNAS, 120, _layers([
				[0, 120, "Encosta rochosa", "Pedra exposta e veios de ferro.", B.STONE, B.DIRT, 0.25, 0.66,
					[[B.IRON, 0.05, 3], [B.COAL, 0.018, 3], [B.COPPER, 0.02, 3]]],
				[120, 350, "Rocha dura", "Rocha dura e compacta.", B.HARD_ROCK, B.STONE, 0.35, 0.62,
					[[B.IRON, 0.04, 120], [B.COAL, 0.009, 120], [B.SILVER, 0.03, 120], [B.TITANIUM, 0.008, 190]]],
				[350, 700, "Veios de titânio", "Basalto com veios de titânio.", B.BASALT, B.HARD_ROCK, 0.35, 0.62,
					[[B.TITANIUM, 0.025, 350], [B.COAL, 0.0054, 350], [B.GOLD, 0.02, 350], [B.EMERALD, 0.008, 350]]],
				[700, M, "Raízes da montanha", "As raízes profundas da cordilheira.", B.ABYSS_STONE, B.BASALT, 0.3, 0.62,
					[[B.TITANIUM, 0.02, 700], [B.COAL, 0.0045, 700], [B.DIAMOND, 0.005, 700], [B.ARTIFACT, 0.002, 700]]],
			]), [&"iron", &"silver", &"titanium", &"coal", &"emerald"],
			[&"hard_rock", &"cave_in"], [&"damage", &"side_drill", &"speed", &"energy"],
			[Color("1e2433"), Color("8aa0b8"), Color("4a5262"), Color("343a48"), Color("b8c8dc")]),
		_region(PANTANO, "Pântano das Profundezas", &"swamp",
			"Águas paradas, lama densa e turfa escondem esmeraldas e minerais radioativos.",
			3, 850, 770, CORDILHEIRA, 160, _layers([
				[0, 100, "Lama", "Lama encharcada e raízes podres.", B.MUD, B.DIRT, 0.2, 0.7,
					[[B.COAL, 0.0225, 3], [B.FOSSIL, 0.006, 6]]],
				[100, 290, "Turfa", "Turfa escura rica em carvão.", B.DIRT, B.CLAY, 0.35, 0.66,
					[[B.COAL, 0.018, 100], [B.EMERALD, 0.012, 100], [B.IRON, 0.02, 100]]],
				[290, 600, "Argila submersa", "Argila encharcada e veios verdes.", B.CLAY, B.STONE, 0.3, 0.64,
					[[B.URANIUM, 0.012, 290], [B.COAL, 0.0067, 290], [B.EMERALD, 0.015, 290], [B.SILVER, 0.02, 290]]],
				[600, M, "Grutas esmeralda", "Grutas cristalinas sob o pântano.", B.CRYSTAL_ROCK, B.HARD_ROCK, 0.35, 0.58,
					[[B.EMERALD, 0.02, 600], [B.COAL, 0.0045, 600], [B.URANIUM, 0.015, 600], [B.CRYSTAL, 0.03, 600]]],
			]), [&"coal", &"emerald", &"uranium", &"fossil", &"crystal"],
			[&"mud", &"unstable", &"cave_in"], [&"collect", &"energy", &"side_drill", &"damage"],
			[Color("16261e"), Color("5a7a4a"), Color("2a4a32"), Color("1c3324"), Color("7fd08a")]),
		_region(ABISMO, "Abismo de Obsidiana", &"volcanic",
			"Uma fenda vulcânica com rios de magma, campos de obsidiana e fragmentos de meteoritos.",
			4, 950, 0, PANTANO, 200, _layers([
				[0, 180, "Crosta vulcânica", "Rocha escura com veios de basalto quente.", B.HARD_ROCK, B.BASALT, 0.25, 0.66,
					[[B.COAL, 0.0135, 3], [B.GOLD, 0.02, 3], [B.RUBY, 0.01, 10]]],
				[180, 440, "Rios de magma", "Rocha magmática incandescente.", B.MAGMA_ROCK, B.BASALT, 0.4, 0.64,
					[[B.RUBY, 0.02, 180], [B.COAL, 0.0067, 180], [B.OBSIDIAN, 0.02, 180], [B.TITANIUM, 0.01, 180]]],
				[440, 840, "Campos de obsidiana", "Vidro vulcânico e meteoritos.", B.BASALT, B.MAGMA_ROCK, 0.3, 0.62,
					[[B.OBSIDIAN, 0.03, 440], [B.COAL, 0.0054, 440], [B.GOLD, 0.02, 440], [B.METEORITE, 0.004, 440]]],
				[840, M, "Câmara do núcleo", "O coração ardente do abismo.", B.ABYSS_STONE, B.MAGMA_ROCK, 0.3, 0.62,
					[[B.METEORITE, 0.006, 840], [B.COAL, 0.0045, 840], [B.VOIDITE, 0.015, 840], [B.DIAMOND, 0.006, 840]]],
			]), [&"obsidian", &"ruby", &"gold", &"meteorite", &"titanium"],
			[&"heat", &"magma", &"hard_rock"], [&"cooling", &"damage", &"speed", &"energy"],
			[Color("1a0d10"), Color("8a2a1a"), Color("2a1a1c"), Color("1a1012"), Color("ff6a3a")]),
		_region(VAZIO, "Vazio Cristalino", &"crystal",
			"Ilhas de gelo e cristal flutuando sobre um vazio misterioso, repletas de gemas raras.",
			5, 1000, 800, ABISMO, 250, _layers([
				[0, 130, "Gelo cristalino", "Gelo antigo e quartzo.", B.ICE, B.CRYSTAL_ROCK, 0.3, 0.66,
					[[B.QUARTZ, 0.04, 3], [B.COAL, 0.0113, 5], [B.CRYSTAL, 0.03, 3]]],
				[130, 430, "Rocha cristalina", "Rocha cristalina e geodos.", B.CRYSTAL_ROCK, B.HARD_ROCK, 0.4, 0.58,
					[[B.CRYSTAL, 0.04, 130], [B.COAL, 0.0067, 130], [B.AMETHYST, 0.02, 130], [B.DIAMOND, 0.004, 220]]],
				[430, 850, "Fendas do vazio", "Fendas que levam ao vazio.", B.ABYSS_STONE, B.CRYSTAL_ROCK, 0.35, 0.6,
					[[B.DIAMOND, 0.01, 430], [B.COAL, 0.0054, 430], [B.VOIDITE, 0.02, 430], [B.RARE_CRYSTAL, 0.004, 430]]],
				[850, M, "Coração do vazio", "Onde nascem os cristais raros.", B.ABYSS_STONE, B.ICE, 0.2, 0.6,
					[[B.RARE_CRYSTAL, 0.008, 850], [B.COAL, 0.0045, 850], [B.VOIDITE, 0.02, 850], [B.ARTIFACT, 0.004, 850]]],
			]), [&"crystal", &"amethyst", &"diamond", &"rare_crystal", &"voidite"],
			[&"ice", &"hard_rock", &"unstable"], [&"damage", &"crit", &"side_drill", &"energy"],
			[Color("120a24"), Color("4a2a7a"), Color("2a1a4a"), Color("1a1030"), Color("c08cff")]),
	]
	# [câmara final, guardião, pesquisa, carga da estrela]
	var finals: Dictionary = {
		VALE: ["Raiz-Mãe", "o Coração da Raiz-Mãe", [[&"copper", 30], [&"crystal", 15], [&"fossil", 4]], 2000],
		DUNAS: ["Templo soterrado", "o Ídolo de âmbar", [[&"gold", 15], [&"quartz", 20], [&"fossil", 5]], 5000],
		CORDILHEIRA: ["Veio-mãe de titânio", "o Núcleo de titânio", [[&"iron", 35], [&"silver", 15], [&"titanium", 6]], 9000],
		PANTANO: ["Ninho no lodo", "o Ovo do lodo", [[&"emerald", 10], [&"uranium", 6], [&"fossil", 5]], 12000],
		ABISMO: ["Câmara de magma", "o Coração de magma", [[&"obsidian", 12], [&"ruby", 10], [&"meteorite", 1]], 22000],
		VAZIO: ["O Núcleo", "o Cristal-Núcleo", [[&"diamond", 6], [&"rare_crystal", 2], [&"voidite", 12]], 45000],
	}
	for r in _list:
		var f: Array = finals[r.id]
		r.final_name = f[0]
		r.guardian_name = f[1]
		r.objectives = _objectives(r, f[2], f[3])
	_by_id.clear()
	for r in _list:
		_by_id[r.id] = r
