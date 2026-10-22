shader_type canvas_item;
// Névoa do subsolo (0.13): escuridão em volta da nave, com um círculo de visão iluminado
// pela própria nave (borda em degraus, estilo pixel art) e pequenas luzes extras
// (vaga-lumes, onda do sonar, guardião).

uniform vec2 rect_size = vec2(720.0, 1280.0);
uniform vec2 ship_pos = vec2(360.0, 640.0);
uniform float radius = 220.0;
uniform float strength = 0.92;
uniform vec4 fog_color : source_color = vec4(0.012, 0.016, 0.03, 1.0);
uniform int light_count = 0;
uniform vec4 lights[24];   // xy = posição (px de tela), z = raio, w = intensidade

float band(float d, float r) {
	float v = 1.0 - smoothstep(r * 0.5, r, d);
	return floor(v * 6.0 + 0.5) / 6.0;   // degraus
}

void fragment() {
	vec2 p = UV * rect_size;
	// Pixels de 6 px: a borda da luz fica serrilhada como pixel art.
	p = floor(p / 6.0) * 6.0 + 3.0;
	float vis = band(distance(p, ship_pos), radius);
	for (int i = 0; i < 24; i++) {
		if (i >= light_count) break;
		vec4 l = lights[i];
		vis = max(vis, band(distance(p, l.xy), l.z) * l.w);
	}
	COLOR = vec4(fog_color.rgb, strength * (1.0 - vis));
}
