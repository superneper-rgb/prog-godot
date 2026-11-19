// Animated hot core and ion wake on tapered exhaust ribbons.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec4 plasma : source_color = vec4(0.25, 0.76, 1.0, 1.0);
instance uniform float power = 0.0;

void fragment() {
	float along = UV.y;
	float side = abs(UV.x * 2.0 - 1.0);
	float vortices = sin(along * 86.0 - TIME * 51.0) * 0.5 + 0.5;
	float weight = (1.0 - smoothstep(0.0, 0.93 - 0.35 * along, side)) * pow(1.0 - along, 1.45);
	float white_hot = pow(1.0 - side, 5.0) * pow(1.0 - along, 6.0);
	ALBEDO = mix(plasma.rgb * (1.0 + power * 1.7), vec3(0.75, 0.95, 1.0) * 3.0, white_hot);
	ALPHA = weight * (0.54 + power * 0.39) * (0.62 + vortices * 0.38);
}
