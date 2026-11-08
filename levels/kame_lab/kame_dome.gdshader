// An energy bubble of the Kamehameha (JS DOME_FS: the aura round the body, the explosion dome): a glowing rim, a faint fill, noise crawling over it. Display-referred in the JS.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, shadows_disabled, cull_back, fog_disabled;
uniform float uTime = 0.0;
uniform float uAlpha = 1.0;
uniform float uRim = 1.0;
uniform float uFill = 0.0;
uniform vec3 uColor = vec3(1.0);
uniform vec3 uHot = vec3(1.0);
uniform sampler2D uNoise : filter_linear, repeat_enable;

void fragment() {
	float f = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float n = texture(uNoise, vec2(UV.x * 3.0 + uTime * 0.25, UV.y * 2.0 - uTime * 0.9)).r;
	float rim = pow(1.0 - f, 2.6) * uRim;
	float a = (rim + uFill * (0.4 + n) * f) * uAlpha;
	ALBEDO = pow(max(mix(uColor, uHot, clamp(rim * 0.8 + uFill * f * n, 0.0, 1.0)), vec3(0.0)), vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0);
}
