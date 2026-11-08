// Blood droplets (JS _bloodUpdate): gravity 13, no drag, constant size, opaque. MODEL_MATRIX as data: col 0 = v0, col 1 = (t0, life, s), col 3 = p0. life already stops at the floor (FX predicts the landing).
shader_type spatial;
render_mode unshaded, shadows_disabled, skip_vertex_transform;
uniform float now = 0.0;

void vertex() {
	float t = now - MODEL_MATRIX[1].x;
	if (t < 0.0 || t >= MODEL_MATRIX[1].y) {
		VERTEX = vec3(0.0);
	} else {
		vec3 p = MODEL_MATRIX[3].xyz + MODEL_MATRIX[0].xyz * t;
		p.y -= 6.5 * t * t;
		VERTEX = (VIEW_MATRIX * vec4(p + VERTEX * MODEL_MATRIX[1].z, 1.0)).xyz;
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
}
