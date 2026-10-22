# DEEPFORGE: Rumo ao Núcleo — Game Design Document

> Documento vivo. Todos os valores numéricos marcados com `[T]` são **ajustáveis** e
> vivem em código centralizado (`scripts/data/balance.gd`, `scripts/data/block_registry.gd`
> e, a partir da Fase 2, em Resources de upgrade). Altere lá, não espalhado pelo código.

## 1. Visão

Jogo mobile Android 2D vertical, offline, single-player. O jogador pilota uma
perfuradora industrial amarela que escava um poço até o Núcleo do planeta.
Cada bloco quebrado rende minério; minério vira Créditos; Créditos viram upgrades;
upgrades levam mais fundo, a biomas mais hostis e mais valiosos. Ao alcançar 500 m,
o jogador pode reiniciar a escavação (prestígio) em troca de Núcleos Antigos, que
compram melhorias permanentes.

Pilares:
1. **Tátil e satisfatório** – cada impacto treme, solta poeira e faíscas.
2. **Progresso legível** – números claros, antes/depois em toda compra.
3. **Sessões curtas** – 2 a 10 minutos fazem diferença; salvamento constante.
4. **Leve** – roda a 60 FPS em Android intermediário, aceitável a 30 FPS em básico.

## 2. Formato e plataforma

| Item | Valor |
|---|---|
| Engine | Godot 4.6 stable (compatível com 4.x ≥ 4.3), GDScript tipado |
| Renderer | Compatibility (OpenGL ES 3 / WebGL2) – melhor cobertura em Android básico |
| Resolução de referência | 720 × 1280, retrato |
| Escala | `canvas_items` + aspecto `expand` (telas mais altas/largas mostram mais mundo) |
| Entrada | Toque (multitoque) e mouse/teclado para testes no desktop |
| Rede | Nenhuma. Totalmente offline |
| Salvamento | `user://` (Fase 4) |

## 3. Loop principal

```
Escavar → coletar minério → (garagem) vender → comprar upgrades/módulos
   ↑                                                           │
   └──────────── ir mais fundo, biomas mais ricos ←────────────┘
                         │ (≥ 500 m)
                         └→ Prestígio → Núcleos Antigos → melhorias permanentes
```

## 4. Controles — movimento livre

| Ação | Toque | Desktop |
|---|---|---|
| Cavar em qualquer direção (menos para cima) | Joystick: para baixo, diagonais, lados — em qualquer ângulo | Setas/WASD combinadas (diagonais incluídas), `Espaço` = baixo |
| Para cima | **Nada** — a broca não sobe | – |
| Sobrecarga | Botão no canto inferior direito, **só com a barra cheia** | `Shift` |
| Garagem | Botão `GARAGEM` no topo | clique, `Esc` fecha |

**Joystick flutuante:** nasce onde o dedo toca; raio `JOYSTICK_RADIUS_PX = 110` `[T]`.
`InputController.joystick_to_intent` converte o vetor em `DrillIntent.aim`:
- zona morta `0.2`: nada;
- qualquer ângulo da metade de baixo é aceito como está; a aceleração vai de 35% a 100%
  conforme a distância do dedo;
- o componente **para cima é descartado**: puxar para cima não faz nada e uma diagonal para
  cima vira movimento lateral. Não existe pulo nem degrau automático.

A máquina **desenha o próprio túnel**: a broca escava um círculo à frente na direção
escolhida e a máquina avança conforme o material cede. No vazio ela cai pela gravidade.

## 5. Mundo

### 5.1 Micro-células e chunks
O **bloco** (48 px = 1 m) continua sendo a unidade de design (vida, dureza, drops, biomas).
O terreno real é feito de **micro-células de 12 px** (4×4 por bloco), o que permite túneis
em qualquer ângulo.

| Parâmetro | Valor `[T]` |
|---|---|
| Micro-célula | 12 px (`CELL_PX`); 16 por bloco (`CELLS_PER_BLOCK`) |
| Largura do mundo | 24 blocos = 96 células; borda de rocha-mãe orgânica (+3 células fixas) |
| Chunk | 16 blocos de altura = 96 × 64 células |
| Geração | layout de blocos amostrado com deformação fractal de ±4 células → bordas naturais |
| Chunks carregados | visível −1 / +2 (antecipados em `WorkerThreadPool`) |
| Profundidade máxima | 1000 m; abaixo, rocha-mãe |

Vida da micro-célula = vida do bloco ÷ 4; cavar 1 bloco de espessura custa ~o mesmo número
de golpes que antes, e o volume de 16 células rende os drops de 1 bloco.

### 5.2 Geração determinística
Função pura `(seed, x, y) → block_id` (`WorldGenerator`). Mesma seed ⇒ mesmo mundo em
qualquer dispositivo. Ingredientes:
- `FastNoiseLite` (embutido no Godot) para cavernas, mistura de material e veios de minério.
- Hash inteiro próprio (sem dependência de `randf`) para dispersão de minérios e variantes visuais.
- Regras por profundidade (bioma), com borda de bioma "serrilhada" por ruído (±4 m).
- Primeiras 6 linhas sem cavernas (início seguro).

Cavernas: `cave_noise(x, y) > limiar_do_bioma` ⇒ ar. Proporção medida: Crosta ~17%,
Cristalinas ~29%, Magmática ~21%, Abismo ~23% (teste `test_biome_content_and_caves`).

### 5.3 Regiões e camadas (`RegionRegistry`)
O mundo de cada exploração é gerado com as **camadas de profundidade da região escolhida**
no mapa mundial (mesmo gerador, mineração, economia e garagem). Cada região tem 4–5 camadas
contíguas de 0 m até a profundidade máxima; cada camada define material principal/secundário,
limiar de caverna e tabela de minérios. Valores `[T]` em `scripts/data/region_registry.gd`.

| # | Região | Tema | Dificuldade | 100% em | Calor desde | Desbloqueio |
|---|---|---|---|---|---|---|
| 1 | Vale das Raízes | savana | ★ Fácil | 250 m | 300 m | livre |
| 2 | Dunas de Âmbar | deserto | ★★ Moderada | 300 m | 200 m | 80 m no Vale |
| 3 | Cordilheira de Ferro | montanhas | ★★★ Difícil | 350 m | 300 m | 120 m nas Dunas |
| 4 | Pântano das Profundezas | pântano | ★★★ Difícil | 350 m | 300 m | 160 m na Cordilheira |
| 5 | Abismo de Obsidiana | vulcânico | ★★★★ Muito difícil | 450 m | 0 m | 200 m no Pântano |
| 6 | Vazio Cristalino | cristalino | ★★★★★ Extrema | 500 m | 300 m | 250 m no Abismo |

- **Desbloqueio** usa só a progressão existente (profundidade máxima alcançada na região
  anterior) — sem moedas novas. Regiões bloqueadas aparecem no mapa com cadeado e o requisito.
- **Progresso** = profundidade máxima da região ÷ "100% em" (exibido em % no mapa).
- **Riscos ambientais** são informativos e descrevem as camadas (areia movediça = areia
  solta, desmoronamento = muitas cavernas, rochas resistentes = camadas duras…), exceto
  **Calor**, que usa a mecânica real (§7.5) com início por região.
- **Equipamentos recomendados** apontam upgrades existentes da garagem.

Camadas (resumo):

| Região | Camadas |
|---|---|
| Vale | Solo superficial (terra) · Areia instável · Argila compactada · Cavernas fossilizadas · Zona abissal |
| Dunas | Dunas (areia) · Arenito · Argila vermelha · Rocha queimada |
| Cordilheira | Encosta rochosa · Rocha dura · Veios de titânio · Raízes da montanha |
| Pântano | Lama · Turfa · Argila submersa · Grutas esmeralda |
| Abismo | Crosta vulcânica · Rios de magma · Campos de obsidiana · Câmara do núcleo |
| Vazio | Gelo cristalino · Rocha cristalina · Fendas do vazio · Coração do vazio |

### 5.4 Materiais: terreno × depósito (`BlockRegistry`)
`hp` = vida; `hardness` = armadura subtraída de cada golpe.

**Terreno** (`BlockDef.is_terrain()`): forma o cenário e é desenhado como textura contínua —
nunca como minério — e **não rende nada** (desde a 0.8: o dinheiro está nos minérios; cavar
reto para baixo não paga). Os recursos antigos de entulho continuam registrados só para
salvamentos antigos.

| Material | HP | Dureza | Recompensa | Visual |
|---|---|---|---|---|
| Terra | 12 | 0 | – | solo macio, pedrinhas e raízes |
| Pedra | 30 | 1 | – | pedras compactas iluminadas, rachaduras |
| Rocha cristalina / dura | 60 / 110 | 4 / 7 | – | pedras |
| Basalto / Rocha magmática | 220 / 320 | 14 / 18 | – | pedras escuras / veios incandescentes |
| Pedra abissal | 700 | 30 | – | pedras |
| Areia | 10 | 0 | – | grãos e faixas de vento |
| Argila | 34 | 1 | – | camadas horizontais |
| Gelo | 60 | 3 | – | facetas com brilho |
| Lama | 14 | 0 | – | escura, reflexos úmidos |

**Depósitos coletáveis** (de Cobre em diante): pequenas pepitas/lascas embutidas na rocha
hospedeira, com contorno escuro e cor própria; nunca ícones grandes nem nomes na mina.

| Depósito | HP | Dureza | Drops | Forma |
|---|---|---|---|---|
| Carvão | 30 | 1 | carvão | pepitas |
| Cobre | 36 | 1 | cobre | pepitas |
| Ferro | 48 | 2 | ferro | pepitas |
| Prata | 70 | 4 | prata | pepitas |
| Quartzo | 60 | 3 | quartzo | lascas |
| Cristal | 70 | 4 | cristal ×2 | lascas |
| Ametista | 100 | 6 | ametista, cristal ×2 | lascas |
| Esmeralda | 180 | 10 | esmeralda, cristal | lascas |
| Ouro | 260 | 16 | ouro | pepitas |
| Titânio | 300 | 15 | titânio | pepitas |
| Rubi | 360 | 20 | rubi | lascas |
| Urânio | 380 | 18 | urânio | pepitas com brilho |
| Obsidiana | 420 | 20 | obsidiana | placas vítreas com fissuras |
| Diamante | 600 | 26 | diamante, cristal ×2 | lascas |
| Minério arcano | 1000 | 34 | minério arcano | placas com fissuras roxas |
| Cristal raro | 800 | 28 | cristal raro, cristal ×4 | lascas multicoloridas |

**Especiais** (raros, desenhados no próprio bloco): Baú soterrado, Artefato, **Fóssil**
(osso; 120 créditos) e **Meteorito** (rocha com fissuras vermelhas; meteorito + cristal ×2).

Classificação dos elementos da imagem de referência: areia, argila, gelo e lama/turfa são
**terreno**; magma é **terreno** (rocha magmática); fósseis são **especial coletável**.
O catálogo (ícones com moldura) é usado só nos painéis (mapa/inventário), nunca na mina.

### 5.5 Distribuição de minérios (`[T]` nas camadas de `RegionRegistry`)
Cada camada tem uma tabela `(bloco, chance base, profundidade mínima)`. Um veio
(ruído de minério > 0.25) multiplica a chance por 3, formando aglomerados.

## 6. Perfuradora e mineração

| Atributo (base) `[T]` | Valor |
|---|---|
| Dano por golpe | 4 |
| Golpes por segundo | 5 |
| Chance / multiplicador de crítico | 5% / 2× |
| Velocidade de deslocamento | 4,5 blocos/s |
| Corpo (colisão) | círculo de 15 px |
| Broca | círculo de 24 px, 12 px à frente do corpo |
| Gravidade / queda máx. | 32 / 14 blocos/s |

A cada golpe, todas as micro-células sólidas dentro da broca recebem o dano (com dureza):

```
efetivo = max(bruto − dureza, bruto × 0,15)      bruto = dano × (crítico ? 2 : 1)
desgaste da célula += efetivo ÷ (vida_do_bloco ÷ 4); ≥ 100% → removida
```

Regras de movimento:
- a velocidade vertical **nunca é negativa**; nada é escavado acima de `topo do corpo − 6 px`
  (nem pela broca, nem por módulos) — teste `test_never_digs_above_the_machine`;
- em movimento lateral a broca sobe o suficiente para o piso do túnel ficar rente à base:
  túneis horizontais ficam nivelados;
- o corpo também tritura o que o bloqueia à frente (bordas que a broca não cobre);
- colisão contínua em subpassos de 4 px: não atravessa material mesmo a 20 FPS.

Feedback: tremor, poeira/lascas na cor do material, faíscas em críticos e na rocha-mãe,
desgaste visível (material escurece e racha), a máquina gira apontando a broca.

## 7. Progressão

### 7.1 Moedas e recursos (Fase 2 — implementado)
- **Créditos** – venda da carga na garagem (`ResourceRegistry`, preço por unidade `[T]`).
- **Cristais** – vão direto para a carteira ao coletar cristal (blocos de cristal, ametista,
  baús e artefatos). Não ocupam carga.
- **Núcleos Antigos** – apenas por prestígio (Fase 4).

| Recurso | Preço | Recurso | Preço | Recurso | Preço |
|---|---|---|---|---|---|
| Carvão | 18 | Ouro | 200 | Diamante | 900 |
| Cobre | 30 | Obsidiana | 220 | Minério arcano | 600 |
| Ferro | 50 | Esmeralda | 280 | Meteorito | 1200 |
| Quartzo | 60 | Titânio | 340 | Artefato | 1500 |
| Prata | 80 | Fóssil | 350 | Cristal raro | 1800 |
| Ametista | 130 | Rubi | 380 | Cristal | → Cristais |
| | | Urânio | 450 | | |

**Minérios raros e valiosos (0.8)**: os minérios ficam concentrados em poucos veios
(`WorldGenerator.VEIN_*`, `Balance.ORE_DENSITY = 0.35`): ~5% dos blocos no Vale e 2–4% nas
outras regiões (antes 10–17%), com preços ~3× maiores. Terreno não rende. A energia da
Sobrecarga vem do valor coletado (`ENERGY_PER_CREDIT = 0.3`), então também está nos minérios.
**Brilho por valor** (`TerrainSkins.glow_tier`, desenhado por `OreGlow`): ≥120 cintila
(ouro, cristal); ≥300 cintila, pulsa com aura e solta partículas (gemas, urânio, titânio,
diamante, cristal raro) — visíveis de longe, convidam a desviar até eles.

A **carga não tem limite** e a **garagem abre de qualquer profundidade** (botão no HUD),
pausando o jogo. Assim sessões curtas sempre terminam com uma compra.

Coleta: `ganho = drops × multiplicador_de_coleta`; a parte fracionária acumula por recurso
entre coletas (determinístico, sem sorteio): com +10%, 10 blocos de cobre rendem 11.

### 7.2 Upgrades (`data/upgrades/*.tres`)
Custo do nível n → n+1: `round(custo_base × crescimento^n)`. Limite `max_level`.
Fórmulas em `Progression` (único lugar onde upgrades viram atributos).

| Upgrade | Moeda | Custo base | Cresc. | Máx | Efeito por nível | Status |
|---|---|---|---|---|---|---|
| Dano | Créditos | 25 | 1.45 | 50 | +2 dano | ✅ Fase 2 |
| Velocidade | Créditos | 40 | 1.50 | 30 | +8% golpes/s | ✅ Fase 2 |
| Crítico | Créditos | 60 | 1.55 | 20 | +2% chance (máx. 75%) | ✅ Fase 2 |
| Coleta | Créditos | 80 | 1.60 | 15 | +10% recursos | ✅ Fase 2 |
| Bateria | Créditos | 50 | 1.40 | 20 | +10% de carga de energia | ✅ |
| Sobrecarga | Cristais | 3 | 1.60 | 10 | +0,5 s e +0,15× golpes/s | ✅ |
| Broca lateral | Créditos | 300 | 1.55 | 10 | nível do módulo | ✅ |
| Drone | Cristais | 6 | 1.70 | 10 | nível do módulo | ✅ |
| Pulso sísmico | Cristais | 8 | 1.70 | 10 | nível do módulo | ✅ |
| Refrigeração | Créditos | 400 | 1.55 | 15 | −6% penalidade de calor | ✅ |

Upgrades de fases futuras aparecem na garagem como **"Em breve"** (já com prévia).
Toda compra mostra **antes → depois** do atributo efetivo. A compra é atômica: ou debita
e sobe o nível, ou não muda nada.

### 7.2.1 Ritmo-alvo (validado por simulação)
`tests/balance_sim.gd` simula a perfuradora real no mundo real do Vale (seed 2024) em
**expedições** (0.9): cada uma começa no elevador mais fundo (descontando o combustível),
extrai com 10% de combustível e, na base, vende tudo e compra o upgrade mais barato.
- **minérios** – vai até o minério visível mais próximo (nunca para cima); com menos de meio
  tanque também busca carvão; sem nada à vista, cava para baixo;
- **reto** – só cava para baixo.

| Vale das Raízes | Buscando minérios | Cavando reto |
|---|---|---|
| Câmara final (250 m) | ~5 min | ~11,5 min |
| Créditos em 12–15 min | ~11 000 | ~60 |
| Upgrades | ~40 | 0–1 |
| Expedições (15 min) | 7, sem resgate | 9 |
| Elevadores | 30, 80 e 150 m | 30, 80 e 150 m |

Testes: `test_balance_simulation_greedy_player` (câmara final entre 2 e 12 min; ≥3
expedições; ≥2 elevadores; ≥10 upgrades; ≥1 módulo; 1ª Sobrecarga após 20 s; 2–30
Sobrecargas; carvão abastece) e `test_seeking_ores_beats_digging_straight` (≥ 4×).

### 7.2.2 Expedições (0.9)
| Parâmetro `[T]` | Valor |
|---|---|
| Tanque | 120 (≈ 2 min de atividade); Tanque +15%/nível |
| Consumo | 1/s movendo ou cavando; ×1,5 na Sobrecarga; Eficiência −5%/nível |
| Carvão | +12 de combustível por bloco |
| Elevador | desce gastando 10% do tanque a cada 100 m |
| Casco | 100; Blindagem +20/nível; calor acima de 1,0 tira 3/s por nível (−refrigeração) |
| Resgate | mantém 50% da carga ganha na expedição |
| Câmara final | 8 blocos de altura no fundo, centro do mapa, relíquia no piso |

### 7.3 Módulos (Fase 3 — implementado)
**2 slots** `[T] MODULE_SLOTS` (um 3º slot é candidato a melhoria permanente de prestígio).
Comprar o 1º nível na aba Upgrades equipa automaticamente se houver slot livre; a aba
Módulos da garagem equipa/remove.

| Módulo | Moeda / custo base | Efeito (nível n) |
|---|---|---|
| Broca lateral | Créditos 300 ×1.55 | Alarga a broca em `5 + 1,2·(n−1)` px: túnel mais largo e mais recursos por golpe. |
| Drone minerador | Cristais 6 ×1.70 | A cada `1,6 − 0,09·(n−1)` s, laser (raio 11 px) no minério mais próximo a até 150 px, dano `0,6 + 0,12·(n−1)` × dano da broca. Nunca acima da máquina. |
| Pulso sísmico | Cristais 8 ×1.70 | Enquanto cava, a cada `8 − 0,4·(n−1)` s, onda de raio `1,6 + 0,12·(n−1)` blocos com dano `1 + 0,2·(n−1)` × dano da broca. Não atinge acima da máquina. |

Visual: brocas nas laterais da máquina, drone orbitando com laser, antena sísmica com anel
de recarga, ondas roxas (douradas quando críticas).

**Sinergia — Ressonância Crítica (Crítico × Pulso):** com o Pulso equipado, cada golpe
crítico devolve 0,6 s da recarga do pulso, e o pulso pode ser crítico com 1,5× a chance de
crítico da broca. Sinergias são declarativas em `SynergyRules.DEFS` (módulos exigidos +
atributo mínimo), prontas para novas combinações.

### 7.4 Energia conquistada e Sobrecarga
A energia **não regenera com o tempo** — é conquistada cavando:

```
carga = (Créditos do material × 0,9 + Cristais × 12) × Bateria ÷ (1 + profundidade/150)
```

Terra rende ~0,8 por bloco; cobre ~6,8; cristal ~22 (de 100). Caçar minérios enche a barra
muito mais rápido — e o movimento livre permite traçar o caminho até os veios.

**Sobrecarga** (botão): só ativa com a barra **100% cheia** e consome tudo. Duração
`6 + 0,5·n` s; golpes/s ×`2,2 + 0,15·n`; deslocamento ×1,35; túnel 30% mais largo
(n = nível do upgrade Sobrecarga). Durante ela a barra esvazia e não carrega. Não há como
acionar repetidamente. Upgrade **Bateria**: +10% de carga por nível.

Simulação (jogador que só cava para baixo): 1ª Sobrecarga após ~65 s; ~9 por 10 min.
A mineração normal nunca depende de energia.

### 7.5 Calor (Fase 3 — implementado)
A partir de 300 m: `calor = clamp((prof − 300)/100, 0, 3)`. Penalidade de golpes/s
`= min(30%, calor × 10%) × (1 − refrigeração)`; Refrigeração: −6%/nível (máx. 90%).
Não destrói recursos. HUD mostra "calor X · −Y%" e tinge a tela de laranja.

### 7.6 Prestígio (Fase 4)
Desbloqueia em 500 m (profundidade máxima da corrida). Núcleos ganhos
`= floor((prof_max − 400) / 50)^1.15`. Reinicia terreno (nova seed), profundidade,
Créditos, Cristais e upgrades da corrida; preserva Núcleos e melhorias permanentes.
Proteção contra duplicação: o ganho é calculado e gravado atomicamente com a nova
corrida, marcado com um `run_id`.

## 8. Direção de arte
Referência visual definida pelo autor (nave e tela de upgrades em pixel art industrial).

- **Nave**: sprite procedural (`ShipArt`, 35×20 px, 2× em jogo) apontando a broca para a
  frente — casco branco, placas amarelas, cabine azul, bloco traseiro escuro com luzes
  azuis, bocais amarelos, pods cinza em cima/embaixo, broca cônica listrada com espiral
  animada. Gira para a direção escavada (espelhada para a cabine ficar em cima).
  Chamas azuis nos bocais, aura na Sobrecarga, acessórios visíveis dos módulos.
- **Interface** (`PixelArt`, `UiTheme`): janelas de aço escuro com bisel e rebites, placa de
  título laranja, valores em caixas escuras com moeda dourada / cristal azul, botão vermelho
  de fechar, cartões com ícone em moldura laranja, "Nv. X", barra segmentada, preço em botão
  dourado e seta verde de compra; vitrine da nave com cantoneiras e faixas de advertência;
  barras de atributos segmentadas (Energia, Velocidade, Poder de mineração, Coleta).
- **Fontes**: Press Start 2P (títulos/números/botões, maiúsculas sem acento) e Jersey 10
  (textos) — ambas OFL. Sem suavização (pixels nítidos).
- **Terreno** orgânico por shader em micro-células, pixels de arte de 3 px. Cada terreno tem
  textura própria (terra macia com pedrinhas, pedra em blocos iluminados, areia, argila em
  camadas, gelo facetado, lama, rocha magmática com veios). Depósitos são pepitas inteiras
  (pertencem à célula do centro, não são recortadas pela borda do material) ou lascas de
  cristal, com contorno escuro e cores distintas.
- **Ambiente do Vale das Raízes (0.7)** — assets reais em `assets/environment/`, gerados por
  código (`EnvArt`, `tools/gen_env_assets.gd`) e aplicados pelo shader sem mudar a geometria:
  - *Texturas de terreno* (64×64 pixels de arte, repetíveis): terra clara/escura, argila, solo
    compacto/úmido/com raízes/com musgo/rachado, pedra clara/cinza/escura, rocha compacta/
    profunda, terra avermelhada, solo arenoso e solo misto — torrões em "bolhas" com pontinho
    de brilho e vãos escuros, como a referência. Amostradas por coordenada de
    mundo; cada material alterna até 4 texturas por ruído de baixa frequência (sem repetição
    evidente) e o terreno é levemente escurecido/dessaturado para os minérios se destacarem.
  - *Progressão por camada no Vale*: superfície = terra clara e solo compacto (raízes como
    decoração); areia instável = solo arenoso/misto e terra escura/úmida com raízes e musgo; argila = argila, terra
    avermelhada e solo rachado; cavernas fossilizadas = pedra cinza/escura e rocha
    compacta; zona abissal = rocha profunda.
  - *Depósitos* (16×16 = um bloco, 3 variações, espelhados; halo translúcido nos luminosos): cubos metálicos (ferro, cobre, prata,
    titânio), pepitas lisas (ouro), gemas lapidadas (diamante), lascas alongadas (cristal
    azul), cristais altos translúcidos (cristal verde/esmeralda), drusa compacta (ametista),
    cristais grandes com brilho (cristal roxo = cristal raro), cristal vermelho (rubi),
    rocha com mineral exposto (urânio), torrões escuros (carvão), quartzo. Topázio tem arte
    pronta, mas não existe como minério no jogo.
  - *Decorações* (só visuais, sem colisão): raízes e pedrinhas embutidas no solo (cortadas
    pelos túneis); musgo, brotos, samambaias, cogumelos, montes de pedra e rochas pontudas
    no chão de cavernas naturais; raízes pendentes, cipós e estalactites no teto. Mais
    vegetação perto da superfície, mais rochas no fundo. Fósseis colecionáveis aparecem
    como osso, crânio, amonite ou costelas.
- **Mapa mundial**: ilhas flutuantes procedurais (`RegionArt`) sobre mar de nuvens, uma
  região por página, placa com o nome, barra de progresso ou cadeado.

## 9. Áudio (Fase 5)
Buses: `Master` → `Music`, `SFX`, `UI`. Sons originais sintetizados (placeholders
identificados). Eventos: impacto, quebra, coleta, upgrade, prestígio.

## 10. Desempenho (metas)
| Item | Meta |
|---|---|
| FPS | 60 (intermediário), ≥30 (básico) |
| Nós por chunk | 1 (`ChunkRenderer`: 1 quad com shader; dados em textura 28×20) |
| Custo de GPU do terreno | ~10 leituras de textura por pixel; validar em aparelho básico (Fase 5) |
| Colisores de física | 0 – colisão por consulta à grade |
| Partículas simultâneas | ≤ `MAX_PARTICLES = 260` (`[T]`; reduzido na qualidade baixa) |
| Geração de chunk | < 2 ms (medido em teste) |
