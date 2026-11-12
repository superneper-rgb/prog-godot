// A flying car (see sky_traffic.gdshaderinc), one surface of it: the models of tools/cars/sky_cars.py, lit like the street's cars (car_look.gdshaderinc) but none of their wear: the people above
// keep them polished (2026-11-10: was the JS's dark unlit silhouette). part: 0 paint, 1 parts, 2 glass, 3 lights. INSTANCE_CUSTOM.x: the engine colour, .y: the paint.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, skip_vertex_transform;

#include "res://levels/shaders/car_look.gdshaderinc"
#include "res://levels/shaders/sky_traffic.gdshaderinc"

uniform int part = 0;
uniform float fill = 0.5;
uniform float light_gain = 3.2;

varying vec3 v_paint;
varying vec3 v_eng;

// the upper city's paints: mostly the dark mass's (black chrome, night violet, gunmetal, oxblood), now and then champagne or pearl (sRGB)
vec3 sky_paint(int i) {
	vec3 c = vec3(0.07, 0.065, 0.08);
	if (i == 1) c = vec3(0.16, 0.08, 0.24);
	else if (i == 2) c = vec3(0.20, 0.21, 0.24);
	else if (i == 3) c = vec3(0.30, 0.05, 0.09);
	else if (i == 4) c = vec3(0.62, 0.52, 0.36);
	else if (i == 5) c = vec3(0.70, 0.70, 0.74);
	return srgb_decode(c);
}

void vertex() {
	float yaw, turn, bob;
	vec3 at = lane_at(MODEL_MATRIX, t, yaw, turn, bob);
	mat3 R = sky_basis(yaw, turn, bob);
	VERTEX = (VIEW_MATRIX * vec4(at + R * VERTEX, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(R * NORMAL, 0.0)).xyz);
	v_paint = sky_paint(int(INSTANCE_CUSTOM.y + 0.5));
	int e = int(INSTANCE_CUSTOM.x + 0.5);
	v_eng = e == 0 ? vec3(0.4, 0.85, 1.0) : (e == 1 ? vec3(1.0, 0.3, 0.8) : vec3(1.0, 0.55, 0.15));
}

void fragment() {
	if (part == 0) {
		ALBEDO = v_paint * 0.6;
		METALLIC = 0.8;
		ROUGHNESS = 0.16;
		CLEARCOAT = 1.0;
		CLEARCOAT_ROUGHNESS = 0.03;
		EMISSION = car_emission(v_paint, 0.8, 1.25, fill, NORMAL, NORMAL, VIEW, INV_VIEW_MATRIX);
	} else if (part == 1) {
		ALBEDO = COLOR.rgb;
		METALLIC = UV.x;
		ROUGHNESS = max(UV.y, 0.05);
		EMISSION = car_emission(ALBEDO, METALLIC, 0.6 * (1.0 - ROUGHNESS) * (1.0 - ROUGHNESS), fill, NORMAL, NORMAL, VIEW, INV_VIEW_MATRIX);
	} else if (part == 2) {
		// the canopy: dark glass mirroring the city, and through it the cabin's warm light (inhabited: the one warm thing on these craft)
		vec3 tint = vec3(0.02, 0.02, 0.035);
		float face = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		ALBEDO = tint;
		METALLIC = 0.2;
		ROUGHNESS = 0.06;
		EMISSION = car_emission(tint, 0.2, 1.6, 0.3, NORMAL, NORMAL, VIEW, INV_VIEW_MATRIX) + display_to_radiance(vec3(1.0, 0.62, 0.30)) * 0.035 * face * face;
	} else {
		vec3 c = COLOR.rgb;
		if (c.g > 0.9 && c.r < 0.1 && c.b < 0.1) c = v_eng;      // (sky_cars.py keys the accent pure green: each craft's engine colour)
		ALBEDO = vec3(0.0);
		ROUGHNESS = 1.0;
		EMISSION = c * UV.x * light_gain;      // (as car_lights.gdshader)
	}
}
