// Main menu backdrop: the searchlight's beam (JS BEAM_VS, BEAM_FS): an additive cone, bright at the lamp, fading along its length and at its edges.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 color = vec3(1.0);
uniform float intensity = 0.55;

void fragment() {
	float f = abs(dot(NORMAL, normalize(VIEW)));
	float a = pow(UV.y, 2.2) * pow(f, 1.6) * intensity;
	ALBEDO = color * a;
	ALPHA = a;
}
