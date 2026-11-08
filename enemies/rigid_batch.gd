class_name RigidBatch
extends RefCounted
## Many copies of one jointed hard-surface model (the robots, the drones), drawn with a handful of instanced draws however many copies there are. The Godot form of the JS game's
## enemies/rigid-merge.js (one merged mesh per material, weight 1 to its joint), one step further: all copies share the mesh and the materials, and the joints of every copy live in one data texture.
##
## A copy is a row of the texture. Texels of a row:
##   0  flash, paint tint, unit number, bar scale
##   1  colour A (rgb), intensity      2  colour B (rgb)      3  sprite size per channel
##   4..8  additive channels: colour (rgb), opacity
##   9  bar world position, yaw        10  bar fill colour, fill (< 0 = hidden)
##   11..  one 3 x 4 world matrix per joint (rows), all zero = that joint's parts are not drawn
## Views write floats straight into `data` and the batch uploads it once per frame in flush().

const PARAMS := 11
const MATRIX_SHADER := preload("res://enemies/rigid_batch.gdshader")
const GLOW_SHADER := preload("res://enemies/rigid_glow.gdshader")
const BAR_SHADER := preload("res://enemies/rigid_bar.gdshader")
const CLEAR_SHADER := preload("res://enemies/rigid_clear.gdshader")

var slots := 1
var width := 0                    # texels per row
var stride := 0                   # floats per row
var capacity := 0
var data := PackedFloat32Array()
var used := 0                     # rows up to here have been handed out at least once
var gen := 0                      # counts clear_all: a view made before the last clear holds a row that is no longer its own

var _free: Array[int] = []
var _img: Image
var _tex: ImageTexture
var _kinds: Array[Dictionary] = []    # { mesh, material, shadow }
var _nodes: Array[MultiMeshInstance3D] = []
var _mms: Array[MultiMesh] = []
var _dirty := true


func _init(p_slots: int, start_capacity: int = 16) -> void:
	slots = p_slots
	width = PARAMS + slots * 3
	stride = width * 4
	_grow(start_capacity)


## One draw per layer: the solid parts, the glow, the bars. The mesh and the material are shared by every level; only the nodes belong to one.
func add_layer(mesh: Mesh, material: ShaderMaterial, shadow: bool) -> void:
	material.set_shader_parameter(&"data", _tex)
	_kinds.append({"mesh": mesh, "material": material, "shadow": shadow})


func _grow(cap: int) -> void:
	var old := data
	capacity = cap
	data = PackedFloat32Array()
	data.resize(capacity * stride)
	data.fill(0.0)
	for i in old.size():
		data[i] = old[i]
	_img = Image.create_empty(width, capacity, false, Image.FORMAT_RGBAF)
	_tex = ImageTexture.create_from_image(_img)
	for k in _kinds:
		var mt: ShaderMaterial = k["material"]
		mt.set_shader_parameter(&"data", _tex)
	for mm in _mms:
		_size_multimesh(mm)


func _size_multimesh(mm: MultiMesh) -> void:
	mm.instance_count = capacity
	var b := PackedFloat32Array()
	b.resize(capacity * 12)
	b.fill(0.0)
	for i in capacity:                # identity: all the placing happens in the shader, from the data texture
		b[i * 12] = 1.0
		b[i * 12 + 5] = 1.0
		b[i * 12 + 10] = 1.0
	mm.buffer = b
	mm.visible_instance_count = used


## The nodes of the batch, under the level being played. Freed with the level; made again on the next one.
func _attach() -> void:
	_nodes.clear()
	_mms.clear()
	var parent: Node = Game.level if Game.level != null else Game.root3d
	if parent == null:
		return
	for k in _kinds:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = k["mesh"]
		_size_multimesh(mm)
		var mi := MultiMeshInstance3D.new()
		mi.name = "RigidBatch"
		mi.multimesh = mm
		mi.material_override = k["material"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if k["shadow"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		parent.add_child(mi)
		_nodes.append(mi)
		_mms.append(mm)


## At level load: the nodes exist (no copies yet), so the engine prepares their pipelines now rather than at the first spawn.
func warm() -> void:
	if not _attached():
		_attach()


func _attached() -> bool:
	return not _nodes.is_empty() and is_instance_valid(_nodes[0]) and _nodes[0].is_inside_tree()


## a free row, all zero. Every view holds one for its whole life.
func acquire() -> int:
	if _free.is_empty():
		if used >= capacity:
			_grow(capacity * 2)
		used += 1
		for mm in _mms:
			mm.visible_instance_count = used
		return used - 1
	return _free.pop_back()


func release(row: int) -> void:
	clear_row(row)
	_free.append(row)


func clear_row(row: int) -> void:
	var o := row * stride
	for i in range(o, o + stride):
		data[i] = 0.0


## JS leaving a level: every copy is gone.
func clear_all() -> void:
	gen += 1
	data.fill(0.0)
	_free.clear()
	used = 0
	for mi in _nodes:
		if is_instance_valid(mi):
			mi.queue_free()
	_nodes.clear()
	_mms.clear()


## joint matrix of one copy
func set_slot(row: int, slot: int, xf: Transform3D) -> void:
	var o := row * stride + (PARAMS + slot * 3) * 4
	var d := data
	var b := xf.basis
	var bx := b.x
	var by := b.y
	var bz := b.z
	var p := xf.origin
	d[o] = bx.x
	d[o + 1] = by.x
	d[o + 2] = bz.x
	d[o + 3] = p.x
	d[o + 4] = bx.y
	d[o + 5] = by.y
	d[o + 6] = bz.y
	d[o + 7] = p.y
	d[o + 8] = bx.z
	d[o + 9] = by.z
	d[o + 10] = bz.z
	d[o + 11] = p.z


## the joint's parts are not drawn
func hide_slot(row: int, slot: int) -> void:
	var o := row * stride + (PARAMS + slot * 3) * 4
	for i in 12:
		data[o + i] = 0.0


## world position of a point in a joint's space, read back from the row (FX asks for it: muzzle flashes, smoke)
func slot_point(row: int, slot: int, p: Vector3) -> Vector3:
	var o := row * stride + (PARAMS + slot * 3) * 4
	var d := data
	return Vector3(d[o] * p.x + d[o + 1] * p.y + d[o + 2] * p.z + d[o + 3],
		d[o + 4] * p.x + d[o + 5] * p.y + d[o + 6] * p.z + d[o + 7],
		d[o + 8] * p.x + d[o + 9] * p.y + d[o + 10] * p.z + d[o + 11])


## Upload the rows; `bounds` is where all the live copies are (culling and shadow cascades go by it).
func flush(bounds: AABB) -> void:
	if used == 0:
		return
	if not _attached():
		_attach()
	_img.set_data(width, capacity, false, Image.FORMAT_RGBAF, data.to_byte_array())
	_tex.update(_img)
	for mi in _nodes:
		mi.custom_aabb = bounds


## JS colour hex (sRGB) to the linear value the shaders work in.
static func lin(hex: int) -> Color:
	return Color.hex((hex << 8) | 0xff).srgb_to_linear()
