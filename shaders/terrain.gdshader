// DEEPFORGE — terreno orgânico de escavação livre.
// TEXTURE traz as micro-células do chunk (+ halo): r = material/255, g = desgaste (0..1),
// b = camada (bioma)/255, a = 1 sólido / 0 vazio. O campo de solidez é suavizado para
// contornos curvos; tudo é quantizado em pixels de arte de 3 px.
//
// Estilos (coluna 6 da paleta = BlockDef.Art):
//   terreno  : 1 terra, 2 pedra, 5 rocha-mãe, 8 magma, 9 areia, 10 argila, 11 gelo, 12 lama
//   depósitos: 3 metálico, 4 gema, 13 fóssil, 14 veios brilhantes, 15 prisma, 6 baú, 7 artefato
//
// Terrenos com "pele" (skin_tex) usam texturas pixel art repetíveis do atlas, amostradas
// por coordenada de mundo em pixels de arte (estáveis com a câmera, sem suavização) e
// alternadas por ruído de baixa frequência (sem repetição evidente). Os demais usam o
// desenho procedural (terrain_col). Depósitos de 3/4/15 são sprites embutidos (ore_atlas);
// decorações embutidas (raízes, pedrinhas) e fósseis vêm de decor_atlas. Nada disso muda a
// geometria: o campo de solidez, as bordas e a escavação são os mesmos.
shader_type canvas_item;

uniform sampler2D noise_tex : filter_linear, repeat_enable;  // 4 ruídos contínuos
uniform sampler2D palette_tex : filter_nearest;              // linha = material
uniform float cell_px = 12.0;
uniform float sub = 4.0;
uniform float art_px = 3.0;
uniform int halo = 2;
uniform float noise_size = 256.0;
uniform float edge_noise = 0.34;
uniform float domain_warp = 0.55;
uniform float material_warp = 0.7;
uniform int biome_row = 33;
uniform sampler2D terrain_atlas : filter_nearest;  // texturas 64×64, 8 por linha
uniform sampler2D ore_atlas : filter_nearest;      // depósitos 12×12: linha = minério, coluna = variação
uniform sampler2D decor_atlas : filter_nearest;    // decorações 24×24, 8 por linha
uniform sampler2D skin_tex : filter_nearest;       // (bloco, camada) → até 4 índices de textura
uniform sampler2D decor_tex : filter_nearest;      // (sorteio 0..15 | densidade, camada) → decoração
uniform int fossil_first = 21;
uniform float terrain_value = 0.84;                // brilho do terreno texturizado
uniform float terrain_saturation = 0.85;                     // primeira das 4 entradas de fóssil no atlas

const int TILE = 64;
const int ORE_PX = 12;
const int ORE_SITE = 14;
const int DECOR_CELL = 24;
const int EMBED_SITE = 28;

varying vec2 world_pos;
varying vec2 local_pos;

#define CELL(c) texelFetch(TEXTURE, clamp((c) + ivec2(halo), ivec2(0), tsize - ivec2(1)), 0)

const vec3 OUTLINE = vec3(0.05, 0.045, 0.06);

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec3 pal(int col, int row) {
	return texelFetch(palette_tex, ivec2(col, row), 0).rgb;
}

float art_of(int id) {
	return texelFetch(palette_tex, ivec2(6, id), 0).r * 255.0;
}

vec4 nz(vec2 p, float scale, vec2 offset) {
	return texture(noise_tex, p / (noise_size * scale) + offset);
}

// Valores pseudoaleatórios por célula inteira (sem correlação entre vizinhas).
vec4 cell_rand(ivec2 c) {
	ivec2 t = ivec2((c.x * 37 + c.y * 91) & 255, (c.x * 53 + c.y * 17 + 128) & 255);
	return texelFetch(noise_tex, t, 0);
}

// Voronoi: distância ao ponto mais próximo (x), ao segundo (y); rel = pixel − ponto.
vec2 voronoi(vec2 p, out vec2 rel, out vec4 rnd) {
	vec2 ip = floor(p);
	vec2 fp = p - ip;
	float d1 = 8.0;
	float d2 = 8.0;
	rel = vec2(0.0);
	rnd = vec4(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			ivec2 c = ivec2(ip) + ivec2(i, j);
			vec4 r = cell_rand(c);
			vec2 o = vec2(float(i), float(j)) + 0.2 + r.xy * 0.6 - fp;
			float d = length(o);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				rel = -o;
				rnd = r;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(d1, d2);
}

vec3 hue(float h) {
	vec3 k = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return mix(vec3(1.0), k, 0.55);
}

// --- Terreno (base destrutível) ---------------------------------------------------
vec3 terrain_col(int id, vec2 q, vec4 n1, vec4 n2) {
	vec3 base = pal(0, id);
	vec3 dark = pal(1, id);
	vec3 light = pal(2, id);
	float art = art_of(id);
	float t = n1.a;
	vec3 col = t < 0.33 ? dark : (t > 0.7 ? light : base);
	col = mix(col, base, 0.3);

	if (art > 1.5 && art < 2.5 || art > 4.5 && art < 5.5) {
		// Pedra / rocha-mãe: blocos rochosos com relevo (luz no topo-esquerda) e frestas.
		vec2 rel; vec4 rnd;
		vec2 d = voronoi(q / (art > 4.5 ? 26.0 : 20.0), rel, rnd);
		float lit = dot(normalize(rel + vec2(0.0001)), normalize(vec2(-0.7, -0.8)));
		col = mix(base, rnd.z > 0.55 ? light : (rnd.z < 0.4 ? dark : base), 0.45);
		col *= 0.9 + 0.22 * lit * smoothstep(0.1, 0.6, d.x);
		if (d.y - d.x < 0.07) { col = mix(dark, OUTLINE, 0.55); }
		else if (d.y - d.x < 0.12) { col = mix(col, dark, 0.6); }
	} else if (art > 0.5 && art < 1.5) {
		// Terra: manchas, pedrinhas e raízes finas.
		float k = nz(q, 0.12, vec2(0.33, 0.71)).r;
		if (k > 0.74) { col = vec3(0.62, 0.58, 0.54); }
		else if (k > 0.70) { col = vec3(0.42, 0.38, 0.35); }
		float root = abs(nz(q, 0.8, vec2(0.1, 0.4)).g - 0.5);
		if (root < 0.012 && n2.r > 0.5) { col = dark * 0.75; }
	} else if (art > 8.5 && art < 9.5) {
		// Areia: grão fino e estrias de vento.
		float g = nz(q, 0.08, vec2(0.7, 0.2)).b;
		col = mix(base, g > 0.6 ? light : dark, abs(g - 0.5) * 0.9);
		float stripe = sin(q.y * 0.22 + nz(q, 1.5, vec2(0.0)).r * 9.0);
		if (stripe > 0.82) { col = mix(col, light, 0.5); }
		else if (stripe < -0.9) { col = mix(col, dark, 0.4); }
	} else if (art > 9.5 && art < 10.5) {
		// Argila: camadas compactadas horizontais.
		float band = sin(q.y * 0.13 + (n1.g - 0.5) * 6.0);
		col = band > 0.45 ? light : (band < -0.55 ? dark : base);
		if (nz(q, 0.1, vec2(0.4, 0.9)).r > 0.76) { col = mix(col, light, 0.6); }
	} else if (art > 10.5 && art < 11.5) {
		// Gelo: facetas claras com brilho nas bordas.
		vec2 rel; vec4 rnd;
		vec2 d = voronoi(q / 24.0, rel, rnd);
		float lit = dot(normalize(rel + vec2(0.0001)), normalize(vec2(-0.6, -0.8)));
		col = mix(dark, base, 0.55 + 0.45 * lit);
		if (d.y - d.x < 0.05) { col = light; }
		// Um brilho por faceta (algumas), perto do canto iluminado.
		if (rnd.w > 0.7 && length(rel - vec2(-0.18, -0.2)) < 0.07) { col = vec3(0.92, 0.98, 1.0); }
	} else if (art > 11.5 && art < 12.5) {
		// Lama: escura, encharcada, com reflexos úmidos.
		float w = nz(q, 0.35, vec2(0.6, 0.6)).r;
		col = mix(dark, base, smoothstep(0.35, 0.65, w));
		if (nz(q, 0.09, vec2(0.15, 0.85)).b > 0.79) { col = light * 1.15; }
	} else if (art > 7.5 && art < 8.5) {
		// Rocha magmática: veios incandescentes.
		vec3 acc = pal(3, id);
		float k = abs(nz(q, 0.6, vec2(0.7, 0.3)).b - 0.5);
		if (k < 0.022) { col = pal(5, id); } else if (k < 0.05) { col = acc; } else if (k < 0.07) { col = pal(4, id); }
	}
	return col * (0.97 + 0.06 * n2.a);
}

// --- Depósitos coletáveis ------------------------------------------------------------
vec3 deposit_col(int id, float art, vec3 host, vec2 q) {
	vec3 acc = pal(3, id);
	vec3 acc_d = pal(4, id);
	vec3 acc_l = pal(5, id);
	vec2 rel; vec4 rnd;
	if (art > 2.5 && art < 4.5 || art > 14.5) {
		// Rocha hospedeira com raros fragmentos do minério; o depósito em si é um sprite
		// desenhado em fragment(), decidido pela célula do seu centro.
		if (cell_rand(ivec2(floor(q / art_px)) + ivec2(91, 17)).x > 0.965) { return acc_d; }
		return host;
	}
	if (art > 13.5 && art < 14.5) {
		// Rocha escura em placas com fissuras brilhantes (obsidiana, arcano, meteorito).
		vec2 d = voronoi(q / 15.0, rel, rnd);
		float lit = dot(normalize(rel + vec2(0.0001)), normalize(vec2(-0.7, -0.8)));
		vec3 c = mix(pal(1, id), pal(0, id), 0.5 + 0.5 * lit);
		if (lit > 0.6 && d.x > 0.2 && d.x < 0.3) { c = mix(c, acc_l, 0.35); }
		float e = d.y - d.x;
		if (e < 0.05) { c = acc_l; } else if (e < 0.1) { c = acc; } else if (e < 0.16) { c = mix(c, acc_d, 0.6); }
		return c;
	}
	return host;
}

int idx_of(float v) {
	return int(v * 255.0 + 0.5);
}

bool is_terrain_art(float a) {
	return (a > 0.5 && a < 2.5) || (a > 7.5 && a < 12.5);
}

// Terreno: textura do atlas (pele da camada) ou, sem pele, o desenho procedural.
vec3 surface_col(int id, int layer, ivec2 ap, vec2 q, vec4 n1, vec4 n2) {
	vec4 sk = texelFetch(skin_tex, ivec2(id, layer), 0);
	int a = idx_of(sk.r);
	if (a == 255) {
		return terrain_col(id, q, n1, n2);
	}
	int b = idx_of(sk.g);
	int c = idx_of(sk.b);
	int d = idx_of(sk.a);
	// Borda pontilhada entre texturas (nada de emendas retas); hash aritmético, sem leitura.
	float dith = (fract(sin(float(ap.x) * 12.9898 + float(ap.y) * 78.233) * 43758.5453) - 0.5) * 0.08;
	// Uma leitura de ruído: g = manchas grandes (variação), b = manchas menores.
	vec4 sel = nz(q, 1.8, vec2(0.17, 0.53));
	int t = a;
	if (b != 255 && sel.g + dith > 0.52) { t = b; }
	float patch_n = sel.b + dith;
	if (c != 255 && patch_n > 0.7) { t = c; }
	if (d != 255 && patch_n < 0.3) { t = d; }
	ivec2 tp = ivec2(mod(vec2(ap), float(TILE)));
	vec3 col = texelFetch(terrain_atlas, ivec2((t % 8) * TILE, (t / 8) * TILE) + tp, 0).rgb;
	// Terreno um pouco mais escuro e menos saturado que a arte crua: é o fundo destrutível,
	// e minérios/nave precisam se destacar. Variação de tom larga quebra a repetição do tile.
	col = mix(vec3(dot(col, vec3(0.3, 0.55, 0.15))), col, terrain_saturation) * terrain_value;
	return col * (0.94 + 0.12 * n1.g);
}

void fragment() {
	ivec2 tsize = textureSize(TEXTURE, 0);
	vec2 origin = world_pos - local_pos;
	ivec2 ap = ivec2(floor(world_pos / art_px));
	vec2 q = (vec2(ap) + 0.5) * art_px;
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
		ivec2 mcc = ivec2(floor(cf + (n1.gb - 0.5) * material_warp));
		vec4 mc = CELL(mcc);
		if (mc.a < 0.5) { mc = home; mcc = ivec2(floor(cf)); }
		if (mc.a < 0.5) { mc = ca.a > 0.5 ? ca : (cb.a > 0.5 ? cb : (cc.a > 0.5 ? cc : cd)); }
		int id = int(mc.r * 255.0 + 0.5);
		float art = art_of(id);
		int lay = min(idx_of(mc.b), 5);
		bool dep = (art > 2.5 && art < 4.5) || (art > 12.5 && art < 13.5) || art > 14.5;
		if (dep || (art > 13.5 && art < 14.5)) {
			// Rocha hospedeira: material de terreno vizinho mais próximo.
			int host = id;
			for (int k = 0; k < 8; k++) {
				ivec2 o = k == 0 ? ivec2(-1, 0) : k == 1 ? ivec2(1, 0) : k == 2 ? ivec2(0, -1) : k == 3 ? ivec2(0, 1)
					: k == 4 ? ivec2(-2, 0) : k == 5 ? ivec2(2, 0) : k == 6 ? ivec2(0, 2) : ivec2(0, -2);
				vec4 hc = CELL(mcc + o * 2);
				int hid = int(hc.r * 255.0 + 0.5);
				float ha = art_of(hid);
				if (hc.a > 0.5 && (ha < 2.5 || (ha > 4.5 && ha < 5.5) || (ha > 7.5 && ha < 12.5))) { host = hid; break; }
			}
			vec3 host_col = host == id ? pal(1, id) : surface_col(host, lay, ap, q, n1, n2);
			col = deposit_col(id, art, host_col, q);
		} else {
			col = surface_col(id, lay, ap, q, n1, n2);
			// Decorações embutidas (raízes, pedrinhas): só sobre terreno, cortadas pelos túneis.
			ivec2 es = ivec2(floor(vec2(ap) / float(EMBED_SITE)));
			vec4 er = cell_rand(es + ivec2(57, 211));
			if (er.x < texelFetch(decor_tex, ivec2(16, lay), 0).r) {
				ivec2 eorg = es * EMBED_SITE + ivec2(er.yz * 4.99);
				ivec2 lp = ap - eorg;
				if (lp.x >= 0 && lp.y >= 0 && lp.x < DECOR_CELL && lp.y < DECOR_CELL) {
					vec4 ec = CELL(ivec2(floor(((vec2(eorg) + 12.0) * art_px - origin) / cell_px)));
					int di = idx_of(texelFetch(decor_tex, ivec2(int(er.w * 15.99), lay), 0).r);
					if (di != 255 && ec.a > 0.5 && is_terrain_art(art_of(idx_of(ec.r)))) {
						if (fract(er.w * 13.0) > 0.5) { lp.x = DECOR_CELL - 1 - lp.x; }
						vec4 dp = texelFetch(decor_atlas, ivec2((di % 8) * DECOR_CELL + lp.x, (di / 8) * DECOR_CELL + lp.y), 0);
						if (dp.a > 0.5) { col = mix(col, dp.rgb, 0.9); }
					}
				}
			}
		}

		// Depósitos: no máximo um sprite por sítio de 14 pixels de arte. O sprite pertence à
		// célula do seu centro: inteiro (não é recortado pela borda ondulada do material),
		// só os túneis o cortam. Variação e espelhamento por sítio.
		ivec2 os = ivec2(floor(vec2(ap) / float(ORE_SITE)));
		vec4 orr = cell_rand(os + ivec2(311, 173));
		if (orr.x > 0.2) {
			ivec2 oorg = os * ORE_SITE + ivec2(orr.yz * 2.99);
			ivec2 lp = ap - oorg;
			if (lp.x >= 0 && lp.y >= 0 && lp.x < ORE_PX && lp.y < ORE_PX) {
				vec4 oc = CELL(ivec2(floor(((vec2(oorg) + 6.0) * art_px - origin) / cell_px)));
				int oid = idx_of(oc.r);
				int row = idx_of(pal(8, oid).r);
				if (oc.a > 0.5 && row != 255) {
					if (fract(orr.w * 7.0) > 0.5) { lp.x = ORE_PX - 1 - lp.x; }
					vec4 op = texelFetch(ore_atlas, ivec2(int(orr.w * 2.99) * ORE_PX + lp.x, row * ORE_PX + lp.y), 0);
					if (op.a > 0.5) {
						col = op.rgb;
					} else if (pal(7, oid).r > 0.5 && length(vec2(lp) - 5.5) < 7.5) {
						col = mix(col, pal(3, oid), 0.22);  // brilho próprio (urânio, cristal roxo)
					}
				}
			}
		}

		// Especiais desenhados no seu bloco: baú, artefato, fóssil.
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
		} else if (home.a > 0.5 && home_art > 12.5 && home_art < 13.5) {
			// Fóssil: osso, crânio, amonite ou costelas (variação por bloco), 16×16 pixels de arte.
			ivec2 blk = ivec2(floor(cf / sub));
			vec4 fr = cell_rand(blk + ivec2(5, 9));
			int fi = fossil_first + int(fr.x * 3.99);
			ivec2 bp = ivec2(floor(lc * 16.0));
			if (fr.y > 0.5) { bp.x = 15 - bp.x; }
			vec4 fp = texelFetch(decor_atlas, ivec2((fi % 8) * DECOR_CELL + 4 + bp.x, (fi / 8) * DECOR_CELL + 4 + bp.y), 0);
			if (fp.a > 0.5) { col = fp.rgb; }
		}

		// Luz de cima, sombra embaixo, contorno escuro nas bordas.
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
