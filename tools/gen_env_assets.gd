extends SceneTree
## Gera os PNGs do ambiente a partir de EnvArt (determinístico).
##   godot --headless --path . -s res://tools/gen_env_assets.gd [-- --preview=/caminho/folha.png]
## Saída: assets/environment/{terrain,ores,vegetation,decorations}/*.png
## Os PNGs são importados como Image (arquivos .import com importer="image") e montados
## em atlas por TerrainTextures em tempo de execução.

const ROOT: String = "res://assets/environment"


func _initialize() -> void:
	var groups: Dictionary = {
		"terrain": EnvArt.terrain_tiles(),
		"ores": EnvArt.ore_sprites(),
		"vegetation": EnvArt.vegetation_sprites(),
		"decorations": EnvArt.decoration_sprites(),
	}
	var count: int = 0
	for dir: String in groups:
		var path: String = "%s/%s" % [ROOT, dir]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
		var items: Dictionary = groups[dir]
		for key: String in items:
			var file: String = "%s/%s.png" % [path, key]
			(items[key] as Image).save_png(file)
			_write_import(file)
			count += 1
	print("gen_env_assets: %d arquivos em %s" % [count, ROOT])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--preview="):
			_preview(groups, a.trim_prefix("--preview="))
	quit()


## Importa como Image (dados de pixel exatos, disponíveis também em builds exportados).
func _write_import(file: String) -> void:
	var imp: String = ProjectSettings.globalize_path(file + ".import")
	if FileAccess.file_exists(imp) and FileAccess.get_file_as_string(imp).contains("importer=\"image\""):
		return
	var f := FileAccess.open(imp, FileAccess.WRITE)
	f.store_string("[remap]\n\nimporter=\"image\"\ntype=\"Image\"\n")
	f.close()


## Folha de prévia (para revisão): cada grupo em uma faixa, ampliado.
func _preview(groups: Dictionary, out: String) -> void:
	var scale: int = 3
	var sheet := Image.create(1500, 1500, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("101418"))
	var y: int = 8
	for dir: String in groups:
		var x: int = 8
		var row_h: int = 0
		var items: Dictionary = groups[dir]
		for key: String in items:
			var img: Image = (items[key] as Image).duplicate()
			var sc: int = scale if dir == "terrain" else scale * 2
			img.resize(img.get_width() * sc, img.get_height() * sc, Image.INTERPOLATE_NEAREST)
			if x + img.get_width() > 1490:
				x = 8
				y += row_h + 8
				row_h = 0
			sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(x, y))
			x += img.get_width() + 8
			row_h = maxi(row_h, img.get_height())
		y += row_h + 20
	sheet.save_png(out)
