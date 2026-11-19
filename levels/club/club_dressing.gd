class_name ClubDressing
extends Node3D
## CLUB 9 as an industrial goth club, over its export: soot-dark brick and cracked concrete on the walls, a polished concrete floor, rusted pipe runs, chains hanging over the
## dance floor, two go-go cages at the stage corners, wrought-iron candelabras on the tables, a red laser fan from the DJ booth and strobe bursts on the drop, and a hallway gone red
## and failing. Everything repeated is one MultiMesh; materials are made here at load; the only new lights are the strobe and the cages' glow.
## (2026-11-16, the user: "make club 9's interior look way better, it is an industrial goth club".)

const TEX := "res://assets/third-party/polyhaven/"
const CAGES := [Vector2(-5.6, 10.3), Vector2(5.6, 10.3)]
const CAGE_R := 0.72
const PLINTH_H := 0.45
const CAGE_TOP := 3.25
const LASER_AT := Vector3(0.0, 2.75, 11.85)
const LASERS := 13

var _lasers: Array[MeshInstance3D] = []
var _laser_root: Node3D
var _laser_m: ShaderMaterial
var _strobe: OmniLight3D
var _cage_lights: Array[OmniLight3D] = []
var _cage_ring_m: StandardMaterial3D
var _hall: Light3D = null
var _hall_e := 0.0
var _flame_m: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func build(level: ClubLevel) -> void:
	name = "ClubDressing"
	_rng.seed = 13
	_surfaces(level)
	_pipes()
	_chains()
	_cages()
	_candles()
	_build_lasers()
	_strobe = OmniLight3D.new()
	_strobe.name = "Strobe"
	_strobe.position = Vector3(0.0, 3.7, 6.0)
	_strobe.omni_range = 16.0
	_strobe.light_color = Color(0.92, 0.88, 1.0)
	_strobe.light_energy = 0.0
	_strobe.shadow_enabled = false
	add_child(_strobe)
	_hall = level._light("club_hall")
	if _hall != null:
		_hall.light_color = Color.hex(0xd2452eff)      # the hallway to the toilets: a dirty red, and the tube is going
		_hall_e = _hall.light_energy * 0.6
	for n: String in ["club_restM", "club_restW"]:
		var l := level._light(n)
		if l != null:
			l.light_color = Color.hex(0xb8d6a0ff)      # sick green-white in the restrooms
			l.light_energy *= 0.7


static func _tex(path: String) -> Texture2D:
	return load(TEX + path) as Texture2D


## Material for a surface: a PBR set on world triplanar mapping (the kit's boxes have no UVs worth keeping), tinted into the club's values.
static func _pbr(diff: String, nor: String, rough: String, tint: Color, scale: float, rough_mul: float, metal: float = 0.0, orm := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(diff)
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = _tex(nor)
	m.normal_scale = 1.0
	m.roughness_texture = _tex(rough)
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN if orm else BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = rough_mul
	m.metallic = metal
	if orm:
		m.metallic_texture = _tex(rough)
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / scale
	m.uv1_triplanar_sharpness = 4.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## The export names its materials by number, so they are found by the JS colours they carry (levels/club/level.js: M.wall 0x19141d, M.plaster 0x24212b, M.floor 0x252029).
func _surfaces(level: ClubLevel) -> void:
	var brick := _pbr("brick_wall_001/textures/brick_wall_001_diffuse_1k.jpg", "brick_wall_001/textures/brick_wall_001_nor_gl_1k.jpg", "brick_wall_001/textures/brick_wall_001_rough_1k.jpg", Color(0.3, 0.2, 0.27), 1.6, 1.0)
	var concrete := _pbr("cracked_concrete_wall/textures/cracked_concrete_wall_diff_1k.jpg", "cracked_concrete_wall/textures/cracked_concrete_wall_nor_gl_1k.jpg", "cracked_concrete_wall/textures/cracked_concrete_wall_rough_1k.jpg", Color(0.24, 0.2, 0.26), 2.2, 1.0)
	var floor_m := StandardMaterial3D.new()      # sealed, polished concrete: it holds the coloured light in soft reflections
	floor_m.albedo_texture = _tex("brushed_concrete_2.jpg")
	floor_m.albedo_color = Color(0.2, 0.17, 0.21)
	floor_m.roughness_texture = floor_m.albedo_texture      # (2026-11-16: a flat 0.3 mirrored every wash light into a clean round blob; the concrete's own grain breaks them into sheen)
	floor_m.roughness = 0.75
	floor_m.metallic = 0.12
	floor_m.uv1_triplanar = true
	floor_m.uv1_world_triplanar = true
	floor_m.uv1_scale = Vector3.ONE / 3.0
	floor_m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var swaps := {"19141d": brick, "24212b": concrete, "252029": floor_m}
	for mi: MeshInstance3D in level.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.is_ancestor_of(self) or is_ancestor_of(mi):
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as StandardMaterial3D
			if m == null:
				continue
			var key := m.albedo_color.to_html(false)
			if swaps.has(key):
				mi.set_surface_override_material(i, swaps[key])


static func rust() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex("rusty_metal_02.jpg")
	m.albedo_color = Color(0.55, 0.42, 0.42)
	m.metallic = 0.75
	m.roughness = 0.55
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 1.5
	return m


static func _mm(mesh: Mesh, xfs: Array[Transform3D], mat: Material, nm: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Pipe runs along the side walls above head height, on brackets.
func _pipes() -> void:
	var pipe := CylinderMesh.new()
	pipe.top_radius = 1.0
	pipe.bottom_radius = 1.0
	pipe.height = 1.0
	pipe.radial_segments = 10
	pipe.rings = 1
	var runs: Array[Transform3D] = []
	var brackets: Array[Transform3D] = []
	# [x, y, z0, z1, radius]
	for r: Array in [[12.3, 3.55, -5.6, 9.9, 0.07], [12.25, 3.75, -5.6, 9.9, 0.045], [-12.3, 3.6, -5.6, 7.3, 0.08], [-12.25, 3.82, -5.6, 7.3, 0.04]]:
		var len_: float = r[3] - r[2]
		runs.append(Transform3D(Basis(Vector3.RIGHT, PI / 2.0).scaled(Vector3(r[4], len_, r[4])), Vector3(r[0], r[1], (r[2] + r[3]) * 0.5)))
		var z: float = r[2] + 0.6
		while z < r[3]:
			brackets.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.05, 0.3, 0.05)), Vector3(r[0], r[1] + 0.15, z)))
			z += 1.8
	var m := rust()
	add_child(_mm(pipe, runs, m, "Pipes"))
	add_child(_mm(pipe, brackets, m, "PipeBrackets"))


## Chains hanging from the ceiling round the dance floor and over the cages: links alternate a quarter turn, each chain its own length.
func _chains() -> void:
	var link := TorusMesh.new()
	link.inner_radius = 0.016
	link.outer_radius = 0.032
	link.rings = 8
	link.ring_segments = 5
	var xfs: Array[Transform3D] = []
	var tops: Array[Vector3] = []
	for i in 9:
		tops.append(Vector3(-6.4, 4.0, 1.4 + i * 0.95))
		tops.append(Vector3(6.4, 4.0, 1.4 + i * 0.95))
	for i in 6:
		tops.append(Vector3(-4.6 + i * 1.85, 4.0, 0.7))
	for c: Vector2 in CAGES:
		for a in 3:
			tops.append(Vector3(c.x + cos(a * TAU / 3.0) * 0.5, 4.0, c.y + sin(a * TAU / 3.0) * 0.5))
	for t: Vector3 in tops:
		var len_ := _rng.randf_range(0.7, 2.1)
		var cage := false
		for c: Vector2 in CAGES:
			if Vector2(t.x, t.z).distance_to(c) < 0.6:
				cage = true
				len_ = 4.0 - CAGE_TOP
		var turn := _rng.randf() * PI
		var n := int(len_ / 0.052)
		for k in n:
			var b := Basis(Vector3.UP, turn + (PI / 2.0 if k % 2 == 1 else 0.0)) * Basis(Vector3.RIGHT, PI / 2.0)
			xfs.append(Transform3D(b.scaled(Vector3(1.0, 1.0, 1.25)), t - Vector3(0.0, 0.03 + k * 0.052, 0.0)))
		if not cage and _rng.randf() < 0.45:      # some end in a hook
			xfs.append(Transform3D(Basis(Vector3.UP, turn).scaled(Vector3(1.6, 1.6, 1.6)), t - Vector3(0.0, 0.08 + n * 0.052, 0.0)))
	var m := rust()
	m.metallic = 0.85
	m.roughness = 0.4
	add_child(_mm(link, xfs, m, "Chains"))


## Go-go cages at the stage corners: a plinth with a red light ring, bars to a capped top hung on chains. A dancer each (ClubCrowd.CAGED).
func _cages() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color.hex(0x1a171dff)
	steel.metallic = 0.9
	steel.roughness = 0.35
	_cage_ring_m = StandardMaterial3D.new()
	_cage_ring_m.albedo_color = Color.hex(0xff1d3aff)
	_cage_ring_m.emission_enabled = true
	_cage_ring_m.emission = Color.hex(0xff1d3aff)
	_cage_ring_m.emission_energy_multiplier = 2.5
	var bar := CylinderMesh.new()
	bar.top_radius = 0.013
	bar.bottom_radius = 0.013
	bar.height = 1.0
	bar.radial_segments = 6
	bar.rings = 1
	var ring := TorusMesh.new()
	ring.inner_radius = CAGE_R - 0.03
	ring.outer_radius = CAGE_R + 0.03
	ring.rings = 32
	ring.ring_segments = 6
	var bars: Array[Transform3D] = []
	var rings: Array[Transform3D] = []
	var glow: Array[Transform3D] = []
	for c: Vector2 in CAGES:
		var plinth := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = CAGE_R + 0.05
		pm.bottom_radius = CAGE_R + 0.12
		pm.height = PLINTH_H
		pm.radial_segments = 24
		plinth.mesh = pm
		plinth.material_override = steel
		plinth.position = Vector3(c.x, PLINTH_H * 0.5, c.y)
		add_child(plinth)
		var cap := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = CAGE_R * 0.4
		cm.bottom_radius = CAGE_R + 0.04
		cm.height = 0.18
		cm.radial_segments = 24
		cap.mesh = cm
		cap.material_override = steel
		cap.position = Vector3(c.x, CAGE_TOP + 0.09, c.y)
		add_child(cap)
		var h := CAGE_TOP - PLINTH_H
		for i in 20:
			var a := i * TAU / 20.0
			bars.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, h, 1.0)), Vector3(c.x + cos(a) * CAGE_R, PLINTH_H + h * 0.5, c.y + sin(a) * CAGE_R)))
		for y: float in [PLINTH_H + 0.02, PLINTH_H + h * 0.5, CAGE_TOP]:
			rings.append(Transform3D(Basis.IDENTITY, Vector3(c.x, y, c.y)))
		glow.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.12, 1.0, 1.12)), Vector3(c.x, 0.06, c.y)))
		var l := OmniLight3D.new()
		l.name = "CageGlow"
		l.light_color = Color.hex(0xff2440ff)
		l.light_energy = 1.2
		l.omni_range = 3.4
		l.position = Vector3(c.x, 2.9, c.y)
		add_child(l)
		_cage_lights.append(l)
		Game.world.add({"kind": "disc", "cx": c.x, "cz": c.y, "r": CAGE_R + 0.12, "top": CAGE_TOP + 0.2, "tag": "furn"})
	add_child(_mm(bar, bars, steel, "CageBars"))
	add_child(_mm(ring, rings, steel, "CageRings"))
	add_child(_mm(ring, glow, _cage_ring_m, "CageGlowRings"))


## Wrought-iron three-candle holders on the high tables and the VIP's tables; the flames flicker in their shader.
func _candles() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color.hex(0x141015ff)
	iron.metallic = 0.8
	iron.roughness = 0.5
	var wax := StandardMaterial3D.new()
	wax.albedo_color = Color.hex(0x2a0a10ff)       # black-red wax
	wax.roughness = 0.6
	_flame_m = ShaderMaterial.new()
	_flame_m.shader = load("res://levels/club/candle_flame.gdshader")
	var stem := CylinderMesh.new()
	stem.top_radius = 1.0
	stem.bottom_radius = 1.0
	stem.height = 1.0
	stem.radial_segments = 6
	stem.rings = 1
	var flame := SphereMesh.new()
	flame.radius = 0.5
	flame.height = 1.0
	flame.radial_segments = 6
	flame.rings = 4
	var irons: Array[Transform3D] = []
	var waxes: Array[Transform3D] = []
	var flames: Array[Transform3D] = []
	# table tops: the four high tables (JS lounge), the two VIP tables
	for t: Vector3 in [Vector3(-9.5, 1.09, -4.6), Vector3(-7.0, 1.09, -4.6), Vector3(7.0, 1.09, -4.6), Vector3(9.5, 1.09, -4.6), Vector3(-9.7, 0.81, 9.9), Vector3(-9.4, 0.81, 11.8)]:
		irons.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.05, 0.02, 0.05)), t + Vector3(0.0, 0.01, 0.0)))
		irons.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.008, 0.16, 0.008)), t + Vector3(0.0, 0.09, 0.0)))
		irons.append(Transform3D(Basis(Vector3.FORWARD, PI / 2.0).scaled(Vector3(0.006, 0.17, 0.006)), t + Vector3(0.0, 0.17, 0.0)))
		for dx: float in [-0.085, 0.0, 0.085]:
			var top := t + Vector3(dx, 0.17 + (0.05 if dx == 0.0 else 0.0), 0.0)
			var h := 0.09 + _rng.randf() * 0.05
			waxes.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.011, h, 0.011)), top + Vector3(0.0, h * 0.5, 0.0)))
			flames.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.016, 0.034, 0.016)), top + Vector3(0.0, h + 0.02, 0.0)))
	add_child(_mm(stem, irons, iron, "Candelabras"))
	add_child(_mm(stem, waxes, wax, "Candles"))
	add_child(_mm(flame, flames, _flame_m, "CandleFlames"))


## The laser fan over the floor from the DJ booth: thin red beams that glow (bloom does the rest).
func _build_lasers() -> void:
	_laser_m = ShaderMaterial.new()      # the heads' haze shader (club_beam.gdshader), flat across a thin beam: smoke breaks it up, it fades into the floor and off the camera (2026-11-16)
	_laser_m.shader = ClubLevel.BEAM_SHADER
	_laser_m.set_shader_parameter(&"len", 1000.0)
	_laser_m.set_shader_parameter(&"core", 0.0)
	_laser_m.set_shader_parameter(&"smoke", 0.8)
	var rad := Game.view.display_to_radiance(Color(1.0, 0.1, 0.18))
	_laser_m.set_shader_parameter(&"col", Color(rad.r, rad.g, rad.b))
	_laser_m.set_shader_parameter(&"power", 0.0)
	var beam := BoxMesh.new()
	beam.size = Vector3(0.007, 0.007, 1.0)
	_laser_root = Node3D.new()
	_laser_root.name = "LaserFan"
	_laser_root.position = LASER_AT
	add_child(_laser_root)
	for i in LASERS:
		var mi := MeshInstance3D.new()
		mi.mesh = beam
		mi.material_override = _laser_m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_laser_root.add_child(mi)
		_lasers.append(mi)
	var head := MeshInstance3D.new()      # the projector on the booth
	var hb := BoxMesh.new()
	hb.size = Vector3(0.3, 0.16, 0.22)
	head.mesh = hb
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color.hex(0x111015ff)
	hm.metallic = 0.7
	hm.roughness = 0.4
	head.material_override = hm
	head.position = LASER_AT + Vector3(0.0, 0.0, 0.12)
	add_child(head)


## The show on the beat (ClubLevel.tick): lasers on for the middle of each 16-beat phrase, sweeping; a strobe burst on the drop every 32 beats; the hallway tube failing.
func tick(t: float, beat: float) -> void:
	var b := t * ClubLevel.BEAT_HZ
	var phrase := fposmod(b, 32.0)
	var on := smoothstep(7.6, 8.2, phrase) * (1.0 - smoothstep(23.6, 24.2, phrase))
	_laser_root.visible = on > 0.01
	if _laser_root.visible:
		_laser_m.set_shader_parameter(&"power", on * (1.2 + 1.3 * beat))
		var sweep := 0.42 * sin(t * 0.9)
		var spread := 0.05 + 0.06 * (0.5 - 0.5 * cos(PI * b / 2.0))      # the fan opens and closes on the half bar
		var tilt := 0.2 + 0.08 * sin(PI * b / 4.0)
		for i in LASERS:
			var k := float(i) - (LASERS - 1) * 0.5
			var yaw := PI + sweep + k * spread      # (the fan points down the room, -z, toward the entrance)
			var dir := Vector3(sin(yaw), -sin(tilt + 0.02 * absf(k)), cos(yaw)).normalized()
			var len_ := minf(18.0, (LASER_AT.y - 0.02) / maxf(0.02, -dir.y))      # each beam runs until it hits the floor
			var x := Basis.looking_at(dir, Vector3.UP)
			_lasers[i].transform = Transform3D(x.scaled(Vector3(1.0, 1.0, len_)), dir * len_ * 0.5)
	# strobe: four hard flashes across beats 30-32 of each phrase
	var sb := phrase - 30.0
	var flash := 0.0
	if sb >= 0.0:
		var f := fposmod(sb * 2.0, 1.0)
		flash = 1.0 if f < 0.12 else 0.0
	_strobe.light_energy = 9.0 * flash
	for l in _cage_lights:
		l.light_energy = 0.9 + 0.9 * beat
	_cage_ring_m.emission_energy_multiplier = 1.6 + 2.2 * beat
	if _hall != null:      # a tube on its way out: steady, then a stutter
		var s := fposmod(t, 7.3)
		var stutter := 1.0 if s > 0.5 else (0.25 if fposmod(s * 23.0, 1.0) < 0.5 else 1.0)
		_hall.light_energy = _hall_e * stutter
