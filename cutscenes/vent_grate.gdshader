// What lies over the vent grate's frames (JS #ventcs .grain, .vig, .shade): film grain rings that jump three times every 0.18 s, the vignette, and the black it ends on.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
uniform float shade = 0.0;
uniform float time = 0.0;
uniform float fade = 1.0;
uniform vec2 res = vec2(1280.0, 720.0);

void fragment() {
	// .grain: repeating-radial-gradient(circle at 30% 40%, #ffffff07 0 1px, #0000 1px 3px) on an element twice the screen, moved in three steps
	float st = floor(mod(time, 0.18) / 0.06);
	vec2 off = st < 1.0 ? vec2(0.0) : (st < 2.0 ? vec2(-0.03, 0.02) : vec2(0.02, -0.02));
	vec2 p = (UV + vec2(0.5)) * 0.5 - off;
	float d = length((p - vec2(0.3, 0.4)) * res * 2.0);
	float ring = step(mod(d, 3.0), 1.0) * 7.0 / 255.0;
	// .vig: radial-gradient(ellipse at 50% 46%, #0000 42%, #000c 100%), farthest corner
	vec2 far_ = vec2(0.5, 0.54) * sqrt(2.0);
	float vg = clamp((length((UV - vec2(0.5, 0.46)) / far_) - 0.42) / 0.58, 0.0, 1.0) * 0.8;
	float a = 1.0 - (1.0 - vg) * (1.0 - shade);
	COLOR = vec4(vec3(ring) * (1.0 - a), a) * fade;
}
