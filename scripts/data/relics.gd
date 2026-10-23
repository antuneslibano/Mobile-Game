class_name Relics
extends RefCounted
## Relíquias (0.19): uma por região, única no mapa todo, numa pequena câmara escondida
## no fundo. Brilha forte e aparece no sonar como estrela. Na base o jogador escolhe:
## INSTALAR (bônus permanente na nave) ou VENDER (muitos créditos). Quando a região é
## refeita (guardião vencido), uma nova relíquia aparece em outro lugar.

## região → [chave do recurso, nome, descrição, valor, atributo do bônus, quantidade,
##           texto do bônus, cor, sprite do depósito]
const DEFS: Dictionary = {
	&"vale": [&"relic_seed", "Semente Primordial", "Uma semente viva das primeiras raízes do mundo. Pulsa como um coração pequeno.",
		6000, &"collect", 0.15, "+15% de recursos coletados", Color("7dff7a"), "cristal_verde"],
	&"dunas": [&"relic_amber", "Âmbar Solar", "Âmbar que guardou a luz de um sol antigo. Esquenta a mão mesmo no escuro.",
		8000, &"fuel_tank", 0.20, "+20% de tanque de combustível", Color("ffb43a"), "ouro"],
	&"cordilheira": [&"relic_heart", "Coração de Ferro", "Um núcleo de metal vivo, arrancado do centro da montanha.",
		10000, &"hull", 25.0, "+25 de casco", Color("c8d4e4"), "titanio"],
	&"pantano": [&"relic_pearl", "Pérola do Brejo", "Formada em séculos de lama e silêncio. Nada gruda nela.",
		12000, &"speed", 0.10, "+10% de golpes por segundo", Color("8fe3ff"), "cristal_azul"],
	&"abismo": [&"relic_magma", "Lágrima de Magma", "Uma gota do Núcleo que esfriou por fora e nunca por dentro.",
		15000, &"temp_limit", 40.0, "+40 °C de limite térmico", Color("ff5a2a"), "cristal_vermelho"],
	&"vazio": [&"relic_prism", "Prisma Eterno", "Um cristal que reflete lugares que ainda não existem.",
		20000, &"crit", 0.10, "+10% de chance de crítico", Color("ff9ff3"), "cristal_roxo"],
}
const REGION_ORDER: Array[StringName] = [&"vale", &"dunas", &"cordilheira", &"pantano", &"abismo", &"vazio"]
## Primeiro id de bloco das relíquias (BlockRegistry): um bloco por região, nesta ordem.
const FIRST_BLOCK: int = 33


static func for_region(region_id: StringName) -> Array:
	return DEFS.get(region_id, [])


static func block_for(region_id: StringName) -> int:
	var i: int = REGION_ORDER.find(region_id)
	return FIRST_BLOCK + i if i >= 0 else -1


static func is_relic_block(id: int) -> bool:
	return id >= FIRST_BLOCK and id < FIRST_BLOCK + REGION_ORDER.size()


static func is_relic_key(key: StringName) -> bool:
	for r: StringName in DEFS:
		if DEFS[r][0] == key:
			return true
	return false


static func def_by_key(key: StringName) -> Array:
	for r: StringName in DEFS:
		if DEFS[r][0] == key:
			return DEFS[r]
	return []


## Aplica os bônus das relíquias instaladas nos atributos.
static func apply(s: DrillStats, installed: Dictionary) -> void:
	for key: Variant in installed:
		var d: Array = def_by_key(StringName(key))
		if d.is_empty():
			continue
		var amount: float = float(d[5])
		match StringName(d[4]):
			&"collect":
				s.collect_mult += amount
			&"fuel_tank":
				s.fuel_max *= 1.0 + amount
			&"hull":
				s.hull_max += amount
			&"speed":
				s.hits_per_second *= 1.0 + amount
			&"temp_limit":
				s.temp_limit += amount
			&"crit":
				s.crit_chance = minf(Progression.MAX_CRIT_CHANCE, s.crit_chance + amount)


## Onde fica a relíquia num mundo (bloco), a partir da semente: entre 45% e 85% da
## profundidade da região, longe das paredes e da câmara final.
static func place(seed_value: int, region: RegionDef) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_value * 31 + 7)
	var top: int = int(region.target_depth_m * 0.45)
	var bottom: int = mini(int(region.target_depth_m * 0.85), RegionRegistry.chamber_top(region) - 8)
	return Vector2i(rng.randi_range(3, Balance.WORLD_WIDTH - 4), rng.randi_range(top, maxi(top, bottom)))
