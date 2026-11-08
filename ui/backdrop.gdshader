// What a menu puts behind itself (CSS backdrop-filter + a tint): the frame so far, blurred by its mip chain, under a radial tint. Also the live world behind the main menu.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float blur_lod = 1.6;
uniform vec4 inner = vec4(0.0, 0.03137, 0.01176, 0.5);    // radial-gradient(ellipse at center, ...)
uniform vec4 outer = vec4(0.0, 0.0, 0.0, 0.88);
uniform float brightness = 1.0;
uniform float saturation = 1.0;
uniform float opacity = 1.0;
uniform vec4 edge_left = vec4(0.0);                               // the main menu's linear-gradient(90deg, rgba(0,0,0,.6) 0%, rgba(0,0,0,.3) 30%, rgba(0,0,0,0) 55%): a = its strength

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	// a small tent, or the upscaled mip shows its blocks
	vec2 ts = SCREEN_PIXEL_SIZE * pow(2.0, blur_lod) * 0.6;
	c = c * 0.4 + (textureLod(screen_tex, SCREEN_UV + ts, blur_lod).rgb + textureLod(screen_tex, SCREEN_UV - ts, blur_lod).rgb + textureLod(screen_tex, SCREEN_UV + vec2(ts.x, -ts.y), blur_lod).rgb + textureLod(screen_tex, SCREEN_UV + vec2(-ts.x, ts.y), blur_lod).rgb) * 0.15;
	c *= brightness;
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(l), c, saturation);
	float r = length((UV - 0.5) * 2.0) * 0.70710678;
	vec4 t = mix(vec4(inner.rgb * inner.a, inner.a), vec4(outer.rgb * outer.a, outer.a), clamp(r, 0.0, 1.0));
	c = t.rgb + c * (1.0 - t.a);
	if (edge_left.a > 0.0) {
		float x = UV.x;
		float a = x < 0.3 ? mix(0.6, 0.3, x / 0.3) : mix(0.3, 0.0, clamp((x - 0.3) / 0.25, 0.0, 1.0));
		c *= 1.0 - a * edge_left.a;
	}
	COLOR = vec4(c, opacity);
}
