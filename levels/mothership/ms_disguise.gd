class_name MsDisguise
extends RefCounted
## THE MOTHERSHIP's disguise (JS levels/mothership/disguise.js): a terrible rubber gray-alien mask, fitted to the character being played and hung on the head bone so it follows every move. Coat-hanger antennae with foil balls, pin-holes where his real eyes peek out, and the PRICE TAG still dangling off the side.
## Prog's is a size too small (squashed on, the jowls bulge); Tommy's is a size too big, wobbles, and has a hole cut in the top for his beanie propeller. At the toast it comes off and bounces across the floor (it stays there: the evidence).
## The head is measured from the skinned vertices at wear time, as in the JS (gear/night-vision.js measureHead); in the rest pose here, which is the same frame: the head's own, without its rest rotation.


class Mask:
	var root: Node3D
	var fit: Node3D
	var tag_pivot: Node3D
	var tommy := false
	var t := 0.0
	var vx := 0.0
	var vy := 0.0
	var vz := 0.0
	var spin := 0.0


var worn: Mask = null
var loose: Mask = null
var _attach: BoneAttachment3D = null
var _rubber: StandardMaterial3D
var _black: StandardMaterial3D
var _wire: StandardMaterial3D
var _foil: StandardMaterial3D
var _white: StandardMaterial3D
var _paper: StandardMaterial3D


func _init() -> void:
	_rubber = MsKit.std(0x9c9d98, 0.55, 0.0, true)
	_black = MsKit.std(0x050505, 0.05)
	_wire = MsKit.std(0xbfc4cc, 0.3, 0.9)
	_foil = MsKit.std(0xe6e9ee, 0.25, 1.0)
	_white = MsKit.flat(0xffffff)
	_paper = MsKit.flat(0xf4efe2)
	_paper.cull_mode = BaseMaterial3D.CULL_DISABLED


func _shell(tommy: bool, cy: float, rx: float, ry: float, rz: float, fc: float) -> ArrayMesh:
	# the shell: an egg (wider at the top), Tommy's with the top cut away
	var th0 := 0.42 if tommy else 0.0
	var thl := PI - th0
	var W_ := 28
	var H_ := 20
	var v := PackedVector3Array()
	for j in H_ + 1:
		var th := th0 + float(j) / H_ * thl
		for i in W_ + 1:
			var ph := float(i) / W_ * TAU
			var px := -cos(ph) * sin(th)
			var uy := cos(th)
			var pz := sin(ph) * sin(th)
			var w := 1.0 + 0.12 * uy if uy > 0.0 else 1.0 - 0.28 * pow(-uy, 1.5)
			v.append(Vector3(px * rx * w, cy + uy * ry, fc + pz * rz * w))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in H_:
		for i in W_:
			var a := j * (W_ + 1) + i
			var b := a + W_ + 1
			for k: int in [a, a + 1, b, a + 1, b + 1, b]:
				st.add_vertex(v[k])
	st.generate_normals()
	return st.commit()


func _build(tommy: bool, m: Dictionary) -> Mask:
	var k := 1.38 if tommy else 1.07
	var M_ := Mask.new()
	M_.tommy = tommy
	M_.root = Node3D.new()
	M_.root.name = "rubber gray mask"
	M_.fit = Node3D.new()
	M_.root.add_child(M_.fit)
	var mW: float = m.W
	var mH: float = m.H
	var mD: float = m.D
	var lc: float = m.lc
	var fc: float = m.fc
	var cy: float = (float(m.uMin) + float(m.uMax)) / 2.0 + mH * (0.12 if tommy else 0.06)
	var rx := mW / 2.0 * k
	var ry := mH / 2.0 * k * (1.05 if tommy else 1.12)
	var rz := mD / 2.0 * k
	MsKit.part(M_.fit, _shell(tommy, cy, rx, ry, rz, fc), _rubber)
	# a rubber seam at the neck, rolled up
	var seam := MsKit.part(M_.fit, MsKit.torus(1.0, 0.1, 24, 6), _rubber, Vector3(0.0, cy - ry * 0.86, fc))
	seam.scale = Vector3(rx * 0.86, rx * 0.86, rz * 0.86)
	# the big black eyes (with the real eyes' pin-holes): placed on the front of the shell
	var ey: float = float(m.eye_u) + mH * 0.03
	var gap := maxf(mW * 0.36, float(m.eye_gap) * 1.1)
	for sx: float in [-1.0, 1.0]:
		var x := lc + sx * gap / 2.0
		var zz := fc + rz * sqrt(maxf(0.05, 1.0 - pow(x - lc, 2.0) / (rx * rx) - pow(ey - cy, 2.0) / (ry * ry))) - 0.004
		var eye := MsKit.part(M_.fit, MsKit.sphere(1.0, 16, 10), _black, Vector3(x, ey, zz))
		eye.scale = Vector3(mW * 0.2, mH * 0.11, mD * 0.06)
		eye.rotation.z = sx * -0.35
		var pin := MsKit.part(M_.fit, MsKit.disc(mW * 0.025, 10), _white, Vector3(x - sx * mW * 0.03, ey - mH * 0.01, zz + mD * 0.06 + 0.002), false)
		pin.rotation.x = PI / 2.0
	# coat-hanger antennae with foil balls
	for sx: float in [-1.0, 1.0]:
		var base := Vector3(lc + sx * rx * 0.35, cy + ry * 0.86, fc - rz * 0.1)
		var pts := PackedVector3Array([base, base + Vector3(sx * 0.03, 0.08, 0.01), base + Vector3(sx * 0.09, 0.15, -0.02), base + Vector3(sx * 0.07, 0.24, 0.0)])
		MsKit.part(M_.fit, MsKit.tube(pts, 0.0045), _wire)
		MsKit.part(M_.fit, MsKit.sphere(0.03, 6, 4), _foil, pts[3])
	# the price tag, on a string off the left side
	var tp := Node3D.new()
	tp.position = Vector3(lc + rx * 0.98, cy + ry * 0.1, fc)
	M_.fit.add_child(tp)
	M_.tag_pivot = tp
	MsKit.part(tp, MsKit.cyl(0.0015, 0.0015, 0.06, 3), _white, Vector3(0.0, -0.03, 0.0), false)
	var tag_m := QuadMesh.new()
	tag_m.size = Vector2(0.075, 0.038)
	var tag := MsKit.part(tp, tag_m, _paper, Vector3(0.012, -0.075, 0.0), false)
	tag.rotation.y = PI / 2.0
	var price := Label3D.new()
	price.text = "$4.99"
	price.font_size = 32
	price.pixel_size = 0.0007
	price.modulate = Color(0.13, 0.13, 0.13)
	price.outline_size = 0
	price.position = Vector3(0.0, 0.0, 0.001)
	price.double_sided = true
	tag.add_child(price)
	return M_


static func _pct(a: PackedFloat32Array, p: float) -> float:
	var s := a.duplicate()
	s.sort()
	return s[int(clampf(p, 0.0, 1.0) * (s.size() - 1))]


## JS measureHead: every vertex skinned mostly to the head or anything under it, relative to the head bone: forward, up and left percentiles, and the eye whites' centre.
static func measure_head(an: Animator) -> Dictionary:
	var sk := an.skel
	var rec: Variant = an.by_key.get(&"head")
	var under: Dictionary = {rec.bone: true}
	for i in sk.get_bone_count():
		var p := sk.get_bone_parent(i)
		if under.has(p):
			under[i] = true
	var scale_ := sk.global_basis.get_scale().x
	var c0: Vector3 = sk.get_bone_global_rest(rec.bone).origin
	var F := PackedFloat32Array()
	var Uu := PackedFloat32Array()
	var Lf := PackedFloat32Array()
	var eye_l: Array[Vector3] = []
	var eye_r: Array[Vector3] = []
	var walk: Array[Node] = [an.actor]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if not n is MeshInstance3D or not (n as MeshInstance3D).is_visible_in_tree():
			continue
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.skin == null:
			continue
		var bone_of: Dictionary = {}
		for b in mi.skin.get_bind_count():
			bone_of[b] = mi.skin.get_bind_bone(b) if mi.skin.get_bind_bone(b) >= 0 else sk.find_bone(mi.skin.get_bind_name(b))
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var BI: Variant = arr[Mesh.ARRAY_BONES]
			var BW: Variant = arr[Mesh.ARRAY_WEIGHTS]
			if BI == null or BW == null or (BI as PackedInt32Array).is_empty():
				continue
			var per: int = (BI as PackedInt32Array).size() / V.size()
			var mat := mi.get_active_material(s)
			var is_eye := mat != null and mat.resource_name.contains("eye_white")
			for i in V.size():
				var best := -1
				var bw := 0.0
				for j in per:
					var w: float = BW[i * per + j]
					if w > bw:
						bw = w
						best = BI[i * per + j]
				if not under.has(bone_of.get(best, -1)):
					continue
				var v: Vector3 = (V[i] - c0) * scale_
				F.append(v.z)
				Uu.append(v.y)
				Lf.append(v.x)
				if is_eye:
					if v.x > 0.0:
						eye_l.append(v)
					else:
						eye_r.append(v)
	if F.size() < 20:
		return {}
	var m := {"fMin": _pct(F, 0.03), "fMax": _pct(F, 0.97), "uMin": _pct(Uu, 0.02), "uMax": _pct(Uu, 0.99), "lMin": _pct(Lf, 0.03), "lMax": _pct(Lf, 0.97)}
	m["W"] = float(m.lMax) - float(m.lMin)
	m["H"] = float(m.uMax) - float(m.uMin)
	m["D"] = float(m.fMax) - float(m.fMin)
	m["lc"] = (float(m.lMin) + float(m.lMax)) / 2.0
	m["fc"] = (float(m.fMin) + float(m.fMax)) / 2.0
	m["eye_u"] = (float(m.uMin) + float(m.uMax)) / 2.0 - float(m.H) * 0.05
	m["eye_gap"] = 0.0
	if not eye_l.is_empty() and not eye_r.is_empty():
		var a := AABB(eye_l[0], Vector3.ZERO)
		for p: Vector3 in eye_l:
			a = a.expand(p)
		var b := AABB(eye_r[0], Vector3.ZERO)
		for p: Vector3 in eye_r:
			b = b.expand(p)
		m["eye_u"] = ((a.get_center().y + b.get_center().y) / 2.0)
		m["eye_gap"] = absf(a.get_center().x - b.get_center().x)
	return m


## put it on (the game's Animator). Safe to call every frame: only builds once per wear.
func wear(an: Animator, char_id: String) -> void:
	if worn != null or an == null or an.skel == null:
		return
	var rec: Variant = an.by_key.get(&"head")
	if rec == null or rec.bone < 0:
		return
	var m := measure_head(an)
	if m.is_empty():
		return
	worn = _build(char_id == "tommy", m)
	_attach = BoneAttachment3D.new()
	_attach.bone_idx = rec.bone
	an.skel.add_child(_attach)
	_attach.add_child(worn.root)
	# the body's facing frame, turned with the head: the head's world rotation without its rest rotation (with the head turned or tilted the mask still lines up with the face)
	var q: Quaternion = an.bone_world_quat(rec.bone) * (rec.rest_w as Quaternion).inverse()
	worn.root.global_transform = Transform3D(Basis(q), an.bone_world_pos(rec.bone))


## knock it off (into the level) with a flick; it bounces and lies there
func knock_off(parent: Node3D) -> void:
	if worn == null:
		return
	var w := worn
	worn = null
	var gt := w.root.global_transform
	w.root.get_parent().remove_child(w.root)
	parent.add_child(w.root)
	w.root.global_transform = gt
	_free_attach()
	w.vx = (randf() - 0.5) * 2.0
	w.vy = 4.2
	w.vz = 2.5
	w.spin = 9.0
	loose = w


func _free_attach() -> void:
	if _attach != null and is_instance_valid(_attach):
		_attach.queue_free()
	_attach = null


## take it off for good
func remove() -> void:
	for w: Mask in [worn, loose]:
		if w != null and is_instance_valid(w.root):
			w.root.queue_free()
	_free_attach()
	worn = null
	loose = null


func update(dt: float, ground: Callable) -> void:
	if worn != null:
		worn.t += dt
		worn.tag_pivot.rotation.z = sin(worn.t * 3.1) * 0.35
		worn.tag_pivot.rotation.x = sin(worn.t * 2.3) * 0.2
		if worn.tommy:
			worn.fit.rotation.z = sin(worn.t * 5.3) * 0.05
			worn.fit.position.y = absf(sin(worn.t * 6.0)) * 0.01
	if loose != null:
		var l := loose
		var r := l.root
		l.vy -= 18.0 * dt
		r.position += Vector3(l.vx, l.vy, l.vz) * dt
		r.rotation.x += l.spin * dt
		r.rotation.z += l.spin * 0.4 * dt
		var gy: float = ground.call(r.position.x, r.position.z, r.position.y)
		if r.position.y < gy + 0.12 and l.vy < 0.0:
			r.position.y = gy + 0.12
			l.vy = -l.vy * 0.4
			l.vx *= 0.6
			l.vz *= 0.6
			l.spin *= 0.5
			if absf(l.vy) < 0.6:
				l.vy = 0.0
				l.spin = 0.0
				l.vx = 0.0
				l.vz = 0.0
