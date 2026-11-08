class_name CityAliens
extends RefCounted
## FOINT CITY aliens (JS levels/hub/city-aliens.js): a handful of the game's own grey (the mob) and green aliens, the real models through enemies/gray_alien_npc.gd (harmless, directable: head scanning, talking mouth, IK walk), living among the townsfolk. Greys and greens never mix: the greys keep to the west of the gate carpet (a grey tour guide and his grey tourist patrol the plaza, the CHESS CLUB: two greys over a board, a grey kibitzer) and the greens to the east (a gossip circle in goth, grunge and punk outfits).
## The club's table, lamp and sign, and the stationary aliens' small colliders, come with the level export. Shoot a grey and the greys within 35 m turn into real gray-alien enemies.

const ALIEN_ID0 := 881000
const NEAR := 55.0      # each one is a full model: only the ones near the player are drawn and animated


class Alien:
	var a: GrayAlienNpc
	var T: Target
	var x := 0.0
	var z := 0.0
	var green := false
	var talk_t := 0.0
	var talking := false
	var walker := false
	var pts: Array = []
	var pi_ := 0
	var speed := 1.2
	var moving := false
	var follow: Alien = null
	var gossip := false
	var ring: Array = []
	var next_: Alien = null
	var kibitz := false
	var foe: Robot = null
	var gone := false


var aliens: Array[Alien] = []
var targets: Array[Target] = []
var by_id: Dictionary = {}
var _gy := 0.0


func _init(root: Node3D, gy: float) -> void:
	_gy = gy
	# ---- the CHESS CLUB on the forecourt, west of the gate carpet
	var club := Vector2(-21.0, 204.0)
	var tb := Vector2(club.x + 1.5, club.y - 0.5)
	var o1 := _spawn(root, false, tb.x, tb.y - 0.95, 0.0)      # the players
	o1.a.look_at_point(tb.x, tb.y)
	var o2 := _spawn(root, false, tb.x, tb.y + 0.95, PI)
	o2.a.look_at_point(tb.x, tb.y)
	var k := _spawn(root, false, tb.x + 1.7, tb.y + 0.2, -PI / 2.0)      # the kibitzer
	k.a.look_at_point(tb.x, tb.y)
	k.kibitz = true
	# ---- the gossip circle of greens east of the carpet (no greys over here)
	var gx := 21.0
	var gz := 205.2
	var ring: Array[Alien] = []
	var outfits := ["goth", "grunge", "punk"]
	for i in 3:
		var a := float(i) / 3.0 * TAU + 0.4
		var r := _spawn(root, true, gx + sin(a) * 1.0, gz + cos(a) * 1.0, a + PI, outfits[i])
		r.gossip = true
		ring.append(r)
	for i in 3:
		var r := ring[i]
		var n := ring[(i + 1) % 3]
		r.a.look_at_point(n.x, n.z)
		r.next_ = n
		r.ring = ring
	# ---- the plaza patrol: a grey tour guide with a tourist in tow
	var guide := _spawn(root, false, -8.0, 198.0, 0.0)
	guide.walker = true
	guide.pts = [Vector2(-8.0, 192.0), Vector2(-28.0, 192.0), Vector2(-28.0, 198.0), Vector2(-8.0, 198.0)]
	guide.speed = 1.2
	var tourist := _spawn(root, false, -6.5, 198.0, 0.0)
	tourist.walker = true
	tourist.follow = guide


func _spawn(root: Node3D, green: bool, x: float, z: float, yaw: float, outfit: String = "") -> Alien:
	var r := Alien.new()
	r.a = GrayAlienNpc.new({"green": green, "outfit": outfit, "pose": &"idle"})
	root.add_child(r.a)
	r.a.place(x, _gy, z, yaw)
	r.x = x
	r.z = z
	r.green = green
	r.T = Target.new(ALIEN_ID0 + aliens.size(), x, z, _gy, {"r": 0.5, "h": 1.6, "max": 100.0, "hp": 100.0, "npc": true, "crowd": true, "w": 0.0})
	r.T.bx = x
	r.T.bz = z
	aliens.append(r)
	targets.append(r.T)
	by_id[r.T.id] = r
	return r


## this NPC steps out and a real gray alien (the game's enemy, same model) takes its place, already angry at the player; the NPC's own target stays down while it fights
func _aggro(q: Alien, player: Player) -> void:
	var R := q.a.R
	var T := q.T
	if q.green or q.foe != null or q.gone or T.dead:
		return
	var rb := Game.spawn_enemy({"x": R.x, "y": R.y, "z": R.z, "yaw": R.yaw}, {"kind": "alien", "no_respawn": true})
	if rb == null:
		return
	if rb.max > 0.0:
		rb.hp = maxf(1.0, rb.max * T.hp / T.max)      # a wounded one stays wounded
	if player != null:
		rb._know(player.x, player.z)
		rb.seen_t = 0.0
	rb.alert_why = "aggro"
	rb.set_(&"alert")
	q.foe = rb
	T.dead = true
	T.respawn_t = 1e9
	q.a.set_shown(false)
	q.a.set_talk(false)


## a combat event on one of the aliens: a hit flinches it (away from the shooter), a kill drops it (`update` lays it down)
func on_hit(e: Dictionary, player: Player) -> void:
	var r: Alien = by_id.get(int(e.get("tid", -1)))
	if r == null or String(e.get("t", "")) == "respawn":
		return
	r.a.R.hit_x = float(e.get("ux", 0.0))
	r.a.R.hit_z = float(e.get("uz", 0.0))
	r.a.R.flinch_t = 0.18
	if String(e.get("t", "")) == "kill":
		r.T.respawn_t = 5.0      # down for a few seconds, then back up (set_pose idle stands it up)
	if not r.green:      # a grey was shot: it and every grey near it come for you
		for q in aliens:
			if not q.green and U.hyp(q.x - r.x, q.z - r.z) < 35.0:
				_aggro(q, player)


func update(t: float, dt: float, player: Player) -> void:
	for r in aliens:
		var a := r.a
		var T := r.T
		var R := a.R
		if r.foe != null:      # fighting as a real enemy: wait for it to die / be cleared
			var rb := r.foe
			var live := Game.combat != null and Game.combat.enemies.robots.has(rb)
			if live and not (rb.dead and rb.dead_t > 20.0):
				a.set_shown(false)
				continue
			if live:
				Game.despawn_enemy(rb)
			r.foe = null
			if rb.dead:      # killed: out for 45 s; a level change cleared it: back as it was
				r.gone = true
				T.dead = true
				T.respawn_t = 45.0
			else:
				T.dead = false
				T.hp = T.max
				a.set_pose(&"idle")
		if r.gone:
			if T.dead:
				a.set_shown(false)
				continue
			r.gone = false
			a.set_pose(&"idle")
		T.bx = r.x
		T.x = r.x
		T.bz = r.z
		T.z = r.z
		T.kx = 0.0
		T.kz = 0.0
		R.flash = T.flash
		R.flinch_t = maxf(0.0, R.flinch_t - dt)
		if T.dead != (a.pose == &"dead"):      # shot down / back on its feet when the target respawns
			a.set_pose(&"dead" if T.dead else &"idle")
			if T.dead:
				a.set_talk(false)
				a.move_to(R.x, R.z)
		var far := player != null and U.hyp(r.x - player.x, r.z - player.z) > NEAR
		a.set_shown(not far)
		if far:
			continue
		a.update(t, dt)
		if T.dead:
			continue
		if r.walker:
			r.x = R.x
			r.z = R.z
			if not r.pts.is_empty():
				if not r.moving:
					r.moving = true
					var p: Vector2 = r.pts[r.pi_]
					a.move_to(p.x, p.y, r.speed, func() -> void:
						r.pi_ = (r.pi_ + 1) % r.pts.size()
						r.moving = false)
			elif r.follow != null:
				var g := r.follow.a.R
				var d := U.hyp(g.x - R.x, g.z - R.z)
				if d > 1.8 and not r.moving:
					r.moving = true
					a.move_to(g.x - sin(g.yaw) * 1.4, g.z - cos(g.yaw) * 1.4, 2.4 if d > 4.0 else 1.3, func() -> void: r.moving = false)
		elif r.gossip:      # whoever is the speaker talks, the others look at them
			r.talk_t -= dt
			if r.talk_t < 0.0:
				r.talk_t = 2.5 + randf() * 3.5
				var s: Alien = r.ring[randi() % r.ring.size()]
				for q: Alien in r.ring:
					q.a.set_talk(q == s)
					var w: Alien = q.next_ if q == s else s
					q.a.look_at_point(w.x, w.z)
		elif r.kibitz:
			r.talk_t -= dt
			if r.talk_t < 0.0:
				var tk := not r.talking
				r.talking = tk
				r.talk_t = 1.5 + randf() * 2.0 if tk else 4.0 + randf() * 6.0
				a.set_talk(tk)
