// THE MOTHERSHIP: its unlit additive pieces (beams, cones, pools, glows, the gravity well), what the JS draws with AdditiveBlending and canvas textures, worked out here.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform int mode = 0;      // 0 plain; 1 beam stripes; 2 a lamp cone (bright at the lamp); 3 a pool of light; 4 a glow dot; 5 the Spine Beam; 6 a gravity well; 7 a glow dot in a MultiMesh (COLOR.a)
instance uniform vec4 tint = vec4(1.0);
instance uniform float opacity = 1.0;
instance uniform float scroll = 0.0;
varying float v_a;

void vertex() {
	v_a = 1.0;
	if (mode == 4 || mode == 7 || mode == 8) {
		float s = length(MODEL_MATRIX[0].xyz);
		vec4 view = VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0);
		view.xy += VERTEX.xy * vec2(s, length(MODEL_MATRIX[1].xyz));
		POSITION = PROJECTION_MATRIX * view;
		if (mode == 7) {
			v_a = COLOR.a;
		}
	} else {
		POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);      // (a shader that writes POSITION must write it on every path: Godot does not fall back)
	}
}

void fragment() {
	float a = 1.0;
	vec3 c = tint.rgb;
	if (mode == 1) {      // JS stripeTex: six bands up the beam, darker at the seam
		float k = 0.35 + 0.65 * pow(0.5 + 0.5 * sin((UV.y + scroll) * 6.2831853 * 6.0), 3.0);
		a = k * (1.0 - 0.7 * abs(2.0 * fract(UV.x) - 1.0));
	} else if (mode == 2) {
		float v = UV.y;
		a = v < 0.35 ? mix(1.0, 0.416, v / 0.35) : mix(0.416, 0.0, clamp((v - 0.35) / 0.65, 0.0, 1.0));
	} else if (mode == 3) {
		float d = length(UV * 2.0 - vec2(1.0));
		a = d < 0.45 ? mix(1.0, 0.353, d / 0.45) : mix(0.353, 0.0, clamp((d - 0.45) / 0.55, 0.0, 1.0));
	} else if (mode == 4 || mode == 7 || mode == 8) {
		float d = length(UV * 2.0 - vec2(1.0));
		a = (mode == 8 ? (d < 0.22 ? mix(1.0, 0.5, d / 0.22) : mix(0.5, 0.0, clamp((d - 0.22) / 0.78, 0.0, 1.0))) : (d < 0.3 ? mix(1.0, 0.6, d / 0.3) : mix(0.6, 0.0, clamp((d - 0.3) / 0.7, 0.0, 1.0)))) * v_a;      // 8: OMNISPHERE's glow map (textures.js glowTexture)
	} else if (mode == 5) {      // JS spine: the stripes run 40 times up the 400 m column and carry a warm gradient of their own
		float k = 0.4 + 0.6 * pow(0.5 + 0.5 * sin((UV.y * 40.0 + scroll) * 6.2831853 * 8.0), 2.0);
		a = k;
		c *= vec3(1.0, pow((200.0 + k * 50.0) / 255.0, 2.2), pow((120.0 + k * 80.0) / 255.0, 2.2));
	} else if (mode == 6) {      // JS wellTex: four arms spiralling in to a white-hot eye
		vec2 p = (UV * 2.0 - vec2(1.0)) * 64.0;
		float r = length(p);
		float u = clamp((r - 6.0) / 56.0, 0.0, 1.0);
		float th = atan(p.y, p.x) - u * 1.6 * 3.1415927;
		float q = 1.5707963;
		float da = abs(th - q * round(th / q));
		float arm = (r > 3.0 && r < 62.0) ? smoothstep(4.5, 2.5, da * r) * 0.9 : 0.0;
		float g = r / 64.0;
		float eye = g < 0.18 ? mix(1.0, 0.5, g / 0.18) : mix(0.5, 0.0, clamp((g - 0.18) / 0.82, 0.0, 1.0));
		a = max(arm, eye) * step(g, 1.0);
	}
	if (mode == 8) {      // OMNISPHERE's sprites: three.js encodes the colour, then the blend adds it times alpha, so the glow's falloff stays linear on the display
		ALBEDO = display_to_radiance(srgb_encode(c) * a * opacity);
		ALPHA = 1.0;
	} else
	ALBEDO = display_to_radiance(srgb_encode(c * a * opacity));      // (toneMapped: false: the JS adds the plain value before the sRGB step)
	ALPHA = 1.0;
}
