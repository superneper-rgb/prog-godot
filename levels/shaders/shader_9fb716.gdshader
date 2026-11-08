// Storm cloud skybox (three.js ShaderMaterial, level warehouse). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform vec3 uCenter;
varying vec3 direction;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1.0,0.0)),f.x),mix(hash(i+vec2(0.0,1.0)),hash(i+1.),f.x),f.y);}

void vertex() {
	vec3 dome_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - uCenter;
	direction=dome_p;POSITION=PROJECTION_MATRIX*MODELVIEW_MATRIX*vec4(dome_p,1.);
	vec4 dome_c = PROJECTION_MATRIX * VIEW_MATRIX * vec4(CAMERA_POSITION_WORLD + dome_p, 1.0);
	POSITION = vec4(dome_c.xy, 0.0, dome_c.w);
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	vec3 d=normalize(direction);vec2 uv=d.xz/(abs(d.y)+.24)*1.8+vec2(TIME*.002,0.);
	float cloud=noise(uv)*.57+noise(uv*2.1)*.28+noise(uv*4.3)*.15;
	float horizon=pow(1.-abs(d.y),5.);vec3 color=mix(vec3(.002,.004,.009),vec3(.018,.029,.048),horizon);
	color+=vec3(.008,.012,.018)*smoothstep(.3,.8,cloud);
	float glow=pow(max(0.,dot(d,normalize(vec3(-.4,.18,-.8)))),18.);
	color+=vec3(.025,.035,.055)*glow*(1.-cloud*.8);fc_=vec4(color,1.);
	ALBEDO = fc_.rgb;
}
