# Prompts de texturas para o ChatGPT (DEEPFORGE)

Como usar:
1. No ChatGPT, mande primeiro o **ESTILO GERAL** (uma vez por conversa).
2. Depois mande um prompt por vez (um prompt = uma imagem).
3. Salve cada imagem com o **nome do arquivo** indicado (ex.: `terra_clara.png`) e me mande todas.
   Eu reduzo para o tamanho do jogo, travo as cores, deixo emendável e gero as variações.

Comece pelo **PILOTO DO VALE** (marcado com ★): é o que mais aparece na tela.

---

## ESTILO GERAL (mandar primeiro)

```
Vou te pedir texturas para um jogo mobile 2D de escavação em pixel art, visto de lado
(corte do subsolo, sem perspectiva). Regras para TODAS as imagens:
- Pixel art de verdade: cada "pixel" da arte é um quadrado chapado, sem anti-aliasing,
  sem desfoque, sem gradiente suave, sem ruído fotográfico.
- Paleta pequena: no máximo 6 a 8 cores por imagem, tons terrosos e saturação moderada.
- Luz suave vinda de cima à esquerda, só nos detalhes (pedrinhas, bordas). Nada de
  sombra grande nem vinheta na imagem toda.
- Sem texto, sem moldura, sem borda, sem marca d'água.
- Estilo de referência: jogos como Terraria, Dome Keeper e Motherload, mas mais limpo.
Responda só com a imagem.
```

---

## TERRENOS (textura que se repete) — 16 imagens

Formato para todos (já vai dentro de cada prompt): imagem quadrada 1024×1024, desenhada numa
grade de **64×64 pixels de arte** (cada pixel da arte = quadrado de 16×16), **emendável nos
4 lados** (as bordas continuam do outro lado, sem costura).

★ `terra_clara.png`
```
Textura emendável nos 4 lados, 1024x1024, pixel art numa grade de 64x64 (cada pixel = quadrado 16x16).
Terra marrom clara da superfície, solta, com grãos e algumas pedrinhas pequenas espalhadas
(sem padrão repetitivo visível). Cores: marrom claro, bege, marrom médio, 1 tom escuro para sombras.
```

★ `terra_escura.png`
```
Textura emendável nos 4 lados, 1024x1024, pixel art numa grade de 64x64 (cada pixel = quadrado 16x16).
Terra marrom escura e úmida, com torrões e alguns grãos mais claros. Cores: marrom escuro,
marrom café, 1 tom quase preto, 1 tom mais claro para destaques.
```

★ `solo_compacto.png`
```
Textura emendável nos 4 lados, 1024x1024, pixel art numa grade de 64x64 (cada pixel = quadrado 16x16).
Solo marrom compactado, com camadas horizontais sutis e pedregulhos achatados.
Cores: marrom médio, marrom acinzentado, bege, 1 tom escuro.
```

★ `solo_umido.png`
```
Textura emendável nos 4 lados, 1024x1024, pixel art numa grade de 64x64 (cada pixel = quadrado 16x16).
Terra escura encharcada, com manchas mais escuras de umidade e poucos pontinhos brilhantes
de água. Cores: marrom muito escuro, marrom-esverdeado, 1 tom de brilho azulado bem discreto.
```

★ `solo_com_raizes.png`
```
Textura emendável nos 4 lados, 1024x1024, pixel art numa grade de 64x64 (cada pixel = quadrado 16x16).
Terra marrom com raízes finas e claras atravessando em curvas (raízes saem e entram pelas
bordas para emendar). Cores: marrom, marrom escuro, raízes bege-amareladas com sombra marrom.
```

★ `solo_com_musgo.png`
```
Textura emendável nos 4 lados, 1024x1024, pixel art numa grade de 64x64 (cada pixel = quadrado 16x16).
Terra escura com manchas de musgo verde-oliva em tufos irregulares. Cores: marrom escuro,
verde-musgo escuro, verde-musgo claro, 1 tom quase preto.
```

★ `solo_arenoso.png`
```
Textura emendável nos 4 lados, 1024x1024, pixel art numa grade de 64x64 (cada pixel = quadrado 16x16).
Areia amarelada compacta com grãos visíveis e pequenas ondulações horizontais.
Cores: amarelo-areia, bege, ocre, 1 tom marrom para sombras.
```

★ `solo_misto.png`
```
Textura emendável nos 4 lados, 1024x1024, pixel art numa grade de 64x64 (cada pixel = quadrado 16x16).
Mistura de terra, areia e pedrinhas de tamanhos variados. Cores: marrom, bege-areia,
cinza das pedrinhas, 1 tom escuro.
```

★ `argila.png`
```
Textura emendável nos 4 lados, 1024x1024, pixel art numa grade de 64x64 (cada pixel = quadrado 16x16).
Argila laranja-avermelhada, lisa, com camadas finas horizontais levemente onduladas.
Cores: laranja-terracota, vermelho-tijolo, laranja claro, 1 tom marrom escuro.
```

★ `terra_avermelhada.png`
```
Textura emendável nos 4 lados, 1024x1024, pixel art numa grade de 64x64 (cada pixel = quadrado 16x16).
Terra vermelho-ferrugem granulada com pedrinhas escuras. Cores: vermelho-ferrugem,
marrom-avermelhado, laranja queimado, 1 tom escuro.
```

★ `solo_rachado.png`
```
Textura emendável nos 4 lados, 1024x1024, pixel art numa grade de 64x64 (cada pixel = quadrado 16x16).
Argila seca e rachada: placas irregulares separadas por fissuras escuras finas.
Cores: terracota claro, terracota, marrom, fissuras quase pretas.
```

★ `pedra_clara.png`
```
Textura emendável nos 4 lados, 1024x1024, pixel art numa grade de 64x64 (cada pixel = quadrado 16x16).
Pedra bege-acinzentada clara formada por blocos/pedras irregulares encaixados, com bordas
iluminadas em cima e sombra embaixo de cada pedra. Cores: bege-cinza claro, cinza médio,
cinza escuro para as juntas, 1 destaque quase branco.
```

★ `pedra_cinza.png`
```
Textura emendável nos 4 lados, 1024x1024, pixel art numa grade de 64x64 (cada pixel = quadrado 16x16).
Pedra cinza média com pedras encaixadas de tamanhos variados e rachaduras finas.
Cores: cinza médio, cinza claro, cinza escuro, 1 tom azulado discreto.
```

★ `pedra_escura.png`
```
Textura emendável nos 4 lados, 1024x1024, pixel art numa grade de 64x64 (cada pixel = quadrado 16x16).
Pedra cinza-azulada escura, pedras grandes encaixadas, poucas rachaduras.
Cores: cinza-azulado escuro, cinza-azulado médio, quase preto, 1 destaque cinza claro.
```

★ `rocha_compacta.png`
```
Textura emendável nos 4 lados, 1024x1024, pixel art numa grade de 64x64 (cada pixel = quadrado 16x16).
Rocha densa e maciça cinza-escura, sem blocos separados, com veios finos mais claros em diagonal.
Cores: cinza grafite, cinza médio, veios cinza claro, 1 tom quase preto.
```

★ `rocha_profunda.png`
```
Textura emendável nos 4 lados, 1024x1024, pixel art numa grade de 64x64 (cada pixel = quadrado 16x16).
Rocha muito profunda, quase preta, com tom azul-arroxeado e poucos detalhes (cristais
minúsculos apagados). Cores: preto-azulado, roxo muito escuro, azul escuro, 1 pontinho lilás.
```

---

## MINÉRIOS (sprite por cima da rocha) — fundo transparente

Formato: imagem quadrada 1024×1024, **fundo transparente**, pixel art numa grade de **16×16
pixels de arte** (cada pixel = quadrado de 64×64), o minério centralizado ocupando uns 12×12 da
grade, **contorno escuro de 1 pixel**. Uma imagem por minério; as 3 variações eu faço.

★ `cobre.png`
```
Sprite pixel art 1024x1024 com fundo transparente, numa grade de 16x16 (cada pixel = quadrado 64x64).
Pepitas de cobre agrupadas (3 a 4 pedaços arredondados), laranja-acobreado com brilho
claro em cima e sombra marrom embaixo, contorno escuro de 1 pixel. Centralizado, ocupando ~12x12.
```

★ `ferro.png`
```
Sprite pixel art 1024x1024 com fundo transparente, numa grade de 16x16 (cada pixel = quadrado 64x64).
Pedaços de minério de ferro: rocha cinza-escura com manchas cor de ferrugem e reflexo
metálico cinza claro, contorno escuro de 1 pixel. Centralizado, ocupando ~12x12.
```

★ `prata.png`
```
Sprite pixel art 1024x1024 com fundo transparente, numa grade de 16x16 (cada pixel = quadrado 64x64).
Pepitas de prata brilhantes, branco-azulado com reflexo quase branco e sombra cinza,
contorno escuro de 1 pixel. Centralizado, ocupando ~12x12.
```

★ `ouro.png`
```
Sprite pixel art 1024x1024 com fundo transparente, numa grade de 16x16 (cada pixel = quadrado 64x64).
Pepitas de ouro grandes e brilhantes, amarelo-dourado com reflexo amarelo claro e sombra
laranja-escura, 1 ou 2 brilhos em estrela, contorno escuro de 1 pixel. Centralizado, ~12x12.
```

★ `carvao.png`
```
Sprite pixel art 1024x1024 com fundo transparente, numa grade de 16x16 (cada pixel = quadrado 64x64).
Pedaços de carvão preto fosco com arestas, pequenos reflexos cinza-azulados,
contorno escuro de 1 pixel. Centralizado, ocupando ~12x12.
```

★ `quartzo.png`
```
Sprite pixel art 1024x1024 com fundo transparente, numa grade de 16x16 (cada pixel = quadrado 64x64).
Cristais de quartzo branco-leitosos em ponta, 3 cristais saindo de uma base de pedra,
faces claras e sombra cinza-lilás, contorno escuro de 1 pixel. Centralizado, ~12x12.
```

★ `cristal_azul.png`
```
Sprite pixel art 1024x1024 com fundo transparente, numa grade de 16x16 (cada pixel = quadrado 64x64).
Cristais azul-ciano em ponta saindo de uma base de pedra, faces com 3 tons de azul e
reflexo quase branco, contorno escuro de 1 pixel. Centralizado, ocupando ~12x12.
```

★ `ametista.png`
```
Sprite pixel art 1024x1024 com fundo transparente, numa grade de 16x16 (cada pixel = quadrado 64x64).
Drusa de ametista: cristais roxos em ponta saindo de uma base de pedra, 3 tons de roxo e
reflexo lilás claro, contorno escuro de 1 pixel. Centralizado, ocupando ~12x12.
```

★ `bau.png`
```
Sprite pixel art 1024x1024 com fundo transparente, numa grade de 16x16 (cada pixel = quadrado 64x64).
Baú de madeira antigo semi-enterrado, tampa arredondada, ferragens de metal dourado e
fechadura, contorno escuro de 1 pixel. Centralizado, ocupando ~13x12.
```

Depois do piloto (outras regiões):

`titanio.png`
```
Sprite pixel art 1024x1024 com fundo transparente, numa grade de 16x16 (cada pixel = quadrado 64x64).
Minério de titânio: rocha escura com placas metálicas azul-acinzentadas brilhantes,
contorno escuro de 1 pixel. Centralizado, ocupando ~12x12.
```

`uranio.png`
```
Sprite pixel art 1024x1024 com fundo transparente, numa grade de 16x16 (cada pixel = quadrado 64x64).
Minério de urânio: pedras escuras com cristais verde-limão que parecem brilhar,
contorno escuro de 1 pixel. Centralizado, ocupando ~12x12.
```

`cristal_verde.png` (esmeralda)
```
Sprite pixel art 1024x1024 com fundo transparente, numa grade de 16x16 (cada pixel = quadrado 64x64).
Esmeraldas: cristais verdes lapidados em prisma saindo de uma base de pedra, 3 tons de
verde e reflexo claro, contorno escuro de 1 pixel. Centralizado, ocupando ~12x12.
```

`diamante.png`
```
Sprite pixel art 1024x1024 com fundo transparente, numa grade de 16x16 (cada pixel = quadrado 64x64).
Diamantes brutos azul-gelo muito claros com faces bem marcadas e brilhos em estrela,
contorno escuro de 1 pixel. Centralizado, ocupando ~12x12.
```

`cristal_vermelho.png` (rubi)
```
Sprite pixel art 1024x1024 com fundo transparente, numa grade de 16x16 (cada pixel = quadrado 64x64).
Rubis: cristais vermelho-sangue em prisma saindo de uma base de pedra, 3 tons de vermelho
e reflexo rosado, contorno escuro de 1 pixel. Centralizado, ocupando ~12x12.
```

`cristal_roxo.png` (cristal raro)
```
Sprite pixel art 1024x1024 com fundo transparente, numa grade de 16x16 (cada pixel = quadrado 64x64).
Cristal raro rosa-magenta translúcido, alto e fino, com núcleo mais claro e pequenas
faíscas, contorno escuro de 1 pixel. Centralizado, ocupando ~12x12.
```

---

## Dicas
- Se o ChatGPT fizer uma imagem com perspectiva, sombra grande ou "foto", peça:
  "refaça mais chapado, pixel art de verdade, sem gradiente, menos cores".
- Se a textura de terreno tiver costura visível, peça: "deixe emendável nos 4 lados".
- Pode mandar também uma imagem de referência de que você gostou junto com o prompt.
