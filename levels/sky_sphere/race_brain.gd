class_name RaceBrain
extends RefCounted
## The hands on a rival's (or a commuter's) controls in the Overcurrent: it steers the same physics the player drives (race_car.gd) by
## pure pursuit on the course's racing line, brakes for the speeds the course worked out, goes round slower craft, sometimes takes a
## branch, burns its boost on straights, and the mean ones lean into the player when he is alongside.

var skill := 1.0          # share of the course's corner speeds it dares
var mean := 0.0           # 0..1: how readily it slams the player
var lane := 0.0           # its own offset from the racing line, m
var takes: Dictionary = {}   # branch title -> it goes that way this run
var rubber := 1.0         # set by the race: catch-up or ease-off
var last_lat := 0.0       # the lane it last aimed for (tests)
var _boost_on := false
var _lunge := 0.0         # seconds left of a slam it has committed to
var _lunge_side := 0.0
var _cool := 0.0
var _stuck := 0.0


func drive(me: SkyRace.Racer, race: SkyRace, dt: float) -> void:
	var car := me.car
	var c := me.controls
	var course := race.course
	var p := course.paths[car.path]
	c.drift = false
	c.boost = false
	c.aftertouch = Vector2.ZERO
	if car.wrecked:
		c.throttle = 0.0
		c.brake = 0.0
		c.steer = 0.0
		return
	var v := maxf(car.speed, 0.0)
	_cool = maxf(0.0, _cool - dt)
	_lunge = maxf(0.0, _lunge - dt)
	# --- where to aim: the line, round whatever is ahead, into a branch, into the player
	var look := 10.0 + v * 0.4
	var i := p.wrap(car.index + int(look / SkyCourse.STEP))
	var lat := p.line[i] + lane
	if p.mag[i] == 1 or p.mag[car.index] == 1:
		lat *= 0.3      # (loops and the roll are taken near the middle, where the twist swings a craft least)
	if car.path == SkyCourse.MAIN:
		for br: SkyCourse.Branch in course.branches:
			var to_split := br.split_i - car.index
			if to_split < 90 and to_split > 0 and takes.get(br.title, false):
				var edge := p.wl[i] if br.side > 0.0 else p.wr[i]
				lat = br.side * (edge + SkyCourse.BRANCH_WIDTH * (1.0 if to_split < 30 else 0.6))
	var room_l := p.wl[i] - 2.0
	var room_r := p.wr[i] - 2.0
	for other: SkyRace.Racer in race.everyone:
		if other == me or other.car.wrecked or other.ghost > 0.0:
			continue
		var rel := other.car.pos - car.pos
		var ahead := rel.dot(car.basis.z)
		if ahead < -4.0 or ahead > 14.0 + v * 0.3:
			continue
		var side := rel.dot(car.basis.x)
		var my_lat := car.local.x
		var gap := (side + my_lat) - lat
		if ahead > 0.0 and absf(gap) < 2.6 and other.car.speed < v + 3.0:
			lat += -2.9 if gap > 0.0 else 2.9
	# a slam: the mean ones commit to a short lunge at the player when he is right beside them
	var pl := race.player_racer()
	if mean > 0.0 and pl != null and pl != me and not pl.car.wrecked and pl.ghost <= 0.0:
		var rel := pl.car.pos - car.pos
		var ahead := rel.dot(car.basis.z)
		var side := rel.dot(car.basis.x)
		if _lunge <= 0.0 and _cool <= 0.0 and absf(ahead) < 4.5 and absf(side) > 1.6 and absf(side) < 5.5 and randf() < mean * dt * 2.2:
			_lunge = 0.7
			_lunge_side = signf(side)
			_cool = 3.5 - mean * 1.5
		if _lunge > 0.0:
			lat = car.local.x + _lunge_side * 4.0
	lat = clampf(lat, -room_r, room_l)
	# round what the course has put in the way (the column, fallen girders, a crusher that will be down)
	if car.path == SkyCourse.MAIN and race.set_pieces() != null:
		var clear := race.set_pieces().free_lat(car.index + 2, i, lat, p.metres[car.index], v, room_l, room_r, car.local.x)
		if clear != lat:
			# something in the way: commit to the gap now, aiming nearer
			lat = clear
			i = p.wrap(car.index + int(maxf(8.0, look * 0.55) / SkyCourse.STEP))
	last_lat = lat
	var lock := lerpf(RaceCar.STEER_LOW, RaceCar.STEER_HIGH, smoothstep(6.0, 78.0, v))
	var want := 0.0
	if p.mag[car.index] == 1 or p.mag[i] == 1:
		# a loop or the roll: a point down a twisting deck is somewhere else entirely, so steer by the error against the road under the craft
		var here: Transform3D = p.frames[car.index]
		var heading := atan2(car.basis.z.dot(here.basis.x), car.basis.z.dot(here.basis.z))
		var off := car.local.x - lat
		want = -heading - atan2(1.2 * off, v + 4.0) + p.curve[car.index] * 2.64
	else:
		var target := p.frames[i] * Vector3(lat, 0.0, 0.0)
		var to := target - car.pos
		var lx := to.dot(car.basis.x)
		var lz := maxf(to.dot(car.basis.z), 1.0)
		want = atan2(2.0 * 2.64 * lx, lz * lz + lx * lx)
	c.steer = clampf(want / maxf(lock, 0.05) * 1.25, -1.0, 1.0)
	# --- how fast: the slowest the course allows over what is coming
	var pace := p.pace[car.index]
	for k: int in [6, 14, 26, 40]:
		pace = minf(pace, p.pace[p.wrap(car.index + int((k + v * 0.35) / SkyCourse.STEP))])
	pace *= skill * rubber
	var err := pace - v
	if err > -1.5:
		c.throttle = clampf(0.75 + err * 0.12, 0.0, 1.0)
		c.brake = 0.0
	else:
		c.throttle = 0.0
		c.brake = clampf(-err * 0.11, 0.15, 1.0)
	# --- boost on a long fast stretch while it has some
	var open := p.pace[p.wrap(car.index + 50)] > 80.0 and p.pace[p.wrap(car.index + 25)] > 80.0 and absf(p.curve[i]) < 0.006
	if _boost_on:
		_boost_on = me.meter > 0.05 and open
	elif me.meter > 0.7 and open and v > 55.0:
		_boost_on = true
	c.boost = _boost_on
	# --- stuck against something: back off and try again (the race respawns it if it stays stuck)
	if v < 3.0 and race.racing():
		_stuck += dt
		if _stuck > 1.2:
			c.throttle = 0.0
			c.brake = 1.0
			c.steer = -c.steer
	else:
		_stuck = 0.0


func stuck_for() -> float:
	return _stuck
