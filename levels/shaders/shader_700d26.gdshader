// East river / rain surface (three.js ShaderMaterial, level warehouse). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying vec3 p;

void vertex() {
	p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(p,1.);
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	float wave=sin(p.x*2.4+p.z*4.+TIME*2.)*.5+sin(p.x*5.-p.z*1.8-TIME*3.)*.3;
	float bands=pow(max(0.,sin(p.x*.24+sin(p.z*.4+TIME)*.15)),22.);
	float broken=smoothstep(.12,.8,sin(p.z*6.+wave*3.));
	vec3 color=vec3(.004,.009,.016)+vec3(.025,.045,.065)*bands*broken;
	color+=vec3(.09,.05,.015)*pow(max(0.,sin(p.x*.095)),38.)*broken*.4;
	float haze=1.-exp(-length(CAMERA_POSITION_WORLD-p)*.0018);color=mix(color,vec3(.012,.021,.034),haze);
	fc_=vec4(color,1.);
	ALBEDO = fc_.rgb;
}
