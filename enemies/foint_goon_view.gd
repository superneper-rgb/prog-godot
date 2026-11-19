class_name FointGoonView
extends RefCounted
## FOINT GOON view (JS enemies/foint-goon-view.js): the user's Meshy toads, one skinned mesh per costume on its own copy of the skeleton. No clips: every pose is built here from the AI state, after the character sheet:
##   idle      hunched, arms hanging, the gun pointing at the floor in the right hand
##   stand     two-handed aim (_two_hand: the gun where both short arms reach, clear of the belly; pistol: the left hand cups the fist; SMG: left on the magwell, stock folded; sprayer: left on the canister), recoil on every shot
##   crouch    down on the right knee, left foot planted forward, still aiming
##   moving    stepping feet (IK onto the ground, any direction: strafes and backpedals read right), hips bob, arms swing when not aiming
##   panic     (labcoat) arms up and flailing as he runs; a shaky one-hand pistol when cornered; reaching for the alarm panel
##   break     (R.on_break, set by a level: OMNISPHERE's pad dockhand) off duty: gun away, right fist on the hip, the left hand brings a cigarette up when R.drag rises
##   hurt      snapped away from the hit (spine, head, the aim knocked off line), sized by the damage; stagger = rocked back, arms thrown out
##   alive     every shot kicks the chest and head and climbs the muzzle; the aim breathes; standing, the weight drifts foot to foot
##   face      eyes, lids, brows, cheeks, jaw and throat by foint_goon_face.gd; off the player, the head follows the face's attention
##   point     the free hand points you out on first sight, and chops toward the post on a long move (R.signal_t)
##   reload    gun tipped up to the chest, left hand to the belt, up to the magwell, slap (R.reload_t / R.reload_dur)
##   dying     knocked back, gun flies out of the hand, left arm thrown up, then he falls flat on his back (the sheet's death pose: legs up, arms out)
## Arms and legs are posed by two-bone IK in the model's own space (+Z forward, +Y up, +X his left); spine / chest / head turn forward-kinematically. The JS asks three.js for world matrices all the time; here each goon keeps its own local / model-space pose (mq, mp, worked out on demand) and hands the local pose to the Skeleton3D at the end of the frame.
## The toads have short arms on a wide belly, so every hand target is first kept within reach and pushed out of the torso (a per-body outline sampled from the skin at load, followed through the spine / chest pose): hands rest on the body, never in it.
## The GOINT costumes reuse the security body; foint_goon_dress.gd recolours them and adds their pieces. Poses read R.role (the job), not the look.

const MODEL := "res://assets/npcs/foint-goon/model.glb"
const GOINT_BODY := {"goint_guard": "security", "goint_adjuster": "security", "goint_suit": "security", "goint_undertaker": "security", "goint_warden": "security",
	"crew": "security", "crew_hod": "security", "foreman": "security"}      # (the Pervert Palace's site crew: foint_goon_dress.gd CREW)
const HELMETED := {"goint_guard": 1, "goint_adjuster": 1}
const HELMET_DEATH := 1.1             # lying on his back in a pointed helmet: chin tucked, so the point clears the floor
const GRIP := Vector3(0.78, 0.045, 0.035)      # the gun's grip top in the right fist: along the hand (x its length), toward the palm, over the knuckles
const GRIP_CURL := 1.5
const UP := Vector3(0.0, 1.0, 0.0)
const PAD_DOWN := Vector3(0.0, -1.0, 0.0)
const BAR_SHADER := "res://enemies/goon_bar.gdshader"


## What every goon wearing one body shares: its bones at rest, the torso's outline, the re-weighted mesh (JS TORSO, the rehanded geometry).
class Body:
	var i: Dictionary = {}                     # bone name -> index
	var names: Array[StringName] = []
	var par := PackedInt32Array()
	var desc: Array[PackedInt32Array] = []     # each bone and all below it
	var rest_q: Array[Quaternion] = []
	var rest_p := PackedVector3Array()
	var rest_mq: Array[Quaternion] = []
	var rest_mp := PackedVector3Array()
	var rest_m: Array[Transform3D] = []
	var rest_mi: Array[Transform3D] = []
	var rest_dir := PackedVector3Array()
	var len_up := 0.0
	var len_fore := 0.0
	var len_hand := 0.0
	var len_thigh := 0.0
	var len_shin := 0.0
	var foot_y := 0.0
	var skin: Skin
	var mesh: ArrayMesh
	var mats: Array[Material] = []
	var back_z := 0.0                          # how far the skin reaches behind him at rest
	# the torso round the vertical: per 5 cm slice (y 0.45..1.3), a centre z and the skin's radius in 24 directions
	var t_cz := PackedFloat32Array()
	var t_r: Array[PackedFloat32Array] = []
	const T_Y0 := 0.45
	const T_DY := 0.05
	const T_NY := 18
	const T_NB := 24


static var _bodies: Dictionary = {}


static func _prep_material(src: Material) -> Material:
	var m := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
	var nm := src.resource_name
	if nm == "glass":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		var c := Color(0.82, 0.93, 1.0).linear_to_srgb()
		c.a = 0.16
		m.albedo_color = c
		m.roughness = 0.05
		m.metallic = 0.1
	elif nm == "band":
		m.metallic = 0.75
		m.roughness = 0.35
	elif nm == "face":      # eyeballs and the mouth: moist, not rubber
		m.roughness = 0.42
		m.metallic = 0.0
	elif m.albedo_texture != null:
		m.roughness = 0.82
		m.metallic = 0.0
	m.resource_name = nm
	return m


## JS _build's rest data, _torsoOutline, _rehand: once per body
static func body(want: String) -> Body:
	if _bodies.has(want):
		return _bodies[want]
	var sc: Node = (load(MODEL) as PackedScene).instantiate()
	var mi: MeshInstance3D = sc.find_child("goon_" + want, true, false)
	var sk := mi.get_parent() as Skeleton3D
	if sk == null:
		sk = mi.get_node(mi.skeleton) as Skeleton3D
	var B := Body.new()
	var n := sk.get_bone_count()
	B.par.resize(n)
	B.rest_p.resize(n)
	B.rest_mp.resize(n)
	B.rest_dir.resize(n)
	for b in n:
		var nm := StringName(sk.get_bone_name(b))
		B.i[nm] = b
		B.names.append(nm)
		B.par[b] = sk.get_bone_parent(b)
		var rt := sk.get_bone_rest(b)
		B.rest_q.append(rt.basis.get_rotation_quaternion())
		B.rest_p[b] = rt.origin
		var g := sk.get_bone_global_rest(b).orthonormalized()
		B.rest_mq.append(g.basis.get_rotation_quaternion())
		B.rest_mp[b] = g.origin
		B.rest_m.append(g)
		B.rest_mi.append(g.inverse())
	for b in n:
		var d := PackedInt32Array()
		for c in n:
			var a := c
			while a >= 0 and a != b:
				a = B.par[a]
			if a == b:
				d.append(c)
		B.desc.append(d)
	var mp := B.rest_mp
	var I := B.i
	B.len_up = mp[I[&"upperarm.R"]].distance_to(mp[I[&"forearm.R"]])
	B.len_fore = mp[I[&"forearm.R"]].distance_to(mp[I[&"hand.R"]])
	B.len_hand = mp[I[&"hand.R"]].distance_to(mp[I[&"fingers.R"]])
	B.len_thigh = mp[I[&"thigh.R"]].distance_to(mp[I[&"shin.R"]])
	B.len_shin = mp[I[&"shin.R"]].distance_to(mp[I[&"foot.R"]])
	for b in n:
		B.rest_dir[b] = B.rest_mq[b] * UP      # childless bones (the feet): along the bone's own axis
	for pr: Array in [[&"upperarm.L", &"forearm.L"], [&"forearm.L", &"hand.L"], [&"hand.L", &"fingers.L"], [&"upperarm.R", &"forearm.R"], [&"forearm.R", &"hand.R"], [&"hand.R", &"fingers.R"], [&"thigh.L", &"shin.L"], [&"shin.L", &"foot.L"], [&"thigh.R", &"shin.R"], [&"shin.R", &"foot.R"]]:
		B.rest_dir[I[pr[0]]] = (mp[I[pr[1]]] - mp[I[pr[0]]]).normalized()
	B.foot_y = minf(mp[I[&"foot.L"]].y, mp[I[&"foot.R"]].y)
	B.skin = mi.skin
	var bind_bone := PackedInt32Array()
	bind_bone.resize(B.skin.get_bind_count())
	for b in B.skin.get_bind_count():
		bind_bone[b] = sk.find_bone(B.skin.get_bind_name(b))
	var bone_bind := PackedInt32Array()
	bone_bind.resize(n)
	for b in bind_bone.size():
		if bind_bone[b] >= 0:
			bone_bind[bind_bone[b]] = b
	# the mesh, with the rest position in CUSTOM0 (a skinned VERTEX is already posed by the time the shader runs; the dye reads where the texel sits at rest)
	var src: Mesh = mi.mesh
	var out := ArrayMesh.new()
	var flags := Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	for s in src.get_surface_count():
		var arr: Array = src.surface_get_arrays(s)
		var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if s == 0:      # the body's primitive: what the JS samples (its first SkinnedMesh)
			_torso_outline(B, pos, arr[Mesh.ARRAY_BONES], arr[Mesh.ARRAY_WEIGHTS], bind_bone)
			_rehand(B, pos, arr, bone_bind)
		for k in range(0, pos.size(), 2):
			B.back_z = minf(B.back_z, pos[k].z)
		var rest := PackedFloat32Array()
		rest.resize(pos.size() * 3)
		for k in pos.size():
			rest[k * 3] = pos[k].x
			rest[k * 3 + 1] = pos[k].y
			rest[k * 3 + 2] = pos[k].z
		arr[Mesh.ARRAY_CUSTOM0] = rest
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
		var m := _prep_material(src.surface_get_material(s))
		out.surface_set_material(s, m)
		B.mats.append(m)
	B.mesh = out
	sc.free()
	_bodies[want] = B
	return B


## the torso round the vertical, from the points that follow the hips / spine / chest (not the arms or legs), grown a little so neighbouring directions agree
static func _torso_outline(B: Body, pos: PackedVector3Array, si: PackedInt32Array, sw: PackedFloat32Array, bind_bone: PackedInt32Array) -> void:
	var core: Array[int] = [B.i[&"hips"], B.i[&"spine"], B.i[&"chest"]]
	var NY := Body.T_NY
	var NB := Body.T_NB
	var zlo := PackedFloat32Array()
	var zhi := PackedFloat32Array()
	zlo.resize(NY)
	zhi.resize(NY)
	zlo.fill(9.0)
	zhi.fill(-9.0)
	var pj := PackedInt32Array()
	var px := PackedFloat32Array()
	var pz := PackedFloat32Array()
	for i in pos.size():
		var w := 0.0
		for k in 4:
			if core.has(bind_bone[si[i * 4 + k]]):
				w += sw[i * 4 + k]
		if w < 0.55:
			continue
		var v := pos[i]
		if absf(v.x) > 0.62:
			continue
		var j := roundi((v.y - Body.T_Y0) / Body.T_DY)
		if j < 0 or j >= NY:
			continue
		pj.append(j)
		px.append(v.x)
		pz.append(v.z)
		zlo[j] = minf(zlo[j], v.z)
		zhi[j] = maxf(zhi[j], v.z)
	B.t_cz.resize(NY)
	for j in NY:
		B.t_cz[j] = (zlo[j] + zhi[j]) / 2.0 if zlo[j] < zhi[j] else 0.0
		var row := PackedFloat32Array()
		row.resize(NB)
		B.t_r.append(row)
	for q in pj.size():
		var j := pj[q]
		var dz := pz[q] - B.t_cz[j]
		var a := atan2(px[q], dz)
		var r := U.hyp(px[q], dz)
		for d in range(-1, 2):
			var b := posmod(roundi(a / TAU * NB) + d, NB)
			B.t_r[j][b] = maxf(B.t_r[j][b], r * (0.97 if d != 0 else 1.0))
	for j in NY:
		var mx := 0.0
		for b in NB:
			mx = maxf(mx, B.t_r[j][b])
		for b in NB:
			if B.t_r[j][b] == 0.0:
				B.t_r[j][b] = mx
	for j in NY:      # a slice also clears its neighbours' bulges (the JS grows them in place, top down)
		for k: int in [j - 1, j + 1]:
			if k >= 0 and k < NY:
				for b in NB:
					B.t_r[j][b] = maxf(B.t_r[j][b], B.t_r[k][b] * 0.94)


## the rig's automatic weights let the forearm pull on the palm and left the fingers on the palm bone, so a curl could not close the hand. Once per body, the hands are re-weighted by distance out along the arm: forearm -> palm -> fingers.
static func _rehand(B: Body, pos: PackedVector3Array, arr: Array, bone_bind: PackedInt32Array) -> void:
	var si: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var sw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var I := B.i
	var sh: float = B.rest_mp[I[&"upperarm.L"]].y
	var x0 := absf(B.rest_mp[I[&"forearm.L"]].x)
	var x1 := absf(B.rest_mp[I[&"hand.L"]].x)
	var x2 := absf(B.rest_mp[I[&"fingers.L"]].x)
	var bb := {}
	for sd: String in ["L", "R"]:
		bb[sd] = [bone_bind[I[StringName("forearm." + sd)]], bone_bind[I[StringName("hand." + sd)]], bone_bind[I[StringName("fingers." + sd)]]]
	for i in pos.size():
		var v := pos[i]
		var ax := absf(v.x)
		if ax < x0 + 0.07 or absf(v.y - sh) > 0.3:
			continue
		var b: Array = bb["L" if v.x > 0.0 else "R"]
		var i0: int
		var i1: int
		var w: float
		if ax < x1 + 0.03:
			i0 = b[0]
			i1 = b[1]
			w = clampf((ax - (x0 + 0.07)) / (x1 + 0.03 - (x0 + 0.07)), 0.0, 1.0)
		else:
			i0 = b[1]
			i1 = b[2]
			w = clampf((ax - (x2 - 0.05)) / (x2 + 0.02 - (x2 - 0.05)), 0.0, 1.0)
		si[i * 4] = i0
		si[i * 4 + 1] = i1
		si[i * 4 + 2] = 0
		si[i * 4 + 3] = 0
		sw[i * 4] = 1.0 - w
		sw[i * 4 + 1] = w
		sw[i * 4 + 2] = 0.0
		sw[i * 4 + 3] = 0.0
	arr[Mesh.ARRAY_BONES] = si
	arr[Mesh.ARRAY_WEIGHTS] = sw


# ------------------------------------------------------------------------------------------------ guns (grip top at the origin, barrel +Z, top +Y): exported from the JS builder, the lamp colours are two shared materials
static var _lamp_mats: Dictionary = {}


static func _lamp_mat(hex: int) -> StandardMaterial3D:
	if _lamp_mats.has(hex):
		return _lamp_mats[hex]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color.hex((hex << 8) | 0xff)
	_lamp_mats[hex] = m
	return m


class Gun:
	var g: Node3D
	var lamps: Array[MeshInstance3D] = []
	var torch: Node3D = null
	var muzzle := Vector3.ZERO


static func _build_gun(kind: String) -> Gun:
	var G := Gun.new()
	G.g = (load("res://assets/objects/goon_gun_%s.glb" % kind) as PackedScene).instantiate()
	G.muzzle = Vector3(0.0, 0.045, 0.19) if kind == "pistol" else (Vector3(0.0, 0.05, 0.375) if kind == "smg" else Vector3(0.0, 0.05, 0.365))
	var walk: Array[Node] = [G.g]
	while walk.size() > 0:
		var n: Node = walk.pop_back()
		var x: Dictionary = n.get_meta("extras", {})
		if String(x.get("js_name", "")) == "J_torch":
			G.torch = n
		if n is MeshInstance3D:
			var mt: Material = (n as MeshInstance3D).mesh.surface_get_material(0)
			if mt != null and mt.resource_name.begins_with("gunLamp"):
				G.lamps.append(n)
		walk.append_array(n.get_children())
	return G


# ------------------------------------------------------------------------------------------------ acid globs + puddles (one set of meshes, drawn by whichever goon view updates first each frame)
static var _acid_frame := -1
static var _acid_level: Node = null
static var _acid_globs: Array[Array] = []
static var _acid_pools: Array[Array] = []


static func _draw_acid(E: Enemies) -> void:
	var frame := Engine.get_process_frames()
	if _acid_frame == frame:
		return
	_acid_frame = frame
	if _acid_level != Game.level:      # the nodes died with the last level
		_acid_globs.clear()
		_acid_pools.clear()
		_acid_level = Game.level
	var A: FointGoon.AcidState = E.goon_acid
	if A == null and _acid_globs.is_empty() and _acid_pools.is_empty():
		return
	var globs: Array[Dictionary] = A.globs if A != null else ([] as Array[Dictionary])
	var pools: Array[Dictionary] = A.pools if A != null else ([] as Array[Dictionary])
	var t := Time.get_ticks_msec() / 1000.0
	while _acid_globs.size() < globs.size():
		_acid_globs.append([FxBeam.ball(0x7dff2e), FxBeam.dot(0x80ff30), _brick_node()])
	while _acid_pools.size() < pools.size():
		_acid_pools.append([FxBeam.puddle(0x5ee82a), FxBeam.puddle(0xd8ff8a)])
	for i in _acid_globs.size():
		var m: MeshInstance3D = _acid_globs[i][0]
		var sp: MeshInstance3D = _acid_globs[i][1]
		var br: MeshInstance3D = _acid_globs[i][2]
		if i >= globs.size():
			m.visible = false
			sp.visible = false
			br.visible = false
			continue
		var q: Dictionary = globs[i]
		var at := Vector3(q.x, q.y, q.z)
		br.visible = q.get("brick", false)
		if br.visible:      # (the site crew's: a brick end over end)
			m.visible = false
			sp.visible = false
			var spin := float(q.life) * 9.0 + i
			br.global_transform = Transform3D(Basis(Vector3(1, 0, 0), spin) * Basis(Vector3(0, 1, 0), spin * 0.37), at)
			continue
		var s := 1.0 + 0.2 * sin(t * 30.0 + i)
		FxBeam.place_ball(m, at, 0.16, 1.0)
		m.scale = Vector3(0.16 * s, 0.16 / s, 0.16 * s)
		FxBeam.place_dot(sp, at, 0.8, 0.8)
	for i in _acid_pools.size():
		var m: MeshInstance3D = _acid_pools[i][0]
		var core: MeshInstance3D = _acid_pools[i][1]
		if i >= pools.size():
			m.visible = false
			core.visible = false
			continue
		var p: Dictionary = pools[i]
		var grow := clampf(float(p.t) / 0.25, 0.0, 1.0)
		var fade := clampf((float(p.life) - float(p.t)) / 0.8, 0.0, 1.0)
		var wob := 1.0 + 0.05 * sin(t * 7.0 + float(p.seed))
		var rr := maxf(0.01, float(p.r) * grow * (0.6 + 0.4 * fade) * wob)
		FxBeam.place_puddle(m, Vector3(p.x, float(p.y) + 0.03, p.z), rr, 0.75 * fade)
		FxBeam.place_puddle(core, Vector3(p.x, float(p.y) + 0.035, p.z), rr * 0.45, (0.45 + 0.25 * sin(t * 11.0 + float(p.seed))) * fade)


## A thrown brick (the site crew's): one of the acid pool's nodes, under the level
static func _brick_node() -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = Vector3(0.11, 0.065, 0.22)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.18, 0.1)
	mat.roughness = 0.95
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.visible = false
	Game.level.add_child(mi)
	return mi


# ------------------------------------------------------------------------------------------------ one goon
var R: FointGoon
var T: Robot
var B: Body
var g: Node3D
var fall: Node3D
var holder: Node3D
var skel: Skeleton3D
var mesh_i: MeshInstance3D
var gun: Gun = null
var dress: FointGoonDress = null
var face: FointGoonFace = null
var culled := false
var smoke_t := 0.0
var spark_t := 0.0
var vent_t := 0.0
var q: Dictionary = {}
var t := randf() * 10.0
var phase := 0.0
var last_x := 0.0
var last_z := 0.0
var last_yaw := NAN
var mv := Vector3.ZERO
var death_t := 0.0
var drop_gun: Variant = null          # Dictionary while the gun lies on the floor
var lie_lift := 0.24
var bar: MeshInstance3D
var bar_t := 0.0
var duty := 0.6
var twist := 0.0
var kick := 0.0
var push_f := 0.0
var push_l := 0.0
var point_at := Vector3.ZERO
var throat_scale := 1.0
var shield_pose_p := Vector3.ZERO
var shield_pose_q := Quaternion.IDENTITY
var has_shield_pose := false
var deco: Variant = null              # despawn takes it with the body (JS this.deco); here the dropped gun is a child of g
# the pose: local to the parent bone, and model space worked out on demand
var lq: Array[Quaternion] = []
var lp := PackedVector3Array()
var wq: Array[Quaternion] = []
var wp := PackedVector3Array()
var dirty := PackedByteArray()
var mw := Transform3D.IDENTITY        # model -> world
var mwi := Transform3D.IDENTITY
var mbi_ok := false
var mbi_spine := Transform3D.IDENTITY
var mbi_chest := Transform3D.IDENTITY
var mb_spine := Transform3D.IDENTITY
var mb_chest := Transform3D.IDENTITY
# the lock on each foot: pinned to the floor while it stands
var lock_on := {&"L": false, &"R": false}
var lock_rec := {&"L": 0.0, &"R": 0.0}
var lock_w := {&"L": Vector3.ZERO, &"R": Vector3.ZERO}
var lock_from := {&"L": Vector3.ZERO, &"R": Vector3.ZERO}
# bone indices
var i_root := 0
var i_hips := 0
var i_spine := 0
var i_chest := 0
var i_head := 0
var i_ua_l := 0
var i_ua_r := 0
var i_fa_l := 0
var i_fa_r := 0
var i_hand_l := 0
var i_hand_r := 0
var i_fing_l := 0
var i_fing_r := 0
var i_throat := -1
var pos_bones := PackedInt32Array()    # the only bones that ever move off their rest position


func _init(p_r: Robot) -> void:
	R = p_r
	T = p_r
	last_x = R.x
	last_z = R.z
	var want: String = GOINT_BODY.get(R.costume, R.costume)
	B = FointGoonView.body(want)
	g = Node3D.new()
	g.name = "Goon%d" % R.id
	fall = Node3D.new()
	holder = Node3D.new()
	g.add_child(fall)
	fall.add_child(holder)
	skel = Skeleton3D.new()
	var n := B.names.size()
	for b in n:
		skel.add_bone(B.names[b])
	for b in n:
		skel.set_bone_parent(b, B.par[b])
		skel.set_bone_rest(b, Transform3D(Basis(B.rest_q[b]), B.rest_p[b]))
		skel.set_bone_pose_rotation(b, B.rest_q[b])
		skel.set_bone_pose_position(b, B.rest_p[b])
		skel.set_bone_pose_scale(b, Vector3.ONE)
	holder.add_child(skel)
	mesh_i = MeshInstance3D.new()
	mesh_i.mesh = B.mesh
	mesh_i.skin = B.skin
	skel.add_child(mesh_i)
	mesh_i.skeleton = mesh_i.get_path_to(skel)
	mesh_i.extra_cull_margin = 2.0
	var I := B.i
	i_root = I[&"root"]
	i_hips = I[&"hips"]
	i_spine = I[&"spine"]
	i_chest = I[&"chest"]
	i_head = I[&"head"]
	i_ua_l = I[&"upperarm.L"]
	i_ua_r = I[&"upperarm.R"]
	i_fa_l = I[&"forearm.L"]
	i_fa_r = I[&"forearm.R"]
	i_hand_l = I[&"hand.L"]
	i_hand_r = I[&"hand.R"]
	i_fing_l = I[&"fingers.L"]
	i_fing_r = I[&"fingers.R"]
	i_throat = I.get(&"throat", -1)
	pos_bones = PackedInt32Array([i_hips, I[&"brow.L"], I[&"brow.R"], I[&"cheek.L"], I[&"cheek.R"]])
	lq.assign(B.rest_q)
	wq.assign(B.rest_mq)
	lp = B.rest_p.duplicate()
	wp = B.rest_mp.duplicate()
	dirty.resize(n)
	# the gun, held in the right hand (child of the model so it sits in model space)
	gun = FointGoonView._build_gun(R.gun)
	holder.add_child(gun.g)
	dress = FointGoonDress.dress(self)        # GOINT costumes: recolour + helmet / armour / shield / flashlight
	if dress == null and gun.torch != null:
		gun.torch.visible = false
	lie_lift = (dress.back_depth if dress != null else -B.back_z) + 0.07
	if FointGoonFace.has_rig(self):
		face = FointGoonFace.new(self)        # eyes, lids, brows, cheeks, jaw, throat
	# health bar (the robots' look)
	bar = MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(0.9, 0.1)
	bar.mesh = bq
	bar.material_override = _bar_mat()
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar.position.y = R.h + 0.45
	bar.extra_cull_margin = 2.0
	bar.visible = false
	g.add_child(bar)
	Game.level.add_child(g)


static var _bar_material: ShaderMaterial = null


static func _bar_mat() -> ShaderMaterial:
	if _bar_material == null:
		_bar_material = ShaderMaterial.new()
		_bar_material.shader = load(BAR_SHADER)
	return _bar_material


func dispose() -> void:
	if dress != null:
		dress.dispose()
	if is_instance_valid(g):
		g.queue_free()


func set_culled(on: bool) -> void:
	if on == culled:
		return
	culled = on
	g.visible = not on


func spine_world() -> Vector3:
	return mw * mp(i_spine)


func el_l_world() -> Vector3:
	return mw * mp(i_fa_l)


func sprite_world(_i: int) -> Vector3:
	return mw * mp(i_spine)


func muzzle_world(_kind: String = "") -> Vector3:
	if gun != null and drop_gun == null:
		return mw * (gun.g.transform * gun.muzzle)
	return Vector3(R.x + sin(R.yaw) * 0.6, R.y + 1.15, R.z + cos(R.yaw) * 0.6)


func gun_world() -> Vector3:
	return mw * gun.g.position


func rest_dir_of(n: StringName) -> Vector3:
	return B.rest_dir[B.i[n]]


# ---------------------------------------------------------------------------------------------- bone posing in model space
func _fk(i: int) -> void:
	if dirty[i] == 0:
		return
	var p := B.par[i]
	if p >= 0:
		_fk(p)
		var pq: Quaternion = wq[p]
		wq[i] = pq * lq[i]
		wp[i] = wp[p] + pq * lp[i]
	else:
		wq[i] = lq[i]
		wp[i] = lp[i]
	dirty[i] = 0


## current rotation of a bone in model space
func mq(i: int) -> Quaternion:
	_fk(i)
	return wq[i]


func mp(i: int) -> Vector3:
	_fk(i)
	return wp[i]


func _touch(i: int) -> void:
	for d: int in B.desc[i]:
		dirty[d] = 1
	if i <= i_chest:
		mbi_ok = false


func _set_q(i: int, v: Quaternion) -> void:
	lq[i] = v
	_touch(i)


func to_model(p: Vector3) -> Vector3:
	return mwi * p


## rotate bone n by q (model-space axes) away from its rest pose, relative to its parent's rest
func rot(n: StringName, v: Quaternion) -> void:
	_rot_i(B.i[n], v)


func _rot_i(i: int, v: Quaternion) -> void:
	var p := B.par[i]
	if p >= 0:
		var P: Quaternion = B.rest_mq[p]
		_set_q(i, P.inverse() * v * P * B.rest_q[i])
	else:
		_set_q(i, v * B.rest_q[i])


func _rot_e(i: int, x: float, y: float, z: float) -> void:
	_rot_i(i, Quaternion.from_euler(Vector3(x, y, z)))      # (Godot's order is three's 'YXZ')


## point bone n (its rest direction) along dir (model space), whatever its parent is doing now
func _aim(i: int, dir: Vector3) -> void:
	var want := Quaternion(B.rest_dir[i], dir.normalized()) * B.rest_mq[i]      # desired model-space rotation
	_set_q(i, mq(B.par[i]).inverse() * want)


## two-bone IK: a = upper bone, b = lower bone, from a's joint to target (model space), elbow / knee toward pole
func _ik(a: int, b: int, target: Vector3, pole: Vector3, la: float, lb: float) -> Vector3:
	if a == i_ua_l or a == i_ua_r:
		target = _arm_safe(a, target, la + lb)      # arms: hands stay out of the body
	var S := mp(a)
	var D := target - S
	var d := clampf(D.length(), absf(la - lb) + 1e-3, la + lb - 1e-3)
	D = D.normalized()
	var x := (la * la - lb * lb + d * d) / (2.0 * d)
	var h := sqrt(maxf(0.0, la * la - x * x))
	var n := pole - D * pole.dot(D)
	if n.length_squared() < 1e-6:
		n = PAD_DOWN
	n = n.normalized()
	var E := S + D * x + n * h
	_aim(a, E - S)
	_aim(b, S + D * d - E)
	return E


## how the spine and chest have moved from rest, and back
func _mb() -> void:
	if mbi_ok:
		return
	mb_spine = Transform3D(Basis(mq(i_spine)), mp(i_spine)) * B.rest_mi[i_spine]
	mb_chest = Transform3D(Basis(mq(i_chest)), mp(i_chest)) * B.rest_mi[i_chest]
	mbi_spine = mb_spine.inverse()
	mbi_chest = mb_chest.inverse()
	mbi_ok = true


## keep a hand target within the arm's reach and outside the torso (pad = the hand's own thickness), following the torso's current pose
func _arm_safe(ua: int, target: Vector3, reach: float) -> Vector3:
	var S := mp(ua)
	var H := target
	var pad := 0.085
	_mb()
	for _it in 4:
		if H.distance_to(S) > reach * 0.985:
			H = S + (H - S).normalized() * (reach * 0.985)
		var up_b := H.y > 0.92
		var Hr := (mbi_chest if up_b else mbi_spine) * H
		if Hr.y < Body.T_Y0 - 0.05 or Hr.y > Body.T_Y0 + Body.T_DY * Body.T_NY:
			break
		var j := clampi(roundi((Hr.y - Body.T_Y0) / Body.T_DY), 0, Body.T_NY - 1)
		var cz := B.t_cz[j]
		var dz := Hr.z - cz
		var a := atan2(Hr.x, dz)
		var f := fposmod(a / TAU * Body.T_NB + Body.T_NB, Body.T_NB)
		var b0 := int(f) % Body.T_NB
		var b1 := (b0 + 1) % Body.T_NB
		var row: PackedFloat32Array = B.t_r[j]
		var rr := lerpf(row[b0], row[b1], f - floorf(f)) + pad
		var d := U.hyp(Hr.x, dz)
		if d >= rr:
			break
		var k := rr / maxf(d, 1e-3)
		Hr.x *= k
		Hr.z = cz + dz * k
		H = (mb_chest if up_b else mb_spine) * Hr
	return H


## is a point (model space) outside the torso by pad, in its current pose
func _clear_of(p: Vector3, pad: float) -> bool:
	_mb()
	var Hr := (mbi_chest if p.y > 0.92 else mbi_spine) * p
	var j := roundi((Hr.y - Body.T_Y0) / Body.T_DY)
	if j < 0 or j >= Body.T_NY:
		return true
	var dz := Hr.z - B.t_cz[j]
	var a := atan2(Hr.x, dz)
	var fb := fposmod(a / TAU * Body.T_NB + Body.T_NB, Body.T_NB)
	var b0 := int(fb) % Body.T_NB
	var b1 := (b0 + 1) % Body.T_NB
	var row: PackedFloat32Array = B.t_r[j]
	return U.hyp(Hr.x, dz) >= lerpf(row[b0], row[b1], fb - floorf(fb)) + pad


func _c(k: StringName, target: float, rate: float, dt: float) -> float:
	var c: float = q.get(k, target)
	if q.has(k):
		c += (target - c) * (1.0 - exp(-rate * dt))
	q[k] = c
	return c


## move a bone by a model-space offset from its rest position
func offset(n: StringName, v: Vector3) -> void:
	_offset_i(B.i[n], v)


func _offset_i(i: int, v: Vector3) -> void:
	var p := B.par[i]
	lp[i] = B.rest_p[i] + (B.rest_mq[p].inverse() * v if p >= 0 else v)
	_touch(i)


func update(dt: float, _now: float, fx: Variant) -> void:
	var sy := sin(R.yaw)
	var cy := cos(R.yaw)
	g.position = Vector3(R.x, R.y, R.z)
	g.rotation = Vector3(0.0, R.yaw, 0.0)
	if R.E != null:
		FointGoonView._draw_acid(R.E)
	# health bar
	var dead := R.dead or R.state == &"dead"
	bar_t = 2.5 if R.flash > 0.5 else maxf(0.0, bar_t - dt * 0.8)
	var show := not dead and bar_t > 0.0 and R.hp < R.max
	bar.visible = show
	if show:
		var f := maxf(0.0, R.hp / R.max)
		var bc := CreatureView._hsl(0.02 + 0.3 * f, 0.85, 0.55)
		bar.set_instance_shader_parameter(&"fill", Vector4(bc.r, bc.g, bc.b, f))
	t += dt
	# speed from real movement (door arrivals move him directly), in his own frame
	var vx := (R.x - last_x) / maxf(dt, 1e-3)
	var vz := (R.z - last_z) / maxf(dt, 1e-3)
	last_x = R.x
	last_z = R.z
	var lf := vx * sy + vz * cy
	var ll := vx * cy - vz * sy            # forward, left
	var spd := _c(&"spd", minf(8.0, U.hyp(lf, ll)), 10.0, dt)
	mv = Vector3(_c(&"mx", ll, 8.0, dt), 0.0, _c(&"mz", lf, 8.0, dt))
	# the sheet's poses
	pose_begin()
	if face != null:
		face.think(dt, dead)
	if dead:
		_dying(dt)
	else:
		death_t = 0.0
		if drop_gun != null:
			_regain_gun()
		_alive(dt, spd)
	if face != null:
		var cam := Game.camera
		var far: bool = cam == null or cam.global_position.distance_squared_to(g.position) > 900.0      # past 30 m the face rests
		face.apply_face(dt, dead, far)
	if dress != null:
		if R.role == "adjuster":
			_shield_pose(dt, dead)
		dress.update(dt, fx, dead)
	# the gun's LEDs flare while he aims
	var aiming := R.fire.ph == &"aim"
	var lamp := _lamp_mat((0xd0ff80 if R.gun == "acid" else 0xffd0c0) if aiming else (0x5aff28 if R.gun == "acid" else 0xff2a18))
	for l: MeshInstance3D in gun.lamps:
		l.material_override = lamp
	R.muzzle = muzzle_world()              # the AI fires from the real muzzle
	R.muzzle_t = R.E.t if R.E != null else -1.0
	# the pose to the skeleton
	push_pose()


## back to the rest pose, ready to be posed (a level's puppet poses him itself: VISITING HOURS' Fenn)
func pose_begin() -> void:
	lq.assign(B.rest_q)
	lp = B.rest_p.duplicate()
	dirty.fill(1)
	mbi_ok = false
	fall.rotation = Vector3.ZERO
	fall.position = Vector3.ZERO
	mw = Transform3D(Basis(Vector3.UP, R.yaw), g.position)
	mwi = mw.inverse()


## the pose to the skeleton (again after update(), when a level's puppet has edited it)
func push_pose() -> void:
	for b in lq.size():
		skel.set_bone_pose_rotation(b, lq[b])
	for b: int in pos_bones:
		skel.set_bone_pose_position(b, lp[b])
	if i_throat >= 0:
		skel.set_bone_pose_scale(i_throat, Vector3(throat_scale, throat_scale, throat_scale))


func _alive(dt: float, spd: float) -> void:
	var L := B
	var state := R.state
	var hostile := state != &"idle" and state != &"return"
	var lab := R.role == "labcoat"
	var tank := R.role == "adjuster"
	var aim_now := R.fire.ph != &"idle" or R.recoil > 0.05
	var ready := hostile and not lab and not R.dev_passive      # weapon up (low ready unless shooting)
	var panic := lab and hostile and not R.cornered and not R.pressing
	if drop_gun == null:
		gun.g.visible = not R.on_break
	var crouch := _c(&"crouch", 1.0 if R.crouch_t > 0.0 or R.cover_duck else 0.0, 9.0 if R.cover_duck or (float(q.get(&"crouch", 0.0)) > 0.5 and R.fire.ph == &"aim") else 6.0, dt)      # pops up from cover quickly
	var stag := _c(&"stag", 1.0 if state == &"stagger" else 0.0, 9.0, dt)
	var fl := R.flinch_t / 0.22 if R.flinch_t > 0.0 else 0.0
	# ---- legs: a planted-foot gait (IK), or the kneel. Each foot is on the ground for `duty` of the cycle and slides back under him at exactly his speed, so it stays put on the floor; the rest of the cycle it lifts and swings forward. Turning on the spot shuffles the feet.
	var yaw_rate := _c(&"yr", absf(U.wrap_angle(R.yaw - (R.yaw if is_nan(last_yaw) else last_yaw))) / maxf(dt, 1e-3), 12.0, dt)
	last_yaw = R.yaw
	var turn_step := clampf((yaw_rate - 1.2) / 2.0, 0.0, 1.0) if crouch < 0.5 and spd < 0.6 else 0.0
	var gw := _c(&"gw", maxf(clampf((spd - 0.12) / 0.5, 0.0, 1.0), turn_step) if crouch < 0.5 else 0.0, 10.0, dt)      # gait weight: eases the stride in and out
	var moving := gw > 0.02
	var A := minf(0.3, 0.12 + spd * 0.045)      # half a stride; a run spends less of the cycle on the ground
	duty = lerpf(0.62, 0.4, clampf((spd - 2.0) / 2.4, 0.0, 1.0))
	phase += dt * (spd * duty / (2.0 * A) if spd > 0.12 else turn_step * 1.8)      # cycles per second
	var mv_l := mv.normalized() if mv.length() > 0.05 else Vector3.ZERO
	var bob := absf(sin(phase * TAU)) * minf(0.045, spd * 0.012) * gw if moving else 0.0
	# hips swing toward the way he is stepping (strafes and backpedals), the spine takes it back out so the chest and gun stay on you
	var ma := atan2(mv.x, mv.z)
	if absf(ma) > PI / 2.0:
		ma -= signf(ma) * PI
	var tw := _c(&"tw", clampf(ma * 0.55, -0.5, 0.5) if spd > 0.6 and crouch < 0.5 else 0.0, 6.0, dt)
	twist = tw
	var kneel_drop: float = (B.rest_mp[i_hips].y - B.foot_y) - (0.11 + L.len_thigh) + 0.02      # hips over a knee on the floor
	var hips_down := crouch * kneel_drop + bob * 0.6 + (0.03 if moving else 0.0) + stag * 0.04
	_offset_i(i_hips, Vector3(0.0, -hips_down, crouch * -0.06 - stag * 0.06))
	if absf(tw) > 1e-3:
		_rot_e(i_hips, 0.0, tw, 0.0)
	# body lean: hunched forward (the sheet), more when running, rocked back by a stagger, a breath
	var breathe := sin(t * 1.9) * 0.02
	# a hit snaps him away from it (fast in, springy out), sized by the damage; every shot kicks the chest and head back
	var ht := R.hit_t
	kick = R.hit_amt * (ht / 0.05 if ht < 0.05 else exp(-(ht - 0.05) * 7.0) * cos((ht - 0.05) * 9.0))
	var hx := R.hit_x
	var hz := R.hit_z
	push_f = hx * sin(R.yaw) + hz * cos(R.yaw)
	push_l = hx * cos(R.yaw) - hz * sin(R.yaw)
	var rk := R.recoil * (0.05 if R.gun == "smg" else (0.1 if R.gun == "acid" else 0.11))
	var lean := 0.07 + (face.lean if face != null else 0.0) + minf(0.2, spd * 0.035) + crouch * 0.12 - stag * 0.45 - fl * 0.12 + (0.15 if panic else 0.0) + push_f * kick * 0.3
	var hit_side := push_l * (fl * 0.25 + kick * 0.3)
	# standing his ground: the weight drifts from foot to foot
	var shift := (1.0 - gw) * (1.0 - crouch) * sin(t * 0.9 + R.id) * 0.03
	if absf(shift) > 1e-4:
		_offset_i(i_hips, Vector3(shift, -hips_down, crouch * -0.06 - stag * 0.06))
	_rot_e(i_spine, lean * 0.5 + breathe, -tw, hit_side - shift * 1.5)
	_rot_e(i_chest, lean * 0.5 - breathe * 0.5 - (0.04 if ready else 0.0) - rk, (-0.12 if ready else 0.0) + sin(phase * TAU) * (0.12 if moving and not ready else 0.03) * gw - push_l * kick * 0.15, 0.0)
	# head: on the player (R.look_at), else wherever the face's attention is (patrol glances: the eyes get there first, the head follows slower)
	var hy := 0.0
	var hp := lean + 0.12                  # the face stays level whatever the spine does
	var F := face
	var look: Variant = R.look_at if R.look_at != null else (F.head_at if F != null else null)
	var hr: float = (10.0 if R.mate_t > 0.45 else 6.0) if R.look_at != null else (F.head_rate if F != null else 6.0)
	if look != null:
		var tl := to_model(look) - mp(i_head)
		hy = clampf(atan2(tl.x, tl.z), -0.9, 0.9) * (1.0 if R.look_at != null else 0.75)
		hp = clampf(atan2(tl.y, U.hyp(tl.x, tl.z)), -0.5, 0.5) * (1.0 if R.look_at != null else 0.7) + lean + 0.12
	else:
		hy = sin(t * 0.37) * 0.25
	_rot_e(i_head, _c(&"hp", hp, hr, dt) + push_f * kick * 0.35 - rk * 1.5 + (F.nod if F != null else 0.0), _c(&"hy", hy, hr, dt), push_l * kick * 0.25 + (F.tilt if F != null else 0.0))
	_legs(dt, gw, A, mv_l, crouch, tw)
	# ---- arms
	var sh_r := mp(i_ua_r)
	var sh_l := mp(i_ua_l)
	var arm_len := L.len_up + L.len_fore
	var lu := L.len_up
	var lfo := L.len_fore
	if R.on_break:      # off duty: right fist on the hip, the left hand holds a cigarette at the chest and brings it up for a drag
		var dr := _c(&"drag", R.drag, 6.0, dt)
		var hp2 := mp(i_head)
		var mo: Array = R.mouth_at if R.mouth_at != null else [-0.04, -0.02, 0.17]
		_ik(i_ua_r, i_fa_r, sh_r + Vector3(-0.17, -arm_len * 0.58, -0.05), Vector3(-1.0, 0.0, -0.3), lu, lfo)
		var hold := sh_l + Vector3(-0.05, -arm_len * 0.42, arm_len * 0.42)
		var mouth := hp2 + Vector3(mo[0], mo[1], mo[2])
		_ik(i_ua_l, i_fa_l, hold.lerp(mouth, dr), Vector3(1.0, -0.7, -0.3), lu, lfo)
		_hand(i_hand_r, i_fing_r, Vector3(0.0, -1.0, 0.2))
		_hand(i_hand_l, i_fing_l, Vector3(-0.5, 0.45, 0.7))
		return
	if R.pressing:      # slapping the alarm panel: right hand out and up, palm forward, a little pump
		var pump := sin(t * 14.0) * 0.03
		_ik(i_ua_r, i_fa_r, sh_r + Vector3(-0.05, 0.12 + pump, arm_len * 0.85), Vector3(-1.0, -0.3, 0.0), lu, lfo)
		_ik(i_ua_l, i_fa_l, sh_l + Vector3(0.1, -arm_len * 0.7, 0.15), Vector3(1.0, 0.0, -1.0), lu, lfo)
		_hand(i_hand_r, i_fing_r, Vector3(0.0, 0.3, 1.0))
		_hand(i_hand_l, i_fing_l, Vector3(0.0, -1.0, 0.2))
		_gun_in_hand(true)
		return
	if panic:      # running for it, arms up and flailing
		for sx: float in [-1.0, 1.0]:
			var w := sin(t * 13.0 + (0.0 if sx > 0.0 else 2.1))
			var sh := sh_l if sx > 0.0 else sh_r
			_ik(i_ua_l if sx > 0.0 else i_ua_r, i_fa_l if sx > 0.0 else i_fa_r, sh + Vector3(sx * (0.22 + 0.08 * w), arm_len * (0.55 + 0.2 * w), 0.12 + 0.1 * cos(t * 11.0 + sx)), Vector3(sx, 0.2, -1.0), lu, lfo)
			_hand(i_hand_l if sx > 0.0 else i_hand_r, i_fing_l if sx > 0.0 else i_fing_r, Vector3(sx * 0.3, 1.0, 0.2))
		_gun_in_hand(false)
		return
	if stag > 0.35 and not lab:      # staggered: arms thrown out for balance, the gun hand wide
		var w := sin(t * 9.0) * 0.06
		_ik(i_ua_r, i_fa_r, sh_r + Vector3(-arm_len * 0.75, arm_len * (0.1 + w), arm_len * 0.3), Vector3(-0.3, -1.0, -0.5), lu, lfo)
		_ik(i_ua_l, i_fa_l, sh_l + Vector3(arm_len * 0.7, arm_len * (0.35 - w), arm_len * 0.2), Vector3(0.3, -1.0, -0.5), lu, lfo)
		_hand(i_hand_l, i_fing_l, Vector3(0.6, 0.6, 0.3), Vector3.ZERO, 0.15)
		_gun_aim(Vector3(-0.5, 0.35, 1.0), 0.0)
		return
	if ready and R.reload_t > 0.0 and not tank:
		_reload(sh_r, sh_l, arm_len, lean)
		return
	if ready or (lab and R.cornered):
		var aim_u := _c(&"aim_u", 1.0 if aim_now or (lab and R.cornered) else 0.0, 12.0 if aim_now else 5.0, dt)
		# low ready -> on the target; the muzzle climbs with each shot, the aim breathes, and a hit knocks it off line
		var climb := R.recoil * ((0.07 + sin(t * 61.0) * 0.03) if R.gun == "smg" else (0.14 if R.gun == "acid" else 0.2)) + kick * 0.25
		var pitch := lerpf(-0.55, -R.aim * 0.9, aim_u) - lean * 0.2 - climb + sin(t * 1.3 + 1.0) * 0.015 * aim_u
		var rec := R.recoil * (0.04 if R.gun == "smg" else 0.075)
		var dir := Vector3(sin(t * 0.9) * 0.02 * aim_u + (sin(t * 47.0) * 0.02 * R.recoil if R.gun == "smg" else 0.0) - push_l * kick * 0.2, -sin(pitch), cos(pitch)).normalized()
		var shake := 0.02 if lab else 0.0
		if tank:      # the adjuster: shield arm across the front, one-handed SMG past its right edge
			var open := _c(&"open", 1.0 if aim_now and not (R.reload_t > 0.0) else 0.0, 9.0 if aim_now else 4.0, dt)
			var rl := sin(clampf(1.0 - R.reload_t / maxf(0.1, R.reload_dur), 0.0, 1.0) * PI) if R.reload_t > 0.0 else 0.0
			var gd := Vector3(-0.3 * rl, 0.75 * rl, 1.0).normalized().lerp(dir, 1.0 - rl).normalized() if rl != 0.0 else dir      # reload: the gun tips up to the chest and back, one-handed
			var G := sh_r + Vector3(0.02 + 0.1 * rl, -0.06 - 0.12 * rl, 0.0) + gd * (arm_len * lerpf(0.9, 0.55, rl) - rec * 1.5)
			_ik(i_ua_r, i_fa_r, G, Vector3(-1.0, -1.0, -0.2), lu, lfo)
			_gun_aim(gd, 0.0)
			_ik(i_ua_l, i_fa_l, sh_l + Vector3(-0.07 + open * 0.05, -0.19 - open * 0.06, 0.2 - open * 0.05), Vector3(1.0, -0.6, -0.4), lu, lfo)
			_hand(i_hand_l, i_fing_l, Vector3(-0.3, 0.15, 1.0), Vector3.ZERO, 1.4)      # a fist in the shield gauntlet
			return
		if R.gun == "pistol" and not lab:      # both hands: the right fist on the grip, the left cupping it
			_two_hand(dir, lerpf(0.24, 0.1, aim_u), lerpf(0.8, 1.0, aim_u), rec)
		elif lab:      # cornered: one shaky hand, the other up in front of his face
			var w := Vector3(sin(t * 23.0) * shake, sin(t * 19.0) * shake, 0.0)
			var G := sh_r + w + dir * (arm_len * 0.9 - rec)
			_ik(i_ua_r, i_fa_r, G, Vector3(-1.0, -1.0, 0.0), lu, lfo)
			_ik(i_ua_l, i_fa_l, sh_l + Vector3(-0.05, arm_len * 0.15, arm_len * 0.55), Vector3(1.0, -1.0, 0.0), lu, lfo)
			_gun_aim(dir, 0.0)
			_hand(i_hand_l, i_fing_l, Vector3(-0.3, 1.0, 0.3), Vector3.ZERO, 0.15)
		else:      # SMG / sprayer: right hand on the grip, left on the magwell / canister
			_two_hand(dir, lerpf(0.24, 0.12, aim_u), lerpf(0.85, 1.0, aim_u), rec * 1.5)
		# the free hand points: at you on first sight ("there!"), or a chop toward the post he is heading for
		var pt: Variant = null
		if not lab and not tank:
			if R.state == &"alert" and R.look_at != null:
				pt = R.look_at
			elif R.signal_t > 0.0 and R.signal_at != null:
				pt = Vector3(R.signal_at.x, R.y + 0.6, R.signal_at.y)
		var pw := _c(&"point", 1.0 if pt != null and not aim_now else 0.0, 10.0, dt)
		if pw > 0.03:
			if pt != null:
				point_at = to_model(pt)
			var to := (point_at - sh_l).normalized()
			var chop := 0.0 if R.state == &"alert" else sin(t * 11.0) * 0.12
			to.y += chop
			var rest := sh_l + Vector3(0.1, -arm_len * 0.8, 0.1)
			var Pp := sh_l + to.normalized() * (arm_len * 0.97)
			_ik(i_ua_l, i_fa_l, rest.lerp(Pp, pw), Vector3(1.0, -0.6, -0.4), lu, lfo)
			_hand(i_hand_l, i_fing_l, to)
		return
	# idle / walking, not fighting: guards carry the gun low in front in both hands, muzzle at the floor ahead (a bob when walking)
	var sw := sin(phase * TAU) * minf(0.25, spd * 0.06) * gw if moving else 0.0
	if not lab:
		_two_hand(Vector3(0.15, -0.2, 1.0).normalized(), 0.15, 0.9, 0.0, sw * 0.04)
		return
	_ik(i_ua_r, i_fa_r, sh_r + Vector3(-0.1, -arm_len * 0.9, 0.08 - sw * arm_len), Vector3(-0.6, 0.0, -1.0), lu, lfo)
	_ik(i_ua_l, i_fa_l, sh_l + Vector3(0.1, -arm_len * 0.9, 0.08 + sw * arm_len), Vector3(0.6, 0.0, -1.0), lu, lfo)
	_hand(i_hand_r, i_fing_r, Vector3(0.0, -1.0, 0.35))
	_hand(i_hand_l, i_fing_l, Vector3(0.0, -1.0, 0.1))
	_gun_in_hand(true)


## both hands on the gun. The toads' arms are short on a wide body, so the gun goes where both really reach: in front of the upper chest, as far out as the left hand still gets (out < 1 brings it in a little), clear of the belly (lifted toward the shoulders when it is not). The wrists stay apart and each hand angles in to its contact, the way a short-armed shooter holds: the right fist round the grip, the left cupping it (pistol) or on the magwell (SMG) or the canister (sprayer). dir = the barrel (model space), drop = how far below the shoulders he would like it, bob = a walking bob.
func _two_hand(dir: Vector3, drop: float, out: float, rec: float = 0.0, bob: float = 0.0) -> void:
	var L := B
	var reach := (L.len_up + L.len_fore) * 0.95
	var hl := L.len_hand
	var kind := R.gun
	var sh_r := mp(i_ua_r)
	var sh_l := mp(i_ua_l)
	var mid := (sh_r + sh_l) * 0.5
	var f := dir.normalized()
	var lf := UP.cross(f).normalized()
	var up := f.cross(lf).normalized()     # barrel, his left, the gun's top
	var hd_r := (f * 0.8 + lf * 0.6).normalized()
	var p_r := lf
	var hd_l := (f * 0.7 + lf * -0.7).normalized()
	var p_l := (-lf + up * (1.0 if kind == "pistol" else 0.5)).normalized()
	var sup_ofs: Vector3
	if kind == "pistol":
		sup_ofs = lf * 0.03 + up * -0.06
	elif kind == "acid":
		sup_ofs = f * 0.1 + up * 0.07 + lf * 0.04
	else:
		sup_ofs = f * 0.1 + up * -0.035
	var wr_ofs := hd_r * (-hl * GRIP.x) + p_r * -GRIP.y + hd_r.cross(p_r).normalized() * -GRIP.z
	var wl_ofs := sup_ofs + hd_l * (-hl * 0.6) + p_l * -GRIP.y + hd_l.cross(p_l).normalized() * -GRIP.z
	var hold := Vector3.ZERO
	var found := false
	var dy := 0.0
	while dy <= 0.36 and not found:
		var base := mid + UP * (bob - maxf(0.06, drop - dy)) + lf * -0.04 - f * rec
		var d := reach + hl
		while d > 0.1 and not ((base + f * d + wr_ofs).distance_to(sh_r) <= reach and (base + f * d + wl_ofs).distance_to(sh_l) <= reach):      # the furthest out both hands reach (nearer is closer to the body)
			d -= 0.015
		var far := base + f * d
		if not _hold_clear(far, wr_ofs, wl_ofs, sup_ofs):
			if dy + 0.06 > 0.36:
				hold = far
				found = true
			dy += 0.06
			continue
		var near := base + f * maxf(0.1, d * out)
		hold = near if out < 1.0 and _hold_clear(near, wr_ofs, wl_ofs, sup_ofs) else far
		found = true
	if not found:      # (float steps can end the JS loop on its last value; it holds the far point then)
		hold = mid + UP * (bob - maxf(0.06, drop - 0.36)) + lf * -0.04 + f * (reach * 0.5 - rec)
	_ik(i_ua_r, i_fa_r, hold + wr_ofs, Vector3(-1.0, -1.0, -0.3), L.len_up, L.len_fore)
	_ik(i_ua_l, i_fa_l, hold + wl_ofs, Vector3(1.0, -1.0, -0.3), L.len_up, L.len_fore)
	_hand(i_hand_r, i_fing_r, hd_r, p_r, GRIP_CURL)
	_hand(i_hand_l, i_fing_l, hd_l, p_l, GRIP_CURL)
	_gun_at(hold, f)


func _hold_clear(C: Vector3, wr_ofs: Vector3, wl_ofs: Vector3, sup_ofs: Vector3) -> bool:
	return _clear_of(C + wr_ofs, 0.075) and _clear_of(C + wl_ofs, 0.075) and _clear_of(C, 0.075) and _clear_of(C + sup_ofs, 0.075)


## where the adjuster's shield hangs (model space): ahead of the left gauntlet, turned toward you, swung open to his left while he fires
func _shield_pose(dt: float, dead: bool) -> void:
	var hand := mp(i_hand_l)
	var open: float = q.get(&"open", 0.0)
	var ya0 := 0.0
	if R.look_at != null and not dead:
		var tm := to_model(Vector3(R.look_at.x, 0.0, R.look_at.z))
		ya0 = clampf(atan2(tm.x - hand.x, tm.z - hand.z), -0.45, 0.45)
	var ya := _c(&"shy", ya0, 6.0, dt) + open * 0.9
	var s := sin(ya)
	var c := cos(ya)
	var ox := -0.16 + open * 0.24
	var oz := 0.32
	shield_pose_p = hand + Vector3(ox * c + oz * s, 0.12 - open * 0.25, -ox * s + oz * c)
	var z := Vector3(s, -0.08, c).normalized()
	var x := UP.cross(z).normalized()
	var y := z.cross(x)
	shield_pose_q = Basis(x, y, z).get_rotation_quaternion()
	has_shield_pose = true


## the reload: gun tipped up and pulled in to the chest, the left hand drops to the belt for a fresh mag, seats it, slaps it home
func _reload(sh_r: Vector3, sh_l: Vector3, arm_len: float, lean: float) -> void:
	var L := B
	var u := clampf(1.0 - R.reload_t / maxf(0.1, R.reload_dur), 0.0, 1.0)
	var tilt := CreatureView._ease(clampf(u / 0.15, 0.0, 1.0)) * (1.0 - CreatureView._ease(clampf((u - 0.88) / 0.12, 0.0, 1.0)))
	var dir := Vector3(-0.25 * tilt, lerpf(0.3, 0.75, tilt) - lean * 0.2, 1.0).normalized()
	var G := sh_r + Vector3(0.12 * tilt, -0.2 - 0.06 * tilt, 0.0) + dir * lerpf(0.3, 0.2, tilt)
	_ik(i_ua_r, i_fa_r, G, Vector3(-1.0, -0.6, -0.5), L.len_up, L.len_fore)
	_gun_aim(dir, 0.0)
	var well := gun.g.transform * Vector3(0.0, -0.12, 0.04)
	var belt := sh_l + Vector3(-0.04, -arm_len * 0.95, 0.12)
	# 0-.3 down to the belt, .3-.6 up to the gun, .6-.75 seat it, .75 slap
	var a := CreatureView._ease(clampf(u / 0.3, 0.0, 1.0))
	var b := CreatureView._ease(clampf((u - 0.3) / 0.3, 0.0, 1.0))
	var slap := sin((u - 0.72) / 0.13 * PI) * 0.06 if u > 0.72 and u < 0.85 else 0.0
	var H := (sh_l + Vector3(0.1, -arm_len * 0.7, 0.15)).lerp(belt, a).lerp(well, b)
	H.y += slap
	if u > 0.85:
		H = H.lerp(sh_l + Vector3(0.08, -arm_len * 0.75, 0.12), CreatureView._ease(clampf((u - 0.85) / 0.15, 0.0, 1.0)))
	_ik(i_ua_l, i_fa_l, H, Vector3(1.0, -1.0, -0.3), L.len_up, L.len_fore)
	_hand(i_hand_l, i_fing_l, Vector3(0.0, 1.0, 0.3), Vector3.ZERO, 0.9 if a > 0.5 else 0.4)      # a fresh mag held in the fingers


## a hand: wrist to knuckles along dir; palm (optional) turns the palm that way; curl closes the fingers toward the palm (0 open, ~1.5 a fist round a grip). The rig has one finger bone per hand (a mitten), so a grip is the whole hand curling.
func _hand(n: int, fi: int, dir: Vector3, palm: Vector3 = Vector3.ZERO, curl: float = 0.35) -> void:
	var d0: Vector3 = B.rest_dir[n]
	var p0 := (PAD_DOWN + d0 * d0.y).normalized()
	if palm == Vector3.ZERO:
		_aim(n, dir)
	else:      # the rest frame (along the bone, palm down) onto the wanted one
		var d1 := dir.normalized()
		var p1 := (palm - d1 * palm.dot(d1)).normalized()
		var M0 := Basis(d0, p0, d0.cross(p0))
		var M1 := Basis(d1, p1, d1.cross(p1))
		var want := (M1 * M0.transposed()).get_rotation_quaternion() * B.rest_mq[n]
		_set_q(n, mq(B.par[n]).inverse() * want)
	var hq := mq(n)
	var want2 := hq * B.rest_mq[n].inverse() * Quaternion(d0.cross(p0).normalized(), curl) * B.rest_mq[fi]
	_set_q(fi, hq.inverse() * want2)


## the gun: in the right fist, barrel along dir (model space), top up
func _gun_aim(dir: Vector3, drop: float) -> void:
	if drop_gun != null:
		return
	var z := dir.normalized()
	var x := UP.cross(z).normalized()
	var y := z.cross(x)
	_hand(i_hand_r, i_fing_r, z, x, GRIP_CURL)      # knuckles along the barrel, palm turned in to the grip, fingers closed round it
	var hand := mp(i_hand_r)
	var d := mq(i_hand_r) * B.rest_mq[i_hand_r].inverse()
	var d0: Vector3 = B.rest_dir[i_hand_r]
	var fwd := d * d0
	var palm := d * (PAD_DOWN + d0 * d0.y).normalized()
	var top := fwd.cross(palm).normalized()
	var grip := hand + fwd * (B.len_hand * GRIP.x) + palm * GRIP.y + top * GRIP.z + Vector3(0.0, drop, 0.0)
	gun.g.transform = Transform3D(Basis(x, y, z), grip)


## the gun with its grip top at C (model space), barrel along dir, top up
func _gun_at(C: Vector3, dir: Vector3) -> void:
	if drop_gun != null:
		return
	var z := dir.normalized()
	var x := UP.cross(z).normalized()
	var y := z.cross(x)
	gun.g.transform = Transform3D(Basis(x, y, z), C)


func _gun_in_hand(down: bool) -> void:
	if drop_gun != null:
		return
	var fwd: Vector3 = (mq(i_hand_r) * B.rest_mq[i_hand_r].inverse()) * B.rest_dir[i_hand_r]
	_gun_aim(fwd.lerp(Vector3(0.0, -0.3, 1.0), 0.25) if down else fwd.lerp(Vector3(0.0, 1.0, 0.3), 0.2), 0.0)


func _y_rot(v: Vector3, ox: float, oz: float, ct: float, st: float) -> Vector3:
	var x := v.x - ox
	var z := v.z - oz
	return Vector3(ox + x * ct + z * st, v.y, oz - x * st + z * ct)      # turn with the hips


func _legs(dt: float, gw: float, A: float, mv2: Vector3, crouch: float, tw: float) -> void:
	var L := B
	var ct := cos(tw)
	var st := sin(tw)
	var hx: float = B.rest_mp[i_hips].x
	var hz: float = B.rest_mp[i_hips].z
	var lift := minf(0.15, 0.06 + A * 0.3)
	for sd: StringName in [&"L", &"R"]:
		var left := sd == &"L"
		var sx := 1.0 if left else -1.0
		var off := 0.0 if left else 0.5
		var i_th: int = B.i[&"thigh.L" if left else &"thigh.R"]
		var i_sh: int = B.i[&"shin.L" if left else &"shin.R"]
		var i_fo: int = B.i[&"foot.L" if left else &"foot.R"]
		var foot := _y_rot(B.rest_mp[i_fo], hx, hz, ct, st)
		var pole := _y_rot(Vector3(sx * 0.15, 0.0, 1.0), 0.0, 0.0, ct, st)
		if crouch > 0.01:      # the kneel: right knee down, left foot forward
			var kneel := not left
			lock_on[sd] = false
			var k := Vector3(foot.x, B.foot_y + 0.13, foot.z - 0.3) if kneel else Vector3(foot.x, foot.y + 0.07, foot.z + 0.32)
			foot = foot.lerp(k, crouch)
			if kneel:
				pole = Vector3(0.0, -1.0, 0.6)
		elif gw > 0.02:
			# planted: the foot is pinned to the floor where it landed (in the world, so turning and strafing do not drag it), unless the body has run off and left it too far behind; in the swing it travels from where it lifted off to the next landing ahead along his motion
			var u := fposmod(phase + off, 1.0)
			var home := foot
			if u < duty:
				var nominal := home + mv2 * lerpf(A, -A, u / duty)
				if not lock_on[sd]:
					lock_on[sd] = true
					lock_rec[sd] = 0.0
					lock_w[sd] = mw * nominal
				var held := mwi * (lock_w[sd] as Vector3)
				held.y = nominal.y
				if float(lock_rec[sd]) > 0.0:      # a quick recovery step back under him (after a hard reversal)
					lock_rec[sd] = maxf(0.0, float(lock_rec[sd]) - dt)
					var s := 1.0 - float(lock_rec[sd]) / 0.15
					held = (lock_from[sd] as Vector3).lerp(nominal, CreatureView._ease(s))
					held.y += sin(s * PI) * lift * 0.6
					var w := mw * held
					w.y -= sin(s * PI) * lift * 0.6      # the pin travels with the step (a swing starting now lifts from here)
					lock_w[sd] = w
				elif held.distance_to(nominal) > A * 2.0 + 0.1:      # left too far behind: step, not slide
					lock_from[sd] = held
					lock_rec[sd] = 0.15
				foot = home.lerp(held, gw)
			else:
				var s := (u - duty) / (1.0 - duty)
				if lock_on[sd]:
					lock_on[sd] = false
					var fr := mwi * (lock_w[sd] as Vector3)
					fr.y = home.y
					lock_from[sd] = fr
				var land := home + mv2 * A
				foot = home.lerp((lock_from[sd] as Vector3).lerp(land, CreatureView._ease(s)), gw)
				foot.y += sin(s * PI) * lift * gw
		else:
			lock_on[sd] = false
		foot.y = maxf(foot.y, B.foot_y - 0.02)
		_ik(i_th, i_sh, foot, pole, L.len_thigh, L.len_shin)
		_aim(i_fo, Vector3(0.0, -0.15, -1.0) if crouch > 0.5 and not left else _y_rot(Vector3(0.0, -0.15, 1.0), 0.0, 0.0, ct, st))


# ---------------------------------------------------------------------------------------------- the death (the sheet: knocked back, arm flung up, then flat on his back)
func _dying(dt: float) -> void:
	var L := B
	death_t += dt
	var Tt := death_t
	if drop_gun == null and Tt > 0.12:
		_throw_gun()
	var u1 := CreatureView._ease(clampf(Tt / 0.45, 0.0, 1.0))
	var u2 := CreatureView._ease(clampf((Tt - 0.35) / 0.55, 0.0, 1.0))
	var land := exp(-(Tt - 0.9) * 9.0) * sin((Tt - 0.9) * 30.0) * 0.04 if Tt > 0.9 else 0.0
	# the fall: pivot at the heels, onto his back
	var back := u1 * 0.25 + u2 * (PI / 2.0 - 0.25)
	fall.rotation = Vector3(-back, 0.0, 0.0)
	fall.position = Vector3(0.0, u2 * lie_lift + land, -u2 * 0.05)      # lying on his back: lifted by how far his back sticks out
	mw = Transform3D(Basis(Vector3.UP, R.yaw), g.position) * fall.transform
	mwi = mw.inverse()
	_offset_i(i_hips, Vector3(0.0, -u1 * 0.12 * (1.0 - u2), 0.0))
	_rot_e(i_spine, -0.2 * u1, 0.0, 0.1 * u1)
	_rot_e(i_chest, -0.15 * u1 + 0.1 * u2, 0.15 * (1.0 - u2), 0.0)
	_rot_e(i_head, -0.4 * u1 + (HELMET_DEATH if HELMETED.has(R.costume) else 0.5) * u2, 0.4 * u2, 0.0)
	var sh_r := mp(i_ua_r)
	var sh_l := mp(i_ua_l)
	var arm := L.len_up + L.len_fore
	# left arm thrown up, then flopped out to the side; right arm (the gun hand) flung out and down
	var up_l := sh_l + Vector3(0.15, arm * 0.85, 0.15)
	var out_l := sh_l + Vector3(arm * 0.85, -0.05, -0.2)
	_ik(i_ua_l, i_fa_l, up_l.lerp(out_l, u2), Vector3(1.0, 0.0, -1.0), L.len_up, L.len_fore)
	var R1 := sh_r + Vector3(-0.3, -arm * 0.75, -0.1)
	var R2 := sh_r + Vector3(-arm * 0.8, -0.1, 0.1)
	_ik(i_ua_r, i_fa_r, R1.lerp(R2, u2), Vector3(-1.0, 0.0, -1.0), L.len_up, L.len_fore)
	_hand(i_hand_l, i_fing_l, Vector3(0.2, 1.0, 0.3), Vector3.ZERO, 0.2)
	_hand(i_hand_r, i_fing_r, Vector3(-1.0, 0.0, 0.3), Vector3.ZERO, 0.2)
	# legs: buckle, then the knees come up a little as he lies there
	for left: bool in [true, false]:
		var sx := 1.0 if left else -1.0
		var i_fo: int = B.i[&"foot.L" if left else &"foot.R"]
		var f: Vector3 = B.rest_mp[i_fo]
		f.z += u2 * 0.25 + (0.05 if left else 0.0)
		f.y += u2 * 0.12
		_ik(B.i[&"thigh.L" if left else &"thigh.R"], B.i[&"shin.L" if left else &"shin.R"], f, Vector3(sx * 0.3, 0.3, 1.0), L.len_thigh, L.len_shin)
		_aim(i_fo, Vector3(0.0, 0.3, 1.0))
	# the dropped gun falls and settles next to him
	if drop_gun != null:
		var D: Dictionary = drop_gun
		D.vy = float(D.vy) - 18.0 * dt
		var p: Vector3 = D.p
		p += Vector3(D.vx, D.vy, D.vz) * dt
		var gn: Node3D = gun.g
		gn.rotation.x += float(D.w) * dt
		gn.rotation.z += float(D.w) * 0.6 * dt
		var fl := R.y + 0.03
		if p.y < fl:
			p.y = fl
			D.vy = -float(D.vy) * 0.25 if absf(float(D.vy)) > 2.0 else 0.0
			D.vx = float(D.vx) * 0.5
			D.vz = float(D.vz) * 0.5
			D.w = float(D.w) * 0.4
			if float(D.vy) == 0.0:
				gn.rotation.x = roundf(gn.rotation.x / PI) * PI
				gn.rotation.z = PI / 2.0
		D.p = p
		gn.global_position = p


func _throw_gun() -> void:
	var gw: Node3D = gun.g
	var at := mw * gw.transform
	gw.top_level = true
	gw.global_transform = at
	var s := sin(R.yaw)
	var c := cos(R.yaw)
	drop_gun = {"p": at.origin, "vx": -c * 1.6 + R.hit_x * 1.2, "vy": 3.2, "vz": s * 1.6 + R.hit_z * 1.2, "w": 9.0}


func _regain_gun() -> void:      # respawned
	gun.g.top_level = false
	gun.g.transform = Transform3D.IDENTITY
	drop_gun = null
