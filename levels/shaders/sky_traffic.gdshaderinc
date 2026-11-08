// FOINT CITY sky traffic (JS levels/hub/city-atmos.js): flying cars on rectangular lanes, in closed form on the clock, so nothing runs per craft in script. Instance: origin = the lane's first corner (x, height, z), basis columns = the other corners and the craft's numbers, INSTANCE_CUSTOM.x = which engine colour.
//   col 0: p1.x, p1.z, p2.x    col 1: p2.z, p3.x, p3.z    col 2: s0, speed, bob

uniform float t = 0.0;

vec3 lane_at(mat4 M, float time, out float yaw, out float turn, out float bob) {
	vec2 P0 = M[3].xz;
	vec2 P1 = vec2(M[0].x, M[0].y);
	vec2 P2 = vec2(M[0].z, M[1].x);
	vec2 P3 = vec2(M[1].y, M[1].z);
	float l0 = distance(P0, P1), l1 = distance(P1, P2), l2 = distance(P2, P3), l3 = distance(P3, P0);
	float s = mod(M[2].x + M[2].y * time, l0 + l1 + l2 + l3);
	bob = M[2].z;
	vec2 a = P0, b = P1;
	float u = s / l0;
	if (s >= l0 + l1 + l2) { a = P3; b = P0; u = (s - l0 - l1 - l2) / l3; }
	else if (s >= l0 + l1) { a = P2; b = P3; u = (s - l0 - l1) / l2; }
	else if (s >= l0) { a = P1; b = P2; u = (s - l0) / l1; }
	vec2 at = mix(a, b, u);
	yaw = atan(b.x - a.x, b.y - a.y);
	turn = u > 0.9 ? (u - 0.9) * 4.0 : 0.0;
	return vec3(at.x, M[3].y + sin(time * 0.7 + bob) * 0.8, at.y);
}
