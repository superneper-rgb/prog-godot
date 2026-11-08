// lava sea (three.js ShaderMaterial, level omnisphere). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying vec3 vWP;
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
float lavaTemp(vec2 p, float t, out float crust) {
    vec2 q = p * .011;
    vec2 warp = vec2(lFbm(q + vec2(0., t * .016)), lFbm(q + vec2(5.2, 1.3) - t * .013)) - .5;
    vec2 w = p * .028 + warp * 3.2;                                                         
    float zone = lFbm(p * .0042 + vec2(t * .005, -t * .004) + warp * .5);                    
    vec2 r = w + vec2(t * .016, t * .01);                                                   
    vec3 v1 = lVoro(r * 1.1), v2 = lVoro(r * 2.6 + 4.1);
    float big = smoothstep(.4, .62, lFbm(p * .006 + 11.));                                   
    float edge = mix(v2.y - v2.x, v1.y - v1.x, big) + (lNoise(r * 6.1) - .5) * .08 + (lNoise(r * 15.) - .5) * .03;   
    float id = big > .5 ? v1.z : v2.z;
    float amount = smoothstep(.38, .6, zone + id * .1);
    crust = smoothstep(.02, .11, edge) * amount;
    float seam = 1. - smoothstep(.0, .05, edge);
    float detail = lFbm(vec2(w.x * 2.4, w.y * 6.5) + vec2(t * .22, -t * .09));               
    float river = 1. - amount;
    float temp = (1. - crust) * (.26 + .38 * detail + .36 * river * smoothstep(.35, .75, detail)) + seam * amount * .4;   
    temp *= .84 + .16 * sin(t * 1.25 + id * 30. + detail * 5.);
    
    vec2 bc = floor(p * .12); float bh = lHash(bc), ph = fract(t * (.15 + bh * .25) + bh * 7.);
    vec2 bp = (bc + .2 + .6 * vec2(lHash(bc + 3.1), lHash(bc + 8.7))) / .12;
    float br = (.6 + 1.6 * bh) * smoothstep(0., .8, ph), bd = length(p - bp);
    if (bh > .55) temp += (1. - crust) * (smoothstep(br, br * .55, bd) * .45 * (1. - smoothstep(.8, 1., ph)) + smoothstep(br * 1.6, br, bd) * smoothstep(.85, 1., ph) * .5);
    return clamp(temp, 0., 1.);
  }

void vertex() {
	vec4 w = MODEL_MATRIX * vec4(VERTEX, 1.); vWP = w.xyz; vec4 mvPosition = VIEW_MATRIX * w; POSITION = PROJECTION_MATRIX * mvPosition;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	vec2 p = vWP.xz; float t = TIME, crust;
	float temp = lavaTemp(p, t, crust), dist = length(CAMERA_POSITION_WORLD - vWP);
	vec3 rock = vec3(.028, .017, .013) * (.5 + .9 * lNoise(p * .35) * lNoise(p * 1.7 + 3.)) + vec3(.12, .01, 0.) * (1. - smoothstep(.0, .6, crust));
	vec3 col = mix(lRamp(temp), rock, crust * (1. - temp * .6));
	vec2 dpx = dFdx(p), dpy = dFdy(p); float dtx = dFdx(temp), dty = dFdy(temp), det = dpx.x * dpy.y - dpx.y * dpy.x;
	vec2 g = abs(det) > 1e-8 ? vec2(dtx * dpy.y - dty * dpx.y, dty * dpx.x - dtx * dpy.x) / det : vec2(0.);
	vec3 n = normalize(vec3(-g.x * 1.6, 1., -g.y * 1.6)), V = normalize(CAMERA_POSITION_WORLD - vWP), H = normalize(V + normalize(vec3(.2, .6, -.3)));
	col += vec3(1., .5, .22) * pow(max(dot(n, H), 0.), 40.) * .7 * (1. - crust) * smoothstep(300., 60., dist);
	fc_ = vec4(col, 1.);
	ALBEDO = fc_.rgb;
}
