// Purge electrical discharge, Foreman eye impact electricity (three.js ShaderMaterial, level warehouse). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, cull_disabled, depth_draw_never, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying vec2 vUv;
uniform float strength;

void vertex() {
	vUv=UV;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	float d=abs(vUv.y-.5)*2.;float hot=exp(-d*d*180.);
	float aura=exp(-d*d*7.)*pow(1.-d,2.);
	vec3 c=mix(vec3(.035,.28,1.),vec3(.75,1.,1.),hot);
	fc_=vec4(c,(hot*.95+aura*.48)*strength);
	ALBEDO = display_to_radiance(fc_.rgb * fc_.a);
}
