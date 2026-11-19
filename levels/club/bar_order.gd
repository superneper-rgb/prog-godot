class_name BarOrder
extends RefCounted
## CLUB 9: ordering a drink. X at the bar calls the bartender over; he brings the drinks pad (bar_pad.gd) up from under the counter and holds it out, while the camera leaves Prog's
## shoulder, watches him come and closes in on the pad until it fills the screen exactly where the bar menu draws the same picture; the pad's glass boots green and the menu
## (BarMenu, club_bar.gd) takes over. When the menu shuts, the pad is there again, the camera eases back to the game's and the pad goes under the counter (or he makes the drink).
## It is the level's `cine` (core/view.gd): while `on` the camera is `camera` and the player gets no input.

const FOV := 44.0
const OVER_T := 0.85        # rig to the two-shot (s)
const BOOT_T := 0.32        # the pad's glass coming on before the menu takes over
const BACK_T := 0.85        # back to the rig after the menu

var on := false
var play := false
var camera := View.Shot.new(Vector3.ZERO, Vector3.FORWARD, FOV)
var crowd: ClubCrowd
var menu: BarMenu
var phase := &"off"         # come (he walks over, lifts the pad), boot, menu, back
var t := 0.0
var _from := View.Shot.new()
var _from_fov := 70.0
var _yaw0 := 0.0
var _up0 := Vector3.UP


func _init(c: ClubCrowd, m: BarMenu) -> void:
	crowd = c
	menu = m


func start() -> void:
	var cam := Game.view.camera
	_from.pos = cam.global_position
	_from.look = cam.global_position - cam.global_basis.z * 4.0
	_from_fov = cam.fov
	_yaw0 = Game.player.yaw
	Game.rig.yaw = PI / 2.0      # (the game's camera settles behind him facing the bar meanwhile, so the way back is short)
	crowd.summon()
	crowd.pad.set_lit(1.0)
	crowd.pad.set_screen(0.0)
	on = true
	phase = &"come"
	t = 0.0
	_put(_from.pos, _from.look, _from_fov, Vector3.UP)


## Where the camera has to be for the pad to fill the screen as the menu's picture does (VendorMenu.stage_rect): square on to its face, centred, at the distance that makes
## its height the picture's share of the screen at this FOV.
func pad_shot() -> Array:
	var xf := crowd.pad.global_transform
	var sz := Game.view.get_viewport().get_visible_rect().size
	var share := menu.stage_rect(sz).size.y / sz.y
	var d := BarPad.HEIGHT / share / (2.0 * tan(deg_to_rad(FOV) * 0.5))
	var n := xf.basis.z.normalized()
	return [xf.origin + n * d, xf.origin, xf.basis.y.normalized()]


## the two-shot while he comes over: high over Prog's shoulder, looking down across the counter at the bartender
func _two_shot() -> Array:
	var P := Game.player
	var b := crowd.bartender.global_position
	var at := Vector3(b.x - 0.45, 1.0, b.z)
	var side := 1.0 if P.z < 2.5 else -1.0      # (high over the shoulder away from the couple at the near end of the bar, so nobody on a stool blocks him)
	var pos := Vector3(minf(P.x, 9.6) - 0.35, 2.3, P.z + 0.85 * side)
	return [pos, at]


func _put(pos: Vector3, look: Vector3, fov: float, up: Vector3) -> void:
	camera.pos = pos
	camera.look = look
	camera.fov = fov
	camera.up = up


func tick(dt: float) -> void:
	if not on:
		return
	t += dt
	var P := Game.player
	match phase:
		&"come":
			P.yaw = lerp_angle(_yaw0, PI / 2.0, Gait.sstep(0.0, 0.6, t))      # he turns to the bar
			var k := Gait.sstep(0.0, OVER_T, t)
			var two := _two_shot()
			var pos: Vector3 = _from.pos.lerp(two[0], k)
			var look: Vector3 = _from.look.lerp(two[1], k)
			var fov := lerpf(_from_fov, FOV + 6.0, k)
			var job := crowd.pad_job()
			if job == &"lift" or job == &"hold":
				var u := crowd.pad_u() if job == &"lift" else 1.0
				var e := Gait.sstep(0.05, 1.0, u)
				var e2 := e * e * (3.0 - 2.0 * e)      # (eased twice: a slow start off the two-shot, a soft landing on the pad)
				var ps := pad_shot()
				pos = pos.lerp(ps[0], e2)
				look = look.lerp(ps[1], e2)
				fov = lerpf(fov, FOV, e2)
				crowd.pad.set_lit(lerpf(1.0, 0.0, Gait.sstep(0.55, 1.0, u)))
				_put(pos, look, fov, Vector3.UP.lerp(ps[2], e2).normalized())
				if job == &"hold":
					phase = &"boot"
					t = 0.0
				return
			_put(pos, look, fov, Vector3.UP)
		&"boot":
			var ps := pad_shot()
			_put(ps[0], ps[1], FOV, ps[2])
			var f := 1.0 if fmod(t, 0.09) < 0.06 else 0.55      # (the tube catching)
			crowd.pad.set_screen(clampf(t / BOOT_T, 0.0, 1.0) * f)
			if t >= BOOT_T:
				crowd.pad.set_screen(1.0)
				phase = &"menu"
				t = 0.0
				menu.open_now()
		&"menu":      # (the level is held while the menu is up; this runs again once it has shut)
			if menu.is_open:
				return
			crowd.pad.set_screen(0.0)
			crowd.release()
			_from.pos = camera.pos
			_from.look = camera.look
			_up0 = camera.up
			phase = &"back"
			t = 0.0
		&"back":
			var rig := Game.rig
			var k := Gait.sstep(0.0, BACK_T, t)
			k = k * k * (3.0 - 2.0 * k)
			crowd.pad.set_lit(minf(1.0, t / 0.3))
			_put(_from.pos.lerp(rig.pos, k), _from.look.lerp(rig.look, k), lerpf(FOV, Config.fov, k), _up0.lerp(Vector3.UP, k).normalized())
			if t >= BACK_T:
				stop()


func stop() -> void:
	on = false
	phase = &"off"
	camera.up = Vector3.ZERO
