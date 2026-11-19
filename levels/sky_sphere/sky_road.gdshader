// The Overcurrent's deck, walls and edges (levels/sky_sphere/sky_course.gd), gritty (user, 2026-11-18: "less vaporwave, more cyberpunk
// gritty ... an underground illegal race"): worn plate steel and patched asphalt scorched by exhausts, chipped paint lines, concrete barriers
// tagged with graffiti, rust underneath, and the sodium pools of the crews' floodlights (one pole every 38 m, alternating sides,
// sky_set_pieces.gd puts the poles at the same places).
// UV: x metres across from the right edge, y metres along. UV2: x the surface kind (0 deck, 1 wall face, 2 wall top, 3 side, 4 underside,
// 5 open-edge lip), y the sector (0 plate, 1 catwalk grating, 2 painted hazard zone, 3 the Ribs). COLOR: r 0.5+ magnetic / 0.25 branch,
// g 0..1 across, b the strip's width / 20.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

uniform sampler2D plate_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plate_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D plate_rough : hint_roughness_g, filter_linear_mipmap, repeat_enable;
uniform sampler2D asphalt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rust_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D concrete_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D concrete_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 sodium = vec3(1.0, 0.6, 0.24);
uniform vec3 work = vec3(0.78, 0.86, 0.95);      // every other floodlight is a cold work lamp

varying flat float kind;
varying flat float sector;
varying vec4 tint;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(123.2, 71.9))) * 41633.19);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.13 + 7.1) * 0.3 + noise(p * 4.7 + 3.3) * 0.15;
}

void vertex() {
	kind = UV2.x;
	sector = UV2.y;
	tint = COLOR;
}

// the floodlight pools: a pole every 38 m, alternating sides, light falling across the deck from it
float pools(float along, float across, float width) {
	float k = floor((along - 19.0) / 38.0 + 0.5);
	float pole_at = k * 38.0 + 19.0;
	float side = mod(k, 2.0) < 1.0 ? width : 0.0;
	vec2 d = vec2(along - pole_at, (across - side) * 0.8);
	return exp(-dot(d, d) / 130.0);
}

void fragment() {
	float across = UV.x;
	float along = UV.y;
	float width = max(tint.b * 20.0, 0.01);
	float x01 = tint.g;
	float magnetic = step(0.4, tint.r);
	float grime = fbm(vec2(across * 0.35, along * 0.05));
	float pool = pools(along, across, width);
	vec3 lamp = mod(floor((along - 19.0) / 38.0 + 0.5), 4.0) < 2.0 ? sodium : work * 0.8;
	vec3 col;
	float rough = 0.7;
	float metal = 0.2;
	vec3 emit = vec3(0.0);
	if (kind < 0.5) {
		// the deck: plate steel, asphalt patches, exhaust scorch along the lines craft take, worn paint
		vec2 tuv = vec2(across, along) / 4.0;
		vec3 plate = texture(plate_tex, tuv).rgb;
		vec3 asphalt = texture(asphalt_tex, vec2(across, along) / 6.0).rgb;
		float patchy = smoothstep(0.5, 0.62, fbm(vec2(across * 0.12, along * 0.025) + 11.0));
		col = mix(plate * vec3(0.55, 0.53, 0.5), asphalt * 0.6, patchy);
		NORMAL_MAP = mix(texture(plate_normal, tuv).rgb, vec3(0.5, 0.5, 1.0), patchy);
		rough = mix(texture(plate_rough, tuv).g * 0.9 + 0.1, 0.85, patchy);
		metal = mix(0.45, 0.0, patchy);
		float scorch = smoothstep(0.55, 0.85, noise(vec2(across * 1.3, along * 0.012))) * 0.6;
		col *= 1.0 - scorch * 0.6;
		col *= 0.55 + 0.45 * grime;
		// paint: faded edge lines and a dashed centre, chipped away in places
		float chip = smoothstep(0.35, 0.55, noise(vec2(across * 3.0, along * 0.7)));
		float edge_line = (1.0 - smoothstep(0.0, 0.18, abs(across - 0.7))) + (1.0 - smoothstep(0.0, 0.18, abs(across - (width - 0.7))));
		float centre = (1.0 - smoothstep(0.0, 0.12, abs(across - width * 0.5))) * step(0.45, fract(along / 9.0));
		col = mix(col, vec3(0.62, 0.6, 0.55), clamp(edge_line, 0.0, 1.0) * chip * 0.7);
		col = mix(col, vec3(0.75, 0.55, 0.12), centre * chip * 0.75);
		if (sector > 1.5 && sector < 2.5) {
			// a painted hazard zone: worn yellow and black chevrons across the deck
			// a painted hazard zone: worn chevrons down the edges only (all across the deck they drowned everything)
			float near_edge = 1.0 - smoothstep(1.4, 1.8, min(across, width - across));
			float chev = step(0.5, fract((along + min(across, width - across) * 0.8) / 2.2));
			col = mix(col, mix(vec3(0.02), vec3(0.45, 0.33, 0.06), chev), 0.6 * chip * near_edge);
		} else if (sector > 0.5 && sector < 1.5) {
			// catwalk grating: rusted bars over the void
			vec2 g = fract(vec2(across * 2.4, along * 6.0));
			float bar = step(g.x, 0.22) + step(g.y, 0.3);
			col = mix(vec3(0.004), texture(rust_tex, vec2(across, along) / 2.0).rgb * 0.5, clamp(bar, 0.0, 1.0));
			metal = 0.6;
		} else if (sector > 2.5) {
			col *= 0.75;
		}
		if (magnetic > 0.5) {
			// a magnetic deck: worn copper coils across it, warm with current
			float coil = 1.0 - smoothstep(0.08, 0.18, abs(fract(along / 3.0) - 0.5));
			col = mix(col, vec3(0.32, 0.14, 0.06), coil * 0.8);
			emit += vec3(1.0, 0.35, 0.08) * coil * 0.35 * (0.6 + 0.4 * sin(TIME * 3.0 + along * 0.2));
		}
		// road studs along the edges, a few dead
		float stud = (1.0 - smoothstep(0.08, 0.14, length(vec2(fract(along / 12.0) - 0.5, (across - 0.35) * 2.0)))) + (1.0 - smoothstep(0.08, 0.14, length(vec2(fract(along / 12.0) - 0.5, (across - width + 0.35) * 2.0))));
		emit += sodium * stud * step(0.3, hash12(vec2(floor(along / 12.0), floor(across)))) * 2.0;
	} else if (kind < 2.5) {
		// the barriers: cracked concrete, filth at the foot, graffiti on the face, a hazard band on top
		vec2 cuv = vec2(along / 3.0, (kind < 1.5 ? x01 : across) * 0.5);
		col = texture(concrete_tex, cuv).rgb * vec3(0.5, 0.48, 0.45);
		NORMAL_MAP = texture(concrete_normal, cuv).rgb;
		rough = 0.9;
		metal = 0.0;
		col *= mix(0.35, 1.0, smoothstep(0.0, 0.6, x01)) * (0.6 + 0.4 * grime);
		if (kind < 1.5) {
			float block = floor(along / 7.0);
			float tagged = step(0.45, hash12(vec2(block, sector + 3.0)));
			float shape = smoothstep(0.52, 0.6, fbm(vec2(along * 0.9, x01 * 3.0) + block * 13.0));
			shape *= step(0.15, x01) * step(x01, 0.9);
			float h = hash12(vec2(block, 7.0));
			vec3 paint = h < 0.3 ? vec3(0.6, 0.06, 0.05) : (h < 0.55 ? vec3(0.05, 0.4, 0.38) : (h < 0.8 ? vec3(0.75, 0.7, 0.62) : vec3(0.7, 0.5, 0.05)));
			col = mix(col, paint * 0.6, shape * tagged * 0.85);
		} else {
			float stripe = step(0.5, fract(along / 1.2));
			col = mix(col, mix(vec3(0.02), vec3(0.55, 0.4, 0.06), stripe), 0.7);
			// neon tube runs the crews bolted along some barrier tops: red or teal, flickering, some dead
			float run = floor(along / 90.0);
			float lit = step(fract(along / 90.0), 0.27) * step(0.35, hash12(vec2(run, 5.0)));
			vec3 neon = hash12(vec2(run, 9.0)) < 0.55 ? vec3(1.0, 0.07, 0.12) : vec3(0.05, 0.85, 0.8);
			float tube = 1.0 - smoothstep(0.05, 0.1, abs(x01 - 0.25));
			float flicker = step(0.08, fract(sin(floor(TIME * 18.0) + run) * 43758.5)) * (0.85 + 0.15 * sin(TIME * 60.0));
			emit += neon * tube * lit * flicker * 3.5;
		}
	} else if (kind < 4.5) {
		// sides and underside: rusted steel and girders
		col = texture(rust_tex, vec2(along / 4.0, across / 4.0)).rgb * 0.5;
		rough = 0.75;
		metal = 0.4;
		if (kind > 3.5) {
			float girder = step(0.82, fract(along / 4.0));
			col *= 0.5 + girder * 0.5;
		}
	} else {
		// an open edge's lip: worn hazard stripes and amber reflectors, so the drop reads at speed
		float stripe = step(0.5, fract(along / 1.5));
		col = mix(vec3(0.02), vec3(0.6, 0.42, 0.06), stripe) * (0.5 + 0.5 * grime);
		emit += sodium * step(0.92, fract(along / 4.0)) * 1.5;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit + col * lamp * pool * 1.1 * step(kind, 2.5);
}
