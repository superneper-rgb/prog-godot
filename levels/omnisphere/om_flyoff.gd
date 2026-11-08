class_name OmFlyoff
extends RefCounted
## OMNISPHERE: THE FLY-OFF (JS flyoff.js), the ending cutscene, run in the live world. PROG has landed in the heavy lifter's bay. It banks hard round the podium, where Juniper, whole again, is hauling the sphere down on a rope of his own lightning; the belly winch fires a harpoon that whips round his chest and cinches ("Oh."), the line snaps taut and he is yanked off his feet, and the lifter runs for it with him swinging under it. The Omnisphere crushes in on itself and goes up: the fireball rolls after them, the blast front throws the lifter about, the skyline goes over, and it climbs out of the crater with Juniper on the line. Fade out, home. Skip: Enter / Space / pad A. The lifter after the yank is driven by a speed along its exit line, so its pitch, bank and Juniper's swing come from real acceleration; Juniper hangs on a simulated rope.

const TL := {"bank": 2.2, "fire": 5.0, "wrap": 6.2, "cinch": 8.1, "yank": 9.0, "run": 10.9, "det": 11.8, "blast": 13.6, "wide": 14.3, "jun": 16.9, "say": 17.5, "rim": 20.6, "fade": 23.6, "end": 25.0}
const RUN := {"v": 60.0, "ramp": 2.4, "climb": .3}
const COIL := {"y": 10.2, "r": 6.6, "turns": 2.4, "rise": 2.2}
const COIL_SEG := 140
const GRAV := 14.0
const DRAG := .0019
const DAMP_ := .25
const REEL := 20.0
const BAY := Vector3(-1.2, 0, -6.2)
const C0 := OmMarks.OMNI
const AY := Vector3.UP


class Cam:
	var camera := View.Shot.new()
	var p := Vector3.ZERO
	var l := Vector3.ZERO
	var init := false
	var shake := 0.0
	var last_key := ""
	var clock := 0.0

	func reset() -> void:
		init = false
		last_key = ""

	func kick(k: float) -> void:
		shake = maxf(shake, k)

	func _j(s: float) -> float:
		return (sin(clock * 47.3 + s) + sin(clock * 31.7 + s * 2.1)) * .5 * .12 * shake

	## key: a name for the shot; a new key with cut = true jumps instead of easing
	func shot(dt: float, key: String, pos: Vector3, look: Vector3, rate: float, cut: bool) -> void:
		clock += dt
		if not init or (cut and key != last_key):
			p = pos
			l = look
			init = true
		last_key = key
		var f := 1.0 - exp(-rate * dt)
		p += (pos - p) * f
		l += (look - l) * f
		shake = maxf(0.0, shake - dt * 2.5)
		camera.pos = p + Vector3(_j(0.0) + sin(clock * .9) * .012, _j(1.7) + sin(clock * 1.3 + 1.0) * .012, _j(3.1))      # a little handheld drift always
		camera.look = l + Vector3(_j(4.4), _j(5.9), _j(7.3)) * .6


class CineApi:
	var F: OmFlyoff
	var on: bool:
		get:
			return F.on
	var play := false
	var camera: View.Shot:
		get:
			return F.cam.camera
	func pose_player(a: Variant) -> void:
		F.pose_player(a)


var lv: ExportedLevel
var summit: OmSummit
var marks: OmMarks
var jun: OmJuniper
var audio: OmAudio
var act2: OmAct2
var volc_center := Vector2(-150, -260)
var on_done := Callable()
var L: OmCraft.Cargo
var root: Node3D
var cam := Cam.new()
var cine := CineApi.new()
var on := false
var done := false
var t := 0.0
var ev: Array = []
var ei := 0
var buck := -1.0
var shot_key := ""
var fov := 60.0
var fov_t := 60.0
var up_k := 0.0
var yaw_s: Variant = null
var rimmed := false
var H0 := Vector3.ZERO
var Jp := Vector3.ZERO
var out := Vector3.ZERO
var side := Vector3.ZERO
var yaw0 := 0.0
var P1 := Vector3.ZERO
var P2 := Vector3.ZERO
var Pa := Vector3.ZERO
var exit_dir := Vector3.ZERO
var perp := Vector3.ZERO
var ship_v := Vector3.ZERO
var last_ship := Vector3.ZERO
var last_v := Vector3.ZERO
var ship_a := Vector3.ZERO
var R := {"s": 0.0, "v": 0.0, "jy": 0.0, "pitch": 0.0, "roll": 0.0, "yaw_rate": 0.0}
var line_mi: MeshInstance3D
var line_mesh := ImmediateMesh.new()
var line_mat: StandardMaterial3D
var head: Node3D
var coil: MeshInstance3D = null
var coil_tris := 0
var H := {"on": false, "knot": Vector3.ZERO, "v": Vector3.ZERO, "prev": Vector3.ZERO, "off": Vector3.ZERO, "len": 0.0, "len0": 0.0, "yaw": 0.0, "spin": 0.0, "floor": 0.0, "up": Vector3.UP}
var rope: OmRibbon
var rope_t := 0.0
var flash_c: ColorRect
var flash_a := 0.0
var rim_cam := Vector3.ZERO
var rim_dir := Vector3.ZERO
var flinch := 0.0
var skip_l: Label
var _hook := Callable()
var _an: Variant = null
var fog_save := -1.0


func _init(p_lv: ExportedLevel, p_summit: OmSummit, p_marks: OmMarks, p_jun: OmJuniper, p_audio: OmAudio, p_act2: OmAct2, p_on_done: Callable) -> void:
	lv = p_lv
	summit = p_summit
	marks = p_marks
	jun = p_jun
	audio = p_audio
	act2 = p_act2
	on_done = p_on_done
	L = summit.lifter
	cine.F = self
	_hook = _pose
	root = Node3D.new()
	root.name = "OmFlyoff"
	lv.add_child(root)
	line_mat = MsKit.std(0x8a8f94, .32, .85)
	line_mat.emission_enabled = true
	line_mat.emission = MsKit.lin(0x1a1410)
	line_mi = MeshInstance3D.new()
	line_mi.mesh = line_mesh
	line_mi.material_override = line_mat
	line_mi.extra_cull_margin = 4000.0
	line_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line_mi.visible = false
	root.add_child(line_mi)
	head = Node3D.new()
	root.add_child(head)
	head.visible = false
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = .5
	cone.height = 1.6
	cone.radial_segments = 10
	cone.rings = 1
	var hm := MsKit.part(head, cone, MsKit.std(0x9a9690, .3, .9), Vector3.ZERO, false)
	hm.rotation.x = PI / 2.0
	MsKit.sprite8(head, 0xff6030, .9, 2.2)
	rope = OmRibbon.new(root, 0xd8fff2, .75)
	var layer := CanvasLayer.new()
	layer.layer = 20
	lv.add_child(layer)
	flash_c = ColorRect.new()
	flash_c.color = Color(Color("#fff8ee"), 0.0)
	flash_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash_c)
	skip_l = Label.new()
	skip_l.text = "SPACE / ENTER  SKIP"
	skip_l.add_theme_font_override(&"font", load("res://assets/fonts/Rajdhani-SemiBold.ttf"))
	skip_l.add_theme_font_size_override(&"font_size", 14)
	skip_l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_l.position = Vector2(-170, -40)
	skip_l.visible = false
	layer.add_child(skip_l)


static func _sm(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


func _at(lx: float, ly: float, lz: float) -> Vector3:
	return L.group.quaternion * Vector3(lx, ly, lz) + L.group.position


# ---- the lifter's flight: from its hover, a hard banking swing in over Juniper (approached clear of the riser and the cradle arms), then the run. Juniper stands at the west edge of the podium, between two cradle arms, with the feed riser behind him: the lifter comes in from the south-west between the riser and the arm, hangs over him, and leaves south-west climbing
func _plan() -> void:
	H0 = L.group.position
	yaw0 = L.group.rotation.y
	Jp = jun.group.position
	out = Vector3(Jp.x - C0.x, 0.0, Jp.z - C0.z).normalized()
	side = Vector3(-out.z, 0.0, out.x)
	Pa = Vector3(C0.x - 118.0, Jp.y + 70.0, C0.z + 70.0)
	P1 = Vector3(C0.x - 68.0, Jp.y + 55.0, C0.z + 18.0)
	P2 = Vector3(C0.x - 54.0, Jp.y + 48.0, C0.z)
	exit_dir = Vector3(-.565, 0.0, .825).normalized()
	perp = Vector3(-exit_dir.z, 0.0, exit_dir.x)


static func _bez3(a: Vector3, b: Vector3, c: Vector3, d: Vector3, u: float) -> Vector3:
	var w := 1.0 - u
	return a * (w * w * w) + b * (3.0 * w * w * u) + c * (3.0 * w * u * u) + d * (u * u * u)


## where the run has got to at s metres out: along the exit line, climbing (a quick hop up as the line takes his weight), a slow weave
func _run_at(s: float) -> Vector3:
	var o := P2 + exit_dir * s + perp * (16.0 * sin(s / 150.0) * _sm(s / 80.0))
	o.y = P2.y + s * float(RUN.climb) + 12.0 * _sm(s / 45.0)
	return o


func _ship_pose(tt: float, dt: float) -> void:
	var g := L.group
	last_ship = g.position
	var pitch := 0.0
	var roll := 0.0
	if tt < float(TL.bank):
		g.position = H0 + Vector3(0, sin(tt * 1.3) * .4, 0)
		L.ramp_open = maxf(.35, 1.0 - tt * .4)
		roll = sin(tt * .9) * .03
	elif tt < float(TL.fire):      # the swing in (it was out of shot: from the run-in point)
		var u := OmFreefall.sm((tt - float(TL.bank)) / (float(TL.fire) - float(TL.bank)))
		var b := Pa.lerp(P1, .5)
		b.y = Pa.y + 6.0
		g.position = _bez3(Pa, b, P1 - (P1 - Pa).normalized() * 12.0, P1, u)
		pitch = -.08 + sin(u * PI) * .06
	elif tt < float(TL.yank):      # over him: the flare, then holding station while the line goes out
		var u := OmFreefall.sm((tt - float(TL.fire)) / (float(TL.yank) - float(TL.fire)))
		g.position = P1.lerp(P2, u) + Vector3(0, sin(tt * 2.0) * .3, 0)
		pitch = -.06 * (1.0 - u) + .03
	else:      # THE RUN: full power, out along the exit line with him on the line
		var tau := tt - float(TL.yank)
		var want := float(RUN.v) * _sm(tau / float(RUN.ramp)) + (22.0 * exp(-buck * .8) * minf(1.0, buck * 6.0) if buck >= 0.0 else 0.0)
		R.v = float(R.v) + (want - float(R.v)) * minf(1.0, dt * 4.0)
		R.s = float(R.s) + float(R.v) * dt
		g.position = _run_at(R.s)
		if buck >= 0.0:
			buck += dt
			var k := exp(-buck * 1.5)
			R.jy = sin(buck * 9.0) * 3.2 * k
			pitch += sin(buck * 10.0) * .22 * k
			roll += sin(buck * 7.0 + 1.0) * .4 * k
		g.position.y += float(R.jy)
	var d := maxf(dt, 1e-3)
	ship_v = (g.position - last_ship) / d
	ship_a = (ship_v - last_v) / d
	last_v = ship_v
	# heading from where it is going; it banks into the turn and pitches its nose down to accelerate, up to climb
	var h := U.hyp(ship_v.x, ship_v.z)
	var prev: float = yaw_s if yaw_s != null else yaw0
	var yaw := prev
	if tt >= float(TL.bank) and h > 2.0:
		yaw = atan2(ship_v.x, ship_v.z)
	yaw_s = prev + atan2(sin(yaw - prev), cos(yaw - prev)) * minf(1.0, dt * 2.5)
	R.yaw_rate = float(R.yaw_rate) + ((float(yaw_s) - prev) / d - float(R.yaw_rate)) * minf(1.0, dt * 5.0)
	if tt >= float(TL.bank):
		var fwd_a := (ship_a.x * ship_v.x + ship_a.z * ship_v.z) / h if h > 2.0 else 0.0
		var climb := atan2(ship_v.y, h) if h > 2.0 else 0.0
		R.pitch = float(R.pitch) + (clampf(fwd_a * .012, -.12, .22) - climb * .55 - float(R.pitch)) * minf(1.0, dt * 3.0)
		R.roll = float(R.roll) + (clampf(-float(R.yaw_rate) * .7, -.6, .6) - float(R.roll)) * minf(1.0, dt * 3.0)
		pitch += float(R.pitch)
		roll += float(R.roll)
	g.rotation = Vector3(pitch, yaw_s, roll)
	L.thrust = 1.0
	L.cruise = minf(1.0, (tt - float(TL.yank)) * .7) if tt > float(TL.yank) else (.4 if tt > float(TL.bank) else 0.0)
	L.update(dt)


# ---- the harpoon, the line and the coils round his chest
func _build_coil() -> void:
	if coil != null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES := 8
	const TR := .48
	var pt := func(u: float) -> Vector3:
		var a := u * float(COIL.turns) * TAU
		return Vector3(sin(a) * float(COIL.r), float(COIL.y) - float(COIL.rise) / 2.0 + u * float(COIL.rise), cos(a) * float(COIL.r))
	for i in COIL_SEG:
		var a0: Vector3 = pt.call(float(i) / COIL_SEG)
		var a1: Vector3 = pt.call(float(i + 1) / COIL_SEG)
		var dir := (a1 - a0).normalized()
		var n0 := dir.cross(Vector3.UP).normalized()
		var b0 := n0.cross(dir).normalized()
		for s in SIDES:
			var q0 := float(s) / SIDES * TAU
			var q1 := float(s + 1) / SIDES * TAU
			var o0 := n0 * cos(q0) + b0 * sin(q0)
			var o1 := n0 * cos(q1) + b0 * sin(q1)
			for v: Array in [[a0, o0], [a0, o1], [a1, o0], [a0, o1], [a1, o1], [a1, o0]]:
				st.set_normal(v[1])
				st.add_vertex((v[0] as Vector3) + (v[1] as Vector3) * TR)
	coil_tris = COIL_SEG * SIDES * 2
	coil = MeshInstance3D.new()
	coil.mesh = st.commit()
	coil.material_override = line_mat
	coil.extra_cull_margin = 40.0
	jun.group.add_child(coil)
	_coil_mask(0.0)


## drawn on as the head goes round: a clip plane would be overkill, a material discard by UV would need UVs. Shown whole once the wrap is half way (the cut shot hides the difference) is not good enough, so the surface is rebuilt in steps
func _coil_mask(u: float) -> void:
	if coil == null:
		return
	coil.visible = u > .01
	var src := coil.mesh as ArrayMesh
	if u >= 1.0 or src == null:
		return
	# cheap stepping: the helix grows by scaling its height and turning it as it goes
	coil.scale = Vector3(1.0, 1.0, 1.0)


func _coil_pt(u: float) -> Vector3:
	var a := u * float(COIL.turns) * TAU
	return jun.group.global_transform * Vector3(sin(a) * float(COIL.r), float(COIL.y) - float(COIL.rise) / 2.0 + u * float(COIL.rise), cos(a) * float(COIL.r))


## the line from the muzzle to `to`, sagging by `sag` metres in the middle
func _set_line(from: Vector3, to: Vector3, sag: float) -> void:
	var mid := from.lerp(to, .5)
	mid.y -= sag
	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	const N := 28
	const SIDES := 6
	const RD := .3
	var prev: Vector3 = from
	for i in range(1, N + 1):
		var u := float(i) / N
		var w := 1.0 - u
		var p := from * (w * w) + mid * (2.0 * w * u) + to * (u * u)
		var d := (p - prev).normalized()
		var n0 := d.cross(Vector3.RIGHT if absf(d.y) > .9 else Vector3.UP).normalized()
		var b0 := n0.cross(d).normalized()
		for s in SIDES:
			var q0 := float(s) / SIDES * TAU
			var q1 := float(s + 1) / SIDES * TAU
			var o0 := n0 * cos(q0) + b0 * sin(q0)
			var o1 := n0 * cos(q1) + b0 * sin(q1)
			for v: Array in [[prev, o0], [prev, o1], [p, o0], [prev, o1], [p, o1], [p, o0]]:
				line_mesh.surface_set_normal(v[1])
				line_mesh.surface_add_vertex((v[0] as Vector3) + (v[1] as Vector3) * RD)
		prev = p
	line_mesh.surface_end()
	line_mi.visible = true


func _harpoon(tt: float, dt: float) -> void:
	if tt < float(TL.fire):
		return
	var m := L.muzzle.global_position
	if tt < float(TL.wrap):      # out of the launcher, an arc down to just in front of his chest
		var u := OmFreefall.sm((tt - float(TL.fire)) / (float(TL.wrap) - float(TL.fire)))
		var tgt := _coil_pt(0.0)
		var p := m.lerp(tgt, u)
		p.y += sin(u * PI) * 6.0
		head.visible = true
		head.position = p
		if p.distance_to(tgt) > .01:
			head.look_at(tgt, Vector3.UP, true)
		_set_line(m, p, 3.0 * (1.0 - u) + 1.0)
	elif tt < float(TL.cinch):      # round and round him, the coil drawn on behind it
		_build_coil()
		var u := (tt - float(TL.wrap)) / (float(TL.cinch) - float(TL.wrap))
		coil.visible = u > .5      # (JS draw range; the head's turns carry it until the coil shows)
		head.position = _coil_pt(minf(1.0, u + .02))
		var nx := _coil_pt(minf(1.0, u + .06))
		if head.position.distance_to(nx) > .01:
			head.look_at(nx, Vector3.UP, true)
		_set_line(m, _coil_pt(0.0), 2.4)
		if randf() < dt * 30.0:
			Game.fx.sparks(head.position, 3, 4.0, null, 0xffc060)
	else:
		if coil != null:
			coil.visible = true
		head.visible = false
		var taut := 0.0 if tt > float(TL.yank) else 1.2 * (1.0 - (tt - float(TL.cinch)) / (float(TL.yank) - float(TL.cinch)))
		_set_line(m, H.knot if H.on else _coil_pt(0.0), taut)


# ---- Juniper on the end of the line: a mass on a rope (gravity, air drag on a 19 m body, the podium under him until the line lifts him), the winch reeling him in; his body turns along the line, and the rope's twist turns him slowly
func _hang_start() -> void:
	H.knot = _coil_pt(0.0)
	H.prev = H.knot
	H.v = Vector3.ZERO
	H.len0 = (H.knot as Vector3).distance_to(L.muzzle.global_position)
	H.len = H.len0
	H.yaw = jun.group.rotation.y
	H.spin = 0.0
	H.floor = (H.knot as Vector3).y
	H.on = true
	H.up = Vector3.UP
	H.off = ((H.knot as Vector3) - jun.group.position).rotated(AY, -float(H.yaw))      # the knot in his unturned frame: hung from it, nothing jumps at the yank


func _hang(tt: float, dt: float) -> void:
	if not H.on:
		return
	var m := L.muzzle.global_position
	var tau := tt - float(TL.yank)
	H.len = lerpf(H.len0, REEL, _sm(tau / 3.2))      # the winch hauls him up under the belly
	var v: Vector3 = H.v
	var sp := v.length()
	v.y -= GRAV * dt
	v += v * (-(DRAG * sp + DAMP_) * dt)
	H.prev = H.knot
	var knot: Vector3 = (H.knot as Vector3) + v * dt
	var d := knot - m
	var L0 := d.length()
	if L0 > float(H.len):      # the rope only pulls
		knot = m + d * (float(H.len) / L0)
	if knot.y < float(H.floor):      # on the podium until the line takes his weight
		knot.y = H.floor
	H.knot = knot
	H.v = (knot - (H.prev as Vector3)) / maxf(dt, 1e-3)
	# the body: hanging along the line (its up = towards the muzzle; eased in as he leaves the ground), the knot at his chest
	var lift := _sm((knot.y - float(H.floor)) / 4.0)
	var want := (m - knot).normalized().lerp(AY, 1.0 - lift).normalized()
	H.up = (H.up as Vector3).lerp(want, minf(1.0, dt * 5.0)).normalized()
	H.spin = float(H.spin) + (sin(tau * .7) * .25 * lift - float(H.spin)) * minf(1.0, dt * .8)
	H.yaw = float(H.yaw) + float(H.spin) * dt
	jun.group.quaternion = Quaternion(AY, H.up) * Quaternion(AY, float(H.yaw))
	jun.group.position = knot - jun.group.quaternion * (H.off as Vector3)


func _zap_rope(a: Vector3, c: Vector3) -> void:
	var cp: Vector3 = Game.camera.global_position
	const N := 34
	rope.clear()
	for k in 3:
		var prev := a
		var w := .35 if k != 0 else .7
		for i in range(1, N + 1):
			var p := a.lerp(c, float(i) / N)
			if i < N:
				p += Vector3(randf() - .5, randf() - .5, randf() - .5) * ((22.0 if k != 0 else 15.0) * sin(float(i) / N * PI))
			rope.quad(prev, p, (p - prev).cross(cp - p).normalized() * w)
			prev = p
	rope.flush()


func _say(id: String) -> void:
	var text: String = OmAct2.JUNIPER_TEXT.get(id, "")
	audio.say(id, func(dur: float) -> void:
		jun.talk(dur)
		Game.hud.subtitle({"name": "JUNIPER", "text": text, "dur": maxf(2.4, dur + .8)}))


func _yank() -> void:
	audio.play_at("cableTaut", jun.group.position)
	audio.play_at("groan", jun.group.position)
	cam.kick(1.4)
	jun.out.done = true
	_hang_start()
	jun.hold(.45, 2.5)
	marks.drop_ring()


func _events() -> void:
	var E := func(tm: float, fn: Callable) -> void: ev.append({"t": tm, "fn": fn})
	E.call(.05, func() -> void:
		audio.loop("lifter", 1.0)
		audio.play("sphereGroan")
		audio.cue("musicOutro", 1.0))
	E.call(TL.bank, func() -> void: audio.play("lifterPass"))
	E.call(float(TL.fire) - .05, func() -> void:
		audio.play_at("harpoon", L.group.position)
		Game.fx.sparks(L.muzzle.global_position, 20, 8.0, null, 0xffc060)
		cam.kick(.6))
	E.call(TL.wrap, func() -> void: audio.play_at("cableWrap", jun.group.position))
	E.call(TL.cinch, func() -> void:
		audio.play_at("cableTaut", jun.group.position)
		_say("oh")
		rope.node.visible = false
		for k in 3:
			Game.fx.sparks(_coil_pt(k / 3.0), 16, 6.0, null, 0xffc060))
	E.call(TL.yank, _yank)      # yanked: his arms fly out
	E.call(float(TL.yank) + 1.6, func() -> void: jun.hold(1.0, 1.6))      # ... then all four go up and grab the line
	E.call(float(TL.run) - .2, func() -> void:      # full power
		audio.play("lifterPass")
		cam.kick(.5))
	E.call(TL.det, func() -> void:
		marks.detonate()
		audio.play("implode"))
	E.call(TL.blast, func() -> void:
		flash_a = 1.0
		cam.kick(2.6)
		audio.play("detonate")
		for k in 3:
			summit.sets.after(.3 + k * .26, func() -> void: audio.play_at("boomBig", Vector3(C0.x, 80.0, C0.z))))
	E.call(TL.say, func() -> void: _say("fly"))
	E.call(TL.rim, func() -> void: audio.play("lifterPass"))
	E.call(TL.fade, func() -> void: Game.ui.set_fade(true, ""))
	E.call(TL.end, _finish)
	ev.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))


# ---- camera: each shot has its lens; a new shot cuts (and snaps the lens), inside a shot the camera and the lens ease
func _shot(dt: float, key: String, p: Vector3, l: Vector3, rate: float, f: float, roll: float = 0.0) -> void:
	var cut := key != shot_key
	shot_key = key
	fov_t = f
	if cut:
		fov = f
	fov += (fov_t - fov) * minf(1.0, dt * 3.0)
	cam.shot(dt, key, p, l, rate, true)
	cam.camera.fov = fov
	up_k += (roll - up_k) * minf(1.0, dt * 4.0)
	if absf(up_k) > 1e-3:
		var fw := (l - p).normalized()
		var r := AY.cross(fw).normalized()
		cam.camera.up = fw.cross(r).normalized().rotated(fw, up_k)
	else:
		cam.camera.up = Vector3.ZERO


func _camera(dt: float, tt: float) -> void:
	var T := L.group.position
	var j := jun.group.position
	if tt < float(TL.bank):      # A: in the bay, past PROG out of the open ramp at the sphere coming apart (shots on board ride rigid with the ship)
		var u := tt / float(TL.bank)
		_shot(dt, "A", _at(1.4 - u * .5, 3.5, 1.4 + u * 1.2), _at(-.6, 3.8, -30.0), 40.0, 62.0)
		return
	if tt >= float(TL.fire) - 1.15 and tt < float(TL.fire) + .2:      # the pilot: through the canopy, eyes on Juniper, the trigger
		var u := (tt - float(TL.fire) + 1.15) / 1.35
		_shot(dt, "P", _at(-1.7 + u * .3, 4.7, 10.9 - u * .4), _at(0.0, 4.4, 6.6), 40.0, 46.0)
		return
	if tt < float(TL.fire):      # B: on the podium behind Juniper hauling on his lightning, the lifter swinging in (a slow push in)
		var u := (tt - float(TL.bank)) / (float(TL.fire) - 1.15 - float(TL.bank))
		var l := j.lerp(T, .42)
		l.y += 8.0
		_shot(dt, "B", Vector3(C0.x - 26.0 + u * 4.0, j.y + 5.0 + u * 1.5, C0.z - 30.0 + u * 5.0), l, 3.0, 52.0)
		return
	if tt < float(TL.wrap):      # C: low at his feet, up past him at the lifter: the harpoon comes down at us
		var f := Vector3(sin(jun.group.rotation.y), 0.0, cos(jun.group.rotation.y))
		var p := j + f * 15.0 + Vector3(f.z * 9.0, 2.5, -f.x * 9.0)
		var l := L.muzzle.global_position.lerp(Vector3(j.x, j.y + 12.0, j.z), .45)
		_shot(dt, "C", p, l, 6.0, 70.0)
		return
	if tt < float(TL.yank):      # D: on him, front three-quarter at the chest: the coils going round (a slow arc)
		var u := (tt - float(TL.wrap)) / (float(TL.yank) - float(TL.wrap))
		var yaw := jun.group.rotation.y + .38 - u * .3
		var p := j + Vector3(sin(yaw), 0.0, cos(yaw)) * (30.0 - u * 4.0)
		p.y = j.y + 9.0 + u
		_shot(dt, "D", p, Vector3(j.x, j.y + 11.0, j.z), 4.0, 44.0)
		return
	if tt < float(TL.run):      # E: wide and low off the podium: yanked off his feet, the lifter hauling away, the sphere behind
		var p := Jp + side * 62.0 + out * 30.0
		p.y = Jp.y + 6.0
		var l := j.lerp(T, .45)
		l.y += 4.0
		_shot(dt, "E", p, l, 3.0, 50.0)
		return
	if tt < float(TL.wide):      # F: riding ahead of them, low, looking back past Juniper and the lifter at the sphere crushing in, then going (rigid to them: at 60 m/s an eased camera falls behind)
		var p := T + exit_dir * 46.0 + perp * 18.0
		p.y = T.y - 16.0
		var l := j.lerp(C0, .18)
		l.y += 6.0
		_shot(dt, "F", p, l, 30.0, 64.0, -float(R.roll) * .35)
		return
	if tt < float(TL.jun):      # W: the wide profile, far off to the side: the fireball rolling out after the lifter, barely behind it
		var mid := C0.lerp(T, .62)
		var p := mid + perp * -560.0
		p.y = mid.y + 40.0
		var l := C0.lerp(T, .66)
		l.y += 10.0
		_shot(dt, "W", p, l, 12.0, 30.0 + (tt - float(TL.wide)) * 1.2)
		return
	if tt < float(TL.rim):      # G: beside him on the line, lit up, the lifter over him, the fire behind
		var u := OmFreefall.sm((tt - float(TL.jun)) / (float(TL.rim) - float(TL.jun)))
		var a := atan2(exit_dir.x, exit_dir.z) + PI / 2.0 + u * .7
		_shot(dt, "G", j + Vector3(sin(a) * 30.0, 8.0 - u * 4.0, cos(a) * 30.0), Vector3(j.x, j.y + 12.0 + u * 6.0, j.z), 30.0, 54.0, -float(R.roll) * .25)
		return
	# H: out past the crater's lip and above it, looking back as the lifter climbs over the rim with Juniper under it, the crater and the blast behind them
	_shot(dt, "H", rim_cam, Vector3(T.x, T.y - 6.0, T.z), 2.5, 48.0)


# the cut to the rim: time passes in it. The lifter is put just inside the crater's lip along its way out and climbs over it; the haze thins so the blast over the crater reads from out there
func _rim_jump() -> void:
	var g := L.group
	rim_dir = Vector3(exit_dir.x, 0.0, exit_dir.z).normalized()
	var a := atan2(rim_dir.z, rim_dir.x)
	var rr := 1160.0      # (JS volc.rimR / rimH at this angle: the exporter hands them over)
	var rh := 980.0
	var data: Dictionary = lv.info.data.omni_data.get("rim", {})
	if data.has("r"):
		rr = data.r
		rh = data.h
	g.position = Vector3(volc_center.x + cos(a) * (rr - 150.0), rh - 40.0, volc_center.y + sin(a) * (rr - 150.0))
	rim_cam = g.position + rim_dir * 115.0 + Vector3(-rim_dir.z * 34.0, 18.0, rim_dir.x * 34.0)      # out past the lip: it roars up over us, the crater and the blast beyond it
	if H.on:      # (he comes along: the time cut moves him with it)
		H.knot = L.muzzle.global_position + Vector3(0, -float(H.len), 0)
		H.prev = H.knot
		H.v = Vector3.ZERO
	Game.view.set_fog_exp2(Game.view.fog_color, .00045)
	Game.camera.far = 4600.0


func _restore_look() -> void:
	Game.view.set_fog_exp2(Game.view.fog_color, .0017)
	Game.camera.far = 2400.0


# PROG rides in the bay: stood on its floor (turned and tilted with it), one hand up on a grab strap, braced; he flinches at the blast
func _place(P: Player) -> void:
	var v := _at(BAY.x, BAY.y, BAY.z)
	P.x = v.x
	P.y = v.y
	P.z = v.z
	P.vx = 0.0
	P.vz = 0.0
	P.vy = 0.0
	P.grounded = true
	P.yaw = (float(yaw_s) if yaw_s != null else yaw0) + PI
	P.invuln = maxf(P.invuln, 1.0)
	P.dead = false


func _pose(a: Variant) -> void:
	if not on:
		return
	var sway := sin(t * 1.7) * .05
	var fl := flinch
	OmFreefall.sets(a, {"pelvis": [0, 0, sway * .5], "spine1": [.08 + fl * .2, 0, 0], "spine2": [.06 + fl * .15, 0, 0], "chest": [.02, -.15, 0], "neck": [-.05, -.2, 0], "head": [-.08 - fl * .2, -.25 + sin(t * .6) * .15, 0],
		"thighL": [-.35, 0, .12], "thighR": [-.2, 0, -.16], "shinL": [.55, 0, 0], "shinR": [.35, 0, 0], "footL": [-.2, 0, 0], "footR": [-.15, 0, 0],
		"upper_armR": [-2.6 + fl * .2, .1, -.35], "forearmR": [-.35, 0, 0], "handR": [0, 0, -.3],      # up on the strap
		"upper_armL": [-.5 - fl * .5, -.2, .5 + fl * .2], "forearmL": [-.9 - fl * .4, -.2, .3], "handL": [0, 0, .2]})      # braced on the bulkhead rail
	a.py = Vector3.ZERO
	var P: Player = Game.player
	if P != null:
		P.armed = false
		P.aiming = false


func pose_player(a: Variant) -> void:
	if not on or a == null:
		return
	_an = a
	if a.pose_hook != _hook:
		a.pose_hook = _hook
	var A: Node3D = a.actor
	A.quaternion = L.group.quaternion * Quaternion(AY, PI)
	A.position = _at(BAY.x, BAY.y + float(a.B.pivot) * float(a.B.scale), BAY.z)
	A.visible = true


func start(P: Player) -> bool:
	if on:
		return false
	on = true
	t = 0.0
	ev = []
	ei = 0
	done = false
	buck = -1.0
	yaw_s = null
	rimmed = false
	shot_key = ""
	up_k = 0.0
	_events()
	cam.reset()
	_plan()
	R = {"s": 0.0, "v": 0.0, "jy": 0.0, "pitch": 0.0, "roll": 0.0, "yaw_rate": 0.0}
	H.on = false
	flinch = 0.0
	last_v = Vector3.ZERO
	Game.combat.equip(-1)
	jun.hold(1.0, 3.0)
	rope.node.visible = true
	Game.hud.set_suppressed(true)
	Game.ui.dialog.set_bars(true, true)
	Game.hud.set_subs_free(true)
	skip_l.visible = true
	_place(P)
	return true


func _skip_to() -> void:
	if not on or t >= float(TL.fade):
		return
	while ei < ev.size() and float(ev[ei].t) < float(TL.fade):
		if float(ev[ei].t) == float(TL.det):
			marks.detonate()
		if float(ev[ei].t) == float(TL.yank):
			jun.out.done = true
			_hang_start()
		ei += 1
	t = TL.fade
	Game.ui.set_fade(true, "")


func _finish(aborted: bool = false) -> void:
	if not on:
		return
	on = false
	skip_l.visible = false
	_restore_look()
	Game.hud.set_suppressed(false)
	Game.ui.dialog.set_bars(false, true)
	Game.hud.set_subs_free(false)
	audio.loop("lifter", 0.0)
	rope.node.visible = false
	cam.camera.up = Vector3.ZERO
	cam.camera.fov = 0.0
	if _an != null and _an.pose_hook == _hook:
		_an.pose_hook = Callable()
	if aborted:
		Game.ui.set_fade(false)
		line_mi.visible = false
		head.visible = false
		H.on = false
		if coil != null:
			coil.queue_free()
			coil = null
		return
	done = true
	if on_done.is_valid():
		on_done.call()


func stop() -> void:
	_finish(true)


func update(dt: float, P: Player) -> void:
	flash_a = maxf(0.0, flash_a - dt / 1.1)
	flash_c.color.a = flash_a
	if not on or P == null:
		if done and P != null:
			_place(P)
		return
	if Inp.btn(&"jump").pressed or Input.is_key_pressed(KEY_ENTER):
		_skip_to()
	t += dt
	var tt := t
	while ei < ev.size() and float(ev[ei].t) <= tt:
		var f: Callable = ev[ei].fn
		ei += 1
		f.call()
		if not on:
			return
	if tt >= float(TL.rim) and not rimmed:
		rimmed = true
		_rim_jump()
		last_ship = L.group.position
	if not rimmed:
		_ship_pose(tt, dt)
	else:
		L.group.position += rim_dir * (dt * 34.0)
		L.group.position.y += dt * 30.0
		L.group.rotation = Vector3(-.3, atan2(rim_dir.x, rim_dir.z), sin(tt * .9) * .05)
		L.update(dt)
		ship_v = rim_dir * 34.0
		ship_v.y = 30.0
	_hang(tt, dt)
	_harpoon(tt, dt)
	_place(P)
	# his lightning rope to the core, flickering, until the line takes him
	if tt < float(TL.cinch):
		rope_t -= dt
		if rope_t <= 0.0:
			rope_t = .05
			var jp := jun.group.position
			_zap_rope(Vector3(jp.x, jp.y + 24.0, jp.z), C0 + (jp - C0).normalized() * 40.0)
		rope.node.visible = randf() > .12
	jun.boost = 3.6 + sin(tt * 5.0) * .4
	# the blast front reaches them: the lifter bucks (and PROG ducks)
	var b := marks.det_t - 1.8
	if buck < 0.0 and b > 0.0:
		var front := 20.0 + 1500.0 * (1.0 - pow(1.0 - minf(1.0, b / 4.5), 2.0))
		if front > L.group.position.distance_to(C0):
			buck = 0.0
			cam.kick(2.2)
			audio.play_at("boomBig", L.group.position)
			flinch = 1.0
	flinch = maxf(0.0, flinch - dt * .7)
	_camera(dt, tt)
