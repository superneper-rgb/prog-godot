// Rain splashes (JS levels/worldbackalley/storm.js updateSplashes): short-lived square specks on the street around the camera, kicking up a little before they fade. Each drop's life runs here from its seed, so nothing runs per frame in script.
// ENGINE DIFFERENCE: the JS's life gets 0.05 s shorter in a gust; here it is the middle value, because changing it live would make every drop jump.
shader_type spatial;
render_mode blend_add, unshaded, shadows_disabled, depth_draw_never, skip_vertex_transform, cull_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

const float RW = 4.2;
const float SW = 7.5;

varying vec3 v_col;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void vertex() {
	float seed = VERTEX.x;
	float life = 0.095 + hash(seed * 1.7) * 0.12;
	float ph = TIME / life + hash(seed * 2.3);
	float cyc = floor(ph);
	float left = (1.0 - fract(ph)) * life;
	float a = hash(seed + cyc * 12.9898) * 6.2831853;
	float r = 0.8 + sqrt(hash(seed * 3.1 + cyc * 78.233)) * 15.0;
	vec3 cam = CAMERA_POSITION_WORLD;
	float x = cam.x + cos(a) * r;
	float z = cam.z + sin(a) * r;
	float ax = abs(x);
	float y = ax <= RW ? 0.0 : (ax <= SW ? 0.15 : -50.0);      // JS groundY: the road, the pavement, nothing past it
	vec4 view = VIEW_MATRIX * vec4(x, y + 0.03 + (life - left) * 0.6, z, 1.0);
	float dist = max(0.1, -view.z);
	float px = 0.045 * VIEWPORT_SIZE.y * 0.5 / dist;           // three.js PointsMaterial: size * (height / 2) / distance
	view.xy += (UV - vec2(0.5)) * 2.0 * point_half(px, dist, VIEWPORT_SIZE, PROJECTION_MATRIX[1][1]);
	VERTEX = view.xyz;
	v_col = vec3(0.7, 0.8, 0.95) * min(1.0, left / 0.15) * 0.4;
}

void fragment() {
	ALBEDO = add_display(v_col, 1.0);
	ALPHA = 1.0;
}
