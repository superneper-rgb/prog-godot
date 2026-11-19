class_name RigLaunch
extends Node3D
## FOINT CITY: Pauly's rig taking off (user, 2026-11-18: "it just light speed flies off into the sky into the distance in a cool action shot way with the camera
## in place from where you see them take off and disappear"). X at the rig once the CLUB 9 talk is had (levels/hub/hub_race_rig.gd): a dip to black while Prog and Pauly climb in
## (RigCrew), then one shot from one place on the street, the camera only turning. The rig, as beaten up as it stands (its red door and its fourth emitter stay on the pavement),
## coughs twice, catches, drags itself up off its dead corner and rocks level, flares its three live emitters, tips its nose to the gap of sky between the towers, gathers a charge
## at its tail and goes: a flash, rings of shocked air up its path, a line of light from the street to the sky that hangs and frays, and a twinkle where it went. The street takes
## it: litter and spray thrown out, the door flung over across the pavement, the lights of the street dipping as it charges. The camera comes back down to what is left on the
## kerb, paper still coming down and the spare emitter spinning itself flat like a dropped coin, and the screen goes to black for the level door (Doors.travel).
## It is the hub's `cine` (core/view.gd): while `on` the camera is `camera` and the player gets no input. Everything it shows is a function of `t`, so a moment can be looked at
## by holding the clock (`hold`) and setting `t`. Its lights are added to the frame and one flash light (core/flash_lights.gd) for the painted street: no real lamp is added.

const TO := "sky-sphere"
const LOADING := "SKYSPHERE"
const GLOW := "res://levels/hub/rig_launch_glow.gdshader"
const BEAM := "res://levels/hub/rig_launch_beam.gdshader"
const CAM := Vector3(1.5, 0.45, -29.0)      # on the road behind the rig's right shoulder, low: the rig, the CLUB 9 front and the towers over the street
const FOV := 58.0
const ELEV := 1.19             # the way out: 68 degrees up along the street, into the gap of sky over the tower at its end
const REACH := 250.0           # how far the line of light runs (the hub's sky is a 300 m shell round the camera)
const CENTRE := Vector3(0.0, 1.0, 0.0)      # the middle of the body, car frame: what it turns about
const HOVER_H := 1.25
const TIP_H := 2.35
const PULL := 0.8              # it draws back down its path before it goes
const ACCEL := 9000.0          # m/s2 up the path: the whole reach in a sixth of a second
const T_COUGH: Array[float] = [0.45, 0.85]
const T_LIFT := 1.25
const T_HOVER := 2.4
const T_TIP := 2.8
const T_CHARGE := 3.6
const T_GO := 4.7
const T_STAR := T_GO + 0.42
const T_DOWN := T_GO + 1.3     # the camera starts back down
const DOWN_S := 1.0
const T_COIN := T_GO + 0.5     # the spare, stood on its rim by the blast, begins to spin down
const COIN_S := 2.6            # and is flat this long after
const T_END := T_GO + 3.4
const FADE := 0.5
const CYAN := Color(0.5, 0.88, 1.0)
const SCRAPS := 44
const HALO_AT: Array[float] = [26.0, 72.0, 140.0]      # rings of shocked air up the path, metres from where it went
const KERB := Vector3(-4.7, 0.5, -38.2)      # what is left: the door and the spare on the pavement, the empty road

static var _sound: AudioStreamWAV = null

var on := false
var play := false                  # (core/view.gd: not a playable cutscene)
var camera := View.Shot.new(CAM, CAM + Vector3.FORWARD, FOV)
var done := false                  # it has gone
var hold := false                  # the clock stands (looking at one moment)
var t := 0.0
var phase := &"off"                # in (to black, climbing in), shot, out (to black)
var crew: RigCrew = null
var rig: HubRaceRig = null
var car: CityCars.CarModel = null

var _pt := 0.0
var _prev := -1.0
var _warm := 12
var _d := Vector3.UP               # the way it goes
var _b0 := Basis.IDENTITY          # parked
var _c0 := Vector3.ZERO            # the body's middle, parked
var _c_go := Vector3.ZERO          # the same, drawn back, the moment it goes
var _end := Vector3.ZERO           # where the line of light ends
var _gone := false
var _fx: Array[MeshInstance3D] = []
var _m_em: Array[ShaderMaterial] = []
var _g_em: Array[MeshInstance3D] = []
var _g_pool: MeshInstance3D
var _g_tail: MeshInstance3D
var _g_flash: MeshInstance3D
var _g_head: MeshInstance3D
var _g_star: MeshInstance3D
var _rings: Array[MeshInstance3D] = []      # two where it left, then the halos up the path
var _beam: MeshInstance3D
var _beam_m: ShaderMaterial
var _light: OmniLight3D
var _lights_m: ShaderMaterial = null        # this car's own lit strips
var _shadow_m: StandardMaterial3D = null
var _snd: AudioStreamPlayer
var _bake := -1
var _door: Node3D = null
var _door_a := Transform3D.IDENTITY
var _door_b := Transform3D.IDENTITY          # where it comes down
var _faded := false                          # this has the screen black
var _spare: Node3D = null
var _spare_a := Transform3D.IDENTITY
var _spare_b := Transform3D.IDENTITY
var _axle := Vector3.ZERO                    # the bare axle, car frame
var _exposure := 1.0
# the litter
var _mm: MultiMesh
var _lp := PackedVector3Array()
var _lv := PackedVector3Array()
var _lax := PackedVector3Array()
var _lang := PackedFloat32Array()
var _lspin := PackedFloat32Array()
var _lwake := PackedFloat32Array()
var _lstate := PackedByteArray()             # 0 not out yet, 1 in the air, 2 lying
var _rng := RandomNumberGenerator.new()


# ---------------------------------------------------------------- building

func setup(p_rig: HubRaceRig) -> void:
	name = "RigLaunch"
	rig = p_rig
	car = rig.car
	crew = RigCrew.new(car)
	_rng.seed = 9
	_d = Basis(Vector3.UP, HubRaceRig.YAW) * Vector3(0.0, sin(ELEV), cos(ELEV))
	_b0 = car.root.transform.basis
	_c0 = car.root.transform * CENTRE
	_c_go = _c0 + Vector3(0.0, TIP_H, 0.0) - _d * PULL
	_end = _c_go + _d * REACH
	var sh: Shader = load(GLOW)
	for w: CityCars.CarWheel in car.wheels:      # the three emitters still on it
		if w.pivot.get_parent() == car.root:
			_g_em.append(_glow(sh, car.root, CYAN, 1.5))
			_g_em[-1].position = w.pivot.position + Vector3(0.0, -0.12, 0.0)
		else:
			_spare = w.pivot
			_axle = Vector3(1.0, 0.34, 1.35)      # (front left: tools/cars/more_cars.py saucer_b AX, TRACK, WR)
	for g in _g_em:
		_m_em.append(g.material_override)
	_g_pool = _glow(sh, self, CYAN, 7.0, false)
	_g_pool.rotation.x = -PI / 2.0
	_g_pool.position = Vector3(HubRaceRig.AT.x, 0.03, HubRaceRig.AT.z)
	_g_tail = _glow(sh, car.root, CYAN, 1.0)
	_g_tail.position = Vector3(0.0, 0.95, -2.25)
	_g_flash = _glow(sh, self, Color(0.8, 0.95, 1.0), 24.0)
	_g_flash.position = _c_go
	_g_head = _glow(sh, self, Color(0.8, 0.95, 1.0), 3.0)
	_g_star = _glow(sh, self, Color(0.75, 0.93, 1.0), 20.0)
	_g_star.position = _end
	_mat(_g_star).set_shader_parameter(&"star", 1.0)
	_mat(_g_star).set_shader_parameter(&"hot", 0.6)
	var across := _across(_d)
	for i in 2 + HALO_AT.size():
		var r := _glow(sh, self, CYAN if i < 2 else Color(0.7, 0.92, 1.0), 4.0, false)
		r.basis = across
		r.position = _c_go if i < 2 else _c_go + _d * HALO_AT[i - 2]
		_mat(r).set_shader_parameter(&"ring", 0.8)
		_mat(r).set_shader_parameter(&"ring_w", 0.05 if i != 1 else 0.11)
		_rings.append(r)
	_beam = MeshInstance3D.new()
	_beam.name = "LightLine"
	_beam.mesh = _tube()
	_beam_m = ShaderMaterial.new()
	_beam_m.shader = load(BEAM)
	_beam.material_override = _beam_m
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.extra_cull_margin = 16384.0
	add_child(_beam)
	_fx.append(_beam)
	_light = OmniLight3D.new()      # the painted street takes this through core/flash_lights.gd, the lit things as a light
	_light.name = "LaunchLight"
	_light.light_color = CYAN
	_light.omni_range = 26.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.add_to_group(FlashLights.GROUP)
	add_child(_light)
	# this car's lit strips on a material of their own (the fleet shares one): they flare with the emitters
	_lights_m = (rig_lights() as ShaderMaterial).duplicate() as ShaderMaterial
	for mi: MeshInstance3D in CityCars._meshes(car.root):
		for i in mi.mesh.get_surface_count():
			if CityCars._group_of(mi.mesh, i) == &"CarLights":
				mi.set_surface_override_material(i, _lights_m)
	var shd := rig.get_node_or_null(^"Shadow") as MeshInstance3D
	if shd != null:
		_shadow_m = shd.material_override as StandardMaterial3D
	# the door and the spare on the pavement: where they lie, and where the spare ends up once the door is gone from under it
	_door = rig.get_node_or_null(^"Pivot_Door") as Node3D
	if _door != null:
		_door_a = _door.global_transform
		_door_b = Transform3D(Basis(Vector3.UP, 0.9) * _door_a.basis, _door_a.origin + Vector3(-0.9, 0.0, 0.55))      # (toward the club's doorway, clear of the green alien by the wall)
	if _spare != null:
		_spare_a = _spare.global_transform
		var at := _spare_a.origin
		rig._lay(_spare, Basis(Vector3.UP, HubRaceRig.YAW - 1.5) * Basis(Vector3.FORWARD, PI / 2.0), Vector2(at.x + 0.25, at.z + 0.5))
		_spare_b = _spare.global_transform
		_spare.global_transform = _spare_a
	_litter()
	_snd = AudioStreamPlayer.new()
	_snd.name = "LaunchSound"
	_snd.bus = &"SFX"
	_snd.volume_db = -3.0
	add_child(_snd)
	if _sound == null and _bake < 0:
		_bake = WorkerThreadPool.add_task(_bake_sound, false, "rig launch sound")
	_show(true)      # (a few frames in the frame, drawing nothing, so their pipelines are made at load)
	_apply(0.0, 0.0)


func rig_lights() -> Material:
	for mi: MeshInstance3D in CityCars._meshes(car.root):
		for i in mi.mesh.get_surface_count():
			if CityCars._group_of(mi.mesh, i) == &"CarLights":
				return mi.get_surface_override_material(i)
	return ShaderMaterial.new()


func _exit_tree() -> void:
	if _bake >= 0:
		WorkerThreadPool.wait_for_task_completion(_bake)
		_bake = -1
	if on:
		_let_go()


static func _mat(mi: MeshInstance3D) -> ShaderMaterial:
	return mi.material_override as ShaderMaterial


## a quad with the glow on it, its own material (power 0: not drawn)
func _glow(sh: Shader, under: Node3D, tint: Color, size: float, facing: bool = true) -> MeshInstance3D:
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter(&"tint", tint)
	m.set_shader_parameter(&"face", 1.0 if facing else 0.0)
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0
	mi.scale = Vector3.ONE * size
	under.add_child(mi)
	_fx.append(mi)
	return mi


## a basis whose z is d (a quad placed with it lies across d; the tube runs along it)
static func _across(d: Vector3) -> Basis:
	var x := d.cross(Vector3.RIGHT).normalized() if absf(d.x) < 0.9 else d.cross(Vector3.UP).normalized()
	return Basis(x, d.cross(x).normalized(), d)


## the line of light's tube: along +Z from 0 to 1, radius 1 at the street widening to 3.2 at the far end (so it is still a line 250 m off), UV.y the way along
static func _tube() -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var ix := PackedInt32Array()
	var sides := 14
	var rings := 2
	for j in rings:
		var z := float(j)
		var r := lerpf(1.0, 3.2, z)
		for i in sides + 1:
			var a := TAU * i / sides
			v.append(Vector3(cos(a) * r, sin(a) * r, z))
			n.append(Vector3(cos(a), sin(a), 0.0))
			uv.append(Vector2(float(i) / sides, z))
	for i in sides:
		var a := i
		var b := i + 1
		var c := i + sides + 1
		var e := i + sides + 2
		ix.append_array([a, c, b, b, c, e])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = ix
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


## The street's litter that the rig throws about: scraps of paper and card that come out from under it as it lifts, and go everywhere when it leaves. Lit as Prog is (and by the
## launch's light), one MultiMesh.
func _litter() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(0.17, 0.12)
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	q.material = m
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = q
	_mm.instance_count = SCRAPS
	var mi := MultiMeshInstance3D.new()
	mi.name = "Litter"
	mi.multimesh = _mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-60.0, -2.0, -100.0), Vector3(120.0, 60.0, 130.0))
	add_child(mi)
	_lp.resize(SCRAPS)
	_lv.resize(SCRAPS)
	_lax.resize(SCRAPS)
	_lang.resize(SCRAPS)
	_lspin.resize(SCRAPS)
	_lwake.resize(SCRAPS)
	_lstate.resize(SCRAPS)
	var tones: Array[Color] = [Color(0.38, 0.37, 0.34), Color(0.3, 0.3, 0.33), Color(0.4, 0.34, 0.24), Color(0.24, 0.26, 0.32), Color(0.44, 0.43, 0.42)]
	for i in SCRAPS:
		_mm.set_instance_color(i, tones[i % tones.size()])
	_litter_reset()


func _litter_reset() -> void:
	_rng.seed = 9
	for i in SCRAPS:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(0.2, 1.1)
		_lp[i] = Vector3(HubRaceRig.AT.x + cos(a) * r, 0.05, HubRaceRig.AT.z + sin(a) * r * 1.6)
		_lv[i] = Vector3.ZERO
		_lax[i] = Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5).normalized()
		_lang[i] = _rng.randf() * TAU
		_lspin[i] = 0.0
		_lwake[i] = _rng.randf_range(T_LIFT + 0.1, T_TIP) if i < SCRAPS - 12 else T_GO      # (the last dozen only come out when it goes)
		_lstate[i] = 0
		_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), _lp[i]))


## The whole shot's sound, made once a session on a worker (audio/offline_synth.gd): the starter turning over twice, the hover drive catching and holding, the whine and the
## indrawn air of the charge, the bang and its echoes off the towers, the zip away, the door on the paving, and the twinkle.
static func _bake_sound() -> void:
	var R := 22050
	var b := OfflineSynth.make(T_END + 1.4, R)
	for c: float in [0.06, 0.24]:      # two bodies into two seats
		OfflineSynth.tone(b, R, c, {"type": &"sine", "f0": 96.0, "f1": 48.0, "gain": 0.22, "dur": 0.14, "attack": 0.004})
	for c: float in T_COUGH:
		OfflineSynth.noise(b, R, c, {"type": &"lowpass", "f0": 560.0, "f1": 110.0, "q": 4.0, "gain": 0.5, "dur": 0.27, "attack": 0.012})
		OfflineSynth.tone(b, R, c, {"type": &"sawtooth", "f0": 84.0, "f1": 36.0, "gain": 0.14, "dur": 0.3, "attack": 0.01})
		OfflineSynth.noise(b, R, c + 0.05, {"type": &"bandpass", "f0": 2600.0, "f1": 900.0, "q": 3.0, "gain": 0.08, "dur": 0.13, "attack": 0.004})
	OfflineSynth.noise(b, R, T_LIFT, {"type": &"lowpass", "f0": 300.0, "f1": 900.0, "q": 3.0, "gain": 0.3, "dur": 0.5, "attack": 0.05})      # it catches
	# the hover drive: a throbbing low note that spins up, holds, and climbs under the charge; cut dead when it goes
	var s0 := int(T_LIFT * R)
	var s1 := int(T_GO * R)
	var ph := 0.0
	for i in range(s0, s1):
		var tt := float(i) / R
		var f := lerpf(42.0, 88.0, smoothstep(T_LIFT, T_HOVER, tt)) + 70.0 * smoothstep(T_TIP, T_GO, tt)
		ph = fposmod(ph + f / R, 1.0)
		var g := 0.15 * smoothstep(T_LIFT, T_LIFT + 0.6, tt) * (1.0 + 0.5 * smoothstep(T_CHARGE, T_GO, tt)) * (1.0 - smoothstep(T_GO - 0.012, T_GO, tt))
		var throb := 0.78 + 0.22 * sin(tt * TAU * 11.0)
		b[i] += (sin(ph * TAU) + 0.5 * sin(ph * TAU * 2.0) + 0.28 * sin(ph * TAU * 3.0) + 0.12 * sin(ph * TAU * 5.0)) * g * throb
	# the charge: a whine that runs up three octaves, a fifth over it
	s0 = int(T_TIP * R)
	ph = 0.0
	var ph2 := 0.0
	for i in range(s0, s1):
		var tt := float(i) / R
		var u := (tt - T_TIP) / (T_GO - T_TIP)
		var f := 280.0 * pow(9.5, pow(u, 1.5)) * (1.0 + 0.006 * sin(tt * TAU * 31.0))
		ph = fposmod(ph + f / R, 1.0)
		ph2 = fposmod(ph2 + f * 1.503 / R, 1.0)
		var g := (0.012 + 0.2 * u * u) * (1.0 - smoothstep(T_GO - 0.012, T_GO, tt))
		b[i] += (sin(ph * TAU) + 0.45 * sin(ph2 * TAU)) * g
	OfflineSynth.noise(b, R, T_CHARGE - 0.25, {"type": &"bandpass", "f0": 420.0, "f1": 5200.0, "q": 1.6, "gain": 0.42, "dur": T_GO - T_CHARGE + 0.25, "attack": (T_GO - T_CHARGE + 0.25) * 0.97})
	# it goes: a beat of nothing, the bang, the sub under it, the crack over it, the zip up the sky, and the bang again off the towers
	var g0 := T_GO + 0.035
	OfflineSynth.noise(b, R, g0, {"type": &"lowpass", "f0": 2800.0, "f1": 70.0, "q": 1.0, "gain": 0.95, "dur": 2.3, "attack": 0.004})
	OfflineSynth.tone(b, R, g0, {"type": &"sine", "f0": 124.0, "f1": 29.0, "gain": 0.85, "dur": 1.6, "attack": 0.004})
	OfflineSynth.noise(b, R, g0, {"type": &"highpass", "f0": 5200.0, "f1": 1500.0, "q": 0.7, "gain": 0.45, "dur": 0.09, "attack": 0.001})
	OfflineSynth.tone(b, R, g0, {"type": &"sine", "f0": 2700.0, "f1": 150.0, "gain": 0.2, "dur": 0.4, "attack": 0.004})
	OfflineSynth.tone(b, R, g0, {"type": &"triangle", "f0": 1350.0, "f1": 75.0, "gain": 0.14, "dur": 0.48, "attack": 0.004})
	OfflineSynth.noise(b, R, g0 + 0.21, {"type": &"lowpass", "f0": 1000.0, "f1": 60.0, "q": 1.0, "gain": 0.36, "dur": 1.5, "attack": 0.01})
	OfflineSynth.noise(b, R, g0 + 0.43, {"type": &"lowpass", "f0": 700.0, "f1": 55.0, "q": 1.0, "gain": 0.2, "dur": 1.6, "attack": 0.02})
	# the door coming down on the paving and rattling still
	var k := 0
	for c: float in [0.62, 0.72, 0.82, 0.93, 1.03, 1.13]:
		OfflineSynth.noise(b, R, T_GO + c, {"type": &"bandpass", "f0": 2500.0 - 150.0 * k, "f1": 1500.0, "q": 4.0, "gain": 0.2 * exp(-k * 0.5), "dur": 0.06, "attack": 0.001})
		OfflineSynth.tone(b, R, T_GO + c, {"type": &"triangle", "f0": 520.0 - 20.0 * k, "f1": 430.0, "gain": 0.07 * exp(-k * 0.5), "dur": 0.08, "attack": 0.001})
		k += 1
	# the spare spinning down on its rim: a tick each half turn, closer and closer, and the clap as it lies flat
	var last := 0.0
	var steps := 1200
	for i in steps:
		var v := float(i) / steps
		var turn := coin(v).y
		if turn - last >= PI:
			last += PI
			var lv := 0.05 + 0.1 * v
			OfflineSynth.noise(b, R, T_COIN + v * COIN_S, {"type": &"bandpass", "f0": 3400.0, "f1": 2400.0, "q": 6.0, "gain": lv, "dur": 0.03, "attack": 0.001})
			OfflineSynth.tone(b, R, T_COIN + v * COIN_S, {"type": &"triangle", "f0": 900.0 + 500.0 * v, "f1": 800.0, "gain": lv * 0.4, "dur": 0.04, "attack": 0.001})
	OfflineSynth.noise(b, R, T_COIN + COIN_S, {"type": &"bandpass", "f0": 1800.0, "f1": 700.0, "q": 2.0, "gain": 0.3, "dur": 0.14, "attack": 0.001})
	OfflineSynth.tone(b, R, T_COIN + COIN_S, {"type": &"triangle", "f0": 420.0, "f1": 300.0, "gain": 0.12, "dur": 0.16, "attack": 0.001})
	# the twinkle
	OfflineSynth.tone(b, R, T_STAR, {"type": &"sine", "f0": 3136.0, "f1": 3120.0, "gain": 0.085, "dur": 1.0, "attack": 0.002})
	OfflineSynth.tone(b, R, T_STAR + 0.07, {"type": &"sine", "f0": 4186.0, "f1": 4170.0, "gain": 0.065, "dur": 0.9, "attack": 0.002})
	OfflineSynth.tone(b, R, T_STAR + 0.14, {"type": &"sine", "f0": 5274.0, "f1": 5250.0, "gain": 0.045, "dur": 0.8, "attack": 0.002})
	OfflineSynth.tone(b, R, T_STAR + 0.38, {"type": &"sine", "f0": 6272.0, "f1": 6250.0, "gain": 0.04, "dur": 0.6, "attack": 0.002})
	OfflineSynth.noise(b, R, T_STAR, {"type": &"bandpass", "f0": 7600.0, "f1": 5200.0, "q": 6.0, "gain": 0.035, "dur": 0.5, "attack": 0.003})
	for i in b.size():      # (the bang runs hot on purpose: rounded off, never clipped)
		b[i] = tanh(b[i] * 1.15)
	_sound = OfflineSynth.wav(b, R)


# ---------------------------------------------------------------- the action

## X at the rig.
func can_start() -> bool:
	return not on and not done


func start() -> void:
	if on or Game.doors.travelling or Game.player == null or Game.player.dead:
		return
	on = true
	done = false
	phase = &"in"
	_pt = 0.0
	var cam := Game.view.camera
	camera.pos = cam.global_position      # (the game's view held while it goes to black)
	camera.look = cam.global_position - cam.global_basis.z * 4.0
	camera.fov = cam.fov
	camera.up = Vector3.ZERO
	Game.player.vx = 0.0
	Game.player.vz = 0.0
	Game.hud.set_suppressed(true)
	Game.ui.set_fade(true)
	_faded = true


## into the seats on black, the camera to its place, and the shot runs
func _begin_shot() -> void:
	if _bake >= 0:
		WorkerThreadPool.wait_for_task_completion(_bake)
		_bake = -1
	phase = &"shot"
	t = 0.0
	_prev = -1.0
	_gone = false
	_exposure = Game.view.exposure
	car.root.visible = true
	rig.set_parked(false)
	_litter_reset()
	_show(true)
	crew.brace = 0.0
	crew.board()
	camera.pos = CAM
	camera.fov = FOV
	_apply(0.0, 0.0)
	if _sound != null:
		_snd.stream = _sound
		_snd.play()
	Game.ui.set_fade(false)
	_faded = false


## the frame's own things given back (the seat, the HUD, the tone map)
func _let_go() -> void:
	on = false
	phase = &"off"
	if crew != null:
		crew.leave()
	if Game.animator != null:
		Game.animator.actor.visible = true
	if Game.hud != null:
		Game.hud.set_suppressed(false)
	if Game.view != null and Game.view.post != null:
		Game.view.post.exposure = Game.view.exposure
	_light.light_energy = 0.0


## on black: through the level door, or (the arena not in this build) everything back as it stood
func _finish() -> void:
	done = true
	_snd.stop()
	_let_go()
	_show(false)
	if Game.LEVELS.has(TO):
		_faded = false      # (the door has the black from here)
		Game.doors.travel({"id": "race-rig", "label": "", "to": TO, "spawn_at": "", "loading": LOADING, "before": func() -> void: pass})
		return
	reset()      # (no level to arrive in yet: the street is put back as it was)


## The street as it was before the shot: the rig at the kerb, Pauly beside it, Prog on the pavement.
func reset() -> void:
	if on:
		_let_go()
	if _faded:
		_faded = false
		Game.ui.set_fade(false)
	_snd.stop()
	hold = false
	done = false
	_gone = false
	t = 0.0
	_prev = -1.0
	_apply(0.0, 0.0)
	_litter_reset()
	_show(false)
	car.root.visible = true
	rig.set_parked(true)
	var P := Game.player
	if P != null:
		P.x = HubRaceRig.BESIDE.x
		P.y = HubRaceRig.BESIDE.y
		P.z = HubRaceRig.BESIDE.z
		P.yaw = PI
		if Game.rig != null:
			Game.rig.snap_to(P)


func _show(v: bool) -> void:
	for mi in _fx:
		mi.visible = v


## Every frame (HubRaceRig.tick). dt is 0 while the game is paused: the shot and its sound hold.
func update(dt: float) -> void:
	if _warm > 0:
		_warm -= 1
		if _warm == 0 and not on:
			_show(false)
	if not on:
		return
	_snd.stream_paused = dt <= 0.0
	# nothing in the street answers a button while it plays (Game reads these after the level's tick)
	Inp.btn(&"attack").pressed = false
	Inp.btn(&"b").pressed = false
	Game.ui.dlg_req = false
	match phase:
		&"in":
			_pt += dt
			if _pt >= FADE:
				_begin_shot()
		&"shot":
			if not hold:
				t += dt
			_apply(t, dt)
			_prev = t
			if t >= T_END and not hold:
				phase = &"out"
				_pt = 0.0
				Game.ui.set_fade(true)
				_faded = true
		&"out":
			_pt += dt
			_apply(t, dt)
			if _pt >= FADE + 0.1:
				_finish()


## Game's frame, after the Animator has posed him (core/game.gd): he is drawn in his seat whatever the game's own camera rig thinks of where its lens is.
func pose_player(an: Animator) -> void:
	an.actor.visible = phase == &"shot" and not _gone or phase == &"in"


# ---------------------------------------------------------------- the shot, as a function of t

static func _ss(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)


func _crossed(at: float) -> bool:
	return _prev < at and t >= at


## how hard the three live emitters burn, 0..1.6
func _burn(tt: float) -> float:
	var e := 0.0
	for c: float in T_COUGH:      # two dead turns of the starter: a stutter of light
		var u := tt - c
		if u > 0.0 and u < 0.3:
			e = maxf(e, (0.35 + 0.35 * sin(u * 90.0)) * (1.0 - u / 0.3))
	if tt >= T_LIFT:
		e = 0.55 + 0.25 * _ss(T_LIFT, T_HOVER, tt) + 0.06 * sin(tt * 23.0)
		e += 0.3 * _ss(T_HOVER, T_TIP, tt)
		e += 0.5 * _ss(T_CHARGE, T_GO, tt)
	return e


func _apply(tt: float, dt: float) -> void:
	var go := tt - T_GO
	# ---- the rig ----
	var m := 1.0           # how much of its parked sag
	var h := 0.0
	var up := 0.0
	var along := 0.0
	var yaw_w := 0.0
	var jit := Vector3.ZERO
	var stretch := 1.0
	for c: float in T_COUGH:      # the starter: a shudder and a hop that goes nowhere
		var u := tt - c
		if u > 0.0 and u < 0.36:
			var k := 1.0 - u / 0.36
			h += 0.045 * sin(u / 0.36 * PI) * k
			jit += Vector3(sin(u * 71.0), 0.0, cos(u * 63.0)) * 0.012 * k
			m += 0.25 * sin(u * 55.0) * k
	if tt >= T_LIFT:
		var u := minf(1.0, (tt - T_LIFT) / (T_HOVER - T_LIFT))
		# the three good corners come up first and the dead one drags: the sag deepens, then it rocks over level and settles
		m = exp(-3.0 * u) * cos(8.0 * u) + 0.9 * sin(PI * clampf(u / 0.28, 0.0, 1.0))
		m *= (1.0 + 1.4 * _ss(0.0, 0.15, u)) * (1.0 - _ss(T_HOVER, T_TIP, tt))
		h = HOVER_H * (1.0 - pow(1.0 - u, 2.6)) + 0.1 * sin(u * PI) * (1.0 - u)
		h += 0.03 * sin(tt * 5.5) * _ss(T_LIFT + 0.5, T_HOVER, tt)
		yaw_w = 0.05 * sin((tt - T_LIFT) * 2.4) * exp(-1.6 * (tt - T_LIFT))
	if tt >= T_TIP:
		var u := _ss(T_TIP, T_CHARGE, tt)
		up = ELEV * (u + 0.07 * sin(u * PI) * sin((tt - T_TIP) * 9.0))
		h = lerpf(h, TIP_H, u)
	if tt >= T_CHARGE:
		var u := clampf((tt - T_CHARGE) / (T_GO - T_CHARGE), 0.0, 1.0)
		along = -PULL * u * u
		up = ELEV
		var a := 0.022 * u * u      # it shakes harder the more it holds
		jit = Vector3(sin(tt * 173.0), sin(tt * 151.0 + 1.0), sin(tt * 197.0 + 2.0)) * a
	if go > 0.0:
		along = -PULL + 0.5 * ACCEL * go * go
		stretch = 1.0 + minf(11.0, along * 0.3)
		jit = Vector3.ZERO
	var basis := Basis(Vector3.UP, HubRaceRig.YAW + yaw_w) * Basis(Vector3.RIGHT, -up) * Basis.from_euler(Vector3(0.05, 0.0, -0.07) * m)
	var centre := _c0 + Vector3(0.0, h, 0.0) + _d * along + jit
	var gone := go > 0.0 and along > 60.0
	car.root.global_transform = Transform3D(basis * Basis.from_scale(Vector3(1.0, 1.0, stretch)), centre - basis * CENTRE)
	if gone != _gone:
		_gone = gone
		car.root.visible = not gone
		crew.set_shown(not gone)
	if on and phase != &"in" and not gone:
		crew.brace = _ss(T_TIP + 0.3, T_CHARGE + 0.3, tt)
		crew.update(Game.time, dt)
	# ---- its light ----
	var burn := _burn(tt) if go <= 0.0 else 1.6
	var near_ground := 1.0 - _ss(0.4, 3.2, h)
	for i in _g_em.size():
		var fl := 1.0 + 0.12 * sin(tt * 31.0 + i * 2.1)
		_m_em[i].set_shader_parameter(&"power", 0.5 * burn * fl)
		_g_em[i].scale = Vector3.ONE * (1.1 + 0.9 * burn)
	if _lights_m != null:
		_lights_m.set_shader_parameter(&"gain", 3.2 + 6.0 * burn)
	_mat(_g_pool).set_shader_parameter(&"power", 0.3 * burn * near_ground * (0.0 if go > 0.05 else 1.0))
	_g_pool.scale = Vector3.ONE * (5.0 + 3.5 * h)
	var charge := _ss(T_CHARGE - 0.3, T_GO, tt) if go <= 0.0 else 0.0
	_mat(_g_tail).set_shader_parameter(&"power", 0.9 * charge * charge + 0.25 * _ss(T_TIP, T_CHARGE, tt) * (1.0 if go <= 0.0 else 0.0))
	_g_tail.scale = Vector3.ONE * (1.4 + 5.0 * charge * charge) * (1.0 + 0.08 * sin(tt * 53.0))
	if _shadow_m != null:
		_shadow_m.albedo_color.a = (1.0 - _ss(0.0, 2.6, h)) * (0.0 if go > 0.0 else 1.0)
	# ---- it goes: the flash, the rings, the line of light, the twinkle ----
	var gp := maxf(go, 0.0)
	_mat(_g_flash).set_shader_parameter(&"power", (0.9 * exp(-gp / 0.045) + 0.07 * exp(-gp / 0.25)) if go > 0.0 else 0.0)
	for i in _rings.size():
		var r := _rings[i]
		var at := 0.0 if i == 0 else (0.07 if i == 1 else sqrt(2.0 * (HALO_AT[i - 2] + PULL) / ACCEL))
		var u := go - at
		var far := HALO_AT[i - 2] if i >= 2 else 0.0
		if u <= 0.0:
			_mat(r).set_shader_parameter(&"power", 0.0)
			continue
		var grow := (5.5 if i == 0 else (3.2 if i == 1 else 4.5))
		var size := (3.0 + (30.0 if i < 2 else 26.0 + far * 0.22) * (1.0 - exp(-u * grow)))      # (the two where it left stay small: they open round the camera)
		r.scale = Vector3.ONE * size
		_mat(r).set_shader_parameter(&"power", ((0.5 if i == 0 else 0.3) if i < 2 else 0.6) * exp(-u * (6.5 if i < 2 else 3.4)))
	var head := clampf((along + PULL) / REACH, 0.0, 1.0) if go > 0.0 else 0.0
	_beam_m.set_shader_parameter(&"head", head)
	_beam_m.set_shader_parameter(&"power", (1.7 * exp(-gp / 0.38) + 0.5 * exp(-gp / 1.3)) * (1.0 - _ss(2.2, 3.0, gp)) if go > 0.0 else 0.0)
	_beam_m.set_shader_parameter(&"tail", maxf(0.0, (gp - 0.55) / 2.4))
	_beam_m.set_shader_parameter(&"fray", _ss(0.25, 1.7, gp))
	_beam_m.set_shader_parameter(&"age", gp)
	var wide := 0.5 * (1.0 + 0.9 * gp)
	_beam.global_transform = Transform3D(_across(_d) * Basis.from_scale(Vector3(wide, wide, REACH)), _c_go)
	var hp := _c_go + _d * (head * REACH)
	_g_head.position = hp
	_g_head.scale = Vector3.ONE * (3.5 + head * REACH * 0.05)
	_mat(_g_head).set_shader_parameter(&"power", (1.2 * (1.0 - _ss(T_STAR - T_GO - 0.12, T_STAR - T_GO + 0.25, gp)) + 0.1 * exp(-(gp - 0.4) * 1.2)) if go > 0.0 else 0.0)
	var su := tt - T_STAR
	if su > 0.0:      # a pop, a second smaller blink, and out
		var pop := exp(-su * 3.0) * (1.0 - exp(-su * 45.0)) + 0.5 * exp(-pow((su - 0.38) / 0.06, 2.0))
		_g_star.scale = Vector3.ONE * (10.0 + 62.0 * pop)
		_g_star.rotation.z = su * 0.5
		_mat(_g_star).set_shader_parameter(&"power", 1.6 * pop * (1.0 - _ss(1.0, 1.5, su)))
	else:
		_mat(_g_star).set_shader_parameter(&"power", 0.0)
	# ---- the street takes it ----
	var tail := car.root.global_transform * Vector3(0.0, 0.95, -2.2)
	var e := 0.35 * burn * near_ground + 2.6 * charge * charge
	for c: float in T_COUGH:      # the backfire lights the road behind it
		if tt > c and tt < c + 0.2:
			e += 1.6 * (1.0 - (tt - c) / 0.2)
	if go > 0.0:
		e = 22.0 * exp(-go / 0.16) + 2.4 * exp(-go / 0.9)
		tail = _c_go + Vector3(0.0, 0.6, 0.0)
	_light.position = tail
	_light.light_energy = e
	_light.light_color = CYAN.lerp(Color.WHITE, clampf(charge + (exp(-gp / 0.2) if go > 0.0 else 0.0), 0.0, 1.0) * 0.6)
	if on and phase != &"in":      # the street's lights dip as it draws its charge, and jump when it goes
		var dip := 1.0 - 0.16 * charge * (0.75 + 0.25 * sin(tt * 61.0) * sin(tt * 17.0))
		Game.view.post.exposure = _exposure * (dip + (0.35 * exp(-go / 0.09) if go > 0.0 else 0.0))
	_kerb(tt, go)
	if on and phase == &"shot" and not hold and dt > 0.0:
		_events(tt, go, h, burn)
	_scraps(dt if (on and phase != &"in" and not hold) else 0.0, tt)
	if on and phase != &"in":
		_camera(tt, go, centre)


## How the spare spins down: its tilt from flat (rad) and how far round it has gone (rad), `v` 0..1 through the spin. A dropped coin: flatter and faster to the end.
static func coin(v: float) -> Vector2:
	return Vector2(1.0 * pow(1.0 - v * v, 0.9), COIN_S * (5.0 * v + 15.0 * v * v * v))


## the door on the pavement and the spare propped on it: they tremble in the wash; when it goes the door is flung over (a flip and a half-turn, down flat nearer the club) and
## the spare is stood up on its rim, where it spins itself flat like a dropped coin
func _kerb(tt: float, go: float) -> void:
	var wash := _ss(T_LIFT, T_HOVER, tt) * (0.4 + 0.6 * _ss(T_CHARGE, T_GO, tt))
	if _door != null:
		var x := _door_a
		var long_axis := _door_a.basis.z.normalized()
		if go > 0.0:
			var u := clampf(go / 0.62, 0.0, 1.0)
			x = _door_a.interpolate_with(_door_b, u)
			long_axis = x.basis.z.normalized()
			x.basis = Basis(long_axis, TAU * u) * x.basis
			x.origin.y += 1.15 * sin(u * PI)
			if u >= 1.0:      # down: it rattles on its long edges and is still
				var r := 0.16 * exp(-(go - 0.62) * 3.0) * sin((go - 0.62) * 31.0)
				x.basis = Basis(long_axis, r) * x.basis
				x.origin.y += absf(sin(r)) * 0.24
		else:
			var r := 0.01 * wash * sin(tt * 47.0)
			x.basis = Basis(long_axis, r) * x.basis
			x.origin.y += absf(r) * 0.3
		_door.global_transform = x
	if _spare != null:
		var x := _spare_a
		if go > 0.0:
			var co := coin(clampf((tt - T_COIN) / COIN_S, 0.0, 1.0))
			var up_k := _ss(0.0, T_COIN - T_GO, go)      # thrown up off the door onto its rim
			var tilt := Basis(Vector3.UP, co.y) * Basis(Vector3.RIGHT, co.x * up_k) * Basis(Vector3.UP, -co.y)
			x = Transform3D(tilt * _spare_a.basis.slerp(_spare_b.basis, up_k), _spare_a.origin.lerp(_spare_b.origin, up_k))
			x.origin.y += 0.34 * sin(co.x * up_k) + 0.35 * sin(up_k * PI)
		else:
			x.basis = Basis(Vector3.RIGHT, 0.012 * wash * sin(tt * 39.0)) * x.basis
		_spare.global_transform = x


## the moments that throw something (FX pools: fx/fx.gd)
func _events(tt: float, go: float, h: float, burn: float) -> void:
	var fx: Variant = Game.fx
	if fx == null:
		return
	var axle := car.root.global_transform * _axle
	var pipe := car.root.global_transform * Vector3(0.0, 0.55, -2.15)
	var back := car.root.global_basis * Vector3(0.0, 0.25, -1.0)
	for c: float in T_COUGH:
		if _crossed(c):      # the bare axle spits, the tail backfires
			fx.sparks(axle, 16, 4.5, Vector3(0.0, 1.0, 0.0), 0xffc27a)
			fx.sparks(pipe, 12, 3.6, back, 0xffc27a)
			fx.dust(pipe + back * 0.4, 4, 1.3)
	if _crossed(T_LIFT):
		fx.sparks(axle, 22, 5.5, Vector3(0.0, 1.0, 0.0), 0xffc27a)
		fx.sparks(pipe, 18, 5.0, back, 0xbfe8ff)
		fx.dust(Vector3(HubRaceRig.AT.x, 0.08, HubRaceRig.AT.z), 10, 3.0)
	if tt > T_LIFT and go <= 0.0 and h < 3.0 and fmod(tt, 0.11) < fmod(_prev, 0.11):      # the wash: dust creeping out from under it
		var a := _rng.randf() * TAU
		fx.dust(Vector3(HubRaceRig.AT.x + cos(a) * 1.6, 0.08, HubRaceRig.AT.z + sin(a) * 2.2), 2, 1.4 + burn)
	if tt > T_CHARGE and go <= 0.0:      # the charge draws the light in: short streaks falling into the tail from a shell that closes
		var u := (tt - T_CHARGE) / (T_GO - T_CHARGE)
		var tail := car.root.global_transform * Vector3(0.0, 0.95, -2.3)
		for i in 3:
			var dir := Vector3(_rng.randf() - 0.5, _rng.randf() - 0.35, _rng.randf() - 0.5).normalized()
			var r := lerpf(7.5, 2.2, u) * _rng.randf_range(0.75, 1.15)
			fx.tracer(tail + dir * r, tail + dir * (r - lerpf(1.2, 2.0, u)), 0.018 + 0.012 * u, 0.1, 0x9fe6ff)
	if _crossed(T_GO):
		var g := Vector3(HubRaceRig.AT.x, 0.06, HubRaceRig.AT.z)
		fx.dust(g, 34, 7.5)
		fx.sparks(g + Vector3(0.0, 0.1, 0.0), 70, 10.0, null, 0x9fd4ff)      # the wet off the road
		fx.sparks(_c_go, 40, 16.0, -_d, 0xdff4ff)
		fx.ripple(g.x, g.y, g.z, 13.0, 0.75, 0.55)
		for i in SCRAPS:      # everything loose goes
			if _lstate[i] == 0:
				_lstate[i] = 1
				_lp[i].y = 0.1
			var out := Vector3(_lp[i].x - g.x, 0.0, _lp[i].z - g.z)
			var dist := maxf(out.length(), 0.4)
			out = out / dist
			var sp := _rng.randf_range(7.0, 17.0) / (1.0 + dist * 0.12)
			_lv[i] = out * sp + Vector3(0.0, _rng.randf_range(4.0, 11.0), 0.0)
			_lspin[i] = _rng.randf_range(9.0, 22.0)
			_lstate[i] = 1


## the litter: out from under it as it lifts, along the ground in its wash, then thrown
func _scraps(dt: float, tt: float) -> void:
	if dt <= 0.0:
		return
	var wash := _ss(T_LIFT, T_HOVER, tt) * (1.0 if tt < T_GO else 0.0)
	for i in SCRAPS:
		var st := _lstate[i]
		if st == 0:
			if tt < _lwake[i] or tt >= T_GO:
				continue
			var out := Vector3(_lp[i].x - HubRaceRig.AT.x, 0.0, _lp[i].z - HubRaceRig.AT.z).normalized()
			_lv[i] = out * _rng.randf_range(2.2, 5.0) + Vector3(0.0, _rng.randf_range(0.8, 2.4), 0.0)
			_lspin[i] = _rng.randf_range(5.0, 13.0)
			_lstate[i] = 1
			st = 1
		var p := _lp[i]
		var v := _lv[i]
		var floor_y := 0.17 if absf(p.x) > 4.2 else 0.02      # (the pavements stand a kerb above the road)
		if st == 1:
			v.y -= 3.4 * dt      # (paper: it is still coming down when the camera does)
			v *= exp(-1.25 * dt)
			v.x += sin(tt * 9.0 + i) * 1.6 * dt      # paper does not fall straight
			p += v * dt
			_lang[i] += _lspin[i] * dt
			if p.y <= floor_y:
				p.y = floor_y
				if absf(v.y) > 1.6:
					v.y = -v.y * 0.3
					v.x *= 0.6
					v.z *= 0.6
				else:
					v = Vector3(v.x, 0.0, v.z)
					_lstate[i] = 2
			if p.x < -7.3 and v.x < 0.0:      # the club's wall
				p.x = -7.3
				v.x = -v.x * 0.3
		else:      # lying: it creeps in the wash, and slides to a stop
			var sp := v.length()
			if wash > 0.0 and sp < 0.6:
				var out := Vector3(p.x - HubRaceRig.AT.x, 0.0, p.z - HubRaceRig.AT.z)
				v += out.normalized() * (1.8 * wash / (1.0 + out.length_squared() * 0.08)) * dt
			v *= exp(-3.5 * dt)
			p += v * dt
			_lang[i] += sp * 2.0 * dt
			if p.x < -7.3:
				p.x = -7.3
		_lp[i] = p
		_lv[i] = v
		var b := Basis(_lax[i], _lang[i]) if _lstate[i] == 1 else Basis(Vector3.UP, _lang[i]) * Basis(Vector3.RIGHT, -PI / 2.0)
		_mm.set_instance_transform(i, Transform3D(b, p))


## One place, turning only: it holds the rig low in the frame, tips up with it, whips up the line of light to where it went, holds on the twinkle, and comes back down to the kerb.
func _camera(tt: float, go: float, centre: Vector3) -> void:
	var target := centre + Vector3(0.0, 1.9 - 0.7 * _ss(T_LIFT, T_HOVER, tt), 0.0) + _d * (1.4 * _ss(T_TIP, T_GO, tt))
	if go > 0.0:
		var at_go := _c_go + Vector3(0.0, 1.2, 0.0) + _d * 1.4
		var sky := CAM + (_c_go + _d * (REACH * 0.62) - CAM).normalized() * 40.0      # a little under the far end: the twinkle sits high in the frame, the line running up to it
		target = at_go.lerp(sky, 1.0 - pow(1.0 - clampf(go / 0.5, 0.0, 1.0), 3.0))
		var down := _ss(T_DOWN - T_GO, T_DOWN - T_GO + DOWN_S, go)
		target = target.lerp(KERB, down * down * (3.0 - 2.0 * down))
	var dir := (target - CAM).normalized()
	var right := dir.cross(Vector3.UP).normalized()
	var upv := right.cross(dir)
	var a := 0.0025 * _ss(T_CHARGE, T_GO, tt) * (1.0 if go <= 0.0 else 0.0)
	if go > 0.0:
		a = 0.05 * exp(-go * 3.2)
	var n1 := sin(tt * 61.0) + 0.6 * sin(tt * 97.0 + 1.3)
	var n2 := sin(tt * 53.0 + 0.7) + 0.6 * sin(tt * 113.0 + 2.1)
	dir = (dir + right * n1 * a + upv * n2 * a).normalized()
	camera.pos = CAM
	camera.look = CAM + dir * 10.0
	camera.up = (Vector3.UP + right * sin(tt * 43.0) * a * 1.5).normalized()
	camera.fov = FOV + (5.0 * exp(-go * 4.5) if go > 0.0 else 0.0)
