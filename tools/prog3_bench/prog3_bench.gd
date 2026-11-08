## Test bench for the rebuilt Prog, away from the game: loads his model and moves, checks every clip against numbers read from the export, and photographs clips with their guns. Run by tools/prog3_bench/run.mjs.
extends Node3D

const ASSET := "res://assets/prog3/"
const WPN := "res://assets/weapons/"

var model: Node3D
var skel: Skeleton3D
var player: AnimationPlayer
var data: Dictionary
var gun_holder: Array[Node] = []
var gun_root: Node3D = null
var gun_nodes: Dictionary = {}
var clip_info: Dictionary = {}
var out_dir := ""


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	out_dir = a[1] if a.size() > 1 else OS.get_temp_dir()
	data = JSON.parse_string(FileAccess.get_file_as_string(ASSET + "prog3_moves.json"))
	_build()
	var mode: String = a[0] if a.size() > 0 else "check"
	if mode == "check":
		_check()
	else:
		await _shots(mode)
	get_tree().quit()


## Every surface of his 24 meshes folded into one per material: they already share one skin, so the vertices simply follow each other
func _merged(src: Node3D) -> MeshInstance3D:
	var by_mat: Dictionary = {}
	var skin: Skin = null
	var skel_path := NodePath()
	for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		if skin == null:
			skin = mi.skin
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if not by_mat.has(mat):
				by_mat[mat] = []
			by_mat[mat].append(mi.mesh.surface_get_arrays(s))
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	var mesh := ArrayMesh.new()
	for mat: Material in by_mat:
		var all: Array = by_mat[mat]
		var merged: Array = []
		merged.resize(Mesh.ARRAY_MAX)
		var base := 0
		for arr: Array in all:
			var count: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			for k in Mesh.ARRAY_MAX:
				if arr[k] == null:
					continue
				if k == Mesh.ARRAY_INDEX:
					var idx: PackedInt32Array = arr[k]
					for i in idx.size():
						idx[i] += base
					arr[k] = idx
				if merged[k] == null:
					merged[k] = arr[k]
				else:
					merged[k].append_array(arr[k])
			base += count
		var flags := 0
		if (merged[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array).size() == base * 8:
			flags = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, merged, [], {}, flags)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var out := MeshInstance3D.new()
	out.name = "prog3_merged"
	out.mesh = mesh
	out.skin = skin
	return out


func _build() -> void:
	model = (load(ASSET + "prog3.glb") as PackedScene).instantiate()
	add_child(model)
	skel = model.find_children("*", "Skeleton3D", true, false)[0]
	var before := model.find_children("*", "MeshInstance3D", true, false).size()
	var merged := _merged(model)
	skel.add_child(merged)
	merged.skeleton = merged.get_path_to(skel)
	print("BENCH model: ", before, " meshes -> 1 with ", merged.mesh.get_surface_count(), " surfaces, ", skel.get_bone_count(), " bones")
	# his own glb's animation player (mouth shapes, hair) stays out of the way here
	for ap: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
		ap.get_parent().remove_child(ap)
		ap.free()
	var moves: Node = (load(ASSET + "prog3_moves.glb") as PackedScene).instantiate()
	var src: AnimationPlayer = moves.find_children("*", "AnimationPlayer", true, false)[0]
	var lib: AnimationLibrary = src.get_animation_library(&"")
	var sample := lib.get_animation(lib.get_animation_list()[0])
	print("BENCH moves: ", lib.get_animation_list().size(), " clips; first track ", sample.track_get_path(0), " type ", sample.track_get_type(0), " keys ", sample.track_get_key_count(0))
	print("BENCH moves tree: ", moves.get_child(0).name, " / ", moves.get_child(0).get_child(0).name if moves.get_child(0).get_child_count() > 0 else "-")
	# the tracks name the moves file's skeleton; point them at this one
	var skel_np := str(model.get_path_to(skel))
	var fixed := AnimationLibrary.new()
	for nm in lib.get_animation_list():
		var an: Animation = lib.get_animation(nm).duplicate()
		for t in an.get_track_count():
			var path := str(an.track_get_path(t))
			var colon := path.rfind(":")
			an.track_set_path(t, NodePath(skel_np + path.substr(colon)))
		fixed.add_animation(nm, an)
	player = AnimationPlayer.new()
	model.add_child(player)
	player.root_node = player.get_path_to(model)
	player.add_animation_library(&"", fixed)
	player.playback_default_blend_time = 0.0
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL   # (held on the frame asked for: it must not run on while a photo waits)
	moves.free()


func _pose_at(clip: String, t: float) -> void:
	player.play(StringName(clip))
	player.seek(t, true)
	player.advance(0.0)
	skel.force_update_all_bone_transforms()


## Every clip, in file order so a bone left over from the clip before would show, against positions walked from the file outside Godot
func _check() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out_dir + "/expected.json"))
	var worst := 0.0
	var worst_at := ""
	var bad := 0
	var missing := 0
	var per: Array = []
	for clip: String in expected:
		if not player.has_animation(StringName(clip)):
			missing += 1
			print("BENCH missing clip ", clip)
			continue
		_pose_at(clip, float(expected[clip]["t"]))
		var clip_worst := 0.0
		var clip_bone := ""
		for b: String in expected[clip]["bones"]:
			var e: Array = expected[clip]["bones"][b]
			var i := skel.find_bone(b)
			var got := skel.global_transform * skel.get_bone_global_pose(i).origin
			var d := got.distance_to(Vector3(e[0], e[1], e[2]))
			if d > clip_worst:
				clip_worst = d
				clip_bone = b
		if clip_worst > worst:
			worst = clip_worst
			worst_at = clip + " " + clip_bone
		if clip_worst > 0.01:
			bad += 1
			per.append("%s %s %.1f cm" % [clip, clip_bone, clip_worst * 100.0])
	print("BENCH check: ", expected.size(), " clips, missing ", missing, ", over 1 cm ", bad, ", worst ", "%.2f cm" % (worst * 100.0), " at ", worst_at)
	for line: String in per.slice(0, 12):
		print("BENCH off: ", line)


func _clear_gun() -> void:
	for n in gun_holder:
		n.queue_free()
	gun_holder.clear()
	gun_root = null
	gun_nodes.clear()


func _attach(hand: String, sock: Dictionary, gun: String) -> Node3D:
	var att := BoneAttachment3D.new()
	skel.add_child(att)
	att.bone_name = hand
	var g: Node3D = (load(WPN + gun + ".glb") as PackedScene).instantiate()
	att.add_child(g)
	var p: Array = sock["pos"]
	var q: Array = sock["quat"]
	var s := float(sock["scale"])
	g.transform = Transform3D(Basis(Quaternion(q[0], q[1], q[2], q[3])).scaled(Vector3(s, s, s)), Vector3(p[0], p[1], p[2]))
	gun_holder.append(att)
	return g


func _part(root: Node, want: String) -> Node3D:
	for n: Node in root.find_children("*", "Node3D", true, false):
		if String(n.name).ends_with(want):
			return n
	return null


func _gun_for(clip: String) -> void:
	_clear_gun()
	var c: Dictionary = data["clips"].get(clip, {})
	if not c.has("gun"):
		return
	var gun: String = c["gun"]
	var sock: Dictionary = data["guns"][gun][c["state"]]
	gun_root = _attach("hand.R", sock["r"], gun)
	if gun == "flail":
		var d := _part(gun_root, "display")
		if d:
			d.visible = false
	if gun == "dual_silenced" and sock.has("l"):
		var other := _attach("hand.L", sock["l"], gun)
		for pair: Array in [[gun_root, "gun_l"], [other, "gun_r"]]:
			var hide_it := _part(pair[0], pair[1])
			if hide_it:
				hide_it.visible = false
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WPN + gun + ".json"))["info"]
	for k in ["mag", "rack", "spare", "hatch"]:
		var o: Variant = info.get(k)
		var nm := ""
		if o is Dictionary and k == "hatch":
			nm = o.get("object3d", "")
		elif o is Dictionary and o.get("obj") is Dictionary:
			nm = o["obj"].get("object3d", "")
		if nm != "":
			gun_nodes[k] = _part(gun_root, nm)
	clip_info = c


func _apply_parts(frame: int) -> void:
	var parts: Dictionary = clip_info.get("gun_parts", {})
	for k: String in parts:
		var n: Node3D = gun_nodes.get(k)
		if n == null:
			continue
		var v: Array = parts[k][mini(frame, parts[k].size() - 1)]
		var xf := Transform3D(Basis(Quaternion(v[3], v[4], v[5], v[6])), Vector3(v[0], v[1], v[2]))
		n.global_transform = gun_root.global_transform * xf


## Photographs from the list the runner wrote: [{clip, t, view, ortho, cz, cx}], same camera numbers as the Blender renders, on a transparent-free grey
func _shots(list_path: String) -> void:
	var list: Array = JSON.parse_string(FileAccess.get_file_as_string(list_path))
	var vp := SubViewport.new()
	vp.size = Vector2i(440, 440)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = false
	add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color8(60, 60, 64)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.95
	add_child(sun)
	sun.look_at_from_position(Vector3(-2, 4, 3), Vector3.ZERO)
	for e: Dictionary in list:
		var clip: String = e["clip"]
		_pose_at(clip, float(e["t"]))
		_gun_for(clip)
		_apply_parts(int(round(float(e["t"]) * 24.0)))
		var a := deg_to_rad(float(e["view"]))
		var dir := Vector3(sin(a), 0.0, cos(a))
		var cx := float(e.get("cx", 0.0))
		cam.size = float(e["ortho"])
		cam.look_at_from_position(Vector3(cx, float(e["cz"]), 0.0) + dir * 5.0, Vector3(cx, float(e["cz"]), 0.0))
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out_dir + "/" + e["name"] + ".png")
	print("BENCH shots: ", list.size())
