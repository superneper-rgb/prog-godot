class_name PostFx
extends CompositorEffect
## POST FX (JS post-fx.js): the last step of every world frame. Tone mapping, contact shadows, height mist, bloom, lens streaks, a film grade, sharpening and grain, as compute passes
## on the way from Godot's HDR colour buffer to its final output.
##
## WHY IT IS BUILT THIS WAY
##  - The three.js frame is DISPLAY-REFERRED: its materials tone map and encode sRGB themselves, and everything here judges and blends what is on screen (bloom's threshold, the grade,
##    the mist). Godot's buffer at this point is HDR radiance, so the first pass turns it into exactly that frame (`display`, three.js's `sceneRT`): three's own tone map, then sRGB. From
##    there the passes are the JS shaders line for line, so every look number means what it meant, and the picture matches to within rounding instead of being re-tuned on Godot's
##    glow / SSAO / adjustments, which all work on radiance and answer to different numbers. Environment.tonemap_mode stays LINEAR: the last pass writes back the linear value of the
##    finished pixel and Godot's own pass only encodes it again, unchanged.
##  - MSAA: the JS target resolves in display space (the materials had already encoded), which is what keeps thin neon lines and sign letters thin and their edges smooth. Godot's own
##    resolve is in HDR radiance (a line of value 5 on black has no anti-aliased edge left at all), so the first pass resolves the samples itself, tone mapped. Where all samples are
##    the same (nearly every pixel) it pays one tone map.
##  - Everything is RenderingDevice compute inside one CompositorEffect, so no scene objects, no shader variants and nothing to compile when a look changes: looks are numbers.
##  - Costs are measured in docs/measurements.md. A look with ao 0 / bloom 0 / streak 0 skips those passes, like the JS.

const CONTEXT := &"prog_post"
const LEVELS := 6                # bloom mips: 1/2 .. 1/64 of the screen

const HEAD := "#version 450\nlayout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;\n"

# ---- HDR buffer -> the display-referred frame. The tone curve is three.js's ACESFilmicToneMapping, or NoToneMapping (clamp).
const CS_DISPLAY := """
#if SAMPLES > 1
layout(set = 0, binding = 0) uniform sampler2DMS tHdr;
#else
layout(set = 0, binding = 0) uniform sampler2D tHdr;
#endif
layout(rgb10_a2, set = 0, binding = 1) uniform restrict writeonly image2D oDisplay;
layout(push_constant, std430) uniform PC { vec4 tone; } pc;                        // x: 0 = no tone mapping, 1 = ACES; y: exposure
const mat3 ACES_IN = mat3(vec3(0.59719, 0.07600, 0.02840), vec3(0.35458, 0.90834, 0.13383), vec3(0.04823, 0.01566, 0.83777));
const mat3 ACES_OUT = mat3(vec3(1.60475, -0.10208, -0.00327), vec3(-0.53108, 1.10813, -0.07276), vec3(-0.07367, -0.00605, 1.07602));
vec3 toDisplay(vec3 c) {
	if (pc.tone.x > 0.5) {
		c = ACES_IN * (c * pc.tone.y / 0.6);
		c = (c * (c + 0.0245786) - 0.000090537) / (c * (0.983729 * c + 0.4329510) + 0.238081);
		c = ACES_OUT * c;
	}
	c = clamp(c, vec3(0.0), vec3(1.0));
	return mix(pow(c, vec3(0.41666)) * 1.055 - vec3(0.055), c * 12.92, vec3(lessThanEqual(c, vec3(0.0031308))));
}
void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy), sz = imageSize(oDisplay);
	if (px.x >= sz.x || px.y >= sz.y) return;
#if SAMPLES > 1
	vec3 s0 = texelFetch(tHdr, px, 0).rgb, sum = toDisplay(s0);
	bool edge = false;
	for (int i = 1; i < SAMPLES; i++) {
		vec3 s = texelFetch(tHdr, px, i).rgb;
		if (s != s0 || edge) { if (!edge) { sum *= float(i); edge = true; } sum += toDisplay(s); }
	}
	imageStore(oDisplay, px, vec4(edge ? sum / float(SAMPLES) : sum, 1.0));
#else
	imageStore(oDisplay, px, vec4(toDisplay(texelFetch(tHdr, px, 0).rgb), 1.0));
#endif
}
"""

# ---- contact shadows: SAO-style, 8 taps of the depth buffer on a golden-angle spiral at half resolution, normals rebuilt from depth. R = occlusion, G = depth for the blurs.
# (Godot's depth is reversed Z and its uv.y runs down: zOf and posOf undo both, so the view space here is the JS one.)
const CS_AO := """
layout(set = 0, binding = 0) uniform sampler2D tDepth;
layout(rg16, set = 0, binding = 1) uniform restrict writeonly image2D oAo;
layout(push_constant, std430) uniform PC { vec2 uClip, uTan, uTexel, uAo; } pc;     // uAo: radius (m), fade end (m)
float zOf(float d) { return pc.uClip.x * pc.uClip.y / (pc.uClip.x + d * (pc.uClip.y - pc.uClip.x)); }
vec3 posOf(vec2 uv, float z) { return vec3(vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0) * pc.uTan * z, -z); }
float depthAt(vec2 uv) { return textureLod(tDepth, uv + pc.uTexel * 0.05, 0.0).r; }   // (half-res centres sit exactly between two depth texels: rounding flipped between them in stripes across flat surfaces, so ties all go one way)
vec3 posAt(vec2 uv) { return posOf(uv, zOf(depthAt(uv))); }
const mat2 TURN = mat2(-0.73736882, 0.67549029, -0.67549029, -0.73736882);          // the golden angle
void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy), sz = imageSize(oAo);
	if (px.x >= sz.x || px.y >= sz.y) return;
	vec2 vUv = (vec2(px) + 0.5) * pc.uTexel;
	float d = depthAt(vUv), z = zOf(d);
	if (d <= 0.00001 || z >= pc.uAo.y) { imageStore(oAo, px, vec4(1.0, 1.0, 0.0, 0.0)); return; }
	vec3 P = posOf(vUv, z);
	vec3 L = posAt(vUv - vec2(pc.uTexel.x, 0.0)), R = posAt(vUv + vec2(pc.uTexel.x, 0.0)), D = posAt(vUv + vec2(0.0, pc.uTexel.y)), U = posAt(vUv - vec2(0.0, pc.uTexel.y));
	vec3 N = normalize(cross(abs(R.z - P.z) < abs(P.z - L.z) ? R - P : P - L, abs(U.z - P.z) < abs(P.z - D.z) ? U - P : P - D));   // the flatter neighbour on each axis: no halo along silhouettes
	float r = pc.uAo.x, inv2 = 1.0 / (r * r), bias = 0.012 + z * 0.0012;
	vec2 rad = r / (2.0 * pc.uTan * z); rad *= min(1.0, 0.16 / rad.y);                // (up close the disc stops growing: a body against the lens would otherwise sample half the screen)
	vec2 fc = vec2(px) + 0.5;
	float ign = fract(52.9829189 * fract(dot(fc, vec2(0.06711056, 0.00583715)))), a = ign * 6.2831853;
	vec2 dir = vec2(cos(a), sin(a));
	float occ = 0.0;
	for (int i = 0; i < 8; i++) {
		vec2 q = vUv + dir * rad * ((float(i) + 0.5) / 8.0); dir = TURN * dir;
		vec3 v = posAt(q) - P; float vv = dot(v, v), f = max(0.0, 1.0 - vv * inv2);
		occ += f * f * max(0.0, dot(v, N) - bias) / (vv + 0.02 * r * r);
	}
	float ao = clamp(1.0 - occ * r * 0.5, 0.0, 1.0);
	ao = mix(ao, 1.0, smoothstep(pc.uAo.y * 0.6, pc.uAo.y, z));
	imageStore(oAo, px, vec4(ao, z / pc.uAo.y, 0.0, 0.0));
}
"""

# ---- two depth-aware blurs of the half-res occlusion
const CS_AO_BLUR := """
layout(set = 0, binding = 0) uniform sampler2D tAO;
layout(rg16, set = 0, binding = 1) uniform restrict writeonly image2D oAo;
layout(push_constant, std430) uniform PC { vec2 uStep, uTexel; float uFade, p0, p1, p2; } pc;
void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy), sz = imageSize(oAo);
	if (px.x >= sz.x || px.y >= sz.y) return;
	vec2 vUv = (vec2(px) + 0.5) * pc.uTexel;
	vec4 c = textureLod(tAO, vUv, 0.0); float z0 = c.g * pc.uFade, k = 1.0 / (0.06 * z0 + 0.06), sum = c.r * 0.375, w = 0.375;
	for (int i = 1; i <= 2; i++) {
		float g = i == 1 ? 0.25 : 0.0625;
		vec4 a = textureLod(tAO, vUv + pc.uStep * float(i), 0.0), b = textureLod(tAO, vUv - pc.uStep * float(i), 0.0);
		float wa = g * max(0.0, 1.0 - abs(a.g * pc.uFade - z0) * k), wb = g * max(0.0, 1.0 - abs(b.g * pc.uFade - z0) * k);
		sum += a.r * wa + b.r * wb; w += wa + wb;
	}
	imageStore(oAo, px, vec4(sum / w, c.g, 0.0, 0.0));
}
"""

# ---- bloom in: what is bright, with an inverse tone curve so a clipped neon tube carries more than a pale wall. Karis weights stop a single hot pixel from flickering the whole glow.
const CS_BRIGHT := """
layout(set = 0, binding = 0) uniform sampler2D tScene;
layout(rgba16f, set = 0, binding = 1) uniform restrict writeonly image2D oGlow;
layout(push_constant, std430) uniform PC { vec2 uPx, uTexel; vec4 uBright; } pc;    // threshold, knee, how much a clipped highlight is worth, how far brightness is judged by luma instead of the top channel
vec4 tap(vec2 uv) {
	vec3 c = textureLod(tScene, uv, 0.0).rgb; float m = mix(max(c.r, max(c.g, c.b)), dot(c, vec3(0.2126, 0.7152, 0.0722)), pc.uBright.w), k = smoothstep(pc.uBright.x, pc.uBright.x + pc.uBright.y, m);
	vec3 L = pow(c, vec3(2.2)) * k / (1.0 - pc.uBright.z * m * m);
	float w = 1.0 / (1.0 + dot(L, vec3(0.2126, 0.7152, 0.0722))); return vec4(L * w, w);
}
void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy), sz = imageSize(oGlow);
	if (px.x >= sz.x || px.y >= sz.y) return;
	vec2 vUv = (vec2(px) + 0.5) * pc.uTexel;
	vec4 s = tap(vUv + pc.uPx * vec2(-1.0, -1.0)) + tap(vUv + pc.uPx * vec2(1.0, -1.0)) + tap(vUv + pc.uPx * vec2(-1.0, 1.0)) + tap(vUv + pc.uPx * vec2(1.0, 1.0));
	imageStore(oGlow, px, vec4(s.rgb / s.a, 1.0));
}
"""

# ---- dual-filter blur (Bjorge 2015): the widest glow for the fewest taps
const CS_DOWN := """
layout(set = 0, binding = 0) uniform sampler2D tSrc;
layout(rgba16f, set = 0, binding = 1) uniform restrict writeonly image2D oGlow;
layout(push_constant, std430) uniform PC { vec2 uPx, uTexel; } pc;
void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy), sz = imageSize(oGlow);
	if (px.x >= sz.x || px.y >= sz.y) return;
	vec2 vUv = (vec2(px) + 0.5) * pc.uTexel;
	vec3 s = textureLod(tSrc, vUv, 0.0).rgb * 4.0 + textureLod(tSrc, vUv - pc.uPx, 0.0).rgb + textureLod(tSrc, vUv + pc.uPx, 0.0).rgb + textureLod(tSrc, vUv + vec2(pc.uPx.x, -pc.uPx.y), 0.0).rgb + textureLod(tSrc, vUv - vec2(pc.uPx.x, -pc.uPx.y), 0.0).rgb;
	imageStore(oGlow, px, vec4(s / 8.0, 1.0));
}
"""
# (the JS draws this with additive blending; a compute pass reads the level it adds to)
const CS_UP := """
layout(set = 0, binding = 0) uniform sampler2D tSrc;
layout(rgba16f, set = 0, binding = 1) uniform restrict image2D oGlow;
layout(push_constant, std430) uniform PC { vec2 uPx, uTexel; float uWeight, p0, p1, p2; } pc;
#define T(x, y) textureLod(tSrc, vUv + pc.uPx * vec2(x, y), 0.0).rgb
void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy), sz = imageSize(oGlow);
	if (px.x >= sz.x || px.y >= sz.y) return;
	vec2 vUv = (vec2(px) + 0.5) * pc.uTexel;
	vec3 s = T(-2.0, 0.0) + T(2.0, 0.0) + T(0.0, 2.0) + T(0.0, -2.0) + (T(-1.0, 1.0) + T(1.0, 1.0) + T(1.0, -1.0) + T(-1.0, -1.0)) * 2.0;
	imageStore(oGlow, px, vec4(imageLoad(oGlow, px).rgb + s / 12.0 * pc.uWeight, 1.0));
}
"""

# ---- anamorphic streak: the same bright pass smeared sideways in three widening steps
const CS_STREAK := """
layout(set = 0, binding = 0) uniform sampler2D tSrc;
layout(rgba16f, set = 0, binding = 1) uniform restrict writeonly image2D oStreak;
layout(push_constant, std430) uniform PC { vec2 uStep, uTexel; float uCut, p0, p1, p2; } pc;
vec3 S(vec2 uv) { vec3 c = textureLod(tSrc, uv, 0.0).rgb; return max(c - pc.uCut, vec3(0.0)); }
void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy), sz = imageSize(oStreak);
	if (px.x >= sz.x || px.y >= sz.y) return;
	vec2 vUv = (vec2(px) + 0.5) * pc.uTexel;
	vec3 s = S(vUv) * 0.3 + (S(vUv + pc.uStep) + S(vUv - pc.uStep)) * 0.2 + (S(vUv + pc.uStep * 2.0) + S(vUv - pc.uStep * 2.0)) * 0.1 + (S(vUv + pc.uStep * 3.0) + S(vUv - pc.uStep * 3.0)) * 0.05;
	imageStore(oStreak, px, vec4(s, 1.0));
}
"""

# ---- the frame: everything above is folded in here, then graded. Written back as the linear value of the finished pixel: Godot's output pass (LINEAR tone map) encodes it to exactly `c`.
const CS_FINAL := """
layout(rgba16f, set = 0, binding = 0) uniform restrict writeonly image2D oColor;
layout(set = 0, binding = 1) uniform sampler2D tScene;
layout(set = 0, binding = 2) uniform sampler2D tDepth;
layout(set = 0, binding = 3) uniform sampler2D tAO;
layout(set = 0, binding = 4) uniform sampler2D tBloom;
layout(set = 0, binding = 5) uniform sampler2D tStreak;
layout(set = 0, binding = 6, std140) uniform U {
	vec4 uCam0, uCam1, uCam2;
	vec4 uTanClip;                                                                   // uTan, uClip
	vec4 uPxAo;                                                                      // uPx, uAoTexel
	vec4 uAoBloom;                                                                   // uAoK: strength, fade end (m); uBloomK: bloom, streak
	vec4 uMist;                                                                      // density, falloff, camera height above the base, glow tightness
	vec4 uMistCol, uGlowCol, uLightDir, uStreakTint;                                 // w: uFar, uAspect, uFrame, uDebug
	vec4 uLift, uInvGamma, uGain, uShadowTint, uHighTint, uVigTint;
	vec4 uTone, uLens;                                                               // uTone: s-curve, saturation, vibrance, black point. uLens: vignette, aberration, grain, sharpen
	vec4 uDrunk, uDrunk2;                                                            // Prog drunk (player/drunk.gd). uDrunk: ghost, blur px, double vision, time. uDrunk2: wobble, saturation, tunnel, hue drift
};
layout(rgba16f, set = 0, binding = 7) uniform restrict image2D oHist;               // the last finished frame, for the drunk ghosting
float hash(vec2 p) { vec3 q = fract(vec3(p.xyx) * 0.1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy), sz = imageSize(oColor);
	if (px.x >= sz.x || px.y >= sz.y) return;
	vec2 fc = vec2(px) + 0.5, uPx = uPxAo.xy, uAoTexel = uPxAo.zw, uTan = uTanClip.xy, uClip = uTanClip.zw;
	float uAspect = uGlowCol.w;
	vec2 uv = fc * uPx, dc = uv - 0.5; float r2 = dot(dc * vec2(uAspect, 1.0), dc * vec2(uAspect, 1.0)) / (0.25 * uAspect * uAspect + 0.25);   // 0 at the centre, 1 in a corner
	vec3 c;
	bool drunk = uDrunk.x + uDrunk.y + uDrunk.z + uDrunk2.x + uDrunk2.z + uDrunk2.w > 0.0;
	float dt_ = uDrunk.w;
	if (drunk) {                                                                     // drunk: the picture swims, splits in two and smears
		uv += uDrunk2.x * vec2(sin(uv.y * 6.0 + dt_ * 1.3) + 0.6 * sin(uv.y * 13.0 - dt_ * 2.1), sin(uv.x * 5.0 + dt_ * 1.1) + 0.6 * sin(uv.x * 11.0 + dt_ * 1.7));
		uv = clamp(uv, uPx, 1.0 - uPx);
		vec2 dv = uDrunk.z * vec2(cos(dt_ * 0.71), 0.55 * sin(dt_ * 0.93)) * (0.65 + 0.35 * sin(dt_ * 0.37));
		vec2 o = uDrunk.y * uPx;
		c = vec3(0.0);
		for (int i = 0; i < 2; i++) {
			vec2 q = uv + (i == 0 ? dv : -dv);
			c += textureLod(tScene, q, 0.0).rgb * 0.2 + (textureLod(tScene, q + vec2(o.x, o.y * 0.6), 0.0).rgb + textureLod(tScene, q - vec2(o.x, o.y * 0.6), 0.0).rgb
				+ textureLod(tScene, q + vec2(-o.x * 0.6, o.y), 0.0).rgb + textureLod(tScene, q + vec2(o.x * 0.6, -o.y), 0.0).rgb) * 0.2;
		}
		c *= 0.5;
	}
	else if (uLens.y > 0.0) { vec2 ca = dc * r2 * uLens.y; c = vec3(textureLod(tScene, uv + ca, 0.0).r, textureLod(tScene, uv, 0.0).g, textureLod(tScene, uv - ca, 0.0).b); }
	else c = textureLod(tScene, uv, 0.0).rgb;
	if (uLens.w > 0.0) {                                                             // contrast-adaptive sharpening (AMD CAS): leaves edges that are already hard alone
		vec3 n = textureLod(tScene, uv - vec2(0.0, uPx.y), 0.0).rgb, s = textureLod(tScene, uv + vec2(0.0, uPx.y), 0.0).rgb, e = textureLod(tScene, uv + vec2(uPx.x, 0.0), 0.0).rgb, w = textureLod(tScene, uv - vec2(uPx.x, 0.0), 0.0).rgb;
		vec3 mn = min(c, min(n, min(s, min(e, w)))), mx = max(c, max(n, max(s, max(e, w))));
		vec3 k = sqrt(clamp(min(mn, 1.0 - mx) / max(mx, vec3(0.0001)), 0.0, 1.0)) * (-1.0 / mix(8.0, 5.0, uLens.w));
		c = clamp(((n + s + e + w) * k + c) / (1.0 + 4.0 * k), 0.0, 1.0);
	}
	vec3 L = pow(c, vec3(2.2));
	float d = textureLod(tDepth, uv, 0.0).r, z = uClip.x * uClip.y / (uClip.x + d * (uClip.y - uClip.x)), mxc = max(c.r, max(c.g, c.b)), ao = 1.0;
	bool sky = d <= 0.00001;                                                         // (JS: d >= 0.99999; Godot's depth is reversed)
	if (uAoBloom.x > 0.0 && z < uAoBloom.y && !sky) {                                // the half-res occlusion, upsampled by depth so it does not bleed over silhouettes
		vec2 f = uv / uAoTexel - 0.5, b = floor(f); f -= b; vec2 p = (b + 0.5) * uAoTexel;
		vec4 a0 = textureLod(tAO, p, 0.0), a1 = textureLod(tAO, p + vec2(uAoTexel.x, 0.0), 0.0), a2 = textureLod(tAO, p + vec2(0.0, uAoTexel.y), 0.0), a3 = textureLod(tAO, p + uAoTexel, 0.0);
		float zn = z / uAoBloom.y, k = uAoBloom.y / (0.05 * z + 0.05);
		vec4 w = vec4((1.0 - f.x) * (1.0 - f.y), f.x * (1.0 - f.y), (1.0 - f.x) * f.y, f.x * f.y) / (0.002 + vec4(abs(a0.g - zn), abs(a1.g - zn), abs(a2.g - zn), abs(a3.g - zn)) * k);
		ao = dot(vec4(a0.r, a1.r, a2.r, a3.r), w) / dot(w, vec4(1.0));
		L *= mix(1.0, ao, uAoBloom.x * (1.0 - smoothstep(0.45, 0.95, mxc)));          // light sources are not occluded
	}
	if (uMist.x > 0.0) {                                                             // analytic exponential height fog, integrated along the view ray
		vec3 vRay = mat3(uCam0.xyz, uCam1.xyz, uCam2.xyz) * vec3(vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0) * uTan, -1.0);
		float len = length(vRay); vec3 dir = vRay / len; float t = (sky ? uMistCol.w : z) * len, ry = dir.y * t * uMist.y;
		float od = uMist.x * exp(-uMist.y * uMist.z) * t * (abs(ry) > 0.001 ? (1.0 - exp(-ry)) / ry : 1.0);
		float T = exp(-min(od, 8.0));
		L = mix(uMistCol.rgb + uGlowCol.rgb * pow(max(dot(dir, uLightDir.xyz), 0.0), uMist.w), L, T);
	}
	if (uAoBloom.z > 0.0) {
		vec3 g = clamp(textureLod(tBloom, uv, 0.0).rgb * uAoBloom.z, vec3(0.0), vec3(16.0));
		g = g * g / (g + 0.012);                                                      // a soft toe: the faint far edge of a glow is a veil that lifts near-black detail (this scale is gamma-dark, so a tiny value shows); it goes, the glow near the light stays
		L = L + g - L * min(g, vec3(1.0));                                            // screen blend: a glow never burns a coloured light to flat white
	}
	if (uAoBloom.w > 0.0) L += textureLod(tStreak, uv, 0.0).rgb * uStreakTint.rgb * uAoBloom.w;
	c = pow(max(L, vec3(0.0)), vec3(1.0 / 2.2));
	// the grade, in display space
	c = max(c - uTone.w, vec3(0.0)) / (1.0 - uTone.w);
	c = pow(max(c * uGain.rgb + uLift.rgb, vec3(0.0)), uInvGamma.rgb);
	c = clamp(c, 0.0, 1.0); c = mix(c, c * c * (3.0 - 2.0 * c), uTone.x);
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722)), chroma = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	c = mix(vec3(lum), c, uTone.y * uDrunk2.y * (1.0 + uTone.z * (1.0 - chroma)));
	if (uDrunk2.w > 0.0) {                                                           // the colours drift round the wheel (YIQ hue turn)
		vec3 yiq = mat3(vec3(0.299, 0.596, 0.211), vec3(0.587, -0.274, -0.523), vec3(0.114, -0.322, 0.312)) * c;
		float a = uDrunk2.w * sin(dt_ * 0.45 + uv.x * 2.0);
		yiq.yz = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * yiq.yz;
		c = clamp(mat3(vec3(1.0), vec3(0.956, -0.272, -1.106), vec3(0.621, -0.647, 1.703)) * yiq, 0.0, 1.0);
	}
	c *= mix(uShadowTint.rgb, uHighTint.rgb, smoothstep(0.0, 0.7, lum));
	c *= mix(vec3(1.0), uVigTint.rgb, uLens.x * smoothstep(0.12, 1.0, r2));
	c *= 1.0 - uDrunk2.z * smoothstep(0.15, 1.0, r2);                               // drunk: the edges of the world go dark
	c = clamp(c, 0.0, 1.0);
	if (drunk) {                                                                     // the frames before linger: a smear behind everything that moves (or the camera)
		c = mix(c, imageLoad(oHist, px).rgb, uDrunk.x);
		imageStore(oHist, px, vec4(c, 1.0));
	}
	float uDebug = uStreakTint.w;
	if (uDebug > 0.5) { if (uDebug < 1.5) c = vec3(ao); else if (uDebug < 2.5) c = pow(textureLod(tBloom, uv, 0.0).rgb * uAoBloom.z, vec3(1.0 / 2.2)); else c = vec3(fract(z * 0.1)); }
	float n = hash(fc + uLightDir.w * vec2(17.0, 59.0)) - 0.5;                       // film grain, strongest in the mids; at least one 8 bit step so the 10 bit gradients reach the canvas unbanded
	c += n * max(uLens.z * (0.35 + 2.6 * lum * (1.0 - lum)), 1.0 / 255.0);
	c = clamp(c, 0.0, 1.0);
	imageStore(oColor, px, vec4(mix(pow((c + vec3(0.055)) / 1.055, vec3(2.4)), c / 12.92, vec3(lessThanEqual(c, vec3(0.04045)))), 1.0));
}
"""


## The textures and bound passes of one viewport's buffers (the game's, or the dev mirror's). They live in the buffers' own context, so a resize frees them and they are rebuilt here.
class Chain:
	var size := Vector2i.ZERO
	var color := RID()
	var color_ms := RID()
	var depth := RID()
	var samples := 1
	var display := RID()
	var ao: Array[RID] = []
	var glow: Array[RID] = []
	var streak: Array[RID] = []
	var hist := RID()             # the drunk ghosting's last frame
	var us_display := RID()
	var us_ao := RID()
	var us_blur: Array[RID] = []
	var us_bright := RID()
	var us_down: Array[RID] = []
	var us_up: Array[RID] = []
	var us_streak: Array[RID] = []
	var us_final := RID()
	var g_full := Vector2i.ZERO
	var g_half := Vector2i.ZERO
	var g_glow: Array[Vector2i] = []
	var g_streak := Vector2i.ZERO
	# push constants that depend on size and look only, rebuilt when either changes
	var look_ver := -1
	var pc_tone := PackedByteArray()
	var pc_blur: Array[PackedByteArray] = []
	var pc_bright := PackedByteArray()
	var pc_down: Array[PackedByteArray] = []
	var pc_up: Array[PackedByteArray] = []
	var pc_streak: Array[PackedByteArray] = []
	var clip := Vector2.ZERO
	var tan_half := Vector2.ZERO
	var pc_ao := PackedByteArray()


var look: Dictionary = Looks.full({})
var look_enabled := true      # false = `look off`
var ao_shed := false          # dynamic resolution shed the contact shadows for this level (View.render)
var debug := 0                # 1 ao, 2 bloom, 3 depth
var frame := 0
var tone_mapping := 0         # 0 = none (three.js NoToneMapping), 1 = ACES (ACESFilmicToneMapping). View.set_tone_mapping owns these.
var exposure := 1.0
var fog_color := Color(0.0, 0.0, 0.0)   # the fog the world is showing right now, linear: the mist takes it when the look has no colour of its own
var has_fog := false
var cpu_us := 0.0             # last frame's cost of this effect on the render thread
var drunk := Vector4.ZERO     # Prog drunk (player/drunk.gd sets these every frame): ghost (0..1 at 60 fps), blur (px at 1080p), double vision (uv), time (s)
var drunk2 := Vector4(0.0, 1.0, 0.0, 0.0)   # wobble (uv), saturation (x), tunnel (0..1), hue drift (rad)
var timing := false           # capture one RD timestamp per pass group (peek profiling only)

var _rd: RenderingDevice = null
var _shaders: Dictionary = {}
var _pipes: Dictionary = {}
var _nearest := RID()
var _linear := RID()
var _ubo := RID()
var _chains: Dictionary = {}
var _look_ver := 0
var _u := PackedFloat32Array()   # the final pass's block; the look's part is set in apply(), the camera's every frame
var _k: Dictionary = {}          # the look in effect (`look` or the neutral one)
var _bloom_on := false
var _streak_on := false
var _ao_on := false
var _mist_on := false
var _lin_mist := Vector3.ZERO
var _build_ms := 0.0
var _drunk_frame := 0


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true    # Godot resolves once, before this pass; what this pass writes to the resolved buffer is what its output pass reads
	access_resolved_depth = true
	_u.resize(84)                   # the block in CS_FINAL, as floats: vec4 by vec4 in its order
	_u[81] = 1.0                    # (drunk saturation: 1 = sober)
	apply()
	_rd = RenderingServer.get_rendering_device()
	if _rd != null:                 # (headless: no RenderingDevice, the effect stays off)
		RenderingServer.call_on_render_thread(_build)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd != null:
		for s: RID in _shaders.values():
			if s.is_valid():
				_rd.free_rid(s)      # (frees its pipelines and uniform sets with it)
		if _nearest.is_valid():
			_rd.free_rid(_nearest)
		if _linear.is_valid():
			_rd.free_rid(_linear)
		if _ubo.is_valid():
			_rd.free_rid(_ubo)


# ---- the look: JS setLook / tweak / apply --------------------------------------------------------------------------------------------------------------------

## Replace the look: anything not named falls back to LOOK_BASE. Only numbers change, so this is free at any moment.
func set_look(l: Dictionary) -> void:
	look = Looks.full(l)
	ao_shed = false
	apply()


## Tweak the current look in place (the `look` console command).
func tweak(partial: Dictionary) -> void:
	look.merge(partial, true)
	apply()


func apply() -> void:
	var k: Dictionary = look if look_enabled else Looks.full(Looks.LOOK_NEUTRAL)
	_k = k
	_look_ver += 1
	# each coarser level is worth bloom_spread of the one above it: low = a glow that hugs its light, high = a haze across the frame. Divided by the sum so the amount stays the amount.
	var weight_sum := 0.0
	var w := 1.0
	for i in LEVELS:
		weight_sum += w
		w *= float(k.bloom_spread)
	var U := _u
	U[20] = float(k.ao)
	U[21] = float(k.ao_fade)
	U[22] = float(k.bloom) / weight_sum
	U[23] = float(k.streak)
	U[31] = float(k.mist_far)
	_vec3(U, 32, k.mist_glow, 2.2)
	var ml: Array = k.mist_light
	var ld := Vector3(ml[0], ml[1], ml[2]).normalized()
	U[36] = ld.x; U[37] = ld.y; U[38] = ld.z
	_vec3(U, 40, k.streak_tint)
	_vec3(U, 44, k.lift)
	var g: Array = k.gamma
	U[48] = 1.0 / float(g[0]); U[49] = 1.0 / float(g[1]); U[50] = 1.0 / float(g[2])
	_vec3(U, 52, k.gain)
	_vec3(U, 56, k.shadow_tint)
	_vec3(U, 60, k.high_tint)
	_vec3(U, 64, k.vignette_tint)
	U[68] = float(k.scurve); U[69] = float(k.saturation); U[70] = float(k.vibrance); U[71] = float(k.black_point)
	U[72] = float(k.vignette); U[73] = float(k.aberration); U[74] = float(k.grain); U[75] = float(k.sharpen)
	_ao_on = float(k.ao) > 0.0
	_bloom_on = float(k.bloom) > 0.0
	_streak_on = float(k.streak) > 0.0
	_mist_on = float(k.mist) > 0.0
	if k.mist_color != null:
		var mc: Array = k.mist_color
		_lin_mist = Vector3(pow(float(mc[0]), 2.2), pow(float(mc[1]), 2.2), pow(float(mc[2]), 2.2))


static func _vec3(U: PackedFloat32Array, i: int, a: Array, power: float = 1.0) -> void:
	U[i] = pow(float(a[0]), power); U[i + 1] = pow(float(a[1]), power); U[i + 2] = pow(float(a[2]), power)


# ---- GPU objects ---------------------------------------------------------------------------------------------------------------------------------------------

func _compile(key: StringName, body: String, defines: String = "") -> void:
	if _pipes.has(key):
		return
	var src := RDShaderSource.new()
	src.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	src.source_compute = HEAD + defines + body
	var spirv := _rd.shader_compile_spirv_from_source(src)
	if spirv.compile_error_compute != "":
		push_error("post_fx %s: %s" % [key, spirv.compile_error_compute])
		return
	var sh := _rd.shader_create_from_spirv(spirv, "post " + key)
	_shaders[key] = sh
	_pipes[key] = _rd.compute_pipeline_create(sh)


func _build() -> void:
	var t0 := Time.get_ticks_usec()
	_compile(&"display_1", CS_DISPLAY, "#define SAMPLES 1\n")
	_compile(&"ao", CS_AO)
	_compile(&"blur", CS_AO_BLUR)
	_compile(&"bright", CS_BRIGHT)
	_compile(&"down", CS_DOWN)
	_compile(&"up", CS_UP)
	_compile(&"streak", CS_STREAK)
	_compile(&"final", CS_FINAL)
	var ss := RDSamplerState.new()
	ss.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	ss.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_nearest = _rd.sampler_create(ss)
	ss.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	ss.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	_linear = _rd.sampler_create(ss)
	_ubo = _rd.uniform_buffer_create(_u.size() * 4)
	_build_ms = (Time.get_ticks_usec() - t0) / 1000.0


func _tex(rsb: RenderSceneBuffersRD, tex_name: StringName, fmt: int, size: Vector2i) -> RID:
	return rsb.create_texture(CONTEXT, tex_name, fmt, RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT, RenderingDevice.TEXTURE_SAMPLES_1, size, 1, 1, true, false)


func _img(binding: int, tex: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(tex)
	return u


func _smp(binding: int, tex: RID, linear: bool) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = binding
	u.add_id(_linear if linear else _nearest)
	u.add_id(tex)
	return u


func _uset(pipe: StringName, us: Array[RDUniform]) -> RID:
	return _rd.uniform_set_create(us, _shaders[pipe], 0)


func _pc(values: Array) -> PackedByteArray:
	return PackedFloat32Array(values).to_byte_array()


## Make / refresh the textures and bound sets for these buffers.
func _chain(rsb: RenderSceneBuffersRD) -> Chain:
	var key := rsb.get_instance_id()
	var ch: Chain = _chains.get(key)
	var size := rsb.get_internal_size()
	var color := rsb.get_color_layer(0)
	var depth := rsb.get_depth_layer(0)
	var msaa := rsb.get_msaa_3d()
	var samples := 1 if msaa == RenderingServer.VIEWPORT_MSAA_DISABLED else (2 if msaa == RenderingServer.VIEWPORT_MSAA_2X else (4 if msaa == RenderingServer.VIEWPORT_MSAA_4X else 8))
	if ch != null and ch.size == size and ch.color == color and ch.depth == depth and ch.samples == samples and rsb.has_texture(CONTEXT, &"display"):
		return ch
	ch = Chain.new()
	_chains[key] = ch
	ch.size = size
	ch.color = color
	ch.depth = depth
	ch.samples = samples
	ch.color_ms = rsb.get_color_layer(0, true) if samples > 1 else color
	var disp_pipe := StringName("display_%d" % samples)
	_compile(disp_pipe, CS_DISPLAY, "#define SAMPLES %d\n" % samples)
	rsb.clear_context(CONTEXT)
	var R16F := RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	ch.display = _tex(rsb, &"display", RenderingDevice.DATA_FORMAT_A2B10G10R10_UNORM_PACK32, size)
	var hs := Vector2i(maxi(1, size.x >> 1), maxi(1, size.y >> 1))
	ch.ao = [_tex(rsb, &"ao0", RenderingDevice.DATA_FORMAT_R16G16_UNORM, hs), _tex(rsb, &"ao1", RenderingDevice.DATA_FORMAT_R16G16_UNORM, hs)]
	ch.glow.clear()
	ch.g_glow.clear()
	var glow_size: Array[Vector2i] = []
	for i in LEVELS:
		var s := Vector2i(maxi(1, size.x >> (i + 1)), maxi(1, size.y >> (i + 1)))
		glow_size.append(s)
		ch.glow.append(_tex(rsb, StringName("glow%d" % i), R16F, s))
		ch.g_glow.append(Vector2i((s.x + 7) >> 3, (s.y + 7) >> 3))
	var ss := Vector2i(maxi(1, size.x >> 3), maxi(1, size.y >> 4))
	ch.streak = [_tex(rsb, &"streak0", R16F, ss), _tex(rsb, &"streak1", R16F, ss)]
	ch.hist = _tex(rsb, &"hist", R16F, size)
	ch.g_full = Vector2i((size.x + 7) >> 3, (size.y + 7) >> 3)
	ch.g_half = Vector2i((hs.x + 7) >> 3, (hs.y + 7) >> 3)
	ch.g_streak = Vector2i((ss.x + 7) >> 3, (ss.y + 7) >> 3)
	ch.us_display = _uset(disp_pipe, [_smp(0, ch.color_ms, false), _img(1, ch.display)])
	ch.us_ao = _uset(&"ao", [_smp(0, depth, false), _img(1, ch.ao[0])])
	ch.us_blur = [_uset(&"blur", [_smp(0, ch.ao[0], false), _img(1, ch.ao[1])]), _uset(&"blur", [_smp(0, ch.ao[1], false), _img(1, ch.ao[0])])]
	ch.us_bright = _uset(&"bright", [_smp(0, ch.display, true), _img(1, ch.glow[0])])
	ch.us_down.clear()
	ch.us_up.clear()
	for i in range(1, LEVELS):
		ch.us_down.append(_uset(&"down", [_smp(0, ch.glow[i - 1], true), _img(1, ch.glow[i])]))
		ch.us_up.append(_uset(&"up", [_smp(0, ch.glow[i], true), _img(1, ch.glow[i - 1])]))
	ch.us_streak = [
		_uset(&"streak", [_smp(0, ch.glow[2], true), _img(1, ch.streak[1])]),
		_uset(&"streak", [_smp(0, ch.streak[1], true), _img(1, ch.streak[0])]),
		_uset(&"streak", [_smp(0, ch.streak[0], true), _img(1, ch.streak[1])]),
		_uset(&"streak", [_smp(0, ch.streak[1], true), _img(1, ch.streak[0])]),
	]
	var ub := RDUniform.new()
	ub.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	ub.binding = 6
	ub.add_id(_ubo)
	ch.us_final = _uset(&"final", [_img(0, color), _smp(1, ch.display, true), _smp(2, depth, false), _smp(3, ch.ao[0], false), _smp(4, ch.glow[0], true), _smp(5, ch.streak[0], true), ub, _img(7, ch.hist)])
	# what depends on the size alone
	var ht := Vector2(1.0 / hs.x, 1.0 / hs.y)
	ch.pc_blur = [_pc([ht.x, 0.0, ht.x, ht.y, 1.0, 0.0, 0.0, 0.0]), _pc([0.0, ht.y, ht.x, ht.y, 1.0, 0.0, 0.0, 0.0])]
	ch.pc_down.clear()
	for i in range(1, LEVELS):
		var src := glow_size[i - 1]
		var dst := glow_size[i]
		ch.pc_down.append(_pc([0.5 / src.x, 0.5 / src.y, 1.0 / dst.x, 1.0 / dst.y]))
	ch.look_ver = -1
	ch.clip = Vector2.ZERO
	ch.tan_half = Vector2.ZERO
	# (a chain whose viewport went away holds no RID of its own: the buffers owned the textures)
	return ch


## What depends on the look (and the size): rebuilt only when either changed, so a frame allocates nothing.
func _refresh(ch: Chain) -> void:
	var k := _k
	var fade := float(k.ao_fade)
	var hs := Vector2i(maxi(1, ch.size.x >> 1), maxi(1, ch.size.y >> 1))
	var ht := Vector2(1.0 / hs.x, 1.0 / hs.y)
	ch.pc_blur = [_pc([ht.x, 0.0, ht.x, ht.y, fade, 0.0, 0.0, 0.0]), _pc([0.0, ht.y, ht.x, ht.y, fade, 0.0, 0.0, 0.0])]
	var g0 := Vector2i(maxi(1, ch.size.x >> 1), maxi(1, ch.size.y >> 1))
	ch.pc_bright = _pc([1.0 / ch.size.x, 1.0 / ch.size.y, 1.0 / g0.x, 1.0 / g0.y, k.bloom_threshold, k.bloom_knee, k.bloom_hot, k.bloom_luma])
	ch.pc_up.clear()
	var weight := float(k.bloom_spread)
	for i in range(1, LEVELS):
		var src := Vector2i(maxi(1, ch.size.x >> (i + 1)), maxi(1, ch.size.y >> (i + 1)))
		var dst := Vector2i(maxi(1, ch.size.x >> i), maxi(1, ch.size.y >> i))
		ch.pc_up.append(_pc([0.5 / src.x, 0.5 / src.y, 1.0 / dst.x, 1.0 / dst.y, weight, 0.0, 0.0, 0.0]))
	var ss := Vector2i(maxi(1, ch.size.x >> 3), maxi(1, ch.size.y >> 4))
	var px := 1.0 / ss.x
	var tx := Vector2(1.0 / ss.x, 1.0 / ss.y)
	ch.pc_streak = [
		_pc([px, 0.0, tx.x, tx.y, k.streak_cut, 0.0, 0.0, 0.0]),
		_pc([px * 4.0, 0.0, tx.x, tx.y, 0.0, 0.0, 0.0, 0.0]),
		_pc([px * 16.0, 0.0, tx.x, tx.y, 0.0, 0.0, 0.0, 0.0]),
		_pc([px * 2.0, 0.0, tx.x, tx.y, 0.0, 0.0, 0.0, 0.0]),
	]
	ch.pc_tone = _pc([float(tone_mapping), exposure, 0.0, 0.0])
	ch.look_ver = _look_ver
	ch.clip = Vector2.ZERO        # pc_ao is rebuilt below with the look's radius and fade


func _pass(pipe: RID, us: RID, pc: PackedByteArray, g: Vector2i) -> void:
	var rd := _rd
	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipe)
	rd.compute_list_bind_uniform_set(cl, us, 0)
	rd.compute_list_set_push_constant(cl, pc, pc.size())
	rd.compute_list_dispatch(cl, g.x, g.y, 1)
	rd.compute_list_end()


# ---- the passes, then the frame: JS post.end ------------------------------------------------------------------------------------------------------------------

func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT or _ubo == RID():
		return
	var t0 := Time.get_ticks_usec()
	var rsb: RenderSceneBuffersRD = render_data.get_render_scene_buffers()
	var sd: RenderSceneDataRD = render_data.get_render_scene_data()
	if rsb == null or sd == null or rsb.get_view_count() != 1:
		return
	var rd := _rd
	var ch := _chain(rsb)
	var pipes := _pipes
	if ch.look_ver != _look_ver:
		_refresh(ch)
	var proj := sd.get_view_projection(0)
	# (this is the projection the frame was drawn with, reversed Z over 0..1: get_z_near / get_z_far misread it. depth = n (f - z) / (z (f - n)) gives near and far back from its two terms)
	var pa := absf(proj.z.z)
	var pb := absf(proj.w.z)
	var near := pb / (1.0 + pa)
	var far := pb / pa
	var tan_half := Vector2(1.0 / absf(proj.x.x), 1.0 / absf(proj.y.y))
	var clip := Vector2(near, far)
	if ch.clip != clip or ch.tan_half != tan_half:
		ch.clip = clip
		ch.tan_half = tan_half
		var k: Dictionary = _k
		var hs := Vector2i(maxi(1, ch.size.x >> 1), maxi(1, ch.size.y >> 1))
		ch.pc_ao = _pc([near, far, tan_half.x, tan_half.y, 1.0 / hs.x, 1.0 / hs.y, k.ao_radius, k.ao_fade])
	ch.pc_tone.encode_float(0, float(tone_mapping))
	ch.pc_tone.encode_float(4, exposure)
	var cam := sd.get_cam_transform()
	frame = (frame + 1) % 1021

	# the frame the materials would have drawn on a canvas
	if timing:
		rd.capture_timestamp("post display")
	_pass(pipes[StringName("display_%d" % ch.samples)], ch.us_display, ch.pc_tone, ch.g_full)

	# contact shadows
	var use_ao := _ao_on and not ao_shed
	if timing:
		rd.capture_timestamp("post ao")
	if use_ao:
		_pass(pipes[&"ao"], ch.us_ao, ch.pc_ao, ch.g_half)
		_pass(pipes[&"blur"], ch.us_blur[0], ch.pc_blur[0], ch.g_half)
		_pass(pipes[&"blur"], ch.us_blur[1], ch.pc_blur[1], ch.g_half)
	# bloom
	if timing:
		rd.capture_timestamp("post bloom")
	if _bloom_on:
		_pass(pipes[&"bright"], ch.us_bright, ch.pc_bright, ch.g_glow[0])
		var down: RID = pipes[&"down"]
		for i in LEVELS - 1:
			_pass(down, ch.us_down[i], ch.pc_down[i], ch.g_glow[i + 1])
		# lens streak, from the 1/8 level before the upward pass adds to it
		if _streak_on:
			var sp: RID = pipes[&"streak"]
			for i in 4:
				_pass(sp, ch.us_streak[i], ch.pc_streak[i], ch.g_streak)
		var up: RID = pipes[&"up"]
		for i in range(LEVELS - 2, -1, -1):
			_pass(up, ch.us_up[i], ch.pc_up[i], ch.g_glow[i])
	# the block of the final pass: the look's part is already in it (apply), the camera's goes in now
	var U := _u
	var b := cam.basis
	U[0] = b.x.x; U[1] = b.x.y; U[2] = b.x.z
	U[4] = b.y.x; U[5] = b.y.y; U[6] = b.y.z
	U[8] = b.z.x; U[9] = b.z.y; U[10] = b.z.z
	U[12] = tan_half.x; U[13] = tan_half.y; U[14] = near; U[15] = far
	var w := float(ch.size.x)
	var h := float(ch.size.y)
	U[16] = 1.0 / w; U[17] = 1.0 / h
	U[18] = 1.0 / float(maxi(1, ch.size.x >> 1)); U[19] = 1.0 / float(maxi(1, ch.size.y >> 1))
	U[20] = float(_k.ao) if use_ao else 0.0
	U[35] = w / h
	U[39] = float(frame)
	# mist colour: the look's own, or the fog the world is showing right now (the sky drift moves it). Fog goes on after tone mapping, so its linear value IS what is on screen.
	if _mist_on:
		var gain := float(_k.mist_gain)
		if _k.mist_color != null:
			U[28] = _lin_mist.x * gain; U[29] = _lin_mist.y * gain; U[30] = _lin_mist.z * gain
		elif has_fog:
			U[28] = fog_color.r * gain; U[29] = fog_color.g * gain; U[30] = fog_color.b * gain
		U[24] = float(_k.mist); U[25] = float(_k.mist_falloff); U[26] = maxf(-12.0, cam.origin.y - float(_k.mist_y)); U[27] = float(_k.mist_glow_pow)
	else:
		U[24] = 0.0
	U[43] = float(debug)
	var gh := pow(clampf(drunk.x, 0.0, 0.97), 60.0 * maxf(Engine.get_process_frames() - _drunk_frame, 1) / maxf(Engine.get_frames_per_second(), 30.0)) if drunk.x > 0.0 else 0.0
	_drunk_frame = Engine.get_process_frames()
	U[76] = gh; U[77] = drunk.y * h / 1080.0; U[78] = drunk.z; U[79] = drunk.w
	U[80] = drunk2.x; U[81] = drunk2.y; U[82] = drunk2.z; U[83] = drunk2.w
	rd.buffer_update(_ubo, 0, U.size() * 4, U.to_byte_array())
	if timing:
		rd.capture_timestamp("post final")
	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipes[&"final"])
	rd.compute_list_bind_uniform_set(cl, ch.us_final, 0)
	rd.compute_list_dispatch(cl, ch.g_full.x, ch.g_full.y, 1)
	rd.compute_list_end()
	if timing:
		rd.capture_timestamp("post end")
	cpu_us = float(Time.get_ticks_usec() - t0)


## What the targets hold, in MB (JS memoryMB), for the status line.
func memory_mb(size: Vector2i) -> float:
	var w := size.x
	var h := size.y
	return (w * h * 4 + (w * h / 4) * 4 * 2 + (w * h / 4) * 8 * 1.33 + (w * h / 128) * 8 * 2) / 1048576.0
