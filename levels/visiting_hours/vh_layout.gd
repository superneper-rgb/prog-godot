class_name VhLayout
extends RefCounted
## VISITING HOURS layout (JS levels/visiting-hours/layout.js): every number the level's script uses. The road, the track and the levee ring are sampled by the JS with three.js's CatmullRomCurve3 and handed over in level.json (data.vh.layout), so they are the same points.

const ROAD_Y := 0.35
const PLAT_Y := 16.0
const PLAT := {"x": 122.0, "z": 704.0, "r": 21.0}
const PRISON := {"x": 270.0, "z": 1000.0, "hx": 95.0, "hz": 72.0, "wall_h": 12.0}
const W := 175.0      # PRISON.x - PRISON.hx: the west wall's line
const PAD := 3.0
const LEVEE := 1.3
const OFF := {"fence": 12.0, "lip": 16.0, "canal": 18.0, "road0": 20.0, "road_c": 23.25, "road1": 26.5, "bank": 29.5}
const GATE := {"z": 1010.0, "x": W, "hw": 4.5}
const ADK := 1.6
const ADP := Vector2(202.425, 961.0)
const AD_D := {"x0": 190.0, "x1": 220.0, "z0": 954.0, "z1": 976.0, "in": 0.35}
const PIPE := {"z": 961.0, "x0": W - 16.0, "x1": 190.0, "floor": 0.14, "roof": 1.32, "hw": 0.78}
const PUMP := {"x0": 190.0, "x1": 202.0, "z0": 955.0, "z1": 967.0, "ceil": 2.6}
const OUTFALL := Vector2(W - 16.0, 961.0)
const ZIP_LAND := Vector3(143.5, 0.0, 801.0)
const FL := {&"b1": 0.0, &"f1": PAD, &"f2": PAD + 6.0, &"f3": PAD + 12.0, &"f4": PAD + 18.0}
const CEIL := {&"b1": 2.7, &"f1": 3.6, &"f2": 3.4, &"f3": 3.4, &"f4": 3.6}
const FLW := {&"b1": -1.2, &"f1": PAD, &"f2": PAD + 6.0, &"f3": PAD + 12.0, &"f4": PAD + 18.0}
const CEILW := {&"b1": 3.9, &"f1": 5.4, &"f2": 5.4, &"f3": 5.4, &"f4": 5.4}
const FLOORS: Array[StringName] = [&"b1", &"f1", &"f2", &"f3", &"f4"]
const LO := 1.3
const OFFICE_D := {"x": 212.0, "w": 6.0, "sill": 1.1, "head": 3.7}
const STAIR_B := {"x0": 214.4, "x1": 219.65, "z0": 954.35, "z1": 962.6, "door": 961.0}
const STAIR_A := {"x0": 190.35, "x1": 195.6, "z0": 968.8, "z1": 975.65}
const LIFT := {"x0": 205.8, "x1": 209.0, "z0": 972.6, "z1": 975.65, "door": 974.1}
const BEDS := [[145.0, 806.0, 7.5], [160.0, 826.0, 5.5], [141.0, 840.0, 5.0], [169.0, 851.0, 6.0], [150.0, 866.0, 5.5], [132.0, 879.0, 4.5], [183.0, 878.0, 5.0], [162.0, 888.0, 5.5], [143.0, 897.0, 4.0]]
const TRACK_P0 := Vector2(40.6, 590.0)

static var deck := PLAT_Y + 5.2
static var board_yaw := atan2(PRISON.x - (PLAT.x + 6.0), PRISON.z - (PLAT.z + 9.0))


## a sampled path: arrays for speed (JS { pts: [{x, z, s, yaw, y}], L })
class Path:
	var x := PackedFloat64Array()
	var z := PackedFloat64Array()
	var y := PackedFloat64Array()
	var s := PackedFloat64Array()
	var yaw := PackedFloat64Array()
	var len_ := 0.0
	var n := 0

	func _init(d: Dictionary) -> void:
		var pts: Array = d.pts
		n = pts.size()
		x.resize(n)
		z.resize(n)
		y.resize(n)
		s.resize(n)
		yaw.resize(n)
		for i in n:
			var p: Dictionary = pts[i]
			x[i] = p.x
			z[i] = p.z
			y[i] = p.y
			s[i] = p.s
			yaw[i] = p.yaw
		len_ = float(d.L)


class At:
	var x := 0.0
	var z := 0.0
	var y := 0.0
	var yaw := 0.0
	var s := 0.0


class Near:
	var s := 0.0
	var d := 0.0
	var i := 0


static var road: Path
static var track: Path
static var ring_road: Path
static var turn_s := 0.0
static var mile := 0.0
static var cue := {}
static var spot := {}


static func load_paths(d: Dictionary) -> void:
	road = Path.new(d.ROAD)
	track = Path.new(d.TRACK)
	ring_road = Path.new(d.RING_ROAD)
	turn_s = nearest(road, TRACK_P0.x, TRACK_P0.y).s
	mile = nearest(road, 0.0, -20.0).s
	cue = {"reveal": turn_s - 540.0, "track": turn_s - 235.0, "lights": turn_s - 14.0}
	spot = {"start": _st(at(road, 4.0)), "turn": _st(at(road, turn_s - 30.0)), "park": [PLAT.x - 10.0, PLAT_Y, PLAT.z - 8.0, PI * 0.35]}


static func _st(p: At) -> Array:
	return [p.x, p.y, p.z, p.yaw]


## point at arc length s along a sampled path (lerped)
static func at(path: Path, s: float) -> At:
	var i := clampi(int(floor(s / (path.len_ / float(path.n - 1)))), 0, path.n - 2)
	var ds := path.s[i + 1] - path.s[i]
	var k := clampf((s - path.s[i]) / (ds if ds != 0.0 else 1.0), 0.0, 1.0)
	var o := At.new()
	o.x = path.x[i] + (path.x[i + 1] - path.x[i]) * k
	o.z = path.z[i] + (path.z[i + 1] - path.z[i]) * k
	o.y = path.y[i] + (path.y[i + 1] - path.y[i]) * k
	o.yaw = path.yaw[i] + wrap_a(path.yaw[i + 1] - path.yaw[i]) * k
	o.s = s
	return o


## nearest sample to (x, z) (every 8th sample, then the neighbours of the best: the road never doubles back that tight)
static func nearest(path: Path, x: float, z: float) -> Near:
	var bi := 0
	var bd := INF
	var i := 0
	while i < path.n:
		var d := (path.x[i] - x) * (path.x[i] - x) + (path.z[i] - z) * (path.z[i] - z)
		if d < bd:
			bd = d
			bi = i
		i += 8
	for j in range(maxi(0, bi - 8), mini(path.n - 1, bi + 8) + 1):
		var d := (path.x[j] - x) * (path.x[j] - x) + (path.z[j] - z) * (path.z[j] - z)
		if d < bd:
			bd = d
			bi = j
	var o := Near.new()
	o.s = path.s[bi]
	o.d = sqrt(bd)
	o.i = bi
	return o


static func wrap_a(a: float) -> float:
	while a > PI:
		a -= TAU
	while a < -PI:
		a += TAU
	return a


static func ad_x(x: float) -> float:
	return ADP.x + (x - ADP.x) * ADK


static func ad_z(z: float) -> float:
	return ADP.y + (z - ADP.y) * ADK


static func floor_of_d(y: float) -> StringName:
	var i := FLOORS.size() - 1
	while i > 0 and y < float(FL[FLOORS[i]]) - 0.001:
		i -= 1
	return FLOORS[i]


## maps a design height: up to LO above a floor it is kept, within half a metre of the ceiling it keeps its distance from the ceiling, in between it stretches; lin: straight between the floors (the stair flights)
static func ad_y(y: float, lin: bool = false) -> float:
	var f := floor_of_d(y)
	var i := FLOORS.find(f)
	var has_n := i + 1 < FLOORS.size()
	var n: StringName = FLOORS[i + 1] if has_n else &""
	var fl: float = FL[f]
	var flw: float = FLW[f]
	var h := y - fl
	var cd: float = CEIL[f]
	var cw: float = CEILW[f]
	if lin and has_n:
		return flw + h * (float(FLW[n]) - flw) / (float(FL[n]) - fl)
	if h <= LO:
		return flw + h
	if h < cd - 0.5:
		return flw + LO + (h - LO) * (cw - 0.5 - LO) / (cd - 0.5 - LO)
	if h <= cd or not has_n:
		return flw + cw - (cd - h)
	return flw + cw + (h - cd) * (float(FLW[n]) - flw - cw) / (float(FL[n]) - fl - cd)      # (the plenum, up to the next floor)


static func s3(x: float, y: float, z: float) -> Array:
	return [ad_x(x), ad_y(y, true), ad_z(z)]


## billboard-local (x, z) -> world (JS scen.toW)
static func to_w(x: float, z: float) -> Vector2:
	var c := cos(board_yaw)
	var s := sin(board_yaw)
	return Vector2(float(PLAT.x) + 6.0 + x * c + z * s, float(PLAT.z) + 9.0 - x * s + z * c)


static func office() -> Dictionary:
	var y0 := ad_y(float(FL[&"f4"]) + float(OFFICE_D.sill))
	var y1 := ad_y(float(FL[&"f4"]) + float(OFFICE_D.head))
	return {"x": ad_x(OFFICE_D.x), "y": (y0 + y1) / 2.0, "z": ad_z(AD_D.z0), "w": float(OFFICE_D.w) * ADK, "h": y1 - y0}
