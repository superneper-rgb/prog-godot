class_name SigilBeastView
extends Node3D
## THE SIGIL'S BODY: what comes up out of the throne in UNDERFOINT and chases the train. The SERN machine the Sigil took over, long and low on ten blade legs, its small 90s television of a head
## carried out over the car on a raised neck, two mantis scythes, six weak-point screens built into its chest, flanks and belly, armour plates that tear off as the ride goes on. Silhouette "A Strider",
## picked by the user on 2026-11-15; model, rig and clips from tools/sigil/build_sigil.py (assets/underfoint/sigil/sigil.glb). It replaces the user's Meshy model that a shader bent (the old
## levels/shaders/uf_beast.gdshader), which an audit found was a green clump in green tunnels with no skeleton.
## This is only the body. Whoever runs the fight sets the pose fields below and calls update(dt); every field the old body had still works, mapped onto the clips:
##   stride (0..1)   idle .. gallop, and how fast the gallop plays
##   strike (0..1)   the "strike" clip, seeked: the neck thrown out forward and down over the car
##   slash_l / _r    the "swipe_l" / "swipe_r" clips seeked through a swing (0 rest, ~0.38 the held wind-up, 0.5 the blow, 1 back); the bigger of the two also seeks "rear", the front rearing up to
##                   bare its belly and chest, which is when the fight lights its screens
##   sway (-1..1)    its chest and neck swung to the side, on top of whatever plays
##   rage, flash, angry, speaking, point_state, crt_armed, blink_rate: as before (a fresh flash also plays the hit flinch)
## New: state (run / climb / wall / grab / fall / defeat), play(clip) for one-shots (roar, lunge, hit, reel, land), damage (0..3 plates torn), crt_open, look_target, fit_h / fit_w (it crouches
## low and narrow to fit a low or tight line, see H_LOW / W_LOW), and broken screens that stay broken. The bone names (root, body_0..4, neck_0..4, head, tail_0..2, arm_L/R_0..2, leg_k_L/R_0..1)
## are used by the fight to place its hit cylinders: keep them.
## The node's origin is the ground under its chest (its body runs ~21 m back from there, its head ~8.5 m ahead); it faces +Z at yaw 0. Its own left is +X.

const MODEL := "res://assets/underfoint/sigil/sigil.glb"
## how far the model sits behind this node's origin: the origin is the ground under its chest, so its head hangs ~8.5 m ahead of it at rest, as the old body's did (the fight's distances were tuned to that)
const BACK := 5.0
const GLASS_SHADER := preload("res://levels/shaders/sigil_glass.gdshader")
const CRT_SHADER := preload("res://levels/shaders/sigil_crt.gdshader")
const HALO_SHADER := preload("res://levels/shaders/sigil_halo.gdshader")
const GREEN := Color(0.35, 1.0, 0.45)
const AMBER := Color(1.0, 0.62, 0.12)
## The weak points by index, each as (across, up) in metres at rest: x > 0 is its own left, 0 its middle (levels/underfoint/uf_chase.gd lights the screen on a raised arm's side by that sign).
## The index meaning is kept from the old body, because the fight picks by it: 0..1 can be hit head-on (over the engine), 0..3 from the side, 1..5 from behind. It squares up to you and rears to
## strike, so they are on its front and underside: 0 throat (under the neck), 1 chest, 2 / 3 the chest's lower flanks (its left, its right), 4 / 5 the second segment's belly (left, right).
const POINT_AT: Array[Vector2] = [Vector2(0.0, 8.45), Vector2(0.0, 5.3), Vector2(1.42, 5.0), Vector2(-1.42, 5.0), Vector2(0.85, 4.15), Vector2(-0.85, 4.15)]
const OFF := 0          # a point's state: dark
const ARMED := 1        # amber, blinking: shoot it
const BROKEN := 2       # shot out (stays broken)
const STATES: Array[StringName] = [&"run", &"climb", &"wall", &"grab", &"fall", &"defeat"]
const UPPER_SHOTS: Array[StringName] = [&"roar", &"lunge", &"hit"]      # played on the upper body only: the legs keep running
const FULL_SHOTS: Array[StringName] = [&"reel", &"land"]
## How high and how wide it reaches (metres from its origin's ground and from its centre line, the most over each clip, measured off the skinned mesh by tools/sigil/build_sigil.py --measure).
## Free it stands 11.7 m high and 6.8 m wide, and a swing or a roar throws its scythes up to 16.2 m. Tight (the *_low clips: crouched, legs drawn in and splayed fore and aft, scythes carried low,
## neck forward) it keeps under 8.8 m and 5.2 m: its 8.4 m shins can fold no tighter and still reach the floor, so fit_h / fit_w below those are not met.
const H_FREE := 11.7
const H_SWING := 16.2
const H_LOW := 8.8
const W_FREE := 6.8
const W_LOW := 5.2
## the plates torn off at each damage stage (bones in the model; a torn one is scaled away and a copy of it flies off)
const TEAR: Array = [[&"plate_b2", &"plate_sh_L"], [&"plate_b0", &"plate_sh_R", &"plate_b3"], [&"plate_b1", &"plate_b4"]]

var strike := 0.0       # 0..1
var sway := 0.0         # -1..1
var stride := 0.0       # 0..1
var rage := 0.0         # 0..1
var flash := 0.0        # a hit: fades by itself
var slash_l := 0.0      # 0 at rest .. 1 through a swing (the fight runs it)
var slash_r := 0.0
var angry := false      # the face goes amber
var speaking := 0.0
var point_state := PackedInt32Array([0, 0, 0, 0, 0, 0])
var crt_armed := false  # the television itself is the target: its armour opens and it blinks amber
var blink_rate := 3.0   # the armed points' blink (the fight speeds it up as time runs out)
var state := &"run"     # what its whole body is doing: one of STATES (wall: on a wall or upside down on a roof, flattened against it)
var damage := 0         # 0..3: how many stages of its armour have been torn off (raise it at a big beat)
var crt_open := -1.0    # the armour round its set: < 0 opens by itself while crt_armed, else held at this (0 shut .. 1 open)
var look_target := Vector3.INF      # what the head watches, in the world; INF = Prog
var look_weight := 1.0
var fit_h := INF        # the fight's room: nothing of it above this (metres over its origin's ground; INF = free). It crouches toward its tight clips to fit, eased
var fit_w := INF        # and no leg wider than this from its centre line (half-width, metres)
var red_l := 0.0        # 0..1: its left scythe glows red (the fight's "get out of the way" cue: levels/underfoint/uf_chase.gd, the swing you jump)
var red_r := 0.0
var burning := false    # it has been through the depot's fire: its plating stays scorched and lit from the fire on it

var _scene: Node3D
var _skel: Skeleton3D
var _sk := Transform3D()        # the skeleton's space -> this node's
var _mesh: MeshInstance3D
var _tree: AnimationTree
var _body_mat: StandardMaterial3D
var _glass_mat: ShaderMaterial
var _crt_mat: ShaderMaterial
var _face: SigilFace
var _view: SubViewport
var _crt_light: OmniLight3D
var _armed_light: OmniLight3D
var _halos: Array[MeshInstance3D] = []
var _marks: Array = []          # [bone, offset in the bone's space] for each weak point, then the screen: [glass, a point 1 m out along its normal]
var _b := {}                    # bone name -> index
var _len := {}                  # clip -> length (s)
var _states := PackedFloat32Array([0, 0, 0, 0, 0, 0])
var _tight := 0.0               # 0 free .. 1 its tight clips (from fit_h / fit_w, eased)
var _tight_sw := 0.0            # the same for its swings and roar, which reach higher
var _shown := false
var _t := 0.0
var _flash_was := 0.0
var _shot_cd := 0.0
var _state_was := &"run"
var _torn := 0
var _open := 0.0
var _hinge := {}                # shell bone -> its hinge axis in the head bone's space
var _look := Quaternion.IDENTITY
var _spark_cd := 0.0
var _debris: Array = []         # [node, velocity, spin, life]
var _was_broken := PackedInt32Array([0, 0, 0, 0, 0, 0])
var _red_mats: Array[StandardMaterial3D] = []      # [left, right]
var _red_lights: Array[OmniLight3D] = []
var _red_nodes: Array[MeshInstance3D] = []
var _burn_light: OmniLight3D
var _feet := PackedInt32Array()         # its ten shin bones, front pair first (left, right)
var _shin := PackedFloat32Array()       # and how long each is: the foot is at the far end


func _init() -> void:
	name = "SigilBeast"
	_scene = (load(MODEL) as PackedScene).instantiate() as Node3D
	_scene.rotation.y = PI      # (built facing Blender's +Y, which glTF makes -Z)
	_scene.position.z = -BACK
	add_child(_scene)
	_skel = _scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_mesh = _skel.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	for i in _skel.get_bone_count():
		_b[_skel.get_bone_name(i)] = i
	var p: Node = _skel
	while p != _scene:
		_sk = (p as Node3D).transform * _sk
		p = p.get_parent()
	_sk = _scene.transform * _sk
	_mesh.custom_aabb = AABB(Vector3(-16.0, -12.0, -24.0), Vector3(32.0, 32.0, 48.0))      # (skinned and thrown about: its rest box is no guide)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_build_materials()
	_build_marks()
	_build_tree()
	_build_lights()
	_build_shadow()
	for i in POINT_AT.size() + 1:
		var h := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		h.mesh = q
		h.material_override = _halo_mat
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		h.visible = false
		add_child(h)
		_halos.append(h)


var _halo_mat: ShaderMaterial


func _build_materials() -> void:
	var m := _mesh.mesh
	for s in m.get_surface_count():
		var nm := String(m.surface_get_name(s))
		var old := m.surface_get_material(s) as BaseMaterial3D
		if nm.contains("glass"):
			_glass_mat = ShaderMaterial.new()
			_glass_mat.shader = GLASS_SHADER
			_mesh.set_surface_override_material(s, _glass_mat)
		elif nm.contains("crt"):
			_crt_mat = ShaderMaterial.new()
			_crt_mat.shader = CRT_SHADER
			_mesh.set_surface_override_material(s, _crt_mat)
		else:
			# the baked atlas, with a rim so its white enamel holds its shape against the dark, and the hit flash in its emission
			_body_mat = StandardMaterial3D.new()
			if old != null:
				_body_mat.albedo_texture = old.albedo_texture
				_body_mat.normal_enabled = old.normal_texture != null
				_body_mat.normal_texture = old.normal_texture
				_body_mat.roughness_texture = old.roughness_texture
				_body_mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
				_body_mat.metallic_texture = old.metallic_texture
				_body_mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
				_body_mat.metallic = 1.0
				_body_mat.ao_enabled = old.ao_texture != null
				_body_mat.ao_texture = old.ao_texture
				_body_mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			_body_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			_body_mat.rim_enabled = true
			_body_mat.rim = 0.45
			_body_mat.rim_tint = 0.35
			_body_mat.emission_enabled = true
			_body_mat.emission = Color.BLACK
			_mesh.set_surface_override_material(s, _body_mat)
	_view = SubViewport.new()
	_view.size = Vector2i(320, 240)
	_view.transparent_bg = false
	_view.disable_3d = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_face = SigilFace.new()
	_face.size = Vector2(320, 240)
	_face.caption = ""
	_view.add_child(_face)
	add_child(_view)
	if _crt_mat != null:
		_crt_mat.set_shader_parameter(&"face", _view.get_texture())
	_halo_mat = ShaderMaterial.new()
	_halo_mat.shader = HALO_SHADER


## each weak point's and the screen's marker: which bone it rides and where on it
func _build_marks() -> void:
	var names: Array[String] = []
	for i in POINT_AT.size():
		names.append_array(["wp_%d" % i, "wpn_%d" % i])
	names.append_array(["crt", "crtn"])
	for n in names:
		var node := _scene.find_child(n, true, false) as Node3D
		var off := Transform3D()
		var bone := 0
		var p: Node = node
		while p != null and p != _skel:      # (glTF children of a joint come in under a BoneAttachment3D)
			if p is BoneAttachment3D:
				bone = _b.get((p as BoneAttachment3D).bone_name, 0)
				break
			off = (p as Node3D).transform * off
			p = p.get_parent()
		_marks.append([bone, off])
	# the armour's hinges, in the head bone's space: the top plate turns about the head's right, the cheeks about its up
	var hb: int = _b[&"head"]
	var hg := _skel.get_bone_global_rest(hb)
	var fwd := ((_mark_rest(POINT_AT.size() * 2 + 1) - _mark_rest(POINT_AT.size() * 2))).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var up := right.cross(fwd).normalized()
	_hinge[&"shell_t"] = hg.basis.inverse() * right
	_hinge[&"shell_L"] = hg.basis.inverse() * up
	_hinge[&"shell_R"] = hg.basis.inverse() * -up


func _mark_rest(k: int) -> Vector3:
	return (_skel.get_bone_global_rest(_marks[k][0]) * (_marks[k][1] as Transform3D)).origin


func _mark(k: int) -> Vector3:
	return (_skel.get_bone_global_pose(_marks[k][0]) * (_marks[k][1] as Transform3D)).origin


func _build_tree() -> void:
	var ap := _scene.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var lib := ap.get_animation_library(&"")
	for n in lib.get_animation_list():
		var a := lib.get_animation(n)
		_len[n] = a.length
		a.loop_mode = Animation.LOOP_LINEAR if n in [&"idle", &"run", &"wall_run", &"climb", &"grab", &"fall", &"idle_low", &"run_low"] else Animation.LOOP_NONE
	ap.active = false
	_tree = AnimationTree.new()
	_tree.name = "Tree"
	_scene.add_child(_tree)
	_tree.root_node = NodePath("..")
	_tree.add_animation_library(&"", lib)
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var path_of := {}      # bone -> the track path the clips use for it
	var idle := lib.get_animation(&"idle")
	for t in idle.get_track_count():
		var p := idle.track_get_path(t)
		path_of[StringName(p.get_concatenated_subnames())] = p
	var bt := AnimationNodeBlendTree.new()
	var x := 0.0
	var anim := func(n: StringName) -> StringName:
		var a := AnimationNodeAnimation.new()
		a.animation = n
		bt.add_node(StringName("a_" + n), a, Vector2(0, x))
		x += 80.0
		return StringName("a_" + n)
	var seek := func(n: StringName) -> StringName:
		var s := AnimationNodeTimeSeek.new()
		bt.add_node(StringName("sk_" + n), s, Vector2(200, x))
		bt.connect_node(StringName("sk_" + n), 0, anim.call(n))
		return StringName("sk_" + n)
	var filt := func(node: AnimationNode, pred: Callable) -> void:
		node.filter_enabled = true
		for bn: StringName in path_of:
			if pred.call(String(bn)):
				node.set_filter_path(path_of[bn], true)
	var upper := func(b: String) -> bool:
		return b.begins_with("neck") or b == "head" or b == "body_0" or b == "body_1" or b.begins_with("arm_")
	# locomotion: idle .. run by stride, the run's speed by stride too
	var ts := AnimationNodeTimeScale.new()
	bt.add_node(&"ts_run", ts, Vector2(200, 0))
	bt.connect_node(&"ts_run", 0, anim.call(&"run"))
	var loco := AnimationNodeBlend2.new()
	bt.add_node(&"loco", loco, Vector2(400, 0))
	bt.connect_node(&"loco", 0, anim.call(&"idle"))
	bt.connect_node(&"loco", 1, &"ts_run")
	# the same crouched low and narrow, blended in by fit_h / fit_w (kept in step with the free run: same length, same speed, synced)
	var ts2 := AnimationNodeTimeScale.new()
	bt.add_node(&"ts_run_low", ts2, Vector2(200, 100))
	bt.connect_node(&"ts_run_low", 0, anim.call(&"run_low"))
	var loco2 := AnimationNodeBlend2.new()
	loco2.sync = true
	bt.add_node(&"loco_low", loco2, Vector2(400, 100))
	bt.connect_node(&"loco_low", 0, anim.call(&"idle_low"))
	bt.connect_node(&"loco_low", 1, &"ts_run_low")
	loco.sync = true
	var tb := AnimationNodeBlend2.new()
	tb.sync = true
	bt.add_node(&"tight_b", tb, Vector2(500, 0))
	bt.connect_node(&"tight_b", 0, &"loco")
	bt.connect_node(&"tight_b", 1, &"loco_low")
	# its whole-body states
	var st := AnimationNodeTransition.new()
	st.input_count = STATES.size()
	for i in STATES.size():
		st.set_input_name(i, STATES[i])
	st.xfade_time = 0.35
	bt.add_node(&"state", st, Vector2(600, 0))
	bt.connect_node(&"state", 0, &"tight_b")
	bt.connect_node(&"state", 1, anim.call(&"climb"))
	bt.connect_node(&"state", 2, anim.call(&"wall_run"))
	bt.connect_node(&"state", 3, anim.call(&"grab"))
	bt.connect_node(&"state", 4, anim.call(&"fall"))
	bt.connect_node(&"state", 5, anim.call(&"defeat"))
	# the swing: the front rears (body, neck, front legs), and each arm swings its own clip
	var rear := AnimationNodeBlend2.new()
	filt.call(rear, func(b: String) -> bool: return b.begins_with("body_") or b.begins_with("neck") or b == "head" or b.begins_with("leg_0_") or b.begins_with("leg_1_"))
	bt.add_node(&"rear_b", rear, Vector2(800, 0))
	bt.connect_node(&"rear_b", 0, &"state")
	bt.connect_node(&"rear_b", 1, seek.call(&"rear"))
	var prev := &"rear_b"
	for side: String in ["l", "r"]:
		var b2 := AnimationNodeBlend2.new()
		var arm := "arm_" + side.to_upper() + "_"
		filt.call(b2, func(b: String) -> bool: return b.begins_with(arm))
		var nm := StringName("sw" + side + "_b")
		bt.add_node(nm, b2, Vector2(1000, 0))
		bt.connect_node(nm, 0, prev)
		var mix := AnimationNodeBlend2.new()      # the free swing or the crouched one
		var mn := StringName("swmix_" + side)
		bt.add_node(mn, mix, Vector2(900, 0))
		bt.connect_node(mn, 0, seek.call(StringName("swipe_" + side)))
		bt.connect_node(mn, 1, seek.call(StringName("swipe_" + side + "_low")))
		bt.connect_node(nm, 1, mn)
		prev = nm
	var sb := AnimationNodeBlend2.new()
	filt.call(sb, func(b: String) -> bool: return b.begins_with("neck") or b == "head" or b == "body_0" or b == "body_1" or b.begins_with("leg_0_"))
	bt.add_node(&"strike_b", sb, Vector2(1200, 0))
	bt.connect_node(&"strike_b", 0, prev)
	bt.connect_node(&"strike_b", 1, seek.call(&"strike"))
	# one-shots: upper-body ones over a running body, whole-body ones over everything
	var ups: Array[StringName] = UPPER_SHOTS.duplicate()
	ups.append(&"roar_low")
	var up_pick := AnimationNodeTransition.new()
	up_pick.input_count = ups.size()
	for i in ups.size():
		up_pick.set_input_name(i, ups[i])
	bt.add_node(&"up_pick", up_pick, Vector2(1200, 300))
	for i in ups.size():
		bt.connect_node(&"up_pick", i, anim.call(ups[i]))
	var shot_up := AnimationNodeOneShot.new()
	shot_up.fadein_time = 0.12
	shot_up.fadeout_time = 0.3
	filt.call(shot_up, upper)
	bt.add_node(&"shot_up", shot_up, Vector2(1400, 0))
	bt.connect_node(&"shot_up", 0, &"strike_b")
	bt.connect_node(&"shot_up", 1, &"up_pick")
	var full_pick := AnimationNodeTransition.new()
	full_pick.input_count = FULL_SHOTS.size()
	for i in FULL_SHOTS.size():
		full_pick.set_input_name(i, FULL_SHOTS[i])
	bt.add_node(&"full_pick", full_pick, Vector2(1400, 300))
	for i in FULL_SHOTS.size():
		bt.connect_node(&"full_pick", i, anim.call(FULL_SHOTS[i]))
	var shot_full := AnimationNodeOneShot.new()
	shot_full.fadein_time = 0.1
	shot_full.fadeout_time = 0.35
	bt.add_node(&"shot_full", shot_full, Vector2(1600, 0))
	bt.connect_node(&"shot_full", 0, &"shot_up")
	bt.connect_node(&"shot_full", 1, &"full_pick")
	bt.connect_node(&"output", 0, &"shot_full")
	_tree.tree_root = bt
	_tree.active = true


func _build_lights() -> void:
	# soft cool fill from above and in front, so the enamel reads in the tunnels (no shadows: the level's own lights do that); the screens and the set are its only glow
	for q: Vector3 in [Vector3(-6.0, 12.0, 6.0), Vector3(6.0, 12.0, 6.0), Vector3(0.0, 1.5, 9.0)]:      # (the low one lights its belly and chest, which is what you see when it rears or grabs the car)
		var l := OmniLight3D.new()
		l.position = q
		l.light_color = Color(0.78, 0.86, 1.0)
		l.light_energy = 2.2 if q.y > 5.0 else 1.4
		l.omni_range = 24.0
		l.omni_attenuation = 1.1
		l.light_specular = 0.6
		add_child(l)
	_crt_light = OmniLight3D.new()
	_crt_light.omni_range = 9.0
	_crt_light.light_energy = 2.0
	add_child(_crt_light)
	_armed_light = OmniLight3D.new()
	_armed_light.light_color = AMBER
	_armed_light.omni_range = 12.0
	_armed_light.light_energy = 0.0
	add_child(_armed_light)
	# the red of a scythe about to cross the car (2026-11-15: the fight has two colours, amber to shoot and red to get out of the way of): a hot strip along each blade and its light on the deck,
	# riding the blade's bone
	for nm: StringName in [&"arm_L_2", &"arm_R_2"]:
		var ba := BoneAttachment3D.new()
		ba.bone_name = nm
		_skel.add_child(ba)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.06, 0.03)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.05, 0.02)
		m.emission_energy_multiplier = 0.0
		var bm := BoxMesh.new()
		bm.size = Vector3(0.34, 4.4, 0.5)
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = m
		mi.position = Vector3(0.0, 2.3, 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		ba.add_child(mi)
		var rl := OmniLight3D.new()
		rl.light_color = Color(1.0, 0.1, 0.05)
		rl.omni_range = 22.0
		rl.light_energy = 0.0
		rl.position = Vector3(0.0, 3.0, 0.0)
		ba.add_child(rl)
		_red_mats.append(m)
		_red_lights.append(rl)
		_red_nodes.append(mi)
	_burn_light = OmniLight3D.new()
	_burn_light.light_color = Color(1.0, 0.45, 0.12)
	_burn_light.omni_range = 16.0
	_burn_light.light_energy = 0.0
	_burn_light.position = Vector3(0.0, 6.0, -4.0)
	add_child(_burn_light)


func _build_shadow() -> void:
	# a soft dark blot under it, so it stands on the ground it runs on (cheap: one decal)
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.85))
	g.set_color(1, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = Vector3(15.0, 14.0, 26.0)
	d.position = Vector3(0.0, 4.0, -6.5)
	d.upper_fade = 0.2
	d.lower_fade = 0.3
	d.albedo_mix = 1.0
	d.modulate = Color(1, 1, 1, 0.8)
	add_child(d)


## How many feet it has (foot_local)
func foot_count() -> int:
	if _feet.is_empty():
		for k in 5:
			for sd: String in ["L", "R"]:
				var i := _skel.find_bone("leg_%d_%s_1" % [k, sd])
				if i < 0:
					continue
				var g := _skel.get_bone_global_rest(i)
				_feet.append(i)
				_shin.append(g.origin.y / maxf(0.2, -g.basis.y.y))      # (at rest the shin runs from the knee down to the ground)
	return _feet.size()


## Foot k's tip in this node's space, as it is posed now: y is its height off whatever it stands on (the floor, or the wall or roof it is rolled onto). The fight reads these to put dust, sparks
## and grit under each foot as it comes down (levels/underfoint/uf_chase.gd _tick_feet).
func foot_local(k: int) -> Vector3:
	return _sk * (_skel.get_bone_global_pose(_feet[k]) * Vector3(0.0, _shin[k], 0.0))


## where weak point i is in the world: what the fight aims its target at
func point_world(i: int) -> Vector3:
	return _skel.global_transform * _mark(i * 2)


## the television's glass, in the world
func crt_world() -> Vector3:
	return _skel.global_transform * _mark(POINT_AT.size() * 2)


## one of the one-shot clips: roar, lunge, hit (upper body, the legs keep going), reel, land (whole body). Crouched to fit (fit_h / fit_w) it roars low, and the others, which would lift it
## back out of its crouch, are left out
func play(clip: StringName) -> void:
	var room := _want()      # (by the room it is given, not the eased crouch: a roar on the frame it came out under a low roof stood up through it)
	if clip == &"roar" and maxf(room.y, _tight_sw) > 0.3:
		clip = &"roar_low"
	elif clip != &"roar" and clip != &"defeat" and maxf(room.x, _tight) > 0.3:
		return
	if clip in UPPER_SHOTS or clip == &"roar_low":
		_tree.set(&"parameters/up_pick/transition_request", String(clip))
		_tree.set(&"parameters/shot_up/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	elif clip in FULL_SHOTS:
		_tree.set(&"parameters/full_pick/transition_request", String(clip))
		_tree.set(&"parameters/shot_full/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	elif clip == &"defeat":
		state = &"defeat"
	_shot_cd = 0.4


func update(dt: float) -> void:
	for k in 2:      # the red blades (see _build_lights)
		var rv := red_l if k == 0 else red_r
		_red_nodes[k].visible = rv > 0.01
		if rv > 0.01:
			var pulse := 0.75 + 0.25 * sin(_t * 26.0)
			_red_mats[k].emission_energy_multiplier = 8.0 * rv * pulse
			_red_lights[k].light_energy = 14.0 * rv * pulse      # (5: the blade is held high, out of a level view, and its light on the car is what is seen: the whole deck goes red)
		else:
			_red_lights[k].light_energy = 0.0
	_burn_light.light_energy = (2.6 + 0.9 * sin(_t * 17.0) * sin(_t * 7.3)) if burning else 0.0
	_t += dt
	_shot_cd -= dt
	flash = maxf(0.0, flash - dt * 5.0)
	if flash > _flash_was + 0.5 and _shot_cd <= 0.0:      # a fresh hit: it flinches
		play(&"hit")
	_flash_was = flash
	# the clips
	var s := clampf(stride, 0.0, 1.0)
	var room := _want()
	var want_t := room.x
	var want_s := room.y
	if not _shown:      # its first frame out (or back in view): straight into the crouch its room needs
		_tight = want_t
		_tight_sw = want_s
	_shown = is_visible_in_tree()
	_tight = move_toward(_tight, want_t, dt * (3.0 if want_t > _tight else 1.0))      # (it ducks quicker than it rises: at 1.2 a lower roof came before it was down)
	_tight_sw = move_toward(_tight_sw, want_s, dt * (3.0 if want_s > _tight_sw else 1.0))
	var lb := smoothstep(0.0, 0.3, s)
	var rs := lerpf(0.5, 1.25, s) * (1.0 + 0.12 * rage)
	_tree.set(&"parameters/loco/blend_amount", lb)
	_tree.set(&"parameters/loco_low/blend_amount", lb)
	_tree.set(&"parameters/ts_run/scale", rs)
	_tree.set(&"parameters/ts_run_low/scale", rs)
	_tree.set(&"parameters/tight_b/blend_amount", _tight)
	_tree.set(&"parameters/swmix_l/blend_amount", _tight_sw)
	_tree.set(&"parameters/swmix_r/blend_amount", _tight_sw)
	if state != _state_was and state in STATES:
		_tree.set(&"parameters/state/transition_request", String(state))
		_state_was = state
	var sw := maxf(slash_l, slash_r)
	_tree.set(&"parameters/rear_b/blend_amount", smoothstep(0.0, 0.06, sw) * (1.0 - smoothstep(0.96, 1.0, sw)) * (1.0 - _tight))      # (crouched, it strikes from the crouch: its screens face forward there already)
	_tree.set(&"parameters/sk_rear/seek_request", sw * _len.get(&"rear", 1.0))
	_tree.set(&"parameters/swl_b/blend_amount", smoothstep(0.0, 0.04, slash_l))
	_tree.set(&"parameters/sk_swipe_l/seek_request", slash_l * _len.get(&"swipe_l", 1.0))
	_tree.set(&"parameters/sk_swipe_l_low/seek_request", slash_l * _len.get(&"swipe_l_low", 1.0))
	_tree.set(&"parameters/swr_b/blend_amount", smoothstep(0.0, 0.04, slash_r))
	_tree.set(&"parameters/sk_swipe_r/seek_request", slash_r * _len.get(&"swipe_r", 1.0))
	_tree.set(&"parameters/sk_swipe_r_low/seek_request", slash_r * _len.get(&"swipe_r_low", 1.0))
	_tree.set(&"parameters/strike_b/blend_amount", smoothstep(0.0, 0.08, strike) * (1.0 - _tight))      # (the strike throws the neck up off its crouch; crouched, the neck is already out low over the car)
	_tree.set(&"parameters/sk_strike/seek_request", clampf(strike, 0.0, 1.0) * _len.get(&"strike", 1.0))
	_tree.advance(dt)
	# on top of the clips: the sway, the head watching Prog, the armour, the plates
	var up_s := Vector3.UP
	if absf(sway) > 0.001:
		_turn(_b[&"body_0"], up_s, sway * 0.18)
		_turn(_b[&"neck_0"], up_s, sway * 0.16)
		_turn(_b[&"neck_1"], up_s, sway * 0.12)
	_track(dt)
	var want := (1.0 if crt_armed else 0.0) if crt_open < 0.0 else crt_open
	_open = move_toward(_open, want, dt * 1.6)
	if _open > 0.001:
		var e := _open * _open * (3.0 - 2.0 * _open)
		var hb: Basis = _skel.get_bone_global_pose(_b[&"head"]).basis
		_turn(_b[&"shell_t"], hb * _hinge[&"shell_t"], 1.15 * e)
		_turn(_b[&"shell_L"], hb * _hinge[&"shell_L"], 1.05 * e)
		_turn(_b[&"shell_R"], hb * _hinge[&"shell_R"], 1.05 * e)
	else:
		for n: StringName in [&"shell_t", &"shell_L", &"shell_R"]:
			_skel.set_bone_pose_rotation(_b[n], _skel.get_bone_rest(_b[n]).basis.get_rotation_quaternion())
	while _torn < clampi(damage, 0, TEAR.size()):
		for n: StringName in TEAR[_torn]:
			_tear(n)
		_torn += 1
	_update_debris(dt)
	# the screens
	var blink := 1.0 if fmod(_t * blink_rate, 1.0) < 0.55 else 0.0
	var armed := 0
	var armed_at := Vector3.ZERO
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	for i in POINT_AT.size():
		var ps := point_state[i]
		_states[i] = float(ps)
		var h := _halos[i]
		h.visible = ps == ARMED and visible
		if ps == ARMED:
			var w := _mark(i * 2)
			var n := (_mark(i * 2 + 1) - w).normalized()
			armed += 1
			armed_at += w
			_place_halo(h, w + n * 0.45, cam, 3.2 if blink > 0.5 else 1.3)
		if ps == BROKEN and _was_broken[i] == 0 and is_inside_tree():      # it has just been shot out: a burst from the glass
			Game.fx.sparks(point_world(i), 26, 9.0, (_skel.global_transform.basis * (_mark(i * 2 + 1) - _mark(i * 2))).normalized())
		_was_broken[i] = 1 if ps == BROKEN else 0
	_glass_mat.set_shader_parameter(&"state", _states)
	_glass_mat.set_shader_parameter(&"blink", blink)
	_glass_mat.set_shader_parameter(&"rage", rage)
	_glass_mat.set_shader_parameter(&"flash", flash)
	# the broken ones go on spitting now and then
	_spark_cd -= dt
	if _spark_cd <= 0.0 and is_inside_tree() and visible:
		_spark_cd = randf_range(0.25, 0.9)
		var broken: Array[int] = []
		for i in POINT_AT.size():
			if point_state[i] == BROKEN:
				broken.append(i)
		if not broken.is_empty():
			var i: int = broken.pick_random()
			Game.fx.sparks(point_world(i), 5, 5.0)
	_armed_light.light_energy = (2.5 * blink + 0.5) if armed > 0 else 0.0
	if armed > 0:
		_armed_light.position = _sk * ((armed_at / armed))
	# the face
	_face.tint = AMBER if angry or crt_armed else GREEN
	_face.speaking = speaking
	var ce := ((5.0 if blink > 0.5 else 0.9) if crt_armed else 1.5 + rage * 0.5)      # (2.6 burned the set to a white box in the tunnels)
	_crt_mat.set_shader_parameter(&"energy", ce)
	_crt_mat.set_shader_parameter(&"flash", flash)
	var cw := _mark(POINT_AT.size() * 2)
	var cn := (_mark(POINT_AT.size() * 2 + 1) - cw).normalized()
	_crt_light.position = _sk * ((cw + cn * 1.2))
	_crt_light.light_color = _face.tint
	_crt_light.light_energy = ce * 0.8
	var ch := _halos[POINT_AT.size()]
	ch.visible = crt_armed and visible
	if crt_armed:
		_place_halo(ch, cw + cn * 0.5, cam, 3.0 if blink > 0.5 else 1.0)
	_body_mat.emission = Color(1.0, 0.55, 0.15) * flash * 0.6


## how far into its tight clips the room it is given puts it: x for its body, y for its swings and roar (which reach higher)
func _want() -> Vector2:
	var tw := clampf((W_FREE - fit_w) / (W_FREE - W_LOW), 0.0, 1.0)
	var th := clampf((H_FREE - fit_h) / (H_FREE - H_LOW), 0.0, 1.0)
	var tsw := clampf((H_SWING - fit_h) / (H_SWING - H_LOW), 0.0, 1.0)
	return Vector2(maxf(th, tw), maxf(tsw, tw))


## a halo sprite on a weak point, in this node's space, sized so it still reads far off
func _place_halo(h: MeshInstance3D, at_skel: Vector3, cam: Camera3D, glow: float) -> void:
	var at := _sk * (at_skel)
	h.position = at
	var size := 2.4
	if cam != null:
		size = maxf(2.4, cam.global_position.distance_to(global_transform * at) * 0.03)
	h.scale = Vector3.ONE * size
	h.set_instance_shader_parameter(&"glow", glow)


## turn a bone about an axis given in the skeleton's space, on top of its pose
func _turn(bone: int, axis: Vector3, angle: float) -> void:
	var g := _skel.get_bone_global_pose(bone)
	var p := _skel.get_bone_parent(bone)
	var pb := _skel.get_bone_global_pose(p).basis if p >= 0 else Basis()
	var nb := Basis(axis.normalized(), angle) * g.basis.orthonormalized()
	_skel.set_bone_pose_rotation(bone, (pb.orthonormalized().inverse() * nb).get_rotation_quaternion())


## the head turned to watch Prog (or look_target), part in the last neck bone, within reach, eased
func _track(dt: float) -> void:
	if not is_inside_tree() or look_weight <= 0.0 or state == &"defeat":
		_look = _look.slerp(Quaternion.IDENTITY, minf(1.0, dt * 4.0))
	else:
		var tgt := look_target
		if tgt == Vector3.INF:
			var pl := Game.player
			tgt = Vector3(pl.x, pl.y + 1.4, pl.z) if pl != null else global_position + global_basis.z * 20.0
		var to_s := _skel.global_transform.affine_inverse() * tgt
		var c := _mark(POINT_AT.size() * 2)
		var f := (_mark(POINT_AT.size() * 2 + 1) - c).normalized()
		var d := (to_s - c).normalized()
		var q := Quaternion(f, d) if f.dot(d) > -0.95 else Quaternion.IDENTITY
		var ang := q.get_angle()
		var lim := 0.9
		if ang > lim:
			q = Quaternion.IDENTITY.slerp(q, lim / ang)
		q = Quaternion.IDENTITY.slerp(q, look_weight)
		_look = _look.slerp(q, minf(1.0, dt * 5.0))
	if _look.get_angle() < 0.001:
		return
	var axis := _look.get_axis()
	var ang2 := _look.get_angle()
	_turn(_b[&"neck_4"], axis, ang2 * 0.35)
	_turn(_b[&"head"], axis, ang2 * 0.65)


## tear a plate off: its bone is scaled away and a copy of it tumbles off the body
func _tear(plate: StringName) -> void:
	var bi: int = _b.get(plate, -1)
	if bi < 0:
		return
	var g := _skel.get_bone_global_pose(bi)
	_skel.set_bone_pose_scale(bi, Vector3.ONE * 0.001)
	if not is_inside_tree():
		return
	var m := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(2.6, 0.14, 2.4) if String(plate).begins_with("plate_b") else Vector3(0.14, 1.4, 2.6)
	m.mesh = bx
	m.material_override = _body_mat
	get_parent().add_child(m)
	m.global_transform = _skel.global_transform * g
	var out := (m.global_position - global_position)
	out.y = 0.0
	var vel := out.normalized() * 6.0 + Vector3.UP * 9.0 - global_basis.z * 14.0
	_debris.append([m, vel, Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4)), 2.5])
	Game.fx.sparks(m.global_position, 30, 10.0)
	Game.fx.shake = maxf(Game.fx.shake, 0.4)


func _update_debris(dt: float) -> void:
	for i in range(_debris.size() - 1, -1, -1):
		var d: Array = _debris[i]
		var m: MeshInstance3D = d[0]
		d[1] = (d[1] as Vector3) + Vector3.DOWN * 22.0 * dt
		m.global_position += (d[1] as Vector3) * dt
		var sp: Vector3 = d[2]
		m.rotate(sp.normalized(), sp.length() * dt)
		d[3] = float(d[3]) - dt
		if float(d[3]) <= 0.0:
			m.queue_free()
			_debris.remove_at(i)


func _exit_tree() -> void:
	for d: Array in _debris:
		(d[0] as Node).queue_free()
	_debris.clear()
