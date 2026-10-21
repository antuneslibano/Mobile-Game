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

## 4. Controles

| Ação | Toque | Desktop |
|---|---|---|
| Perfurar para baixo | Segurar o dedo na área de escavação, alinhado à máquina | Segurar botão esquerdo / `Espaço` / `↓` |
| Mover / perfurar lateralmente | Arrastar o dedo para a esquerda/direita da máquina | Arrastar mouse / `←` `→` / `A` `D` |
| Botões grandes inferiores | `◀`, `PERFURAR`, `▶` (multitoque) | Clique |
| Impulso (Fase 3) | Botão `IMPULSO` | `Shift` |

Regras de direção (`[T]` em `Balance`):
- `STEER_DEADZONE_PX = 40` – se o dedo está a menos de 40 px (horizontal, na tela) da
  máquina, a intenção é **perfurar para baixo**; fora disso, **mover** naquela direção.
- Sem intenção horizontal, a máquina se **auto-alinha** à coluna mais próxima
  (`ALIGN_SPEED`), garantindo poços de 1 bloco de largura.
- Mover contra um degrau de 1 bloco com espaço acima → **pulo automático** (`HOP_HEIGHT_BLOCKS`).
- Mover contra uma parede alta segurando o toque → **perfuração lateral** (multiplicador
  `SIDE_DRILL_MULT = 0.6` da taxa normal).
- A máquina **não** perfura para cima.

## 5. Mundo

### 5.1 Grade e chunks
| Parâmetro | Valor `[T]` |
|---|---|
| Tamanho do bloco | 48 px na tela (arte em 16 px, escala 3×, filtro nearest) |
| Largura do mundo | 24 colunas (colunas 0 e 23 são rocha-mãe indestrutível) |
| 1 bloco | 1 metro de profundidade |
| Altura do chunk | 16 linhas (chunks são faixas horizontais da largura toda) |
| Chunks carregados | do chunk visível acima −1 até abaixo +2 (antecipados em thread) |
| Geração por quadro | no máximo `GEN_CHUNKS_PER_FRAME = 1` chunk antecipado; chunk sob a câmera é síncrono |
| Profundidade máxima | 1000 m; abaixo disso, rocha-mãe ("crosta do Núcleo", meta futura) |

### 5.2 Geração determinística
Função pura `(seed, x, y) → block_id` (`WorldGenerator`). Mesma seed ⇒ mesmo mundo em
qualquer dispositivo. Ingredientes:
- `FastNoiseLite` (embutido no Godot) para cavernas, mistura de material e veios de minério.
- Hash inteiro próprio (sem dependência de `randf`) para dispersão de minérios e variantes visuais.
- Regras por profundidade (bioma), com borda de bioma "serrilhada" por ruído (±4 m).
- Primeiras 6 linhas sem cavernas (início seguro).

Cavernas: `cave_noise(x, y) > limiar_do_bioma` ⇒ ar. Proporção medida: Crosta ~17%,
Cristalinas ~29%, Magmática ~21%, Abismo ~23% (teste `test_biome_content_and_caves`).

### 5.3 Biomas
| Bioma | Faixa | Materiais | Limiar de caverna `[T]` | Calor (Fase 3) |
|---|---|---|---|---|
| Crosta | 0–100 m | terra, pedra, cobre, ferro, baú | 0.67 | 0 |
| Cavernas Cristalinas | 100–300 m | rocha cristalina, rocha dura, cristal, ametista | 0.60 | 0 |
| Zona Magmática | 300–600 m | basalto, rocha magmática, ouro, rubi | 0.65 | 1 → 3 |
| Abismo Ancestral | 600–1000 m | pedra abissal, vazionita, artefato | 0.63 | 3 |

### 5.4 Blocos (`BlockRegistry`)
`hp` = vida; `hardness` = armadura subtraída de cada golpe. `drops` define recursos
(usados a partir da Fase 2). Valores `[T]`:

| id | Bloco | HP | Dureza | Drops | Bioma |
|---|---|---|---|---|---|
| 0 | Ar | – | – | – | – |
| 1 | Terra | 6 | 0 | terra ×1 | Crosta |
| 2 | Pedra | 14 | 1 | pedra ×1 | Crosta |
| 3 | Cobre | 18 | 1 | cobre ×1 | Crosta |
| 4 | Ferro | 26 | 2 | ferro ×1 | Crosta |
| 5 | Rocha-mãe | ∞ | – | – | paredes/fundo |
| 6 | Baú soterrado | 10 | 0 | cobre ×3, ferro ×2 | Crosta (raro, especial) |
| 7 | Rocha cristalina | 30 | 3 | pedra ×1 | Cristalinas |
| 8 | Rocha dura | 45 | 5 | pedra ×2 | Cristalinas |
| 9 | Cristal | 35 | 3 | cristal ×1 | Cristalinas |
| 10 | Ametista | 50 | 4 | ametista ×1, cristal ×1 | Cristalinas |
| 11 | Basalto | 70 | 8 | basalto ×1 | Magmática |
| 12 | Rocha magmática | 90 | 10 | basalto ×1 | Magmática |
| 13 | Ouro | 85 | 9 | ouro ×1 | Magmática |
| 14 | Rubi | 110 | 11 | rubi ×1 | Magmática |
| 15 | Pedra abissal | 150 | 16 | pedra abissal ×1 | Abismo |
| 16 | Vazionita | 200 | 18 | vazionita ×1 | Abismo |
| 17 | Artefato | 120 | 12 | artefato ×1 | Abismo (raro, especial) |

### 5.5 Distribuição de minérios (`[T]` em `WorldGenerator.ORE_TABLES`)
Cada bioma tem uma tabela `(bloco, chance base, profundidade mínima)`. Um veio
(ruído de minério > 0.25) multiplica a chance por 3, formando aglomerados.

## 6. Perfuradora e mineração

| Atributo (Fase 1, base) `[T]` | Valor |
|---|---|
| Dano por golpe | 4 |
| Golpes por segundo | 6 |
| Chance de crítico | 5% |
| Multiplicador crítico | 2.0× |
| Velocidade horizontal | 4.5 blocos/s |
| Gravidade | 32 blocos/s² |
| Queda máxima | 14 blocos/s |
| Colisor | 0.78 × 0.84 bloco (cabe em poço de 1 bloco) |

Fórmula de dano por golpe (centralizada em `MiningRules`):

```
bruto      = dano × (crítico ? mult_crítico : 1)
efetivo    = max(bruto − dureza, bruto × MIN_DAMAGE_RATIO)      MIN_DAMAGE_RATIO = 0.15
lateral    = efetivo × SIDE_DRILL_MULT (se perfuração lateral)
```

Assim, a dureza torna upgrades de dano essenciais nos biomas profundos, mas nunca
impede totalmente a mineração (piso de 15%).

Feedback: tremor da máquina e da câmera, poeira/lascas na cor do bloco, faíscas em
críticos e em rocha-mãe, rachaduras em 4 estágios sobre o bloco, partículas de
destruição.

## 7. Progressão (Fases 2–4, especificado agora para preparar a arquitetura)

### 7.1 Moedas
- **Créditos** – venda de minérios na garagem.
- **Cristais** – depósitos especiais (cristal, ametista, baús, artefatos).
- **Núcleos Antigos** – apenas por prestígio.

### 7.2 Upgrades
Custo: `custo(n) = custo_base × crescimento^n`, arredondado. Limite `max_level`.
Efeito: `valor(n) = base + passo × n` (ou multiplicativo, por upgrade).

| Upgrade | Moeda | Custo base | Cresc. | Máx | Efeito por nível |
|---|---|---|---|---|---|
| Dano | Créditos | 25 | 1.35 | 50 | +2 dano |
| Velocidade | Créditos | 40 | 1.40 | 30 | +8% golpes/s |
| Crítico | Créditos | 60 | 1.45 | 20 | +2% chance |
| Capacidade de energia | Créditos | 50 | 1.40 | 20 | +15 energia |
| Coleta | Créditos | 80 | 1.50 | 15 | +10% recursos |
| Impulso | Cristais | 3 | 1.60 | 10 | +0.5 s duração, +10% força |
| Broca lateral | Créditos | 300 | 1.55 | 10 | desbloqueia/melhora módulo |
| Drone | Cristais | 10 | 1.70 | 10 | desbloqueia/melhora módulo |
| Pulso sísmico | Cristais | 15 | 1.70 | 10 | desbloqueia/melhora módulo |
| Refrigeração | Créditos | 400 | 1.55 | 15 | −6% penalidade de calor |

Toda compra mostra **antes → depois**.

### 7.3 Módulos (Fase 3)
3 slots iniciais. Broca lateral (golpeia blocos adjacentes), Drone minerador
(minera autonomamente um bloco próximo), Pulso sísmico (onda periódica de dano em
área). Sinergia **Crítico × Pulso**: críticos acumulam carga e reduzem o tempo de
recarga do pulso. Arquitetura de sinergias por regras declarativas.

### 7.4 Energia e impulso (Fase 3)
Energia máx. 100 `[T]`, regeneração 8/s `[T]`. Impulso custa 40, dura 3 s, ×1.8 de
golpes/s. Energia **nunca** bloqueia a mineração normal.

### 7.5 Calor (Fase 3)
A partir de 300 m: `calor = clamp((prof − 300)/100, 0, 3)`. Penalidade de eficiência
`= calor × 10% × (1 − refrigeração)`, máx. 30%. Não destrói recursos.

### 7.6 Prestígio (Fase 4)
Desbloqueia em 500 m (profundidade máxima da corrida). Núcleos ganhos
`= floor((prof_max − 400) / 50)^1.15`. Reinicia terreno (nova seed), profundidade,
Créditos, Cristais e upgrades da corrida; preserva Núcleos e melhorias permanentes.
Proteção contra duplicação: o ganho é calculado e gravado atomicamente com a nova
corrida, marcado com um `run_id`.

## 8. Direção de arte
- Pixel art procedural original (gerada em código, sem assets externos), 16 px por bloco.
- Máquina: amarelo industrial `#F2B33D`, metal `#6E7A86`, luzes azuis `#4FC3FF`.
- Paletas por bioma: Crosta (marrons/terrosos), Cristalinas (azul-violeta frio),
  Magmática (preto-basalto e laranja), Abismo (verde-petróleo e roxo profundo).
- Contorno claro na borda superior dos blocos expostos e sombra na inferior.
- Fundo "parede de caverna" escurecida atrás de blocos escavados.

## 9. Áudio (Fase 5)
Buses: `Master` → `Music`, `SFX`, `UI`. Sons originais sintetizados (placeholders
identificados). Eventos: impacto, quebra, coleta, upgrade, prestígio.

## 10. Desempenho (metas)
| Item | Meta |
|---|---|
| FPS | 60 (intermediário), ≥30 (básico) |
| Nós por chunk | 1 (`ChunkRenderer` com `_draw` em lote, 1 textura atlas) |
| Colisores de física | 0 – colisão por consulta à grade |
| Partículas simultâneas | ≤ `MAX_PARTICLES = 260` (`[T]`; reduzido na qualidade baixa) |
| Geração de chunk | < 2 ms (medido em teste) |
