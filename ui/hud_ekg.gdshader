// The integrity monitor's screen (CSS #hp .hpv + .hpcrt): the CRT look of ui/crt.gdshaderinc, with the EKG trace and the energy shield overlay between the glass and the text.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
#include "res://ui/crt.gdshaderinc"
#include "res://ui/ecg.gdshaderinc"

uniform vec4 canvas_rect = vec4(9.6, 30.0, 204.8, 41.0);    // the trace's canvas in the screen, css px
uniform float sh_on = 0.0;      // .hpsh opacity
uniform float sh_w = 0.0;       // the fill's width, 0..1
uniform vec3 sh_col = vec3(0.302, 0.722, 1.0);   // --sh
uniform float sh_bright = 1.0;  // recharging: shrech
uniform float sh_flash = 0.0;   // <u>

void fragment() {
	vec2 css = rect_px / px_scale;
	vec2 p = UV * css;
	vec4 under = vec4(0.0);
	vec2 q = p - canvas_rect.xy;
	if (q.x >= 0.0 && q.y >= 0.0 && q.x < canvas_rect.z && q.y < canvas_rect.w) {
		under = ecg_trace(q, canvas_rect.zw);
	}
	if (sh_on > 0.0) {
		// a coloured fill from the left, screened over the monitor: a hard right edge with a soft shoulder, a bright bar along the bottom
		float w = sh_w * css.x;
		vec3 add = vec3(0.0);
		vec4 bar = vec4(0.0);
		if (p.x < w) {
			add = sh_col * mix(0.55, 0.3, p.x / max(w, 1.0)) * sh_bright;
			if (p.x > w - 3.0) { add = sh_col * sh_bright; }
			if (p.y > css.y - 5.0) {
				bar = vec4(sh_col, 1.0);
			} else {
				float b = crt_shadow(css.y - 5.0 - p.y, 10.0);
				bar = vec4(sh_col * b, b);
			}
		} else if (w > 0.0) {
			add = sh_col * 0.7 * crt_shadow(max(p.x - (w + 4.0), 0.0), 14.0);
		}
		add = vec3(1.0) - (vec3(1.0) - add) * (vec3(1.0) - sh_col * sh_flash * 0.8);
		under.rgb += add * sh_on;
		bar *= sh_on;
		under = vec4(bar.rgb + under.rgb * (1.0 - bar.a), bar.a + under.a * (1.0 - bar.a));
	}
	COLOR = crt_compose(UV, FRAGCOORD.xy, TIME, under);
}
