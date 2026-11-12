// The Deck lamps that were cut (levels/hub/deck_look.gd `cut`): their pieces are merged into the district's big meshes with everything else, so they are folded away here instead:
// a vertex inside one of these boxes moves to the box's middle, and the piece's triangles are left with no area. Boxes in world space; the rest of the city never enters the loop.
uniform vec3 cut_lo[128];
uniform vec3 cut_hi[128];
uniform int cut_n = 0;
uniform vec3 cut_all_lo = vec3(0.0);
uniform vec3 cut_all_hi = vec3(0.0);

// a world position, or the middle of the cut box it is in
vec3 city_cut(vec3 wp) {
	if (cut_n > 0 && all(greaterThanEqual(wp, cut_all_lo)) && all(lessThanEqual(wp, cut_all_hi))) {
		for (int i = 0; i < 128; i++) {
			if (i >= cut_n) {
				break;
			}
			if (all(greaterThanEqual(wp, cut_lo[i])) && all(lessThanEqual(wp, cut_hi[i]))) {
				return (cut_lo[i] + cut_hi[i]) * 0.5;
			}
		}
	}
	return wp;
}
