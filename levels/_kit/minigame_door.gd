class_name MinigameDoor
extends RefCounted
## MINIGAME DOOR (JS levels/_kit/minigame-door.js), "add mini game here". One call puts a giant sealed metal door and a SchleedTech terminal panel into any level; pressing E / B at the panel runs a hacking minigame, winning slides the door open (its collision goes with it), losing leaves it locked so the player can try again; either way you are put back in front of the terminal (the world holds still while you play). door: false = the terminal only, for a level that has its own door: open it from on_open. The exporter wrote the JS door and panel into the level as well: those are removed here, this class is the one door.

const GREEN := "#46ff82"
const AMBER := "#ffa828"
const RED := "#ff3024"
const TIER_NAMES: Array[String] = ["CIVILIAN", "CORPORATE", "MILITARY", "SCHLEEDTECH BLACK"]
const FX_RUMBLE := "res://assets/sfx/grind/fx/door_rumble.wav"

var o := {}
var game := "grind"
var title := ""
var own := true
var opts := {}
var group: Node3D = null
var world: World = null
var solid: World.Solid = null
var target := {}
var P0 := {}
var D := {}
var side := -1.0
var leaves: Array[Node3D] = []
var lamp_mat: StandardMaterial3D = null
var ring: MeshInstance3D = null
var ring_mat: StandardMaterial3D = null
var prompt: Sprite3D = null
var screen_vp: SubViewport = null
var prompt_vp: SubViewport = null
var screen_ctl: Control = null
var prompt_ctl: Control = null
var status := "locked"
var open_t := 0.0
var busy := false
var prev_held := false
var msg := ""
var msg_t := 0.0
var screen_t := 99.0
var pad := false
var time := 0.0
var spot := Vector3.ZERO


static func _stripes() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var a := Color("#e0a020")
	var b := Color("#15191c")
	for y in 64:
		for x in 64:
			var on := false
			for i in range(-2, 4):
				var l := i * 32 + 64 - y
				if x >= l and x < l + 16:
					on = true
			img.set_pixel(x, y, b if on else a)
	return ImageTexture.create_from_image(img)


func _box(m: Material, w: float, h: float, d: float, x: float, y: float, z: float, parent: Node3D = null) -> MeshInstance3D:
	var b := MeshInstance3D.new()
	b.mesh = MsKit.box(w, h, d)
	b.material_override = m
	b.position = Vector3(x, y, z)
	(parent if parent != null else group).add_child(b)
	return b


func _viewport(size_: Vector2i, ctl: Control, transparent: bool) -> SubViewport:
	var v := SubViewport.new()
	v.size = size_
	v.disable_3d = true
	v.transparent_bg = transparent
	v.gui_disable_input = true
	v.render_target_update_mode = SubViewport.UPDATE_ONCE
	ctl.size = Vector2(size_)
	v.add_child(ctl)
	group.add_child(v)
	return v


func _init(L: Node3D, p_world: World, p_o: Dictionary) -> void:
	o = p_o
	world = p_world
	game = String(o.get("game", "grind"))
	title = String(o.get("title", "SECURITY DOOR")).to_upper()
	own = not (o.get("door") is bool and o.door == false)
	var panel: Dictionary = o.get("panel", {})
	if own:
		D = {"x": 0.0, "y": 0.0, "z": 0.0, "width": 10.0, "height": 8.0, "thick": 0.5}
		D.merge(o.get("door", {}), true)
	else:
		D = {"x": float(panel.get("x", 0.0)), "y": float(panel.get("y", 0.0)), "z": float(panel.get("z", 0.0)) + 1.0, "width": 10.0, "height": 8.0, "thick": 0.5}
	P0 = {"x": float(D.x) - float(D.width) / 2.0 - 2.0, "y": float(D.y), "z": float(D.z) - 1.0, "yaw": 0.0}
	P0.merge(panel, true)
	opts = {"title": title, "difficulty": o.get("difficulty", 1), "seed": o.get("seed", title)}
	if o.has("length"):
		opts.length = o.length
	opts.merge(o.get("game_opts", {}), true)
	# the exporter's copy of this door goes: the level's by_name group and its solids
	if L.get(&"by_name") != null and L.by_name.has("Minigame door: " + title):
		for n: Node in L.node_named("Minigame door: " + title):
			n.queue_free()
		L.by_name.erase("Minigame door: " + title)
	var stale: Array[World.Solid] = []
	for s: World.Solid in world.solids:
		var ex: Variant = s.data.get("extra")      # (the exporter keeps a solid's JS id under extra)
		var sid: String = String(ex.get("id", "")) if ex is Dictionary else ""
		if sid == "minigame door " + title or sid == "minigame panel " + title:
			stale.append(s)
	for s: World.Solid in stale:
		world.remove(s)
	group = Node3D.new()
	group.name = "Minigame door: " + title
	L.add_child(group)
	var dx: float = D.x
	var dy: float = D.y
	var dz: float = D.z
	side = signf(float(P0.z) - dz)      # which face of the door the panel (and the player) is on
	if side == 0.0:
		side = -1.0
	# ---- materials + textures ----
	var steel := MsKit.std(0x8a97a1, 0.55, 0.3)
	var dark := MsKit.std(0x3a444c, 0.7, 0.3)
	lamp_mat = StandardMaterial3D.new()
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_mat.albedo_color = Color(RED)
	# ---- the door: frame, two sliding leaves, hazard band, status lamp, sign ----
	var w: float = D.width
	var h: float = D.height
	var t: float = D.thick
	var lw := w / 2.0 - 0.04
	var face_z := t / 2.0 + 0.03
	if own:
		var hazard := StandardMaterial3D.new()
		hazard.albedo_texture = _stripes()
		hazard.metallic = 0.2
		hazard.roughness = 0.7
		hazard.uv1_scale = Vector3(6, 1, 1)
		_box(dark, 0.55, h + 0.6, t + 0.55, dx - w / 2.0 - 0.25, dy + h / 2.0 + 0.3, dz)
		_box(dark, 0.55, h + 0.6, t + 0.55, dx + w / 2.0 + 0.25, dy + h / 2.0 + 0.3, dz)
		_box(dark, w + 1.6, 0.6, t + 0.55, dx, dy + h + 0.3, dz)
		_box(lamp_mat, w * 0.5, 0.22, 0.08, dx, dy + h - 0.25, dz + side * (t / 2.0 + 0.3))
		for ex: float in [-1.0, 1.0]:      # warning beacons
			var bc := MeshInstance3D.new()
			bc.mesh = MsKit.sphere(0.28, 12, 8)
			bc.material_override = lamp_mat
			bc.position = Vector3(dx + ex * (w / 2.0 + 0.25), dy + h + 0.75, dz + side * (t / 2.0 + 0.3))
			group.add_child(bc)
		var bolt_mesh := MsKit.cyl(0.12, 0.12, 0.1, 8)
		for dir: float in [-1.0, 1.0]:
			var leaf := Node3D.new()
			leaf.position = Vector3(dx + dir * w / 4.0, dy, dz)
			group.add_child(leaf)
			_box(steel, lw, h, t, 0, h / 2.0, 0, leaf)
			for f: float in [-1.0, 1.0]:
				for k: float in [0.3, 0.55, 0.8]:
					_box(dark, lw - 0.5, 0.22, 0.1, 0, h * k, f * face_z, leaf)
				# (a three.js box maps the texture whole on each face, a Godot box does not: a quad on the band's outer face)
				_box(dark, lw - 0.2, 0.9, 0.06, 0, 0.5, f * (t / 2.0 + 0.01), leaf)
				var band := MeshInstance3D.new()
				var bq := QuadMesh.new()
				bq.size = Vector2(lw - 0.2, 0.9)
				band.mesh = bq
				band.material_override = hazard
				band.position = Vector3(0, 0.5, f * (t / 2.0 + 0.041))
				if f < 0.0:
					band.rotation.y = PI
				leaf.add_child(band)
				for i in 3:
					var bolt := MeshInstance3D.new()
					bolt.mesh = bolt_mesh
					bolt.material_override = dark
					bolt.rotation.x = PI / 2.0
					bolt.position = Vector3(-dir * (lw / 2.0 - 0.35), h * (0.25 + i * 0.25), f * (t / 2.0 + 0.05))
					leaf.add_child(bolt)
			_box(dark, 0.3, h, t + 0.12, -dir * (lw / 2.0 - 0.02), h / 2.0, 0, leaf)      # the centre seam
			leaves.append(leaf)
		var sign_ctl := Control.new()
		sign_ctl.draw.connect(func() -> void: _draw_sign(sign_ctl))
		var sign_vp := _viewport(Vector2i(1024, 100), sign_ctl, false)
		var sign_mesh := MeshInstance3D.new()
		var sq := QuadMesh.new()
		sq.size = Vector2(w * 0.9, 0.9)
		sign_mesh.mesh = sq
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.albedo_texture = sign_vp.get_texture()
		sign_mesh.material_override = sm
		sign_mesh.position = Vector3(dx, dy + h - 1.3, dz + side * (t / 2.0 + 0.34))
		sign_mesh.rotation.y = 0.0 if side > 0.0 else PI
		group.add_child(sign_mesh)
	solid = world.add({"id": "minigame door " + title, "kind": "box", "cx": dx, "cz": dz, "hx": w / 2.0, "hz": t / 2.0 + 0.1, "bottom": dy - 7.0, "top": dy + h, "off": not own})
	# ---- the panel: a SchleedTech terminal on a post, a live screen, a floating prompt ----
	var px: float = P0.x
	var py: float = P0.y
	var pz: float = P0.z
	var yaw: float = P0.yaw
	var pnl := Node3D.new()
	pnl.position = Vector3(px, py, pz)
	pnl.rotation.y = yaw
	group.add_child(pnl)
	_box(dark, 1.1, 0.25, 0.8, 0, 0.125, 0, pnl)
	_box(steel, 0.38, 0.95, 0.38, 0, 0.7, 0, pnl)
	var head := Node3D.new()
	head.position = Vector3(0, 1.55, 0)
	head.rotation.x = -0.28
	pnl.add_child(head)
	_box(steel, 1.3, 1.0, 0.5, 0, 0, 0, head)
	_box(dark, 1.16, 0.86, 0.06, 0, 0, 0.25, head)
	screen_ctl = Control.new()
	screen_ctl.draw.connect(_draw_screen)
	screen_vp = _viewport(Vector2i(512, 360), screen_ctl, false)
	var screen := MeshInstance3D.new()
	var scq := QuadMesh.new()
	scq.size = Vector2(1.08, 0.76)
	screen.mesh = scq
	var scm := StandardMaterial3D.new()
	scm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	scm.albedo_texture = screen_vp.get_texture()
	screen.material_override = scm
	screen.position.z = 0.285
	head.add_child(screen)
	_box(lamp_mat, 0.1, 0.1, 0.05, 0.5, -0.5, 0.27, head)
	spot = Vector3(px + sin(yaw) * 1.5, py, pz + cos(yaw) * 1.5)      # the way the panel faces
	ring = MeshInstance3D.new()
	ring.mesh = MsKit.ring(0.85, 1.0, 40)
	ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 168.0 / 255.0, 40.0 / 255.0, 0.8)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = ring_mat
	ring.position = spot + Vector3(0, 0.04, 0)
	group.add_child(ring)
	prompt_ctl = Control.new()
	prompt_ctl.draw.connect(_draw_prompt)
	prompt_vp = _viewport(Vector2i(512, 128), prompt_ctl, true)
	prompt = Sprite3D.new()
	prompt.texture = prompt_vp.get_texture()
	prompt.pixel_size = 2.6 / 512.0
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.render_priority = 100
	prompt.shaded = false
	prompt.position = Vector3(px, py + 2.75, pz)
	prompt.visible = false
	group.add_child(prompt)
	world.add({"id": "minigame panel " + title, "kind": "box", "cx": px, "cz": pz, "hx": 0.55, "hz": 0.4, "yaw": yaw, "bottom": py - 0.2, "top": py + 1.9})
	target = {"x": spot.x, "y": spot.y, "z": spot.z}


var locked: bool:
	get:
		return status != "open"


func tier_name() -> String:
	return String(o.get("tier_name", TIER_NAMES[clampi(int(opts.difficulty) - 1, 0, 3)]))


func _draw_sign(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 1024, 100), Color("#11181c"))
	c.draw_rect(Rect2(4, 4, 1016, 92), Color("#e0a020"), false, 6.0)
	var f := CrtTheme.font(&"raj700")
	var s := title.substr(0, 34)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 56).x
	c.draw_string(f, Vector2(512.0 - w / 2.0, 72.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color("#e0a020"))


func _draw_screen() -> void:
	var c := screen_ctl
	var f := CrtTheme.font(&"vt323")
	c.draw_rect(Rect2(0, 0, 512, 360), Color("#021208"))
	var col := Color(GREEN if status == "open" else (AMBER if status == "running" else RED))
	var blink := int(floorf(time * 2.0)) % 2 == 0
	var line := func(txt: String, y: float, cc: Variant = GREEN, sz: int = 26, x: float = 22.0) -> void:
		c.draw_string(f, Vector2(x, y + f.get_ascent(sz)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(cc))
	line.call("SCHLEEDTECH P-1200 // LINK 09", 18.0, GREEN, 24)
	line.call(title.substr(0, 30), 56.0, "#c8ffd8", 30)
	c.draw_rect(Rect2(22, 100, 468, 3), col)
	line.call("STATUS", 118.0, GREEN, 26)
	var st := "UNLOCKED" if status == "open" else ("LINK ACTIVE" if status == "running" else (msg if msg != "" else "SEALED"))
	line.call(st, 118.0, col, 26, 130.0)
	line.call("ICE CLASS  " + tier_name(), 156.0, "#c8ffd8", 24)
	if status == "locked":
		line.call(("[B]" if pad else "[E]") + " JACK IN" + (" _" if blink else ""), 236.0, AMBER, 42)
	elif status == "running":
		line.call("RUNNING INTRUSION...", 236.0, AMBER, 34)
	else:
		line.call("ACCESS GRANTED", 236.0, GREEN, 40)
	var y := 0
	while y < 360:
		c.draw_rect(Rect2(0, y, 512, 1), Color(0, 0, 0, 0.28))
		y += 4


func _draw_prompt() -> void:
	var c := prompt_ctl
	var f := CrtTheme.font(&"vt323")
	c.draw_rect(Rect2(8, 20, 496, 88), Color(2 / 255.0, 14 / 255.0, 6 / 255.0, 0.82))
	c.draw_rect(Rect2(8, 20, 496, 88), Color(AMBER), false, 4.0)
	var s := ("B" if pad else "E") + "   JACK IN"
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 56).x
	c.draw_string(f, Vector2(256.0 - w / 2.0, 66.0 + (f.get_ascent(56) - f.get_descent(56)) / 2.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Color(AMBER))


func _redraw_screen() -> void:
	screen_ctl.queue_redraw()
	screen_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _redraw_prompt() -> void:
	prompt_ctl.queue_redraw()
	prompt_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## a heavy door grinding open: a clunk, a low sweep, a hiss
func _rumble() -> void:
	var a := AudioStreamPlayer.new()
	a.stream = load(FX_RUMBLE)
	a.bus = &"SFX"
	group.add_child(a)
	a.finished.connect(a.queue_free)
	a.play()


func _solve(quiet: bool = false) -> void:
	if status == "open":
		return
	status = "open"
	screen_t = 99.0
	if quiet:
		open_t = 1.0
		solid.set_off(true)
		for i in leaves.size():
			leaves[i].position.x = float(D.x) + (1.0 if i != 0 else -1.0) * (float(D.width) / 4.0 + float(D.width) / 2.0 - 0.1)
	else:
		_rumble()
		CrtTheme.menu_sound("pauseConfirm")      # JS ctx.controlFeedback
	var cb: Variant = o.get("on_open")
	if cb is Callable:
		(cb as Callable).call(quiet)
	_redraw_screen()


## when the minigame ends, won or lost, you are back on your feet in front of the terminal, facing it
func _return_to_panel(P: Player) -> void:
	if P == null or P.dead:
		return
	P.x = spot.x
	P.y = spot.y
	P.z = spot.z
	P.vx = 0.0
	P.vy = 0.0
	P.vz = 0.0
	P.grounded = true
	P.yaw = atan2(float(P0.x) - spot.x, float(P0.z) - spot.z)
	P.invuln = maxf(P.invuln, 1.5)
	Game.rig.snap_to(P)


func _start(P: Player) -> void:
	if busy or status != "locked":
		return
	busy = true
	status = "running"
	screen_t = 99.0
	_redraw_screen()
	var ses := GrindSession.run_grind(opts)
	var r: Dictionary = await ses.done
	busy = false
	_return_to_panel(P)
	if r.get("ok", false):
		_solve()
	else:
		status = "locked"
		var aborted: bool = r.get("aborted", false)
		msg = "LINK DROPPED" if aborted else "LOCKOUT - RETRY"
		msg_t = 3.0
		Game.hud.toast("LINK DROPPED / TRY AGAIN" if aborted else "LOCKOUT / TRY AGAIN")
		screen_t = 99.0


func update(dt: float, P: Player) -> void:
	time += dt
	var w: float = D.width
	if status == "open" and open_t < 1.0:
		open_t = minf(1.0, open_t + dt / 1.7)
		var e := open_t * open_t * (3.0 - 2.0 * open_t)
		for i in leaves.size():
			leaves[i].position.x = float(D.x) + (1.0 if i != 0 else -1.0) * (w / 4.0 + e * (w / 2.0 - 0.1))
		if open_t > 0.45:
			solid.set_off(true)
	if status != "open":
		solid.set_off(not own)
	var flash := 1.0 if status == "open" else (0.5 + 0.5 * sin(time * 9.0) if status == "running" else 0.5 + 0.5 * sin(time * 3.0))
	var lc := Color(GREEN if status == "open" else (AMBER if status == "running" else RED)).srgb_to_linear() * (0.35 + 0.65 * flash)
	lc.a = 1.0
	lamp_mat.albedo_color = lc.linear_to_srgb()
	ring.visible = status == "locked"
	ring_mat.albedo_color.a = 0.45 + 0.35 * sin(time * 4.0)
	if msg_t > 0.0:
		msg_t -= dt
		if msg_t <= 0.0:
			msg = ""
			screen_t = 99.0
	if Inp.using_pad != pad:
		pad = Inp.using_pad
		_redraw_prompt()
		screen_t = 99.0
	var b := Inp.btn(&"b")
	var edge := (b.held and not prev_held) or b.pressed
	prev_held = b.held
	if P == null or P.dead:
		prompt.visible = false
		return
	var d := U.hyp(P.x - float(P0.x), P.z - float(P0.z))
	var here := absf(P.y - float(P0.y)) < 3.0
	if here and d < 30.0:
		screen_t += dt
		if screen_t > 0.25:
			screen_t = 0.0
			_redraw_screen()
	prompt.visible = here and d < 3.2 and status == "locked" and not busy
	if edge and here and d < 2.8 and status == "locked" and not busy and dt > 0.0:
		_start(P)


## QA / scripted open (skips the minigame); quiet: already open (a checkpoint), no sound
func open(quiet: bool = false) -> void:
	_solve(quiet)


func reset() -> void:
	status = "locked"
	open_t = 0.0
	solid.set_off(not own)
	for i in leaves.size():
		leaves[i].position.x = float(D.x) + (1.0 if i != 0 else -1.0) * float(D.width) / 4.0
	msg = ""
	screen_t = 99.0
	_redraw_screen()
