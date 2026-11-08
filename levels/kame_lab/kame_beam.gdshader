// A beam shell of the Kamehameha (JS BEAM_FS): bright where it faces you (core) or at its silhouette (outer skin), noise streaming along it, spiral bands winding round it. Display-referred in the JS.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, shadows_disabled, cull_back, fog_disabled;
uniform float uTime = 0.0;
uniform float uAlpha = 1.0;
uniform float uLen = 1.0;
uniform float uSpiral = 0.0;
uniform float uRim = 1.0;
uniform float uFill = 0.0;
uniform vec3 uColor = vec3(1.0);
uniform vec3 uHot = vec3(1.0);
uniform sampler2D uNoise : filter_linear, repeat_enable;

void fragment() {
	float f = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float along = UV.y * uLen;
	float n = texture(uNoise, vec2(UV.x * 2.0 + uTime * 0.4, along * 0.18 - uTime * 2.6)).r;
	float n2 = texture(uNoise, vec2(UV.x * 3.0 - uTime * 0.7, along * 0.45 - uTime * 6.0)).r;
	float body = uFill * smoothstep(0.0, 0.75, f) + uRim * pow(1.0 - f, 2.0);
	float spi = uSpiral * smoothstep(0.55, 1.0, sin(UV.x * 12.566 + along * 2.2 - uTime * 30.0)) * (0.5 + n2);
	float a = clamp(body * (0.55 + 0.9 * n) + spi, 0.0, 1.6) * uAlpha;
	ALBEDO = pow(max(mix(uColor, uHot, clamp(body * n + spi * 0.6, 0.0, 1.0)), vec3(0.0)), vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0);
}
