class_name VhInside
extends RefCounted
## VISITING HOURS: section 4's machinery inside the admin block (JS inside.js). The night shift (kit stealth), the cameras on B1 and 1F panning their corridors and painting what they see on the floor; while Dale is at his monitors, a camera that holds you long enough is Dale seeing you. Dale's console: every camera in the block (a level cine, green phosphor, the HUD hidden) and the monitor wall itself (feeds drawn into small targets in turn); CAM 08 is the warden's office. The door board releases Stair B's 2F door. Going loud: the lockdown. Klaxons, the lights drop to red, the phone jammer comes up, every guard comes for you.

const F1 := 3.0
const F2 := 9.0
const F4 := 21.0
# (design metres: mapped in _init)
const GUARDS4 := [
	{"id": "b1", "at": [204.0, 0.0, 971.0], "yaw": 0.0, "patrol": [[204.0, 971.0], [204.0, 974.6], [204.0, 961.1], [212.4, 961.1], [204.0, 961.1]], "range": 13.0},      # (starts walking AWAY up C2: facing the junction he made you the moment you came out of the pump room)
	{"id": "locker", "at": [209.6, F1, 956.2], "yaw": PI, "range": 10.0, "smoke": true, "hold": true},      # (hold: busy at something; stays put, facing it, until he notices)
	{"id": "dale", "at": [206.9, F1, 967.05], "yaw": 0.0, "range": 8.0, "smoke": true, "hold": true},
	{"id": "f2a", "at": [192.8, F2, 961.2], "yaw": PI / 2.0, "patrol": [[192.8, 961.2], [212.2, 961.2]], "range": 14.0},
	{"id": "f2b", "at": [210.8, F2, 967.7], "yaw": -PI / 2.0, "patrol": [[210.8, 967.7], [194.4, 967.7]], "range": 14.0},
	{"id": "tv", "at": [214.6, F2, 971.6], "yaw": PI / 2.0, "range": 9.0, "smoke": true, "hold": true},
]
# the cameras: two that matter (watched while Dale is at his desk), the rest only feeds
const CAMS_D := [
	{"id": "b1", "name": "CAM 01 · B1 CORRIDOR", "floor": &"b1", "at": [213.85, 2.45, 962.2], "yaw": -PI / 2.0, "pan": 0.75, "pitch": -0.36, "live": true, "range": 7.5},
	{"id": "f1", "name": "CAM 02 · 1F CORRIDOR", "floor": &"f1", "at": [202.85, F1 + 3.3, 962.2], "yaw": PI / 2.0, "pan": 0.75, "pitch": -0.3, "live": true, "range": 7.5},
	{"id": "lobby", "name": "CAM 03 · LOBBY", "floor": &"f1", "at": [219.3, F1 + 3.3, 975.3], "look": [207.0, F1 + 0.6, 969.5]},
	{"id": "visit", "name": "CAM 04 · VISITING", "floor": &"f1", "at": [202.1, F1 + 3.3, 954.7], "look": [194.0, F1 + 0.6, 966.0]},
	{"id": "claims", "name": "CAM 05 · 2F CLAIMS", "floor": &"f2", "at": [213.9, F2 + 3.15, 954.7], "look": [196.0, F2 + 0.4, 966.0]},
	{"id": "staff", "name": "CAM 06 · 2F STAFF ROOM", "floor": &"f2", "at": [209.6, F2 + 3.15, 975.3], "look": [218.0, F2 + 0.6, 970.5]},
	{"id": "lift", "name": "CAM 07 · 4F LIFT", "floor": &"f4", "at": [202.6, F4 + 3.4, 967.5], "look": [206.4, F4 + 0.6, 974.2]},
	{"id": "warden", "name": "CAM 08 · 4F WARDEN", "floor": &"f4", "at": [215.6, F4 + 3.75, 962.45], "look": [212.2, F4 + 0.75, 958.9]},
]
const RANGE := 12.0      # a live camera: reach (m; a camera's own `range` wins), half-angles across and down its view
const HA := 0.42
const VA := 0.3
const N_CONE := 10
const RTW := 160
const RTH := 120
const CONE_SHADER := """shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
#include "res://levels/shaders/common.gdshaderinc"
uniform vec3 col = vec3(0.55, 1.0, 0.7);
uniform float opacity = 0.0;
void fragment() {
	// the painted view: a phosphor-green patch, brightest at its far edge (the camera's eye line), scan bars across it and a hard rim all round, so where it stops reads at a glance
	float y = (1.0 - UV.y) * 64.0;
	float x = UV.x * 128.0;
	float a = mix(0.3, 0.75, UV.y);
	if (y > 6.0 && y < 58.0 && mod(y - 6.0, 7.0) < 3.0) { a *= 0.55; }
	if (y < 4.0 || y > 60.0 || x < 4.0 || x > 124.0) { a = 1.0; }
	ALBEDO = display_to_radiance(srgb_encode(col * a * opacity));
}
"""
const GREEN_SHADER := """shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform vec2 res = vec2(640.0, 360.0);
void fragment() {
	// (JS: half resolution, pixelated, grayscale(1) sepia(1) hue-rotate(68deg) saturate(2.4) contrast(1.3) brightness(1.1))
	vec2 q = (floor(SCREEN_UV * res) + 0.5) / res;
	vec3 c = texture(screen, q).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	l = (l - 0.5) * 1.3 + 0.5;
	COLOR = vec4(vec3(0.42, 1.0, 0.62) * clamp(l, 0.0, 1.0) * 1.1, 1.0);
}
"""


class Cam:
	var id := ""
	var name := ""
	var floor_id: StringName
	var at := Vector3.ZERO
	var head: Node3D
	var tally: StandardMaterial3D
	var yaw0 := 0.0
	var pitch0 := 0.0
	var yaw_now := 0.0
	var pan := 0.0
	var live := false
	var range_ := RANGE
	var seen := 0.0
	var t := 0.0
	var cone: MeshInstance3D
	var cone_mesh: ArrayMesh
	var cone_mat: ShaderMaterial
	var feed: Camera3D


class Cine:
	var on := false
	var play := false
	var camera := View.Shot.new(Vector3.ZERO, Vector3.FORWARD, 64.0)

	func pose_player(_a: Variant) -> void:
		pass


var lv: ExportedLevel
var world: World
var admin: VhAdmin
var audio: VhAudio
var people: VhPeople
var st: StealthKit
var mine: Array = []
var guards: Array = []
var cams: Array[Cam] = []
var beacons: Array[Light3D] = []
var loud := false
var why := ""
var dale: Robot = null
var cam_seen := 0.0
var alarm_t := 0.0
var feed_i := 7
var feed_t := 0
var found := {}
var hold_t := 0.0
var released := false
var klax_t := 0.0
var rr := 0
var fr := 0
var on_loud := Callable()
var on_find := Callable()
var warned := false
var feeds_live := false
var cine := Cine.new()
var stand := Vector2.ZERO
var wall := Vector3.ZERO
var layer: CanvasLayer
var lbl: Label
var green: ColorRect
var feeds: Array[SubViewport] = []
var atlas: SubViewport
var crt: ShaderMaterial
var board_canvas: VhKit.Canvas
var _board_flash := 0
var _feed_floor: StringName = &""


func _init(p_lv: ExportedLevel, p_admin: VhAdmin, p_people: VhPeople, p_audio: VhAudio, fur: Dictionary) -> void:
	lv = p_lv
	world = lv.world
	admin = p_admin
	people = p_people
	audio = p_audio
	st = StealthKit.new(lv, world)
	st.lit_at = admin.lit_at
	st.on_alarm = func(g: StealthKit.Guard, w: String, _P: Variant = null) -> void: go_loud("heard" if w == "heard" else "seen", g)
	var spots: Dictionary = fur.spots
	# design -> world: a camera keeps its bracket on its wall, a guard's post and beat move with the rooms (bigger rooms: they see a little further, the cameras' painted patches cover the same stretch of corridor), Dale sits at his console
	for g: Dictionary in GUARDS4:
		var at0: Array = g.at
		var q := g.duplicate()
		q["at"] = spots.dale if g.id == "dale" else admin.pt(at0[0], at0[1], at0[2])
		q["range"] = float(g.range) * 1.25
		if g.has("patrol"):
			var pat: Array = []
			for p: Array in g.patrol:
				var w := admin.pt(p[0], at0[1], p[1])
				pat.append([w[0], w[2]])
			q["patrol"] = pat
		guards.append(q)
	for n: Node3D in lv.node_named("vh-camcone"):
		n.visible = false
	var shader := Shader.new()
	shader.code = CONE_SHADER
	for d: Dictionary in CAMS_D:
		var c := Cam.new()
		c.id = d.id
		c.name = d.name
		c.floor_id = d.floor
		var a0: Array = d.at
		var aw := admin.pt(a0[0], a0[1], a0[2])
		c.at = Vector3(aw[0], aw[1], aw[2])
		c.head = VhKit.one(lv, "vh-camhead-" + c.id)
		var tn := VhKit.one(lv, "vh-tally-" + c.id)
		c.tally = VhKit.unlit(0xff2a1a)
		for mi in VhKit.meshes(tn):
			mi.material_override = c.tally
		if d.has("look"):
			var l0: Array = d.look
			var lw := admin.pt(l0[0], l0[1], l0[2])
			c.yaw0 = atan2(float(lw[0]) - c.at.x, float(lw[2]) - c.at.z)
			c.pitch0 = atan2(float(lw[1]) - c.at.y, U.hyp(float(lw[0]) - c.at.x, float(lw[2]) - c.at.z))
		else:
			c.yaw0 = d.yaw
			c.pitch0 = d.pitch
		c.yaw_now = c.yaw0      # (t 0: a sweep starts at its end turned aside, not on the door you come in by)
		c.pan = float(d.get("pan", 0.0))
		c.live = bool(d.get("live", false))
		if d.has("range"):
			c.range_ = float(d.range) * VhLayout.ADK
		if c.live:
			c.cone_mesh = ArrayMesh.new()
			c.cone = MeshInstance3D.new()
			c.cone.mesh = c.cone_mesh
			c.cone.extra_cull_margin = 50.0
			c.cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.cone_mat = ShaderMaterial.new()
			c.cone_mat.shader = shader
			c.cone.material_override = c.cone_mat
			(admin.floors[c.floor_id] as Node3D).add_child(c.cone)
		cams.append(c)
	beacons.assign(_lights("vh-beacon"))
	# ---- the console: the CCTV cine and the monitor wall's feeds
	layer = CanvasLayer.new()
	layer.layer = 13
	layer.visible = false
	lv.add_child(layer)
	green = ColorRect.new()
	green.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gs := Shader.new()
	gs.code = GREEN_SHADER
	var gm := ShaderMaterial.new()
	gm.shader = gs
	green.material = gm
	green.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(green)
	layer.add_child(_Scan.new())
	var vt: Font = load("res://assets/fonts/VT323-Regular.ttf")
	lbl = _label(vt, 26, Color("#b8ffcc"))
	lbl.position = Vector2(50.0, 36.0)
	layer.add_child(lbl)
	var rec := _label(vt, 26, Color("#ff6a50"))
	rec.text = "● REC"
	rec.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rec.position = Vector2(-120.0, 36.0)
	layer.add_child(rec)
	var hint := _label(vt, 17, Color(0.72, 1.0, 0.8, 0.65))
	hint.text = "LMB / RT NEXT  ·  RMB / LT BACK  ·  SPACE / B LEAVE"
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-220.0, -44.0)
	layer.add_child(hint)
	var ss: Array = spots.stand
	stand = Vector2(ss[0], ss[2])
	var wa := admin.pt(206.8, F1, 965.6)
	wall = Vector3(wa[0], wa[1], wa[2])
	_build_feeds()
	# ---- the door board: a mimic of the block, a lamp a door; X releases Stair B's 2F door
	board_canvas = VhKit.Canvas.new(256, 192, _draw_board)
	lv.add_child(board_canvas)
	for mi in VhKit.meshes(VhKit.one(lv, "vh-door-board")):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = board_canvas.get_texture()
		mi.material_override = m


func _lights(nm: String) -> Array[Light3D]:
	var out: Array[Light3D] = []
	for n: Node3D in lv.node_named(nm):
		if n is Light3D:
			out.append(n as Light3D)
			(n as Light3D).light_energy = 0.0
	return out


func _label(f: Font, size: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override(&"font", f)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", c)
	l.add_theme_color_override(&"font_shadow_color", Color(c.r, c.g, c.b, 0.5))
	return l


## the scan lines, the vignette and the slow rolling bar over the feed
class _Scan:
	extends Control
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(_dt: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var h := size.y
		var y := 0.0
		while y < h:
			draw_rect(Rect2(0.0, y, size.x, 2.0), Color(0.0, 0.0, 0.0, 0.22))
			y += 4.0
		var roll := fmod(Time.get_ticks_msec() / 4500.0, 1.0) * (h * 1.15) - h * 0.15
		draw_rect(Rect2(0.0, roll, size.x, h * 0.14), Color(0.63, 1.0, 0.75, 0.05))


# All eight feeds share one atlas (4 x 2, each feed drawn into its own cell) and the sixteen screens are the export's merged mesh: one draw for the wall. A feed is its own small viewport drawn once in turn; the atlas pastes them. (The floors are on their own render layers: a feed's camera sees its floor while the player's sees his.)
func _build_feeds() -> void:
	atlas = SubViewport.new()
	atlas.size = Vector2i(RTW * 4, RTH * 2)
	atlas.disable_3d = true
	atlas.render_target_update_mode = SubViewport.UPDATE_ONCE
	lv.add_child(atlas)
	for i in cams.size():
		var f := SubViewport.new()
		f.size = Vector2i(RTW, RTH)
		f.own_world_3d = false
		f.positional_shadow_atlas_size = 0
		f.render_target_update_mode = SubViewport.UPDATE_DISABLED
		f.msaa_3d = Viewport.MSAA_DISABLED
		f.handle_input_locally = false
		f.gui_disable_input = true
		lv.add_child(f)
		var c3 := Camera3D.new()
		c3.fov = 64.0 * 0.75      # (three.js fov is vertical as here; 4:3 target)
		c3.fov = 64.0
		c3.near = 0.05
		c3.far = 200.0
		f.add_child(c3)
		cams[i].feed = c3
		feeds.append(f)
		var tr := TextureRect.new()
		tr.texture = f.get_texture()
		tr.position = Vector2((i % 4) * RTW, (i / 4) * RTH)
		tr.size = Vector2(RTW, RTH)
		atlas.add_child(tr)
	crt = lv.shader_ports.mats.get("shader_0c99d2#0")
	if crt != null:
		crt.set_shader_parameter(&"map", atlas.get_texture())
	# the floors on their own render layers
	var bit := 10
	for id: StringName in admin.floors:
		_layer_all(admin.floors[id], 1 << bit)
		bit += 1


static func _layer_all(root: Node, mask: int) -> void:
	var walk: Array[Node] = [root]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if n is VisualInstance3D:
			(n as VisualInstance3D).layers = mask


static func floor_bit(admin_: VhAdmin, id: StringName) -> int:
	var bit := 10
	for k: StringName in admin_.floors:
		if k == id:
			return 1 << bit
		bit += 1
	return 0


const BASE_MASK := (1 << 10) - 1


## the player's camera sees the floors the admin shows; this frame's feed floor is drawn for the feed alone
func main_mask() -> int:
	var m := BASE_MASK
	for id: StringName in admin.floors:
		if (admin.floors[id] as Node3D).visible and id != _feed_floor:
			m |= floor_bit(admin, id)
	return m


static func _dir_of(yaw: float, pitch: float) -> Vector3:
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))


## a live camera's floor patch: the near and far edges of its view across its width, cut short by walls
func _paint_cone(c: Cam) -> void:
	var y0: float = float(VhLayout.FLW[c.floor_id]) + 0.03
	var pts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in N_CONE:
		var yaw := c.yaw_now - HA + 2.0 * HA * i / (N_CONE - 1)
		for j in 2:
			var p := c.pitch0 - VA if j == 0 else c.pitch0 + VA
			var D := _dir_of(yaw, p)
			var tt := (y0 - c.at.y) / D.y if D.y < -0.01 else c.range_
			tt = minf(tt, c.range_)
			var clear := world.ray_clear(c.at.x + D.x * 0.3, c.at.y + D.y * 0.3, c.at.z + D.z * 0.3, D.x, D.y, D.z, tt, 0.02) + 0.3
			tt = minf(tt, clear)
			pts.append(Vector3(c.at.x + D.x * tt, y0, c.at.z + D.z * tt))
			uvs.append(Vector2(float(i) / float(N_CONE - 1), float(j)))      # (u across the view, v near -> far)
	for i in N_CONE - 1:
		idx.append_array(PackedInt32Array([i * 2, i * 2 + 1, i * 2 + 2, i * 2 + 1, i * 2 + 3, i * 2 + 2]))
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	c.cone_mesh.clear_surfaces()
	c.cone_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)


func _edge(c: Cam, yaw: float, p: float, y0: float) -> float:      # (as _paint_cone draws it)
	var D := _dir_of(yaw, p)
	var tt := (y0 - c.at.y) / D.y if D.y < -0.01 else c.range_
	tt = minf(tt, c.range_)
	tt = minf(tt, world.ray_clear(c.at.x + D.x * 0.3, c.at.y + D.y * 0.3, c.at.z + D.z * 0.3, D.x, D.y, D.z, tt, 0.02) + 0.3)
	return tt * cos(p)


## can live camera c see P right now? What you see is what it sees: P has to be standing on the patch it paints (the floor just under the camera, short of the patch's near edge, is out of its view), and nothing may stand between the lens and P's chest (cover counts)
func _cam_sees(c: Cam, P: Player) -> bool:
	var dx := P.x - c.at.x
	var dz := P.z - c.at.z
	var h := U.hyp(dx, dz)
	var yaw := atan2(dx, dz)
	var fl: float = VhLayout.FLW[c.floor_id]
	var y0 := fl + 0.03
	if absf(VhLayout.wrap_a(yaw - c.yaw_now)) > HA or absf(P.y - fl) > 1.2:
		return false
	if h < _edge(c, yaw, c.pitch0 - VA, y0) or h > _edge(c, yaw, c.pitch0 + VA, y0):
		return false
	var cy := P.y + (0.7 if P.crouching else 1.2)
	var V := Vector3(dx, cy - c.at.y, dz)
	var d := V.length()
	V /= d
	return world.ray_clear(c.at.x + V.x * 0.3, c.at.y + V.y * 0.3, c.at.z + V.z * 0.3, V.x, V.y, V.z, d - 0.3, 0.05) >= d - 0.75


func open_cctv() -> void:
	cine.on = true
	hold_t = 0.0
	layer.visible = true
	Game.hud.set_suppressed(true)
	audio.tone(900.0, 0.08, 0.08)
	var vs := lv.get_viewport().get_visible_rect().size
	(green.material as ShaderMaterial).set_shader_parameter(&"res", vs * 0.5)


func close_cctv() -> void:
	if cine.on:
		Game.hud.set_suppressed(false)
	cine.on = false
	layer.visible = false


func _cctv(dt: float, t: float) -> void:
	var P: Player = Game.player
	if P != null:
		P.x = stand.x
		P.z = stand.y
		P.vx = 0.0
		P.vz = 0.0
		P.yaw = 0.0
	if Inp.btn(&"jump").pressed or Inp.btn(&"b").pressed:
		close_cctv()
		return
	if Inp.btn(&"attack").pressed or Inp.btn(&"fire").pressed:
		feed_i = (feed_i + 1) % cams.size()
		hold_t = 0.0
		audio.tone(1400.0, 0.05, 0.06)
		audio.noise_burst(0.15, 0.15)
	if Inp.btn(&"ads").pressed:
		feed_i = (feed_i + cams.size() - 1) % cams.size()
		hold_t = 0.0
		audio.tone(1400.0, 0.05, 0.06)
		audio.noise_burst(0.15, 0.15)
	var c: Cam = cams[feed_i]
	var D := _dir_of(c.yaw_now if c.live else c.yaw0 + sin(t * 0.25) * 0.06, c.pitch0)
	cine.camera.pos = c.at + D * 0.3
	cine.camera.look = cine.camera.pos + D * 10.0
	var sec := 3 * 3600 + 12 * 60 + int(t)
	lbl.text = "%s\n%02d:%02d:%02d" % [c.name, (sec / 3600) % 24, (sec / 60) % 60, sec % 60]
	hold_t += dt
	if c.id == "warden" and hold_t > 1.3 and not found.has("fenn"):
		found["fenn"] = true
		if on_find.is_valid():
			on_find.call("fenn")
	if c.id == "lift" and hold_t > 1.3 and not found.has("box"):
		found["box"] = true
		if on_find.is_valid():
			on_find.call("box")


func _draw_feed() -> void:
	# one feed in turn; the floor it needs is switched on for this frame's draw (main_mask keeps it from the player's camera)
	rr = (rr + 1) % cams.size()
	var c: Cam = cams[rr]
	var D := _dir_of(c.yaw_now if c.live else c.yaw0, c.pitch0)
	var pos := c.at + D * 0.3
	c.feed.global_transform = Transform3D(Basis.looking_at(D, Vector3.UP), pos)
	c.feed.cull_mask = BASE_MASK | floor_bit(admin, c.floor_id)
	_feed_floor = c.floor_id if not (admin.floors[c.floor_id] as Node3D).visible else &""
	if _feed_floor != &"":
		(admin.floors[c.floor_id] as Node3D).visible = true
		admin.cur = "?"      # (shown again next frame by the admin's own rule)
	feeds[rr].render_target_update_mode = SubViewport.UPDATE_ONCE
	atlas.render_target_update_mode = SubViewport.UPDATE_ONCE


func _draw_board(g: Control) -> void:
	g.draw_rect(Rect2(0.0, 0.0, 256.0, 192.0), Color("#1c2630"))
	var f := ThemeDB.fallback_font
	g.draw_string(f, Vector2(10.0, 20.0), "DOOR CONTROL · ADMIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#c9d6ea"))
	var rows := [["4F", [["STAIR A", "r"]]], ["3F", [["STAIR A", "r"]]], ["2F", [["STAIR A", "r"], ["STAIR B", "g" if released else "r"]]], ["1F", [["STAIR B", "g"], ["LOBBY", "r"], ["VISIT", "g"]]], ["B1", [["STAIR B", "g"], ["PUMP RM", "g"]]]]
	for i in rows.size():
		var y := 42.0 + i * 30.0
		g.draw_string(f, Vector2(10.0, y + 5.0), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#8aa0b8"))
		var ds: Array = rows[i][1]
		for j in ds.size():
			var x := 46.0 + j * 70.0
			var c := Color("#40ff70") if ds[j][1] == "g" else ((Color("#ff3020") if _board_flash % 2 == 1 else Color("#601010")) if loud else Color("#ff3020"))
			g.draw_circle(Vector2(x, y), 6.0, c)
			g.draw_string(f, Vector2(x + 9.0, y + 4.0), ds[j][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#c9d6ea"))


# ---- going loud: the guards on your floor come for you at once, the others as you reach them (they cannot follow you up a stairwell)
func _engage_near() -> void:
	var P: Player = Game.player
	if P == null:
		return
	for g: StealthKit.Guard in st.guards:
		if not g.r.dead and not g.o.get("engaged", false) and absf(g.r.y - P.y) < 2.0 and U.hyp(g.r.x - P.x, g.r.z - P.z) < 28.0:
			g.o["engaged"] = true
			(g.r as FointGoon).on_break = false
			st.engage(g, P)


## quiet: a checkpoint past the lockdown puts it back on without the radio's lines
func go_loud(p_why: String, _by: Variant = null, quiet: bool = false) -> void:
	if loud:
		return
	loud = true
	why = p_why
	alarm_t = 0.0
	klax_t = 0.0
	audio.jam(true)
	audio.siren()
	_engage_near()
	for c in cams:
		if c.cone != null:
			c.cone.visible = false
	board_canvas.redraw()
	if not quiet and on_loud.is_valid():
		on_loud.call(p_why)


## checkpoint: quiet again, everybody back at his post, the doors as the night shift left them
func reset(guards_on: bool = true, p_released: bool = false, dale_down: bool = false) -> void:
	loud = false
	why = ""
	cam_seen = 0.0
	for c in cams:
		c.t = 0.0
		c.seen = 0.0
	released = p_released
	found.clear()
	warned = false
	if cine.on:
		close_cctv()
	audio.jam(false)
	admin.emergency = 0.0
	for b in beacons:
		b.light_energy = 0.0
	for c in cams:
		if c.cone != null:
			c.cone.visible = true
	admin.unlock("sbF2", p_released)
	admin.unlock("pump", true)
	st.clear()
	_clear_mine()
	dale = null
	if guards_on:
		for gd: Dictionary in guards:
			if gd.id == "dale" and dale_down:
				continue
			var at: Array = gd.at
			var r := Game.spawn_enemy({"x": at[0], "y": float(at[1]) + 0.05, "z": at[2], "yaw": gd.yaw}, {"kind": "goon", "costume": "goint_guard", "gun": "pistol", "no_respawn": true})
			if r == null:
				continue
			(r as FointGoon).on_break = gd.get("smoke", false)
			mine.append(r)
			var o := {"post": [at[0], at[2], gd.yaw], "range": gd.range, "hold": gd.get("hold", false)}
			if gd.has("patrol"):
				o["patrol"] = gd.patrol
			st.add(r, o)
			if gd.id == "dale":
				dale = r
	board_canvas.redraw()


func _clear_mine() -> void:
	for r: Robot in mine:
		if not r.gone:
			Game.despawn_enemy(r)
	mine.clear()


func release() -> void:
	if released:
		return
	released = true
	admin.unlock("sbF2", true)
	audio.tone(110.0, 0.7, 0.18, &"sawtooth")
	audio.thud(0.5)
	board_canvas.redraw()


## dt, P, live = section 4 is being played
func update(dt: float, P: Player, t: float, live: bool) -> void:
	if crt != null:
		crt.set_shader_parameter(&"uT", t)
	if cine.on:
		_cctv(dt, t)
	# a guard on a floor not on show is not drawn: the block's floors show one at a time
	var F: Dictionary = admin.floors
	var bots: Dictionary = Game.fx.bot_by_id if Game.fx != null else {}
	for g: StealthKit.Guard in st.guards:
		var f: Node3D = F.get(admin.floor_at(g.r.y + 0.5))
		var seen := f != null and f.visible
		g.off_view = not seen
		var bv: Variant = bots.get(g.r.id)
		if bv != null:
			(bv.g as Node3D).visible = seen
	st.update(dt, P if live else null)
	for g: StealthKit.Guard in st.guards:
		var r := g.r as FointGoon
		if r.dead:
			continue
		if r.on_break and (g.mode != "calm" or g.sus > 0.2):      # (a smoker who hears something puts it out)
			r.on_break = false
		if g.o.get("hold", false) and g.mode == "calm" and g.sus < 0.3 and not loud:      # (absorbed in what he is doing: slower to feel you behind him)
			var post: Array = g.o.post
			g.sus = maxf(0.0, g.sus - dt * 0.35)
			r.x += (float(post[0]) - r.x) * minf(1.0, dt * 8.0)
			r.z += (float(post[1]) - r.z) * minf(1.0, dt * 8.0)
			r.yaw = post[2]
			r.vx = 0.0
			r.vz = 0.0
	var watched := live and not loud and dale != null and not dale.dead
	# the cameras pan (a pause at each end), the live ones look for P while Dale is watching
	var worst := 0.0
	for c in cams:
		c.t += dt
		if c.pan != 0.0:
			var u := fmod(c.t * 0.1, 2.0)
			var k := u if u < 1.0 else 2.0 - u
			var e := clampf((k - 0.12) / 0.76, 0.0, 1.0)
			c.yaw_now = c.yaw0 + (e * 2.0 - 1.0) * c.pan
		c.head.rotation = Vector3(-c.pitch0, c.yaw_now, 0.0)
		if not c.live:
			continue
		var fv: bool = (F[c.floor_id] as Node3D).visible
		var sees := watched and P != null and fv and _cam_sees(c, P)
		var lit := admin.lit_at(P.x, P.y, P.z) if sees else 0.0
		var rate := 1.0 / 2.4 if lit > 0.8 else 1.0 / 3.8      # (Dale has to notice it on one of sixteen screens)
		# (crouched: a smaller shape on one screen of sixteen; out of the patch the meter drains quickly, so crossing a sweep is a matter of timing, not luck)
		c.seen = c.seen + dt * rate * (0.45 if P.crouching else 1.0) if sees else maxf(0.0, c.seen - dt * 0.9)
		worst = maxf(worst, c.seen)
		c.tally.albedo_color = MsKit.srgb(0x401010 if not watched else (0xffd040 if c.seen > 0.0 and sin(t * (10.0 + c.seen * 30.0)) > 0.0 else 0xff2a1a))
		if c.cone != null and fv:
			fr = (fr + 1) % 3
			if fr == 0:
				_paint_cone(c)
			var a := minf(1.0, c.seen * 2.0)
			var b := maxf(0.0, c.seen * 2.0 - 1.0)      # phosphor green, amber as Dale starts to notice, red as he does
			c.cone_mat.set_shader_parameter(&"col", Vector3(0.55 + 0.45 * a, 1.0 - 0.3 * a - 0.55 * b, 0.7 - 0.5 * a - 0.1 * b))
			c.cone_mat.set_shader_parameter(&"opacity", 0.28 + c.seen * 0.3 if watched else 0.0)
		if c.seen > 0.0 and randf() < dt * 4.0:
			audio.tone(1800.0, 0.03, 0.03, &"sine")
		if c.seen >= 1.0:
			go_loud("camera")
		if not warned and watched and P != null and fv and U.hyp(P.x - c.at.x, P.z - c.at.z) < 10.5 * VhLayout.ADK and absf(P.y - float(VhLayout.FLW[c.floor_id])) < 1.0:      # (the Boss sees it before it sees you)
			warned = true
			if on_find.is_valid():
				on_find.call("camera")
	cam_seen = worst
	# loud: the klaxons go on, the beacons turn, the lights fall to emergency red
	if loud:
		alarm_t += dt
		klax_t -= dt
		_engage_near()
		if klax_t <= 0.0:
			klax_t = 3.8
			audio.siren()
		admin.emergency = minf(1.0, admin.emergency + dt * 2.0)
		for i in beacons.size():
			beacons[i].light_energy = 7.0 * maxf(0.0, sin(t * 5.0 + i * 1.7)) / PI
		var fl := int(floor(t * 3.0))
		if fl != _board_flash:
			_board_flash = fl
			if (F[&"f1"] as Node3D).visible:
				board_canvas.redraw()
	# the monitor wall: a feed every fourth frame while you are near it
	var near_wall := P != null and not cine.on and (F[&"f1"] as Node3D).visible and absf(P.y - float(VhLayout.FLW[&"f1"])) < 2.0 and U.hyp(P.x - wall.x, P.z - wall.z) < 7.0 * VhLayout.ADK
	feeds_live = near_wall or cine.on      # (the 4F people are posed only while a monitor or the cine can show them)
	_feed_floor = &""
	if near_wall:
		feed_t = (feed_t + 1) % 4
		if feed_t == 0:
			_draw_feed()
	if Game.camera != null:
		Game.camera.cull_mask = main_mask()


func dispose() -> void:
	close_cctv()
	st.clear()
	_clear_mine()
	if Game.camera != null:
		Game.camera.cull_mask = 0xFFFFF
