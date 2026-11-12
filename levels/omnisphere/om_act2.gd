class_name OmAct2
extends RefCounted
## OMNISPHERE act two (JS act2.js): everything past Checkpoint Gamma's gate, up to the moment Juniper is free. ASSEMBLY LINE: conveyor, three stamping presses (telegraphed slams), the Quarterly Review; then the LINE GOES HAYWIRE (belt and presses triple, bodies on hooks swing across the floor at head height, half-built robots ride out of the hopper). FREIGHT DOCKS: the FOINT gunship (chin cannon, missile salvos; it burns, spirals and crashes). CONTAINMENT: shoot both seals on each of Juniper's four cuffs while security pours in; every freed arm slams whoever is near it; every cuff that comes off lets his current loose across the floor. Then the belt: he tears the hoses out and breaks out, the frame is swept apart and he punches the west wall out. The art is exported; the moving bits are found by name.

const J := {"x": -200.0, "z": -265.0, "floor": 18.0, "r": 45.0}
const ROCKET_SPOT := [-233.8, 18.0, -70.5]
const JUNIPER_TEXT := {"hi": "...h-hi.", "cuff1": "Oh. That one hurt less.", "cuff2": "Thank you. I think.", "cuff3": "I can feel my fingers again.", "cuff4": "That was the last one. Oh.", "free": "I can... go? Okay. Okay.", "fall": "Please don't fall.", "mine": "That's mine.", "oh": "Oh.", "fly": "I'm... up. This is up."}


class Press:
	var x := 0.0
	var head: Node3D
	var warn: MeshInstance3D
	var off := 0.0
	var hit_cd := 0.0
	var ph := -1.0
	var slam_t := -1


class Hook:
	var x := 0.0
	var pivot: Node3D
	var L := 10.5
	var ph := 0.0
	var drop := 0.0
	var hit_cd := 0.0


class Seal:
	var c: OmJuniper.Cuff
	var ci := 0
	var k := 0
	var beacon: OmSecurity.Beacon
	var armed := false
	var armed_once := false
	var T: OmProp


class FrameP:
	var g: Node3D
	var s: World.Solid = null
	var dir := 0.0
	var side := 1.0
	var home := Vector3.ZERO
	var u := 0.0
	var is_beam := false
	var v := 0.0


class Chunk:
	var g: MeshInstance3D
	var v := Vector3.ZERO
	var w := Vector3.ZERO
	var rest := false
	var h := 0.0


class Ship:
	var n := 0
	var s: OmCraft.Gunship
	var T: OmProp
	var hb: OmCraft.Hitboxes
	var t := 0.0
	var a := 0.0
	var ph := "in"
	var fire_t := 3.0
	var burst := 0
	var missile_t := 6.0
	var crash_v := Vector3.ZERO
	var y := 34.0
	var done := false
	var lift := 0.0
	var lv := 0.0


class Missile:
	var m: MeshInstance3D
	var v := Vector3.ZERO
	var to := Vector3.ZERO
	var t := 0.0


## DOUG, Juniper's caretaker (FOINT asset care, in his jumpsuit): he is sure they are friends. Talkable before the fight; he runs for it when it starts.
class Doug:
	extends RefCounted
	var g: Node3D
	var head: Node3D
	var mouth: Node3D
	var flee := false
	var talk := false
	var lx: Variant = null
	var lz: Variant = null
	var t := 0.0

	func look_at(x: float, z: float) -> void:
		lx = x
		lz = z

	func look_away() -> void:
		lx = null
		lz = null

	func set_talk(v: bool) -> void:
		talk = v

	func mouth_world() -> Vector3:
		return mouth.global_position

	func update(dt: float) -> void:
		t += dt
		mouth.scale.y = 1.0 + absf(sin(t * 18.0)) * 3.0 if talk else 1.0
		var ty := atan2(float(J.x) - g.position.x, float(J.z) - 4.0 - g.position.z) if lx == null else atan2(float(lx) - g.position.x, float(lz) - g.position.z)
		g.rotation.y += atan2(sin(ty - g.rotation.y), cos(ty - g.rotation.y)) * minf(1.0, dt * 4.0)
		if flee and g.visible:
			g.position.x += dt * 4.0
			g.position.z -= dt * 3.0
			g.rotation.y = 2.2
			if g.position.x > float(J.x) + 40.0:
				g.visible = false


var lv: ExportedLevel
var bo: Blockout
var W: World
var root: Node3D
var sec: OmSecurity
var sets: OmSets
var craft: OmCraft
var audio: OmAudio
var draw: OmDraw
var marks: OmMarks
var alarm: Callable
var jun: OmJuniper
var presses: Array[Press] = []
var hooks: Array[Hook] = []
var shells: Node3D
var cat_s: OmSecurity.Door
var cat_n: OmSecurity.Door
var freight: OmSecurity.Door
var exit_door: OmSecurity.Door
var hall_door: OmSecurity.Door
var door_s: OmSecurity.Door
var doors_w: Array[OmSecurity.Door] = []
var bay_hall: OmSecurity.Bay
var seals: Array[Seal] = []
var frame: Array[FrameP] = []
var plinth_s: World.Solid
var plinth_g: Node3D
var frame_gone := false
var west_in: Node3D
var rim: Node3D
var breach_light: Light3D
var hall_light: Light3D
var drum_light: Light3D
var wall_s := {}
var chunks: Array[Chunk] = []
var breached := false
var ships: Array[Ship] = []
var missiles: Array[Missile] = []
var doug := Doug.new()
var doug_talker := false
var drum_deck := {"id": "drum", "x0": float(J.x) - 44.0, "x1": float(J.x) + 44.0, "z0": float(J.z) - 44.0, "z1": float(J.z) + 44.0, "top": J.floor, "disc": [J.x, J.z, 44.0], "big": true}
var drum_surge_t := 0.0
var fin := {"slam_t": 4.0, "arrivals_t": 3.0, "door": 0, "done": false}
var hay := {"on": false, "t": 0.0, "api": null, "spawn_t": 3.0, "made": [], "wait": -1.0, "wait_api": null}
var released := false
var clock := 0.0
var rocket_cd := 0.0
var shell_x := 0.0
var on_cuff := Callable()
var on_release := Callable()
var on_frame := Callable()
var _hook_t := {}
var chunk_mat: StandardMaterial3D
var chunk_mat2: StandardMaterial3D
var missile_mesh: CylinderMesh
var missile_mat: StandardMaterial3D


func _init(p_lv: ExportedLevel, p_bo: Blockout, p_sec: OmSecurity, p_sets: OmSets, p_craft: OmCraft, p_audio: OmAudio, p_draw: OmDraw, p_marks: OmMarks, p_alarm: Callable) -> void:
	lv = p_lv
	bo = p_bo
	W = p_lv.world
	root = Node3D.new()
	root.name = "OmAct2"
	lv.add_child(root)
	sec = p_sec
	sets = p_sets
	craft = p_craft
	audio = p_audio
	draw = p_draw
	marks = p_marks
	alarm = p_alarm
	var sol := VhKit.solids(W)
	var F: float = J.floor
	chunk_mat = MsKit.std(0x3a3f46, .8, .4)
	chunk_mat2 = MsKit.std(0x4a1c18, .8, .2)
	missile_mesh = CylinderMesh.new()
	missile_mesh.top_radius = 0.0
	missile_mesh.bottom_radius = .25
	missile_mesh.height = 1.4
	missile_mesh.radial_segments = 8
	missile_mesh.rings = 1
	missile_mat = VhKit.unlit(0xffd080, 1.0)
	# ---- the assembly line
	var px := [-198.0, -210.0, -222.0]
	for i in 3:
		var p := Press.new()
		p.x = px[i]
		p.head = VhKit.one(lv, "om-press-%d" % i)
		p.warn = MsKit.sprite8(root, 0xffa020, 0.0, 2.4)
		p.warn.position = Vector3(p.x, 30.0, -44.6)
		p.off = i * 1.5
		presses.append(p)
	var hx := [-200.0, -213.0, -226.0]
	for i in 3:
		var h := Hook.new()
		h.x = hx[i]
		h.pivot = VhKit.one(lv, "om-hook-%d" % i)
		h.pivot.visible = false
		h.ph = i * 2.1
		hooks.append(h)
	shells = VhKit.one(lv, "om-shells")
	cat_s = sec.blast_door(-226.0, -20.25, 26.0, 2.4, 3.2, "x", {"auto": false})
	cat_n = sec.blast_door(-226.0, -61.75, 26.0, 2.4, 3.2, "x", {"auto": false})
	freight = sec.blast_door(-236.75, -41.0, 18.0, 8.0, 7.0, "z", {"auto": false})
	exit_door = sec.blast_door(-206.0, -61.75, 18.0, 2.4, 3.2, "x")
	hall_door = sec.blast_door(-176.75, -41.0, 18.0, 3.2, 4.0, "z")
	bay_hall = sec.drone_bay(-212.0, 26.0, -59.5)
	hall_light = VhKit.light(lv, "om-hall-light")
	drum_light = VhKit.light(lv, "om-drum-light")
	breach_light = VhKit.light(lv, "om-breach-light")
	breach_light.visible = false
	# ---- containment
	door_s = sec.blast_door(J.x, float(J.z) + 46.4, F, 3.6, 4.0, "x")
	doors_w = [sec.blast_door(float(J.x) + 46.4, J.z, F, 3.6, 4.0, "z", {"auto": false}), sec.blast_door(float(J.x) - 46.4, J.z, F, 3.6, 4.0, "z", {"auto": false}), sec.blast_door(J.x, float(J.z) - 46.4, F, 3.6, 4.0, "x", {"auto": false})]
	_seal_frames([door_s] + doors_w)
	for i: int in [17, 18, 19]:
		wall_s[i] = sol.get("wall-%d" % i, [])
	west_in = VhKit.one(lv, "om-west-in")
	rim = VhKit.one(lv, "om-rim")
	rim.visible = false
	plinth_s = (sol["plinth"] as Array)[0]
	plinth_g = VhKit.one(lv, "om-plinth")
	var fr := [[-13.5, -4.0], [13.5, -4.0], [-13.5, -10.0], [13.5, -10.0]]
	for i in 4:
		var f := FrameP.new()
		f.g = VhKit.one(lv, "om-frame-%d" % i)
		f.s = (sol["frame-%d" % i] as Array)[0]
		f.dir = signf(fr[i][0])
		f.side = 1.0 if float(fr[i][1]) > -7.0 else -1.0
		f.home = f.g.position
		frame.append(f)
	for i in 2:
		var f := FrameP.new()
		f.g = VhKit.one(lv, "om-frame-%d" % (i + 4))
		f.side = 1.0 if i == 0 else -1.0
		f.home = f.g.position
		f.is_beam = true
		frame.append(f)
	doug.g = VhKit.one(lv, "om-doug")
	doug.head = VhKit.one(lv, "om-doug-head")
	doug.mouth = VhKit.one(lv, "om-doug-mouth")
	jun = OmJuniper.new(lv)
	# seals: two shootable lock seals per cuff (combat targets that follow the model), each with a shoot beacon while it is live
	for ci in jun.cuffs.size():
		var c: OmJuniper.Cuff = jun.cuffs[ci]
		for k in 2:
			var s := Seal.new()
			s.c = c
			s.ci = ci
			s.k = k
			s.beacon = sec.shoot_beacon(c.seals[k], Vector3.ZERO, 2.2)
			s.beacon.set_on(false)
			s.T = OmProp.make(9600 + seals.size(), 0.0, 0.0, 0.0, .75, 1.5, 70.0)
			seals.append(s)


## New (user, 2026-11-10): the drum's door holes are 6 m wide and their frames 5 m, set back 2-3 m into the wall. The drum's jambs end before the frame does, so a
## 0.3 m slot ran up each side of every frame and you saw into (or out of) the drum through it at an angle. One post per side fills it, in the drum wall's own
## material, parented to the door so it goes with the door (the breach destroys the west one).
func _seal_frames(drum_doors: Array) -> void:
	var mat: Material = null
	for n: Node3D in lv.node_named("omnisphere landmarks"):
		for mi in VhKit.meshes(n):
			mat = mi.get_active_material(0)
	var post := BoxMesh.new()
	post.size = Vector3(0.42, 4.7, 1.6)      # across the slot, the frame's height, the frame's depth plus a little
	for d: OmSecurity.Door in drum_doors:
		var out := Vector3(d.x - float(J.x), 0.0, d.z - float(J.z)).normalized()      # from the drum's centre out through this door
		var side := Vector3(out.z, 0.0, -out.x)
		var centre := Vector3(J.x, d.y, J.z) + out * 45.5      # the frame sits 0.9 m inside the door line (46.4)
		for s: float in [-1.0, 1.0]:
			var m := MeshInstance3D.new()
			m.mesh = post
			m.material_override = mat
			d.g.add_child(m)
			m.global_transform = Transform3D(Basis.looking_at(out), centre + side * s * 2.65 + Vector3.UP * 2.35)


## Juniper says one of juniper-lines.js (voice + the shared subtitle strip)
func say(id: String) -> void:
	var text: String = JUNIPER_TEXT.get(id, "")
	audio.say(id, func(dur: float) -> void:
		jun.talk(dur)
		Game.hud.subtitle({"name": "JUNIPER", "text": text, "dur": dur}))


func arm_seals(is_belt: bool) -> void:
	var C: Combat = Game.combat
	if C == null:
		return
	for s in seals:
		if (s.c.name == "belt") != is_belt:
			continue
		s.T.dead = s.c.open
		s.T.hp = s.T.max
		s.armed = true
		OmProp.arm(s.T)


# the frame comes apart (Juniper's sweep): columns topple outward, the crossbeams drop
func smash_frame(instant: bool = false) -> void:
	if frame_gone:
		return
	frame_gone = true
	plinth_s.set_off(true)      # the plinth is cleared away: he stands with his feet on the deck
	plinth_g.visible = false
	jun.group.position.y = J.floor
	for f in frame:
		if f.s != null:
			f.s.set_off(true)
		f.u = 1.0 if instant else 1e-3
		if instant:
			_pose_frame(f)
	if not instant:
		for f in frame:
			if not f.is_beam:
				sets.boom(f.g.position.x, float(J.floor) + 8.0, f.g.position.z, 5.0, 0.0, {"harmless": true})
		audio.play_at("groan", Vector3(J.x, float(J.floor) + 20.0, J.z))
		if Game.fx != null:
			Game.fx.shake = 1.6


func _pose_frame(f: FrameP) -> void:
	if f.is_beam:
		if f.u >= 1.0:
			f.g.position.y = float(J.floor) + 1.0
			f.g.position.z = f.home.z + f.side * 22.0
		f.g.rotation.z = f.side * .12 * f.u
	else:      # flung aside: the front pair shoved south then over, the back pair straight over north (inside the drum, clear of his way out)
		f.g.rotation.x = f.side * (PI / 2.0 - .08) * f.u * f.u
		f.g.position.z = f.home.z + (14.0 if f.side > 0.0 else 0.0) * sin(minf(1.0, f.u) * PI / 2.0)


func _restore_frame() -> void:
	frame_gone = false
	plinth_s.set_off(false)
	plinth_g.visible = true
	jun.group.position.y = float(J.floor) + 2.0
	for f in frame:
		f.u = 0.0
		f.v = 0.0
		if f.s != null:
			f.s.set_off(false)
		f.g.rotation = Vector3.ZERO
		f.g.position = f.home


func breach_west(instant: bool = false) -> void:
	if breached:
		return
	breached = true
	for i: int in wall_s:
		for s: World.Solid in wall_s[i]:
			s.set_off(true)
	doors_w[1].destroy(true)
	west_in.visible = false
	if marks != null:
		marks.breach(true)
	breach_light.visible = true
	if instant:
		return
	var x0 := float(J.x) - 46.0
	var z0: float = J.z
	var F: float = J.floor
	rim.visible = true
	for k in 6:
		sets.after(k * .09, func() -> void:
			if Game.fx != null:
				Game.fx.explosion(Vector3(x0 + (randf() - .5) * 6.0, F + 4.0 + randf() * 26.0, z0 + (randf() - .5) * 22.0), 5.0 + randf() * 4.0))
	var c := Vector3(x0, F + 12.0, z0)
	audio.play_at("boomBig", c)
	audio.play_at("groan", c)
	if Game.fx != null:
		Game.fx.shake = 2.6
	alarm.call(20.0)
	for k in 18:
		var ch := Chunk.new()
		var bm := BoxMesh.new()
		var h := 1.5 + randf() * 4.0
		bm.size = Vector3(1.5 + randf() * 3.5, h, .8 + randf() * 1.2)
		ch.g = MsKit.part(root, bm, chunk_mat if k % 3 != 0 else chunk_mat2, Vector3(x0 - 1.0, F + 3.0 + randf() * 28.0, z0 + (randf() - .5) * 22.0))
		ch.g.rotation = Vector3(randf() * 3.0, randf() * 3.0, 0.0)
		ch.v = Vector3(-(9.0 + randf() * 16.0), 2.0 + randf() * 9.0, (randf() - .5) * 10.0)
		ch.w = Vector3((randf() - .5) * 5.0, (randf() - .5) * 5.0, (randf() - .5) * 5.0)
		ch.h = h / 2.0
		chunks.append(ch)


func _restore_breach() -> void:
	breached = false
	breach_light.visible = false
	rim.visible = false
	for i: int in wall_s:
		for s: World.Solid in wall_s[i]:
			s.set_off(false)
	doors_w[1].destroy(false)
	west_in.visible = true
	if marks != null:
		marks.breach(false)
	for c in chunks:
		c.g.queue_free()
	chunks.clear()


# ---- gunships
func launch_ship(n: int) -> Ship:
	var sh := Ship.new()
	sh.n = n
	sh.s = craft.gunship()
	sh.s.group.scale = Vector3.ONE * 1.25
	sh.T = OmProp.make(9700 + n, -205.0, -160.0, 30.0, 4.5, 3.4, 1100.0)
	sh.T.dead = false
	Game.combat.targets.append(sh.T)
	audio.play_at("gunshipPass", Vector3(-205, 30, -160))
	sh.hb = OmCraft.Hitboxes.new(sh.T)
	sh.a = PI if n != 0 else 0.0
	ships.append(sh)
	Game.hud.toast("SECOND GUNSHIP INBOUND" if n != 0 else "GUNSHIP!")
	return sh


func _missile(from: Vector3, to: Vector3) -> void:
	var m := Missile.new()
	m.m = MsKit.part(root, missile_mesh, missile_mat, from, false)
	m.v = (to - from).normalized() * 26.0
	m.to = to
	missiles.append(m)
	audio.play_at("arc", from)


func _update_ships(dt: float, P: Player) -> void:
	var C: Combat = Game.combat
	for sh in ships:
		if sh.done:
			continue
		sh.t += dt
		sh.s.update(dt)
		var g := sh.s.group
		var T := sh.T
		if sh.ph != "crash" and T.hp <= 0.0:
			sh.ph = "crash"
			T.dead = true
			sh.hb.drop()
			sh.crash_v = Vector3(cos(sh.a) * 8.0, 0.0, sin(sh.a) * 8.0)
			audio.play_at("boomBig", g.position)
			Game.fx.explosion(g.position, 4.0)
			Game.hud.toast("GUNSHIP DOWN")
		if sh.ph == "crash":
			sh.crash_v.y -= 14.0 * dt
			g.position += sh.crash_v * dt
			g.rotation.z += dt * 2.6
			g.rotation.x += dt * .7
			if randf() < dt * 12.0:
				Game.fx.explosion(g.position + Vector3((randf() - .5) * 4.0, 1.0, (randf() - .5) * 4.0), 1.4)
			var ground := W.ground_height(g.position.x, g.position.z, 1.0, g.position.y + 1.0)
			if g.position.y < maxf(1.0, ground + .5):
				sets.boom(g.position.x, g.position.y + 1.0, g.position.z, 9.0, 40.0)
				sets.boom(g.position.x + 3.0, g.position.y + 2.0, g.position.z - 2.0, 6.0, 0.0, {"harmless": true})
				g.visible = false
				sh.done = true
			continue
		# fly: orbit the dock at altitude, always facing PROG; chin-cannon bursts and missile salvos
		sh.a += dt * (.5 if sh.ph == "in" else .22)
		var R := 60.0 - minf(26.0, sh.t * 6.0) if sh.ph == "in" else 34.0
		if sh.ph == "in" and sh.t > 4.5:
			sh.ph = "fight"
		var tx := -205.0 + cos(sh.a) * R
		var tz := -92.0 + sin(sh.a) * R
		var ty := sh.y + sin(sh.t * .7) * 3.0
		# probe window raised 5 m so a roof above a low bob is seen; climb and settle at limited speed, never a snap
		var want := OmCraft.hull_lift(W, tx, ty + 5.0, tz, -sin(sh.a) * 22.0, cos(sh.a) * 22.0, 10.0)
		var tv := clampf((want - sh.lift) * 2.2, -2.2, 7.0)
		sh.lv += (tv - sh.lv) * minf(1.0, dt * 3.5)
		sh.lift = maxf(0.0, sh.lift + sh.lv * dt)
		g.position = Vector3(tx, ty + sh.lift, tz)
		if P != null:
			g.rotation.y = atan2(P.x - tx, P.z - tz)
		g.rotation.z = -.15
		sh.hb.sync(tx, ty + sh.lift, tz, g.rotation.y)      # the hit volumes follow the hull, lift included
		if sh.ph != "fight" or P == null or P.dead or C == null:
			continue
		sh.fire_t -= dt
		sh.missile_t -= dt
		if sh.fire_t <= 0.0:
			if sh.burst <= 0:
				sh.burst = 7
			var o := g.position + Vector3(0, -2, 0)
			var d := Vector3(P.x - o.x, P.y + 1.0 - o.y, P.z - o.z).normalized()
			d.x += (randf() - .5) * .06
			d.z += (randf() - .5) * .06
			C.enemies.fire_from(T.id, o.x, o.y, o.z, d.x, d.y, d.z, {"kind": "plasma", "speed": 36.0, "dmg": 7.0, "r": .2})
			sh.burst -= 1
			sh.fire_t = .13 if sh.burst > 0 else 3.2
		if sh.missile_t <= 0.0:
			sh.missile_t = 7.0
			for k in 3:
				var to := Vector3(P.x + (randf() - .5) * 8.0, 18.0, P.z + (randf() - .5) * 8.0)
				var live := sh
				sets.after(k * .26, func() -> void:
					if not live.done and is_instance_valid(live.s.group):
						_missile(live.s.group.position + Vector3(0, -1.5, 0), to))
	for i in range(missiles.size() - 1, -1, -1):
		var m := missiles[i]
		m.t += dt
		m.m.position += m.v * dt
		m.m.quaternion = Quaternion(Vector3.UP, m.v.normalized())
		if randf() < .6:
			Game.fx.dust(m.m.position, 1, .4)
		if m.m.position.distance_to(m.to) < 1.2 or m.t > 4.0 or m.m.position.y < m.to.y:
			sets.boom(m.m.position.x, m.m.position.y + .3, m.m.position.z, 4.2, 26.0)
			m.m.queue_free()
			missiles.remove_at(i)


# presses: cycle, telegraph, slam (damage on the belt under the head); haywire: three times the tempo
func _update_presses(dt: float, t: float, P: Player, C: Combat) -> void:
	var on: bool = hay.on
	var period := 1.6 if on else 4.6
	for p in presses:
		if p.ph < 0.0:
			p.ph = p.off / 4.6
		p.ph += dt / period
		var m := fmod(p.ph, 1.0)
		var cyc := floori(p.ph)
		var down := m > .72 and m < .86
		var warn := m > .52 and m <= .72
		var y := 19.3 if down else (19.3 + (m - .86) / .14 * 6.7 if m >= .86 else 26.0 - (sin((m - .52) / .2 * PI) * .25 if warn else 0.0))
		if m > .72 and p.slam_t != cyc:
			p.slam_t = cyc
			if P != null and U.hyp(P.x - p.x, P.z + 41.0) < 30.0:
				var at := Vector3(p.x, 20.0, -41.0)
				audio.play_at("boom", at)
				Game.fx.shake = maxf(Game.fx.shake, .8 if on else .5)
				if on:
					Game.fx.sparks(at, 18, 7.0, null, 0xffc060)
		p.head.position.y = y
		MsKit.opa(p.warn, .5 + .5 * sin(t * 30.0) if warn else 0.0)
		p.hit_cd = maxf(0.0, p.hit_cd - dt)
		if y < 21.0 and P != null and not P.dead and p.hit_cd <= 0.0 and absf(P.x - p.x) < 2.2 and P.z < -38.8 and P.z > -43.2 and P.y < 21.5:
			p.hit_cd = 1.0
			C.hurt_player(P, 45.0, p.x, -41.0, "melee")
			P.vy = 8.0
			P.grounded = false
			P.z += 2.0 if P.z > -41.0 else -2.0
		if C != null and y < 21.0:
			for r: Robot in C.enemies.robots:
				if not r.dead and absf(r.x - p.x) < 2.2 and r.z < -38.8 and r.z > -43.2:
					C.damage(r, 400.0, {"x": p.x, "z": -41.0}, 4.0)


# a cuff comes off: his current gets loose across the whole floor (the Draw's warn -> surge on a round live deck), then the deck is withdrawn
func _drop_drum_deck() -> void:
	draw.live_decks.erase(drum_deck)
	drum_surge_t = 0.0


func _cuff_surge() -> void:
	if not draw.live_decks.has(drum_deck):
		draw.live_decks.append(drum_deck)
	drum_surge_t = 4.6
	draw.trigger({})
	alarm.call(5.0)
	audio.play_at("draw", Vector3(J.x, float(J.floor) + 4.0, J.z))
	Game.hud.toast("SURGE  -  GET OFF THE FLOOR", 1.8)


func _finale_waves(dt: float, P: Player, C: Combat) -> void:
	fin.arrivals_t = float(fin.arrivals_t) - dt
	var alive := 0
	if sec.cur_wave != null:
		for r: Robot in sec.cur_wave.spawned:
			if not r.dead:
				alive += 1
	if float(fin.arrivals_t) <= 0.0 and alive < 9 and not fin.done:
		fin.arrivals_t = 7.5
		var d: OmSecurity.Door = doors_w[int(fin.door) % 3]
		fin.door = int(fin.door) + 1
		var kinds: Array = [["robot", "assault"], ["drone", ""], ["robot", "suppression"]][int(fin.door) % 3]
		var out := Vector3(d.x - float(J.x), 0.0, d.z - float(J.z)).normalized()
		var F: float = J.floor
		var a := {"via": "door", "door": d, "kind": kinds[0], "speed": 2.8 if kinds[0] == "robot" else 4.2, "from": [d.x + out.x * 3.0, F, d.z + out.z * 3.0], "path": [[d.x - out.x * 3.0, F, d.z - out.z * 3.0], [d.x - out.x * 12.0, F, d.z - out.z * 12.0]]}
		if kinds[0] == "robot":
			a["heavy"] = kinds[1]
		sec.inject(a)
	# freed arms slam whoever is near them
	fin.slam_t = float(fin.slam_t) - dt
	var free: Array[int] = []
	for i in jun.arms.size():
		if jun.arms[i].free > .9:
			free.append(i)
	if not free.is_empty() and float(fin.slam_t) <= 0.0:
		fin.slam_t = 5.5 / free.size()
		var i: int = free[randi() % free.size()]
		var A: OmJuniper.Arm = jun.arms[i]
		jun.slam(i)
		sets.after(.6, func() -> void:
			var hp := jun.hand_world(A)
			sets.boom(hp.x, float(J.floor) + .5, hp.z, 7.0, 0.0, {"harmless": true})
			for r: Robot in C.enemies.robots:
				if not r.dead and U.hyp(r.x - hp.x, r.z - hp.z) < 10.0:
					C.damage(r, 500.0, {"x": hp.x, "z": hp.z}, 10.0)
			if P != null and U.hyp(P.x - hp.x, P.z - hp.z) < 4.0:
				C.hurt_player(P, 25.0, hp.x, hp.z, "melee"))


# ---- the line goes haywire
func _update_haywire(dt: float, P: Player, C: Combat) -> void:
	if float(hay.wait) > 0.0:
		hay.wait = float(hay.wait) - dt
		if float(hay.wait) <= 0.0:
			hay.wait = -1.0
			haywire(hay.wait_api)
	if not hay.on:
		return
	hay.t = float(hay.t) + dt
	var fx: Variant = Game.fx
	# the hooks drop, then swing across the belt (z) on their chains
	for h in hooks:
		h.pivot.visible = true
		h.drop = minf(1.0, h.drop + dt * 1.4)
		h.ph += dt * 2.1
		var a := sin(h.ph) * 1.05 * h.drop
		var lift := (1.0 - h.drop) * 8.0
		h.pivot.rotation.x = -a
		h.pivot.position.y = 31.2 + lift
		var by := 31.2 + lift - cos(a) * h.L
		var bz := -41.0 + sin(a) * h.L
		var vz := cos(h.ph) * 2.1 * 1.05 * h.L
		h.hit_cd = maxf(0.0, h.hit_cd - dt)
		if P != null and not P.dead and h.hit_cd <= 0.0 and h.drop > .9 and absf(P.x - h.x) < 1.3 and absf(P.z - bz) < 1.4 and P.y + 1.7 > by - 1.3 and P.y < by + 1.1:
			h.hit_cd = 1.2
			C.hurt_player(P, 26.0, h.x, bz - signf(vz), "melee")
			P.vz = signf(vz) * 11.0
			P.vy = 6.0
			P.grounded = false
			fx.shake = maxf(fx.shake, 1.0)
			audio.play_at("boom", Vector3(h.x, by, bz))
		if C != null:
			for r: Robot in C.enemies.robots:
				if not r.dead and not r.drone and absf(r.x - h.x) < 1.3 and absf(r.z - bz) < 1.5 and r.y + 1.5 > by - 1.3 and float(_hook_t.get(r.id, 0.0)) < float(hay.t):
					_hook_t[r.id] = float(hay.t) + 1.0
					C.damage(r, 160.0, {"x": h.x, "z": bz - signf(vz)}, 9.0)
	# half-built line robots ride out of the hopper onto the belt
	hay.spawn_t = float(hay.spawn_t) - dt
	var alive := 0
	for r: Robot in hay.made:
		if not r.dead:
			alive += 1
	if float(hay.spawn_t) <= 0.0 and alive < 3 and (hay.made as Array).size() < 7:
		hay.spawn_t = 5.5
		var r: Robot = bo.spawn({"x": -190.6, "y": 19.3, "z": -41.0, "yaw": -PI / 2.0}, {"kind": "robot"})
		if r != null:
			(hay.made as Array).append(r)
			var at := Vector3(-190, 20.5, -41)
			fx.sparks(at, 24, 6.0, null, 0xffc060)
			audio.play_at("kiosk", at)


## the line goes haywire
func haywire(_api: Variant = null) -> void:
	if hay.on:
		return
	hay.on = true
	hay.t = 0.0
	hay.spawn_t = 2.5
	hay.made = []
	alarm.call(12.0)
	audio.play_at("draw", Vector3(-207, 30, -41))
	Game.hud.toast("LINE OVERRIDE  -  THE LINE IS RUNNING WILD", 2.6)


## the review is over: the line seizes (a bang down the belt, the hooks fall)
func haywire_stop(quiet: bool = false) -> void:
	hay.wait = -1.0
	if not hay.on:
		return
	hay.on = false
	for h in hooks:
		h.pivot.visible = false
		h.drop = 0.0
		h.pivot.rotation.x = 0.0
	if not quiet:
		for p in presses:
			sets.boom(p.x, 22.0, -41.0, 4.0, 0.0, {"harmless": true})
		audio.play_at("groan", Vector3(-207, 24, -41))


## the line goes haywire delay seconds of game time from now
func haywire_in(delay: float) -> void:
	hay.wait = delay


func arms_free() -> bool:
	for c in jun.cuffs:
		if c.name != "belt" and not c.open:
			return false
	return true


func belt_free() -> bool:
	return jun.belt.open


func ships_down(n: int) -> bool:
	var k := 0
	for s in ships:
		if s.done or s.ph == "crash":
			k += 1
	return k >= n


func finale(on: bool) -> void:
	fin.done = not on
	fin.arrivals_t = 2.0
	if on:
		doug.flee = true


func doug_on() -> void:
	if doug_talker:
		return
	doug_talker = true
	Game.dialogue.add_talker({"id": "doug", "name": "DOUG  //  ASSET CARE", "x": doug.g.position.x, "y": J.floor, "z": doug.g.position.z, "yaw": -2.4, "color": "#e0782a", "voice_pitch": .62, "actor": doug, "active": func() -> bool: return not doug.flee and doug.g.visible,
		"lines": ["Oh. Hey. You are not on the schedule.", "I'm Doug. I'm his caretaker. Well. Friend. Caretaker is the job title. We're friends.", "He does not talk. That is fine. I talk enough for both of us. That is the dynamic.",
			"Every morning I tell him about my divorce. Every morning he screams. He gets it, you know?", "They pull eleven gigawatts out of him a day. I sit with him on my breaks. Unpaid. That is friendship.", "Don't unplug him. He'd miss me."]})


## the belt is off: the hoses come out, he roars, the plant dies (escape takes him from here)
func release() -> void:
	fin.done = true
	released = true
	jun.tear_hoses()
	alarm.call(60.0)
	audio.play_at("boomBig", Vector3(J.x, 30.0, J.z))
	say("free")
	audio.pa("free")
	Game.fx.shake = 2.0
	draw.stop()
	if marks != null:
		marks.flare(1.0)
	if on_release.is_valid():
		on_release.call()


func reset(stage: String, _obj: int, retry: bool) -> void:
	haywire_stop(true)
	for s in ships:
		s.s.free_model()
		s.T.dead = true
		s.hb.drop()
	ships.clear()
	for m in missiles:
		m.m.queue_free()
	missiles.clear()
	var late := stage == "escape"
	var live := late and released and not retry      # straight on from the release: he is mid-breakout, leave him be
	for s in seals:
		s.T.dead = true
		s.T.hp = s.T.max
		s.armed_once = false
		s.armed = false
		s.beacon.set_on(false)
	_drop_drum_deck()
	if not live:
		jun.reset()
		if late:
			for c in jun.cuffs:
				jun.open_cuff(c)
			jun.tear_hoses()
		else:
			released = false
			_restore_frame()
			_restore_breach()
	fin.done = true
	doug.flee = false
	doug.g.visible = stage == "drum"
	doug.g.position = Vector3(float(J.x) + 9.8, J.floor, float(J.z) + 5.2)
	if stage == "drum":
		doug_on()


func update(dt: float, P: Player, C: Combat) -> void:
	clock += dt
	var belt := 6.6 if hay.on else 2.2
	shell_x += belt * dt
	shells.position.x = -232.0 + fmod(shell_x, 6.0)
	_update_presses(dt, clock, P, C)
	_update_haywire(dt, P, C)
	# the conveyor carries whatever stands on it toward the presses
	if P != null and P.grounded and P.z < -39.0 and P.z > -43.0 and P.x > -230.0 and P.x < -186.0 and absf(P.y - 19.2) < .2:
		P.x -= belt * dt
	_update_ships(dt, P)
	# seals follow the model; a cuff whose two seals are down blows open
	for s in seals:
		if not s.T.dead and s.T.hp <= 0.0:
			s.T.dead = true
		var p := jun.seal_world(s.c, s.k)
		s.T.x = p.x
		s.T.bx = p.x
		s.T.z = p.z
		s.T.bz = p.z
		s.T.y = p.y - .75
		s.T.kx = 0.0
		s.T.kz = 0.0
		s.c.seals[s.k].visible = not s.T.dead and not s.c.open
		var on := s.armed and not s.T.dead and not s.c.open
		if on != s.beacon.on:
			s.beacon.set_on(on)
	for c in jun.cuffs:
		if c.open:
			continue
		var all_dead := true
		var once := false
		for s in seals:
			if s.c == c:
				all_dead = all_dead and s.T.dead
				once = once or s.armed_once
		if all_dead and once:
			jun.open_cuff(c)
			var p := c.g.global_position
			Game.fx.explosion(p, 2.6)
			audio.play_at("boomBig", p)
			Game.fx.shake = 1.2
			if c.arm >= 0:
				var n := 0
				for k in jun.cuffs:
					if k.arm >= 0 and k.open:
						n += 1
				say("cuff%d" % n)
				_cuff_surge()
				if on_cuff.is_valid():
					on_cuff.call(n)
	if drum_surge_t > 0.0:
		drum_surge_t -= dt
		if drum_surge_t <= 0.0:
			_drop_drum_deck()
	for s in seals:
		if not s.T.dead:
			s.armed_once = true
	if not fin.done:
		_finale_waves(dt, P, C)
	jun.update(dt)
	doug.update(dt)
	# the frame coming apart, the wall chunks flying
	var F: float = J.floor
	for f in frame:
		if f.u > 0.0 and f.u < 1.0:
			f.u = minf(.99 if f.is_beam else 1.0, f.u + dt * (.9 if f.is_beam else .7))
			if f.is_beam:
				f.v += 18.0 * dt
				f.g.position.y = maxf(F + 1.0, f.g.position.y - f.v * dt)
				f.g.position.z = f.home.z + f.side * 22.0 * minf(1.0, f.u * 1.4)
				f.g.rotation.z = f.side * .12 * f.u
				if f.g.position.y <= F + 1.01 and f.u < 1.0:
					f.u = 1.0
					sets.boom(f.g.position.x, F + 1.0, f.g.position.z, 6.0, 0.0, {"harmless": true})
			else:
				_pose_frame(f)
				if f.u >= 1.0:
					sets.boom(f.g.position.x, F + 1.0, f.g.position.z + f.side * 15.0, 7.0, 0.0, {"harmless": true})
					if on_frame.is_valid():
						on_frame.call()
	for c in chunks:
		if c.rest:
			continue
		c.v.y -= 22.0 * dt
		c.g.position += c.v * dt
		c.g.rotation += c.w * dt
		var gy := W.ground_height(c.g.position.x, c.g.position.z, .5, c.g.position.y + 1.0)
		if c.g.position.y < -6.0:
			c.g.visible = false
			c.rest = true
		elif gy > -INF and c.g.position.y - c.h < gy and c.v.y < 0.0:
			c.g.position.y = gy + c.h
			c.v *= .35
			c.v.y = absf(c.v.y) * .25
			c.w *= .4
			if c.v.length() < 1.2:
				c.rest = true
	# rocket resupply on the dock
	rocket_cd = maxf(0.0, rocket_cd - dt)
	if P != null and C != null and rocket_cd <= 0.0 and U.hyp(P.x - float(ROCKET_SPOT[0]), P.z - float(ROCKET_SPOT[2])) < 2.4 and absf(P.y - float(ROCKET_SPOT[1])) < 1.0:
		rocket_cd = 12.0
		var i := Weapons.index_of("rocket")
		if i >= 0:
			if not C.owned.has(i):
				C.give(i)
			C.ammo[i] = Weapons.WEAPONS[i].mag_size
			C.reserve[i] = Weapons.WEAPONS[i].max
		Game.hud.toast("FOINT-N-SHOOT: ROCKETS RESTOCKED  -  HEAVY ROTATION READY", 2.4)
		audio.play_at("kiosk", Vector3(ROCKET_SPOT[0], ROCKET_SPOT[1], ROCKET_SPOT[2]))
	hall_light.light_energy = 14.0 * draw.power / PI
	drum_light.light_energy = 30.0 * draw.power / PI
