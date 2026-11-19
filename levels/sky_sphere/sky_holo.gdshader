// A race crew's holo billboard hung off the derelict shell (sky_set_pieces.gd): scanlines, columns of glyph blocks scrolling, tearing and
// dropping out, red or teal (instance `hue`). The neon in the grime. Additive, so it glows in the haze.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

instance uniform float seed = 0.0;
instance uniform float hue = 0.0;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(123.2, 71.9))) * 41633.19);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME + seed * 10.0;
	// a tear now and then: rows slide sideways
	float tear = step(0.93, hash12(vec2(floor(t * 7.0), seed))) * (hash12(vec2(floor(uv.y * 24.0), floor(t * 7.0))) - 0.5) * 0.15;
	uv.x += tear;
	vec2 cell = floor(vec2(uv.x * 46.0, uv.y * 18.0 + t * 2.0 * step(0.5, hash12(vec2(floor(uv.x * 46.0), seed)))));
	float glyph = step(0.55, hash12(cell + floor(t * 1.5)));
	vec2 inner = fract(vec2(uv.x * 46.0, uv.y * 18.0 + t * 2.0));
	glyph *= step(0.15, inner.x) * step(inner.x, 0.85) * step(0.15, inner.y) * step(inner.y, 0.85);
	float scan = 0.65 + 0.35 * sin(uv.y * 400.0 + t * 30.0);
	float frame = step(min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)), 0.02);
	float dropout = step(0.06, hash12(vec2(floor(t * 3.0), seed + 1.0)));
	vec3 col = mix(vec3(1.0, 0.08, 0.16), vec3(0.05, 0.95, 0.85), hue);
	float a = (glyph * 0.32 + frame * 1.2 + 0.06) * scan * dropout;
	ALBEDO = col * a * 1.6;
}
