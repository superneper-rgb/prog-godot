// shader_fbf9e3 (three.js ShaderMaterial, level kame-lab). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying vec2 vUv;
varying vec3 vN;
varying vec3 vV;
uniform float uAlpha;
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
	float f = abs(dot(normalize(vN), normalize(vV)));
	float n = texture(uNoise, vec2(vUv.x * 3.0 + TIME * 0.25, vUv.y * 2.0 - TIME * 0.9)).r;
	float rim = pow(1.0 - f, 2.6) * uRim, a = (rim + uFill * (0.4 + n) * f) * uAlpha;
	fc_ = vec4(mix(uColor, uHot, clamp(rim * 0.8 + uFill * f * n, 0.0, 1.0)), a);
	ALBEDO = display_to_radiance(fc_.rgb * fc_.a);
}
