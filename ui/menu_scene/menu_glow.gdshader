// Main menu backdrop: an additive sprite or ribbon (lamps, halos, reflections on the wet ground, the bolt).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
#include "res://ui/menu_scene/menu_sprite.gdshaderinc"
