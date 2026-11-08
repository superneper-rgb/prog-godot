// The city's soft sprites, blended (steam puffs; see city_sprites.gdshaderinc). three.js blends on display values: over a dark street this draws the same picture.
shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never, skip_vertex_transform, cull_disabled;

#include "res://levels/shaders/common.gdshaderinc"
#include "res://levels/shaders/city_sprites.gdshaderinc"

void fragment() {
	vec4 tx = texture(map, vUv);
	float al = tx.a * vCol.a;
	ALBEDO = add_display(vCol.rgb * tx.rgb, al) / max(al, 0.0001);
	ALPHA = al;
}
