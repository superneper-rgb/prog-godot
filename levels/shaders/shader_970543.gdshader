// shader_970543 (three.js ShaderMaterial, level kame-lab). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying vec2 vUv;
varying vec3 vN;
varying vec3 vV;
uniform float uAlpha;
uniform float uLen;
uniform float uSpiral;
uniform float uRim;
uniform float uFill;
uniform vec3 uColor;
uniform vec3 uHot;
uniform sampler2D uNoise : repeat_enable, filter_linear_mipmap_anisotropic;

void vertex() {
	vUv = UV; vec4 mv = MODELVIEW_MATRIX * vec4(VERTEX, 1.0); vN = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz); vV = normalize(-mv.xyz); POSITION = PROJECTION_MATRIX * mv;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	float f = abs(dot(normalize(vN), normalize(vV))), along = vUv.y * uLen;
	float n = texture(uNoise, vec2(vUv.x * 2.0 + TIME * 0.4, along * 0.18 - TIME * 2.6)).r;
	float n2 = texture(uNoise, vec2(vUv.x * 3.0 - TIME * 0.7, along * 0.45 - TIME * 6.0)).r;
	float body = uFill * smoothstep(0.0, 0.75, f) + uRim * pow(1.0 - f, 2.0);
	float spi = uSpiral * smoothstep(0.55, 1.0, sin(vUv.x * 12.566 + along * 2.2 - TIME * 30.0)) * (0.5 + n2);
	float a = clamp(body * (0.55 + 0.9 * n) + spi, 0.0, 1.6) * uAlpha;
	vec3 col = mix(uColor, uHot, clamp(body * n + spi * 0.6, 0.0, 1.0));
	fc_ = vec4(col, a);
	ALBEDO = display_to_radiance(fc_.rgb * fc_.a);
}
