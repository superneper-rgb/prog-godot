// FOINT CITY's towers and podiums (levels/hub/city_facades.gd), on the island and on the far shore. In place of the JS facade (city-kit.js facadeMaterial over city-style.js makeMassSkins):
// a 28.8 m texture of faint window dashes that repeated up every tower. Judged against the Batman Beyond references (CLAUDE.md, Look): a skyscraper in a city burns with runs of
// cyan and blue-white strip windows. Built at real scale: strip windows you can see into (a room behind each,
// its ceiling light, its furniture, now and then someone in it), glass and wet walls carrying the live sky and the skyline across the street, water running down the faces, the
// street's glow washing up the lowest floors. Unshaded like the rest of the city: the light is painted here.
// Skins: 0 poured concrete (old town), 1 steel with mullion ribs, 2 glass curtain wall (the newer towers).
// The exported normals all point up, so a face's frame comes from screen derivatives. UV is the JS one: metres / 28.8 along the perimeter and up from the face's own base (V flipped).
shader_type spatial;
render_mode unshaded, shadows_disabled;

#include "res://levels/shaders/city_env.gdshaderinc"

uniform int skin = 0;
uniform vec3 mass : source_color = vec3(0.098, 0.075, 0.145);      // the JS skin's base colour
uniform float glow_k = 1.0;                                         // the JS uGlow: the far shore's windows a little dimmer
uniform float bay = 2.4;                                            // window spacing along the face, m
uniform vec4 win = vec4(0.55, 1.85, 0.9, 2.5);                     // the opening in its bay: x0, x1, sill, head (m)
uniform float reveal = 0.22;                                        // how deep the glass sits in the wall
uniform float room_bays = 2.0;                                      // bays to a room
uniform float lit_share = 0.55;                                     // how many rooms have their lights on (a skyscraper in a city: most of them)
uniform float lamp_k = 0.3;                                         // a lit room's light, radiance
uniform float ground_y = -10.0;                                     // the street (JS GY): its glow washes up the lowest floors
uniform vec3 upwash : source_color = vec3(0.32, 0.14, 0.42);
uniform float upwash_k = 0.03;

varying vec3 v_shade;
varying vec3 w_pos;
varying flat vec3 v_far_mass;      // display colours turned to radiance once per vertex (they only change with the level's tone map)
varying flat vec3 v_far_street;
varying flat vec3 v_alu;

const float FH = 3.6;                // floor to floor (JS: 8 floors to a 28.8 m tile)
const float CEIL = 3.2;              // a room's ceiling, under the slab
const vec3 KEY = vec3(-0.423, 0.0, -0.906);      // the city's faint key (JS city-style.js massShade)

// A room seen through its glass: p on the glass (room-local metres: x across 0..size.x, y up from the floor, z = 0 at the glass), rd into the building.
// Unlit (radiance per unit of the room's light): the walls, the ceiling's lights, the floor's pool, a desk row or a sofa, now and then someone standing.
vec3 room(vec3 p, vec3 rd, vec3 size, float h, float h2) {
	vec3 sd = vec3(rd.x >= 0.0 ? 1.0 : -1.0, rd.y >= 0.0 ? 1.0 : -1.0, 1.0);
	vec3 ird = sd / max(abs(rd), vec3(1e-4));
	vec3 tw = ((sd * 0.5 + 0.5) * size - p) * ird;
	float t = min(min(tw.x, tw.y), tw.z);
	vec3 q = p + rd * t;
	bool office = h2 < 0.55;
	vec3 lamp = vec3(size.x * (0.35 + 0.3 * h), size.y, size.z * (0.4 + 0.25 * h2));      // where the light hangs
	vec3 lq = q - lamp;
	float fall = 0.3 + 1.6 / (1.0 + 0.16 * dot(lq, lq));                               // the light falls off away from it: the corners go dark
	vec3 paint = mix(vec3(0.95, 0.86, 0.76), vec3(0.74, 0.8, 0.98), fract(h * 4.3)) * (office ? 0.85 : 1.0);
	vec2 m = q.xz - lamp.xz;
	vec3 c;
	vec3 glow = vec3(0.0);
	if (t == tw.z) {                // the back wall: a cabinet row or a sofa along its foot, a picture over it in a home
		c = paint * 0.34;
		float fx0 = size.x * (0.08 + 0.3 * h);
		float fx1 = fx0 + size.x * (0.3 + 0.35 * h2);
		c *= (q.y < (office ? 1.9 : 0.85) && q.x > fx0 && q.x < fx1) ? 0.22 : 1.0;
		float px = q.x - (fx0 + fx1) * 0.5;
		c = (!office && abs(px) < 0.45 && abs(q.y - 1.6) < 0.32) ? mix(vec3(0.5, 0.18, 0.12), vec3(0.15, 0.3, 0.45), h2 * 2.0) * 0.5 : c;
	} else if (t == tw.y) {
		if (rd.y > 0.0) {           // the ceiling: an office's rows of panels, a home's one lamp
			c = paint * 0.1;
			if (office) {
				float row = abs(fract(q.z / 2.4 + 0.5 * h) - 0.5);
				glow = vec3(3.2) * step(row, 0.09) * step(abs(q.x - size.x * 0.5), size.x * 0.32);
			} else {
				glow = vec3(2.4) * exp(-dot(m, m) * 6.0);
			}
		} else {                    // the floor
			c = office ? vec3(0.07, 0.07, 0.08) : vec3(0.1, 0.065, 0.045);
		}
	} else {                        // the side walls, darker toward the window
		c = paint * 0.22 * (0.4 + 0.6 * q.z / size.z);
	}
	c = c * fall + glow;
	// the midground: a desk row in an office, and now and then someone standing at it
	float zm = size.z * (0.3 + 0.3 * h2);
	float tm = (zm - p.z) * ird.z;
	if (tm < t) {
		vec3 k = p + rd * tm;
		float desk = (office && k.y < 1.1 && k.x > size.x * 0.12 && k.x < size.x * 0.88) ? 1.0 : 0.0;
		float px = size.x * (0.2 + 0.6 * fract(h * 7.1));
		float who = step(fract(h * 3.7), 0.14);
		float body = who * max(step(abs(k.x - px), 0.21 - 0.05 * smoothstep(0.9, 1.5, k.y)) * step(k.y, 1.52), step(length(vec2(k.x - px, k.y - 1.66)), 0.12));
		float occ = max(desk, body);
		c = mix(c, vec3(0.03) + vec3(0.5) * desk * step(abs(k.y - 1.08), 0.025), occ);
	}
	return c;
}

void vertex() {
	v_shade = srgb_decode(COLOR.rgb);       // (the exporter stores vertex colours sRGB encoded; the JS attribute is the linear value)
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_far_mass = display_to_radiance(vec3(0.022, 0.016, 0.036));
	v_far_street = display_to_radiance(vec3(0.032, 0.02, 0.042));
	v_alu = display_to_radiance(vec3(0.11, 0.1, 0.14));
}

void fragment() {
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 V = normalize(w_pos - cam);
	// the face's frame, and its UV in metres
	float um = UV.x * 28.8;
	float hm = (1.0 - UV.y) * 28.8;
	vec2 dum = vec2(dFdx(um), dFdy(um));
	vec2 dhm = vec2(dFdx(hm), dFdy(hm));
	vec3 n;
	vec3 T;
	city_face(w_pos, V, um, n, T);
	float fp = max(length(dum), length(dhm));       // metres per pixel: how much detail this pixel can hold
	float cosv = max(dot(-V, n), 0.0);
	float fres = pow(1.0 - cosv, 5.0);
	float above = w_pos.y - ground_y;
	vec3 lit_mass = mass * v_shade;      // the wall's colour in the baked face shade

	// the grid: floors, window bays, rooms
	float fl = floor(hm / FH);
	float fy = hm - fl * FH;
	float bx = um - floor(um / bay) * bay;
	float rw = bay * room_bays;
	float ri = floor(um / rw);
	float rx = um - ri * rw;
	vec3 rd = vec3(dot(V, T), V.y, max(dot(V, -n), 0.03));

	// which rooms are lit: a stretch of one floor (a tenancy) is dark, half asleep or blazing; along it the lights come in runs
	vec3 rc = w_pos + T * ((ri + 0.5) * rw - um) + vec3(0.0, (fl + 0.5) * FH - hm, 0.0);      // the room's centre in the world: its own key, the same from every side
	vec3 rk = floor(rc * 0.5 + 0.37);
	float h = hash13(rk);
	float h2 = hash13(rk + 19.1);
	float ten = hash13(vec3(floor(rc.x / 13.0), fl, floor(rc.z / 13.0)) + 0.5);
	float floor_k = ten < 0.1 ? 0.0 : (ten > 0.8 ? 1.5 : 0.6 + 0.5 * fract(ten * 9.7));
	float on = step(1.0 - lit_share, 0.6 * vnoise1(ri * 0.55 + ten * 63.0) + 0.4 * h) * floor_k;
	float hc = fract(h * 13.7);
	vec3 lc = hc < 0.7 ? COOL : (hc < 0.92 ? PALE : WARM);
	float L = on * lamp_k * glow_k * (0.6 + 0.8 * h2);
	float tv = (1.0 - step(0.001, on)) * step(0.95, hc);      // a dark room with the television on: its blue flicker
	lc = mix(lc, vec3(0.42, 0.52, 1.0), tv);
	L += tv * lamp_k * glow_k * 0.3 * (0.55 + 0.45 * vnoise1(TIME * 7.0 + h * 50.0));
	// far off, a room is a pixel or two and its own light would sparkle as the camera moves: first a whole lit stretch of a floor goes as one (still a dash
	// across the city), then, when the floors are under a pixel too, the face takes the average glow
	float far_k = smoothstep(0.5, 1.4, fp);
	float flat_k = smoothstep(1.6, 3.2, fp);
	L = mix(L, floor_k * lit_share * lamp_k * glow_k, far_k);
	L = mix(L, 0.75 * lit_share * lamp_k * glow_k, flat_k);
	lc = mix(lc, vec3(0.42, 0.76, 1.0), far_k);

	// the opening, and how much of this pixel it covers (far off, a window is less than a pixel: its share of the wall)
	float aa = max(fp * 0.75, 0.002);
	float open = smoothstep(win.x - aa, win.x + aa, bx) * (1.0 - smoothstep(win.y - aa, win.y + aa, bx)) * smoothstep(win.z - aa, win.z + aa, fy) * (1.0 - smoothstep(win.w - aa, win.w + aa, fy));
	float area = (win.y - win.x) / bay * (win.w - win.z) / FH;
	open = mix(open, area, smoothstep(0.3, 1.1, fp));
	open *= smoothstep(0.34, 0.46, v_shade.g);      // not on the dark shadow bands under ledges (JS gap, k 0.3)
	float det = 1.0 - smoothstep(0.03, 0.2, fp);     // fine detail: seams, ribs, slats, sills
	float near_room = 1.0 - smoothstep(0.12, 0.5, fp);

	// through the glass: the reveal first (the glass sits back in the wall), then the room
	vec2 g = vec2(bx, fy) + rd.xy * (reveal / rd.z);
	g.x = clamp(g.x, win.x, win.y);      // only the head and the sill show as a reveal: across the bays the glass runs on, a strip (the mullions are drawn on it)
	float jamb = (1.0 - step(win.z, g.y) * step(g.y, win.w)) * (1.0 - smoothstep(0.08, 0.35, fp));
	vec3 size = vec3(rw, CEIL, 3.5 + 4.5 * h2);
	vec3 inside = room(vec3(clamp(rx + g.x - bx, 0.01, rw - 0.01), g.y, 0.0), rd, size, h, h2);
	inside = (mix(vec3(0.75), inside, near_room) + 0.35) * lc * L;      // (+: the light filling the glass, so a lit run reads as a strip of light from across the city)
	inside += lit_mass * 0.55;                               // a dark room: tinted glass with the sky's light on it, a little darker than the wall (no black holes in a lit face)
	// blinds and curtains, just behind the glass
	float bl = fract(h * 5.3);
	if (bl > 0.68 && L > 0.0) {
		float drop = win.w - (win.w - win.z) * (0.15 + 0.8 * fract(h * 11.1));
		if (bl > 0.86) {      // curtains across part of the window: the light comes through them soft
			float edge = win.x + (win.y - win.x) * (0.3 + 0.7 * fract(h * 17.3));
			float fold = 0.75 + 0.25 * sin(g.x * 18.0 + h * 9.0) * det;
			inside = mix(inside, lc * L * 0.55 * fold, step(g.x, edge) * 0.92);
		} else {              // venetian blinds, down to some height: lit slats
			float s = fract(g.y * 13.0);
			float slat = mix(0.55, smoothstep(0.1, 0.3, s) * (1.0 - smoothstep(0.75, 0.95, s)), det);
			inside = mix(inside, lc * L * (0.2 + 0.4 * slat), step(drop, g.y) * 0.9);
		}
	}

	// the frame round the glass, lit from inside when the room is
	float frame = max(1.0 - smoothstep(0.02, 0.02 + aa, min(g.x - win.x, win.y - g.x)), 1.0 - smoothstep(0.045, 0.045 + aa, min(g.y - win.z, win.w - g.y))) * det;
	inside = mix(inside, lit_mass * 1.4 + lc * L * 0.18, frame);

	// the glass: the room through it, the city in it, and the rain on it
	float rain = 1.0 - smoothstep(0.015, 0.06, fp);
	float rv = vnoise(vec2(um * 7.0, hm * 0.6 - TIME * 1.3));
	vec3 R = reflect(V, n);
	R.y += (rv - 0.5) * 0.05 * rain;
	float F0 = skin == 0 ? 0.02 : (skin == 1 ? 0.035 : 0.05);      // the wall: wet concrete, wet steel, spandrel glass
	float rough = skin == 0 ? 0.65 : (skin == 1 ? 0.4 : 0.08);
	vec3 city = city_env(normalize(R), mix(rough, 0.04 + 0.4 * smoothstep(0.2, 2.0, fp), open), above, v_far_mass, v_far_street, lamp_k);      // one look at the city, as blurred as what this pixel mostly is
	float Fg = 0.04 + 0.96 * fres;
	vec3 glass = inside * (1.0 - Fg) * vec3(0.86, 0.9, 0.96) + city * Fg;
	glass *= 1.0 + 0.5 * smoothstep(0.82, 0.97, rv) * rain;      // a run of water catching the light

	// the wall: the skin's colour in the baked face shade, weathered in big soft patches, stained down from every ledge
	vec3 base = lit_mass;
	float wea = 0.8 + 0.4 * vnoise(vec2(um, hm) * 0.07);
	float stain = smoothstep(0.55, 0.88, vnoise(vec2(um * 2.1, hm * 0.05)));
	float wx = smoothstep(win.x - 0.1, win.x + 0.25, bx) * (1.0 - smoothstep(win.y - 0.25, win.y + 0.1, bx));
	float drip = wx * step(fy, win.z) * exp(-(win.z - fy) * 0.7) * (0.4 + 0.6 * vnoise(vec2(bx * 9.0, hm * 0.5)));      // the dirt each sill sheds down the wall under it
	float shade = wea * (1.0 - 0.3 * stain) * (1.0 - 0.45 * drip * det);
	if (skin == 0) {           // poured concrete: the slab edge, panel joints, a sill under every window
		shade *= 1.0 + 0.12 * det * step(fy, 0.32);
		shade *= 1.0 - 0.55 * det * (1.0 - smoothstep(0.0, 0.035 + aa, abs(fy - 0.02)));
		float jx = um - floor(um / rw) * rw;
		shade *= 1.0 - 0.5 * det * (1.0 - smoothstep(0.0, 0.03 + aa, min(jx, rw - jx)));
		float sill = step(win.x - 0.09, bx) * step(bx, win.y + 0.09);
		shade *= 1.0 + det * sill * (0.5 * step(win.z - 0.09, fy) * step(fy, win.z) - 0.4 * step(win.z - 0.26, fy) * step(fy, win.z - 0.09));
	} else if (skin == 1) {    // steel: a rib between every bay, lit on one flank and shadowed on the other; the spandrel's seams
		float rc0 = bx < bay * 0.5 ? bx : bx - bay;
		float rib = 1.0 - smoothstep(0.08, 0.08 + aa, abs(rc0));
		float flank = dot(T * sign(rc0), KEY);
		shade *= 1.0 + det * rib * (0.25 + 0.45 * flank);
		shade *= 1.0 - 0.5 * det * (1.0 - smoothstep(0.0, 0.025 + aa, abs(fy - 0.02)));
	} else {                   // glass curtain wall: dark spandrel glass between the vision bands, the aluminium of the mullions and transoms
		float mul = 1.0 - smoothstep(0.03, 0.03 + aa, min(bx, bay - bx));
		float tra = 1.0 - smoothstep(0.035, 0.035 + aa, min(abs(fy - win.z), abs(fy - win.w)));
		shade *= 0.75;
		base += v_alu * max(mul, tra) * det;
	}
	// wet: the rain runs down every face in sheets, and the wet wall carries a blur of the sky
	float wet = 0.55 + 0.45 * vnoise(vec2(um * 4.0, hm * 0.25 + TIME * 0.5));
	float Fw = F0 + (max(1.0 - rough, F0) - F0) * fres;
	vec3 wall = base * shade + city * Fw * (skin == 2 ? 1.0 : wet);
	vec3 street = upwash * upwash_k * exp(-max(above, 0.0) / 14.0);
	wall += street * (0.7 + 0.3 * wea);
	// a lit window's light spilling out onto the wall round it, strongest on the sill under it
	vec2 dq = max(vec2(win.x - bx, win.z - fy), vec2(bx - win.y, fy - win.w));
	float dw = length(max(dq, vec2(0.0)));
	float on_sill = skin == 0 ? step(win.x - 0.09, bx) * step(bx, win.y + 0.09) * step(win.z - 0.09, fy) * step(fy, win.z) : 0.0;
	wall += lc * L * (0.07 * exp(-dw * 3.0) + 0.25 * on_sill * det) * near_room;

	vec3 jamb_c = lit_mass * 0.5 + lc * L * 0.12 + street * 0.4;
	vec3 opening = mix(glass + street * 0.12, jamb_c, jamb);
	ALBEDO = mix(wall, opening, open);
}
