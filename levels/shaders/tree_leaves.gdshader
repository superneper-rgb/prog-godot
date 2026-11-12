// Leaves for FOINT CITY's trees and shrubs (levels/hub/city_trees.gd). Each card is a cluster of painted leaves cut out here, so a canopy's edge breaks up into leaves instead of a hull.
// leaf_kind 0: pointed ovals with a midrib (the street trees, the shrubs); 1: fans with a notch (the planters' columnar trees).
// Per vertex (COLOR): r = how far out in the crown (0 the dark core, 1 the sunlit shell), g = the card's seed, b = its flutter phase. Per tree (INSTANCE_CUSTOM): x = how far towards col_alt, y = brightness.
// Far away a leaf is smaller than a pixel: the card fades to its round blob instead, so the canopy does not shimmer.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

#include "res://levels/shaders/tree_wind.gdshaderinc"

uniform int leaf_kind = 0;
uniform float cells = 4.0;            // leaves across a card
uniform vec3 col_dark : source_color = vec3(0.04, 0.12, 0.1);
uniform vec3 col_light : source_color = vec3(0.2, 0.42, 0.22);
uniform vec3 col_tip : source_color = vec3(0.55, 0.7, 0.3);
uniform vec3 col_alt : source_color = vec3(0.3, 0.42, 0.16);
uniform float alt_amount = 1.0;
uniform float fill = 0.2;             // the city's baked fill, so a canopy reads at night away from the lamps
uniform vec3 sky_tint : source_color = vec3(0.16, 0.1, 0.26);      // the smog sky's glow on the tops
uniform float flutter = 0.03;

varying float v_shade;
varying float v_seed;
varying float v_alt;
varying float v_bright;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 h22(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

void vertex() {
	vec3 at = MODEL_MATRIX[3].xyz;
	VERTEX += vec3(wind_dir.x, 0.7, wind_dir.y) * flutter * wind * sin(TIME * 6.3 + COLOR.b * 40.0 + at.x * 0.7) * step(0.6, VERTEX.y);
	VERTEX = tree_bend(VERTEX, at, TIME);
	v_shade = COLOR.r;
	v_seed = COLOR.g;
	v_alt = INSTANCE_CUSTOM.x;
	v_bright = INSTANCE_CUSTOM.y > 0.0 ? INSTANCE_CUSTOM.y : 1.0;
}

void fragment() {
	vec2 uv = UV * cells;
	vec2 ci = floor(uv);
	float aa = max(max(fwidth(uv.x), fwidth(uv.y)), 1e-4);      // (both ways: a card seen edge-on blurs along one only)
	float cover = 0.0;
	float lshade = 0.5;
	float rib = 0.0;
	float along = 0.5;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = ci + vec2(float(i), float(j));
			vec2 r = h22(c + v_seed * 17.0);
			vec2 ctr = c + 0.2 + 0.6 * r;
			if (length(ctr / cells - 0.5) > 0.42) {
				continue;      // only leaves inside the card's round cluster
			}
			float ang = h21(c * 1.7 + v_seed * 9.1) * 6.2831853;
			vec2 d = uv - ctr;
			vec2 q = vec2(cos(ang) * d.x + sin(ang) * d.y, -sin(ang) * d.x + cos(ang) * d.y);
			float k = 0.0;
			float x = 0.5;
			if (leaf_kind == 0) {
				float L = 1.05;
				x = q.x / L + 0.5;
				float hw = 0.3 * pow(max(sin(3.14159 * clamp(x, 0.0, 1.0)), 0.0), 0.7);
				k = (1.0 - smoothstep(hw - aa, hw + aa, abs(q.y))) * step(0.0, x) * step(x, 1.0);
				rib = max(rib, k * (1.0 - smoothstep(0.0, 0.035 + aa, abs(q.y))) * step(0.15, x));
			} else {
				vec2 b = q + vec2(0.45, 0.0);      // the fan opens from its stalk
				float rho = length(b);
				float th = atan(b.y, b.x);
				x = rho / 0.85;
				k = (1.0 - smoothstep(0.82 - aa, 0.82 + aa, rho)) * (1.0 - smoothstep(0.72 - aa * 2.0, 0.72 + aa * 2.0, abs(th))) * step(0.08, rho);
				k *= 1.0 - (1.0 - smoothstep(0.04, 0.07, abs(th))) * smoothstep(0.55, 0.65, rho);      // the notch
				k = max(k, (1.0 - smoothstep(0.02, 0.02 + aa, abs(q.y))) * step(-0.75, q.x) * step(q.x, -0.4));   // the stalk
			}
			if (k > cover) {
				cover = k;
				lshade = h21(c + 3.3 + v_seed);
				along = x;
			}
		}
	}
	float px = aa;      // cells per pixel: past ~0.2 a leaf is a smudge
	float blob = 1.0 - smoothstep(0.38, 0.46, length(UV - 0.5));
	float a = mix(cover, blob, smoothstep(0.06, 0.2, px));
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;

	vec3 lightc = mix(col_light, col_alt, clamp(v_alt, 0.0, 1.0) * alt_amount);
	vec3 c = mix(col_dark, lightc, v_shade);
	c = mix(c, col_tip, smoothstep(0.7, 1.0, v_shade) * 0.5 * (0.6 + 0.4 * along));
	c *= (0.82 + 0.36 * lshade) * (1.0 - 0.3 * rib) * v_bright;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;      // (both faces of a card take the crown's normal)
	}
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	ALBEDO = c;
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
	BACKLIGHT = c * 0.6;      // a lamp behind the canopy glows through it
	EMISSION = c * fill + sky_tint * max(wn.y, 0.0) * 0.18 * v_shade;
}
