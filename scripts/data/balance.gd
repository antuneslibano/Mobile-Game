class_name Balance
extends RefCounted
## Constantes ajustáveis de jogo. Ver GAME_DESIGN.md (valores marcados com [T]).
## Mantenha TODO número de balanceamento aqui ou nos registros de dados.

# --- Mundo -------------------------------------------------------------------
## "Bloco" é a unidade de design (1 m, vida, dureza, drops). O terreno real é feito de
## micro-células de CELL_PX, CELL_SUB×CELL_SUB por bloco, para escavação livre.
const BLOCK_PX: int = 48                 ## Tamanho do bloco na tela (1 metro).
const CELL_PX: int = 12                  ## Tamanho da micro-célula.
const CELL_SUB: int = 4                  ## Micro-células por lado de bloco.
const CELLS_PER_BLOCK: int = 16          ## CELL_SUB²: volume de um bloco em células.
const WORLD_WIDTH: int = 24              ## Largura em blocos (bordas são rocha-mãe).
const CHUNK_HEIGHT: int = 16             ## Altura do chunk em blocos.
const WORLD_CELLS_X: int = 96            ## WORLD_WIDTH × CELL_SUB.
const CHUNK_CELLS_Y: int = 64            ## CHUNK_HEIGHT × CELL_SUB.
const WALL_CELLS: int = 3                ## Borda de rocha-mãe garantida (células).
const WARP_CELLS: float = 4.0            ## Deformação orgânica dos materiais (células).
const MAX_DEPTH_ROWS: int = 1000         ## Abaixo disso só há rocha-mãe.
const METERS_PER_BLOCK: float = 1.0
const SAFE_SURFACE_ROWS: int = 6         ## Linhas iniciais sem cavernas.
const SKY_ROWS_VISIBLE: int = 7          ## Quanto do céu a câmera pode mostrar.

# --- Streaming de chunks -----------------------------------------------------
const CHUNKS_PRELOAD_ABOVE: int = 1
const CHUNKS_PRELOAD_BELOW: int = 2
const CHUNK_UNLOAD_HYSTERESIS: int = 2   ## Chunks extras mantidos antes de descarregar.
const GEN_CHUNKS_PER_FRAME: int = 1      ## Orçamento de geração antecipada.

# --- Perfuradora (atributos base, Fase 1) -------------------------------------
const DRILL_BASE_DAMAGE: float = 4.0
const DRILL_BASE_HITS_PER_SEC: float = 5.0
const DRILL_BASE_CRIT_CHANCE: float = 0.05
const DRILL_BASE_CRIT_MULT: float = 2.0
const DRILL_MOVE_SPEED_BLOCKS: float = 4.5
const DRILL_ACCEL_BLOCKS: float = 40.0
const DRILL_RADIUS_PX: float = 22.5      ## Corpo (círculo de colisão; menor que a broca em qualquer ângulo). Nave 1,5× (0.8.1).
const BIT_RADIUS_PX: float = 36.0        ## Área cavada à frente (> corpo: o túnel cabe a máquina).
const BIT_OFFSET_PX: float = 18.0        ## Centro da broca à frente do corpo.
const GRAVITY_BLOCKS: float = 32.0
const MAX_FALL_BLOCKS: float = 14.0
const MIN_DAMAGE_RATIO: float = 0.15

# --- Energia e Sobrecarga -------------------------------------------------------------
## A energia NÃO regenera com o tempo: é conquistada cavando (valor do material).
## A Sobrecarga só ativa com a barra cheia e consome tudo.
const ENERGY_MAX: float = 100.0
const ENERGY_PER_CREDIT: float = 0.3         ## Carga por Crédito de material cavado…
const ENERGY_PER_CRYSTAL: float = 12.0       ## …e por Cristal coletado.
const ENERGY_DEPTH_SCALE_M: float = 150.0    ## Carga ÷ (1 + prof/este) — minérios fundos valem mais.
const ENERGY_GAIN_PER_LEVEL: float = 0.1     ## Upgrade "Bateria": +10% de carga.
const OVERDRIVE_DURATION: float = 6.0
const OVERDRIVE_DURATION_PER_LEVEL: float = 0.5
const OVERDRIVE_DIG_MULT: float = 2.2        ## Golpes/s durante a Sobrecarga.
const OVERDRIVE_DIG_PER_LEVEL: float = 0.15
const OVERDRIVE_MOVE_MULT: float = 1.35
const OVERDRIVE_BIT_MULT: float = 1.3        ## Túnel mais largo durante a Sobrecarga.

# --- Calor (Fase 3) -------------------------------------------------------------------
## Calor (0.18): temperatura por profundidade e limite térmico da nave (HeatRules).
const TEMP_LIMIT_BASE: float = 70.0           ## °C que a nave aguenta sem Refrigeração.
const TEMP_PER_COOLING: float = 20.0          ## +°C de limite por nível de Refrigeração.
const TEMP_WARN_MARGIN: float = 10.0          ## Aviso "perto do limite" a esta distância.
const HEAT_OVER_SPAN_C: float = 40.0          ## °C acima do limite para a perda máxima.
const HEAT_PENALTY_MAX: float = 0.5           ## Perda máxima de golpes/s superaquecendo.
const HEAT_HULL_DPS_PER_C: float = 0.35       ## Dano/s no casco por °C acima do limite.

# --- Módulos (Fase 3) -----------------------------------------------------------------
const MODULE_SLOTS: int = 2
const SIDE_DRILL_RADIUS_PX: float = 7.5      ## Broca lateral: alarga a área cavada…
const SIDE_DRILL_RADIUS_PER_LEVEL: float = 1.8
const DRONE_INTERVAL: float = 1.6
const DRONE_INTERVAL_PER_LEVEL: float = 0.09
const DRONE_DAMAGE_RATIO: float = 0.6        ## Dano do drone (× dano da broca).
const DRONE_DAMAGE_PER_LEVEL: float = 0.12
const DRONE_RANGE_PX: float = 150.0
const DRONE_LASER_RADIUS_PX: float = 11.0
const PULSE_INTERVAL: float = 8.0
const PULSE_INTERVAL_PER_LEVEL: float = 0.4
const PULSE_RADIUS_CELLS: float = 1.6
const PULSE_RADIUS_PER_LEVEL: float = 0.12
const PULSE_DAMAGE_RATIO: float = 1.0
const PULSE_DAMAGE_PER_LEVEL: float = 0.2
## Sinergia Crítico × Pulso: segundos de recarga devolvidos por crítico e multiplicador de chance.
const SYNERGY_CRIT_PULSE_REFUND: float = 0.6
const SYNERGY_PULSE_CRIT_MULT: float = 1.5

# --- Controles ---------------------------------------------------------------
const JOYSTICK_RADIUS_PX: float = 110.0
const JOYSTICK_DEADZONE: float = 0.2

# --- Câmera ------------------------------------------------------------------
const CAMERA_FOLLOW_SPEED: float = 7.0
const CAMERA_LOOK_AHEAD_RATIO: float = 0.16  ## Fração da altura da tela abaixo da máquina.
const CAMERA_SHAKE_DECAY: float = 2.6
const CAMERA_SHAKE_MAX_PX: float = 9.0

# --- Efeitos -----------------------------------------------------------------
const MAX_PARTICLES: int = 260
const HIT_PARTICLES: int = 3
const BREAK_PARTICLES: int = 14
const PICKUP_TEXT_MAX: int = 14

## Multiplica a chance de todos os minérios de veio (especiais raros não mudam). Junto com
## os veios concentrados do gerador, deixa poucos aglomerados por tela.
const ORE_DENSITY: float = 0.35

## Custos em Créditos dos upgrades (×). A nave 1,5× colhe mais de cada veio; os preços
## dos minérios ficam altos (vale desviar) e o custo das melhorias acompanha.
const UPGRADE_CREDIT_COST_MULT: float = 2.5

# --- Expedições (0.9) ---------------------------------------------------------------
const FUEL_BASE: float = 120.0               ## Tanque inicial (≈ segundos de atividade).
const FUEL_USE_PER_SEC: float = 1.0          ## Gasto por segundo movendo ou cavando.
const FUEL_BOOST_MULT: float = 2.0           ## Sobrecarga gasta o dobro (0.18: era 1,5×).
const FUEL_LOW_RATIO: float = 0.25           ## Alerta de combustível baixo…
const FUEL_CRITICAL_RATIO: float = 0.10      ## …e crítico.
const HULL_BASE: float = 100.0
const RESCUE_KEEP_RATIO: float = 0.5         ## Resgate de emergência: fração da carga mantida.
const FINAL_CHAMBER_ROWS: int = 12           ## Altura (blocos) da câmara final no fundo da região.
const FINAL_CHAMBER_HALF_WIDTH: int = 10     ## Meia-largura (blocos) da câmara final.

# --- Guardião da câmara final (arena de combate) ---------------------------------------
## O guardião é um corpo largo que cobre todo o piso da câmara: a nave anda por cima dele
## (topo plano) e o desgasta enquanto se move; raízes/espinhos sobem de baixo, com aviso,
## tentando acertar a nave. Três fases conforme a vida cai (ataques mais rápidos e densos).
const GUARDIAN_BODY_ROWS: float = 2.5        ## Espessura do corpo (blocos) sobre o fundo.
const GUARDIAN_ARENA_HALF_BLOCKS: int = 8    ## Meia-largura da arena plana (blocos).
const GUARDIAN_HP: float = 4000.0            ## Vida no Vale (dificuldade 1)…
const GUARDIAN_HP_PER_DIFFICULTY: float = 0.9  ## …+90% por nível de dificuldade acima de 1.
const GUARDIAN_HIT_DAMAGE: float = 22.0      ## Dano no casco por acerto no Vale…
const GUARDIAN_HIT_DAMAGE_PER_DIFFICULTY: float = 8.0  ## …+8 por nível de dificuldade.
const GUARDIAN_INVULN_SEC: float = 1.0       ## Casco sem novo dano logo após um acerto.
const GUARDIAN_INTERVALS: Array[float] = [1.7, 1.3, 0.95]  ## Entre ataques, por fase.
const GUARDIAN_WARNS: Array[float] = [0.85, 0.75, 0.65]    ## Aviso antes de subir, por fase.
const GUARDIAN_REWARD_CRYSTALS: int = 8      ## Cristais (× dificuldade) + 1 Artefato ao vencê-lo.

# --- Níveis de broca (0.12) -----------------------------------------------------------
## Nível do aprimoramento Broca em que ela passa a quebrar cada classe de minério
## (0: cobre/quartzo/carvão; 1: ferro/prata/cristal/fóssil; 2: ouro/ametista;
## 3: rubi/esmeralda/titânio/urânio/obsidiana; 4: diamante/meteorito/arcano/raro/artefato).
const DRILL_TIER_LEVELS: Array[int] = [0, 2, 5, 9, 13]
## Subida em rampa: componente para cima ≤ esta fração do movimento lateral (~35°).
const CLIMB_SLOPE: float = 0.7

# --- Broca forçada / névoa / sonar (0.13) ----------------------------------------------
## Insistir num minério duro demais esquenta a broca: cada golpe soma STRAIN_PER_HIT; a
## tensão cai STRAIN_DECAY por segundo. Acima de 1,0 o casco sofre STRAIN_HULL_DPS.
const STRAIN_PER_HIT: float = 0.14
const STRAIN_DECAY: float = 0.45
const STRAIN_MAX: float = 1.6
const STRAIN_HULL_DPS: float = 8.0
## Névoa: raio da luz da nave (blocos) e profundidade em que a escuridão fica total.
const LIGHT_RADIUS_BLOCKS: float = 6.0
const BIO_LIGHT_BLOCKS: float = 3.0      ## Luz das plantas bioluminescentes (0.15).
const FOG_FULL_DEPTH_M: float = 12.0
## Sonar: recarga (s), alcance (blocos), velocidade da onda (blocos/s), duração dos sinais.
const SONAR_COOLDOWN: float = 12.0
const SONAR_RANGE_BLOCKS: float = 22.0
const SONAR_SPEED_BLOCKS: float = 26.0
const SONAR_BLIP_SEC: float = 7.0
