// Cutscene particles computed from their spawn values (the JS's script-stepped point pools, as powers/power_puffs): MODEL_MATRIX carries data: col 0 = v0, col 1 = (t0, life, s0), col 2 = (s1, damp, accel up), col 3 = p0. style 0 (tommy-ascension.js): COLOR is the colour and peak alpha; style 1 (kamehameha.js): COLOR.r * 4 = kind: 0 spark, 1 inward streak, 2 aura flame, 3 dust, 4 smoke.
uniform float now = 0.0;
uniform int style = 0;
uniform float dot_val = 0.45;      // the round dot's middle stop, at 35%
uniform float max_px = 420.0;
varying vec4 v_c;

void vertex() {
	float t = now - MODEL_MATRIX[1].x;
	float life = MODEL_MATRIX[1].y;
	if (t < 0.0 || t >= life) {
		VERTEX = vec3(0.0);        // a dead slot collapses to a point: nothing rasterises
		v_c = vec4(0.0);
	} else {
		float u = t / life;
		float k = max(MODEL_MATRIX[2].y, 0.0001);
		float a = MODEL_MATRIX[2].z;
		float e = (1.0 - exp(-k * t)) / k;
		vec3 v0 = MODEL_MATRIX[0].xyz;
		vec3 p = MODEL_MATRIX[3].xyz + vec3(v0.x, 0.0, v0.z) * e;
		p.y += a / k * t + (v0.y - a / k) * e;
		float s = mix(MODEL_MATRIX[1].z, MODEL_MATRIX[2].x, u);
		vec4 mv = VIEW_MATRIX * vec4(p, 1.0);
		float px = s * PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y * 0.5 / max(0.05, -mv.z);
		s *= min(1.0, max_px / max(px, 0.001));
		VERTEX = mv.xyz + VERTEX * s;
		if (style == 0) {
			v_c = vec4(COLOR.rgb, (u < 0.12 ? u / 0.12 : 1.0) * (1.0 - u) * COLOR.a);
		} else {
			float kd = COLOR.r * 4.0;
			if (kd > 3.5) {
				v_c = vec4(0.12, 0.12, 0.15, 0.55 * sin(PI * min(1.0, u * 1.4)));
			} else if (kd > 2.5) {
				v_c = vec4(0.42, 0.38, 0.33, 0.45 * sin(PI * u));
			} else {
				float f = (kd > 0.5 && kd < 1.5) ? sin(PI * u) : pow(1.0 - u, 1.3);
				v_c = vec4(mix(1.0, 0.35, u) * f, mix(1.0, 0.7, u) * f, f, 1.0);
			}
		}
	}
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float r = d < 0.35 ? mix(1.0, dot_val, d / 0.35) : mix(dot_val, 0.0, clamp((d - 0.35) / 0.65, 0.0, 1.0));
	float a = v_c.a * r;
	if (a < 0.004) {
		discard;
	}
	ALBEDO = pow(max(v_c.rgb, vec3(0.0)), vec3(2.2));      // (display-referred in the JS)
	ALPHA = a;
}
