// shader_312693 (three.js ShaderMaterial, level visiting-hours). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying float vA;
varying float vEnd;
uniform float uFlash;
uniform float uLit;

void vertex() {
	vec3 p = VERTEX; float sp = 21. + fract(p.x * 13.1) * 6.; p.y = mod(p.y - TIME * sp, 34.); p.x += (34. - p.y) * .2;
	vec3 w = vec3(mod(p.x - CAMERA_POSITION_WORLD.x + 35., 70.) - 35. + CAMERA_POSITION_WORLD.x, p.y - 12. + CAMERA_POSITION_WORLD.y, mod(p.z - CAMERA_POSITION_WORLD.z + 35., 70.) - 35. + CAMERA_POSITION_WORLD.z);
	float e = floor(CUSTOM0.x + .5); w += e * vec3(-.07, .62, 0.); vEnd = e;
	float d = length(w - CAMERA_POSITION_WORLD); vA = smoothstep(34., 4., d) * smoothstep(.5, 2.5, d);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.);
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	float a = vA * (.16 + uFlash * .5 + uLit * .2) * mix(1., .25, vEnd); fc_ = vec4(vec3(.72,.8,.9) * (1. + uFlash * 2.), a);
	ALBEDO = display_to_radiance(fc_.rgb);
	ALPHA = fc_.a;
}
