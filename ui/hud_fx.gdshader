// HUD full-screen tints, all one quad: mode 0 = #hurt / #mind radial vignette, mode 1 = #deadscr (the black closes in around the text), mode 2 = #scope mask + lens.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

uniform int mode = 0;
uniform float opacity = 1.0;
uniform vec4 inner = vec4(0.0);      // colour at `stop`, CSS rgba
uniform vec4 outer = vec4(0.745, 0.059, 0.039, 0.6);
uniform float stop = 0.42;
uniform float k = 0.0;               // deadscr: --k
uniform vec2 rect_px = vec2(1920.0, 1080.0);
uniform float r_px = 500.0;          // scope: --r, real px
uniform vec4 lens_shadow = vec4(0.0, 0.0, 0.0, 0.62);
uniform float lens_blur = 90.0;
uniform float lens_spread = 10.0;

vec4 pre(vec4 c) { return vec4(c.rgb * c.a, c.a); }

void fragment() {
	vec4 out_c = vec4(0.0);
	if (mode == 0) {
		// radial-gradient(ellipse at center, ...): 100% is the ellipse through the corners
		float r = length((UV - 0.5) * 2.0) * 0.70710678;
		float u = clamp((r - stop) / (1.0 - stop), 0.0, 1.0);
		out_c = mix(pre(inner), pre(outer), u);
	} else if (mode == 1) {
		float r = length((UV - 0.5) * 2.0) * 0.70710678;
		float a = (1.0 - k) * 0.5;
		float b = a + 0.36;
		vec4 c0 = pre(vec4(30.0 / 255.0, 0.0, 0.0, 0.4));
		vec4 c1 = vec4(0.0);
		vec4 c2 = pre(vec4(0.0, 0.0, 0.0, 0.93));
		vec4 c3 = vec4(0.0, 0.0, 0.0, 1.0);
		if (r < a) { out_c = mix(c0, c1, r / max(a, 0.0001)); }
		else if (r < b) { out_c = mix(c1, c2, (r - a) / max(b - a, 0.0001)); }
		else { out_c = mix(c2, c3, clamp((r - b) / max(1.0 - b, 0.0001), 0.0, 1.0)); }
	} else {
		vec2 p = (UV - 0.5) * rect_px;
		float d = length(p);
		// the black mask, with a 2 px soft inner edge
		float mask = clamp((d - (r_px - 2.0)) / 2.0, 0.0, 1.0);
		// the lens: inset 0 0 9vmin 1vmin rgba(0,0,0,.62), inset 0 0 0 2px rgba(120,200,230,.35)
		float inner_d = r_px - d;
		float sg = lens_blur * 0.5;
		float sh = clamp(1.0 - (inner_d - lens_spread) / (sg * 2.0), 0.0, 1.0);
		sh = sh * sh * lens_shadow.a;
		vec4 c = vec4(0.0, 0.0, 0.0, sh);
		if (inner_d >= 0.0 && inner_d < 2.0) {
			float a2 = 0.35;
			vec3 rim = vec3(0.471, 0.784, 0.902);
			c = vec4(rim * a2 + c.rgb * (1.0 - a2), a2 + c.a * (1.0 - a2));
		}
		vec4 m = vec4(vec3(0.008, 0.012, 0.016) * mask, mask);
		out_c = vec4(m.rgb + c.rgb * (1.0 - m.a), m.a + c.a * (1.0 - m.a));
	}
	COLOR = out_c * opacity;
}
