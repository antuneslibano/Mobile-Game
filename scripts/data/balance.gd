class_name Balance
extends RefCounted
## Constantes ajustáveis de jogo. Ver GAME_DESIGN.md (valores marcados com [T]).
## Mantenha TODO número de balanceamento aqui ou nos registros de dados.

# --- Mundo -------------------------------------------------------------------
const BLOCK_PX: int = 48                 ## Tamanho do bloco na tela.
const ART_PX: int = 16                   ## Resolução da pixel art por bloco.
const WORLD_WIDTH: int = 24              ## Colunas (0 e WIDTH-1 são paredes).
const CHUNK_HEIGHT: int = 16             ## Linhas por chunk.
const MAX_DEPTH_ROWS: int = 1000         ## Abaixo disso só há rocha-mãe.
const METERS_PER_BLOCK: float = 1.0
const SAFE_SURFACE_ROWS: int = 6         ## Linhas iniciais sem cavernas.
const SKY_ROWS_VISIBLE: int = 7          ## Quanto do céu a câmera pode mostrar.

# --- Streaming de chunks -----------------------------------------------------
const CHUNKS_PRELOAD_ABOVE: int = 1
const CHUNKS_PRELOAD_BELOW: int = 2
const CHUNK_UNLOAD_HYSTERESIS: int = 2   ## Chunks extras mantidos antes de descarregar.
const GEN_CHUNKS_PER_FRAME: int = 1      ## Orçamento de geração antecipada.
const MAX_DAMAGED_CELLS: int = 64

# --- Perfuradora (atributos base, Fase 1) -------------------------------------
const DRILL_BASE_DAMAGE: float = 4.0
const DRILL_BASE_HITS_PER_SEC: float = 6.0
const DRILL_BASE_CRIT_CHANCE: float = 0.05
const DRILL_BASE_CRIT_MULT: float = 2.0
const DRILL_MOVE_SPEED_BLOCKS: float = 4.5
const DRILL_ACCEL_BLOCKS: float = 40.0
const DRILL_SIZE_BLOCKS: Vector2 = Vector2(0.78, 0.84)
const GRAVITY_BLOCKS: float = 32.0
const MAX_FALL_BLOCKS: float = 14.0
const HOP_HEIGHT_BLOCKS: float = 1.2
const ALIGN_GAIN: float = 14.0           ## Ganho do auto-alinhamento à coluna.
const ALIGN_TOLERANCE_BLOCKS: float = 0.18
const SIDE_DRILL_MULT: float = 0.6
const MIN_DAMAGE_RATIO: float = 0.15

# --- Controles ---------------------------------------------------------------
const STEER_DEADZONE_PX: float = 40.0

# --- Câmera ------------------------------------------------------------------
const CAMERA_FOLLOW_SPEED: float = 7.0
const CAMERA_LOOK_AHEAD_RATIO: float = 0.16  ## Fração da altura da tela abaixo da máquina.
const CAMERA_SHAKE_DECAY: float = 2.6
const CAMERA_SHAKE_MAX_PX: float = 9.0

# --- Efeitos -----------------------------------------------------------------
const MAX_PARTICLES: int = 260
const HIT_PARTICLES: int = 3
const BREAK_PARTICLES: int = 14
