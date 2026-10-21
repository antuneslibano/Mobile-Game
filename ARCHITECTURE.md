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
scenes/
  main.tscn                raiz: Game + HUD
  game/game.tscn           mundo: fundo, terreno, overlay, perfuradora, FX, câmera, input
  gameplay/drill.tscn      perfuradora (lógica + visual)
  ui/hud.tscn              HUD superior e controles inferiores
scripts/
  autoload/                singletons globais (apenas estado e sinais)
    event_bus.gd           EventBus – barramento de sinais de jogo
    game_state.gd          GameState – estado da corrida (seed, profundidade, estatísticas)
  data/                    definições estáticas e balanceamento (sem lógica de cena)
    balance.gd             Balance – constantes ajustáveis
    block_def.gd           BlockDef (Resource)
    block_registry.gd      BlockRegistry – tabela de blocos
    biome_def.gd           BiomeDef (Resource)
    biome_registry.gd      BiomeRegistry – faixas, paletas, regras
  world/                   modelo e renderização do terreno
    world_generator.gd     WorldGenerator – (seed,x,y) → id, puro
    chunk_data.gd          ChunkData – ids de um chunk
    world_model.gd         WorldModel – cache de chunks, modificações, dano
    terrain_view.gd        TerrainView – carrega/descarrega e recicla ChunkRenderers
    chunk_renderer.gd      ChunkRenderer – desenha 1 chunk em lote via _draw
    mining_overlay.gd      MiningOverlay – rachaduras e flash de impacto
  render/
    tile_art.gd            TileArt – gera o atlas pixel art procedural (Image → ImageTexture)
    background.gd          Background – céu, superfície e base
  gameplay/
    drill_stats.gd         DrillStats – atributos efetivos (base + upgrades futuros)
    drill_intent.gd        DrillIntent – intenção de controle (mover, perfurar, impulso)
    mining_rules.gd        MiningRules – fórmula de dano centralizada
    drill.gd               Drill – física em grade, colisão, alvo de perfuração, golpes
    drill_visual.gd        DrillVisual – desenho e animação da máquina
    input_controller.gd    InputController – toque/mouse/teclado → DrillIntent
  camera/depth_camera.gd   DepthCamera – seguimento suave, limites, tremor
  fx/debris_fx.gd          DebrisFx – partículas em pool (struct-of-arrays, 1 nó)
  game/game.gd             Game – composição e ligação dos sistemas do mundo
  ui/hud.gd                Hud – leitura de estado, áreas de toque
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
│   ├── DepthCamera (Camera2D)
│   └── InputController (Node)
└── Hud (CanvasLayer, layer=10, hud.gd)        scenes/ui/hud.tscn
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
```

## 5. Sinais (EventBus)

| Sinal | Parâmetros | Emissor | Ouvintes (fase) |
|---|---|---|---|
| `block_hit` | `cell: Vector2i, block_id: int, damage: float, crit: bool` | Game | Áudio (5) |
| `block_destroyed` | `cell: Vector2i, block_id: int, drops: Dictionary` | Game | Inventário (2), Áudio (5) |
| `depth_changed` | `depth_m: int, max_depth_m: int` | GameState | Hud, Prestígio (4) |
| `biome_changed` | `biome_id: int` | GameState | Hud, Áudio (5), Calor (3) |
| `run_started` | `seed: int` | GameState | Hud |

Sinais locais: `WorldModel.cell_changed(cell)`, `WorldModel.chunk_generated(index)`,
`Drill.block_hit(...)`, `Drill.block_destroyed(...)`, `Drill.blocked_by_unbreakable(cell)`.

## 6. Terreno

- **Coordenadas**: célula `(x, y)`; `y = 0` é a primeira linha de solo; `y < 0` é céu.
  Pixel = célula × `Balance.BLOCK_PX`.
- **Chunk** = faixa de `WORLD_WIDTH × CHUNK_HEIGHT` células; índice = `floor(y / CHUNK_HEIGHT)`.
- **Carregamento**: `TerrainView` calcula, a cada quadro, o intervalo de chunks visíveis
  pela câmera (+margem). Visíveis são garantidos de forma síncrona; os de antecipação
  entram numa fila com orçamento de `GEN_CHUNKS_PER_FRAME`. Chunks fora do intervalo +
  histerese são descarregados do cache e seus renderers voltam ao pool.
- **Modificações**: `WorldModel._mods: Dictionary[int → Dictionary[int → int]]`
  (chunk → índice local → novo id). Sobrevivem ao descarregamento; são reaplicadas na
  regeneração e serão serializadas pelo `SaveService` (Fase 4).
- **Dano parcial**: `WorldModel._damage: Dictionary[Vector2i → float]`, limitado a
  `MAX_DAMAGED_CELLS` (os mais antigos expiram). Não é salvo (intencional).
- **Renderização**: `ChunkRenderer._draw()` emite um `draw_texture_rect_region` por célula
  a partir de **um único atlas** → o renderizador 2D agrupa tudo em poucos lotes. Só
  redesenha quando o chunk muda. Bordas iluminadas/sombras são calculadas no desenho
  consultando vizinhos (`WorldModel.peek_block`, que não força geração).

## 7. Perfuradora

- Colisão AABB contra a grade, separada por eixo, com subpassos ≤ 0,4 bloco: impossível
  atravessar blocos mesmo em queda máxima ou a 30 FPS. Teste dedicado verifica a invariante.
- `DrillIntent.move ∈ [−1, 1]`, `drill: bool`, `boost: bool`.
- Alvo: lateral (se movendo contra parede alta e perfurando) ou abaixo (sem intenção
  horizontal, apoiada e alinhada). Degrau de 1 bloco ⇒ pulo automático.
- Golpes em ritmo fixo (`hits_per_second`) com acumulador; RNG próprio semeável.
- `DrillStats` encapsula atributos; na Fase 2, `ProgressionService.build_stats()` gera
  a instância a partir de upgrades/módulos, sem alterar `Drill`.

## 8. Entrada

`InputController._unhandled_input` processa `InputEventScreenTouch/Drag` (o mouse vira
toque via `emulate_touch_from_mouse`). Cada índice de toque é rastreado: toques sobre a
barra inferior acionam `◀ / PERFURAR / ▶` (multitoque real); toques na área de escavação
viram direção relativa à posição da máquina na tela; toques sobre a barra superior são
ignorados (`Hud.is_point_blocking`). Teclado (`←→AD`, `↓ S Espaço`) é somado para desktop.

## 9. Preparação para as próximas fases

| Fase | Encaixe |
|---|---|
| 2 – Economia | `Inventory` e `ProgressionService` como autoloads; `UpgradeDef` (Resource) em `data/upgrades/`; Garagem em `scenes/ui/garage.tscn`; ouvintes de `EventBus.block_destroyed`. |
| 3 – Módulos/energia/calor | `ModuleDef` + `ModuleSystem` (nós filhos de `Drill` que reagem a `block_hit`); `SynergyRules` declarativas; `HeatRules` em `gameplay/`; `DrillVisual.set_modules()`. |
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
