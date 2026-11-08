// Additive cutscene particles: flames, sparks, embers.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, skip_vertex_transform, cull_disabled, fog_disabled;
#include "res://cutscenes/cine_puffs.gdshaderinc"
