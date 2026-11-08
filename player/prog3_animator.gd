## Prog V3's animator: plays the moves authored on his rebuilt body (assets/prog3) from the player's state, in place of the procedural layers. Cutscene poses, seats and machine work still go through the old Animator code.
class_name Prog3Animator
extends Animator

const ASSET := "res://assets/prog3/"
const WPN := "res://assets/weapons/"
const FPS := 24.0
const FADE := 0.14                     # seconds to cross from one move to the next
const WALK_MAX := 2.1                  # m/s where a walk becomes a run
# metres one full cycle of each gait covers: the clip plays at speed / this, so a planted foot stays planted
const STRIDE := {"walk": 1.5, "run": 2.6, "sprint": 3.4, "strafe": 2.7, "backstep": 1.15, "creep": 1.0, "tired": 1.0}
# these clips were authored with him going up or over something: the game moves him, so only the dips stay (a crouch before a jump, a landing)
const STRIP := ["jump", "running_jump", "double_jump", "flip_left", "flip_right", "flip_back", "fall_and_land", "hammer_fist", "ledge_hang", "ledge_climb", "ladder_climb", "swim_tread", "swim_crawl", "pole_swing", "wall_run"]

static var _scene: PackedScene = null
static var _mesh: ArrayMesh = null
static var _skin: Skin = null
static var _clips: Dictionary = {}     # clip name -> Animation
static var _data: Dictionary = {}      # prog3_moves.json

class Layer:
	var name := ""
	var anim: Animation
	var t := 0.0
	var w := 0.0
	var strip := false
	var fade := FADE
	var tracks: Dictionary = {}        # bone -> [rotation track, position track], -1 where the clip has none

var _layers: Array[Layer] = []
var _upper: Layer = null
var _w_upper := 0.0
var _upper_arms_only := false
var _upper_held: Layer = null          # stays on while the reload or air hold fades out
var _upper_arms_held := false
var _track_cache: Dictionary = {}      # clip -> tracks
var _anim_bones: Array[int] = []
var _rest_q: Dictionary = {}
var _rest_p: Dictionary = {}
var _is_upper: Dictionary = {}         # spine and up
var _is_arm: Dictionary = {}           # shoulders, arms, hands
var _hand_r := -1
var _hand_l := -1
var _gait_ph := 0.0
var _rl_was := false
var _rl_t := 0.0
var _dead_t := 0.0
var _lift := 0.0
var _gun_id := ""
var _part_nodes: Dictionary = {}
var _gun_l: Node3D = null
var _gun_l_rest := Transform3D.IDENTITY
var _w_aim2 := 0.0
var _fallback := false


## The model and moves are shared by every copy of him: his 24 meshes folded into one per material the first time, and the bones named as the rest of the game knows them.
static func _old_name(n: String) -> String:
	if n == "spine_1":
		return "spine1"
	if n == "spine_2":
		return "spine2"
	for f: String in ["thumb", "index", "middle", "ring", "pinky"]:
		for j in range(1, 4):
			if n.begins_with("%s_%d." % [f, j]):
				return "%s_0%d.%s" % [f, j, n.substr(n.length() - 1)]
	return n


static func _merge(src: Node) -> void:
	var by_mat: Dictionary = {}
	for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		if _skin == null:
			_skin = mi.skin.duplicate() if mi.skin != null else null
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if not by_mat.has(mat):
				by_mat[mat] = []
			by_mat[mat].append(mi.mesh.surface_get_arrays(s))
	_mesh = ArrayMesh.new()
	for mat: Material in by_mat:
		var merged: Array = []
		merged.resize(Mesh.ARRAY_MAX)
		var base := 0
		for arr: Array in by_mat[mat]:
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
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, merged, [], {}, flags)
		_mesh.surface_set_material(_mesh.get_surface_count() - 1, mat)
	if _skin != null:
		for i in _skin.get_bind_count():
			_skin.set_bind_name(i, StringName(_old_name(String(_skin.get_bind_name(i)))))


static func _load_shared() -> void:
	if _scene != null:
		return
	_scene = load(ASSET + "prog3.glb")
	var first := _scene.instantiate()
	_merge(first)
	first.free()
	_data = JSON.parse_string(FileAccess.get_file_as_string(ASSET + "prog3_moves.json"))
	var moves: Node = (load(ASSET + "prog3_moves.glb") as PackedScene).instantiate()
	var src: AnimationPlayer = moves.find_children("*", "AnimationPlayer", true, false)[0]
	var lib: AnimationLibrary = src.get_animation_library(&"")
	for nm in lib.get_animation_list():
		_clips[String(nm)] = lib.get_animation(nm)
	moves.free()


static func _prepared() -> Node3D:
	_load_shared()
	var m: Node3D = _scene.instantiate()
	for ap: AnimationPlayer in m.find_children("*", "AnimationPlayer", true, false):
		ap.get_parent().remove_child(ap)
		ap.free()
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		mi.get_parent().remove_child(mi)
		mi.free()
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	for b in sk.get_bone_count():
		sk.set_bone_name(b, _old_name(sk.get_bone_name(b)))
	var mi := MeshInstance3D.new()
	mi.name = "prog3_body"
	mi.mesh = _mesh
	mi.skin = _skin
	sk.add_child(mi)
	mi.skeleton = mi.get_path_to(sk)
	return m


## Everywhere that makes the playable character goes through here: the old Animator for anyone but him.
static func create(B: Builds.Build) -> Animator:
	if not B.clips:
		return Animator.new((load(B.file) as PackedScene).instantiate(), B)
	return Prog3Animator.new(_prepared(), B)


func _init(gltf_scene: Node3D, build: Builds.Build = null) -> void:
	super(gltf_scene, build)
	_hand_r = _bone_of(&"hand", 1)
	_hand_l = _bone_of(&"hand", 0)
	var skip_face := ["jaw", "teeth", "tongue", "lip_", "mouth_"]
	for b in skel.get_bone_count():
		var n := skel.get_bone_name(b)
		var face := n.begins_with("hair")
		for f: String in skip_face:
			face = face or n.begins_with(f)
		if face:
			continue
		_anim_bones.append(b)
		var rx := skel.get_bone_rest(b)
		_rest_q[b] = rx.basis.get_rotation_quaternion()
		_rest_p[b] = rx.origin
		var up := false
		var arm := false
		var a := b
		while a >= 0:
			var an_ := skel.get_bone_name(a)
			if an_ == "spine1":
				up = true
			if an_.begins_with("clavicle"):
				arm = true
			a = skel.get_bone_parent(a)
		_is_upper[b] = up
		_is_arm[b] = arm


## His paint carries everything: the game's plain lambert on all of it. Not the old model's eye shader, whose self-lit whites glow in the dark on this face.
func _restyle(mi: MeshInstance3D) -> void:
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
		if m != null:
			mi.set_surface_override_material(i, _conv(m, (mi.mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR) != 0))


func _tracks_of(clip: String, anim: Animation) -> Dictionary:
	if _track_cache.has(clip):
		return _track_cache[clip]
	var out := {}
	for tr in anim.get_track_count():
		var path := str(anim.track_get_path(tr))
		var b := skel.find_bone(_old_name(path.substr(path.rfind(":") + 1)))
		if b < 0:
			continue
		if not out.has(b):
			out[b] = [-1, -1]
		if anim.track_get_type(tr) == Animation.TYPE_ROTATION_3D:
			out[b][0] = tr
		elif anim.track_get_type(tr) == Animation.TYPE_POSITION_3D:
			out[b][1] = tr
	_track_cache[clip] = out
	return out


func _layer_for(clip: String) -> Layer:
	var l := Layer.new()
	l.name = clip
	l.anim = _clips[clip]
	l.tracks = _tracks_of(clip, l.anim)
	l.strip = STRIP.has(clip)
	return l


## Crosses to `clip` unless it is already the one on top
func _want(clip: String, fade: float = FADE) -> Layer:
	if not _clips.has(clip):
		clip = "idle"
	var top: Layer = _layers.back() if not _layers.is_empty() else null
	if top != null and top.name == clip:
		return top
	var l := _layer_for(clip)
	if _layers.is_empty() or fade <= 0.0:
		l.w = 1.0
		_layers = [l]
		return l
	l.fade = 0.3 if (clip == "idle" or clip.ends_with("_idle")) else fade
	_layers.append(l)
	return l


func _gait(clip: String, kind: String, speed: float, dt: float) -> void:
	_gait_ph = fmod(_gait_ph + dt * minf(speed / float(STRIDE[kind]), 3.4), 1.0)
	_want(clip)


func _timed(clip: String, dt: float) -> void:
	var l := _want(clip)
	l.t = fmod(l.t + dt, maxf(l.anim.length, 0.001))


func _seek(clip: String, t_: float) -> void:
	_want(clip).t = t_


# ---- what he is doing, from the player's state ----
func _choose(dt: float, P: Player, gun: String, show: bool) -> void:
	var sp := U.hyp(P.vx, P.vz)
	var sy := sin(P.yaw)
	var cy := cos(P.yaw)
	var lvf := P.vx * sy + P.vz * cy
	var lvs := P.vx * cy - P.vz * sy
	var tired := P.max_hp != 0.0 and not P.dead and P.hp / P.max_hp <= 0.25
	_upper = null
	_upper_arms_only = false
	if P.dead:
		_dead_t += dt
		_seek("death", minf(_dead_t, _clips["death"].length))
		return
	_dead_t = 0.0
	if P.mode == &"hang":
		_timed("ledge_hang", dt)
		return
	if P.mode == &"pull":
		_seek("ledge_climb", clampf(P.mode_t / Config.pull_time, 0.0, 1.0) * _clips["ledge_climb"].length)
		return
	if P.mode == &"pole":
		_timed("pole_swing", dt)
		return
	if P.mode == &"swim":
		_timed("swim_crawl" if sp > 0.5 else "swim_tread", dt)
		return
	if P.mode == &"ladder":
		_seek("ladder_climb", fmod(P.lad_ph, 1.0) * _clips["ladder_climb"].length)
		return
	var armed_suffix := "aim" if P.aiming else "carry"
	var held := show and gun != ""
	if P.wall_run != null:
		_gait("wall_run", "run", sp, dt)
		_want("wall_run").t = _gait_ph * _clips["wall_run"].length
	elif P.flip >= 0.0:
		var c := "double_jump"
		var a := 0.86
		var b := 1.44
		if P.flip_type == &"back":
			c = "flip_back"
		elif P.flip_type == &"side_l":
			c = "flip_left"
		elif P.flip_type == &"side_r":
			c = "flip_right"
		if c != "double_jump":
			a = 0.26
			b = 1.12
		_seek(c, lerpf(a, b, P.flip - sin(TAU * P.flip) / TAU))      # (slow in, whipping through the middle, slow out: the old flip's own spin curve)
	elif gun == "flail" and held and FlailSim.FLAIL.on:
		_seek("flail_swing", minf(FlailSim.FLAIL.elapsed, _clips["flail_swing"].length))
	elif P.slamming:
		_seek("hammer_fist", 1.2 if P.slam_drop else lerpf(0.78, 1.1, P.slam_u))
		held = false
	elif P.punching:
		var st := clampi(P.punch_stage, 0, 2)
		var a2: float = [0.0, 0.34, 0.74][st]
		var b2: float = [0.34, 0.74, 1.25][st]
		_seek("punch_combo", lerpf(a2, b2, clampf(P.punch_u, 0.0, 1.0)))
		held = false
	elif not P.grounded:
		if P.vy > 0.0:
			_seek("jump", lerpf(0.5, 0.26, clampf(P.vy / 8.0, 0.0, 1.0)))
		else:
			_seek("fall_and_land", 0.3)
		if held:
			_upper = _layer_for("%s_%s_idle" % [gun, armed_suffix]) if _clips.has("%s_%s_idle" % [gun, armed_suffix]) else null
			_upper_arms_only = true
	elif P.land_t > 0.0 and sp < 2.0 and P.land_impact > 8.0:
		var lu := 1.0 - P.land_t / (P.land_dur if P.land_dur != 0.0 else 0.44)
		_seek("fall_and_land", lerpf(0.62, 1.6, lu))
		if held:
			_upper = _layer_for("%s_carry_idle" % gun) if _clips.has("%s_carry_idle" % gun) else null
			_upper_arms_only = true
	elif P.crouching:
		if sp > 0.15:
			_gait("crouch_walk", "creep", sp, dt)
		else:
			_seek("crouch", 0.9)
		if held:
			_upper = _layer_for("%s_%s_idle" % [gun, armed_suffix]) if _clips.has("%s_%s_idle" % [gun, armed_suffix]) else null
			_upper_arms_only = true
	elif sp < 0.15:
		if held and _clips.has("%s_%s_idle" % [gun, armed_suffix]):
			_seek("%s_%s_idle" % [gun, armed_suffix], 0.0)
		else:
			_timed("tired_idle" if tired else ("flail_carry_idle" if held and gun == "flail" else "idle"), dt)
	else:
		_locomotion(dt, P, gun if held else "", armed_suffix, sp, lvf, lvs, tired)
	# a reload works over whatever the legs are doing
	var rl := "%s_reload" % gun
	if held and P.rl_on and _clips.has(rl):
		var u := Layer.new()
		u = _layer_for(rl)
		_rl_t += dt * _clips[rl].length / maxf(P.rl_dur if P.rl_dur != 0.0 else 1.5, 0.05)
		u.t = minf(_rl_t, _clips[rl].length)
		_upper = u
		_upper_arms_only = false


func _locomotion(dt: float, P: Player, gun: String, st: String, sp: float, lvf: float, lvs: float, tired: bool) -> void:
	var sideways := absf(lvs) > absf(lvf) * 0.7
	var turned := P.strafing or P.aiming
	var side := "left" if lvs > 0.0 else "right"
	if gun != "" and gun != "flail":
		if st == "aim":
			if sideways:
				_gait("%s_aim_strafe_%s" % [gun, side], "strafe", sp, dt)
			elif lvf < -0.3:
				_gait("%s_aim_backpedal" % gun, "backstep", sp, dt)
			else:
				_gait("%s_aim_walk" % gun, "walk", sp, dt)
		elif turned and sideways:
			_gait("%s_carry_strafe_%s" % [gun, side], "strafe", sp, dt)
		elif sp < WALK_MAX:
			_gait("%s_carry_walk" % gun, "walk", sp, dt)
		else:
			_gait("%s_carry_run" % gun, "run", sp, dt)
		return
	if gun == "flail":
		if sp < WALK_MAX:
			_gait("flail_carry_walk", "walk", sp, dt)
		else:
			_gait("flail_carry_run", "run", sp, dt)
		return
	if tired:
		_gait("tired_walk", "tired", sp, dt)
	elif turned and sideways:
		_gait("strafe_%s" % side, "strafe", sp, dt)
	elif turned and lvf < -0.3:
		_gait("walk_backwards", "backstep", sp, dt)
	elif P.sprinting:
		_gait("sprint", "sprint", sp, dt)
	elif sp < WALK_MAX:
		_gait("walk", "walk", sp, dt)
	else:
		_gait("run", "run", sp, dt)


# ---- writing it onto the skeleton ----
func _write_pose(dt: float) -> void:
	var top: Layer = _layers.back()
	for l: Layer in _layers:
		if l == top:
			l.w = minf(1.0, l.w + dt / top.fade)
		else:
			l.w = maxf(0.0, l.w - dt / top.fade)
		if _is_gait(l.name):
			l.t = _gait_ph * l.anim.length
	while _layers.size() > 1 and _layers[0].w <= 0.0:
		_layers.remove_at(0)
	_w_upper = U.damp(_w_upper, 1.0 if _upper != null else 0.0, 9.0, dt)
	if _upper != null:
		_upper_held = _upper
		_upper_arms_held = _upper_arms_only
	elif _w_upper < 0.002:
		_upper_held = null
	for b: int in _anim_bones:
		var q: Quaternion = _rest_q[b]
		var p: Vector3 = _rest_p[b]
		var total := 0.0
		for l: Layer in _layers:
			if l.w <= 0.0:
				continue
			var lq: Quaternion = _rest_q[b]
			var lp: Vector3 = _rest_p[b]
			var tr: Array = l.tracks.get(b, [-1, -1])
			if tr[0] >= 0:
				lq = l.anim.rotation_track_interpolate(tr[0], l.t)
			if tr[1] >= 0:
				lp = l.anim.position_track_interpolate(tr[1], l.t)
				if l.strip:
					lp = Vector3(_rest_p[b].x, minf(lp.y, _rest_p[b].y), _rest_p[b].z)
			var ww := l.w * l.w * (3.0 - 2.0 * l.w)      # (eased both ends, or the start and stop of a blend read as a snap)
			if ww <= 0.0:
				continue
			total += ww
			q = lq if total == ww else q.slerp(lq, ww / total)
			p = lp if total == ww else p.lerp(lp, ww / total)
		if _upper_held != null and (_is_arm[b] if _upper_arms_held else _is_upper[b]):
			var ut: Array = _upper_held.tracks.get(b, [-1, -1])
			var uq: Quaternion = _rest_q[b]
			if ut[0] >= 0:
				uq = _upper_held.anim.rotation_track_interpolate(ut[0], _upper_held.t)
			q = q.slerp(uq, _w_upper)
		skel.set_bone_pose_rotation(b, q)
		skel.set_bone_pose_position(b, p)


func _is_gait(n: String) -> bool:
	return n.ends_with("_walk") or n.ends_with("_run") or n in ["walk", "run", "sprint", "walk_backwards", "strafe_left", "strafe_right", "wall_run"] or n.ends_with("_backpedal") or n.contains("_strafe_")


func _turn_bone(b: int, q_model: Quaternion) -> void:
	var par := skel.get_bone_parent(b)
	var pq := skel.get_bone_global_pose(par).basis.get_rotation_quaternion() if par >= 0 else Quaternion.IDENTITY
	skel.set_bone_pose_rotation(b, (pq.inverse() * q_model * pq * skel.get_bone_pose_rotation(b)).normalized())


## Aim up, down and off to the side comes from the spine, so the gun stays on the camera's line; a shot's kick goes through it too
func _aim_spine(P: Player, dt: float) -> void:
	_w_aim2 = U.damp(_w_aim2, 1.0 if P.aiming and P.armed else 0.0, 14.0, dt)
	var kp := wv.k.p if wv != null else 0.0
	var ang := (-P.aim_pitch * _w_aim2 - kp * 0.5) / 3.0
	var yaw := P.aim_yaw * _w_aim2 / 3.0
	if absf(ang) < 0.0005 and absf(yaw) < 0.0005:
		return
	var q := Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, ang)
	for k: StringName in [&"spine1", &"spine2", &"chest"]:
		var r: BoneRec = by_key.get(k)
		if r != null:
			_turn_bone(r.bone, q)


func _setup_gun(gun: String) -> void:
	if gun == _gun_id:
		return
	_gun_id = gun
	_part_nodes.clear()
	_gun_l = null
	if gun == "" or wv == null or wv.group == null:
		return
	var f := WPN + gun + ".json"
	if not FileAccess.file_exists(f):
		return
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(f))["info"]
	for k in ["mag", "rack", "spare", "hatch"]:
		var o: Variant = info.get(k)
		var nm := ""
		if o is Dictionary and k == "hatch":
			nm = o.get("object3d", "")
		elif o is Dictionary and o.get("obj") is Dictionary:
			nm = o["obj"].get("object3d", "")
		if nm != "":
			_part_nodes[k] = _node_ending(nm)
	if gun == "dual_silenced":
		_gun_l = _node_ending("gun_l")
		if _gun_l != null:
			_gun_l_rest = wv.group.global_transform.affine_inverse() * _gun_l.global_transform


func _node_ending(want: String) -> Node3D:
	for n: Node in wv.group.find_children("*", "Node3D", true, false):
		if String(n.name).ends_with(want):
			return n
	return null


static func _sock(s: Dictionary) -> Transform3D:
	var p: Array = s["pos"]
	var q: Array = s["quat"]
	var k := float(s["scale"])
	return Transform3D(Basis(Quaternion(q[0], q[1], q[2], q[3])).scaled(Vector3(k, k, k)), Vector3(p[0], p[1], p[2]))


## The gun rides his right hand at the socket measured when the hold was authored; WeaponView still runs its parts, flash and kick
func _place_gun(P: Player, dt: float, show: bool, gun: String) -> void:
	if wv == null:
		return
	wv.set_weapon(P.weapon_idx if P.armed else -1)
	wv.update(dt, show)
	w_arm = U.damp(w_arm, 1.0 if show else 0.0, 14.0, dt)
	if not wv.group.visible or wv.info == null or gun == "":
		return
	_setup_gun(gun)
	var guns: Dictionary = _data["guns"]
	if not guns.has(gun):
		return
	var states: Dictionary = guns[gun]
	var low: String = "low" if states.has("low") else String(states.keys()[0])
	var st: String = "aim" if (P.aiming and states.has("aim")) else low
	var base := actor.global_transform * _model_xf
	var k := wv.k
	var kick := Transform3D(Basis.from_euler(Vector3(-k.p, k.y, k.r)), Vector3(0.0, 0.0, -k.z))
	var sk := _sock(states[low]["r"])
	if states.has("aim"):
		sk = sk.interpolate_with(_sock(states["aim"]["r"]), _w_aim2)      # (between the holds the gun slides in his hand, never jumps)
	wv.group.global_transform = base * skel.get_bone_global_pose(_hand_r) * sk * kick
	if _gun_l != null and states[st].has("l"):
		_gun_l.global_transform = base * skel.get_bone_global_pose(_hand_l) * _sock(states[st]["l"]) * _gun_l_rest
	# a reload's magazine and bolt, as authored with his left hand
	if _upper != null and _upper.name.ends_with("_reload"):
		var parts: Dictionary = _data["clips"].get(_upper.name, {}).get("gun_parts", {})
		var fr := int(_upper.t * FPS)
		for part: String in parts:
			var n: Node3D = _part_nodes.get(part)
			if n != null:
				var v: Array = parts[part][mini(fr, parts[part].size() - 1)]
				n.global_transform = wv.group.global_transform * Transform3D(Basis(Quaternion(v[3], v[4], v[5], v[6])), Vector3(v[0], v[1], v[2]))


func update(dt: float, P: Player) -> void:
	# cutscenes, seats and machine work pose him through the old code until they get their own moves
	var fi := P.factory_interaction
	if pose_hook.is_valid() or seat != null or (fi != null and fi.weight > 0.01):
		_fallback = true
		super(dt, P)
		return
	if _fallback:
		_fallback = false
		_layers.clear()
	dt = minf(dt, 0.05)
	t += dt
	_dt = dt
	_P = P
	run = U.damp(run, clampf(U.hyp(P.vx, P.vz) / Config.run_speed, 0.0, 1.0), 12.0, dt)
	var normal := P.mode == &"normal"
	var show := P.armed and normal and not P.crouch_hide and not P.slamming and not P.scoped
	var gun := ""
	if P.armed and P.weapon_idx >= 0 and wv != null:
		gun = Weapons.WEAPONS[P.weapon_idx].id if Weapons.WEAPONS.size() > P.weapon_idx else ""
	if not P.rl_on:
		_rl_t = 0.0
	_choose(dt, P, gun, show)
	_write_pose(dt)
	_aim_spine(P, dt)
	# where the body is: the clips hold their own turns, so the actor only stands, turned to his yaw; a ledge or the water sets his height
	var pos := Vector3(P.x, P.y + B.pivot * B.scale, P.z)
	if P.mode == &"swim":
		pos.y = P.y + Config.swim_float - (0.36 if U.hyp(P.vx, P.vz) <= 0.5 else 0.0) * B.scale
	actor.position = pos
	actor.rotation = Vector3(0.0, P.yaw, 0.0)
	# the wall run was authored with the wall on his right: mirrored for one on his left
	model.scale.x = -1.0 if (P.wall_run != null and P.wall_run.side < 0) else 1.0
	# hanging: lifted so his hands really are on the lip
	var lift := 0.0
	if P.mode == &"hang" and P.ledge != null:
		_refresh_xf()
		var hy := maxf(bone_world_pos(_hand_l).y, bone_world_pos(_hand_r).y)
		lift = P.ledge.t + 0.03 - (hy - _lift)
	_lift = U.damp(_lift, lift, 30.0, dt)
	actor.position.y += _lift
	_refresh_xf()
	_place_gun(P, dt, show, gun)
