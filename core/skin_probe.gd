class_name SkinProbe
extends RefCounted
## Reads a posed character's skinned vertices from script (JS mesh.getVertexPosition, skeleton.update): the lowest point of the body, or the first surface a ray meets. Holds a copy of the rest vertices and weights of every visible skinned surface.

class Surf:
	var V: PackedVector3Array
	var BI: PackedInt32Array
	var BW: PackedFloat32Array
	var per := 4
	var bone_of := PackedInt32Array()
	var bind: Array[Transform3D] = []


var an: Animator
var surfs: Array[Surf] = []


func _init(p_an: Animator) -> void:
	an = p_an
	var sk := an.skel
	var walk: Array[Node] = [an.model]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if not n is MeshInstance3D or not (n as MeshInstance3D).is_visible_in_tree():
			continue
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.skin == null:
			continue
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			if arr[Mesh.ARRAY_BONES] == null or (arr[Mesh.ARRAY_BONES] as PackedInt32Array).is_empty():
				continue
			var o := Surf.new()
			o.V = arr[Mesh.ARRAY_VERTEX]
			o.BI = arr[Mesh.ARRAY_BONES]
			o.BW = arr[Mesh.ARRAY_WEIGHTS]
			o.per = o.BI.size() / o.V.size()
			for b in mi.skin.get_bind_count():
				var bi := mi.skin.get_bind_bone(b)
				o.bone_of.append(bi if bi >= 0 else sk.find_bone(mi.skin.get_bind_name(b)))
				o.bind.append(mi.skin.get_bind_pose(b))
			surfs.append(o)


func _xforms(o: Surf) -> Array[Transform3D]:
	var sk := an.skel
	var sg := sk.global_transform
	var xf: Array[Transform3D] = []
	xf.resize(o.bone_of.size())
	for b in o.bone_of.size():
		var bi := o.bone_of[b]
		xf[b] = sg * sk.get_bone_global_pose(bi) * o.bind[b] if bi >= 0 else sg
	return xf


static func _skin(o: Surf, xf: Array[Transform3D], i: int) -> Vector3:
	var p := Vector3.ZERO
	var v := o.V[i]
	var at := i * o.per
	for j in o.per:
		var w := o.BW[at + j]
		if w > 0.0:
			p += (xf[o.BI[at + j]] * v) * w
	return p


## the lowest world height of the model (every `step`th vertex is enough)
func lowest(step: int = 7) -> float:
	var low := INF
	for o in surfs:
		var xf := _xforms(o)
		for i in range(0, o.V.size(), step):
			var y := _skin(o, xf, i).y
			if y < low:
				low = y
	return low


## the first vertex a ray meets (within radius of it): a stand-in for a mesh raycast. NAN vector when it misses.
func ray_hit(from: Vector3, dir: Vector3, max_d: float, radius: float = 0.04) -> Vector3:
	var best := INF
	var hit := Vector3(NAN, NAN, NAN)
	for o in surfs:
		var xf := _xforms(o)
		for i in o.V.size():
			var p := _skin(o, xf, i)
			var d := p - from
			var along := d.dot(dir)
			if along < 0.0 or along > max_d or along >= best:
				continue
			if (d - dir * along).length_squared() < radius * radius:
				best = along
				hit = p
	return hit
