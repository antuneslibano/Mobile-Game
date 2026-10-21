# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Versionamento: `0.<fase>.<correção>` até o 1.0.

## [0.5.0] — Nova nave e interface no estilo da referência

### Adicionado
- **Nave nova** em pixel art procedural (casco branco, placas amarelas, cabine azul, bocais
  amarelos, pods com luzes, broca cônica com espiral animada), girando para a direção escavada.
- **Interface refeita** no estilo da referência: painéis de aço com rebites, placa laranja de
  título, moedas em caixas (moeda dourada / cristal), botão vermelho de fechar, vitrine da
  nave com barras de atributos, cartões com moldura laranja, "Nv. X", barra segmentada,
  preço dourado e seta verde; HUD, joystick e botão de Sobrecarga no mesmo estilo.
- Fontes pixel OFL: Press Start 2P e Jersey 10.
- Ícones pixel art para todos os upgrades.

### Alterado
- Upgrades renomeados: "Dano da broca" → **Broca**, "Velocidade" → **Turbina**.

## [0.4.0] — Escavação livre e energia conquistada

### Adicionado
- **Movimento livre**: a máquina cava em qualquer ângulo da metade de baixo (lados, diagonais,
  baixo) e desenha o próprio túnel; no vazio cai pela gravidade. Nunca sobe.
- **Terreno em micro-células de 12 px** (16 por bloco), gerado do layout de blocos com
  deformação fractal; escavação por círculo com desgaste por célula.
- **Energia conquistada**: não regenera; enche pelo valor do material cavado (minérios e
  Cristais valem muito mais). **Sobrecarga** só com a barra cheia: 6 s, ×2,2 golpes/s,
  túnel 30% mais largo, mais velocidade; consome a barra inteira.
- Aviso "SOBRECARGA PRONTA"; botão mostra a porcentagem de carga.
- Textos de coleta somam ganhos do mesmo recurso.

### Alterado
- Broca lateral agora alarga o túnel; drone e pulso escavam áreas circulares.
- Upgrades "Capacidade de energia" → **Bateria** (+10% de carga) e "Impulso" → **Sobrecarga**.
- Removidos o pulo automático e o auto-alinhamento à coluna.
- A máquina gira apontando a broca na direção escavada.

## [0.3.0] — Fase 3: terreno orgânico, joystick, energia, calor e módulos

### Adicionado
- **Terreno orgânico**: shader `shaders/terrain.gdshader` desenha a grade como campo
  contínuo — contornos arredondados e irregulares, transições naturais entre materiais,
  pepitas de minério, lascas de cristal, veios de magma, luz/sombra e oclusão, rachaduras.
  1 quad por chunk; dados das células em textura (atualização por texel).
- **Joystick flutuante** (nasce onde o dedo toca); para cima não faz nada.
- Energia (100, +8/s) e **impulso** (−40 energia, ×1,8 golpes/s por 3 s) com botão dedicado,
  aura e chama; a mineração normal nunca depende de energia.
- **Calor** a partir de 300 m (até −30% de golpes/s), indicador no HUD e tinta na tela;
  **Refrigeração** reduz.
- **Módulos** com 2 slots: Broca lateral, Drone minerador, Pulso sísmico; equipar/remover na
  aba Módulos; aparência da máquina muda com os módulos.
- **Sinergia Ressonância Crítica** (Crítico × Pulso), declarativa em `SynergyRules`.
- Todos os 10 upgrades liberados; prévias legíveis para módulos e impulso.
- Aviso com o nome do bioma ao entrar.
- 11 testes da Fase 3; teste de integração reescrito para o joystick (37 verificações).

### Removido
- Botões inferiores `◀`, `PERFURAR`, `▶` (substituídos pelo joystick).
- Atlas de tiles quadrados (`TileArt`).

### Alterado
- Cristais: blocos de cristal/ametista/baú rendem 2; Drone custa 6 e Pulso 8 Cristais.

## [0.2.0] — Fase 2: recursos, inventário, garagem, economia e upgrades

### Adicionado
- 12 recursos com preço (`ResourceRegistry`); Cristais vão direto para a carteira.
- `Economy` (carteira, carga sem limite, níveis) e `Progression` (custo exponencial, compra
  atômica, atributos, textos antes → depois), ambos puros e testados.
- 10 upgrades em `data/upgrades/*.tres`; Dano, Velocidade, Crítico e Coleta funcionais;
  os demais aparecem como "Em breve" (Fase 3).
- Garagem acessível de qualquer profundidade: carga detalhada, VENDER TUDO, abas
  Upgrades/Módulos, cartões com antes → depois, pausa o jogo, fecha com "voltar" do Android.
- Botão GARAGEM no HUD com o valor da carga; Créditos e Cristais reais no HUD.
- Textos flutuantes de coleta ("+1 Cobre").
- Testes: economia (5), progressão (5) incluindo simulação de balanceamento de 10 min;
  teste de integração ampliado para venda e compra pela garagem (29 verificações).
- Bot de teste vende e compra (`--no-shop` para desligar), `--open-garage-at=T`.

### Alterado (balanceamento)
- Blocos mais resistentes por bioma (ex.: basalto 70 → 220 HP, dureza 8 → 14) e golpes
  base 6 → 5/s; rochas das Cavernas rendem mais pedra. Ver GAME_DESIGN.md §5.4 e §7.2.1.
- "Voltar" do Android não fecha mais o jogo com a garagem aberta.

## [0.1.2] — APK menor

### Alterado
- Exportação apenas arm64-v8a (APK de 51 MB → 26 MB); praticamente todos os celulares atuais são 64 bits.
- APK publicado em `releases/` para download direto pelo GitHub.

## [0.1.1] — Build Android

### Adicionado
- Preset de exportação Android (`export_presets.cfg`), sem Gradle, arm64-v8a + armeabi-v7a.
- Compressão de textura ETC2/ASTC habilitada (exigida pelo Android).
- Instruções de APK debug/release no README.

## [0.1.0] — Fase 1: base jogável

### Adicionado
- Projeto Godot 4.6 (compatível com 4.7), renderer Compatibility, retrato 720×1280,
  escala `canvas_items` + `expand`, toque emulado por mouse para testes no desktop.
- `GAME_DESIGN.md` (parâmetros ajustáveis) e `ARCHITECTURE.md` (cenas, sinais, fluxo de dados).
- Mundo determinístico por seed: `WorldGenerator` com `FastNoiseLite` + hash inteiro próprio;
  4 biomas (Crosta, Cavernas Cristalinas, Zona Magmática, Abismo Ancestral) com borda
  serrilhada, cavernas, veios de minério e blocos especiais (baú, artefato).
- 18 tipos de bloco com vida, dureza, drops e evento especial (`BlockRegistry`).
- `WorldModel`: chunks de 24×16 em `PackedByteArray`, modificações persistentes
  (exportáveis em JSON), dano parcial limitado, geração antecipada em `WorkerThreadPool`.
- Renderização por chunk em lote (1 nó por chunk, 1 atlas), pool de renderers,
  bordas iluminadas e sombras projetadas; atlas de pixel art 100% procedural (`TileArt`).
- Perfuradora com física em grade (sem colisores), subpassos anti-atravessamento,
  auto-alinhamento à coluna, pulo automático em degraus, perfuração para baixo e lateral,
  críticos, feedback de rocha-mãe.
- Controles: segurar para perfurar, arrastar para direcionar, botões grandes ◀ / PERFURAR / ▶
  com multitoque, teclado no desktop.
- Câmera com seguimento suave, antecipação para baixo, limites e tremor.
- Partículas em pool (struct-of-arrays, 1 nó, limite configurável), rachaduras em 4 estágios
  e flash de impacto.
- HUD: profundidade, máxima, bioma, Créditos/Cristais (placeholders da Fase 2), energia
  (placeholder da Fase 3), dica inicial, FPS em builds de depuração, margens seguras.
- Testes: 25 unitários headless, teste de integração com toques simulados (19 verificações),
  sessão automática (`--autotest`) com captura de tela, `tools/run_tests.sh`.
