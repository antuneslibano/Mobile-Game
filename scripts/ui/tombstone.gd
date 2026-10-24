class_name Tombstone
extends RefCounted
## Leitura do relatório de crash nativo do Android (tombstone em protobuf, 0.22): sinal,
## endereço, mensagem de abort e a pilha da thread que quebrou (biblioteca + deslocamento
## + função quando houver). Formato: AOSP system/core/debuggerd/proto/tombstone.proto.

const MAX_FRAMES: int = 18


## Resumo legível. "" se os bytes não parecerem um tombstone.
static func summary(bytes: PackedByteArray) -> String:
	var top: Dictionary = _fields(bytes, 0, bytes.size())
	if top.is_empty():
		return ""
	var out: PackedStringArray = []
	var tid: int = int(_first(top, 6, 0))
	var sig: Variant = _first(top, 10, null)
	if sig is PackedByteArray:
		var s: Dictionary = _fields(sig, 0, (sig as PackedByteArray).size())
		var line: String = "   sinal %s (%s)" % [_str(_first(s, 2, "?")), _str(_first(s, 4, ""))]
		if int(_first(s, 8, 0)) != 0:
			line += " endereço 0x%x" % int(_first(s, 9, 0))
		out.append(line)
	var abort: String = _str(_first(top, 14, ""))
	if abort != "":
		out.append("   abort: " + abort.left(200))
	for c: Variant in top.get(15, []):
		if c is PackedByteArray:
			var cf: Dictionary = _fields(c, 0, (c as PackedByteArray).size())
			out.append("   causa: " + _str(_first(cf, 1, "")).left(160))
	# Threads: mapa tid → Thread (entradas com chave 1 e valor 2).
	var crashed: Dictionary = {}
	var names: PackedStringArray = []
	for e: Variant in top.get(16, []):
		if not e is PackedByteArray:
			continue
		var entry: Dictionary = _fields(e, 0, (e as PackedByteArray).size())
		var th: Variant = _first(entry, 2, null)
		if not th is PackedByteArray:
			continue
		var t: Dictionary = _fields(th, 0, (th as PackedByteArray).size())
		var id: int = int(_first(t, 1, int(_first(entry, 1, -1))))
		names.append("%d:%s" % [id, _str(_first(t, 2, "?"))])
		if id == tid:
			crashed = t
	if crashed.is_empty():
		out.append("   thread %d não encontrada (%d threads)" % [tid, names.size()])
		return "\n".join(out)
	out.append("   thread que quebrou: %d \"%s\"" % [tid, _str(_first(crashed, 2, "?"))])
	var n: int = 0
	for f: Variant in crashed.get(4, []):
		if not f is PackedByteArray or n >= MAX_FRAMES:
			continue
		var fr: Dictionary = _fields(f, 0, (f as PackedByteArray).size())
		var file: String = _str(_first(fr, 6, "?")).get_file()
		var fn: String = _str(_first(fr, 4, ""))
		var line: String = "   #%02d %s +0x%x" % [n, file, int(_first(fr, 1, 0))]
		if fn != "":
			line += " %s+%d" % [fn.left(90), int(_first(fr, 5, 0))]
		out.append(line)
		n += 1
	return "\n".join(out)


static func _first(d: Dictionary, field: int, default: Variant) -> Variant:
	var v: Variant = d.get(field, [])
	return (v as Array)[0] if v is Array and not (v as Array).is_empty() else default


static func _str(v: Variant) -> String:
	if v is PackedByteArray:
		return (v as PackedByteArray).get_string_from_utf8()
	return str(v)


## Campos de uma mensagem: número → [valores] (varint → int; bloco → PackedByteArray).
## {} se o formato não fecha.
static func _fields(b: PackedByteArray, from: int, to: int) -> Dictionary:
	var out: Dictionary = {}
	var i: int = from
	while i < to:
		var key: Array = _varint(b, i, to)
		if key.is_empty():
			return {}
		i = key[1]
		var field: int = int(key[0]) >> 3
		var wire: int = int(key[0]) & 7
		var val: Variant
		match wire:
			0:
				var v: Array = _varint(b, i, to)
				if v.is_empty():
					return {}
				val = v[0]
				i = v[1]
			1:
				if i + 8 > to:
					return {}
				val = b.decode_u64(i)
				i += 8
			2:
				var ln: Array = _varint(b, i, to)
				if ln.is_empty() or int(ln[1]) + int(ln[0]) > to or int(ln[0]) < 0:
					return {}
				i = ln[1]
				val = b.slice(i, i + int(ln[0]))
				i += int(ln[0])
			5:
				if i + 4 > to:
					return {}
				val = b.decode_u32(i)
				i += 4
			_:
				return {}
		if field <= 0:
			return {}
		if not out.has(field):
			out[field] = []
		(out[field] as Array).append(val)
	return out


static func _varint(b: PackedByteArray, i: int, to: int) -> Array:
	var v: int = 0
	var shift: int = 0
	while i < to and shift < 64:
		var x: int = b[i]
		i += 1
		v |= (x & 0x7F) << shift
		if x < 0x80:
			return [v, i]
		shift += 7
	return []
