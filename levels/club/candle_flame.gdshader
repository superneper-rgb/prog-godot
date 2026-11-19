// CLUB 9's candle flames (levels/club/club_dressing.gd): a small glowing teardrop that flickers and leans, each instance on its own clock. Unshaded: it is the light.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

void vertex() {
	float id = float(INSTANCE_ID);
	float f = 1.0 + 0.18 * sin(TIME * 17.0 + id * 2.3) + 0.1 * sin(TIME * 31.0 + id * 5.1);
	float up = max(VERTEX.y, 0.0);
	VERTEX.y *= f;
	VERTEX.xz *= 1.0 - 0.45 * up;                          // pinched to a point at the top
	VERTEX.x += up * 0.25 * sin(TIME * 3.1 + id);          // leaning in a draught
}

void fragment() {
	float tip = clamp(UV.y, 0.0, 1.0);
	ALBEDO = mix(vec3(1.0, 0.86, 0.45), vec3(1.0, 0.38, 0.08), tip) * 3.0;
}
