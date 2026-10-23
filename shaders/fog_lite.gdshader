shader_type canvas_item;
// Névoa simples (modo de compatibilidade, 0.17): só o círculo de luz da nave, sem lista
// de luzes extras nem laços. Mesmo visual de borda em degraus da névoa normal.

uniform vec2 rect_size = vec2(720.0, 1280.0);
uniform vec2 ship_pos = vec2(360.0, 640.0);
uniform float radius = 220.0;
uniform float strength = 0.92;
uniform vec4 fog_color : source_color = vec4(0.012, 0.016, 0.03, 1.0);

void fragment() {
	vec2 p = floor(UV * rect_size / 6.0) * 6.0 + 3.0;
	float v = 1.0 - smoothstep(radius * 0.3, radius, distance(p, ship_pos));
	v = floor(v * 10.0 + 0.5) / 10.0;
	COLOR = vec4(fog_color.rgb, strength * (1.0 - v));
}
