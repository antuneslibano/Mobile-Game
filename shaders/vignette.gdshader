// Vinheta de alerta do HUD: brilho colorido nas bordas da tela (calor, casco, combustível).
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 0.35, 0.1, 1.0);
uniform float strength = 0.0;

void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.0, 0.72));
	float v = smoothstep(0.30, 0.70, d);
	// Degraus discretos (combina com a pixel art).
	v = floor(v * 6.0) / 6.0;
	COLOR = vec4(tint.rgb, v * strength);
}
