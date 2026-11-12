// The city's rain (JS index.html CityView._rain + update, reworked in the Godot port at the user's request 2026-11-09). Each drop is a thin streak facing the camera, its base point in VERTEX, wrapped into a 40 x 28 x 40 box round the camera.
// UV.x picks the side of the streak, UV.y its end (0 the falling head, 1 the tail). The defaults are the hub's drizzle; a storm (Back Alley) sets its own.
// ENGINE DIFFERENCE (asked for): the JS box sat between world heights 0 and 28 and its drops were 1-pixel lines through every roof. Here the box follows the camera up and down (so the lower city and the bridge get rain),
// a drop stops at the topmost solid under it (RainCover's map in `cover`), and the streaks have a width, a soft edge and a tapering tail. A streak never draws thinner than a pixel: a thinner one fades instead, so far rain does not shimmer.
shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never, skip_vertex_transform, cull_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform float speed = 24.0;
uniform float len = 0.7;
uniform float slant = 0.04;      // the streak's lean (JS sl)
uniform float drift = 0.0;       // storm rain drifts with the wind as it falls
uniform float opacity = 0.3;
uniform float width = 0.006;     // a drop's thickness, metres
uniform float below = 10.0;      // the box reaches this far under the camera (and 28 - below over it)
uniform sampler2D cover : filter_nearest, repeat_enable;
uniform float cover_cell = 0.5;  // RainCover.CELL
uniform float cover_n = 96.0;    // RainCover.N

varying float v_y;
varying float v_roof;
varying float v_a;
varying vec2 v_uv;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void vertex() {
	vec3 b = VERTEX;
	float h = hash(dot(b, vec3(12.9898, 78.233, 37.719)));
	vec3 cam = CAMERA_POSITION_WORLD;
	float fall = TIME * speed * (0.9 + 0.2 * h);
	float y0 = cam.y - below;
	vec3 p = vec3(cam.x + mod(b.x + fall * drift - cam.x + 20.0, 40.0) - 20.0, y0 + mod(b.y - fall - y0, 28.0), cam.z + mod(b.z - cam.z + 20.0, 40.0) - 20.0);
	vec3 a = vec3(slant, len, 0.0) * (0.8 + 0.4 * hash(h * 7.13));      // the streak trails back up the drop's path
	vec3 mid = p + a * 0.5;
	vec3 to_cam = cam - mid;
	float dist = max(length(to_cam), 0.05);
	vec3 side = cross(a, to_cam);
	side = length(side) > 1e-5 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	float px = 2.0 * dist / (VIEWPORT_SIZE.y * PROJECTION_MATRIX[1][1]);      // a pixel's size at this distance
	float w = max(width, px * 1.5);
	vec3 q = p + a * UV.y + side * (UV.x * 2.0 - 1.0) * w * 0.5;
	v_roof = textureLod(cover, (floor(p.xz / cover_cell) + 0.5) / cover_n, 0.0).r;
	v_y = q.y;
	v_uv = UV;
	vec2 off = abs(p.xz - cam.xz);
	v_a = (width / w)                                                           // thinner than it is drawn: fainter
		* smoothstep(0.25, 1.2, dist)                                            // one right in the lens
		* (1.0 - smoothstep(15.0, 20.0, max(off.x, off.y)))                      // the box's sides, so drops do not pop in
		* smoothstep(0.0, 2.0, p.y - y0) * (1.0 - smoothstep(26.0, 28.0, p.y - y0))
		* (0.85 + 0.15 * hash(h * 3.71));      // (0.65..1 until 2026-11-11: the flicker read as noise)
	VERTEX = (VIEW_MATRIX * vec4(q, 1.0)).xyz;
}

void fragment() {
	if (v_y < v_roof) {
		discard;      // under a roof, an awning, the bridge
	}
	float across = 1.0 - abs(v_uv.x * 2.0 - 1.0);
	float along = smoothstep(0.0, 0.25, v_uv.y) * (1.0 - smoothstep(0.6, 1.0, v_uv.y));      // an even streak with soft ends, like the JS lines (the bright head was noisy: user, 2026-11-11)
	ALBEDO = srgb_decode(vec3(0.62, 0.66, 0.78));      // a cooler grey-violet than the JS #aac8e8, so it sits in the city's palette instead of glittering
	ALPHA = clamp(opacity * 2.6 * v_a * smoothstep(0.0, 0.85, across) * along, 0.0, 0.6);      // (a storm drop right by the lens would otherwise white out; boost 2.2, was 3 until 2026-11-11: too much, said the user)
}
