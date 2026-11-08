// A vendor terminal's machine picture (JS VendorMenu._neon + pzSign): the sign's glow (bright + saturated pixels inside the sign's region) breathes: a dark multiply dims the baked-in glow while a blurred bright copy (screen) lifts it, like a real neon sign with a tired ballast. Done per pixel here, from the picture's own mips, instead of the JS's two extra canvases.
shader_type canvas_item;

uniform sampler2D art : filter_linear_mipmap, repeat_disable;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 0.25);    // x1, y1, x2, y2
uniform float min_v = 0.804;
uniform bool neon_white = true;
uniform float level = 0.15;    // 0..1, the pzSign curve's value
uniform float blur_lod = 2.5;

bool lit(vec3 c, float a) {
	if (a < 0.5) {
		return false;
	}
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	return (mx >= min_v && mx - mn >= mx * 0.42) || (neon_white && mx >= 0.843 && mn >= 0.588);
}

void fragment() {
	vec4 t = texture(art, UV);
	vec3 c = t.rgb;
	float mask = 0.0;
	if (UV.x > region.x && UV.x < region.z && UV.y > region.y && UV.y < region.w) {
		vec4 bl = textureLod(art, UV, blur_lod);
		mask = lit(c, t.a) ? 1.0 : 0.0;
		// multiply: the dark copy, opacity .8 * level: the baked glow dims as the sign fades
		float dk_o = 0.8 * level;
		if (mask > 0.0) {
			c *= mix(1.0, 60.0 / 255.0, dk_o);
		}
		// screen: the blurred bright copy, opacity .95 - .85 * level, brightness 1.9
		if (lit(bl.rgb, bl.a)) {
			vec3 g = min(bl.rgb * 1.1 * 1.9, vec3(1.0));
			float go = 0.95 - 0.85 * level;
			c = 1.0 - (1.0 - c) * (1.0 - g * go);
		}
	}
	COLOR = vec4(c, t.a);
}
