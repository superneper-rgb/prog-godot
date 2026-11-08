class_name JetpackKit
extends RefCounted
## JETPACK EQUIP for kit levels (JS levels/_kit/jetpack.js + jetpack-yard/jetpack-fx.js): the pack on PROG's back (spinning turbines, heat-glowing bell nozzles that vector with travel, reactor core, spring-deployed wings, a turbulent shader plume, a world-space trail and shockwave rings) and the phosphor fuel gauge, switched on and off mid-level. The physics is the engine's own (Player.step, Config.jet_fuel = seconds of thrust per airtime; a Config value a level changes is restored automatically). The pack hangs off the character's chest bone, offset solved from the rig's rest pose, so it rides the animated back. Use: var jet := JetpackKit.new(lv, 1.0); jet.equip(true); then jet.update(dt, P) every frame.

const SEAT_UP := 1.26      # where the pack sits, in metres from the feet along the body: the same spot for every character; the actor's scale shrinks it for Tommy
const SEAT_BACK := .27
const P_IN := Color(0xe8 / 255.0, 0xfd / 255.0, 1.0)
const P_MID := Color(0x3e / 255.0, 0xe3 / 255.0, 1.0)
const P_OUT := Color(0x9a / 255.0, 0x46 / 255.0, 1.0)
const P_LOW := Color(1.0, 0xa0 / 255.0, 0x30 / 255.0)
const P_DRY := Color(1.0, 0x2a / 255.0, 0x1a / 255.0)
const PLUME := "shader_type spatial;\nrender_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;\nuniform float uAmt = 1.0;\nuniform float uLayer = 0.0;\nuniform vec3 uIn = vec3(1.0);\nuniform vec3 uMid = vec3(0.0, 1.0, 1.0);\nuniform vec3 uOut = vec3(0.6, 0.3, 1.0);\nfloat h(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }\nfloat n(vec2 p){ vec2 i=floor(p),f=fract(p); f=f*f*(3.-2.*f); return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1.)),f.x),f.y); }\nvoid fragment(){\n float along=UV.y;\n vec2 q=vec2(UV.x*6.,along*3.-TIME*(7.+uLayer*3.));\n float t=n(q)*.6+n(q*2.3+3.7)*.3+n(q*5.1)*.1;\n float rim=abs(dot(NORMAL,VIEW));\n float shape=smoothstep(1.,.15,along+t*.45*along) * pow(rim,.6+uLayer);\n float diamonds=.5+.5*sin(along*34.-TIME*40.); diamonds=pow(diamonds,6.)*(1.-along)*.8;\n vec3 c=mix(uIn,uMid,smoothstep(0.,.35,along)); c=mix(c,uOut,smoothstep(.3,.9,along+t*.2));\n float a=(shape*(.55+t*.7)+diamonds*shape)*uAmt;\n ALBEDO=c*a*1.4;\n}\n"


class Ring:
	var m: MeshInstance3D
	var t := 1.0
	var dur := 1.0
	var r0 := 1.0
	var r1 := 3.0
	var a := 1.0


var on := false
var fuel := 1.0
var lv: Node
var layer: CanvasLayer
var box: HBoxContainer
var lbl: Label
var back: ColorRect
var fill: ColorRect
var group: Node3D
var body: Node3D
var loc := Transform3D.IDENTITY
var attached := false
var _an: Variant = null
var noz: Array = []      # {duct, fan, rim, tip, sx}
var wings: Array = []    # {piv, sx, tip_l}
var plumes: Array = []   # {g, outer, mid, inn, diamonds, glow}
var vents: Array[StandardMaterial3D] = []
var seam_mat: StandardMaterial3D
var nozzle_mat: StandardMaterial3D
var core: MeshInstance3D
var cage: MeshInstance3D
var core_glow: MeshInstance3D
var beacon: MeshInstance3D
var beacon_mat: StandardMaterial3D
var rings: Array[Ring] = []
var ring_i := 0
var sparks: OmPuffs
var smoke: OmPuffs
var was_on := false
var was_jet := false
var was_dry := false
var clock := 0.0
var spin := 0.0
var wing_open := 0.0
var wing_v := 0.0
var burn := 0.0
var emit_acc := 0.0
var smoke_acc := 0.0
var lean := 0.0
var lean_v := 0.0
var roll := 0.0
var roll_v := 0.0
var kick := 0.0
var kick_v := 0.0
var heat := 0.0


func _init(parent: Node, p_fuel: float = 1.0) -> void:
	lv = parent
	fuel = p_fuel
	layer = CanvasLayer.new()
	layer.layer = 12
	parent.add_child(layer)
	box = HBoxContainer.new()
	box.anchor_left = .5
	box.anchor_right = .5
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -105.0
	box.offset_right = 105.0
	box.offset_top = -80.0
	box.offset_bottom = -64.0
	box.add_theme_constant_override(&"separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)
	lbl = Label.new()
	lbl.text = "JET"
	lbl.add_theme_font_override(&"font", load("res://assets/fonts/VT323-Regular.ttf"))
	lbl.add_theme_font_size_override(&"font_size", 16)
	box.add_child(lbl)
	back = ColorRect.new()
	back.color = Color("#2f8a4c")
	back.custom_minimum_size = Vector2(170.0, 12.0)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	var bg := ColorRect.new()
	bg.color = Color("#031008")
	bg.position = Vector2(1, 1)
	bg.size = Vector2(168, 10)
	back.add_child(bg)
	fill = ColorRect.new()
	fill.position = Vector2(1, 1)
	fill.size = Vector2(168.0, 10.0)
	back.add_child(fill)
	var x := 9.0      # the gauge's segments
	while x < 168.0:
		var seg := ColorRect.new()
		seg.color = Color("#031008")
		seg.position = Vector2(1.0 + x, 1)
		seg.size = Vector2(2, 10)
		back.add_child(seg)
		x += 11.0
	layer.visible = false
	_build()


func _std(hex: int, rough: float, metal: float, emit: int = 0, e: float = 0.0) -> StandardMaterial3D:
	var m := MsKit.std(hex, rough, metal, true)
	if emit != 0:
		m.emission_enabled = true
		m.emission = MsKit.lin(emit)
		m.emission_energy_multiplier = e
	return m


func _panel(base: String) -> Texture2D:      # worn gunmetal panel sheet: brushed noise, panel seams, rivets, a hazard band and a stencil
	var f := ThemeDB.fallback_font
	var cv := VhKit.Canvas.new(256, 256, func(c: Control) -> void:
		c.draw_rect(Rect2(0, 0, 256, 256), Color(base))
		var s := [1337]
		var rnd := func() -> float:
			s[0] = (int(s[0]) * 16807) % 2147483647
			return float(s[0]) / 2147483647.0
		for y in 256:
			c.draw_rect(Rect2(0, y, 256, 1), Color(1, 1, 1, .02 + rnd.call() * .04) if rnd.call() < .5 else Color(0, 0, 0, .02 + rnd.call() * .04))
		for y: int in [0, 64, 112, 176]:
			c.draw_rect(Rect2(0, y, 256, 2), Color(0, 0, 0, .75))
			c.draw_rect(Rect2(0, y + 2, 256, 1), Color(1, 1, 1, .14))
			var rx := 8
			while rx < 256:
				c.draw_circle(Vector2(rx + 1, y + 7), 2.4, Color(0, 0, 0, .6))
				c.draw_circle(Vector2(rx, y + 6), 1.6, Color(.86, .9, .94, .45))
				rx += 16
		for x: int in [0, 96, 160]:
			c.draw_rect(Rect2(x, 0, 2, 256), Color(0, 0, 0, .75))
		var hx := -40
		while hx < 296:      # hazard band
			c.draw_colored_polygon(PackedVector2Array([Vector2(hx, 116), Vector2(hx + 11, 116), Vector2(hx - 11, 138), Vector2(hx - 22, 138)]), Color("#d8a21c"))
			hx += 22
		c.draw_string(f, Vector2(8, 160), "SCHLEED-TECH  JX-9", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(.9, .94, .96, .55))
		c.draw_string(f, Vector2(170, 230), "! HOT EXHAUST", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, .35, .16, .6)))
	lv.add_child(cv)
	return cv.get_texture()


func _mi(mesh: Mesh, mat: Material, parent: Node3D, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


func _build() -> void:
	group = Node3D.new()
	group.name = "jetpack"
	group.visible = false
	lv.add_child(group)
	sparks = OmPuffs.new(lv, 420, true)
	smoke = OmPuffs.new(lv, 160, false)
	# ---- materials
	var hull := MsKit.std(0xffffff, .9, .8)
	hull.albedo_texture = _panel("#3a434c")
	var plate := MsKit.std(0xffffff, .75, .9, true)
	plate.albedo_texture = _panel("#9aa6ae")
	nozzle_mat = _std(0x4a4440, .35, .95, 0xff4a10, 0.0)
	var trim := MsKit.std(0x10161b, .6, .5)
	var neon := _std(0x0b2a30, .4, 0.0, 0x19e6ff, 1.6)
	seam_mat = neon
	var warn := VhKit.unlit(0xff2a2a, 1.0)
	# ---- frame: angular spine plate, shoulder yoke, glowing seam, heat vents
	body = Node3D.new()
	group.add_child(body)
	_mi(MsKit.box(.5, .66, .14), hull, body)
	var up := _mi(MsKit.cyl(.19, .27, .2, 6), plate, body, Vector3(0, .4, .02))
	up.rotation.y = PI / 6.0
	_mi(MsKit.box(.04, .74, .02), neon, body, Vector3(0, 0, -.084))      # proud of the plate: no coplanar flicker
	for sx: float in [-1.0, 1.0]:
		var st := _mi(MsKit.box(.05, .6, .03), trim, body, Vector3(sx * .2, .05, .092))
		st.rotation.z = sx * .08
	for i in 4:
		var vm := _std(0x300a05, .5, 0.0, 0xff5a1c, .2)
		vents.append(vm)
		_mi(MsKit.box(.3, .028, .03), vm, body, Vector3(0, .24 - i * .075, -.085))
	# ---- reactor: glowing core in a spinning wire cage
	var core_pos := Vector3(0, .06, -.14)
	core = _mi(MsKit.sphere(.085, 8, 6), VhKit.unlit(0x67f0ff, 1.0), body, core_pos)
	var cm := VhKit.unlit(0xb8fbff, .35)
	cm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cm.disable_fog = true
	cage = _mi(MsKit.sphere(.13, 8, 5), cm, body, core_pos)
	core_glow = MsKit.sprite8(body, 0x56e8ff, .7, .55)
	core_glow.position = core_pos
	# ---- two turbine ducts: shell, glowing rim, spinning bladed fan
	for sx: float in [-1.0, 1.0]:
		var duct := Node3D.new()
		duct.position = Vector3(sx * .24, -.18, -.16)
		body.add_child(duct)
		_mi(MsKit.cyl(.115, .09, .52, 14, true), plate, duct)
		_mi(MsKit.torus(.115, .014, 20, 6), neon, duct, Vector3(0, .26, 0))
		var rim_mat: StandardMaterial3D = neon.duplicate()
		_mi(MsKit.torus(.09, .02, 20, 6), rim_mat, duct, Vector3(0, -.27, 0))
		var fan := Node3D.new()
		fan.position.y = .2
		duct.add_child(fan)
		for b in 9:
			var blade := _mi(MsKit.box(.1, .008, .028), trim, fan, Vector3(.05 * cos(b / 9.0 * TAU), 0, -.05 * sin(b / 9.0 * TAU)))
			blade.rotation = Vector3(.5, b / 9.0 * TAU, 0)
		_mi(MsKit.cyl(.025, .025, .03, 8), neon, fan)
		# bell nozzle: a flare under the duct, heat-tinted
		_mi(MsKit.cyl(.085, .125, .18, 18, true), nozzle_mat, duct, Vector3(0, -.34, 0))
		for k in 3:
			_mi(MsKit.torus(.1, .008, 18, 5), trim, duct, Vector3(0, .12 - k * .16, 0))
		var tip := Node3D.new()      # the plume hangs from here (bell mouth)
		tip.position.y = -.43
		duct.add_child(tip)
		noz.append({"duct": duct, "fan": fan, "rim": rim_mat, "tip": tip, "sx": sx})
	# wings: swept fins that fold out while burning, glowing leading edge
	for sx: float in [-1.0, 1.0]:
		var piv := Node3D.new()
		piv.position = Vector3(sx * .27, .22, -.08)
		body.add_child(piv)
		var fin := _mi(MsKit.box(.52, .016, .2), hull, piv, Vector3(sx * .26, 0, -.06))
		fin.rotation.y = sx * -.3
		var edge := _mi(MsKit.box(.54, .02, .018), neon, piv, Vector3(sx * .27, 0, -.15))
		edge.rotation.y = sx * -.3
		var tl := _mi(MsKit.sphere(.03, 6, 4), warn, piv, Vector3(sx * .5, 0, -.1))
		wings.append({"piv": piv, "sx": sx, "tip_l": tl})
	# antenna with a blinking beacon
	var ant := _mi(MsKit.cyl(.006, .006, .38, 5), trim, body, Vector3(.19, .55, -.02))
	ant.rotation.z = -.12
	beacon_mat = VhKit.unlit(0x4dff9a, 1.0)
	beacon = _mi(MsKit.sphere(.022, 8, 6), beacon_mat, body, Vector3(.215, .74, -.02))
	# ---- plume per nozzle: layered additive cones, mach diamonds, glow billboard
	var sh := Shader.new()
	sh.code = PLUME
	for n: Dictionary in noz:
		var g := Node3D.new()
		g.visible = false
		(n.tip as Node3D).add_child(g)
		var mk := func(r: float, h: float, ly: float) -> MeshInstance3D:
			var cone := CylinderMesh.new()      # apex down, UV.y 0 at the nozzle
			cone.top_radius = r
			cone.bottom_radius = 0.0
			cone.height = h
			cone.radial_segments = 20
			cone.rings = 8
			cone.cap_top = false
			cone.cap_bottom = false
			var pm := ShaderMaterial.new()
			pm.shader = sh
			pm.set_shader_parameter(&"uLayer", ly)
			var m := _mi(cone, pm, g, Vector3(0, -h / 2.0, 0))
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			return m
		var diamonds: Array = []
		for _i in 5:
			var d := MsKit.glow(g, MsKit.sphere(.07, 4, 2), 0, 0xffffff, .85)
			d.scale = Vector3(1, 1.7, 1)
			diamonds.append(d)
		var glow := MsKit.sprite8(g, 0x66e8ff, 1.0, 1.0)
		glow.position.y = -.15
		plumes.append({"g": g, "outer": mk.call(.2, 2.3, 0.0), "mid": mk.call(.13, 1.6, 1.0), "inn": mk.call(.07, 1.0, 2.0), "diamonds": diamonds, "glow": glow})
	# ---- shockwave rings (pooled): horizontal discs that expand and fade
	var rm := MsKit.ring(.86, 1.0, 40)
	for _i in 8:
		var r := Ring.new()
		r.m = MsKit.glow(lv, rm, 0, 0x7af3ff, 0.0)
		r.m.rotation.x = -PI / 2.0
		r.m.visible = false
		rings.append(r)


## the rest of the rig: local = restWorld(chest)^-1 * actor * seat, so the pose it is in right now does not matter
func _attach() -> void:
	var an: Variant = Game.animator
	if an == null or not an.by_key.has(&"chest"):
		return
	var rec: Variant = an.by_key[&"chest"]
	var rest: Transform3D = an._model_xf * an.skel.get_bone_global_rest(rec.bone)
	var B: Variant = an.B
	var seat := Transform3D(Basis.IDENTITY, Vector3(0, SEAT_UP / float(B.scale) - float(B.pivot), -SEAT_BACK / float(B.scale)))
	loc = rest.affine_inverse() * seat
	_an = an
	attached = true


## give (true) or take away (false) the jetpack
func equip(v: bool = true) -> void:
	on = v
	Config.jet_fuel = fuel if on else 0.0
	layer.visible = on
	group.visible = on
	if on and not attached:
		_attach()


func _ring(p: Vector3, r0: float, r1: float, dur: float, col: Color, a: float = .9) -> void:
	var r := rings[ring_i % rings.size()]
	ring_i += 1
	r.t = 0.0
	r.dur = dur
	r.r0 = r0
	r.r1 = r1
	r.a = a
	r.m.position = p
	r.m.visible = true
	MsKit.tint(r.m, col)


func _tip(n: Dictionary) -> Vector3:
	return (n.tip as Node3D).global_position


func update(dt: float, P: Player) -> void:
	if not on or P == null:
		return
	if not attached or _an != Game.animator:
		attached = false
		_attach()
	dt = minf(dt, .05)
	var f: float = P.jet_fuel / fuel if P.jet_on else 1.0      # full on the ground, the burn drains it, empty until you land
	var dry: bool = P.jet_on and P.jet_fuel <= 0.0
	fill.size.x = 0.0 if dry else 168.0 * clampf(f, 0.0, 1.0)
	var jetting: bool = P.jetting
	var c := Color("#7af3ff") if jetting else (Color("#ffb43c") if f < 0.35 else Color("#2fd46a"))
	fill.color = c
	lbl.add_theme_color_override(&"font_color", Color("#7af3ff") if jetting else (Color("#ffb43c") if f < 0.35 else Color("#8dffb4")))
	_pack(P, dt, f, jetting, dry)


func _pack(P: Player, dt: float, fuel_f: float, jetting: bool, dry: bool) -> void:
	clock += dt
	if attached and _an != null:
		var an: Variant = _an
		var rec: Variant = an.by_key[&"chest"]
		group.global_transform = an.actor.global_transform * (an._model_xf * an.skel.get_bone_global_pose(rec.bone)) * loc
	var j_on: bool = P.jet_on
	var low_f := j_on and fuel_f < .35
	burn += ((1.0 if jetting else 0.0) - burn) * minf(1.0, dt * (14.0 if jetting else 5.0))      # 0..1 smoothed throttle
	spin += dt * (4.0 + burn * 70.0)
	# fuel-driven plasma colour: cyan / violet when full, amber when low, red when dying
	var lowk := 1.0 - fuel_f / .35
	var hot_c: Color = P_MID.lerp(P_LOW, lowk) if low_f else P_MID
	var out_c: Color = P_OUT.lerp(P_DRY, lowk) if low_f else P_OUT
	# pack motion: lean against travel (springy), ignition recoil, engine rumble while burning
	var sy := sin(P.yaw)
	var cy := cos(P.yaw)
	var fwd := P.vx * sy + P.vz * cy
	var side := P.vx * cy - P.vz * sy
	var t_lean := clampf(fwd * .045, -.35, .35) if j_on else 0.0
	var t_roll := clampf(-side * .04, -.3, .3) if j_on else 0.0
	lean_v += ((t_lean - lean) * 90.0 - lean_v * 12.0) * dt
	lean += lean_v * dt
	roll_v += ((t_roll - roll) * 90.0 - roll_v * 12.0) * dt
	roll += roll_v * dt
	kick_v += (-kick * 260.0 - kick_v * 14.0) * dt
	kick += kick_v * dt
	var rumble := burn * .006
	body.position = Vector3((randf() - .5) * rumble, kick + (randf() - .5) * rumble, 0.0)
	body.rotation = Vector3(-lean * .35, 0.0, roll * .3)
	heat = clampf(heat + (dt * 1.4 if jetting else -dt * .35), 0.0, 1.0)      # nozzles heat while burning, cool slowly
	nozzle_mat.emission_energy_multiplier = heat * heat * 2.2
	nozzle_mat.emission = Color(1.0, .25 + heat * .25, .05 + heat * .1)
	# thrust vectoring: ducts swivel to push against travel, wings spring open with overshoot
	for n: Dictionary in noz:
		var d: Node3D = n.duct
		d.rotation.x += (lean * 1.6 - d.rotation.x) * minf(1.0, dt * 10.0)
		d.rotation.z += (roll * 1.4 - float(n.sx) * .04 * burn - d.rotation.z) * minf(1.0, dt * 10.0)
		(n.fan as Node3D).rotation.y = spin * float(n.sx)
		var rm: StandardMaterial3D = n.rim
		rm.emission_energy_multiplier = 1.4 + burn * 2.5 + sin(clock * 30.0) * .15 * burn
		rm.emission = MsKit.lin(0x19e6ff).lerp(out_c, burn * (1.0 if low_f else 0.0))
	var w_target := 1.0 if j_on and not dry else 0.0
	wing_v += ((w_target - wing_open) * 160.0 - wing_v * 11.0) * dt
	wing_open += wing_v * dt
	for w: Dictionary in wings:
		var piv: Node3D = w.piv
		piv.rotation.z = float(w.sx) * -wing_open * .75
		piv.rotation.x = sin(clock * 40.0 + float(w.sx)) * .02 * burn
		(w.tip_l as Node3D).visible = int(clock * 6.0) % 2 == 0 or j_on
	core.rotation = Vector3(clock * 2.0, clock * 3.0, 0.0)
	cage.rotation = Vector3(0.0, -clock * 2.0, clock * 1.3)
	var pulse := 1.0 + sin(clock * (4.0 + burn * 18.0)) * (.12 + burn * .15)
	core.scale = Vector3.ONE * (pulse * (1.0 + burn * .5))
	cage.scale = Vector3.ONE * (1.0 + burn * .45)
	var core_c := Color(.4, .94, 1.0).lerp(Color(1.0, .35, .1), lowk) if low_f else Color(.4, .94, 1.0)
	(core.material_override as StandardMaterial3D).albedo_color = core_c
	MsKit.tint(core_glow, core_c)
	core_glow.scale = Vector3.ONE * (.45 + burn * .5 + sin(clock * 9.0) * .04)
	for i in vents.size():
		vents[i].emission_energy_multiplier = .15 + burn * (1.4 + sin(clock * 22.0 + i * 1.7) * .5) + (.3 if j_on else 0.0)
	beacon.visible = int(clock * (9.0 if low_f else 2.2)) % 2 == 0
	beacon_mat.albedo_color = Color("#ff2a2a") if low_f or dry else Color("#4dff9a")
	seam_mat.emission_energy_multiplier = 1.2 + burn * 2.0
	# plumes
	for idx in plumes.size():
		var pl: Dictionary = plumes[idx]
		var g: Node3D = pl.g
		g.visible = burn > .03
		if not g.visible:
			continue
		var flick := 1.0 + sin(clock * 55.0 + idx * 2.1) * .12 + sin(clock * 23.0 + idx) * .1
		var sputter := .55 + .45 * absf(sin(clock * (14.0 + 20.0 * lowk))) if low_f else 1.0
		var L := burn * flick * sputter
		(pl.outer as Node3D).scale = Vector3(1.0 + (1.0 - L) * .3, L, 1.0 + (1.0 - L) * .3)
		(pl.mid as Node3D).scale = Vector3(1, L * 1.02, 1)
		(pl.inn as Node3D).scale = Vector3(1, L * .96, 1)
		(pl.outer as Node3D).position.y = -2.3 / 2.0 * L
		(pl.mid as Node3D).position.y = -1.6 / 2.0 * L * 1.02
		(pl.inn as Node3D).position.y = -1.0 / 2.0 * L * .96
		for k: String in ["outer", "mid", "inn"]:
			var m: ShaderMaterial = (pl[k] as MeshInstance3D).material_override
			m.set_shader_parameter(&"uIn", P_IN)
			m.set_shader_parameter(&"uMid", hot_c)
			m.set_shader_parameter(&"uOut", out_c)
			m.set_shader_parameter(&"uAmt", minf(1.0, burn * 1.3) * sputter)
		var dm: Array = pl.diamonds
		for i in dm.size():
			var d: MeshInstance3D = dm[i]
			var ph := fmod(clock * 5.0 + i / 5.0 + idx * .3, 1.0)
			d.position.y = -.2 - ph * 1.5 * L
			d.scale = Vector3(1.0 - ph * .5, 1.7 * (1.0 - ph * .6), 1.0 - ph * .5)
			MsKit.tint(d, P_IN.lerp(hot_c, ph), (1.0 - ph) * burn * .9)
		var gl: MeshInstance3D = pl.glow
		gl.scale = Vector3.ONE * ((.8 + .25 * sin(clock * 40.0 + idx)) * burn * (sputter if low_f else 1.0) * 2.4)
		MsKit.tint(gl, hot_c)
	# events: ignition burst, dry cough, landing puff
	if jetting and not was_jet:      # every relight punches the pack down a touch
		kick_v -= 1.6
	if j_on and not was_on:
		var b := (_tip(noz[0]) + _tip(noz[1])) * .5
		_ring(b, .3, 3.4, .5, hot_c, .95)
		_ring(b + Vector3(0, -.15, 0), .2, 2.0, .35, P_IN, .8)
		_ring(b + Vector3(0, -.4, 0), .1, 4.8, .7, out_c, .55)
		for _i in 70:
			var a := randf() * TAU
			var s := 3.0 + randf() * 8.0
			sparks.emit(b.x, b.y, b.z, {"vx": cos(a) * s, "vy": -2.0 - randf() * 6.0, "vz": sin(a) * s, "life": .35 + randf() * .5, "size": .22, "grow": -.9, "col": 0xe8fdff, "drag": 2.2, "alpha": 1.0, "fade": .02})
		for _i in 14:
			var a := randf() * TAU
			smoke.emit(b.x, b.y, b.z, {"vx": cos(a) * 2.2, "vy": -.4, "vz": sin(a) * 2.2, "life": .9, "size": .35, "grow": 3.9, "col": 0x808c99, "alpha": .55, "drag": 2.5, "fade": .05})
	if dry and not was_dry:
		for n: Dictionary in noz:
			var v := _tip(n)
			for _i in 18:
				smoke.emit(v.x, v.y, v.z, {"vx": (randf() - .5) * 3.0, "vy": -1.0 - randf() * 2.0, "vz": (randf() - .5) * 3.0, "life": 1.1, "size": .3, "grow": 3.7, "col": 0x2e2e33, "alpha": .8, "drag": 2.0, "fade": .05})
			for _i in 14:
				sparks.emit(v.x, v.y, v.z, {"vx": (randf() - .5) * 5.0, "vy": -1.0 - randf() * 4.0, "vz": (randf() - .5) * 5.0, "life": .5, "size": .16, "grow": -.9, "col": 0xffa030, "drag": 1.0, "alpha": 1.0, "fade": .02})
	if not j_on and was_on:      # landed: ground ring and dust
		_ring(Vector3(P.x, P.y + .06, P.z), .5, 4.2, .55, P_MID, .8)
		_ring(Vector3(P.x, P.y + .08, P.z), .3, 2.6, .4, P_IN, .7)
		for i in 22:
			var a := i / 22.0 * TAU
			var s := 2.0 + randf() * 2.0
			smoke.emit(P.x, P.y + .1, P.z, {"vx": cos(a) * s, "vy": .4, "vz": sin(a) * s, "life": .8, "size": .3, "grow": 3.0, "col": 0x73808c, "alpha": .45, "drag": 3.0, "fade": .05})
	was_on = j_on
	was_dry = dry
	was_jet = jetting
	# continuous exhaust: bright sparks, long-lived plasma blobs that stay in the world (the trail), dark smoke
	if burn > .2:
		emit_acc += dt * 240.0 * burn
		smoke_acc += dt * 55.0 * burn
		for n: Dictionary in noz:
			var v := _tip(n)
			for _i in int(emit_acc / 2.0):
				var a := randf() * TAU
				var sp := randf() * 2.2
				var hs := randf() < .4
				sparks.emit(v.x + (randf() - .5) * .08, v.y - randf() * .3, v.z + (randf() - .5) * .08, {"vx": cos(a) * sp, "vy": -(7.0 + randf() * 9.0) + P.vy * .3, "vz": sin(a) * sp, "life": .25 + randf() * .3 if hs else .5 + randf() * .6, "size": .2 if hs else .3, "grow": -.85 if hs else .8, "col": 0xe8fdff if hs else 0x3ee3ff, "drag": .6 if hs else 1.4, "alpha": 1.0 if hs else .35, "fade": .02})
			for _i in int(smoke_acc / 2.0):
				smoke.emit(v.x, v.y - .3, v.z, {"vx": (randf() - .5) * 1.6, "vy": -2.0 - randf() * 3.0, "vz": (randf() - .5) * 1.6, "life": 1.0 + randf() * .7, "size": .25, "grow": 3.4, "col": 0x1a1414 if low_f else 0x6b8094, "alpha": .75 if low_f else .4, "drag": 1.3, "fade": .05})
		emit_acc = fmod(emit_acc, 2.0)
		smoke_acc = fmod(smoke_acc, 2.0)
	# a tiny shockring pulse down the plume while burning (energy rippling off the engines)
	if burn > .5 and int(clock * 9.0) != int((clock - dt) * 9.0):
		var b := (_tip(noz[0]) + _tip(noz[1])) * .5
		_ring(b + Vector3(0, -.5, 0), .2, 1.4, .35, hot_c, .45)
	for r in rings:
		if not r.m.visible:
			continue
		r.t += dt
		var u := r.t / r.dur
		if u >= 1.0:
			r.m.visible = false
			continue
		var e := 1.0 - (1.0 - u) * (1.0 - u)
		r.m.scale = Vector3.ONE * lerpf(r.r0, r.r1, e)
		MsKit.opa(r.m, r.a * (1.0 - u))
	sparks.update(dt)
	smoke.update(dt)
