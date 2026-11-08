// The implants' particles (JS powers/fireball.js, frost.js stepPool), computed from the spawn values so a live one costs the script nothing. MODEL_MATRIX carries data: col 0 = v0, col 1 = (t0, life, s0), col 2 = (s1, damp, accel up), col 3 = p0. COLOR.r = kind: 0 flame, 1 ember, 2 smoke, 3 mist, 4 flake. Point size capped as the JS caps gl_PointSize.
uniform float now = 0.0;
uniform float dot_mid = 0.35;      // the radial texture's middle stop
uniform float dot_val = 0.6;
varying vec4 v_c;

vec4 kind_colour(float kind, float u) {
	if (kind < 0.5) {
		float f = pow(1.0 - u, 1.2);
		float r = (u < 0.3 ? 1.0 : mix(1.0, 0.3, (u - 0.3) / 0.7)) * f;
		return vec4(r, mix(0.85, 0.06, min(1.0, u * 1.6)) * f, mix(0.5, 0.0, min(1.0, u * 3.0)) * f, 1.0);
	}
	if (kind < 1.5) {
		float f = 1.0 - u;
		return vec4(1.0, 0.55 * f + 0.15, 0.1 * f, f);
	}
	if (kind < 2.5) {
		return vec4(0.1, 0.09, 0.08, 0.5 * sin(PI * u));
	}
	if (kind < 3.5) {
		float f = sin(PI * min(1.0, u * 1.4)) * (1.0 - u);
		return vec4(0.42 * f, 0.62 * f, 0.8 * f, 1.0);
	}
	return vec4(0.92, 0.97, 1.0, 0.85 * (1.0 - u * u));
}

void vertex() {
	float t = now - MODEL_MATRIX[1].x;
	float life = MODEL_MATRIX[1].y;
	if (t < 0.0 || t >= life) {
		VERTEX = vec3(0.0);        // a dead slot collapses to a point: nothing rasterises
		v_c = vec4(0.0);
	} else {
		float u = t / life;
		float k = MODEL_MATRIX[2].y;
		float a = MODEL_MATRIX[2].z;
		float e = (1.0 - exp(-k * t)) / k;
		vec3 v0 = MODEL_MATRIX[0].xyz;
		vec3 p = MODEL_MATRIX[3].xyz + vec3(v0.x, 0.0, v0.z) * e;
		p.y += a / k * t + (v0.y - a / k) * e;
		float kind = COLOR.r * 4.0;
		if (kind > 2.5 && p.y < 0.03 && (v0.y < 0.0 || a < 0.0)) {
			p.y = 0.03;
		}
		float s = mix(MODEL_MATRIX[1].z, MODEL_MATRIX[2].x, u);
		vec4 mv = VIEW_MATRIX * vec4(p, 1.0);
		float px = s * PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y * 0.5 / max(0.05, -mv.z);
		s *= min(1.0, 320.0 / max(px, 0.001));
		VERTEX = mv.xyz + VERTEX * s;
		v_c = kind_colour(kind, u);
	}
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float t = d < dot_mid ? mix(1.0, dot_val, d / dot_mid) : mix(dot_val, 0.0, clamp((d - dot_mid) / (1.0 - dot_mid), 0.0, 1.0));
	float a = v_c.a * t;
	if (a < 0.004) {
		discard;
	}
	ALBEDO = pow(max(v_c.rgb, vec3(0.0)), vec3(2.2));      // (display-referred in the JS)
	ALPHA = a;
}
