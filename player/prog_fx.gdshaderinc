// Shared noise for the character detail shaders (JS GLSL_FX). They work from the bind-pose vertex position, handed over in CUSTOM0 (see Animator._rebuilt_mesh),
// so the detail sticks to the skin through every animation: Godot has already skinned VERTEX by the time the vertex shader runs.
float hsh(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vn(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hsh(i), hsh(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hsh(i + vec3(0.0, 1.0, 0.0)), hsh(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
			mix(mix(hsh(i + vec3(0.0, 0.0, 1.0)), hsh(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hsh(i + vec3(0.0, 1.0, 1.0)), hsh(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	return 0.55 * vn(p) + 0.3 * vn(p * 2.3 + 4.1) + 0.15 * vn(p * 5.1 + 9.7);
}
