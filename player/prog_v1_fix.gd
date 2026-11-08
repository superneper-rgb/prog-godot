## Prog V1's mesh fixes at load (JS _reskinWaist, _matchShorts, _meldStraps, _reshapeNose, on the build's skinFix): waist weights, shorts on the skin, straps on the shirt, the nose. Only the old prog.glb needs them.
class_name ProgV1Fix
extends RefCounted


static func _sst(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func apply(src: Mesh, skin: Skin) -> ArrayMesh:
	var names: Array[String] = []
	if skin != null:
		for i in skin.get_bind_count():
			names.append(Animator.san(String(skin.get_bind_name(i))))
	var surf: Array = []
	var by_name: Dictionary = {}
	for s in src.get_surface_count():
		var a: Array = src.surface_get_arrays(s)
		surf.append(a)
		var m := src.surface_get_material(s)
		if m != null:
			by_name[m.resource_name] = a
	if not names.is_empty():
		for a: Array in surf:
			_reskin_waist(a, names)
		_match_shorts(by_name, names)
		_meld_straps(by_name, names)
	if by_name.has("bk_nose"):
		_reshape_nose(by_name["bk_nose"])
	for a: Array in surf:
		_weld_weights(a)
	var out := ArrayMesh.new()
	for s in surf.size():
		var a: Array = surf[s]
		var flags := 0
		if (a[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array).size() == (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() * 8:
			flags = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), a, [], {}, flags)
		out.surface_set_material(s, src.surface_get_material(s))
	return out


## Not in the JS. The mesh is flat shaded, each face with its own copy of a corner, and those copies can carry different bone weights: bent hard, a joint's faces pull apart and it tears. Every copy of a corner now shares one set of weights.
static func _weld_weights(a: Array) -> void:
	var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var si: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var sw: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	if si.is_empty() or sw.is_empty():
		return
	var st := si.size() / pos.size()
	var groups: Dictionary = {}
	for v in pos.size():
		var key := Vector3i((pos[v] * 2000.0).round())
		if not groups.has(key):
			groups[key] = PackedInt32Array()
		groups[key].append(v)
	for key: Vector3i in groups:
		var g: PackedInt32Array = groups[key]
		if g.size() < 2:
			continue
		var sum: Dictionary = {}
		for v in g:
			for c in st:
				if sw[v * st + c] > 0.0:
					sum[si[v * st + c]] = sum.get(si[v * st + c], 0.0) + sw[v * st + c]
		var order: Array = sum.keys()
		order.sort_custom(func(x: int, y: int) -> bool: return sum[x] > sum[y])
		order = order.slice(0, mini(4, st))
		var total := 0.0
		for b: int in order:
			total += float(sum[b])
		for v in g:
			for c in st:
				if c < order.size():
					si[v * st + c] = order[c]
					sw[v * st + c] = float(sum[order[c]]) / total
				else:
					si[v * st + c] = 0
					sw[v * st + c] = 0.0
	a[Mesh.ARRAY_BONES] = si
	a[Mesh.ARRAY_WEIGHTS] = sw


static func _reskin_waist(a: Array, names: Array[String]) -> void:
	var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var si: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var sw: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	if si.is_empty() or sw.is_empty():
		return
	var st := si.size() / pos.size()
	var ch_i: Array[int] = [names.find("pelvis"), names.find("spine1"), names.find("spine2"), names.find("chest")]
	var ch_y: Array[float] = [0.84, 0.97, 1.13, 1.29]
	if ch_i.has(-1):
		return
	var th_l := names.find("thighL")
	var th_r := names.find("thighR")
	# pass 1: hips. Move thigh weight to pelvis from upper-thigh height upward.
	for v in pos.size():
		var y := pos[v].y
		if y < 0.70 or y > 1.1 or absf(pos[v].x) > 0.5:
			continue
		var f := minf(1.0, (y - 0.70) / 0.24)
		var k := f * f * (3.0 - 2.0 * f) * 0.85
		var moved := 0.0
		var pel_slot := -1
		for c in st:
			var idx := si[v * st + c]
			var w := sw[v * st + c]
			if (idx == th_l or idx == th_r) and w > 0.0:
				sw[v * st + c] = w * (1.0 - k)
				moved += w * k
			if idx == ch_i[0] and w > 0.0:
				pel_slot = c
		if moved <= 0.0:
			continue
		if pel_slot < 0:           # find a free / weakest non-thigh slot
			var best := -1
			var bw := 9.0
			for c in st:
				if sw[v * st + c] < bw:
					bw = sw[v * st + c]
					best = c
			si[v * st + best] = ch_i[0]
			sw[v * st + best] = moved
		else:
			sw[v * st + pel_slot] += moved
	for v in pos.size():
		var y := pos[v].y
		if y < 0.78 or y > 1.34:
			continue
		var others: Array = []
		var wt := 0.0
		for k in st:
			var w := sw[v * st + k]
			if w <= 0.0:
				continue
			var idx := si[v * st + k]
			if ch_i.has(idx):
				wt += w
			else:
				others.append([idx, w])
		if wt < 0.5:
			continue
		var ia := 0
		var ib := 0
		var t := 0.0
		if y >= ch_y[3]:
			ia = 3
			ib = 3
		elif y > ch_y[0]:
			for c in 3:
				if y <= ch_y[c + 1]:
					ia = c
					ib = c + 1
					t = (y - ch_y[c]) / (ch_y[c + 1] - ch_y[c])
					break
		t = t * t * (3.0 - 2.0 * t)
		var merged: Array = others.duplicate()
		if wt * (1.0 - t) > 1e-4:
			merged.append([ch_i[ia], wt * (1.0 - t)])
		if wt * t > 1e-4:
			merged.append([ch_i[ib], wt * t])
		merged.sort_custom(func(p: Array, q: Array) -> bool: return p[1] > q[1])
		merged = merged.slice(0, 4)
		var total := 0.0
		for e: Array in merged:
			total += float(e[1])
		for k in st:
			if k < merged.size():
				si[v * st + k] = merged[k][0]
				sw[v * st + k] = float(merged[k][1]) / total
			else:
				si[v * st + k] = 0
				sw[v * st + k] = 0.0
	a[Mesh.ARRAY_BONES] = si
	a[Mesh.ARRAY_WEIGHTS] = sw


## Tank-top straps were skinned half to the neck/head while the shirt body follows the chest, so they drifted off the shirt when he turned his head or leaned. Pull neck influence out of the
## shirt's upper ring and give every strap vertex the skin weights of the nearest vertex on that ring, so straps and shirt move as one piece.
static func _meld_straps(by_name: Dictionary, names: Array[String]) -> void:
	if not by_name.has("bk_tank"):
		return
	var a: Array = by_name["bk_tank"]
	var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var si: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var sw: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var chest := names.find("chest")
	var neck := names.find("neck")
	if chest < 0 or neck < 0 or si.is_empty():
		return
	var st := si.size() / pos.size()
	var ring: Array[int] = []
	var strap: Array[int] = []
	for v in pos.size():
		var q := pos[v]
		if q.y < 1.27:
			continue
		# move neck weight into the chest slot (add to existing chest weight, else reuse the neck slot)
		var nw := 0.0
		var cs := -1
		var ns := -1
		for c in st:
			var i := si[v * st + c]
			var w := sw[v * st + c]
			if i == neck and w > 0.0:
				nw += w
				ns = c
			if i == chest and w > 0.0:
				cs = c
		if nw > 0.0:
			if cs >= 0:
				sw[v * st + cs] += nw
				sw[v * st + ns] = 0.0
			else:
				si[v * st + ns] = chest
		var ell := pow(q.x / 0.31, 2.0) + pow(q.z / 0.29, 2.0)
		if q.y > 1.34 and absf(q.x) > 0.12 and ell < 0.92:
			strap.append(v)
		elif q.y > 1.28:
			ring.append(v)
	for v in strap:
		var best := -1
		var bd := 1e9
		var q := pos[v]
		for r in ring:
			var e := pos[r] - q
			var d := e.x * e.x + e.y * e.y * 0.5 + e.z * e.z
			if d < bd:
				bd = d
				best = r
		if best < 0:
			continue
		for c in st:
			si[v * st + c] = si[best * st + c]
			sw[v * st + c] = sw[best * st + c]
	# back straps hover above the shirt's top edge: drop their lower ends down onto the shirt surface so they join it
	for v in pos.size():
		var q := pos[v]
		var x := absf(q.x)
		if q.z < 0.0 and q.y > 1.35 and q.y < 1.37 and x > 0.12 and x < 0.23:
			var zs := -0.206 + (x - 0.135) / 0.07 * 0.056
			pos[v] = Vector3(q.x, 1.295, zs + (-0.012 if q.z < -0.165 else 0.006))
	a[Mesh.ARRAY_VERTEX] = pos
	a[Mesh.ARRAY_BONES] = si
	a[Mesh.ARRAY_WEIGHTS] = sw


## Make the shorts follow the skin underneath exactly (copy skin weights from the nearest skin vertex) and push the cloth out a hair, so the thigh never pokes through while the legs swing.
static func _match_shorts(by_name: Dictionary, names: Array[String]) -> void:
	if not by_name.has("bk_skin"):
		return
	var sk: Array = by_name["bk_skin"]
	var sp: PackedVector3Array = sk[Mesh.ARRAY_VERTEX]
	var ss: PackedInt32Array = sk[Mesh.ARRAY_BONES]
	var sww: PackedFloat32Array = sk[Mesh.ARRAY_WEIGHTS]
	var st0 := ss.size() / sp.size()
	var cand: Array[int] = []
	# body skin only: his arms hang beside the hips, so without the bone test the waistband copied the arm's weights and stretched to the hands whenever the arms moved
	for i in sp.size():
		var q := sp[i]
		if q.y <= 0.45 or q.y >= 1.2 or absf(q.x) >= 0.5:
			continue
		var b := 0
		var bw := -1.0
		for k in st0:
			if sww[i * st0 + k] > bw:
				bw = sww[i * st0 + k]
				b = ss[i * st0 + k]
		var nm := names[b] if b < names.size() else ""
		if nm.begins_with("pelvis") or nm.begins_with("spine") or nm.begins_with("thigh") or nm.begins_with("shin") or nm.begins_with("foot") or nm.begins_with("toe"):
			cand.append(i)
	for key: String in ["bk_shorts", "bk_shorts_fray"]:
		if not by_name.has(key):
			continue
		var a: Array = by_name[key]
		var p: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var si: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var sw: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var st := si.size() / p.size()
		for v in p.size():
			var q := p[v]
			var best := -1
			var bd := 1e9
			for i in cand:
				var d := sp[i].distance_squared_to(q)
				if d < bd:
					bd = d
					best = i
			if best < 0:
				continue
			for k in mini(st, st0):
				si[v * st + k] = ss[best * st0 + k]
				sw[v * st + k] = sww[best * st0 + k]
			# push outward from the leg axis by position only, so coincident (flat-shaded) vertices move together: no seams
			var cx := 0.13 if q.x >= 0.0 else -0.13
			var dx := q.x - cx
			var dz := q.z
			var l := sqrt(dx * dx + dz * dz)
			if l == 0.0:
				l = 1.0
			var f := 0.014 * clampf((0.97 - q.y) / 0.12, 0.0, 1.0)
			p[v] = Vector3(q.x + dx / l * f, q.y, q.z + dz / l * f)
		a[Mesh.ARRAY_VERTEX] = p
		a[Mesh.ARRAY_BONES] = si
		a[Mesh.ARRAY_WEIGHTS] = sw


static func _reshape_nose(a: Array) -> void:
	var pa: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	const Y0 := 1.627
	const H := 0.103
	const Z0 := 0.11
	const DZ := 0.078
	const HW := 0.03
	const HWN := 0.036
	const TIP := DZ * 1.25
	const UT := 0.34
	for i in pa.size():
		var q := pa[i]
		var u := clampf((q.y - Y0) / H, 0.0, 1.0)
		var d := clampf((q.z - Z0) / DZ, 0.0, 1.0)
		var av := minf(1.0, absf(q.x) / HW)
		var prof := (1.0 - u) / (1.0 - UT) if u >= UT else 0.4 + 0.6 * (u / UT)      # straight bridge slope down to the tip, steep underside
		var nx := signf(q.x) * av * HWN * (0.7 + 0.3 * (1.0 - u))                      # narrower at the bridge, widest at the nostrils
		var dz := lerpf(d * DZ, prof * (1.0 - av) * TIP, _sst(0.3, 0.7, d))            # front surface becomes the triangle; the buried back is left alone
		pa[i] = Vector3(nx, q.y, Z0 + dz)
	a[Mesh.ARRAY_VERTEX] = pa
	# JS computeVertexNormals
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var nr := PackedVector3Array()
	nr.resize(pa.size())
	var tri := idx.size() / 3 if not idx.is_empty() else pa.size() / 3
	for t in tri:
		var i0 := idx[t * 3] if not idx.is_empty() else t * 3
		var i1 := idx[t * 3 + 1] if not idx.is_empty() else t * 3 + 1
		var i2 := idx[t * 3 + 2] if not idx.is_empty() else t * 3 + 2
		var n := (pa[i2] - pa[i0]).cross(pa[i1] - pa[i0])      # (Godot winds its triangles the other way round from glTF)
		nr[i0] += n
		nr[i1] += n
		nr[i2] += n
	for i in nr.size():
		nr[i] = nr[i].normalized()
	a[Mesh.ARRAY_NORMAL] = nr
