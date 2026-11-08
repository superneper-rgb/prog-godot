// A CSS text-shadow glow: the text rasterised once (ui/glow_text.gd), its mip chain standing in for the blur. Up to three shadows, each a radius (as a mip level) and a colour.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

uniform sampler2D glow : filter_linear_mipmap, repeat_disable;
uniform vec3 lod = vec3(2.0, 3.0, 4.0);
uniform vec4 c0 = vec4(1.0, 0.1, 0.1, 1.0);
uniform vec4 c1 = vec4(1.0, 0.1, 0.1, 0.9);
uniform vec4 c2 = vec4(1.0, 0.0, 0.0, 0.65);
uniform float gain = 1.0;
uniform float opacity = 1.0;

float blur(vec2 uv, float l) {
	// a little tent over the mip's texels, so the upscaled mip does not show its blocks
	vec2 ts = fwidth(uv) * pow(2.0, l) * 0.5;
	float s = textureLod(glow, uv, l).a * 0.4;
	s += textureLod(glow, uv + ts * vec2(1.0, 0.4), l).a * 0.15;
	s += textureLod(glow, uv + ts * vec2(-0.4, 1.0), l).a * 0.15;
	s += textureLod(glow, uv + ts * vec2(-1.0, -0.4), l).a * 0.15;
	s += textureLod(glow, uv + ts * vec2(0.4, -1.0), l).a * 0.15;
	return s;
}

void fragment() {
	float a0 = blur(UV, lod.x) * c0.a * gain;
	float a1 = blur(UV, lod.y) * c1.a * gain;
	float a2 = blur(UV, lod.z) * c2.a * gain;
	vec3 col = c2.rgb * a2;
	float a = a2;
	col = c1.rgb * a1 + col * (1.0 - a1);
	a = a1 + a * (1.0 - a1);
	col = c0.rgb * a0 + col * (1.0 - a0);
	a = a0 + a * (1.0 - a0);
	COLOR = vec4(col, a) * opacity;
}
