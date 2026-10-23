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
##   --grant-ores=N      (debug) N de cada minério comum no armazém
##   --safe-area=T,B,L,R simula notch/cantos/barra de gestos (px do jogo)
##   --settings-at=T     (com --autotest) abre as Configurações em T segundos
##   --splash            (com --autotest) mostra a tela de abertura
##   --creatures         (debug) caverna com uma criatura de cada espécie à frente da nave
##   --sonar-at=T        (com --autotest) usa o sonar em T segundos
##   --base-at=T / --station=KIND  (com --autotest) abre a base em T s e, opcional, a estação
## Em --autotest o salvamento fica desligado (não toca no perfil real).

@onready var game: Game = $Game
@onready var hud: Hud = $Hud
var garage: Garage
var world_map: WorldMap
var base: BaseScreen
var report: ExpeditionReport
var settings: SettingsScreen
var _rescue: bool = false
var _rescue_reason: StringName = &""
var _debug_seed: int = -1


func _ready() -> void:
	var args: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var world_seed: int = int(args.get("seed", "-1"))
	var testing: bool = args.has("autotest")
	SaveService.enabled = SaveService.enabled and not testing
	Guard.step("carregando perfil")
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
	hud.sonar = game.sonar
	hud.layer = 10
	garage = Garage.new()
	garage.name = "Garage"
	add_child(garage)
	world_map = WorldMap.new()
	world_map.name = "WorldMap"
	add_child(world_map)
	world_map.explore_requested.connect(_on_explore)
	base = BaseScreen.new()
	base.name = "BaseScreen"
	add_child(base)
	move_child(base, garage.get_index())
	base.station_requested.connect(_on_station)
	garage.closed.connect(func() -> void: base._refresh())
	world_map.closed.connect(func() -> void: base._refresh())
	settings = SettingsScreen.new()
	settings.name = "Settings"
	add_child(settings)
	base.settings_requested.connect(settings.open)
	hud.settings_requested.connect(settings.open)
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
		if OS.is_debug_build() and args.has("creatures"):
			game.debug_creature_showcase()
		if OS.is_debug_build() and args.has("ask-new-area"):
			get_tree().create_timer(1.5).timeout.connect(func() -> void:
				world_map.open()
				world_map.ask_new_area(world_map.current_region()))
		if args.has("settings-at"):
			get_tree().create_timer(float(args["settings-at"])).timeout.connect(func() -> void:
				settings.open()
				if args.has("diag"):
					settings.show_diagnostics())
		if args.has("sonar-at"):
			get_tree().create_timer(float(args["sonar-at"])).timeout.connect(func() -> void: game.sonar.ping())
		if args.has("base-at"):
			var st := StringName(String(args.get("station", "")))
			get_tree().create_timer(float(args["base-at"])).timeout.connect(func() -> void:
				base.open()
				if st != &"":
					_on_station(st))
		if args.has("extract-at"):
			get_tree().create_timer(float(args["extract-at"])).timeout.connect(extract)
	else:
		game.start_run(GameState.world_seed, -1, GameState.region_mods(GameState.region_id), GameState.done.has(GameState.region_id))
	if OS.is_debug_build() and args.has("grant-ores"):
		var n: float = float(args["grant-ores"])
		GameState.collect_drops(Vector2.ZERO, {&"copper": n, &"iron": n, &"quartz": n, &"silver": n * 0.5, &"gold": n * 0.3, &"fossil": 2.0, &"amethyst": 3.0})
	if OS.is_debug_build() and (args.has("grant-credits") or args.has("grant-crystals")):
		GameState.economy.credits += int(args.get("grant-credits", "0"))
		GameState.economy.crystals += int(args.get("grant-crystals", "0"))
		GameState._emit_economy()
	if not testing and not args.has("no-map"):
		base.open()
	if not testing or args.has("splash"):
		# Tela de abertura (0.14) por cima da base enquanto o jogo termina de carregar.
		var splash := SplashScreen.new()
		splash.name = "Splash"
		add_child(splash)
		if Guard.crashed_last_time:
			splash.finished.connect(_show_crash_notice)
	elif Guard.crashed_last_time:
		_show_crash_notice()
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
	# "Voltar" no Android: fecha a tela de cima (estação ou mapa); na base, encerra.
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if settings != null and settings.is_open():
		settings.close()
	elif garage != null and garage.is_open():
		garage.close_animated()
	elif world_map != null and world_map.is_open():
		world_map.close_animated()
	elif base != null and base.is_open():
		get_tree().quit()


## EXPLORAR no mapa: começa uma expedição na região, sempre a partir da superfície.
func _on_explore(region_id: StringName) -> void:
	if Transitions.shutter_busy():
		return
	_start_expedition(region_id)
	world_map.close()
	base.close()


## start_row > 0 só em testes/depuração (--start-row).
func _start_expedition(region_id: StringName, start_row: int = 0) -> void:
	Guard.step("gerando mundo", String(region_id))
	GameState.start_dive(region_id, _debug_seed)
	game.start_run(GameState.world_seed, start_row, GameState.region_mods(region_id), GameState.done.has(region_id))
	GameState.begin_expedition()
	Guard.step("expedição", String(region_id))
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
	Guard.step("relatório")
	var r: Dictionary = GameState.end_expedition(_rescue, _rescue_reason if _rescue else &"extract", game.world.export_modifications())
	SaveService.save_now()
	report.show_report(r)


func _back_to_base() -> void:
	Guard.step("base")
	base.open()


## Estação tocada na base.
## Só o Laboratório abre pela porta de metal (Transitions.shutter); as outras estações
## entram deslizando.
func _on_station(kind: StringName) -> void:
	Guard.step("estação", String(kind))
	if Transitions.shutter_busy():
		return
	if kind == &"map":
		world_map.open()
	elif kind == &"lab":
		Transitions.shutter(get_tree(), func() -> void: garage.open_station(kind))
	else:
		garage.open_station(kind)


## Aviso depois de um fechamento inesperado: conta o que aconteceu, diz se o modo de
## compatibilidade foi ligado e leva ao diagnóstico.
func _show_crash_notice() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CrashNotice"
	layer.layer = 36
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var safe := SafeMargin.new(20.0, 10.0, 10.0, 640.0)
	root.add_child(safe)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelArt.style(&"frame"))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(UiTheme.label(UiTheme.display_text("O JOGO FECHOU SOZINHO"), 30, UiTheme.ORANGE, 700))
	var msg: String = "Da última vez o jogo fechou de repente (%s). Seu progresso salvo foi mantido." % Guard.last_step
	if Guard.compat and not Guard.compat_manual:
		msg += "\n\nLigamos o modo de compatibilidade, que é mais leve e estável. Dá para desligar nas Configurações."
	msg += "\n\nSe continuar acontecendo, abra o Diagnóstico, toque em COPIAR e mande o texto para o desenvolvedor."
	var l := UiTheme.label(msg, 22, UiTheme.TEXT, 500)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	v.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var diag := Button.new()
	diag.text = UiTheme.display_text("DIAGNÓSTICO")
	diag.custom_minimum_size = Vector2(0, 72)
	diag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_button(diag, &"steel")
	diag.pressed.connect(func() -> void:
		layer.queue_free()
		settings.open()
		settings.show_diagnostics())
	row.add_child(diag)
	var ok := Button.new()
	ok.name = "CrashNoticeOk"
	ok.text = "OK"
	ok.custom_minimum_size = Vector2(0, 72)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_button(ok, &"green")
	ok.pressed.connect(layer.queue_free)
	row.add_child(ok)
	Transitions.pop_in(panel)
