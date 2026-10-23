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
	lines.append("Modo de compatibilidade: %s%s" % ["ligado" if Guard.compat else "desligado", " (escolhido)" if Guard.compat_manual else ""])
	lines.append("Etapa atual: %s" % Guard.step_name)
	if Guard.crashed_last_time:
		lines.append("FECHOU SOZINHO na última vez, em: %s (seguidas: %d)" % [Guard.last_step, Guard.crash_count])
	else:
		lines.append("Última sessão terminou normalmente.")
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
