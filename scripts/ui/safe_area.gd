class_name SafeArea
extends RefCounted
## Área segura da tela (0.17): o que fica fora de notch/câmera furada, cantos
## arredondados e barra de gestos, em unidades do jogo (viewport). Todas as telas usam
## isto para não ter nada cortado nas bordas, em qualquer celular ou tablet.
##
## No PC as margens são zero; em builds de depuração, --safe-area=T,B,L,R simula um
## aparelho com essas margens (px do jogo) para testar.

## Margem mínima nas bordas de cima e de baixo em celulares (cantos arredondados mesmo
## quando o sistema não informa recorte).
const MIN_MOBILE_EDGE: float = 8.0
## Largura máxima do conteúdo das telas de menu: em tablets e celulares dobráveis o
## painel fica centralizado em vez de esticar de ponta a ponta.
const MAX_CONTENT_W: float = 760.0

## Simulação (testes): x = topo, y = baixo, z = esquerda, w = direita. x < 0 = desligada.
static var debug_insets: Vector4 = Vector4(-1, 0, 0, 0)


## Margens (topo, baixo, esquerda, direita) em px do jogo para uma viewport.
static func insets(vp: Viewport) -> Vector4:
	if debug_insets.x >= 0.0:
		return debug_insets
	if vp == null or not OS.has_feature("mobile"):
		return Vector4.ZERO
	var win := Vector2(DisplayServer.window_get_size())
	var size: Vector2 = vp.get_visible_rect().size
	if win.x <= 0.0 or win.y <= 0.0 or size.x <= 0.0:
		return Vector4(MIN_MOBILE_EDGE, MIN_MOBILE_EDGE, 0, 0)
	# A área segura vem em pixels da tela; a janela pode não começar na origem da tela.
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var origin := Vector2(DisplayServer.window_get_position())
	safe.position -= origin
	var k: float = size.x / win.x
	var top: float = clampf(safe.position.y, 0.0, win.y * 0.25) * k
	var bottom: float = clampf(win.y - safe.end.y, 0.0, win.y * 0.25) * k
	var left: float = clampf(safe.position.x, 0.0, win.x * 0.25) * k
	var right: float = clampf(win.x - safe.end.x, 0.0, win.x * 0.25) * k
	return Vector4(maxf(top, MIN_MOBILE_EDGE), maxf(bottom, MIN_MOBILE_EDGE), left, right)


static func top(vp: Viewport) -> float:
	return insets(vp).x


static func bottom(vp: Viewport) -> float:
	return insets(vp).y


## Retângulo seguro em px do jogo.
static func rect(vp: Viewport) -> Rect2:
	var size: Vector2 = vp.get_visible_rect().size
	var i: Vector4 = insets(vp)
	return Rect2(i.z, i.x, size.x - i.z - i.w, size.y - i.x - i.y)


## Margens laterais de um conteúdo que deve ficar no máximo com MAX_CONTENT_W de largura
## (centralizado), respeitando as margens base e a área segura. Retorna (esquerda, direita).
static func side_margins(vp: Viewport, base: float, max_w: float = MAX_CONTENT_W) -> Vector2:
	var size: Vector2 = vp.get_visible_rect().size
	var i: Vector4 = insets(vp)
	var l: float = base + i.z
	var r: float = base + i.w
	var extra: float = (size.x - l - r) - max_w
	if extra > 0.0:
		l += extra * 0.5
		r += extra * 0.5
	return Vector2(l, r)


## Lê --safe-area=T,B,L,R (só em depuração).
static func parse_debug(arg: String) -> void:
	var p: PackedStringArray = arg.split(",")
	if p.size() == 4:
		debug_insets = Vector4(float(p[0]), float(p[1]), float(p[2]), float(p[3]))
