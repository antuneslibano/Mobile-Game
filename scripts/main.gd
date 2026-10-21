extends Node
## Raiz do jogo. Lê argumentos de linha de comando (após "--"):
##   --seed=N            seed fixa do mundo
##   --start-row=N       (debug) começa na linha N
##   --autotest=S        executa o bot de teste por S segundos e encerra
##   --shots=T:path,...  (com --autotest) capturas de tela em T segundos
##   --no-drive          (com --autotest) não pilota; útil só para capturas
##   --no-shop           (com --autotest) não vende nem compra upgrades
##   --open-garage-at=T  (com --autotest) abre a garagem em T segundos

@onready var game: Game = $Game
@onready var hud: Hud = $Hud
var garage: Garage


func _ready() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var world_seed: int = int(args.get("seed", "-1"))
	GameState.new_run(world_seed)
	game.input.hud = hud
	garage = Garage.new()
	garage.name = "Garage"
	add_child(garage)
	hud.garage_requested.connect(garage.open)
	game.start_run(GameState.world_seed, int(args.get("start-row", "-1")))
	if args.has("autotest"):
		var bot := Autopilot.new()
		bot.name = "Autopilot"
		bot.game = game
		bot.duration = float(args["autotest"])
		bot.drive = not args.has("no-drive")
		bot.shop = not args.has("no-shop")
		bot.garage = garage
		bot.open_garage_at = float(args.get("open-garage-at", "-1"))
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
