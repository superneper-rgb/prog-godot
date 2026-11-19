// Item energy (sky_items.gd): the mag harpoon's tether and the ram shell's plasma hull. Bright at the rim, bands crawling over it. Additive.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.6, 0.18);
uniform float power = 1.5;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	rim = pow(rim, 2.2);
	float bands = 0.5 + 0.5 * sin(local_pos.z * 14.0 - TIME * 18.0 + local_pos.y * 6.0);
	float flicker = 0.85 + 0.15 * sin(TIME * 41.0);
	ALBEDO = tint * power * (rim * 1.4 + bands * 0.18 + 0.05) * flicker;
}
