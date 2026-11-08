// A vendor terminal's CRT, over the menu (JS .pz-crt, .pz-tear): scanlines, a dark edge with a faint glow of the theme's colour, the slow roll, the glitch's tears.
shader_type canvas_item;
render_mode blend_mix;

uniform vec3 pzr = vec3(1.0, 0.22, 0.19);
uniform float css_h = 500.0;     // the view's height in pixels
uniform float flick = 1.0;
uniform float roll = -0.22;
uniform vec3 tear_a = vec3(0.4, 0.02, 0.0);     // y, height, opacity
uniform vec3 tear_b = vec3(0.7, 0.01, 0.0);

void fragment() {
	float y_px = UV.y * css_h;
	// repeating-linear-gradient: black .34 on one row in three
	float scan = mod(floor(y_px), 3.0) < 1.0 ? 0.34 : 0.0;
	// radial 72% 78%: the colour .07 in the middle, black .55 at the edge
	float d = clamp(length((UV - 0.5) / vec2(0.72, 0.78)) * 2.0 * 0.5, 0.0, 1.0);
	vec3 rc = mix(pzr, vec3(0.0), d);
	float ra = mix(0.07, 0.55, d);
	// the roll bar
	float k = (UV.y - roll) / 0.22;
	vec3 c = rc;
	float a = ra;
	if (k > 0.0 && k < 1.0) {
		float b = 0.09 * (k < 0.55 ? k / 0.55 : (1.0 - k) / 0.45);
		c = mix(c, pzr, b / max(a + b, 0.001));
		a = a + b - a * b;
	}
	if (scan > 0.0) {
		c = c * (1.0 - scan) * a / max(a + scan - a * scan, 0.001);
		a = a + scan - a * scan;
	}
	// the tears (screen blended in the JS)
	float t = 0.0;
	if (abs(UV.y - tear_a.x - tear_a.y * 0.5) < tear_a.y * 0.5) {
		t = max(t, tear_a.z * 0.55);
	}
	if (abs(UV.y - tear_b.x - tear_b.y * 0.5) < tear_b.y * 0.5) {
		t = max(t, tear_b.z * 0.55);
	}
	if (t > 0.0) {
		c = mix(c, pzr, t);
		a = max(a, t);
	}
	COLOR = vec4(c, a * flick);
}
