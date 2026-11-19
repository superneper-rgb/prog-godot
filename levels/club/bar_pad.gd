class_name BarPad
extends Node3D
## CLUB 9's drinks pad: the bar menu's device (assets/ui/bar_pad/bar_pad.png, the user's painting, the alien hand under it included) as a slab the bartender holds out. Its front is the picture
## itself, its edge and back are cut to the picture's outline, so when the camera lands square on it the 2D menu (BarMenu, the same picture flat) takes over without a jump.

const ART := "res://assets/ui/bar_pad/bar_pad.png"
const HEIGHT := 0.27              # the whole picture, hand included (m)
const RATIO := 1024.0 / 1536.0    # picture width / height
const DEPTH := 0.032              # how thick the slab is
## where the bartender's left wrist sits, in the pad's own space: behind the painted (left) hand (the fingers wrap the bottom edge toward the customer)
const WRIST := Vector3(-0.005, -0.1, -0.05)

var mat: ShaderMaterial = null
var _mi: MeshInstance3D = null


func _init() -> void:
	name = "BarPad"
	var tex: Texture2D = load(ART)
	mat = ShaderMaterial.new()
	mat.shader = load("res://levels/club/bar_pad.gdshader")
	mat.set_shader_parameter(&"art", tex)
	_mi = MeshInstance3D.new()
	_mi.mesh = _build_mesh(tex)
	_mi.material_override = mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)


## 1 lit by the club, 0 the picture as painted (what the 2D menu shows)
func set_lit(v: float) -> void:
	mat.set_shader_parameter(&"lit", v)


## the glass's green, 0..1
func set_screen(v: float) -> void:
	mat.set_shader_parameter(&"screen_on", v)


## Front and back are the picture's rectangle (the shader drops what is transparent); the edge walls follow its outline, traced once from the alpha at a quarter of the size.
static func _build_mesh(tex: Texture2D) -> ArrayMesh:
	var w := HEIGHT * RATIO
	var h := HEIGHT
	var zf := DEPTH * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tl := Vector3(-w / 2.0, h / 2.0, 0.0)
	var tr := Vector3(w / 2.0, h / 2.0, 0.0)
	var br := Vector3(w / 2.0, -h / 2.0, 0.0)
	var bl := Vector3(-w / 2.0, -h / 2.0, 0.0)
	var uv := {tl: Vector2(0, 0), tr: Vector2(1, 0), br: Vector2(1, 1), bl: Vector2(0, 1)}
	# front (Godot: clockwise as seen is the front face), then the back, darker
	for side: int in [1, -1]:
		var order: Array = [tl, tr, br, tl, br, bl] if side == 1 else [tl, br, tr, tl, bl, br]
		st.set_color(Color(1, 1, 1, 1) if side == 1 else Color(0.22, 0.22, 0.24, 0))
		st.set_normal(Vector3(0, 0, side))
		for p: Vector3 in order:
			st.set_uv(uv[p])
			st.add_vertex(p + Vector3(0, 0, zf * side))
	# the edge
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img = img.duplicate()
	img.resize(256, 384, Image.INTERPOLATE_BILINEAR)
	var bm := BitMap.new()
	bm.create_from_image_alpha(img, 0.5)
	var polys := bm.opaque_to_polygons(Rect2i(0, 0, 256, 384), 1.0)
	st.set_color(Color(0.55, 0.55, 0.57, 0))
	for poly: PackedVector2Array in polys:
		var n := poly.size()
		if n < 3:
			continue
		var pts: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		var area := 0.0
		for i in n:
			var q := poly[i] / Vector2(256.0, 384.0)
			uvs.append(q)
			pts.append(Vector3((q.x - 0.5) * w, (0.5 - q.y) * h, 0.0))
		for i in n:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			area += a.x * b.y - b.x * a.y
		for i in n:
			var j := (i + 1) % n
			var a := pts[i]
			var b := pts[j]
			var d := b - a
			if d.length() < 1e-5:
				continue
			var out := Vector3(d.y, -d.x, 0.0).normalized() * (1.0 if area > 0.0 else -1.0)
			var af := a + Vector3(0, 0, zf)
			var bf := b + Vector3(0, 0, zf)
			var bb := b - Vector3(0, 0, zf)
			var ab := a - Vector3(0, 0, zf)
			var quad: Array = [[af, uvs[i]], [bf, uvs[j]], [bb, uvs[j]], [af, uvs[i]], [bb, uvs[j]], [ab, uvs[i]]]
			if (bf - af).cross(bb - af).dot(out) > 0.0:      # (clockwise from outside: the cross product points in)
				quad = [quad[0], quad[2], quad[1], quad[3], quad[5], quad[4]]
			st.set_normal(out)
			for v: Array in quad:
				st.set_uv(v[1])
				st.add_vertex(v[0])
	return st.commit()
