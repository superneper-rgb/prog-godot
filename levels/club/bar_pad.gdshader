// CLUB 9's drinks pad (levels/club/bar_pad.gd): the painted device on a slab. Its front is the picture; `lit` takes it from lit by the club (1) to the picture as painted (0), so
// the camera can land on it and hand over to the 2D menu, which draws the same picture flat. `screen_on` lights the glass in the bar terminal's green as it boots.
shader_type spatial;
render_mode cull_back;

uniform sampler2D art : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float lit = 1.0;
uniform float screen_on = 0.0;
uniform vec4 hole = vec4(0.1641, 0.1549, 0.6641, 0.7135);     // the glass, as fractions of the picture: x1, y1, x2, y2
uniform vec3 phos = vec3(0.16, 0.9, 0.42);

void fragment() {
	vec4 t = texture(art, UV);
	if (t.a < 0.5) {
		discard;
	}
	vec3 c = t.rgb * COLOR.rgb;      // (vertex colour: 1 on the front, darker on the edges and the back)
	ALBEDO = c * lit;
	ROUGHNESS = 0.5;
	SPECULAR = 0.35 * lit;
	vec2 q = (UV - hole.xy) / (hole.zw - hole.xy);
	float in_glass = step(0.0, q.x) * step(q.x, 1.0) * step(0.0, q.y) * step(q.y, 1.0) * COLOR.a;      // (COLOR.a: 1 on the front face only)
	vec2 e = min(q, 1.0 - q);
	float soft = smoothstep(0.0, 0.08, min(e.x, e.y * 0.6));
	float scan = 0.8 + 0.2 * step(0.5, fract(q.y * 140.0));
	EMISSION = c * (1.0 - lit) + phos * screen_on * in_glass * soft * scan * 0.55;
}
