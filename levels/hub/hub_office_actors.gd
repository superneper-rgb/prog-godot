class_name HubOfficeActors
extends RefCounted
## The people in the B-9 office (JS levels/hub/office-actors.js, npcs/mixamo-rig.js): The Boss pondering his screens, a finger drumming his chin; Shit-chan the bored sentry; Cherub typing. The Boss and Shit-chan are their own imported skeletons, put into the real bind pose and posed each frame as the JS does (idle rig, swings about the actor's axes, two-bone arms). Her stock hand's finger curl and her eyelid blink are not here: the hand reaches the stock with its fingers at rest, and she does not blink. Cherub is the talker body (HubNpcs.Cherub, the same createCherubNPC as the JS), sat in his chair; his forearms and typing hands are the export's. A cutscene drives them through body.cine / cherub_cine (attend, talk, anger, look, yaw, hit, dead, flinch, strain, buzz), as the JS's actor.cine.

const FLOOR := -10.0
const BOSS_FILE := "res://assets/npcs/the-boss/model.glb"
const SHIT_FILE := "res://assets/npcs/shit-chan/model-lod.glb"
const SHIT_MAP := "res://assets/npcs/shit-chan/office-albedo.jpg"

## One imported body: skeleton, axes, the rest of makeMixamoRig
class Body:
	var root: Node3D
	var sk: Skeleton3D
	var b := {}                # bone name, less "mixamorig", -> index
	var bind_q := {}           # idx -> local rotation in the bind pose
	var bind_pinv := {}        # idx -> inverse of its parent's global rotation in the bind pose
	var left := Vector3.RIGHT
	var up := Vector3.UP
	var fwd := Vector3.FORWARD
	var down_l := 0.0
	var down_r := 0.0
	var rel := Quaternion.IDENTITY      # the actor's axes in skeleton space
	var inv_xf := Transform3D.IDENTITY  # actor space -> skeleton space
	var cine: Variant = null            # JS actor.cine: the cutscene's pose layer
	var cine_hold := false              # JS actor.cineHold: a cutscene has his yaw
	var home := Vector3.ZERO

	func bone_world(n: String) -> Vector3:
		return sk.global_transform * sk.get_bone_global_pose(b[n]).origin

	func gp(n: String) -> Vector3:
		return sk.get_bone_global_pose(b[n]).origin

	## JS rig set(): from its bind rotation, turned about the body's axes
	func set_rot(n: String, deltas: Array) -> void:
		if not b.has(n):
			return
		var i: int = b[n]
		var q: Quaternion = bind_q[i]
		var pinv: Quaternion = bind_pinv[i]
		for d: Array in deltas:
			var ax: Vector3 = d[0]
			q = Quaternion((pinv * ax).normalized(), d[1]) * q
		sk.set_bone_pose_rotation(i, q)

	## JS swing(): rotate a bone about the actor's own axes (x = her left, y = up, z = forward), whatever the imported skeleton's local axes happen to be
	func swing(n: String, x: float, y: float = 0.0, z: float = 0.0) -> void:
		if not b.has(n):
			return
		var i: int = b[n]
		var par := sk.get_bone_parent(i)
		var pq: Quaternion = sk.get_bone_global_pose(par).basis.get_rotation_quaternion() if par >= 0 else Quaternion.IDENTITY
		var e := Quaternion.from_euler(Vector3(x, y, z))      # (YXZ, Godot's default, as the JS's)
		var world := rel * e * rel.inverse()
		sk.set_bone_pose_rotation(i, (pq.inverse() * world * pq) * sk.get_bone_pose_rotation(i))

	func _aim(i: int, child: int, point: Vector3) -> void:
		var from := sk.get_bone_global_pose(i).origin
		var old := (sk.get_bone_global_pose(child).origin - from).normalized()
		var want := (point - from).normalized()
		var q := Quaternion(old, want) * sk.get_bone_global_pose(i).basis.get_rotation_quaternion()
		var par := sk.get_bone_parent(i)
		var pq: Quaternion = sk.get_bone_global_pose(par).basis.get_rotation_quaternion() if par >= 0 else Quaternion.IDENTITY
		sk.set_bone_pose_rotation(i, (pq.inverse() * q).normalized())

	## JS reach(): the two-bone solve, target and hint in the actor's space
	func reach(side: String, target: Vector3, hint: Vector3) -> void:
		if not b.has(side + "Arm") or not b.has(side + "ForeArm") or not b.has(side + "Hand"):
			return
		var a: int = b[side + "Arm"]
		var f: int = b[side + "ForeArm"]
		var h: int = b[side + "Hand"]
		var p := sk.get_bone_global_pose(a).origin
		var bp := sk.get_bone_global_pose(f).origin
		var hp := sk.get_bone_global_pose(h).origin
		var goal := inv_xf * target
		var bend_ := (inv_xf * hint) - p
		var l1 := p.distance_to(bp)
		var l2 := bp.distance_to(hp)
		var dir := goal - p
		var d := maxf(.001, minf(dir.length(), (l1 + l2) * .995))
		dir = dir.normalized()
		bend_ = (bend_ - dir * bend_.dot(dir)).normalized()
		var along := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
		var elbow := p + dir * along + bend_ * sqrt(maxf(0.0, l1 * l1 - along * along))
		_aim(a, f, elbow)
		_aim(f, h, goal)


var L: ExportedLevel
var boss: Body = null
var shit: Body = null
var hands: Array[Node3D] = []
var _acc := 0.0
var _gun_stock := Vector3(-.1, 1.37, -.05)      # where the stock of the rifle sits in her space (the exported rifle stands still with her)
var cherub: HubNpcs.Cherub = null
var cherub_cine: Variant = null
var _cherub_statue: Node3D = null
var boss_actor: BossActor = null
var _interior: Node3D = null
var _clock := 0.0


## JS's talker actor for the Boss: talking turns him from his screens to face the player; his model and idle are the office's own, only the yaw is driven here.
class BossActor:
	extends RefCounted
	var o: HubOfficeActors
	var face_to: Variant = null

	func look_at_point(x: float, z: float) -> void:
		face_to = Vector2(x, z)

	func look_away() -> void:
		face_to = null

	func set_talk(_v: bool) -> void:
		pass

	func mouth_world() -> Vector3:
		var b := o.boss
		if b == null:
			return Vector3(127.0, FLOOR + 1.7, 330.0)
		return b.root.global_transform * Vector3(0.0, 1.68, 0.12)

	func update(dt: float) -> void:
		var b := o.boss
		if b == null or dt <= 0.0 or b.cine_hold:
			return
		var yaw := PI / 2.0
		if face_to != null:
			var f: Vector2 = face_to
			yaw = atan2(f.x - b.root.position.x, f.y - b.root.position.z)
		var d := yaw - b.root.rotation.y
		b.root.rotation.y += atan2(sin(d), cos(d)) * minf(1.0, dt * 4.0)


func _init(p_level: ExportedLevel, interior: Node3D) -> void:
	L = p_level
	for nm: String in ["Cherub typing hand -1", "Cherub typing hand 1"]:
		for h: Node in L.node_named(nm):
			hands.append(h)
	boss = _load(BOSS_FILE, "Office / The Boss pondering screens", interior, null, true)
	shit = _load(SHIT_FILE, "Office / Shit-chan armed idle", interior, load(SHIT_MAP), false)
	if boss != null:
		boss.home = boss.root.position
	if shit != null:
		shit.home = shit.root.position
	boss_actor = BossActor.new()
	boss_actor.o = self
	_interior = interior


## JS createCherubNPC at his seat: the talker's body from the hub's export, in the statue's place. The statue keeps only its forearms and hands.
func load_cherub(J: Dictionary, bin: PackedByteArray) -> void:
	var nodes: Array = L.node_named("Office / Cherub typing")
	if nodes.is_empty() or not (J.get("npcs", {}) as Dictionary).has("cherub"):
		return
	_cherub_statue = nodes[0]
	for c: Node in _cherub_statue.get_children():
		if String(c.name).contains("skinned") and c is Node3D:
			(c as Node3D).visible = false
	var d: Dictionary = J["npcs"]["cherub"]
	cherub = HubNpcs.Cherub.new()
	cherub.name = "Office / Cherub typing (body)"
	(_interior if _interior != null else L).add_child(cherub)
	cherub.build(d, bin)
	cherub.prepare(d["bones"])
	cherub.place(_cherub_statue.global_position.x, _cherub_statue.global_position.y, _cherub_statue.global_position.z, PI)


static func _rx(c: HubNpcs.Cherub, nm: String, v: float) -> void:
	if not c.has_bone(nm):
		return
	var i: int = c.bones[nm]
	var e := c.skeleton.get_bone_pose_rotation(i).get_euler(EULER_ORDER_XYZ)
	e.x = v
	c.skeleton.set_bone_pose_rotation(i, Basis.from_euler(e, EULER_ORDER_XYZ).get_rotation_quaternion())


static func _ra(c: HubNpcs.Cherub, nm: String, ax: float, ay: float, az: float, set_y: Variant = null) -> void:
	if not c.has_bone(nm):
		return
	var i: int = c.bones[nm]
	var e := c.skeleton.get_bone_pose_rotation(i).get_euler(EULER_ORDER_XYZ)
	e.x += ax
	e.y = float(set_y) if set_y != null else e.y + ay
	e.z += az
	c.skeleton.set_bone_pose_rotation(i, Basis.from_euler(e, EULER_ORDER_XYZ).get_rotation_quaternion())


## JS the Cherub actor's update: strain = the seat-shaking effort (0..1), buzz = how hard the chair is rattling right now, look = where to turn his head, talk = his voice level
func _cherub_pose(t: float, dt: float) -> void:
	var a := cherub
	var c: Dictionary = cherub_cine if cherub_cine != null else {}
	var strain: float = c.get("strain", 0.0)
	var buzz: float = c.get("buzz", 0.0)
	var dead: float = c.get("dead", 0.0)
	if c.has("yaw"):      # swivels round in his chair (the boss intro's alt ending)
		a.R_yaw = c["yaw"]
	if c.has("look"):
		var lk: Vector2 = c["look"]
		a.look_at_point(lk.x, lk.y)
	else:
		a.look_away()
	a.set_talk(float(c.get("talk", 0.0)) > .12)
	a.update(t, dt)
	var shake := .012 * buzz + .004 * strain
	a.position = Vector3(a.R_x + shake * sin(t * 91.0), a.R_y + .035 * buzz * absf(sin(t * 37.0)) + .02 * strain, a.R_z + shake * sin(t * 73.0 + 1.0))
	a.rotation.z = .025 * buzz * sin(t * 53.0)
	for s: String in ["L", "R"]:
		_rx(a, "thigh" + s, -1.45)
		_rx(a, "shin" + s, 1.55)
		_rx(a, "foot" + s, -.1 - .25 * strain)
		if a.has_bone("wing" + s):      # wings flare and buzz with the effort
			_rx(a, "wing" + s, .28 - .2 * strain)
			_ra(a, "wing" + s, 0.0, 0.0, 0.0, (1.0 if s == "L" else -1.0) * (.24 + .5 * strain + .25 * buzz * sin(t * 41.0)))
	_ra(a, "neck", .16 * (1.0 - strain) - .22 * strain + 1.0 * dead - .3 * float(c.get("flinch", 0.0)), 0.0, 0.0)      # head tips back as he pushes
	_ra(a, "chest", .09 - .12 * strain + .7 * dead, 0.0, 0.0)
	_ra(a, "head", 0.0, 0.0, .05 * buzz * sin(t * 29.0))
	_cherub_statue.global_transform = a.global_transform
	for i in hands.size():      # stops typing and grips the desk edge
		hands[i].position.y = .91 + maxf(0.0, sin(t * 15.0 + i * 2.2)) * .018 * (1.0 - strain) + .12 * strain


static func _topple(a: Body, k: float) -> void:      # cine.dead (0..1): a felled man topples straight backwards about his feet (yaw-relative), lying along the floor at 1
	a.root.rotation.x = -1.52 * k
	a.root.position.y = FLOOR + .15 * k


static func _skel(n: Node) -> Skeleton3D:
	var st: Array[Node] = [n]
	while not st.is_empty():
		var c: Node = st.pop_back()
		st.append_array(c.get_children())
		if c is Skeleton3D:
			return c
	return null


## the exported statue gives the actor's place and the model's fit; its skinned body goes, its rifle stays
func _load(file: String, frozen: String, interior: Node3D, albedo: Texture2D, coat: bool) -> Body:
	if not ResourceLoader.exists(file):
		return null
	var nodes: Array = L.node_named(frozen)
	if nodes.is_empty():
		return null
	var statue: Node3D = nodes[0]
	var fit := Transform3D.IDENTITY
	if statue.get_child_count() > 0 and statue.get_child(0) is Node3D:
		fit = (statue.get_child(0) as Node3D).transform
	var st: Array[Node] = [statue]
	while not st.is_empty():
		var c: Node = st.pop_back()
		if String(c.name).contains("rifle"):
			continue
		st.append_array(c.get_children())
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false
	var body := Body.new()
	body.root = Node3D.new()
	body.root.name = frozen
	(interior if interior != null else L).add_child(body.root)
	body.root.global_transform = statue.global_transform
	var model: Node3D = (load(file) as PackedScene).instantiate()
	model.transform = fit
	body.root.add_child(model)
	body.sk = _skel(model)
	if body.sk == null:
		body.root.queue_free()
		statue.visible = true
		return null
	var mi: MeshInstance3D = null
	st = [model]
	while not st.is_empty():
		var c: Node = st.pop_back()
		st.append_array(c.get_children())
		if c is MeshInstance3D:
			var m := c as MeshInstance3D
			if mi == null and m.skin != null:
				mi = m
			for s in m.get_surface_override_material_count():
				var src := m.mesh.surface_get_material(s)
				if src is StandardMaterial3D:
					var d := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
					if albedo != null:      # (the JS's TextureLoader flips it, the GLB's own maps are not: the same flip here)
						d.albedo_texture = albedo
						d.uv1_scale = Vector3(1, -1, 1)
						d.uv1_offset = Vector3(0, 1, 0)
					d.normal_enabled = false
					d.roughness_texture = null
					d.metallic_texture = null
					d.roughness = .88
					m.set_surface_override_material(s, d)
	var sk := body.sk
	for i in sk.get_bone_count():
		var nm := sk.get_bone_name(i).replace("mixamorig:", "").replace("mixamorig_", "").replace("mixamorig", "")
		body.b[nm] = i
	_to_bind(body, mi)
	if coat and mi != null:
		_anchor_coat(body, mi)
	return body


## This export's node pose is NOT the pose the skin was bound in (legs bent, an arm up): every bone goes into the real bind pose from the skin, then the axes come from there (JS makeMixamoRig)
static func _to_bind(B: Body, mi: MeshInstance3D) -> void:
	var sk := B.sk
	var skin := mi.skin if mi != null else null
	if skin != null:
		var glob := {}
		for k in skin.get_bind_count():
			var nm := skin.get_bind_name(k)
			var i := sk.find_bone(nm) if nm != "" else skin.get_bind_bone(k)
			if i >= 0:
				glob[i] = skin.get_bind_pose(k).affine_inverse()
		for i in sk.get_bone_count():      # (Godot's bones come parents first)
			if not glob.has(i):
				continue
			var par := sk.get_bone_parent(i)
			var pm: Transform3D = glob[par] if glob.has(par) else Transform3D.IDENTITY
			var loc: Transform3D = pm.affine_inverse() * glob[i]
			sk.set_bone_pose_position(i, loc.origin)
			sk.set_bone_pose_rotation(i, loc.basis.get_rotation_quaternion())
			sk.set_bone_pose_scale(i, loc.basis.get_scale())
	sk.force_update_all_bone_transforms()
	for k: String in ["Hips", "LeftArm", "RightArm", "Head"]:
		if not B.b.has(k):
			return
	B.left = (B.gp("LeftArm") - B.gp("RightArm")).normalized()
	var u := (B.gp("Head") - B.gp("Hips")).normalized()
	B.up = (u - B.left * u.dot(B.left)).normalized()
	B.fwd = B.left.cross(B.up).normalized()
	for n: String in B.b:
		var i: int = B.b[n]
		B.bind_q[i] = sk.get_bone_pose_rotation(i)
		var par := sk.get_bone_parent(i)
		var pq: Quaternion = sk.get_bone_global_pose(par).basis.get_rotation_quaternion() if par >= 0 else Quaternion.IDENTITY
		B.bind_pinv[i] = pq.inverse()
	B.down_l = _arm_down(B, "Left")
	B.down_r = _arm_down(B, "Right")
	var to_sk := sk.global_transform.affine_inverse() * B.root.global_transform
	B.inv_xf = to_sk
	B.rel = to_sk.basis.get_rotation_quaternion()


## how far each arm must turn (about the forward axis) to hang down at the side: from its bind direction to ~10 degrees off vertical
static func _arm_down(B: Body, side: String) -> float:
	var v := B.gp(side + "Hand") - B.gp(side + "Arm")
	var l := v.dot(B.left) * (1.0 if side == "Left" else -1.0)
	var u := v.dot(B.up)
	var phi := atan2(l, -u)
	return .17 - phi if side == "Left" else phi - .17      # +alpha about fwd raises a left arm / lowers a right arm


## The imported coat's tails are skinned to the hands. The moment the arms come forward they drag the back of the coat up behind him like a wing. Hand the far-from-the-arm influences to the torso.
func _anchor_coat(B: Body, mi: MeshInstance3D) -> void:
	var sk := B.sk
	var torso: Array[String] = []
	for n: String in ["Hips", "Spine", "Spine1", "Spine2"]:
		if B.b.has(n):
			torso.append(n)
	var torso_y: Array[float] = []
	for n: String in torso:
		torso_y.append(B.gp(n).y)
	var segs := {}
	for n: String in ["Left", "Right"]:
		for part: String in ["Arm", "ForeArm", "Hand"]:
			var k: String = n + part
			if not B.b.has(k):
				continue
			var i: int = B.b[k]
			var kids := sk.get_bone_children(i)
			var a := sk.get_bone_global_pose(i).origin
			segs[i] = [a, sk.get_bone_global_pose(kids[0]).origin if kids.size() > 0 else a]
	# the mesh's bone numbers are the skin's binds
	var skin := mi.skin
	var bind_to_bone := PackedInt32Array()
	bind_to_bone.resize(skin.get_bind_count())
	var bone_to_bind := {}
	for k in skin.get_bind_count():
		var nm := skin.get_bind_name(k)
		var i := sk.find_bone(nm) if nm != "" else skin.get_bind_bone(k)
		bind_to_bone[k] = i
		bone_to_bind[i] = k
	var src := mi.mesh as ArrayMesh
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ids: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var wts: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := ids.size() / maxi(1, pos.size())
		for v in pos.size():
			var p := pos[v]
			for q in per:
				var o := v * per + q
				if wts[o] < .01:
					continue
				var bi := bind_to_bone[ids[o]]
				if not segs.has(bi):
					continue
				var a: Vector3 = segs[bi][0]
				var d: Vector3 = segs[bi][1] - a
				var u := clampf((p - a).dot(d) / maxf(1e-6, d.length_squared()), 0.0, 1.0)
				if (a + d * u).distance_to(p) <= .24 / maxf(.001, mi.global_transform.basis.get_scale().x):
					continue
				var best := 0
				var gap := INF
				for j in torso_y.size():
					if absf(torso_y[j] - p.y) < gap:
						gap = absf(torso_y[j] - p.y)
						best = j
				ids[o] = bone_to_bind.get(B.b[torso[best]], ids[o])
		arr[Mesh.ARRAY_BONES] = ids
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), arr)
		out.surface_set_material(s, mi.get_surface_override_material(s) if mi.get_surface_override_material(s) != null else src.surface_get_material(s))
	mi.mesh = out


## JS makeMixamoRig update, standing (speed 0)
func _idle(B: Body, time: float) -> void:
	var br := sin(time * 1.7)
	var sway := sin(time * .6)
	var L_ := B.left
	var U_ := B.up
	var F_ := B.fwd
	B.set_rot("Hips", [[F_, .012 * sway]])
	B.set_rot("Spine", [[L_, .01 * br]])
	B.set_rot("Spine1", [[L_, .014 * br]])
	B.set_rot("Spine2", [[L_, .01 * br]])
	B.set_rot("Neck", [[U_, .03 * sway]])
	B.set_rot("Head", [[U_, .05 * sin(time * .43)], [L_, .01 * br]])
	B.set_rot("LeftUpLeg", [])
	B.set_rot("RightUpLeg", [])
	B.set_rot("LeftLeg", [])
	B.set_rot("RightLeg", [])
	B.set_rot("LeftArm", [[F_, B.down_l], [L_, .02 * br]])
	B.set_rot("RightArm", [[F_, B.down_r], [L_, .02 * br]])
	B.set_rot("LeftForeArm", [[L_, -(.16 + .03 * br)]])
	B.set_rot("RightForeArm", [[L_, -(.16 + .03 * br)]])


static func _smooth(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


static func _hash(k: float) -> float:
	var s := sin(k * 127.1 + 311.7) * 43758.5453
	return (s - floorf(s)) * 2.0 - 1.0


## Slow glances: dwell on one spot for most of the period, then ease to the next.
static func _glance(t: float, period: float, seed_: float) -> float:
	var u := t / period
	var k := floorf(u)
	var f := _smooth(minf(1.0, (u - k) * 3.5))
	return _hash(k + seed_ - 1.0) * (1.0 - f) + _hash(k + seed_) * f


## a.cine (the boss intro, the office shut-up): attend = eyes on the visitor, hand off the chin; talk = voice level; anger = lunges at the desk, palms flat on it; hit, dead.
func _boss_pose(t: float) -> void:
	var a := boss
	_idle(a, t)
	var c: Dictionary = a.cine if a.cine != null else {}
	var att: float = c.get("attend", 0.0)
	var talk: float = c.get("talk", 0.0)
	var ang: float = c.get("anger", 0.0)
	var roam := 1.0 - att
	a.root.position = Vector3(a.home.x + sin(a.root.rotation.y) * .42 * ang, a.home.y, a.home.z + cos(a.root.rotation.y) * .42 * ang)
	# Working a problem: leans toward the wall, eyes travelling from screen to screen, a finger drumming the chin in bursts, the odd slow stroke, and a shifting of weight.
	var br := sin(t * 1.4)
	var nod := talk * sin(t * 6.7)
	a.swing("Hips", 0.0, .03 * sin(t * .23), .025 * sin(t * .19))
	a.swing("Spine", .05 + .012 * br + .22 * ang, -.02 * sin(t * .23) * roam, -.015 * sin(t * .19))
	a.swing("Spine1", .03 + .01 * br + .14 * ang + .02 * talk)
	a.swing("Neck", .03 - .2 * ang, .12 * _glance(t, 3.7, 1.0) * roam, .03 * sin(t * .21))
	a.swing("Head", .06 + .1 * _glance(t, 4.9, 5.0) * roam - .08 * att - .24 * ang + .05 * nod, .22 * _glance(t, 3.7, 1.0) * roam + .04 * talk * sin(t * 2.3), .06 * sin(t * .17 + 2.0) * roam)
	var gate := maxf(0.0, sin(t * .37 + 1.0) - .5) / .5 * roam
	var drum := absf(sin(t * 9.0)) * .012 * gate
	var chin := Vector3(-.04 + .012 * sin(t * .5) * (1.0 - gate), 1.58 + drum, .21 + .014 * sin(t * .5))
	var point := Vector3(-.3 + .04 * sin(t * 2.1) * talk, 1.16 + .07 * talk * sin(t * 4.3), .4 + .05 * talk)
	a.reach("Right", chin.lerp(point, att).lerp(Vector3(-.27, 1.06, .8), ang), Vector3(-.44, 1.25, .22))
	a.reach("Left", Vector3(-.12, 1.15 + .006 * br, .22).lerp(Vector3(.27, 1.06, .8), ang), Vector3(.4, 1.04, .09))
	var hit: float = c.get("hit", 0.0)
	if hit != 0.0:      # the round snaps his head back
		a.swing("Head", -.7 * hit)
	_topple(a, c.get("dead", 0.0))


func _shit_pose(t: float) -> void:
	var a := shit
	_idle(a, t)
	# Bored sentry: slow breathing with the odd deep sigh, weight shifting hip to hip, eyes drifting over the room.
	var sigh := 1.0 + 1.6 * pow(maxf(0.0, sin(t * .33)), 8.0)
	var br := sin(t * 1.5) * sigh
	a.swing("Hips", 0.0, .035 * sin(t * .31), .02 * sin(t * .43) + .065 + .018 * sin(t * .7))
	a.swing("Spine", 0.0, 0.0, -.045)
	a.swing("Spine1", .012 * br, -.03 * sin(t * .31), -.015 * sin(t * .43))
	a.swing("Spine2", .02 * br)
	# a.cine (the Shit-chan scene): attend = eyes on Prog (look = his bearing from her facing), talk = her voice level.
	var c: Dictionary = a.cine if a.cine != null else {}
	var att: float = c.get("attend", 0.0)
	var talk: float = c.get("talk", 0.0)
	var look: float = float(c.get("look", 0.0)) * att
	var roam := 1.0 - att
	if c.has("yaw"):      # turns round to face the room (the boss intro's alt ending)
		a.root.rotation.y = c["yaw"]
	var gy := _glance(t, 4.4, 3.0) * roam
	var gx := _glance(t, 5.3, 11.0) * roam
	a.swing("Neck", .02 + .03 * gx, .12 * gy + .4 * look, .02 * sin(t * .27))
	a.swing("Head", .03 + .04 * gx - .04 * att + .04 * talk * sin(t * 6.3), .2 * gy + .55 * look, .03 * sin(t * .27 + 1.0) + .1 * talk * sin(t * 2.2))
	var flinch: float = c.get("flinch", 0.0)
	if flinch != 0.0:
		a.swing("Spine1", -.3 * flinch)
		a.swing("Head", -.25 * flinch)
	a.reach("Left", Vector3(.19, 1.02 + .004 * br, -.01), Vector3(.62, 1.1, .04))
	a.reach("Right", _gun_stock, Vector3(-.55, 1.05, .18))
	_topple(a, c.get("dead", 0.0))


func update(_t: float, dt: float) -> void:
	var real := Game.frame_real_dt if Game.paused == false else 0.0      # (the world is held still during a dialogue or a cutscene; these people are not: their own clock, as the JS's real-time one)
	_clock += real
	var t := _clock
	boss_actor.update(real)
	if cherub != null:
		_cherub_pose(t, real)
	else:      # Cherub: the two hands typing
		for i in hands.size():
			hands[i].position.y = .91 + maxf(0.0, sin(t * 15.0 + i * 2.2)) * .018
	_acc += real
	var in_cine := (boss != null and boss.cine != null) or (shit != null and shit.cine != null)
	if _acc < 1.0 / 30.0 and not in_cine:
		return
	_acc = 0.0
	if boss != null:
		_boss_pose(t)
	if shit != null:
		_shit_pose(t)
