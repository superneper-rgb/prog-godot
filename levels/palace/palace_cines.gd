class_name PalaceCines
extends Cutscene
## The Pervert Palace's arrival (user, 2026-11-19: "something like a cutscene in place of the loading screen"): the site's half of it. The street's half (levels/hub/hub_sambo.gd) walks Prog
## and Sambo to the site's gate on the quay and tilts up the crane, and cuts to black for the load (no loading card). This half opens on the crane: the camera comes down out of the dark past
## the jib, over the lit floors and the festoons, down to the gate as the two of them walk in off the quay, the foreman and his crew on their break by the drum. When it is done the talk
## with the foreman begins. It is the level's `cine` while `on` (core/view.gd): the world runs, Prog and Sambo are walked by it. X skips it.

const DUR := 6.4

var lv: PalaceLevel
var play := false      # (core/view.gd: not a playable cutscene)
var t := 0.0
var has_sambo := true
var _p0 := Vector3.ZERO


func setup(level: PalaceLevel) -> void:
	lv = level


func arrive() -> void:
	on = true
	t = 0.0
	var P := Game.player
	P.x = 128.6
	P.z = 200.4
	P.y = PalaceSite.Y0
	P.yaw = PI / 2.0
	_p0 = Vector3(P.x, P.y, P.z)
	lv.sambo.place(Vector3(128.2, PalaceSite.Y0, 202.6), PI / 2.0)
	lv.sambo.body.selfie = 1.0
	enter_cine(true)
	update(0.0)


func skip() -> void:
	if not on:
		return
	t = DUR
	update(0.0)


func update(dt: float) -> void:
	if not on:
		return
	t += dt
	var u := clampf(t / DUR, 0.0, 1.0)
	# the two of them walk in off the quay: Prog to a step inside the gate, Sambo beside him, filming himself
	var P := Game.player
	var walk := seg(t, 1.6, 5.4)
	if walk > 0.0 and walk < 1.0 and P.x < 132.9:
		player_step(dt, 0.55, PI / 2.0 + 0.04)
	var sp := Vector3(128.2, PalaceSite.Y0, 202.6).lerp(Vector3(133.4, PalaceSite.Y0, 202.4), ease_(seg(t, 1.3, 5.6)))
	var moving := seg(t, 1.3, 5.6) > 0.0 and seg(t, 1.3, 5.6) < 1.0
	lv.sambo.pos = sp
	lv.sambo.yaw = PI / 2.0
	lv.sambo.body.speed = 1.0 if moving else 0.0
	lv.sambo.body.global_position = sp
	lv.sambo.body.rotation.y = lv.sambo.yaw
	lv.sambo.body.update(dt)
	# the camera: down out of the dark past the jib, over the floors, to the gate
	var a := Vector3(170.0, 46.0, 236.0)
	var b := Vector3(150.0, 14.0, 214.0)
	var c := Vector3(138.6, -7.6, 196.4)
	var e := ease_(u)
	var pos := a.lerp(b, e).lerp(b.lerp(c, e), e)
	var look := Vector3(160.0, 24.0, 200.0).lerp(Vector3(132.0, -8.6, 201.4), ease_(seg(t, 0.4, DUR)))
	shot(pos, look, lerpf(52.0, 46.0, e))
	if t >= DUR:
		on = false
		leave_cine()
		lv.sambo.body.speed = 0.0
		lv._start_talk()


## (Prog walks; the rig is left where the shot ends, behind him)
func pose_player(_an: Animator) -> void:
	pass
