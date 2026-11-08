class_name VhLift
extends RefCounted
## VISITING HOURS: the admin block's service lift (JS lift.js), the way round 4F's lockdown shutter. Parked open on 4F, locked by the lockdown. Overridden from 3F's tier desk it comes down at lockdown crawl (~20 s, the floor lamp over 3F's doors counting it down), its doors slide open on 3F, and it carries Prog up to the warden's floor. The car is its own floor: moving colliders.

const CAR_H := 3.4
const DOWN := 0.3      # (the lockdown crawl down; the ride up)
const UP := 1.1

var lv: ExportedLevel
var admin: VhAdmin
var audio: VhAudio
var car: Node3D
var sol: Array = []      # {s, b, t}
var shut: World.Solid
var leaves: Array = []      # {m, k}
var x0 := 0.0
var x1 := 0.0
var z0 := 0.0
var z1 := 0.0
var y3 := 0.0
var y4 := 0.0
var dx := 0.0
var dz := 0.0
var dw := 0.0
var y := 0.0
var state := "locked"
var door_k := 0.0
var t := 0.0
var hum_t := 0.0
var ind_text: Label3D
var ind_shown := ""
var door_at := Vector2.ZERO
var feeds_live := Callable()


func _init(p_lv: ExportedLevel, p_admin: VhAdmin, p_audio: VhAudio) -> void:
	lv = p_lv
	admin = p_admin
	audio = p_audio
	var LF: Dictionary = VhLayout.LIFT
	x0 = VhLayout.ad_x(LF.x0) + 0.02
	x1 = VhLayout.ad_x(LF.x1) - 0.02
	z0 = VhLayout.ad_z(LF.z0) + 0.02
	z1 = VhLayout.ad_z(LF.z1) - 0.02
	y3 = VhLayout.FLW[&"f3"]
	y4 = VhLayout.FLW[&"f4"]
	dx = VhLayout.ad_x(205.7)
	dz = VhLayout.ad_z(LF.door)
	dw = 1.6 * VhLayout.ADK
	door_at = Vector2(dx, dz)
	car = VhKit.one(lv, "service-lift")
	# (the export has the car wherever the tour left it: its geometry is in world metres over the car's own origin; y is the node's own)
	y = car.position.y
	var ss: Dictionary = VhKit.solids(lv.world)
	var cx := (x0 + x1) / 2.0
	var cz := (z0 + z1) / 2.0
	var bases := [[-0.3, 0.0], [0.0, CAR_H], [0.0, CAR_H], [0.0, CAR_H], [0.0, 1.1]]      # floor, three walls, the trolley
	var list: Array = ss.get("lift-car", [])
	for i in mini(list.size(), bases.size()):
		sol.append({"s": list[i], "b": bases[i][0], "t": bases[i][1]})
	var sh: Array = ss.get("lift-shut", [])
	shut = sh[0] if not sh.is_empty() else null
	var nodes: Array = lv.node_named("vh-lift-leaf")
	for i in nodes.size():
		leaves.append({"m": nodes[i], "k": -1.0 if (nodes[i] as Node3D).position.z < dz else 1.0})
	var ind := VhKit.one(lv, "vh-lift-ind")
	ind.visible = false
	ind_text = Label3D.new()
	ind_text.font = load("res://assets/fonts/ShareTechMono-Regular.ttf")
	ind_text.font_size = 34
	ind_text.pixel_size = 0.011
	ind_text.modulate = Color("#ff3020")
	ind_text.outline_size = 0
	ind_text.double_sided = false
	ind_text.shaded = false
	ind_text.global_transform = ind.global_transform
	(admin.floors[&"f3"] as Node3D).add_child(ind_text)
	ind_text.global_transform = ind.global_transform.translated_local(Vector3(0.0, 0.0, 0.02))
	var bk := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.9, 0.34)
	bk.mesh = qm
	bk.material_override = VhKit.unlit(0x100808)
	(admin.floors[&"f3"] as Node3D).add_child(bk)
	bk.global_transform = ind.global_transform
	_place(y4)


func _place(ny: float) -> void:
	var d := ny - y
	var P: Player = Game.player
	if d != 0.0 and P != null and not P.dead and P.x > x0 and P.x < x1 and P.z > z0 and P.z < z1 and absf(P.y - y) < 0.6:      # (riding: carried with the floor)
		P.y += d
		if P.vy < 0.0:
			P.vy = 0.0
	y = ny
	car.position.y = ny
	for q: Dictionary in sol:
		(q.s as World.Solid).set_span(ny + float(q.b), ny + float(q.t))


## is P standing in the car?
func in_car(P: Player) -> bool:
	return P != null and P.x > x0 + 0.3 and P.x < x1 - 0.3 and P.z > z0 + 0.3 and P.z < z1 - 0.3 and absf(P.y - y) < 0.8


## checkpoint: 'locked' (parked on 4F, the lockdown holding it), 'open3' (waiting on 3F, doors open), 'top' (arrived on 4F)
func reset(st: String = "locked") -> void:
	state = st
	t = 0.0
	door_k = 1.0 if st == "open3" else 0.0
	_place(y3 if st == "open3" else y4)


## the tier desk's override: it starts down
func call_down() -> void:
	if state != "locked":
		return
	state = "down"
	t = 0.0
	audio.tone(70.0, 1.2, 0.2, &"sawtooth")
	audio.thud(0.5)


## X in the car on 3F: the doors shut and up it goes
func ride() -> void:
	if state != "open3":
		return
	state = "closing"
	t = 0.0
	audio.tone(660.0, 0.25, 0.1, &"sine")


func update(dt: float) -> void:
	t += dt
	var F: Dictionary = admin.floors
	if state == "down":
		_place(maxf(y3, y - DOWN * dt))
		if y <= y3:
			state = "opening"
			t = 0.0
			audio.tone(880.0, 0.3, 0.12, &"sine")
			lv.get_tree().create_timer(0.26).timeout.connect(func() -> void: audio.tone(660.0, 0.4, 0.12, &"sine"))
	elif state == "opening":
		door_k = minf(1.0, door_k + dt / 1.4)
		if door_k >= 1.0:
			state = "open3"
	elif state == "closing":
		var P: Player = Game.player
		var aboard := P != null and P.x > x0 and P.x < x1 and P.z > z0 and P.z < z1 and absf(P.y - y) < 0.8
		if not aboard:      # (stepped out: the doors open again; it never leaves without him)
			state = "opening"
		else:
			door_k = maxf(0.0, door_k - dt / 1.2)
			if door_k <= 0.0:
				state = "up"
				t = 0.0
				audio.thud(0.4)
	elif state == "up":
		var u := minf(1.0, t * UP / (y4 - y3))
		_place(y3 + (y4 - y3) * (u * u * (3.0 - 2.0 * u)))
		if u >= 1.0:
			state = "top"
			audio.tone(880.0, 0.3, 0.12, &"sine")
	if state == "down" or state == "up":
		hum_t -= dt
		if hum_t <= 0.0:
			hum_t = 0.5
			audio.tone(48.0, 0.55, 0.045, &"sawtooth")
	for q: Dictionary in leaves:
		(q.m as Node3D).position.z = dz + float(q.k) * dw / 4.0 * (1.0 + 2.0 * door_k * 0.98)
	if shut != null:
		shut.set_off(door_k > 0.6)
	var f3: Node3D = F[&"f3"]
	var f4: Node3D = F[&"f4"]
	car.visible = f3.visible or f4.visible or (feeds_live.is_valid() and feeds_live.call())
	# the lamp: LOCKED on 4F while the lockdown holds it; the floor and the arrow on the way
	if f3.visible:
		var fl := "4" if y > y4 - 0.5 else ("3" if y < y3 + 0.5 else "v")
		var locked := state == "locked"
		var txt := "LOCK 4" if locked else ("^" if state == "up" else fl)
		var col := ("#ff3020" if int(floor(t * 2.0)) % 2 == 1 else "#701008") if locked else "#ffb030"
		if txt + col != ind_shown:
			ind_shown = txt + col
			ind_text.text = txt
			ind_text.modulate = Color(col)
