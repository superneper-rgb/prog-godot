// The Deck's running surface (levels/hub/deck_look.gd): wet steel-plate carriageway in the rain. Same layout as the JS canvas (city-deck.js makeSurface: service strips at the
// parapets, white edge lines, the cool dashed centre seam, plate joints), drawn at any distance instead of from a 128 x 256 texture, and wet: polished wheel tracks, puddles that
// ring with the rain, the bay's expansion joint, and the parapet lamps and the sky haze reflected in it. UV: u across the carriageway (0..1), v along it, 12 m per unit.
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled;
#include "res://levels/shaders/flash_light.gdshaderinc"      // the brief lights of play (core/flash_lights.gd)

global uniform vec3 prog_smog;     // FOINT CITY's haze colour (levels/hub/hub_level.gd): what the wet deck mirrors when it mirrors nothing else

const int MAX_LAMPS = 64;
uniform vec4 lamps[MAX_LAMPS];     // xyz = lamp head, w = tint index (0 violet-white, 1 red-white: lamp-zones.js)
uniform int lamp_n = 0;
uniform vec3 tint_a : source_color = vec3(0.66, 0.5, 1.0);
uniform vec3 tint_b : source_color = vec3(1.0, 0.4, 0.56);
uniform float lamp_k = 2.2;        // reflected lamp brightness
uniform float sky_k = 1.6;         // reflected haze brightness
uniform float half_w = 6.65;       // the surface's half width, m (HW - 0.55)

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return s;
}

// rain rings: a ring in each cell that grows and fades on its own clock; returns the slope it gives the water
vec2 ripples(vec2 p, float t) {
	vec2 g = vec2(0.0);
	for (int k = 0; k < 2; k++) {
		vec2 q = p * (k == 0 ? 2.1 : 3.3) + float(k) * 7.3;
		vec2 c = floor(q);
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 cell = c + vec2(float(i), float(j));
				float h = hash12(cell);
				vec2 o = cell + vec2(hash12(cell + 3.1), hash12(cell + 5.7));
				float ph = fract(t * (0.9 + h * 0.5) + h);
				vec2 d = q - o;
				float r = length(d);
				float ring = sin((r - ph * 0.9) * 40.0) * smoothstep(0.08, 0.0, abs(r - ph * 0.9)) * (1.0 - ph);
				g += ring * d / max(r, 1e-3);
			}
		}
	}
	return g;
}

float band(float x, float c, float w, float soft) {
	return 1.0 - smoothstep(w, w + soft, abs(x - c));
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float u = fract(UV.x);
	float along = (1.0 - UV.y) * 12.0;            // (glTF flips v: the export's UV.y is 1 - the JS v)
	bool under = cam.y < wp.y - 0.05;             // seen from the Underline: the export's slab has no bottom face, so this is what you see of the deck's underside
	float x = (u - 0.5) * 2.0 * half_w;          // metres across from the centre line
	float px = fwidth(x) + 0.004;                 // a pixel, in metres: keeps the paint lines from shimmering far away

	// the plate: dark, with aggregate, plate seams and service strips (JS #121219, #1a1a23)
	vec3 base = vec3(0.0060, 0.0060, 0.0095);
	float grit = vnoise(wp.xz * 9.0) * 0.6 + vnoise(wp.xz * 31.0) * 0.4;
	base *= 0.75 + 0.55 * grit;
	float strip = step(half_w - 1.45, abs(x));
	base = mix(base, vec3(0.0105, 0.0105, 0.0150) * (0.85 + 0.3 * vnoise(wp.xz * 4.0)), strip);
	float seam = 1.0 - smoothstep(0.0, 0.035 + px, abs(fract(along / 0.984 + 0.5) - 0.5) * 0.984);
	base *= 1.0 - 0.45 * seam * (1.0 - strip);
	float stain = smoothstep(0.55, 0.85, fbm(wp.xz * 0.35 + 3.0));
	base *= 1.0 - 0.35 * stain;

	// the bay's expansion joint (each bay's v starts at 0 where the one before it ends): a steel finger plate
	float joint = 1.0 - smoothstep(0.16, 0.16 + px, along);
	float fingers = step(0.5, fract(x * 2.5));
	base = mix(base, vec3(0.020, 0.020, 0.026) * (0.7 + 0.5 * fingers), joint);

	// paint, worn where the wheels run: white edge lines, the cool dashed centre seam
	float wear = smoothstep(0.25, 0.75, vnoise(wp.xz * vec2(1.3, 5.0)) * 0.7 + 0.3 * vnoise(wp.xz * 12.0));
	float edge = band(abs(x), half_w * 0.64, 0.1, px);      // (the JS lines at 23/128 and 105/128 across)
	base = mix(base, vec3(0.30, 0.31, 0.34), edge * 0.55 * wear * (1.0 - joint));
	float dash = band(x, 0.0, 0.11, px) * step(0.19, fract(along / 1.5) ) * step(fract(along / 1.5), 0.69);
	base = mix(base, vec3(0.10, 0.30, 0.48), dash * 0.6 * (1.0 - joint));

	// wet: the wheel tracks are polished and hold a skin of water; puddles lie in the ruts and along the gutters
	float lane = abs(abs(x) - half_w * 0.33);
	float track = band(lane, 0.85, 0.28, 0.25);
	float pud_n = fbm(wp.xz * 0.22 + vec2(5.0, 1.0));
	float gutter = smoothstep(half_w - 2.2, half_w - 1.2, abs(x));
	float puddle = smoothstep(0.52, 0.58, pud_n + 0.12 * track + 0.14 * gutter - 0.06 * joint);
	base *= mix(1.0, 0.55, puddle);
	base *= 1.0 - 0.2 * track;

	// the water's surface: rain rings in the puddles, a fine chop everywhere else
	vec2 slope = vec2(vnoise(wp.xz * 6.0 + TIME * 0.5) - 0.5, vnoise(wp.zx * 6.0 - TIME * 0.4) - 0.5) * 0.12;
	slope += ripples(wp.xz, TIME) * 0.05 * puddle;
	vec3 n = normalize(vec3(slope.x, 1.0, slope.y));
	vec3 v = normalize(cam - wp);
	vec3 r = reflect(-v, n);
	float fres = 0.03 + 0.97 * pow(1.0 - max(dot(n, v), 0.0), 5.0);
	float wet = mix(0.35, 1.0, max(puddle, track * 0.7));
	float shine = mix(70.0, 900.0, puddle);       // tight in standing water, smeared on the wet plate

	vec3 col = base + prog_smog * sky_k * fres * wet;
	for (int i = 0; i < MAX_LAMPS; i++) {
		if (i >= lamp_n || under) {
			break;
		}
		vec3 L = lamps[i].xyz - wp;
		float d = length(L);
		if (d > 90.0) {
			continue;
		}
		float s = pow(max(dot(r, L / d), 0.0), shine);
		vec3 tint = lamps[i].w > 0.5 ? tint_b : tint_a;
		col += tint * lamp_k * s * wet * (0.4 + 0.6 * fres) * shine * 0.004 / (1.0 + d * 0.02);
	}
	ALBEDO = (under ? vec3(0.0055, 0.0055, 0.0072) * (0.8 + 0.4 * grit) : col) + flash_light(wp, under ? vec3(0.0, -1.0, 0.0) : n, vec3(0.2));
}
