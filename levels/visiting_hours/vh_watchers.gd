class_name VhWatchers
extends RefCounted
## VISITING HOURS: who watches the approach (JS patrol.js, section 3). The tower searchlights (VhPrison moves them; here: are you in a lit patch, out in the open?), the patrol car going round the levee road swinging its spotlight from the marsh to the canal and back, and the guards on foot (kit stealth: the outfall man in the canal pacing past the pipe's mouth, two on the gate apron with the hearse). Out in a light, the light stops on you and turns amber; stay in it and you are made. Crouched in a reed bed, or with something solid between you and the lamp, the lights do not see you.

const CAR_SPOT := 11.0      # the car's spotlight hits the ground this far out, a patch this wide (m)
const CAR_R := 3.2
const W := VhLayout.W

var lv: ExportedLevel
var world: World
var prison: VhPrison
var audio: VhAudio
var st: StealthKit
var mine: Array = []      # (the guards this file spawned: despawned on every reset, never left to pile up)
var car: Node3D
var spot: SpotLight3D
var beam: Node3D
var amber: Array[MeshInstance3D] = []
var lamp_local := Vector3.ZERO
var s := 0.0
var v := 9.0
var t := 0.0
var expose := 0.0
var by: Variant = null
var caught_t := -1.0
var last_why := ""
var lock: Variant = null      # {at, beam}
var lamp_w := Vector3.ZERO
var aim := Vector3.ZERO
var on_caught := Callable()
var tgt: StealthKit.Guard = null


func _init(p_lv: ExportedLevel, p_world: World, p_prison: VhPrison, p_audio: VhAudio, p_lamp: Variant) -> void:
	lv = p_lv
	world = p_world
	prison = p_prison
	audio = p_audio
	st = StealthKit.new(lv, world)
	st.lit_at = _lit_at
	st.on_alarm = func(g: StealthKit.Guard, why: String, _P: Variant = null) -> void: caught("heard" if why == "heard" else "guard", g)
	car = VhKit.one(lv, "vh-patrol-car")
	spot = VhKit.light(lv, "vh-patrol-spot") as SpotLight3D
	beam = VhKit.one(lv, "vh-patrol-beam")
	for mi in VhKit.meshes(beam):
		mi.extra_cull_margin = 60.0
	for n: Node3D in lv.node_named("vh-patrol-amber"):
		var a := MsKit.sprite8(n.get_parent(), 0xffa020, 0.15, 1.1)
		a.position = n.position
		n.visible = false
		amber.append(a)
	lamp_local = VhPrison.v3(p_lamp)
	s = VhLayout.ring_road.len_ * 0.6


# how lit a spot is, for the guards' eyes: the hut lamp, the gate apron, the wall lamps along the floodlit strip, a searchlight's patch; the marsh is dark
func _lit_at(x: float, y: float, z: float) -> float:
	var k := 0.5
	var hut: Dictionary = prison.hut_lamp
	if not hut.is_empty() and U.hyp(x - float(hut.x), z - float(hut.z)) < float(hut.r):
		k = maxf(k, 1.3)
	if U.hyp(x - (W - 6.0), z - float(VhLayout.GATE.z)) < 15.0:
		k = maxf(k, 1.6)
	if y > VhLayout.PAD - 0.5:
		for p: Dictionary in prison.wall_lamps:
			if U.hyp(x - float(p.x), z - float(p.z)) < 8.0:
				k = maxf(k, 1.4)
				break
	for b in prison.beams:
		if b.spot_r > 0.0 and U.hyp(x - b.aim.x, z - b.aim.z) < b.spot_r:
			k = maxf(k, 2.0)
	return k


func in_bed(P: Player) -> bool:
	for b: Array in VhLayout.BEDS:
		if U.hyp(P.x - float(b[0]), P.z - float(b[1])) < float(b[2]) * 0.92:
			return true
	return false


## is P out in the open as seen from (x, y, z): nothing solid between, not hidden in the reeds
func exposed_to(P: Player, x: float, y: float, z: float) -> bool:
	if P.crouching and in_bed(P):
		return false
	var cy := P.y + (0.65 if P.crouching else 1.15)
	var dx := P.x - x
	var dy := cy - y
	var dz := P.z - z
	var d := sqrt(dx * dx + dy * dy + dz * dz)
	var o := minf(9.0, d * 0.5)      # (from a few metres out: the lamp sits inside its tower's collider)
	var ux := dx / d
	var uy := dy / d
	var uz := dz / d
	return world.ray_clear(x + ux * o, y + uy * o, z + uz * o, ux, uy, uz, d - o, 0.05) >= d - o - 0.45


func caught(why: String, p_by: Variant = null) -> void:
	if caught_t >= 0.0:
		return
	caught_t = 0.0
	last_why = why
	by = p_by
	audio.siren()
	if on_caught.is_valid():
		on_caught.call(why)


## dt, P (the player), live = section 3 running (else the car just drives and nobody is looking)
func update(dt: float, P: Player, live: bool) -> void:
	t += dt
	var R := VhLayout.ring_road
	# ---- the car: round the levee road counterclockwise, slower in the bends; the spotlight swings from the marsh (left) through ahead to the canal (right)
	var ahead := VhLayout.at(R, fmod(s + 8.0, R.len_))
	var here := VhLayout.at(R, fmod(s, R.len_))
	var turn := absf(VhLayout.wrap_a(ahead.yaw - here.yaw))
	v += ((5.0 if turn > 0.15 else 9.5) - v) * minf(1.0, dt * 1.5)
	s = fmod(s + v * dt, R.len_)
	var p := VhLayout.at(R, s)
	car.global_transform = Transform3D(Basis(Vector3.UP, p.yaw), Vector3(p.x, VhLayout.LEVEE, p.z))
	var swing := sin(t * 0.42) * 1.45
	var h := p.yaw + swing
	lamp_w = car.global_transform * lamp_local
	aim = Vector3(lamp_w.x + sin(h) * CAR_SPOT, 0.0, lamp_w.z + cos(h) * CAR_SPOT)
	# the ground's height under the patch (its offset from the wall: pad, embankment, canal, road, bank, marsh)
	var n := VhLayout.nearest(R, aim.x, aim.z)
	var inward := (aim.x - R.x[n.i]) * -cos(R.yaw[n.i]) + (aim.z - R.z[n.i]) * sin(R.yaw[n.i])
	var O: Dictionary = VhLayout.OFF
	var off := float(O.road_c) - inward
	if off < float(O.fence):
		aim.y = VhLayout.PAD
	elif off < float(O.lip):
		aim.y = VhLayout.PAD + (VhLayout.LEVEE - VhLayout.PAD) * (off - float(O.fence)) / (float(O.lip) - float(O.fence))
	elif off < float(O.road0):
		aim.y = 0.12
	elif off < float(O.road1):
		aim.y = VhLayout.LEVEE
	else:
		aim.y = maxf(0.0, VhLayout.LEVEE * (1.0 - (off - float(O.road1)) / 3.0))
	if spot != null:
		spot.global_position = lamp_w
		spot.look_at(aim)
	var vv := aim - lamp_w
	var ln := vv.length()
	if ln > 0.01:
		beam.global_transform = Transform3D(Basis.looking_at(vv / ln, Vector3.UP, true).scaled_local(Vector3(1.0, 1.0, ln)), lamp_w)
	for i in amber.size():
		MsKit.opa(amber[i], 0.9 if sin(t * 3.0 + i * PI) > 0.0 else 0.15)

	st.update(dt, P)
	lock = null
	if not live or P == null or P.dead or caught_t >= 0.0:
		if caught_t >= 0.0:
			caught_t += dt
		expose = maxf(0.0, expose - dt)
		return
	# ---- who can see P right now: a tower's patch, the car's patch, the car's headlights on the road ahead
	var worst_b: VhPrison.Beam = null
	var worst_kind := ""
	var rate := 0.0
	for b in prison.beams:
		if b.spot_r <= 0.0:
			continue
		var d := U.hyp(P.x - b.aim.x, P.z - b.aim.z)
		if d < b.spot_r * 0.85 and exposed_to(P, b.lamp.x, b.lamp.y, b.lamp.z):
			var r := 1.0 / 1.5
			if r > rate:
				rate = r
				worst_kind = "tower"
				worst_b = b
	if U.hyp(P.x - aim.x, P.z - aim.z) < CAR_R and exposed_to(P, lamp_w.x, lamp_w.y, lamp_w.z):
		rate = maxf(rate, 1.0 / 0.7)
		worst_kind = "car"
		worst_b = null
	var dx := P.x - p.x
	var dz := P.z - p.z
	var dd := U.hyp(dx, dz)
	if dd < 16.0 and absf(VhLayout.wrap_a(atan2(dx, dz) - p.yaw)) < 0.4 and exposed_to(P, p.x, VhLayout.LEVEE + 1.0, p.z):
		rate = maxf(rate, 1.0 / 0.5)
		worst_kind = "car"
		worst_b = null
	if worst_kind != "":
		expose += dt * rate
		by = worst_b
	else:
		expose = maxf(0.0, expose - dt * 0.8)
	# the warning: the light stops on you and goes amber (a tower's beam is held on you by the level; the car brakes)
	for b in prison.beams:
		b.lock = expose if worst_b == b else maxf(0.0, b.lock - dt)
	if worst_kind == "tower" and expose > 0.25:
		lock = {"at": Vector3(P.x, P.y, P.z), "beam": worst_b}
	if worst_kind == "car" and expose > 0.2:
		v *= exp(-dt * 4.0)
	if expose >= 1.0:
		caught("car" if worst_kind == "car" else "tower", worst_b)


## the beam the level holds on the player
func lock_beam() -> VhPrison.Beam:
	if lock != null:
		return lock.beam
	if caught_t >= 0.0 and by is VhPrison.Beam:
		return by
	return null


## checkpoint: the car somewhere it is not looking at you, nobody alarmed, guards (re)spawned at their posts
func reset(guards: bool = true, car_at: float = 0.62) -> void:
	caught_t = -1.0
	expose = 0.0
	lock = null
	s = VhLayout.ring_road.len_ * car_at
	v = 9.0
	for b in prison.beams:
		b.lock = 0.0
	st.clear()
	_clear_mine()
	if guards:
		var list := [
			{"id": "outfall", "at": [W - 18.0, 0.0, 958.0], "yaw": 0.0, "patrol": [[W - 18.0 + 0.3, 969.0], [W - 18.0 + 0.3, 950.0]], "range": 17.0},      # down in the canal, pacing past the bars the contact cut, torch on
			{"id": "apron1", "at": [W - 4.5, VhLayout.PAD, float(VhLayout.GATE.z) - 5.5], "yaw": -PI / 2.0 - 0.3, "range": 19.0},
			{"id": "apron2", "at": [W - 9.5, VhLayout.PAD, float(VhLayout.GATE.z) + 3.2], "yaw": -PI / 2.0 + 0.4, "range": 19.0},
		]
		for gd: Dictionary in list:
			var at: Array = gd.at
			var r := Game.spawn_enemy({"x": at[0], "y": float(at[1]) + 0.05, "z": at[2], "yaw": gd.yaw}, {"kind": "goon", "costume": "goint_guard", "gun": "pistol", "no_respawn": true})
			if r == null:
				continue
			mine.append(r)
			var o := {"post": [at[0], at[2], gd.yaw], "range": gd.range}
			if gd.has("patrol"):
				o["patrol"] = gd.patrol
			st.add(r, o)


func _clear_mine() -> void:
	for r: Robot in mine:
		if not r.gone:
			Game.despawn_enemy(r)
	mine.clear()


func takedown_active(P: Player) -> bool:
	tgt = st.takedown_target(P)
	return tgt != null


func takedown_run() -> void:
	if tgt != null:
		st.takedown(tgt, Game.player)
		audio.splash(0.4)


func dispose() -> void:
	st.clear()
	_clear_mine()
