# Prompts de arte — a nave (DEEPFORGE)

## Antes de começar: como a nave funciona no jogo

- A nave **não é uma imagem só**. O jogo monta a nave a partir de **5 peças** que o jogador
  troca no Hangar: **formato da broca**, **material da broca**, **casco**, **motor** e
  **pintura**. São 5 × 7 × 5 × 5 × 8 = 7.000 combinações, então não dá para gerar uma
  imagem por combinação. Por isso os prompts pedem **peças separadas, sempre no mesmo
  enquadramento**, para eu encaixar uma em cima da outra.
- Em jogo a nave é **pequena** (mais ou menos do tamanho de um dedo na tela). Ela aparece
  **grande** só no Hangar. Então a arte precisa ser bonita grande, e também precisa ter uma
  **silhueta clara**, para continuar reconhecível quando eu reduzir.
- A nave é vista **de lado**, deitada, com a **broca apontando para a DIREITA**. Em jogo eu
  giro a imagem para a direção em que ela cava.
- A **rotação da broca** (a espiral girando), o **fogo dos motores**, a **sujeira** e o
  **brilho** eu faço no código. Não precisa pedir isso.

**Ordem recomendada:** faça só o **teste (passo 1)** primeiro e me mande. Com os minérios
aprendemos que vale testar antes de gerar tudo. Se a nave ficar boa no jogo, seguimos com
as peças.

**Dica importante para manter tudo alinhado:** no ChatGPT, gere a nave base (passo 2) e,
para cada variante, **envie de novo a imagem da nave base** junto com o prompt da variante
("edite esta imagem…"). Assim ele mantém a mesma pose, o mesmo tamanho e a mesma posição.
Se sair um pouco torto, tudo bem: eu alinho aqui.

---

## ESTILO DA NAVE (mandar primeiro, uma vez)

```
Vou pedir artes da nave de um jogo mobile 2D de escavação ("DEEPFORGE: Rumo ao Núcleo").
A nave é uma pequena máquina-broca que cava até o centro da Terra.

Design da nave (manter SEMPRE igual):
- Vista lateral perfeita (perfil, sem perspectiva), deitada na horizontal, com a broca
  apontando para a DIREITA.
- Corpo central compacto e arredondado, casco BRANCO com sombra cinza-azulada embaixo.
- Placas de blindagem AMARELAS em cima e embaixo do casco (é a "pintura" da nave).
- Cabine com janela AZUL brilhante e um reflexo claro, na parte da frente do corpo.
- Dois módulos de propulsão cinza, um em cima e outro embaixo do corpo, com luzinhas
  azul-ciano.
- Bloco traseiro de metal escuro com dois bocais de motor amarelos na traseira (esquerda).
- Na frente (direita), uma broca em cone, de aço, com uma espiral marcada.
- Proporção total de 7 de largura para 4 de altura; a broca ocupa ~40% da largura.

Estilo para TODAS as imagens:
- Pixel art em alta definição, pixels visíveis, bordas nítidas, sem desfoque.
- Contorno escuro grosso em volta da silhueta toda; sombreado em 3 a 4 tons.
- Luz vinda de cima à esquerda.
- Formas grandes e simples primeiro: precisa continuar reconhecível reduzida a 35×20 pixels.
- Fundo TRANSPARENTE (PNG), sem chão, sem sombra projetada, sem fogo, sem efeitos.
- Sem texto, sem logotipo, sem moldura, sem marca d'água.
Responda só com a imagem.
```

---

## 1. TESTE — nave completa (fazer primeiro)

`nave_teste.png`
```
A nave completa como descrita, versão padrão (broca de aço em cone, casco branco, pintura
amarela, motores padrão). Imagem 1536×1024, fundo transparente, nave centralizada ocupando
~85% da largura. Silhueta forte e limpa.
```

Me mande essa. Eu reduzo para o tamanho do jogo e mostro como ficou no Hangar e cavando.

---

## 2. Nave base (a "referência" de todas as peças)

Se o teste ficou bom, ele mesmo pode ser a base. Se não, gere de novo:

`nave_base.png`
```
A mesma nave, 1536×1024, fundo transparente, centralizada ocupando ~85% da largura.
Esta imagem será a REFERÊNCIA para todas as próximas: mantenha exatamente esta pose,
este tamanho e esta posição.
```

---

## 3. Peças separadas (sempre enviando a nave_base junto)

Cada peça vem **sozinha**, em 1536×1024, fundo transparente, **na mesma posição em que
fica na nave_base**. Assim eu empilho as camadas. Use este começo em todos os prompts:

```
Edite esta imagem: mantenha o mesmo tamanho de tela, a mesma escala e a mesma posição.
Apague tudo, deixe só a peça pedida, no lugar exato em que ela está na nave. Fundo
transparente.
```

### 3a. Corpo sem broca e sem motor

`peca_corpo.png`
```
Deixe só o corpo central: casco, placas amarelas, cabine e os módulos de propulsão de
cima e de baixo. Sem a broca da frente e sem o bloco traseiro com os bocais.
```

### 3b. Cascos — 5 imagens (só o corpo, como na 3a)

`casco_padrao.png`
```
O corpo como na peça do corpo: casco branco liso com sombra cinza-azulada.
```
`casco_blindado.png`
```
O mesmo corpo com placas de blindagem grossas e rebitadas na frente e atrás da cabine;
aspecto pesado e militar. Casco ainda branco.
```
`casco_titanio.png`
```
O mesmo corpo em titânio: azul-acinzentado claro metálico, com linhas de painel finas e
um brilho frio.
```
`casco_casca.png`
```
O mesmo corpo feito de casca de árvore e madeira: marrom, com veios, nós e pequenas
raízes coladas, como se tivesse crescido do Vale das Raízes.
```
`casco_dourado.png`
```
O mesmo corpo folheado a ouro: dourado brilhante com arabescos discretos gravados e
rebites dourados escuros.
```

**Regra para todos os cascos:** as placas de blindagem de cima e de baixo continuam em
**amarelo puro e chapado (3 tons)**. É a parte que eu troco de cor para as pinturas.

### 3c. Motores — 5 imagens (só o bloco traseiro com os bocais)

`motor_padrao.png`
```
Só o bloco traseiro de metal escuro com os dois bocais amarelos.
```
`motor_turbo.png`
```
O bloco traseiro com bocais de aço maiores e mais compridos, com um anel azul-ciano
brilhante na boca de cada um. Aspecto de alta velocidade.
```
`motor_tanques.png`
```
O bloco traseiro padrão, e os módulos de propulsão de cima e de baixo com tanques extras
laranja presos com cintas. Mande só o bloco traseiro e os dois módulos.
```
`motor_reator.png`
```
O bloco traseiro com um pequeno reator: uma esfera verde brilhante dentro de uma gaiola
de metal, com tubos ligando aos bocais.
```
`motor_vagalume.png`
```
O bloco traseiro com um abdômen de vaga-lume orgânico: segmentos em verde-amarelado
luminoso, com textura de inseto, no lugar dos bocais.
```

### 3d. Formatos da broca — 5 imagens (só a broca, em aço)

Todas em **aço** (cinza-azulado com espiral marcada). O material eu aplico por cima.

`broca_cone.png` — Padrão
```
Só a broca da frente: um cone médio de aço com espiral, base do tamanho da altura do corpo.
```
`broca_agulha.png` — Agulha
```
Só a broca: comprida e FINA como uma agulha, base estreita, ponta muito afiada, espiral
fina.
```
`broca_robusta.png` — Robusta
```
Só a broca: curta e LARGA, base mais alta que o corpo, formato de bala grossa
arredondada, espiral grossa.
```
`broca_dupla.png` — Dupla
```
Só a broca: DUAS brocas finas lado a lado, uma em cima e outra embaixo, paralelas,
saindo da mesma base.
```
`broca_coroa.png` — Coroa
```
Só a broca: um cilindro largo e reto (quase sem afinar), terminando numa coroa de dentes
serrilhados na ponta, como uma serra-copo.
```

### 3e. Materiais da broca — 7 amostras de textura

Não preciso de 35 brocas (5 formatos × 7 materiais). Preciso só da **superfície** de cada
material, que eu aplico em qualquer formato.

```
Uma textura quadrada 1024×1024, que se repete sem emendas, do material abaixo, vista de
perto, com o mesmo estilo de pixel art. Sem objeto, só a superfície.
```
| Arquivo | Material |
|---|---|
| `mat_aco.png` | Aço escovado cinza-azulado com riscos finos |
| `mat_dourada.png` | Ouro polido com reflexos amarelo-claros |
| `mat_cristal.png` | Cristal azul-ciano translúcido com facetas e brilhos brancos |
| `mat_raiz.png` | Raiz viva marrom-avermelhada, fibras torcidas e pequenas folhas |
| `mat_plasma.png` | Energia rosa-magenta com núcleo branco e faíscas |
| `mat_fossil.png` | Osso fóssil bege com rachaduras e marcas de concha |
| `mat_brasa.png` | Rocha incandescente: crosta escura com rachaduras laranja e amarelas |

### 3f. Pinturas — não precisa de imagem

As 8 pinturas (Amarelo, Cobre, Esmeralda, Rubi, Ametista, Âmbar, Meia-noite, Cromada) eu
faço trocando a cor das placas amarelas no código. Por isso a regra do amarelo chapado nos
cascos.

---

## 4. Módulos (acessórios) — 3 imagens

Mesma regra: envie a nave_base junto, deixe só o acessório, na posição em que ele fica.

`modulo_broca_lateral.png`
```
Acrescente uma broca lateral pequena presa embaixo do corpo, apontando para baixo e um
pouco para a frente. Depois apague a nave e deixe só a broca lateral com o suporte dela.
```
`modulo_drone.png`
```
Um pequeno drone minerador redondo com uma luz azul e duas hélices, flutuando acima e
atrás da nave. Mande só o drone, sem a nave, em 512×512 com fundo transparente.
```
`modulo_sismico.png`
```
Uma antena sísmica em cima do corpo: haste fina de metal com um disco e uma luz laranja
na ponta. Depois apague a nave e deixe só a antena.
```

---

## Resumo do que me mandar

1. `nave_teste.png` — **primeiro, sozinha**.
2. Se aprovado: `nave_base.png`, `peca_corpo.png`, os 5 cascos, os 5 motores, os 5
   formatos de broca, as 7 texturas de material e os 3 módulos (27 imagens além do teste,
   ou 26 se o teste virar a base).

Pode mandar em lotes de até 20, como antes. Os nomes ajudam muito, mas se esquecer de
renomear, mande na ordem desta lista.
