class_name VhCar
extends RefCounted
## VISITING HOURS car (JS car.js): the rental, a tired '70s sedan on the shared vehicle controller, with headlights you can kill (a spot light, lens glows, a faint beam in the rain) and tail lights that flare on the brakes. The body is the export's.

const CAR := "vh_rental"

static var _lv: ExportedLevel = null


## the model: the one the export kept, on its feet at the origin (Vehicles places it)
static func _build(_o: Dictionary) -> Vehicles.VModel:
	var lv := _lv
	var root := VhKit.one(lv, "vh-rental")
	var chassis := VhKit.one(lv, "vh-rental-chassis")
	root.global_transform = Transform3D.IDENTITY
	var m := Vehicles.VModel.new()
	m.root = root
	m.chassis = chassis
	chassis.transform = Transform3D.IDENTITY
	m.wheel_r = 0.33
	m.hl = 2.44
	m.hw = 1.02
	m.wheelbase = 2.95
	m.axle_f = 1.475
	m.axle_r = -1.475
	m.track = 0.885
	m.height = 1.42
	m.seat = {"x": 0.38, "y": 0.52, "z": -0.15, "scale": 0.55, "wheel": {"x": 0.38, "y": 0.93, "z": 0.32, "tilt": 0.1, "r": 0.2}}
	var pivots: Array = lv.node_named("vh-rental-pivot")
	var spins: Array = lv.node_named("vh-rental-spin")
	for i in pivots.size():
		var w := Vehicles.VWheel.new()
		w.pivot = pivots[i]
		w.spin = spins[i]
		w.front = w.pivot.position.z > 0.0
		m.wheels.append(w)
	# lights: lens glows front and back, the spot that actually lights the road, a faint cone you can see in the rain
	var heads: Array[MeshInstance3D] = []
	var tails: Array[MeshInstance3D] = []
	for n: Node3D in lv.node_named("vh-rental-head"):
		n.visible = false
	for n: Node3D in lv.node_named("vh-rental-tail"):
		n.visible = false
	for i in 2:
		var h := MsKit.sprite8(chassis, 0xfff1cc, 1.0, 0.9)
		h.position = Vector3(-0.68 if i == 1 else 0.68, 0.72, 2.47)
		heads.append(h)
		var tl := MsKit.sprite8(chassis, 0xff2a14, 0.75, 0.5)
		tl.position = Vector3(-0.74 if i == 1 else 0.74, 0.78, -2.46)
		tails.append(tl)
	var spot := VhKit.light(lv, "vh-rental-spot") as SpotLight3D
	if spot != null:
		spot.transform = Transform3D(Basis.looking_at(Vector3(0.0, -1.2, 22.0) - Vector3(0.0, 0.8, 2.5), Vector3.UP), Vector3.ZERO)      # (under its place in the JS tree, at the lamp)
		spot.shadow_enabled = false
	var cone := VhKit.one(lv, "vh-rental-cone")
	for mi in VhKit.meshes(cone):
		mi.extra_cull_margin = 30.0
	m.set_lights = func(v: bool) -> void:
		m.lights = v
		if spot != null:
			spot.light_energy = 2200.0 / PI if v else 0.0
		cone.visible = v
		for h: MeshInstance3D in heads:
			h.visible = v
	m.brake = func(b: bool) -> void:
		for tl: MeshInstance3D in tails:
			tl.scale = Vector3.ONE * (0.95 if b else 0.5)
			MsKit.opa(tl, 1.0 if b else (0.75 if m.lights else 0.35))
	m.set_lights.call(true)
	m.brake.call(false)
	return m


static func register(lv: ExportedLevel) -> void:
	_lv = lv
	Vehicles.register_type(CAR, {"build": _build, "label": "'74 RENTAL SEDAN", "nitro": false, "tail_pluck": false,
		"handling": {"top_speed": 24.0, "reverse_speed": 8.0, "accel": 10.0, "brake": 22.0, "coast": 2.6, "rolling": 6.0, "mu": 1.3, "rear_grip": 1.22, "drive": "rear", "hb_mu": 0.34, "slip_peak_f": 0.2, "slip_peak_r": 0.15, "yaw_inertia": 1.05, "steer_low": 0.56, "steer_high": 0.12, "suspension": 7.0, "body_freq": 9.0, "body_damp": 0.36},
		"cam": {"dist": 7.2, "height": 2.0, "pitch": 0.26, "side": 0.0}, "engine": {"base": 32.0, "span": 78.0, "type": "sawtooth", "whine": 0.0},
		"seat": {"x": 0.38, "y": 0.52, "z": -0.15, "scale": 0.55, "wheel": {"x": 0.38, "y": 0.93, "z": 0.32, "tilt": 0.1, "r": 0.2}}})
