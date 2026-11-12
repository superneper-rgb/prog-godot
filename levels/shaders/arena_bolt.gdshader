// FOINT DOME's edge lightning (JS lightning.js + the morph targets in arena.js): one of four jagged shapes picked per flash, from the same noise; the JS draw range that grows the bolt becomes a reveal along the arc.
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 base = vec3(1.0);
uniform vec3 emit = vec3(0.0);
instance uniform float seed_ = 0.0;
instance uniform float shape = 0.0;
instance uniform float reveal = 2.0;
instance uniform float opacity = 0.0;
instance uniform float emit_k = 0.0;

varying float v_u;

float noise(float n) {
	float h = sin(n * 127.1 + seed_ * 311.7 + shape * 231.3) * 43758.5453;
	return (h - floor(h)) * 2.0 - 1.0;
}

void vertex() {
	float x = VERTEX.x;
	float z = VERTEX.z;
	float r = max(length(vec2(x, z)), 0.001);
	float u = clamp((r - 24.45) / 5.36, 0.0, 1.0);
	float node = u * 14.0;
	float lo = floor(node);
	float f = node - lo;
	float env = sin(u * 3.14159265);
	float off = (noise(lo) * (1.0 - f) + noise(lo + 1.0) * f) * 0.14 * env;
	VERTEX.x += off * z / r;
	VERTEX.y += (noise(lo + 47.0) * (1.0 - f) + noise(lo + 48.0) * f) * 0.07 * env;
	VERTEX.z += -off * x / r;
	v_u = u;
}

void fragment() {
	if (v_u > reveal) {
		discard;
	}
	ALBEDO = base + emit * emit_k;
	ALPHA = clamp(opacity, 0.0, 1.0);
}
