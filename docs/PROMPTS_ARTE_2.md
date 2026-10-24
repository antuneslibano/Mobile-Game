# Prompts de arte — parte 2 (DEEPFORGE)

O que aprendemos com a parte 1:
- **Terrenos** ficaram ótimos (textura que se repete, vista de perto).
- **Minérios** não funcionaram: o ChatGPT faz ilustrações grandes e detalhadas, e no
  tamanho de um bloco (16×16 pixels) elas viram "pipoca". Abaixo tem um prompt novo,
  pensado para ícone minúsculo.
- O ChatGPT brilha em **arte grande**: ilhas do mapa, fundo da base, tela de abertura,
  núcleo do guardião, fundos das cavernas. É isso que esta parte pede.

Como usar: mande o **ESTILO GERAL 2** uma vez; depois um prompt por imagem; salve com o
nome indicado e me mande. Prefira **fundo transparente** quando o prompt pedir (se vier
com fundo, eu recorto, mas transparente fica melhor).

---

## ESTILO GERAL 2 (mandar primeiro)

```
Vou pedir artes para um jogo mobile 2D de escavação ("DEEPFORGE: Rumo ao Núcleo"):
uma nave-broca cava até o centro da Terra passando por regiões (vale de raízes, dunas de
âmbar, cordilheira de ferro, pântano, abismo de obsidiana e vazio cristalino).
Estilo para TODAS as imagens:
- Pixel art em alta definição, com pixels visíveis e bordas nítidas (sem desfoque),
  contorno escuro nas formas principais, sombreado em 3 a 4 tons.
- Cores vibrantes mas não neon; luz vinda de cima à esquerda.
- Leitura clara em tela de celular: formas grandes primeiro, detalhes pequenos depois.
- Sem texto, sem logotipo, sem moldura, sem marca d'água.
Responda só com a imagem.
```

---

## 1. Ilhas das regiões (mapa) — 6 imagens, fundo transparente

Aparecem grandes no carrossel do mapa. Formato: 1536×1024, **fundo transparente**, a ilha
centralizada ocupando ~80% da largura.

`ilha_vale.png`
```
Ilha flutuante em corte (vista de lado), fundo transparente, 1536x1024. Em cima: grama
verde, árvores pequenas e raízes grossas descendo pela terra. O corte mostra camadas:
terra marrom, argila avermelhada, pedra cinza e, no fundo, um núcleo vermelho pulsando
entre raízes. Pedrinhas soltas caindo da base.
```

`ilha_dunas.png`
```
Ilha flutuante em corte (vista de lado), fundo transparente, 1536x1024. Em cima: dunas
de areia dourada com ossos e pedras. O corte mostra areia, arenito em faixas laranja e
veios de âmbar brilhando; no fundo, um núcleo âmbar brilhante.
```

`ilha_cordilheira.png`
```
Ilha flutuante em corte (vista de lado), fundo transparente, 1536x1024. Em cima: picos
rochosos cinza-azulados com neve nas pontas. O corte mostra rocha densa com veios de
ferro e titânio metálicos; no fundo, um núcleo de metal incandescente.
```

`ilha_pantano.png`
```
Ilha flutuante em corte (vista de lado), fundo transparente, 1536x1024. Em cima: pântano
escuro com poças, juncos e cogumelos que brilham. O corte mostra lama verde-escura,
raízes molhadas e bolhas; no fundo, um núcleo verde-ácido.
```

`ilha_abismo.png`
```
Ilha flutuante em corte (vista de lado), fundo transparente, 1536x1024. Em cima: rocha
vulcânica preta rachada com fumaça. O corte mostra obsidiana roxa-escura e rios de magma
laranja; no fundo, um núcleo de magma.
```

`ilha_vazio.png`
```
Ilha flutuante em corte (vista de lado), fundo transparente, 1536x1024. Em cima: cristais
gigantes rosa e lilás. O corte mostra rocha escura quase preta com cristais flutuando e
pontos de luz como estrelas; no fundo, um núcleo prismático.
```

---

## 2. Tela de abertura — 1 imagem

`abertura.png`
```
Arte de capa vertical 1024x1536 para jogo mobile. Uma nave-broca pequena e robusta
(amarela e branca, broca cônica embaixo) mergulhando num poço que desce por camadas
coloridas da Terra até um núcleo brilhante lá no fundo. Deixe o terço de cima mais
limpo (céu escuro ao amanhecer) para eu colocar o título do jogo.
```

---

## 3. Fundo da base (tela inicial) — 1 imagem

Fica atrás das estações (Bancada, Hangar, Mercado, Laboratório, Mesa de mapas), que
continuam desenhadas pelo jogo. Por isso o fundo **não deve ter máquinas nem mesas**.

`fundo_base.png`
```
Fundo vertical 1024x1536 de uma base de pesquisa subterrânea vista de frente, VAZIA:
paredes de metal rebitado e rocha, vigas, canos, cabos, luzes amareladas no teto, piso
de grade metálica na parte de baixo. Sem máquinas, sem mesas, sem pessoas, sem objetos
no chão (o jogo coloca as estações por cima). Clima aconchegante de oficina.
```

---

## 4. Fundo das cavernas (atrás dos túneis) — 6 imagens que se repetem

Aparece nos túneis já escavados, bem escurecido pelo jogo. Formato: 1024×1024,
**emendável nos 4 lados**, pouco contraste.

`caverna_vale.png`
```
Textura emendável nos 4 lados, 1024x1024: parede de caverna escura vista de frente, terra
marrom-escura com raízes finas e pedras embutidas, pouco contraste, tons escuros.
```
`caverna_dunas.png`
```
Textura emendável nos 4 lados, 1024x1024: parede de caverna de arenito escuro em faixas
horizontais laranja-amarronzadas, pouco contraste, tons escuros.
```
`caverna_cordilheira.png`
```
Textura emendável nos 4 lados, 1024x1024: parede de caverna de rocha cinza-azulada escura
com fraturas e pequenos veios metálicos apagados, pouco contraste.
```
`caverna_pantano.png`
```
Textura emendável nos 4 lados, 1024x1024: parede de caverna de lama verde-escura com
raízes e pequenos fungos apagados, pouco contraste, tons escuros.
```
`caverna_abismo.png`
```
Textura emendável nos 4 lados, 1024x1024: parede de caverna de obsidiana quase preta com
rachaduras finas de brasa vermelha bem apagadas, pouco contraste.
```
`caverna_vazio.png`
```
Textura emendável nos 4 lados, 1024x1024: parede de caverna roxa quase preta com
pontinhos de cristal lilás como estrelas distantes, pouco contraste.
```

---

## 5. Núcleo do guardião (chefe) — 6 imagens, fundo transparente

Aparece grande na arena do combate (os tentáculos o jogo desenha).

`nucleo_vale.png`
```
Coração-núcleo orgânico de um chefe, 1024x1024, fundo transparente, visto de frente:
uma esfera vermelha pulsante envolta por raízes grossas, com um "olho" brilhante no
centro e rachaduras luminosas. Ameaçador mas bonito.
```
Para as outras regiões, troque a descrição do meio:
- `nucleo_dunas.png`: "esfera de âmbar com inseto fossilizado, envolta por ossos e areia"
- `nucleo_cordilheira.png`: "esfera de metal incandescente com placas de ferro rebitadas"
- `nucleo_pantano.png`: "esfera verde-ácida gosmenta, envolta por raízes molhadas e bolhas"
- `nucleo_abismo.png`: "esfera de magma com crosta de obsidiana rachada"
- `nucleo_vazio.png`: "esfera prismática de cristal que reflete arco-íris"

---

## 6. Minérios — nova tentativa (ícone minúsculo)

Faça primeiro só 2 (cobre e ouro) para testarmos antes dos outros.

`cobre.png`
```
Ícone de jogo para ser visto MUITO pequeno (32x32 na tela), desenhado em 1024x1024 com
fundo transparente: 3 pepitas de cobre grandes e simples, formas arredondadas, contorno
preto GROSSO, 3 tons de laranja-acobreado + 1 brilho claro. Sem pedras em volta, sem
brilho no fundo, sem detalhes pequenos, sem faíscas. Estilo ícone de Terraria.
```
`ouro.png`
```
Ícone de jogo para ser visto MUITO pequeno (32x32 na tela), desenhado em 1024x1024 com
fundo transparente: 2 a 3 pepitas de ouro grandes e simples, contorno preto GROSSO,
3 tons de amarelo-dourado + 1 brilho quase branco. Sem pedras em volta, sem brilho no
fundo, sem detalhes pequenos, sem faíscas. Estilo ícone de Terraria.
```
