// A boost icon on the run (sky_items.gd, Hydro Thunder style): a hexagon plate standing on its edge, turning, bright at its rim with a
// chevron burned into its faces. Its colour (blue: a little boost, red: a lot) comes from the MultiMesh instance colour.
shader_type spatial;
render_mode unshaded;

uniform vec3 tint : source_color = vec3(1.0);
uniform float power = 1.0;

varying vec3 local_pos;
varying vec3 col;

void vertex() {
	local_pos = VERTEX;
	col = COLOR.rgb;
	float a = TIME * 2.6 + float(INSTANCE_ID) * 0.9;
	float c = cos(a);
	float s = sin(a);
	VERTEX.xy = mat2(vec2(c, s), vec2(-s, c)) * VERTEX.xy;
	VERTEX *= 1.0 + 0.06 * sin(TIME * 6.0 + float(INSTANCE_ID));
}

void fragment() {
	vec2 p = local_pos.xz;
	float r = length(p);
	float rim = smoothstep(0.7, 0.9, r);
	float chev = 1.0 - smoothstep(0.06, 0.12, abs(abs(p.x) * 0.8 + p.y * 0.7 - 0.25));
	chev *= step(r, 0.65);
	float side = 1.0 - smoothstep(0.08, 0.11, abs(local_pos.y));
	ALBEDO = col * (0.35 + rim * 2.2 + chev * 1.8 + (1.0 - side) * 0.8) * power;
}
