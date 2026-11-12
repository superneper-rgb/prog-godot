// Glowing points (JS PointsMaterial with a glowSprite): the FOINT DOME's flames and spire tips, the alley's door bulb. All of it is in glow_points.gdshaderinc.
// ENGINE DIFFERENCE: the bulb's JS material takes fog; here none does, because fog on an additive surface adds the fog colour (tools/check.mjs rule).
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, skip_vertex_transform, cull_disabled, fog_disabled;

#include "res://levels/shaders/glow_points.gdshaderinc"
