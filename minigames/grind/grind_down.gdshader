// RAILJACK: the scene buffer shrunk into a small viewport (the bloom canvas, the ASCII grid). A little box filter so thin lines survive the shrink, as they do in the browser's drawImage.
shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D src : filter_linear, repeat_disable;

void fragment() {
	vec2 h = fwidth(UV) * 0.25;
	vec3 c = texture(src, UV + vec2(-h.x, -h.y)).rgb + texture(src, UV + vec2(h.x, -h.y)).rgb + texture(src, UV + vec2(-h.x, h.y)).rgb + texture(src, UV + vec2(h.x, h.y)).rgb;
	COLOR = vec4(c * 0.25, 1.0);
}
