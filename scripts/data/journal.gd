class_name Journal
extends RefCounted
## Diário de pesquisa do Laboratório (0.10): entradas curtas liberadas por descobertas
## (recurso coletado pela primeira vez), criaturas catalogadas e guardiões vencidos. Aos poucos revelam que os
## minerais raros e as criaturas estão ligados ao Núcleo.

## [id, gatilho ("res:<recurso>", "guardian:<região>" ou "start"), título, texto]
const ENTRIES: Array = [
	[&"start", "start", "Diário de campo #1",
		"Base montada no Vale das Raízes. A sonda indica terras raras abaixo de nós e uma assinatura de calor estranha, regular como um batimento."],
	[&"copper", "res:copper", "Cobre",
		"Cobre nativo, quase puro. Serve para fiação e brocas. Estranho: os veios seguem as raízes, como se crescessem juntos."],
	[&"iron", "res:iron", "Ferro",
		"Ferro denso. Com ele a Bancada já consegue reforçar o casco e o tanque."],
	[&"quartz", "res:quartz", "Quartzo",
		"Cristais de quartzo vibram levemente quando a broca liga. Ressonância? Vou medir."],
	[&"silver", "res:silver", "Prata",
		"Prata em lâminas finas. Condutora excelente: abre o segundo nível de projetos."],
	[&"crystal", "res:crystal", "Cristal azul",
		"Os cristais azuis guardam energia. Moídos, alimentam os módulos da nave."],
	[&"fossil", "res:fossil", "Fóssil",
		"Ossos de algo enorme, com marcas de broca... feitas de dentro para fora. Alguma coisa cavava aqui embaixo."],
	[&"amethyst", "res:amethyst", "Ametista",
		"A ametista brilha no escuro quando chego perto da câmara funda. O brilho pulsa no mesmo ritmo do sinal de calor."],
	[&"gold", "res:gold", "Ouro",
		"Ouro em pepitas grandes. Valioso, mas o laboratório quer outra coisa: ele isola o ruído do Núcleo."],
	[&"artifact", "res:artifact", "Artefato",
		"Um objeto lapidado, frio, impossível para a geologia daqui. Alguém (ou algo) esteve neste subsolo antes."],
	[&"firefly", "creature:firefly", "Vaga-lume das raízes",
		"Insetos luminosos nas cavernas do Vale. Fogem da nave, mas a luz deles pulsa no mesmo ritmo do sinal de calor."],
	[&"mole", "creature:mole", "Toupeira de raiz",
		"Pequenos escavadores com raízes crescendo nas costas. Parece que as raízes os usam para se espalhar."],
	[&"spider", "creature:spider", "Aranha de raiz",
		"Guarda os veios brilhantes como se fossem ovos. Ataca qualquer coisa que se aproxime do minério."],
	[&"worm", "creature:worm", "Minhoca escavadora",
		"Abre túneis enormes e engole terra. Os fósseis com marcas de broca... eram dela. Ela sente a vibração da nave."],
	[&"bio_sample", "res:bio_sample", "Amostras biológicas",
		"O tecido das criaturas conduz energia como um mineral. Com ele a Bancada liberou peças orgânicas."],
	[&"guardian_vale", "guardian:vale", "O Coração da Raiz-Mãe",
		"As raízes eram um corpo só, protegendo um coração mineral. Quando ele parou, todas as raízes do Vale escureceram. Projetos grandes liberados."],
	[&"ruby", "res:ruby", "Rubi",
		"Rubis nascem perto do calor. Quanto mais fundo, mais vermelhos: o Núcleo os aquece."],
	[&"titanium", "res:titanium", "Titânio",
		"Titânio puro em veios-mãe. Finalmente um casco à altura do que vive lá embaixo."],
	[&"emerald", "res:emerald", "Esmeralda",
		"Esmeraldas do pântano crescem em camadas, como anéis de árvore. Contam uma história de milhões de anos."],
	[&"uranium", "res:uranium", "Urânio",
		"Urânio. Perigoso, mas a bateria agradece. A radiação forma desenhos: setas apontando para baixo."],
	[&"obsidian", "res:obsidian", "Obsidiana",
		"Vidro vulcânico com bolhas de um gás que não existe na superfície."],
	[&"meteorite", "res:meteorite", "Meteorito",
		"Um meteorito enterrado a centenas de metros. Ele não caiu: foi puxado para cá."],
	[&"diamond", "res:diamond", "Diamante",
		"Diamantes perfeitos, sem inclusões. Forjados por uma pressão constante, quase intencional."],
	[&"voidite", "res:voidite", "Minério arcano",
		"Minério arcano absorve a luz da lanterna. Os instrumentos enlouquecem perto dele."],
	[&"rare_crystal", "res:rare_crystal", "Cristal raro",
		"O cristal raro canta. A nota é a mesma do batimento que ouvimos no primeiro dia. O Núcleo está chamando."],
]


## Entradas liberadas (na ordem do diário).
static func unlocked(discovered: Dictionary, done: Dictionary, creatures: Dictionary = {}) -> Array:
	var out: Array = []
	for e: Array in ENTRIES:
		if is_unlocked(String(e[1]), discovered, done, creatures):
			out.append(e)
	return out


static func is_unlocked(trigger: String, discovered: Dictionary, done: Dictionary, creatures: Dictionary = {}) -> bool:
	if trigger.begins_with("creature:"):
		return creatures.has(StringName(trigger.substr(9)))
	if trigger == "start":
		return true
	if trigger.begins_with("res:"):
		return discovered.has(StringName(trigger.substr(4)))
	if trigger.begins_with("guardian:"):
		return done.has(StringName(trigger.substr(9)))
	return false
