// RAILJACK: over the glass and its HUD (JS composite): the alarm's red hue, the flashes, scan lines, grain, the slow roll bar and the vignette.
shader_type canvas_item;
render_mode blend_disabled;

uniform sampler2D screen : hint_screen_texture, filter_nearest, repeat_disable;
uniform vec2 box = vec2(1000.0, 700.0);
uniform float red = 0.0;
uniform float red_flash = 0.0;
uniform float white_flash = 0.0;
uniform vec2 grain_off = vec2(0.0);
uniform float roll = 0.0;
uniform vec3 roll_col = vec3(0.43, 1.0, 0.67);

float lum(vec3 c) {
	return 0.3 * c.r + 0.59 * c.g + 0.11 * c.b;
}

vec3 clip_color(vec3 c) {
	float l = lum(c);
	float n = min(c.r, min(c.g, c.b));
	float x = max(c.r, max(c.g, c.b));
	if (n < 0.0) {
		c = l + (c - l) * l / (l - n);
	}
	if (x > 1.0) {
		c = l + (c - l) * (1.0 - l) / (x - l);
	}
	return c;
}

// canvas 'hue': the source's hue with the backdrop's saturation and luminosity
vec3 blend_hue(vec3 cb, vec3 cs) {
	float sat_b = max(cb.r, max(cb.g, cb.b)) - min(cb.r, min(cb.g, cb.b));
	float mn = min(cs.r, min(cs.g, cs.b));
	float mx = max(cs.r, max(cs.g, cs.b));
	vec3 s = mx > mn ? (cs - mn) * sat_b / (mx - mn) : vec3(0.0);
	return clip_color(s + (lum(cb) - lum(s)));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 px = UV * box;
	vec3 c = texture(screen, SCREEN_UV).rgb;
	if (red > 0.0) {
		c = mix(c, blend_hue(c, vec3(1.0, 30.0 / 255.0, 20.0 / 255.0)), red);
	}
	c = mix(c, vec3(1.0, 40.0 / 255.0, 20.0 / 255.0), red_flash * 0.3);
	c = mix(c, vec3(210.0, 255.0, 220.0) / 255.0, white_flash * 0.75);
	if (mod(floor(px.y), 3.0) > 1.5) {      // the scan pattern: one row in three
		c *= 0.58;
	}
	// grain, 'overlay'
	float n = hash(mod(floor(px + grain_off), 160.0));
	vec3 ov = vec3(c.r < 0.5 ? 2.0 * c.r * n : 1.0 - 2.0 * (1.0 - c.r) * (1.0 - n), c.g < 0.5 ? 2.0 * c.g * n : 1.0 - 2.0 * (1.0 - c.g) * (1.0 - n), c.b < 0.5 ? 2.0 * c.b * n : 1.0 - 2.0 * (1.0 - c.b) * (1.0 - n));
	c = mix(c, ov, 0.14);
	// the slow roll bar, 'lighter'
	float k = (UV.y - roll) / 0.2;
	if (k > 0.0 && k < 1.0) {
		c += roll_col * 0.05 * (k < 0.55 ? k / 0.55 : (1.0 - k) / 0.45);
	}
	// vignette
	float r0 = min(box.x, box.y) * 0.3;
	float r1 = length(box) * 0.58;
	float v = clamp((length(px - box * 0.5) - r0) / (r1 - r0), 0.0, 1.0);
	c = mix(c, vec3(0.0), v * 0.85);
	COLOR = vec4(min(c, vec3(1.0)), 1.0);
}
