// The wind in FOINT CITY's trees (levels/hub/city_trees.gd), shared by the bark and the leaves so the limbs stay in their canopy.
// A tree bends more the higher up you go (nothing below 1 m moves), leans a little with the wind and swings on a phase of its own, taken from where it stands.

uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float wind = 1.0;

vec3 tree_bend(vec3 v, vec3 at, float t) {
	float h = max(0.0, v.y - 1.0);
	float k = h * h * 0.0045 * wind;
	float ph = at.x * 0.31 + at.z * 0.27;
	float s = 0.35 + sin(t * 1.1 + ph) + 0.4 * sin(t * 2.7 + ph * 1.7) + 0.15 * sin(t * 5.3 + ph * 3.1);
	v.xz += wind_dir * s * k;
	return v;
}
