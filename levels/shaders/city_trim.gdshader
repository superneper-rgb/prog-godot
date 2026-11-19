// FOINT CITY's building kit, inside the district's flat vertex-colour meshes (levels/hub/city_facades.gd; JS district-view.js `flat`): the cornices, parapets and copings, the roof
// plant, stair bulkheads and aerials, the struts and sky bridges, the fascia ledges over the shops (city-buildings.js, city-style.js). The JS painted them NIGHT.trim and
// NIGHT.chromeDark, about three times lighter than the towers they sit on (the JS Deck found the same and took its own darker set), so every podium wore a lavender line and
// every roof a pale box, where the Batman Beyond references have dark crowns. Here the kit sits in the mass's values and its tops are wet and carry the sky. Everything else
// in these meshes (the quay, the rails, the Deck's own steel, street props) draws exactly as the plain material did. The Deck lamps that were cut (levels/hub/deck_look.gd)
// fold away here (levels/shaders/city_cut.gdshaderinc).
shader_type spatial;
render_mode unshaded, shadows_disabled;

#include "res://levels/shaders/city_env.gdshaderinc"
#include "res://levels/shaders/city_cut.gdshaderinc"
#include "res://levels/shaders/flash_light.gdshaderinc"      // the brief lights of play (core/flash_lights.gd)

uniform float ground_y = -10.0;
uniform float kit_k = 0.32;          // how far the kit drops toward the towers' values

varying vec3 v_col;
varying vec3 w_pos;
varying flat vec3 v_far_mass;
varying flat vec3 v_far_street;

void vertex() {
	v_col = srgb_decode(COLOR.rgb);           // (what the plain material did: vertex colours stored sRGB)
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 cw = city_cut(wp);      // a cut Deck lamp's mast or arm folds away
	if (cw != wp) {
		VERTEX = (inverse(MODEL_MATRIX) * vec4(cw, 1.0)).xyz;
	}
	w_pos = cw;
	v_far_mass = display_to_radiance(vec3(0.022, 0.016, 0.036));
	v_far_street = display_to_radiance(vec3(0.032, 0.02, 0.042));
}

void fragment() {
	vec3 c = v_col;
	vec3 V = normalize(w_pos - CAMERA_POSITION_WORLD);
	vec3 n = normalize(cross(dFdx(w_pos), dFdy(w_pos)));
	if (dot(n, V) > 0.0) {
		n = -n;
	}
	// is it the kit? JS NIGHT.trim and NIGHT.chromeDark after FLAT_GAMMA (1.6) are (0.048, 0.0385, 0.076) and (0.043, 0.043, 0.059), times a face shade of 0.84..1.1:
	// the shade scales all three, so the hue gives them away (and the brightness keeps out the Deck's own darker steel, which leans the same way)
	vec2 q = vec2(c.r, c.b) / max(c.g, 1e-5);
	float kit = max(1.0 - smoothstep(0.07, 0.11, length(q - vec2(1.25, 1.97))), 1.0 - smoothstep(0.05, 0.08, length(q - vec2(1.0, 1.364))));
	kit *= smoothstep(0.024, 0.03, c.g) * step(ground_y + 1.0, w_pos.y);
	if (kit > 0.0) {
		float up = smoothstep(0.6, 0.9, n.y);
		vec3 face = c * kit_k;
		float fres = pow(1.0 - max(dot(-V, n), 0.0), 5.0);
		vec3 sky = city_env(normalize(reflect(V, n)), 0.35, w_pos.y - ground_y, v_far_mass, v_far_street, 0.3);
		vec3 top = c * kit_k * 0.7 + sky * (0.03 + 0.4 * fres);      // a wet top: dark, with the sky in it at a low angle
		c = mix(c, mix(face, top, up), kit);
	}
	ALBEDO = c + flash_light(w_pos, n, vec3(0.3));
}
