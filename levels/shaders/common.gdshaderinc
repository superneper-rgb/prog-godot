// Shared by the hand-ported level shaders.
// Godot draws into HDR and post_fx.gd tone-maps at the end. three.js tone-maps each material as it draws, then blends on the display value. These convert between the two.

global uniform float prog_exposure;       // the level's tone map (View.apply_render_state)
global uniform float prog_tone_on;

// sRGB-encoded value to linear (three.js sRGBTransferEOTF).
vec3 srgb_decode(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

// linear to sRGB-encoded (three.js sRGBTransferOETF).
vec3 srgb_encode(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

float _rrt_inverse(float y) {
	y = clamp(y, 0.0, 1.0);
	float a = 1.0 - 0.983729 * y;
	float b = 0.0245786 - 0.4329510 * y;
	float d = 0.000090537 + 0.238081 * y;
	return (-b + sqrt(b * b + 4.0 * a * d)) / (2.0 * a);
}

// The HDR radiance that post_fx.gd's tone map turns into this display colour: for the JS shaders that write straight to the screen, without <tonemapping_fragment>. Same as View.display_to_radiance.
vec3 display_to_radiance(vec3 c) {
	vec3 l = srgb_decode(clamp(c, vec3(0.0), vec3(1.0)));
	if (prog_tone_on < 0.5) {
		return l;
	}
	vec3 v = vec3(dot(vec3(0.643038, 0.311187, 0.045775), l), dot(vec3(0.059269, 0.931436, 0.009295), l), dot(vec3(0.005962, 0.063929, 0.930118), l));
	v = vec3(_rrt_inverse(v.x), _rrt_inverse(v.y), _rrt_inverse(v.z));
	v = vec3(dot(vec3(1.764741, -0.675778, -0.088963), v), dot(vec3(-0.147028, 1.160252, -0.013224), v), dot(vec3(-0.036337, -0.162436, 1.198773), v));
	return max(v * 0.6 / prog_exposure, vec3(0.0));
}

// three.js ACESFilmicToneMapping, then to the display value (<tonemapping_fragment> + <colorspace_fragment>).
vec3 radiance_to_display(vec3 c) {
	if (prog_tone_on < 0.5) {
		return srgb_encode(c);
	}
	c *= prog_exposure / 0.6;
	vec3 v = vec3(dot(vec3(0.59719, 0.35458, 0.04823), c), dot(vec3(0.07600, 0.90834, 0.01566), c), dot(vec3(0.02840, 0.13383, 0.83777), c));
	v = (v * (v + 0.0245786) - 0.000090537) / (v * (0.983729 * v + 0.4329510) + 0.238081);
	return srgb_encode(clamp(vec3(dot(vec3(1.60475, -0.53108, -0.07367), v), dot(vec3(-0.10208, 1.10813, -0.00605), v), dot(vec3(-0.00327, -0.07276, 1.07602), v)), vec3(0.0), vec3(1.0)));
}

// What to add to Godot's HDR frame so that over a dark background the picture is the JS one: there, this radiance is tone-mapped, then added to the display value, scaled by its alpha.
// A glow added before the tone map instead comes out far too bright, because the curve lifts small values most. Use with ALPHA = 1.
vec3 add_display(vec3 radiance, float alpha) {
	return display_to_radiance(radiance_to_display(radiance) * alpha);
}

// gl_PointSize in a quad: half the quad's width in view space for a point `px` pixels across, `dist` in front of the camera.
float point_half(float px, float dist, vec2 viewport, float p11) {
	return px * dist / (viewport.y * p11);
}
