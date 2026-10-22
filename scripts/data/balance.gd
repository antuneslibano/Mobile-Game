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
const DRILL_RADIUS_PX: float = 15.0      ## Corpo (círculo de colisão; menor que a broca em qualquer ângulo).
const BIT_RADIUS_PX: float = 24.0        ## Área cavada à frente (> corpo: o túnel cabe a máquina).
const BIT_OFFSET_PX: float = 12.0        ## Centro da broca à frente do corpo.
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
const HEAT_START_M: int = 300
const HEAT_PER_M: float = 0.01               ## +1 de calor a cada 100 m.
const HEAT_MAX: float = 3.0
const HEAT_PENALTY_PER_LEVEL: float = 0.1    ## −10% de golpes/s por nível de calor.
const HEAT_PENALTY_MAX: float = 0.3

# --- Módulos (Fase 3) -----------------------------------------------------------------
const MODULE_SLOTS: int = 2
const SIDE_DRILL_RADIUS_PX: float = 5.0      ## Broca lateral: alarga a área cavada…
const SIDE_DRILL_RADIUS_PER_LEVEL: float = 1.2
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
