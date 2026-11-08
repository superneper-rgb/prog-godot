class_name MsHallLights
extends RefCounted
## The reception's alien light show (JS levels/mothership/hall-lights.js): the family is Italian, but they are still grays. Under the frescoed dome hangs THE HALO, a black-and-chrome saucer ring held up by nothing, with a chase of LED nodes round its rim and twelve moving heads that throw beams
## down into the hall; a truss of PAR cans over the band; an LED wall behind the band (EQ bars + an Italian greeting in a ticker); green neon running up the gilded columns, along the cornice and round the dance floor like a saucer's landing lights.
## Everything plays to the band's song (band.feel): the beams change pattern every four bars and flash on the kick, the stage cans strobe on the snare, the whole rig blinks white on a crash. When the cover is blown the show turns to a red alarm sweep. Beams and pools are unlit additive meshes; the only real lights are the halo's colour wash and the stage wash.

const FLOOR := 2.0
const OCT_A := 27.5
const OCT_S := 2.0 * OCT_A * 0.41421356
const OCT_RV := OCT_A / 0.92387953
const PAL := [0x5cff7a, 0xff3ad0, 0x3ae0ff, 0xa060ff]      # alien green, magenta, cyan, violet
const HR := 13.0
const NODES := 64
const TICK := "  BENVENUTI  *  AUGURI AGLI SPOSI  *  0002PXR  *  CENT'ANNI  *  "


class LHead:
	var g: Node3D
	var lens_mat: StandardMaterial3D
	var beam: MeshInstance3D
	var pool: MeshInstance3D
	var aim := Vector3(0.0, 2.0, 0.0)
	var want := Vector3.ZERO
	var len_ := 22.0
	var r1 := 2.1
	var a := 0.0
	var target := Vector3.ZERO


## The LED wall's picture (JS drawLed on a canvas), redrawn at 30 Hz.
class LedWall:
	extends Control
	var F: Dictionary = {}
	var alarm := false

	func _draw() -> void:
		var w := 320.0
		var h := 148.0
		draw_rect(Rect2(0, 0, w, h), Color8(4, 4, 10))
		var font := ThemeDB.fallback_font
		if F.is_empty():
			return
		var t: float = F.t
		var beat: float = F.beat
		if alarm:      # the cover is blown: ALLARME
			var on := floori(t * 6.0) % 2 == 1
			draw_rect(Rect2(0, 0, w, h), Color("#ff2010") if on else Color("#3a0404"))
			draw_string(font, Vector2(0.0, h / 2.0 + 15.0), "ALLARME", HORIZONTAL_ALIGNMENT_CENTER, w, 44, Color("#200000") if on else Color("#ff3020"))
		else:
			var bars := 20
			var bw := w / bars
			for k in bars:      # EQ: bass on the left, keys / voice on the right
				var u := float(k) / (bars - 1)
				var v := (1.0 - u) * float(F.low) + u * maxf(float(F.keys), float(F.vocal))
				var wob := 0.5 + 0.5 * sin(beat * TAU + k * 1.7)
				var hh := roundi(minf(1.0, v * (0.55 + 0.45 * wob) + float(F.kick) * 0.25 * (1.0 - u)) * 13.0) * 7
				var y := 0
				while y < hh:
					draw_rect(Rect2(k * bw + 2.0, h - 26.0 - y - 6.0, bw - 4.0, 5.0), Color("#ff3ad0") if y > 70 else (Color("#3ae0ff") if y > 45 else Color("#5cff7a")))
					y += 7
			# ticker (Italian greeting) + a line of gray script (ENGINE DIFFERENCE: the JS's syllabics glyphs are not in the game's fonts: little strokes in the same place)
			var off := fmod(t * 40.0, TICK.length() * 10.8)
			draw_string(font, Vector2(-off, h - 6.0), TICK + TICK, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#5cff7a"))
			for i in 26:
				var s := (i * 7 + floori(beat)) % 13
				var x := 6.0 + i * 12.0
				var c := Color(160.0 / 255.0, 96.0 / 255.0, 1.0, 0.85)
				draw_line(Vector2(x, 6.0 + s % 3), Vector2(x + 7.0, 6.0 + (s * 5) % 9), c, 1.5)
				draw_line(Vector2(x + (s % 4), 16.0), Vector2(x + 6.0 - (s % 3), 8.0), c, 1.5)
		var y2 := 0
		while y2 < int(h):      # pixel rows
			draw_rect(Rect2(0, y2, w, 1), Color(0, 0, 0, 0.35))
			y2 += 3


var zone: Node3D
var wash: OmniLight3D
var stage_light: OmniLight3D
var singer: Array
var halo: Node3D
var heads: Array[LHead] = []
var pars: Array[LHead] = []
var nodes: MultiMesh
var ring_lights: MultiMesh
var neon: StandardMaterial3D
var floor_ring: MeshInstance3D
var under: MeshInstance3D
var led: LedWall
var led_vp: SubViewport
var led_t := 0.0
var _black: StandardMaterial3D
var _white := Color.WHITE
var _red := MsKit.srgb(0xff1a10)


func _head(parent: Node3D, len_: float, r0: float, r1: float) -> LHead:
	var h := LHead.new()
	var g := Node3D.new()
	parent.add_child(g)
	h.g = g
	var can := MsKit.part(g, MsKit.cyl(0.22, 0.28, 0.6, 10), _black)
	can.rotation.x = PI / 2.0
	h.lens_mat = MsKit.flat(0xffffff)
	var lens := MsKit.part(g, MsKit.disc(0.2, 12), h.lens_mat, Vector3(0.0, 0.0, 0.31), false)
	lens.rotation.x = PI / 2.0
	h.beam = MsKit.glow(g, MsKit.cone_z(r0, r1, len_, 16), 2, 0xffffff, 1.0)
	h.beam.position.z = 0.3
	h.pool = MsKit.glow(zone, MsKit.disc(1.0, 20), 3, 0xffffff, 1.0)
	h.len_ = len_
	h.r1 = r1
	return h


func _shine(h: LHead, col: Color, k: float) -> void:
	# (colours are display colours here; the JS's material colours are linear)
	var lc := col.srgb_to_linear()
	MsKit.tint(h.beam, Color(lc.r * 0.34 * k, lc.g * 0.34 * k, lc.b * 0.34 * k))
	var ln := col.lerp(_white, 0.5)
	h.lens_mat.albedo_color = Color(ln.r * (0.4 + k), ln.g * (0.4 + k), ln.b * (0.4 + k))
	var dist := h.g.global_position.distance_to(h.aim)
	h.beam.scale = Vector3(1.0, 1.0, minf(1.0, dist / h.len_) + 0.02)      # the cone stops at what it lights
	# aimed at a body: the pool lies on the stage under it, not in its chest. (The JS's pool scale and colour lines sit inside the comment on this line, so its pools stay white, 1 m wide: kept.)
	h.pool.position = Vector3(h.aim.x, (float(singer[1]) if h.aim.y > FLOOR + 0.2 else FLOOR) + 0.03, h.aim.z)


func _point(h: LHead, target: Vector3, k: float) -> void:
	h.aim = h.aim.lerp(target, k)
	if h.g.global_position.distance_squared_to(h.aim) > 1e-4:
		h.g.look_at(h.aim, Vector3.UP, true)


func _init(p_zone: Node3D, p_wash: OmniLight3D, spots: Dictionary, p_stage: OmniLight3D) -> void:
	zone = p_zone
	wash = p_wash
	stage_light = p_stage
	singer = spots.singer
	_black = MsKit.std(0x0c0c12, 0.35, 0.6)
	var chrome := MsKit.std(0xc8ccd8, 0.2, 0.9)
	neon = MsKit.flat(PAL[0])
	# ---- THE HALO: a floating ring under the dome
	halo = Node3D.new()
	halo.position = Vector3(0.0, 18.6, 0.0)
	zone.add_child(halo)
	MsKit.part(halo, MsKit.torus(HR, 0.55, 64, 10), _black)
	var rim := MsKit.part(halo, MsKit.torus(HR, 0.6, 64, 4), chrome, Vector3(0.0, 0.35, 0.0))
	rim.scale.y = 0.25
	under = MsKit.glow(halo, MsKit.ring(HR - 0.8, HR + 0.8, 64), 0, 0x2aff8a, 0.35)
	under.position.y = -0.58
	nodes = MultiMesh.new()
	nodes.transform_format = MultiMesh.TRANSFORM_3D
	nodes.use_colors = true
	nodes.mesh = MsKit.sphere(0.16, 8, 6)
	nodes.instance_count = NODES
	var nodes_m := StandardMaterial3D.new()
	nodes_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nodes_m.vertex_color_use_as_albedo = true
	nodes_m.vertex_color_is_srgb = true
	var nmi := MultiMeshInstance3D.new()
	nmi.multimesh = nodes
	nmi.material_override = nodes_m
	nmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.add_child(nmi)
	for i in NODES:
		var a := float(i) / NODES * TAU
		nodes.set_instance_transform(i, Transform3D(Basis(), Vector3(sin(a) * (HR + 0.62), 0.0, cos(a) * (HR + 0.62))))
		nodes.set_instance_color(i, MsKit.srgb(PAL[0]))
	for k in 4:      # four struts to a hub round the Spine Beam (the halo's antigravity core)
		var a := k * PI / 2.0 + PI / 4.0
		var s := MsKit.part(halo, MsKit.box(0.25, 0.25, HR - 4.2), _black, Vector3(sin(a) * (HR / 2.0 + 2.0), 0.0, cos(a) * (HR / 2.0 + 2.0)))
		s.rotation.y = a
	MsKit.part(halo, MsKit.torus(4.2, 0.4, 32, 8), chrome)
	MsKit.part(halo, MsKit.torus(4.2, 0.14, 32, 6), neon, Vector3(0.0, -0.4, 0.0), false)
	for i in 12:
		var a := float(i) / 12.0 * TAU
		var yoke := Node3D.new()
		yoke.position = Vector3(sin(a) * HR, -0.9, cos(a) * HR)
		halo.add_child(yoke)
		MsKit.part(yoke, MsKit.box(0.12, 0.6, 0.12), _black, Vector3(0.0, 0.3, 0.0))
		var h := _head(yoke, 22.0, 0.18, 2.1)
		h.a = a
		heads.append(h)
	# ---- the stage truss: four PAR cans over the band
	var truss := Node3D.new()
	truss.position = Vector3(float(singer[0]) + 0.6, FLOOR + 8.2, 0.0)
	zone.add_child(truss)
	MsKit.part(truss, MsKit.box(0.5, 0.5, 13.0), _black)
	for dz: float in [-0.2, 0.2]:
		for dy: float in [-0.2, 0.2]:
			var tube := MsKit.part(truss, MsKit.cyl(0.04, 0.04, 13.2, 6), chrome, Vector3(dz, dy, 0.0))
			tube.rotation.x = PI / 2.0
	for dz: float in [-1.0, 1.0]:      # hung from the cornice
		MsKit.part(truss, MsKit.cyl(0.03, 0.03, 9.0, 4), chrome, Vector3(0.0, 4.75, dz * 6.0))
	var plist: Array = [spots.drums, spots.singer, spots.singer, spots.keys]
	for i in 4:
		var p: Array = plist[i]
		var h := _head(truss, 9.0, 0.15, 1.2)
		h.g.position = Vector3(0.0, -0.45, -4.5 + i * 3.0)
		h.target = Vector3(p[0], float(p[1]) + 0.5, p[2])
		pars.append(h)
	# ---- the LED wall behind the band (west face, between the drapes), gold-framed like the mirrors
	var LW := 10.0
	var LH := 4.6
	led_vp = SubViewport.new()
	led_vp.size = Vector2i(320, 148)
	led_vp.disable_3d = true
	led_vp.transparent_bg = false
	led_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	led = LedWall.new()
	led.size = Vector2(320, 148)
	led_vp.add_child(led)
	zone.add_child(led_vp)
	var wall := Node3D.new()
	wall.position = Vector3(-OCT_A + 0.56, FLOOR + 1.0 + LH / 2.0 + 1.0, 0.0)
	wall.rotation.y = PI / 2.0
	zone.add_child(wall)
	var scr := QuadMesh.new()
	scr.size = Vector2(LW, LH)
	var scr_m := StandardMaterial3D.new()
	scr_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	scr_m.albedo_texture = led_vp.get_texture()
	scr_m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	MsKit.part(wall, scr, scr_m, Vector3.ZERO, false)
	var gold := MsKit.std(0xd8a83a, 0.3, 0.85)
	for f: Array in [[LW + 0.5, 0.25, 0.0, LH / 2.0 + 0.12], [LW + 0.5, 0.25, 0.0, -LH / 2.0 - 0.12], [0.25, LH, -LW / 2.0 - 0.12, 0.0], [0.25, LH, LW / 2.0 + 0.12, 0.0]]:
		MsKit.part(wall, MsKit.box(f[0], f[1], 0.12), gold, Vector3(f[2], f[3], 0.02))
	# ---- neon: up the inner face of every column, along the cornice, round the dance floor
	for k in 8:
		var a := k * PI / 4.0 + PI / 8.0
		var r := OCT_RV - 0.9 - 0.72
		MsKit.part(zone, MsKit.box(0.08, 14.5, 0.08), neon, Vector3(sin(a) * r, FLOOR + 1.2 + 7.25, cos(a) * r), false)
		var th := k * PI / 4.0
		var line := MsKit.part(zone, MsKit.box(OCT_S * 0.9, 0.1, 0.1), neon, Vector3(sin(th) * (OCT_A - 0.62), 18.2, cos(th) * (OCT_A - 0.62)), false)
		line.rotation.y = th + PI / 2.0
	floor_ring = MsKit.glow(zone, MsKit.ring(10.95, 11.3, 64), 0, PAL[0], 1.0)
	floor_ring.position.y = FLOOR + 0.02
	ring_lights = MultiMesh.new()
	ring_lights.transform_format = MultiMesh.TRANSFORM_3D
	ring_lights.use_colors = true
	ring_lights.mesh = MsKit.disc(0.22, 10)
	ring_lights.instance_count = 32
	var rl_m := StandardMaterial3D.new()
	rl_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rl_m.vertex_color_use_as_albedo = true
	rl_m.vertex_color_is_srgb = true
	rl_m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rl_m.disable_fog = true
	rl_m.no_depth_test = false
	var rmi := MultiMeshInstance3D.new()
	rmi.multimesh = ring_lights
	rmi.material_override = rl_m
	rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone.add_child(rmi)
	for i in 32:
		var a := float(i) / 32.0 * TAU
		ring_lights.set_instance_transform(i, Transform3D(Basis(), Vector3(sin(a) * 11.6, FLOOR + 0.025, cos(a) * 11.6)))
		ring_lights.set_instance_color(i, MsKit.srgb(PAL[1]))


func set_shown(on: bool) -> void:
	led_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func update(dt: float, F: Dictionary, mode: String, time: float) -> void:
	var alarm := mode == "panic" or mode == "scratch"
	var quiet := mode == "off"
	var block := floori(maxf(0.0, float(F.bar)) / 4.0)
	var pattern := block % 4
	var b: float = F.beat
	var energy := 0.35 + 0.65 * float(F.low)
	var flash: float = F.crash
	var kick: float = F.kick
	halo.position.y = 18.6 + sin(time * 0.6) * 0.15
	halo.rotation.y += dt * (0.6 if alarm else 0.05)
	var singer_at := Vector3(singer[0], float(singer[1]) + 0.6, singer[2])
	# moving heads
	for i in heads.size():
		var h: LHead = heads[i]
		var P := h.g.global_position
		var a := atan2(P.x, P.z)
		var alt := 1.0 if i % 2 else -1.0
		if alarm:
			var s := a + time * 2.4 * alt
			h.want = Vector3(sin(s) * 10.0, FLOOR, cos(s) * 10.0)
		elif pattern == 0:      # all on the singer
			h.want = singer_at + Vector3(sin(b * 1.3 + i) * 1.2, 0.0, cos(b * 0.9 + i) * 2.2)
		elif pattern == 1:      # circling the floor
			var s := a + b * PI / 4.0
			var r := 7.0 + 3.0 * sin(b * PI / 2.0)
			h.want = Vector3(sin(s) * r, FLOOR, cos(s) * r)
		elif pattern == 2:      # crossing fans, swinging on the beat
			var s := a + PI + alt * (0.7 + 0.5 * sin(b * PI))
			h.want = Vector3(sin(s) * 9.0, FLOOR, cos(s) * 9.0)
		else:      # jumps a step on every beat
			var s := a + PI + floorf(b) * PI / 4.0
			h.want = Vector3(sin(s) * 6.0, FLOOR, cos(s) * 6.0)
		_point(h, h.want, minf(1.0, dt * (8.0 if alarm else (10.0 if pattern == 3 else 3.0))))
		var col: Color = _red if alarm else MsKit.srgb(PAL[(block + (i % 2) * 2) % 4])
		var k: float = 0.05 if quiet else (0.7 + 0.3 * sin(time * 20.0) if alarm else (0.25 + 0.45 * kick) * energy + 0.12)
		_shine(h, col.lerp(_white, flash) if flash > 0.3 and not alarm else col, minf(1.4, k + flash * 0.8))
	# stage cans: on the band, strobing on the snare, the singer's pair brighter while he sings
	for i in pars.size():
		var h: LHead = pars[i]
		_point(h, h.target, 1.0)
		var col: Color = _red if alarm else MsKit.srgb(PAL[(floori(b) + i) % 4])
		var k: float = 0.05 if quiet else (0.5 if alarm else 0.25 + 0.7 * float(F.snare) + (0.4 * float(F.sing) if i == 1 or i == 2 else 0.0))
		_shine(h, col, k)
	# halo nodes chase round the rim, a step per eighth note
	var step := floori(b * 2.0)
	for i in NODES:
		var on := posmod(i + step, 8) < 3
		nodes.set_instance_color(i, (_red if on else MsKit.srgb(0x200000)) if alarm else (MsKit.srgb(PAL[(block + (0 if i % 16 < 8 else 1)) % 4]) if on else MsKit.srgb(0x101418)))
	for i in 32:
		var on := posmod(i + floori(b), 4) == 0
		if on:
			var c := MsKit.srgb(0xff2010 if alarm else PAL[(block + 1) % 4])
			var m := 0.6 + kick
			ring_lights.set_instance_color(i, Color(c.r * m, c.g * m, c.b * m))
		else:
			ring_lights.set_instance_color(i, MsKit.srgb(0x050505))
	# neon breathes with the bass and kicks
	var nc := MsKit.srgb(0xff2010 if alarm else PAL[(block * 3) % 4])
	var nk: float = (0.5 + (0.5 if sin(time * 12.0) > 0.0 else 0.0)) if alarm else 0.45 + 0.3 * float(F.low) + 0.5 * kick
	neon.albedo_color = Color(nc.r * nk, nc.g * nk, nc.b * nk)
	var nl := nc.srgb_to_linear()
	MsKit.tint(floor_ring, Color(nl.r * nk * 0.8, nl.g * nk * 0.8, nl.b * nk * 0.8))
	MsKit.opa(under, 0.5 if alarm else 0.18 + 0.3 * kick)
	# the real lights: the halo's wash takes the beams' colour; the stage wash pumps with the kick
	if wash != null:
		wash.light_color = MsKit.srgb(0xff2010 if alarm else PAL[block % 4])
		wash.light_energy = (10.0 + (8.0 if sin(time * 12.0) > 0.0 else 0.0) if alarm else 4.0 + 10.0 * kick * energy) / PI
	if stage_light != null:
		stage_light.light_color = MsKit.srgb(0xff3020 if alarm else PAL[(floori(b / 2.0) + 1) % 4]).lerp(MsKit.srgb(0xff8aa8), 0.4)
		stage_light.light_energy = (12.0 if alarm else 10.0 + 10.0 * kick) / PI
	led_t += dt
	if led_t > 1.0 / 30.0:
		led_t = 0.0
		led.F = F
		led.alarm = alarm
		led.queue_redraw()
