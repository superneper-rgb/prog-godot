class_name SkyVenue
extends Node3D
## The derelict SkySphere, taken over for an illegal race (user, 2026-11-18): a rusted shell 760 m across, its ribs and broken lights, the
## walkable ticket concourse hung in the middle, and the crews' signage along the run. (Was a clean neon sphere 274 m across.)

const ARRIVAL := Vector3(35, 0.08, -153)
const PARKED := Vector3(41.4, 0.14, -147.4)
const TICKETS := Vector3(35, 0.0, -103.9)
const SHUTTLE := Vector3(35, 0.0, -158.5)
const PAULY_AT := Vector3(30.5, 0.0, -104.5)
const START_LINE := 40.0
const SHELL_CENTER := Vector3(0, 26, 0)
const SHELL_RADIUS := 760.0
const RIB_SCALE := SHELL_RADIUS / 274.0      # the ribs were drawn for the old 274 m shell
const CYAN := Color("cfdcea")      # (kept names: now the cold work lamps)
const GOLD := Color("ff9a3c")      # sodium
const PINK := Color("ff2a1a")      # red beacons
const PHOSPHOR := Color("aafdc7")

var _armor: Array[Transform3D] = []
var _trim: Array[Transform3D] = []
var _bolts: Array[Transform3D] = []
var _aqua: Array[Transform3D] = []
var _rose: Array[Transform3D] = []
var _gold: Array[Transform3D] = []
var _lamps: Array[MeshInstance3D] = []
var _engine: Node3D
var _rng := RandomNumberGenerator.new()
var _off: Material
var _ready_light: Material
var _go_light: Material


func build(world: World, course: SkyCourse) -> void:
	name = "SkySphereStation"
	_rng.seed = 7741      # (which of the old light strips still work: the same ones every time)
	var sphere := SphereMesh.new()
	sphere.radius = SHELL_RADIUS
	sphere.height = SHELL_RADIUS * 2.0
	sphere.radial_segments = 96
	sphere.rings = 48
	var shell := ShaderMaterial.new()
	shell.shader = preload("res://levels/sky_sphere/sky_shell.gdshader")
	SkyGeometry.part(self, sphere, shell, Transform3D(Basis.IDENTITY, SHELL_CENTER))
	_pressure_ribs()
	_reactor()
	_concourse(world)
	_wayfinding(course)
	SkyGeometry.boxes(self, SkyLook.steel(), _armor)
	SkyGeometry.boxes(self, SkyLook.rust(), _trim)
	SkyGeometry.boxes(self, SkyLook.rust(), _bolts)
	SkyGeometry.boxes(self, SkyGeometry.light(CYAN, 0.9), _aqua)
	SkyGeometry.boxes(self, SkyGeometry.light(PINK, 1.7), _rose)
	SkyGeometry.boxes(self, SkyGeometry.light(GOLD, 1.5), _gold)
	_armor.clear()
	_trim.clear()
	_bolts.clear()
	_aqua.clear()
	_rose.clear()
	_gold.clear()
	set_start_lamps(0)


func tick(dt: float) -> void:
	_engine.rotation.y += dt * 0.18


func set_start_lamps(lit: int) -> void:
	for i in _lamps.size():
		_lamps[i].material_override = _go_light if lit == 4 else (_ready_light if i < lit else _off)


func _on_shell(heading: float, latitude: float, radius: float) -> Vector3:
	return SHELL_CENTER + Vector3(sin(heading) * cos(latitude), sin(latitude), cos(heading) * cos(latitude)) * radius


func _pressure_ribs() -> void:
	for rib in 12:
		var heading := TAU * rib / 12.0
		for i in 20:
			var a := -1.35 + float(i) * 0.135
			var b := a + 0.135
			_armor.append(SkyGeometry.beam(_on_shell(heading, a, 267.0 * RIB_SCALE), _on_shell(heading, b, 267.0 * RIB_SCALE), 7.6 * RIB_SCALE * 0.8, 10.5 * RIB_SCALE * 0.8))
			_bolts.append(SkyGeometry.beam(_on_shell(heading, a + 0.014, 256.0 * RIB_SCALE), _on_shell(heading, b - 0.014, 256.0 * RIB_SCALE), 3.4 * RIB_SCALE * 0.8, 2.2 * RIB_SCALE * 0.8))
			var lighting := _rose if rib % 3 == 0 else _aqua
			if _rng.randf() < 0.18:
				lighting.append(SkyGeometry.beam(_on_shell(heading, a + 0.029, 254.6 * RIB_SCALE), _on_shell(heading, b - 0.016, 254.6 * RIB_SCALE), 0.57 * RIB_SCALE * 0.8, 0.62 * RIB_SCALE * 0.8))
			if i % 4 == 1:
				for side: float in [-1.0, 1.0]:
					_trim.append(SkyGeometry.beam(_on_shell(heading + side * 0.09, a, 265.0 * RIB_SCALE), _on_shell(heading, b, 246.0 * RIB_SCALE), 2.8 * RIB_SCALE * 0.8, 4.1 * RIB_SCALE * 0.8))
	for latitude: float in [-0.58, -0.23, 0.18, 0.54]:
		for i in 72:
			var a := TAU * i / 72.0
			var b := a + TAU / 72.0
			_armor.append(SkyGeometry.beam(_on_shell(a, latitude, 261.0 * RIB_SCALE), _on_shell(b, latitude, 261.0 * RIB_SCALE), 4.6 * RIB_SCALE * 0.8, 5.4 * RIB_SCALE * 0.8))
			var lighting := _gold if latitude < -0.3 else _aqua
			if _rng.randf() < 0.18:
				lighting.append(SkyGeometry.beam(_on_shell(a + 0.008, latitude + 0.007, 257.0 * RIB_SCALE), _on_shell(b - 0.023, latitude + 0.007, 257.0 * RIB_SCALE), 0.57 * RIB_SCALE * 0.8, 0.62 * RIB_SCALE * 0.8))
			if i % 3 != 0:
				_bolts.append(SkyGeometry.beam(_on_shell(a, latitude - 0.006, 253.0 * RIB_SCALE), _on_shell(a, latitude + 0.042, 264.0 * RIB_SCALE), 3.6 * RIB_SCALE * 0.8, 4.2 * RIB_SCALE * 0.8))


func _reactor() -> void:
	const CENTER := Vector3(12, 151, 56)
	var collar := CylinderMesh.new()
	collar.top_radius = 23.0
	collar.bottom_radius = 18.0
	collar.height = 9.0
	var case_metal := SkyLook.rust()
	SkyGeometry.part(self, collar, case_metal, Transform3D(Basis.IDENTITY, CENTER + Vector3.UP * 14.0))
	SkyGeometry.part(self, collar, case_metal, Transform3D(Basis(Vector3.RIGHT, PI), CENTER - Vector3.UP * 14.0))
	var core := CylinderMesh.new()
	core.top_radius = 11.4
	core.bottom_radius = 11.4
	core.height = 29.0
	SkyGeometry.part(self, core, SkyGeometry.light(Color("ff5a1a"), 0.8), Transform3D(Basis.IDENTITY, CENTER))      # (a dead reactor, embers in it)
	_engine = Node3D.new()
	_engine.position = CENTER
	add_child(_engine)
	var casing: Array[Transform3D] = []
	var bars: Array[Transform3D] = []
	for i in 20:
		var angle := TAU * i / 20.0
		var outward := Basis(Vector3.UP, angle)
		var section := outward.z
		casing.append(SkyGeometry.box_at(section * 15.0, Vector3(1.8, 31.0, 2.3), outward * Basis(Vector3.BACK, 0.23)))
		bars.append(SkyGeometry.box_at(section * 16.3, Vector3(0.28, 18.0, 0.33), outward * Basis(Vector3.BACK, 0.23)))
		_armor.append(SkyGeometry.beam(CENTER + section * 19.0 + Vector3.UP * 18.0, CENTER + section * 45.0 + Vector3.UP * 61.0, 2.6, 3.0))
		if i % 2 == 0:
			_rose.append(SkyGeometry.beam(CENTER + section * 18.0 - Vector3.UP * 16.0, CENTER + section * 27.0 - Vector3.UP * 23.0, 0.64, 1.2))
	SkyGeometry.boxes(_engine, case_metal, casing)
	SkyGeometry.boxes(_engine, SkyGeometry.light(PINK, 1.7), bars)


func _concourse(world: World) -> void:
	_deck(world, Vector2(35.0, -142.5), Vector2(20.0, 38.0))
	_deck(world, Vector2(35.0, -106.5), Vector2(34.0, 34.0))
	_fence(world, Vector2(25, -161.5), Vector2(25, -123.5))
	_fence(world, Vector2(45, -161.5), Vector2(45, -123.5))
	_fence(world, Vector2(25, -161.5), Vector2(45, -161.5))
	_fence(world, Vector2(18, -123.5), Vector2(25, -123.5))
	_fence(world, Vector2(45, -123.5), Vector2(52, -123.5))
	_fence(world, Vector2(18, -123.5), Vector2(18, -89.5))
	_fence(world, Vector2(52, -123.5), Vector2(52, -89.5))
	_fence(world, Vector2(18, -89.5), Vector2(52, -89.5))
	for z: float in [-157.0, -136.5, -116.0]:
		var frame := Transform3D(Basis.IDENTITY, Vector3(35.0, 0.0, z))
		_arch(frame, 9.8 if z < -123.5 else 15.8, 7.7, _aqua if z != -136.5 else _rose)
	for i in 45:
		var z := -157.5 + i * 1.32
		for side: float in [-1.0, 1.0]:
			_aqua.append(SkyGeometry.box_at(Vector3(35.0 + side * 4.7, 0.024, z), Vector3(0.11, 0.018, 0.91)))
		if i % 4 == 2:
			_gold.append(SkyGeometry.box_at(Vector3(35.0, 0.019, z), Vector3(1.5, 0.022, 0.24)))
	_panel(Vector3(35, 6.94, -137.54), 12.6, 1.72, "SKYSPHERE", 0.018, CYAN)
	_panel(Vector3(35, 5.65, -158.8), 8.4, 0.92, "SHUTTLE BAY", 0.011, GOLD, false)
	_docking_pad(world)
	_ticket_stand(world)
	for side: float in [-1.0, 1.0]:
		var bank := Vector3(35.0 + side * 13.75, 0.0, -113.0)
		_bolts.append(SkyGeometry.box_at(bank + Vector3.UP * 0.81, Vector3(2.32, 1.62, 4.28)))
		_trim.append(SkyGeometry.box_at(bank + Vector3.UP * 1.65, Vector3(2.58, 0.21, 4.51)))
		_aqua.append(SkyGeometry.box_at(bank + Vector3(-side * 1.24, 1.34, 0.0), Vector3(0.071, 0.14, 3.75)))
		for i in 12:
			_bolts.append(SkyGeometry.box_at(bank + Vector3(-side * 1.21, 0.51, (i - 5.5) * 0.30), Vector3(0.1, 0.62, 0.13)))
		world.box(bank.x, bank.z, 2.55, 4.5, 1.75, {"bottom": -0.05, "tag": "concourse machinery"})
	# Structural suspension below the public deck, with illuminated tie rods visible from the track.
	for x: float in [21.0, 49.0]:
		var anchor := Vector3(x, -24.0, -133.0)
		for z: float in [-96.0, -147.0]:
			_armor.append(SkyGeometry.beam(Vector3(x, -0.6, z), anchor, 2.3, 2.5))
			_aqua.append(SkyGeometry.beam(Vector3(x - 0.9, -1.15, z), anchor + Vector3.LEFT * 0.9, 0.23, 0.25))
		_bolts.append(SkyGeometry.beam(anchor, Vector3(x * 1.8, -76.0, -190.0), 2.8, 4.0))


func _docking_pad(world: World) -> void:
	_armor.append(SkyGeometry.box_at(PARKED - Vector3.UP * 0.09, Vector3(6.0, 0.095, 8.6)))
	world.box(PARKED.x, PARKED.z, 2.45, 3.85, 1.13, {"bottom": 0.0, "tag": "parked saucer"})
	world.add({"kind": "disc", "cx": PARKED.x, "cz": PARKED.z, "r": 1.0, "bottom": 0.0, "top": 2.38, "tag": "saucer canopy"})
	for side: float in [-1.0, 1.0]:
		for i in 9:
			_gold.append(SkyGeometry.box_at(PARKED + Vector3(side * 2.71, -0.066, (i - 4.0) * 0.84), Vector3(0.25, 0.038, 0.60), Basis(Vector3.UP, PI * 0.18 * side)))
		_aqua.append(SkyGeometry.box_at(PARKED + Vector3(0.0, -0.052, side * 4.3), Vector3(5.5, 0.05, 0.16)))


func _deck(world: World, center: Vector2, size: Vector2) -> void:
	world.box(center.x, center.y, size.x, size.y, 0.0, {"bottom": -2.5, "tag": "concourse"})
	_armor.append(SkyGeometry.box_at(Vector3(center.x, -1.68, center.y), Vector3(size.x, 3.0, size.y)))
	var tiles := roundi(size.y / 4.0)
	for i in tiles:
		var row := size.y / tiles
		var z := center.y - size.y * 0.5 + row * (i + 0.5)
		for j in 4:
			var col := size.x * 0.25
			var target := _trim if j % 3 == 0 else _armor
			target.append(SkyGeometry.box_at(Vector3(center.x + col * (j - 1.5), -0.09, z), Vector3(col - 0.047, 0.18, row - 0.045)))
		_bolts.append(SkyGeometry.box_at(Vector3(center.x, -1.0, z), Vector3(size.x + 0.14, 0.48, 0.28)))


func _fence(world: World, a: Vector2, b: Vector2) -> void:
	var center := a.lerp(b, 0.5)
	var delta := (b - a).abs()
	world.box(center.x, center.y, delta.x + 0.27, delta.y + 0.27, 1.32, {"bottom": -0.22, "tag": "rail", "no_cam": true})
	var start := Vector3(a.x, 1.22, a.y)
	var end := Vector3(b.x, 1.22, b.y)
	_trim.append(SkyGeometry.beam(start, end, 0.24, 0.22))
	_armor.append(SkyGeometry.beam(start - Vector3.UP * 0.77, end - Vector3.UP * 0.77, 0.17, 0.23))
	var steps := ceili(a.distance_to(b) / 2.7)
	for i in range(steps + 1):
		var p := start.lerp(end, float(i) / steps)
		_armor.append(SkyGeometry.box_at(p - Vector3.UP * 0.55, Vector3(0.24, 1.25, 0.3)))
		_aqua.append(SkyGeometry.box_at(p + Vector3.UP * 0.05, Vector3(0.35, 0.11, 0.38)))


func _ticket_stand(world: World) -> void:
	var frame := Transform3D(Basis.IDENTITY, Vector3(35.0, 0.0, -101.0))
	_arch(frame, 5.05, 4.75, _gold)
	world.box(35.0, -100.6, 9.3, 3.7, 4.2, {"bottom": -0.2, "tag": "ticket stand"})
	_armor.append(SkyGeometry.box_at(Vector3(35.0, 0.63, -101.6), Vector3(9.25, 1.26, 1.96)))
	_trim.append(SkyGeometry.box_at(Vector3(35.0, 1.30, -101.72), Vector3(9.7, 0.16, 2.22)))
	_bolts.append(SkyGeometry.box_at(Vector3(35.0, 2.25, -99.85), Vector3(8.75, 4.46, 1.28)))
	for side: float in [-1.0, 1.0]:
		_gold.append(SkyGeometry.box_at(Vector3(35.0 + side * 3.88, 1.39, -102.48), Vector3(0.64, 0.1, 0.31)))
		_armor.append(SkyGeometry.box_at(Vector3(35.0 + side * 3.65, 2.50, -100.95), Vector3(0.92, 1.78, 0.78)))
	_panel(Vector3(35.0, 4.29, -102.0), 8.65, 1.12, "RACE TICKETS", 0.014, PHOSPHOR)
	_panel(Vector3(35.0, 2.54, -100.65), 5.1, 1.28, "OVERCURRENT", 0.008, PHOSPHOR)
	_panel(Vector3(35.0, 0.67, -102.54), 3.9, 0.42, "PILOT CHECK-IN", 0.0055, CYAN)
	var counter_light := OmniLight3D.new()
	counter_light.light_color = PHOSPHOR
	counter_light.light_energy = 1.24
	counter_light.omni_range = 9.0
	counter_light.position = Vector3(34.2, 3.7, -104.0)
	add_child(counter_light)
	for i in 16:
		var x := 35.0 + (i - 7.5) * 0.49
		_bolts.append(SkyGeometry.box_at(Vector3(x, 0.22, -102.61), Vector3(0.32, 0.2, 0.075)))
		if i % 4 != 0:
			_aqua.append(SkyGeometry.box_at(Vector3(x, 0.27, -102.67), Vector3(0.24, 0.035, 0.046)))


func _arch(frame: Transform3D, width: float, height: float, glow: Array[Transform3D]) -> void:
	for sign_: float in [-1.0, 1.0]:
		var foot := frame * Vector3(sign_ * width, -0.22, 0.0)
		var hinge := frame * Vector3(sign_ * width, height * 0.63, 0.0)
		var shoulder := frame * Vector3(sign_ * width * 0.69, height * 0.92, 0.0)
		var peak := frame * Vector3(0.0, height, 0.0)
		var corners: Array[Vector3] = [foot, hinge, shoulder, peak]
		for i in 3:
			var a := corners[i]
			var b := corners[i + 1]
			_armor.append(SkyGeometry.beam(a, b, 0.92, 1.15))
			_trim.append(SkyGeometry.beam(a - frame.basis.z * 0.55, b - frame.basis.z * 0.55, 0.34, 0.29))
			glow.append(SkyGeometry.beam(a.lerp(b, 0.13) - frame.basis.z * 0.72, a.lerp(b, 0.88) - frame.basis.z * 0.72, 0.105, 0.105))
		_bolts.append(SkyGeometry.box_at(foot + frame.basis.y * 0.5, Vector3(1.65, 1.0, 1.54), frame.basis))


func _panel(at: Vector3, width: float, height: float, text: String, size: float, color: Color, facing_back: bool = true, frame: Basis = Basis.IDENTITY) -> void:
	var flip := Basis(Vector3.UP, PI) if facing_back else Basis.IDENTITY
	var axes := frame * flip
	_armor.append(SkyGeometry.box_at(at, Vector3(width + 0.36, height + 0.28, 0.38), axes))
	var screen := BoxMesh.new()
	screen.size = Vector3(width, height, 0.05)
	SkyGeometry.part(self, screen, SkyGeometry.light(Color("101829"), 1.0), Transform3D(axes, at + axes.z * 0.22))
	var sign := SkyGeometry.sign_text(self, text, at + axes.z * 0.26, size, color)
	sign.basis = axes


func _wayfinding(course: SkyCourse) -> void:
	var start := course.sample(START_LINE)
	_arch(start, SkyCourse.HALF_WIDTH + 0.14, 9.4, _aqua)
	_panel(start * Vector3(0.0, 8.35, -1.0), 12.75, 1.78, "OVERCURRENT", 0.021, GOLD, true, start.basis)
	_off = SkyGeometry.light(Color("403041"), 0.82)
	_ready_light = SkyGeometry.light(Color("ff6139"), 2.45)
	_go_light = SkyGeometry.light(Color("62ffc0"), 2.3)
	var lens := BoxMesh.new()
	lens.size = Vector3(0.65, 0.38, 0.2)
	var line := BoxMesh.new()
	line.size = Vector3(SkyCourse.HALF_WIDTH * 2.0 - 1.0, 0.025, 0.56)
	SkyGeometry.part(self, line, SkyGeometry.light(Color("b5d8df"), 0.92), start.translated_local(Vector3(0.0, 0.013, 0.0)))
	for i in 3:
		var dx := (i - 1) * 0.94
		_lamps.append(SkyGeometry.part(self, lens, _off, start.translated_local(Vector3(dx, 6.84, -0.54))))
		_bolts.append(SkyGeometry.box_at(start * Vector3(dx, 6.84, -0.45), Vector3(0.86, 0.57, 0.36), start.basis))
	for i in course.gate_s.size():
		var mark := course.sample(course.gate_s[i])
		_arch(mark, SkyCourse.HALF_WIDTH + 0.24, 7.9, _rose)
		_panel(mark * Vector3(0.0, 7.3, -0.95), 10.15, 1.0, course.gate_names[i], 0.012, GOLD if course.gate_names[i] != "FINISH" else CYAN, true, mark.basis)
