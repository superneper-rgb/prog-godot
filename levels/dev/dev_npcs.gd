class_name DevNpcs
extends RefCounted
## DEV level NPC catalogue's makers (JS levels/dev/npcs.js, npcs/mixamo-rig.js, npcs/frug.js): make(def) -> an Inst { root, update(time, dt), set_move(v), mats }. Generic .glb (plays the named / first clip), the imported Mixamo bodies (The Boss, Shit-chan: a bind-pose-aware procedural idle and walk), Frug, the Pale Punk, the gray and green aliens, and the hub's talkers (Puppy, Winged, Cherub: their rigs are read from the hub's export).

const LIFE_J := "res://assets/levels/hub/life.json"
const LIFE_BIN := "res://assets/levels/hub/life.bin"
# the game's own NPCs: what the JS BUILT_IN makes. (PROG V2 is the rebuilt Prog: kept out of this port until the user says so.)
const BUILT_IN := [
	{"id": "shit-chan", "name": "SHIT-CHAN", "note": "Ember Vanguard: idles standing and walks (procedural) whenever she is moved", "radius": .4, "height": 1.75, "hp": 160.0, "make": "mixamo", "file": "res://assets/npcs/shit-chan/model-lod.glb", "map": "res://assets/npcs/shit-chan/office-albedo.jpg"},
	{"id": "pale_punk", "name": "PALE PUNK", "note": "Gunshop clerk (own loader, idle + blink)", "radius": .4, "height": 1.85, "hp": 160.0, "make": "pale_punk"},
	{"id": "gray_alien", "name": "GRAY ALIEN", "note": "The enemy gray alien as a harmless NPC (same model + animation, procedural idle)", "radius": .4, "height": 1.5, "hp": 160.0, "make": "gray"},
	{"id": "green_alien", "name": "GREEN ALIEN", "note": "Gray alien model, recoloured green (procedural, idle)", "radius": .4, "height": 1.5, "hp": 160.0, "make": "green"},
	{"id": "puppy", "name": "PUPPY", "note": "Bipedal big-headed pup: tail wag, blink, floppy ears, jaw flap", "radius": .4, "height": 1.45, "hp": 120.0, "make": "talker"},
	{"id": "winged", "name": "WINGED THING", "note": "Pale low-poly creature with paddle wings: blink, wandering stare, lip flap", "radius": .4, "height": 2.05, "hp": 120.0, "make": "talker"},
	{"id": "cherub", "name": "CHERUB", "note": "Grotesque cherub: eyeballs, blink, jaw flap, wing fidget", "radius": .4, "height": 2.0, "hp": 140.0, "make": "talker"},
	{"id": "the_boss", "name": "THE BOSS", "note": "Trench-coat boss: procedural idle / walk", "radius": .4, "height": 1.9, "hp": 220.0, "make": "mixamo", "file": "res://assets/npcs/the-boss/model.glb"},
	{"id": "frug", "name": "FRUG", "note": "Box-headed red bruiser: Meshy clips, feet-fixed walk/run, stands otherwise", "radius": .45, "height": 1.75, "hp": 200.0, "make": "frug", "costume": "muscle"},
	{"id": "frug_suit", "name": "FRUG (SUIT)", "note": "Same model + rig, suit costume", "radius": .45, "height": 1.75, "hp": 200.0, "make": "frug", "costume": "suit"},
	{"id": "prog", "name": "PROG", "note": "Playable character, bind pose", "file": "res://assets/prog.glb", "radius": .4, "height": 1.8, "hp": 200.0},
	{"id": "tommy", "name": "TOMMY", "note": "Playable character, bind pose", "file": "res://assets/tommy.glb", "scale": .68, "radius": .4, "height": 1.33, "hp": 120.0},
]


class Inst:
	var root: Node3D
	var mats: Array[Material] = []
	var alien: GrayAlienNpc = null      # (its batch draws at the robot's own place: the level places it, not the holder)
	var has_move := false

	func update(_time: float, _dt: float) -> void:
		pass

	func set_move(_v: float) -> void:
		pass

	## JS: m.emissive.setRGB(f * 0.7, f * 0.08, f * 0.08)
	func flash(f: float) -> void:
		for m: Material in mats:
			if m is StandardMaterial3D:
				(m as StandardMaterial3D).emission = Color(f * 0.7, f * 0.08, f * 0.08)
			elif m is ShaderMaterial:
				(m as ShaderMaterial).set_shader_parameter(&"flash", Vector3(f * 0.7, f * 0.08, f * 0.08))


## generic .glb NPC: scale, loop an animation clip if the file has one
class GlbInst:
	extends Inst
	func _init(def: Dictionary) -> void:
		var scene: PackedScene = load(def.file)
		root = Node3D.new()
		var model: Node3D = scene.instantiate()
		model.scale = Vector3.ONE * float(def.get("scale", 1.0))
		root.add_child(model)
		DevNpcs.own_mats(model, mats)
		var aps := model.find_children("*", "AnimationPlayer", true, false)
		if not aps.is_empty():
			var ap: AnimationPlayer = aps[0]
			var names := ap.get_animation_list()
			if not names.is_empty():
				var clip: String = def.get("clip", "")
				var use: String = clip if ap.has_animation(clip) else String(names[0])
				ap.get_animation(use).loop_mode = Animation.LOOP_LINEAR
				ap.play(use)
				ap.seek(randf() * ap.current_animation_length)


## JS makeMixamoRig + fbxMaker: this export's node pose is not the pose the skin was bound in, so every bone goes into the real bind pose; the arms hang, and it breathes, or walks when it is moved
class MixamoInst:
	extends Inst
	var B: HubOfficeActors.Body
	var model: Node3D
	var base_y := 0.0
	var height := 1.75
	var speed := 0.0
	var phase := randf() * 6.28
	var w := 0.0
	var bob := 0.0

	func _init(def: Dictionary, holder: Node3D) -> void:
		has_move = true
		height = def.height
		root = Node3D.new()
		holder.add_child(root)      # (in the tree first: the bind pose reads global transforms)
		model = (load(def.file) as PackedScene).instantiate()
		root.add_child(model)
		B = HubOfficeActors.Body.new()
		B.root = root
		B.sk = HubOfficeActors._skel(model)
		var mi: MeshInstance3D = null
		var albedo: Texture2D = load(def.map) if def.has("map") else null
		for c: Node in model.find_children("*", "MeshInstance3D", true, false):
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
					d.roughness = 1.0
					d.metallic = 0.1
					d.emission_enabled = true
					d.emission = Color.BLACK
					m.set_surface_override_material(s, d)
					mats.append(d)
		for i in B.sk.get_bone_count():
			var nm := B.sk.get_bone_name(i).replace("mixamorig:", "").replace("mixamorig_", "").replace("mixamorig", "")
			B.b[nm] = i
		HubOfficeActors._to_bind(B, mi)
		# scaled to its height (the file's own units are ignored), feet on y = 0, centred
		var box := mi.mesh.get_aabb()
		var k := height / box.size.y
		var c := box.get_center()
		model.scale = Vector3.ONE * k
		model.position = Vector3(-c.x * k, -box.position.y * k, -c.z * k)
		base_y = model.position.y

	func set_move(v: float) -> void:
		speed = v

	func update(time: float, dt: float) -> void:
		var walking := speed > 0.2
		var target := 1.0 if walking else 0.0
		w += (target - w) * minf(1.0, dt * 7.0)
		var sp := minf(speed, 3.2)
		var kk := minf(1.25, maxf(0.55, sp / 1.4))
		if w > 0.002:
			phase += dt * PI * 2.0 * sp / 1.5
		var s := sin(phase)
		var c := cos(phase)
		var I := 1.0 - w
		var br := sin(time * 1.7)
		var sway := sin(time * 0.6)
		var swing := 0.5 * kk * w
		var arm_sw := 0.42 * kk * w
		var lift := 0.7 * kk * w
		var L := B.left
		var U_ := B.up
		var F := B.fwd
		B.set_rot("Hips", [[F, 0.012 * sway * I], [U_, 0.1 * kk * s * w]])
		B.set_rot("Spine", [[L, 0.01 * br * I], [U_, -0.05 * kk * s * w]])
		B.set_rot("Spine1", [[L, 0.014 * br * I], [U_, -0.05 * kk * s * w]])
		B.set_rot("Spine2", [[L, 0.01 * br * I], [U_, -0.04 * kk * s * w]])
		B.set_rot("Neck", [[U_, 0.03 * sway * I]])
		B.set_rot("Head", [[U_, 0.05 * sin(time * 0.43) * I + 0.04 * kk * s * w], [L, 0.01 * br * I]])
		B.set_rot("LeftUpLeg", [[L, -swing * s]])
		B.set_rot("RightUpLeg", [[L, swing * s]])
		B.set_rot("LeftLeg", [[L, 0.08 * w + lift * maxf(0.0, c)]])
		B.set_rot("RightLeg", [[L, 0.08 * w + lift * maxf(0.0, -c)]])
		B.set_rot("LeftArm", [[F, B.down_l], [L, 0.02 * br * I + arm_sw * s]])
		B.set_rot("RightArm", [[F, B.down_r], [L, 0.02 * br * I - arm_sw * s]])
		B.set_rot("LeftForeArm", [[L, -(0.16 + 0.03 * br * I + 0.28 * w * maxf(0.0, -s))]])
		B.set_rot("RightForeArm", [[L, -(0.16 + 0.03 * br * I + 0.28 * w * maxf(0.0, s))]])
		bob = 0.018 * kk * w * absf(c)
		model.position.y = base_y + bob * height


## JS createFrug: one mesh, two costumes (muscle.jpg / suit.jpg on the same UVs); Idle / Walking / Running by how fast it is being moved
class FrugInst:
	extends Inst
	var ap: AnimationPlayer
	var current := &""
	var speed := 0.0

	func _init(def: Dictionary) -> void:
		has_move = true
		root = Node3D.new()
		var model: Node3D = (load("res://assets/npcs/frug/model.glb") as PackedScene).instantiate()
		root.add_child(model)
		var map: Texture2D = load("res://assets/npcs/frug/%s.jpg" % ("suit" if def.get("costume", "muscle") == "suit" else "muscle"))
		DevNpcs.own_mats(model, mats)
		for m: Material in mats:
			(m as StandardMaterial3D).albedo_texture = map
		ap = model.find_children("*", "AnimationPlayer", true, false)[0]
		for nm: StringName in [&"Idle", &"Walking", &"Running"]:
			if ap.has_animation(nm):
				ap.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
		ap.play(&"Idle")
		current = &"Idle"

	func set_move(v: float) -> void:
		speed = v

	func update(_time: float, _dt: float) -> void:
		var a := &"Running" if speed > 3.0 else (&"Walking" if speed > 0.3 else &"Idle")
		if a != current:
			ap.play(a, 0.25)
			current = a
		ap.speed_scale = 1.0 if a == &"Idle" else speed / (4.5 if a == &"Running" else 1.4)


class PunkInst:
	extends Inst
	var punk: PalePunk

	func _init() -> void:
		punk = PalePunk.new()
		root = punk
		mats.append(punk._mat)

	func update(time: float, _dt: float) -> void:
		punk.update_at(time)


class AlienInst:
	extends Inst

	func _init(green: bool) -> void:
		alien = GrayAlienNpc.new({"green": green})
		root = alien

	func update(time: float, dt: float) -> void:
		alien.update(time, dt)


class TalkerInst:
	extends Inst
	var a: NpcRig

	func _init(id: String) -> void:
		var J: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LIFE_J))
		var d: Dictionary = J.npcs[id]
		var bin := FileAccess.get_file_as_bytes(LIFE_BIN)      # (110 MB, for this spawn only: a dev tool's button press)
		match id:
			"puppy":
				a = HubNpcs.Puppy.new()
			"winged":
				a = HubNpcs.Winged.new()
			"cherub":
				a = HubNpcs.Cherub.new()
		a.name = id
		a.build(d, bin)
		if a is HubNpcs.Cherub:
			(a as HubNpcs.Cherub).prepare(d["bones"])
		a.call(&"place", 0.0, 0.0, 0.0, 0.0)
		root = a

	func update(time: float, dt: float) -> void:
		a.update(time, dt)


## own copy of every material: hit flashes must not leak to the other spawns
static func own_mats(model: Node, mats: Array[Material]) -> void:
	for c: Node in model.find_children("*", "MeshInstance3D", true, false):
		var m := c as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(s)
			if src is StandardMaterial3D:
				var d := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.emission_enabled = true
				d.emission = Color.BLACK
				d.emission_energy_multiplier = 1.0
				m.set_surface_override_material(s, d)
				mats.append(d)


## holder: in the tree already; the NPC's root goes under it
static func make(def: Dictionary, holder: Node3D) -> Inst:
	var inst := _make(def, holder)
	if inst != null and inst.root.get_parent() == null:
		holder.add_child(inst.root)
	return inst


static func _make(def: Dictionary, holder: Node3D) -> Inst:
	match String(def.get("make", "")):
		"mixamo":
			return MixamoInst.new(def, holder)
		"frug":
			return FrugInst.new(def)
		"pale_punk":
			return PunkInst.new()
		"gray":
			return AlienInst.new(false)
		"green":
			return AlienInst.new(true)
		"talker":
			return TalkerInst.new(def.id)
	return GlbInst.new(def)
