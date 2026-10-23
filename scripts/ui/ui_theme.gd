class_name UiTheme
extends RefCounted
## Tema visual único da interface: fonte pixelada (Pixelify Sans, OFL), painéis metálicos,
## placas e botões em pixel art (PixelArt). Construído em código.

const BG := Color("0f131b")
const PANEL := Color("161b27")
const PANEL_EDGE := Color("3c4456")
const TEXT := Color("eef1f6")
const TEXT_DIM := Color("9aa4b5")
const ACCENT := Color("f7b52c")
const ORANGE := Color("f5a623")
const BLUE := Color("3fd0ff")
const GREEN := Color("6fe07a")
const RED := Color("ff5a4a")
const CREDITS := Color("ffd166")
const CRYSTALS := Color("6fe3ff")

const FONT_SMALL: int = 22
const FONT_NORMAL: int = 28
const FONT_BIG: int = 52
## Fontes pixel art (SIL OFL 1.1, ver assets/fonts/OFL-*.txt):
## títulos, números e botões = Press Start 2P; textos = Jersey 10.
const DISPLAY_FONT_PATH: String = "res://assets/fonts/PressStart2P-Regular.ttf"
const BODY_FONT_PATH: String = "res://assets/fonts/Jersey10-Regular.ttf"
## Press Start 2P é larga: tamanhos pedidos para ela são reduzidos por este fator.
const DISPLAY_SCALE: float = 0.67
## Jersey 10 tem olho pequeno: tamanhos pedidos para textos são ampliados por este fator.
const BODY_SCALE: float = 1.3

static var _theme: Theme
static var _fonts: Dictionary = {}


## Fonte por "peso": >= 700 = fonte de destaque (Press Start 2P); abaixo = texto (Jersey 10).
static func font(weight: int = 500) -> Font:
	var display: bool = weight >= 700
	if not _fonts.has(display):
		var f: FontFile = load(DISPLAY_FONT_PATH if display else BODY_FONT_PATH) as FontFile
		# Pixel art: sem suavização nem hinting, posições inteiras (letras nítidas).
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_fonts[display] = f
	return _fonts[display]


## Tamanho efetivo para um peso (a fonte de destaque é mais larga).
static func font_size(size: int, weight: int) -> int:
	if weight >= 700:
		return maxi(8, int(round(size * DISPLAY_SCALE / 2.0)) * 2)
	return int(round(size * BODY_SCALE))


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = font(500)
	t.default_font_size = font_size(FONT_NORMAL, 500)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0.03, 0.04, 0.06, 1.0))
	t.set_constant("outline_size", "Label", 6)
	t.set_stylebox("panel", "PanelContainer", PixelArt.style(&"frame"))
	t.set_stylebox("panel", "Panel", PixelArt.style(&"inset"))
	_apply_button(t, &"steel")
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_hover_pressed_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", TEXT_DIM.darkened(0.3))
	t.set_color("font_outline_color", "Button", Color(0.03, 0.04, 0.06, 1.0))
	t.set_constant("outline_size", "Button", 5)
	t.set_font_size("font_size", "Button", font_size(FONT_NORMAL, 700))
	t.set_font("font", "Button", font(700))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	return t


static func _apply_button(t: Theme, kind: StringName) -> void:
	t.set_stylebox("normal", "Button", _btn(kind))
	t.set_stylebox("hover", "Button", _btn(kind))
	t.set_stylebox("pressed", "Button", _btn_pressed(kind))
	t.set_stylebox("hover_pressed", "Button", _btn_pressed(kind))
	t.set_stylebox("disabled", "Button", PixelArt.style(&"disabled"))


static func _btn(kind: StringName) -> StyleBox:
	if kind == &"steel":
		return PixelArt.style(&"inset")
	return PixelArt.style(kind)


static func _btn_pressed(kind: StringName) -> StyleBox:
	if kind == &"steel":
		return PixelArt.style(&"slot")
	return PixelArt.style(StringName(String(kind) + "_pressed"))


## Aplica um estilo de botão: &"gold", &"green", &"red", &"blue" ou &"steel".
## Botões claros (dourado/verde) usam texto escuro, como na referência.
static func style_button(b: Button, kind: StringName) -> void:
	b.add_theme_stylebox_override("normal", _btn(kind))
	b.add_theme_stylebox_override("hover", _btn(kind))
	b.add_theme_stylebox_override("pressed", _btn_pressed(kind))
	b.add_theme_stylebox_override("hover_pressed", _btn_pressed(kind))
	b.add_theme_stylebox_override("disabled", PixelArt.style(&"disabled"))
	var dark: bool = kind == &"gold"
	var fc: Color = Color("2a1a08") if dark else TEXT
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fc)
	b.add_theme_constant_override("outline_size", 0 if dark else 5)
	b.focus_mode = Control.FOCUS_NONE
	b.expand_icon = true


## Texto para a fonte de destaque: a Press Start 2P desenha maiúsculas acentuadas como
## minúsculas, então os acentos das MAIÚSCULAS são removidos (padrão de fontes de jogo).
static func display_text(text: String) -> String:
	var out: String = ""
	for ch in text:
		out += _strip_accent(ch)
	return out


static func _strip_accent(ch: String) -> String:
	const FROM: String = "ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ"
	const TO: String = "AAAAAEEEEIIIIOOOOOUUUUC"
	var i: int = FROM.find(ch)
	return TO[i] if i >= 0 else ch


static func label(text: String, size: int, color: Color, weight: int = 600) -> Label:
	var l := Label.new()
	l.text = display_text(text) if weight >= 700 else text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", font_size(size, weight))
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Texto que encolhe para caber (0.20): a largura mínima deixa de depender do texto e a
## fonte diminui (até min_px) quando o espaço é menor. Para títulos e valores em linhas
## apertadas (cabeçalhos), assim nada empurra a tela para fora das bordas.
static func fit(l: Label, min_px: int = 12) -> Label:
	l.clip_text = true
	l.set_meta("fit_base", l.get_theme_font_size("font_size"))
	var refit := func() -> void:
		if not is_instance_valid(l) or l.size.x <= 0.0:
			return
		var f: Font = l.get_theme_font("font")
		var s: int = int(l.get_meta("fit_base"))
		while s > min_px and f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > l.size.x - 2.0:
			s -= 1
		if s != l.get_theme_font_size("font_size"):
			l.add_theme_font_size_override("font_size", s)
	l.resized.connect(refit)
	l.draw.connect(func() -> void: refit.call_deferred())
	return l


## Ícone pixel art (TextureRect nítido) do tamanho pedido.
static func icon_rect(id: StringName, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = PixelArt.icon(id)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Caixa de moeda como na referência: ícone + valor dentro de um painel escuro.
static func currency_box(currency: StringName) -> Array:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", PixelArt.style(&"slot"))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	box.add_child(h)
	h.add_child(icon_rect(&"crystal" if currency == Economy.CRYSTALS else &"coin", 36))
	var value := fit(label("0", FONT_NORMAL, TEXT, 700))
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(value)
	return [box, value]


## 1234 → "1.234", 1500000 → "1,5 mi".
static func short_number(n: int) -> String:
	if n >= 1000000:
		return ("%.1f mi" % (n / 1000000.0)).replace(".", ",")
	var s: String = str(n)
	var out: String = ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


## Botão quadrado de engrenagem (abre as Configurações).
static func gear_button() -> Button:
	var b := Button.new()
	b.name = "SettingsButton"
	b.icon = PixelArt.icon(&"gear")
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(72, 72)
	b.add_theme_constant_override("icon_max_width", 44)
	b.focus_mode = Control.FOCUS_NONE
	style_button(b, &"steel")
	return b
