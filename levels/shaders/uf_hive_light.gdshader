// The point of light at the nape of every body in the Sigil's throne (levels/underfoint/uf_throne.gd): dim, and every five seconds all of them come up together and hold, as the Taken's heads do.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec3 glow : source_color = vec3(0.18, 0.88, 0.38);

void fragment() {
	float beat = fract(TIME / 5.0) * 5.0;
	float up = smoothstep(0.0, 0.12, beat) * (1.0 - smoothstep(1.3, 1.7, beat));
	ALBEDO = glow * (0.35 + 1.5 * up);
}
