class_name VhPrison
extends RefCounted
## VISITING HOURS: the moving parts of Saltmarsh Correctional (JS prison.js): the four tower searchlights, tower four's real light, the warden's office window (a painted silhouette scene), the steam off the drain.

const FIELD: Array = [[[118.0, 818.0], [158.0, 832.0], [186.0, 862.0], [196.0, 892.0], [166.0, 878.0], [138.0, 858.0], [116.0, 842.0]], [[212.0, 838.0], [250.0, 856.0], [236.0, 892.0], [200.0, 905.0], [192.0, 870.0]], [], [[110.0, 930.0], [128.0, 958.0], [96.0, 1000.0], [82.0, 960.0]]]


class Beam:
	var node: Node3D
	var mat: ShaderMaterial
	var lamp := Vector3.ZERO
	var four := false
	var base := 0.0
	var i := 0
	var t := 0.0
	var aim := Vector3.ZERO
	var want := Vector3.ZERO
	var len_ := 340.0
	var u := 0.0
	var lock := 0.0
	var spot_r := 0.0
	var _hot := false


class Puff:
	var node: Node3D
	var mi: MeshInstance3D
	var base := 1.0      # the width the export baked into its mesh
	var u := 0.0
	var r := 0.0


var lv: ExportedLevel
var beams: Array[Beam] = []
var mode := "hill"
var flash := 0.0
var spot: SpotLight3D
var hill: Array[Vector3] = []
var hut_lamp: Dictionary = {}
var wall_lamps: Array = []
var pad_hole: Dictionary = {}
var puffs: Array[Puff] = []
var steam_x := 0.0
var steam_z := 0.0
var nv_k := 0.0
var office := OfficeScene.new()


static func v3(d: Variant) -> Vector3:
	if d is Dictionary:
		return Vector3(float(d.x), float(d.y), float(d.z))
	if d is Array:
		return Vector3(float(d[0]), float(d[1]), float(d[2]))
	return Vector3.ZERO


func _init(p_lv: ExportedLevel, data: Dictionary) -> void:
	lv = p_lv
	wall_lamps = data.get("wallLamps", [])
	hut_lamp = data.get("hutLamp", {})
	pad_hole = data.get("padHole", {})
	var list: Array = data.get("beams", [])
	for i in list.size():
		var d: Dictionary = list[i]
		var b := Beam.new()
		b.i = i
		b.node = VhKit.one(lv, "vh-beam-%d" % i)
		b.lamp = v3(d.lamp)
		b.four = bool(d.four)
		b.base = float(d.base)
		b.t = i * 1.7
		b.u = i * 0.3
		b.len_ = float(d.get("len", 340.0))
		for mi in VhKit.meshes(b.node):      # (each beam goes amber on its own)
			var m := mi.get_active_material(0)
			if m is ShaderMaterial:
				b.mat = (m as ShaderMaterial).duplicate() as ShaderMaterial
				mi.material_override = b.mat
			mi.extra_cull_margin = 400.0
		beams.append(b)
	spot = VhKit.light(lv, "vh-tower-spot") as SpotLight3D
	var mid := VhLayout.at(VhLayout.track, VhLayout.track.len_ * 0.45)
	hill = [Vector3(mid.x - 30.0, 4.0, mid.z - 10.0), Vector3(mid.x + 26.0, 10.0, mid.z + 30.0)]
	# the steam: the boiler room's blowdown runs out through this drain, warm water into a cold canal, and it smokes. A pale column rising over the embankment, leaning with the wind: the one thing that gives the drain away from the hill
	var at: Array = (data.get("steam", {}) as Dictionary).get("at", [0.0, 0.0, 0.0])
	steam_x = float(at[0]) + 0.9
	steam_z = float(at[2])
	var puff_mat := ShaderMaterial.new()
	puff_mat.shader = load("res://levels/visiting_hours/vh_puff.gdshader")
	var nodes: Array = lv.node_named("vh-steam")
	for i in nodes.size():
		var p := Puff.new()
		p.node = nodes[i]
		for mi in VhKit.meshes(p.node):
			p.mi = mi
			p.base = maxf(mi.mesh.get_aabb().size.x, 0.001)
			mi.material_override = puff_mat
			mi.extra_cull_margin = 40.0
		p.u = float(i) / float(nodes.size())
		p.r = randf()
		puffs.append(p)
	office.build(lv, VhLayout.office())


## its own opacity: a soft sprite with normal blending is exported on a billboard material
static func _own(n: Node3D) -> Material:
	for mi in VhKit.meshes(n):
		var m := mi.get_active_material(0)
		if m != null:
			var d := m.duplicate() as Material
			mi.material_override = d
			return d
	return null


static func _set_puff(m: Material, c: Color, a: float) -> void:
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter(&"opacity", a)
		var l := c.srgb_to_linear()
		(m as ShaderMaterial).set_shader_parameter(&"col", Vector3(l.r, l.g, l.b))
	elif m is StandardMaterial3D:
		(m as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, a)


static func _loop_at(pts: Array, u: float) -> Vector2:
	var n := pts.size()
	var k := fposmod(u, float(n))
	var i := int(floor(k))
	var f := k - i
	var a: Array = pts[i]
	var b: Array = pts[(i + 1) % n]
	var e := f * f * (3.0 - 2.0 * f)
	return Vector2(float(a[0]) + (float(b[0]) - float(a[0])) * e, float(a[1]) + (float(b[1]) - float(a[1])) * e)


## lock = Vector3 or null: tower four (or lock_beam) points at it (it found you)
func update(dt: float, _time: float, lock: Variant, lock_beam: Beam, draw_office: bool) -> void:
	for b in beams:
		b.t += dt
		var locked := lock != null and (lock_beam == b if lock_beam != null else b.four)
		if locked:
			var lp: Vector3 = lock
			b.want = Vector3(lp.x, lp.y + 0.6, lp.z)
		elif mode == "field" and not (FIELD[b.i] as Array).is_empty():
			b.u += dt * 0.11
			var q := _loop_at(FIELD[b.i], b.u)
			b.want = Vector3(q.x, 0.0, q.y)
		elif b.four:
			var u := 0.5 + 0.5 * sin(b.t * 0.32)
			var w := sin(b.t * 0.71) * 0.5 + 0.5
			b.want = hill[0].lerp(hill[1], u)
			b.want.y += w * 4.0
		else:
			var a := b.base + sin(b.t * 0.27) * 0.9
			b.want = Vector3(b.lamp.x + sin(a) * 180.0, 0.0, b.lamp.z + cos(a) * 180.0)
		if b.aim.length_squared() == 0.0:
			b.aim = b.want
		b.aim = b.aim.lerp(b.want, 1.0 - exp(-dt * (2.4 if locked else 1.6)))
		var v := b.aim - b.lamp
		var ln := minf(b.len_, v.length() + 8.0)
		var s := ln / 260.0 * 1.15
		if v.length_squared() > 1e-6:
			b.node.global_transform = Transform3D(Basis.looking_at(v.normalized(), Vector3.UP, true).scaled_local(Vector3(s, s, ln)), b.lamp)
		b.spot_r = (v.length() / 260.0) * 1.15 * 16.0 * 0.72      # the lit patch on the ground the beam is pointing at (radius, m)
		var hot := b.lock > 0.5
		if hot != b._hot and b.mat != null:
			b._hot = hot
			var c := MsKit.lin(0xffb050 if hot else 0xdfe8ff)
			b.mat.set_shader_parameter(&"uCol", Vector3(c.r, c.g, c.b))
		if b.four and spot != null:
			spot.look_at(b.aim if not b.aim.is_equal_approx(spot.global_position) else b.aim + Vector3.DOWN)
			spot.light_energy = 1.5 / PI
	office.update(dt, draw_office)
	_steam(dt)


func _steam(dt: float) -> void:
	# the goggles amplify it like everything else: brighter and thicker, so it still stands out of the green
	nv_k += ((1.0 if Game.night_vision.on else 0.0) - nv_k) * minf(1.0, dt * 4.0)
	var lit := 1.0 + nv_k * 2.4
	var base := MsKit.srgb(0xd6d4cc)
	var cl := base.srgb_to_linear()
	cl = Color(cl.r * lit, cl.g * lit, cl.b * lit)
	for p in puffs:
		p.u += dt / 9.0
		if p.u > 1.0:
			p.u -= 1.0
			p.r = randf()
		var u := p.u
		var h := u * 11.0
		var lean := h * h * 0.045
		p.node.global_position = Vector3(steam_x - 1.4 - u * 2.2 - lean * 0.6 + sin(p.r * 9.0 + u * 4.0) * 0.4, 0.8 + h, steam_z + lean + cos(p.r * 7.0 + u * 3.0) * 0.5)
		p.node.scale = Vector3.ONE * ((2.6 + u * 9.0 + p.r * 1.5) / p.base)
		if p.mi != null:
			p.mi.set_instance_shader_parameter(&"col", Vector3(cl.r, cl.g, cl.b))
			p.mi.set_instance_shader_parameter(&"opacity", minf(1.0, minf(1.0, u * 6.0) * pow(1.0 - u, 1.2) * (0.8 + flash * 0.3) * (1.0 + nv_k * 0.6)))


## the warden's office window: a painted scene on the lit pane. state 'beat' (the warden circles Fenn tied in a chair and hits him; a bulb swings), 'window' (he walks up to the glass and stands looking out at the hill), 'blind' (he pulls the blind down), 'closed' (light through the slats).
class OfficeScene:
	var canvas: VhKit.Canvas
	var state := "beat"
	var t := 0.0
	var st := 0.0
	var acc := 0.0
	var blind := 0.0
	var hit := 0.0
	var glow_tex: GradientTexture2D

	func build(lv: ExportedLevel, _o: Dictionary) -> void:
		canvas = VhKit.Canvas.new(256, 128, _draw)
		lv.add_child(canvas)
		var g := Gradient.new()
		g.set_color(0, Color.WHITE)
		g.set_color(1, Color.BLACK)
		glow_tex = GradientTexture2D.new()
		glow_tex.gradient = g
		glow_tex.fill = GradientTexture2D.FILL_RADIAL
		glow_tex.fill_from = Vector2(0.5, 0.5)
		glow_tex.fill_to = Vector2(1.0, 0.5)
		glow_tex.width = 128
		glow_tex.height = 128
		var pane := VhKit.one(lv, "vh-office-pane")
		for mi in VhKit.meshes(pane):
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_texture = canvas.get_texture()
			m.disable_fog = true
			mi.material_override = m

	func set_state(s: String) -> void:
		if state != s:
			state = s
			st = 0.0
		blind = 1.0 if s == "closed" else (blind if s == "blind" else 0.0)      # (a checkpoint can wind it back)

	func update(dt: float, draw: bool) -> void:
		t += dt
		st += dt
		hit -= dt
		acc += dt
		if state == "window" and st > 6.5:
			set_state("blind")
		if state == "blind" or state == "closed":
			blind = minf(1.0, blind + dt * (0.55 if state == "blind" else 1.0))
			if blind >= 1.0:
				state = "closed"
		if draw and acc > 1.0 / 20.0:
			acc = 0.0
			canvas.redraw()

	func _ellipse(c: Control, x: float, y: float, rx: float, ry: float, col: Color, rot: float = 0.0) -> void:
		c.draw_set_transform(Vector2(x, y), rot, Vector2(rx, ry))
		c.draw_circle(Vector2.ZERO, 1.0, col)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# the warden: big shoulders, a bald head, rings when the fist comes up
	func _man(c: Control, cx: float, base: float, s: float, arm: float, col: Color) -> void:
		_ellipse(c, cx, base - 30.0 * s, 22.0 * s, 30.0 * s, col)
		c.draw_circle(Vector2(cx, base - 66.0 * s), 11.0 * s, col)
		if arm != 0.0:
			c.draw_set_transform(Vector2(cx + 16.0 * s, base - 46.0 * s), arm, Vector2.ONE)
			c.draw_rect(Rect2(0.0, -5.0 * s, 34.0 * s, 10.0 * s), col)
			c.draw_circle(Vector2(34.0 * s, 0.0), 7.0 * s, col)
			c.draw_rect(Rect2(30.0 * s, -3.0 * s, 3.0, 3.0), Color(1.0, 0.86, 0.47, 0.9))
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Fenn: a toad in a chair, tied, his tie the one pale thing
	func _fenn(c: Control, cx: float, base: float, nod: float, col: Color) -> void:
		c.draw_rect(Rect2(cx - 14.0, base - 34.0, 4.0, 34.0), col)
		c.draw_rect(Rect2(cx - 14.0, base - 18.0, 28.0, 4.0), col)
		c.draw_rect(Rect2(cx + 10.0, base - 18.0, 4.0, 18.0), col)
		_ellipse(c, cx, base - 30.0, 13.0, 15.0, col)
		_ellipse(c, cx + nod * 6.0, base - 52.0 + nod * 3.0, 14.0, 10.0, col, nod * 0.4)
		c.draw_colored_polygon(PackedVector2Array([Vector2(cx - 2.0, base - 40.0), Vector2(cx + 2.0, base - 40.0), Vector2(cx + 3.0, base - 24.0), Vector2(cx, base - 21.0), Vector2(cx - 3.0, base - 24.0)]), Color(0.9, 0.86, 0.78, 0.55))

	func _draw(c: Control) -> void:
		var bulb := 128.0 + sin(t * 2.3) * 16.0
		var k := 0.82 + 0.18 * sin(t * 2.3 + 1.0)
		var inner := Color(k, 222.0 / 255.0 * k, 160.0 / 255.0 * k)
		var outer := Color(150.0 / 255.0 * k, 92.0 / 255.0 * k, 52.0 / 255.0 * k)
		c.draw_rect(Rect2(0.0, 0.0, 256.0, 128.0), outer)
		c.draw_texture_rect(glow_tex, Rect2(bulb - 170.0, 40.0 - 170.0, 340.0, 340.0), false, Color(inner.r - outer.r, inner.g - outer.g, inner.b - outer.b, 1.0))
		c.draw_line(Vector2(128.0, 0.0), Vector2(bulb, 18.0), Color(0.12, 0.06, 0.02, 0.9), 1.0)
		c.draw_circle(Vector2(bulb, 21.0), 4.0, Color("#fff6d0"))
		var dark := Color(20.0 / 255.0, 10.0 / 255.0, 4.0 / 255.0, 0.88)
		if state == "beat":
			var cyc := fmod(t, 5.5)
			var wx := 70.0 + sin(cyc * 1.6) * 26.0 if cyc < 3.0 else 128.0
			var punch := cyc > 3.6 and cyc < 4.1
			if punch and hit <= 0.0:
				hit = 0.6
			_fenn(c, 168.0, 124.0, sin(hit * 9.0) * 0.8 if hit > 0.0 else 0.15 * sin(t), dark)
			_man(c, wx, 128.0, 1.0, -0.1 if punch else (-1.2 if cyc > 3.0 else 0.9), dark)
		else:
			var u := minf(1.0, st / 2.2)
			var s := 1.0 + u * 1.15
			var cx := 128.0 + (1.0 - u) * -50.0
			_fenn(c, 178.0, 124.0, 0.5, Color(20.0 / 255.0, 10.0 / 255.0, 4.0 / 255.0, 0.6))
			_man(c, cx, 128.0 + u * 70.0, s, 0.0, Color(14.0 / 255.0, 7.0 / 255.0, 3.0 / 255.0, 0.88 + u * 0.08))
			if u > 0.9:      # a cigar end, glowing
				c.draw_circle(Vector2(cx + 9.0 * s, 128.0 + u * 70.0 - 62.0 * s), 2.4, Color(1.0, 0.55, 0.235, 0.6 + 0.4 * sin(t * 3.0)))
		if blind > 0.0:
			var hgt := 128.0 * blind
			var y := 0.0
			while y < hgt:
				c.draw_rect(Rect2(0.0, y, 256.0, 5.6), Color(40.0 / 255.0, 24.0 / 255.0, 12.0 / 255.0, 0.97))
				y += 7.0
