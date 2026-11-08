// Box-shadow maths shared by the two blend halves. Everything in css px; the quad is larger than the box by `pad` on each side, so the outer glow has room.
uniform vec2 box_css = vec2(600.0, 440.0);
uniform vec2 pad = vec2(60.0, 60.0);
uniform vec2 radius = vec2(24.0, 22.0);         // border-radius a / b
uniform float opacity = 1.0;
uniform vec4 outer = vec4(0.353, 1.0, 0.588, 0.5);
uniform float outer_blur = 36.0;
uniform float outer_spread = 6.0;
uniform vec4 line = vec4(0.0);
uniform vec4 in_a = vec4(0.314, 1.0, 0.549, 0.5);
uniform float in_a_blur = 66.0;
uniform vec4 in_b = vec4(0.627, 1.0, 0.784, 0.5);
uniform float in_b_blur = 14.0;

float bg_erf(float x) {
	float s = sign(x), a = abs(x);
	float e = 1.0 + (0.278393 + (0.230389 + 0.078108 * (a * a)) * a) * a;
	e *= e;
	return s * (1.0 - 1.0 / (e * e));
}

vec3 box_glow(vec2 uv) {
	vec2 full = box_css + pad * 2.0;
	vec2 p = uv * full - full * 0.5;
	// distance to the rounded box (an elliptical corner, scaled to a circle): negative inside
	float rr = max(min(radius.x, radius.y), 0.001);
	vec2 sc = vec2(rr / max(radius.x, 0.001), rr / max(radius.y, 0.001));
	vec2 q = abs(p) * sc - (box_css * 0.5) * sc + vec2(rr);
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - rr;
	vec3 c = vec3(0.0);
	if (outer.a > 0.0) {
		float s = max(outer_blur * 0.5, 0.001);
		float k = 0.5 - 0.5 * bg_erf((d - outer_spread) / (s * 1.41421356));
		c += outer.rgb * outer.a * k * step(0.0, d);
	}
	if (d < 0.0) {
		float id = -d;
		float ka = 0.5 - 0.5 * bg_erf(id / (max(in_a_blur * 0.5, 0.001) * 1.41421356));
		float kb = 0.5 - 0.5 * bg_erf(id / (max(in_b_blur * 0.5, 0.001) * 1.41421356));
		c += in_a.rgb * in_a.a * ka + in_b.rgb * in_b.a * kb;
	}
	if (line.a > 0.0) {
		c += line.rgb * line.a * clamp(1.0 - abs(d - 0.5) * 1.0, 0.0, 1.0);
	}
	return c;
}
