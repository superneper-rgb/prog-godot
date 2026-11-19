class_name SkySetPieces
extends Node3D
## The run's moving and breaking things (user, 2026-11-18: set pieces, "collapsing structures, moving parts", Hydro Thunder style):
##   the crews' floodlight poles (one every 38 m, alternating sides, sodium and cold white in pairs: sky_road.gdshader draws their pools on
##   the deck), burning barrels, and glitching holo billboards hung off the shell (the neon in the grime),
##   THE CRUSHERS: hydraulic heads over one lane at a time, a red beacon before each slam; under one when it lands is a wreck,
##   THE GANTRY: a rusted crane gantry over the road that comes down as the first craft nears it; its girders stay on the road,
##   THE COLUMN: a support column standing in the middle of a widened road,
##   THE WRECKERS: wrecking balls on chains swinging across the road from gantries (stretch two),
##   THE SHIELDING: the reactor's shield plates, which come down like the gantry's girders.
## Simulated here (not by the physics engine) so the takedown slow motion slows them too. Back as they were at every start.

const G := 24.0
const POLE_EVERY := 38.0
const CRUSH_PERIOD := 2.3
const HEAD_UP := 7.0
const HEAD_DOWN := 0.25
const GANTRY_H := 9.5
const GANTRY_WARN := 110.0     # metres before it that the first craft brings it down
const COLUMN_R := 3.4
const BALL_R := 1.8
const BALL_PIVOT := 15.0       # the pivot's height over the deck
const BALL_CHAIN := 13.4
const BALL_PERIOD := 2.8


class Head:
	var node: MeshInstance3D
	var beacon: MeshInstance3D
	var base := Transform3D.IDENTITY   # the frame at the road (x across, y up)
	var u0 := 0.0
	var u1 := 0.0
	var phase := 0.0
	var h := HEAD_UP


class Ball:
	var node: MeshInstance3D
	var chain: MeshInstance3D
	var base := Transform3D.IDENTITY
	var i := 0
	var phase := 0.0
	var amp := 8.0
	var pos := Vector3.ZERO

	func across(t: float) -> float:
		return amp * sin(TAU * (t / BALL_PERIOD + phase))

	func height(x: float) -> float:
		return BALL_PIVOT - sqrt(maxf(0.0, BALL_CHAIN * BALL_CHAIN - x * x))


class Girder:
	var node: MeshInstance3D
	var home := Transform3D.IDENTITY
	var pos := Vector3.ZERO
	var basis := Basis.IDENTITY
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO
	var half := 4.0                    # half its length
	var falling := false
	var down := false
	var index := 0


var race: SkyRace
var _course: SkyCourse
var _heads: Array[Head] = []
var _balls: Array[Ball] = []
var _girders: Array[Girder] = []
var _gantry_s := PackedFloat32Array()
var _gantry_fell: Array[bool] = []
var _columns: Array[Vector3] = []      # centre at deck height, and the road's up there
var _column_up: Array[Vector3] = []
var _beacon_on: Material
var _beacon_off: Material


func build(owner_race: SkyRace) -> void:
	name = "SetPieces"
	race = owner_race
	_course = race.course
	_poles()
	_crushers()
	_gantries()
	_column_build()
	_wreckers()
	reset()


func reset() -> void:
	for g: Girder in _girders:
		g.falling = false
		g.down = false
		g.pos = g.home.origin
		g.basis = g.home.basis
		g.vel = Vector3.ZERO
		g.spin = Vector3.ZERO
		g.node.global_transform = g.home
	for k in _gantry_fell.size():
		_gantry_fell[k] = false


func tick(dt: float) -> void:
	var t := race.race_time()
	for hd: Head in _heads:
		var c := fposmod(t / CRUSH_PERIOD + hd.phase, 1.0)
		var h := HEAD_UP
		if c > 0.55 and c < 0.62:
			h = lerpf(HEAD_UP, HEAD_DOWN, pow(inverse_lerp(0.55, 0.62, c), 2.0))
		elif c >= 0.62 and c < 0.8:
			h = HEAD_DOWN
		elif c >= 0.8:
			h = lerpf(HEAD_DOWN, HEAD_UP, smoothstep(0.8, 1.0, c))
		if hd.h > 0.6 and h <= 0.6:
			Game.fx.sparks(hd.base * Vector3((hd.u0 + hd.u1) * 0.5, 0.3, 0.0), 14, 8.0, hd.base.basis.y, 0xffb060)
			race.cue_near(SkyDriveFx.Cue.CRASH, hd.base.origin)
		hd.h = h
		hd.node.transform = Transform3D(hd.base.basis, hd.base * Vector3((hd.u0 + hd.u1) * 0.5, h + 0.9, 0.0))
		hd.beacon.material_override = _beacon_on if (c > 0.38 and c < 0.62 and fmod(t * 8.0, 1.0) < 0.5) else _beacon_off
	# the gantry comes down when the first craft nears it
	for k in _gantry_s.size():
		if _gantry_fell[k]:
			continue
		for r: SkyRace.Racer in race.racers:
			if r.progress + SkyRace.START_LINE > _gantry_s[k] - GANTRY_WARN:
				_collapse(k)
				break
	for g: Girder in _girders:
		if g.falling:
			_fall(g, dt)
	for b: Ball in _balls:
		var x := b.across(t)
		b.pos = b.base * Vector3(x, b.height(x), 0.0)
		var pivot := b.base * Vector3(0.0, BALL_PIVOT, 0.0)
		b.node.global_transform = Transform3D(b.base.basis, b.pos)
		b.chain.global_transform = SkyGeometry.beam(pivot, b.pos, 0.18, 0.18)
	_collide()


## Whatever a craft runs into here: the crushers, the fallen girders, the column.
func _collide() -> void:
	for r: SkyRace.Racer in race.everyone:
		var car := r.car
		if car.wrecked or r.ghost > 0.0 or car.held:
			continue
		if car.path == SkyCourse.MAIN:
			for hd: Head in _heads:
				if hd.h > 1.7:
					continue
				var l := hd.base.affine_inverse() * car.pos
				if absf(l.z) < 2.4 + car.half.z * 0.6 and l.x > hd.u0 - car.half.x * 0.6 and l.x < hd.u1 + car.half.x * 0.6 and l.y < hd.h + 1.6:
					race.crash(r, "CRUSHED")
		for g: Girder in _girders:
			if not (g.falling or g.down):
				continue
			var a := g.pos - g.basis.x * g.half
			var b := g.pos + g.basis.x * g.half
			var ab := b - a
			var t := clampf((car.pos - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var near := a + ab * t
			var off := car.pos - near
			var d := off.length()
			var reach := car.half.x + 0.75
			if d >= reach or d < 0.001:
				continue
			var n := off / d
			if g.falling:
				race.crash(r, "COLLAPSE")
				continue
			car.pos += n * (reach - d)
			var vn := car.vel.dot(n)
			if vn < 0.0:
				car.vel -= n * (vn * 1.3)
				Game.fx.sparks(near, 8, 6.0, n, 0xffc070)
				if -vn > 20.0 * (SkyRace.PLAYER_TOUGH if r == race.player_racer() else 1.0):
					race.crash(r, "DEBRIS")
		for b: Ball in _balls:
			var d := car.pos.distance_to(b.pos)
			if d > BALL_R + car.half.x + 0.3:
				continue
			var n := (car.pos - b.pos)
			n -= car.road.basis.y * n.dot(car.road.basis.y)
			n = n.normalized() if n.length() > 0.01 else car.road.basis.x
			if r == race.player_racer():
				# it hits the player hard and throws him across; the wall he lands in decides the rest
				car.vel += n * 16.0 + car.road.basis.y * 3.0
				car.stagger = maxf(car.stagger, 1.0)
				car.pos += n * (BALL_R + car.half.x + 0.3 - d)
				Game.fx.sparks(b.pos, 16, 9.0, n, 0xffb060)
				race.cue_near(SkyDriveFx.Cue.CRASH, b.pos)
			else:
				race.crash(r, "WRECKING BALL")
		for k in _columns.size():
			var up := _column_up[k]
			var off := car.pos - _columns[k]
			off -= up * off.dot(up)
			var d := off.length()
			var reach := COLUMN_R + car.half.x
			if d >= reach or d < 0.001:
				continue
			var n := off / d
			car.pos += n * (reach - d)
			var vn := car.vel.dot(n)
			if vn < 0.0:
				car.vel -= n * (vn * 1.2)
				Game.fx.sparks(_columns[k] + n * COLUMN_R + up * 0.8, 8, 6.0, n, 0xffc070)
				if -vn > 24.0 * (SkyRace.PLAYER_TOUGH if r == race.player_racer() else 1.0):
					race.crash(r, "COLUMN")


# ------------------------------------------------------------- for the AI ----

## The nearest lane to `lat` that nothing here blocks between main samples i0 and i1, for a craft at main metres s_car going v: the
## column, girders on the road (or coming down), a crusher that will be down when it gets there.
## `cur`: where the craft is across now; the gap on that side is taken (choosing by the line flipped sides halfway through the swerve).
func free_lat(i0: int, i1: int, lat: float, s_car: float, v: float, room_l: float, room_r: float, cur: float = NAN) -> float:
	var lo: Array[float] = []
	var hi: Array[float] = []
	const MARGIN := 2.0
	var p := _course.paths[SkyCourse.MAIN]
	for k in _heads.size():
		var c := _course.crushers[k]
		if c.i < i0 - 3 or c.i > i1 + 3:
			continue
		var t := race.race_time() + maxf(0.0, p.metres[c.i] - s_car) / maxf(v, 10.0)
		var ph := fposmod(t / CRUSH_PERIOD + c.phase, 1.0)
		if ph > 0.45 and ph < 0.9:
			lo.append(c.u0 - MARGIN)
			hi.append(c.u1 + MARGIN)
	for b: Ball in _balls:
		if b.i < i0 - 4 or b.i > i1 + 4:
			continue
		var tb := race.race_time() + maxf(0.0, p.metres[b.i] - s_car) / maxf(v, 10.0)
		var x := b.across(tb)
		if b.height(x) < 4.5:
			lo.append(x - BALL_R - 1.8)
			hi.append(x + BALL_R + 1.8)
	for g: Girder in _girders:
		if not (g.down or g.falling) or g.index < i0 - 9 or g.index > i1 + 9:
			continue
		var fr := _course.frame(SkyCourse.MAIN, g.index)
		var ua := (g.pos - g.basis.x * g.half - fr.origin).dot(fr.basis.x)
		var ub := (g.pos + g.basis.x * g.half - fr.origin).dot(fr.basis.x)
		if g.falling:
			ua = (g.home.origin - g.home.basis.x * g.half - fr.origin).dot(fr.basis.x)
			ub = (g.home.origin + g.home.basis.x * g.half - fr.origin).dot(fr.basis.x)
		lo.append(minf(ua, ub) - 2.6)      # (the widest craft's half width, the piece's own thickness and a little room)
		hi.append(maxf(ua, ub) + 2.6)
	for ci: int in _course.columns:
		if ci >= i0 - 6 and ci <= i1 + 6:
			lo.append(-COLUMN_R - 4.0)
			hi.append(COLUMN_R + 4.0)
	if lo.is_empty():
		return lat
	var blocked := func(u: float) -> bool:
		for k in lo.size():
			if u > lo[k] and u < hi[k]:
				return true
		return false
	if not blocked.call(lat):
		return lat
	var from := lat if is_nan(cur) else cur
	var best := lat
	var best_d := INF
	var options: Array[float] = []
	for k in lo.size():
		options.append(lo[k] - 0.05)
		options.append(hi[k] + 0.05)
	for u: float in options:
		if u > room_l or u < -room_r or blocked.call(u):
			continue
		if absf(u - from) < best_d:
			best_d = absf(u - from)
			best = u
	return best


# ----------------------------------------------------------------- poles ----

func _poles() -> void:
	var p := _course.paths[SkyCourse.MAIN]
	var steel: Array[Transform3D] = []
	var lamps: Array[Transform3D] = []
	var cold: Array[Transform3D] = []
	var k := 0
	while true:
		var s := float(k) * POLE_EVERY + POLE_EVERY * 0.5
		if s > p.metres[p.size() - 1]:
			break
		var i := _course.index_at(s)
		var side := 1.0 if k % 2 == 0 else -1.0
		if p.mag[i] == 0 and p.deck[i] == 1:
			var fr := p.frames[i]
			var edge := (p.wl[i] if side > 0.0 else p.wr[i]) + 0.9
			var foot := fr * Vector3(side * edge, -0.2, 0.0)
			var top := fr * Vector3(side * edge, 9.0, 0.0)
			var arm := fr * Vector3(side * (edge - 3.0), 9.2, 0.0)
			steel.append(SkyGeometry.beam(foot, top, 0.35, 0.35))
			steel.append(SkyGeometry.beam(top, arm, 0.25, 0.25))
			(lamps if k % 4 < 2 else cold).append(SkyGeometry.box_at(arm - fr.basis.y * 0.25, Vector3(1.4, 0.3, 0.8), fr.basis))
		k += 1
	SkyGeometry.boxes(self, SkyLook.rust(), steel)
	SkyGeometry.boxes(self, SkyGeometry.light(SkyLook.SODIUM, 2.6), lamps)
	SkyGeometry.boxes(self, SkyGeometry.light(SkyLook.WORK, 2.4), cold)
	_billboards()
	# burning barrels and a flare line at the start
	var fire: Array[Transform3D] = []
	var drums: Array[Transform3D] = []
	var fires: Array[float] = [12.0, 30.0, 52.0, 70.0]
	for f in 8:
		fires.append(_course.finish_s - 60.0 + float(f) * 22.0)      # the Sump's finish
	for s: float in fires:
		var fr := _course.sample(s)
		for side: float in [-1.0, 1.0]:
			var at := fr * Vector3(side * (SkyCourse.HALF_WIDTH + 2.4), 0.5, 0.0)
			drums.append(SkyGeometry.box_at(at, Vector3(0.9, 1.0, 0.9), fr.basis))
			fire.append(SkyGeometry.box_at(at + fr.basis.y * 0.62, Vector3(0.7, 0.25, 0.7), fr.basis))
	SkyGeometry.boxes(self, SkyLook.rust(), drums)
	SkyGeometry.boxes(self, SkyGeometry.light(Color("ff6a1a"), 3.0), fire)
	var glow := OmniLight3D.new()
	glow.light_color = Color("ff7a2a")
	glow.light_energy = 3.0
	glow.omni_range = 40.0
	glow.shadow_enabled = false
	glow.position = _course.sample(30.0) * Vector3(0.0, 6.0, 0.0)
	add_child(glow)
	for s: float in [_course.finish_s - 20.0, _course.finish_s + 60.0]:
		var sump := OmniLight3D.new()
		sump.light_color = Color("ff5a1a")
		sump.light_energy = 3.5
		sump.omni_range = 55.0
		sump.shadow_enabled = false
		sump.position = _course.sample(s) * Vector3(0.0, 8.0, 0.0)
		add_child(sump)


## Holo billboards for the race, hung off the shell side of the run on rusted struts, glitching red and teal: the neon in the grime.
func _billboards() -> void:
	var p := _course.paths[SkyCourse.MAIN]
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://levels/sky_sphere/sky_holo.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2(22.0, 9.0)
	var struts: Array[Transform3D] = []
	var words: Array[String] = ["OVERCURRENT", "NO RULES", "PLACE YOUR BETS", "OVERCURRENT", "RUN IT", "NO REFUNDS"]
	var k := 0
	var s := 220.0
	while s < _course.finish_s - 100.0:
		var i := _course.index_at(s)
		if p.mag[i] == 0:
			var fr := p.frames[i]
			var side := -1.0      # the shell side (the sphere's axis is on the left)
			var at := fr * Vector3(side * (p.wr[i] + 16.0), 14.0, 30.0)
			var face := (fr.origin + fr.basis.z * 60.0 - at)
			face.y = 0.0
			var basis := Basis.looking_at(-face.normalized(), Vector3.UP)
			var board := MeshInstance3D.new()
			board.mesh = quad
			board.material_override = mat
			board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			board.transform = Transform3D(basis, at)
			board.set_instance_shader_parameter(&"seed", float(k) * 3.7)
			board.set_instance_shader_parameter(&"hue", 0.0 if k % 2 == 0 else 1.0)
			add_child(board)
			var label := SkyGeometry.sign_text(self, words[k % words.size()], at + basis.z * 0.1, 0.03, Color("ffd9d0") if k % 2 == 0 else Color("d0fff8"), &"orb800")
			label.basis = basis
			for dx: float in [-8.0, 8.0]:
				var top := at + basis.x * dx - Vector3.UP * 4.5
				struts.append(SkyGeometry.beam(top, top - Vector3.UP * 26.0 + basis.z * 4.0, 0.8, 0.8))
			k += 1
		s += 290.0
	SkyGeometry.boxes(self, SkyLook.rust(), struts)


# -------------------------------------------------------------- crushers ----

func _crushers() -> void:
	var p := _course.paths[SkyCourse.MAIN]
	_beacon_on = SkyGeometry.light(SkyLook.BEACON, 3.0)
	_beacon_off = SkyGeometry.light(Color("3a1410"), 1.0)
	var head_mat := ShaderMaterial.new()
	head_mat.shader = preload("res://levels/sky_sphere/sky_prop.gdshader")
	head_mat.set_shader_parameter(&"paint", Color("c9a01a"))
	var frame: Array[Transform3D] = []
	var lens := BoxMesh.new()
	lens.size = Vector3(0.6, 0.4, 0.6)
	for c: SkyCourse.Crusher in _course.crushers:
		var fr := p.frames[c.i]
		var hd := Head.new()
		hd.base = fr
		hd.u0 = c.u0
		hd.u1 = c.u1
		hd.phase = c.phase
		var box := BoxMesh.new()
		box.size = Vector3(c.u1 - c.u0, 1.8, 4.6)
		hd.node = MeshInstance3D.new()
		hd.node.mesh = box
		hd.node.material_override = head_mat
		hd.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(hd.node)
		# the press frame: posts outside the walls on both sides and a beam across the whole road, the piston hung over its lane
		# (posts at the lane's own edges stood in the middle of the road)
		var wl := p.wl[c.i] + 1.6
		var wr := -(p.wr[c.i] + 1.6)
		for u: float in [wl, wr]:
			frame.append(SkyGeometry.beam(fr * Vector3(u, -0.3, 2.6), fr * Vector3(u, HEAD_UP + 3.6, 2.6), 0.8, 0.8))
			frame.append(SkyGeometry.beam(fr * Vector3(u, -0.3, -2.6), fr * Vector3(u, HEAD_UP + 3.6, -2.6), 0.8, 0.8))
		frame.append(SkyGeometry.beam(fr * Vector3(wr, HEAD_UP + 3.6, 0.0), fr * Vector3(wl, HEAD_UP + 3.6, 0.0), 1.2, 5.6))
		frame.append(SkyGeometry.beam(fr * Vector3((c.u0 + c.u1) * 0.5, HEAD_UP + 3.0, 0.0), fr * Vector3((c.u0 + c.u1) * 0.5, HEAD_UP + 1.6, 0.0), 1.0, 1.0))
		hd.beacon = MeshInstance3D.new()
		hd.beacon.mesh = lens
		hd.beacon.transform = Transform3D(fr.basis, fr * Vector3((c.u0 + c.u1) * 0.5, HEAD_UP + 4.5, 0.0))
		add_child(hd.beacon)
		_heads.append(hd)
	SkyGeometry.boxes(self, SkyLook.rust(), frame)


# ---------------------------------------------------------------- gantry ----

func _gantries() -> void:
	var p := _course.paths[SkyCourse.MAIN]
	var towers: Array[Transform3D] = []
	var lamps: Array[Transform3D] = []
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.9, 1.1)
	for gi in _course.gantries.size():
		var i := _course.gantries[gi]
		var fr := p.frames[i]
		_gantry_s.append(p.metres[i])
		_gantry_fell.append(false)
		var wl := p.wl[i] + 1.4
		var wr := p.wr[i] + 1.4
		for u: float in [wl, -wr]:
			towers.append(SkyGeometry.beam(fr * Vector3(u, -0.4, 0.0), fr * Vector3(u, GANTRY_H + 1.0, 0.0), 1.6, 2.2))
			towers.append(SkyGeometry.beam(fr * Vector3(u, -0.4, 1.8), fr * Vector3(u, GANTRY_H, 0.0), 0.5, 0.5))
			towers.append(SkyGeometry.beam(fr * Vector3(u, -0.4, -1.8), fr * Vector3(u, GANTRY_H, 0.0), 0.5, 0.5))
		# the truss across, in pieces that come down
		var style := _course.gantry_style[gi] if gi < _course.gantry_style.size() else 0
		var n := 5 if style == 0 else 4
		var span := wl + wr
		for k in n:
			var u_mid := wl - span * (float(k) + 0.5) / float(n)
			var g := Girder.new()
			g.half = span / float(n) * 0.5
			g.index = i
			var piece := MeshInstance3D.new()
			var m := BoxMesh.new()
			m.size = Vector3(g.half * 2.0, 1.1, 1.4) if style == 0 else Vector3(g.half * 2.0, 0.5, 2.6)
			piece.mesh = m
			piece.material_override = SkyLook.rust() if style == 0 else SkyLook.steel()
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			piece.top_level = true
			add_child(piece)
			g.node = piece
			g.home = Transform3D(fr.basis, fr * Vector3(u_mid, GANTRY_H, 0.0))
			_girders.append(g)
			lamps.append(SkyGeometry.box_at(fr * Vector3(u_mid, GANTRY_H - 0.8, 0.0), Vector3(1.2, 0.3, 0.6), fr.basis))
	SkyGeometry.boxes(self, SkyLook.rust(), towers)
	SkyGeometry.boxes(self, SkyGeometry.light(SkyLook.WORK, 2.2), lamps)


func _collapse(k: int) -> void:
	_gantry_fell[k] = true
	var i := _course.gantries[k]
	var fr := _course.frame(SkyCourse.MAIN, i)
	race.cue_near(SkyDriveFx.Cue.CRASH, fr.origin)
	Game.fx.sparks(fr * Vector3(0.0, GANTRY_H, 0.0), 30, 12.0, null, 0xffb060)
	# two of the truss pieces come down, never side by side, so there is always a way through (all of it blocked the whole road)
	var pattern: Array = [[1, 3], [0, 3], [1, 4], [0, 2], [2, 4]].pick_random()
	var n := 0
	for g: Girder in _girders:
		if g.index != i:
			continue
		n += 1
		if not pattern.has(n - 1):
			continue
		g.falling = true
		g.vel = fr.basis.z * randf_range(-4.0, 4.0) + fr.basis.x * randf_range(-2.0, 2.0)
		g.spin = Vector3(randf_range(-1.0, 1.0), randf_range(-1.5, 1.5), randf_range(-1.0, 1.0))
	if race.player_racer().progress + SkyRace.START_LINE > _gantry_s[k] - GANTRY_WARN - 60.0:
		race.pop("IT'S COMING DOWN")


func _fall(g: Girder, dt: float) -> void:
	var fr := _course.frame(SkyCourse.MAIN, g.index)
	g.vel += Vector3.DOWN * (G * dt)
	g.pos += g.vel * dt
	var w := g.spin.length()
	if w > 0.001:
		g.basis = Basis(g.spin / w, w * dt) * g.basis
	var h := (g.pos - fr.origin).dot(fr.basis.y)
	if h < 0.6:
		# landed: lying on the deck, a little askew, for the rest of the run
		g.pos += fr.basis.y * (0.6 - h)
		g.falling = false
		g.down = true
		var along := g.basis.x - fr.basis.y * g.basis.x.dot(fr.basis.y)
		if along.length_squared() < 0.01:
			along = fr.basis.x
		along = along.normalized()
		g.basis = Basis(along, fr.basis.y, along.cross(fr.basis.y)).orthonormalized()
		Game.fx.dust(g.pos, 6, 2.5)
		Game.fx.sparks(g.pos, 12, 7.0, fr.basis.y, 0xffb060)
	g.node.global_transform = Transform3D(g.basis, g.pos)


# --------------------------------------------------------------- wreckers ----

func _wreckers() -> void:
	var p := _course.paths[SkyCourse.MAIN]
	var ball := SphereMesh.new()
	ball.radius = BALL_R
	ball.height = BALL_R * 2.0
	ball.radial_segments = 16
	ball.rings = 8
	var chain := BoxMesh.new()
	chain.size = Vector3.ONE
	var frame: Array[Transform3D] = []
	for c: SkyCourse.Crusher in _course.wreckers:
		var fr := p.frames[c.i]
		var b := Ball.new()
		b.base = fr
		b.i = c.i
		b.phase = c.phase
		b.amp = minf(p.wl[c.i], p.wr[c.i]) * 0.85
		b.node = MeshInstance3D.new()
		b.node.mesh = ball
		b.node.material_override = SkyLook.rust()
		b.node.top_level = true
		add_child(b.node)
		b.chain = MeshInstance3D.new()
		b.chain.mesh = chain
		b.chain.material_override = SkyLook.steel()
		b.chain.top_level = true
		add_child(b.chain)
		var wl := p.wl[c.i] + 1.6
		var wr := -(p.wr[c.i] + 1.6)
		for u: float in [wl, wr]:
			frame.append(SkyGeometry.beam(fr * Vector3(u, -0.3, 0.0), fr * Vector3(u, BALL_PIVOT + 1.0, 0.0), 1.0, 1.4))
		frame.append(SkyGeometry.beam(fr * Vector3(wr, BALL_PIVOT + 0.6, 0.0), fr * Vector3(wl, BALL_PIVOT + 0.6, 0.0), 1.4, 1.2))
		_balls.append(b)
	SkyGeometry.boxes(self, SkyLook.rust(), frame)


# ---------------------------------------------------------------- column ----

func _column_build() -> void:
	var p := _course.paths[SkyCourse.MAIN]
	var cyl := CylinderMesh.new()
	cyl.top_radius = COLUMN_R
	cyl.bottom_radius = COLUMN_R * 1.15
	cyl.height = 160.0
	cyl.radial_segments = 20
	var bands: Array[Transform3D] = []
	for i: int in _course.columns:
		var fr := p.frames[i]
		_columns.append(fr.origin)
		_column_up.append(fr.basis.y)
		var node := MeshInstance3D.new()
		node.mesh = cyl
		node.material_override = SkyLook.concrete()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.transform = Transform3D(fr.basis, fr.origin + fr.basis.y * 30.0)
		add_child(node)
		# hazard bands and lamps so it reads from far off at speed (it was a black mass)
		var stripes := MeshInstance3D.new()
		var band := CylinderMesh.new()
		band.top_radius = COLUMN_R * 1.03
		band.bottom_radius = COLUMN_R * 1.08
		band.height = 2.4
		band.radial_segments = 20
		stripes.mesh = band
		var hazard := ShaderMaterial.new()
		hazard.shader = preload("res://levels/sky_sphere/sky_prop.gdshader")
		hazard.set_shader_parameter(&"paint", Color("e0a81c"))
		stripes.material_override = hazard
		stripes.transform = Transform3D(fr.basis, fr.origin + fr.basis.y * 1.3)
		add_child(stripes)
		for k in 4:
			var a := TAU * float(k) / 4.0
			var off := (fr.basis.x * cos(a) + fr.basis.z * sin(a)) * (COLUMN_R + 0.2)
			bands.append(SkyGeometry.box_at(fr.origin + off + fr.basis.y * 6.0, Vector3(0.6, 0.6, 0.6), fr.basis))
		var lamp := OmniLight3D.new()
		lamp.light_color = SkyLook.SODIUM
		lamp.light_energy = 2.5
		lamp.omni_range = 26.0
		lamp.position = fr.origin + fr.basis.y * 10.0 - fr.basis.z * 8.0
		add_child(lamp)
	SkyGeometry.boxes(self, SkyGeometry.light(SkyLook.BEACON, 2.4), bands)
