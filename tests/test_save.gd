extends "res://tests/test_case.gd"
## Salvamento do perfil: escrita atômica, validação, cópia de segurança e restauração.

const PATH: String = "user://test_profile.json"


func _clean() -> void:
	for suffix: String in ["", ".tmp", ".bak", ".corrompido", ".bak.corrompido"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func _profile(credits: int) -> Dictionary:
	var e := Economy.new()
	e.credits = credits
	return {"schema": SaveFile.SCHEMA_VERSION, "economy": e.to_dict(), "region": "dunas",
			"regions": {"vale": 120, "dunas": 40}}


func test_roundtrip() -> void:
	_clean()
	check(SaveFile.write_atomic(PATH, _profile(77)), "gravou o perfil")
	check(not FileAccess.file_exists(PATH + ".tmp") and not FileAccess.file_exists(PATH + ".bak"), "sem temporários")
	var d: Dictionary = SaveFile.read(PATH)
	check_eq(int(d.economy.credits), 77, "créditos restaurados")
	check_eq(int(d.regions.vale), 120, "progresso por região restaurado")
	check(SaveFile.write_atomic(PATH, _profile(90)), "sobrescreveu o perfil")
	check_eq(int(SaveFile.read(PATH).economy.credits), 90, "versão mais nova lida")
	_clean()


func test_missing_and_corrupted() -> void:
	_clean()
	check(SaveFile.read(PATH).is_empty(), "sem arquivo: perfil vazio")
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{ isto não é json")
	f.close()
	check(SaveFile.read(PATH).is_empty(), "arquivo corrompido: perfil vazio")
	check(FileAccess.file_exists(PATH + ".corrompido"), "arquivo corrompido preservado")
	check(not FileAccess.file_exists(PATH), "arquivo corrompido fora do caminho principal")
	f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": 999, "economy": {}}))
	f.close()
	check(SaveFile.read(PATH).is_empty(), "esquema desconhecido rejeitado")
	_clean()


func test_backup_fallback() -> void:
	_clean()
	# Simula queda no meio da troca: principal inválido, .bak íntegro.
	var f := FileAccess.open(PATH + ".bak", FileAccess.WRITE)
	f.store_string(JSON.stringify(_profile(55)))
	f.close()
	f = FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("")
	f.close()
	check_eq(int(SaveFile.read(PATH).get("economy", {}).get("credits", -1)), 55, "recuperou do .bak")
	_clean()


func test_economy_from_dict_validates() -> void:
	var e := Economy.new()
	e.credits = 500
	e.crystals = 7
	e.cargo[&"gold"] = 3
	e.upgrade_levels[&"damage"] = 2
	var back: Economy = Economy.from_dict(JSON.parse_string(JSON.stringify(e.to_dict())))
	check_eq(back.credits, 500, "créditos")
	check_eq(back.crystals, 7, "cristais")
	check_eq(int(back.cargo.get(&"gold", 0)), 3, "carga")
	check_eq(back.get_level(&"damage"), 2, "nível de upgrade")
	var bad: Economy = Economy.from_dict({"credits": -40, "cargo": {"nada": 5, "gold": -2},
			"upgrades": {"damage": 9999, "inexistente": 3}, "equipped": ["drone", 12]})
	check_eq(bad.credits, 0, "créditos negativos descartados")
	check(bad.cargo.is_empty(), "carga inválida descartada")
	check_eq(bad.get_level(&"damage"), UpgradeRegistry.get_def(&"damage").max_level, "nível limitado ao máximo")
	check(bad.equipped_modules.is_empty(), "módulo não comprado não é equipado")
