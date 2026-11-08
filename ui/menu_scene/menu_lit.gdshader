// Main menu backdrop: the yard's solid surfaces (three.js MeshStandardMaterial with FogExp2): tower, wall, tarmac, chain-link.
shader_type spatial;
render_mode cull_disabled, fog_disabled;
uniform sampler2D map : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_normal = false;
uniform vec3 col = vec3(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float rough = 0.8;
uniform float metal = 0.2;
uniform float alpha_test = 0.0;
uniform float fog_k = 0.03;
uniform vec3 fog_col = vec3(0.0);

void fragment() {
	vec4 t = texture(map, UV * uv_scale);
	if (alpha_test > 0.0 && t.a < alpha_test) {
		discard;
	}
	ALBEDO = col * t.rgb;
	ROUGHNESS = rough;
	METALLIC = metal;
	if (has_normal) {
		NORMAL_MAP = texture(normal_map, UV * uv_scale).rgb;
	}
	float d = -VERTEX.z * fog_k;
	FOG = vec4(fog_col, 1.0 - exp(-d * d));
}
