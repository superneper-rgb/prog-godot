// The phosphor look every CRT screen shares (CSS .pc-crt / .pc-view / .hpcrt / .hacrt / .pz-crt): the view texture over a dark radial glass, its glow, the vignette, scanlines,
// a rolling bar, flicker, inset light, grain, tube curvature, and the random glitch (ui/crt_screen.gd steps the keys and sets the g_ uniforms). Every size is in css px
// (px_scale = real pixels per css px, scanlines stay on real pixels as in the browser). The view is premultiplied, because a SubViewport with a clear background stores it so.
uniform sampler2D view : filter_linear, repeat_disable;
uniform vec2 rect_px = vec2(600.0, 440.0);        // this screen on the window, real pixels
uniform float px_scale = 1.0;
uniform float view_mip = 0.0;

// the glass behind the picture: radial-gradient(ellipse 85% 85% at 50% 50%, #052010, #010a04)
uniform vec4 bg_center = vec4(0.0196, 0.1255, 0.0627, 1.0);
uniform vec4 bg_edge = vec4(0.0039, 0.0392, 0.0157, 1.0);
uniform vec2 bg_size = vec2(0.85, 0.85);

// text-shadow / box-shadow glow of whatever the view holds
uniform vec3 glow_tint = vec3(0.314, 1.0, 0.549);
uniform float glow_amount = 0.75;
uniform float glow_radius = 7.0;                  // css px
uniform float glow_floor = 0.0;                   // what is dimmer than this does not glow (the wheel's dark disc)
uniform float glow_keep_color = 0.0;              // 1: the glow takes the content's own colour, not the tint

// radial-gradient(ellipse 74% 80% at 50% 50%, rgba(80,255,150,.06), rgba(0,0,0,.6) 100%), then repeating-linear-gradient(0deg, rgba(0,0,0,.34) 0 1px, transparent 1px 3px)
uniform vec4 vig_inner = vec4(0.314, 1.0, 0.588, 0.06);
uniform vec4 vig_outer = vec4(0.0, 0.0, 0.0, 0.6);
uniform vec2 vig_size = vec2(0.74, 0.8);
uniform float scan = 0.34;
uniform float scan_period = 3.0;
uniform float overlay = 1.0;                      // #pause.pc-zoom .pc-crt {opacity: .45}

// the rolling bar (.pc-crt:before, pzRoll) and the overlay's flicker (pzFlick)
uniform vec3 roll_color = vec3(0.431, 1.0, 0.667);
uniform float roll_alpha = 0.09;
uniform float roll_period = 5.5;
uniform float roll_h = 0.22;
uniform float flick_period = 3.3;

// inset box-shadows of .hpcrt / .hacrt (blur in css px)
uniform vec4 inset_a = vec4(0.0);
uniform float inset_a_blur = 12.0;
uniform vec4 inset_b = vec4(0.0);
uniform float inset_b_blur = 3.0;

uniform vec2 curve = vec2(0.0);                   // tube curvature, off unless the JS screen had it
uniform float grain = 0.0;

// the glitch (pzGlitch / pzTear): one key at a time, held
uniform vec2 g_shift = vec2(0.0);                 // css px
uniform float g_skew = 0.0;                       // tan(skewX)
uniform float g_bright = 1.0;
uniform float g_contrast = 1.0;
uniform float g_sat = 1.0;
uniform float g_hue = 0.0;                        // radians
uniform vec2 g_clip = vec2(0.0);                  // inset() top, bottom, as fractions: outside it the view is gone and the backdrop shows
uniform vec3 tear_a = vec3(0.4, 10.0, 0.0);       // y fraction, height css px, alpha
uniform vec3 tear_b = vec3(0.7, 5.0, 0.0);
uniform vec3 tear_color = vec3(0.47, 1.0, 0.706);
uniform float tear_opacity = 0.55;

float crt_hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }

// CSS erf-shaped edge of a box-shadow: 1 at the edge side, 0 deep inside (sigma = blur / 2)
float crt_shadow(float d, float blur) {
	float s = max(blur * 0.5, 0.001);
	float x = d / (s * 1.41421356);
	float a = x;
	float e = 1.0 + (0.278393 + (0.230389 + 0.078108 * (a * a)) * a) * a;
	e *= e;
	return 0.5 * (1.0 / (e * e));     // 0.5 * (1 - erf(x)), x >= 0
}

vec3 crt_hue(vec3 c, float a) {
	float s = sin(a), k = cos(a);
	mat3 m = mat3(
		vec3(0.213 + k * 0.787 - s * 0.213, 0.213 - k * 0.213 + s * 0.143, 0.213 - k * 0.213 - s * 0.787),
		vec3(0.715 - k * 0.715 - s * 0.715, 0.715 + k * 0.285 + s * 0.140, 0.715 - k * 0.715 + s * 0.715),
		vec3(0.072 - k * 0.072 + s * 0.928, 0.072 - k * 0.072 - s * 0.283, 0.072 + k * 0.928 + s * 0.072));
	return m * c;
}

// a layer that lies between the glass and the view (premultiplied): the EKG trace
vec4 crt_compose(vec2 uv, vec2 frag, float t, vec4 under) {
	vec2 css = rect_px / px_scale;
	// tube curvature: the picture bulges
	vec2 c0 = uv * 2.0 - 1.0;
	vec2 u = (c0 + c0 * (c0.yx * c0.yx) * curve) * 0.5 + 0.5;

	// the glitch moves the picture, skews it about its middle, clips it to a band
	vec2 gu = u;
	gu.x -= (g_shift.x + g_skew * (u.y - 0.5) * css.y * -1.0) / css.x;
	gu.y -= g_shift.y / css.y;
	float shown = step(g_clip.x, u.y) * step(u.y, 1.0 - g_clip.y);

	vec4 v = textureLod(view, gu, view_mip);
	vec3 glow = vec3(0.0);
	if (glow_amount > 0.0) {
		vec2 r = vec2(glow_radius) / css;
		vec4 s = vec4(0.0);
		// two rings, the outer one light: about the gaussian a CSS blur of this radius gives
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.7853982;
			vec2 d = vec2(cos(a), sin(a));
			s += textureLod(view, gu + d * r * 0.42, view_mip) * 1.4;
			s += textureLod(view, gu + vec2(d.y, -d.x) * r * 0.78 + d * r * 0.2, view_mip) * 0.8;
			s += textureLod(view, gu + d.yx * r * 1.15, view_mip) * 0.35;
		}
		s /= 20.4;
		vec3 own = s.rgb;
		float lum = max(own.r, max(own.g, own.b));
		float kept = max(lum - glow_floor, 0.0) / max(1.0 - glow_floor, 0.001);
		glow = mix(glow_tint * kept, own * kept / max(lum, 0.001), glow_keep_color) * glow_amount * 1.7;
	}
	if (g_hue != 0.0) { v.rgb = crt_hue(v.rgb, g_hue); }

	vec3 bg = mix(bg_center.rgb, bg_edge.rgb, clamp(length((u - 0.5) / bg_size), 0.0, 1.0));
	float bga = bg_center.a;
	vec3 col = bg * bga;
	float alpha = bga;
	col = under.rgb + col * (1.0 - under.a);
	alpha = under.a + alpha * (1.0 - under.a);
	col = v.rgb + col * (1.0 - v.a);
	alpha = v.a + alpha * (1.0 - v.a);
	col += glow;
	alpha = max(alpha, min(1.0, length(glow)));
	// filter: brightness() contrast() saturate()
	if (g_bright != 1.0 || g_contrast != 1.0 || g_sat != 1.0) {
		col *= g_bright;
		col = (col - 0.5 * alpha) * g_contrast + 0.5 * alpha;
		float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
		col = max(mix(vec3(l), col, g_sat), vec3(0.0));
	}
	col *= shown;
	alpha *= shown;

	// inset light of the screen edge
	vec2 e = min(uv, 1.0 - uv) * css;
	float edge = min(e.x, e.y);
	if (inset_a.a > 0.0) {
		float k = crt_shadow(edge, inset_a_blur) * inset_a.a;
		col = inset_a.rgb * k + col * (1.0 - k);
		alpha = k + alpha * (1.0 - k);
	}
	if (inset_b.a > 0.0) {
		float k = crt_shadow(edge, inset_b_blur) * inset_b.a;
		col = inset_b.rgb * k + col * (1.0 - k);
		alpha = k + alpha * (1.0 - k);
	}

	// the overlay: vignette, scanlines, roll bar; pzFlick lifts it for a frame or two
	float fl = 1.0;
	if (flick_period > 0.0) {
		float p = fract(t / flick_period);
		if (p >= 0.09 && p < 0.10) { fl = 0.93; }
		else if (p >= 0.47 && p < 0.48) { fl = 0.95; }
		else if (p >= 0.71 && p < 0.72) { fl = 0.9; }
	}
	fl *= overlay;
	float vr = clamp(length((uv - 0.5) / vig_size), 0.0, 1.0);
	vec4 vi = mix(vec4(vig_inner.rgb * vig_inner.a, vig_inner.a), vec4(vig_outer.rgb * vig_outer.a, vig_outer.a), vr) * fl;
	col = vi.rgb + col * (1.0 - vi.a);
	alpha = vi.a + alpha * (1.0 - vi.a);
	if (scan > 0.0) {
		float sl = (mod(frag.y, scan_period * px_scale) < px_scale ? 1.0 : 0.0) * scan * fl;
		col *= 1.0 - sl;
		alpha = sl + alpha * (1.0 - sl);
	}
	if (roll_alpha > 0.0) {
		// a band roll_h tall travels from just above the top to the bottom edge; transparent -> colour at 55% -> transparent
		float top = -roll_h + fract(t / roll_period) * (1.0 + roll_h);
		float bp = (uv.y - top) / roll_h;
		if (bp > 0.0 && bp < 1.0) {
			float k = (bp < 0.55 ? bp / 0.55 : (1.0 - bp) / 0.45) * roll_alpha * fl;
			col = roll_color * k + col * (1.0 - k);
			alpha = k + alpha * (1.0 - k);
		}
	}
	// the tears: bright bands, screen blended
	if (tear_a.z > 0.0 || tear_b.z > 0.0) {
		float y = uv.y * css.y;
		float ta = (y >= tear_a.x * css.y && y < tear_a.x * css.y + tear_a.y) ? tear_a.z : 0.0;
		float tb = (y >= tear_b.x * css.y && y < tear_b.x * css.y + tear_b.y) ? tear_b.z : 0.0;
		float k = max(ta, tb) * tear_opacity;
		if (k > 0.0) {
			vec3 tc = tear_color * k;
			col = vec3(1.0) * alpha - (vec3(alpha) - col) * (1.0 - tc);
			col = max(col, tc);
			alpha = max(alpha, k);
		}
	}
	if (grain > 0.0) {
		col += (crt_hash(frag + fract(t) * 517.0) - 0.5) * grain * alpha;
	}
	return vec4(col, alpha);
}
