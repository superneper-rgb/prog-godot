// A mirror's glass (three.js ReflectorShader): the mirrored camera's picture of the glass itself, looked up by position on the glass. That camera looks out of the wall through the glass, so its right is the glass's left.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;
uniform sampler2D mirror_tex : source_color, filter_linear, repeat_disable;
uniform vec3 tint = vec3(1.0);
uniform vec2 glass_size = vec2(1.0);
varying vec2 on_glass;

void vertex() {
	on_glass = VERTEX.xy / glass_size;
}

void fragment() {
	ALBEDO = texture(mirror_tex, vec2(0.5 - on_glass.x, 0.5 - on_glass.y)).rgb * tint;
}
