class_name ApartmentLevel
extends ExportedLevel
## PROG'S APARTMENT (JS levels/apartment/level.js): home. No combat, no objectives: a place to save (the bed), and the way in and out is the front door. Sleeping fades to black and saves. Its parts: apt_props.gd (TV, lights, cigarette, drip, mirror, city), apt_roaches.gd, apt_closet.gd, apt_audio.gd, apt_wakeup.gd (the wake-up cutscene, console only in the JS).

const H := 2.7           # floor to ceiling
const SPAWN := {"x": -0.95, "y": 0.02, "z": 3.55}
const BED_SPOT := Vector2((1.62 + 3.62) / 2.0 + 0.3, -1.4 + 0.35)
const TV_SPOT := Vector2(0.95 - 0.45, (-2.95 - 1.15) / 2.0)
const CLOSET := {"x0": 5.38, "x1": 5.98, "z0": -2.35, "z1": -1.0, "top": 2.05}


## A level cutscene (View.apply_camera and the frame read `on`, `camera`, `play`): the sleep, which holds the camera where it was; the closet's push-in; the wake-up.
class Cine:
	var L: ApartmentLevel
	var play := false
	var sleep_cam := View.Shot.new()
	var sleeping := false
	var on: bool:
		get:
			return sleeping or (L.closet != null and L.closet.is_on()) or (L.wakeup != null and L.wakeup.on)
	var camera: View.Shot:
		get:
			if L.wakeup != null and L.wakeup.on:
				return L.wakeup.camera
			if L.closet != null and L.closet.is_on():
				return L.closet.camera
			return sleep_cam

	func pose_player(an: Animator) -> void:
		if L.wakeup != null and L.wakeup.on:
			L.wakeup.pose_player(an)
		elif L.closet != null and L.closet.is_on():
			L.closet.pose_player(an)


var cine := Cine.new()
var props: AptProps = null
var closet: AptCloset = null
var audio: AptAudio = null
var wakeup: AptWakeup = null
var _time := 0.0
var _sleep_t := 0.0
var _saved := false
var _click: AudioStreamWAV = null


func build() -> void:
	super.build()
	cine.L = self
	var mats := {}
	var stack: Array[Node] = [self]
	while not stack.is_empty():      # (the glow materials the tube and the vanity flicker through)
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var me: Mesh = (n as MeshInstance3D).mesh
			for s in me.get_surface_count():
				var m := me.surface_get_material(s)
				if m != null and m.resource_name != "":
					mats[m.resource_name] = m
	props = AptProps.new(self, mats)
	closet = AptCloset.new(self, CLOSET)
	add_child(closet)
	audio = AptAudio.new()
	add_child(audio)
	wakeup = AptWakeup.new(self)
	add_child(wakeup)
	for d: Dictionary in portals:      # JS active: () => !(wakeup && wakeup.on)
		d["active"] = func() -> bool: return not wakeup.on
	actions.append(closet.action)
	actions.append({"x": TV_SPOT.x, "z": TV_SPOT.y, "label": func() -> String: return "TURN OFF — TV" if props.tv_on else "TURN ON — TV",
		"active": func(p: Player) -> bool: return not _busy() and U.hyp(p.x - TV_SPOT.x, p.z - TV_SPOT.y) < 1.0,
		"run": func() -> void:
			props.toggle_tv()
			_click_sound()})
	actions.append({"x": BED_SPOT.x, "z": BED_SPOT.y, "label": "SLEEP — SAVE GAME",
		"active": func(p: Player) -> bool: return not _busy() and U.hyp(p.x - BED_SPOT.x, p.z - BED_SPOT.y) < 1.0,
		"run": _start_sleep})


func _busy() -> bool:
	return closet.is_on() or cine.sleeping or wakeup.on


func _click_sound() -> void:
	if _click == null:
		_click = Cutscene.synth(0.06, [[0.0, 0.05, 900.0, 540.0, &"square", 0.03, 0.002]], [])
	Game.sfx.clip(_click, {"wet": 0.1})


func on_exit() -> void:
	if cine.sleeping:
		Game.ui.set_fade(false)
		Game.hud.set_suppressed(false)
	cine.sleeping = false
	if wakeup != null:
		wakeup.dispose()


func _start_sleep() -> void:
	cine.sleeping = true
	_sleep_t = 0.0
	_saved = false
	var c := Game.camera
	cine.sleep_cam.pos = c.global_position
	cine.sleep_cam.look = c.global_position - c.global_transform.basis.z * 3.0
	Game.hud.set_suppressed(true)
	Game.ui.set_fade(true)


func tick(dt: float) -> void:
	var P := Game.player
	_time += dt
	if P != null and not P.dead and P.y > H - 0.5:      # safety net: nobody stands up there
		P.x = SPAWN.x
		P.z = SPAWN.z
		P.y = SPAWN.y
		P.vx = 0.0
		P.vy = 0.0
		P.vz = 0.0
		Game.rig.snap_to(P)
	var rdt := dt if dt > 0.0 else get_process_delta_time()
	if props != null and dt > 0.0:
		props.update(dt, _time, P)
		audio.update(dt, P, props)
	if closet != null:
		closet.update_closet(rdt)
	if wakeup != null:
		wakeup.update(dt)
	if cine.sleeping:
		_sleep_t += rdt
		if _sleep_t > 1.0 and not _saved:
			_saved = true
			Game.save_game(true)
			Game.ui.set_fade(true, "GAME SAVED")
			_click_sound()
		if _sleep_t > 2.6:
			Game.ui.set_fade(false)
		if _sleep_t > 3.3:
			cine.sleeping = false
			Game.hud.set_suppressed(false)
			Inp.guard_arm()
