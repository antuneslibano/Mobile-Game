class_name SaveFile
extends RefCounted
## Leitura/escrita segura do perfil (JSON em user://).
## Escrita: grava em .tmp, guarda o arquivo anterior como .bak, troca e só então apaga o .bak.
## Leitura: valida o esquema; se o principal estiver corrompido, tenta o .bak; arquivos
## inválidos são renomeados para .corrompido (nunca apagados silenciosamente).

const SCHEMA_VERSION: int = 1


static func write_atomic(path: String, data: Dictionary) -> bool:
	var tmp: String = path + ".tmp"
	var bak: String = path + ".bak"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Salvamento: não foi possível abrir %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	var had_old: bool = FileAccess.file_exists(path)
	if had_old:
		DirAccess.remove_absolute(bak)
		if DirAccess.rename_absolute(path, bak) != OK:
			return false
	if DirAccess.rename_absolute(tmp, path) != OK:
		if had_old:
			DirAccess.rename_absolute(bak, path)
		return false
	if had_old:
		DirAccess.remove_absolute(bak)
	return true


## Retorna o dicionário salvo (validado) ou {} se não houver salvamento utilizável.
static func read(path: String) -> Dictionary:
	for candidate: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var text: String = FileAccess.get_file_as_string(candidate)
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary and is_valid(parsed):
			return parsed
		push_warning("Salvamento inválido em %s; preservado como .corrompido" % candidate)
		DirAccess.rename_absolute(candidate, candidate + ".corrompido")
	return {}


static func is_valid(d: Dictionary) -> bool:
	return int(d.get("schema", -1)) == SCHEMA_VERSION and d.get("economy") is Dictionary \
			and d.get("regions", {}) is Dictionary
