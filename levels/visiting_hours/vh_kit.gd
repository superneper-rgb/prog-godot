class_name VhKit
extends RefCounted
## VISITING HOURS: small tools shared by the level's parts: finding what the export kept, giving a sprite its own opacity, a solid by its JS id.


static func one(lv: ExportedLevel, nm: String) -> Node3D:
	for n: Node3D in lv.node_named(nm):
		return n
	push_warning("VISITING HOURS: nothing exported as " + nm)
	var d := Node3D.new()
	lv.add_child(d)
	return d


static func all(lv: ExportedLevel, nm: String) -> Array:
	return lv.node_named(nm)


## a named light is two things in the export: its place in the JS tree (a plain node that hides and moves with its parent) and the Godot light, loose under the level. The light goes under its place, on: what shows it is the tree above it
static func adopt_lights(lv: ExportedLevel) -> void:
	for nm: Variant in lv.by_name.keys():
		var list: Array = lv.by_name[nm]
		var ls: Array = []
		var places: Array = []
		for n: Node3D in list:
			if n is Light3D:
				ls.append(n)
			elif not (n is MeshInstance3D or n is MultiMeshInstance3D):
				places.append(n)
		for l: Light3D in ls:
			var best: Node3D = null
			var bd := INF
			for p: Node3D in places:
				var d := p.global_position.distance_squared_to(l.global_position)
				if d < bd:
					bd = d
					best = p
			if best != null:
				places.erase(best)
				l.reparent(best, true)
				l.visible = true


## a named sprite is exported twice over its size: the mesh is already its full width and the node keeps the JS scale too
static func unscale_sprites(lv: ExportedLevel) -> void:
	for nm: Variant in lv.by_name.keys():
		for n: Node3D in lv.by_name[nm]:
			if n is MeshInstance3D or n.get_child_count() != 1 or n.scale.is_equal_approx(Vector3.ONE):
				continue
			var mi := n.get_child(0) as MeshInstance3D
			if mi != null and mi.mesh != null and mi.mesh.get_aabb().size.z < 1e-3 and mi.mesh.get_surface_count() == 1 and absf(mi.mesh.get_aabb().size.x - mi.mesh.get_aabb().size.y) < 0.01 and absf(n.scale.x - mi.mesh.get_aabb().size.x) < n.scale.x * 0.5:
				n.scale = Vector3.ONE


## the meshes at or under a node
static func meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var walk: Array[Node] = [root]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if n is MeshInstance3D:
			out.append(n as MeshInstance3D)
	return out


## the light at or under a named node (a named light is its own node in by_name)
static func light(lv: ExportedLevel, nm: String) -> Light3D:
	for n: Node3D in lv.node_named(nm):
		if n is Light3D:
			return n as Light3D
		for c: Node in n.find_children("*", "Light3D", true, false):
			return c as Light3D
	push_warning("VISITING HOURS: no light " + nm)
	return null


## a sprite's own copy of its material: glows share one material per colour (ShaderPorts), and these change opacity one by one
static func own_sprite(n: Node3D) -> ShaderMaterial:
	for mi: MeshInstance3D in meshes(n):
		var m: Material = mi.material_override
		if m == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			m = mi.get_active_material(0)
		if m is ShaderMaterial:
			var d := (m as ShaderMaterial).duplicate() as ShaderMaterial
			mi.material_override = d
			return d
	return null


## every StandardMaterial3D under a node as its own copy (identical exported materials are folded, so a fade or a colour would reach other things)
static func own_std(root: Node) -> Array[StandardMaterial3D]:
	var out: Array[StandardMaterial3D] = []
	for mi in meshes(root):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as StandardMaterial3D
			if m != null:
				var d := m.duplicate() as StandardMaterial3D
				mi.set_surface_override_material(s, d)
				out.append(d)
	return out


static func set_col(mi: Node3D, c: Color) -> void:
	for m in meshes(mi):
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var sm := m.get_active_material(s) as StandardMaterial3D
			if sm != null:
				sm.albedo_color = Color(c.r, c.g, c.b, sm.albedo_color.a)


## JS solids carrying a vhId: id -> Array of Solid (in world order)
static func solids(world: World) -> Dictionary:
	var out := {}
	for s: World.Solid in world.solids:
		var ex: Variant = s.data.get("extra")
		if ex is Dictionary and (ex as Dictionary).has("vhId"):
			var k: String = (ex as Dictionary)["vhId"]
			if not out.has(k):
				out[k] = []
			(out[k] as Array).append(s)
	return out


static func unlit(hex: int, a: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.hex((hex << 8) | 0xff)
	m.albedo_color.a = a
	if a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## a 2D picture on a plane drawn with a Control: redrawn only when asked. size in pixels; draw: Callable(Control)
class Canvas:
	extends SubViewport
	var fn: Callable

	class Pad:
		extends Control
		var fn: Callable

		func _draw() -> void:
			if fn.is_valid():
				fn.call(self)

	var pad: Pad

	func _init(w: int, h: int, p_fn: Callable) -> void:
		fn = p_fn
		size = Vector2i(w, h)
		transparent_bg = false
		disable_3d = true
		handle_input_locally = false
		gui_disable_input = true
		render_target_update_mode = SubViewport.UPDATE_ONCE
		pad = Pad.new()
		pad.fn = p_fn
		pad.size = Vector2(w, h)
		add_child(pad)

	func redraw() -> void:
		pad.queue_redraw()
		render_target_update_mode = SubViewport.UPDATE_ONCE
