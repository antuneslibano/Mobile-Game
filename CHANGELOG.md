# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Versionamento: `0.<fase>.<correção>` até o 1.0.

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
