// Shared motion of FX particles (JS FX.update "particles"), computed from the spawn values so a live particle costs the CPU nothing.
// JS each frame: vel.y -= grav * dt; pos += vel * dt; vel *= exp(-1.2 * dt); scale = s0 * (grow > 0 ? 1 + grow * (1 - k) : k); opacity = half * k. Closed form of the same motion.
// MODEL_MATRIX carries data, not a transform: col 0 = v0, col 1 = (t0, life, s0), col 2 = (grow, grav, -), col 3 = p0. COLOR = rgb + half strength.
uniform float now = 0.0;
varying float v_a;

void vertex() {
	float t = now - MODEL_MATRIX[1].x;
	float life = MODEL_MATRIX[1].y;
	if (t < 0.0 || t >= life) {
		VERTEX = vec3(0.0);        // a dead slot collapses to a point: nothing rasterises
		v_a = 0.0;
	} else {
		float k = 1.0 - t / life;
		float grow = MODEL_MATRIX[2].x;
		float s = max(0.001, MODEL_MATRIX[1].z * (grow > 0.0 ? 1.0 + grow * (1.0 - k) : k));
		float e = (1.0 - exp(-1.2 * t)) / 1.2;
		vec3 p = MODEL_MATRIX[3].xyz + MODEL_MATRIX[0].xyz * e;
		p.y -= MODEL_MATRIX[2].y / 1.2 * (t - e);
		VERTEX = (VIEW_MATRIX * vec4(p + VERTEX * s, 1.0)).xyz;
		v_a = COLOR.a * k;
	}
}
