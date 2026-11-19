// UNDERFOINT's standing and running water (the sewer's channels, the flooded branch): a dark level surface whose ripples are two reads of one noise sliding past each other. Opaque: nothing down here is clear enough to see through.
shader_type spatial;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 deep : source_color = vec3(0.016, 0.04, 0.024);
uniform vec2 flow = vec2(0.09, 0.12);      // metres a second, in noise space
uniform float ripple = 0.3;

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = w_pos.xz * 0.33;
	float a = texture(noise_tex, p + flow * TIME).r;
	float b = texture(noise_tex, p * 1.7 - flow * TIME * 1.3 + 0.41).r;
	vec3 n = normalize(vec3((a - 0.5) * ripple + (b - 0.5) * ripple * 0.6, 1.0, (b - 0.5) * ripple + (a - 0.5) * ripple * 0.4));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = deep * (0.7 + 0.6 * a);
	ROUGHNESS = 0.04;
	SPECULAR = 0.7;
}
