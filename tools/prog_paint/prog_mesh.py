## Prog's model as plain arrays, shared by the paint tools (bake.py, paint.py, write_glb.py) and a live Blender session: the glb read straight from its own
## vertex and index arrays (never through Blender's glTF importer, which turns the bones), welded per surface so the UV unwrap sees connected faces.
import json, struct, math
import numpy as np

# surfaces that take the painted texture (all of them since the new head: the eyes are textured spheres)
PAINTED = ["bk_skin", "bk_skin_dark", "bk_tank", "bk_shorts", "bk_shorts_fray", "bk_boot", "bk_sole", "bk_hair", "bk_lace",
	"bk_eye_white", "bk_mouth", "bk_teeth", "bk_tongue"]
# never shrunk as hidden in the UV layout: the inside of the mouth is seen whenever he talks, the eyes when the lids open
NEVER_HIDDEN = ["bk_eye_white", "bk_mouth", "bk_teeth", "bk_tongue"]


def read_glb(path):
	b = open(path, "rb").read()
	n = struct.unpack("<I", b[12:16])[0]
	j = json.loads(b[20:20 + n])
	B = b[20 + n + 8:]
	return j, B


def acc(j, B, i):
	a = j["accessors"][i]
	v = j["bufferViews"][a["bufferView"]]
	n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
	dt = {5126: np.float32, 5121: np.uint8, 5123: np.uint16, 5125: np.uint32}[a["componentType"]]
	off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
	stride = v.get("byteStride", 0)
	isz = np.dtype(dt).itemsize * n
	if stride and stride != isz:
		raw = np.frombuffer(B, dtype=np.uint8, count=stride * (a["count"] - 1) + isz, offset=off)
		rows = np.stack([raw[k * stride:k * stride + isz] for k in range(a["count"])])
		out = rows.view(dt).reshape(a["count"], n)
	else:
		out = np.frombuffer(B, dtype=dt, count=a["count"] * n, offset=off).reshape(a["count"], n)
	if a.get("normalized") and dt != np.float32:
		out = out.astype(np.float32) / np.iinfo(dt).max
	return out.copy() if n > 1 else out.reshape(-1).copy()


def reshape_nose(p):
	## the same nose ProgV1Fix._reshape_nose makes at load, so the paint lands on the nose the game shows
	Y0, H, Z0, DZ, HW, HWN = 1.627, 0.103, 0.11, 0.078, 0.03, 0.036
	TIP, UT = DZ * 1.25, 0.34
	out = p.copy()
	for i, q in enumerate(p):
		u = min(max((q[1] - Y0) / H, 0.0), 1.0)
		d = min(max((q[2] - Z0) / DZ, 0.0), 1.0)
		av = min(1.0, abs(q[0]) / HW)
		prof = (1.0 - u) / (1.0 - UT) if u >= UT else 0.4 + 0.6 * (u / UT)
		nx = math.copysign(1.0, q[0]) * av * HWN * (0.7 + 0.3 * (1.0 - u)) if q[0] != 0.0 else 0.0
		t = min(max((d - 0.3) / 0.4, 0.0), 1.0)
		t = t * t * (3.0 - 2.0 * t)
		dz = d * DZ + (prof * (1.0 - av) * TIP - d * DZ) * t
		out[i] = (nx, q[1], Z0 + dz)
	return out


def smooth_skin(name, c):
	## the head and neck skin are shaded smooth (V3's head is dense, and its neck slivers showed as dark facets and streaks, user 2026-11-15); the rest of
	## him stays faceted, except what he wears (user, 2026-11-16): the jorts' folds read as crumpled paper faceted, the ribbed tank (tank.py) is a dense
	## grid that only reads as knit smooth, and so are the boots' leather and laces (boots.py; their sole stays crisp). c: the face's centre in glb space.
	return (name == "bk_skin" and c[1] > 1.47 and abs(c[0]) < 0.17) or name in ("bk_shorts", "bk_tank", "bk_boot", "bk_lace")


SRC_UV = "TEXCOORD_1"      # colours carried over from an older texture (V3's head) ride on this set of texture coordinates


class Model:
	## prims: per surface {name, P, C, I}; verts/faces: the welded mesh; face_src[f] = (surface, triangle); sid[f] = surface; vcol_pt = smooth vertex colour
	def __init__(self, glb):
		j, B = read_glb(glb)
		self.gltf = j
		self.prims = []
		for p in j["meshes"][0]["primitives"]:
			name = j["materials"][p["material"]]["name"]
			at = p["attributes"]
			P = acc(j, B, at["POSITION"])
			col_key = "COLOR_0" if "COLOR_0" in at else ("_VCOL" if "_VCOL" in at else None)
			C = acc(j, B, at[col_key])[:, :3] if col_key else np.ones((len(P), 3), np.float32)
			I = acc(j, B, p["indices"]).astype(np.int64).reshape(-1, 3)
			S = acc(j, B, at[SRC_UV]) if SRC_UV in at else np.full((len(P), 2), -1.0, np.float32)
			if name == "bk_nose":
				P = reshape_nose(P)
			self.prims.append({"name": name, "P": P, "C": C, "I": I, "S": S})
		self.verts, self.faces, self.face_src, self.sid, vcol = [], [], [], [], []
		for si, pr in enumerate(self.prims):
			key = np.round(pr["P"] * 20000.0).astype(np.int64)
			uniq, inv = np.unique(key, axis=0, return_inverse=True)
			inv = inv.reshape(-1)
			first = np.full(len(uniq), -1, np.int64)
			for vi in range(len(inv) - 1, -1, -1):
				first[inv[vi]] = vi
			base = len(self.verts)
			self.verts.extend(pr["P"][first].tolist())
			acc_c = np.zeros((len(uniq), 3))
			cnt = np.zeros(len(uniq))
			np.add.at(acc_c, inv, pr["C"])
			np.add.at(cnt, inv, 1)
			vcol.extend((acc_c / cnt[:, None]).tolist())
			for t, tri in enumerate(pr["I"]):
				w = [base + int(inv[k]) for k in tri]
				if len(set(w)) < 3:
					continue          # degenerate after the weld: never drawn, gets no paint
				self.faces.append(w)
				self.face_src.append((si, t))
				self.sid.append(si)
		self.vcol_pt = np.array(vcol, np.float32)

	def painted_ids(self):
		return {i for i, pr in enumerate(self.prims) if pr["name"] in PAINTED}

	def make_object(self, name="prog", uv_npz=None):
		## the welded mesh as a Blender object (glb space: Y up), with the surface id, the smooth vertex colour and, given uv.npz, the baked UV layout
		import bpy
		me = bpy.data.meshes.new(name)
		me.from_pydata(self.verts, [], self.faces)
		me.update()
		ob = bpy.data.objects.new(name, me)
		bpy.context.scene.collection.objects.link(ob)
		fa = me.attributes.new("sid", "FLOAT", "FACE")
		fa.data.foreach_set("value", np.array(self.sid, np.float32))
		cp = me.color_attributes.new("vsmooth", "FLOAT_COLOR", "POINT")
		vc = np.ones((len(self.verts), 4), np.float32)
		vc[:, :3] = self.vcol_pt
		cp.data.foreach_set("color", vc.reshape(-1))
		sm = np.zeros(len(self.faces), bool)
		V = np.array(self.verts, np.float32)
		for fi, f in enumerate(self.faces):
			sm[fi] = smooth_skin(self.prims[self.sid[fi]]["name"], V[f].mean(0))
		me.polygons.foreach_set("use_smooth", sm)
		uvl = me.uv_layers.new(name="UVMap")
		if uv_npz is not None:
			z = np.load(uv_npz)
			uvs = np.zeros((len(self.faces), 3, 2), np.float32)
			for fi, (si, t) in enumerate(self.face_src):
				uvs[fi] = z["uv%d" % si][t]
			uvl.data.foreach_set("uv", np.nan_to_num(uvs, nan=5.0).reshape(-1))
		src = me.uv_layers.new(name="src")
		suv = np.zeros((len(self.faces), 3, 2), np.float32)
		for fi, (si, t) in enumerate(self.face_src):
			s = self.prims[si]["S"][self.prims[si]["I"][t]]
			suv[fi] = np.where(s[:, :1] >= 0.0, np.stack([s[:, 0], 1.0 - s[:, 1]], 1), -1.0)
		src.data.foreach_set("uv", suv.reshape(-1))
		me.uv_layers.active = uvl
		return ob
