// The FOINT CITY billboard's screen (levels/hub/foint_ad_monitor.gd): the ad's current video frame as a lit LED panel. Unlit and out of the fog like the dome's lights, so it holds across the plaza.
// Close up the panel's pixel grid shows; it fades out once a pixel is smaller than a screen pixel, so far off it is a clean picture with no shimmer (the frames are mipmapped as well).
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, cull_back;

uniform sampler2D video : source_color, hint_default_black, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 pixels = vec2(960.0, 540.0);     // the video's size: one LED cell per video pixel
uniform float gain = 0.85;                    // overall brightness (the tone curve and bloom come after)
uniform float level = 1.0;                    // flicker / power, set by the script
uniform float t = 0.0;
uniform vec3 sheen : source_color = vec3(0.06, 0.07, 0.12);   // the glass at a grazing angle: the night sky's violet-blue

void fragment() {
	vec2 uv = UV;
	vec3 c = texture(video, uv).rgb;
	// the LED grid, only where the cells are big on screen
	vec2 p = uv * pixels;
	vec2 fw = fwidth(p);
	float near = 1.0 - smoothstep(0.18, 0.55, max(fw.x, fw.y));
	vec2 cell = abs(fract(p) - 0.5) * 2.0;
	float grid = mix(1.0, (1.0 - smoothstep(0.55, 1.0, max(cell.x, cell.y))) * 1.3, near * 0.55);
	// a faint refresh band rolling down the panel
	float band = 1.0 + 0.05 * (1.0 - smoothstep(0.0, 0.06, abs(fract(uv.y - t * 0.11) - 0.5)));
	// the backlight falls off a little at the panel's edges
	vec2 e = min(uv, 1.0 - uv) * vec2(pixels.x / pixels.y, 1.0);
	float edge = 0.8 + 0.2 * smoothstep(0.0, 0.05, min(e.x, e.y));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = c * gain * level * grid * band * edge + sheen * fres;
}
