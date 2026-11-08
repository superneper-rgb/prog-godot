// ash sky (three.js ShaderMaterial, level omnisphere). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform vec3 uCenter;
varying vec3 vDir;
uniform float uFlash;
uniform vec2 uFlashDir;
uniform vec3 uFog;
float lHash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float lNoise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f); return mix(mix(lHash(i), lHash(i + vec2(1., 0.)), f.x), mix(lHash(i + vec2(0., 1.)), lHash(i + vec2(1., 1.)), f.x), f.y); }
float lFbm(vec2 p) { float s = 0., a = .5; for (int i = 0; i < 4; i++) { s += a * lNoise(p); p = p * 2.03 + vec2(1.7, 9.2); a *= .5; } return s; }
vec3 lVoro(vec2 p) {
  vec2 i = floor(p), f = fract(p); float d1 = 8., d2 = 8., id = 0.;
  for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
    vec2 g = vec2(float(x), float(y)), o = vec2(lHash(i + g), lHash(i + g + 19.7)), r = g + o - f; float d = dot(r, r);
    if (d < d1) { d2 = d1; d1 = d; id = lHash(i + g + 5.3); } else if (d < d2) d2 = d;
  }
  return vec3(sqrt(d1), sqrt(d2), id);
}
vec3 lRamp(float t) {
  vec3 c = mix(vec3(.02, .008, .005), vec3(.45, .03, .005), smoothstep(.0, .3, t));
  c = mix(c, vec3(1.5, .32, .03), smoothstep(.25, .6, t));
  return mix(c, vec3(2.1, 1.05, .26), smoothstep(.62, .97, t));
}

void vertex() {
	vec3 dome_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - uCenter;
	vDir = dome_p; POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(dome_p, 1.);
	vec4 dome_c = PROJECTION_MATRIX * VIEW_MATRIX * vec4(CAMERA_POSITION_WORLD + dome_p, 1.0);
	POSITION = vec4(dome_c.xy, 0.0, dome_c.w);
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	vec3 d = normalize(vDir); float e = d.y;
	vec3 col = mix(uFog * 1.5 + vec3(.05, .012, 0.), vec3(.016, .007, .008), smoothstep(-.02, .5, e));
	vec2 cp = d.xz / max(e + .14, .05) * 1.8 + vec2(TIME * .011, TIME * .006);
	float c = smoothstep(.32, .82, lFbm(cp) * .75 + lFbm(cp * 3.1 - TIME * .01) * .35);
	vec3 cloud = mix(vec3(.045, .022, .018), vec3(.6, .17, .05), smoothstep(.45, -.02, e) * (.4 + .6 * lFbm(cp * 2.)));
	col = mix(col, cloud, c * smoothstep(-.05, .12, e) * .9);
	col += vec3(.5, .11, .02) * exp(-max(e, 0.) * 12.) * .55;
	float fl = uFlash * smoothstep(.8, 1., dot(normalize(d.xz + 1e-4), uFlashDir)) * smoothstep(.02, .3, e) * (.25 + c);
	col += vec3(.75, .62, .95) * fl;
	fc_ = vec4(mix(uFog, col, smoothstep(-.06, .02, e)), 1.);
	ALBEDO = fc_.rgb;
}
