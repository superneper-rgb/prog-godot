// The city's glowing sprites, additive (see city_sprites.gdshaderinc).
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, skip_vertex_transform, cull_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"
#include "res://levels/shaders/city_sprites.gdshaderinc"

void fragment() {
	vec4 tx = texture(map, vUv);
	ALBEDO = add_display(vCol.rgb * tx.rgb, tx.a * vCol.a);
}
