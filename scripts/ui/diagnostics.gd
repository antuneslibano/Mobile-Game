class_name Diagnostics
extends RefCounted
## Relatório de diagnóstico (0.17): aparelho, sistema, GPU, memória, tela, área segura,
## estado do modo de compatibilidade, onde o jogo estava quando fechou sozinho e o fim do
## log da sessão anterior. Mostrado nas Configurações, com botão de copiar, para o
## jogador mandar ao desenvolvedor.

const LOG_LINES: int = 40


static func report(vp: Viewport) -> String:
	var lines: PackedStringArray = []
	lines.append("DEEPFORGE %s" % String(ProjectSettings.get_setting("application/config/version", "?")))
	lines.append("Aparelho: %s" % OS.get_model_name())
	lines.append("Sistema: %s %s" % [OS.get_name(), OS.get_version()])
	lines.append("Processador: %s (%d núcleos)" % [OS.get_processor_name(), OS.get_processor_count()])
	var mem: Dictionary = OS.get_memory_info()
	lines.append("Memória: %s livre de %s" % [_mb(int(mem.get("available", -1))), _mb(int(mem.get("physical", -1)))])
	lines.append("Memória do jogo: %s (pico %s)" % [_mb(OS.get_static_memory_usage()), _mb(OS.get_static_memory_peak_usage())])
	lines.append("GPU: %s · %s" % [RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_name()])
	lines.append("API gráfica: %s" % RenderingServer.get_video_adapter_api_version())
	lines.append("Tela: %s · janela %s · jogo %s · escala %.2f" % [
			str(DisplayServer.screen_get_size()), str(DisplayServer.window_get_size()),
			str(vp.get_visible_rect().size if vp != null else Vector2.ZERO), DisplayServer.screen_get_scale()])
	lines.append("Área segura: %s · margens %s" % [str(DisplayServer.get_display_safe_area()), str(SafeArea.insets(vp))])
	lines.append("Modo de compatibilidade: %s%s" % ["nível %d" % Guard.compat_level if Guard.compat else "desligado", " (escolhido)" if Guard.compat_manual else " (automático)"])
	lines.append("Etapa atual: %s" % Guard.step_name)
	if Guard.crashed_last_time:
		lines.append("FECHOU SOZINHO na última vez, em: %s (seguidas: %d)" % [Guard.last_step, Guard.crash_count])
		lines.append("Modo de compatibilidade naquela sessão: %s" % ("nível %d" % Guard.last_level if Guard.last_level > 0 else "desligado"))
		if not Guard.last_history.is_empty():
			lines.append("Etapas antes de fechar: %s" % " > ".join(Guard.last_history))
	else:
		lines.append("Última sessão terminou normalmente.")
	_android_step = "início"
	var exits: String = android_exit_reasons()
	if OS.get_name() == "Android":
		lines.append("")
		lines.append("--- motivos de saída registrados pelo Android ---")
		if exits != "":
			lines.append(exits)
		else:
			# Erro de script em build de release interrompe a função e devolve vazio:
			# mostra o último passo alcançado e o fim do log desta sessão (com o erro).
			if not _android_out.is_empty():
				lines.append("\n".join(_android_out))
			lines.append("(leitura interrompida em: %s)" % _android_step)
			lines.append(current_log_tail(15))
	var tail: String = previous_log_tail()
	if tail != "":
		lines.append("")
		lines.append("--- fim do log da sessão anterior ---")
		lines.append(tail)
	return "\n".join(lines)


static func _mb(bytes: int) -> String:
	return "?" if bytes < 0 else "%.0f MB" % (bytes / 1048576.0)


## Últimas linhas do log da sessão anterior (o Godot renomeia o log ao abrir o jogo).
static func previous_log_tail() -> String:
	var dir := DirAccess.open("user://logs")
	if dir == null:
		return ""
	var best: String = ""
	for f in dir.get_files():
		if f.ends_with(".log") and f != "godot.log" and f > best:
			best = f
	if best == "":
		return ""
	var text: String = FileAccess.get_file_as_string("user://logs/" + best)
	var all: PackedStringArray = text.strip_edges().split("\n")
	var from: int = maxi(0, all.size() - LOG_LINES)
	return "\n".join(all.slice(from))


## Último passo alcançado na leitura do Android (para saber onde falhou).
static var _android_step: String = ""


## Últimas linhas do log desta sessão.
static func current_log_tail(count: int) -> String:
	var text: String = FileAccess.get_file_as_string("user://logs/godot.log")
	var all: PackedStringArray = text.strip_edges().split("\n")
	return "\n".join(all.slice(maxi(0, all.size() - count)))


## Motivos REASON_* de ApplicationExitInfo (Android 11+).
const EXIT_REASONS: Dictionary = {
	0: "desconhecido", 1: "o próprio app saiu", 2: "encerrado por sinal", 3: "pouca memória",
	4: "crash (Java)", 5: "CRASH NATIVO", 6: "travou (ANR)", 7: "falha ao iniciar",
	8: "permissão mudou", 9: "uso excessivo de recursos", 10: "pedido do usuário",
	11: "usuário parou", 12: "dependência morreu", 13: "outro", 14: "congelado",
	15: "pacote mudou", 16: "app atualizado",
}


## Últimos fechamentos do app segundo o Android (motivo, sinal, memória e, em crash
## nativo, as funções da pilha). Vazio fora do Android ou se a API não existir.
static func android_exit_reasons(limit: int = 3) -> String:
	if OS.get_name() != "Android":
		return ""
	_android_out.clear()
	_android_step = "plugin AndroidRuntime"
	if not Engine.has_singleton("AndroidRuntime"):
		return "(plugin AndroidRuntime indisponível)"
	var rt: Object = Engine.get_singleton("AndroidRuntime")
	_android_step = "getApplicationContext"
	var ctx: Object = rt.call("getApplicationContext")
	if ctx == null:
		return "(sem contexto do Android)"
	_android_step = "getSystemService"
	var am: Object = ctx.call("getSystemService", "activity")
	if am == null:
		return "(sem ActivityManager)"
	_android_step = "getPackageName"
	var pkg: String = str(ctx.call("getPackageName"))
	_android_step = "getHistoricalProcessExitReasons(%s)" % pkg
	var list: Object = am.call("getHistoricalProcessExitReasons", pkg, 0, limit)
	if list == null:
		return "(Android sem histórico de saídas)"
	_android_step = "List.size"
	var n: int = _int(list.call("size"))
	if n <= 0:
		return "(nenhum registro)"
	for i in n:
		_android_step = "registro %d: get" % (i + 1)
		var info: Object = list.call("get", i)
		if info == null:
			continue
		# Cada campo separado e convertido com segurança (alguns vêm vazios/nulos); o que
		# já foi lido fica em _android_out mesmo se um passo seguinte falhar.
		_android_step = "registro %d: motivo" % (i + 1)
		var reason: int = _int(info.call("getReason"))
		_android_step = "registro %d: data" % (i + 1)
		var when: String = Time.get_datetime_string_from_unix_time(_int(info.call("getTimestamp")) / 1000, true)
		_android_out.append("%d) %s · %s" % [i + 1, when, EXIT_REASONS.get(reason, str(reason))])
		_android_step = "registro %d: status" % (i + 1)
		_android_out.append("   status (sinal/código): %d" % _int(info.call("getStatus")))
		_android_step = "registro %d: descrição" % (i + 1)
		_android_out.append("   descrição: %s" % _str(info.call("getDescription")))
		_android_step = "registro %d: memória" % (i + 1)
		_android_out.append("   memória: pss %d MB, rss %d MB" % [_int(info.call("getPss")) / 1024, _int(info.call("getRss")) / 1024])
		if reason == 5 or reason == 6:
			_android_step = "registro %d: pilha" % (i + 1)
			var stack: String = _trace_summary(info.call("getTraceInputStream"), reason == 5)
			if stack != "":
				_android_out.append(stack)
	_android_step = "fim"
	return "\n".join(_android_out)


## Linhas já lidas do Android (sobrevivem a um erro no meio da leitura).
static var _android_out: PackedStringArray = []


static func _int(v: Variant) -> int:
	return int(v) if v is int or v is float or v is bool else -1


static func _str(v: Variant) -> String:
	return "" if v == null else str(v)


## Resumo da pilha: crash nativo (tombstone em protobuf) → trechos legíveis que citam
## bibliotecas e funções; ANR (texto) → começo da pilha da thread principal.
static func _trace_summary(stream: Object, native: bool) -> String:
	if stream == null:
		return ""
	var data: Variant = stream.call("readAllBytes")
	stream.call("close")
	_android_out.append("   pilha: %s bytes" % (str((data as PackedByteArray).size()) if data is PackedByteArray else "?"))
	if not data is PackedByteArray:
		return ""
	var bytes: PackedByteArray = data
	if not native:
		var text: String = bytes.slice(0, 6000).get_string_from_utf8()
		var keep: PackedStringArray = []
		for line in text.split("\n"):
			if line.contains("at ") or line.contains("#") or line.contains("main"):
				keep.append("   " + line.strip_edges())
			if keep.size() >= 25:
				break
		return "\n".join(keep)
	# Trechos ASCII imprimíveis com pelo menos 6 caracteres; ficam os que parecem frames.
	var parts: PackedStringArray = []
	var run := PackedByteArray()
	for b in bytes.slice(0, 400000):
		if b >= 32 and b < 127:
			run.append(b)
			continue
		if run.size() >= 6:
			var str_run: String = run.get_string_from_ascii()
			if (str_run.contains(".so") or str_run.contains("::") or str_run.contains("signal") or str_run.contains("Abort") \
					or str_run.contains("SIG")) and not parts.has(str_run):
				parts.append("   " + str_run.left(160))
		run.clear()
		if parts.size() >= 40:
			break
	return "\n".join(parts)
