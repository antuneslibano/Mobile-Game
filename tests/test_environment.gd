extends "res://tests/test_case.gd"
## Ambiente visual: assets gerados, texturas repetíveis, sprites distintos, tabelas por
## região e decorações de caverna (só visuais, nunca em túneis escavados).


func _img(path: String) -> Image:
	var img: Image = load(path) as Image
	if img == null:
		return null
	img = img.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	return img


func test_assets_exist_with_expected_sizes() -> void:
	for name in TerrainSkins.TILES:
		var img: Image = _img("%s/terrain/%s.png" % [TerrainSkins.ROOT, name])
		check(img != null and img.get_size() == Vector2i(TerrainTextures.TERRAIN_TILE, TerrainTextures.TERRAIN_TILE), "textura %s %d×%d" % [name, TerrainTextures.TERRAIN_TILE, TerrainTextures.TERRAIN_TILE])
	for name in TerrainSkins.ORES:
		for v in TerrainSkins.ORE_VARIANTS:
			var img: Image = _img("%s/ores/%s_%d.png" % [TerrainSkins.ROOT, name, v + 1])
			check(img != null and img.get_size() == Vector2i(EnvArt.ORE, EnvArt.ORE), "depósito %s_%d 12×12" % [name, v + 1])
			if img != null:
				check(img.get_pixel(0, 0).a == 0.0, "depósito %s com fundo transparente" % name)
	for e: Array in TerrainSkins.DECOR:
		var img: Image = _img("%s/%s/%s.png" % [TerrainSkins.ROOT, e[0], e[1]])
		var limit: int = 16 if e[2] == &"fossil" else TerrainSkins.DECOR_CELL
		check(img != null and img.get_width() <= limit and img.get_height() <= limit, "decoração %s cabe na célula" % e[1])
	var atlas: Image = TerrainTextures.terrain_atlas()
	check_eq(atlas.get_size(), Vector2i(TerrainTextures.TERRAIN_TILE * 8, TerrainTextures.TERRAIN_TILE * 2), "atlas de texturas 8×2")


## Repetível: a emenda (última → primeira coluna/linha) não destoa das fronteiras internas
## (no máximo 25% acima da pior delas: uma rachadura pode cair justo na linha da emenda).
func test_terrain_tiles_are_seamless() -> void:
	var t: int = TerrainTextures.TERRAIN_TILE
	for name in TerrainSkins.TILES:
		var img: Image = _img("%s/terrain/%s.png" % [TerrainSkins.ROOT, name])
		for vertical: bool in [false, true]:
			var worst: float = 0.0
			var seam: float = 0.0
			for k in t:
				var line: float = 0.0
				for i in t:
					var a: Vector2i = Vector2i(k, i) if not vertical else Vector2i(i, k)
					var b: Vector2i = Vector2i((k + 1) % t, i) if not vertical else Vector2i(i, (k + 1) % t)
					line += _diff(img.get_pixelv(a), img.get_pixelv(b))
				if k == t - 1:
					seam = line
				else:
					worst = maxf(worst, line)
			check(seam <= worst * 1.25, "%s sem emenda %s (emenda %.1f, pior interna %.1f)" % [name, "vertical" if vertical else "horizontal", seam, worst])


func _diff(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


## Cada minério se reconhece sem o nome: silhueta OU cor claramente diferentes.
func test_ore_sprites_are_distinct() -> void:
	var masks: Dictionary = {}
	var means: Dictionary = {}
	for name in TerrainSkins.ORES:
		var img: Image = _img("%s/ores/%s_1.png" % [TerrainSkins.ROOT, name])
		var mask := PackedByteArray()
		var sum := Color(0, 0, 0, 0)
		var n: int = 0
		for y in EnvArt.ORE:
			for x in EnvArt.ORE:
				var c: Color = img.get_pixel(x, y)
				mask.append(1 if c.a > 0.5 else 0)
				if c.a > 0.5:
					sum += c
					n += 1
		check(n >= 20, "%s tem corpo visível (%d px)" % [name, n])
		masks[name] = mask
		means[name] = sum / maxf(1.0, n)
	var names: Array = TerrainSkins.ORES
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: PackedByteArray = masks[names[i]]
			var b: PackedByteArray = masks[names[j]]
			var inter: int = 0
			var uni: int = 0
			for k in a.size():
				inter += a[k] & b[k]
				uni += a[k] | b[k]
			var iou: float = float(inter) / maxf(1.0, uni)
			var cd: float = _diff(means[names[i]], means[names[j]])
			check(iou < 0.8 or cd > 0.25, "%s × %s distintos (silhueta %.2f, cor %.2f)" % [names[i], names[j], iou, cd])


func test_every_deposit_has_a_sprite_and_terrain_has_none() -> void:
	var pal: Image = TerrainTextures.build_palette()
	for def: BlockDef in BlockRegistry.all():
		var sprite: String = TerrainSkins.ore_sprite_for(def.id)
		var row: int = pal.get_pixel(8, def.id).r8
		if def.art in [BlockDef.Art.ORE, BlockDef.Art.CRYSTAL, BlockDef.Art.PRISM, BlockDef.Art.CHEST]:
			check(not sprite.is_empty(), "%s tem sprite de depósito" % def.key)
			check_eq(row, TerrainSkins.ORES.find(sprite), "%s: linha do atlas na paleta" % def.key)
		else:
			check_eq(row, TerrainSkins.NONE, "%s sem sprite de depósito" % def.key)
		if def.is_terrain():
			check(sprite.is_empty(), "%s (terreno) não vira ícone de minério" % def.key)


func test_vale_uses_all_terrain_textures() -> void:
	var used: Dictionary = {}
	var vale: RegionDef = RegionRegistry.get_def(RegionRegistry.VALE)
	for layer in vale.layers.size():
		for id in BlockRegistry.COUNT:
			var k: PackedByteArray = TerrainSkins.skin_for(RegionRegistry.VALE, layer, id)
			for v in k:
				if v != TerrainSkins.NONE:
					check(v < TerrainSkins.TILES.size(), "índice de textura válido")
					used[v] = true
	check_eq(used.size(), TerrainSkins.TILES.size(), "as 16 texturas do Vale estão em uso")
	check_eq(TerrainSkins.skin_for(RegionRegistry.VALE, 0, BlockRegistry.DIRT)[0], TerrainSkins.tile("terra_clara"), "superfície do Vale: terra clara")
	# Material de uma camada vizinha usa a textura da camada que o define.
	check_eq(TerrainSkins.skin_for(RegionRegistry.VALE, 0, BlockRegistry.SAND)[0], TerrainSkins.tile("solo_arenoso"), "areia perto da fronteira texturizada")
	check_eq(TerrainSkins.skin_for(RegionRegistry.DUNAS, 0, BlockRegistry.SAND)[0], TerrainSkins.NONE, "areia das Dunas mantém o desenho próprio")


func test_decor_tables_are_valid() -> void:
	for r in RegionRegistry.all():
		for layer in r.layers.size():
			var t: Dictionary = TerrainSkins.decor_for(r.id, layer)
			for kind: String in t:
				var table: Array = t[kind]
				check(float(table[0]) >= 0.0 and float(table[0]) <= 1.0, "densidade válida")
				for i in range(1, table.size()):
					var idx: int = TerrainSkins.decor_index(table[i][0])
					check(idx >= 0, "decoração %s existe" % table[i][0])
					if idx >= 0:
						check_eq(TerrainSkins.DECOR[idx][2], StringName(kind), "%s é do tipo %s" % [table[i][0], kind])
	check_eq(TerrainSkins.fossil_indices().size(), 4, "quatro desenhos de fóssil")
	var img: Image = TerrainTextures.build_decor_table(RegionRegistry.VALE)
	check(img.get_pixel(TerrainTextures.DECOR_SLOTS, 0).r > 0.0, "Vale tem decorações embutidas na superfície")
	img = TerrainTextures.build_decor_table(RegionRegistry.DUNAS)
	check_eq(img.get_pixel(TerrainTextures.DECOR_SLOTS, 0).r, 0.0, "outras regiões sem decorações (por enquanto)")


func test_cave_decor_only_in_natural_caves() -> void:
	var vale: RegionDef = RegionRegistry.get_def(RegionRegistry.VALE)
	var w := WorldModel.new(11, vale)
	var plan: Dictionary = {}
	var index: int = 0
	for i in 4:
		w.get_chunk(i)
		plan = CaveDecor.plan(w, i, RegionRegistry.VALE)
		if plan.size() >= 3:
			index = i
			break
	check(plan.size() >= 3, "cavernas do Vale recebem vegetação (%d)" % plan.size())
	for c: Vector2i in plan:
		var e: Array = plan[c]
		check(w.is_solid(c), "decoração apoiada em célula sólida")
		var dir: int = -1 if e[2] == &"floor" else 1
		check(w.peek_cell(c + Vector2i(0, dir)) == BlockRegistry.AIR and not w.is_modified(c + Vector2i(0, dir)),
				"decoração voltada para caverna natural")
	# Escavar o apoio remove a decoração; o espaço escavado não ganha decoração nova.
	var anchor: Vector2i = plan.keys()[0]
	var deco := CaveDecor.new()
	deco.world = w
	deco.chunk_index = index
	deco.items = plan.duplicate()
	w.set_cell(anchor, BlockRegistry.AIR)
	deco.on_cells_changed([anchor] as Array[Vector2i])
	check(not deco.items.has(anchor), "decoração some quando o apoio é escavado")
	var again: Dictionary = CaveDecor.plan(w, index, RegionRegistry.VALE)
	var below := anchor + Vector2i(0, 1)
	check(not again.has(below) or again[below][2] != &"floor", "túnel escavado não recebe decoração")
	deco.free()
	w.shutdown()
	# Outras regiões continuam sem vegetação.
	var dunas := WorldModel.new(11, RegionRegistry.get_def(RegionRegistry.DUNAS))
	dunas.get_chunk(index)
	check(CaveDecor.plan(dunas, index, RegionRegistry.DUNAS).is_empty(), "Dunas sem vegetação de caverna")
	dunas.shutdown()


## Câmera anti-cintilação: passo inteiro em pixels do jogo e do aparelho.
func test_camera_snap_step() -> void:
	check_eq(DepthCamera.step_for_scale(1.0), 1.0, "escala 1×: passo de 1 px")
	check_eq(DepthCamera.step_for_scale(1.5), 2.0, "720 → 1080 (1,5×): passo de 2 px = 3 px reais")
	check_eq(DepthCamera.step_for_scale(2.25), 4.0, "2,25×: passo de 4 px = 9 px reais")
	check_eq(DepthCamera.step_for_scale(2.0), 1.0, "2×: passo de 1 px")
	for sc: float in [1.5, 2.25, 1.0 + 1.0 / 3.0, 0.75]:
		var st: float = DepthCamera.step_for_scale(sc)
		var dev: float = st * sc
		check(absf(dev - roundf(dev)) < 0.02 or st == 1.0, "escala %.3f: passo %.0f inteiro no aparelho" % [sc, st])
