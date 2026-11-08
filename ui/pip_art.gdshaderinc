// The handheld terminal's light on its bezel: the screen shape blurred (a tight halo or a wide one), with the glass itself cut out, so the screen keeps its CRT look. Screen blended: two quads.
uniform sampler2D blur_tex : filter_linear, repeat_disable;
uniform sampler2D glass_tex : filter_linear, repeat_disable;
uniform vec3 light = vec3(0.2745, 1.0, 0.5098);
uniform float opacity = 0.85;

vec3 pip_light(vec2 uv) {
	float b = texture(blur_tex, uv).r * (1.0 - texture(glass_tex, uv).r);
	return light * b * opacity;
}
