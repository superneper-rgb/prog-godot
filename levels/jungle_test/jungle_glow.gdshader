// JUNGLE TEST bioluminescence: flower hearts, bells, mushroom caps and vine bulbs. They glow in their vertex colour, breathe slowly out of step with each other, and sway with their plant.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://levels/jungle_test/jungle_wind.gdshaderinc"

uniform float energy = 4.0;
uniform float pulse = 0.3;
uniform float speed = 1.2;

varying float ph;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float w = jungle_weight(VERTEX, COLOR.a);
	vec3 at = sway_by == 0 ? VERTEX : root;
	VERTEX += jungle_wind(at, w);
	ph = dot(sway_by == 0 ? VERTEX : root, vec3(0.71, 0.33, 0.53));
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float p = 1.0 - pulse + pulse * sin(TIME * speed + ph);
	ALBEDO = COLOR.rgb * 0.25;
	ROUGHNESS = 0.3;
	SPECULAR = 0.6;
	EMISSION = COLOR.rgb * energy * p * (0.75 + 0.5 * rim);
}
