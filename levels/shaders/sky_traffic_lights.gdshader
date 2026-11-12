// A flying car's lights as glows (see sky_traffic.gdshaderinc; JS SkyTrafficLights), so a craft far up still reads: headlamp, tail, a white strobe, and its two engines. VERTEX.xy = the quad's corner, VERTEX.z = which light.
// Where they sit is the model's (tools/cars/sky_cars.py), one material per kind (hub_life.gd _build_sky_traffic); they ride the hull's own attitude (sky_basis).
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, skip_vertex_transform, cull_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"
#include "res://levels/shaders/sky_traffic.gdshaderinc"

uniform sampler2D map : source_color, filter_linear_mipmap;
uniform vec2 head = vec2(2.3, 0.0);      // (forward, up) in the craft
uniform vec2 tail = vec2(-2.3, 0.05);
uniform vec2 strobe = vec2(0.0, 0.55);
uniform vec3 engine = vec3(-1.9, 0.0, -0.25);      // (forward, side, up): one each side
const float SIZE = 3.2;

varying vec3 vCol;
varying vec2 vUv;

void vertex() {
	float yaw, turn, bob;
	vec3 at = lane_at(MODEL_MATRIX, t, yaw, turn, bob);
	mat3 R = sky_basis(yaw, turn, bob);
	int li = int(VERTEX.z + 0.5);
	vec3 q;
	float sz = SIZE;
	if (li == 0) { q = vec3(0.0, head.y, head.x); vCol = vec3(1.0, 0.95, 0.85); }
	else if (li == 1) { q = vec3(0.0, tail.y, tail.x); vCol = vec3(1.0, 0.08, 0.08); }
	else if (li == 2) { q = vec3(0.0, strobe.y, strobe.x); float blink = fract(t * 1.3 + bob) < 0.12 ? 1.0 : 0.0; vCol = vec3(blink, blink * 0.95, blink); }
	else {
		q = vec3(li == 3 ? engine.y : -engine.y, engine.z, engine.x);
		int e = int(INSTANCE_CUSTOM.x + 0.5);
		vCol = (e == 0 ? vec3(0.4, 0.85, 1.0) : (e == 1 ? vec3(1.0, 0.3, 0.8) : vec3(1.0, 0.55, 0.15))) * 0.6;
		sz = SIZE * 0.8;
	}
	vUv = VERTEX.xy * vec2(0.5, -0.5) + 0.5;
	VERTEX = (VIEW_MATRIX * vec4(at + R * q, 1.0)).xyz + vec3(VERTEX.xy * sz * 0.5 / PROJECTION_MATRIX[1][1], 0.0);
}

void fragment() {
	vec4 tx = texture(map, vUv);
	ALBEDO = add_display(vCol * tx.rgb, tx.a);
}
