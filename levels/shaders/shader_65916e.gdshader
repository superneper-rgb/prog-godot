// CityWalls, CityShops, the alley's brick (JS levels/hub/city-kit.js facadeMaterial): the facade map shaded by a baked per-vertex shade, plus the lit windows and signs of its glow map.
shader_type spatial;
render_mode unshaded, shadows_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform sampler2D map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D glowMap : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float uGlow = 1.0;

varying vec3 vShade;

void vertex() {
	vShade = srgb_decode(COLOR.rgb);       // the exporter stores vertex colours sRGB encoded (their darks need the precision); the JS attribute is the linear value
}

void fragment() {
	vec3 a = texture(map, UV).rgb;
	vec3 g = texture(glowMap, UV).rgb;
	ALBEDO = a * vShade + g * uGlow * (0.6 + 0.4 * vShade.g);
}
