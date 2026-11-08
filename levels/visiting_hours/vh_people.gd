class_name VhPeople
extends RefCounted
## VISITING HOURS: the people section 4's cameras see (JS people.js; none of them sees you): Oswald Fenn tied to a chair under the bare bulb in the warden's office, the warden working on him between pulls on the cigar, the two undertakers from MEMORIAL ACRES smoking by the lift with the box, the night man at the lobby desk. The goons' own model, face and dress (a FointGoonView without its AI) in poses made here: seated and bound, the punch, the smoke.

const PUNCH := 6.2      # the warden's cycle (s): smoke, wind up, hit, step back
const STEPS := [0.0, 0.55, 1.0]


class Puppet:
	var R: FointGoon
	var v: FointGoonView


var admin: VhAdmin
var fenn: Puppet
var warden: Puppet
var under: Array[Puppet] = []
var desk: Puppet
var warden_at := Vector3.ZERO
var warden_yaw := 0.0
var flex: Node3D
var bulb: Node3D
var lamp: VhAdmin.Fitting
var lx := 0.0
var ly := 0.0
var lz := 0.0
var t := 0.0
var hit := 0.0
var swing := 0.05
var on_hit := Callable()
var hands := 0.0
var hands_on := false
var dead_t := -1.0
var w_hands := 0.0
var snap := 0.0
var look := 0.0
var look_now := 0.0
var say: Dictionary = {}      # Puppet -> {t, dur, amp, seed}
var halted := false
var face_at: Variant = null      # Vector2 (x, z): the caller may move it
var walk_to: Array = []
var walk_v := 1.1
var back := 0.0


static func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


## a goon body in a costume at [x, y, z] facing yaw, parented to a floor's group
func _puppet(lv: ExportedLevel, parent: Node3D, costume: String, at: Array, yaw: float, scale: float, smoke: bool, id: int) -> Puppet:
	var p := Puppet.new()
	var R := FointGoon.new(lv.world, 9000 + id, float(at[0]), float(at[2]), float(at[1]), {"spawn": {"costume": costume, "gun": "pistol"}})
	R.yaw = yaw
	R.costume = costume      # (JS: a costume by name, whatever the AI's list of costumes says)
	R.role = "security"
	R.h = 1.6
	R.state = &"idle"
	R.on_break = smoke
	R.flashlight = false
	p.R = R
	p.v = FointGoonView.new(R)
	p.v.g.reparent(parent, false)
	p.v.g.scale = Vector3.ONE * scale
	return p


func _init(lv: ExportedLevel, p_admin: VhAdmin, data_fur: Dictionary) -> void:
	admin = p_admin
	for nm: String in by_ids():
		for n: Node3D in lv.node_named(nm):      # (the JS's own copies, posed however the export found them)
			n.visible = false
			n.queue_free()
	var F: Dictionary = admin.floors
	var set_: Dictionary = data_fur.set
	var chair: Array = set_.chair
	var cx: float = chair[0]
	var cy: float = chair[1]
	var cz: float = chair[2]
	var f4: Node3D = F[&"f4"]
	fenn = _puppet(lv, f4, "goint_suit", [cx, cy, cz - 0.05], 0.8, 1.0, false, 3)      # (half toward the camera in the corner)
	warden_at = Vector3(cx - 1.15, cy, cz + 1.2)      # (north-west of him: the camera sees them both)
	warden_yaw = atan2(cx - warden_at.x, cz - warden_at.z)
	warden = _puppet(lv, f4, "goint_warden", [warden_at.x, cy, warden_at.z], warden_yaw, 1.16, true, 11)
	var box: Array = set_.box
	# (against the corridor's far wall, looking at the lift: clear of its doorway, which Prog comes out of in section 5)
	under.append(_puppet(lv, f4, "goint_undertaker", [float(box[0]) - 5.7, cy, float(box[2]) - 1.6], PI / 2.0 + 0.3, 1.0, true, 21))
	under.append(_puppet(lv, f4, "goint_undertaker", [float(box[0]) - 5.9, cy, float(box[2]) + 1.0], PI / 2.0 - 0.2, 1.0, true, 22))
	desk = _puppet(lv, F[&"f1"], "goint_guard", admin.pt(217.2, 3.0, 967.3), PI, 1.0, true, 31)
	# the bare bulb on its flex over him, swinging a little since the last punch
	var ba: Array = set_.bulbAt
	lx = ba[0]
	ly = ba[1]
	lz = ba[2]
	flex = VhKit.one(lv, "vh-flex")
	bulb = VhKit.one(lv, "vh-bulb")
	var best := INF
	for l: VhAdmin.Fitting in admin.lights:      # (admin.light('f4', lx, ly - 1.25, lz, { i: 18 }))
		var d := absf(l.x - lx) + absf(l.y - (ly - 1.25)) + absf(l.z - lz)
		if d < best:
			best = d
			lamp = l


static func by_ids() -> Array[String]:
	var a: Array[String] = []
	for id: int in [3, 11, 21, 22, 31]:
		a.append("vh-puppet-%d" % id)
	return a


## Fenn: sat, slumped, hands behind the chair, feet planted; p_hit = 0..1 snaps his head away (a punch from the front); kick = the round from behind whipping him forward; dead = 0..1 the slump after the shot (no breath, chin on his chest)
func _seated(p: Puppet, dt: float, p_hit: float, dead: float, kick: float) -> void:
	var v := p.v
	var R := p.R
	v.g.position = Vector3(R.x, R.y, R.z)
	v.g.rotation.y = R.yaw
	v.bar.visible = false
	v.t += dt
	v.pose_begin()
	var B := v.B
	if v.face != null:
		v.face.think(dt, false)
	var vt := v.t
	var live := 1.0 - dead
	var br := sin(vt * 1.5) * 0.025 * live
	var sag := sin(vt * 0.23) * 0.12 * live
	var nod: float = v.face.nod if v.face != null else 0.0
	v.offset(&"hips", Vector3(0.0, -(B.rest_mp[v.i_hips].y - 0.56), -0.1))
	v._rot_e(v.i_spine, 0.32 + br + p_hit * -0.25 + dead * 0.32 + kick * 0.3, 0.0, sag * 0.3 + dead * 0.12)
	v._rot_e(v.i_chest, 0.16 - p_hit * 0.35 + dead * 0.3 + kick * 0.4, 0.0, p_hit * 0.25 + dead * 0.1 + dead * 0.16)      # (dead: the shoulders let go, one lower than the other)
	v._rot_e(v.i_head, 0.22 - p_hit * 0.7 + nod * live + dead * 0.85 - look_now * 0.55 * live + kick * 0.75, sag + p_hit * 0.55 - dead * 0.3 + kick * 0.35, 0.2 + p_hit * 0.35 + dead * 0.25 + kick * 0.3)
	for s: String in ["L", "R"]:
		var ti: int = B.i[StringName("thigh." + s)]
		var si: int = B.i[StringName("shin." + s)]
		var th := v.mp(ti)
		v._ik(ti, si, Vector3(th.x * 1.2, B.foot_y + 0.09, th.z + 0.36), Vector3(0.0, 0.3, 1.0), B.len_thigh, B.len_shin)
	for q: Array in [[v.i_ua_l, v.i_fa_l, v.i_hand_l, v.i_fing_l, 1.0], [v.i_ua_r, v.i_fa_r, v.i_hand_r, v.i_fing_r, -1.0]]:
		var sx: float = q[4]
		var sh := v.mp(q[0])
		v._ik(q[0], q[1], Vector3(sx * 0.14, sh.y - (B.len_up + B.len_fore) * 0.72, sh.z - 0.32), Vector3(sx, -0.3, -1.0), B.len_up, B.len_fore)
		v._hand(q[2], q[3], Vector3(-sx * 0.4, -0.3, -0.6))
	if v.face != null:
		v.face.apply_face(dt, false, false)
	if v.dress != null:
		v.dress.update(dt, null, false)
	if v.gun != null:
		v.gun.g.visible = false
	v.push_pose()


## the warden: smoking (the goon view's off-duty pose), then the right fist cocked back, driven into Fenn, the step back
func _punch(p: Puppet, u: float) -> void:
	var v := p.v
	var wind := _ease(clampf((u - 0.52) / 0.1, 0.0, 1.0))
	var drive := _ease(clampf((u - 0.62) / 0.04, 0.0, 1.0))
	var bk := _ease(clampf((u - 0.7) / 0.12, 0.0, 1.0))
	var k := 1.0 - bk
	if wind <= 0.0:
		return
	var B := v.B
	var arm := B.len_up + B.len_fore
	var sh := v.mp(v.i_ua_r)
	v._rot_e(v.i_chest, 0.1 + drive * 0.25 * k, (-0.35 * wind + 0.7 * drive) * k, 0.0)
	var s2 := v.mp(v.i_ua_r)
	var cock := s2 + Vector3(-0.06, -0.1, -0.2)
	var hit_p := s2 + Vector3(0.12, 0.02, arm * 0.95)
	var rest := sh + Vector3(-0.17, -arm * 0.58, -0.05)
	var tgt := rest.lerp(cock, wind * k).lerp(hit_p, drive * k)
	v._ik(v.i_ua_r, v.i_fa_r, tgt, Vector3(-1.0, -0.4, -0.2), B.len_up, B.len_fore)
	v._hand(v.i_hand_r, v.i_fing_r, Vector3(0.0, -0.1, 1.0), Vector3.ZERO, 1.4)
	_finish(v)


func _finish(v: FointGoonView) -> void:
	if v.dress != null:
		v.dress.update(0.0, null, false)
	v.push_pose()


## an undertaker with his hands up (k 0..1): the cigarette forgotten, both arms raised, palms out (section 5: Prog comes out of the lift)
func _hands_up(p: Puppet, k: float) -> void:
	var v := p.v
	var B := v.B
	var arm := B.len_up + B.len_fore
	for q: Array in [[v.i_ua_l, v.i_fa_l, v.i_hand_l, v.i_fing_l, 1.0], [v.i_ua_r, v.i_fa_r, v.i_hand_r, v.i_fing_r, -1.0]]:
		var sx: float = q[4]
		var sh := v.mp(q[0])
		var rest := sh + Vector3(sx * 0.08, -arm * 0.92, 0.02)
		var up := sh + Vector3(sx * 0.3, arm * 0.74, 0.1)
		v._ik(q[0], q[1], rest.lerp(up, _ease(k)), Vector3(sx, -0.2, 0.3), B.len_up, B.len_fore)
		v._hand(q[2], q[3], Vector3(0.0, 1.0, 0.35))
	_finish(v)


## the warden after the shot: leaning back from it, head ducked a little off the window, both hands up at Prog (he is the one with the gun) (k 0..1)
func _cringe(p: Puppet, k: float) -> void:
	if k <= 0.0:
		return
	var v := p.v
	v._rot_e(v.i_chest, -0.16 * k, 0.12 * k, 0.0)
	v._rot_e(v.i_head, 0.12 * k, 0.22 * k, 0.08 * k)      # (lean first: the arms go up from where the shoulders end up)
	_hands_up(p, k)


## the jaw while a voice line plays: stepped, not smooth (shut / half / wide, ~7 beats a second, a rest on every few) so the speaking beats read like a 90s puppet
func _mouth(p: Puppet, dt: float) -> void:
	var f := p.v.face
	if f == null:
		return
	var m: Variant = say.get(p)
	if m == null:
		f.cue = 0.0
		return
	m.t = float(m.t) + dt
	if float(m.t) >= float(m.dur):
		say.erase(p)
		f.cue = 0.0
		return
	var b := int(floor(float(m.t) * 7.0))
	var h := fmod(absf(sin((b + 1) * 12.9898 + float(m.seed)) * 43758.5453), 1.0)
	f.cue = 0.0 if b % 5 == 4 else float(STEPS[1 + (1 if h > 0.55 else 0)]) * (0.0 if float(m.t) > float(m.dur) - 0.15 else 1.0) * float(m.amp)


## the undertakers put their hands up (now: already up, for a checkpoint); off: back to their cigarettes
func surrender(on: bool = true, now: bool = false) -> void:
	hands_on = on
	if now or not on:
		hands = 1.0 if on else 0.0
	for p in under:
		p.R.on_break = not on


## section 6: the shot through the window. Fenn's head snaps, he slumps in the ropes; the warden stops, hands up; the bulb swings hard
func shoot() -> void:
	if dead_t >= 0.0:
		return
	dead_t = 0.0
	hit = 0.0
	snap = 0.05
	say.erase(fenn)
	swing = 0.75
	warden.R.on_break = false


## the warden stops (Prog is in the room): no more punches, the cigar forgotten, he keeps facing at (Vector2 x, z: moved by the caller), backs off along to at a careful speed (Fenn between them), and after the shot steps back from at
func halt(at: Variant, to: Array = [], speed: float = 1.1) -> void:
	halted = true
	face_at = at
	walk_to = to.duplicate()
	walk_v = speed


## who = fenn | warden: flap the jaw for dur s (a voice line's length)
func speak(who: String, dur: float, amp: float = 1.0) -> void:
	say[fenn if who == "fenn" else warden] = {"t": 0.0, "dur": dur, "amp": amp, "seed": randf() * 99.0}


func reset() -> void:
	halted = false
	face_at = null
	walk_to = []
	back = 0.0
	warden.R.x = warden_at.x
	warden.R.z = warden_at.z
	warden.R.yaw = warden_yaw
	say.clear()
	for p: Puppet in [fenn, warden]:
		if p.v.face != null:
			p.v.face.cue = 0.0
			p.v.face.hang = 0.0
	dead_t = -1.0
	hit = 0.0
	w_hands = 0.0
	look = 0.0
	look_now = 0.0
	warden.R.on_break = true


var dead: bool:
	get:
		return dead_t >= 0.0


## live_f4 / live_f1: which floors anyone could see this frame (a puppet off screen is not posed)
func update(dt: float, live_f4: bool, live_f1: bool) -> void:
	t += dt
	var u := fmod(t, PUNCH) / PUNCH
	var gone := dead_t >= 0.0
	if gone:
		dead_t += dt
		w_hands = minf(1.0, w_hands + dt * 3.0)
	look_now += (look - look_now) * minf(1.0, dt * 2.5)
	if not gone and not halted and u > 0.64 and u < 0.66 and hit < 0.5:
		hit = 1.0
		swing = 0.32
		if on_hit.is_valid():
			on_hit.call()
	snap = maxf(0.0, snap - dt)      # (the shot: the head whips for a frame or two, then nothing holds it up)
	hit = 0.0 if gone else maxf(0.0, hit - dt * 1.6)
	swing = maxf(0.05, swing - dt * 0.05)
	var sw := sin(t * 2.1) * swing
	var bx := lx + sin(sw) * 1.6
	var by := ly - cos(sw) * 1.6
	bulb.global_position = Vector3(bx, by, lz)
	if lamp != null:
		if lamp.light != null:
			lamp.light.global_position = Vector3(bx, by - 0.1, lz)
		lamp.x = bx
	flex.global_transform = Transform3D(Basis.from_euler(Vector3(0.0, 0.0, -sw)).scaled_local(Vector3(1.0, 1.6, 1.0)), Vector3((lx + bx) / 2.0, (ly + by) / 2.0, lz))
	if live_f1:
		desk.R.drag = pow(maxf(0.0, sin(t * 0.7 + 31.0)), 6.0)
		desk.v.update(dt, 0.0, Game.fx)
	_mouth(fenn, dt)      # (the line runs its course off screen too: no jaw left hanging open)
	_mouth(warden, dt)
	if not live_f4:
		return
	warden.R.drag = 0.0 if gone or halted else (maxf(0.0, sin(u / 0.45 * TAU)) if u < 0.45 else 0.0)
	if face_at != null:
		var W := warden.R
		var fa: Vector2 = face_at
		W.yaw += VhLayout.wrap_a(atan2(fa.x - W.x, fa.y - W.z) - W.yaw) * minf(1.0, dt * 4.0)
		if not walk_to.is_empty():
			var to: Vector3 = walk_to[0]
			var dx := to.x - W.x
			var dz := to.z - W.z
			var dd := U.hyp(dx, dz)
			var st := minf(dd, dt * walk_v)
			if dd > 0.01:
				W.x += dx / dd * st
				W.z += dz / dd * st
			else:
				walk_to.pop_front()
		if gone and back < 0.55:      # (a step back from the man with the gun)
			var st := minf(0.55 - back, dt * 1.1)
			back += st
			W.x -= sin(W.yaw) * st
			W.z -= cos(W.yaw) * st
	hands = minf(1.0, hands + dt * 2.2) if hands_on else 0.0
	warden.v.update(dt, 0.0, Game.fx)
	for i in under.size():
		var p: Puppet = under[i]
		p.R.drag = 0.0 if hands_on else pow(maxf(0.0, sin(t * 0.7 + (21.0 + i))), 6.0)
		p.v.update(dt, 0.0, Game.fx)
	if not gone and not halted:
		_punch(warden, u)
	elif gone:
		_cringe(warden, _ease(w_hands))
	var slump := _ease(clampf((dead_t - 0.06) / 0.38, 0.0, 1.0)) if gone else 0.0
	if fenn.v.face != null:
		fenn.v.face.hang = 0.5 * slump if gone else 0.0      # (the jaw left half open)
	_seated(fenn, dt, hit, slump, 1.0 if snap > 0.0 else 0.0)
	if hands > 0.0:
		for p in under:
			_hands_up(p, hands)


## Fenn sat in his chair right now (a checkpoint can start the finale before 4F has ever been drawn, and its line of fire is measured off his chest)
func pose_fenn() -> void:
	_seated(fenn, 0.0, 0.0, 0.0, 0.0)


## a bone's place in the world (the finale frames its shots on them)
static func bone_at(p: Puppet, n: StringName) -> Vector3:
	var v := p.v
	if not v.B.i.has(n):
		return Vector3(p.R.x, p.R.y + 1.4, p.R.z)
	return v.mw * (v.mp(v.B.i[n]) * v.g.scale.x)


func dispose() -> void:
	for p: Puppet in [fenn, warden, under[0], under[1], desk]:
		p.v.dispose()
