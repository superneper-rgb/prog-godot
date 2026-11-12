// FOINT DOME's giant screen (JS tournament-tv.js picture: toneMapped false): shows the broadcast / menu viewport as the display colours it holds.
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform sampler2D screen : filter_linear, repeat_disable;

void fragment() {
	ALBEDO = display_to_radiance(texture(screen, UV).rgb);
}
