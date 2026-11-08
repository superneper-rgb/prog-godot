class_name HubOffice
extends RefCounted
## The B-9 office on the alley (JS levels/hub/office-layout.js createOfficeAccess, office-operator.js, office-entry.js update, office-atmosphere.js, office-music.js, the live parts of office-view.js and office-tv-wall.js): the push button and its scanner that reads you top to toe, the two sliding door leaves, the interior that is only drawn when you can see it, the cigarette haze, the room's dimmed light, its music, the desk monitor, and the nineteen televisions on three low-rate CCTV feeds. The room itself comes with the level export; the people are in hub_office_actors.gd.

const X0 := 116.0
const X1 := 130.0
const Z0 := 326.2
const Z1 := 333.8
const Z := 330.0
const FLOOR := -10.0
const HEIGHT := 4.6
const BUTTON := Vector3(115.615, FLOOR + 1.1, 331.65)
# Cabinet centres: wall coordinate z, height y, width, height, depth, finish, channel (JS OFFICE_TVS, in the order of the "Vintage TV i" screens)
const TVS: Array[Array] = [[327.5, .56, 1.2, .95, .75, 0, 0], [328.9, .66, 1.5, 1.15, .86, 1, 1], [330.55, .70, 1.65, 1.28, .9, 0, 2], [332.2, .56, 1.35, .95, .75, 2, 3], [327.4, 1.50, 1.0, .78, .64, 2, 4], [328.65, 1.77, 1.35, 1.0, .75, 3, 0], [330.15, 1.87, 1.43, 1.05, .78, 1, 4], [331.7, 1.63, 1.25, .92, .7, 0, 2], [332.8, 1.40, .7, .65, .52, 3, 5], [327.3, 2.32, .82, .72, .58, 1, 1], [328.45, 2.84, 1.35, 1.0, .75, 0, 2], [330.0, 2.91, 1.3, .9, .72, 2, 0], [331.5, 2.68, 1.35, 1.05, .78, 0, 1], [332.75, 2.20, .92, .82, .58, 3, 4], [327.3, 3.05, .72, .64, .50, 3, 5], [328.5, 3.74, .95, .70, .6, 1, 3], [330.1, 3.72, .70, .62, .5, 3, 4], [331.5, 3.64, .98, .75, .62, 2, 0], [332.75, 2.97, .70, .62, .48, 1, 2]]
const TINTS: Array[int] = [0xbac4ba, 0xaaa18e, 0x99b7cd, 0xb2a997, 0xa1b7dd, 0x748073]
# The alley shot films from the lens of the camera hung on the B-9 front over the door.
const SHOTS: Array[Array] = [[Vector3(122, -7.95, 330.1), Vector3(120.1, -8.55, 328.3), 55.0, 45.0], [Vector3(115.2, -5.55, 327.35), Vector3(101, -9.3, 330.6), 65.0, 90.0], [Vector3(125, -7.4, 329.4), Vector3(118.7, -8.65, 331.4), 60.0, 45.0]]
const SCAN_T := 1.65
const WIDTHS: Array[float] = [.4, .46, .52]
const STRENGTHS: Array[float] = [.025, .008, .003]
const DX := -.94
const DY := -1.34
const L_ := .95
const F_ := .87

var L: ExportedLevel
var world: World
var door: World.Solid = null
# ---- createOfficeAccess ----
var state := "locked"
var elapsed := 0.0
var opening := 0.0
var from_inside := false
var button_depression := 0.0
# ---- createOfficeOperator ----
var op_phase := "idle"
var op_time := 0.0
var op_weight := 0.0
var stance := Vector3(115.48, FLOOR, BUTTON.z)
var facing := BUTTON
var pose := Player.FactoryInteraction.new()
# ---- createOfficeEntry update ----
var doors: Array[Node3D] = []
var arm: Node3D = null
var elbow: Node3D = null
var sensor: Node3D = null
var button: Node3D = null
var beam: MeshInstance3D = null
var line: MeshInstance3D = null
var _beam_mesh := ImmediateMesh.new()
var _line_mesh := ImmediateMesh.new()
var deploy := 0.0
var last_opening := -1.0
var last_button := -1.0
var rested := false
var bend := 0.0
var shoulder := 0.0
# ---- the room ----
var interior: Node3D = null
var hide_when_out: Array[Node3D] = []
var interior_on := true
# ---- atmosphere ----
var smoke: Array = []
var shafts: Node3D = null
var smoke_group: Node3D = null
var weight := 0.0
var key_level := 0.0
var base_hemi := 1.2
var base_sun := 0.62
var base_fill := 26.0
var fill: Light3D = null
var had_weight := false
# ---- monitors ----
var screen_ctl: Control = null
var screen_vp: SubViewport = null
var tick := -1
# ---- televisions ----
var tv_mats: Array[ShaderMaterial] = []
var feeds: Array[SubViewport] = []
var feed_frame := 0
var feed_last := -1
# ---- music ----
var music: AudioStreamPlayer = null
var music_inside := false
var actors: HubOfficeActors = null


func _one(nm: String) -> Node3D:
	var a: Array = L.node_named(nm)
	return (a[0] as Node3D) if not a.is_empty() else null


func _init(p_level: ExportedLevel) -> void:
	L = p_level
	world = L.world
	for s: World.Solid in world.solids:
		var ex: Variant = s.data.get("extra")      # (the exporter keeps a solid's JS id under extra)
		if ex is Dictionary and String(ex.get("id", "")) == "office/security-door":
			door = s
			break
	doors = [_one("B-9 sliding door -1"), _one("B-9 sliding door 1")]
	arm = _one("B-9 / articulated identity scanner")
	elbow = _one("B-9 scanner elbow")
	sensor = _one("scanner sensor")
	button = _one("B-9 physical push button")
	interior = _one("B-9 / occluded interior")
	var hide: Array[Node3D] = []
	for nm: String in ["B-9 / nineteen vintage television tubes", "B-9 / drifting cigarette haze", "B-9 / light shafts in suspended dust"]:
		var n := _one(nm)
		if n != null:
			hide.append(n)
	hide_when_out = hide
	bend = acos(clampf((DX * DX + DY * DY - L_ * L_ - F_ * F_) / (2.0 * L_ * F_), -1.0, 1.0))
	shoulder = atan2(DY, DX) - atan2(F_ * sin(bend), L_ + F_ * cos(bend))
	# the fan and the stripe (JS effectMat: additive, vertex coloured, both sides)
	var fx := StandardMaterial3D.new()
	fx.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fx.vertex_color_use_as_albedo = true
	fx.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fx.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fx.disable_fog = true
	fx.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam = MeshInstance3D.new()
	beam.name = "scanner laser fan"
	beam.mesh = _beam_mesh
	beam.material_override = fx
	beam.visible = false
	beam.extra_cull_margin = 16.0
	L.add_child(beam)
	line = MeshInstance3D.new()
	line.name = "scan line on subject"
	line.mesh = _line_mesh
	line.material_override = fx
	line.visible = false
	line.extra_cull_margin = 16.0
	L.add_child(line)
	pose.target = BUTTON
	_build_screens()
	_build_tvs()
	_build_atmosphere()
	music = AudioStreamPlayer.new()
	music.stream = (load("res://assets/sfx/office/blue-toned-mix.mp3") as AudioStreamMP3).duplicate()
	music.stream.loop = true
	music.bus = &"Music" if AudioServer.get_bus_index(&"Music") >= 0 else &"Master"
	music.volume_db = -80.0
	L.add_child(music)
	actors = HubOfficeActors.new(L, interior)
	# the push button (JS WORLD_ACTIONS)
	L.actions.append({"x": BUTTON.x, "z": BUTTON.z,
		"active": func(p: Variant) -> bool: return state != "open" and state != "closing" and (can_press(p) if state == "locked" or state == "closed" else in_range(p)),
		"label": func() -> String: return "PRESSING ACCESS BUTTON" if op_phase != "idle" else ("PRESS ACCESS BUTTON" if state == "locked" or state == "closed" else ("IDENTITY SCAN IN PROGRESS" if state == "scanning" else "ACCESS GRANTED / OPENING")),
		"run": func() -> void: request(Game.player)})


static func inside(p: Variant) -> bool:
	return p != null and p.x > X0 + .3 and p.x < X1 and p.z > Z0 and p.z < Z1 and p.y >= FLOOR - .5 and p.y < FLOOR + HEIGHT


# ---- createOfficeAccess ----
func in_range(p: Variant) -> bool:
	return not p.dead and absf(p.y - FLOOR) < 1.6 and p.x < X0 + .4 and U.hyp(p.x - (X0 - 1.4), p.z - Z) < 2.8


func press(p: Variant) -> bool:
	if not (state == "locked" or state == "closed") or not in_range(p):
		return false
	state = "scanning"
	elapsed = 0.0
	from_inside = false
	return true


func _access(dt: float, p: Variant) -> void:
	dt = clampf(dt, 0.0, .05)
	var at_door: bool = absf(p.y - FLOOR) < 2.0 and absf(p.z - Z) < 1.8
	var threshold: bool = at_door and absf(p.x - X0) < 1.1
	var exit_sensor: bool = at_door and p.x > X0 + .15 and p.x < X0 + 1.5
	# An interior approach always opens the exit, including a direct dev-console spawn.
	if (state == "locked" or state == "closed") and exit_sensor:
		state = "opening"
		elapsed = 0.0
		from_inside = true
	if state == "scanning":
		# The scan must finish with the subject still in front of the door.
		if not in_range(p):
			state = "locked"
			elapsed = 0.0
			return
		elapsed += dt
		if elapsed >= SCAN_T:
			state = "opening"
			elapsed = 0.0
	elif state == "opening":
		elapsed += dt
		opening = minf(1.0, opening + dt / .85)
		# Keep a conservative blocker until both leaves fully clear the passage.
		if opening >= 1.0:
			opening = 1.0
			if door != null:
				door.set_off(true)
			state = "open"
			elapsed = 0.0
	elif state == "open":
		elapsed += dt
		var passed: bool = p.x < X0 - 1.4 if from_inside else p.x > X0 + 2.0
		if not threshold and elapsed > .45 and (passed or elapsed > 5.0):
			state = "closing"
			elapsed = 0.0
	elif state == "closing":
		if threshold or exit_sensor:
			state = "opening"
			elapsed = 0.0
			from_inside = p.x > X0
		else:
			opening = maxf(0.0, opening - dt / .85)
			if opening == 0.0:
				if door != null:
					door.set_off(false)
				state = "closed"
				elapsed = 0.0


# ---- createOfficeOperator: feed the warehouse's existing Animator layer; the scan starts at button contact ----
func can_press(p: Variant) -> bool:
	return in_range(p) and absf(p.z - BUTTON.z) < .35 and absf(stance.x - p.x) < .8 and p.grounded and p.mode == &"normal"


func depression() -> float:
	return sin(PI * minf(1.0, op_time / .52)) * .035 if op_phase == "press" else 0.0


func request(p: Player) -> bool:
	if op_phase != "idle" or not (state == "locked" or state == "closed") or not can_press(p) or p.dead or not p.grounded or p.mode != &"normal":
		return false
	# Stay in the player's current lane: a short forward approach, never a sidestep.
	stance.z = p.z
	facing.z = p.z
	op_phase = "approach"
	op_time = 0.0
	return true


func _operator(dt: float, p: Player) -> void:
	if op_phase == "idle" and op_weight == 0.0:
		return
	var moving: bool = Inp.move.mag > .15 or Inp.btn(&"jump").pressed or Inp.btn(&"fire").held
	if op_phase != "idle" and (moving or p.dead or not p.grounded or p.mode != &"normal" or not in_range(p)):
		op_phase = "idle"
		op_time = 0.0
	if op_phase == "approach":
		op_time += dt
		if _approach(p, dt):
			op_phase = "press"
			op_time = 0.0
		elif op_time > 2.4:
			op_phase = "idle"
			op_time = 0.0
	elif op_phase == "press":
		var before := op_time
		op_time += dt
		if before < .26 and op_time >= .26:
			press(p)
		if op_time >= .52:
			op_phase = "idle"
			op_time = 0.0
	var active := op_phase != "idle"
	op_weight += ((1.0 if active else 0.0) - op_weight) * (1.0 - exp(-dt * (16.0 if active else 12.0)))
	if active or op_weight > .002:
		pose.active = active
		pose.weight = op_weight
		pose.target = Vector3(BUTTON.x + depression(), BUTTON.y, facing.z)
		pose.settle_vx = _settle.x if op_phase == "approach" else 0.0
		pose.settle_vz = _settle.y if op_phase == "approach" else 0.0
		p.factory_interaction = pose
	else:
		op_weight = 0.0
		if p.factory_interaction == pose:
			p.factory_interaction = null


var _settle := Vector2.ZERO


## JS control-approach.js with the default face: a short, collision-checked settling step
func _approach(P: Player, dt: float) -> bool:
	if P.dead or not P.grounded or P.mode != &"normal":
		return false
	var dx := stance.x - P.x
	var dz := stance.z - P.z
	if U.hyp(dx, dz) > 2.4:
		return false
	# Clear the projecting cabinet corner before sidestepping across its face. (face = {x: 0, z: 1})
	var n := dz
	var sx := 0.0 if absf(n) > .025 else dx
	var sz := n if absf(n) > .025 else dz
	var k := minf(1.0, dt * 3.0 / maxf(.001, U.hyp(sx, sz)))
	var x := P.x + sx * k
	var z := P.z + sz * k
	var y := world.ground_height(x, z, Config.radius, P.y + .42)
	_settle = Vector2.ZERO
	if not is_finite(y) or absf(y - P.y) > .35 or world.blocked(x, z, y, P.h, Config.radius, .1):
		return false
	_settle = Vector2((x - P.x) / dt if dt > 0.0 else 0.0, (z - P.z) / dt if dt > 0.0 else 0.0)
	P.x = x
	P.z = z
	P.y = y
	P.vx = 0.0
	P.vz = 0.0
	var yaw := atan2(facing.x - P.x, facing.z - P.z)
	var turn := atan2(sin(yaw - P.yaw), cos(yaw - P.yaw))
	P.yaw += turn * minf(1.0, dt * 16.0)
	return U.hyp(stance.x - P.x, stance.z - P.z) < .12 and absf(turn) < .18


# ---- createOfficeEntry update ----
func _ss(a: float, b: float, x: float) -> float:
	var q := clampf((x - a) / (b - a), 0.0, 1.0)
	return q * q * (3.0 - 2.0 * q)


func _damp(a: float, b: float, lam: float, dt: float) -> float:
	return lerpf(a, b, 1.0 - exp(-lam * dt))


func _entry(dt: float, p: Player) -> void:
	var scanning := state == "scanning"
	var u := minf(1.0, elapsed / SCAN_T)
	if last_opening != opening:
		var slide := _ss(0.0, 1.0, opening)
		for i in doors.size():
			if doors[i] != null:
				doors[i].position.z = Z + (1.0 if i != 0 else -1.0) * (.65 + slide * 1.4)
		last_opening = opening
	if last_button != button_depression:
		if button != null:
			button.position.x = BUTTON.x + button_depression
		last_button = button_depression
	if arm == null or elbow == null or (not scanning and rested):
		return
	var desired := _ss(0.0, .22, u) if scanning else 0.0
	deploy = _damp(deploy, desired, 22.0 if scanning else 9.0, dt)
	# Analytic two-link solve; eased joint angles prevent instant pose changes.
	arm.rotation.z = lerpf(-2.94, shoulder, deploy)
	elbow.rotation.z = lerpf(2.7, bend, deploy)
	arm.rotation.y = _damp(arm.rotation.y, clampf((p.z - Z) * .5, -.65, .65) if scanning else 0.0, 12.0, dt)
	var show_fx := scanning and u > .23 and u < .91
	beam.visible = show_fx
	line.visible = show_fx
	rested = not scanning and deploy < .001
	if rested:
		arm.rotation.z = -2.94
		elbow.rotation.z = 2.7
		if sensor != null:
			sensor.quaternion = Quaternion.IDENTITY
		return
	if sensor == null:
		return
	sensor.quaternion = Quaternion.IDENTITY
	var origin := sensor.global_position
	var h: float = p.h
	var scan := _ss(.24, .88, u)
	var y: float = p.y + h * (.94 - .89 * scan)
	var aim := Vector3(p.x, y, p.z)
	var dir: Vector3 = (aim - origin).normalized()
	var local := (sensor.get_parent() as Node3D).global_transform.basis.get_rotation_quaternion().inverse() * dir
	sensor.quaternion = Quaternion(Vector3(-1, 0, 0), local.normalized())
	if not show_fx:
		return
	origin = sensor.global_transform * Vector3(-.2, 0, 0)
	var fade := _ss(.23, .29, u) * (1.0 - _ss(.85, .91, u))
	var r: float = Config.radius
	# Attenuated structured-light fan: narrow central stripe and two faint fringes.
	_beam_mesh.clear_surfaces()
	_beam_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var width := WIDTHS[i] * r / .36
		var q := STRENGTHS[i] * fade
		var c0 := Color(.09 * q * .15, .8 * q * .15, q * .15)
		var c1 := Color(.09 * q, .8 * q, q)
		_beam_mesh.surface_set_color(c0)
		_beam_mesh.surface_add_vertex(origin)
		_beam_mesh.surface_set_color(c1)
		_beam_mesh.surface_add_vertex(Vector3(p.x - .08, y, p.z - width))
		_beam_mesh.surface_set_color(c1)
		_beam_mesh.surface_add_vertex(Vector3(p.x - .08, y, p.z + width))
	_beam_mesh.surface_end()
	# The contact stripe wraps the front of a body-sized capsule, with a soft edge.
	var body := r * (.62 if scan < .23 else (.73 if scan > .8 else 1.04))
	var segs := 12
	_line_mesh.clear_surfaces()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		for band in 2:
			for j in 6:
				var corner: int = [0, 1, 0, 1, 1, 0][j]
				var row: int = band + [0, 0, 1, 0, 1, 1][j]
				var a := -PI / 2.0 + (i + corner) / float(segs) * PI
				var q := (.95 if row == 1 else .015) * fade
				_line_mesh.surface_set_color(Color(.25 * q, .9 * q, q))
				_line_mesh.surface_add_vertex(Vector3(p.x - cos(a) * (body + .018), y + (row - 1) * .019, p.z + sin(a) * body))
	_line_mesh.surface_end()


# ---- the desk monitor: a canvas of four little screens, redrawn ten times a second ----
func _build_screens() -> void:
	var n := _one("B-9 screens")
	if n == null:
		return
	screen_ctl = Control.new()
	screen_ctl.size = Vector2(512, 512)
	screen_ctl.draw.connect(_draw_screens)
	screen_vp = SubViewport.new()
	screen_vp.size = Vector2i(512, 512)
	screen_vp.disable_3d = true
	screen_vp.transparent_bg = false
	screen_vp.gui_disable_input = true
	screen_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	screen_vp.add_child(screen_ctl)
	L.add_child(screen_vp)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = VendorStage._hex(0x96c3a0)
	m.albedo_texture = screen_vp.get_texture()
	for mi: MeshInstance3D in CityDriving._meshes(n):
		mi.material_override = m


func _draw_screens() -> void:
	var c := screen_ctl
	var t: float = c.get_meta(&"t", 0.0)
	var f := CrtTheme.font(&"mono")
	c.draw_rect(Rect2(0, 0, 512, 512), Color("#061b16"))
	var names: Array[String] = ["B-9 / CASE ARCHIVE", "SIGNAL ACQUISITION", "FOINT / SURVEILLANCE", "ANOMALY TELEMETRY"]
	for i in 4:
		var x := float(i % 2) * 256.0
		var y := float(i / 2) * 256.0
		c.draw_rect(Rect2(x + 9, y + 9, 238, 238), Color("#4d9870"), false, 1.0)
		c.draw_string(f, Vector2(x + 16, y + 30), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#8fcd91"))
		if i == 1 or i == 3:
			var pts := PackedVector2Array()
			for k in 220:
				pts.append(Vector2(x + 18 + k, y + 130 + sin(k * .075 + t * (i + 1)) * 28.0 + sin(k * .31 + t * 4.0) * 10.0))
			c.draw_polyline(pts, Color("#60c296"), 1.0)
		else:
			var tails: Array[String] = ["  TRACKING", "  RESTRICTED", "  NO CARRIER"]
			for j in 9:
				var col := Color("#b7e3a0") if j == int(t * 2.0) % 9 else Color("#438568")
				c.draw_string(f, Vector2(x + 18, y + 60 + j * 18), ("CAM " if i != 0 else "FILE ") + str(9210 + j * 13) + tails[j % 3], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		c.draw_string(f, Vector2(x + 18, y + 232), "REC  10.13.1993   %02d" % (int(t) % 60), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#92bb85"))
	var yy := 0
	while yy < 512:
		c.draw_rect(Rect2(0, yy, 512, 1), Color(0, 0, 0, .26))
		yy += 3
	c.draw_rect(Rect2(0, fmod(t * 38.0, 512.0), 512, 9), Color(167 / 255.0, 1.0, 196 / 255.0, .07))


# ---- the televisions: three shared low-frequency CCTV captures rather than nineteen full scene draws ----
func _build_tvs() -> void:
	var shader: Shader = load("res://levels/hub/office_tv.gdshader")
	for i in 3:
		var v := SubViewport.new()
		v.size = Vector2i(320, 240)
		v.world_3d = L.get_world_3d()
		v.render_target_update_mode = SubViewport.UPDATE_DISABLED
		v.positional_shadow_atlas_size = 0
		v.audio_listener_enable_3d = false
		v.gui_disable_input = true
		var cam := Camera3D.new()
		cam.fov = SHOTS[i][2]
		cam.near = .1
		cam.far = SHOTS[i][3]
		cam.position = SHOTS[i][0]
		v.add_child(cam)
		L.add_child(v)
		cam.look_at(SHOTS[i][1])
		cam.current = true
		feeds.append(v)
	for mode in 6:
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter(&"feed", feeds[mode % 3].get_texture())
		m.set_shader_parameter(&"mode", mode)
		var c := VendorStage._hex(TINTS[mode]).srgb_to_linear()
		m.set_shader_parameter(&"tint", Vector3(c.r, c.g, c.b))
		tv_mats.append(m)
	for i in TVS.size():
		for n: Node in L.node_named("Vintage TV %d / curved glass" % i):
			for mi: MeshInstance3D in CityDriving._meshes(n):
				_tube_uv(mi)
				mi.material_override = tv_mats[int(TVS[i][6])]


## (the exporter drops the UVs of a ShaderMaterial's mesh when the shader has no map: the tube's plane gives them back)
func _tube_uv(mi: MeshInstance3D) -> void:
	var src := mi.mesh as ArrayMesh
	if src == null:
		return
	var arr := src.surface_get_arrays(0)
	if arr[Mesh.ARRAY_TEX_UV] != null:
		return
	var box := mi.get_aabb()
	var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv := PackedVector2Array()
	uv.resize(pos.size())
	for i in pos.size():
		uv[i] = Vector2((pos[i].x - box.position.x) / box.size.x, 1.0 - (pos[i].y - box.position.y) / box.size.y)
	arr[Mesh.ARRAY_TEX_UV] = uv
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(src.surface_get_primitive_type(0), arr)
	mi.mesh = out


func _tvs(t: float, visible: bool) -> void:
	if not visible:
		return
	for m: ShaderMaterial in tv_mats:
		m.set_shader_parameter(&"time", t)
	if int(floor(t * 5.0)) == feed_last:
		return
	feed_last = int(floor(t * 5.0))
	feeds[feed_frame % 3].render_target_update_mode = SubViewport.UPDATE_ONCE
	feed_frame += 1


# ---- createOfficeAtmosphere ----
func _build_atmosphere() -> void:
	smoke_group = _one("B-9 / drifting cigarette haze")
	shafts = _one("B-9 / light shafts in suspended dust")
	if smoke_group != null:
		for c: Node in smoke_group.get_children():
			if c is Node3D:
				smoke.append({"s": c, "base": (c as Node3D).position, "phase": randf() * TAU})
	var v: Variant = Game.view
	base_hemi = v.hemi_intensity
	base_sun = v.sun_intensity
	if L.city != null and L.city.fill != null:
		fill = L.city.fill
		base_fill = fill.light_energy


## JS keyLight: runs every frame, frozen game or not: while an office cutscene plays, the camera's fill comes back as a soft key so faces read in close-ups (same light, so no new shader variant).
func key_light(dt: float, on: bool) -> void:
	key_level += ((1.0 if on else 0.0) - key_level) * (1.0 - exp(-3.0 * minf(.1, dt)))
	if fill != null:
		fill.light_energy = base_fill * (1.0 - weight) + 4.0 / PI * key_level * weight


func _atmosphere(t: float, dt: float, cam: Vector3, p: Variant, visible: bool) -> void:
	var q: Variant = p
	var target: float = _ss(114.8, 118.0, q.x) * (1.0 - _ss(129.5, 131.0, q.x)) * _ss(325.9, 327.0, q.z) * (1.0 - _ss(333.0, 334.1, q.z)) * (1.0 - _ss(-6.0, -4.0, q.y))
	weight += (target - weight) * (1.0 - exp(-4.0 * minf(.1, dt)))
	var v: Variant = Game.view
	if weight > .001 or had_weight:
		v.set_hemi(v.hemi_color, v.hemi_ground, base_hemi + (.28 - base_hemi) * weight)
		v.set_sun(v.sun_color, base_sun + (.035 - base_sun) * weight)
		if fill != null:      # Remove the camera's outdoor fill inside.
			fill.light_energy = base_fill * (1.0 - weight) + 4.0 / PI * key_level * weight
		had_weight = weight > .001
	if smoke_group != null:
		smoke_group.visible = visible
	if shafts != null:
		shafts.visible = visible
	if not visible:
		return
	for w: Dictionary in smoke:
		var s: Node3D = w.s
		var ph: float = w.phase
		var b: Vector3 = w.base
		s.position = b + Vector3(sin(t * .085 + ph) * .3, sin(t * .12 + ph) * .12, sin(t * .055 + ph) * .19)


func _music(dt: float, p: Variant, active: bool, duck: bool) -> void:
	var now := inside(p)
	if not now and music_inside:
		music.stop()
		music.volume_db = -80.0
	music_inside = now
	if not now or not active:
		if music.playing:
			music.stream_paused = true
		return
	if not music.playing:
		music.stream_paused = false
		music.play()
	music.stream_paused = false
	var v := db_to_linear(music.volume_db)
	v += ((.035 if duck else .10) - v) * (1.0 - exp(-3.0 * minf(.1, dt)))
	music.volume_db = linear_to_db(maxf(v, .0001))


## every frame the hub is played
func update(t: float, dt: float, p: Player, cam: Vector3, active: bool) -> void:
	_operator(dt, p)
	button_depression = depression()
	_access(dt, p)
	var cam_v := {"x": cam.x, "y": cam.y, "z": cam.z}
	var in_room := inside(p) or inside(cam_v)
	var door_vis := opening > 0.0 and U.hyp(cam.x - 116.0, cam.z - 330.0) < 35.0
	var vis := in_room or door_vis
	if interior != null and interior.visible != vis:
		interior.visible = vis
	_atmosphere(t, dt, cam, p, vis)
	if vis:
		actors.update(t, dt)
		if int(floor(t * 10.0)) != tick and screen_vp != null:
			tick = int(floor(t * 10.0))
			screen_ctl.set_meta(&"t", t)
			screen_ctl.queue_redraw()
			screen_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_tvs(t, in_room)
	_entry(dt, p)
	var cine: bool = L.call(&"office_cine")      # (ducked under the office cutscenes)
	_music(Game.frame_real_dt if cine else dt, p, active or cine, cine)
