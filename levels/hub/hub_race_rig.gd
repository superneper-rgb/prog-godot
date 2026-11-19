class_name HubRaceRig
extends Node3D
## FOINT CITY: Pauly's racing rig at the kerb outside CLUB 9 (2026-11-17, the user's scene: levels/club/phone_guy.gd). The export had a plain stand-in car of boxes parked there: it
## is gone, every part of it (and the street litter where the rig stands). In its place his blue saucer (assets/vehicles/city/saucerB.glb, tools/cars/more_cars.py saucer_b), big
## enough for Prog at full size and Pauly side by side (DRIVER / PASSENGER below: they ride in it in the race), and a little beaten up: the paint dented and scratched, its red
## driver's door off its hinge and lying on the pavement, the front-left emitter (its wheel) off its axle and propped on the door, the car down on that corner. Once Prog has talked
## to Pauly in the club he waits here by it. X at the rig then (2026-11-18, the user's scene): Prog and Pauly get in and it takes off, the level's `cine`
## (levels/hub/rig_launch.gd). The shot ends on black at the handoff to the SkySphere's shuttle bay.

const OLD := Vector2(-3.2, -38.0)          # where the export's stand-in stood (its colliders: tag car / cab, ci 0)
const AT := Vector3(-2.75, 0.0, -38.0)     # the rig: 2.6 m wide, its door side a hand off the kerb (x -4.2)
## Where the two sit, car frame (x left, y up, z forward; metres): hips. The seats tools/cars/more_cars.py saucer_b builds; the canopy clears Prog's crown seated upright.
const DRIVER := Vector3(0.46, 1.12, -0.1)
const PASSENGER := Vector3(-0.46, 1.12, -0.1)
const ROOF := 2.28                          # the inside of the canopy over the seats
## No steering wheel (user, 2026-11-17): it is driven with the mind, like the city's GRAY SAUCER and GREEN POD. Where the driver's hands rest, as theirs do (life.json car_models
## saucerG: the seat's "wheel" 0.04 up and 0.37 ahead of the hips, tilt 0.7, r 0.12).
const DRIVER_HANDS := Vector3(0.46, 1.16, 0.27)
const YAW := PI                            # nose to -z: his door side (the car's left) to the pavement and the club door
const BLUE := 0x1f4fae
const RED := 0x9c1a17
const OWNER_AT := Vector2(-5.0, -40.7)     # on the pavement at the back of his rig (clear of where Prog comes out of the club, -6, -36.6)
const BESIDE := Vector3(-5.3, 0.15, -39.5)  # where Prog stands when he is put down by the rig (after the take-off shot), facing Pauly (yaw PI)
const GET_IN := Vector2(-4.5, -38.0)       # the X spot: the pavement at the driver's side, where the door was

var car: CityCars.CarModel
var owner_npc: GrayAlienNpc = null
var launch: RigLaunch = null               # the take-off (only once Pauly is out here)
var _solids: Array[World.Solid] = []       # the rig's own, and Pauly's
var _t := 0.0


func build(level: HubLevel) -> void:
	name = "RaceRig"
	_hide_placeholder(level)
	var kit: CityCars = level.life.cars if level.life != null and level.life.cars != null else CityCars.new()
	car = kit.model(&"saucerB", Color.hex((BLUE << 8) | 0xff), 9)
	add_child(car.root)
	car.root.transform = Transform3D(Basis(Vector3.UP, YAW) * Basis.from_euler(Vector3(0.05, 0.0, -0.07)), AT + Vector3(0.0, -0.03, 0.0))      # down on the front-left corner
	_scuff(car.root, 0.42, 1.0)
	# the door: off, red, flat on the pavement beside the car, turned a little
	var door := car.door
	if door != null:
		door.get_parent().remove_child(door)
		add_child(door)
		_scuff(door, 0.5, 1.0, Color.hex((RED << 8) | 0xff))
		_dead_lights(door)
		_lay(door, Basis(Vector3.UP, YAW + 0.35) * Basis(Vector3.FORWARD, -PI / 2.0), Vector2(AT.x - 2.55, AT.z - 0.2))
	# the front-left emitter: off its axle, leaning on the door with the axle up in the air
	for w: CityCars.CarWheel in car.wheels:
		var lp := w.pivot.position
		if lp.z > 0.0 and lp.x > 0.0:
			w.pivot.get_parent().remove_child(w.pivot)
			add_child(w.pivot)
			_dead_lights(w.pivot)
			_lay(w.pivot, Basis(Vector3.UP, YAW - 0.6) * Basis(Vector3.FORWARD, 1.15), Vector2(AT.x - 2.2, AT.z + 0.85))
			break
	_shadow()
	# solid: the hull and the canopy
	_solids.append(level.world.add({"kind": "box", "cx": AT.x, "cz": AT.z, "hx": 1.25, "hz": 2.05, "yaw": YAW, "bottom": 0.0, "top": 1.07, "tag": "car"}))
	_solids.append(level.world.add({"kind": "disc", "cx": AT.x, "cz": AT.z, "r": 1.05, "bottom": 1.0, "top": 2.38, "tag": "car"}))
	if Game.story_get(PhoneGuy.FLAG):
		owner_npc = GreenAlienBoston.make()
		owner_npc.name = "PaulyByHisRig"
		add_child(owner_npc)
		owner_npc.place(OWNER_AT.x, 0.15, OWNER_AT.y, atan2(AT.x - OWNER_AT.x, AT.z - OWNER_AT.y))
		owner_npc.view.post_hook = _wait_pose
		_solids.append(level.world.add({"kind": "disc", "cx": OWNER_AT.x, "cz": OWNER_AT.y, "r": 0.32, "top": 1.6, "tag": "npc", "no_cam": true}))
		# X on the pavement by the driver's side, or on Pauly: they get in and it goes (the level's cine, then the level door)
		launch = RigLaunch.new()
		add_child(launch)
		launch.setup(self)
		level.actions.append({"x": GET_IN.x, "z": GET_IN.y, "label": "GET IN — PAULY’S RIG",
			"active": func(p: Player) -> bool: return launch.can_start() and p.y < 1.2 and p.x < AT.x - 0.9 and (U.hyp(p.x - GET_IN.x, p.z - GET_IN.y) < 2.3 or U.hyp(p.x - OWNER_AT.x, p.z - OWNER_AT.y) < 1.7),
			"run": func() -> void: launch.start()})


## The rig and Pauly at the kerb, or gone from it (the take-off has them): their solids, him standing there.
func set_parked(v: bool) -> void:
	for s: World.Solid in _solids:
		s.set_off(not v)
	car.root.visible = true
	if owner_npc != null:
		owner_npc.set_shown(v)


## A soft dark pool on the road under the rig (the old car had one; the street's light is painted, so a parked car needs its own to sit on the ground).
func _shadow() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.0, 0.0, 0.8))
	g.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	g.add_point(0.55, Color(0.0, 0.0, 0.0, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = tex
	m.albedo_color = Color.WHITE
	var q := PlaneMesh.new()
	q.size = Vector2(3.2, 5.0)
	var mi := MeshInstance3D.new()
	mi.name = "Shadow"
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.transform = Transform3D(Basis(Vector3.UP, YAW), AT + Vector3(0.0, 0.015, 0.0))


## The export's stand-in: a plain car of boxes on the kerb (its body, cab, wheels and lamps sit in static_batch meshes merged with the other stand-ins along this kerb), and its
## colliders. Its triangles are taken out of those meshes; the others stay.
func _hide_placeholder(level: HubLevel) -> void:
	var foot := AABB(Vector3(-4.4, -0.1, OLD.y - 2.6), Vector3(3.1, 1.8, 5.2))      # (the old car's box and a margin)
	for n: Node in level.find_children("*static_batch*", "Node3D", true, false):
		for mi: Node in ([n] if n is MeshInstance3D else n.find_children("*", "MeshInstance3D", false, false)):
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			var bb := m.global_transform * m.get_aabb()
			if bb.intersects(foot) and bb.position.x > -4.5:      # (the stand-ins' batches only: the pavement and kerb batch reaches back to the buildings, and keeps its kerb)
				_cut(m, foot)
	# its ground shadow: a dark quad on the road, merged with the other stand-ins' (flat, unlit): its two triangles go
	for mi: Node in level.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.mesh.get_surface_count() == 0:
			continue
		var mat := m.mesh.surface_get_material(0)
		var bb := m.global_transform * m.get_aabb()
		if mat != null and mat.resource_name.begins_with("basic") and bb.size.y < 0.2 and bb.intersects(foot):
			_cut(m, AABB(Vector3(foot.position.x, -0.1, foot.position.z), Vector3(foot.size.x, 0.4, foot.size.z)))
	for tag: String in ["car", "cab"]:
		for s: World.Solid in level.solids_tagged(tag):
			if Vector2(s.cx - OLD.x, s.cz - OLD.y).length() < 1.0:
				s.set_off(true)
	# the street litter (small boxes strewn by the export) under the rig and where its door and emitter lie: gone, so nothing pokes through them
	var clear := AABB(Vector3(-6.4, -0.1, AT.z - 2.6), Vector3(5.2, 1.0, 5.2))
	for mm: Node in level.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := mm as MultiMeshInstance3D
		var M := mmi.multimesh
		if M == null or M.mesh == null:
			continue
		for k in M.instance_count:
			var t: Transform3D = mmi.global_transform * M.get_instance_transform(k)
			var bb := t * M.mesh.get_aabb()
			if clear.has_point(t.origin) and bb.size.length() < 2.0 and bb.size.y > 0.03:      # (small and standing up: litter, not paving)
				M.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ZERO), M.get_instance_transform(k).origin))


## The mesh without its triangles whose middle lies in `box` (world).
static func _cut(m: MeshInstance3D, box: AABB) -> void:
	var xf := m.global_transform
	var am := ArrayMesh.new()
	var cut := false
	for s in m.mesh.get_surface_count():
		var a: Array = m.mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
		var keep := PackedInt32Array()
		var i := 0
		while i + 2 < ix.size():
			if box.has_point(xf * ((v[ix[i]] + v[ix[i + 1]] + v[ix[i + 2]]) / 3.0)):
				cut = true
			else:
				keep.append_array([ix[i], ix[i + 1], ix[i + 2]])
			i += 3
		if keep.is_empty():
			continue
		a[Mesh.ARRAY_INDEX] = keep
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		am.surface_set_material(am.get_surface_count() - 1, m.mesh.surface_get_material(s))
	if cut:
		m.mesh = am
		if am.get_surface_count() == 0:
			m.visible = false


## Bodywork that has been knocked about: its paint's dents and scratches up (and a colour of its own, for the door).
static func _scuff(n: Node, dent: float, scratch: float, paint: Color = Color(0, 0, 0, 0)) -> void:
	for mi: Node in ([n] if n is MeshInstance3D else []) + n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var sm := m.get_surface_override_material(i) as ShaderMaterial
			if sm == null or CityCars._group_of(m.mesh, i) != &"CarPaint":
				continue
			if paint.a > 0.0:
				sm = sm.duplicate() as ShaderMaterial
				sm.set_shader_parameter(&"own_paint", paint)
				m.set_surface_override_material(i, sm)
			sm.set_shader_parameter(&"dent", dent)
			sm.set_shader_parameter(&"scratch", scratch)


## A part off the car is dead: its lit strips go dark.
func _dead_lights(n: Node) -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.035, 0.045)
	dark.metallic = 0.6
	dark.roughness = 0.45
	for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			if CityCars._group_of(m.mesh, i) == &"CarLights":
				m.set_surface_override_material(i, dark)


## Put a loose part down: turned by `b`, its lowest point on the pavement (y 0.15), its middle at `xz`.
func _lay(n: Node3D, b: Basis, xz: Vector2) -> void:
	n.global_transform = Transform3D(b, Vector3.ZERO)
	var box := AABB()
	var first := true
	for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var bb := m.global_transform * m.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	var c := box.get_center()
	n.global_position += Vector3(xz.x - c.x, 0.15 - box.position.y + 0.004, xz.y - c.z)


## Every frame (HubLevel.tick): the owner waits, weight on one leg, looking his rig over, and at Prog when he comes near.
func tick(dt: float) -> void:
	if launch != null:
		launch.update(dt)
	if owner_npc == null or not owner_npc.is_shown():
		return
	_t += dt
	var P := Game.player
	if P != null and Vector2(P.x - OWNER_AT.x, P.z - OWNER_AT.y).length() < 6.0:
		owner_npc.look_at_point(P.x, P.z)
	else:
		owner_npc.look_away()
	owner_npc.update(_t, dt)


func _wait_pose() -> void:
	var v := owner_npc.view
	var q := v.pose
	q.rot[v.j_spine] = q.rot[v.j_spine] * Basis.from_euler(Vector3(-0.06, 0.0, 0.05 * sin(_t * 0.4)))
	q.euler(v.j_sh_l, -0.25, 0.0, 0.35)      # hands on his hips
	q.euler(v.j_el_l, -1.5, 0.6, 0.0)
	q.euler(v.j_sh_r, -0.25, 0.0, -0.35)
	q.euler(v.j_el_r, -1.5, -0.6, 0.0)
