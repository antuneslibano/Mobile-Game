# DEEPFORGE — Expedições, base e criaturas (plano 0.9 → 0.11)

Documento de design das próximas versões. Decisões do autor marcadas com **[decidido]**;
números são propostas iniciais `[T]`, validadas depois por simulação (`tests/balance_sim.gd`).

## Visão

Você é um **cientista-explorador de terras raras**. Cada descida é uma **expedição**: sai da
base, cava com combustível limitado, coleta amostras e minérios, encontra criaturas e
precisa **voltar** com a carga. O que traz vira **pesquisa** (novos projetos) e **materiais**
(para construir as peças da nave na base). Cada região tem um **fundo** com uma câmara final;
o Núcleo, no Vazio Cristalino, é o fim do jogo.

Ciclo: **Base → Expedição → Extração → Pesquisa/Construção → Base**.

## Decisões

| Tema | Decisão |
|---|---|
| Fim da expedição | **Combustível** é o limite principal; resgate de emergência devolve **50% da carga** [decidido] |
| Economia | **Híbrida**: construir peças custa materiais + créditos; vender só o excedente [decidido] |
| Base | Tela com **estações tocáveis** (sem personagem andando) [decidido] |
| Criaturas | Comportamento **depende da espécie** (ambiente, guardiã, escavadora, chefe) [decidido] |
| Elevadores | ~~Começar da última camada~~ — **removidos na 0.9.1** (o autor não gostou); os túneis salvos fazem o papel: cair por eles não gasta combustível [decidido] |
| Fim do mapa | Câmara final com **guardião** (marco + chefe) e saída clara para a base (0.9.1) [decidido] |

---

## 0.9 — Expedições ✅ (implementada)

### Combustível
- Tanque base `120` `[T]` (implementado). Gasta `1/s` em atividade (movendo ou cavando) e `×1,5` na Sobrecarga;
  parado não gasta.
- **Carvão vira combustível**: cada bloco de carvão abastece `+12` direto no tanque (o minério
  mais barato ganha papel).
- Upgrades novos: **Tanque** (capacidade) e **Eficiência** (consumo).
- HUD: barra de combustível ao lado da energia; aviso em 25% e 10%.

### Casco
- `100` de casco `[T]`. Dano por: calor acima do limite (por segundo), desmoronamentos
  (risco já listado no mapa), criaturas (0.11).
- Upgrade novo: **Blindagem**. HUD: barra de casco.

### Extração e resgate
- Botão **EXTRAIR** no HUD: cápsula sobe com a nave; **100% da carga**.
- **Combustível = 0 ou casco = 0** → resgate de emergência: **50% da carga** (por recurso,
  arredondado para baixo). Cristais já na carteira não se perdem.
- Tela de resultado da expedição: carga trazida, perdas, descobertas, objetivos cumpridos.

### ~~Elevadores~~ (removidos na 0.9.1)
- Toda expedição parte da superfície; o mundo persistente guarda o poço, e cair por ele não
  gasta combustível.

### Mundo persistente por região
- **Seed fixa por região** e **escavação salva** (`WorldModel.export_modifications` já existe):
  minério tirado não reaparece (sem farm), túneis continuam lá na volta.

### Fundo e câmara final
- O `target_depth_m` de cada região vira um **fundo real** (rocha-mãe) com uma **câmara final**
  gerada (sala grande) com um **guardião** (0.9.1). Vencê-lo = **objetivo principal**:
  - libera a **próxima região** (substitui o requisito atual de profundidade);
  - libera um **projeto grande** (0.10).

| Região | Fundo (0.9.1) | Câmara final · guardião |
|---|---|---|
| Vale das Raízes | 600 m | Raiz-Mãe · Coração da Raiz-Mãe (minhocão na 0.11) |
| Dunas de Âmbar | 700 m | Templo soterrado · Ídolo de âmbar |
| Cordilheira de Ferro | 800 m | Veio-mãe de titânio · Núcleo de titânio |
| Pântano das Profundezas | 850 m | Ninho no lodo · Ovo do lodo |
| Abismo de Obsidiana | 950 m | Câmara de magma · Coração de magma (o limite é o calor) |
| Vazio Cristalino | 1000 m | O Núcleo · Cristal-Núcleo — fim do jogo |

### Objetivos por região (painel do mapa)
- **Principal**: vencer o guardião da câmara final.
- **Pesquisa** (3): ex.: catalogar os minérios novos da região, encontrar 5 fósseis,
  trazer 10 amostras de X.
- **Desafios** (3 estrelas): ex.: chegar ao fundo numa expedição; voltar com carga ≥ X;
  extrair sem resgate de emergência.
- Substitui o "% explorado" do carrossel; salvos por região.

### Dentro da expedição não se compra
- A garagem sai do HUD durante a expedição (vira a base, 0.10). Na 0.9, provisoriamente, a
  garagem atual abre **só na base** (entre expedições).

---

## 0.10 — Base e construção

Tela da base com **estações tocáveis**:

| Estação | Função |
|---|---|
| Hangar | Nave com as peças instaladas (visíveis no sprite) |
| Bancada | Projetos liberados e construção (materiais + créditos) |
| Laboratório | Catálogo de minérios, criaturas e fósseis; diário de pesquisa (história) |
| Mesa de mapas | Carrossel de regiões + escolha de elevador |
| Mercado | Venda do excedente |

- **Projetos** se liberam por pesquisa: descobrir um minério, catalogar uma criatura, chegar
  a uma câmara final. Ex.: descobrir urânio → "Reator compacto".
- **Receitas** `[T]`: ex.: Broca Nv. 3 = 12 ferro + 6 prata + 300 créditos.
- Os upgrades atuais viram peças com receita; os níveis existentes no salvamento são
  preservados.

## 0.11 — Criaturas (começando pelo Vale)

| Papel | Vale | Comportamento | Recompensa |
|---|---|---|---|
| Ambiente | toupeira de raiz, vaga-lume | anda pelas superfícies, foge da nave | entrada no catálogo |
| Guardiã | aranha de raiz | protege um veio brilhante; ataca quem se aproxima | amostra biológica |
| Escavadora | minhoca | abre os próprios túneis; dano no contato | amostra biológica |
| Chefe | minhocão da Raiz-Mãe | câmara final | projeto grande |

- Combate com o que já existe: **broca** (contato), **drone** (laser), **pulso sísmico**
  (atordoa). Dano no casco.
- Amostras biológicas servem para pesquisa e construção (não para dinheiro).
- Depois: criaturas e chefes das outras regiões.

## História (diário de pesquisa)

Cada descoberta gera uma entrada curta no diário (Laboratório). Aos poucos, as entradas
revelam que as criaturas e os minerais raros estão ligados ao Núcleo. Sem cenas longas.

## Riscos

- **Escopo**: cada versão entrega um ciclo jogável completo; criaturas só depois de casco e
  objetivos existirem.
- **Desempenho**: criaturas com IA simples sobre a grade de células; poucas por tela.
- **Balanceamento**: a simulação ganha combustível, extração e elevadores na 0.9.
