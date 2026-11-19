// The FOINT DOME's lights (levels/hub/foint_dome.gd): the red windows, seams and door slats, the sign's letters, the lanterns' glass. Unlit and out of the fog, so they hold
// their colour across the plaza (as the JS light meshes did). COLOR.r is each face's own strength; `level` is what FointDomeLife breathes and flickers.
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.92, 0.0, 0.07);     // deep crimson, as the concept's windows: a touch of blue in it, no green
uniform vec3 hot : source_color = vec3(1.0, 0.1, 0.16);       // the core a strong light burns towards (kept red: the tone curve turns a brighter one orange)
uniform float gain = 0.42;                                    // (user, 2026-11-12: "dimmer and deeper like the concept"; was 0.85, and under the tone curve that read scarlet)
uniform float level = 1.0;

void fragment() {
	float k = COLOR.r * level;
	ALBEDO = mix(tint, hot, smoothstep(0.75, 1.1, k) * 0.45) * k * gain;
}
