extends Node
## Proteção contra o jogo fechar sozinho (0.17). Autoload "Guard", o primeiro a carregar.
##
## - Marca a sessão como "rodando" num arquivo; ao ir para segundo plano ou fechar
##   normalmente, marca como encerrada. Se o jogo abrir e a sessão anterior ainda estava
##   "rodando" com o app na frente, ele fechou sozinho (crash ou o sistema matou).
## - Guarda a última etapa (step) antes do fechamento, para o diagnóstico.
## - Depois de um fechamento, liga o modo de compatibilidade (compat): sem threads na
##   geração do mundo e na trilha, névoa simples e menos efeitos. O jogador pode ligar ou
##   desligar o modo nas Configurações.

const PATH: String = "user://session.json"

## Sessão anterior fechou sozinha.
var crashed_last_time: bool = false
## Etapa em que estava quando fechou ("" se não fechou sozinha).
var last_step: String = ""
## Quantas vezes seguidas fechou sozinha (zera depois de uma sessão normal).
var crash_count: int = 0
## Modo de compatibilidade ligado (automático depois de um fechamento ou pelo jogador).
var compat: bool = false
## O jogador escolheu o modo nas Configurações (não muda sozinho).
var compat_manual: bool = false
## Desligado nos testes (não grava nada).
var enabled: bool = true
var step_name: String = "iniciando"

var _state: Dictionary = {}
var _foreground: bool = true
var _write_t: float = 0.0
var _extra: String = ""


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
	if OS.is_debug_build() and OS.get_cmdline_user_args().has("--compat"):
		compat = true
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
		crash_count += 1
	if compat_manual:
		compat = bool(_state.get("compat", false))
	else:
		compat = crashed_last_time or bool(_state.get("compat", false))


## Registra a etapa atual (grava na hora: é o que sobra se o app fechar).
func step(name: String, extra: String = "") -> void:
	step_name = name
	_extra = extra
	_write(true)


## Detalhe que muda com frequência (profundidade etc.): gravado no máximo a cada 5 s.
func detail(extra: String) -> void:
	_extra = extra


func set_compat(on: bool) -> void:
	compat = on
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
	var d: Dictionary = {
		"running": running,
		"step": step_name + ((" · " + _extra) if _extra != "" else ""),
		"crash_count": crash_count,
		"compat": compat,
		"compat_manual": compat_manual,
		"version": String(ProjectSettings.get_setting("application/config/version", "")),
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))
		f.close()
