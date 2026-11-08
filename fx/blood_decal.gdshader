// Floor splats (JS _bloodSplat, _bloodUpdate): pop out over 0.2 s, fade over the last `fade` seconds of their life. INSTANCE_CUSTOM = (t0, life, size). Lit like the JS Lambert material.
shader_type spatial;
render_mode blend_mix, depth_draw_never, diffuse_lambert, specular_disabled, shadows_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float now = 0.0;
uniform float fade = 5.0;
varying float v_a;

void vertex() {
	float t = now - INSTANCE_CUSTOM.x;
	float rem = INSTANCE_CUSTOM.y - t;
	if (t < 0.0 || rem <= 0.0) {
		VERTEX = vec3(0.0);
		v_a = 0.0;
	} else {
		float g = min(1.0, t / 0.2);
		VERTEX *= INSTANCE_CUSTOM.z * (0.3 + 0.7 * g * (2.0 - g));
		v_a = rem < fade ? max(0.0, 0.92 * rem / fade) : 0.92;
	}
}

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb;
	ALPHA = c.a * v_a;
	ROUGHNESS = 1.0;
}
