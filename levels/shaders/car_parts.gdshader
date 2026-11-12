// FOINT CITY car parts: trim, tyres, rims, chrome, panel gaps in one surface. tools/cars/build_cars.py bakes each part's albedo into the vertex colour and its metallic and roughness into the UV. The street's road film is on them too (car_grime), heaviest low down: tyres, rims, sills.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://levels/shaders/car_look.gdshaderinc"

uniform float fill = 0.42;
varying vec3 v_cp;
varying vec3 v_cn;
varying flat float v_seed;

void vertex() {
	v_cp = car_frame(VERTEX);
	v_cn = car_frame(NORMAL);
	v_seed = car_seed(INSTANCE_ID);
}

void fragment() {
	vec4 g = car_grime(v_cp, normalize(v_cn), v_seed);
	float d = g.x * 0.8;
	ALBEDO = mix(COLOR.rgb, CAR_FILM, d);
	METALLIC = UV.x * (1.0 - d);
	ROUGHNESS = mix(max(UV.y, 0.05), 0.85, d);
	EMISSION = car_emission(ALBEDO, METALLIC, 0.5 * (1.0 - ROUGHNESS) * (1.0 - ROUGHNESS), fill, NORMAL, NORMAL, VIEW, INV_VIEW_MATRIX);
}
