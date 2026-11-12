// ## A lamp's light cone seen through haze: unlit and additive, soft at its silhouette, fading down its length and where it meets the floor.
// New (user, 2026-11-10, OMNISPHERE's yard lamp): the export drew the cone as a lit StandardMaterial at the JS's 4.5 % additive opacity. The browser blended
// after gamma, so 4.5 % was a faint haze there. Godot blends in linear light, where the same 4.5 % reads as a solid grey wedge with hard edges.
// `opacity` keeps the JS's scale (OmDraw.set_opacity drives it with the plant's power) and `gain` sets how bright the soft beam is.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec3 tint : source_color = vec3(1.0);
uniform float opacity = 0.045;
uniform float gain = 5.0;      // (edge and fall thin the beam a lot: at full power this is a faint haze near the lamp, fading out down the cone)
uniform float beam_len = 14.0;      // apex at local y 0, the mouth at y -beam_len
uniform float soft_floor = 1.2;     // metres over which the cone fades into whatever it touches
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying float along;

void vertex() {
	along = clamp(-VERTEX.y / max(beam_len, 0.01), 0.0, 1.0);
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), VIEW));
	float edge = facing * facing;                              // grazing faces (the silhouette) go to nothing
	float fall = (1.0 - along) * (0.35 + 0.65 * (1.0 - along)) + 0.04;      // bright at the lamp, thin at the mouth
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 p = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float scene_z = -p.z / p.w;
	float soft = clamp((scene_z + VERTEX.z) / soft_floor, 0.0, 1.0);      // VERTEX is view space here: -VERTEX.z is this fragment's depth
	ALBEDO = tint;
	ALPHA = clamp(opacity * gain * edge * fall * soft, 0.0, 1.0);
}
