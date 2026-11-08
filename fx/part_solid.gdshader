// Solid tumbling particles (brass, shells, spent magazines): JS FX "solid" parts: gravity without drag, a spin, and they stop dead at y = 0.03. Flat shaded Lambert like the JS materials.
// MODEL_MATRIX as data: col 0 = v0, col 1 = (t0, life, s0), col 2 = (grav, rot x, rot y), col 3 = p0. INSTANCE_CUSTOM = (spin x, spin y, spin z, rot z).
shader_type spatial;
render_mode skip_vertex_transform, diffuse_lambert, specular_disabled, shadows_disabled;
uniform float now = 0.0;

mat3 euler_xyz(vec3 r) {       // three.js order: Rx * Ry * Rz
	float cx = cos(r.x), sx = sin(r.x), cy = cos(r.y), sy = sin(r.y), cz = cos(r.z), sz = sin(r.z);
	mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cx, sx), vec3(0.0, -sx, cx));
	mat3 ry = mat3(vec3(cy, 0.0, -sy), vec3(0.0, 1.0, 0.0), vec3(sy, 0.0, cy));
	mat3 rz = mat3(vec3(cz, sz, 0.0), vec3(-sz, cz, 0.0), vec3(0.0, 0.0, 1.0));
	return rx * ry * rz;
}

void vertex() {
	float t = now - MODEL_MATRIX[1].x;
	float life = MODEL_MATRIX[1].y;
	if (t < 0.0 || t >= life) {
		VERTEX = vec3(0.0);
	} else {
		float k = 1.0 - t / life;
		float s = max(0.001, MODEL_MATRIX[1].z * min(1.0, k * 5.0));
		vec3 p0 = MODEL_MATRIX[3].xyz;
		vec3 v0 = MODEL_MATRIX[0].xyz;
		float g = MODEL_MATRIX[2].x;
		// when it reaches the floor plane: position and spin stop there
		float disc = v0.y * v0.y + 2.0 * g * max(0.0, p0.y - 0.03);
		float hit = g > 0.0 ? (v0.y + sqrt(max(0.0, disc))) / g : 1e6;
		float te = min(t, hit);
		vec3 p = p0 + v0 * te;
		p.y = max(0.03, p.y - 0.5 * g * te * te);
		mat3 r = euler_xyz(vec3(MODEL_MATRIX[2].y, MODEL_MATRIX[2].z, INSTANCE_CUSTOM.w) + INSTANCE_CUSTOM.xyz * te);
		VERTEX = (VIEW_MATRIX * vec4(p + r * (VERTEX * s), 1.0)).xyz;
	}
}

void fragment() {
	NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
