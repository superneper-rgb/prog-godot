// RigidBatch, the additive parts: the JS game's glow sprites (camera-facing quads with a soft radial falloff) and additive rings, all copies of a model in one draw.
// Sprite channels live in the copy's row of the data texture: texel 3 holds one size per sprite channel (0..3), texels 4..8 colour + opacity per channel.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform, fog_disabled;

uniform sampler2D data : filter_nearest, repeat_disable;

const int PARAMS = 11;

varying vec4 v_col;
varying float v_sprite;

void vertex() {
	int row = INSTANCE_ID;
	int slot = int(UV2.x + 0.5);
	int ch = int(UV2.y + 0.5);
	int base = PARAMS + slot * 3;
	vec4 r0 = texelFetch(data, ivec2(base, row), 0);
	vec4 r1 = texelFetch(data, ivec2(base + 1, row), 0);
	vec4 r2 = texelFetch(data, ivec2(base + 2, row), 0);
	vec4 h = vec4(VERTEX, 1.0);
	vec3 world = vec3(dot(r0, h), dot(r1, h), dot(r2, h));
	v_col = texelFetch(data, ivec2(4 + ch, row), 0);
	vec4 view = VIEW_MATRIX * vec4(world, 1.0);
	float base_size = CUSTOM0.x;
	v_sprite = base_size > 0.0 ? 1.0 : 0.0;
	if (base_size > 0.0) {                           // a THREE.Sprite: faces the camera, its size follows the joint's scale
		float scale_of_joint = length(vec3(r0.x, r1.x, r2.x));
		float size = base_size * scale_of_joint * texelFetch(data, ivec2(3, row), 0)[ch];
		view.xy += (UV - vec2(0.5)) * vec2(1.0, -1.0) * size;
	}
	VERTEX = view.xyz;
}

void fragment() {
	float a = 1.0;
	if (v_sprite > 0.5) {                            // the canvas gradient: 1 at the centre, 0.55 a quarter of the way out, 0 at the rim
		float d = length(UV * 2.0 - vec2(1.0));
		a = d < 0.25 ? mix(1.0, 0.55, d / 0.25) : mix(0.55, 0.0, clamp((d - 0.25) / 0.75, 0.0, 1.0));
	}
	ALBEDO = v_col.rgb;
	// ENGINE DIFFERENCE: the JS adds these to a display-referred frame, Godot adds them before the tone map: the curve keeps the same glow on screen
	ALPHA = pow(a * v_col.a, 2.2);
}
