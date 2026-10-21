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
## Em --autotest o salvamento fica desligado (não toca no perfil real).

@onready var game: Game = $Game
@onready var hud: Hud = $Hud
var garage: Garage
var world_map: WorldMap


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
			GameState.region_progress[r.id] = maxi(GameState.region_depth(r.id), 300)
	var region_arg := StringName(String(args.get("region", "")))
	if region_arg != &"" and RegionRegistry.get_def(region_arg).id == region_arg:
		GameState.region_id = region_arg
	GameState.start_dive(GameState.region_id, world_seed)
	game.input.hud = hud
	hud.drill = game.drill
	garage = Garage.new()
	garage.name = "Garage"
	add_child(garage)
	hud.garage_requested.connect(garage.open)
	world_map = WorldMap.new()
	world_map.name = "WorldMap"
	add_child(world_map)
	world_map.explore_requested.connect(_on_explore)
	hud.map_requested.connect(world_map.open)
	game.start_run(GameState.world_seed, int(args.get("start-row", "-1")))
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
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and (garage == null or not garage.is_open()):
		get_tree().quit()


## EXPLORAR no mapa: continua a exploração atual ou começa uma nova na região escolhida.
func _on_explore(region_id: StringName) -> void:
	if region_id != GameState.region_id or not GameState.dive_active:
		GameState.start_dive(region_id)
		game.start_run(GameState.world_seed)
	world_map.close()
