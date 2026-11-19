class_name HubNpcs
extends RefCounted
## The hub's talkers, as bodies (JS npcs/puppy-npc.js, winged-npc.js, cherub-npc.js, armchair-general.js update(), statement for statement, on the rig of npc_rig.gd). Dialogue itself is core/dialogue.gd: these only look, talk and idle.
## Their rest poses are the export's, each update sets what the JS sets. The grey and green aliens are the real models (enemies/gray_alien_npc.gd).


static func _wrap(a: float) -> float:
	return atan2(sin(a), cos(a))


## JS createPuppyNPC: a golden-tan pup standing on two legs
class Puppy:
	extends NpcRig
	var R_x := 0.0
	var R_z := 0.0
	var R_yaw := 0.0
	var talk := false
	var look := false
	var look_x := 0.0
	var look_z := 0.0
	var hy := 0.0
	var hp := 0.0
	var hr := 0.0
	var blink := 0.0
	var next_blink := 2.0
	var jaw_o := 0.0
	const LEGS := ["hipL", "kneeL", "hipR", "kneeR"]

	func place(x: float, y: float, z: float, yaw: float) -> void:
		R_x = x
		R_z = z
		R_yaw = yaw
		position = Vector3(x, y, z)
		rotation.y = yaw

	func set_talk(v: bool) -> void:
		talk = v

	func look_at_point(x: float, z: float) -> void:
		look = true
		look_x = x
		look_z = z

	func look_away() -> void:
		look = false

	func mouth_world() -> Vector3:
		return joint_point("mouth", Vector3.ZERO)

	func update(time: float, dt: float) -> void:
		dt = clampf(dt, 0.0, 0.05)
		# head: turn to the look target (clamped), a curious tilt, otherwise a lazy sniff around
		var ty := sin(time * 0.45) * 0.25
		var tp := sin(time * 0.7) * 0.04
		var tr := 0.0
		if look:
			ty = clampf(HubNpcs._wrap(atan2(look_x - R_x, look_z - R_z) - R_yaw), -1.0, 1.0)
			tp = -0.05
			tr = 0.2 * sin(time * 0.9) + 0.1
		var k := 1.0 - exp(-8.0 * dt)
		hy += (ty - hy) * k
		hp += (tp - hp) * k
		hr += (tr - hr) * k
		rot("neck", hp, hy, hr)
		# jaw + tongue
		var open := 0.18 + 0.26 * absf(sin(time * 15.0)) if talk else 0.02 + 0.02 * sin(time * 2.2)
		jaw_o += (open - jaw_o) * (1.0 - exp(-25.0 * dt))
		rot("jaw", jaw_o, 0.0, 0.0)
		show_part("inner", jaw_o > 0.07)
		show_part("tongue", jaw_o > 0.07)
		# breathing, weight shift, bounce when talking
		var br := sin(time * 2.4)
		var bob := absf(sin(time * 7.0)) * 0.012 if talk else 0.0
		scl("torso", Vector3(1.15 * (1.0 + 0.012 * br), 1.0 + 0.018 * br, 1.0 + 0.012 * br))
		pos("body", Vector3(0.0, bob, 0.0))
		rot("body", 0.0, 0.0, sin(time * 0.6) * 0.02)
		# tail wag
		rot("tail", -0.1 + 0.05 * sin(time * 3.0), sin(time * (15.0 if talk else 7.0)) * (0.7 if talk else 0.45), 0.0)
		# ears flop with the head and a little breeze
		for i in 2:
			var s := 1.0 if i == 1 else -1.0
			rot("ear%d" % i, 0.05 * sin(time * 2.3 + i * 2.0) - hp * 0.8, 0.0, s * (0.35 + 0.06 * sin(time * 1.7 + i) + jaw_o * 0.4 + absf(hy) * 0.1))
		# arms sway, legs stand square
		for s: float in [-1.0, 1.0]:
			var u := "L" if s < 0.0 else "R"
			rot("sh" + u, sin(time * 1.3 + s) * 0.05 + (0.2 * sin(time * 6.0 + s) if talk else 0.0), 0.0, s * (0.12 + (0.1 if talk else 0.0)))
			rot("el" + u, -0.25, 0.0, 0.0)
		# blink
		next_blink -= dt
		if next_blink <= 0.0:
			blink = 0.14
			next_blink = 2.0 + randf() * 3.0
		blink = maxf(0.0, blink - dt)
		var bl := sin((1.0 - blink / 0.14) * PI) if blink > 0.0 else 0.0
		for i in 2:
			scl("eye%d" % i, Vector3(1.0, 1.0 - 0.9 * bl, 1.0))


## JS createWingedNPC: pale blotchy skin, bulging eyes, two big fleshy paddle wings
class Winged:
	extends NpcRig
	var R_x := 0.0
	var R_z := 0.0
	var R_yaw := 0.0
	var talk := false
	var look := false
	var look_x := 0.0
	var look_z := 0.0
	var hy := 0.0
	var hp := 0.0
	var hr := 0.0
	var blink := 0.0
	var next_t := 2.0
	var jaw_o := 0.0
	var gx := 0.0
	var gy := 0.0
	var gt := 0.0
	var pup := {"L": Vector2.ZERO, "R": Vector2.ZERO}
	var pup_z := {}

	func place(x: float, y: float, z: float, yaw: float) -> void:
		R_x = x
		R_z = z
		R_yaw = yaw
		position = Vector3(x, y, z)
		rotation.y = yaw

	func set_talk(v: bool) -> void:
		talk = v

	func look_at_point(x: float, z: float) -> void:
		look = true
		look_x = x
		look_z = z

	func look_away() -> void:
		look = false

	func mouth_world() -> Vector3:
		return joint_point("mouthPt", Vector3.ZERO)

	func update(time: float, dt: float) -> void:
		dt = clampf(dt, 0.0, 0.05)
		# head: slow wobble, or turned to the target with an uneasy tilt
		var ty := sin(time * 0.5) * 0.3
		var tp := sin(time * 0.8) * 0.05
		var tr := sin(time * 0.37) * 0.08
		if look:
			ty = clampf(HubNpcs._wrap(atan2(look_x - R_x, look_z - R_z) - R_yaw), -1.0, 1.0)
			tp = 0.04
			tr = -0.14 + 0.05 * sin(time * 1.1)
		var k := 1.0 - exp(-6.0 * dt)
		hy += (ty - hy) * k
		hp += (tp - hp) * k
		hr += (tr - hr) * k
		rot("neck", hp * 0.5, hy * 0.6, hr * 0.5)
		rot("head", hp * 0.5, hy * 0.4, hr * 0.5)
		# lips
		var open := 0.012 + 0.03 * absf(sin(time * 12.0)) if talk else 0.003 + 0.003 * sin(time * 1.6)
		jaw_o += (open - jaw_o) * (1.0 - exp(-22.0 * dt))
		var jp := get_pos("jaw")
		jp.y = -jaw_o
		pos("jaw", jp)
		var up := get_pos("upper")
		up.y = 0.012 + jaw_o * 0.15
		pos("upper", up)
		# eyes: the stare wanders, one pupil a little off from the other
		gt -= dt
		if gt <= 0.0:
			gt = 0.7 + randf() * 2.2
			gx = (randf() - 0.5) * 0.026
			gy = (randf() - 0.5) * 0.022
		for u: String in ["L", "R"]:
			var right := u == "R"
			var p := get_pos("pup" + u)
			var q := 1.0 - exp(-9.0 * dt)
			p.x += (gx * (1.0 if right else 0.6) - p.x) * q
			p.y += (gy * (0.6 if right else 1.0) - p.y) * q
			pos("pup" + u, p)
		next_t -= dt
		if next_t <= 0.0:
			blink = 0.2
			next_t = 2.2 + randf() * 3.5
		blink = maxf(0.0, blink - dt)
		var bl := sin((1.0 - blink / 0.2) * PI) if blink > 0.0 else 0.0
		for u: String in ["L", "R"]:
			show_part("lid" + u, bl > 0.06, Vector3(0.088, 0.085 * bl, 0.08))
		# body: breathing belly, a gentle sway, wings fidget (and flare a bit when he talks)
		var br := sin(time * 2.1)
		scl("belly", Vector3(0.13 * (1.0 + 0.015 * br), 0.165, 0.115 * (1.0 + 0.04 * br)))
		rot("body", 0.0, 0.0, sin(time * 0.5) * 0.015)
		pos("body", Vector3(0.0, sin(time * 1.1) * 0.004, 0.0))
		for s: float in [-1.0, 1.0]:
			var u := "L" if s < 0.0 else "R"
			var flare := 0.12 * absf(sin(time * 6.0 + s)) if talk else 0.0
			rot("wing" + u, 0.04 * sin(time * 0.9 + s) + 0.12, 0.0, s * (1.1 - flare - 0.04 * sin(time * 1.3 + s * 2.0)))
			rot("hip" + u, 0.0, 0.0, s * 0.03)
			rot("knee" + u, 0.05, 0.0, 0.0)


## JS createCherubNPC: the Meshy sculpt on its 17-bone skeleton, painted in vertex colours
class Cherub:
	extends NpcRig
	var R_x := 0.0
	var R_y := 0.0
	var R_z := 0.0
	var R_yaw := 0.0
	var talk := false
	var look := false
	var look_x := 0.0
	var look_z := 0.0
	var hy := 0.0
	var hp := 0.0
	var hr := 0.0
	var blink := 0.0
	var next_t := 2.0
	var jaw_o := 0.0
	var gx := 0.0
	var gy := 0.0
	var gt := 0.0
	var hurt_k := 0.0
	var dead := false
	var fall := 0.0
	var rests: Dictionary = {}      # bind-pose rotations, animated on top of (JS rest)
	var eyes: Array = []            # [{ "pup": bone, "lid": bone, "lid_y": , "s": side }]

	func prepare(list: Array) -> void:
		for nm: String in bones:
			rests[nm] = skeleton.get_bone_pose_rotation(bones[nm]).get_euler(EULER_ORDER_XYZ)
		# eyes: a group under the head bone holding white, pupil, lid, in that order (see the JS)
		var head: int = bones.get("head", -1)
		var order := 0
		for i in list.size():
			if int(list[i]["parent"]) == head and String(list[i]["name"]) == "":
				eyes.append({"s": -1.0 if order == 0 else 1.0, "pup": i + 2, "lid": i + 3})
				order += 1

	func place(x: float, y: float, z: float, yaw: float) -> void:
		R_x = x
		R_y = y
		R_z = z
		R_yaw = yaw
		position = Vector3(x, y, z)
		rotation.y = yaw

	func set_talk(v: bool) -> void:
		talk = v

	func look_at_point(x: float, z: float) -> void:
		look = true
		look_x = x
		look_z = z

	func look_away() -> void:
		look = false

	func mouth_world() -> Vector3:
		return joint_point("jaw", Vector3(-0.04 + 0.04, 0.29 - 0.3, 0.2 - 0.03))

	func hurt() -> void:
		hurt_k = 1.0

	func die() -> void:
		dead = true
		talk = false

	func revive() -> void:
		dead = false

	func _rs(nm: String, x: float, y: float, z: float) -> void:
		var r: Vector3 = rests[nm]
		rot(nm, r.x + x, r.y + y, r.z + z)

	func update(time: float, dt: float) -> void:
		dt = clampf(dt, 0.0, 0.05)
		fall += ((1.0 if dead else 0.0) - fall) * minf(1.0, dt * (3.5 if dead else 2.0))      # death: topples backwards onto the pavement
		rotation_order = EULER_ORDER_YXZ
		rotation = Vector3(-1.5 * fall, R_yaw, 0.0)
		position.y = R_y + 0.12 * fall
		if dead:
			talk = false
			look = false
		# head: slow uneasy wobble, or turned to the target with a tilt
		var ty := sin(time * 0.45) * 0.25
		var tp := sin(time * 0.7) * 0.05
		var tr := sin(time * 0.33) * 0.07
		if look:
			ty = clampf(HubNpcs._wrap(atan2(look_x - R_x, look_z - R_z) - R_yaw), -1.0, 1.0)
			tp = 0.05
			tr = 0.12 + 0.04 * sin(time * 1.1)
		var k := 1.0 - exp(-5.0 * dt)
		hy += (ty - hy) * k
		hp += (tp - hp) * k
		hr += (tr - hr) * k
		var hu := hurt_k
		hurt_k = maxf(0.0, hu - dt * 3.2)                          # damage flinch
		_rs("neck", hp * 0.5 - 0.3 * hu, hy * 0.55, hr * 0.5 + 0.12 * hu)
		_rs("head", hp * 0.5 - 0.35 * hu, hy * 0.45, hr * 0.5 - 0.1 * hu)
		# jaw
		var open := (0.06 + 0.16 * absf(sin(time * 11.0)) if talk else 0.01 + 0.01 * sin(time * 1.4)) + 0.3 * hu
		jaw_o += (open - jaw_o) * (1.0 - exp(-20.0 * dt))
		_rs("jaw", jaw_o, 0.0, 0.0)
		# breathing + sway
		var br := sin(time * 2.0)
		_rs("spine", 0.02 * br - 0.12 * hu, 0.0, sin(time * 0.5) * 0.015)
		_rs("chest", -0.03 * br - 0.1 * hu, 0.0, 0.0)
		_rs("hips", 0.0, 0.0, -sin(time * 0.5) * 0.01)
		scl("chest", Vector3(1.0 + 0.012 * br, 1.0, 1.0 + 0.025 * br))
		# wings: fidget, flare a bit when talking
		for s: float in [-1.0, 1.0]:
			var side := "L" if s < 0.0 else "R"
			var flare := (0.14 * absf(sin(time * 6.0 + s)) if talk else 0.0) + 0.45 * hu
			var f := 0.05 * sin(time * 1.3 + s * 2.0)
			_rs("wing" + side, 0.05 * sin(time * 0.9 + s), 0.0, s * (flare + f))
			_rs("wingTip" + side, 0.0, 0.0, s * (flare * 0.6 + 0.04 * sin(time * 1.7 + s)))
		# eyes: the stare wanders, one pupil a little off from the other; skin lids blink
		gt -= dt
		if gt <= 0.0:
			gt = 0.7 + randf() * 2.2
			gx = (randf() - 0.5) * 0.024
			gy = (randf() - 0.5) * 0.02
		next_t -= dt
		if next_t <= 0.0:
			blink = 0.2
			next_t = 2.2 + randf() * 3.5
		blink = maxf(0.0, blink - dt)
		var bl := sin((1.0 - blink / 0.2) * PI) if blink > 0.0 else 0.0
		for e: Dictionary in eyes:
			var s: float = e.s
			var pi_: int = e.pup
			var p := skeleton.get_bone_pose_position(pi_)
			var kk := 1.0 - exp(-9.0 * dt)
			p.x += (gx * (1.0 if s > 0.0 else 0.6) - p.x) * kk
			p.y += (gy * (0.6 if s > 0.0 else 1.0) - p.y) * kk
			skeleton.set_bone_pose_position(pi_, p)
			var li: int = e.lid
			skeleton.set_bone_pose_scale(li, Vector3(0.07, 0.065 * maxf(bl, 0.01), 0.054) if bl > 0.06 else Vector3.ONE * 0.0001)
			skeleton.set_bone_pose_position(li, Vector3(0.0, 0.065 * (1.0 - bl) * 0.6, 0.0))


## JS createArmchairGeneral: one reduced mesh and one 512 px colour map, with weighted breathing and burger bites. The JS rewrites every vertex in script; here the same sums run in the vertex shader.
class ArmchairGeneral:
	extends NpcRig
	var clock := 0.0
	var mat_rid: RID
	const VERT := "{ float x = VERTEX.x, y = VERTEX.y, z = VERTEX.z;\n\tfloat weight = smoothstep(0.35, 1.1, y);\n\tfloat hand = smoothstep(0.04, 0.13, x) * smoothstep(1.06, 1.23, y) * smoothstep(0.02, 0.2, z);\n\tfloat head = smoothstep(1.39, 1.5, y) * (1.0 - smoothstep(0.11, 0.23, abs(x)));\n\tfloat chin = smoothstep(1.34, 1.4, y) * (1.0 - smoothstep(1.44, 1.49, y)) * (1.0 - smoothstep(0.07, 0.14, abs(x))) * smoothstep(0.12, 0.25, z);\n\tVERTEX.x = x * (1.0 + uBreath * weight * 0.018) + uSway * weight * 0.025 + uBite * (-0.085 * hand + 0.025 * head);\n\tVERTEX.y = y + uBreath * weight * 0.016 + uBite * (0.075 * hand - 0.025 * head) - uJaw * chin;\n\tVERTEX.z = z * (1.0 + uBreath * weight * 0.035) + uBreath * weight * 0.012 + uBite * (-0.055 * hand + 0.055 * head); }"

	func build_flat(data: Dictionary, bin: PackedByteArray) -> void:
		var mi := MeshInstance3D.new()
		mi.mesh = NpcRig.flat_mesh(data, bin)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 0.18      # (the hand reaching toward the mouth, in the fixed culling bounds)
		add_child(mi)
		var m := mi.mesh.surface_get_material(0) as StandardMaterial3D
		mat_rid = m.get_rid()
		Game.view.material_look.patch(m, {"decl": "uniform float uBreath;\nuniform float uSway;\nuniform float uBite;\nuniform float uJaw;", "vert": VERT})

	func place(x: float, y: float, z: float, yaw: float) -> void:
		position = Vector3(x, y, z)
		rotation.y = yaw

	func mouth_world() -> Vector3:
		return global_transform * Vector3(0.0, 1.38, 0.25)

	func update(_time: float, dt: float) -> void:
		if dt <= 0.0:
			return
		clock += dt
		var breath := sin(clock * TAU / 2.1)
		var sway := sin(clock * TAU / 4.7)
		var phase := fmod(clock, 9.0)
		var bite := smoothstep(2.0, 3.0, phase) * (1.0 - smoothstep(3.7, 4.7, phase))
		var chew := smoothstep(3.0, 3.3, phase) * (1.0 - smoothstep(5.0, 5.6, phase))
		var jaw := chew * (0.5 + 0.5 * sin(clock * 15.0)) * 0.012
		RenderingServer.material_set_param(mat_rid, &"uBreath", breath)
		RenderingServer.material_set_param(mat_rid, &"uSway", sway)
		RenderingServer.material_set_param(mat_rid, &"uBite", bite)
		RenderingServer.material_set_param(mat_rid, &"uJaw", jaw)


## A talker that is a dressed gray or green alien from a level's rigs.json (the MOTHERSHIP's valet, coat check, MC, janitor and captives): the export's rig, in the pose it was exported in. Only the idle head, the look and the mouth are animated. (The hub's own two aliens are the real models.)
class AlienNpc:
	extends NpcRig
	var R_x := 0.0
	var R_z := 0.0
	var R_yaw := 0.0
	var talk := false
	var look := false
	var look_x := 0.0
	var look_z := 0.0
	var green := false
	var hd_y := 0.0
	var hd_p := 0.0
	var hd_r := 0.0
	var mouth_rest := Vector3.ONE

	func prepare(id: String) -> void:
		green = id == "green_alien"
		if bones.has("mouthHole"):
			mouth_rest = skeleton.get_bone_pose_scale(bones["mouthHole"])

	func place(x: float, y: float, z: float, yaw: float) -> void:
		R_x = x
		R_z = z
		R_yaw = yaw
		position = Vector3(x, y, z)
		rotation.y = yaw

	func set_talk(v: bool) -> void:
		talk = v

	func look_at_point(x: float, z: float) -> void:
		look = true
		look_x = x
		look_z = z

	func look_away() -> void:
		look = false

	func mouth_world() -> Vector3:
		return joint_point("head", Vector3(0.0, 0.1, 0.16)) if bones.has("head") else global_position + Vector3(0.0, 1.5, 0.0)

	func update(time: float, dt: float) -> void:
		if not bones.has("head"):
			return
		dt = clampf(dt, 0.0, 0.05)
		var look_yaw := HubNpcs._wrap(atan2(look_x - R_x, look_z - R_z) - R_yaw) if look else NAN
		var ty: float
		var tp: float
		var tr := 0.0
		if green:      # JS case 'lean': back flat on the wall, one foot up on it
			var tk := 1.0 if talk else 0.0
			ty = clampf(look_yaw if look else 0.0, -0.9, 0.9) + (1.0 - tk) * sin(time * 0.5) * 0.18
			tp = 0.05 + 0.03 * tk * sin(time * 9.0)
			tr = 0.04
		else:          # JS case 'idle'
			ty = sin(time * 0.5) * 0.45 if not look else clampf(look_yaw, -0.9, 0.9)
			tp = sin(time * 0.33) * 0.05
			rot("hips", 0.0, 0.0, sin(time * 0.4) * 0.03)
			rot("spine", sin(time * 1.5) * 0.01, 0.0, 0.0)
		var k := 1.0 - exp(-12.0 * dt)
		hd_y += (ty - hd_y) * k
		hd_p += (tp - hd_p) * k
		hd_r += (tr - hd_r) * k
		rot("head", hd_p, hd_y, hd_r)
		if bones.has("mouthHole"):      # JS: the mouth opens while he is talking
			var open := 0.35 + 0.65 * absf(sin(time * 13.0)) if talk else 0.0
			skeleton.set_bone_pose_scale(bones["mouthHole"], Vector3(mouth_rest.x, 0.001 + open * 0.016, mouth_rest.z))


## one actor per talker in life.json; the talkers themselves are added by HubLevel, with these as their actors
static func build(level: ExportedLevel, J: Dictionary, bin: PackedByteArray) -> Dictionary:
	var out := {}
	var group := Node3D.new()
	group.name = "HubNpcs"
	level.add_child(group)
	var npcs: Dictionary = J.get("npcs", {})
	for id: String in npcs:
		if id == "winged" or id == "cherub":      # not on the street any more (user, 2026-11-16); the office builds its own cherub from the same data
			continue
		var d: Dictionary = npcs[id]
		if id == "green_alien" or id == "gray_alien":      # the real models: JS createGreenAlienLeaner, createGrayAlienNPC
			var al: GrayAlienNpc = GreenAlienLeaner.new() if id == "green_alien" else GrayAlienNpc.new()
			al.name = id
			group.add_child(al)
			al.place(float(d["x"]), float(d["y"]), float(d["z"]), float(d["yaw"]))
			out[id] = al
			continue
		var a: NpcRig
		match id:
			"puppy":
				a = Puppy.new()
			"winged":
				a = Winged.new()
			"cherub":
				a = Cherub.new()
			"armchair_general":
				a = ArmchairGeneral.new()
			_:
				a = AlienNpc.new()
		a.name = id
		group.add_child(a)
		if a is ArmchairGeneral:
			(a as ArmchairGeneral).build_flat(d, bin)
		else:
			a.build(d, bin)
		if a is Cherub:
			(a as Cherub).prepare(d["bones"])
		elif a is AlienNpc:
			(a as AlienNpc).prepare(id)
		a.call(&"place", float(d["x"]), float(d["y"]), float(d["z"]), float(d["yaw"]))
		out[id] = a
	return out
