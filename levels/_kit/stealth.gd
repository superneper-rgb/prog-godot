class_name StealthKit
extends RefCounted
## STEALTH (kit, JS levels/_kit/stealth.js): guards that have to notice you before they fight. Forgiving and readable (Mark of the Ninja's cones, Metal Gear's "?"); works on any Robot-based enemy, built and tuned on the goons (kind goon, GOINT guards with torches: r.beam).
##   sight      each guard's view is painted on the ground: a fan clipped by walls, faint white -> amber as he gets suspicious -> red. Seeing you fills his SUSPICION (faster close, lit, standing, moving, in his torch beam; slower crouched in the dark). Over 35 % he stops, turns to where he saw you, walks over to look (gives up if he cannot get there), looks left and right, then walks back to his post; full (after at least a beat of "?") = ALARM. Out of sight it drains.
##   witnesses  a guard who sees a man go down (or later finds the body) gets REACT_T seconds of "!" (a ring fills) and then raises the alarm, unless he goes down first.
##   hearing    noise(x, y, z, r, loud): shots, glass, a fight. Anyone in range turns and comes to look (loud = straight to alarm).
##   takedown   from behind, unseen, within reach: drops him without a sound.
## An alarm is never game over by itself: the level decides what it means (on_alarm). Marks over heads only show for guards you could actually see. While a guard is unaware his own _look is muted (Robot.look_muted) and his ally alerts are blocked (ally_cd). A post is a one-spot patrol.

const REACT_T := 2.3
const SUS_LOOK := 0.35
const CONE := 0.85
const RAYS := 11
const EYE := 1.55
const L_SUS := ["Hm?", "Hello?", "Who's there?", "That you, Dale?", "...Rats again."]
const L_LOOK := ["I'm coming to look.", "Hold on.", "Somebody there?"]
const L_CALM := ["Storm.", "Nothing.", "Probably the storm.", "Imagining things."]
const L_BODY := ["MAN DOWN!", "Oh no. Oh no.", "Is he-- HEY!"]
const L_ALARM := ["INTRUDER!", "Contact!", "There! THERE!"]
const AMB := Color(1.0, 0.72, 0.25)
const RED := Color(1.0, 0.18, 0.1)
const WHITE := Color(0.75, 0.85, 1.0)


## The mark over a guard's head: a ring that fills round a "?" or "!", his line under it.
class Mark:
	extends Control
	var fill := 0.0
	var red := false
	var glyph := "?"
	var line := ""
	var font: Font

	func _draw() -> void:
		var c := Color("#ff4a3a") if red else Color("#ffb84a")
		var o := Vector2(17.0, 17.0)
		draw_circle(o, 15.0, Color(0.0, 0.0, 0.0, 0.35))
		draw_arc(o, 15.0, 0.0, TAU, 32, Color(c, 0.3), 3.0)
		if fill > 0.0:
			draw_arc(o, 15.0, -PI / 2.0, -PI / 2.0 + TAU * fill, 32, c, 3.0)
		draw_string(font, Vector2(0.0, 26.0), glyph, HORIZONTAL_ALIGNMENT_CENTER, 34.0, 26, c)
		if line != "":
			draw_string(font, Vector2(-100.0, 50.0), line, HORIZONTAL_ALIGNMENT_CENTER, 234.0, 15, Color(c, 0.9))


class Guard:
	var r: Robot
	var o: Dictionary
	var sus := 0.0
	var mode := "calm"
	var react := 0.0
	var react_why := ""
	var look: Variant = null
	var look_t := 0.0
	var inv_t := 0.0
	var line := ""
	var line_t := 0.0
	var was_dead := false
	var range_ := 19.0
	var cone_t := 0.0
	var alarm_t := 0.0
	var patrol0: PackedVector2Array
	var returning := false
	var going_look := false
	var stuck_look := false
	var best_d := 0.0
	var prog_t := 0.0
	var sus_t := 0.0
	var scan_base := NAN
	var scan_t := 0.0
	var vis_t := 0.0
	var in_view := true
	var off_view := false
	var hold := false
	var cone: MeshInstance3D
	var cone_mesh: ImmediateMesh
	var mark: Mark


var root: Node3D
var world: World
var guards: Array[Guard] = []
var bodies: Array = []
var cones := false
var lit_at := Callable()
var on_alarm := Callable()
var _layer: CanvasLayer
var _font: Font
var _cone_mat: ShaderMaterial


func _init(p_root: Node3D, p_world: World) -> void:
	root = p_root
	world = p_world
	_layer = CanvasLayer.new()
	_layer.layer = 3
	root.add_child(_layer)
	_font = load("res://assets/fonts/VT323-Regular.ttf") if ResourceLoader.exists("res://assets/fonts/VT323-Regular.ttf") else ThemeDB.fallback_font
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;\ninstance uniform vec4 tint = vec4(1.0);\nvoid fragment() { float r = COLOR.r; float a = tint.a * (1.0 - smoothstep(0.55, 1.0, r)) * (0.55 + 0.45 * smoothstep(0.0, 0.2, r)); ALBEDO = tint.rgb * a; ALPHA = 1.0; }\n"
	_cone_mat = ShaderMaterial.new()
	_cone_mat.shader = sh


## a guard joins: r = the spawned enemy; o = {post: [x, z, yaw], patrol: [[x, z], [x, z]] or null, range (m), role}
func add(r: Robot, o: Dictionary = {}) -> Guard:
	var g := Guard.new()
	g.r = r
	g.o = o
	g.range_ = o.get("range", 19.0)
	g.cone_t = randf() * 0.15
	var pat := PackedVector2Array()      # (a post is a one-spot patrol: the Robot's return state walks back to patrol[0], so it must never be empty)
	var op: Variant = o.get("patrol")
	if op != null:
		for p: Array in op:
			pat.append(Vector2(p[0], p[1]))
	else:
		pat = PackedVector2Array([Vector2(r.x, r.z), Vector2(r.x, r.z)])
	r.patrol = pat
	r.wp = 0
	r.pause = 0.0
	if o.has("post"):
		r.yaw = o.post[2]
	g.patrol0 = pat.duplicate()
	r.look_muted = true      # unaware: the meter decides, not the stock instant spot
	r.ally_cd = 1e9
	r.known = null
	r.set_(&"idle")
	r.state_t = 0.0
	g.cone = MeshInstance3D.new()
	g.cone_mesh = ImmediateMesh.new()
	g.cone.mesh = g.cone_mesh
	g.cone.material_override = _cone_mat
	g.cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.cone.extra_cull_margin = 60.0
	g.cone.visible = false
	root.add_child(g.cone)
	g.mark = Mark.new()
	g.mark.font = _font
	g.mark.size = Vector2(34.0, 34.0)
	g.mark.visible = false
	g.mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(g.mark)
	guards.append(g)
	return g


func _say(g: Guard, list: Array) -> void:
	g.line = list[randi() % list.size()]
	g.line_t = 2.2


func _rebuild_cone(g: Guard) -> void:
	var r := g.r
	var y := r.y + 0.08
	var m := g.cone_mesh
	m.clear_surfaces()
	m.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var last := Vector3.ZERO
	for i in RAYS + 1:
		var a := r.yaw - CONE + 2.0 * CONE * i / RAYS
		var dx := sin(a)
		var dz := cos(a)
		var hit: float = world.ray_clear(r.x, r.y + 1.0, r.z, dx, 0.0, dz, g.range_, 0.05)
		var L := maxf(0.3, minf(g.range_, hit))
		var p := Vector3(r.x + dx * L, y, r.z + dz * L)
		if i > 0:
			m.surface_set_color(Color(0.0, 0.0, 0.0))
			m.surface_add_vertex(Vector3(r.x, y, r.z))
			m.surface_set_color(Color(1.0, 0.0, 0.0))
			m.surface_add_vertex(p)
			m.surface_set_color(Color(1.0, 0.0, 0.0))
			m.surface_add_vertex(last)
		last = p
	m.surface_end()


## is the point inside this guard's torch beam (goint_guard: r.beam from the dress, the cone in world space)?
func in_beam(g: Guard, x: float, y: float, z: float) -> bool:
	var b: Variant = g.r.get(&"beam")
	if not b is Dictionary or (b as Dictionary).is_empty() or not b.on or g.r.dead:
		return false
	var vx: float = x - float(b.x)
	var vy: float = y - float(b.y)
	var vz: float = z - float(b.z)
	var d := sqrt(vx * vx + vy * vy + vz * vz)
	if d > float(b.range) * 1.2 or d < 0.2:
		return false
	return (vx * float(b.dx) + vy * float(b.dy) + vz * float(b.dz)) / d > cos(float(b.angle) * 1.15)


## can this guard see P right now (cone + range + LOS)? returns the fill rate (0 = no)
func _see_rate(g: Guard, P: Player) -> float:
	var r := g.r
	var dx := P.x - r.x
	var dz := P.z - r.z
	var d := U.hyp(dx, dz)
	if P.dead or absf(P.y - r.y) > 9.0:
		return 0.0
	var torch := in_beam(g, P.x, P.y + (0.7 if P.crouching else 1.1), P.z)
	var lit: float = lit_at.call(P.x, P.y, P.z) if lit_at.is_valid() else 1.0
	var crouch := 0.62 if P.crouching else 1.0
	var rng := maxf(g.range_ * lit * crouch, d + 0.5 if torch else 0.0)
	if d > rng:
		return 0.0
	var off := absf(U.wrap_angle(atan2(dx, dz) - r.yaw))
	if d > 2.2 and off > CONE * (1.25 if g.mode == "sus" else 1.0):
		return 0.0
	var oy := r.y + EYE
	var ty := P.y + (0.8 if P.crouching else 1.2)
	var dy := ty - oy
	var L := sqrt(dx * dx + dy * dy + dz * dz)
	if L == 0.0:
		L = 1.0
	if world.ray_clear(r.x, oy, r.z, dx / L, dy / L, dz / L, L, 0.04) < L - 0.5:
		return 0.0
	var near := 1.0 - d / rng
	return minf(1.6, (0.32 + 1.6 * near * near) * (1.3 if P.vx * P.vx + P.vz * P.vz > 4.0 else 0.85) * (1.5 if lit > 1.3 else 1.0) * (2.0 if torch else 1.0))      # (full in ~1 s at the closest, ~3 s at the edge)


func can_see_point(g: Guard, x: float, y: float, z: float, max_d: float = 48.0, cone_: float = 1.25) -> bool:
	var r := g.r
	var dx := x - r.x
	var dz := z - r.z
	var d := U.hyp(dx, dz)
	if d > max_d:
		return false
	if d > 2.0 and absf(U.wrap_angle(atan2(dx, dz) - r.yaw)) > cone_:
		return false
	var oy := r.y + EYE
	var dy := y - oy
	var L := sqrt(dx * dx + dy * dy + dz * dz)
	if L == 0.0:
		L = 1.0
	return world.ray_clear(r.x, oy, r.z, dx / L, dy / L, dz / L, L, 0.04) >= L - 0.6


func alarm(g: Guard, why: String, P: Variant) -> void:
	if g.mode == "alarm" or g.r.dead:
		return
	g.mode = "alarm"
	g.alarm_t = 0.0
	g.react = 0.0
	g.sus = 1.0
	_say(g, L_ALARM)
	_off_break(g.r)
	g.r.look_muted = false
	if on_alarm.is_valid():
		on_alarm.call(g, why, P)


func _off_break(r: Robot) -> void:
	if r.get(&"on_break") != null:
		r.set(&"on_break", false)


## put a guard into the fight (the level calls this from on_alarm when the alarm means shooting)
func engage(g: Guard, P: Variant) -> void:
	var r := g.r
	if r.dead:
		return
	r.ally_cd = 0.0
	r.patrol = g.patrol0.duplicate()
	if P != null:
		r._know(P.x, P.z)
	r.seen_t = 0.0
	r.alert_why = "stealth"
	r.set_(&"alert")
	if r.E != null and r.E.barks != null:
		r.E.barks.say(r, "alert")


## calm a guard back down (hunt over / checkpoint): back to his post or route
func calm(g: Guard) -> void:
	var r := g.r
	if r.dead:
		return
	g.mode = "calm"
	g.sus = 0.0
	g.react = 0.0
	g.look = null
	g.going_look = false
	g.stuck_look = false
	g.scan_base = NAN
	r.look_muted = true
	r.ally_cd = 1e9
	r.known = null
	r.patrol = g.patrol0.duplicate()
	r.wp = 0
	r.pause = 0.5
	r.set_(&"idle")
	# back to work: a guard with a post walks back to it and turns to his old heading (smoothly, in update); a patrol just picks his route up again
	if g.o.has("post") and g.o.get("patrol") == null:
		var px: float = g.o.post[0]
		var pz: float = g.o.post[1]
		if U.hyp(r.x - px, r.z - pz) > 0.7:
			r.patrol = PackedVector2Array([Vector2(px, pz), Vector2(px, pz)])
		g.returning = true


func noise(x: float, y: float, z: float, rad: float, loud: bool = false) -> void:
	for g: Guard in guards:
		if g.r.dead or g.mode == "alarm":
			continue
		var d := U.hyp(x - g.r.x, z - g.r.z)
		if d > rad or absf(y - g.r.y) > rad * 0.6:
			continue
		if loud:
			alarm(g, "heard", null)
			continue
		g.sus = maxf(g.sus, 0.5)
		g.mode = "sus"
		g.look = Vector2(x, z)
		g.look_t = 0.0
		g.inv_t = 0.0
		_say(g, L_SUS)


func takedown_target(P: Player) -> Guard:
	var best: Guard = null
	var bd := 1.9
	for g: Guard in guards:
		var r := g.r
		if r.dead or g.mode == "alarm" or g.react > 0.0:
			continue
		var dx := P.x - r.x
		var dz := P.z - r.z
		var d := U.hyp(dx, dz)
		if d > bd or absf(P.y - r.y) > 1.2:
			continue
		if absf(U.wrap_angle(atan2(dx, dz) - r.yaw)) < 1.75:      # he must not be facing you
			continue
		best = g
		bd = d
	return best


func takedown(g: Guard, P: Player) -> void:
	var r := g.r
	g.mode = "calm"
	r.ally_cd = 1e9
	r.hp = 0.0
	r.hurt(999.0, P, 1.5, null, true)
	MsSound.play([["noise", 0.0, {"type": &"bandpass", "f0": 900.0, "q": 1.2, "gain": 0.5, "dur": 0.09}], ["tone", 0.0, {"type": &"sine", "f0": 120.0, "f1": 50.0, "gain": 0.5, "dur": 0.14}], ["noise", 0.25, {"type": &"lowpass", "f0": 500.0, "f1": 120.0, "gain": 0.3, "dur": 0.25}]], 0.1)
	if Game.fx != null:
		Game.fx.shake = maxf(Game.fx.shake, 0.25)
	Game.time_scale = 0.25
	root.get_tree().create_timer(0.09, true, false, true).timeout.connect(func() -> void: Game.time_scale = 1.0)


func update(dt: float, P: Player) -> void:
	var cam: Camera3D = Game.view.camera if Game.view != null else null
	for g: Guard in guards:
		var r := g.r
		if r.dead and not g.was_dead:      # a man down: who saw it?
			g.was_dead = true
			g.mode = "dead"
			bodies.append({"x": r.x, "y": r.y, "z": r.z, "g": g, "found": false})
			for o: Guard in guards:
				if o != g and not o.r.dead and o.mode != "alarm" and can_see_point(o, r.x, r.y + 0.9, r.z, 50.0, 1.3):
					o.react = REACT_T
					o.react_why = "witness"
					_say(o, L_BODY)
					_off_break(o.r)
		if r.dead:
			g.cone.visible = false
			g.mark.visible = false
			continue
		if g.returning and g.mode == "calm":      # walking back to his post, then turning to face where he always faces
			var px: float = g.o.post[0]
			var pz: float = g.o.post[1]
			var pyaw: float = g.o.post[2]
			if U.hyp(r.x - px, r.z - pz) < 0.8:
				r.patrol = PackedVector2Array([Vector2(px, pz), Vector2(px, pz)])
				r.pause = 0.3
				r._face(dt, pyaw, 3.0)
				if absf(U.wrap_angle(r.yaw - pyaw)) < 0.05:
					g.returning = false
		elif g.mode != "calm":
			g.returning = false
		if g.mode == "alarm":
			g.alarm_t += dt
			if r.state == &"idle" and g.alarm_t > 25.0 and not g.hold:
				calm(g)
		elif r.state != &"idle" and r.state != &"return":      # shot and not killed: he knows
			alarm(g, "hit", P)
		elif P != null:
			# witnesses count down; anyone else watches
			if g.react > 0.0:
				g.react -= dt
				r.pause = 0.5
				for b: Dictionary in bodies:
					if b.g != g and U.hyp(float(b.x) - r.x, float(b.z) - r.z) < 60.0:
						r._face(dt, atan2(float(b.x) - r.x, float(b.z) - r.z), 6.0)
						break
				if g.react <= 0.0:
					alarm(g, g.react_why, P)
			else:
				var rate := _see_rate(g, P)
				if rate > 0.0:
					g.sus = minf(1.0, g.sus + rate * dt)
					g.look = Vector2(P.x, P.z)
					g.look_t = 0.0
					g.inv_t = 0.0
					if g.mode == "calm" and g.sus > SUS_LOOK:
						g.mode = "sus"
						_say(g, L_SUS)
						_off_break(r)
				else:
					g.sus = maxf(0.0, g.sus - dt * (0.12 if g.mode == "sus" else 0.3))
				g.sus_t = g.sus_t + dt if g.mode == "sus" else 0.0
				if g.sus >= 1.0 and g.sus_t > 0.8:      # always a beat of ? first: time to drop out of sight
					alarm(g, "seen", P)
				# suspicious: stop, turn to it, then go and look; give up after a while
				if g.mode == "sus" and g.look != null:
					g.look_t += dt
					var l: Vector2 = g.look
					var d := U.hyp(l.x - r.x, l.y - r.z)
					if g.look_t < 1.3 or rate > 0.0:
						r.pause = 0.4
						r._face(dt, atan2(l.x - r.x, l.y - r.z), 5.0)
					elif d > 1.4 and g.inv_t < 7.0 and not g.stuck_look:
						g.inv_t += dt
						if not g.going_look:
							g.going_look = true
							g.best_d = d
							g.prog_t = 0.0
							r.patrol = PackedVector2Array([l, l])
							r.wp = 0
							r.pause = 0.0
							_say(g, L_LOOK)
						if d < g.best_d - 0.3:
							g.best_d = d
							g.prog_t = 0.0
						else:
							g.prog_t += dt
							if g.prog_t > 1.5:      # can't get there (a wall, a drop): look from here
								g.stuck_look = true
					else:
						if is_nan(g.scan_base):
							g.scan_base = r.yaw
							g.scan_t = 0.0
							r.patrol = PackedVector2Array([Vector2(r.x, r.z), Vector2(r.x, r.z)])
						g.inv_t += dt
						g.scan_t += dt
						r.pause = 0.3
						r._face(dt, g.scan_base + sin(g.scan_t * 1.1) * 0.8, 2.5)      # look left and right about where he stopped
						if g.scan_t > 4.0 or g.sus <= 0.0:
							g.going_look = false
							g.stuck_look = false
							g.scan_base = NAN
							_say(g, L_CALM)
							calm(g)
				# bodies in plain view get found
				if g.mode != "alarm" and g.react <= 0.0:
					for b: Dictionary in bodies:
						if not b.found and b.g != g and can_see_point(g, b.x, float(b.y) + 0.4, b.z, 24.0, 1.1):
							b.found = true
							g.react = REACT_T
							g.react_why = "body"
							_say(g, L_BODY)
							_off_break(r)
							break
		# the painted cone
		g.cone.visible = cones and g.mode != "alarm" and not g.off_view      # off_view: the level says he cannot be seen from here (another floor)
		if g.cone.visible:
			g.cone_t -= dt
			if g.cone_t <= 0.0:
				g.cone_t = 0.12
				_rebuild_cone(g)
			var hot := 1.0 if g.react > 0.0 else g.sus
			var c := WHITE.lerp(AMB, clampf(hot * 1.6, 0.0, 1.0))
			if g.react > 0.0 or hot > 0.85:
				c = c.lerp(RED, 0.7)
			g.cone.set_instance_shader_parameter(&"tint", Vector4(c.r, c.g, c.b, 0.085 + 0.12 * hot))
		# the mark over his head
		g.line_t -= dt
		if g.line_t <= 0.0:
			g.line = ""
		var show := g.sus > 0.04 or g.react > 0.0 or (g.mode == "alarm" and g.alarm_t < 2.5) or g.line != ""
		if show and cam != null:      # only guards you could actually see: near, or a clear line from the camera
			g.vis_t -= dt
			if g.vis_t <= 0.0:
				g.vis_t = 0.25
				var cp := cam.global_position
				var h := Vector3(r.x, r.y + 1.5, r.z) - cp
				var L := h.length()
				if L == 0.0:
					L = 1.0
				g.in_view = L < 45.0 or world.ray_clear(cp.x, cp.y, cp.z, h.x / L, h.y / L, h.z / L, L, 0.02) >= L - 0.8
		show = show and g.in_view and not Game.dialogue.on
		var ok := false
		if cam != null and show:
			var w := Vector3(r.x, r.y + 1.6 + 0.55, r.z)
			if not cam.is_position_behind(w):
				ok = true
				var sp := cam.unproject_position(w)
				g.mark.position = sp - Vector2(17.0, 34.0)
				var red := g.react > 0.0 or g.mode == "alarm"
				g.mark.fill = (1.0 - g.react / REACT_T if g.react > 0.0 else 1.0) if red else g.sus
				g.mark.red = red
				g.mark.glyph = "!" if red else "?"
				g.mark.line = g.line
				g.mark.queue_redraw()
		g.mark.visible = ok


func clear() -> void:
	for g: Guard in guards:
		g.cone.queue_free()
		g.mark.queue_free()
	guards.clear()
	bodies.clear()


func any_alarm() -> bool:
	for g: Guard in guards:
		if not g.r.dead and g.mode == "alarm":
			return true
	return false


func reacting() -> bool:
	for g: Guard in guards:
		if not g.r.dead and g.react > 0.0:
			return true
	return false
