extends Node
## Salvamento automático do perfil (economia, upgrades, módulos, carga e progresso por
## região). Grava: periodicamente quando há mudanças, ao comprar upgrades, ao fechar a
## garagem/mapa, ao começar uma exploração, ao bater recorde de profundidade e ao sair
## ou pausar o app. O terreno de cada exploração não é salvo (cada mergulho é novo).

const PATH: String = "user://deepforge_profile.json"
const DEBOUNCE_SEC: float = 3.0

## Desligado em testes que não devem tocar no perfil real.
var enabled: bool = true
var save_count: int = 0
var _dirty: bool = false
var _timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.wallet_changed.connect(func(_c: int, _k: int) -> void: mark_dirty())
	EventBus.cargo_changed.connect(func(_n: int, _v: int) -> void: mark_dirty())
	EventBus.modules_changed.connect(func(_e: Array[StringName]) -> void: mark_dirty())
	EventBus.upgrade_purchased.connect(func(_id: StringName, _l: int) -> void: save_now())
	EventBus.garage_closed.connect(save_now)
	EventBus.map_closed.connect(save_now)
	EventBus.region_changed.connect(func(_r: StringName) -> void: save_now())
	EventBus.region_progress_changed.connect(func(_r: StringName, _d: int) -> void: mark_dirty())
	EventBus.region_unlocked.connect(func(_r: StringName) -> void: save_now())


## Carrega o perfil salvo em GameState. Retorna false se não havia salvamento válido.
func load_profile() -> bool:
	if not enabled:
		return false
	var d: Dictionary = SaveFile.read(PATH)
	if d.is_empty():
		return false
	GameState.apply_profile(d)
	return true


func mark_dirty() -> void:
	_dirty = true


func save_now() -> bool:
	_dirty = false
	_timer = 0.0
	if not enabled:
		return false
	var ok: bool = SaveFile.write_atomic(PATH, GameState.to_profile())
	if ok:
		save_count += 1
	return ok


func _process(delta: float) -> void:
	if not _dirty:
		return
	_timer += delta
	if _timer >= DEBOUNCE_SEC:
		save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		save_now()
