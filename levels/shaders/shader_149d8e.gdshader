// shader_149d8e (three.js ShaderMaterial, level visiting-hours). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never;

#include "res://levels/shaders/common.gdshaderinc"

uniform float uT;
uniform float uLit;
uniform float uHW;
uniform vec4 uRip[16];
uniform vec3 uLp;
float h1(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5); }
float n2(vec2 p){ vec2 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f); return mix(mix(h1(i), h1(i + vec2(1.0, 0.0)), f.x), mix(h1(i + vec2(0.0, 1.0)), h1(i + vec2(1.0, 1.0)), f.x), f.y); }
float rip(vec2 p, out float crest){ float w = 0.; crest = 0.;
        for (int i = 0; i < 16; i++) { float age = uT - uRip[i].z; if (age < 0. || age > 2.2) continue; float d = distance(p, uRip[i].xy), r = .05 + age * .42, k = abs(d - r);
          float a = uRip[i].w * (1. - age / 2.2) * exp(-k * 14.) / (1. + d * 3.); w += sin((d - r) * 34.) * a; crest += a; }
        return w * .016; }
float hgt(vec2 p, out float crest){ vec2 fl = vec2(p.x + uT * .55, p.y); float chop = (n2(fl * vec2(1.6, 4.)) - .5) * .008 + sin(fl.x * 7. + p.y * 9. + uT * 2.) * .0015;
        return chop + rip(p, crest); }
varying vec3 vW;

void vertex() {
	vec4 w = MODEL_MATRIX * vec4(VERTEX, 1.); float c; w.y += hgt(w.xz, c); vW = w.xyz; vec4 mvPosition = VIEW_MATRIX * w; POSITION = PROJECTION_MATRIX * mvPosition;
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	vec2 p = vW.xz, fl = vec2(p.x + uT * .55, p.y); float c0, c1, c2, e = .015;
	float h0 = hgt(p, c0), hx = hgt(p + vec2(e, 0.), c1), hz = hgt(p + vec2(0., e), c2);
	vec3 N = normalize(vec3(-(hx - h0) / e, 1., -(hz - h0) / e)), V = normalize(CAMERA_POSITION_WORLD - vW);
	float fres = .03 + .97 * pow(1. - max(dot(N, V), 0.), 5.);
	vec3 Lv = uLp - vW; float Ld = length(Lv); Lv /= Ld; float att = 4. / (1. + Ld * Ld * .06);
	float spec = pow(max(dot(N, normalize(Lv + V)), 0.), 90.) * att * 1.6;
	float scum = n2(fl * vec2(1.2, 4.)) * .6 + n2(fl * vec2(3.5, 9.) + 7.) * .4;
	float edge = smoothstep(uHW - .14, uHW, abs(p.y - 961.00)) * (.5 + .5 * n2(fl * vec2(5., 16.) + uT * .4));
	float foam = clamp(edge + smoothstep(.15, .5, c0) * n2(p * 22. + uT), 0., 1.);
	vec3 body = mix(vec3(.10, .09, .045), vec3(.21, .19, .09), scum) * (uLit + att * .25 * max(N.y, 0.));
	vec3 col = mix(body, vec3(.035, .035, .03) * (uLit * 2. + att * .4), fres) + vec3(1., .94, .8) * spec + vec3(.62, .6, .5) * foam * (uLit + att * .3);
	fc_ = vec4(col, clamp(.8 + fres * .2 + foam * .3 - scum * .06, 0., 1.));
	ALBEDO = display_to_radiance(fc_.rgb);
	ALPHA = fc_.a;
}
