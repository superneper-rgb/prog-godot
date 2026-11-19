// A dropped shock mine (sky_items.gd): a squat dark disc with a red core and a band that blinks faster as nothing happens.
shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(1.0, 0.29, 0.24);
uniform float power = 1.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float r = length(local_pos.xz);
	float band = 1.0 - smoothstep(0.03, 0.07, abs(local_pos.y));
	float core = 1.0 - smoothstep(0.12, 0.2, r);
	float blink = step(0.5, fract(TIME * 3.0 + float(INSTANCE_ID) * 0.37));
	ALBEDO = vec3(0.03, 0.03, 0.04);
	METALLIC = 0.6;
	ROUGHNESS = 0.4;
	EMISSION = tint * power * (band * (1.2 + 2.2 * blink) + core * 3.0 * step(0.0, local_pos.y));
}
