shader_type canvas_item;
// Ondas de calor (0.19): distorce o que já foi desenhado (mundo, névoa) com ondas que
// sobem, como ar quente. strength 0..1 vem do quanto a nave passou do limite térmico.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float strength = 0.0;
uniform float time = 0.0;
uniform vec2 rect_size = vec2(720.0, 1280.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 p = UV * rect_size;
	// Duas ondas: uma larga e lenta, uma fina e rápida, subindo; mais forte embaixo.
	float rise = time * 2.2;
	float w1 = sin(p.y * 0.035 + rise * 1.7 + sin(p.x * 0.01) * 2.0);
	float w2 = sin(p.y * 0.11 - rise * 3.1 + p.x * 0.02);
	float amp = strength * (0.55 + 0.45 * UV.y);
	vec2 off = vec2(w1 * 3.2 + w2 * 1.3, w2 * 1.6) * amp / rect_size;
	vec3 c = texture(screen_tex, uv + off).rgb;
	// Leve tom quente e um brilho que pulsa.
	c = mix(c, c * vec3(1.12, 0.95, 0.82), strength * 0.6);
	c += vec3(0.08, 0.025, 0.0) * strength * (0.5 + 0.5 * sin(rise * 2.0));
	COLOR = vec4(c, 1.0);
}
