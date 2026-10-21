extends SceneTree
## Runner headless:  godot --headless --path . -s res://tests/run_tests.gd

const SUITES: Array[String] = [
	"res://tests/test_data.gd",
	"res://tests/test_world.gd",
	"res://tests/test_mining.gd",
	"res://tests/test_economy.gd",
	"res://tests/test_progression.gd",
	"res://tests/test_phase3.gd",
	"res://tests/test_drill.gd",
	"res://tests/test_render.gd",
]


func _initialize() -> void:
	var total: int = 0
	var failed: int = 0
	var t0: int = Time.get_ticks_msec()
	for path in SUITES:
		var script: GDScript = load(path)
		if script == null:
			print("ERRO  não foi possível carregar %s" % path)
			failed += 1
			continue
		print("== %s" % path.get_file())
		for m: Dictionary in script.get_script_method_list():
			var method: String = m["name"]
			if not method.begins_with("test_"):
				continue
			var suite: RefCounted = script.new()
			suite.call(method)
			total += 1
			var fails: Array[String] = suite.get("failures")
			var notes: Array[String] = suite.get("notes")
			if fails.is_empty():
				print("  ok    %s" % method)
			else:
				failed += 1
				print("  FALHA %s" % method)
				for f in fails:
					print("        - %s" % f)
			for n in notes:
				print("        · %s" % n)
	print("")
	print("%d testes, %d falhas (%d ms)" % [total, failed, Time.get_ticks_msec() - t0])
	quit(1 if failed > 0 else 0)
