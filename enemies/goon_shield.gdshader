// FOINT goon: the adjuster's energy shield (JS foint-goon-dress.js buildShield): an additive curved sheet with the hex texture, tiled and scrolling on the face, one unrepeated copy for the bright edge.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform sampler2D hex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool edge = false;
instance uniform vec3 tint = vec3(0.05, 0.27, 1.0);
instance uniform float opacity = 0.0;
instance uniform float scroll = 0.0;

void fragment() {
	// (the JS canvas texture is flipped in v, and its offset is added before that)
	vec2 uv = vec2(UV.x, 1.0 - (UV.y + scroll));
	vec4 c = edge ? textureLod(hex, clamp(uv, vec2(0.002), vec2(0.998)), 0.0) : texture(hex, uv);
	ALBEDO = add_display(tint * c.rgb, c.a * opacity);
	ALPHA = 1.0;
}
