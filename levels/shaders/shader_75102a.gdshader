// spire-sky (three.js ShaderMaterial, level spire). Drafted by tools/export/port_shader.mjs and checked by eye.
shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled, depth_draw_never, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform vec3 uCenter;
varying vec3 vDir;
uniform float uBeat;
uniform float uStrength;
uniform vec3 uSky;
uniform vec3 uBg;
float h(vec3 p){ p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float n3(vec3 x){ vec3 i = floor(x), f = fract(x); f = f * f * (3.0 - 2.0 * f);
        return mix(mix(mix(h(i), h(i + vec3(1.0,0.0,0.0)), f.x), mix(h(i + vec3(0.0,1.0,0.0)), h(i + vec3(1.0,1.0,0.0)), f.x), f.y),
                   mix(mix(h(i + vec3(0.0,0.0,1.0)), h(i + vec3(1.0,0.0,1.0)), f.x), mix(h(i + vec3(0.0,1.0,1.0)), h(i + vec3(1.0,1.0,1.0)), f.x), f.y), f.z); }
float gyro(vec3 p){ return sin(p.x) * cos(p.y) + sin(p.y) * cos(p.z) + sin(p.z) * cos(p.x); }
float field(vec3 d, float t){ vec3 w = d * 6.0 + vec3(t, -t * 0.7, t * 0.5); w += 0.6 * vec3(n3(w * 1.7), n3(w * 1.7 + 11.0), n3(w * 1.7 + 23.0)); return gyro(w); }

void vertex() {
	vec3 dome_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - uCenter;
	vDir = dome_p; vec4 p = MODELVIEW_MATRIX * vec4(dome_p, 1.0); POSITION = PROJECTION_MATRIX * p;
	vec4 dome_c = PROJECTION_MATRIX * VIEW_MATRIX * vec4(CAMERA_POSITION_WORLD + dome_p, 1.0);
	POSITION = vec4(dome_c.xy, 0.0, dome_c.w);
}

void fragment() {
	vec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);
	vec3 d = normalize(vDir); float t = TIME * 0.02;
	float g1 = field(d, t);
	float wall1 = smoothstep(0.5, 1.1, abs(g1));
	vec3 e = vec3(0.012, 0.0, 0.0);
	vec3 gr = vec3(field(normalize(d + e.xyy), t) - field(normalize(d - e.xyy), t), field(normalize(d + e.yxy), t) - field(normalize(d - e.yxy), t), field(normalize(d + e.yyx), t) - field(normalize(d - e.yyx), t));
	vec3 nrm = normalize(d * 0.6 - gr * 1.8 * sign(g1));
	vec3 L = normalize(vec3(0.35, 0.7, 0.45));
	float lit = clamp(dot(nrm, L) * 0.5 + 0.5, 0.0, 1.0);
	float spec = pow(max(dot(reflect(-L, nrm), -d), 0.0), 18.0);
	float mott = n3(d * 9.0 + 3.0) * 0.6 + n3(d * 21.0) * 0.4;
	float ridge = 1.0 - abs(2.0 * n3(d * 14.0 + vec3(0.0, t * 2.0, 0.0)) - 1.0), vein = smoothstep(0.86, 0.99, ridge);
	float vein2 = smoothstep(0.88, 0.995, 1.0 - abs(2.0 * n3(d * 31.0 + 9.0) - 1.0));
	float beat = 0.85 + 0.35 * uBeat;
	vec3 fleshDark = vec3(0.13, 0.016, 0.03), fleshLit = vec3(0.50, 0.085, 0.11);
	vec3 membrane = mix(fleshDark, fleshLit, lit * (0.45 + 0.55 * mott));
	membrane = mix(membrane, vec3(0.05, 0.004, 0.012), (vein * 0.7 + vein2 * 0.4));
	membrane += vec3(0.55, 0.06, 0.07) * (vein * 0.18 + vein2 * 0.08) * beat;
	vec3 cp = d * 5.0 + 4.0; vec3 cid = floor(cp), cf = fract(cp) - 0.5;
	vec3 jit = vec3(h(cid), h(cid + 3.1), h(cid + 7.7)) - 0.5; vec3 q = cf - jit * 0.35;
	float cr = 0.16 + 0.12 * h(cid + 1.7), cd = length(q), cyst = step(0.55, h(cid + 9.3)) * (1.0 - smoothstep(cr - 0.02, cr, cd));
	vec3 cn = normalize(q + 0.001); float cl = clamp(dot(cn, L) * 0.5 + 0.5, 0.0, 1.0), cs = pow(max(dot(reflect(-L, cn), -d), 0.0), 22.0);
	vec3 cystCol = mix(vec3(0.12, 0.012, 0.025), vec3(0.62, 0.07, 0.10), cl) + vec3(0.7, 0.35, 0.3) * cs * 0.45;
	membrane = mix(membrane, cystCol, cyst * smoothstep(0.7, 0.95, wall1));
	membrane += vec3(0.9, 0.5, 0.45) * spec * 0.22 * wall1;
	vec3 ember = mix(vec3(1.0, 0.34, 0.12), uSky, 0.25);
	vec3 w2 = d * 12.0 + vec3(-t * 0.6, t, t * 0.4) + 7.0; w2 += 0.5 * vec3(n3(w2 * 2.1), n3(w2 * 2.1 + 5.0), n3(w2 * 2.1 + 17.0));
	float wall2 = smoothstep(0.5, 1.1, abs(gyro(w2)));
	float glowField = 0.5 + 0.5 * n3(d * 3.0 + vec3(0.0, t * 3.0, 0.0));
	vec3 deep = mix(ember * (0.2 + 0.8 * glowField) * beat * 0.8, vec3(0.22, 0.03, 0.05), wall2 * 0.7);
	float lip = smoothstep(0.35, 0.8, wall1) * (1.0 - smoothstep(0.8, 1.0, wall1));
	vec3 col = mix(deep, membrane, wall1) + vec3(0.9, 0.22, 0.12) * lip * 0.22 * beat;
	fc_ = vec4(mix(uBg, col, uStrength), 1.0);
	ALBEDO = display_to_radiance(fc_.rgb);
}
