class_name FallFx
extends Node2D
## Queda livre (0.20): riscos de vento subindo em volta da nave enquanto ela cai. Filho
## da Drill; a intensidade (0..1) vem de Game (mesma da câmera).

const LINES: int = 14

var amount: float = 0.0
var _t: float = 0.0
var _seeds: PackedFloat32Array = []


func _ready() -> void:
	z_index = 5
	for i in LINES * 2:
		_seeds.append(randf())


func _process(delta: float) -> void:
	_t += delta
	visible = amount > 0.02
	if visible:
		queue_redraw()


func _draw() -> void:
	for i in LINES:
		var sx: float = _seeds[i * 2]
		var sp: float = _seeds[i * 2 + 1]
		# Cada risco sobe em ciclo, numa coluna ao redor da nave (mais denso nas bordas).
		var x: float = (sx - 0.5) * 300.0
		if absf(x) < 40.0:
			x = signf(x if x != 0.0 else 1.0) * (40.0 + absf(x))
		var ph: float = fposmod(_t * (1.6 + sp * 1.4) + sp, 1.0)
		var y: float = 260.0 - ph * 560.0
		var length: float = (40.0 + sp * 70.0) * amount
		var a: float = amount * 0.7 * sin(ph * PI)
		draw_line(Vector2(x, y), Vector2(x, y + length), Color(1, 1, 1, a), 2.0 + sp * 1.5)
