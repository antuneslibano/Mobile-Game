// DEEPFORGE — terreno orgânico de escavação livre.
// TEXTURE traz as micro-células do chunk (+ halo): r = material/255, g = desgaste (0..1),
// b = bioma/255, a = 1 sólido / 0 vazio. O campo de solidez é suavizado (bilinear com
// smoothstep + ruído) para contornos curvos; o desenho é quantizado em pixels de arte de 3 px.
shader_type canvas_item;

uniform sampler2D noise_tex : filter_linear, repeat_enable;  // 4 ruídos contínuos
uniform sampler2D palette_tex : filter_nearest;              // linha = material
uniform float cell_px = 12.0;
uniform float sub = 4.0;              // micro-células por bloco (para especiais)
uniform float art_px = 3.0;
uniform int halo = 2;
uniform float noise_size = 256.0;
uniform float edge_noise = 0.34;
uniform float domain_warp = 0.55;     // em células
uniform float material_warp = 0.7;    // em células
uniform int biome_row = 18;

varying vec2 world_pos;
varying vec2 local_pos;

#define CELL(c) texelFetch(TEXTURE, clamp((c) + ivec2(halo), ivec2(0), tsize - ivec2(1)), 0)

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec3 pal(int col, int row) {
	return texelFetch(palette_tex, ivec2(col, row), 0).rgb;
}

vec4 nz(vec2 p, float scale, vec2 offset) {
	return texture(noise_tex, p / (noise_size * scale) + offset);
}

float art_of(int id) {
	return texelFetch(palette_tex, ivec2(6, id), 0).r * 255.0;
}

void fragment() {
	ivec2 tsize = textureSize(TEXTURE, 0);
	vec2 origin = world_pos - local_pos;
	vec2 q = (floor(world_pos / art_px) + 0.5) * art_px;
	if (q.y < 0.0) {
		discard;
	}
	vec2 cf = (q - origin) / cell_px;
	vec4 n1 = nz(q, 1.0, vec2(0.0));
	vec4 n2 = nz(q, 0.41, vec2(0.31, 0.77));

	vec2 g = cf + (n1.gb - 0.5) * domain_warp - 0.5;
	vec2 fl = floor(g);
	ivec2 c0 = ivec2(fl);
	vec2 f = g - fl;
	vec4 ca = CELL(c0);
	vec4 cb = CELL(c0 + ivec2(1, 0));
	vec4 cc = CELL(c0 + ivec2(0, 1));
	vec4 cd = CELL(c0 + ivec2(1, 1));
	vec2 fs = f * f * (3.0 - 2.0 * f);
	float s = mix(mix(ca.a, cb.a, fs.x), mix(cc.a, cd.a, fs.x), fs.y);
	s += (n1.r - 0.5) * edge_noise + (n2.r - 0.5) * edge_noise * 0.4;
	vec2 grad = vec2(mix(cb.a - ca.a, cd.a - cc.a, fs.y), mix(cc.a - ca.a, cd.a - cb.a, fs.x));

	vec4 home = CELL(ivec2(floor(cf)));
	vec3 col;

	if (s > 0.5) {
		vec4 mc = CELL(ivec2(floor(cf + (n1.gb - 0.5) * material_warp)));
		if (mc.a < 0.5) { mc = home; }
		if (mc.a < 0.5) { mc = ca.a > 0.5 ? ca : (cb.a > 0.5 ? cb : (cc.a > 0.5 ? cc : cd)); }
		int id = int(mc.r * 255.0 + 0.5);
		vec3 base = pal(0, id);
		vec3 dark = pal(1, id);
		vec3 light = pal(2, id);
		vec3 acc = pal(3, id);
		vec3 acc_d = pal(4, id);
		vec3 acc_l = pal(5, id);
		float art = art_of(id);

		float t = n1.a;
		col = t < 0.33 ? dark : (t > 0.7 ? light : base);
		col = mix(col, base, 0.25);
		col *= 0.97 + 0.06 * n2.a;

		if (art > 2.5 && art < 3.5) {            // minério: pepitas
			float k = nz(q, 0.3, vec2(0.5, 0.1)).r;
			if (k > 0.66) { col = acc_l; } else if (k > 0.56) { col = acc; } else if (k > 0.51) { col = acc_d; }
		} else if (art > 3.5 && art < 4.5) {     // cristal: lascas verticais
			float k = texture(noise_tex, vec2(q.x / (noise_size * 0.08), q.y / (noise_size * 0.45)) + vec2(0.2, 0.6)).g;
			if (k > 0.7) { col = acc_l; } else if (k > 0.6) { col = acc; } else if (k > 0.55) { col = acc_d; }
		} else if (art > 7.5) {                  // magma: veios incandescentes
			float k = abs(nz(q, 0.6, vec2(0.7, 0.3)).b - 0.5);
			if (k < 0.022) { col = acc_l; } else if (k < 0.05) { col = acc; } else if (k < 0.07) { col = acc_d; }
		} else if (art > 4.5 && art < 5.5) {     // rocha-mãe: fissuras escuras
			if (abs(n2.b - 0.5) < 0.03) { col = dark * 0.7; }
		}

		// Especiais (baú, artefato) desenhados no seu bloco.
		int home_id = int(home.r * 255.0 + 0.5);
		float home_art = art_of(home_id);
		vec2 lc = fract(cf / sub);
		if (home.a > 0.5 && home_art > 5.5 && home_art < 6.5) {
			vec3 hb = pal(0, home_id);
			vec3 hd = pal(1, home_id);
			vec3 hg = pal(3, home_id);
			if (lc.x > 0.12 && lc.x < 0.88 && lc.y > 0.24 && lc.y < 0.88) {
				col = mod(floor(lc.y * 16.0), 3.0) < 1.0 ? hb * 0.8 : hb;
				if (lc.x < 0.18 || lc.x > 0.82 || lc.y < 0.3 || lc.y > 0.82) { col = hd; }
				if (abs(lc.y - 0.47) < 0.04) { col = hg * 0.8; }
				if (abs(lc.x - 0.5) < 0.06 && lc.y > 0.43 && lc.y < 0.62) { col = hg; }
			}
		} else if (home.a > 0.5 && home_art > 6.5 && home_art < 7.5) {
			float d = length(lc - 0.5);
			if (d < 0.1) { col = pal(5, home_id); } else if (d > 0.24 && d < 0.32) { col = pal(3, home_id); }
		}

		// Luz de cima, sombra embaixo, contorno escuro.
		float edge = s - 0.5;
		if (dot(grad, grad) > 0.0001) {
			float lit = dot(normalize(grad), normalize(vec2(0.3, 1.0)));
			float rim = 1.0 - smoothstep(0.0, 0.16, edge);
			col = mix(col, col * (1.0 + 0.5 * lit), rim);
			col = mix(col, col * 0.42, 1.0 - smoothstep(0.0, 0.035, edge));
		}

		// Desgaste: material sendo raspado pela broca escurece e racha.
		float worn = home.g;
		if (worn > 0.0 && home.a > 0.5) {
			col *= 1.0 - 0.3 * worn;
			float k = abs(nz(q, 0.33, vec2(0.13, 0.41)).b - 0.5);
			if (k < 0.01 + worn * 0.03) { col *= 0.35; }
		}
	} else {
		int row = biome_row + int(home.b * 255.0 + 0.5);
		float t = n1.a;
		col = t < 0.38 ? pal(1, row) : (t > 0.78 ? pal(2, row) : pal(0, row));
		col *= 1.0 - 0.6 * smoothstep(0.0, 0.5, s);
		col *= 1.0 - 0.25 * clamp(-grad.y, 0.0, 1.0) * smoothstep(0.1, 0.5, s);
	}
	COLOR = vec4(col, 1.0);
}
