extends Node
## Gera assets/audio/sound_bank.res a partir dos sintetizadores (Sfx._build_all,
## MusicSynth, BossSynth). Rodar sempre que um som mudar:
##   godot --headless --path . res://tools/bake_audio.tscn

func _ready() -> void:
	var bank := SoundBank.new()
	Sfx.call("_build_all")
	bank.streams = (Sfx.get("_streams") as Dictionary).duplicate()
	var m := MusicSynth.new()
	while not m.fill(m.n):
		pass
	bank.music = m.result()
	var bs := BossSynth.new()
	while not bs.fill(bs.n):
		pass
	bank.boss = bs.result()
	var err: int = ResourceSaver.save(bank, Sfx.BANK_PATH, ResourceSaver.FLAG_COMPRESS)
	print("banco de sons: %d efeitos + trilha + tema → %s (%s)" % [bank.streams.size(), Sfx.BANK_PATH, error_string(err)])
	get_tree().quit(0 if err == OK else 1)
