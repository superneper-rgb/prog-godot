// The night vision screen (JS gear/night-vision.js): the CSS filter grayscale(1) contrast(1.05) brightness(1.2) sepia(1) hue-rotate(58deg) saturate(3.2) on the picture, then the overlay: grain, scanlines, vignette, the switch-on flash.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float flash = 0.0;
uniform float overlay = 1.0;

float noise_at(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	// grayscale(1) contrast(1.05) brightness(1.2)
	float L = dot(c, vec3(0.2126, 0.7152, 0.0722));
	L = clamp((L - 0.5) * 1.05 + 0.5, 0.0, 1.0);
	L = clamp(L * 1.2, 0.0, 1.0);
	// sepia(1) of a grey
	c = clamp(vec3(L * 1.351, L * 1.203, L * 0.937), vec3(0.0), vec3(1.0));
	// hue-rotate(58deg)
	float s = 0.84805, k = 0.52992;
	mat3 h = mat3(
		vec3(0.213 + k * 0.787 - s * 0.213, 0.213 - k * 0.213 + s * 0.143, 0.213 - k * 0.213 - s * 0.787),
		vec3(0.715 - k * 0.715 - s * 0.715, 0.715 + k * 0.285 + s * 0.140, 0.715 - k * 0.715 + s * 0.715),
		vec3(0.072 - k * 0.072 + s * 0.928, 0.072 - k * 0.072 - s * 0.283, 0.072 + k * 0.928 + s * 0.072));
	c = clamp(h * c, vec3(0.0), vec3(1.0));
	// saturate(3.2)
	float l2 = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = clamp(mix(vec3(l2), c, 3.2), vec3(0.0), vec3(1.0));
	// grain: 240 x 135 cells, a new field most frames, screen-blended at .15
	vec2 cell = floor(SCREEN_UV * vec2(240.0, 135.0));
	float v = noise_at(cell + floor(TIME * 36.0) * 0.37);
	vec3 g = vec3(v * 0.7, v, v * 0.6) * 0.15 * overlay;
	c = 1.0 - (1.0 - c) * (1.0 - g);
	// scanlines: rgba(0,0,0,.18), one pixel in three
	if (mod(FRAGCOORD.y, 3.0) < 1.0) {
		c *= 1.0 - 0.18 * overlay;
	}
	// vignette: transparent to 55%, rgba(0,12,0,.55) at 85%, rgba(0,6,0,.92) at 100% of an ellipse 75% x 70% of the screen
	float d = length((UV - vec2(0.5)) / vec2(0.75, 0.7));
	float a = d < 0.55 ? 0.0 : (d < 0.85 ? mix(0.0, 0.55, (d - 0.55) / 0.3) : mix(0.55, 0.92, min(1.0, (d - 0.85) / 0.15)));
	c = mix(c, d < 0.85 ? vec3(0.0, 12.0 / 255.0, 0.0) : vec3(0.0, 6.0 / 255.0, 0.0), a * overlay);
	// the switch-on flash
	if (flash > 0.0) {
		vec2 px = (UV - vec2(0.5)) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
		float r = length(px) / length(vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0) * 0.5);
		vec3 fc = r < 0.4 ? mix(vec3(230.0, 255.0, 220.0), vec3(120.0, 255.0, 90.0), r / 0.4) : mix(vec3(120.0, 255.0, 90.0), vec3(40.0, 160.0, 30.0), (r - 0.4) / 0.6);
		float fa = r < 0.4 ? mix(1.0, 0.75, r / 0.4) : mix(0.75, 0.35, (r - 0.4) / 0.6);
		c = mix(c, fc / 255.0, fa * flash);
	}
	COLOR = vec4(c, 1.0);
}
