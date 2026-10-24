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


## 0.22: leitura do tombstone do Android (thread que quebrou, sinal e pilha).
func test_tombstone_summary() -> void:
	var bytes: PackedByteArray = "0803120b73616d73756e672f723971286330c8015221080b1207534947534547561801220b534547565f4d415045525240014890dafa0682013c08641238086412046d61696e222e08b42410b4a48080800e2211707468726561645f636f6e645f776169742800320d2f617065782f6c6962632e736f8201980108c80112920108c801120b474c546872656164203432224708c4c72210c4c7a280800e2215676c65735f647261775f647261775f617272617973280c32212f76656e646f722f6c696236342f65676c2f6c6962474c45535f6d616c692e736f223708805e1080de8080800e280032292f646174612f6170702f782f6c69622f61726d36342f6c6962676f646f745f616e64726f69642e736f".hex_decode()
	var txt: String = Tombstone.summary(bytes)
	check(txt.contains("SIGSEGV") and txt.contains("SEGV_MAPERR") and txt.contains("0xdead10"), "sinal e endereço")
	check(txt.contains("GLThread 42") and txt.contains("libGLES_mali.so +0x8a3c4 gles_draw_draw_arrays+12"), "thread que quebrou e o quadro do driver")
	check(txt.contains("libgodot_android.so +0x2f00") and not txt.contains("pthread_cond_wait"), "só a pilha da thread que quebrou")
	check(Tombstone.summary("lixo qualquer".to_utf8_buffer()) == "" or not Tombstone.summary("lixo qualquer".to_utf8_buffer()).contains("thread que quebrou"), "bytes inválidos não quebram")

