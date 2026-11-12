// JUNGLE TEST: the breeze every plant shares (jungle_leaf, jungle_glow), so a flower's glowing bell moves with its own stalk.
// sway_by 0: the weight is the vertex colour's alpha (meshes merged in world space: vines, hanging from their anchor). 1: it grows with the height and reach from the instance's root (MultiMesh plants).

uniform float sway = 0.12;          // metres at full weight
uniform float sway_speed = 1.0;
uniform int sway_by = 1;

float jungle_weight(vec3 v, float a) {
	return sway_by == 0 ? a : clamp(v.y * 0.55 + length(v.xz) * 0.35, 0.0, 2.2);
}

// the offset for a vertex: a slow lean that comes and goes in gusts, and a quick flutter on top. `at` sets the phase (the root, or the vertex itself).
vec3 jungle_wind(vec3 at, float w) {
	float t = TIME * sway_speed;
	float ph = dot(at.xz, vec2(0.11, 0.07));
	float gust = 0.55 + 0.45 * sin(t * 0.31 + at.x * 0.021 + at.z * 0.013);
	vec3 lean = vec3(sin(t * 1.15 + ph), 0.0, cos(t * 0.95 + ph * 1.3)) * gust;
	vec3 flutter = vec3(sin(t * 3.7 + ph * 5.0), 0.5 * sin(t * 4.3 + ph * 3.0), cos(t * 3.1 + ph * 4.0)) * 0.22;
	return (lean + flutter) * sway * w;
}
