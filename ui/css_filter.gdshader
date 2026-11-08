// A CSS filter chain on a picture: grayscale(1) sepia(1) hue-rotate() saturate() brightness() contrast(). Defaults: the controls diagram on the phosphor screen (#pCtl #ctlImg).
shader_type canvas_item;
render_mode unshaded;

uniform float hue = 1.3614;        // 78 deg
uniform float sat = 3.4;
uniform float bright = 1.3;
uniform float contrast = 1.2;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float L = dot(t.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 c = clamp(vec3(L * 1.351, L * 1.203, L * 0.937), vec3(0.0), vec3(1.0));
	float s = sin(hue), k = cos(hue);
	mat3 h = mat3(
		vec3(0.213 + k * 0.787 - s * 0.213, 0.213 - k * 0.213 + s * 0.143, 0.213 - k * 0.213 - s * 0.787),
		vec3(0.715 - k * 0.715 - s * 0.715, 0.715 + k * 0.285 + s * 0.140, 0.715 - k * 0.715 + s * 0.715),
		vec3(0.072 - k * 0.072 + s * 0.928, 0.072 - k * 0.072 - s * 0.283, 0.072 + k * 0.928 + s * 0.072));
	c = clamp(h * c, vec3(0.0), vec3(1.0));
	float l2 = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = clamp(mix(vec3(l2), c, sat), vec3(0.0), vec3(1.0));
	c = clamp(c * bright, vec3(0.0), vec3(1.0));
	c = clamp((c - 0.5) * contrast + 0.5, vec3(0.0), vec3(1.0));
	COLOR = vec4(c, t.a) * COLOR;
}
