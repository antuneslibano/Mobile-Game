class_name CreatureManager
extends Node2D
## Criaturas do subsolo (0.11): surgem por chunk quando ele carrega (posições
## determinísticas pela seed), somem quando o chunk descarrega. Cada passo move as
## criaturas perto da nave, aplica mordidas no casco, o dano da broca/drone/pulso nelas e
## avisa avistamentos (catálogo) e mortes (amostras biológicas). Desenho em pixel art de
## 3 px a partir de sprites gerados uma vez.

signal creature_seen(species: StringName)
signal creature_defeated(species: StringName, at: Vector2)
signal ship_bitten(damage: float, species: StringName)

const ART: float = 3.0
const ACTIVE_BLOCKS: float = 26.0     ## Só simula criaturas até esta distância da nave.
const SEE_BLOCKS: float = 5.0         ## Distância de avistamento (catálogo).
## Regiões com criaturas (por enquanto só o Vale) e profundidade mínima de cada espécie.
const SPAWNS: Dictionary = {
	&"vale": {&"firefly": 8, &"mole": 10, &"spider": 60, &"worm": 150},
}

var world: WorldModel
var region: RegionDef
var creatures: Array[Creature] = []
var _seed: int = 0
var _t: float = 0.0
static var _sprites: Dictionary = {}


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(w: WorldModel, r: RegionDef, p_seed: int) -> void:
	creatures.clear()
	world = w
	region = r
	_seed = p_seed
	if not SPAWNS.has(r.id):
		return
	w.chunk_loaded.connect(_on_chunk_loaded)
	w.chunk_unloaded.connect(_on_chunk_unloaded)


func _on_chunk_loaded(index: int) -> void:
	for e: Dictionary in plan(world, index, region, _seed):
		creatures.append(Creature.new(e.species, e.pos, hash([_seed, index, e.species])))


func _on_chunk_unloaded(index: int) -> void:
	var keep: Array[Creature] = []
	for c in creatures:
		if WorldModel.chunk_index_for_row(floori(c.pos.y / Balance.CELL_PX)) != index:
			keep.append(c)
	creatures = keep


## Onde nascem as criaturas de um chunk (puro e determinístico; o chunk precisa estar
## carregado). [{species, pos}]
static func plan(w: WorldModel, index: int, r: RegionDef, p_seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var table: Dictionary = SPAWNS.get(r.id, {})
	if table.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([p_seed, index, "criaturas"])
	var counts: Dictionary = {&"firefly": 0, &"mole": 0, &"spider": 0, &"worm": 0}
	var limits: Dictionary = {&"firefly": 2, &"mole": 1 if rng.randf() < 0.85 else 0,
			&"spider": 1 if rng.randf() < 0.75 else 0, &"worm": 1 if rng.randf() < 0.4 else 0}
	var y0: int = index * Balance.CHUNK_CELLS_Y
	var stop_row: int = (RegionRegistry.chamber_top(r) - 3) * Balance.CELL_SUB
	var air := func(c: Vector2i) -> bool: return w.peek_cell(c) == BlockRegistry.AIR
	for attempt in 220:
		var c := Vector2i(rng.randi_range(6, Balance.WORLD_CELLS_X - 7), y0 + rng.randi_range(2, Balance.CHUNK_CELLS_Y - 3))
		if c.y >= stop_row:
			continue
		var depth_m: int = c.y / Balance.CELL_SUB
		var id: int = w.peek_cell(c)
		var center: Vector2 = WorldModel.cell_center(c)
		if id == BlockRegistry.AIR:
			# Vaga-lume: caverna aberta.
			if counts[&"firefly"] < limits[&"firefly"] and depth_m >= int(table[&"firefly"]) \
					and air.call(c + Vector2i(0, -3)) and air.call(c + Vector2i(3, 0)) and air.call(c + Vector2i(-3, 0)):
				out.append({"species": &"firefly", "pos": center})
				counts[&"firefly"] += 1
				continue
			# Toupeira: chão de caverna (sólido embaixo, espaço em cima).
			if counts[&"mole"] < limits[&"mole"] and depth_m >= int(table[&"mole"]) and not air.call(c + Vector2i(0, 1)) \
					and air.call(c + Vector2i(0, -1)) and air.call(c + Vector2i(0, -2)) and air.call(c + Vector2i(0, -3)):
				out.append({"species": &"mole", "pos": center + Vector2(0, -8)})
				counts[&"mole"] += 1
			continue
		var def: BlockDef = BlockRegistry.get_def(id)
		# Aranha: ao lado de um veio brilhante, num espaço aberto.
		if counts[&"spider"] < limits[&"spider"] and depth_m >= int(table[&"spider"]) and TerrainSkins.glow_tier(def) > 0:
			for d: Vector2i in [Vector2i(0, -3), Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3)]:
				if air.call(c + d) and air.call(c + d + d / 3):
					out.append({"species": &"spider", "pos": WorldModel.cell_center(c + d)})
					counts[&"spider"] += 1
					break
			continue
		# Minhoca: dentro do terreno, fundo.
		if counts[&"worm"] < limits[&"worm"] and depth_m >= int(table[&"worm"]) and def.is_terrain() and id != BlockRegistry.BEDROCK:
			out.append({"species": &"worm", "pos": center})
			counts[&"worm"] += 1
	return out


## Um passo de simulação. intent_steering: a nave está pilotando (broca ativa).
func step(delta: float, drill: Drill, steering: bool) -> void:
	_t += delta
	if creatures.is_empty() or drill == null:
		return
	var ship: Vector2 = drill.position
	var b: float = Balance.BLOCK_PX
	var bit: Vector2 = drill.bit_center()
	var bit_r: float = drill.bit_radius()
	var s: DrillStats = drill.stats
	var dps: float = s.damage * s.hits_per_second * drill.speed_mult
	var dead: Array[Creature] = []
	for c in creatures:
		if c.pos.distance_to(ship) > ACTIVE_BLOCKS * b:
			continue
		if not c.alive:
			dead.append(c)
			continue
		var bite: float = c.step(delta, world, ship, drill.radius) if not drill.disabled else 0.0
		if bite > 0.0:
			ship_bitten.emit(bite, c.species)
			Sfx.play(&"bite", randf_range(0.9, 1.1))
		_maybe_sound(c, delta, c.pos.distance_to(ship) / b)
		if c.pos.distance_to(ship) < SEE_BLOCKS * b:
			creature_seen.emit(c.species)
		if steering:
			for p in c.body_points():
				if p.distance_to(bit) < bit_r + c.radius:
					if c.take_damage(dps * delta):
						dead.append(c)
					break
	for c in dead:
		_kill(c)


## Sons das criaturas perto da nave (mais alto quanto mais perto), de tempos em tempos.
func _maybe_sound(c: Creature, delta: float, dist_blocks: float) -> void:
	c.sound_cd -= delta
	if c.sound_cd > 0.0 or dist_blocks > 8.0:
		return
	var vol: float = -4.0 - dist_blocks * 2.2
	match c.species:
		&"firefly":
			c.sound_cd = randf_range(2.5, 5.0)
			Sfx.play(&"firefly", randf_range(0.9, 1.2), vol - 6.0)
		&"mole":
			c.sound_cd = randf_range(1.5, 3.5)
			Sfx.play(&"mole", randf_range(0.9, 1.15), vol)
		&"spider":
			c.sound_cd = randf_range(2.0, 3.5)
			Sfx.play(&"spider", randf_range(0.85, 1.1), vol)
		&"worm":
			c.sound_cd = randf_range(1.6, 3.0)
			Sfx.play(&"worm", randf_range(0.8, 1.05), vol + 2.0)


## Dano em área (pulso sísmico: também atordoa) e tiro do drone.
func area_damage(center: Vector2, r: float, amount: float, stun: float = 0.0) -> void:
	var dead: Array[Creature] = []
	for c in creatures:
		for p in c.body_points():
			if p.distance_to(center) < r + c.radius:
				c.stun = maxf(c.stun, stun)
				if c.take_damage(amount):
					dead.append(c)
				break
	for c in dead:
		_kill(c)


func _kill(c: Creature) -> void:
	if not creatures.has(c):
		return
	creatures.erase(c)
	c.alive = false
	creature_defeated.emit(c.species, c.pos)


func alive_count(species: StringName = &"") -> int:
	var n: int = 0
	for c in creatures:
		if species == &"" or c.species == species:
			n += 1
	return n


# --- Desenho ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not creatures.is_empty() or get_meta("drawn", false):
		set_meta("drawn", not creatures.is_empty())
		queue_redraw()


func _draw() -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	var view := Rect2(-INF, -INF, INF, INF)
	if cam != null:
		var half: Vector2 = get_viewport_rect().size / cam.zoom * 0.6
		view = Rect2(cam.global_position - half, half * 2.0)
	for c in creatures:
		if not view.has_point(c.pos):
			continue
		var mod := Color(1, 1, 1).lerp(Color(3, 3, 3), c.flash * 0.7)
		if c.stun > 0.0:
			mod = mod * Color(0.7, 0.8, 1.2)
		match c.species:
			&"firefly":
				_draw_firefly(c, mod)
			&"mole":
				_draw_sprite(c, &"mole", int(c.t * 8.0) % 2, mod)
			&"spider":
				_draw_sprite(c, &"spider", int(c.t * 10.0) % 2, mod)
				var eye: float = 0.5 + 0.5 * sin(_t * 6.0)
				draw_circle(c.pos + Vector2(c.dir * 9.0, -2.0), 4.0, Color(1.0, 0.2, 0.15, 0.25 + 0.25 * eye))
			&"worm":
				_draw_worm(c, mod)
		if c.hp < c.max_hp:
			var w: float = 34.0
			var p: Vector2 = c.pos + Vector2(-w * 0.5, -c.radius - 14.0)
			draw_rect(Rect2(p, Vector2(w, 5)), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(p + Vector2(1, 1), Vector2((w - 2) * c.hp / c.max_hp, 3)), Color("ff5a3a") if c.is_hostile() else Color("7fe07a"))


func _draw_sprite(c: Creature, kind: StringName, frame: int, mod: Color) -> void:
	var tex: Texture2D = sprite(kind, frame)
	var sz: Vector2 = Vector2(tex.get_size()) * ART
	draw_set_transform(c.pos, 0.0, Vector2(-1.0 if c.dir < 0.0 else 1.0, 1.0))
	draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false, mod)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_firefly(c: Creature, mod: Color) -> void:
	var pulse: float = 0.5 + 0.5 * sin(c.t * 5.0)
	draw_circle(c.pos, 18.0, Color(0.75, 1.0, 0.35, 0.10 + 0.08 * pulse))
	draw_circle(c.pos, 9.0, Color(0.85, 1.0, 0.45, 0.25 + 0.2 * pulse))
	_draw_sprite(c, &"firefly", int(c.t * 16.0) % 2, mod)


func _draw_worm(c: Creature, mod: Color) -> void:
	var seg: Texture2D = sprite(&"worm_seg", 0)
	for i in range(c.segments.size() - 1, 0, -1):
		var k: float = 1.0 - float(i) / c.segments.size() * 0.45
		var sz: Vector2 = Vector2(seg.get_size()) * ART * k
		draw_texture_rect(seg, Rect2(c.segments[i] - sz * 0.5, sz), false, mod)
	var head: Texture2D = sprite(&"worm_head", int(c.t * 6.0) % 2)
	var hs: Vector2 = Vector2(head.get_size()) * ART
	draw_set_transform(c.pos, c.heading, Vector2.ONE)
	draw_texture_rect(head, Rect2(-hs * 0.5, hs), false, mod)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Sprites das espécies (gerados uma vez; 2 quadros quando animados).
static func sprite(kind: StringName, frame: int) -> Texture2D:
	var key := "%s_%d" % [kind, frame]
	if not _sprites.has(key):
		_sprites[key] = ImageTexture.create_from_image(_build(kind, frame))
	return _sprites[key]


static func _build(kind: StringName, frame: int) -> Image:
	match kind:
		&"mole":
			return _mole(frame)
		&"spider":
			return _spider(frame)
		&"firefly":
			return _firefly(frame)
		&"worm_head":
			return _worm_head(frame)
	return _worm_seg()


## Toupeira de raiz: corpo marrom-rosado, focinho rosa, garras e tufos de raiz nas costas.
static func _mole(frame: int) -> Image:
	var pal: Array[Color] = [Color("1a0c08"), Color("5a3020"), Color("8a5038"), Color("b8785a"), Color("f0a0a0"), Color("6e3818"), Color("0a0606"), Color("e8e0d0")]
	var cv := EnvArt.Canvas.new(16, 12, pal)
	cv.disc(Vector2(7.5, 7.0), 5.5, func(p: Vector2) -> int:
		return 3 if p.y < 5.5 else (2 if p.y < 8.5 else 1), 0.75)
	for x in range(12, 15):
		cv.setp(x, 7, 4)
		cv.setp(x, 8, 4 if x < 14 else 0)
	cv.setp(11, 5, 6)
	# Patas/garras (alternam por quadro).
	var f: int = frame
	for x: int in [4 + f, 9 - f]:
		cv.setp(x, 10, 1)
		cv.setp(x + 1, 10, 7)
	# Tufos de raiz nas costas.
	for x: int in [4, 6, 8]:
		cv.setp(x, 2, 5)
		cv.setp(x + 1, 1, 5)
	cv.outline(0)
	return cv.image()


## Aranha de raiz: corpo de casca, olhos vermelhos e oito pernas de raiz.
static func _spider(frame: int) -> Image:
	var pal: Array[Color] = [Color("120804"), Color("3a1c0c"), Color("6e3818"), Color("a8642c"), Color("ff3a26"), Color("ffd0a0")]
	var cv := EnvArt.Canvas.new(20, 14, pal)
	for i in 4:
		var x0: float = 6.0 + i * 2.5
		var lift: float = 1.0 if (i + frame) % 2 == 0 else 0.0
		for sgn: float in [-1.0, 1.0]:
			# Pernas: sobem até o "joelho" e descem até o chão.
			var kx: float = x0 + sgn * 0.0
			for k in 4:
				cv.setp(int(kx + (i - 1.5) * k * 0.6), int(6.0 - k - lift), 2)
			for k in 5:
				cv.setp(int(kx + (i - 1.5) * (2.4 + k * 0.5)), int(3.0 - lift + k * 2.0), 1 if sgn > 0 else 2)
	cv.disc(Vector2(9.0, 7.0), 4.2, func(p: Vector2) -> int:
		return 3 if p.y < 6.0 else (2 if fposmod(p.x + p.y, 3.0) < 1.5 else 1))
	cv.disc(Vector2(14.0, 7.5), 2.6, func(p: Vector2) -> int: return 2)
	cv.setp(15, 6, 4)
	cv.setp(16, 7, 4)
	if frame == 0:
		cv.setp(15, 6, 5)
	cv.outline(0)
	return cv.image()


## Vaga-lume: corpo escuro, asas claras batendo e cauda verde-amarelada.
static func _firefly(frame: int) -> Image:
	var pal: Array[Color] = [Color("10140a"), Color("2a2a1a"), Color("e8f4ff"), Color("d8ff6a"), Color("ffffc0")]
	var cv := EnvArt.Canvas.new(7, 7, pal)
	cv.setp(3, 3, 1)
	cv.setp(4, 3, 1)
	cv.setp(2, 3, 3)
	cv.setp(1, 3, 4)
	cv.setp(2, 4, 3)
	var wy: int = 1 if frame == 0 else 2
	cv.setp(3, wy, 2)
	cv.setp(4, wy, 2)
	return cv.image()


## Minhoca: cabeça com mandíbulas (abre/fecha) e anéis do corpo.
static func _worm_head(frame: int) -> Image:
	var pal: Array[Color] = [Color("1a0808"), Color("6a2a2a"), Color("a8504a"), Color("e08a7a"), Color("f0e0c0")]
	var cv := EnvArt.Canvas.new(14, 12, pal)
	cv.disc(Vector2(6.0, 6.0), 4.8, func(p: Vector2) -> int:
		return 3 if p.y < 4.5 else (2 if p.y < 7.5 else 1))
	var o: int = 1 if frame == 0 else 0
	for i in 3:
		cv.setp(10 + i, 3 - o + (1 if i == 2 else 0), 4)
		cv.setp(10 + i, 8 + o - (1 if i == 2 else 0), 4)
	cv.setp(9, 5, 0)
	cv.setp(9, 6, 0)
	cv.outline(0)
	return cv.image()


static func _worm_seg() -> Image:
	var pal: Array[Color] = [Color("1a0808"), Color("6a2a2a"), Color("a8504a"), Color("e08a7a")]
	var cv := EnvArt.Canvas.new(11, 11, pal)
	cv.disc(Vector2(5.5, 5.5), 4.6, func(p: Vector2) -> int:
		if absf(p.x - 5.5) < 0.6:
			return 1
		return 3 if p.y < 4.5 else (2 if p.y < 7.5 else 1))
	cv.outline(0)
	return cv.image()
