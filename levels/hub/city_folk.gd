class_name CityFolk
extends RefCounted
## FOINT CITY townsfolk bodies (JS levels/hub/city-folk.js, folk-kit.js geometry()): the species as the JS built them, with the attributes glTF cannot carry (life.json + life.bin), into meshes for levels/shaders/folk.gdshader. One shared material; meshes are made once per level load.

var material: ShaderMaterial
var _J: Dictionary
var _bin: PackedByteArray
var _cache: Dictionary = {}
var _ix := PackedInt32Array()


func _init(J: Dictionary, bin: PackedByteArray) -> void:
	_J = J
	_bin = bin
	material = ShaderMaterial.new()
	material.shader = load("res://levels/shaders/folk.gdshader")
	var atlas := String(J.get("atlas", ""))
	if atlas != "":
		material.set_shader_parameter(&"atlas", load("res://assets/" + atlas))


func release_bin() -> void:
	_bin = PackedByteArray()
	_ix = PackedInt32Array()


func species_mesh(nm: String) -> ArrayMesh:
	if not _cache.has(nm):
		_cache[nm] = _mesh(_J["species"][nm])
	return _cache[nm]


## a species with every vertex in one animation mode (VISITING HOURS' inmates: 3, talks with its hands)
func species_mesh_mode(nm: String, mode: float) -> ArrayMesh:
	var key := "%s:%f" % [nm, mode]
	if not _cache.has(key):
		var m := _mesh(_J["species"][nm])
		var arr := m.surface_get_arrays(0)
		var b4: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
		for i in range(2, b4.size(), 4):
			b4[i] = mode
		arr[Mesh.ARRAY_CUSTOM0] = b4
		var flags := m.surface_get_format(0) & (Mesh.ARRAY_FORMAT_CUSTOM_BASE - 1)
		flags = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) | (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
		var out := ArrayMesh.new()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
		_cache[key] = out
	return _cache[key]


func driver_mesh(nm: String) -> ArrayMesh:
	var key := "driver:" + nm
	if not _cache.has(key):
		_cache[key] = _mesh(_J["drivers"][nm]["geo"])
	return _cache[key]


## three.js winds its faces the other way round. (Not cull_front in the shader: Godot turns the normal of what it takes for a back face.)
func _indices(n: int) -> PackedInt32Array:
	while _ix.size() < n:
		var b := _ix.size()
		_ix.append_array([b, b + 2, b + 1])
	return _ix.slice(0, n)


func _mesh(g: Dictionary) -> ArrayMesh:
	var n := int(g["n"])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _bin.slice(int(g["pos"]), int(g["pos"]) + n * 12).to_vector3_array()
	arr[Mesh.ARRAY_NORMAL] = _bin.slice(int(g["nor"]), int(g["nor"]) + n * 12).to_vector3_array()
	arr[Mesh.ARRAY_TEX_UV] = _bin.slice(int(g["uv"]), int(g["uv"]) + n * 8).to_vector2_array()
	arr[Mesh.ARRAY_TEX_UV2] = _bin.slice(int(g["tile"]), int(g["tile"]) + n * 8).to_vector2_array()
	arr[Mesh.ARRAY_CUSTOM0] = _bin.slice(int(g["b4"]), int(g["b4"]) + n * 16).to_float32_array()
	arr[Mesh.ARRAY_CUSTOM1] = _bin.slice(int(g["pivot"]), int(g["pivot"]) + n * 12).to_float32_array()
	arr[Mesh.ARRAY_CUSTOM2] = _bin.slice(int(g["col"]), int(g["col"]) + n * 12).to_float32_array()
	arr[Mesh.ARRAY_INDEX] = _indices(n)
	var flags := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) | (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	return m
