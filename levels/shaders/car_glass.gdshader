// FOINT CITY car glass: dark tinted, mirroring the city harder than the paint does (car_look.gdshaderinc), with the street's film on it: dust settled on the top, a dirty band along the bottom edge, dried water spots.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;
#include "res://levels/shaders/car_look.gdshaderinc"

uniform vec3 tint : source_color = vec3(0.02, 0.02, 0.035);
// 2026-11-11 (user: the car interiors looked like flat red slabs): the glass was 0.9 opaque and mirrored the red sky and its stepped skyline (car_city) at coat 1.6, so it read as
// a red painted panel with blocky edges and the cabin behind it (seats, wheel, the driver) was 10% visible. Now the cabin shows through and the sky is a sheen on the glass, not its colour.
uniform float alpha = 0.5;
uniform float coat = 0.7;
uniform float rim = 0.0;      // a clear bubble (the alien craft's domes): how much it closes up toward its edge, so its shape still reads
varying vec3 v_cp;
varying vec3 v_cn;
varying flat float v_seed;

void vertex() {
	v_cp = car_frame(VERTEX);
	v_cn = car_frame(NORMAL);
	v_seed = car_seed(INSTANCE_ID);
}

void fragment() {
	vec4 g = car_grime(v_cp + vec3(0.0, 0.25, 0.0), normalize(v_cn), v_seed);      // (lifted: the glass sits above the splash, only its lowest edge takes the road film)
	float spots = smoothstep(0.62, 0.8, car_vn(v_cp * 30.0 + v_seed)) * g.w;
	float d = clamp(g.x * 0.6 + spots * 0.35, 0.0, 1.0);
	ALBEDO = mix(tint, CAR_FILM, d);
	METALLIC = 0.2 * (1.0 - d);
	ROUGHNESS = mix(0.08, 0.6, d);
	EMISSION = car_emission(ALBEDO, 0.2 * (1.0 - d), coat * (1.0 - 0.7 * d), 0.3, NORMAL, NORMAL, VIEW, INV_VIEW_MATRIX);
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5) * rim;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);      // (a glancing view of glass mirrors more and shows less of what is behind it)
	ALPHA = mix(mix(mix(alpha, 0.9, fres), 0.95, edge), 0.97, d);
}
