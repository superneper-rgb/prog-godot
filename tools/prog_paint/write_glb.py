## Prog's painted texture, step 3: put the UV layout (bake.py) and the texture (paint.py) into prog.glb, and nothing else. The skeleton, skin, weights,
## positions and normals are copied over as they are; a vertex is only duplicated where a UV seam splits it. The painted surfaces drop their vertex colours
## (the paint carries the colour now) and point at the texture; the eye whites get the lid colour the blink shader needs.
##   python tools/prog_paint/write_glb.py assets/prog.glb F:/prog-godot-cache/prog_paint/uv.npz prog_paint.png [out.glb]
import sys, os, json, struct
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from prog_mesh import read_glb, acc, PAINTED

SRC, UVZ, IMG = sys.argv[1], sys.argv[2], sys.argv[3]
DST = sys.argv[4] if len(sys.argv) > 4 else SRC
MOUTH_Y = 1.66            # bk_pupil triangles below this are the slot of a mouth (the old head's; the new one has none)
LID = [0.38, 0.21, 0.15]  # eyelid colour (linear): the darker skin round his eyes (lighter read pale on a shut eye)

j, B = read_glb(SRC)
uvz = np.load(UVZ)
names = [str(n) for n in uvz["names"]]

CT = {np.dtype(np.float32): 5126, np.dtype(np.uint8): 5121, np.dtype(np.uint16): 5123, np.dtype(np.uint32): 5125}
TYPE = {1: "SCALAR", 2: "VEC2", 3: "VEC3", 4: "VEC4", 16: "MAT4"}
new_acc, chunks = [], []
blen = 0


def raw_dtype(i):
	a = j["accessors"][i]
	return {5126: np.float32, 5121: np.uint8, 5123: np.uint16, 5125: np.uint32}[a["componentType"]]


def put(arr, kind=None, normalized=False, target=None):
	## append an accessor (and its own buffer view) holding arr; returns its index
	global blen
	arr = np.ascontiguousarray(arr)
	n = 1 if arr.ndim == 1 else arr.shape[1]
	data = arr.tobytes()
	pad = (-blen) % 4
	if pad:
		chunks.append(b"\0" * pad)
		blen += pad
	view = {"buffer": 0, "byteOffset": blen, "byteLength": len(data)}
	if target:
		view["target"] = target
	j_views.append(view)
	chunks.append(data)
	blen += len(data)
	a = {"bufferView": len(j_views) - 1, "componentType": CT[arr.dtype], "count": int(arr.shape[0]), "type": kind or TYPE[n]}
	if normalized:
		a["normalized"] = True
	if a["type"] == "VEC3" and arr.dtype == np.float32:
		a["min"] = arr.min(0).tolist()
		a["max"] = arr.max(0).tolist()
	new_acc.append(a)
	return len(new_acc) - 1


def raw(i):
	## an accessor's data in its own component type (not normalised to float)
	a = j["accessors"][i]
	v = j["bufferViews"][a["bufferView"]]
	n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
	dt = raw_dtype(i)
	isz = np.dtype(dt).itemsize * n
	stride = v.get("byteStride", 0) or isz
	off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
	buf = np.frombuffer(B, np.uint8, count=stride * (a["count"] - 1) + isz, offset=off)
	rows = np.lib.stride_tricks.as_strided(buf, (a["count"], isz), (stride, 1))
	out = np.ascontiguousarray(rows).view(dt).reshape(a["count"], n)
	return out if n > 1 else out.reshape(-1)


j_views = []
mesh = j["meshes"][0]
for pi, p in enumerate(mesh["primitives"]):
	mat = j["materials"][p["material"]]
	name = mat["name"]
	at = dict(p["attributes"])
	I = raw(p["indices"]).astype(np.int64).reshape(-1, 3)
	attrs = {k: raw(v) for k, v in at.items() if k not in ("TEXCOORD_0", "TEXCOORD_1")}      # (TEXCOORD_1: the old texture's coordinates, the bake's alone)
	norm = {k: bool(j["accessors"][v].get("normalized")) for k, v in at.items()}
	if name == "bk_pupil":
		cen = attrs["POSITION"][I].mean(1)
		I = I[cen[:, 1] >= MOUTH_Y]
	if name in PAINTED:
		uv = uvz["uv%d" % names.index(name)].astype(np.float64)
		if len(uv) != len(I):
			sys.exit("write_glb: %s has %d triangles, uv.npz %d: bake again from this file" % (name, len(I), len(uv)))
		uv = np.nan_to_num(uv, nan=0.0)
		uv[:, :, 1] = 1.0 - uv[:, :, 1]                   # Blender's V runs up, glTF's down
		key = np.stack([I.reshape(-1), np.round(uv[:, :, 0] * 2e5).reshape(-1).astype(np.int64), np.round(uv[:, :, 1] * 2e5).reshape(-1).astype(np.int64)], 1)
		uniq, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
		src_v = uniq[:, 0]
		attrs = {k: v[src_v] for k, v in attrs.items() if k not in ("COLOR_0", "_VCOL")}
		attrs["TEXCOORD_0"] = uv.reshape(-1, 2)[first].astype(np.float32)
		I = inv.reshape(-1, 3)
		mat.setdefault("pbrMetallicRoughness", {})["baseColorTexture"] = {"index": 0}
		if name == "bk_eye_white":
			mat["extras"] = {"lidColor": LID}       # the eyelid tone the blink shader closes over the eye (Animator._restyle, eye_fx.gdshader)
		mat["pbrMetallicRoughness"]["baseColorFactor"] = [1.0, 1.0, 1.0, 1.0]
		print("write_glb: %-15s %5d -> %5d vertices" % (name, len(raw(at["POSITION"])), len(src_v)))
	new_at = {}
	for k, v in attrs.items():
		new_at[k] = put(v, normalized=norm.get(k, False), target=34962)
	p["attributes"] = new_at
	idx = I.reshape(-1)
	p["indices"] = put(idx.astype(np.uint16 if idx.max() < 65535 else np.uint32), target=34963)

for sk in j.get("skins", []):
	if "inverseBindMatrices" in sk:
		sk["inverseBindMatrices"] = put(raw(sk["inverseBindMatrices"]).astype(np.float32), kind="MAT4")
if j.get("animations"):
	sys.exit("write_glb: animations are not carried over by this tool")

j["accessors"] = new_acc
j["bufferViews"] = j_views
j["images"] = [{"uri": IMG}]
j["samplers"] = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 33071, "wrapT": 33071}]
j["textures"] = [{"sampler": 0, "source": 0}]
binb = b"".join(chunks)
binb += b"\0" * ((-len(binb)) % 4)
j["buffers"] = [{"byteLength": len(binb)}]
js = json.dumps(j, separators=(",", ":")).encode()
js += b" " * ((-len(js)) % 4)
out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(binb))
out += struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(binb), 0x004E4942) + binb
tmp = DST + ".tmp"
open(tmp, "wb").write(out)
os.replace(tmp, DST)
print("write_glb:", DST, len(out), "bytes")
