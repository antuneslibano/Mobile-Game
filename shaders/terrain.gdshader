// DEEPFORGE — terreno orgânico.
// A grade de blocos (dados do chunk em TEXTURE, 1 texel por célula + halo) é tratada como um
// campo contínuo: contornos arredondados e irregulares, materiais com bordas naturais,
// minérios em pepitas e veios. Quantizado em "pixels de arte" de 3 px para manter a pixel art.
//
// TEXTURE (por chunk): r = id do bloco/255, g = estágio de dano (0..4)/255,
//                      b = bioma/255, a = 1 sólido / 0 vazio.
shader_type canvas_item;

uniform sampler2D noise_tex : filter_linear, repeat_enable;  // 4 ruídos contínuos independentes
uniform sampler2D palette_tex : filter_nearest;              // linha = bloco; colunas = cores
uniform float block_px = 48.0;
uniform float art_px = 3.0;
uniform int halo = 2;
uniform float noise_size = 256.0;
uniform float edge_noise = 0.34;      // irregularidade do contorno (em unidades de solidez)
uniform float domain_warp = 0.2;      // deslocamento do contorno (em células; mantém colisão coerente)
uniform float material_warp = 0.85;   // deformação das bordas entre materiais (em células)
uniform int biome_row = 18;           // primeira linha de fundos de bioma na paleta

varying vec2 world_pos;
varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Lê uma célula (coordenada local do chunk) dos dados em TEXTURE. Macro, pois TEXTURE é
// embutido do fragment() e não pode ser passado para funções em todos os backends.
#define CELL(c) texelFetch(TEXTURE, clamp((c) + ivec2(halo), ivec2(0), tsize - ivec2(1)), 0)

vec3 pal(int col, int row) {
	return texelFetch(palette_tex, ivec2(col, row), 0).rgb;
}

vec4 nz(vec2 p, float scale, vec2 offset) {
	return texture(noise_tex, p / (noise_size * scale) + offset);
}

void fragment() {
	ivec2 tsize = textureSize(TEXTURE, 0);
	vec2 origin = world_pos - local_pos;
	vec2 q = (floor(world_pos / art_px) + 0.5) * art_px;   // centro do pixel de arte
	if (q.y < 0.0) {
		discard;
	}
	vec2 cf = (q - origin) / block_px;                      // coordenada de célula (contínua)
	vec4 n1 = nz(q, 1.0, vec2(0.0));                       // r: bordas, g/b: deformação, a: textura
	vec4 n2 = nz(q, 0.41, vec2(0.31, 0.77));               // detalhe fino

	// Solidez bilinear suavizada entre os 4 centros de célula vizinhos.
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
	s += (n1.r - 0.5) * edge_noise + (n2.r - 0.5) * edge_noise * 0.45;
	vec2 grad = vec2(mix(cb.a - ca.a, cd.a - cc.a, fs.y), mix(cc.a - ca.a, cd.a - cb.a, fs.x));

	ivec2 home_c = ivec2(floor(cf));
	vec4 home = CELL(home_c);
	vec3 col;

	if (s > 0.5) {
		// Material: busca deformada por ruído para bordas naturais entre materiais.
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
		float art = pal(6, id).r * 255.0;

		// Minérios e cristais usam a rocha hospedeira vizinha como fundo e mostram o depósito
		// como um aglomerado que se adensa no centro da célula.
		vec2 mcf = cf + (n1.gb - 0.5) * material_warp;
		float cluster = 1.0 - clamp(length(fract(mcf) - 0.5) * 1.9, 0.0, 1.0);
		if (art > 2.5 && art < 4.5) {
			ivec2 mcc = ivec2(floor(mcf));
			vec4 host = CELL(mcc + ivec2(-1, 0));
			if (host.a < 0.5 || pal(6, int(host.r * 255.0 + 0.5)).r * 255.0 > 2.5) { host = CELL(mcc + ivec2(1, 0)); }
			if (host.a < 0.5 || pal(6, int(host.r * 255.0 + 0.5)).r * 255.0 > 2.5) { host = CELL(mcc + ivec2(0, -1)); }
			if (host.a > 0.5 && pal(6, int(host.r * 255.0 + 0.5)).r * 255.0 < 2.5) {
				int hid = int(host.r * 255.0 + 0.5);
				base = pal(0, hid);
				dark = pal(1, hid);
				light = pal(2, hid);
			}
		}

		float t = n1.a;
		col = t < 0.33 ? dark : (t > 0.7 ? light : base);
		col = mix(col, base, 0.25);                             // contraste moderado
		col *= 0.97 + 0.06 * n2.a;                              // grão suave

		if (art > 2.5 && art < 3.5) {            // minério: pepitas
			float k = nz(q, 0.3, vec2(0.5, 0.1)).r + cluster * 0.38;
			if (k > 0.84) { col = acc_l; } else if (k > 0.72) { col = acc; } else if (k > 0.67) { col = acc_d; }
		} else if (art > 3.5 && art < 4.5) {     // cristal: lascas verticais
			float k = texture(noise_tex, vec2(q.x / (noise_size * 0.08), q.y / (noise_size * 0.45)) + vec2(0.2, 0.6)).g + cluster * 0.3;
			if (k > 0.9) { col = acc_l; } else if (k > 0.8) { col = acc; } else if (k > 0.75) { col = acc_d; }
		} else if (art > 7.5) {                  // magma: veios incandescentes
			float k = abs(nz(q, 0.6, vec2(0.7, 0.3)).b - 0.5);
			if (k < 0.022) { col = acc_l; } else if (k < 0.05) { col = acc; } else if (k < 0.07) { col = acc_d; }
		} else if (art > 4.5 && art < 5.5) {     // rocha-mãe: fissuras escuras
			float k = abs(n2.b - 0.5);
			if (k < 0.03) { col = dark * 0.7; }
		}

		// Especiais desenhados na própria célula.
		int home_id = int(home.r * 255.0 + 0.5);
		float home_art = pal(6, home_id).r * 255.0;
		vec2 lc = fract(cf);
		if (home.a > 0.5 && home_art > 5.5 && home_art < 6.5) {        // baú
			if (lc.x > 0.16 && lc.x < 0.84 && lc.y > 0.3 && lc.y < 0.84) {
				vec3 hb = pal(0, home_id);
				vec3 hd = pal(1, home_id);
				vec3 hg = pal(3, home_id);
				col = mod(floor(lc.y * 16.0), 3.0) < 1.0 ? hb * 0.8 : hb;
				if (lc.x < 0.22 || lc.x > 0.78 || lc.y < 0.36 || lc.y > 0.78) { col = hd; }
				if (abs(lc.y - 0.5) < 0.04) { col = hg * 0.8; }
				if (abs(lc.x - 0.5) < 0.06 && lc.y > 0.46 && lc.y < 0.64) { col = hg; }
			}
		} else if (home.a > 0.5 && home_art > 6.5 && home_art < 7.5) { // artefato: glifo
			float d = length(lc - 0.5);
			vec3 ha = pal(3, home_id);
			if (d < 0.1) { col = pal(5, home_id); } else if (d > 0.24 && d < 0.32) { col = ha; }
		}

		// Luz de cima nas superfícies expostas, sombra embaixo e contorno escuro.
		float edge = s - 0.5;
		if (dot(grad, grad) > 0.0001) {
			float lit = dot(normalize(grad), normalize(vec2(0.3, 1.0)));
			float rim = 1.0 - smoothstep(0.0, 0.16, edge);
			col = mix(col, col * (1.0 + 0.5 * lit), rim);
			col = mix(col, col * 0.42, 1.0 - smoothstep(0.0, 0.035, edge));
		}

		// Rachaduras progressivas no bloco danificado.
		float stage = home.g * 255.0;
		if (stage > 0.5 && home.a > 0.5) {
			float k = abs(nz(q, 0.33, vec2(0.13, 0.41)).b - 0.5);
			float reach = 0.16 + stage * 0.09;
			if (k < 0.012 + stage * 0.007 && length(lc - 0.5) < reach) {
				col *= 0.28;
			}
		}
	} else {
		// Vazio escavado/caverna: parede de fundo do bioma com oclusão perto da rocha.
		int row = biome_row + int(home.b * 255.0 + 0.5);
		float t = n1.a;
		col = t < 0.38 ? pal(1, row) : (t > 0.78 ? pal(2, row) : pal(0, row));
		col *= 1.0 - 0.6 * smoothstep(0.0, 0.5, s);
		// Sombra projetada sob saliências (rocha acima).
		col *= 1.0 - 0.25 * clamp(-grad.y, 0.0, 1.0) * smoothstep(0.1, 0.5, s);
	}
	COLOR = vec4(col, 1.0);
}
