// FOINT CITY's shop fronts (levels/hub/city_facades.gd), in place of the JS facade shader on its shop atlas (city-textures.js makeShopUnits: 8 x 8 units of 256 x 192 px, each
// 6 m wide and 4.6 m high, one quad per unit). Here the glass is glass: the lit display stands back behind it (parallax, with the shop's own sides at the edges), the street and the
// skyline across it show in it, the rain runs down it. A rolled-down shutter or a papered-up window is wet. The fascia and its sign stay as the JS painted them.
shader_type spatial;
render_mode unshaded, shadows_disabled;

#include "res://levels/shaders/city_env.gdshaderinc"
#include "res://levels/shaders/flash_light.gdshaderinc"      // the brief lights of play (core/flash_lights.gd)

uniform sampler2D map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D glowMap : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float uGlow = 0.52;            // the JS shops' glow (dimmer than the towers': the street is lit, not a fairground)
uniform float depth = 1.1;             // how far back the display stands behind the glass, m
uniform float lamp_k = 0.3;            // the skyline's lit windows in the glass (as city_facade.gdshader)
uniform float ground_y = -10.0;

varying vec3 v_shade;
varying vec3 w_pos;
varying flat vec3 v_far_mass;
varying flat vec3 v_far_street;

const vec2 UNIT = vec2(6.0, 4.6);                                          // JS SHOP_W, SHOP_H
const vec4 GLASS = vec4(10.0 / 256.0, 246.0 / 256.0, 50.0 / 192.0, 176.0 / 192.0);      // the glass in its unit: x0, x1, top, bottom (fractions from the unit's top left)

void vertex() {
	v_shade = srgb_decode(COLOR.rgb);
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_far_mass = display_to_radiance(vec3(0.022, 0.016, 0.036));
	v_far_street = display_to_radiance(vec3(0.032, 0.02, 0.042));
}

void fragment() {
	vec3 V = normalize(w_pos - CAMERA_POSITION_WORLD);
	float um = UV.x * 8.0 * UNIT.x;                                         // metres along the row of units
	vec3 n;
	vec3 T;
	city_face(w_pos, V, um, n, T);
	vec2 duvx = dFdx(UV);
	vec2 duvy = dFdy(UV);
	float fp = max(length(vec2(duvx.x, duvy.x)) * 8.0 * UNIT.x, length(vec2(duvx.y, duvy.y)) * 8.0 * UNIT.y);      // metres per pixel
	vec2 cell = floor(UV * 8.0);
	vec2 f = UV * 8.0 - cell;                                               // in the unit: x across, y down from the top
	float cosv = max(dot(-V, n), 0.0);
	float fres = pow(1.0 - cosv, 5.0);
	float above = w_pos.y - ground_y;
	float near = 1.0 - smoothstep(0.02, 0.08, fp);

	vec3 a = texture(map, UV).rgb;
	vec3 g0 = texture(glowMap, UV).rgb;
	vec3 js = a * v_shade + g0 * uGlow * (0.6 + 0.4 * v_shade.g);           // the JS shop front, as it was
	float aa = fp / (8.0 * UNIT.x) * 8.0;
	float in_glass = smoothstep(GLASS.x - aa, GLASS.x, f.x) * (1.0 - smoothstep(GLASS.y, GLASS.y + aa, f.x)) * smoothstep(GLASS.z - aa, GLASS.z, f.y) * (1.0 - smoothstep(GLASS.w, GLASS.w + aa, f.y));
	float lit = smoothstep(0.01, 0.04, dot(g0, vec3(0.3, 0.5, 0.2)));      // light behind it: an open shop's glass (else a shutter, paper, a dark unit)

	// the rain on the glass: runs of water down it, wandering, a bead now and then sliding down each
	float col_id = floor(um * 4.0);
	float run = step(0.78, hash11(col_id * 3.1 + cell.y));
	float hm = (1.0 - f.y) * UNIT.y;
	float wx = fract(um * 4.0 + 0.18 * sin(hm * 2.3 + col_id * 1.7) + 0.06 * sin(hm * 7.1 + col_id));
	float stream = run * (1.0 - smoothstep(0.02, 0.09, abs(wx - 0.5))) * near;
	float bead = stream * smoothstep(0.75, 0.95, fract(hm * 0.35 + TIME * (0.25 + 0.3 * hash11(col_id))));
	vec2 wob = vec2(vnoise(vec2(um * 9.0, hm * 9.0)) - 0.5, vnoise(vec2(um * 9.0 + 7.0, hm * 9.0 - TIME * 0.4)) - 0.5) * 0.004 * near;

	// through the glass: the display stands `depth` back; where the eye looks past it, the shop's sides
	vec3 rd = vec3(dot(V, T), V.y, max(dot(V, -n), 0.05));
	vec2 off = rd.xy * (depth / rd.z) / UNIT;
	vec2 fp2 = f + vec2(off.x, -off.y) + wob + vec2(stream * 0.006, 0.0);
	vec2 inset = vec2(0.004, 0.006);
	vec2 fc = clamp(fp2, GLASS.xz + inset, GLASS.yw - inset);
	float past = clamp(length((fp2 - fc) * UNIT) / 0.6, 0.0, 1.0);          // how far past the display's edge: the side walls, darker the deeper
	vec3 g1 = textureGrad(glowMap, (cell + fc) / 8.0, duvx, duvy).rgb;
	vec3 inside = (g1 * uGlow * (1.0 - 0.75 * past) + a * v_shade * 0.4) * (1.0 - 0.18 * stream);      // a run of water bends the light: a darker thread
	vec3 R = reflect(V, n);
	R.x += (wob.x * 40.0 + stream * 0.05) * near;
	vec3 city = city_env(normalize(R), mix(0.45, 0.03, lit * in_glass), above, v_far_mass, v_far_street, lamp_k);
	float Fg = 0.04 + 0.96 * fres;
	vec3 glass = inside * (1.0 - Fg) + city * Fg * (1.0 + 1.5 * stream) + g1 * uGlow * 0.2 * bead;

	// everything else is wet: the fascia, the pillars, a shutter's slats, the paper on an empty unit
	float rib = 0.6 + 0.4 * smoothstep(0.2, 0.8, abs(fract(f.y * 32.0) - 0.5) * 2.0) * (1.0 - smoothstep(0.03, 0.1, fp));
	float wet = 0.6 + 0.4 * vnoise(vec2(um * 3.0, hm * 0.4 + TIME * 0.5));
	vec3 rest = js + city * (0.03 + 0.3 * fres) * wet * (in_glass > 0.5 ? rib : 1.0);
	ALBEDO = mix(rest, glass, in_glass * lit) + flash_light(w_pos, n, vec3(0.25));
}
