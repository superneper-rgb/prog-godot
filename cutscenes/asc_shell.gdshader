// Tommy's aura shell and the shock dome (JS cutscenes/tommy-ascension.js shellMat): a hot rim over crawling noise, additive, both faces. Display-referred in the JS.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, shadows_disabled, cull_disabled, fog_disabled;
uniform float uTime = 0.0;
uniform float uAlpha = 0.0;
uniform vec3 uColor = vec3(1.0);
uniform vec3 uHot = vec3(1.0);

float h21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y); }

void fragment() {
	float f = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - f, 2.0);
	float n = vn(vec2(UV.x * 9.0, UV.y * 4.0 - uTime * 3.2)) * 0.7 + vn(vec2(UV.x * 21.0, UV.y * 9.0 - uTime * 6.0)) * 0.5;
	float a = (rim * 1.2 + 0.05 * n) * uAlpha;
	ALBEDO = pow(max(mix(uColor, uHot, clamp(rim * 0.9 + n * 0.2, 0.0, 1.0)), vec3(0.0)), vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0);
}
