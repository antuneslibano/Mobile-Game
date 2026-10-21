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
- **Atlas**: `TerrainTextures` monta três atlas (texturas 64×64, depósitos 12×12 × 3
  variações, decorações 24×24) e duas tabelas da região ativa: `skin_tex` (bloco × camada →
  até 4 texturas) e `decor_tex` (camada → decoração embutida por faixa de sorteio +
  densidade). `GameState.apply_region` chama `TerrainTextures.apply_region`.
- **Shader** (mesma geometria, mesmas bordas): `surface_col` amostra a textura do material
  por pixel de arte (`texelFetch`, sem filtro); sem pele usa o procedural antigo. Depósitos
  são um sprite por sítio de 14 pixels de arte, decidido pela célula do centro. Decorações
  embutidas: um sítio de 28 pixels de arte, só sobre terreno. Fósseis: sprite por bloco.
- **Cavernas**: `CaveDecor` (filho do `ChunkRenderer`) planeja, ao montar o chunk, plantas no
  chão e raízes no teto de cavernas naturais (`WorldModel.is_modified` exclui túneis) e as
  remove quando a célula de apoio é escavada. Sem colisão; desenho em um único CanvasItem.
