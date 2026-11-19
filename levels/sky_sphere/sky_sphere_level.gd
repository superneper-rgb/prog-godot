class_name SkySphereLevel
extends Level
## Arrival, ticket stand, and the Overcurrent run inside the derelict SkySphere (an illegal underground race since 2026-11-18).

var look := {"bloom": 0.34, "bloom_threshold": 0.82, "bloom_hot": 0.5, "streak": 0.03,
	"streak_tint": [1.0, 0.76, 0.52], "shadow_tint": [1.06, 0.98, 0.9], "gamma": [1.08, 1.0, 0.93],
	"ao": 0.62, "grain": 0.045, "vignette": 0.42}      # (gritty since 2026-11-18: warm smoke, crushed blacks, film grain; was a clean cool neon grade)
var course: SkyCourse
var venue: SkyVenue
var cine: SkyRace
var _pauly: GrayAlienNpc
var _screen: SkyRaceUi
var _ticket := false


func build() -> void:
	no_fight = true
	var spawn := SkyVenue.ARRIVAL
	world.spawn = {"x": spawn.x, "y": spawn.y, "z": spawn.z, "yaw": 0.0}
	Game.view.apply_render_state({"background": Color("0a0806"), "fog": [Color("2a211a"), 30.0, 720.0],
		"tone_mapping": View.TONE_ACES, "exposure": 1.18, "hemi": [Color("8f8172"), Color("2e221a"), 1.65],
		"sun": [Color("ffb27a"), 0.85], "sun_cast": false, "clip": [0.10, 1700.0]})
	course = SkyCourse.new()
	add_child(course)
	course.build()
	venue = SkyVenue.new()
	add_child(venue)
	venue.build(world, course)
	_pauly = GreenAlienBoston.make()
	add_child(_pauly)
	_pauly.name = "PaulyAtTheTickets"
	_set_pauly_waiting()
	cine = SkyRace.new()
	add_child(cine)
	cine.build(course, venue, _pauly)
	var canvas := CanvasLayer.new()
	canvas.layer = 0
	add_child(canvas)
	_screen = SkyRaceUi.new()
	_screen.race = cine
	canvas.add_child(_screen)
	var counter := SkyVenue.TICKETS
	actions.append({"x": counter.x, "z": counter.z, "label": "SELECT RACE", "active": _near_tickets, "run": _open_tickets})
	var return_bay := SkyVenue.SHUTTLE
	portals.append({"id": "return_to_club9", "x": return_bay.x, "z": return_bay.z, "radius": 2.3, "label": "SHUTTLE TO CLUB 9",
		"to": "hub", "spawn_at": "club9", "active": func() -> bool: return not cine.on})


func on_enter() -> void:
	# Discard the old ride's seat blend before the arrival fade reveals the concourse.
	var animator := Game.animator
	if animator != null and animator.seat == null:
		animator.seat_last = null
		animator.w_seat = 0.0


func modal() -> bool:
	return _ticket or (cine != null and cine.results)


func tick(dt: float) -> void:
	if Game.started and not Game.paused and not Inp.text_capture and not Game.forge.is_open and not (Game.freecam != null and Game.freecam.on):
		if modal():
			if Inp.btn(&"b").pressed or Inp.btn(&"pause").pressed:
				Inp.btn(&"pause").pressed = false
				_return_to_concourse()
			elif Inp.key_hit(KEY_X) or Inp.key_hit(KEY_ENTER) or Inp.btn(&"jump").pressed or Inp.btn(&"attack").pressed:
				_ticket = false
				cine.start()
		elif cine.on and Inp.btn(&"b").pressed:
			_return_to_concourse()
	venue.tick(dt)
	cine.tick(dt)
	if not cine.on:
		if dt > 0.0 and Game.player.y < -4.0:
			_return_to_shuttle_bay()
		_pauly.look_at_point(Game.player.x, Game.player.z)
		_pauly.update(Game.time, dt)


func camera_placed(_cam: Vector3, _real_dt: float) -> void:
	_screen.refresh(_ticket)


func on_exit() -> void:
	if _ticket:
		_ticket = false
		Game.hud.set_suppressed(false)
	if cine != null:
		cine.stop()


func _near_tickets(player: Player) -> bool:
	var target := SkyVenue.TICKETS
	return not cine.on and absf(player.y - target.y) < 1.6 and Vector2(player.x - target.x, player.z - target.z).length_squared() < 10.9


func _open_tickets() -> void:
	_ticket = true
	Game.hud.set_suppressed(true)
	CrtTheme.menu_sound("open")
	Inp.guard_arm()


func _return_to_concourse() -> void:
	_ticket = false
	if cine.on:
		cine.stop()
		_set_pauly_waiting()
		Game.rig.snap_to(Game.player)
	Game.hud.set_suppressed(false)
	CrtTheme.menu_sound("close")
	Inp.guard_arm()


func _set_pauly_waiting() -> void:
	var at := SkyVenue.PAULY_AT
	_pauly.place(at.x, at.y, at.z, PI)


func _return_to_shuttle_bay() -> void:
	var p := Game.player
	var at := SkyVenue.ARRIVAL
	p.x = at.x
	p.y = at.y
	p.z = at.z
	p.yaw = 0.0
	p.vx = 0.0
	p.vy = 0.0
	p.vz = 0.0
	Game.rig.snap_to(p)
