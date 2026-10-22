# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Versionamento: `0.<fase>.<correção>` até o 1.0.

## [0.9.0] — Expedições

### Adicionado
- **Expedições**: cada descida tem começo, meio e fim. A base é o mapa mundial (GARAGEM e
  EXPLORAR); durante a expedição não se compra nada.
- **Combustível** (tanque 120, gasta movendo/cavando, ×1,5 na Sobrecarga). **Carvão abastece**
  o tanque (não vai mais para a carga).
- **Casco**: o calor acima do nível seguro causa dano (refrigeração reduz).
- **Extrair** (HUD): a cápsula desce o cabo e leva a nave com **toda a carga**.
  **Resgate de emergência** (sem combustível ou casco): volta com **metade da carga desta
  expedição**. Fechar o app no meio conta como resgate.
- **Relatório da expedição**: carga trazida/perdida, valor, conquistas.
- **Elevadores**: ao alcançar uma camada nova, um elevador fica no topo dela; a próxima
  expedição pode começar ali (desce gastando combustível).
- **Fundo de cada região** (rocha-mãe) com **câmara final** e relíquia; concluí-la libera a
  próxima região.
- **Objetivos por região**: principal (câmara final), 3 de pesquisa (coletar recursos) e
  3 estrelas (câmara final numa só expedição, carga grande, 5 extrações sem resgate).
- **Mundo persistente**: mapa fixo por região e escavação salva (minério tirado não volta).
- **HUD**: barras de combustível e casco, termômetro, botão EXTRAIR; **alertas visuais**
  com vinheta pulsante nas bordas e aviso piscando (combustível baixo/crítico,
  superaquecimento com dano no casco, calor).
- Upgrades novos: **Tanque**, **Eficiência**, **Blindagem**.
- Testes: `test_expedition.gd`, regras de região/câmara, simulação com expedições,
  extração/resgate/alertas no teste de cena.

### Alterado
- Próxima região liberada pela câmara final da anterior (salvamentos antigos mantêm o que
  já estava liberado).
- Garagem só na base; carrossel mostra a conclusão dos objetivos.

## [0.8.1] — Nave maior

### Alterado
- **Nave 1,5× maior** (1 pixel do sprite = 3 px, o mesmo pixel de arte do terreno); corpo,
  broca e broca lateral crescem junto, então o túnel continua do tamanho da nave.
- Custo em Créditos dos upgrades ×3: a nave maior colhe mais de cada veio (simulação de
  10 min buscando minérios: ~283 m, ~32 upgrades, ~10 400 créditos; cavando reto: ~60).

### Documentação
- `ROADMAP_EXPEDICOES.md`: plano das versões 0.9 (expedições), 0.10 (base e construção) e
  0.11 (criaturas) com as decisões tomadas.

## [0.8.0] — Minérios raros, valiosos e brilhantes

### Alterado
- **Economia repensada**: minérios concentrados em poucos veios (~3× menos por área) e
  preços ~3× maiores; terra, pedra e rochas não rendem mais nada. Na simulação de 10 min,
  quem vai atrás dos minérios ganha ~6 800 créditos e compra ~41 upgrades; quem só cava
  reto ganha ~30.
- Energia da Sobrecarga recalibrada para os novos valores (vem dos minérios).
- Depósitos voltam a ser desenhados inteiros, em destaque sobre o terreno (com contorno),
  decididos pelo bloco.

### Adicionado
- **Brilho dos minérios valiosos** (`OreGlow`): cintilações em estrela (ouro, cristal) e,
  nos mais valiosos (gemas, urânio, titânio, diamante, cristal raro), aura pulsante e
  partículas subindo — visíveis de longe.
- Simulação com duas estratégias (`tests/balance_sim.gd`) e teste de que buscar minérios
  rende muito mais que cavar reto.

## [0.7.2] — Correções: minérios, transições e menus

### Corrigido
- **Minérios piscando**: a câmera agora anda em passos inteiros em pixels do jogo e do
  aparelho (com escala fracionária, como 720 → 1080, cada pixel de arte mudava de largura
  a cada quadro, inclusive durante o tremor).
- **Minérios "colados"**: cada bloco de minério mostra um aglomerado recortado pela forma do
  veio, com contorno virando sombra na rocha, halo mais suave e fragmentos no veio.
- **Transições de terreno**: mistura por altura entre materiais, camadas e variações, com
  fronteiras deformadas por ruído fractal — os torrões de um material avançam entre os do
  outro, sem degraus nem emendas retas.

### Alterado
- Garagem e mapa maiores (textos, ícones, botões e cartões) e roláveis por arrasto em
  qualquer ponto, com inércia; arrastar sobre um botão não compra nada.
- Na garagem, toda a página (nave, carga, abas e cartões) rola; o cabeçalho fica fixo.

## [0.7.1] — Vale das Raízes mais fiel à referência

### Alterado
- Texturas de terreno refeitas em "bolhas" (torrões pequenos com pontinho de brilho e vãos
  escuros), sem linhas de calçamento; rocha compacta e solo rachado mantêm as frestas.
- Depósitos com 16×16 pixels de arte (um bloco): cristais facetados com faixa de brilho e
  halo translúcido (cristal azul, cristal roxo, diamante, urânio), cubos metálicos, pepitas
  de ouro com reflexo, ametista em drusa, topázio prismático.
- Raízes com sombreamento cilíndrico (faixa de brilho, lado escuro) e ramificações; moitas
  de folhas, palmeirinha, cogumelos com pintas, pedras granuladas, rochas pontudas
  avermelhadas, crânio, amonite e costelas redesenhados. Decorações em células de 32.
- Superfície do Vale mais limpa: solo com raízes e com musgo passam para a camada de terra
  escura, onde o tom combina.

## [0.7.0] — Visual do Vale das Raízes

### Adicionado
- **16 texturas de terreno** em pixel art repetível (terra clara/escura, argila, solo
  compacto, úmido, com raízes, com musgo, rachado, pedras clara/cinza/escura, rocha compacta e
  profunda, terra avermelhada, solo arenoso e misto), aplicadas pelo shader por camada.
- **Depósitos redesenhados** como sprites embutidos com silhuetas próprias (cubos metálicos,
  pepitas de ouro, gemas lapidadas, lascas, drusas, rocha com mineral exposto), 3 variações.
- **Raízes, musgo, plantas, cogumelos e rochas** decorativos no Vale: embutidos no solo e nas
  cavernas naturais (chão e teto), sem colisão; somem quando o apoio é escavado.
- **Fósseis** variados (osso, crânio, amonite, costelas).
- Assets reais em `assets/environment/` e gerador `tools/gen_env_assets.gd`.
- Testes do ambiente (`test_environment.gd`).

### Alterado
- Terra, pedra, argila e rochas usam as novas texturas em todas as regiões; areia das Dunas,
  gelo, lama e magma mantêm o desenho próprio.
- Ícones de minério do mapa usam os mesmos sprites da mina.

## [0.6.0] — Minérios, terrenos e mapa mundial

### Adicionado
- **Mapa mundial** em carrossel: uma região por página com ilustração (ilha flutuante),
  deslizar horizontal com encaixe suave, setas laterais e indicadores de página; painel com
  nome, descrição, dificuldade, progresso, camadas de profundidade, principais recursos,
  riscos ambientais, equipamentos recomendados e botão EXPLORAR (desativado se bloqueada).
- **Seis regiões** com camadas próprias: Vale das Raízes, Dunas de Âmbar, Cordilheira de
  Ferro, Pântano das Profundezas, Abismo de Obsidiana e Vazio Cristalino. Desbloqueio por
  profundidade alcançada na região anterior (sem moedas novas).
- **Salvamento do perfil** (antes não havia): economia, upgrades, módulos, carga, região atual
  e progresso por região; escrita atômica com cópia de segurança.
- Terrenos novos (areia, argila, gelo, lama) e depósitos novos (carvão, prata, quartzo,
  esmeralda, titânio, urânio, obsidiana, diamante, cristal raro) e especiais (fóssil, meteorito).
- Ícones de catálogo dos minérios para os painéis; botão de mapa no HUD.
- Testes: `test_regions.gd`, `test_save.gd` e verificações do mapa no teste de cena.

### Alterado
- **Terra e Pedra** são terreno (textura macia × pedra compacta), mantendo a recompensa
  que já existia. Depósitos viram **pequenas pepitas/lascas** embutidas na rocha, com
  contorno e cores distintas — sem nomes nem molduras durante a mineração.
- Biomas fixos substituídos pelas camadas da região escolhida; calor começa por região.
- "Vazionita" passa a se chamar **Minério arcano**.

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
