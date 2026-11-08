// One frame of the handheld terminal art: a little unsharp mask (the JS resampled the sheet to the window with one), and Tommy's white hands (the skin mask, baked by tools/build_ui_art.py).
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D hand_tex : filter_linear, repeat_disable;
uniform float white_hands = 0.0;
uniform float sharpen = 0.3;

void fragment() {
	vec2 w = fwidth(UV);
	vec4 c = texture(TEXTURE, UV, -0.35);
	if (sharpen > 0.0 && c.a > 0.03) {
		vec3 n = texture(TEXTURE, UV + vec2(w.x, 0.0)).rgb + texture(TEXTURE, UV - vec2(w.x, 0.0)).rgb + texture(TEXTURE, UV + vec2(0.0, w.y)).rgb + texture(TEXTURE, UV - vec2(0.0, w.y)).rgb;
		c.rgb = clamp(c.rgb + (c.rgb - n * 0.25) * sharpen, vec3(0.0), vec3(1.0));
	}
	if (white_hands > 0.0) {
		c.rgb = mix(c.rgb, vec3(1.0), texture(hand_tex, UV).r);
	}
	COLOR = c;
}
