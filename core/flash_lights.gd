class_name FlashLights
extends RefCounted
## The brief lights of play (a muzzle flash, an explosion, a gadget's blast, a spell) handed to the painted world. Lit things already take them as real lights;
## the painted shaders (FOINT CITY's walls, roads, Deck) cannot, so every frame the nearest few go out as global shader values and
## levels/shaders/flash_light.gdshaderinc adds them there. A light joins by being in the GROUP; nothing else to wire.

const GROUP := &"flash_light"
const N := 4      # how many the painted world takes at once (flash_light.gdshaderinc reads this many)
const P: Array[StringName] = [&"prog_flash_p0", &"prog_flash_p1", &"prog_flash_p2", &"prog_flash_p3"]      # xyz where, w range
const C: Array[StringName] = [&"prog_flash_c0", &"prog_flash_c1", &"prog_flash_c2", &"prog_flash_c3"]      # rgb linear colour times energy

static var _sent := 0      # how many slots were last sent lit (an idle frame after an idle frame sends nothing)


## Declares the global shader values (core/material_look.gd, with the others, before any shader that reads them compiles).
static func declare() -> void:
	for k in N:
		RenderingServer.global_shader_parameter_add(P[k], RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, -1000.0, 0.0, 1.0))
		RenderingServer.global_shader_parameter_add(C[k], RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4.ZERO)


## Once a frame after the FX: the N lit flashes nearest the camera.
static func push(tree: SceneTree, cam: Vector3) -> void:
	var near: Array[Vector2] = []      # (distance squared, index)
	var lights := tree.get_nodes_in_group(GROUP)
	for i in lights.size():
		var l := lights[i] as OmniLight3D
		if l == null or not l.is_visible_in_tree() or l.light_energy < 0.01:
			continue
		near.append(Vector2(l.global_position.distance_squared_to(cam), i))
	if near.is_empty() and _sent == 0:
		return
	near.sort()
	var n := mini(N, near.size())
	for k in N:
		if k < n:
			var l := lights[int(near[k].y)] as OmniLight3D
			var p := l.global_position
			var c := l.light_color.srgb_to_linear() * l.light_energy
			RenderingServer.global_shader_parameter_set(P[k], Vector4(p.x, p.y, p.z, l.omni_range))
			RenderingServer.global_shader_parameter_set(C[k], Vector4(c.r, c.g, c.b, 0.0))
		elif k < _sent:
			RenderingServer.global_shader_parameter_set(C[k], Vector4.ZERO)
	_sent = n
