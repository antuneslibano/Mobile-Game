extends "res://tests/test_case.gd"


func test_terrain_textures_build() -> void:
	var t0: int = Time.get_ticks_usec()
	var pal: Image = TerrainTextures.build_palette()
	var noise: Image = TerrainTextures.build_noise()
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	check_eq(pal.get_height(), BlockRegistry.COUNT + BiomeRegistry.COUNT, "paleta: uma linha por bloco + biomas")
	for def: BlockDef in BlockRegistry.all():
		if def.solid:
			check(pal.get_pixel(0, def.id).a > 0.99, "cor base de %s" % def.key)
			check(absf(pal.get_pixel(6, def.id).r * 255.0 - float(def.art)) < 0.5, "tipo de arte codificado em %s" % def.key)
	check_eq(noise.get_width(), TerrainTextures.NOISE_SIZE, "ruído 256 px")
	# Ruído precisa variar em todos os canais (senão as bordas ficariam retas).
	for ch in 4:
		var lo: float = 1.0
		var hi: float = 0.0
		for i in 64:
			var c: Color = noise.get_pixel((i * 37) % 256, (i * 91) % 256)
			var v: float = [c.r, c.g, c.b, c.a][ch]
			lo = minf(lo, v)
			hi = maxf(hi, v)
		check(hi - lo > 0.3, "canal %d do ruído varia (%.2f..%.2f)" % [ch, lo, hi])
	note("texturas do terreno em %.1f ms" % ms)


func test_terrain_shader_loads() -> void:
	var shader: Shader = load(TerrainTextures.SHADER_PATH)
	check(shader != null, "shader de terreno carrega")
	check(shader != null and shader.get_code().contains("texelFetch"), "shader lê os dados das células")
