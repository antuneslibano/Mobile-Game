extends "res://tests/test_case.gd"


func test_tile_atlas_builds() -> void:
	var t0: int = Time.get_ticks_usec()
	var img: Image = TileArt.build_image()
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	check(img != null, "atlas gerado")
	check_eq(img.get_width(), TileArt.STRIDE * TileArt.VARIANTS, "largura do atlas")
	check_eq(img.get_height(), TileArt.STRIDE * TileArt.ROWS, "altura do atlas")
	# Todo bloco visível tem pixels opacos em todas as variantes.
	for def: BlockDef in BlockRegistry.all():
		if def.art == BlockDef.Art.NONE:
			continue
		for v in TileArt.VARIANTS:
			var r: Rect2 = TileArt.region(def.id, v)
			var c: Color = img.get_pixel(int(r.position.x) + 8, int(r.position.y) + 8)
			check(c.a > 0.9, "tile %s/%d opaco" % [def.key, v])
	note("atlas %dx%d em %.1f ms" % [img.get_width(), img.get_height(), ms])
