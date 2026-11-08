// The city's rain (JS index.html CityView._rain + update): each drop is a line with its base point in VERTEX, wrapped into a 40 x 28 x 40 box around the camera. UV.x picks the line's end. The defaults are the hub's drizzle; a storm (Back Alley) sets its own.
shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never, skip_vertex_transform, cull_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform float speed = 24.0;
uniform float len = 0.7;
uniform float slant = 0.04;      // the streak's lean (JS sl)
uniform float drift = 0.0;       // storm rain drifts with the wind as it falls
uniform float opacity = 0.3;

void vertex() {
	vec3 b = VERTEX;
	vec3 cam = CAMERA_POSITION_WORLD;
	float fall = TIME * speed;
	vec3 p = vec3(cam.x + mod(b.x + fall * drift - cam.x + 20.0, 40.0) - 20.0, mod(b.y - fall, 28.0), cam.z + mod(b.z - cam.z + 20.0, 40.0) - 20.0);
	p += UV.x * vec3(slant, len, 0.0);      // the streak trails back up the drop's path
	VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
}

void fragment() {
	ALBEDO = srgb_decode(vec3(0.6667, 0.7843, 0.9098));      // #aac8e8
	ALPHA = opacity;
}
