extends Node
## Raiz do jogo. Lê argumentos de linha de comando (após "--"):
##   --seed=N            seed fixa do mundo
##   --start-row=N       (debug) começa na linha N
##   --autotest=S        executa o bot de teste por S segundos e encerra
##   --shots=T:path,...  (com --autotest) capturas de tela em T segundos
##   --no-drive          (com --autotest) não pilota; útil só para capturas
##   --no-shop           (com --autotest) não vende nem compra upgrades
##   --open-garage-at=T  (com --autotest) abre a garagem em T segundos
##   --grant-credits=N / --grant-crystals=N  (apenas builds de depuração) moedas iniciais
##   --region=ID         explora a região (vale, dunas, cordilheira, pantano, abismo, vazio)
##   --no-map            não abre o mapa mundial ao iniciar
##   --map-at=T / --map-page=N  (com --autotest) abre o mapa em T s, na página N
##   --unlock-all        (debug) libera todas as regiões
##   --fuel=F            (debug) combustível inicial (fração do tanque)
##   --extract-at=T      (com --autotest) chama a extração em T segundos
##   --guardian-hp=F     (debug) vida inicial do guardião da câmara final (fração)
## Em --autotest o salvamento fica desligado (não toca no perfil real).

@onready var game: Game = $Game
@onready var hud: Hud = $Hud
var garage: Garage
var world_map: WorldMap
var report: ExpeditionReport
var _rescue: bool = false
var _rescue_reason: StringName = &""
var _debug_seed: int = -1


func _ready() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var world_seed: int = int(args.get("seed", "-1"))
	var testing: bool = args.has("autotest")
	SaveService.enabled = SaveService.enabled and not testing
	if not SaveService.load_profile():
		GameState.reset_profile()
	if OS.is_debug_build() and args.has("unlock-all"):
		SaveService.enabled = false  # progresso artificial nunca vai para o perfil do jogador
		for r in RegionRegistry.all():
			GameState.unlocked[r.id] = true
	var region_arg := StringName(String(args.get("region", "")))
	if region_arg != &"" and RegionRegistry.get_def(region_arg).id == region_arg:
		GameState.region_id = region_arg
	GameState.start_dive(GameState.region_id, world_seed)
	game.input.hud = hud
	hud.drill = game.drill
	hud.guardian = game.guardian
	garage = Garage.new()
	garage.name = "Garage"
	add_child(garage)
	world_map = WorldMap.new()
	world_map.name = "WorldMap"
	add_child(world_map)
	world_map.explore_requested.connect(_on_explore)
	world_map.garage_requested.connect(garage.open)
	report = ExpeditionReport.new()
	report.name = "ExpeditionReport"
	add_child(report)
	report.closed.connect(_back_to_base)
	hud.extract_requested.connect(extract)
	game.drill.stranded.connect(_on_stranded)
	game.extraction_finished.connect(_on_extraction_finished)
	game.guardian_defeated.connect(_on_guardian_defeated)
	_debug_seed = world_seed
	var start_row: int = int(args.get("start-row", "-1"))
	if testing or args.has("no-map"):
		# Testes: começa direto numa expedição (sem passar pela base).
		_start_expedition(GameState.region_id, maxi(0, start_row))
		if OS.is_debug_build() and args.has("fuel"):
			game.drill.vitals.fuel = game.drill.vitals.fuel_max * clampf(float(args["fuel"]), 0.0, 1.0)
		if OS.is_debug_build() and args.has("guardian-hp"):
			game.guardian.hp = game.guardian.max_hp * clampf(float(args["guardian-hp"]), 0.01, 1.0)
		if args.has("extract-at"):
			get_tree().create_timer(float(args["extract-at"])).timeout.connect(extract)
	else:
		game.start_run(GameState.world_seed, -1, GameState.region_mods(GameState.region_id), GameState.done.has(GameState.region_id))
	if OS.is_debug_build() and (args.has("grant-credits") or args.has("grant-crystals")):
		GameState.economy.credits += int(args.get("grant-credits", "0"))
		GameState.economy.crystals += int(args.get("grant-crystals", "0"))
		GameState.sell_cargo()
	if not testing and not args.has("no-map"):
		world_map.open()
	if testing:
		var bot := Autopilot.new()
		bot.name = "Autopilot"
		bot.game = game
		bot.duration = float(args["autotest"])
		bot.drive = not args.has("no-drive")
		bot.shop = not args.has("no-shop")
		bot.garage = garage
		bot.open_garage_at = float(args.get("open-garage-at", "-1"))
		bot.garage_tab_modules = args.get("garage-tab", "") == "modules"
		bot.world_map = world_map
		bot.open_map_at = float(args.get("map-at", "-1"))
		bot.map_page = int(args.get("map-page", "-1"))
		for part: String in String(args.get("shots", "")).split(",", false):
			var sep: int = part.find(":")
			if sep > 0:
				bot.shots.append([part.substr(0, sep).to_float(), part.substr(sep + 1)])
		add_child(bot)


static func _parse_args(raw: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for a in raw:
		if not a.begins_with("--"):
			continue
		var body: String = a.substr(2)
		var eq: int = body.find("=")
		if eq >= 0:
			out[body.substr(0, eq)] = body.substr(eq + 1)
		else:
			out[body] = "1"
	return out


func _notification(what: int) -> void:
	# "Voltar" no Android: fecha a garagem se aberta (tratado nela); senão encerra.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and (garage == null or not garage.is_open()) \
			and (world_map == null or world_map.is_open()):
		get_tree().quit()


## EXPLORAR no mapa: começa uma expedição na região, sempre a partir da superfície.
func _on_explore(region_id: StringName) -> void:
	_start_expedition(region_id)
	world_map.close()


## start_row > 0 só em testes/depuração (--start-row).
func _start_expedition(region_id: StringName, start_row: int = 0) -> void:
	GameState.start_dive(region_id, _debug_seed)
	game.start_run(GameState.world_seed, start_row, GameState.region_mods(region_id), GameState.done.has(region_id))
	GameState.begin_expedition()
	_rescue = false
	SaveService.mark_dirty()


## EXTRAIR (HUD): a cápsula leva a nave e toda a carga.
func extract() -> void:
	if not GameState.expedition_active or game.extracting:
		return
	_rescue = false
	game.play_extraction()


## Combustível ou casco zerou: resgate de emergência (metade da carga desta expedição).
func _on_stranded(reason: StringName) -> void:
	if not GameState.expedition_active or game.extracting:
		return
	_rescue = true
	_rescue_reason = reason
	hud.show_alert("RESGATE DE EMERGÊNCIA", UiTheme.RED)
	get_tree().create_timer(1.2).timeout.connect(func() -> void: game.play_extraction())


## Guardião vencido: conclui a região, libera a próxima e oferece a volta à base.
func _on_guardian_defeated(hull_ratio: float) -> void:
	var before: Dictionary = GameState.unlocked.duplicate()
	GameState.complete_region(hull_ratio)
	var unlocked_name: String = ""
	for r in RegionRegistry.all():
		if GameState.unlocked.has(r.id) and not before.has(r.id):
			unlocked_name = r.display_name
	SaveService.mark_dirty()
	hud.show_region_complete(GameState.region(), unlocked_name)


func _on_extraction_finished() -> void:
	var r: Dictionary = GameState.end_expedition(_rescue, _rescue_reason if _rescue else &"extract", game.world.export_modifications())
	SaveService.save_now()
	report.show_report(r)


func _back_to_base() -> void:
	world_map.open()
