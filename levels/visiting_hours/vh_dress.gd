class_name VhDress
extends RefCounted
## VISITING HOURS: the far dressing's and the claims floor's small moving things (JS dressing.js, furnish.js update): the fog rings that follow the camera, blinking masts, lamps on their last legs, the shack's TV, the road's cat's-eyes, the mist cards, and the staff room's TV showing FOINT ARENA.

class Flick:
	var sp: Node3D
	var mat: Material
	var pl: Light3D
	var base := 0.0
	var soft := false
	var t := 0.0
	var on := true


var lv: ExportedLevel
var rings: Array = []
var blink: Array[Material] = []
var flick: Array[Flick] = []
var tv_mesh: StandardMaterial3D
var tv_light: Light3D
var eyes: ShaderMaterial
var mist: ShaderMaterial
var tv: VhKit.Canvas
var tv_floor: Node3D
var tv_acc := 0.0
var tv_k := 0.0


func _init(p_lv: ExportedLevel, info: Dictionary, f2: Node3D) -> void:
	lv = p_lv
	rings = lv.node_named("vh-ring")
	for n: Node3D in lv.node_named("vh-blink"):
		blink.append(VhPrison._own(n))
	var list: Array = info.get("flickerInfo", [])
	for i in list.size():
		var f := Flick.new()
		f.sp = VhKit.one(lv, "vh-flick-s-%d" % i)
		f.mat = VhPrison._own(f.sp)
		f.pl = VhKit.light(lv, "vh-flick-l-%d" % i)
		f.base = float(list[i].base)
		f.soft = bool(list[i].soft)
		flick.append(f)
	var own := VhKit.own_std(VhKit.one(lv, "vh-shack-tv"))
	tv_mesh = own[0] if not own.is_empty() else null
	tv_light = VhKit.light(lv, "vh-shack-tvl")
	eyes = lv.shader_ports.mats.get("shader_6c1b3c#0")
	mist = lv.shader_ports.mats.get("shader_ea8496#0")
	# the staff room's TV: FOINT ARENA live
	tv_floor = f2
	tv = VhKit.Canvas.new(128, 96, _draw_tv)
	lv.add_child(tv)
	for mi in VhKit.meshes(VhKit.one(lv, "vh-tv")):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = tv.get_texture()
		mi.material_override = m


func _draw_tv(g: Control) -> void:
	var k := tv_k
	g.draw_rect(Rect2(0.0, 0.0, 128.0, 96.0), Color("#20140c"))
	g.draw_rect(Rect2(14.0, 50.0, 100.0, 32.0), Color("#c8a050"))
	for yy: float in [46.0, 40.0]:
		g.draw_line(Vector2(10.0, yy), Vector2(118.0, yy), Color("#e04030"), 2.0)
	var hit := sin(k * 2.1) > 0.7
	g.draw_rect(Rect2(44.0 + sin(k) * 6.0 + (6.0 if hit else 0.0), 30.0, 14.0, 26.0), Color("#e04020"))
	g.draw_rect(Rect2(70.0 - sin(k * 1.3) * 5.0, 28.0 + (4.0 if hit else 0.0), 16.0, 28.0), Color("#e04020"))
	g.draw_rect(Rect2(0.0, 0.0, 128.0, 14.0), Color("#ff7a20"))
	g.draw_string(ThemeDB.fallback_font, Vector2(6.0, 10.0), "FOINT ARENA  LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	for _i in 300:
		g.draw_rect(Rect2(randf() * 128.0, randf() * 96.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, randf() * 0.12))


func update(dt: float, t: float, flash: float, fog_col: Color, cam: Vector3, car_on: bool, car_x: float, car_z: float, car_yaw: float) -> void:
	for m: Node3D in rings:
		m.global_position = Vector3(cam.x, 0.0, cam.z)
	if eyes != null:
		eyes.set_shader_parameter(&"uOn", 1.0 if car_on else 0.0)
		eyes.set_shader_parameter(&"uFlash", flash)
		eyes.set_shader_parameter(&"uCar", Vector3(car_x, 0.0, car_z))
		eyes.set_shader_parameter(&"uFwd", Vector2(sin(car_yaw), cos(car_yaw)))
	var bo := (1.0 if sin(t * 2.6) > 0.2 else 0.08) * (1.0 - flash * 0.5)
	for b in blink:
		_op(b, bo)
	for f in flick:
		f.t -= dt
		if f.t <= 0.0:
			f.t = randf_range(0.05, 0.5) if f.soft else randf_range(0.03, 0.25)
			f.on = randf() > 0.08 if f.soft else randf() > 0.45
		var k := 1.0 if f.on else (0.55 if f.soft else 0.05)
		if f.pl != null:
			f.pl.light_energy = f.base * k / PI
		_op(f.mat, k)
	var k2 := 0.5 + 0.5 * absf(sin(t * 7.3) * sin(t * 2.1 + 1.0))
	if tv_mesh != null:
		tv_mesh.albedo_color = Color(0.35 * k2, 0.55 * k2, k2)
	if tv_light != null:
		tv_light.light_energy = 4.0 * k2 / PI
	if mist != null:
		var c := fog_col.srgb_to_linear()
		mist.set_shader_parameter(&"uCol", Vector3(c.r * 1.15 + flash * 0.2, c.g * 1.15 + flash * 0.2, c.b * 1.15 + flash * 0.2))
	# the staff room's TV
	if tv_floor.visible:
		tv_acc += dt
		if tv_acc >= 0.1:
			tv_acc = 0.0
			tv_k = t * 3.0
			tv.redraw()


static func _op(m: Material, a: float) -> void:
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter(&"opacity", a)
	elif m is StandardMaterial3D:
		(m as StandardMaterial3D).albedo_color.a = a
