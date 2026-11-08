// OMNISPHERE paint (JS levels/omnisphere/paint.js, HEAD and BODY, statement for statement): world-space texturing (no UVs needed), painted edge wear, baked grime, magma heat toward the lava, and two level-wide dials every material reads: omni_power (the facility's power, which the Draw pulls down) and omni_alarm (the red alarm pulse).
// The export hands the per-vertex data over in glTF's slots (tools/export/page.js): COLOR.rgb = aTint, COLOR.a = the baked AO, UV = aGlow.rg, UV2.x = aGlow.b, UV2.y = aStyle + aWear * 0.99.

uniform sampler2D tBasalt : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tDeck : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tPaint : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tShield : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tRust : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tGrate : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float uStyle;
uniform float uLocal;
uniform vec3 uTint;
uniform vec3 uGlowCol;
global uniform float omni_power;
global uniform float omni_alarm;
varying vec3 vPW;
varying vec3 vPN;
varying vec3 vPL;
varying float vWear;
varying float vStyle;
varying vec3 vTint;
varying vec3 vGlow;
varying float vBvc;

float pH(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float pN(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3. - 2. * f); return mix(mix(pH(i), pH(i + vec2(1., 0.)), f.x), mix(pH(i + vec2(0., 1.)), pH(i + vec2(1., 1.)), f.x), f.y); }
float pF(vec2 p) { return .5 * pN(p) + .3 * pN(p * 2.03 + 7.1) + .2 * pN(p * 4.11 + 3.7); }
vec3 pV(vec2 p) {
	vec2 i = floor(p), f = fract(p); float d1 = 8., d2 = 8., id = 0.;
	for (int y = -1; y <= 1; y++) { for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y)), o = vec2(pH(i + g), pH(i + g + 19.7)), r = g + o - f; float d = dot(r, r);
		if (d < d1) { d2 = d1; d1 = d; id = pH(i + g + 5.3); } else if (d < d2) { d2 = d; }
	} }
	return vec3(sqrt(d1), sqrt(d2), id);
}
float pL(vec3 c) { return dot(c, vec3(.299, .587, .114)); }
vec3 pG(vec3 c, float s) { return mix(vec3(pL(c)), c, s); }
vec3 pT(sampler2D t, vec3 p, vec3 n, float s) {
	vec3 b = pow(abs(n), vec3(6.)); b /= (b.x + b.y + b.z + 1e-5);
	return texture(t, p.zy * s).rgb * b.x + texture(t, p.xz * s).rgb * b.y + texture(t, p.xy * s).rgb * b.z;
}
float pSeam(vec2 f, float w) { return max(1. - smoothstep(0., w, min(f.x, 1. - f.x)), 1. - smoothstep(0., w, min(f.y, 1. - f.y))); }


void omni_body(float uTime, float fy, out vec3 c, out vec3 pGlow, out float pRough, out float pMetal) {
	pGlow = vec3(0.); pRough = .8; pMetal = .1;
	float uPower = omni_power, uAlarm = omni_alarm, uLava = 0.;
	vec3 p = uLocal > .5 ? vPL : vPW, n = normalize(vPN); float up = n.y, k = vStyle > .5 ? vStyle : uStyle;      // local: textured in the object's own space (craft that move: nothing crawls over them)
	vec3 tint = vStyle > .5 ? vTint : uTint, glowCol = vStyle > .5 ? vGlow : uGlowCol;     // style / tint / glow per vertex when the geometry carries them (parts.js Batch merges every style into one mesh), else this material's
	float hz = abs(n.x) > abs(n.z) ? p.z : p.x;
	vec2 pc = abs(up) > .7 ? p.xz / 2.5 : vec2(hz / 3., p.y / 2.);                       // painted panel grid: 3 x 2 m on walls, 2.5 m tiles on floors
	vec2 cell = floor(pc); float rnd = pH(cell + k * 7.), seam = pSeam(fract(pc), .018) * .45;
	float grime = pF(p.xz * .21 + p.y * .13), bvc = vBvc;                        // vertex colour = baked AO (parts.js), the tint comes in uTint
	// textures are detail only: normalised to average 1 (the Poly Haven photos are very dark), the albedo comes from the style; low metalness (no environment map)
	float dS = pL(pT(tShield, p, n, .3)) / .095, dP = pL(pT(tPaint, p, n, .2)) / .07, dD = pL(pT(tDeck, p, n, .3)) / .031, dR = pL(pT(tRust, p, n, .16)) / .058, dG = pL(pT(tGrate, p, n, .55)) / .12;
	if (k < 1.5) { c = vec3(.085, .09, .1) * mix(1., dS, .6) * (.85 + .3 * rnd); pRough = .5; pMetal = .25; }
	else if (k < 2.5) { c = vec3(.3, .31, .33) * mix(1., dS, .5) * (.9 + .2 * rnd); pRough = .45; pMetal = .25; }
	else if (k < 3.5) { c = vec3(.42, .035, .022) * mix(1., dP, .45) * (.9 + .2 * rnd); pRough = .5; }
	else if (k < 4.5) { c = vec3(.17, .035, .028) * mix(1., dP, .5) * (.88 + .24 * rnd); pRough = .62; }
	else if (k < 5.5) { float s = step(.5, fract((p.x + p.z + p.y) * .42)); c = mix(vec3(.02), vec3(.62, .36, .02), s) * mix(1., dR, .35); seam = 0.; pRough = .6; }
	else if (k < 6.5) { c = vec3(.26, .25, .23) * mix(1., dD, .45) * (.85 + .3 * rnd); seam *= .6; pRough = .95; pMetal = 0.; }
	else if (k < 7.5) { c = vec3(.2, .2, .21) * mix(1., dD, .55) * (.9 + .2 * rnd); pRough = .7; pMetal = .15; }
	else if (k < 8.5) { c = vec3(.22, .2, .18) * mix(1., dG, .7); seam = 0.; pRough = .7; pMetal = .2; }
	else if (k < 9.5) { c = vec3(.3, .14, .07) * mix(vec3(1.), pT(tRust, p, n, .16) / vec3(.129, .039, .011) * .5 + .5, .6); pRough = .9; }
	else if (k < 10.5) { c = vec3(.45, .28, .07) * mix(1., dS, .4); pRough = .35; pMetal = .35; seam *= .3; }
	else if (k < 11.5) { c = vec3(.025, .024, .023) * (.8 + .4 * pN(p.xz * 3.)); pRough = .95; pMetal = 0.; seam *= .3; }
	else if (k < 12.5) {
		// basalt: plates with magma cracks (hot toward the lava), ash settled on top
		vec2 rp = abs(up) > .6 ? p.xz : vec2(hz, p.y * 1.35);
		vec3 v = pV(rp * .16), v2 = pV(rp * .6 + 3.3);
		float edge = v.y - v.x + (pN(rp * .9) - .5) * .05, crack = 1. - smoothstep(0., .035, edge), fine = 1. - smoothstep(0., .03, v2.y - v2.x);
		vec3 bas = pG(pT(tBasalt, p, n, .07), .35) * vec3(10., 9., 8.4) * (.7 + .45 * v.z);
		float ashy = smoothstep(.5, .92, up) * smoothstep(.3, .65, pF(p.xz * .08));
		c = mix(bas, vec3(.12, .11, .105) * (.75 + .5 * pN(p.xz * .9)), ashy) * (1. - crack * .6) * (1. - fine * .2);
		float hot = (1. - smoothstep(uLava + 1., uLava + 14., p.y)) * (smoothstep(.25, .6, pN(rp * .05 + 7.)) * .7 + .3), pulse = .6 + .4 * sin(uTime * 1.15 + v.z * 40.);
		pGlow = vec3(1., .26, .04) * (crack * (hot * 1.6 + .02) + fine * hot * .25) * pulse * (1. - ashy * .8);
		seam = 0.; pRough = .93; pMetal = 0.;
	}
	else if (k < 13.5) { c = vec3(.5, .44, .33) * mix(1., dP, .35) * (.9 + .2 * rnd); pRough = .7; }
	else if (k < 14.5) { c = vec3(.55, .56, .6) * mix(1., dS, .4); pRough = .25; pMetal = .35; seam *= .5; }
	else if (k < 15.5) { c = vec3(.03, .032, .036) * mix(1., dS, .5); pRough = .35; pMetal = .3; }
	else {
		// lights and glass: dark housing, the glow follows the facility's power
		c = vec3(.03); pRough = .3; pMetal = .2; seam = 0.;
		float pw = uPower;
		if (k < 20.5) { pGlow = glowCol * (.2 + 1.3 * pw); }
		else if (k < 21.5) { c = vec3(.02, .025, .03); pRough = .08; pMetal = .6; pGlow = glowCol * (.25 * pw) * (.5 + .5 * pN(p.xz * .4 + p.y)); }
		else if (k < 22.5) { float scan = .72 + .28 * sin(fy * 1.6), roll = .8 + .2 * smoothstep(.0, .1, fract(p.y * .5 - uTime * .25)); pGlow = glowCol * (.3 + 1.3 * pw) * scan * roll * (.7 + .3 * pN(p.xy * 6. + uTime)); }
		else if (k < 23.5) { float on = step(.5, fract(uTime * 1.3 + rnd)); pGlow = mix(glowCol * (.6 + 2. * on) * (.3 + .7 * pw), vec3(3., .12, .05) * (.4 + 2.4 * step(.5, fract(uTime * 2.2))), uAlarm); }
		else if (k < 24.5) { float flow = .6 + .4 * sin(p.x * .7 + p.z * .7 - uTime * 6.) * sin(p.y * 2. + uTime * 3.); pGlow = glowCol * (.7 + 1.8 * flow) * (.25 + .75 * pw); c = vec3(.05, .09, .07); }
		else { pGlow = vec3(1.6, .4, .06) * (.7 + .3 * sin(uTime * 2. + p.x)); }
	}
	c *= tint;
	if (k < 15.5 && k != 12.) {
		// painted edge wear: bright scratched metal on chamfers, chipped by noise; grime pooled low and in panel seams
		float chip = smoothstep(.35, .7, pN(p.xz * 3.1 + p.y * 2.7) * .6 + vWear * .7);
		c = mix(c, vec3(.5, .48, .45) * (.8 + .4 * pN(p.xy * 9.)), clamp(vWear * chip, 0., 1.) * (k > 4.5 && k < 6.5 ? .4 : .85));
		c *= (1. - seam) * mix(1., .55 + .45 * grime, .55);
		if (up > .7) { c *= .82 + .18 * pN(p.xz * 1.3); }
	}
	c *= mix(.45, 1., bvc);
	// heat: scorch near the magma, a hot rim right above it, warm bounce light from below
	if (k < 19.5) {
		float wy = vPW.y, heat = 1. - smoothstep(uLava + .5, uLava + 18., wy);
		c = mix(c, c * vec3(.55, .42, .36), heat * .5);
		pGlow += vec3(1., .3, .05) * (1. - smoothstep(uLava + .2, uLava + 4., wy)) * .4;
		pGlow += c * vec3(1., .42, .16) * (max(0., -up) * .6 + .22 * (1. - smoothstep(uLava + 4., 60., wy)) * (1. - max(0., up)));
		pGlow += c * vec3(1., .12, .08) * uAlarm * .5 * step(.5, fract(uTime * 2.2));          // the room goes red with the alarm
	}
	pGlow = min(pGlow, vec3(4.));
}
