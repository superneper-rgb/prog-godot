// The brief lights of play (core/flash_lights.gd: muzzle flashes, explosions, gadget blasts, spells) on a painted, unshaded surface. Radiance to add, for a surface that
// reflects `fl_refl` of the light falling on it (the painted value is a dark result, not the material's colour: so the caller says what the material would reflect).
// n: the surface's outward normal (world), or vec3(0.0) to light it from every side. Godot's omni light, inverse square inside its range window.
global uniform vec4 prog_flash_p0;
global uniform vec4 prog_flash_p1;
global uniform vec4 prog_flash_p2;
global uniform vec4 prog_flash_p3;
global uniform vec4 prog_flash_c0;
global uniform vec4 prog_flash_c1;
global uniform vec4 prog_flash_c2;
global uniform vec4 prog_flash_c3;

// (every local here is fl_-named: an including shader's own uniforms share the scope, and Godot took city_facade's `win` over a local of that name)
vec3 flash_one(vec4 fl_p, vec4 fl_c, vec3 fl_w, vec3 fl_n) {
	vec3 fl_l = fl_p.xyz - fl_w;
	float fl_d2 = max(dot(fl_l, fl_l), 0.04);
	float fl_r = max(fl_p.w, 0.001);
	float fl_win = clamp(1.0 - (fl_d2 * fl_d2) / (fl_r * fl_r * fl_r * fl_r), 0.0, 1.0);
	float fl_lam = dot(fl_n, fl_n) > 0.0 ? max(dot(fl_n, fl_l * inversesqrt(fl_d2)), 0.0) : 1.0;
	return fl_c.rgb * (fl_win * fl_win * fl_lam / fl_d2);
}

vec3 flash_light(vec3 fl_w, vec3 fl_n, vec3 fl_refl) {
	if (prog_flash_c0.r + prog_flash_c0.g + prog_flash_c0.b <= 0.0) {
		return vec3(0.0);      // (nothing lit: slot 0 fills first)
	}
	vec3 fl_sum = flash_one(prog_flash_p0, prog_flash_c0, fl_w, fl_n) + flash_one(prog_flash_p1, prog_flash_c1, fl_w, fl_n) + flash_one(prog_flash_p2, prog_flash_c2, fl_w, fl_n) + flash_one(prog_flash_p3, prog_flash_c3, fl_w, fl_n);
	return fl_sum * fl_refl;
}
