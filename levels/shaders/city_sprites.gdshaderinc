// The city's loose sprites (JS CityView.update + levels/hub/sprite-field.js): neon halos, wall fixtures, dead signals, steam puffs, lamp heads. Everything the JS animates sprite by sprite in script is written here in closed form, on the same clock as CityLife.t, so nothing runs per sprite in script.
// One instance per sprite. Instance origin = where it stands, COLOR = colour and base opacity, INSTANCE_CUSTOM = size x, size y, kind, p0. The instance's basis is not a rotation: it carries the rest of the numbers (column 0 = p1, p2, p3; column 1 x = p4).
//   kind 0 nothing   1 neon: p0 rate, p1 ph, p2 gate   2 wall fixture: p0 fail, p1 ph   3 dead signal   4 steam puff: p0 t, p1 sp0, p2 dx, p3 y0, p4 rise   5 lamp head: p0 bad, p1 base

uniform sampler2D map : source_color, filter_linear_mipmap;
uniform float t = 0.0;         // CityLife.t
uniform float bad_k = 1.0;     // the dying lamp's k this frame (CityLife: it has random dips, and its light has to dip with its glow)

varying vec4 vCol;
varying vec2 vUv;

void vertex() {
	vUv = UV;
	vec4 C = INSTANCE_CUSTOM;
	vec3 q = MODEL_MATRIX[0].xyz;
	vec3 p = MODEL_MATRIX[3].xyz;
	vec2 sc = C.xy;
	float a = COLOR.a;
	int kind = int(C.z + 0.5);
	if (kind == 1) {                // neon: slow breathing with the odd stutter
		float k = 0.9 + 0.1 * sin(t * C.w * 6.0 + q.x);
		if (q.y > 0.0 && sin(t * 13.0 + q.x) * sin(t * 3.1 + q.x * 2.0) > q.y) {
			k = 0.25;
		}
		a *= k;
	} else if (kind == 2) {         // wall lamps hum; two of them fail in bursts
		float k = 0.96 + 0.04 * sin(t * 2.7 + q.x);
		if (C.w > 0.5) {
			bool bur = sin(t * 0.7 + q.x) * sin(t * 0.29 + q.x) > 0.6;
			k = bur && sin(t * 29.0 + q.x) * sin(t * 6.1) > 0.4 ? 0.2 : 1.0;
		}
		a *= k;
	} else if (kind == 3) {         // dead signals flash amber
		if (mod(t, 1.3) >= 0.75) {
			sc = vec2(0.0);
		}
	} else if (kind == 4) {         // steam (JS q.t = (q.t + dt * 0.28 * q.sp0) % 1, as one expression)
		float u = fract(C.w + t * 0.28 * q.x);
		p = vec3(p.x + q.y * u, q.z + u * MODEL_MATRIX[1].x, p.z);
		sc = vec2(0.7 + u * 2.4);
		a = sin(u * PI) * 0.34;
	} else if (kind == 5) {         // lamps: one is dying, the rest hum
		a *= C.w > 0.5 ? bad_k : 1.0 + sin(t * 3.0 + q.x) * 0.015;
	}
	vCol = vec4(COLOR.rgb, a);
	vec3 c = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	VERTEX = c + vec3(VERTEX.xy * sc, 0.0);
}
