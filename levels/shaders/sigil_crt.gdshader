// The Sigil's head (enemies/sigil_beast_view.gd): the glass of its 90s television, showing its face (ui/sigil_face.gd drawn into a SubViewport). Barrel-bent picture, the tube's lines, a dark
// rim where the picture falls off the curve, and glossy glass over it all. `energy` is how hard it burns (the fight blinks it when the set itself is the target).
shader_type spatial;
render_mode cull_back;

uniform sampler2D face : source_color, filter_linear, repeat_disable;
uniform float energy = 2.6;
uniform float flash = 0.0;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	q *= 1.0 + 0.07 * dot(q, q);
	vec2 uv = q * 0.5 + 0.5;
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	vec3 c = texture(face, uv).rgb;
	float scan = 0.72 + 0.28 * sin(uv.y * 240.0 * 3.14159);
	float vig = smoothstep(1.25, 0.55, length(q));
	ALBEDO = vec3(0.008);
	ROUGHNESS = 0.07;
	SPECULAR = 0.7;
	EMISSION = c * scan * vig * inside * energy + vec3(1.0, 0.55, 0.15) * flash * 0.4;
}
