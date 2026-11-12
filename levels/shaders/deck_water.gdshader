// Water off the Deck (levels/hub/deck_underside.gd): the rain running off the slab's edges and through its expansion joints, and the wet streaks it leaves down the piers.
// It carries light, it is not a light: a faint violet-grey (the city's 30%), additive, so it only shows against the dark mass behind it. UV is in metres: x along, y down from the top.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(0.36, 0.34, 0.52);
uniform float strength = 0.05;
uniform float columns = 3.0;        // drip lines per metre that could run
uniform float density = 0.35;       // how many of them do
uniform float speed = 6.0;          // m/s down (0: a still stain)
uniform float height = 12.0;        // the sheet's height, for the fade at the bottom

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float vnoise1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash11(i), hash11(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	float x = UV.x * columns;
	float c = floor(x);
	float h = hash11(c + 17.0);
	float on = step(h, density);
	float w = fract(x) - 0.5 - (hash11(c + 3.0) - 0.5) * 0.5;
	float line = 1.0 - smoothstep(0.03, 0.14, abs(w));
	float y = UV.y;
	float flow;
	if (speed > 0.0) {      // falling water: dashes running down the line at their own pace
		float ph = fract(y / (2.0 + 3.0 * h) - TIME * speed / (2.0 + 3.0 * h) * (0.8 + 0.4 * hash11(c + 9.0)) + h * 5.0);
		flow = smoothstep(0.0, 0.06, ph) * (1.0 - smoothstep(0.25, 0.7, ph));
		flow = max(flow, 0.25);
	} else {               // a stain: strongest under the cap where the water comes out, wandering, dying out down the face
		flow = vnoise1(y * 0.8 + c * 3.1) * exp(-y * 0.16);
		line = 1.0 - smoothstep(0.1, 0.45, abs(w));
	}
	float fade = smoothstep(0.0, 0.4, y) * (1.0 - smoothstep(height * 0.7, height, y));
	ALBEDO = tint * strength * on * line * flow * fade;
}
