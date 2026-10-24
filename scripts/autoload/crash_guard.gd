extends Node
## Proteção contra o jogo fechar sozinho (0.17). Autoload "Guard", o primeiro a carregar.
##
## - Marca a sessão como "rodando" num arquivo; ao ir para segundo plano ou fechar
##   normalmente, marca como encerrada. Se o jogo abrir e a sessão anterior ainda estava
##   "rodando" com o app na frente, ele fechou sozinho (crash ou o sistema matou).
## - Guarda a última etapa (step) antes do fechamento, para o diagnóstico.
## - Depois de um fechamento, liga o modo de compatibilidade, que sobe um nível a cada
##   novo fechamento (0.17.2) até o jogo parar de fechar; o nível em que parou aponta a
##   causa. O jogador também pode escolher o nível nas Configurações.
##     1: mundo sem threads, névoa simples;
##     2: + sem o efeito de calor na tela;
##     3: + metade das criaturas, brilhos mais leves (sem partículas nem luz na névoa).
##   Desde a 0.21 nenhum nível tira a música, os sons, as criaturas ou os brilhos: os sons
##   vêm prontos do banco (SoundBank), sem síntese nem threads no aparelho.

const PATH: String = "user://session.json"

## Sessão anterior fechou sozinha.
var crashed_last_time: bool = false
## Etapa em que estava quando fechou ("" se não fechou sozinha).
var last_step: String = ""
## Nível do modo de compatibilidade na sessão que fechou sozinha.
var last_level: int = 0
const MAX_LEVEL: int = 3
## Últimas etapas da sessão que fechou (mais antiga primeiro).
var last_history: PackedStringArray = []
var _history: PackedStringArray = []
## Quantas vezes seguidas fechou sozinha (zera depois de uma sessão normal).
var crash_count: int = 0
## Nível do modo de compatibilidade (0 = desligado).
var compat_level: int = 0
## Modo de compatibilidade ligado (qualquer nível).
var compat: bool:
	get:
		return compat_level >= 1
## O jogador escolheu o modo nas Configurações (não muda sozinho).
var compat_manual: bool = false
## Desligado nos testes (não grava nada).
var enabled: bool = true
var step_name: String = "iniciando"

var _state: Dictionary = {}
var _foreground: bool = true
var _write_t: float = 0.0
var _extra: String = ""
## Marcos já registrados nesta sessão (mark): só a primeira vez de cada um.
var _marks: Dictionary = {}
## Memória nativa do processo (MB) na última gravação; -1 = desconhecida.
var mem_mb: int = -1
## Memória na sessão que fechou sozinha (última gravação antes de fechar).
var last_mem_mb: int = -1
var _debug_class: Object = null
const HISTORY: int = 14


func _init() -> void:
	# Lê antes de qualquer outro autoload (Sfx consulta o modo ao iniciar).
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--autotest") or a == "--no-guard":
			enabled = false
	var force: bool = args.has("--guard")  # testes do próprio Guard (com --autotest)
	for a in OS.get_cmdline_args():
		if a == "-s" or a == "--script" or a.begins_with("res://tests/"):
			enabled = false
	if force:
		enabled = true
	# Simulação de notch/cantos (--safe-area=T,B,L,R) lida antes de qualquer tela montar.
	if OS.is_debug_build():
		for a in args:
			if a.begins_with("--safe-area="):
				SafeArea.parse_debug(a.trim_prefix("--safe-area="))
	_load()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.is_debug_build():
		for a in OS.get_cmdline_user_args():
			if a == "--compat":
				compat_level = maxi(compat_level, 1)
			elif a.begins_with("--compat="):
				compat_level = clampi(int(a.trim_prefix("--compat=")), 0, MAX_LEVEL)
	step("iniciando")


func _load() -> void:
	if not enabled or not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		return
	_state = parsed
	compat_manual = bool(_state.get("compat_manual", false))
	crash_count = int(_state.get("crash_count", 0))
	if bool(_state.get("running", false)):
		crashed_last_time = true
		last_step = String(_state.get("step", "?"))
		last_level = _saved_level()
		var h: Variant = _state.get("history", [])
		if h is Array:
			for e: Variant in h:
				last_history.append(str(e))
		crash_count += 1
	last_mem_mb = int(_state.get("mem_mb", -1)) if crashed_last_time else -1
	compat_level = _saved_level()
	# Escolha manual que segue fechando (0.19.2): depois de 2 fechamentos seguidos o
	# modo volta a subir sozinho.
	if crashed_last_time and compat_manual and crash_count >= 2 and compat_level < MAX_LEVEL:
		compat_manual = false
	if crashed_last_time and not compat_manual:
		compat_level = mini(MAX_LEVEL, compat_level + 1)


## Nível gravado (arquivos da 0.17.0/0.17.1 só tinham "compat": true/false).
func _saved_level() -> int:
	if _state.has("level"):
		return clampi(int(_state["level"]), 0, MAX_LEVEL)
	return 1 if bool(_state.get("compat", false)) else 0


## Registra a etapa atual (grava na hora: é o que sobra se o app fechar).
func step(name: String, extra: String = "") -> void:
	step_name = name
	_extra = extra
	_history.append("%ds %s%s" % [Time.get_ticks_msec() / 1000, name, (" · " + extra) if extra != "" else ""])
	if _history.size() > HISTORY:
		_history = _history.slice(_history.size() - HISTORY)
	_write(true)


## Marco de diagnóstico (0.19.2): a primeira vez de algo nesta sessão (primeira aranha,
## primeiro som de um tipo, efeito ligado...). Entra no histórico e grava na hora, sem
## mudar a etapa atual.
func mark(key: String) -> void:
	if _marks.has(key) or not enabled:
		return
	_marks[key] = true
	_history.append("%ds %s ·%s" % [Time.get_ticks_msec() / 1000, key, (" " + _extra) if _extra != "" else ""])
	if _history.size() > HISTORY:
		_history = _history.slice(_history.size() - HISTORY)
	_write(true)


## Detalhe que muda com frequência (profundidade etc.): gravado no máximo a cada 5 s.
func detail(extra: String) -> void:
	_extra = extra


## Escolha do jogador (vale ao reabrir o jogo; não sobe mais sozinho).
func set_level(level: int) -> void:
	compat_level = clampi(level, 0, MAX_LEVEL)
	compat_manual = true
	_write(true)


func _process(delta: float) -> void:
	_write_t += delta
	if _write_t >= 5.0:
		_write_t = 0.0
		_write(_foreground)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			# Em segundo plano o sistema pode encerrar o app: isso não é um fechamento.
			_foreground = false
			_write(false)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_foreground = true
			_write(true)
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_PREDELETE:
			_write(false)


## Grava o estado da sessão. Depois de 3 min sem problemas a contagem de fechamentos
## zera; o modo de compatibilidade, se ligou sozinho, continua até o jogador escolher.
func _write(running: bool) -> void:
	if not enabled:
		return
	if Time.get_ticks_msec() > 180000:
		crash_count = 0
	mem_mb = _native_mem_mb()
	var d: Dictionary = {
		"mem_mb": mem_mb,
		"running": running,
		"step": step_name + ((" · " + _extra) if _extra != "" else ""),
		"crash_count": crash_count,
		"history": Array(_history),
		"compat": compat,
		"level": compat_level,
		"compat_manual": compat_manual,
		"version": String(ProjectSettings.get_setting("application/config/version", "")),
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))
		f.close()


## Memória nativa alocada pelo processo (Android: android.os.Debug, barato). -1 fora do
## Android ou se a leitura falhar.
func _native_mem_mb() -> int:
	if OS.get_name() != "Android":
		var m: int = OS.get_static_memory_usage()
		return m / 1048576 if m > 0 else -1
	if _debug_class == null:
		_debug_class = JavaClassWrapper.wrap("android.os.Debug")
	if _debug_class == null:
		return -1
	var v: Variant = _debug_class.call("getNativeHeapAllocatedSize")
	return int(v) / 1048576 if (v is int or v is float) else -1

