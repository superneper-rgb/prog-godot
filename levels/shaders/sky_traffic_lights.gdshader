// A flying car's four lights (see sky_traffic.gdshaderinc; JS SkyTrafficLights): headlamp, tail, a white strobe on top, the engine. VERTEX.xy = the quad's corner, VERTEX.z = which light.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, skip_vertex_transform, cull_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"
#include "res://levels/shaders/sky_traffic.gdshaderinc"

uniform sampler2D map : source_color, filter_linear_mipmap;
const float SIZE = 3.2;

varying vec3 vCol;
varying vec2 vUv;

void vertex() {
	float yaw, turn, bob;
	vec3 at = lane_at(MODEL_MATRIX, t, yaw, turn, bob);
	float fx = sin(yaw), fz = cos(yaw);
	int li = int(VERTEX.z + 0.5);
	vec3 p = at;
	if (li == 0) { p += vec3(fx * 2.3, 0.0, fz * 2.3); vCol = vec3(1.0, 0.95, 0.85); }
	else if (li == 1) { p += vec3(-fx * 2.3, 0.05, -fz * 2.3); vCol = vec3(1.0, 0.08, 0.08); }
	else if (li == 2) { p += vec3(0.0, 0.55, 0.0); float blink = fract(t * 1.3 + bob) < 0.12 ? 1.0 : 0.0; vCol = vec3(blink, blink * 0.95, blink); }
	else {
		p += vec3(-fx * 1.9, -0.25, -fz * 1.9);
		int e = int(INSTANCE_CUSTOM.x + 0.5);
		vCol = (e == 0 ? vec3(0.4, 0.85, 1.0) : (e == 1 ? vec3(1.0, 0.3, 0.8) : vec3(1.0, 0.55, 0.15))) * 0.8;
	}
	vUv = VERTEX.xy * vec2(0.5, -0.5) + 0.5;
	VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz + vec3(VERTEX.xy * SIZE * 0.5 / PROJECTION_MATRIX[1][1], 0.0);
}

void fragment() {
	vec4 tx = texture(map, vUv);
	ALBEDO = add_display(vCol * tx.rgb, tx.a);
}
