class_name WhViews
extends Node
## The warehouse's moving looks (JS architecture.js update, entrances.js, workstations.js, factory-drives.js, door-boards.js, lockdown-view.js, foreman-model.js): every part the JS moves is found by its .name in the export and moved here; the rules that live in those files (a passage through a shutter, standing at a console) come along.

const X_AXIS := Vector3(1.0, 0.0, 0.0)
const Y_AXIS := Vector3(0.0, 1.0, 0.0)
const Z_AXIS := Vector3(0.0, 0.0, 1.0)
const STAGE_ORDER := WhDirector.STAGE_ORDER
const BOARD_ROWS := {"racks": ["rackRelayA", "rackRelayB", "clear"], "sorting": ["sortRelayA", "sortRelayB", "clear"], "security": ["reserveA", "reserveB", "clear"], "reclamation": ["cageA", "cageB", "clear"], "vault": ["clampA", "clampB", "clear", "cartridge"]}
const BOARD_GATE := {"racks": "racks", "sorting": "sorting", "security": "security", "reclamation": "reclamation"}
const ENTRANCE_START := 0.35

var L: WarehouseLevel
var mats: Dictionary = {}              # material resource name -> material
var solids_view: Dictionary = {}       # solid -> [{node, mode}]
var attached: Array[Dictionary] = []   # {node, solid}
var bulkheads: Array[Dictionary] = []
var requested: Dictionary = {}         # gate solid -> bool
var bridge_requested := false
var bridge_amount := 0.0
var slag_box := {"live": false, "x0": 0.0, "x1": 0.0, "cz": 0.0, "hz": 1.0, "bottom": 0.0, "top": 0.0}
var doors: Dictionary = {}             # "stage/i" -> door
var arrivals: Array[Dictionary] = []
var models: Dictionary = {}            # control id -> console parts
var interaction: Variant = null
var boards: Dictionary = {}
var leaves: Array[Node3D] = []
var lockdown_panels: Array[Dictionary] = []
var lockdown_amount := 0.0
var lockdown_locked := false
var rollers: Array[Dictionary] = []
var parcels: Array[Dictionary] = []
var latches: Array[Dictionary] = []
var rotors: Array[Node3D] = []
var dial_hands: Array[Node3D] = []
var drives: Array[Dictionary] = []
var shaft: Node3D
var press_rod: Node3D
var press_warning: Node3D
var carriage: Node3D
var ram: Node3D
var piston: World.Solid
var press: World.Solid
var bridge_view: Node3D
var bridge_rods: Array[Dictionary] = []
var fm: Dictionary = {}                # Foreman parts
var fm_solid_body: World.Solid
var fm_solid_feet: Array[World.Solid] = []
var wheel_angle := 0.0
var fm_last_time := NAN
var exterior: Array[Node3D] = []
var mission: WhMissionHud
var guidance: WhGuidance
var props: WhSetpieceViews
var roof_door: MinigameDoor = null
var wrappers: Array[Dictionary] = []
var rooms: Dictionary = {}
var _vis_stage := ""
const SHOWN := {"roof": ["roof"], "racks": ["dispatch", "sorting"], "sorting": ["sorting", "dispatch", "freight"], "freight": ["freight", "sorting"], "transfer": ["handling"], "security": ["reserve"], "reclamation": ["reclamation"], "vault": ["vault"], "escape": ["vault", "apron"], "finale": ["apron"]}
var _pool_timer := 0.0


func _init(level: WarehouseLevel) -> void:
	L = level


func _node(nm: String) -> Node3D:
	var a: Array = L.node_named(nm)
	return a[0] if a.size() > 0 else null


func _ready() -> void:
	_collect_materials()
	_build_solids()
	_build_doors()
	_build_consoles()
	_build_drives()
	_build_boards()
	_build_foreman()
	_build_lockdown()
	mission = WhMissionHud.new()
	add_child(mission)
	props = WhSetpieceViews.new(L)
	add_child(props)
	slag_box = props.slag_box
	guidance = WhGuidance.new(L)
	add_child(guidance)


func leave() -> void:
	if mission != null:
		mission.queue_free()


func _collect_materials() -> void:
	var walk: Array[Node] = [L]
	while walk.size() > 0:
		var n: Node = walk.pop_back()
		if n is MeshInstance3D:
			var m: Mesh = (n as MeshInstance3D).mesh
			if m != null:
				for s in m.get_surface_count():
					var mt: Material = m.surface_get_material(s)
					if mt != null and mt.resource_name != "":
						mats[mt.resource_name.rstrip("0123456789").trim_suffix("_")] = mt
		walk.append_array(n.get_children())


func _mat(prefix: String) -> StandardMaterial3D:
	return mats.get(prefix) as StandardMaterial3D


## JS: dynamic meshes that stand for a solid; groups attached to one; the machine details riding them
func _build_solids() -> void:
	for k: String in L.by_name.keys():
		if k.begins_with("WhSolid_"):
			var s := L.solid(int(k.substr(8)))
			if s != null:
				var n: Node3D = L.node_named(k)[0]
				var parts: Array = solids_view.get(s, [])
				parts.append({"node": n, "kind": "box"})
				solids_view[s] = parts
		elif k.begins_with("WhAttach_"):
			var s := L.solid(int(k.get_slice("_", 1)))
			if s != null:
				attached.append({"node": L.node_named(k)[0], "solid": s})
		elif k.begins_with("WhRoller_"):
			rollers.append({"node": L.node_named(k)[0], "router": k.get_slice("_", 2), "angle": 0.0})
		elif k.begins_with("WhParcel_"):
			parcels.append({"node": L.node_named(k)[0], "router": k.get_slice("_", 2), "len": float(k.get_slice("_", 3)), "position": float(k.get_slice("_", 4))})
		elif k.begins_with("WhLatch_"):
			latches.append({"node": L.node_named(k)[0], "id": k.get_slice("_", 1), "side": float(k.get_slice("_", 2))})
		elif k.begins_with("WhRotor_"):
			rotors.append(L.node_named(k)[0])
		elif k.begins_with("WhDialHand_"):
			dial_hands.append(L.node_named(k)[0])
	for stage: String in WhData.GATES:
		var s := L.solid(int(WhData.GATES[stage]))
		var parts: Array = solids_view.get(s, [])
		if parts.is_empty():
			continue
		var down := s.top < -0.0 and false
		requested[s] = s.off
		bulkheads.append({"solid": s, "node": parts[0].node, "base": (s.top + s.bottom) / 2.0, "bottom": s.bottom, "top": s.top, "travel": (s.top - s.bottom + 0.6) * (-1.0 if down else 1.0), "amount": 1.0 if s.off else 0.0})
	shaft = _node("WhShaft")
	press_rod = _node("WhPressRod")
	press_warning = _node("WhPressWarning")
	for m: Dictionary in L.movers:
		if m.id == "cargo piston lift":
			piston = m.s
		elif m.id == "cargo press":
			press = m.s
	# the outdoor set (JS exterior.group): hidden while the rooms are all there is to see
	exterior.assign(L.node_named("Warehouse / rainy city waterfront"))
	# JS visibility.js: outdoor views skip enclosed factory rooms while preserving each object's animated visibility. The wrappers keep the state they were exported in, so they are sorted here by what they hold.
	var roof_box := AABB(Vector3(-36.0, 11.0, -52.0), Vector3(117.0, 31.0, 79.0))
	var dock_box := AABB(Vector3(240.0, -6.0, 144.0), Vector3(85.0, 56.0, 88.0))
	for w: Node3D in L.node_named("Warehouse / outdoor visibility"):
		var b := _bounds_of(w)
		if b.size == Vector3.ZERO:
			wrappers.append({"n": w, "roof": true, "dock": true})
		else:
			wrappers.append({"n": w, "roof": b.intersects(roof_box), "dock": b.intersects(dock_box)})
	for room: String in ["roof", "dispatch", "sorting", "freight", "handling", "reserve", "reclamation", "vault", "apron"]:
		var a: Array = L.node_named("Warehouse dressing / " + room)
		if a.size() > 0:
			rooms[room] = a[0]


## World bounds of the meshes under a node (they are all still at their build pose at load)
func _bounds_of(n: Node) -> AABB:
	var out := AABB()
	var any := false
	var walk: Array[Node] = [n]
	while walk.size() > 0:
		var c: Node = walk.pop_back()
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			var a := mi.global_transform * mi.get_aabb()
			out = out.merge(a) if any else a
			any = true
		walk.append_array(c.get_children())
	return out


func _update_visibility(stage: String) -> void:
	if stage == _vis_stage:
		return
	_vis_stage = stage
	for e: Dictionary in wrappers:
		(e.n as Node3D).visible = e.roof if stage == "roof" else (e.dock if stage == "finale" else true)
	var on: Array = SHOWN.get(stage, [])
	for k: String in rooms:
		(rooms[k] as Node3D).visible = on.has(k)


func solid_moved(s: World.Solid) -> void:
	var parts: Array = solids_view.get(s, [])
	for p: Dictionary in parts:
		(p.node as Node3D).position = Vector3(s.cx, (s.top + s.bottom) / 2.0, s.cz)


func lift_moved(s: World.Solid) -> void:
	var parts: Array = solids_view.get(s, [])
	for p: Dictionary in parts:
		(p.node as Node3D).position = Vector3(s.cx, s.top - 0.285, s.cz)
	if models.has("lift"):
		var c: Dictionary = models["lift"]
		var g: Node3D = c.g
		g.position = Vector3(s.cx - 0.98, s.top, s.cz + 0.2)
		var col: World.Solid = c.get("collision")
		if col != null:
			col.place(g.position.x, g.position.z)
			col.set_span(s.top, s.top + 1.42)


func gate_request(s: World.Solid, open: bool) -> void:
	if s != null:
		requested[s] = open


func exterior_visible(on: bool) -> void:
	for n: Node3D in exterior:
		n.visible = on


func mission_card(plan: Variant) -> void:
	if mission != null and plan != null:
		mission.card(plan)


# ---- the roof door (JS addMinigameDoor): the way into Dispatch starts sealed: a giant door whose panel runs a minigame (WhData.TUNING.roofDoor sets which one and how hard) ----
func roof_door_locked() -> bool:
	return roof_door.locked


func roof_door_target() -> Dictionary:
	return roof_door.target


func roof_door_reset() -> void:
	roof_door.reset()


func roof_door_update(dt: float, P: Player) -> void:
	roof_door.update(dt, P)


# ---- the shutters a wave comes through (JS entrances.js) ----
func _build_doors() -> void:
	var all: Dictionary = WhData.FACTORY_ENTRANCES
	for stage: String in all:
		var list: Array = all[stage]
		for i in list.size():
			var e: Dictionary = list[i]
			var key := "%s/%d" % [stage, i]
			var gate: World.Solid = null
			var want := "deployment %s shutter" % key
			for s: World.Solid in L.world.solids:
				if s.data.get("id", "") == want:
					gate = s
					break
			var front := float(e.length) - 1.7
			doors[key] = {"e": e, "shutter": _node("WhShutter_%s_%d" % [stage, i]), "roller": _node("WhDoorRoller_%s_%d" % [stage, i]), "lamp": _mat("whDoorLamp_%s_%d" % [stage, i]), "gate": gate, "reveal": front - 0.1, "until": -1.0, "amount": 0.0, "last_open": false}


func _find_door(stage: String, index: int) -> Variant:
	var list: Array = WhData.FACTORY_ENTRANCES.get(stage, [])
	if list.is_empty():
		return null
	return doors.get("%s/%d" % [stage, posmod(index, list.size())])


static func _entrance_point(e: Dictionary, distance: float, lane: float = 0.0) -> Dictionary:
	return {"x": float(e.x) + float(e.nx) * distance + float(e.nz) * lane, "y": float(e.y), "z": float(e.z) + float(e.nz) * distance - float(e.nx) * lane, "yaw": atan2(float(e.nx), float(e.nz))}


func entrance_point(stage: String, index: int) -> Variant:
	var d: Variant = _find_door(stage, index)
	return _entrance_point(d.e, float(d.e.length)) if d != null else null


func announce(stage: String, index: int, time: float) -> void:
	var d: Variant = _find_door(stage, index)
	if d != null:
		d.until = time + 6.0


func reset_for_stage() -> void:
	arrivals.clear()
	for d: Dictionary in doors.values():
		d.until = -1.0
		d.amount = 0.0
		if d.shutter != null:
			(d.shutter as Node3D).position.y = 0.0
		var g: World.Solid = d.gate
		if g != null:
			g.set_off(false)
			g.set_span(float(d.e.y), float(d.e.y) + 4.8)
	for r: Dictionary in drives:
		r.last = NAN
		r.speed = 0.0


func request_passage(stage: String, index: int, time: float, kind: String, P: Player, actors: Array[Robot]) -> Variant:
	var d: Variant = _find_door(stage, index)
	if d == null:
		return null
	d.until = maxf(float(d.until), time + 2.5)
	if float(d.amount) < 0.84:
		return null
	var e: Dictionary = d.e
	var h := 3.28 if kind == "mech" else (2.665 if kind == "guard" else (0.48 if kind == "spider" else 2.05))
	var r := 0.9 if kind == "mech" else (0.72 if kind == "guard" else 0.6)
	var ey := float(e.y)
	for lane: float in [0.0, -1.45, 1.45]:
		var start := _entrance_point(e, ENTRANCE_START, lane)
		var end_ := _entrance_point(e, float(e.length), lane)
		if U.hyp(P.x - float(end_.x), P.z - float(end_.z)) < 4.0 and absf(P.y - ey) < 4.0:
			continue
		var busy := false
		for a: Robot in actors:
			if not a.dead and absf(a.y - ey) < 3.0 and U.hyp(a.x - float(start.x), a.z - float(start.z)) < r + 1.0:
				busy = true
				break
		if busy:
			continue
		var clear := true
		for ti in 11:
			var t := ti * 0.1
			var x := lerpf(start.x, end_.x, t)
			var z := lerpf(start.z, end_.z, t)
			var y: float = ey if e.get("air", false) else L.world.ground_height(x, z, r, ey + 0.5)
			if not is_finite(y) or absf(y - ey) > 0.6 or L.world.blocked(x, z, y, h, r, 0.1):
				clear = false
				break
			for a: Robot in actors:
				if not a.dead and a.get(&"factory_arrival") != true and absf(a.y - y) < 3.0 and U.hyp(a.x - x, a.z - z) < r + 0.7:
					clear = false
					break
			if not clear:
				break
		if clear:
			return {"start": start, "end": end_, "door": d, "height": h, "radius": r}
	return null


## AI, firing and drone height corrections resume only after the complete walk / flight out of the alcove. The actor remains a normal damageable target.
func dispatch(actor: Variant, passage: Dictionary) -> void:
	arrivals.append({"actor": actor, "passage": passage, "progress": 0.0})
	actor.factory_arrival = true
	actor.arrival_nx = float(passage.door.e.nx)
	actor.arrival_nz = float(passage.door.e.nz)


func _update_doors(dt: float, time: float, P: Player) -> void:
	var busy := {}
	for a: Dictionary in arrivals:
		if not a.actor.dead:
			busy[a.passage.door] = true
	for d: Dictionary in doors.values():
		var open: bool = time < float(d.until) or busy.has(d)
		if open != d.last_open and dt > 0.0:
			d.last_open = open
		d.amount = U.damp(float(d.amount), 1.0 if open else 0.0, 6.0, dt)
		var am: float = d.amount
		if d.shutter != null:
			(d.shutter as Node3D).position.y = am * 5.0
		if d.roller != null:
			(d.roller as Node3D).rotation.x = am * 12.0
		var g: World.Solid = d.gate
		if g != null:
			var want_off := am > 0.995
			if am > 0.0005 or not g.off:
				g.set_span(float(d.e.y) + am * 5.0, float(d.e.y) + 4.8 + am * 5.0)
			g.set_off(want_off)
		var lm: StandardMaterial3D = d.lamp
		if lm != null:
			lm.albedo_color = Color.hex((0xffb34aff if sin(time * 8.0) > 0.0 else 0x88502cff) if open else 0x60939aff)
	var i := arrivals.size() - 1
	while i >= 0:
		var a: Dictionary = arrivals[i]
		var r: Variant = a.actor
		var p: Dictionary = a.passage
		if r.dead:
			r.factory_arrival = false
			arrivals.remove_at(i)
			i -= 1
			continue
		var st: Dictionary = p.start
		var en: Dictionary = p.end
		var length := U.hyp(float(en.x) - float(st.x), float(en.z) - float(st.z))
		var is_drone: bool = r.drone
		var step := dt * (3.6 if is_drone else 2.8) / length
		var next := minf(1.0, float(a.progress) + step)
		var x := lerpf(st.x, en.x, next)
		var z := lerpf(st.z, en.z, next)
		var y: float = float(st.y) if p.door.e.get("air", false) else L.world.ground_height(x, z, p.radius, float(st.y) + 0.5)
		# A player can interrupt an arrival by standing in its path; the gate remains open, and the actor never teleports through the player.
		var blocked := false
		for o: Robot in Game.combat.enemies.robots:
			if o != r and not o.dead and absf(o.y - y) < 3.0 and U.hyp(o.x - x, o.z - z) < float(p.radius) + o.r + 0.15:
				blocked = true
				break
		r.factory_arrival_speed = 0.0
		if not blocked and (absf(P.y - y) > 3.0 or U.hyp(P.x - x, P.z - z) > float(p.radius) + 0.7):
			a.progress = next
			r.x = x
			r.z = z
			r.y = y + (1.4 if is_drone else 0.0)
			r.yaw = st.yaw
			if is_drone:
				r.vy = 0.0
			r.factory_arrival_speed = 3.6 if is_drone else 2.8
		if float(a.progress) >= 1.0:
			r.factory_arrival = false
			r.hx = en.x
			r.hz = en.z
			r.hy = en.y
			r.patrol = PackedVector2Array([Vector2(en.x, en.z)])
			r.vx = 0.0
			r.vz = 0.0
			r.lvz = 0.0
			r.lvx = 0.0
			r.set_(&"alert")
			arrivals.remove_at(i)
		i -= 1


# ---- the consoles (JS workstations.js) ----
func _build_consoles() -> void:
	for c: Dictionary in L.director.controls:
		var id: String = c.id
		var g := _node("WhControl_" + id)
		if g == null:
			continue
		var segs: Array[Node3D] = []
		for i in 5:
			var s := _node("WhSeg_%s_%d" % [id, i])
			if s != null:
				segs.append(s)
		var col: World.Solid = null
		for s: World.Solid in L.world.solids:
			if s.data.get("id", "") == "control cabinet " + id:
				col = s
				break
		models[id] = {"g": g, "control": c, "lever": _node("WhLever_" + id), "button": _node("WhButton_" + id), "display": _node("WhDisplay_" + id), "lamp": _mat("whLamp_" + id), "beacon": _node("WhBeacon_" + id), "status_ready": _node("WhStatus_%s_ready" % id), "status_done": _node("WhStatus_%s_done" % id), "status_waiting": _node("WhStatus_%s_waiting" % id), "segments": segs, "scan": _node("WhScan_" + id), "burst": _node("WhBurst_" + id), "burst_mat": _mat("whBurst_" + id), "mechanism": _node("WhMech_" + id), "canister": _node("WhCanister_" + id), "response": _node("WhResponse_" + id), "collision": col, "amount": 0.0, "kick": 0.0, "was_done": null, "lever_x": 0.0, "button_z": -0.3, "y": float(c.y)}


func _target_for(c: Dictionary) -> Dictionary:
	var m: Variant = models.get(c.id)
	if m == null:
		return {"stance": Vector3(float(c.x), float(c.y), float(c.z) + 0.65), "target": Vector3(float(c.x), float(c.y) + 1.15, float(c.z) + 1.12), "kind": "board"}
	var g: Node3D = m.g
	if m.canister != null:
		var t: Vector3 = (m.canister as Node3D).global_position + Vector3(0.0, 0.48, 0.0)
		return {"stance": Vector3(t.x, g.global_position.y, t.z - 0.58), "target": t, "kind": "grab"}
	var bt: Vector3 = (m.button as Node3D).global_position if m.button != null else g.global_position + Vector3(0.0, 1.1, 0.0)
	var st := g.to_global(Vector3(0.19, 0.0, -0.72))      # in front of the button, whichever way the cabinet faces
	return {"stance": Vector3(st.x, g.global_position.y, st.z), "target": bt, "kind": "press"}


## JS kit/control-approach.js: a short, collision-checked settling step before a hold operation. Walking / jumping cancels immediately; this never teleports or locks the player into a cutscene.
func prepare_control(c: Dictionary, P: Player, dt: float) -> bool:
	var moving: bool = Inp.move.mag > 0.15 or Inp.btn(&"jump").pressed or Inp.btn(&"fire").held
	var t := _target_for(c)
	if moving:
		interaction = null
		return false
	interaction = {"id": c.id, "target": t.target, "kind": t.kind}
	var m: Variant = models.get(c.id)
	var ry: float = (m.g as Node3D).rotation.y if m != null else 0.0
	return _approach(P, t.stance, t.target, dt, Vector2(-sin(ry), -cos(ry)))


func _approach(P: Player, stance: Vector3, target: Vector3, dt: float, face: Vector2) -> bool:
	if P.dead or not P.grounded or P.mode != &"normal":
		return false
	var dx := stance.x - P.x
	var dz := stance.z - P.z
	if U.hyp(dx, dz) > 2.4:
		return false
	# Clear the projecting cabinet corner before sidestepping across its face.
	var n := dx * face.x + dz * face.y
	var sx := n * face.x if absf(n) > 0.025 else dx
	var sz := n * face.y if absf(n) > 0.025 else dz
	var k := minf(1.0, dt * 3.0 / maxf(0.001, U.hyp(sx, sz)))
	var x := P.x + sx * k
	var z := P.z + sz * k
	var y := L.world.ground_height(x, z, P.r, P.y + 0.42)
	if not is_finite(y) or absf(y - P.y) > 0.35 or L.world.blocked(x, z, y, P.h, P.r, 0.1):
		return false
	P.x = x
	P.z = z
	P.y = y
	P.vx = 0.0
	P.vz = 0.0
	var yaw := atan2(target.x - P.x, target.z - P.z)
	var turn := U.wrap_angle(yaw - P.yaw)
	P.yaw += turn * minf(1.0, dt * 16.0)
	return U.hyp(stance.x - P.x, stance.z - P.z) < 0.12 and absf(turn) < 0.18


func _update_consoles(dt: float, state: Dictionary, P: Player) -> void:
	var flags: Dictionary = state.flags
	var near_id: String = L.hud_state.get("near_id", "")
	var hold: float = L.hud_state.get("progress", 0.0)
	var held: bool = Inp.btn(&"b").held
	var time: float = state.time
	var stage_now: int = STAGE_ORDER.find(state.stage)
	for id: String in models:
		var p: Dictionary = models[id]
		var ctl: Dictionary = p.control
		var done: bool = flags.get(id, false) or (id == "foreman" and flags.get("bossStarted", false)) or STAGE_ORDER.find(ctl.stage) < stage_now
		var ready: bool = not done and L.director.available(ctl)
		p.amount = U.damp(float(p.amount), 1.0 if done else 0.0, 12.0, dt)
		# Quick feedback: the lever pulls in and the cabinet trembles while held; on completion the lever slams, the body punches in and the lamp flashes.
		var holding: bool = near_id == id and held and not done and interaction != null and interaction.id == id
		if done and p.was_done == false:
			p.kick = 1.0
		p.was_done = done
		p.kick = maxf(0.0, float(p.kick) - dt * 4.0)
		var kk: float = p.kick
		var shake := sin(time * 42.0) * 0.006 * hold if holding else 0.0
		var pr := smoothstep(0.0, 1.0, hold)
		var g: Node3D = p.g
		if p.lever != null:
			p.lever_x = U.damp(float(p.lever_x), -float(p.amount) * 1.1 - (pr * 0.65 if holding else 0.0) + sin(kk * PI) * 0.35, 18.0, dt)
			(p.lever as Node3D).rotation.x = p.lever_x
		g.scale = Vector3(1.0 + kk * 0.025, 1.0 - kk * 0.02, 1.0 + kk * 0.025)
		if id != "lift":
			g.position.y = float(p.y) + shake
		if p.button != null:
			p.button_z = U.damp(float(p.button_z), -0.3 + (0.055 * pr if holding else (0.025 if done else 0.0)), 22.0, dt)
			(p.button as Node3D).position.z = p.button_z
		var pulse := 0.4 + 0.6 * (0.5 + 0.5 * sin(time * PI * 2.4))
		var lm: StandardMaterial3D = p.lamp
		if lm != null:
			var col := Color.hex(0xffffffff if kk > 0.6 else (0x80e3b6ff if done else (0xffbc55ff if ready else 0x425459ff)))
			if ready and not holding:
				col = Color(col.r * pulse, col.g * pulse, col.b * pulse)
			lm.albedo_color = col
		if p.status_ready != null:
			(p.status_ready as Node3D).visible = ready
			(p.status_done as Node3D).visible = done
			(p.status_waiting as Node3D).visible = not ready and not done
		if p.beacon != null:
			(p.beacon as Node3D).scale.y = 0.16 + (0.06 * pr if holding else 0.0)
		if p.scan != null:
			(p.scan as Node3D).visible = ready
			(p.scan as Node3D).position.x = sin(time * 2.8) * 0.185
		var segs: Array = p.segments
		for i in segs.size():
			(segs[i] as Node3D).visible = done or (ready and (not holding or hold > i / 5.0))
		if p.burst != null:
			(p.burst as Node3D).visible = kk > 0.0
			var bs := 1.0 + (1.0 - kk) * 2.6
			(p.burst as Node3D).scale = Vector3(bs, bs, bs)
			if p.burst_mat != null:
				(p.burst_mat as StandardMaterial3D).albedo_color.a = kk * 0.65
		if p.display != null:
			(p.display as Node3D).scale.x = 0.4 * (maxf(0.08, hold) if near_id == id and not done else 1.0)
		if p.response != null:
			var rs: Node3D = p.response
			if id.begins_with("reserve"):
				rs.rotation.x = float(p.amount) * 1.15
			elif id.begins_with("freight"):
				rs.position.y = 0.68 - float(p.amount) * 0.25
			else:
				rs.rotation.z = float(p.amount) * PI / 2.0
		if p.mechanism != null:
			var me: Node3D = p.mechanism
			if id.begins_with("clamp"):
				me.rotation.z = (-1.0 if id == "clampA" else 1.0) * float(p.amount) * 0.85
			else:
				me.position.y = float(ctl.y) + 1.8 + float(p.amount) * 1.1
		if p.canister != null:
			var ca: Node3D = p.canister
			ca.visible = not done
			ca.position.y = 0.75 + (smoothstep(0.0, 1.0, hold) * 0.35 if holding else 0.0)
	# the operator's pose (the animator reads it)
	var active: bool = near_id != "" and held and interaction != null and interaction.id == near_id and not P.dead and P.grounded
	var cur: Player.FactoryInteraction = P.factory_interaction if P.factory_interaction != null else Player.FactoryInteraction.new()
	cur.weight = U.damp(cur.weight, 1.0 if active else 0.0, 14.0 if active else 10.0, dt)
	if active:
		cur.target = interaction.target
		cur.active = true
	else:
		cur.active = false
		interaction = null
	P.factory_interaction = cur if cur.weight > 0.002 else null


# ---- the drives (JS factory-drives.js, drive-plans.js) ----
func _build_drives() -> void:
	for m: Dictionary in L.movers:
		var s: World.Solid = m.s
		var sid := L.world.solids.find(s)
		var id: String = m.id
		var type := "overhead-hoist" if id == "cargo crane shuttle" else ("hydraulic-press" if m.get("hazard", false) else ("hydraulic-lift" if m.axis == "y" else "rack-carriage"))
		var st: String = m.get("stage", "")
		var base_y: float = -12.8 if id == "cargo piston lift" else (-15.8 if st == "security" else (-21.8 if st == "reclamation" else (-2.8 if st == "finale" else s.bottom - 2.0)))
		drives.append({"m": m, "s": s, "type": type, "axis": m.axis, "from": float(m.from), "slope": float(m.get("slope", 0.0)), "base_y": base_y, "g": _node("WhDrive_%d" % sid), "trolley": _node("WhTrolley_%d" % sid), "rod": _node("WhRod_%d" % sid), "bearing": _node("WhBearing_%d" % sid), "motor": _node("WhMotor_%d" % sid), "cap": _node("WhCap_%d" % sid), "last": NAN, "speed": 0.0})
	carriage = _node("WhCarriage")
	ram = _node("WhLiftRam")
	var parts: Array = solids_view.get(L.dock_bridge, [])
	bridge_view = parts[0].node if parts.size() > 0 else null
	bridge_amount = 0.0 if L.dock_bridge.off else 1.0
	var i := 0
	while _node("WhBridgeRod_%d" % i) != null:
		var z: float = L.dock_bridge.cz + (-1.0 if i == 0 else 1.0) * (L.dock_bridge.hz - 0.6)
		bridge_rods.append({"rod": _node("WhBridgeRod_%d" % i), "z": z})
		i += 1


static func _link(n: Node3D, a: Vector3, b: Vector3, r: float) -> void:
	if n == null:
		return
	var d := b - a
	var L2 := maxf(0.001, d.length())
	n.transform = Transform3D(Basis(Quaternion(Y_AXIS, d / L2)).scaled_local(Vector3(r, L2, r)), (a + b) * 0.5)


func _drive_endpoints(d: Dictionary) -> Array[Vector3]:
	var s: World.Solid = d.s
	match d.type:
		"hydraulic-press":
			return [Vector3(s.cx, 10.0, s.cz), Vector3(s.cx, s.top, s.cz)]
		"hydraulic-lift":
			return [Vector3(s.cx, float(d.base_y), s.cz), Vector3(s.cx, s.top - 0.35, s.cz)]
		"overhead-hoist":
			return [Vector3(s.cx, 9.0, s.cz + 2.5), Vector3(s.cx, s.top - 0.4, s.cz + 2.5)]
	var along_x: bool = d.axis == "x"
	var position := s.cx if along_x else s.cz
	var y := s.top - 1.05
	var from: float = d.from
	return [Vector3(from - 1.5 if along_x else s.cx, y - (position - from + 1.5) * float(d.slope), s.cz if along_x else from - 1.5), Vector3(s.cx, y, s.cz)]


func _update_drives(dt: float) -> void:
	for d: Dictionary in drives:
		var s: World.Solid = d.s
		if d.g != null:
			(d.g as Node3D).position = Vector3(s.cx, s.top, s.cz)
		if d.trolley != null:
			(d.trolley as Node3D).position = Vector3(s.cx, 0.0, s.cz)
		var e := _drive_endpoints(d)
		_link(d.rod, e[0], e[1], 0.035 if d.type == "overhead-hoist" else 0.13)
		if d.bearing != null:
			(d.bearing as Node3D).position = e[0]
		if d.motor != null:
			(d.motor as Node3D).position = e[0] + Vector3(0.4, -0.2, 0.5)
		if d.cap != null:
			(d.cap as Node3D).position = e[0] + Vector3(0.4, -0.2, 1.15)
	var lift := L.lift
	if carriage != null:
		carriage.position = Vector3(lift.cx, lift.top, lift.cz)
	_link(ram, Vector3(0.0, -9.0, 0.0), Vector3(0.0, lift.top - 1.2 if lift.cx < 0.01 else -5.7, 0.0), 0.42)
	# The return bridge raises from beneath the near bank on two hydraulic arms. Its interlock becomes walkable only after the deck is seated flat.
	var br := L.dock_bridge
	bridge_amount = U.damp(bridge_amount, 1.0 if bridge_requested else 0.0, 6.0, dt)
	var angle := -(1.0 - bridge_amount) * PI / 2.0
	var hinge_x := br.cx - br.hx
	var width := br.hx * 2.0
	if bridge_view != null:
		bridge_view.visible = true
		bridge_view.transform = Transform3D(Basis(Z_AXIS, angle).scaled_local(Vector3(width, br.top - br.bottom, br.hz * 2.0)), Vector3(hinge_x + cos(angle) * width / 2.0, -0.3 + sin(angle) * width / 2.0, br.cz))
	br.set_off(bridge_amount < 0.995)
	var lamp := _mat("whBridgeLamp")
	if lamp != null:
		lamp.albedo_color = Color.hex(0xffb348ff if br.off else 0x75e6c0ff)
	for p: Dictionary in bridge_rods:
		_link(p.rod, Vector3(hinge_x - 1.4, -2.5, p.z), Vector3(hinge_x + cos(angle) * width * 0.8, -0.3 + sin(angle) * width * 0.8, p.z), 0.11)


func _update_architecture(dt: float, time: float, state: Dictionary) -> void:
	for a: Dictionary in attached:
		var s: World.Solid = a.solid
		(a.node as Node3D).position = Vector3(s.cx, s.top, s.cz)
	if shaft != null and piston != null:
		shaft.scale.y = piston.top + 13.0
		shaft.position.y = (-13.0 + piston.top) / 2.0
	if press_rod != null and press != null:
		press_rod.scale.y = 10.0 - press.top
		press_rod.position.y = (10.0 + press.top) / 2.0
		press_warning.visible = press.bottom < 1.7 or sin(time * 5.0) > 0.0
	var fl: Dictionary = state.flags
	var early: bool = state.stage == "roof" or state.stage == "racks" or state.stage == "sorting"
	for r: Dictionary in rollers:
		if not (fl.get(r.router, false) or not early):
			r.angle = float(r.angle) + dt * 1.5
		(r.node as Node3D).rotation.y = r.angle
	for p: Dictionary in parcels:
		if not (fl.get(p.router, false) or not early):
			p.position = float(p.position) + dt * 0.65
		(p.node as Node3D).position.x = fposmod(float(p.position) + float(p.len) / 2.0, float(p.len)) - float(p.len) / 2.0
	for p: Dictionary in latches:
		var n: Node3D = p.node
		n.rotation.z = U.damp(n.rotation.z, float(p.side) * 1.1 if state.stage == "freight" and fl.get(p.id, false) else 0.0, 5.0, dt)
	# A motorised shutter stays solid at its animated height. Clearance never grants passage through a visibly closed slab, even during the first frame.
	for d: Dictionary in bulkheads:
		var s: World.Solid = d.solid
		var target: bool = requested.get(s, s.off)
		d.amount = U.damp(float(d.amount), 1.0 if target else 0.0, 5.0, dt)
		var rise: float = float(d.amount) * float(d.travel)
		var n: Node3D = d.node
		n.position.y = float(d.base) + rise
		n.visible = true
		s.set_span(float(d.bottom) + rise, float(d.top) + rise)
		s.set_off(float(d.amount) > 0.995)
	for r: Node3D in rotors:
		r.rotation.z = time * 0.32
	for h: Node3D in dial_hands:
		h.rotation.z = -0.55 - time * 0.025


# ---- the boards ----
func _build_boards() -> void:
	for stage: String in BOARD_ROWS:
		var g := _node("WhBoard_" + stage)
		if g == null:
			continue
		var lamps: Array[Node3D] = []
		for i in (BOARD_ROWS[stage] as Array).size():
			lamps.append(_node("WhBoardLamp_%s_%d" % [stage, i]))
		var s: World.Solid = L.solid(int(WhData.GATES[BOARD_GATE[stage]])) if BOARD_GATE.has(stage) else null
		boards[stage] = {"g": g, "lamps": lamps, "beacon": _node("WhBoardBeacon_" + stage), "solid": s, "y0": g.position.y, "bottom0": s.bottom if s != null else 0.0, "ids": BOARD_ROWS[stage]}
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color.hex(0xff3a24ff)
	var green := StandardMaterial3D.new()
	green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	green.albedo_color = Color.hex(0x4dff88ff)
	mats["_red"] = red
	mats["_green"] = green


static func _mesh_child(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c: Node in n.get_children():
		if c is MeshInstance3D:
			return c
	return null


func _update_boards(state: Dictionary) -> void:
	for stage: String in boards:
		var b: Dictionary = boards[stage]
		var on: bool = stage == state.stage
		(b.g as Node3D).visible = on
		if not on:
			continue
		if b.solid != null:
			(b.g as Node3D).position.y = float(b.y0) + ((b.solid as World.Solid).bottom - float(b.bottom0))
		var open := true
		var ids: Array = b.ids
		for i in ids.size():
			var done: bool = state.flags.get("clearance" if ids[i] == "clear" else ids[i], false)
			var mi := _mesh_child(b.lamps[i])
			if mi != null:
				mi.material_override = mats["_green"] if done else mats["_red"]
			if not done:
				open = false
		var bm := _mesh_child(b.beacon)
		if bm != null:
			bm.material_override = mats["_green"] if open else mats["_red"]


# ---- the Foreman's lockdown (JS arena-lockdown.js, lockdown-view.js): real rising collision panels close the approach and cap the low dock walls ----
func _build_lockdown() -> void:
	for s: World.Solid in L.world.solids:
		if String(s.data.get("id", "")).begins_with("foreman lockdown"):
			lockdown_panels.append({"solid": s, "base": s.top, "bottom": s.bottom})
	var i := 0
	while _node("WhLeaf_%d" % i) != null:
		leaves.append(_node("WhLeaf_%d" % i))
		i += 1


func lockdown_update(dt: float, B: Dictionary, P: Player) -> void:
	var next: bool = B.mode == "intro" or B.mode == "fight" or B.mode == "transition" or B.mode == "dying"
	lockdown_locked = next
	var target := 1.0 if next else 0.0
	lockdown_amount += signf(target - lockdown_amount) * minf(absf(target - lockdown_amount), maxf(0.0, dt) / 0.9)
	for p: Dictionary in lockdown_panels:
		var s: World.Solid = p.solid
		var base: float = p.base
		var ntop := base + (12.0 - base) * lockdown_amount
		if ntop != s.top:
			s.set_span(s.bottom, ntop)
		s.set_off(lockdown_amount <= 0.001)
	# Close the activation-frame escape race without a hidden wall: put any actor crossing the rising perimeter back on the visible apron side.
	if next and not P.dead:
		var x := clampf(P.x, 267.0, 299.2)
		var z := clampf(P.z, 157.0, 211.0)
		if x != P.x:
			P.x = x
			P.vx = 0.0
			P.ix = 0.0
		if z != P.z:
			P.z = z
			P.vz = 0.0
			P.iz = 0.0
	for i in leaves.size():
		var leaf := leaves[i]
		var h := 12.0 - (0.0 if i < 7 else 4.0)      # (west leaves rise from the apron, the rest from the deck walls)
		leaf.position.y = h * lockdown_amount
		leaf.visible = lockdown_amount > 0.001


# ---- the Foreman (JS foreman-model.js, foreman-pose.js armJoints) ----
func _build_foreman() -> void:
	for nm: String in ["FmTorso", "FmWheel", "FmCore", "FmPupil", "The Foreman"]:
		fm[nm] = _node(nm)
	for s: float in [-1.0, 1.0]:
		var k := "%d" % int(s)
		for nm: String in ["FmShoulder_", "FmPod_", "FmJet_", "FmLid_", "FmFoot_", "FmLegU_", "FmLegL_", "FmLegH_", "FmKnee_", "FmArmU_", "FmArmL_", "FmArmR_", "FmElbow_", "FmHand_"]:
			fm[nm + k] = _node(nm + k)
	fm["waves"] = L.node_named("FmWave")
	fm["warns"] = L.node_named("FmWarn")
	fm["falling"] = L.node_named("FmFalling")
	for s: World.Solid in L.world.solids:
		var id: String = s.data.get("id", "")
		if id == "Foreman armored chassis":
			fm_solid_body = s
		elif id == "Foreman planted foot":
			fm_solid_feet.append(s)


static func _beam(n: Variant, a: Vector3, b: Vector3) -> void:
	if n == null:
		return
	var node: Node3D = n
	var d := b - a
	var len_ := maxf(0.001, d.length())
	var sc := node.scale
	sc.y = len_
	node.transform = Transform3D(Basis(Quaternion(Y_AXIS, d / len_)).scaled_local(sc), (a + b) * 0.5)


## JS armJoints: arm joints in boss-local space. The chassis (and the front flywheel) is a keep-out volume: hands are pushed clear of it and each elbow is lifted / forward until neither limb segment crosses it.
static func _inside(p: Vector3) -> bool:
	return absf(p.x) < 3.6 and p.z > -3.2 and p.z < 5.4 and p.y > 3.8 and p.y < 10.6


static func _seg_hits(a: Vector3, b: Vector3) -> bool:
	for i in 17:
		if _inside(a.lerp(b, i / 16.0)):
			return true
	return false


static func _arm_joints(side: float, pose: Dictionary) -> Array[Vector3]:
	var c: Vector3 = pose.press if side > 0.0 else pose.fork
	if (side > 0.0 or c.y > 3.8) and c.y < 10.5 and absf(c.x) < 5.0 and c.z > -4.6 and c.z < 6.4:
		var dx := 5.0 - absf(c.x)
		var dz := 6.4 - c.z
		if dx <= dz:
			c.x = (signf(c.x) if c.x != 0.0 else side) * 5.0
		else:
			c.z = 6.4
	var a := Vector3(side * 4.7, 8.1, 0.0)
	if side < 0.0:
		# Fixed 5.3 m links, with elbow bent away from the chassis. No telescoping.
		var d := c - a
		var ln := d.length()
		var u := d / ln
		var pv := Vector3(-1.0 + u.x * u.x, u.x * u.y, u.x * u.z).normalized()
		var bend := sqrt(maxf(0.0, 5.3 * 5.3 - ln * ln / 4.0))
		return [a, (a + c) * 0.5 + pv * bend, c]
	var b := (a + c) * 0.5 + Vector3(side * 1.1, 1.4, 0.0)
	for _k in 30:
		if not (_seg_hits(a, b) or _seg_hits(b, c)):
			break
		b.x = side * maxf(5.2, side * b.x)
		b.z += 0.8
		b.y += 0.45
	return [a, b, c]


func _update_foreman(time: float) -> void:
	var root: Node3D = fm.get("The Foreman")
	if root == null:
		return
	var boss := L.boss
	var B: Dictionary = boss.B
	var fall := WhForeman._smooth(float(B.mt) / 3.2) if B.mode == "dying" else (1.0 if B.dead else 0.0)
	var pose := boss.pose()
	var dt := 0.0 if is_nan(fm_last_time) else clampf(time - fm_last_time, 0.0, 0.1)
	fm_last_time = time
	root.position = Vector3(B.x, -fall * 3.4, B.z)
	root.rotation = Vector3(0.0, float(B.yaw), 0.0)
	var torso: Node3D = fm["FmTorso"]
	if torso == null:
		return
	torso.position.y = pose.bob
	torso.rotation = Vector3(float(pose.lean) + fall * 0.38, 0.0, 0.0)
	var ram_on: bool = B.mode == "fight" and B.move == "ram" and float(B.mt) >= float(boss.K.ram.warning)
	for sk: String in ["-1", "1"]:
		var side := float(sk)
		if fm["FmPod_" + sk] != null:
			(fm["FmPod_" + sk] as Node3D).rotation.x = -0.45 if B.move == "salvo" else 0.0
		if fm["FmShoulder_" + sk] != null:
			(fm["FmShoulder_" + sk] as Node3D).rotation.z = side * (0.12 + (int(B.phase) - 1) * 0.1)
		if fm["FmJet_" + sk] != null:
			(fm["FmJet_" + sk] as Node3D).visible = ram_on
	if fm_solid_body != null:
		fm_solid_body.place(B.x, B.z)
		fm_solid_body.set_off(B.dead)
		fm_solid_body.set_span(fm_solid_body.bottom, 9.5 + float(pose.bob) - fall * 3.4)
	wheel_angle += dt * (maxf(0.0, 1.0 - float(B.mt) / 3.2) if B.mode == "dying" else (0.0 if B.dead else (4.0 if B.exposed else float(B.phase))))
	if fm["FmWheel"] != null:
		(fm["FmWheel"] as Node3D).rotation.z = wheel_angle
	var aperture := boss.core_aperture()
	if fm["FmPupil"] != null:
		(fm["FmPupil"] as Node3D).rotation.z = -wheel_angle
		(fm["FmPupil"] as Node3D).visible = aperture > 0.2
	if fm["FmCore"] != null:
		(fm["FmCore"] as Node3D).visible = aperture > 0.05
	var core_m := _mat("fmCoreMat")
	if core_m != null:
		core_m.emission_energy_multiplier = (3.0 if B.exposed else 0.35) + float(B.flash) * 2.0
	var eye := _mat("fmEyeLamp")
	if eye != null:
		eye.albedo_color = Color.hex(0x54edffff if B.exposed else (0xffd05cff if B.move == "recover" else 0xff5838ff))
	if fm["FmLid_-1"] != null:
		(fm["FmLid_-1"] as Node3D).position = Vector3(0.0, 7.2 - aperture * 1.9, 4.35)
	if fm["FmLid_1"] != null:
		(fm["FmLid_1"] as Node3D).position = Vector3(0.0, 7.2 + aperture * 1.9, 4.35)
	var feet: Array = B.feet
	for i in 2:
		if i >= feet.size():
			continue
		var f: Dictionary = feet[i]
		var sk := "-1" if i == 0 else "1"
		var side := -1.0 if i == 0 else 1.0
		var p := WhForeman.local_point(B, Vector3(f.x, f.y, f.z))
		if fm["FmFoot_" + sk] != null:
			(fm["FmFoot_" + sk] as Node3D).position = p
			(fm["FmFoot_" + sk] as Node3D).rotation.y = float(f.yaw) - float(B.yaw)
		var a := Vector3(side * 2.1, 4.6 + float(pose.bob), 0.0)
		var c := Vector3(p.x, p.y + 1.0, p.z)
		var b := (a + c) * 0.5 + Vector3(0.0, 0.25, 1.4)
		_beam(fm["FmLegU_" + sk], a, b)
		_beam(fm["FmLegL_" + sk], b, c)
		if fm["FmKnee_" + sk] != null:
			(fm["FmKnee_" + sk] as Node3D).position = b
		_beam(fm["FmLegH_" + sk], a + Vector3(side * 0.65, 0.0, 0.0), c + Vector3(side * 0.65, 0.0, 0.0))
		if i < fm_solid_feet.size():
			var fs := fm_solid_feet[i]
			fs.place(f.x, f.z)
			fs.set_span(f.y, float(f.y) + 1.0)
			fs.set_off(B.dead)
	for sk: String in ["-1", "1"]:
		var side := float(sk)
		var J := _arm_joints(side, pose)
		_beam(fm["FmArmU_" + sk], J[0], J[1])
		_beam(fm["FmArmL_" + sk], J[1], J[2])
		if fm["FmElbow_" + sk] != null:
			(fm["FmElbow_" + sk] as Node3D).position = J[1]
		_beam(fm["FmArmR_" + sk], J[1] + Vector3(side * 0.45, 0.0, 0.0), J[2] + Vector3(side * 0.45, 0.0, 0.0))
		if fm["FmHand_" + sk] != null:
			var h: Node3D = fm["FmHand_" + sk]
			h.position = J[2]
			h.rotation = Vector3(float(pose.cannon_pitch), float(pose.cannon_yaw), 0.0) if side < 0.0 else Vector3.ZERO
	var marks: Array = B.marks
	var warns: Array = fm.warns
	for i in warns.size():
		var q: Node3D = warns[i]
		var has := i < marks.size()
		q.visible = B.mode == "fight" and has and ((B.move == "stamp" and float(B.mt) < float(boss.K.stamp.warning)) or (B.move == "drop" and float(B.mt) < float(boss.K.drop.warning)))
		if has:
			q.position = Vector3(marks[i].x, 0.045, marks[i].z)
	var falling: Array = fm.falling
	for i in falling.size():
		var q: Node3D = falling[i]
		var has := i < marks.size()
		q.visible = B.mode == "fight" and B.move == "drop" and has and float(B.mt) < float(boss.K.drop.warning)
		if q.visible:
			var u := clampf((float(B.mt) - (float(boss.K.drop.warning) - 0.55)) / 0.55, 0.0, 1.0)
			q.position = Vector3(marks[i].x, 0.6 + 15.0 * (1.0 - u * u), marks[i].z)
	var rings: Array = B.rings
	var waves: Array = fm.waves
	for i in waves.size():
		var q: Node3D = waves[i]
		var has := i < rings.size()
		q.visible = has and B.mode == "fight"
		if has:
			var r: Dictionary = rings[i]
			q.position = Vector3(r.x, 0.28, r.z)
			q.scale = Vector3(float(r.r), float(r.r), 4.0)


func update(dt: float, time: float, P: Player, state: Dictionary) -> void:
	_update_architecture(dt, time, state)
	_update_drives(dt)
	_update_doors(dt, time, P)
	_update_consoles(dt, state, P)
	_update_boards(state)
	_update_foreman(time)
	props.sync(time, dt)
	guidance.update(state, P, L.setpieces.chase.danger)
	guidance.update_foreman(L.boss.B)
	_update_visibility(state.stage)
	if mission != null:
		mission.update(state, L.hud_state, Inp.using_pad)
