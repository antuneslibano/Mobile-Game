# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Versionamento: `0.<fase>.<correção>` até o 1.0.

## [0.19.1] — Modo teste, relíquias com desenho próprio e prévia da nave

### Adicionado
- **Modo teste** (Configurações › MODO TESTE): +10.000 créditos, +100 cristais, +50 de
  cada recurso, todas as relíquias, liberar regiões, melhorias no máximo, sujar/limpar
  a nave, nave invencível (sem gastar combustível e sem dano) e, durante a expedição,
  ir até a relíquia, ir ao guardião ou encher tanque e casco.
- **Prévia da nave no visual**: cada opção mostra a miniatura da nave com aquela peça,
  e uma prévia animada fica no canto da tela enquanto você rola pela customização.

### Alterado
- As seis relíquias ganharam desenhos próprios (semente com broto, gota de âmbar com
  inseto, coração de metal, pérola na concha, gota de magma e prisma com arco-íris), no
  mundo e nos ícones. Antes usavam o sprite de cristais e minérios.

## [0.19.0] — Nave que desgasta, relíquias e "ele retornará"

### Adicionado
- **Calor na tela**: ao superaquecer, a tela treme e ondula como ar quente, mais forte
  quanto maior o excesso. O aviso mostra a perda: "BROCA −X% · CASCO −Y/s".
- **Desgaste da nave**: cavar suja e enferruja a nave; levar dano deixa amassados.
  Sujeira e ferrugem tiram até 25% da velocidade da broca; amassados fazem a expedição
  começar com o casco ferido. A nave fica visivelmente mais suja durante a expedição e
  o Hangar mostra um aviso quando ela precisa de cuidado.
- **Cuidar da nave** (Hangar): a nave aparece grande com as manchas de sujeira,
  ferrugem e os amassados. Escolha a ferramenta (ESPONJA, LIXA ou SOLDA) e arraste o
  dedo por cima: a sujeira sai com espuma e som, a lixa solta pó, a solda solta
  faíscas. Ao terminar uma camada, a nave brilha.
- **Formatos de broca** (Hangar › Visual): Padrão, Agulha, Robusta, Dupla e Coroa
  (esta só depois de vencer o guardião do Vale).
- **Vitória sobre o guardião**: tela de VITÓRIA, depois escurece, um coração pulsa e
  aparece "...mas ele retornará.". A região é refeita (novo mapa, guardião de volta).
  Contagem de 5 s para voltar à base, ou o botão **PRÓXIMA REGIÃO** abre o mapa na
  região liberada.
- **Som próprio ao acertar o guardião**, diferente do bloco indestrutível.
- **Relíquias**: cada região esconde uma só, numa pequena câmara entre 45% e 85% da
  profundidade. Aparece no sonar como estrela dourada. Na base, escolha: **INSTALAR**
  (bônus permanente) ou **VENDER** (muitos créditos), ou decidir depois no Laboratório
  (Planos › Relíquias). Semente Primordial (Vale, +15% coleta), Âmbar Solar (Dunas, +20%
  tanque), Coração de Ferro (Cordilheira, +25 casco), Pérola do Brejo (Pântano, +10%
  golpes), Lágrima de Magma (Abismo, +40 °C) e Prisma Eterno (Vazio, +10% crítico).
  Quando a região é refeita, aparece outra (dá para vender a repetida).

### Alterado
- "Vender tudo" no Mercado não vende relíquias.

## [0.18.0] — Tutorial, calor, tema do guardião e couro

### Adicionado
- **Tutorial jogável** na primeira vez que o jogo abre: uma expedição guiada no Vale (com
  cobre e carvão logo abaixo) e depois a base. Cada passo tem um texto curto e uma seta
  animada em cima do que tocar, e só avança quando o jogador faz a ação: cavar, coletar
  minério, pegar carvão, usar a Sobrecarga, o sonar, ver o termômetro, extrair, vender no
  Mercado, construir na Bancada e explorar no mapa. Nos menus, o resto da tela fica
  escurecido e bloqueado. **PULAR TUTORIAL** pede confirmação. Quem já tinha salvamento
  não vê o tutorial.
- **Tema do guardião**: música tensa (ostinato frígio, batida de coração, acorde
  dissonante) que entra em crossfade 50 m antes da câmara final, antes de ver o
  guardião, e sai ao subir, vencer ou extrair.
- **Couro**: as criaturas rendem couro (70 créditos), que vende no Mercado e entra nas
  peças orgânicas da Bancada. Amostras biológicas de salvamentos antigos viram couro.

### Alterado
- **Calor por profundidade**: a temperatura sobe da superfície ao fundo de cada região
  (Vale 25→140 °C; Abismo 90→320 °C). A nave aguenta 70 °C, +20 °C por nível de
  **Refrigeração** (agora mais barata). Acima do limite a broca perde até 50% de
  velocidade e o casco sofre dano. HUD em °C, com aviso "QUENTE" perto do limite e
  "SUPERAQUECENDO" acima; o mapa mostra a faixa de cada região.
- **Sobrecarga** gasta o dobro de combustível (antes 1,5×), com "×2" piscando no
  combustível enquanto dura.

## [0.17.3] — Leitura do Android à prova de campos vazios

### Corrigido
- Diagnóstico: os motivos de saída do Android paravam no meio quando um registro vinha
  com campo vazio (ex.: sem descrição). Agora cada campo é lido com segurança e o que já
  foi lido aparece mesmo se um registro falhar.

## [0.17.2] — Modo de compatibilidade em níveis

### Alterado
- O modo de compatibilidade agora tem 3 níveis e sobe sozinho a cada novo fechamento
  até o jogo parar de fechar: 1) mundo e trilha sem threads e névoa simples; 2) + sem
  trilha sonora e sem sons das criaturas; 3) + sem criaturas, plantas que brilham e
  brilho dos minérios. Nas Configurações o botão alterna entre os níveis.
- Diagnóstico: quando não consegue ler os motivos de saída do Android, mostra em que
  passo parou e o fim do log desta sessão (com o erro).

## [0.17.1] — Diagnóstico com o motivo do Android

### Adicionado
- O Diagnóstico mostra os últimos fechamentos registrados pelo próprio Android
  (ApplicationExitInfo, Android 11+): motivo (crash nativo, travamento, pouca memória…),
  sinal, memória usada e, em crash nativo, as bibliotecas/funções da pilha.
- Mostra também se o modo de compatibilidade estava ligado na sessão que fechou e as
  últimas etapas antes do fechamento.

## [0.17.0] — Qualquer tela e mais estabilidade

### Adicionado
- **Área segura em todas as telas**: base, Bancada, Hangar, Mercado, Laboratório, mapa,
  relatório, Configurações, abertura, avisos e HUD respeitam notch/câmera furada, cantos
  arredondados e barra de gestos (`SafeArea`/`SafeMargin`) e se reajustam se a tela
  mudar de tamanho. Em tablets e celulares dobráveis o conteúdo fica centralizado com
  largura máxima, e a câmera aproxima para nunca mostrar além das paredes do mapa.
- **Proteção contra fechamento**: se o jogo fechar sozinho com o app na frente, ao reabrir
  aparece um aviso (com a etapa em que estava) e o **modo de compatibilidade** liga
  sozinho: mundo e trilha gerados sem threads e névoa simples. Dá para ligar/desligar nas
  Configurações › Sistema.
- **Diagnóstico** (Configurações): aparelho, Android, GPU, memória, tela, área segura,
  onde o jogo fechou e o fim do log anterior, com botão **COPIAR** para mandar ao
  desenvolvedor. O log em arquivo agora também fica ligado no celular.

### Corrigido
- Shader do terreno sem arrays com índice variável e névoa sem `break` dependente de
  uniform: construções que travam ou derrubam alguns drivers de GPU de celular (Mali,
  PowerVR, Adreno antigos). O visual não muda.
- Engrenagem das Configurações saía da tela no cabeçalho da base em celulares de 720.

## [0.16.0] — Configurações de áudio e minério que sempre rende

### Adicionado
- **Configurações** (engrenagem na base, ao lado das moedas, e no jogo, abaixo do painel):
  volume da Música, dos Efeitos e da Máquina (broca e motor), de 0 a 100% em passos de
  5%, com som de amostra ao soltar e botão PADRÃO. Salvo à parte do perfil.

### Corrigido
- **Minério que não dropava**: cada célula de minério valia 1/16 de bloco, então raspar
  só a quina fazia o desenho sumir sem render item. Agora, ao quebrar um pedaço, o pedaço
  conectado do veio (até um bloco) rende de uma vez; pedaço de meio bloco ou mais conta
  como bloco inteiro. O resto do veio vira a rocha em volta (continua para cavar).

### Alterado (balanceamento)
- Como o minério agora rende tudo o que se vê (cerca de 2× mais do que antes), os
  upgrades custam mais créditos (×2,5 em vez de ×1,5), as receitas pedem um pouco mais de
  material e o carvão dá 4 de combustível por bloco (antes 6). Na simulação, a câmara
  final do Vale fica em ~13 min.

## [0.15.1] — Porta só no Laboratório e compatibilidade

### Alterado
- A porta de metal agora só aparece ao entrar e sair do Laboratório; as demais telas
  voltaram a entrar deslizando (com o "whoosh"), como na 0.14. Sons da porta mais baixos.

### Corrigido
- APK também para celulares com Android 32 bits (armeabi-v7a), além de 64 bits.
- Abas do Laboratório recriadas na hora (o catálogo não perdia o nome ao reabrir).

## [0.15.0] — Porta de metal, plantas que brilham e volume

### Adicionado
- **Porta de metal** nas trocas de tela (base ↔ estações, mapa, relatório, EXPLORAR): a
  porta de enrolar desce batendo nos trilhos, fecha com um "clank" e um quique, a tela
  troca por trás e ela sobe de novo.
- **Plantas bioluminescentes** nas cavernas do Vale (chão e teto, espaçadas): brilham
  fraquinho e clareiam um pouco a névoa em volta, servindo de guia.

### Alterado
- **Volume**: broca e motor com metade do volume (-6 dB); a trilha toca com 25% do
  volume da broca. A trilha subiu uma oitava, ganhou harmônicos médios e é normalizada
  — antes ela era quase só grave, que o alto-falante do celular não reproduz.

## [0.14.0] — Catálogo, trilha sonora, abertura e polimento

### Adicionado
- **Tela de abertura**: ao abrir o jogo, o nome DEEPFORGE e a nave furando camadas de
  terra com barra de carregamento (1,8 a 4 s, enquanto a trilha é gerada); some com fade.
- **Catálogo no Laboratório**: abas Minerais, Criaturas, Plantas e Diário em grade; o que
  ainda não foi achado aparece como silhueta "???". Tocar num item abre a ficha (descrição,
  valor, broca necessária, regiões, uso na Bancada, quantos já coletou / onde vive,
  comportamento, quantas venceu).
- **Trilha sonora** bem baixinha (pads e sinos gerados no próprio jogo, em loop) e **sons
  das criaturas** (zumbido do vaga-lume, guincho da toupeira, chiado da aranha, ronco da
  minhoca, mordida), mais altos quanto mais perto.
- **Transições**: estações da base, mapa e relatório de expedição deslizam/aparecem com
  animação e um "whoosh"; a placa da estação dá um pulinho ao tocar.

### Alterado
- **Baú coletável**: encostar no baú coleta o bloco inteiro de uma vez (não quebra mais
  aos poucos).
- **Névoa** maior (luz de 6 blocos), mais escura fora da luz e com transição gradual do
  claro para o escuro.
- **Sonar**: a onda, a luz e os sinais somem com fade em vez de apagar de uma vez.
- **Receitas graduais**: cada nível da Bancada pede mais material que o anterior
  (1, 2, 3, 4… no 1º tier).

### Desempenho
- Brilho dos minérios redesenhado a 30 quadros/s e só nos chunks visíveis; criaturas não
  redesenham sem criaturas; visual da nave guardado em cache; névoa com 8 luzes extras.

## [0.13.0] — Névoa, sonar, broca forçada e correções

### Adicionado
- **Névoa**: o subsolo fica escuro; só se vê o que a luz da nave alcança (~4,6 blocos),
  com borda em degraus de pixel art. Vaga-lumes e o guardião também iluminam. Na
  superfície não há névoa (escurece até 12 m).
- **Sonar** (botão verde no canto inferior esquerdo, tecla Q): bip de submarino e uma
  onda que marca minérios, baús (com a cor da raridade) e criaturas em até 22 blocos.
  Sinais pulsam na posição (visíveis na névoa) e, fora da tela, viram setas na borda
  apontando a direção. Minério que a broca ainda não quebra aparece riscado. Recarga 12 s.
- **Broca forçada**: insistir num minério duro demais esquenta a broca ("BROCA
  ESQUENTANDO %"); passando do limite ela superaquece, solta fumaça e fere o casco até
  você parar.

### Alterado
- **Onda de choque** (pulso sísmico) quebra em anéis de dentro para fora (0,45 s), não
  mais de uma vez.
- **Subida**: a broca gira sempre por baixo, e a nave só sobe apoiada (no chão ou cavando
  a rampa) e com a broca já virada para o lado da subida. Inverter a diagonal no ar não
  faz mais a nave voar.

### Corrigido
- Nomes longos cortados nos cartões da Bancada e do Hangar (agora quebram linha).
- Visual da nave no Hangar: requisito em texto legível embaixo de cada opção.
- Ícones dos materiais alinhados nas receitas.
- Aviso de "Nova área" centralizado em qualquer tela.

## [0.12.0] — Broca por nível, rampas, cavernas, baús raros e som

### Adicionado
- **Broca por nível**: a broca inicial quebra cobre, quartzo, carvão e terreno; Broca
  Nv. 2 quebra ferro, prata, cristal e fóssil; Nv. 5 ouro e ametista; Nv. 9 rubi,
  esmeralda, titânio, urânio e obsidiana; Nv. 13 diamante, meteorito, arcano, cristal raro
  e artefato. Minério duro demais faz barulho de metal e mostra "BROCA FRACA PARA …".
- **Subida em rampa**: mirando na diagonal para cima a nave sobe cavando (até ~35°);
  reto para cima continua sem efeito.
- **Baús com raridade**: comum (aura dourada), raro (azul) e lendário (roxa); mais fundo,
  melhores. Abrir rende cristais e materiais e pode trazer uma **planta**: visual exclusivo
  da nave (8 no total: Broca Fóssil/Brasa, Casco de Casca/Dourado, Motor Vaga-lume,
  Pinturas Âmbar/Meia-noite/Cromada). Lendário sempre traz planta. Laboratório mostra
  "Plantas de baú x/8"; o Hangar libera o visual.
- **Explorar nova área** (mapa): troca o mapa da região por um novo, com aviso de que a
  área atual (túneis, minério, baús e recorde) será apagada; objetivos, guardião vencido,
  catálogo e armazém continuam.
- **Sons** sintetizados: broca girando (loop), motor, golpes, bloco quebrando, metal,
  coleta, baú, casco atingido, criatura, Sobrecarga e toque na base.

### Alterado
- **Cavernas**: salões em patamares (pisos planos com degraus) ligados por galerias
  horizontais compridas.
- **Toupeira** pula degraus, escala paredes e desce bordas baixas.
- **Carvão**: 6 de combustível por bloco (era 12) e ~55% menos carvão no mapa.

## [0.11.0] — Criaturas do Vale, visual da nave e baús

### Adicionado
- **Criaturas no Vale das Raízes** (surgem nas cavernas conforme a profundidade):
  - **Vaga-lume** (a partir de 8 m): voa e brilha, foge da nave; entra no catálogo.
  - **Toupeira de raiz** (10 m): anda pelo chão das cavernas e foge; rende 1 amostra.
  - **Aranha de raiz** (60 m): guarda veios brilhantes e ataca quem chega perto (10 de casco).
  - **Minhoca escavadora** (150 m): abre os próprios túneis, persegue e morde (14 de casco).
  - A broca encostada fere; o **pulso sísmico** fere e atordoa; o **drone** também acerta.
  - **Amostras biológicas** (não vendáveis) entram nas receitas do 2º tier de Coleta,
    Bateria e Drone. Aviso "NOVA CRIATURA", seção **Criaturas** no Laboratório e
    entradas novas no diário.
- **Visual da nave**: broca (Aço, Dourada, Cristal, Raiz-Mãe, Plasma), casco (Padrão,
  Blindado, Titânio), motores (Padrão, Turbo, Tanques extras, Reator) e pintura (Amarelo,
  Cobre, Esmeralda, Rubi, Ametista). Liberados por níveis de peça, descobertas e guardiões;
  a nave evolui sozinha e o jogador escolhe no **Hangar** (alerta quando há novidade).
- **Baús novos**: sprite próprio em 3 variações (madeira com cintas douradas, reforçado em
  ferro, antigo coberto de raízes e entreaberto com brilho) e aura de brilho.

## [0.10.0] — Base de pesquisa e construção

### Adicionado
- **Base de pesquisa**: o hub entre expedições é um galpão em pixel art com cinco
  **estações tocáveis**, cada uma com placa e alerta "!" quando há novidade:
  - **Mesa de mapas**: mapa mundial e expedição (também no botão EXPEDIÇÃO);
  - **Bancada**: construir peças com **materiais + Créditos/Cristais** (receita com tem/precisa);
  - **Hangar**: nave, atributos e módulos (equipar/remover);
  - **Mercado**: armazém; vender por recurso, **só o excedente** (o que a Bancada não usa) ou tudo;
  - **Laboratório**: catálogo de minerais descobertos e **diário de pesquisa** (história).
- **Receitas**: cada peça tem uma trilha de materiais em 3 tiers (níveis 1–4, 5–8, 9+);
  um nível só vira projeto quando seus materiais foram descobertos; o 3º tier é um
  **projeto grande**, liberado ao vencer um guardião.
- 20 entradas no diário, liberadas por descobertas e pelo guardião do Vale.

### Alterado
- Economia híbrida: custo em Créditos das peças ×1,5 (era ×3), já que os minérios agora
  também são materiais.
- O mapa mundial abre pela base (botão "< BASE" volta); a garagem virou as estações.

## [0.9.2] — Combate contra o guardião

### Alterado
- **Guardião em modo de combate**: o corpo dele cobre todo o piso da câmara final (topo
  plano); a nave anda por cima e o desgasta enquanto se move.
- **Raízes/espinhos que sobem de baixo**: aviso no ponto de saída (rachadura brilhando,
  coluna vermelha e setas), sobem, ficam e descem; acertar a nave tira muito casco
  (22 no Vale, +8 por dificuldade) com 1 s de invulnerabilidade depois.
- **Três fases** conforme a vida cai: ataques mais rápidos, duplos/triplos, pancadas largas
  e ondas de um lado ao outro com uma brecha para escapar.
- **Câmera de combate**: ao entrar na arena a câmera se afasta (zoom 0,75), fica fixa na
  arena, bordas avermelhadas e aviso "COMBATE!". Volta ao normal ao vencer ou sair.
- Câmara final maior (12 × 21 blocos) com arena plana de 16 blocos.
- Vencido, o corpo se desfaz e o piso abre.

## [0.9.1] — Guardiões e mapas fundos

### Adicionado
- **Guardião na câmara final** de cada região (marco e chefe): um coração preso por raízes
  (Vale, Pântano) ou cercado de cristais (demais regiões). A broca o desgasta por contato;
  a cada 2,4 s ele brilha e solta um pulso que fere o casco de quem estiver perto. Barra de
  vida no HUD, rachaduras e alerta "CASCO ATINGIDO!".
- Vencê-lo conclui a região, libera a próxima, dá 1 Artefato + Cristais e abre o painel
  **REGIÃO CONCLUÍDA** com **VOLTAR À BASE** (extração com toda a carga) ou continuar.
- Nova estrela: vencer o guardião com mais da metade do casco.
- **Câmera de abertura**: a expedição começa mostrando o céu, a base e a torre, com a nave
  abaixo do HUD; a câmera desce quando a nave começa a se mover.

### Alterado
- **Mapas 2,4× mais fundos** (Vale 600 m … Vazio 1000 m), com camadas, minérios e calor
  reescalonados e mais carvão nas camadas fundas. O tanque cheio leva a ~170–250 m: o
  combustível volta a ser o limite de cada expedição.
- Objetivos de pesquisa e de carga um pouco maiores.
- A câmera não mostra abaixo do fundo da região (a câmara final fica enquadrada).

### Removido
- **Elevadores**: toda expedição parte da superfície. Os túneis continuam salvos e cair por
  eles não gasta combustível, então cada expedição chega mais fundo pelo seu poço.

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
