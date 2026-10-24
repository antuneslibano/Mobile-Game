# DEEPFORGE: Rumo ao Núcleo

Jogo mobile Android 2D vertical, offline e single-player, de escavação incremental.
Pilote uma perfuradora industrial através de quatro biomas até o Núcleo do planeta.

> **Status: Fase 3 concluída (revisada)** — escavação livre em qualquer ângulo (menos para cima)
> com terreno orgânico em micro-células, energia conquistada e Sobrecarga, calor, módulos e
> sinergia. Prestígio e salvamento na Fase 4.

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
| Cavar em qualquer direção — baixo, diagonais, lados | joystick (arraste o dedo em qualquer ponto da tela) | setas/WASD (combinadas = diagonal), `Espaço` = baixo |
| Para cima | nada — **a broca não sobe** | – |
| Sobrecarga (só com a barra de energia cheia) | botão no canto inferior direito | `Shift` |
| Garagem (vender, upgrades, módulos) | botão **GARAGEM** no topo | clique; `Esc` fecha |
| Mapa mundial (escolher região) | botão de mapa ao lado da garagem; deslize para os lados | arraste/setas na tela; `Esc` fecha |

**Expedições (0.9):** o mapa é a base. Escolha a região, toque em EXPLORAR e cave até onde o
combustível deixar; **EXTRAIR** traz toda a carga, e ficar sem combustível ou casco chama o
resgate (metade da carga da expedição). A garagem abre só na base. Toda expedição parte da
superfície, mas seus túneis ficam salvos (cair por eles não gasta combustível). Cada região
tem, no fundo, uma câmara final com um **guardião**: vença-o para concluir a região.

Ao abrir, o jogo mostra o **mapa mundial**: deslize para escolher entre seis regiões
(uma por página) e toque em **EXPLORAR**. Regiões bloqueadas mostram o requisito (profundidade
na região anterior). O progresso (economia, upgrades, módulos, carga, profundidade máxima por
região) é **salvo automaticamente** em `user://deepforge_profile.json`.

Você desenha o próprio túnel: a máquina escava na direção do joystick e avança conforme o
material cede. A energia enche cavando — minérios e cristais enchem muito mais.

## Testes

```bash
GODOT=/caminho/para/godot tools/run_tests.sh
```

Executa, em modo headless:

| Etapa | Comando | O que verifica |
|---|---|---|
| Importação | `godot --headless --path . --import` | projeto abre, cache de classes, sem erros de parser |
| Unitários | `godot --headless --path . -s res://tests/run_tests.gd` | ambiente (assets e tamanhos, texturas sem emenda, minérios distintos por silhueta/cor, terreno sem ícone de minério, 16 texturas em uso no Vale, tabelas de decoração, vegetação só em cavernas naturais e removida ao escavar), regiões (registro, camadas contíguas, desbloqueio, progresso, terreno × depósito, gerador por região, ícones), salvamento (ida e volta, arquivo corrompido, `.bak`, validação da economia), escavação livre (diagonal desenha o túnel, horizontal nivelado, nada escavado acima, para cima não move, sem atravessar a 20 FPS), joystick em qualquer ângulo, energia que não regenera e Sobrecarga só com barra cheia, carga por valor do material, calor, módulos, sinergia, slots; dados, determinismo da seed, biomas, cavernas, threads, modificações/JSON, dano, fórmulas, física da perfuradora (sem atravessar blocos a 60/30/20 FPS), paredes, pulo, perfuração lateral, atlas, economia (coleta, frações, venda sem duplicação), progressão (custos, compra atômica, limites, bloqueios, antes/depois) e simulação de balanceamento de 10 min |
| Integração | `godot --headless --path . --fixed-fps 60 res://tests/scene_test.tscn` | 58 verificações com toques simulados: mapa (abre ao iniciar, deslizar troca/encaixa a página, arrasto curto não troca, setas, região bloqueada desativa EXPLORAR, desbloqueio, mergulho em outra região com as camadas certas, mineração lá, perfil salvo/restaurado), joystick (zona morta, baixo, lados, analógico, para cima), multitoque joystick + impulso, setas removidas, barra superior ignorada, descida real, eventos de bloco, câmera; garagem: vender, comprar, efeito na máquina, módulos (equipar automático, slots, remover/equipar) |
| Sessão | `godot --headless --path . --fixed-fps 60 -- --seed=42 --autotest=30` | bot joga 30 s, verifica a invariante de colisão a cada passo e imprime métricas |

### Argumentos de depuração (após `--`)

| Argumento | Efeito |
|---|---|
| `--seed=N` | seed fixa do mundo |
| `--autotest=S` | bot de teste por S segundos; encerra com código 0/1 |
| `--shots=T:arquivo.png,...` | capturas de tela (requer renderização real, não `--headless`) |
| `--start-row=N` | começa na linha N (inspecionar biomas profundos) |
| `--no-drive` | com `--autotest`, não pilota (só capturas) |
| `--no-shop` | com `--autotest`, não vende nem compra |
| `--open-garage-at=T` | com `--autotest`, abre a garagem em T segundos |
| `--garage-tab=modules` | abre a garagem na aba Módulos |
| `--grant-credits=N`, `--grant-crystals=N` | moedas iniciais (só builds de depuração) |
| `--region=ID` | começa na região (`vale`, `dunas`, `cordilheira`, `pantano`, `abismo`, `vazio`) |
| `--unlock-all` | libera todas as regiões (só builds de depuração; desliga o salvamento nessa sessão) |
| `--no-map` | não abre o mapa ao iniciar |
| `--map-at=T`, `--map-page=N` | com `--autotest`, abre o mapa em T segundos na página N |
| `--fuel=F` | combustível inicial (fração do tanque; só builds de depuração) |
| `--extract-at=T` | com `--autotest`, chama a extração em T segundos |
| `--guardian-hp=F` | vida inicial do guardião da câmara final (fração; só builds de depuração) |
| `--sonar-at=T` | com `--autotest`, usa o sonar em T segundos |
| `--tutorial` | com `--autotest`, mostra o tutorial por cima da expedição |
| `--wear=F` | nave desgastada (sujeira, ferrugem e amassados em F; só depuração) |
| `--upgrade=id:n,...` | níveis de melhorias ao iniciar (ex.: `cooling:5`; só depuração) |
| `--admin` | com `--settings-at`, abre o Modo teste |
| `--garage-scroll=N` | com `--base-at`/`--station`, rola a estação (-1 = visual da nave) |
| `--look=slot:id,...` | visual sem requisito (ex.: `shape:twin`; só depuração) |
| `--sell=KEY` | com `--station=market`, abre a venda em quantidade |
| `--fall-test` | com `--autotest`, abre um poço de 60 blocos abaixo da nave |
| `SUITE=nome` (env) | `tests/run_tests.gd` roda só a suíte com esse nome |
| `tools/bake_audio.tscn` | gera o banco de sons (rodar ao mudar um som) |
| `--near-relic` | com `--autotest`, começa logo acima da relíquia da região |
| `--relic-choice-at=T` | com `--autotest`, abre a escolha da relíquia na base em T segundos |
| `--settings-at=T` | com `--autotest`, abre as Configurações em T segundos (`--diag` abre o Diagnóstico) |
| `--safe-area=T,B,L,R` | simula notch/cantos/barra de gestos (px do jogo; só depuração) |
| `--compat[=N]` | força o modo de compatibilidade, nível N de 1 a 3 (só depuração) |
| `--real-bot=S` | fluxo real (abertura, base, mapa, EXPLORAR, salvamento e Guard) e piloto automático por S segundos (só depuração) |
| `--guard` | com `--autotest`, liga a detecção de fechamento (normalmente desligada nos testes) |
| `--splash` | com `--autotest`, mostra a tela de abertura |
| `--ask-new-area` | abre o mapa com o aviso de "nova área" (só builds de depuração) |
| `--creatures` | caverna com uma criatura de cada espécie à frente da nave (só builds de depuração) |
| `--grant-ores=N` | N de cada minério comum no armazém (só builds de depuração) |
| `--base-at=T`, `--station=KIND` | com `--autotest`, abre a base em T s e a estação (`map`, `bench`, `hangar`, `market`, `lab`) |

Captura de telas sem monitor (Linux):

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 720x1280 --fixed-fps 60 \
  -- --seed=42 --start-row=450 --autotest=4 --shots=3:/tmp/magma.png
```

### Assets do ambiente

Texturas, depósitos, vegetação e decorações ficam em `assets/environment/` (PNGs reais).
Para regenerá-los a partir do código (`scripts/render/env_art.gd`):

```bash
godot --headless --path . -s res://tools/gen_env_assets.gd -- --preview=/tmp/folha.png
godot --headless --path . --import
```

## Estrutura

```
scenes/    main, game, gameplay/drill, ui/hud
scripts/   autoload · data · world · render · gameplay · camera · fx · game · ui · debug
tests/     runner headless, suítes unitárias, teste de cena
tools/     run_tests.sh, gen_env_assets.gd
assets/    fonts, environment (terrain, ores, vegetation, decorations)
```

Detalhes em [ARCHITECTURE.md](ARCHITECTURE.md). Regras e números ajustáveis em
[GAME_DESIGN.md](GAME_DESIGN.md) e `scripts/data/balance.gd`.

## Desempenho (medido na Fase 1)

Medições em desktop (Linux, headless) — servem como referência relativa; o perfil em
Android real será feito na Fase 5.

| Métrica | Valor |
|---|---|
| Geração de um chunk (6.144 micro-células) | ~10 ms, **em thread de trabalho** (chunks à frente) |
| Chunks carregados simultaneamente | 5–8 (renderers ativos: 4–6) |
| Nós por chunk / colisores | 1 / 0 |
| Texturas do terreno (paleta + ruído 256², 1× ao iniciar) | ~60 ms |
| Terreno na GPU | 1 quad + 1 chamada de desenho por chunk; ~10 leituras de textura por pixel |
| Partículas | pool fixo de 260, nó inativo quando vazio |
| Nós ativos na cena | ~25 |

Escolhas para Android básico: renderer Compatibility, nenhum colisor de física, terreno
desenhado na GPU com 1 quad por chunk (alterar uma célula atualiza 1 texel), ruído em
textura (não calculado por pixel), sem varreduras do mundo por quadro.

## Exportação Android

O preset `Android` já está em `export_presets.cfg` (APK sem Gradle, arm64-v8a + armeabi-v7a,
`com.deepforge.rumoaonucleo`, retrato, imersivo). Senhas **não** ficam no repositório.

Pré-requisitos (uma vez):
1. JDK 17+ e Android SDK (`platform-tools` e `build-tools` com `apksigner`).
2. Templates de exportação da mesma versão do Godot (Editor → Gerenciar Templates de Exportação).
3. Em Editor → Configurações do Editor → Exportar → Android: caminho do SDK, do JDK e o
   *debug keystore* (o Godot cria um automaticamente, ou use
   `keytool -genkeypair -keystore debug.keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -validity 10000 -dname "CN=Android Debug,O=Android,C=US"`).

APK debug (contador de FPS visível):

```bash
godot --headless --path . --export-debug "Android" build/deepforge-debug.apk
```

APK release (crie sua chave uma vez e guarde-a: ela é necessária para atualizar o app instalado):

```bash
keytool -genkeypair -keystore deepforge-release.keystore -alias deepforge -keyalg RSA -keysize 2048 -validity 10000
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$PWD/deepforge-release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=deepforge
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=sua_senha
godot --headless --path . --export-release "Android" build/deepforge.apk
```

Instalar: `adb install -r build/deepforge.apk`, ou copie o APK para o celular e abra-o
(permita "instalar apps desconhecidos" para o app usado para abrir o arquivo).

## Roadmap

| Fase | Conteúdo | Status |
|---|---|---|
| 1 | Projeto, máquina, terreno, câmera, controle, mineração | ✅ concluída |
| 2 | Recursos, inventário, garagem, economia, upgrades | ✅ concluída |
| 3 | Escavação livre, terreno orgânico, joystick, módulos, energia/Sobrecarga, calor, sinergias | ✅ concluída |
| — | Mapa mundial com 6 regiões, terrenos × depósitos, salvamento do perfil | ✅ |
| — | Minérios raros/valiosos com brilho, nave 1,5× | ✅ |
| 0.9 | Expedições: combustível, casco, extração/resgate, fundo e objetivos por região | ✅ |
| 0.9.1 | Mapas 2,4× mais fundos, guardião na câmara final, câmera de abertura, sem elevadores | ✅ |
| 0.9.2 | Combate contra o guardião: arena, ataques de baixo, câmera de combate | ✅ |
| 0.10 | Base com estações tocáveis, construção com materiais, mercado de excedente, laboratório | ✅ |
| 0.11 | Criaturas no Vale, visual da nave escolhido no Hangar, baús novos | ✅ |
| 0.12 | Broca por nível, subida em rampa, cavernas em patamares, baús raros com plantas, nova área, sons | ✅ |
| 0.13 | Névoa com luz da nave, sonar, broca forçada esquenta, onda de choque em anéis, correções de interface | ✅ |
| 0.14 | Catálogo com fichas no Laboratório, trilha sonora e sons das criaturas, tela de abertura, transições, baú coletável, receitas graduais, desempenho | ✅ |
| 0.15 | Porta de metal nas trocas de tela, plantas bioluminescentes no Vale, volume da trilha e da máquina | ✅ |
| 0.16 | Configurações de volume (música, efeitos, máquina), minério sempre rende item | ✅ |
| 0.17 | Área segura em todas as telas (notch, cantos, barra de gestos, tablets), modo de compatibilidade automático, diagnóstico | ✅ |
| 0.18 | Tutorial jogável, calor por profundidade com limite térmico, tema do guardião, couro vendável, Sobrecarga 2× combustível | ✅ |
| 0.19 | Calor tremendo a tela, desgaste e cuidado da nave no Hangar, formatos de broca, vitória "ele retornará" com região refeita, relíquias por região | ✅ |
| 0.21 | Novo combate do guardião (arena, sementes, espinhos, batimento), criaturas sólidas que rondam e batem, sons prontos (compatibilidade sem cortes), som de oficina, slider melhor | ✅ |
| 0.20 | Venda em quantidade, brocas com função, sujeira na run, "!" no Laboratório, câmera de queda, telas responsivas | ✅ |
| 0.10–0.11 | Base com construção, criaturas — ver [ROADMAP_EXPEDICOES.md](ROADMAP_EXPEDICOES.md) | planejado |
| 5 | Arte, efeitos, áudio, otimização, exportação Android | pendente |

## Limitações conhecidas

- O salvamento guarda o perfil, não o túnel: ao reabrir, a exploração recomeça na superfície
  da região (com tudo o que foi comprado e o progresso de cada região).
- Riscos ambientais do mapa são informativos (descrevem as camadas), exceto o Calor.
- Fontes de título não têm acentos maiúsculos (ex.: "DUNAS DE AMBAR" na placa).
- O shader do terreno ainda não foi medido em aparelho Android real; se houver queda de
  FPS em aparelhos básicos, a Fase 5 adiciona um preset de qualidade.
- Contornos seguem micro-células de 12 px suavizadas: em close aparecem como pixel art
  recortada (intencional), não como curvas vetoriais.
- Sem áudio (Fase 5) e com o ícone padrão do Godot.

## Licença dos assets

- Toda a arte (nave, terreno, interface, ícones) é gerada por código neste repositório
  (`scripts/gameplay/ship_art.gd`, `scripts/ui/pixel_art.gd`, `shaders/terrain.gdshader`,
  `scripts/render/`). Nenhuma imagem de terceiros é usada.
- Fontes (SIL Open Font License 1.1, incluídas com as licenças em `assets/fonts/`):
  **Press Start 2P** (títulos, números e botões) e **Jersey 10** (textos).
