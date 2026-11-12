extends KitLevel
## BACK ALLEY (JS levels/worldbackalley/level.js): a straight run through another part of the city in a thunderstorm, held by gray aliens. One stage: the ambush, then per group of grays a 'reach' ring ALERT_RANGE short of them (walking in spawns the group, already alerted) and a 'kill' objective.
## It opens on the intro cutscene (alley_intro.gd: Prog walking home past the grays' social club, they heckle, a warning shot, the ambush) and the ambush fight; the last kill plays the ending (alley_outro.gd: he collapses in the puddle outside his building) and goes home to the hub. alley_props.gd: what moves on the set pieces.

const SW := 7.5
const ZL := 110.0
const ALERT_RANGE := 22.0
const RW := 4.2
# [z of the group, [x, z] of each alien]. The ambush (the intro's grays) holds the stretch up to z -70, so the first ring group starts at z -44.
const GROUPS := [
	[-44.0, [[-3.0, -42.0], [1.0, -46.0], [5.6, -49.0]]],
	[-20.0, [[0.0, -18.0], [-4.0, -23.0]]],
	[4.0, [[-2.0, 2.0], [2.5, 7.0], [5.8, 1.0]]],
	[36.0, [[-1.0, 33.0], [3.0, 38.0]]],
	[68.0, [[0.0, 66.0], [-3.0, 71.0], [3.2, 73.0]]],
	[96.0, [[-2.0, 94.0], [2.0, 97.0], [0.0, 100.0]]],
]
const PATH := {"x": 0.9, "z0": -105.0, "stop": -81.7}
const AMBUSH0 := [["club", -6.2, -85.2], ["club", -6.7, -86.9], ["club", -5.95, -87.6], ["door", -5.9, -84.0], ["rise", 6.3, -74.6], ["rise", 5.1, -90.4], ["rise", -6.3, -70.6]]

var loadout: Array = ["pistol", "shotgun", "rifle"]      # JS LOADOUT, EQUIP
var equip := "rifle"
var weather: Storm = null
# the set pieces: the grays' social club back door (left wall), the puddle he ends up in and the heap behind him
const CLUB := {"x": -SW, "z": -86.0, "len": 4.6, "out": 1.9}
const PUDDLE := {"x": 3.3, "z": 102.6, "rx": 1.5, "rz": 1.1, "rot": 0.3}
const PILE := {"x": 2.6, "z": 94.0}      # (under the street lamp at x 6.3, z 94)
const PUDDLES := [PUDDLE, {"x": -2.2, "z": -95.0, "rx": 1.2, "rz": 0.8}, {"x": 1.8, "z": -62.0, "rx": 1.6, "rz": 0.9, "rot": 0.6}, {"x": -1.0, "z": -30.0, "rx": 1.0, "rz": 0.7}, {"x": 2.6, "z": 20.0, "rx": 1.3, "rz": 0.8, "rot": -0.4}, {"x": -2.4, "z": 58.0, "rx": 1.1, "rz": 0.9}]
var props: AlleyProps = null
var intro: AlleyIntro = null
var outro: AlleyOutro = null
var _intro_done := false


## The game runs whichever cutscene is playing in the live world (no input, its camera, its pose on the player)
class Cine:
	var L: Node3D
	var play := false
	var on: bool:
		get:
			return L.intro != null and L.intro.on or L.outro != null and L.outro.on
	var camera: View.Shot:
		get:
			return L.intro.camera if L.intro != null and L.intro.on else L.outro.camera

	func pose_player(an: Animator) -> void:
		if L.intro != null and L.intro.on:
			L.intro.pose_player(an)
		elif L.outro != null and L.outro.on:
			L.outro.pose_player(an)


var cine := Cine.new()
const STORM := {"rain_n": 4200, "rain_speed": 44.0, "slant": 0.38, "opacity": 0.44, "len": 1.4}      # a wind-driven downpour (rain_n was 7200 until 2026-11-11: too much, said the user) (CityLife; storm.gd's gusts lean it further over)


func tick_level(dt: float) -> void:
	var P := Game.player
	if intro != null:
		intro.update(dt, P)
	if outro != null:
		outro.update(dt, P)
	if props != null:
		props.update(dt)
	weather.update(dt, Game.camera.global_position)


## (dev)
func play_outro() -> bool:
	if intro != null:
		intro.finish(true)
	return outro != null and not outro.on and outro.start(Game.player)


func kit_options() -> Dictionary:
	return {"id": "worldbackalley", "name": "BACK ALLEY", "spawn": {"x": 0.0, "y": 0.0, "z": -ZL + 8.0, "yaw": 0.0}, "complete_text": "Get home.",
		"on_enter_stage": func(_b: Blockout, _o: Dictionary) -> void:      # a checkpoint load (or a respawn) mid-cutscene drops it; the intro objective restarts it
			if intro != null:
				intro.finish(true)
			if outro != null:
				outro.finish(true),
		"on_complete": func(_b: Blockout) -> void:
			if intro != null:
				intro.finish(true)
			if outro != null:
				outro.start(Game.player)}


static func _ground_y(x: float) -> float:
	return 0.0 if absf(x) <= RW else (0.15 if absf(x) <= SW else 0.0)


## nudge a spawn off a car / barrier / dumpster
func _free_spot(x: float, z: float) -> Variant:
	for r: float in [0.0, 0.8, 1.5, 2.3]:
		for k in (8 if r > 0.0 else 1):
			var px := x + sin(k * PI / 4.0) * r
			var pz := z + cos(k * PI / 4.0) * r
			var y := world.ground_height(px, pz, 0.45, 1.0)
			if absf(px) < SW - 0.6 and y > -1.0 and not world.blocked(px, pz, y, 1.6, 0.45, 0.3):
				return {"x": px, "y": y, "z": pz}
	return null


func setup() -> void:
	city = CityLife.new(self, false, STORM)
	city_ambience = true
	storm = true
	weather = Storm.new(self, city)
	cine.L = self
	props = AlleyProps.new(self, PUDDLES)
	add_child(props)
	var ambush: Array = []
	var cast: Array = []
	for a: Array in AMBUSH0:
		var p: Variant = _free_spot(a[1], a[2]) if a[0] == "rise" else null
		var x: float = p["x"] if p != null else a[1]
		var z: float = p["z"] if p != null else a[2]
		ambush.append({"x": x, "y": _ground_y(x), "z": z, "kind": "alien"})
		cast.append({"kind": a[0], "x": x, "z": z})
	intro = AlleyIntro.new(self, weather, CLUB, cast, PATH, func() -> void: _intro_done = true)
	add_child(intro)
	outro = AlleyOutro.new(self, weather, props, PUDDLE, PILE, func() -> void:
		Game.doors.travel({"id": "backalley-home", "to": "hub", "label": "HOME"}))
	add_child(outro)
	var objectives: Array = [
		{"id": "intro", "label": "Walk home", "kind": "custom", "text": "Get home.", "guide": false,
			"on_start": func(_b: Blockout, _o: Dictionary) -> void:
				_intro_done = false
				if intro == null or Game.player == null or not intro.start(Game.player):
					_intro_done = true,
			"done": func(_b: Blockout, _p: Player, _c: Combat) -> bool: return _intro_done},
		{"id": "ambush", "label": "The ambush", "kind": "kill", "text": "They want a fight. Give them one.", "spawn": [PATH.x, 0.0, PATH.stop], "spawns": ambush},
	]
	var i := 1
	for g: Array in GROUPS:
		var z: float = g[0]
		var n := str(i)
		objectives.append({"id": "approach" + n, "label": "Group " + n, "kind": "reach", "at": [0.0, 0.0, z - ALERT_RANGE], "radius": SW, "text": "Push up the alley."})
		var spawns: Array = []
		for s: Array in g[1]:
			var p: Variant = _free_spot(s[0], s[1])
			if p != null:
				var d: Dictionary = p
				d["kind"] = "alien"
				spawns.append(d)
		objectives.append({"id": "clear" + n, "label": "Clear group " + n, "kind": "kill", "text": "Clear the alley of gray aliens.", "spawns": spawns})
		i += 1
	bo.stage({"id": "alley", "name": "Back Alley", "spawn": {"x": 0.0, "y": 0.0, "z": -ZL + 8.0, "yaw": 0.0}, "task": "Gray aliens hold the street between you and home.", "objectives": objectives})
