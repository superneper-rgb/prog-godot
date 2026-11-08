class_name VhFinale
extends RefCounted
## VISITING HOURS: section 6, Fenn (JS finale.js): the finale cutscene, played in the live world. Directed, not just staged: the man on the billboard is only ever seen from far off or in pieces, and the round is a line between him and Fenn the whole scene is built on.
##   A, the office: Prog comes through the door behind his own shoulder; the warden stops mid-punch and backs round the chair to keep Fenn between them; Fenn lifts his head into a close-up ("...You actually came."); a wide held on the line of fire; the round crosses the window in the frame the glass goes, Fenn whips forward, the picture punches in; a side angle on the slump; over Prog's shoulder the warden's hands go up ("That wasn't me!"). The hill: a hot casing rings on the grating at lens height, the camera cranes up the rail, the rifle, into the hood for the drag. Prog at the broken window, seen from the storm outside; his eyes (a long lens on the billboard, the ember breathing); a dolly zoom on him ("On our billboard."); he turns and is gone.
##   B, the hill: the glove opens, the cigarette falls, lightning: the next flash finds the chair empty. Black (time passes). A flash: Prog comes up the service stair far off, runs the catwalk at a camera lying by the cigarette, stops over it. "Still burning." Water off his helmet puts it out. Black.
## Both parts run on clocks laid out at start() from the real lengths of the voice lines, so every cut lands on its line; Space / Enter skips.

const NSH := 150

var lv: ExportedLevel
var admin: VhAdmin
var people: VhPeople
var sniper: VhSniper
var audio: VhAudio
var storm := Callable()
var deck := 0.0
var Y4 := 21.0

var on := false
var play := false
var done := false
var part := "A"
var t := 0.0
var ev := 0
var look_k := 0.0
var impact := -1.0
var shattered := false
var hit_done := false
var drip_t := -1.0
var camera := View.Shot.new(Vector3.ZERO, Vector3.FORWARD, 50.0)
var _an: Variant = null
var _hook := Callable()
var _prev_hook := Callable()
var A := {}
var B := {}
var EA: Array = []
var EB: Array = []
var K := {"face_at": Vector2.ZERO}
var key_burst := 0.0
var flash_t := 0.0
var skip_at := -1.0
var black_a := 0.0
var black_want := 0.0
var black_rate := 1.0 / 0.9

var key: Light3D
var broken: MeshInstance3D
var broken_canvas: VhKit.Canvas
var shards: MultiMeshInstance3D
var sh_pos := PackedVector3Array()
var sh_vel := PackedVector3Array()
var sh_t := -1.0
var tracer: Node3D
var core: MeshInstance3D
var halo: MeshInstance3D
var tr_t := -1.0
var gobo: MeshInstance3D
var gobo_m: StandardMaterial3D
var drip_win: Drips
var drip_tarp: Drips
var helmet: MeshInstance3D
var layer: CanvasLayer
var fade: ColorRect
var flash_r: ColorRect
var skip_l: Label


## water: drips off the broken window's head and off the tarp's front edge onto the rail; srcs: {x, y, z, floor, sx, sz}
class Drips:
	var node: MultiMeshInstance3D
	var srcs: Array
	var bounce := false
	var pos := PackedVector3Array()
	var vel := PackedFloat32Array()
	var b := PackedByteArray()

	func _init(parent: Node, p_srcs: Array, p_bounce: bool) -> void:
		srcs = p_srcs
		bounce = p_bounce
		var n := srcs.size()
		pos.resize(n)
		vel.resize(n)
		b.resize(n)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		mm.mesh = q
		mm.instance_count = n
		node = MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = MsKit.glow_mat(7)
		node.extra_cull_margin = 60.0
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		parent.add_child(node)
		MsKit.tint(node, MsKit.lin(0xbcd0f0), 0.75)
		for i in n:
			mm.set_instance_color(i, Color(1.0, 1.0, 1.0, 1.0))
		reset()

	func _spawn(i: int) -> void:
		var s: Dictionary = srcs[i]
		pos[i] = Vector3(float(s.x) + (randf() - 0.5) * float(s.get("sx", 0.0)), float(s.y) - randf() * 0.02, float(s.z) + (randf() - 0.5) * float(s.get("sz", 0.0)))
		vel[i] = -randf() * 0.5
		b[i] = 0

	func reset() -> void:
		for i in srcs.size():
			_spawn(i)
			pos[i].y -= randf() * (float(srcs[i].y) - float(srcs[i].floor))

	func step(dt: float) -> void:
		var mm := node.multimesh
		for i in srcs.size():
			vel[i] -= 9.8 * dt
			pos[i].y += vel[i] * dt
			var fl: float = srcs[i].floor
			if pos[i].y < fl:
				if bounce and b[i] == 0 and vel[i] < -1.5:
					pos[i].y = fl
					vel[i] = -vel[i] * (0.2 + randf() * 0.15)
					b[i] = 1
				elif pos[i].y < fl - (0.03 if bounce else 0.0):
					_spawn(i)
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(0.02, 0.02, 0.02)), pos[i]))


static func _win(u: float, a: float, b: float) -> float:
	var k := clampf((u - a) / (b - a), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


static func _ease(u: float) -> float:
	var k := clampf(u, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


static func _turn(a: float, b: float, k: float) -> float:
	return a + atan2(sin(b - a), cos(b - a)) * clampf(k, 0.0, 1.0)


func _bw(x: float, z: float, y: float = NAN) -> Vector3:      # billboard-local (x, z) -> world, on the catwalk
	var w := VhLayout.to_w(x, z)
	return Vector3(w.x, deck if is_nan(y) else y, w.y)


func _init(p_lv: ExportedLevel, p_admin: VhAdmin, p_people: VhPeople, p_sniper: VhSniper, p_audio: VhAudio, p_storm: Callable, p_deck: float) -> void:
	lv = p_lv
	admin = p_admin
	people = p_people
	sniper = p_sniper
	audio = p_audio
	storm = p_storm
	deck = p_deck
	Y4 = VhLayout.FLW[&"f4"]
	for nm: String in ["vh-fin-broken", "vh-fin-shards", "vh-fin-tracer", "vh-fin-gobo", "vh-fin-drips", "vh-fin-drop"]:
		for n: Node3D in lv.node_named(nm):
			n.visible = false
	key = VhKit.light(lv, "vh-fin-key")
	if key != null:
		key.light_energy = 0.0
	var f4: Node3D = admin.floors[&"f4"]
	# the window going: its glass and blind hidden, a ring of broken glass and torn slats left in the frame, a cone of glass driven into the room
	broken_canvas = VhKit.Canvas.new(512, 256, _draw_broken)
	broken_canvas.transparent_bg = true
	lv.add_child(broken_canvas)
	broken = MeshInstance3D.new()
	var bq := QuadMesh.new()
	broken.mesh = bq
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.albedo_texture = broken_canvas.get_texture()
	broken.material_override = bm
	broken.visible = false
	f4.add_child(broken)
	sh_pos.resize(NSH)
	sh_vel.resize(NSH)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = MsKit.quad()
	mm.instance_count = NSH
	for i in NSH:
		mm.set_instance_color(i, Color(1.0, 1.0, 1.0, 1.0))
	shards = MultiMeshInstance3D.new()
	shards.multimesh = mm
	shards.material_override = MsKit.glow_mat(7)
	shards.extra_cull_margin = 60.0
	shards.visible = false
	f4.add_child(shards)
	MsKit.tint(shards, MsKit.lin(0xcfe6ff), 0.9)
	# the round: a hot white core inside an orange halo, a 14 m streak from the hill that crosses the window in the frame the glass goes and stops in Fenn
	tracer = Node3D.new()
	tracer.visible = false
	lv.add_child(tracer)
	var cb := BoxMesh.new()
	cb.size = Vector3(0.03, 0.03, 1.0)
	core = MsKit.glow(tracer, cb, 0, 0xfff4d8, 1.0)
	var hb := BoxMesh.new()
	hb.size = Vector3(0.14, 0.14, 1.0)
	halo = MsKit.glow(tracer, hb, 0, 0xff9a40, 0.45)
	core.extra_cull_margin = 300.0
	halo.extra_cull_margin = 300.0
	# light: the window frame thrown across the office floor by each flash while the glass is out
	var gc := VhKit.Canvas.new(128, 128, _draw_gobo)
	lv.add_child(gc)
	gobo = MeshInstance3D.new()
	var gq := PlaneMesh.new()
	gq.size = Vector2(1.0, 1.0)
	gobo.mesh = gq
	gobo_m = StandardMaterial3D.new()
	gobo_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gobo_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gobo_m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gobo_m.albedo_texture = gc.get_texture()
	gobo_m.albedo_color = Color(MsKit.srgb(0xaec4ee), 0.0)
	gobo_m.disable_fog = true
	gobo.material_override = gobo_m
	gobo.visible = false
	f4.add_child(gobo)
	# water
	var W: Dictionary = admin.live_office
	var dw: Array = []
	for i in 22:
		dw.append({"x": float(W.x) + (i / 21.0 - 0.5) * float(W.w) * 0.9, "y": float(W.y1) - 0.05, "z": float(W.z) + 0.02, "floor": Y4 + 0.02, "sx": 0.06})
	drip_win = Drips.new(f4, dw, false)
	var dt_: Array = []
	for i in 26:
		var p := _bw(-8.3 + i * 0.128, 2.17, deck + 1.88)
		dt_.append({"x": p.x, "y": p.y, "z": p.z, "floor": deck + 1.075, "sx": 0.05, "sz": 0.02})
	drip_tarp = Drips.new(lv, dt_, true)
	helmet = MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.0045
	hs.height = 0.009
	helmet.mesh = hs
	helmet.scale = Vector3(1.0, 2.4, 1.0)
	helmet.material_override = VhKit.unlit(0xd8e6ff, 0.85)
	helmet.visible = false
	lv.add_child(helmet)
	# the cut-to-black, the skip hint, a white lightning frame
	layer = CanvasLayer.new()
	layer.layer = 12
	lv.add_child(layer)
	flash_r = ColorRect.new()
	flash_r.color = Color("#e4eeff")
	flash_r.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_r.modulate.a = 0.0
	layer.add_child(flash_r)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	layer.add_child(fade)
	skip_l = Label.new()
	skip_l.text = "SPACE / ENTER  SKIP"
	skip_l.add_theme_font_override(&"font", load("res://assets/fonts/Rajdhani-SemiBold.ttf"))
	skip_l.add_theme_font_size_override(&"font_size", 14)
	skip_l.add_theme_color_override(&"font_color", Color(1.0, 0.9, 0.86, 0.55))
	skip_l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_l.position = Vector2(-170.0, -110.0)
	skip_l.visible = false
	layer.add_child(skip_l)


func _draw_broken(g: Control) -> void:
	var fill := Color(150.0 / 255.0, 175.0 / 255.0, 205.0 / 255.0, 0.22)
	var line := Color(225.0 / 255.0, 238.0 / 255.0, 1.0, 0.45)
	var s := 3
	var r := func() -> float:
		s = (s * 16807) % 2147483647
		return float(s - 1) / 2147483646.0
	var jag := func(a: Vector2, b: Vector2, c: Vector2) -> void:
		g.draw_colored_polygon(PackedVector2Array([a, b, c]), fill)
		g.draw_polyline(PackedVector2Array([a, b, c, a]), line, 1.0)
	var x := 0.0
	while x < 512.0:
		var w: float = 10.0 + r.call() * 12.0
		jag.call(Vector2(x, 0.0), Vector2(x + w, 0.0), Vector2(x + w * r.call(), 4.0 + r.call() * 22.0))
		jag.call(Vector2(x, 256.0), Vector2(x + w, 256.0), Vector2(x + w * r.call(), 252.0 - r.call() * 16.0))
		x += 14.0 + r.call() * 10.0
	var y := 0.0
	while y < 256.0:
		var h: float = 8.0 + r.call() * 10.0
		jag.call(Vector2(0.0, y), Vector2(0.0, y + h), Vector2(4.0 + r.call() * 18.0, y + h * r.call()))
		jag.call(Vector2(512.0, y), Vector2(512.0, y + h), Vector2(508.0 - r.call() * 18.0, y + h * r.call()))
		y += 12.0 + r.call() * 10.0
	for _i in 9:      # the blind's torn slats
		var sx: float = 40.0 + r.call() * 430.0
		g.draw_line(Vector2(sx, 0.0), Vector2(sx + (r.call() - 0.5) * 30.0, 30.0 + r.call() * 70.0), Color(40.0 / 255.0, 36.0 / 255.0, 30.0 / 255.0, 0.9), 5.0)


func _draw_gobo(g: Control) -> void:
	g.draw_rect(Rect2(0.0, 0.0, 128.0, 128.0), Color.BLACK)
	for x in 3:
		for y in 2:
			var ry := 6.0 + y * 61.0
			var steps := 8
			for i in steps:      # (light fades toward the far side: a vertical gradient over the whole picture)
				var y0 := ry + 55.0 * i / steps
				var v := (y0 + 3.0) / 128.0
				g.draw_rect(Rect2(6.0 + x * 41.0, y0, 35.0, 55.0 / steps + 0.5), Color(v, v, v))


# ---- the blocking: the line of fire, the marks, the walks
func _measure() -> void:
	var W: Dictionary = admin.live_office
	K.W = W
	var fen := people.fenn
	var F := Vector3(fen.R.x, Y4, fen.R.z)
	K.F = F
	var ch := VhPeople.bone_at(fen, &"chest")
	var T := Vector3(ch.x, ch.y + 0.32, ch.z)      # where the round goes in: between the shoulders, from behind
	K.T = T
	var M := sniper.local(-0.13, 1.28, 1.68)      # the muzzle (250 m off)
	K.M = M
	var dir := (T - M).normalized()
	K.dir = dir
	var d := Vector3(dir.x, 0.0, dir.z).normalized()
	K.d = d
	var r := Vector3(d.z, 0.0, -d.x)      # (d: into the room along the line; r: its right)
	K.r = r
	var X := M + dir * ((float(W.z) - M.z) / dir.z)      # where it crosses the window
	K.X = X
	K.len_x = X.distance_to(M)
	K.len_t = T.distance_to(M)
	var door := Vector3(VhLayout.ad_x(205.75) - 0.8, Y4, VhLayout.ad_z(958.6))      # just outside the office door (held open)
	var mark := F + d * 2.0 - r * 1.5      # Prog's mark: off the line, Fenn and the window in front of him
	K.mark = mark
	K.in_path = [door, door + Vector3(1.6, 0.0, 0.0), mark]
	K.ward_to = [F + d * 1.6 + r * 0.9, F - d * 0.6 + r * 1.9]      # the warden backs round the chair (Fenn between them)
	var win_at := Vector3(X.x + 0.3, Y4, float(W.z) + 0.55)      # at the broken window, where the round came in
	K.win_at = win_at
	var ch2 := sniper.local(0.0, 0.0, 0.0)
	var to_chair := Vector3(ch2.x - win_at.x, 0.0, ch2.z - win_at.z).normalized()
	K.to_chair = to_chair
	var toF := Vector3(F.x - mark.x, 0.0, F.z - mark.z).normalized()
	K.to_f = toF
	K.win_path = [mark + toF * 0.35, win_at]
	K.exit_to = win_at + Vector3(-3.4, 0.0, 1.1)      # (back toward the door, wide of the camera behind him)
	# the hill: the chair's axes, the casing's landing (the macro is set before it lands), the crane up the rail into the hood
	var o := sniper.local(0.0, 0.0, 0.0)
	var sx := sniper.local(1.0, 0.0, 0.0) - o
	var sz := sniper.local(0.0, 0.0, 1.0) - o
	K.sx = sx
	K.sz = sz
	var land := sniper.casing_land()
	K.crane = [land - sx * 0.36 + sz * 0.06 + Vector3(0.0, 0.05, 0.0), sniper.local(-1.0, 0.62, 0.8), sniper.local(-0.85, 0.8, 1.4), sniper.local(-0.55, 0.72, 2.1)]
	K.crane_look = [land + sx * 0.2 + Vector3(0.0, 0.06, 0.0), sniper.local(-0.1, 0.3, 0.55), sniper.local(-0.15, 1.1, 0.5), sniper.local(-0.02, 1.31, 0.3)]
	var bo := _bw(0.0, 0.0)
	K.bx = _bw(1.0, 0.0) - bo
	K.bz = _bw(0.0, 1.0) - bo
	var D := deck - VhLayout.PLAT_Y
	K.stair_low = _bw(9.8, -6.0, VhLayout.PLAT_Y + D * 0.26)
	K.stair_top = _bw(9.8, 1.65)
	K.turn_at = _bw(8.4, 1.62)
	K.arr_path = null
	K.E = null


## three.js CatmullRomCurve3.getPoint, centripetal (its default)
static func _crom(pts: Array, u: float) -> Vector3:
	var l := pts.size()
	var p := (l - 1) * u
	var ip := int(floor(p))
	var w := p - ip
	if w == 0.0 and ip == l - 1:
		ip = l - 2
		w = 1.0
	var p0: Vector3 = pts[ip - 1] if ip > 0 else (pts[0] as Vector3) - (pts[1] as Vector3) + (pts[0] as Vector3)
	var p1: Vector3 = pts[ip]
	var p2: Vector3 = pts[ip + 1]
	var p3: Vector3 = pts[ip + 2] if ip + 2 < l else (pts[l - 1] as Vector3) - (pts[l - 2] as Vector3) + (pts[l - 1] as Vector3)
	var d0 := pow(p0.distance_squared_to(p1), 0.25)
	var d1 := pow(p1.distance_squared_to(p2), 0.25)
	var d2 := pow(p2.distance_squared_to(p3), 0.25)
	if d1 < 1e-4:
		d1 = 1.0
	if d0 < 1e-4:
		d0 = d1
	if d2 < 1e-4:
		d2 = d1
	var out := Vector3.ZERO
	for a in 3:
		var t1 := ((p1[a] - p0[a]) / d0 - (p2[a] - p0[a]) / (d0 + d1) + (p2[a] - p1[a]) / d1) * d1
		var t2 := ((p2[a] - p1[a]) / d1 - (p3[a] - p1[a]) / (d1 + d2) + (p3[a] - p2[a]) / d2) * d1
		var c2 := -3.0 * p1[a] + 3.0 * p2[a] - 2.0 * t1 - t2
		var c3 := 2.0 * p1[a] - 2.0 * p2[a] + t1 + t2
		out[a] = p1[a] + t1 * w + c2 * w * w + c3 * w * w * w
	return out


# ---- the window going
func _shatter() -> void:
	if shattered:
		return
	shattered = true
	var W: Dictionary = admin.live_office
	admin.office_group.visible = false
	broken.visible = true
	broken.position = Vector3(float(W.x), (float(W.y0) + float(W.y1)) / 2.0, float(W.z) + 0.01)
	broken.scale = Vector3(float(W.w), float(W.y1) - float(W.y0), 1.0)
	var X: Vector3 = K.X
	var d: Vector3 = K.d
	# the glass goes where the round goes: 5-12 m/s inward, within ~28 degrees of the line, most of it from round the hole
	for i in NSH:
		var sp := 5.0 + randf() * 7.0
		var a := (randf() - 0.5) * 0.95
		var e := (randf() - 0.35) * 0.8
		var near := randf() < 0.7
		sh_pos[i] = Vector3(X.x + (randf() - 0.5) * 1.4 if near else float(W.x) + (randf() - 0.5) * float(W.w) * 0.8, X.y + (randf() - 0.3) * 0.9 if near else lerpf(float(W.y0), float(W.y1), randf()), float(W.z) + 0.05)
		sh_vel[i] = Vector3((d.x * cos(a) + d.z * sin(a)) * sp, e * sp * 0.6 + 1.0, (d.z * cos(a) - d.x * sin(a)) * sp)
	sh_t = 0.0
	shards.visible = true
	gobo.position = Vector3(float(W.x), Y4 + 0.03, float(W.z) + 2.4)
	gobo.scale = Vector3(float(W.w), 1.0, 4.8)
	gobo.visible = true
	drip_win.reset()
	drip_win.node.visible = true


func _mend() -> void:
	admin.office_group.visible = true
	broken.visible = false
	shards.visible = false
	sh_t = -1.0
	gobo.visible = false
	tracer.visible = false
	tr_t = -1.0
	drip_win.node.visible = false
	shattered = false
	hit_done = false


func _fire() -> void:
	tr_t = 0.0
	tracer.visible = true
	var dir: Vector3 = K.dir
	tracer.global_basis = Basis(Quaternion(Vector3(0.0, 0.0, 1.0), dir))
	sniper.muzzle()


func _tracer_step(dt: float) -> void:
	if tr_t < 0.0:
		return
	tr_t += dt
	var head := lerpf(float(K.len_x) - 45.0, float(K.len_t) + 0.3, clampf(tr_t / 0.085, 0.0, 1.0))
	var tail := maxf(0.0, head - 14.0)
	var fd := 1.0 - _win(tr_t, 0.085, 0.24)
	if head >= float(K.len_x):      # (the frame it reaches the glass)
		_shatter()
	if head >= float(K.len_t) and not hit_done:
		_hit()
	var M: Vector3 = K.M
	var dir: Vector3 = K.dir
	tracer.global_position = M + dir * ((head + tail) / 2.0)
	tracer.scale.z = maxf(0.01, head - tail)
	MsKit.opa(core, fd)
	MsKit.opa(halo, 0.45 * fd)
	if fd <= 0.0:
		tracer.visible = false
		tr_t = -1.0


func _hit() -> void:
	hit_done = true
	impact = t
	people.shoot()
	_pulse(0.85)
	key_burst = 1.0
	var M: Vector3 = K.M
	(storm.call() as VhStorm).reveal(M.x + 60.0, M.z - 40.0)      # (he fired under the thunder)
	audio.snipe()
	audio.noise_burst(1.0, 0.22)
	audio.thud(0.9)


func _pulse(o: float = 0.85) -> void:
	flash_r.modulate.a = o
	flash_t = 0.14


func _black(on_: bool, slow: bool = false) -> void:
	black_want = 1.0 if on_ else 0.0
	black_rate = 1.0 / (1.6 if slow else 0.9)


# ---- the clocks: laid out from the voice lines' real lengths, so a cut never lands mid-sentence
func _plan() -> void:
	var Lf := audio.len_of("f-came")
	var Lw := audio.len_of("w-notme")
	var Lb := audio.len_of("b-what")
	var Lp := audio.len_of("p-sniper")
	var Lm := audio.len_of("p-warm")
	A = {"walk0": 0.25, "halt": 0.4, "cut_fenn": 2.8, "lift": 2.9}
	A.came = 3.5
	A.wide = A.came + Lf + 0.45
	A.step = A.wide + 0.3
	A.fire = A.wide + 1.75
	A.side = A.fire + 0.55
	A.warden = A.side + 1.15
	A.notme = A.warden + 0.35
	A.hill = A.notme + Lw + 0.35
	A.crane = A.hill + 1.9
	A.drag0 = A.hill + 3.7
	A.win = A.hill + 6.0
	A.what = A.win + 1.1
	A.pov = A.what + Lb + 0.25
	A.zoom = A.pov + 2.7
	A.sniper = A.zoom + 0.3
	A.exit = A.sniper + Lp + 0.45
	A.end = A.exit + 1.6
	A.arrive = A.walk0 + _path_len(K.in_path) / 3.0
	A.at_win = A.win + 0.9
	B = {"drop": 1.3, "flash": 2.75, "black": 4.3, "up": 5.7}
	B.stop = B.up + 6.0
	B.look = B.stop + 0.25
	B.close = B.stop + 0.55
	B.warm = B.close + 0.5
	B.drip = B.warm + Lm + 0.55
	B.fade = B.drip + 2.5
	B.end = B.fade + 1.8
	var M: Vector3 = K.M
	EA = [
		[0.0, func() -> void: audio.tone(46.0, float(A.fire) - 0.05, 0.07, &"sawtooth")],      # (the score: a low industrial hum under the rain, until the round)
		[A.halt, func() -> void: people.halt(_face_at(), K.ward_to, 2.0)],      # (he hurries: Fenn between them before the close-up)
		[A.lift, func() -> void: people.look = 1.0],
		[A.came, func() -> void: audio.say("f-came", {"urgent": true, "on_start": func(_id: String, d: float) -> void: people.speak("fenn", d, 0.9)})],
		[A.fire, _fire],
		[A.notme, func() -> void: audio.say("w-notme", {"urgent": true, "on_start": func(_id: String, d: float) -> void: people.speak("warden", d, 1.0)})],
		[float(A.hill) + 0.1, func() -> void: sniper.eject()],
		[A.win, func() -> void: audio.pad(float(A.end) - float(A.win) + float(B.end), 0.075, 4.0, 7.0)],      # (the low strings, from Prog at the window to the black)
		[A.what, func() -> void: audio.say("b-what", {"urgent": true})],
		[float(A.pov) + 1.05, func() -> void: (storm.call() as VhStorm).reveal(M.x - 30.0, M.z - 70.0)],
		[A.sniper, func() -> void: audio.say("p-sniper", {"urgent": true})],
		[A.end, _to_b],
	]
	EB = [
		[0.0, func() -> void: audio.quiet = 0.45],
		[B.drop, func() -> void: sniper.drop()],
		[B.flash, func() -> void:
			(storm.call() as VhStorm).reveal(M.x - 60.0, M.z - 30.0)
			_pulse(0.9)],
		[float(B.flash) + 0.075, func() -> void: sniper.show(false)],      # (gone between two stutters of the same strike)
		[B.black, func() -> void:
			_black(true)
			audio.quiet = 0.85],
		[float(B.up) - 0.25, func() -> void:
			_black(false)
			(storm.call() as VhStorm).reveal(M.x + 50.0, M.z - 90.0)
			_pulse(0.55)],
		[float(B.close) - 0.1, func() -> void: audio.quiet = 1.0],
		[B.look, func() -> void: look_k = 1.0],
		[B.warm, func() -> void: audio.say("p-warm", {"urgent": true})],
		[B.drip, func() -> void:
			drip_t = 0.0
			helmet.visible = true],
		[B.fade, func() -> void: _black(true, true)],
		[B.end, _finish],
	]


func _face_at() -> Vector2:
	return K.face_at


# ---- paths: a polyline walked by arc length
static func _path_len(pts: Array) -> float:
	var n := 0.0
	for i in range(1, pts.size()):
		n += (pts[i] as Vector3).distance_to(pts[i - 1])
	return n


static func _along(pts: Array, s: float) -> Array:
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		var l := b.distance_to(a)
		if s <= l or i == pts.size() - 1:
			var k := clampf(s / maxf(l, 1e-6), 0.0, 1.0)
			return [a.lerp(b, k), atan2(b.x - a.x, b.z - a.z)]
		s -= l
	return [pts[0], 0.0]


static func _yaw_to(a: Vector3, b: Vector3) -> float:
	return atan2(b.x - a.x, b.z - a.z)


## where Prog is at time u of the current part, and which way he faces (a pure function: his velocity is its difference)
func _block(u: float) -> Array:
	if part == "A":
		if u < float(A.hill):
			var w := _along(K.in_path, _path_len(K.in_path) * _ease((u - float(A.walk0)) / (float(A.arrive) - float(A.walk0))))
			var to_f := _yaw_to(K.mark, K.F)
			var yaw: float = w[1] if u < float(A.arrive) - 0.3 else _turn(w[1], to_f, (u - float(A.arrive) + 0.3) / 0.6)
			var p: Vector3 = (w[0] as Vector3) + (K.to_f as Vector3) * (0.35 * _win(u, float(A.step), float(A.step) + 0.5))      # (the half step toward him: hope)
			if u > float(A.warden) - 0.4:
				yaw = _turn(yaw, atan2(people.warden.R.x - p.x, people.warden.R.z - p.z), (u - float(A.warden) + 0.4) / 0.5)
			return [p, yaw]
		var tc: Vector3 = K.to_chair
		if u < float(A.exit):
			var n := _path_len(K.win_path)
			var w := _along(K.win_path, n * _ease((u - float(A.hill)) / (float(A.at_win) - float(A.hill))))
			return [w[0], w[1] if u < float(A.at_win) - 0.4 else _turn(w[1], atan2(tc.x, tc.z), (u - float(A.at_win) + 0.4) / 0.6)]
		var k := _ease((u - float(A.exit) - 0.25) / 1.6)
		var away := _yaw_to(K.win_at, K.exit_to)
		return [(K.win_at as Vector3).lerp(K.exit_to, k * 0.8), _turn(atan2(tc.x, tc.z), away, (u - float(A.exit)) / 0.45)]
	# B: below the deck on the service stair (out of every shot), up it, along the catwalk at a run, slowing to stand over the cigarette
	if K.arr_path == null:
		return [K.stair_low, 0.0]
	var n := _path_len(K.arr_path)
	var v := clampf((u - (float(B.up) - 1.5)) / (float(B.stop) - float(B.up) + 1.5), 0.0, 1.0)
	var s := v / 0.84 * 0.9 if v < 0.84 else 0.9 + 0.1 * sin((v - 0.84) / 0.16 * PI / 2.0)
	var w := _along(K.arr_path, n * s)
	var bx: Vector3 = K.bx
	return [w[0], w[1] if v < 0.97 else _turn(w[1], atan2(-bx.x, -bx.z), (v - 0.97) / 0.03)]


func _body(u: float, P: Player) -> void:
	var a := _block(u)
	var b := _block(maxf(0.0, u - 0.04))
	var ap: Vector3 = a[0]
	var bp: Vector3 = b[0]
	P.x = ap.x
	P.y = ap.y
	P.z = ap.z
	P.yaw = a[1]
	P.vx = (ap.x - bp.x) / 0.04
	P.vz = (ap.z - bp.z) / 0.04
	P.vy = 0.0
	P.grounded = true
	P.invuln = maxf(P.invuln, 1.0)
	P.dead = false
	K.face_at = Vector2(P.x, P.z)
	if people.face_at != null:
		people.face_at = K.face_at


func pose_player(an: Variant) -> void:
	if not on:
		return
	if _an != an or an.pose_hook != _hook:
		_an = an
		_prev_hook = an.pose_hook
		_hook = _pose
		an.pose_hook = _hook


func _pose(a: Variant) -> void:      # (he looks down at it)
	if _prev_hook.is_valid():
		_prev_hook.call(a)
	if not on or part != "B" or look_k <= 0.0:
		return
	var k := clampf(look_k, 0.0, 1.0)
	var hi: int = Animator.KEYS.find(&"head")
	var ni: int = Animator.KEYS.find(&"neck")
	var si: int = Animator.KEYS.find(&"spine2")
	if hi >= 0:
		var c: Vector3 = a.pose[hi]
		c.x = lerpf(c.x, 0.6, k)
		a.pose[hi] = c
	if ni >= 0:
		var c: Vector3 = a.pose[ni]
		c.x = lerpf(c.x, 0.3, k)
		a.pose[ni] = c
	if si >= 0:
		var c: Vector3 = a.pose[si]
		c.x += 0.14 * k
		a.pose[si] = c


# ---- the shots: where the camera is at time u (a pure function of the clock: cuts between shots, eased moves within them)
func _eyes_of(p: VhPeople.Puppet) -> Vector3:
	if not p.v.B.i.has(&"eye.L"):
		return Vector3(p.R.x, Y4 + 1.4, p.R.z)
	return (VhPeople.bone_at(p, &"eye.L") + VhPeople.bone_at(p, &"eye.R")) * 0.5


## the dolly zoom, k 0..1: behind Prog's head looking past it at the billboard; the camera backs off as the lens narrows so the head stays one size
func _zoom_shot(k: float) -> Array:
	var wa: Vector3 = K.win_at
	var tc: Vector3 = K.to_chair
	var h := Vector3(wa.x, Y4 + 1.76, wa.z)
	var d := lerpf(1.0, 3.0, k)
	var side := Vector3(-tc.z, 0.0, tc.x)
	var tg := sniper.local(0.0, 1.0, 0.2)
	var pos := h - tc * d + side * (0.4 + 0.14 * k) + Vector3(0.0, -0.04, 0.0)
	return [pos, h.lerp(tg, 0.02 + 0.98 * k * k), rad_to_deg(2.0 * atan(0.46 / (2.0 * d)))]


func _base_shot(u: float, P: Player) -> Array:
	var F: Vector3 = K.F if K.has("F") else Vector3.ZERO
	if part == "A":
		var r: Vector3 = K.r
		var d: Vector3 = K.d
		var T: Vector3 = K.T
		var wa: Vector3 = K.win_at
		var tc: Vector3 = K.to_chair
		# 1. through the door behind his right shoulder, tracking him in: the bulb, Fenn, the warden backing off
		if u < float(A.cut_fenn):
			var f := (_block(u + 0.45)[0] as Vector3) - (_block(maxf(0.0, u - 0.35))[0] as Vector3)
			f.y = 0.0
			if f.length_squared() < 1e-4:
				f = F - Vector3(P.x, 0.0, P.z)
				f.y = 0.0
			f = f.normalized()
			var rt := Vector3(-f.z, 0.0, f.x)
			return [Vector3(P.x, Y4 + 1.6, P.z) - f * 1.7 + rt * 0.55, Vector3(F.x, Y4 + 1.15, F.z), 44.0]
		# 2. Fenn: his face as he lifts it, from between where he looks and where Prog stands; the dolly creeps in through his line
		if u < float(A.wide):
			var e := _eyes_of(people.fenn)
			var h := VhPeople.bone_at(people.fenn, &"head")
			var fw := Vector3(e.x - h.x, 0.0, e.z - h.z).normalized()
			var mk: Vector3 = K.mark
			var to_p := Vector3(mk.x - F.x, 0.0, mk.z - F.z).normalized()
			var cd := (fw * 0.25 + to_p * 0.75).normalized()
			var k := _win(u, float(A.cut_fenn), float(A.wide))
			return [e + cd * lerpf(1.45, 1.1, k) + Vector3(0.0, -0.07, 0.0), e + Vector3(0.0, -0.09, 0.0), 34.0]
		# 3. the line of fire: Fenn, the window behind him, the ember on the hill just past his head; held, creeping in. The round comes down this line
		if u < float(A.side):
			var k := _win(u, float(A.wide), float(A.fire) + 0.2)
			return [T + d * lerpf(3.7, 3.25, k) + r * 0.42 + Vector3(0.0, 0.24, 0.0), T - d * 1.6 + Vector3(0.0, 0.1, 0.0), 42.0]
		# 4. low, front-left of him: Fenn gone slack in the ropes, the glass still coming in past him, the warden behind with his hands going up
		if u < float(A.warden):
			var k := _win(u, float(A.side), float(A.warden))
			return [F + r * lerpf(-3.1, -2.9, k) + d * 0.45 + Vector3(0.0, 0.9, 0.0), F + r * 0.4 + Vector3(0.0, 1.0, 0.0), 48.0]
		# 5. over Prog's shoulder (the one away from Fenn): the warden, hands up, facing the gun
		if u < float(A.hill):
			var wh := VhPeople.bone_at(people.warden, &"head")
			var pp := Vector3(P.x, Y4, P.z)
			var tw := Vector3(wh.x - pp.x, 0.0, wh.z - pp.z).normalized()
			var sd := Vector3(-tw.z, 0.0, tw.x)
			var c1 := pp - tw * 0.95 + sd * 0.62
			var c2 := pp - tw * 0.95 - sd * 0.62
			var s := c1 if c1.distance_squared_to(F) > c2.distance_squared_to(F) else c2
			s += tw * (0.18 * _win(u, float(A.warden), float(A.hill)))
			s.y = Y4 + 1.78
			return [s, wh + Vector3(0.0, -0.14, 0.0), 32.0]
		# 6. the hill: at lens height on the grating, the hot casing rings down into frame and lies smoking; the crane up the rail, the rifle, into the hood
		if u < float(A.win):
			var k := _win(u, float(A.crane), float(A.win) - 0.7)
			return [_crom(K.crane, k), _crom(K.crane_look, k), lerpf(32.0, 44.0, k)]
		# 7. from the room behind him, low: he walks into the broken window and stops, a silhouette against the storm and its flashes; the slow push in
		if u < float(A.pov):
			var k := _win(u, float(A.win), float(A.pov))
			var side := Vector3(-tc.z, 0.0, tc.x)
			return [wa - tc * lerpf(5.6, 4.7, k) - side * 1.3 + Vector3(0.0, 0.72, 0.0), wa + tc * 4.0 + Vector3(0.0, 1.75, 0.0), 50.0]
		# 8. his eyes: a long lens on the billboard 250 m off through the rain, the ember breathing (a little handheld drift)
		if u < float(A.zoom):
			var eye := Vector3(P.x, P.y + 1.58, P.z) + tc * 0.25
			var tg := sniper.local(0.05, 1.0, 0.2) + Vector3(sin(u * 1.3) * 0.06, sin(u * 1.9) * 0.05, 0.0)
			return [eye, tg, 2.3]
		# 9. the dolly zoom over his shoulder: the camera backs into the room as the lens closes on the billboard, his head held the same size, the hill rushing up behind it
		if u < float(A.exit):
			return _zoom_shot(_ease((u - float(A.zoom)) / (float(A.exit) - float(A.zoom))))
		# 10. held on the window and the hill: he turns, passes the lens and is gone
		return _zoom_shot(1.0)
	var sx: Vector3 = K.sx
	var sz: Vector3 = K.sz
	var bx: Vector3 = K.bx
	var bz: Vector3 = K.bz
	# 11. low and close by the chair: the glove, the cigarette; it falls (the camera goes down with it); lightning, and the next flash finds the chair empty
	if u < float(B.up) - 0.25:
		var k := _win(u, 0.0, float(B.drop))
		var dn := _win(u, float(B.drop), float(B.drop) + 0.55)
		var hand := sniper.local(0.24, 0.66, 0.4)
		var seat := sniper.local(-0.05, 0.5, 0.1)
		var settle := _win(u, float(B.drop) + 0.6, float(B.drop) + 1.3)
		var cg := sniper.cig_at()
		var lk := hand.lerp(cg, dn).lerp(seat.lerp(cg, 0.62), settle)
		var p0 := sniper.local(lerpf(0.98, 0.9, k), lerpf(0.62, 0.58, k), lerpf(0.75, 0.7, k))
		return [p0.lerp(cg + sz * 0.75 + sx * 0.35 + Vector3(0.0, 0.32, 0.0), settle), lk, lerpf(36.0, 50.0, settle)]
	var E: Vector3 = K.E if K.E != null else sniper.cig_at()
	# 12. lying on the grating by the cigarette: Prog comes up the stair at the far end and runs at us, stopping over it
	if u < float(B.close):
		var dn := _win(u, float(B.stop) - 1.5, float(B.close) - 0.2)
		var lk := (Vector3(P.x, P.y + 1.58 - 0.15, P.z)).lerp(E + bx * 0.35 + Vector3(0.0, 0.45, 0.0), dn)
		return [E - bx * 1.1 + bz * 0.2 + Vector3(0.0, 0.3, 0.0), lk, 44.0]
	# 13. the cigarette, close: drips off the tarp on the rail behind, his boots; the water off his helmet; out
	var k := _win(u, float(B.close), float(B.fade))
	return [E + bx * lerpf(-0.27, -0.22, k) + bz * 0.16 + Vector3(0.0, lerpf(0.08, 0.065, k), 0.0), E + Vector3(0.0, 0.012, 0.0), 38.0]


## shot 3's punch: the frame the round lands the picture snaps in and jolts, settling in a third of a second (the rig's own shake is off in a cutscene)
func _shot(u: float, P: Player) -> Array:
	var s := _base_shot(u, P)
	if impact < 0.0 or part != "A":
		return s
	var v := u - impact
	if v < 0.0 or v > 0.5:
		return s
	var k := exp(-v * 18.0)
	s[2] = float(s[2]) - 14.0 * k
	s[0] = (s[0] as Vector3) + Vector3(sin(u * 190.0) * 0.05 * k, cos(u * 230.0) * 0.045 * k, 0.0)
	return s


func _to_b() -> void:
	part = "B"
	t = 0.0
	ev = 0
	look_k = 0.0
	sniper.show(true)
	sniper.drag = 0.0
	sniper.flare_from(null)
	key_burst = 0.0
	if key != null:
		key.light_energy = 0.0
	drip_tarp.reset()
	drip_tarp.node.visible = true


func start() -> bool:
	if on:
		return false
	var P: Player = Game.player
	if P == null:
		return false
	people.reset()
	sniper.reset()
	_mend()
	audio.jam(false)
	audio.hush()
	sniper.show(true)      # (measure reads his matrix; he has been there all along)
	people.pose_fenn()
	_measure()
	_plan()
	on = true
	done = false
	part = "A"
	t = 0.0
	ev = 0
	look_k = 0.0
	impact = -1.0
	drip_t = -1.0
	skip_at = -1.0
	sniper.on_clink = func(v: float) -> void: audio.clink(v)
	(storm.call() as VhStorm).mist = 1.7      # (thicker mist round the lamps and the marsh)
	admin.unlock("office", true)
	admin.hold("office", 90.0)
	Game.ui.dialog.set_bars(true, true)
	Game.hud.set_suppressed(true)
	Game.hud.set_subs_free(true)
	skip_l.visible = true
	black_a = 0.0
	black_want = 0.0
	_body(0.0, P)
	var s := _shot(0.0, P)
	camera.pos = s[0]
	camera.look = s[1]
	camera.fov = s[2]
	return true


## the scene's weather and score back to the level's own (finish, reset, dispose)
func _calm() -> void:
	audio.quiet = 0.0
	(storm.call() as VhStorm).mist = 1.0
	drip_tarp.node.visible = false
	drip_win.node.visible = false
	helmet.visible = false
	if key != null:
		key.light_energy = 0.0
	sniper.flare_from(null)


## straight to the end: the chair empty, the cigarette on the grating, black
func skip() -> void:
	if not on or skip_at >= 0.0:
		return
	audio.hush()
	if not people.dead:
		people.shoot()
		_shatter()
	sniper.drop()
	sniper.show(false)
	black_a = 1.0
	black_want = 1.0
	skip_at = 0.45


func _finish() -> void:
	if not on:
		return
	on = false
	done = true
	skip_at = -1.0
	_calm()
	if _an != null and is_instance_valid(_an) and _an.pose_hook == _hook:
		_an.pose_hook = _prev_hook
	_an = null
	Game.ui.dialog.set_bars(false, false)
	Game.hud.set_suppressed(false)
	Game.hud.set_subs_free(false)
	skip_l.visible = false
	var P: Player = Game.player
	if P != null:
		var at := _bw(-5.3, 1.55)
		var ch := sniper.local(0.0, 0.0, 0.0)
		P.x = at.x
		P.y = at.y
		P.z = at.z
		P.vx = 0.0
		P.vz = 0.0
		P.yaw = atan2(ch.x - P.x, ch.z - P.z)
		Game.rig.snap_to(P)
	black_want = 0.0
	black_rate = 1.0 / 0.5


## a checkpoint before the finale: everything as it was (Fenn alive, the window whole, the chair on the billboard empty)
func reset() -> void:
	if on:
		_finish()
	_calm()
	done = false
	people.reset()
	sniper.reset()
	_mend()


func update(dt: float) -> void:
	var P: Player = Game.player
	if sh_t >= 0.0:
		sh_t += dt
		var mm := shards.multimesh
		for i in NSH:
			var v := sh_vel[i]
			v.y -= 9.8 * dt
			var q := sh_pos[i] + v * dt
			if q.y < Y4 + 0.02:
				q.y = Y4 + 0.02
				v = Vector3(v.x * 0.3, 0.0, v.z * 0.3)
			sh_vel[i] = v
			sh_pos[i] = q
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(0.045, 0.045, 0.045)), q))
		if sh_t > 6.0:
			shards.visible = false
			sh_t = -1.0
	_tracer_step(dt)
	if drip_win.node.visible:
		drip_win.step(dt)
	if drip_tarp.node.visible:
		drip_tarp.step(dt)
	var st: VhStorm = storm.call()
	if gobo.visible:
		gobo_m.albedo_color.a = clampf(st.flash * 0.8 + key_burst * 0.6, 0.0, 0.9)
	if flash_t > 0.0:
		flash_t -= dt
		flash_r.modulate.a = maxf(0.0, flash_t / 0.14) * 0.85 if flash_t > 0.0 else 0.0
	black_a = move_toward(black_a, black_want, dt * black_rate)
	fade.modulate.a = black_a
	sniper.update(dt)
	if not on or P == null:
		return
	if Inp.key_hit(KEY_SPACE) or Inp.key_hit(KEY_ENTER) or Inp.key_hit(KEY_KP_ENTER):
		skip()
	if skip_at >= 0.0:
		skip_at -= dt
		if skip_at <= 0.0:
			_finish()
		return
	t += dt
	var list: Array = EA if part == "A" else EB
	while ev < list.size() and float(list[ev][0]) <= t:
		var e: Array = list[ev]
		var pt := part
		ev += 1
		(e[1] as Callable).call()
		if not on or part != pt:
			return
	if part == "A":
		# his drags: one as the crane reaches the hood, one through Prog's long lens
		sniper.drag = maxf(_win(t, float(A.drag0), float(A.drag0) + 1.0) * (1.0 - _win(t, float(A.win) - 0.5, float(A.win) + 0.2)), _win(t, float(A.pov) + 0.25, float(A.pov) + 1.1) * (1.0 - _win(t, float(A.pov) + 1.9, float(A.zoom))))
		# the key: the impact's white burst through the window, then the storm on his face at the sill (and every flash)
		key_burst = maxf(0.0, key_burst - dt * 7.0)
		if key != null:
			if key_burst > 0.0:
				key.global_position = (K.X as Vector3) + (K.d as Vector3) * 1.2
				key.light_energy = 60.0 * key_burst / PI
			else:
				key.light_energy = 0.0
	else:
		if K.arr_path == null and t > float(B.drop) + 0.8 and sniper.on_deck:
			var E := sniper.cig_at()
			E.y = deck + 0.005
			K.E = E
			var stop := E + (K.bx as Vector3) * 0.78 + (K.bz as Vector3) * 0.04
			stop.y = deck
			K.arr_path = [K.stair_low, K.stair_top, K.turn_at, stop]
		if K.E == null:
			K.E = sniper.cig_at()
		if drip_t >= 0.0:
			drip_t += dt
			var y := 1.42 - 4.9 * drip_t * drip_t
			helmet.global_position = (K.E as Vector3) + Vector3(0.0, maxf(0.0, y) + 0.01, 0.0)
			if y <= 0.0:
				drip_t = -1.0
				helmet.visible = false
				sniper.douse()
				audio.sizzle(1.1)
				audio.noise_burst(0.3, 0.18)
	_body(t, P)
	# the far flare: the ember 250 m off reads as a point of fire in every shot from the office (walls hide it; on the hill it is the real thing)
	var s := _shot(t, P)
	camera.pos = s[0]
	camera.look = s[1]
	camera.fov = s[2]
	if part == "A" and (t < float(A.hill) or t >= float(A.win)):
		sniper.flare_from(camera.pos, camera.fov)
	else:
		sniper.flare_from(null)
