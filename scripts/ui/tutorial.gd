class_name Tutorial
extends CanvasLayer
## Tutorial jogável (0.18): na primeira vez que o jogo abre, uma expedição guiada no Vale
## e depois a base. Cada passo mostra um texto curto, um indicador animado em cima do que
## tocar e só avança quando o jogador faz a ação (cavar, coletar, Sobrecarga, sonar,
## extrair, vender, construir, explorar). Dá para pular a qualquer momento, com
## confirmação. Ao terminar (ou pular), GameState.tutorial_done libera o jogo normal.

signal finished(skipped: bool)

## Desligado nos testes de cena que não são do tutorial (o jogo abre direto na base).
static var enabled: bool = true

const ORE_BLOCKS: Array[Vector2i] = [Vector2i(0, 7), Vector2i(1, 7), Vector2i(-2, 9)]  ## (dx, linha) do cobre
const COAL_BLOCKS: Array[Vector2i] = [Vector2i(-1, 12), Vector2i(0, 12)]           ## (dx, linha) do carvão

## Passos-chave (índices em _steps): resumo da expedição e chegada na base.
const STEP_REPORT: int = 8
const STEP_BASE: int = 9

var main: Node
var step: int = 0
var _steps: Array[Dictionary] = []
var _root: Control
var _draw: Control
var _bubble: PanelContainer
var _text: Label
var _ok: Button
var _skip: Button
var _blockers: Array[ColorRect] = []
var _confirm: Control
var _t: float = 0.0
var _entered: int = -1
var _base_cargo: int = 0
var _refueled: bool = false
var _credits_before: int = 0


func _ready() -> void:
	layer = 37
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_steps()
	_build_ui()
	_go(0)
	main.get("hud").call("hide_hint")
	var drill: Drill = main.get("game").drill
	drill.refueled.connect(func(_f: float) -> void: _refueled = true)


## Prepara a expedição do tutorial: cobre e carvão logo abaixo de onde a nave começa.
static func plant_resources(world: WorldModel) -> void:
	var sub: int = Balance.CELL_SUB
	var cx: int = Balance.WORLD_WIDTH / 2
	for list: Array in [[ORE_BLOCKS, BlockRegistry.COPPER], [COAL_BLOCKS, BlockRegistry.COAL]]:
		for b: Vector2i in list[0]:
			for oy in sub:
				for ox in sub:
					world.set_cell(Vector2i((cx + b.x) * sub + ox, b.y * sub + oy), int(list[1]))


# --- Passos ----------------------------------------------------------------------------

func _build_steps() -> void:
	var hud: Hud = main.get("hud")
	var game: Game = main.get("game")
	var drill: Drill = game.drill
	_steps = [
		{"text": "Bem-vindo à DEEPFORGE! Você pilota uma nave que cava até o centro da Terra. Vamos aprender jogando.",
			"ok": true, "block": true},
		{"text": "Arraste o dedo em qualquer lugar da tela para guiar a broca. Cave para baixo!",
			"target": func() -> Rect2: return _joystick_rect(hud), "drag": true,
			"done": func() -> bool: return drill.depth_m() >= 5},
		{"text": "Minérios brilham. Passe a broca neles para coletar. Pegue o cobre!",
			"target": func() -> Rect2: return _world_rect(_nearest_planted(game, BlockRegistry.COPPER)),
			"enter": func() -> void: _base_cargo = GameState.economy.cargo_count(),
			"done": func() -> bool: return GameState.economy.cargo_count() > _base_cargo},
		{"text": "Cavar gasta combustível (barra laranja). O carvão, a pedra escura, enche o tanque. Pegue um pouco!",
			"target": func() -> Rect2: return _world_rect(_nearest_planted(game, BlockRegistry.COAL)),
			"extra": func() -> Rect2: return _control_rect(hud, "FuelBar"),
			"enter": func() -> void: _refueled = false,
			"done": func() -> bool: return _refueled},
		{"text": "Coletar enche a ENERGIA. Cheia, toque em SOBRECARGA: cava muito mais rápido, mas gasta o dobro de combustível.",
			"target": func() -> Rect2: return _control_rect(hud, "BoostButton"),
			"enter": func() -> void: drill.energy.add_charge(drill.energy.max_energy * 2.0),
			"done": func() -> bool: return drill.energy.is_boosting()},
		{"text": "Lá embaixo é escuro. Toque no SONAR para mostrar minérios, baús e criaturas por perto.",
			"target": func() -> Rect2: return _control_rect(hud, "SonarButton"),
			"done": func() -> bool: return game.sonar.cooldown > 0.0},
		{"text": "Quanto mais fundo, mais quente. Acima do limite a nave superaquece: melhore a Refrigeração para descer mais.",
			"target": func() -> Rect2: return _control_rect(hud, "HeatValue"), "ok": true},
		{"text": "Hora de voltar! Toque em EXTRAIR: a cápsula leva você e toda a carga para a base.",
			"target": func() -> Rect2: return _control_rect(hud, "ExtractButton"),
			"enter": func() -> void: _set_extract_enabled(true),
			"done": func() -> bool: return bool(main.get("report").call("is_open"))},
		{"text": "Este é o resumo da expedição. Toque em BASE.",
			"target": func() -> Rect2: return _control_rect(main.get("report"), "BaseButton"), "block": true,
			"done": func() -> bool: return bool(main.get("base").call("is_open")) and not bool(main.get("report").call("is_open"))},
		{"text": "Esta é a sua base. Primeiro, toque no MERCADO para vender minérios.",
			"target": func() -> Rect2: return _control_rect(main.get("base"), "Station_market"), "block": true,
			"done": func() -> bool: return _garage_at(&"market")},
		{"text": "Venda o EXCEDENTE: o que a Bancada precisa fica guardado.",
			"target": func() -> Rect2: return _control_rect(main.get("garage"), "SellSurplusButton"), "block": true,
			"enter": func() -> void: _ensure_surplus(),
			"done": func() -> bool: return GameState.economy.credits > _credits_before},
		{"text": "Ótimo! Feche o Mercado.",
			"target": func() -> Rect2: return _control_rect(main.get("garage"), "CloseButton"), "block": true,
			"done": func() -> bool: return not bool(main.get("garage").call("is_open"))},
		{"text": "Agora toque na BANCADA: é onde você constrói melhorias com minérios e créditos.",
			"target": func() -> Rect2: return _control_rect(main.get("base"), "Station_bench"), "block": true,
			"enter": func() -> void: _ensure_affordable(&"damage"),
			"done": func() -> bool: return _garage_at(&"bench")},
		{"text": "Melhore a BROCA: toque na seta. Broca melhor quebra minérios mais duros.",
			"target": func() -> Rect2: return _control_rect(main.get("garage"), "Card_damage", "Buy"), "block": true,
			"done": func() -> bool: return GameState.economy.get_level(&"damage") >= 1},
		{"text": "Feche a Bancada.",
			"target": func() -> Rect2: return _control_rect(main.get("garage"), "CloseButton"), "block": true,
			"done": func() -> bool: return not bool(main.get("garage").call("is_open"))},
		{"text": "Pronto! Toque na MESA DE MAPAS para escolher onde cavar.",
			"target": func() -> Rect2: return _control_rect(main.get("base"), "Station_map"), "block": true,
			"done": func() -> bool: return bool(main.get("world_map").call("is_open"))},
		{"text": "Toque em EXPLORAR e boa escavação! Vença o guardião no fundo de cada região.",
			"target": func() -> Rect2: return _control_rect(main.get("world_map"), "ExploreButton"), "block": true,
			"done": func() -> bool: return not bool(main.get("world_map").call("is_open"))},
	]
	# Durante a parte jogável, EXTRAIR só funciona no passo dele.
	_set_extract_enabled(false)


func _process(delta: float) -> void:
	_t += delta
	if main.get_node_or_null("Splash") != null:
		_root.visible = false
		return
	_root.visible = true
	if step >= _steps.size():
		_finish(false)
		return
	var s: Dictionary = _steps[step]
	if _entered != step:
		_entered = step
		_text.text = String(s.text)
		_ok.visible = bool(s.get("ok", false))
		Transitions.pop_in(_bubble)
	# A expedição pode acabar antes (combustível, casco): pula para o passo certo.
	if step < STEP_REPORT and bool(main.get("report").call("is_open")):
		_go(STEP_REPORT)
		return
	if step < STEP_BASE and bool(main.get("base").call("is_open")) and not bool(main.get("report").call("is_open")):
		_go(STEP_BASE)
		return
	if _confirm == null and s.has("done") and bool((s.done as Callable).call()):
		Sfx.play(&"click", 1.3)
		_go(step + 1)
		return
	_layout(s)
	_draw.queue_redraw()


func advance() -> void:
	_go(step + 1)


## Vai para o passo i e já prepara o que ele precisa (no mesmo quadro: uma ação do
## jogador logo em seguida já conta para o passo novo).
func _go(i: int) -> void:
	step = i
	if step < _steps.size() and _steps[step].has("enter"):
		(_steps[step].enter as Callable).call()


# --- Interface -------------------------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "TutorialRoot"
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	for i in 4:
		var b := ColorRect.new()
		b.color = Color(0, 0, 0, 0.6)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.visible = false
		_root.add_child(b)
		_blockers.append(b)
	_draw = Control.new()
	_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_on_draw)
	_root.add_child(_draw)
	_bubble = PanelContainer.new()
	_bubble.name = "TutorialBubble"
	_bubble.add_theme_stylebox_override("panel", PixelArt.style(&"frame"))
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_bubble)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_bubble.add_child(v)
	_text = UiTheme.label("", 25, UiTheme.TEXT, 600)
	_text.name = "TutorialText"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_text)
	_ok = Button.new()
	_ok.name = "TutorialOk"
	_ok.text = UiTheme.display_text("ENTENDI")
	_ok.custom_minimum_size = Vector2(0, 66)
	_ok.add_theme_font_size_override("font_size", UiTheme.font_size(24, 700))
	UiTheme.style_button(_ok, &"green")
	_ok.pressed.connect(func() -> void:
		Sfx.play(&"click")
		advance())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_ok)
	_skip = Button.new()
	_skip.name = "TutorialSkip"
	_skip.text = UiTheme.display_text("PULAR TUTORIAL")
	_skip.custom_minimum_size = Vector2(0, 56)
	_skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skip.add_theme_font_size_override("font_size", UiTheme.font_size(17, 700))
	UiTheme.style_button(_skip, &"steel")
	_skip.pressed.connect(_ask_skip)
	row.add_child(_skip)


## Bolha de texto do lado oposto ao alvo; bloqueios em volta do alvo nos passos de menu.
func _layout(s: Dictionary) -> void:
	var vp: Vector2 = _root.get_viewport_rect().size
	var safe: Vector4 = SafeArea.insets(get_viewport())
	var target: Rect2 = _target_rect(s)
	var w: float = minf(vp.x - 40.0, 640.0)
	_text.custom_minimum_size = Vector2(w - 48.0, 0)
	_bubble.size = Vector2(w, 0)
	_bubble.reset_size()
	var top_half: bool = target.size.x > 0.0 and target.get_center().y < vp.y * 0.5
	var y: float = vp.y - safe.y - _bubble.size.y - 330.0 if top_half else safe.x + 300.0
	if target.size.x > 0.0 and not top_half and y + _bubble.size.y > target.position.y - 30.0:
		y = maxf(safe.x + 120.0, target.position.y - _bubble.size.y - 60.0)
	_bubble.position = Vector2((vp.x - w) * 0.5, clampf(y, safe.x + 80.0, vp.y - safe.y - _bubble.size.y - 10.0))
	var block: bool = bool(s.get("block", false))
	var hole: Rect2 = target.grow(10.0) if target.size.x > 0.0 else Rect2(vp * 0.5, Vector2.ZERO)
	if bool(s.get("ok", false)) and not s.has("target"):
		hole = Rect2(vp * 0.5, Vector2.ZERO)
	var rects: Array[Rect2] = [
		Rect2(0, 0, vp.x, hole.position.y),
		Rect2(0, hole.end.y, vp.x, vp.y - hole.end.y),
		Rect2(0, hole.position.y, hole.position.x, hole.size.y),
		Rect2(hole.end.x, hole.position.y, vp.x - hole.end.x, hole.size.y),
	]
	for i in 4:
		_blockers[i].visible = block
		_blockers[i].position = rects[i].position
		_blockers[i].size = rects[i].size
	# A bolha (com o botão de pular) fica acima dos bloqueios.
	_root.move_child(_bubble, -1)


func _target_rect(s: Dictionary) -> Rect2:
	if not s.has("target"):
		return Rect2()
	var r: Variant = (s.target as Callable).call()
	return r if r is Rect2 else Rect2()


## Indicador: anel pulsando em volta do alvo e uma seta que balança apontando para ele.
## No passo de cavar, um "dedo" desliza para baixo mostrando o gesto.
func _on_draw() -> void:
	if step >= _steps.size():
		return
	var s: Dictionary = _steps[step]
	var col := Color("ffd23f")
	for key: String in ["target", "extra"]:
		if not s.has(key):
			continue
		var r: Variant = (s[key] as Callable).call()
		if not r is Rect2 or (r as Rect2).size.x <= 0.0:
			continue
		var rect: Rect2 = (r as Rect2).grow(8.0 + 4.0 * sin(_t * 6.0))
		_draw.draw_rect(rect, Color(col.r, col.g, col.b, 0.9), false, 5.0)
		if key == "extra":
			continue
		var c: Vector2 = rect.get_center()
		var vp: Vector2 = _draw.get_viewport_rect().size
		var from_top: bool = c.y > vp.y * 0.35
		var bob: float = 10.0 * sin(_t * 5.0)
		var tip: Vector2 = Vector2(c.x, rect.position.y - 6.0 - bob) if from_top else Vector2(c.x, rect.end.y + 6.0 + bob)
		var dir: float = -1.0 if from_top else 1.0
		var pts := PackedVector2Array([tip, tip + Vector2(-24, 34 * dir), tip + Vector2(-9, 34 * dir), tip + Vector2(-9, 70 * dir),
				tip + Vector2(9, 70 * dir), tip + Vector2(9, 34 * dir), tip + Vector2(24, 34 * dir)])
		_draw.draw_colored_polygon(pts, col)
		_draw.draw_polyline(pts + PackedVector2Array([tip]), Color(0, 0, 0, 0.85), 3.0)
		if bool(s.get("drag", false)):
			var k: float = fposmod(_t * 0.8, 1.0)
			var p: Vector2 = c + Vector2(0, -40 + 160.0 * k)
			_draw.draw_circle(p, 26.0, Color(1, 1, 1, 0.75 * (1.0 - k)))
			_draw.draw_arc(p, 26.0, 0.0, TAU, 32, Color(0, 0, 0, 0.6 * (1.0 - k)), 3.0)


# --- Pular -----------------------------------------------------------------------------

func _ask_skip() -> void:
	if _confirm != null:
		return
	Sfx.play(&"click")
	_confirm = Control.new()
	_confirm.name = "SkipConfirm"
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelArt.style(&"frame"))
	panel.custom_minimum_size = Vector2(minf(620.0, _root.get_viewport_rect().size.x - 40.0), 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(UiTheme.label(UiTheme.display_text("PULAR O TUTORIAL?"), 30, UiTheme.ORANGE, 700))
	var l := UiTheme.label("Tem certeza? O tutorial mostra o essencial em poucos minutos e não aparece de novo.", 23, UiTheme.TEXT, 500)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var keep := Button.new()
	keep.name = "SkipCancel"
	keep.text = UiTheme.display_text("CONTINUAR")
	keep.custom_minimum_size = Vector2(0, 72)
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_button(keep, &"green")
	keep.pressed.connect(func() -> void:
		_confirm.queue_free()
		_confirm = null)
	row.add_child(keep)
	var yes := Button.new()
	yes.name = "SkipConfirmYes"
	yes.text = UiTheme.display_text("SIM, PULAR")
	yes.custom_minimum_size = Vector2(0, 72)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_button(yes, &"red")
	yes.pressed.connect(func() -> void: _finish(true))
	row.add_child(yes)
	Transitions.pop_in(panel)


func _finish(skipped: bool) -> void:
	if not is_inside_tree():
		return
	_set_extract_enabled(true)
	GameState.tutorial_done = true
	SaveService.save_now()
	Guard.step("tutorial", "pulado" if skipped else "concluído")
	if not skipped:
		main.get("hud").call("show_alert", "TUTORIAL CONCLUÍDO!", UiTheme.GREEN)
	finished.emit(skipped)
	queue_free()


# --- Ajudantes -------------------------------------------------------------------------

func _set_extract_enabled(on: bool) -> void:
	var b: Button = main.get("hud").find_child("ExtractButton", true, false)
	if b != null:
		b.disabled = not on


func _garage_at(kind: StringName) -> bool:
	var g: Node = main.get("garage")
	return bool(g.call("is_open")) and StringName(g.call("station")) == kind


## Retângulo (tela) de um controle achado pelo nome, opcionalmente um filho dele.
func _control_rect(parent: Node, node_name: String, child: String = "") -> Rect2:
	if parent == null:
		return Rect2()
	var c: Node = parent.find_child(node_name, true, false)
	if c != null and child != "":
		c = c.find_child(child, true, false)
	if c is Control and (c as Control).is_visible_in_tree():
		return (c as Control).get_global_rect()
	return Rect2()


func _joystick_rect(hud: Hud) -> Rect2:
	var js: Node = hud.find_child("Joystick", true, false)
	var center: Vector2 = js.get("rest_pos") if js != null else _root.get_viewport_rect().size * Vector2(0.5, 0.8)
	var r: float = Balance.JOYSTICK_RADIUS_PX
	return Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0)


## Retângulo de um bloco do mundo na tela (posição mundial → tela pela câmera).
func _world_rect(world_pos: Vector2) -> Rect2:
	if world_pos.x < 0.0:
		return Rect2()
	var xf: Transform2D = get_viewport().get_canvas_transform()
	var b: float = Balance.BLOCK_PX * xf.get_scale().x
	var p: Vector2 = xf * world_pos
	var vp: Vector2 = _root.get_viewport_rect().size
	p = p.clamp(Vector2(b, b + 300.0), vp - Vector2(b, b + 200.0))
	return Rect2(p - Vector2(b, b) * 0.5, Vector2(b, b))


## Centro do bloco plantado (ainda não coletado) mais perto da nave; x < 0 se não há.
func _nearest_planted(game: Game, id: int) -> Vector2:
	var sub: int = Balance.CELL_SUB
	var cx: int = Balance.WORLD_WIDTH / 2
	var best := Vector2(-1, -1)
	var best_d: float = INF
	var list: Array[Vector2i] = ORE_BLOCKS if id == BlockRegistry.COPPER else COAL_BLOCKS
	for b: Vector2i in list:
		var bx: int = cx + b.x
		var c := Vector2i(bx * sub + sub / 2, b.y * sub + sub / 2)
		var found: bool = false
		for oy in sub:
			for ox in sub:
				if game.world.peek_cell(Vector2i(bx * sub + ox, b.y * sub + oy)) == id:
					found = true
		if not found:
			continue
		var p: Vector2 = WorldModel.cell_center(c)
		var d: float = p.distance_to(game.drill.position)
		if d < best_d:
			best_d = d
			best = p
	return best


## Garante algo para vender no passo do Mercado (presente do tutorial).
func _ensure_surplus() -> void:
	_credits_before = GameState.economy.credits
	var reserve: Dictionary = Recipes.reserve(GameState.economy.upgrade_levels)
	var cargo: Dictionary = GameState.economy.cargo
	var any: bool = false
	for k: StringName in cargo:
		if int(cargo[k]) > int(reserve.get(k, 0)):
			any = true
	if not any:
		GameState.collect_drops(Vector2.ZERO, {&"quartz": 3.0})


## Garante materiais e créditos para a primeira melhoria (presente do tutorial).
func _ensure_affordable(id: StringName) -> void:
	var econ: Economy = GameState.economy
	var def: UpgradeDef = UpgradeRegistry.get_def(id)
	var lvl: int = econ.get_level(id)
	var mats: Dictionary = Recipes.materials(def, lvl)
	for k: StringName in mats:
		econ.discovered[k] = true
		econ.cargo[k] = maxi(int(econ.cargo.get(k, 0)), int(mats[k]))
	econ.credits = maxi(econ.credits, Progression.cost(def, lvl))
	GameState._emit_economy()
