# DEEPFORGE: Rumo ao Núcleo

Jogo mobile Android 2D vertical, offline e single-player, de escavação incremental.
Pilote uma perfuradora industrial através de quatro biomas até o Núcleo do planeta.

> **Status: Fase 1 concluída** — projeto, máquina, terreno, câmera, controles e mineração.
> Economia, garagem e upgrades chegam na Fase 2 (veja [Roadmap](#roadmap)).

## Requisitos

| Item | Versão |
|---|---|
| Godot | **4.6.x stable** (testado em 4.6.2 e 4.7.1) |
| Renderer | Compatibility (OpenGL ES 3) |
| Dependências externas | nenhuma (arte e geração são procedurais) |

## Como executar

1. Abra o Godot e importe `project.godot` (ou `godot --path .` na pasta do projeto).
2. Pressione **F5**. A janela de desktop abre em 450×800 (proporção de celular).

Linha de comando:

```bash
godot --path .                       # jogar
godot --path . -- --seed=42          # mundo fixo
```

### Controles

| Ação | Toque | Desktop |
|---|---|---|
| Perfurar para baixo | segurar o dedo alinhado à máquina | segurar clique / `Espaço` / `↓` / `S` |
| Mover | arrastar o dedo para o lado da máquina | arrastar o mouse / `←` `→` / `A` `D` |
| Perfurar lateralmente | segurar o dedo ao lado, contra uma parede | `←`/`→` + `Espaço` |
| Botões inferiores | `◀`, `PERFURAR`, `▶` (multitoque) | clique |

Degraus de um bloco são escalados automaticamente. A máquina se alinha sozinha à
coluna mais próxima quando não há direção, para cavar poços retos.

## Testes

```bash
GODOT=/caminho/para/godot tools/run_tests.sh
```

Executa, em modo headless:

| Etapa | Comando | O que verifica |
|---|---|---|
| Importação | `godot --headless --path . --import` | projeto abre, cache de classes, sem erros de parser |
| Unitários | `godot --headless --path . -s res://tests/run_tests.gd` | 25 testes: dados, determinismo da seed, biomas, cavernas, threads, modificações/JSON, dano, fórmulas, física da perfuradora (sem atravessar blocos a 60/30/20 FPS), paredes, pulo, perfuração lateral, efeito perceptível de dano, atlas |
| Integração | `godot --headless --path . --fixed-fps 60 res://tests/scene_test.tscn` | cena principal com toques simulados: perfurar, arrastar, multitoque nos botões, barra superior ignorada, descida real, eventos de bloco, câmera |
| Sessão | `godot --headless --path . --fixed-fps 60 -- --seed=42 --autotest=30` | bot joga 30 s, verifica a invariante de colisão a cada passo e imprime métricas |

### Argumentos de depuração (após `--`)

| Argumento | Efeito |
|---|---|
| `--seed=N` | seed fixa do mundo |
| `--autotest=S` | bot de teste por S segundos; encerra com código 0/1 |
| `--shots=T:arquivo.png,...` | capturas de tela (requer renderização real, não `--headless`) |
| `--start-row=N` | começa na linha N (inspecionar biomas profundos) |
| `--no-drive` | com `--autotest`, não pilota (só capturas) |

Captura de telas sem monitor (Linux):

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 720x1280 --fixed-fps 60 \
  -- --seed=42 --start-row=450 --autotest=4 --shots=3:/tmp/magma.png
```

## Estrutura

```
scenes/    main, game, gameplay/drill, ui/hud
scripts/   autoload · data · world · render · gameplay · camera · fx · game · ui · debug
tests/     runner headless, suítes unitárias, teste de cena
tools/     run_tests.sh
```

Detalhes em [ARCHITECTURE.md](ARCHITECTURE.md). Regras e números ajustáveis em
[GAME_DESIGN.md](GAME_DESIGN.md) e `scripts/data/balance.gd`.

## Desempenho (medido na Fase 1)

Medições em desktop (Linux, headless) — servem como referência relativa; o perfil em
Android real será feito na Fase 5.

| Métrica | Valor |
|---|---|
| Geração de um chunk (384 células) | ~0,9–1,5 ms, **em thread de trabalho** (chunks à frente) |
| Chunks carregados simultaneamente | 5–8 (renderers ativos: 4–6) |
| Nós por chunk / colisores | 1 / 0 |
| Atlas procedural (gerado 1× ao iniciar) | 30–45 ms |
| Partículas | pool fixo de 260, nó inativo quando vazio |
| Nós ativos na cena | ~25 |

Escolhas para Android básico: renderer Compatibility, nenhum colisor de física, um
`_draw` em lote por chunk (redesenhado apenas quando muda), um único atlas de textura,
filtro nearest com borda replicada no atlas, sem varreduras do mundo por quadro.

## Exportação Android

A configuração de exportação (`export_presets.cfg`), ícones adaptativos e instruções
completas de APK debug/release fazem parte da **Fase 5**. Pré-requisitos já conhecidos:
JDK 17+, Android SDK (platform-tools, build-tools, platform 34+), e os *export templates*
da mesma versão do Godot. Nenhum APK foi gerado nesta fase.

## Roadmap

| Fase | Conteúdo | Status |
|---|---|---|
| 1 | Projeto, máquina, terreno, câmera, controle, mineração | ✅ concluída |
| 2 | Recursos, inventário, garagem, economia, upgrades | pendente |
| 3 | Biomas (efeitos), módulos, energia/impulso, calor, sinergias | pendente |
| 4 | Prestígio, persistência, testes, balanceamento | pendente |
| 5 | Arte, efeitos, áudio, otimização, exportação Android | pendente |

## Limitações conhecidas (Fase 1)

- Créditos, Cristais e energia aparecem no HUD como placeholders; drops já são emitidos
  (`EventBus.block_destroyed`) mas ainda não há inventário.
- Sem salvamento: cada execução começa uma nova corrida com seed aleatória.
- Sem áudio (infraestrutura de buses na Fase 5).
- Não é possível voltar à superfície por um caminho fechado (a garagem da Fase 2 terá retorno).
- Desempenho ainda não perfilado em aparelho Android real.

## Licença dos assets

Toda a arte é gerada por código neste repositório (`scripts/render/tile_art.gd`,
`drill_visual.gd`, `background.gd`). Nenhum asset de terceiros é usado.
