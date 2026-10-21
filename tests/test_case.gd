extends RefCounted
## Base mínima de asserções para as suítes headless.

var failures: Array[String] = []
var notes: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func check_eq(a: Variant, b: Variant, msg: String) -> void:
	if a != b:
		failures.append("%s (obtido=%s esperado=%s)" % [msg, str(a), str(b)])


func note(msg: String) -> void:
	notes.append(msg)
