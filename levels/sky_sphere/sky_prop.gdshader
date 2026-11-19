// The Overcurrent's smashable barrels and barrier blocks (sky_props.gd): painted metal with black hazard stripes and a lit band, so a
// stack reads at speed against the dark deck.
shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec3 paint : source_color = vec3(1.0, 0.54, 0.12);

varying vec3 obj;

void vertex() {
	obj = VERTEX;
}

void fragment() {
	float stripe = step(0.5, fract((obj.x + obj.z) * 1.6 + obj.y * 1.6));
	float band = 1.0 - smoothstep(0.05, 0.08, abs(obj.y - 0.18));
	vec3 base = mix(paint, vec3(0.03, 0.03, 0.035), stripe * 0.85);
	ALBEDO = base;
	ROUGHNESS = 0.5;
	METALLIC = 0.4;
	EMISSION = paint * (band * 1.4 + 0.04);
}
