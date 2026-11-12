// Where the city's rain lands (new in the Godot port, asked for by the user 2026-11-09): little rings spreading on whatever is on top round the camera (RainCover's map: the street, a roof, the bridge deck), with a bright fleck as the drop hits.
// Each splash is one flat quad; its life runs here from its seed (VERTEX.x), so nothing runs per frame in script.
shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never, skip_vertex_transform, cull_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform float radius = 14.0;      // how far round the camera they land
uniform float opacity = 0.12;      // (0.24 until 2026-11-11: too busy, said the user)
uniform float below = 10.0;       // the rain's box (rain.gdshader): no splash where no drop reaches
uniform sampler2D cover : filter_nearest, repeat_enable;
uniform float cover_cell = 0.5;
uniform float cover_n = 96.0;

varying float v_k;
varying float v_a;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void vertex() {
	float seed = VERTEX.x;
	float life = 0.3 + hash(seed * 1.7) * 0.2;
	float ph = TIME / life + hash(seed * 2.3);
	float cyc = floor(ph);
	float k = fract(ph);
	// A splash lands on a fixed world spot and stays there for its life: its point is a hash in a 2 * radius square that wraps round the camera, like the drops.
	// (It was cam.xz plus an offset, so every ring slid along with the player: user, 2026-11-11.) A ring near the square's edge, where the wrap can move it, is faded out.
	vec3 cam = CAMERA_POSITION_WORLD;
	vec2 base = vec2(hash(seed + cyc * 12.9898), hash(seed * 3.1 + cyc * 78.233)) * 2.0 * radius;
	vec2 xz = cam.xz + mod(base - cam.xz + radius, 2.0 * radius) - radius;
	float r = length(xz - cam.xz);
	float y = textureLod(cover, (floor(xz / cover_cell) + 0.5) / cover_n, 0.0).r;
	float size = mix(0.015, 0.06, sqrt(k)) * (0.7 + 0.6 * hash(seed * 5.1 + cyc));
	vec3 p = vec3(xz.x + (UV.x - 0.5) * 2.0 * size, y + 0.025, xz.y + (UV.y - 0.5) * 2.0 * size);
	v_k = k;
	v_a = (1.0 - smoothstep(radius * 0.6, radius * 0.9, max(abs(xz.x - cam.x), abs(xz.y - cam.z)))) * smoothstep(0.4, 0.8, r) * step(cam.y - below, y) * step(y, cam.y - below + 28.0);
	VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
}

void fragment() {
	if (v_a <= 0.0) {
		discard;
	}
	float d = length(UV - vec2(0.5)) * 2.0;
	float ring = smoothstep(0.7, 0.88, d) * (1.0 - smoothstep(0.88, 1.0, d)) * pow(1.0 - v_k, 2.2);      // a faint, quick ripple rather than a cartoon ring (user, 2026-11-11)
	float fleck = (1.0 - smoothstep(0.0, 0.3, d)) * (1.0 - smoothstep(0.0, 0.12, v_k));      // the hit itself
	ALBEDO = srgb_decode(vec3(0.6667, 0.7843, 0.9098));      // the drops' #aac8e8
	ALPHA = clamp(opacity * v_a * (ring + fleck * 0.6), 0.0, 1.0);
}
