// FX particles, normal blending (smoke, steam): JS MeshBasicMaterial transparent, no depth write.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled, skip_vertex_transform;
#include "part.gdshaderinc"

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = v_a * smoothstep(0.15, 1.2, -VERTEX.z);      // (thins out in the last metre before the lens: a cube passing the camera would otherwise grey the whole frame)
}
