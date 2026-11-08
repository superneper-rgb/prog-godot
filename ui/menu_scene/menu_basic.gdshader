// Main menu backdrop: a lit window or a beacon's core (three.js MeshBasicMaterial with HDR colour and FogExp2).
shader_type spatial;
render_mode unshaded, fog_disabled;
uniform vec3 col = vec3(1.0);
uniform float fog_k = 0.03;
uniform vec3 fog_col = vec3(0.0);

void fragment() {
	ALBEDO = col;
	float d = -VERTEX.z * fog_k;
	FOG = vec4(fog_col, 1.0 - exp(-d * d));
}
