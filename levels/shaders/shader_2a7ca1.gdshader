// shader_2a7ca1 (three.js ShaderMaterial, level visiting-hours). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

varying vec3 vDir;
uniform float uFlash;
uniform float uSheet;
uniform vec3 uStrike;
uniform vec3 uSheetDir;
uniform vec3 uFog;
uniform vec2 uGlowDir;
uniform vec2 uCityDir;
float h1(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p){ vec2 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f); return mix(mix(h1(i), h1(i + vec2(1.0, 0.0)), f.x), mix(h1(i + vec2(0.0, 1.0)), h1(i + 1.), f.x), f.y); }
float fbm(vec2 p){ float a = .5, s = 0.; for (int i = 0; i < 5; i++) { s += a * n2(p); p = p * 2.03 + 17.1; a *= .5; } return s; }

void vertex() {
	vDir = normalize(VERTEX);
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	vec3 d = normalize(vDir); float h = d.y, hz = max(h, 0.) + .07;
	vec2 p = d.xz / hz;
	float lo = fbm(p * 1.3 + vec2(TIME * .018, TIME * .006)), hi = fbm(p * .55 - vec2(TIME * .007, 0.) + 9.);
	float dens = smoothstep(.38, .78, lo * .65 + hi * .55);
	float band = floor(dens * 4.) / 4.;
	vec3 top = vec3(.035, .045, .062), belly = vec3(.11, .13, .17), deep = vec3(.018, .022, .03);
	vec3 c = mix(top, belly, band); c = mix(c, deep, smoothstep(.75, 1., dens) * .7);
	c += vec3(.06, .075, .1) * smoothstep(.45, .5, dens) * (1. - smoothstep(.5, .62, dens));
	vec2 hd = normalize(d.xz + 1e-4); float low = 1. - smoothstep(.0, .45, h);
	float pg = pow(max(dot(hd, uGlowDir), 0.), 18.), cg = pow(max(dot(hd, uCityDir), 0.), 10.);
	c += vec3(.55, .28, .08) * pg * low * (.25 + dens * .6) * .55 + vec3(.35, .12, .3) * cg * low * (.2 + dens * .5) * .45 + vec3(.05, .2, .25) * cg * low * low * .25;
	float ang = atan(d.x, d.z) * 60.; float bx = floor(ang); float bh = (.004 + h1(vec2(bx, 3.)) * .016 + step(.93, h1(vec2(bx, 9.))) * .02) * smoothstep(.55, .95, dot(hd, uCityDir));
	if (h < bh && h > -.02) { c = vec3(.015, .012, .02); if (h1(floor(vec2(ang * 4., h * 900.))) > .93) c += vec3(.5, .3, .45) * .6; }
	float sk = pow(max(dot(d, normalize(uStrike)), 0.), 7.); c += vec3(.55, .62, .85) * uFlash * (.18 + sk * (1.2 + dens * 2.));
	float sh = pow(max(dot(d, normalize(uSheetDir)), 0.), 14.); c += vec3(.35, .38, .55) * uSheet * sh * (.3 + dens * 1.6);
	c = mix(uFog, c, smoothstep(-.02, .14, h) * .9 + .1 * step(.14, h));
	fc_ = vec4(c, 1.);
	ALBEDO = display_to_radiance(fc_.rgb);
}
