// The animation viewer's floor (tools/anim_viewer): a dark plate with a metre grid, a fine 25 cm grid and the two axes (green: his forward, +Z; red: his left, +X). Lit, so the feet's shadows read.
shader_type spatial;

varying vec3 wp;
uniform vec2 centre = vec2(0.0);      // where the plate is faded from: the viewer moves the plate along with whoever is chasing about on it

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid(vec2 p) {
	vec2 g = abs(fract(p - 0.5) - 0.5) / max(fwidth(p), vec2(1e-4));
	return 1.0 - min(min(g.x, g.y), 1.0);
}

void fragment() {
	float coarse = grid(wp.xz);
	float fine = grid(wp.xz * 4.0);
	float ax_z = 1.0 - min(abs(wp.x) / max(fwidth(wp.x) * 1.5, 1e-4), 1.0);
	float ax_x = 1.0 - min(abs(wp.z) / max(fwidth(wp.z) * 1.5, 1e-4), 1.0);
	vec3 c = vec3(0.035, 0.038, 0.042) + fine * 0.012 + coarse * 0.05;
	c = mix(c, vec3(0.25, 0.7, 0.35), ax_z * step(0.0, wp.z) * 0.8);
	c = mix(c, vec3(0.75, 0.3, 0.25), ax_x * step(0.0, wp.x) * 0.8);
	float fade = smoothstep(16.0, 5.0, length(wp.xz - centre));
	ALBEDO = mix(vec3(0.03, 0.032, 0.035), c, fade);
	ROUGHNESS = 0.92;
}
