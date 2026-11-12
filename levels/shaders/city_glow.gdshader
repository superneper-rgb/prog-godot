// FOINT CITY's lit seams, lamp heads, LED studs and kerb channels: the district's glow merge (JS district-view.js `glow`, DistrictGlow), a light source in its own right, drawn as
// the plain unlit material it was (vertex colour, sRGB, times the export's untone-mapped gain) on both sides. Its own shader only so the cut Deck lamps' heads can fold away
// (levels/shaders/city_cut.gdshaderinc, levels/hub/deck_look.gd).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://levels/shaders/city_cut.gdshaderinc"

uniform vec3 gain = vec3(2.3765645, 2.3765645, 2.3769784);      // the export's albedo colour: three.js toneMapped false, made up in Godot's HDR

varying vec3 v_col;

void vertex() {
	vec3 c = COLOR.rgb;
	v_col = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 cw = city_cut(wp);
	if (cw != wp) {
		VERTEX = (inverse(MODEL_MATRIX) * vec4(cw, 1.0)).xyz;
	}
}

void fragment() {
	ALBEDO = v_col * gain;
}
