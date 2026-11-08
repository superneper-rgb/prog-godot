// volcano cone (three.js ShaderMaterial, level omnisphere). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying vec3 vWP;
varying vec3 vN;
varying vec3 vInfo;
uniform vec2 uC;
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
	vec4 w = MODEL_MATRIX * vec4(VERTEX, 1.); vWP = w.xyz; vN = normalize(mat3(MODEL_MATRIX) * NORMAL); vInfo = CUSTOM0.xyz;
	vec4 mvPosition = VIEW_MATRIX * w; POSITION = PROJECTION_MATRIX * mvPosition;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	vec3 N = normalize(vN), P = vWP; float y = P.y, ang = vInfo.x, outer = vInfo.y, t = vInfo.z;
	float big = lFbm(P.xz * .0035), fine = lFbm(vec2(ang * 150., y * .05)), grain = lNoise(P.xz * .09 + y * .07);
	float strata = .5 + .5 * sin(y * .055 + fine * 5.);
	vec3 alb = mix(vec3(.05, .04, .038), vec3(.15, .07, .042), strata * .6 * (1. - outer));
	alb = mix(alb, vec3(.12, .108, .1), outer * smoothstep(.25, .9, N.y) * (.55 + .45 * big));
	alb *= .65 + .5 * fine + .2 * grain;
	vec3 L = mix(vec3(.09, .055, .05), vec3(.2, .13, .11), N.y * .5 + .5) + vec3(.8, .28, .09) * max(N.y, 0.) * .3 + vec3(.5, .22, .12) * outer * (.6 + .4 * N.y);
	vec3 Ld = normalize(vec3(uC.x, -60., uC.y) - P);
	L += vec3(2.6, .78, .2) * max(dot(N, Ld), 0.) * exp(-max(y, 0.) / 420.) * (1. - outer * .8);
	vec3 col = alb * L;
	float inner = 1. - outer;
	col += vec3(1.3, .28, .04) * exp(-max(y + 10., 0.) / 22.) * inner;
	float ck = lNoise(vec2(ang * 110., y * .045)) * .7 + lNoise(vec2(ang * 330., y * .14)) * .3;
	col += lRamp(.8) * (1. - smoothstep(.0, .03, abs(ck - .5))) * exp(-max(y, 0.) / 95.) * inner * .9;
	{ float fa = ang * 29. / 6.2831853, bin = mod(floor(fa), 29.), hs = lHash(vec2(bin, 3.1));
	float top = 140. + lHash(vec2(bin, 8.7)) * 360., w = abs(fract(fa) - .5 + (lNoise(vec2(y * .012, bin * 3.)) - .5) * .3);
	float flow = lFbm(vec2(fract(fa) * 30., y * .025 + TIME * .9));
	float m = step(.72, hs) * (1. - smoothstep(.01, .026, w)) * smoothstep(top + 4., top - 18., y) * inner;
	col += lRamp(.55 + .45 * flow) * m * 1.2;
	col += vec3(1.4, .4, .08) * step(.72, hs) * (1. - smoothstep(.0, .06, w)) * exp(-abs(y - top) / 14.) * inner;
	}
	{ float fb0 = ang * 19. / 6.2831853, bin = mod(floor(fb0), 19.), hs = lHash(vec2(bin, 5.7)), len = .16 + lHash(vec2(bin, 1.9)) * .4;
	float fb = fb0 + sin(t * 11. + bin * 2.3) * .07 + (lNoise(vec2(t * 18., bin)) - .5) * .12, w = abs(fract(fb) - .5);
	float u = t / len, wid = mix(.008, .026, clamp(u, 0., 1.));
	float crust = lFbm(vec2(fract(fb) * 60., t * 90. - TIME * .05));
	float m = step(.32, hs) * outer * (1. - smoothstep(wid * .6, wid, w)) * smoothstep(1., .75, u);
	col = mix(col, col * .45, step(.32, hs) * outer * (1. - smoothstep(wid, wid * 1.8, w)) * smoothstep(1.2, .8, u));
	col += lRamp(clamp(.95 - u * .55 + (crust - .5) * .5, 0., 1.)) * m * 1.15;
	}
	col += vec3(.9, .25, .05) * smoothstep(.93, 1., t) * inner * .5;
	fc_ = vec4(col, 1.);
	ALBEDO = fc_.rgb;
}
