// A still glow sprite of an exported level (three.js Sprite, additive): one quad facing the camera, blended on the display value like the JS. A BaseMaterial3D billboard cannot take add_display (core/material_look.gd does not write billboards), and pre-tone-map additive comes out far too bright.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, skip_vertex_transform, cull_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform sampler2D map : source_color, filter_linear_mipmap;
uniform vec3 col = vec3(1.0);
uniform float opacity = 1.0;

varying vec2 vUv;

void vertex() {
	vUv = UV;
	vec3 c = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	VERTEX = c + vec3(VERTEX.xy, 0.0);
}

void fragment() {
	vec4 t = texture(map, vUv);
	// (the exporter folds a toned material's colour into its vertex colours, sRGB encoded: the lamps' sodium amber lives here, and col is white)
	ALBEDO = add_display(col * srgb_decode(COLOR.rgb) * t.rgb, t.a * opacity);
}
