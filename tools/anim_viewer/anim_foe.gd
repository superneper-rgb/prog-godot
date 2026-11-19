class_name AnimFoe
extends RefCounted
## One enemy on the animation viewer's stage (tools/anim_viewer/anim_cast.gd says how): the game's own Robot class and view, the game's own AI step, and a stand-in target the viewer holds.

var v: AnimViewer
var kind := ""
var rb: Robot
var bv: Variant
var action := "stand"
var dist := 6.0
var target := "fixed"
var t := 0.0               # how long this action has run
var body_h := 1.8
var extras: Array[Robot] = []      # what it summoned (the Flayed Prophet's brood)
var _gap := 0.0
var _cycle := 0.0

func _init(p_v: AnimViewer, p_kind: String) -> void:
	v = p_v
	kind = p_kind
	var E := v.combat.enemies
	E.spawn_hook = _summon
	E.on_reap = _reap
	rb = _make(kind, {"x": 0.0, "y": 0.0, "z": 0.0, "yaw": 0.0}, {})
	bv = Game.enemy_views.bot_by_id[rb.id]
	body_h = clampf(rb.h * maxf(rb.visual_scale, 1.0), 0.8, 12.0)
	set_action("stand")

static func _new_id() -> int:
	AnimCast.next_id += 1
	return AnimCast.next_id

## the same way Game.spawn_enemy makes one, on the viewer's own World and without the game's combat
func _make(k: String, pt: Dictionary, o: Dictionary) -> Robot:
	var id := _new_id()
	var po := {"ax": 5.0, "az": 0.0, "owner": o.get("owner"), "spawn": {"kind": k}}
	var r: Robot
	if k == "drone":
		r = Drone.new(v.world, id, pt.x, pt.z, pt.y, po)
	elif Game.can_spawn_kind(k):
		r = Game._kind_script(k).new(v.world, id, pt.x, pt.z, pt.y, po)
	else:
		r = Robot.new(v.world, id, pt.x, pt.z, pt.y, po)
	if k == "heavy":
		r.heavy = true
		r.max = 220.0
		r.hp = 220.0
		r.r = 0.72
	r.yaw = pt.get("yaw", 0.0)
	r.no_respawn = true
	v.combat.enemies.add(r)
	Game.enemy_views.add_for(r)
	return r

func _summon(pt: Dictionary, o: Dictionary) -> Variant:
	var r := _make(String(o.get("kind", "follower")), pt, o)
	extras.append(r)
	r._know(v.P.x, v.P.z)
	return r

func _reap(r: Robot) -> void:
	_drop(r)
	extras.erase(r)

func _drop(r: Robot) -> void:
	v.combat.enemies.robots.erase(r)
	Game.enemy_views.remove_for(r)

func dispose() -> void:
	for r in extras.duplicate():
		_drop(r)
	extras.clear()
	_drop(rb)
	var E := v.combat.enemies
	if E != null:
		E.spawn_hook = Callable()
		E.on_reap = Callable()

## back at the start: where it stood, alive, calm
func restart() -> void:
	for r in extras.duplicate():
		_drop(r)
	extras.clear()
	v.combat.enemies.bolts.clear()
	rb.hx = 0.0
	rb.hz = 0.0
	rb.hy = 0.0
	rb.reset(false)
	rb.yaw = 0.0
	rb.immune_t = 0.0
	t = 0.0
	_gap = 0.0
	_cycle = 0.0
	_place_target()

func set_action(id: String) -> void:
	var a := AnimCast.foe_action(id)
	action = a[0]
	target = a[3]
	if float(a[2]) > 0.0:
		dist = float(a[2])
	if action == "melee":
		dist = clampf(rb.ai.reach * 0.7, 0.8, 5.0)
	if rb.dead:
		restart()
	t = 0.0
	_gap = 0.0
	_cycle = 0.0
	if action == "stand" or action == "patrol":
		rb.known = null
		rb.set_(&"idle")
	else:
		rb._know(v.P.x, v.P.z)
		if rb.state == &"idle" or rb.state == &"search" or rb.state == &"return":
			rb.set_(&"alert")
	_place_target()

func set_dist(d: float) -> void:
	dist = d
	_place_target()

## where the stand-in player is for this action
func _place_target() -> void:
	var P := v.P
	P.y = rb.y
	match target:
		"far":
			P.x = 0.0
			P.z = 70.0
		"ahead":
			P.x = rb.x + sin(rb.yaw) * dist
			P.z = rb.z + cos(rb.yaw) * dist
		_:
			P.x = rb.hx
			P.z = rb.hz + dist

func _busy() -> bool:
	return rb.state == &"windup" or rb.state == &"attack" or rb.state == &"recover" or rb.state == &"stagger" or rb.state == &"dead"

## one frame: the target, the push into the state this action holds, the game's AI step, the view
func tick(dt: float, now: float) -> void:
	var P := v.P
	var E := v.combat.enemies
	P.god = true
	P.dead = false
	P.hp = 100.0
	P.vx = 0.0
	P.vz = 0.0
	t += dt
	if target == "ahead":
		_place_target()
	if action != "death" and not rb.dead:
		rb.hp = rb.max
	match action:
		"alert":
			rb._know(P.x, P.z)
			rb.seen_t = 0.0
			if rb.state != &"alert":
				rb.set_(&"alert")
			rb.state_t = minf(rb.state_t, rb.ai.alert_delay * 0.9)
		"chase":
			rb._know(P.x, P.z)
			rb.seen_t = 0.0
			if not _busy() and rb.state != &"pursue":
				rb.set_(&"pursue")
		"fight":
			rb._know(P.x, P.z)
			rb.seen_t = 0.0
			if rb.state == &"idle" or rb.state == &"search" or rb.state == &"return":
				rb.set_(&"alert")
		"melee", "shot":
			rb._know(P.x, P.z)
			rb.seen_t = 0.0
			if _busy():
				_gap = 0.5
			else:
				_gap -= dt
				if _gap <= 0.0 and rb.state != &"idle":
					rb._begin(&"melee" if action == "melee" else &"shot", U.hyp(P.x - rb.x, P.z - rb.z))
				elif rb.state == &"idle" or rb.state == &"search":
					rb.set_(&"alert")
		"flinch", "stagger":
			_cycle += dt
			rb._know(P.x, P.z)
			if _cycle > 2.4 and not rb.dead:
				_cycle = 0.0
				rb.immune_t = 0.0
				rb.poise = 0.0
				var heavy := action == "stagger"
				var amount := Config.ai_stagger_dmg + 1.0 if heavy else 2.0
				rb.hp = maxf(1.0, rb.max - amount)
				rb.hurt(amount, P, 7.0 if heavy else 1.0, null, false)
		"death":
			_cycle += dt
			if not rb.dead and _cycle > 0.7:
				rb.hp = 0.0
				rb.hurt(rb.max, P, 4.0, null, true)
			elif rb.dead and rb.dead_t > 4.0:
				var keep := action
				restart()
				action = keep
				_cycle = 0.0
	if action == "stand":
		rb.vx = 0.0
		rb.vz = 0.0
		rb.lvx = 0.0
		rb.lvz = 0.0
		rb.state_t += dt
	else:
		E.update(dt, P)
	v.combat.events.clear()
	for r in extras:
		_view(r, dt, now)
	_view(rb, dt, now)

func _view(r: Robot, dt: float, now: float) -> void:
	var b: Variant = Game.enemy_views.bot_by_id.get(r.id)
	if b == null:
		return
	b.set_culled(false)
	if r.frozen_t > 0.0 and not r.dead:
		return
	b.update(dt, now, null)

func readout() -> String:
	var s := "%s  hp %d/%d" % [String(rb.state), int(rb.hp), int(rb.max)]
	if rb.atk != &"":
		s += "  atk %s %.2f" % [String(rb.atk), rb.a_u]
	var mv: Variant = rb.get(&"mv")
	if mv != null and String(mv) != "":
		s += "  mv %s" % String(mv)
	s += "  |  target %.1f m" % U.hyp(v.P.x - rb.x, v.P.z - rb.z)
	if not extras.is_empty():
		s += "  |  %d summoned" % extras.size()
	return s

func focus() -> Vector3:
	return Vector3(rb.x, rb.y, rb.z)
