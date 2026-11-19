// OMNISPHERE: a capacitor bank's glass tube (levels/omnisphere/om_lab.gd). It was one flat green cylinder. Now it is dark glass you see the core through: a bright rim at
// grazing angles, charge rings climbing it, a faint stain of the core's colour, all of it following the plant's power (omni_power, which the Draw pulls down).
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, unshaded;

uniform vec3 tint : source_color = vec3(0.25, 1.0, 0.62);
global uniform float omni_power;
varying vec3 v_lp;

void vertex() {
	v_lp = VERTEX;
}

void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	float pw = 0.15 + 0.85 * omni_power;
	float ring = smoothstep(0.82, 1.0, sin(v_lp.y * 2.6 - TIME * 2.4) * 0.5 + 0.5);
	float band = smoothstep(0.9, 1.0, sin(v_lp.y * 0.58 + 1.0) * 0.5 + 0.5);      // the glass's own hoops
	vec3 glow = tint * (f * 1.6 + ring * 0.35 + 0.06) * pw;
	ALBEDO = mix(glow, vec3(0.02, 0.03, 0.03), band * 0.7);
	ALPHA = clamp(0.1 + f * 0.75 + ring * 0.12 + band * 0.6, 0.0, 1.0);
}
