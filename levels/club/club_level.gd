class_name ClubLevel
extends ExportedLevel
## CLUB 9 (JS levels/club/level.js): the nightclub's show on top of its exported world: slow colour drift, moving heads that sweep the floor, the turning chandelier, the LED wall behind the DJ, the beat in the lights, and its music.
## (The JS holds the show still under prefers-reduced-motion, a browser setting. Godot has none to read.)

const BEAT_HZ := 2.4
const PAL_HEX: Array[int] = [0x8a3bff, 0xd51c38, 0x671bb7]      # restrained purple / blue / magenta

var _time := 0.0
var _pal: Array[Color] = []
var _heads: Array[Dictionary] = []
var _ball: Node3D = null
var _floor_a: Light3D = null
var _floor_b: Light3D = null
var _dj: Light3D = null
var _fill: Light3D = null
var _vip: Light3D = null
var _lounge: Light3D = null
var _music: MusicTrack = null
var _screen: ShaderMaterial = null


## The JS works in linear colour: three's Color(hex) decodes, and lerp mixes the decoded values.
func _tint(u: float) -> Color:
	u = fposmod(u, 3.0)
	var i := int(floorf(u))
	return _pal[i].lerp(_pal[(i + 1) % 3], u - i)


func _named(n: String) -> Node3D:
	var a := node_named(n)
	if a.is_empty():
		push_warning("club: nothing named %s in the export (node tools/export/export.mjs level club)" % n)
		return null
	return a[0]


## A named light. (Its name also marks an empty node from the export: the Light3D is the one to drive.)
func _light(n: String) -> Light3D:
	for x: Variant in node_named(n):
		if x is Light3D:
			return x
	return null


## The material a named mesh draws with: a mesh it holds, or the first under it.
static func _mat_of(n: Node) -> BaseMaterial3D:
	if n == null:
		return null
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).mesh.get_surface_count() > 0:
		return (n as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
	for c in n.get_children():
		var m := _mat_of(c)
		if m != null:
			return m
	return null


func build() -> void:
	super.build()
	for h: int in PAL_HEX:
		_pal.append(Color.hex((h << 8) | 0xff).srgb_to_linear())
	for i in 4:
		var yoke := _named("ClubYoke%d" % i)
		var aim := _named("ClubAim%d" % i)
		if yoke == null or aim == null:
			continue
		var beam := _mat_of(_named("ClubBeam%d" % i))
		var spot := _light("ClubSpot%d" % i)
		_heads.append({"yoke": yoke, "aim": aim, "beam": beam, "lens": _mat_of(_named("ClubLens%d" % i)), "spot": spot, "phase": i * 1.7, "hx": yoke.global_position.x, "hz": yoke.global_position.z,
			"base_opacity": 0.2, "base_energy": spot.light_energy if spot != null else 0.0})
	_ball = _named("Rotating wrought-iron chandelier")
	_floor_a = _light("club_floorA")
	_floor_b = _light("club_floorB")
	_dj = _light("club_dj")
	_fill = _light("club_fill")
	_vip = _light("club_vip")
	_lounge = _light("club_lounge")
	_build_screen()
	var track: AudioStreamMP3 = load("res://assets/sfx/club9-timbre-industrial.mp3")
	track.loop = true
	_music = MusicTrack.new(track, 0.11)      # the same recording as the street entrance, with the indoor full-range mix (was 0.32: far too loud inside the club)
	add_child(_music)


## LED wall behind the DJ: slow drifting bands in the club colours. The JS redraws a canvas about 8 times a second; this draws the same picture, on the same steps.
func _build_screen() -> void:
	var n := _named("ClubDjScreen")
	var mi: MeshInstance3D = null
	if n is MeshInstance3D:
		mi = n
	elif n != null:
		for c in n.get_children():
			if c is MeshInstance3D:
				mi = c
	if mi == null:
		return
	_screen = ShaderMaterial.new()
	_screen.shader = load("res://levels/club/dj_screen.gdshader")
	_screen.set_shader_parameter(&"pal0", _pal[0])
	_screen.set_shader_parameter(&"pal1", _pal[1])
	_screen.set_shader_parameter(&"pal2", _pal[2])
	mi.mesh.surface_set_material(0, _screen)


## JS: linear colour on a light
static func _light_col(l: Light3D, c: Color) -> void:
	if l != null:
		l.light_color = c.linear_to_srgb()


static func _energy(l: Light3D, intensity: float) -> void:
	if l != null:
		l.light_energy = intensity / PI      # three.js units (see ExportedLevel._build_lights)


func tick(dt: float) -> void:
	if dt <= 0.0:
		return
	dt = minf(dt, 0.05)
	_time += dt
	var t := _time
	var beat := pow(0.5 + 0.5 * cos(_time * TAU * BEAT_HZ), 3.0)
	var counter := pow(0.5 + 0.5 * cos(_time * TAU * BEAT_HZ + PI), 3.0)
	_light_col(_floor_a, Color.hex(0xc51b35ff).srgb_to_linear())
	_light_col(_floor_b, Color.hex(0x8126cfff).srgb_to_linear())
	_energy(_floor_a, 65.0 + beat * 70.0)
	_energy(_floor_b, 65.0 + counter * 70.0)
	_energy(_dj, 35.0 + beat * 20.0)
	var P := Game.player
	if P != null and _fill != null:
		_fill.global_position = Vector3(P.x, P.y + 2.6, P.z - 1.4)      # a faint cool light that travels with the player so the character never goes silhouette-black
	_light_col(_vip, _tint(t * 0.04 + 2.4))
	_light_col(_lounge, _tint(t * 0.035 + 0.6))
	_light_col(_dj, _tint(t * 0.12 + 0.8))
	for hd: Dictionary in _heads:
		var phase: float = hd["phase"]
		var a := t * 0.31 + phase
		var tx := sin(a) * 4.6
		var tz := 5.8 + cos(a * 0.83 + phase) * 3.1
		var yoke: Node3D = hd["yoke"]
		var hx: float = hd["hx"]
		var hz: float = hd["hz"]
		yoke.rotation.y = atan2(tx - hx, tz - hz)      # the yoke turns about y, the head aims at the floor spot (its cone follows)
		var aim: Node3D = hd["aim"]
		aim.look_at(Vector3(tx, 0.0, tz), Vector3.UP, true)
		var c := _tint(t * 0.2 + phase * 0.6)
		var disp := c.linear_to_srgb()
		var rad := Game.view.display_to_radiance(disp)      # JS: toneMapped false, the colour is what reaches the screen
		var bm: BaseMaterial3D = hd["beam"]
		if bm != null:
			bm.albedo_color = Color(rad.r, rad.g, rad.b, float(hd["base_opacity"]) * (0.55 + 0.45 * beat))
		var lens: BaseMaterial3D = hd["lens"]
		if lens != null:
			lens.albedo_color = Color(rad.r, rad.g, rad.b, lens.albedo_color.a)
		var spot: SpotLight3D = hd["spot"]
		if spot != null:
			spot.light_energy = float(hd["base_energy"]) * (0.65 + 0.35 * beat)
			spot.light_color = disp
			spot.look_at(Vector3(tx, 0.0, tz))
	if _ball != null:
		_ball.rotation.y += dt * 0.12


func start_music() -> void:
	if _music != null and not _music.playing:
		_music.play()


func on_exit() -> void:
	if _music != null:
		_music.stop()
