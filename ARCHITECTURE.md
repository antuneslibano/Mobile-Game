# DEEPFORGE — Arquitetura

## 1. Princípios

1. **Regras ≠ dados ≠ renderização ≠ interface.** Cada camada fica em sua pasta e só
   conversa com a de baixo por API explícita ou sinais.
2. **Modelo do mundo sem nós.** O terreno é dados (`PackedByteArray` por chunk). Nenhum
   `Node2D` ou colisor por bloco. A renderização desenha chunks inteiros em lote.
3. **Determinismo.** Geração é função pura de `(seed, x, y)`; o que muda é registrado como
   *modificação* e é isso que se salva.
4. **Testável sem cena.** `WorldModel`, `WorldGenerator`, `MiningRules` e a física/mineração
   da `Drill` funcionam com objetos puros e são exercitados pelos testes headless.
5. **Extensível por fases.** Pontos de extensão já existem (ex.: `DrillStats` virá do
   `ProgressionService`; `EventBus.block_destroyed` alimentará o inventário).

## 2. Estrutura de pastas

```
project.godot              configuração (retrato 720×1280, Compatibility, autoloads)
icon.svg                   ícone original
data/upgrades/*.tres       definições de upgrades (editáveis no Inspector)
scenes/
  main.tscn                raiz: Game + HUD
  game/game.tscn           mundo: fundo, terreno, overlay, perfuradora, FX, câmera, input
  gameplay/drill.tscn      perfuradora (lógica + visual)
  ui/hud.tscn              HUD superior e controles inferiores
scripts/
  autoload/                singletons globais (apenas estado e sinais)
    event_bus.gd           EventBus – barramento de sinais de jogo
    game_state.gd          GameState – estado da corrida, região atual, progresso por região, perfil
    save_service.gd        SaveService – carrega/salva o perfil (debounce, pausa/saída do app)
  data/                    definições estáticas e balanceamento (sem lógica de cena)
    balance.gd             Balance – constantes ajustáveis
    block_def.gd           BlockDef (Resource)
    block_registry.gd      BlockRegistry – tabela de blocos
    biome_def.gd           BiomeDef (Resource)
    biome_registry.gd      BiomeRegistry – camadas da região ativa (id_for_row)
    region_def.gd          RegionDef (Resource) – região do mapa: camadas, recursos, riscos, desbloqueio
    region_registry.gd     RegionRegistry – as seis regiões, riscos, regras de desbloqueio/progresso
    terrain_skins.gd       TerrainSkins – textura por material/camada, sprite por depósito, decorações
    resource_def.gd        ResourceDef (Resource) – recurso coletável e preço
    resource_registry.gd   ResourceRegistry – tabela de recursos
    upgrade_def.gd         UpgradeDef (Resource) – definição de upgrade
    upgrade_registry.gd    UpgradeRegistry – lista ordenada (caminhos explícitos)
  save/save_file.gd        SaveFile – JSON com escrita atômica (.tmp → .bak), validação, .corrompido
  economy/                 regras de economia, sem nós
    economy.gd             Economy – carteira, carga, níveis de upgrade
    progression.gd         Progression – custos, compra atômica, atributos, antes/depois
  world/                   modelo e renderização do terreno
    world_generator.gd     WorldGenerator – (seed,x,y) → id, puro
    chunk_data.gd          ChunkData – ids de um chunk
    world_model.gd         WorldModel – cache de chunks, modificações, dano
    terrain_view.gd        TerrainView – carrega/descarrega e recicla ChunkRenderers
    chunk_renderer.gd      ChunkRenderer – 1 quad por chunk com o shader de terreno; dados em textura
    cave_decor.gd          CaveDecor – vegetação/pedras de caverna do chunk (só desenho)
    ore_glow.gd            OreGlow – cintilação, aura e partículas dos minérios valiosos do chunk
    mining_overlay.gd      MiningOverlay – brilho de impacto
  render/
    terrain_textures.gd    TerrainTextures – paleta, ruído, atlas (dos PNGs) e tabelas da região ativa
    env_art.gd             EnvArt – gerador da pixel art do ambiente (usado só por tools/)
    background.gd          Background – céu, superfície e base
  gameplay/
    energy_system.gd       EnergySystem – energia e impulso (puro)
    heat_rules.gd          HeatRules – calor e penalidade (puro)
    module_system.gd       ModuleSystem – broca lateral, drone, pulso (puro, sinais p/ visuais)
    synergy_rules.gd       SynergyRules – sinergias declarativas
    drill_stats.gd         DrillStats – atributos efetivos (base + upgrades futuros)
    ship_vitals.gd         ShipVitals – combustível e casco da expedição (puro)
    drill_intent.gd        DrillIntent – intenção de controle (mover, perfurar, impulso)
    mining_rules.gd        MiningRules – fórmula de dano centralizada
    drill.gd               Drill – física em grade, colisão, alvo de perfuração, golpes
    drill_visual.gd        DrillVisual – desenho e animação da máquina
    input_controller.gd    InputController – toque/mouse/teclado → DrillIntent
  camera/depth_camera.gd   DepthCamera – seguimento suave, limites, tremor
  fx/debris_fx.gd          DebrisFx – partículas em pool (struct-of-arrays, 1 nó)
  fx/pickup_fx.gd          PickupFx – textos "+2 Cobre" (1 nó, pool limitado)
  fx/module_fx.gd          ModuleFx – drone, lasers e ondas do pulso
shaders/terrain.gdshader   terreno orgânico (campo contínuo sobre a grade)
  game/game.gd             Game – composição e ligação dos sistemas do mundo
  ui/hud.gd                Hud – leitura de estado, áreas de toque, botão da garagem
  ui/garage.gd             Garage – vender carga, abas Upgrades/Módulos (pausa o jogo)
  ui/upgrade_card.gd       UpgradeCard – nível, antes → depois, botão de compra
  ui/virtual_joystick.gd   VirtualJoystick – desenho do joystick flutuante
  ui/pixel_art.gd          PixelArt – primitivas, estilos 9-slice (metal, placas, botões) e ícones
  ui/segmented_bar.gd      SegmentedBar – barras segmentadas (níveis, atributos, energia)
  ui/ship_preview.gd       ShipPreview – vitrine da nave na garagem
  ui/world_map.gd          WorldMap – tela do mapa mundial (carrossel + painel de informações, pausa)
  ui/region_carousel.gd    RegionCarousel – deslizar horizontal com encaixe, setas e indicadores
  ui/region_art.gd         RegionArt – ilustração procedural (ilha flutuante) por região
  ui/touch_scroll.gd       TouchScroll – rolagem por arrasto com inércia (cancela o toque no botão)
  ui/expedition_report.gd  ExpeditionReport – resultado da expedição (extração/resgate)
  game/elevator_rig.gd     ElevatorRig – cabo da cápsula de extração (visual)
  game/final_guardian.gd   FinalGuardian – guardião da câmara final (regras dos pulsos/vida e arte)
  gameplay/ship_art.gd     ShipArt – sprite procedural da nave (quadros da broca)
assets/fonts/              Press Start 2P e Jersey 10 (OFL 1.1, licenças incluídas)
assets/environment/        terrain/ ores/ vegetation/ decorations/ – PNGs (importados como Image)
tools/gen_env_assets.gd    regenera os PNGs do ambiente
  ui/ui_theme.gd, gem_icon.gd, pad_button.gd – tema e componentes desenhados em código
  debug/autopilot.gd       Autopilot – bot de teste (--autotest) e captura de tela
  main.gd                  Main – raiz, argumentos de linha de comando
tests/
  run_tests.gd             runner headless (SceneTree)
  test_case.gd             base de asserções
  test_*.gd                suítes
```

## 3. Grafo de cenas (Fase 1)

```
Main (Node, main.gd)
├── Game (Node2D, game.gd)                     scenes/game/game.tscn
│   ├── Background (Node2D, z=-10)
│   ├── TerrainView (Node2D)  → N × ChunkRenderer (pool, criados em código)
│   ├── MiningOverlay (Node2D, z=1)
│   ├── Drill (Node2D, drill.gd, z=2)          scenes/gameplay/drill.tscn
│   │   └── Visual (Node2D, drill_visual.gd)
│   ├── DebrisFx (Node2D, z=3)
│   ├── ModuleFx (Node2D, z=3)
│   ├── PickupFx (Node2D, z=4)
│   ├── DepthCamera (Camera2D)
│   └── InputController (Node)
├── Hud (CanvasLayer, layer=10, hud.gd)        scenes/ui/hud.tscn
└── Garage (CanvasLayer, layer=20, garage.gd)  criado por main.gd; PROCESS_MODE_ALWAYS
```

## 4. Fluxo de dados

```
toque/mouse/teclado ──► InputController ──► DrillIntent ──► Drill.step(delta)
                              ▲  consulta áreas            │  colisão: WorldModel.is_solid()
                              │                            │  golpe:   MiningRules.compute_hit()
                             Hud                           │           WorldModel.damage_cell()
                                                           ▼
                     WorldModel.cell_changed ──► TerrainView ──► ChunkRenderer.queue_redraw()
                     Drill.block_hit/destroyed ──► Game ──► DebrisFx, MiningOverlay, DepthCamera.shake
                                                     └──► EventBus.block_hit / block_destroyed
                     Game._process ──► GameState.update_depth() ──► EventBus.depth_changed ──► Hud

Fase 2 — economia:
  Drill.dug(células) ──► Game ──► Drill.drops_for() ──► GameState.collect_drops() ──► Economy.collect(drops × coleta)
                                                    └─► EventBus.resources_collected ──► PickupFx
                                                    └─► EventBus.wallet_changed / cargo_changed ──► Hud, Garage
  Garage (botão) ──► GameState.sell_cargo() / buy_upgrade() ──► Progression.try_buy()
                                         └─► GameState.stats = Progression.build_stats(níveis)
                                         └─► EventBus.stats_changed ──► Game ──► Drill.stats
```

Regra: **toda mutação de economia passa por GameState**, que publica os eventos. `Economy`
e `Progression` são puros (testados sem cena); a UI apenas lê e chama GameState.

## 5. Sinais (EventBus)

| Sinal | Parâmetros | Emissor | Ouvintes (fase) |
|---|---|---|---|
| `block_hit` | `point: Vector2, material_id: int, crit: bool` | Game | Áudio (5) |
| `material_dug` | `at: Vector2, counts: Dictionary` (material → células) | Game | Hud, Áudio (5) |
| `depth_changed` | `depth_m: int, max_depth_m: int` | GameState | Hud, Prestígio (4) |
| `biome_changed` | `biome_id: int` | GameState | Hud, Áudio (5), Calor (3) |
| `run_started` | `seed: int` | GameState | Hud |
| `resources_collected` | `at: Vector2, gained: Dictionary` | GameState | PickupFx (via Game), Áudio (5) |
| `overdrive_ready` | – | Game (de Drill) | Hud (aviso), Áudio (5) |
| `wallet_changed` | `credits: int, crystals: int` | GameState | Hud, Garage |
| `cargo_changed` | `item_count: int, value: int` | GameState | Hud, Garage |
| `cargo_sold` | `credits_gained: int` | GameState | Áudio (5), Save (4) |
| `upgrade_purchased` | `id: StringName, new_level: int` | GameState | Save (4) se `important`, Áudio (5) |
| `stats_changed` | – | GameState | Game → Drill |
| `garage_opened` / `garage_closed` | – | Garage | InputController (limpa toques), Save (4) |
| `modules_changed` | `equipped: Array[StringName]` | GameState | Game → Drill.modules, Garage |
| `boost_started` | – | Game (de Drill) | Áudio (5) |
| `region_changed` | `region_id: StringName` | GameState | Hud |
| `region_progress_changed` | `region_id, depth_m` (a cada 10 m de recorde) | GameState | SaveService |
| `region_unlocked` | `region_id: StringName` | GameState | SaveService, Hud (aviso) |
| `map_opened` / `map_closed` | – | WorldMap | InputController (limpa toques), SaveService |
| `expedition_started` / `expedition_ended` | região, início (m) / relatório | GameState | SaveService, testes |
| `elevator_unlocked` | região, profundidade | GameState | Hud (aviso) |
| `objective_completed` / `region_completed` | região, objetivo, texto / região | GameState | Hud (aviso) |

Sinais locais: `WorldModel.cell_changed(cell)`, `WorldModel.chunk_generated(index)`,
`Drill.block_hit(...)`, `Drill.block_destroyed(...)`, `Drill.blocked_by_unbreakable(cell)`.

## 6. Terreno (micro-células)

- **Unidades**: bloco = 48 px (design: vida, drops, metros); **micro-célula** = 12 px
  (dados reais). Célula `(cx, cy)`; `cy = 0` é a superfície; `cy < 0` é céu.
- **Geração** (`WorldGenerator`): layout de blocos (`generate_block`) → micro-células
  amostrando o layout com deformação fractal (tabela 256² de ruído, ±4 células).
  `generate_chunk` calcula o layout do chunk + margem uma vez; `generate_cell` gera uma
  célula avulsa (vizinhos fora de chunks carregados). Especiais (baú, artefato) não se
  deformam.
- **Chunk** = 96 × 64 células (`ChunkData.ids` + `dmg` de desgaste). Antecipação em
  `WorkerThreadPool`; visíveis síncronos; descarregamento com histerese.
- **Modificações**: `_mods` (chunk → índice local → id) sobrevivem ao descarregamento;
  exportáveis em JSON (Fase 4).
- **Escavação**: `dig_circle` / `dig_cells` aplicam um golpe a várias células (dureza por
  célula, desgaste acumulado) e retornam `DigResult` (células removidas por material).
  `min_y` impede escavar acima da máquina. `blocking_cells` / `circle_hits_solid` dão a
  colisão do corpo circular. Lotes de alterações saem em `cells_changed`.
- **Renderização**: cada `ChunkRenderer` mantém uma textura de dados 100 × 68 (halo de 2):
  r = material, g = desgaste, b = bioma, a = sólido; um quad com `terrain.gdshader`
  suaviza o campo em contornos curvos. Alterações atualizam texels e sobem 1× por quadro.

## 7. Perfuradora (movimento livre)

- Corpo = círculo (15 px); broca = círculo (24 px) 12 px à frente na direção `facing`.
- `DrillIntent.aim` (qualquer ângulo, y ≥ 0) → velocidade desejada; gravidade; colisão
  contínua por subpassos com deslizamento por eixo. **`velocity.y` nunca é negativa.**
- Golpes a `hits_per_second × speed_mult`: escava broca ∪ células que bloqueiam o corpo à
  frente, nunca acima de `dig_ceiling()`. Sinais: `dig_hit` (FX), `dug` (drops),
  `blocked_by_unbreakable`, `boost_started`, `overdrive_ready`.
- `EnergySystem` (carga conquistada pelo valor do material; Sobrecarga só com barra cheia),
  `HeatRules`, `ModuleSystem` (alarga a broca, drone, pulso — via `apply_external_dig`) e
  `SynergyRules` são puros e avançados em `physics_step`.

## 8. Entrada

`InputController._unhandled_input` processa `InputEventScreenTouch/Drag` (o mouse vira
toque via `emulate_touch_from_mouse`). Cada índice de toque é rastreado: toques sobre a
barra inferior acionam `◀ / PERFURAR / ▶` (multitoque real); toques na área de escavação
viram direção relativa à posição da máquina na tela; toques sobre a barra superior são
ignorados (`Hud.is_point_blocking`). Teclado (`←→AD`, `↓ S Espaço`) é somado para desktop.

## 9. Preparação para as próximas fases

| Fase | Encaixe |
|---|---|
| 2 – Economia | ✅ `Economy` + `Progression` (puros) sob `GameState`; `UpgradeDef` em `data/upgrades/`; `Garage` (CanvasLayer em código). |
| 3 – Módulos/energia/calor | ✅ `EnergySystem`, `HeatRules`, `ModuleSystem` e `SynergyRules` puros, pertencentes à `Drill` e avançados em `physics_step`; golpes de módulos usam `Drill.apply_external_hit/break_external` (mesmos sinais, drops e FX). Joystick no `InputController`. Terreno por shader. |
| 4 – Prestígio/persistência | `SaveService` (temp + rename, `schema_version`, validação), `WorldModel.export_mods()/import_mods()`, `PrestigeService` com `run_id`. |
| 5 – Polimento | `AudioService` + buses `Music/SFX/UI`, preset de qualidade (`Balance.QUALITY`), export Android. |

## 10. Desempenho (perfil esperado)

| Sistema | Custo por quadro |
|---|---|
| TerrainView | O(chunks carregados) – só compara índices; sem varrer células |
| ChunkRenderer | 0 quando estático; redesenho de 384 células apenas no chunk alterado |
| Drill | O(células sob o AABB) ≈ 4–6 consultas por subpasso |
| DebrisFx | O(partículas vivas) ≤ 260; inativo quando vazio |
| Nós ativos | ~15 + chunks carregados (≈5) |

Detalhes medidos ficam no `README.md` (seção Desempenho) após cada fase.

## 11. Regiões, mapa e salvamento

- **Região → mundo**: `GameState.start_dive(region_id, seed)` aplica a região
  (`BiomeRegistry.set_layers`, `HeatRules.heat_start_m`, `TerrainTextures.apply_layers`) e
  `Game.start_run` cria `WorldModel.new(seed, region)`; `WorldGenerator` guarda as próprias
  camadas (seguro em threads). O fundo (`Background.setup`) usa as cores da região.
- **Mapa** (`WorldMap`, CanvasLayer 25, pausa o jogo): abre ao iniciar e pelo botão de mapa
  do HUD. `RegionCarousel` desenha as páginas num único Control; arrasto > 18% da largura ou
  "flick" > 900 px/s troca de página, com encaixe exponencial e resistência elástica nas
  pontas; toque e mouse são tratados de forma idempotente. EXPLORAR emite
  `explore_requested(region_id)` → `Main._on_explore` (mesma região com mergulho ativo
  apenas fecha o mapa).
- **Terreno × depósito no shader**: a paleta tem a coluna 6 = tipo de arte, coluna 7 = brilho.
  Terrenos têm estilos próprios em `terrain_col`; depósitos usam a rocha hospedeira vizinha
  como fundo. Pepitas metálicas são decididas pela célula do **centro** da pepita (voronoi),
  então nunca ficam recortadas pela borda ondulada do material.
- **Salvamento** (`SaveService` + `SaveFile`): `user://deepforge_profile.json` com esquema 1:
  economia (créditos, cristais, carga, upgrades, módulos), região atual e profundidade máxima
  por região. O terreno escavado **não** é salvo (cada mergulho gera um mundo novo). Grava
  com debounce de 3 s após compra, venda, recorde de 10 m, desbloqueio, troca de região,
  fechamento de garagem/mapa e imediatamente ao pausar/fechar o app. Leitura valida tudo
  (`Economy.from_dict`, ids de região) e cai para o `.bak` se o principal estiver corrompido.

## 12. Ambiente visual (texturas, depósitos, decorações)

- **Assets**: `EnvArt` desenha a pixel art (determinística; texturas periódicas) e
  `tools/gen_env_assets.gd` grava os PNGs em `assets/environment/{terrain,ores,vegetation,
  decorations}`. Os PNGs usam `importer="image"` (pixels exatos, também no APK) e podem ser
  retocados à mão; o jogo nunca os regenera.
- **Atlas**: `TerrainTextures` monta três atlas (texturas 64×64, depósitos 16×16 × 3
  variações, decorações 32×32) e duas tabelas da região ativa: `skin_tex` (bloco × camada →
  até 4 texturas) e `decor_tex` (camada → decoração embutida por faixa de sorteio +
  densidade). `GameState.apply_region` chama `TerrainTextures.apply_region`.
- **Shader** (mesma geometria, mesmas bordas): `surface_col` amostra a textura do material
  por pixel de arte (`texelFetch`, sem filtro); sem pele usa o procedural antigo.
- **Transições (mistura por altura)**: o material de cada pixel vem de 4 células em volta de
  uma grade deformada por ruído fractal (duas oitavas: `material_warp`, `material_warp2`).
  Cada superfície (material + camada) soma seus pesos bilineares; as duas mais fortes se
  misturam por altura (`height_pick`: vence a de relevo — brilho do torrão — mais alto somado
  ao peso, `blend_height`). O mesmo vale para as variações dentro de um material (manchas
  selecionadas por ruído com deformação de domínio). Escolha discreta: pixels nítidos.
- **Depósitos**: um aglomerado 16×16 por bloco de minério (variação e espelho por bloco),
  inteiro e com contorno, decidido pela célula do centro do bloco (a grade de blocos
  coincide com a dos chunks); se o centro foi escavado, o resto do veio ainda mostra o
  minério. Brilho dos valiosos: `OreGlow` (filho do `ChunkRenderer`, mistura aditiva, some
  quando o centro do bloco é escavado). Decorações embutidas: um sítio de 36 pixels de arte.
- **Câmera anti-cintilação**: `DepthCamera` suaviza em ponto flutuante e desenha em passos
  inteiros em pixels do jogo e do aparelho (`step_for_scale`: 1,5× → 2 px), tremor incluído.
- **Listas roláveis**: `TouchScroll` (garagem, mapa) rola por arrasto em qualquer ponto, com
  inércia; ao virar arrasto cancela o toque no botão de origem (move o "mouse" para longe e
  solta lá), então rolar nunca compra. Fósseis: sprite por bloco.
- **Cavernas**: `CaveDecor` (filho do `ChunkRenderer`) planeja, ao montar o chunk, plantas no
  chão e raízes no teto de cavernas naturais (`WorldModel.is_modified` exclui túneis) e as
  remove quando a célula de apoio é escavada. Sem colisão; desenho em um único CanvasItem.

## 13. Expedições (0.9)

- **Fluxo** (`Main`): base = `WorldMap` (GARAGEM, EXPLORAR) →
  `_start_expedition` (`GameState.start_dive` com a seed fixa da região, `Game.start_run`
  com a escavação salva, sempre da superfície, `GameState.begin_expedition`). A câmera abre
  enquadrando o céu e a base (`DepthCamera.intro`) e desce quando a nave começa a se mover.
  → EXTRAIR (`Game.play_extraction`, cabo do `ElevatorRig`) ou `Drill.stranded` (resgate após
  1,2 s) → `GameState.end_expedition` (perdas, estrelas, escavação codificada) →
  `ExpeditionReport` → base.
- **Combustível/casco** (`ShipVitals`, dono: `Drill`): gasto por atividade, Sobrecarga ×1,5,
  carvão abastece (`BlockDef.fuel`), calor acima de `HEAT_SAFE_LEVEL` fere o casco. Zerar
  qualquer um desliga a nave (`disabled`) e emite `stranded`.
- **Fundo da região**: `WorldGenerator._cell` devolve rocha-mãe a partir de
  `target_depth_m` e escava a câmara final (elipse com ruído, no centro).
  `GameState.check_final_chamber` só avisa a chegada (`final_chamber_reached`).
- **Guardião** (`FinalGuardian`, filho de `Game`): corpo de rocha-mãe cobrindo o piso da
  arena, gerado em `WorldGenerator._forced_cell` enquanto `generator.guardian_alive` (falso
  quando a região já foi concluída); a arena plana é escavada em `_cell`. Regras puras em
  `FinalGuardian.step` (agenda de ataques com RNG próprio, fases, acerto círculo × retângulo,
  invulnerabilidade), `on_body` e `take_damage`; `safe_dir` é o desvio usado pelo bot e pela
  simulação. `Game._guardian_step` liga o modo de combate da câmera
  (`DepthCamera.combat`: zoom e enquadramento fixo; evento `guardian_combat`), aplica os
  acertos no casco (`Drill.apply_hull_damage`, evento `guardian_hit`) e o dano/s da broca
  enquanto a nave anda sobre o corpo; ao vencê-lo, abre o piso (`WorldModel.fill_cells`, salvo
  na escavação), dá a recompensa e emite `guardian_defeated` → `GameState.complete_region` →
  painel do HUD (voltar à base/continuar). Fora do combate a câmera não desce abaixo do
  fundo da região (`DepthCamera.bottom_limit`).
- **Persistência**: `profile_seed` → `region_seed(id)`; escavação por região codificada
  (índice local u16 + material u8, base64 por chunk); objetivos, estatísticas por
  região e a expedição em andamento (fechar o app no meio = resgate) vão no perfil.

## 14. Base e construção (0.10)

- **Fluxo**: `Main` abre `BaseScreen` (galpão desenhado por `BaseView`, cinco botões de
  estação) ao iniciar e depois de cada relatório. `station_requested` → `&"map"` abre o
  `WorldMap` (EXPLORAR fecha mapa e base); as demais abrem `Garage.open_station(kind)`
  (páginas Bancada, Hangar, Mercado e Laboratório). Mapa e estações restauram a pausa ao
  fechar; o "voltar" do Android fecha a tela de cima e, na base, encerra.
- **Receitas** (`Recipes`): trilha de materiais por peça e tier; `requirement` (material não
  descoberto ou projeto grande sem guardião); `reserve` (maior pedido de cada material pelos
  próximos níveis). `Progression.buy_status/try_buy` checam e gastam materiais (atômico).
- **Economia**: `Economy.discovered` (salvo) e `tech` (guardiões vencidos, derivado de
  `GameState.done`); `sell`, `sell_surplus`, `spend_materials`.
- **Diário** (`Journal`): entradas com gatilho `res:<recurso>` / `guardian:<região>`;
  `GameState.journal_seen` controla o alerta do Laboratório.

## 15. Criaturas e visual da nave (0.11)

- **Criaturas**: `Creature` (regras puras sobre a grade: vaga-lume, toupeira, aranha,
  minhoca; `step` devolve a mordida no casco) e `CreatureManager` (filho de `Game`):
  `plan` decide, por chunk e seed, onde nascem (ao carregar o chunk; somem ao descarregar);
  `step` simula só perto da nave, aplica a broca, avisa avistamentos e mortes;
  `area_damage` recebe o pulso sísmico (com atordoamento) e o drone. A minhoca escava com
  `WorldModel.carve_terrain` (só terreno). `GameState.see_creature/defeat_creature` cuidam
  do catálogo (salvo) e das amostras biológicas.
- **Visual da nave**: `ShipLooks` (opções por encaixe e requisitos; `resolve` = escolha
  salva ou a melhor liberada); `ShipArt.frame(i, look)` gera e guarda o sprite de cada
  combinação; `DrillVisual.look`, a vitrine do Hangar e a base usam `GameState.ship_look()`.

## 16. 0.12: broca por nível, rampas, baús e som

- **Níveis de broca**: `MiningRules.required_tier/tier_for_level` (limiares em
  `Balance.DRILL_TIER_LEVELS`); `DrillStats.drill_tier`; `WorldModel.dig_cells(..., drill_tier)`
  devolve `too_hard` e a `Drill` emite `blocked_by_hardness` → HUD "BROCA FRACA".
- **Rampas**: `DrillIntent.sanitize` limita a subida a `CLIMB_SLOPE` do lateral (quase
  vertical = nada); `Drill` deixa os propulsores vencerem a gravidade só nessa proporção e
  não desliza para cima quando trava de lado; `dig_ceiling` libera a broca na subida.
- **Cavernas**: `WorldGenerator._cell` amostra os salões em patamares de 3 blocos e soma
  galerias horizontais (`_gallery`, ruído ridged).
- **Baús**: `Chests.rarity` (posição + seed + profundidade) e `Chests.open` (recompensa e
  planta); `DigResult.chest_blocks` → `Drill.chest_opened` → `Game._on_chest_opened` →
  `GameState.open_chest`; `Economy.blueprints` (salvo) liberam opções `bp:` em `ShipLooks`;
  `OreGlow` pinta a aura do baú com a cor da raridade.
- **Nova área**: `GameState.new_area` incrementa `region_variant` (entra na seed da região)
  e apaga escavação e recorde.
- **Som**: autoload `Sfx` sintetiza `AudioStreamWAV` na inicialização; `play`, `drill`,
  `engine`; loops silenciam com o jogo pausado.

## 17. 0.13: névoa, sonar e broca forçada

- **Névoa** (`FogLayer`, CanvasLayer 2, shader `shaders/fog.gdshader`): escuridão em tela
  com o círculo de luz da nave (`LIGHT_RADIUS_BLOCKS`, convertido pela transformação do
  canvas, então acompanha o zoom do combate) e até 8 luzes extras (vaga-lumes, guardião,
  onda do sonar). O HUD fica na camada 10.
- **Sonar** (`SonarOverlay`, CanvasLayer 3): `ping` (recarga), `step` avança a onda e
  `_scan_ring` marca blocos de minério/baú e criaturas entre o raio anterior e o atual;
  desenho em tela (sinais e setas de borda). Disparo por `DrillIntent.sonar` (botão do HUD
  ou Q).
- **Broca forçada**: `Drill.strain` sobe a cada golpe em minério duro demais e cai com o
  tempo; acima de 1 fere o casco (`STRAIN_*` em Balance).
- **Onda de choque**: `ModuleSystem._step_wave` → `Drill.apply_external_ring` (anéis com o
  teto fixado no disparo).
- **Subida**: `Drill._low_angle` (giro sempre por baixo) e `_supported` (só sobe apoiada).

## 18. 0.14: catálogo, áudio, abertura e desempenho

- **Abertura** (`SplashScreen`, CanvasLayer 40): criada por `main.gd` fora do autotest;
  fica `MIN_SEC`..`MAX_SEC` (espera `Sfx.music_ready`) e se libera com fade.
- **Laboratório**: `Garage._refresh_lab` com abas (`LabTab_*`); grades `_lab_grid`
  (a de minerais chama-se `Catalog`) e fichas `_detail` (nó `LabDetail`).
- **Transições** (`Transitions`): `slide_in`, `fade_in`, `pop_in`, `bump` com tweens que
  rodam com o jogo pausado.
- **Áudio**: `Sfx` gera a trilha numa tarefa do `WorkerThreadPool` (`_build_music_thread`);
  `_process` a inicia quando a tarefa termina; `_exit_tree` espera a tarefa. Criaturas
  tocam sons por `CreatureManager._maybe_sound` (distância, recarga aleatória).
- **Baú**: `WorldModel.dig_cells` remove as 16 células do bloco de baú ao tocar em uma.
- **Receitas**: `Recipes.materials` cresce a cada nível dentro do tier.
- **Desempenho**: `OreGlow` redesenha a 30 Hz só na tela; `GameState.ship_look` em cache
  (500 ms, invalidado em `set_look`).

## 19. 0.15: porta de metal, plantas bioluminescentes e volume

- **Porta** (`ShutterDoor`, CanvasLayer 45): `Transitions.shutter(tree, on_closed)` cria a
  porta, que desce, quica, chama `on_closed` (a troca de tela) e sobe. Desde a 0.15.1
  só no Laboratório (`main._on_station` e `Garage.close_animated` com `_kind == lab`). `Transitions.shutter_enabled = false` deixa a troca imediata (testes).
- **Plantas** (`CaveDecor`): itens `bio_floor`/`bio_ceil` só nas regiões `BIO_REGIONS`,
  com `BIO_CHANCE`, `BIO_SPACING` e `BIO_MIN_ROW`; `bio_lights()` (cache) alimenta a
  `FogLayer` pelo registro estático `CaveDecor.live`. A névoa aceita até 12 luzes.
- **Volume**: `Sfx.DRILL_DB`/`ENGINE_DB`; `music_db = DRILL_DB + linear_to_db(0.25)` com a
  trilha normalizada.

## 20. 0.16: configurações e coleta de minério

- **Áudio por canal**: `Sfx` cria os buses `Musica`, `Efeitos` e `Maquina`; `set_volume`,
  `get_volume`, `save_settings`/`load_settings` (`user://deepforge_settings.json`, fora do
  perfil). `SettingsScreen` (CanvasLayer 35) abre pela engrenagem (`UiTheme.gear_button`)
  da base e do HUD (`settings_requested`).
- **Minério**: em `WorldModel.dig_cells`, quando uma célula de bloco que rende
  (`_whole_block`) quebra, `_vein_piece` pega o pedaço conectado (até 1 bloco; sobras
  pequenas vão junto), que vira `generator.host_terrain`. `DigResult.drop_bonus` completa
  pedaços de meio bloco para um bloco só nos itens (`drop_counts()`); combustível e energia
  usam `counts`.

## 21. 0.17: telas e estabilidade

- **Área segura**: `SafeArea.insets(viewport)` converte `DisplayServer.get_display_safe_area`
  (relativa à janela) para px do jogo, com mínimo de 8 px em cima/embaixo no celular;
  `side_margins` limita o conteúdo a `MAX_CONTENT_W` (760) centralizado. `SafeMargin` é o
  MarginContainer de tela cheia usado pelas telas de menu (atualiza em `size_changed`).
  HUD e base calculam posições com as margens; `DepthCamera.target_zoom` aproxima em
  telas mais largas que o mundo.
- **Guard** (autoload `crash_guard.gd`, o primeiro): `user://session.json` com `running`,
  `step` e o modo; `running` fica true só com o app na frente. Sessão anterior "rodando"
  ao abrir = fechou sozinho → `crashed_last_time`, `compat` automático e aviso em
  `main._show_crash_notice`. `Guard.step/detail` registram a etapa (base, estação, mapa,
  gerando mundo, expedição · profundidade, extraindo, relatório).
- **Modo de compatibilidade** (`Guard.compat_level`, 0.17.2; sobe um nível a cada
  fechamento automático): nível 1 `WorldModel.threaded = false`, trilha por
  `MusicSynth.fill` por quadro (sem `WorkerThreadPool`), `FogLayer` com
  `shaders/fog_lite.gdshader`; nível 2 sem trilha e sem sons de criaturas; nível 3 sem
  criaturas (`CreatureManager.setup`), plantas bioluminescentes e `OreGlow`.
- **Diagnóstico**: `Diagnostics.report` (aparelho, sistema, GPU, memória, tela, área segura,
  etapa, fim do log anterior em `user://logs`), mostrado em `SettingsScreen.show_diagnostics`.
- **Shaders**: `terrain.gdshader` sem arrays locais com índice variável (`surf_key`,
  `surf_sum`, `host_offset`); `fog.gdshader` sem `break` dependente de uniform.

## 22. 0.18: tutorial, calor, tema do guardião e couro

- **Tutorial** (`Tutorial`, CanvasLayer 37): criado por `main._start_tutorial` quando
  `GameState.tutorial_done` é falso (perfil novo; salvamentos antigos contam como feito).
  `plant_resources` põe cobre e carvão abaixo do início. `_steps`: texto, `target` (rect
  na tela: controle por nome ou bloco do mundo pela câmera), `enter`, `done`, `block`
  (quatro ColorRect em volta do alvo bloqueiam o resto) e `ok`. `_go` troca de passo e
  roda `enter` no mesmo quadro. Se a expedição acabar antes, pula para o resumo/base.
  Pular: `SkipConfirm`. `Tutorial.enabled = false` nos testes de cena; `tests/tutorial_test`
  percorre todos os passos.
- **Calor** (`HeatRules`): `configure(região)`, `temp_at`, `over`, `penalty`, `hull_dps`,
  `safe_depth`; `RegionDef.temp_surface/temp_bottom` (`RegionRegistry.TEMPS`);
  `DrillStats.temp_limit` = `TEMP_LIMIT_BASE` + `TEMP_PER_COOLING` × Refrigeração.
- **Música**: `MusicSynth._sample` virtual; `BossSynth` (16 s) gerado junto com a trilha
  (thread ou por quadro no modo de compatibilidade); `Sfx.set_boss_mode` faz o crossfade.
  `Game._update_boss_music` liga a `BOSS_MUSIC_RANGE_M` da câmara final.
- **Couro**: recurso `leather`; `Economy.from_dict` converte `bio_sample`.

## 23. 0.19: desgaste, cuidado da nave, vitória e relíquias

- **Calor na tela** (`HeatShimmer`, CanvasLayer 4): `BackBufferCopy` + shader
  `heat_shimmer.gdshader` (lê a tela e ondula); força = `drill.heat_penalty /
  HEAT_PENALTY_MAX`. Desligado com `Guard.compat_level >= 2`.
- **Desgaste** (`WearRules`): `GameState.wear` = {dirt, rust, dents} 0..1, salvo no
  perfil. `Game._on_dug` → `add_dig`; queda de casco → `add_damage`. `penalty` reduz
  `Drill.wear_penalty` (velocidade); `hull_start_ratio` ajusta o casco inicial.
- **Cuidar da nave** (`ShipCare` + `ShipCarePanel`, Hangar): máscara por tipo (2 px por
  pixel da arte) com cobertura por `FastNoiseLite`; `scrub` apaga dentro do pincel e
  grava o nível em `GameState.wear`. `TouchScroll.no_scroll` impede a rolagem ao
  arrastar sobre a nave.
- **Formatos de broca**: `ShipLooks` slot `shape`; `ShipArt.drill_has` desenha cada um.
- **Vitória** (`VictoryScreen`, CanvasLayer 32, pausa): `chosen(next_region)`;
  `GameState.complete_region` marca `reset_on_end` e `end_expedition` chama `new_area`.
- **Relíquias** (`Relics`): um bloco por região (`BlockRegistry` 33..38, `special =
  &"relic"`), posição `Relics.place(semente, região)`; `WorldGenerator._forced_cell`
  abre uma câmara 3×3 em volta. `collect_drops` limita a 1 e marca
  `GameState.relic_prompt`; `main.show_relic_choice` (CanvasLayer 33) abre na base ou por
  `EventBus.relic_choice_requested`. `install_relic` grava em `Economy.relics` e
  `Relics.apply` soma o bônus em `_refresh_stats`. Relíquias ficam fora de `sell_all` e
  `cargo_value`.

### 0.19.1
- **Modo teste** (`AdminPanel`, aberto por `SettingsScreen.show_admin`): `run(id)` aplica
  cada atalho; `ShipVitals.invincible` (estático) zera consumo e dano; pular na
  expedição usa `main.admin_jump`, que chama `Game.start_run` com `start_x`.
- **Prévia**: `Garage._thumb` (miniatura por visual, cacheada) e `_float_preview`
  (`ShipPreview` no canto, visível quando a vitrine saiu da tela).
- **Guard.mark(chave)** (0.19.2): marco "primeira vez nesta sessão" no histórico
  (14 etapas); `mem_mb` (android.os.Debug.getNativeHeapAllocatedSize) gravado com o
  estado. Escolha manual com 2+ fechamentos seguidos volta ao automático.
- **Sprites de relíquias**: `tools/gen_relic_art.py` → `assets/environment/ores/relic_*`,
  linhas novas em `TerrainSkins.ORES`.

