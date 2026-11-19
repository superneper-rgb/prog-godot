## Writes the "Prog" object built by head_swap.py (in Blender, glb space) back into a glb, keeping V1's skeleton exactly as it was (no trip through
## Blender's glTF exporter, which turns the bones): the nodes, skin and every existing bone's rest are copied from prog.glb; a "jaw" bone is added under
## "head" (world-aligned, at JAW_PIVOT); the mesh is written flat shaded, one primitive per surface, 4 weights per vertex. V3's texture coordinates
## ride along as TEXCOORD_1 (the bake carries V3's painted face over from them; write_glb.py drops them again).
##   in Blender: glb_out.write(bpy.data.objects["Prog"], "assets/prog.glb", "F:/prog-godot-cache/prog_paint/prog_head.glb")
import json, os, struct, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from prog_mesh import read_glb, acc

JAW_PIVOT = (0.0, 1.658, 0.005)          # V3's jaw hinge, moved back with its head
NEW_COLORS = {"bk_mouth": [0.35, 0.06, 0.06, 1.0], "bk_teeth": [0.85, 0.82, 0.72, 1.0], "bk_tongue": [0.6, 0.15, 0.15, 1.0]}


def _node_world(j, idx, parent_of):
	m = np.eye(4)
	chain = []
	while idx is not None:
		chain.append(idx)
		idx = parent_of.get(idx)
	for i in reversed(chain):
		m = m @ _trs(j["nodes"][i])
	return m


def _trs(n):
	if "matrix" in n:
		return np.array(n["matrix"], np.float64).reshape(4, 4).T
	t = n.get("translation", [0, 0, 0])
	x, y, z, w = n.get("rotation", [0, 0, 0, 1])
	s = n.get("scale", [1, 1, 1])
	r = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
		[2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
		[2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
	m = np.eye(4)
	m[:3, :3] = r * np.array(s)
	m[:3, 3] = t
	return m


def _quat(r):
	## rotation matrix -> glTF quaternion (x, y, z, w)
	t = np.trace(r)
	if t > 0:
		s = np.sqrt(t + 1.0) * 2
		return [(r[2, 1] - r[1, 2]) / s, (r[0, 2] - r[2, 0]) / s, (r[1, 0] - r[0, 1]) / s, 0.25 * s]
	i = int(np.argmax([r[0, 0], r[1, 1], r[2, 2]]))
	if i == 0:
		s = np.sqrt(1.0 + r[0, 0] - r[1, 1] - r[2, 2]) * 2
		return [0.25 * s, (r[0, 1] + r[1, 0]) / s, (r[0, 2] + r[2, 0]) / s, (r[2, 1] - r[1, 2]) / s]
	if i == 1:
		s = np.sqrt(1.0 + r[1, 1] - r[0, 0] - r[2, 2]) * 2
		return [(r[0, 1] + r[1, 0]) / s, 0.25 * s, (r[1, 2] + r[2, 1]) / s, (r[0, 2] - r[2, 0]) / s]
	s = np.sqrt(1.0 + r[2, 2] - r[0, 0] - r[1, 1]) * 2
	return [(r[0, 2] + r[2, 0]) / s, (r[1, 2] + r[2, 1]) / s, 0.25 * s, (r[1, 0] - r[0, 1]) / s]


def write(ob, v1_glb, out_path):
	import bpy
	j, B = read_glb(v1_glb)
	sk = j["skins"][0]
	if any(j["nodes"][n]["name"] == "jaw" for n in sk["joints"]):
		raise RuntimeError("this file already has a jaw: write from the original V1 file")
	jn = [j["nodes"][n]["name"] for n in sk["joints"]] + ["jaw"]
	parent_of = {c: i for i, n in enumerate(j["nodes"]) for c in n.get("children", [])}
	head = next(i for i, n in enumerate(j["nodes"]) if n["name"] == "head")
	# the jaw bone: world-aligned at the pivot, under the head
	hw = _node_world(j, head, parent_of)
	jw = np.eye(4)
	jw[:3, 3] = JAW_PIVOT
	local = np.linalg.inv(hw) @ jw
	jaw_node = {"name": "jaw", "translation": local[:3, 3].tolist()}
	rq = _quat(local[:3, :3])
	if abs(rq[3]) < 0.999999:
		jaw_node["rotation"] = rq
	j["nodes"].append(jaw_node)
	jaw_idx = len(j["nodes"]) - 1
	j["nodes"][head].setdefault("children", []).append(jaw_idx)
	# the mesh node's own transform (the skin's bind space): the jaw's inverse bind is taken in that space, as the others are
	mesh_node = next(i for i, n in enumerate(j["nodes"]) if n.get("skin") == 0)
	ibm_old = acc(j, B, sk["inverseBindMatrices"]).reshape(-1, 4, 4)
	jaw_ibm = np.linalg.inv(jw).T.astype(np.float32)          # (glTF matrices are column-major)
	ibm = np.concatenate([ibm_old, jaw_ibm[None]], 0)
	sk["joints"].append(jaw_idx)

	# ---- mesh: flat shaded, per surface
	me = ob.data
	me.calc_loop_triangles()
	gname = {g.index: g.name for g in ob.vertex_groups}
	vw = []
	for v in me.vertices:
		ws = sorted(((g.weight, gname[g.group]) for g in v.groups if g.weight > 1e-4), reverse=True)[:4]
		tot = sum(w for w, _ in ws) or 1.0
		jj = [jn.index(n) for _, n in ws] + [0] * (4 - len(ws))
		ww = [w / tot for w, _ in ws] + [0.0] * (4 - len(ws))
		vw.append((jj, ww))
	src = me.uv_layers.get("src")
	surf = [m.name[2:] if m.name.startswith("P_") else m.name for m in me.materials]
	by_surf = {}
	for t in me.loop_triangles:
		by_surf.setdefault(t.material_index, []).append(t)
	mats_old = {m["name"]: m for m in j["materials"]}
	new_mats, prims = [], []
	accs, views, chunks = [], [], []
	blen = [0]

	def put(arr, kind, target=None):
		arr = np.ascontiguousarray(arr)
		data = arr.tobytes()
		pad = (-blen[0]) % 4
		if pad:
			chunks.append(b"\0" * pad)
			blen[0] += pad
		v = {"buffer": 0, "byteOffset": blen[0], "byteLength": len(data)}
		if target:
			v["target"] = target
		views.append(v)
		chunks.append(data)
		blen[0] += len(data)
		ct = {np.dtype(np.float32): 5126, np.dtype(np.uint8): 5121, np.dtype(np.uint16): 5123, np.dtype(np.uint32): 5125}[arr.dtype]
		a = {"bufferView": len(views) - 1, "componentType": ct, "count": int(arr.shape[0]), "type": kind}
		if kind == "VEC3" and arr.dtype == np.float32:
			a["min"] = arr.min(0).tolist()
			a["max"] = arr.max(0).tolist()
		accs.append(a)
		return len(accs) - 1

	# smooth normals for the head and neck skin, by position (the V3 neck and V1's ring are separate vertices at the same places: by position, no seam)
	from prog_mesh import smooth_skin
	acc_n = {}
	def key(co):
		return (round(co.x, 4), round(co.y, 4), round(co.z, 4))
	smooth_tri = set()
	for t in me.loop_triangles:
		nm = surf[t.material_index]
		c = sum((me.vertices[v].co for v in t.vertices), me.vertices[t.vertices[0]].co * 0.0) / 3.0
		if smooth_skin(nm, (c.x, c.y, c.z)):
			smooth_tri.add(t.index)
			for v in t.vertices:
				k = key(me.vertices[v].co)
				acc_n[k] = acc_n.get(k, t.normal * 0.0) + t.normal * t.area
	for mi in sorted(by_surf):
		tris = by_surf[mi]
		name = surf[mi]
		n = len(tris) * 3
		P = np.zeros((n, 3), np.float32)
		Nn = np.zeros((n, 3), np.float32)
		JJ = np.zeros((n, 4), np.uint8)
		WW = np.zeros((n, 4), np.float32)
		UV = np.full((n, 2), -1.0, np.float32)
		for k, t in enumerate(tris):
			fn = t.normal
			for c in range(3):
				vi = t.vertices[c]
				P[k * 3 + c] = me.vertices[vi].co
				Nn[k * 3 + c] = acc_n[key(me.vertices[vi].co)].normalized() if t.index in smooth_tri else fn
				JJ[k * 3 + c], WW[k * 3 + c] = vw[vi]
				if src is not None:
					u = src.data[t.loops[c]].uv
					if u.x != 0.0 or u.y != 0.0:
						UV[k * 3 + c] = (u.x, 1.0 - u.y)
		if name in mats_old:
			m = json.loads(json.dumps(mats_old[name]))
		else:
			m = {"name": name, "doubleSided": True, "pbrMetallicRoughness": {"baseColorFactor": NEW_COLORS.get(name, [1, 1, 1, 1]), "metallicFactor": 0}}
		new_mats.append(m)
		attrs = {"POSITION": put(P, "VEC3", 34962), "NORMAL": put(Nn, "VEC3", 34962), "JOINTS_0": put(JJ, "VEC4", 34962), "WEIGHTS_0": put(WW, "VEC4", 34962)}
		if (UV[:, 0] >= 0.0).any():
			attrs["TEXCOORD_1"] = put(UV, "VEC2", 34962)
		idx = np.arange(n, dtype=np.uint16 if n < 65535 else np.uint32)
		prims.append({"attributes": attrs, "indices": put(idx, "SCALAR", 34963), "material": len(new_mats) - 1})
	sk["inverseBindMatrices"] = put(ibm.astype(np.float32).reshape(-1, 16), "MAT4")
	j["materials"] = new_mats
	j["meshes"][0]["primitives"] = prims
	j["accessors"] = accs
	j["bufferViews"] = views
	for k in ("images", "textures", "samplers"):
		j.pop(k, None)
	binb = b"".join(chunks)
	binb += b"\0" * ((-len(binb)) % 4)
	j["buffers"] = [{"byteLength": len(binb)}]
	js = json.dumps(j, separators=(",", ":")).encode()
	js += b" " * ((-len(js)) % 4)
	out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(binb))
	out += struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(binb), 0x004E4942) + binb
	os.makedirs(os.path.dirname(out_path), exist_ok=True)
	open(out_path, "wb").write(out)
	return {"bytes": len(out), "surfaces": [p["material"] for p in prims], "names": [m["name"] for m in new_mats], "jaw_local": jaw_node}
