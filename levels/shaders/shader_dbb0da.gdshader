// shader_dbb0da (three.js ShaderMaterial, level visiting-hours). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never;

#include "res://levels/shaders/common.gdshaderinc"

varying vec3 vW;
varying vec2 vUv;
uniform float uFlash;
uniform float uShore;
uniform vec3 uSky;
float hh(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float rings(vec2 p, float s){ vec2 c = floor(p / s), f = fract(p / s) - .5; float r = 0.;
        for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) { vec2 o = vec2(float(x), float(y)), id = c + o; vec2 ctr = o + vec2(hh(id), hh(id + 7.)) - .5;
          float t = fract(TIME * (.7 + hh(id + 3.) * .6) + hh(id + 11.)), d = length(f - ctr) * s, R = t * .45 * s;
          r += (1. - smoothstep(0., .035, abs(d - R))) * (1. - t); }
        return r; }

void vertex() {
	vUv = UV; vec4 w = MODEL_MATRIX * vec4(VERTEX, 1.); vW = w.xyz; vec4 mvPosition = VIEW_MATRIX * w; POSITION = PROJECTION_MATRIX * mvPosition;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	vec3 V = normalize(CAMERA_POSITION_WORLD - vW); float fr = pow(1. - max(V.y, 0.), 4.);
	float rp = rings(vW.xz, 1.1) + rings(vW.xz + 13.7, .7) * .7;
	float wob = sin(atan(vUv.y - .5, vUv.x - .5) * 7. + vW.x * .3) * .025, edge = mix(1., smoothstep(.5, .36, length(vUv - .5) + wob), uShore);
	float ns = hh(floor(vW.xz * .25)) * .5 + hh(floor(vW.xz * .07)) * .5;
	vec3 c = mix(vec3(.012, .03, .045), vec3(.025, .06, .07), ns) + uSky * (fr * .45 + rp * .14 + .03) + vec3(.7, .78, .95) * uFlash * (fr * .7 + .04 + rp * .25);
	fc_ = vec4(c, edge * .92);
	ALBEDO = display_to_radiance(fc_.rgb);
	ALPHA = fc_.a;
}
