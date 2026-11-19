class_name ClubLevel
extends ExportedLevel
## CLUB 9 (JS levels/club/level.js): the nightclub's show on top of its exported world: slow colour drift, moving heads that sweep the floor, the turning chandelier, the LED wall behind the DJ, the beat in the lights, and its music.
## (The JS holds the show still under prefers-reduced-motion, a browser setting. Godot has none to read.)

const BEAT_HZ := 2.4
const PAL_HEX: Array[int] = [0x8a3bff, 0xd51c38, 0x671bb7]      # restrained purple / blue / magenta
const BEAM_SHADER := preload("res://levels/club/club_beam.gdshader")
const BEAM_LEN := 6.4                # the exported beam cone: 6.4 m along +z, 1.3 m radius at the end
const BEAM_DEG := 4.5                # half-angle of a beam now (the export's was 11.5)
const PHRASE := 16.0                 # beats per look
# The show's looks, run in this order, one per phrase: SWEEP all together, FAN out and in mirrored, CIRCLE each round its own spot, HIT all on the
# floor's centre chasing on the beat, CROSS corner to corner on every bar.
enum Look { SWEEP, FAN, CIRCLE, HIT, CROSS }
const LOOK_SEQ: Array[int] = [Look.SWEEP, Look.FAN, Look.CIRCLE, Look.HIT, Look.SWEEP, Look.CROSS, Look.FAN, Look.HIT]
# colour pairs per phrase (even heads, odd heads); white is the punch a real rig keeps for the big moments
const COLS: Array = [[0x7a2cff, 0x7a2cff], [0xe0183a, 0x7a2cff], [0xc020d8, 0xc020d8], [0xf2eaff, 0xe0183a], [0x5a2cff, 0xc020d8], [0xe0183a, 0xe0183a],
	[0x7a2cff, 0xf2eaff], [0xf2eaff, 0xf2eaff]]

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
var _crowd: ClubCrowd = null
var _dress: ClubDressing = null
var phone_guy: PhoneGuy = null      # Pauly, the green alien on the hallway payphone (until the talk with him is had)
const MUSIC_VOL := 0.11
var cine: BarOrder = null      # ordering at the bar: the bartender brings the drinks pad over (core/view.gd reads it as the level's cutscene)


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
	# 2026-11-16 (user: "the light show in club 9 is unrealistic and lame"): the four moving heads were wide flat-alpha cones (a purple slab when the camera
	# met one) drifting in slow colour, two of them with soft-edged spots that made pink blobs on the floor. Now: tight beams in haze (club_beam.gdshader),
	# a hard-edged spot with a gobo on every head, and a show that runs looks phrase by phrase, with slewed moves, colour cuts and a blackout into each downbeat.
	var gobo := _gobo()
	for i in 4:
		var yoke := _named("ClubYoke%d" % i)
		var aim := _named("ClubAim%d" % i)
		if yoke == null or aim == null:
			continue
		var bn := _named("ClubBeam%d" % i)
		var bm := ShaderMaterial.new()
		bm.shader = BEAM_SHADER
		bm.set_shader_parameter(&"len", BEAM_LEN)
		for mi: Node in ([bn] if bn is MeshInstance3D else bn.find_children("*", "MeshInstance3D", true, false)) if bn != null else []:
			(mi as MeshInstance3D).material_override = bm
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var old := _light("ClubSpot%d" % i)
		if old != null:
			old.visible = false
		var spot := SpotLight3D.new()
		spot.name = "HeadSpot%d" % i
		spot.spot_angle = BEAM_DEG * 1.15
		spot.spot_angle_attenuation = 5.0      # a hard edge: a tight beam throws a crisp pool, not a blob
		spot.spot_range = 14.0
		spot.spot_attenuation = 0.6
		spot.light_projector = gobo
		spot.shadow_enabled = false
		spot.light_specular = 0.6
		add_child(spot)
		spot.global_position = aim.global_position
		_heads.append({"yoke": yoke, "aim": aim, "beam_node": bn, "beam": bm, "lens": _mat_of(_named("ClubLens%d" % i)), "spot": spot,
			"hx": yoke.global_position.x, "hz": yoke.global_position.z, "pt": Vector3(yoke.global_position.x * 0.4, 0.0, 6.0)})
	_ball = _named("Rotating wrought-iron chandelier")
	_floor_a = _light("club_floorA")
	_floor_b = _light("club_floorB")
	_dj = _light("club_dj")
	_fill = _light("club_fill")
	_vip = _light("club_vip")
	_lounge = _light("club_lounge")
	for l: Light3D in [_floor_a, _floor_b, _dj, _vip, _lounge, _light("club_south"), _light("club_vest"), _light("club_barA"), _light("club_barB")]:
		if l != null:
			l.light_specular = 0.04      # the washes' highlights were soft pink blobs sliding over the polished floor; the heads' pools carry the floor now
	var south := _light("club_south")
	if south != null:      # it hung 0.7 m under the ceiling at the entrance and blew it out into a white-violet slab across the top of the screen
		south.global_position.y = 2.3
		south.light_energy *= 0.6
	_build_screen()
	_dress = ClubDressing.new()
	add_child(_dress)
	_dress.build(self)
	# The exported club was empty: its new city goths and green alien regulars dance here, with a bartender working the bar.
	_crowd = ClubCrowd.new()
	add_child(_crowd)
	_crowd.build()
	Game.shops.bar.bar = _crowd.serve      # a drink bought at the bar's terminal: the bartender makes it
	cine = BarOrder.new(_crowd, Game.shops.bar)
	Game.shops.bar.summon = cine.start      # (2026-11-16, user: X at the bar no longer pops the terminal up; the bartender brings his pad over and the menu is on it)
	var track: AudioStreamMP3 = load("res://assets/sfx/club9-timbre-industrial.mp3")
	track.loop = true
	_music = MusicTrack.new(track, MUSIC_VOL)      # the same recording as the street entrance, with the indoor full-range mix (was 0.32: far too loud inside the club)
	add_child(_music)
	if not Game.story_get(PhoneGuy.FLAG):
		phone_guy = PhoneGuy.new()
		add_child(phone_guy)
		phone_guy.build(self)


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


## The heads' gobo: a ring of soft dots round a centre dot, the stock "breakup" wheel a moving head throws onto a dance floor. Made once at load.
static func _gobo() -> ImageTexture:
	const N := 64
	var img := Image.create(N, N, false, Image.FORMAT_L8)
	var c := Vector2(N, N) * 0.5
	var dots: Array[Vector2] = [Vector2.ZERO]
	for k in 7:
		dots.append(Vector2.from_angle(TAU * k / 7.0) * 0.52)
	for y in N:
		for x in N:
			var p := (Vector2(x, y) - c) / (N * 0.5)
			var v := 0.0
			for d: Vector2 in dots:
				v = maxf(v, 1.0 - smoothstep(0.17, 0.24, p.distance_to(d)))
			v *= 1.0 - smoothstep(0.9, 1.0, p.length())
			img.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(img)


## Where head i aims on the floor in a look, at beat b.
func _look_at(look: int, i: int, b: float) -> Vector3:
	var hx: float = _heads[i]["hx"]
	var hz: float = _heads[i]["hz"]
	var left := hx < 0.0
	match look:
		Look.SWEEP:      # all together, side to side over two bars, the front pair and back pair a beat apart
			return Vector3(4.0 * sin(PI * (b - (0.0 if hz < 6.0 else 1.0)) / 8.0), 0.0, 6.0 + (hz - 6.0) * 0.45)
		Look.FAN:      # mirrored: out to the walls and back in to the middle, once a bar
			var o := 0.5 - 0.5 * cos(PI * b / 4.0)
			return Vector3((-1.0 if left else 1.0) * lerpf(0.6, 4.8, o), 0.0, hz + (6.0 - hz) * 0.3)
		Look.CIRCLE:      # each one round its own patch of floor, a quarter turn apart
			var a := PI * b / 8.0 + float(i) * PI * 0.5
			return Vector3(hx * 0.45 + cos(a) * 1.8, 0.0, hz + (6.0 - hz) * 0.35 + sin(a) * 1.8)
		Look.HIT:      # all on the middle of the floor, a small turn so the pools shimmer
			var a := PI * b / 4.0 + float(i) * PI * 0.5
			return Vector3(cos(a) * 0.7, 0.0, 6.0 + sin(a) * 0.7)
		_:      # CROSS: to the far corner, and over to the other on each bar (the slew makes the move)
			var bar := int(floorf(b / 4.0)) % 2
			return Vector3((3.6 if left else -3.6) * (1.0 if bar == 0 else 0.3), 0.0, (9.0 if hz < 6.0 else 3.0) if bar == 0 else 6.0)


## JS: linear colour on a light
static func _light_col(l: Light3D, c: Color) -> void:
	if l != null:
		l.light_color = c.linear_to_srgb()


static func _energy(l: Light3D, intensity: float) -> void:
	if l != null:
		l.light_energy = intensity / PI      # three.js units (see ExportedLevel._build_lights)


func tick(dt: float) -> void:
	# 2026-11-17: a talk here (Pauly's on the payphone runs two minutes) no longer stops the club dead: the show, the dancers and the talker go on with the real clock while the
	# game holds Prog for it. (Paused or in a menu, it all still holds.)
	var talk := dt <= 0.0 and Game.dialogue.on and not Game.paused
	if talk:
		dt = Game.frame_real_dt
	if dt <= 0.0:
		return
	dt = minf(dt, 0.05)
	_time += dt
	if _crowd != null:
		_crowd.tick(_time, dt)
	if phone_guy != null:
		phone_guy.tick(_time, dt)
		if _music != null:
			_music.volume = MUSIC_VOL * (1.0 - 0.55 * phone_guy.hush())      # the music sits back while he can be heard
	if talk:
		Game.enemy_views.flush()      # (the frame's own upload is skipped while the game holds)
	if cine != null:
		cine.tick(dt)
	var t := _time
	var beat := pow(0.5 + 0.5 * cos(_time * TAU * BEAT_HZ), 3.0)
	var counter := pow(0.5 + 0.5 * cos(_time * TAU * BEAT_HZ + PI), 3.0)
	_light_col(_floor_a, Color.hex(0xc51b35ff).srgb_to_linear())
	_light_col(_floor_b, Color.hex(0x8126cfff).srgb_to_linear())
	# the washes sit low and breathe with the beat, so the room stays dark and the beams carry the show (they pumped 65-135 and lit the whole floor pink)
	_energy(_floor_a, 30.0 + beat * 22.0)
	_energy(_floor_b, 30.0 + counter * 22.0)
	var P := Game.player
	if P != null and _fill != null:
		_fill.global_position = Vector3(P.x, P.y + 2.6, P.z - 1.4)      # a faint cool light that travels with the player so the character never goes silhouette-black
	_light_col(_vip, _tint(t * 0.04 + 2.4))
	_light_col(_lounge, _tint(t * 0.035 + 0.6))
	_show(t, dt, beat)
	if _ball != null:
		_ball.rotation.y += dt * 0.12
	if _dress != null:
		_dress.tick(t, beat)


## The moving heads, phrase by phrase: a look from LOOK_SEQ, a colour pair cut in on the downbeat, the heads slewing to their marks like motors
## (fast, but never a jump), a chase on the beat in HIT and CROSS, and every beam dark for the last beat before the phrase lands.
func _show(t: float, dt: float, beat: float) -> void:
	var b := t * BEAT_HZ
	var ph := int(floorf(b / PHRASE))
	var in_ph := fposmod(b, PHRASE)
	var look: int = LOOK_SEQ[ph % LOOK_SEQ.size()]
	var pair: Array = COLS[ph % COLS.size()]
	var hit := 1.0 - smoothstep(0.0, 0.5, in_ph)      # the downbeat slam
	var dark := smoothstep(PHRASE - 1.0, PHRASE - 0.9, in_ph)      # the breath before it
	var beat_i := int(floorf(b)) % 4
	var dj_c := Color.hex((int(pair[0]) << 8) | 0xff)
	if _dj != null:
		_dj.light_color = dj_c
	_energy(_dj, (30.0 + beat * 25.0) * (1.0 - dark))
	for i in _heads.size():
		var hd: Dictionary = _heads[i]
		var goal := _look_at(look, i, b)
		var pt: Vector3 = hd["pt"]
		pt = pt.move_toward(goal, dt * 9.0).lerp(goal, minf(1.0, dt * 5.0))      # a head's pan/tilt motors: quick, with a top speed
		hd["pt"] = pt
		var yoke: Node3D = hd["yoke"]
		var hx: float = hd["hx"]
		var hz: float = hd["hz"]
		yoke.rotation.y = atan2(pt.x - hx, pt.z - hz)      # the yoke turns about y, the head aims at the floor spot (its cone follows)
		var aim: Node3D = hd["aim"]
		aim.look_at(pt, Vector3.UP, true)
		var throw := aim.global_position.distance_to(pt)
		var bn: Node3D = hd["beam_node"]
		if bn != null:
			var w := tan(deg_to_rad(BEAM_DEG)) * BEAM_LEN / 1.3
			bn.scale = Vector3(w, w, throw / BEAM_LEN)      # (the export's cone, narrowed, and run to the floor)
		var lvl := 0.75 + 0.25 * beat
		if look == Look.HIT or look == Look.CROSS:
			lvl = 1.0 if beat_i == i else 0.18 + 0.12 * beat      # a chase round the four on the beat
		lvl = maxf(lvl, hit) * (1.0 - dark)
		var disp := Color.hex((int(pair[i % 2]) << 8) | 0xff)
		var rad := Game.view.display_to_radiance(disp)      # JS: toneMapped false, the colour is what reaches the screen
		var bm: ShaderMaterial = hd["beam"]
		bm.set_shader_parameter(&"col", Color(rad.r, rad.g, rad.b))
		bm.set_shader_parameter(&"power", 1.25 * lvl)
		var lens: BaseMaterial3D = hd["lens"]
		if lens != null:
			lens.albedo_color = Color(rad.r * (0.2 + 2.0 * lvl), rad.g * (0.2 + 2.0 * lvl), rad.b * (0.2 + 2.0 * lvl), lens.albedo_color.a)
		var spot: SpotLight3D = hd["spot"]
		spot.global_position = aim.global_position
		spot.look_at(pt)
		spot.light_color = disp
		spot.light_energy = 22.0 * lvl
		spot.spot_range = throw + 2.0


func start_music() -> void:
	if _music != null and not _music.playing:
		_music.play()


## Shops.near_bar: is Prog at the bar (X opens its terminal)?
func near_bar() -> bool:
	return Game.player != null and ClubCrowd.near_bar(Game.player) and not Game.drunk.busy() and not (cine != null and cine.on)


func on_exit() -> void:
	Game.shops.bar.bar = Callable()
	Game.shops.bar.summon = Callable()
	if _crowd != null:
		_crowd.dispose()
	if _music != null:
		_music.stop()
