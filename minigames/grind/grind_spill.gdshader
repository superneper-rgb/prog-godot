// RAILJACK: the dark room behind the monitor, with the screen's colour spilling onto it (JS composite: the #010301 fill and the radial spill).
shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 win = vec2(1920.0, 1080.0);
uniform float r0 = 200.0;
uniform float r1 = 1400.0;
uniform vec4 col = vec4(0.08, 0.31, 0.16, 0.35);

void fragment() {
	float d = length(UV * win - win * 0.5);
	float k = clamp((d - r0) / (r1 - r0), 0.0, 1.0);
	float a = col.a * (1.0 - k);
	vec3 c = vec3(1.0, 3.0, 1.0) / 255.0;
	COLOR = vec4(mix(c, col.rgb * (1.0 - k) + vec3(0.0), a), 1.0);
}
