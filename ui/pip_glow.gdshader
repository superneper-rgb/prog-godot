// .wh-glow: radial-gradient(ellipse, rgba(70,255,120,.2) 0, rgba(40,200,90,.08) 50%, transparent 75%), over the glass.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

uniform float opacity = 0.85;

void fragment() {
	// CSS ellipse: farthest-corner by default, so 100% is the ellipse through the corners
	float r = length((UV - 0.5) * 2.0) * 0.70710678;
	vec4 a = vec4(vec3(70.0, 255.0, 120.0) / 255.0 * 0.2, 0.2);
	vec4 b = vec4(vec3(40.0, 200.0, 90.0) / 255.0 * 0.08, 0.08);
	vec4 c = r < 0.5 ? mix(a, b, r / 0.5) : mix(b, vec4(0.0), clamp((r - 0.5) / 0.25, 0.0, 1.0));
	COLOR = c * opacity;
}
