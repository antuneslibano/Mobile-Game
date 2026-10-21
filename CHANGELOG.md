# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Versionamento: `0.<fase>.<correção>` até o 1.0.

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
