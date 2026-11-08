class_name DevLevel
extends ExportedLevel
## DEV level (JS levels/dev/level.js): an endless flat plane with in-game dev tools (F2). F2 opens / closes the tools (frees the cursor; WASD still moves you, right-drag orbits, wheel zooms). Tools (keys 1-5): PLACE, MOVE, SELECT, DELETE, TELEPORT. Palette: shapes, props, NPCs, enemies, weapons. By default a new object rests against whatever surface is under the cursor; hold SHIFT to place it in mid-air (wheel = distance). Moving: plain drag slides over surfaces, SHIFT + drag moves straight up / down, CTRL + drag moves in the camera plane. R rotates 15 degrees, Delete removes, Ctrl+D duplicates, Esc closes. Console: Game.level.add_prop("shape", "cube", {x, y, z, size}), .spawn("count"), .clear_all(), .spawn_weapon("rifle"), .give_all(), .empty_wheel().

const REVIVE_AFTER := 6.0      # seconds a downed NPC lies there before standing back up
const ENEMIES := [
	{"id": "robot", "name": "ROBOT", "note": "hostile, standard"},
	{"id": "heavy", "name": "HEAVY ROBOT", "note": "armoured, 220 hp"},
	{"id": "patrol", "name": "PATROL ROBOT", "note": "walks a 4 m beat until it sees you", "ax": 4.0},
	{"id": "dummy", "name": "TRAINING DUMMY", "note": "robot that never acts"},
	{"id": "alien", "name": "GRAY ALIEN", "note": "fat mafioso alien: fast, spams a plasma pistol, rare purple mind blast (shove + slow)", "kind": "alien"},
	{"id": "prophet", "name": "FLAYED PROPHET", "note": "hovering flayed summoner: attacks on spawn, blood-glob volleys, births finger-legged brood from its slit, bursts on death", "kind": "prophet"},
	{"id": "scream", "name": "MAWNEST", "note": "spider-legged sac of tongues: attacks on spawn, tongue whip, spits barbed darts, calls its kin", "kind": "scream"},
	{"id": "drone", "name": "GUN DRONE", "note": "flying shooter: strafes, fires bursts, calls reinforcements"},
	# the MEAT SPIRE's enemies
	{"id": "crawler", "name": "SINEWCRAWLER", "note": "wall crawler: hangs 4.5 m above where you place it, drops on you (red ring), spits bile, leaps back up", "kind": "crawler"},
	{"id": "spore", "name": "BLISTERBLOAT", "note": "floating blister sac: drifts at you, swells and bursts into a slowing cloud (also when shot: shoot it far away)", "kind": "spore"},
	{"id": "tongue", "name": "WALLWRETCH", "note": "wall-fused screamer: aims (line), yanks you off ledges + stun; shoot the tongue tip to sever it", "kind": "tongue"},
	{"id": "brute", "name": "GRISTLE BRUTE", "note": "bone-shield brute: blocks from the front, hit its back or blast the carapace open with the Bellows Beast; charges", "kind": "brute"},
	{"id": "mimic", "name": "MAWLEDGE", "note": "a ledge that bites: stand on it and it chomps (0.55 s tell), double damage while its mouth is open", "kind": "mimic"},
	{"id": "worm", "name": "DIRGEWORM", "note": "blind gut-worm: attacks on spawn, petal-maw slam up close, howling pressure-ring shoves, keeps growing longer", "kind": "worm"},
	{"id": "assassin", "name": "NIGHT ASSASSIN", "note": "human in a stealth suit + night vision: suppressed pistol double-taps; up close a knife dash (1 s stun) and a backflip away", "kind": "assassin"},
	{"id": "warden", "name": "THE MARROW WARDEN", "note": "mid-boss: NOTARIZE > INK BLOT > FILING > PAPER SHUFFLE > SEAL BROKEN (double damage)", "kind": "warden"},
]
const VM_X := -7.5
const VM_Z := 2.5
var vending := {"x": VM_X, "z": VM_Z, "prompt": {"x": VM_X + 1.9, "z": VM_Z, "r": 2.2}}      # front faces +X (towards the spawn)
var vending_injector: VendingInjector = null
const TOOLS := [["place", "PLACE"], ["move", "MOVE"], ["select", "SELECT"], ["delete", "DELETE"], ["teleport", "TELEPORT"]]
const TABS := [["shape", "SHAPES"], ["prop", "PROPS"], ["vendor", "VENDORS"], ["npc", "NPCS"], ["enemy", "ENEMIES"], ["weapon", "WEAPONS"]]
const SAVE_PATH := "user://dev_layout.json"
const PAGE_SIZE := 6      # palette paging: 6 items (3 rows) per page, current page remembered per tab
const AMBER := Color("#ffd166")


class Prop:
	var uid := 0
	var cat := ""
	var def: Dictionary
	var size := Vector3.ONE
	var yaw := 0.0
	var pitch := 0.0
	var roll := 0.0
	var color := ""
	var collide := true
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var root: Node3D
	var solids: Array = []


class Npc:
	var uid := 0
	var def: Dictionary
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var yaw := 0.0
	var fall := 0.0
	var holder: Node3D
	var inst: DevNpcs.Inst = null
	var target: Target
	var solid: World.Solid
	var px := NAN
	var pz := NAN
	var sp := 0.0


class Foe:
	var uid := 0
	var kind: Dictionary
	var rb: Robot
	var x := 0.0
	var y := 0.0
	var z := 0.0


var props: Array[Prop] = []
var npcs: Array[Npc] = []
var enemies_: Array[Foe] = []
var catalogue: Array = []
var uid := 0
var edit := false
var tool := "place"
var tab := "shape"
var snap := true
var freeze := false
var god := false
var air_dist := 8.0
var shift_down := false
var saved_cam: Variant = null
var sel: Variant = null      # {kind, ref}
var drag: Variant = null     # {pk, mode, q0, c0}
var ghost: Node3D = null
var ghost_key := ""
var ring: MeshInstance3D
var sel_ring: MeshInstance3D
var sel_box: MeshInstance3D
var sel_box_mesh := ImmediateMesh.new()
var show_info := true
var pal_page := {}
var brush := {"cat": "shape", "id": "cube", "size": Vector3.ONE, "yaw": 0.0, "pitch": 0.0, "roll": 0.0, "color": "#c9a45c", "collide": true}
var layer: CanvasLayer
var panel: PanelContainer
var panel_box: VBoxContainer
var hud_l: Label
var font: Font
var clock := 0.0
var _rendered := false
var r_o := Vector3.ZERO
var r_d := Vector3.DOWN


func build() -> void:
	super.build()
	_load_catalogue()
	_build_mirror()
	_build_machine()
	var rm := MsKit.ring(.85, 1.0, 40)
	var mk := func() -> MeshInstance3D:
		var mat := VhKit.unlit(0xffd166, .9)
		mat.no_depth_test = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var m := MeshInstance3D.new()
		m.mesh = rm
		m.material_override = mat
		m.rotation.x = -PI / 2.0
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		return m
	ring = mk.call()
	sel_ring = mk.call()
	sel_box = MeshInstance3D.new()
	sel_box.mesh = sel_box_mesh
	var bm := VhKit.unlit(0xffd166, 1.0)
	bm.no_depth_test = true
	sel_box.material_override = bm
	sel_box.extra_cull_margin = 1000.0
	sel_box.visible = false
	add_child(sel_box)
	_build_ui()


func _load_catalogue() -> void:
	catalogue.clear()
	var f := FileAccess.open("res://assets/npcs/manifest.json", FileAccess.READ)
	if f != null:
		var man: Variant = JSON.parse_string(f.get_as_text())
		if man is Dictionary:
			for m: Dictionary in man.get("npcs", []):
				var d := {"radius": .4, "height": 1.8, "hp": 160.0, "note": ""}
				d.merge(m, true)
				d.file = "res://" + String(m.file)
				d.yaw = deg_to_rad(float(m.get("yaw", 0.0)))
				catalogue.append(d)
	for d: Dictionary in DevNpcs.BUILT_IN:
		var known := false
		for x: Dictionary in catalogue:
			known = known or x.id == d.id
		if not known and (not d.has("file") or ResourceLoader.exists(d.file)):
			catalogue.append(d.duplicate())


## the mirror: a free-standing real-time mirror 6 m in front of the spawn (faces the spawn, so you see your model from the front). Its frame, base and solids come with the export; the glass is named by the JS.
func _build_mirror() -> void:
	var g := node_named("DevMirror")
	if g.is_empty():
		push_warning("dev level: no DevMirror in the export (node tools/export/export.mjs level dev)")
		return
	var mi: MeshInstance3D = g[0] if g[0] is MeshInstance3D else g[0].find_children("*", "MeshInstance3D", true, false)[0]
	MirrorView.attach(mi, 0xe4e8ee, 0.45, 40.0)


## the DORBATELEPHINIUM IMPLANTS vending machine: left of the spawn, facing it. X near it opens the plasmid menu. The cabinet and its solid come with the export; its flap is named VendFlap by the JS, its arms are the injector cutscene's.
func _build_machine() -> void:
	vending_injector = VendingInjector.new()
	add_child(vending_injector)
	vending_injector.position = Vector3(float(vending.x), 0.0, float(vending.z))
	vending_injector.rotation.y = PI / 2.0
	vending_injector.scale = Vector3.ONE * 1.3
	var fl := node_named("VendFlap")
	if not fl.is_empty():
		vending_injector.flap_node = fl[0] as Node3D


## the arms depots placed from the VENDORS tab, for the X-to-shop (Shops.near_depot): kind, feet height and the spot in front of the machine where X works
var vendors: Array:
	get:
		return vendor_spots()


func vendor_spots() -> Array:
	var out: Array = []
	for o in props:
		if not o.def.get("vendor", false):
			continue
		var k: float = o.size.x / float(o.def.base[0])
		var yaw := deg_to_rad(o.yaw)
		var f: float = o.size.z / 2.0 + 0.75 * k
		out.append({"kind": o.def.id, "x": o.x, "y": o.y - o.size.y / 2.0, "z": o.z, "prompt": {"x": o.x + sin(yaw) * f, "z": o.z + cos(yaw) * f, "r": 1.1 * maxf(1.0, k)}})
	return out


# ---- props & shapes
func add_prop(cat: String, id: String, st: Dictionary = {}) -> Prop:
	var def: Variant = DevProps.find_def(cat, id)
	if def == null:
		Game.hud.toast("NO SUCH " + cat.to_upper() + ": " + id)
		return null
	var o := Prop.new()
	uid += 1
	o.uid = uid
	o.cat = cat
	o.def = def
	o.size = st.get("size", Vector3(def.base[0], def.base[1], def.base[2]))
	o.yaw = st.get("yaw", 0.0)
	o.pitch = st.get("pitch", 0.0)
	o.roll = st.get("roll", 0.0)
	o.color = st.get("color", def.color)
	o.collide = st.get("collide", true)
	o.x = st.get("x", 0.0)
	o.y = st.get("y", o.size.y / 2.0)
	o.z = st.get("z", 0.0)
	props.append(o)
	_rebuild_prop(o)
	return o


func _rebuild_prop(o: Prop) -> void:      # new mesh (size / colour changed)
	if o.root != null:
		o.root.queue_free()
	o.root = DevProps.build_object(o.def, o.color, o.size)
	add_child(o.root)
	_place_prop(o)


func _place_prop(o: Prop) -> void:      # position / rotation / colliders
	o.root.position = Vector3(o.x, o.y, o.z)
	o.root.rotation = Vector3(deg_to_rad(o.pitch), deg_to_rad(o.yaw), deg_to_rad(o.roll))
	for s: World.Solid in o.solids:
		world.remove(s)
	o.solids = []
	if o.collide and o.pitch == 0.0 and o.roll == 0.0:
		for sp: Dictionary in DevProps.colliders(o.def, o.x, o.y, o.z, o.yaw, o.size):
			o.solids.append(world.add(sp))


func remove_prop(o: Prop) -> void:
	if not props.has(o):
		return
	props.erase(o)
	o.root.queue_free()
	for s: World.Solid in o.solids:
		world.remove(s)
	if sel != null and sel.ref == o:
		select(null)


# ---- NPCs
func _npc_def(id: String) -> Variant:
	for d: Dictionary in catalogue:
		if d.id == id:
			return d
	return null


func spawn_npc_at(def: Dictionary, x: float, y: float, z: float, yaw: float) -> Npc:
	var n := Npc.new()
	uid += 1
	n.uid = uid
	n.def = def
	n.x = x
	n.y = y
	n.z = z
	n.yaw = yaw
	n.holder = Node3D.new()
	n.holder.name = "NPC %s #%d" % [def.name, n.uid]
	add_child(n.holder)
	n.inst = DevNpcs.make(def, n.holder)
	if n.inst == null:
		n.holder.queue_free()
		Game.hud.toast("COULD NOT LOAD " + String(def.name))
		return null
	n.target = Target.new(2000 + n.uid, x, z, y, {"r": def.radius, "h": def.height, "max": def.hp, "hp": def.hp, "npc": true, "w": 0.0, "dev": true})
	n.solid = world.add({"kind": "disc", "cx": x, "cz": z, "r": float(def.radius) * .9, "bottom": y, "top": y + float(def.height) * .9, "tag": "bound"})
	Game.combat.targets.append(n.target)
	npcs.append(n)
	_place_npc(n, 0.0)
	return n


func _place_npc(n: Npc, dt: float) -> void:
	var Tg := n.target
	if dt > 0.0 and n.inst.has_move:      # NPCs with a walk animation: how fast is it being moved (dragged / teleported / set from the panel)? walk at that speed, face the way it goes, stand idle otherwise
		var dx: float = n.x - (n.x if is_nan(n.px) else n.px)
		var dz: float = n.z - (n.z if is_nan(n.pz) else n.pz)
		n.px = n.x
		n.pz = n.z
		var v := minf(3.2, Vector2(dx, dz).length() / dt)
		n.sp += (v - n.sp) * minf(1.0, dt * 9.0)
		var moving: bool = not Tg.dead and n.sp > 0.3
		n.inst.set_move(n.sp if moving else 0.0)
		if moving and Vector2(dx, dz).length() > 1e-4:
			var want: float = atan2(dx, dz) + float(n.def.get("yaw", 0.0))
			var d_a := fposmod(want - n.yaw + PI, TAU) - PI
			n.yaw += d_a * minf(1.0, dt * 10.0)
	if Tg.dead and Tg.respawn_t > REVIVE_AFTER:
		Tg.respawn_t = REVIVE_AFTER
	n.fall += ((1.0 if Tg.dead else 0.0) - n.fall) * minf(1.0, dt * 5.0)
	var sh: float = 0.0 if Tg.dead else Tg.wob * .04 * sin(clock * 55.0)
	if n.inst.alien != null:      # (ENGINE DIFFERENCE: an alien draws in the enemy batch at its robot's place, so it is placed rather than parented; it falls with its own dead pose)
		n.inst.alien.place(n.x + sh, n.y, n.z, n.yaw)
		if Tg.dead != (n.inst.alien.pose == &"dead"):
			n.inst.alien.set_pose(&"dead" if Tg.dead else &"idle")
	else:
		n.holder.rotation = Vector3(-1.45 * n.fall, n.yaw, 0.0)
		n.holder.position = Vector3(n.x + sh, n.y + .1 * n.fall, n.z)
	n.inst.flash(Tg.flash)


func move_npc(n: Npc, x: float, y: float, z: float) -> void:
	n.x = x
	n.y = y
	n.z = z
	n.target.x = x
	n.target.bx = x
	n.target.z = z
	n.target.bz = z
	n.target.y = y
	n.solid.place(x, z)
	n.solid.set_span(y, y + float(n.def.height) * .9)


func remove_npc(n: Npc) -> void:
	if not npcs.has(n):
		return
	npcs.erase(n)
	n.holder.queue_free()
	world.remove(n.solid)
	Game.combat.targets.erase(n.target)
	if sel != null and sel.ref == n:
		select(null)


## console helper: an NPC 3.2 m in front of the player
func spawn(id: String = "count") -> Npc:
	var def: Variant = _npc_def(id)
	if def == null:
		Game.hud.toast("NO SUCH NPC: " + id)
		return null
	var P: Player = Game.player
	var x := P.x + sin(P.yaw) * 3.2
	var z := P.z + cos(P.yaw) * 3.2
	return spawn_npc_at(def, x, 0.0, z, atan2(P.x - x, P.z - z) + float(def.get("yaw", 0.0)))


# ---- enemies (the game's hostile robots)
func spawn_enemy_at(id: String, x: float, y: float, z: float, yaw: float = 0.0) -> Foe:
	var k: Variant = null
	for e: Dictionary in ENEMIES:
		if e.id == id:
			k = e
	if k == null:
		return null
	var o := {"ax": k.get("ax", 0.0), "az": 0.0, "drone": id == "drone", "no_respawn": true}
	if k.has("kind"):
		o["kind"] = k.kind
	var rb: Robot = Game.spawn_enemy({"x": x, "y": y, "z": z, "yaw": yaw}, o)
	if rb == null:
		return null
	if id == "heavy":
		rb.heavy = true
		rb.max = 220.0
		rb.hp = 220.0
		rb.r = .72
	if id == "dummy":
		rb.dev_passive = true
	var e := Foe.new()
	uid += 1
	e.uid = uid
	e.kind = k
	e.rb = rb
	e.x = x
	e.y = y
	e.z = z
	enemies_.append(e)
	return e


func move_enemy(e: Foe, x: float, y: float, z: float) -> void:
	var rb := e.rb
	e.x = x
	e.y = y
	e.z = z
	rb.x = x
	rb.hx = x
	rb.z = z
	rb.hz = z
	rb.hy = y
	rb.y = y + float(rb.get(&"hover") if rb.get(&"hover") != null else 0.0)
	rb.vx = 0.0
	rb.vz = 0.0
	rb.kvx = 0.0
	rb.kvz = 0.0


func remove_enemy(e: Foe) -> void:
	if not enemies_.has(e):
		return
	enemies_.erase(e)
	Game.despawn_enemy(e.rb)
	if sel != null and sel.ref == e:
		select(null)


func clear_props() -> void:
	for o in props.duplicate():
		remove_prop(o)


func clear_npcs() -> void:
	for n in npcs.duplicate():
		remove_npc(n)


func clear_enemies() -> void:
	for e in enemies_.duplicate():
		remove_enemy(e)


func clear_all() -> void:
	clear_props()
	clear_npcs()
	clear_enemies()
	clear_weapons()


# ---- weapons (pickups on the ground; they live in combat.drops)
func spawn_weapon_at(id: String, x: float, y: float, z: float, st: Dictionary = {}) -> Variant:
	var i := Weapons.index_of(id)
	if i < 0:
		Game.hud.toast("NO SUCH WEAPON: " + id)
		return null
	var o := {}
	if st.has("ammo"):
		o["ammo"] = st.ammo
	if st.has("reserve"):
		o["reserve"] = st.reserve
	return Game.combat.spawn_drop(i, x, y, z, o)


## console helper: spawn_weapon("rifle") drops one 2 m in front of the player
func spawn_weapon(id: String) -> Variant:
	var P: Player = Game.player
	return spawn_weapon_at(id, P.x + sin(P.yaw) * 2.0, P.y + .5, P.z + cos(P.yaw) * 2.0)


func move_weapon(d: Variant, x: float, y: float, z: float) -> void:
	d.x = x
	d.y = maxf(0.0, y)
	d.z = z
	d.vx = 0.0
	d.vy = 0.0
	d.vz = 0.0
	d.rest = false
	d.pin = .12


func remove_weapon(d: Variant) -> void:
	Game.combat.remove_drop(d)
	if sel != null and sel.ref == d:
		select(null)


func clear_weapons() -> void:
	for d: Variant in Game.combat.drops.duplicate():
		remove_weapon(d)


func give_all() -> void:
	var C: Combat = Game.combat
	for k in Weapons.WEAPONS.size():
		var w: Variant = Weapons.WEAPONS[k]
		if not C.owned.has(k):
			C.give(k)
		else:
			C.ammo[k] = w.mag_size
			C.reserve[k] = w.max - w.mag_size
	Game.hud.toast("ALL WEAPONS ON THE WHEEL")


func empty_wheel() -> void:
	var C: Combat = Game.combat
	for k: Variant in C.slots.duplicate():
		if k != null:
			C.remove(k)
	Game.hud.toast("WEAPON WHEEL EMPTIED")


# ---- picking + placement (mouse -> ray)
func _set_ray() -> void:
	var cam: Camera3D = Game.camera
	var mp := get_viewport().get_mouse_position()
	r_o = cam.project_ray_origin(mp)
	r_d = cam.project_ray_normal(mp)


func _cyl_t(x: float, y: float, z: float, r: float, h: float) -> float:      # ray vs vertical cylinder
	var a := r_d.x * r_d.x + r_d.z * r_d.z
	if a < 1e-9:
		return INF
	var px := r_o.x - x
	var pz := r_o.z - z
	var c2 := 2.0 * (px * r_d.x + pz * r_d.z)
	var c := px * px + pz * pz - r * r
	var disc := c2 * c2 - 4.0 * a * c
	if disc < 0.0:
		return INF
	var s := sqrt(disc)
	var t := (-c2 - s) / (2.0 * a)
	if t < 0.0:
		t = (-c2 + s) / (2.0 * a)
	if t < 0.0:
		return INF
	var yy := r_o.y + r_d.y * t
	return INF if yy < y or yy > y + h else t


## ray vs a prop's own box (the engine has no mesh raycast against a node: its oriented bounds stand in, so a sphere picks as a box) -> [t, normal] or null
func _prop_hit(o: Prop) -> Variant:
	var b := Basis.from_euler(Vector3(deg_to_rad(o.pitch), deg_to_rad(o.yaw), deg_to_rad(o.roll)))
	var inv := b.inverse()
	var lo := inv * (r_o - Vector3(o.x, o.y, o.z))
	var ld := inv * r_d
	var hs := o.size / 2.0
	var t0 := -INF
	var t1 := INF
	var axis := 0
	for i in 3:
		if absf(ld[i]) < 1e-9:
			if absf(lo[i]) > hs[i]:
				return null
			continue
		var a := (-hs[i] - lo[i]) / ld[i]
		var c := (hs[i] - lo[i]) / ld[i]
		if a > c:
			var q := a
			a = c
			c = q
		if a > t0:
			t0 = a
			axis = i
		t1 = minf(t1, c)
		if t0 > t1:
			return null
	if t0 < 0.0:
		return null
	var n := Vector3.ZERO
	n[axis] = -signf(ld[axis])
	return [t0, b * n]


func _surface_hit(exclude: Variant) -> Variant:      # nearest ground / prop surface under the ray: {t, p, n}
	var best: Variant = null
	if r_d.y < -1e-5:
		var t := -r_o.y / r_d.y
		if t > 0.0:
			best = {"t": t, "p": r_o + r_d * t, "n": Vector3.UP}
	for o in props:
		if o == exclude:
			continue
		var h: Variant = _prop_hit(o)
		if h != null and (best == null or float(h[0]) < float(best.t)):
			best = {"t": h[0], "p": r_o + r_d * float(h[0]), "n": h[1]}
	return best


static func _snap_v(v: float) -> float:
	return roundf(v * 2.0) / 2.0


## where an object (size / yaw) goes for the current cursor: rests against the surface (any direction) or floats in mid-air with SHIFT
func _placement_for(size: Vector3, yaw: float, exclude: Variant) -> Variant:
	if shift_down:
		var p := r_o + r_d * air_dist
		if snap:
			p = Vector3(_snap_v(p.x), _snap_v(p.y), _snap_v(p.z))
		return p
	var h: Variant = _surface_hit(exclude)
	if h == null:
		return null
	var p: Vector3 = h.p
	var n: Vector3 = h.n
	if snap:
		if absf(n.x) < .5:
			p.x = _snap_v(p.x)
		if absf(n.y) < .5:
			p.y = _snap_v(p.y)
		if absf(n.z) < .5:
			p.z = _snap_v(p.z)
	return p + n * DevProps.reach_along(size, yaw, n)


func _stand_point() -> Variant:      # for characters: a point on a surface facing up
	var h: Variant = _surface_hit(null)
	if h == null or (h.n as Vector3).y < .5:
		return null
	var p: Vector3 = h.p
	if snap and p.y < .01:
		p.x = _snap_v(p.x)
		p.z = _snap_v(p.z)
	return p


func _pick_object() -> Variant:
	var best: Variant = null
	var bt := INF
	for o in props:
		var h: Variant = _prop_hit(o)
		if h != null and float(h[0]) < bt:
			bt = h[0]
			best = {"kind": "prop", "ref": o}
	for n in npcs:
		var t := _cyl_t(n.x, n.y, n.z, maxf(float(n.def.radius), .35), n.def.height)
		if t < bt:
			bt = t
			best = {"kind": "npc", "ref": n}
	for e in enemies_:
		var t := _cyl_t(e.rb.x, e.rb.y, e.rb.z, maxf(e.rb.r, .4), e.rb.h)
		if t < bt:
			bt = t
			best = {"kind": "enemy", "ref": e}
	for d: Variant in Game.combat.drops:
		var t := _cyl_t(d.x, d.y, d.z, .5, 1.0)
		if t < bt:
			bt = t
			best = {"kind": "weapon", "ref": d}
	return best


# ---- selection / brush
func select(pk: Variant) -> void:
	sel = pk
	_render_panel()


func _brush_def() -> Variant:
	return DevProps.find_def(brush.cat, brush.id) if brush.cat == "shape" or brush.cat == "prop" or brush.cat == "vendor" else null


func _subject() -> Variant:
	if sel != null:
		if sel.kind == "weapon":
			return {"kind": "weapon", "ref": sel.ref, "title": "SELECTED: " + String(Weapons.WEAPONS[sel.ref.i].name) + " #" + str(sel.ref.id)}
		if sel.kind == "prop":
			return {"kind": "prop", "ref": sel.ref, "def": sel.ref.def, "title": "SELECTED: " + String(sel.ref.def.name) + " #" + str(sel.ref.uid)}
		return {"kind": sel.kind, "ref": sel.ref, "title": "SELECTED: " + String(sel.ref.def.name if sel.kind == "npc" else sel.ref.kind.name) + " #" + str(sel.ref.uid)}
	var d: Variant = _brush_def()
	return {"kind": "brush", "ref": brush, "def": d, "title": "BRUSH: " + String(d.name)} if d != null else null


func _apply_field(key: String, v: Variant) -> void:
	var s: Variant = _subject()
	if s == null:
		return
	if s.kind == "prop" or s.kind == "brush":
		var o: Variant = s.ref
		var rebuild := false
		if key == "sx" or key == "sy" or key == "sz":
			var q: Vector3 = o.size if s.kind == "prop" else o["size"]
			q["xyz".find(key[1])] = clampf(v, .1, 60.0)
			if s.kind == "prop":
				o.size = q
			else:
				o["size"] = q
			rebuild = true
		elif key == "scale":
			var b: Array = s.def.base
			var q := Vector3(b[0], b[1], b[2]) * clampf(v, .1, 60.0)
			if s.kind == "prop":
				o.size = q
			else:
				o["size"] = q
			rebuild = true
		elif key == "yaw" or key == "pitch" or key == "roll":
			o.set(key, v) if s.kind == "prop" else o.merge({key: v}, true)
		elif key == "color":
			o.set("color", v) if s.kind == "prop" else o.merge({"color": v}, true)
			rebuild = true
		elif key == "collide":
			o.set("collide", v) if s.kind == "prop" else o.merge({"collide": v}, true)
		elif key == "px":
			o.x = v
		elif key == "py":
			o.y = v
		elif key == "pz":
			o.z = v
		if s.kind == "prop":
			if rebuild:
				_rebuild_prop(o)
			else:
				_place_prop(o)
		else:
			ghost_key = ""
	elif s.kind == "weapon":
		var d: Variant = s.ref
		var w: Variant = Weapons.WEAPONS[d.i]
		if key == "px" or key == "py" or key == "pz":
			move_weapon(d, v if key == "px" else d.x, v if key == "py" else d.y, v if key == "pz" else d.z)
		elif key == "ammo":
			d.ammo = roundi(clampf(v, 0.0, w.mag_size))
		elif key == "reserve":
			d.reserve = roundi(clampf(v, 0.0, w.max - w.mag_size))
	else:
		var o: Variant = s.ref
		if key == "yaw":
			if s.kind == "enemy":
				o.rb.yaw = deg_to_rad(v)
			else:
				o.yaw = deg_to_rad(v)
		elif key == "px" or key == "py" or key == "pz":
			var x: float = v if key == "px" else o.x
			var y: float = v if key == "py" else o.y
			var z: float = v if key == "pz" else o.z
			if s.kind == "npc":
				move_npc(o, x, y, z)
			else:
				move_enemy(o, x, y, z)


func _nudge_yaw(dir: float) -> void:
	var s: Variant = _subject()
	if s == null or s.kind == "weapon":
		return
	var cur: float
	if s.kind == "prop":
		cur = s.ref.yaw
	elif s.kind == "brush":
		cur = s.ref["yaw"]
	elif s.kind == "npc":
		cur = rad_to_deg(s.ref.yaw)
	else:
		cur = rad_to_deg(s.ref.rb.yaw)
	_apply_field("yaw", fposmod(cur + dir * 15.0, 360.0))
	_render_panel()


func _duplicate() -> void:
	if sel != null and sel.kind == "weapon":
		var d: Variant = sel.ref
		var c: Variant = spawn_weapon_at(Weapons.WEAPONS[d.i].id, d.x + 1.0, d.y, d.z, {"ammo": d.ammo, "reserve": d.reserve})
		if c != null:
			select({"kind": "weapon", "ref": c})
		return
	if sel == null or sel.kind != "prop":
		return
	var o: Prop = sel.ref
	var c := add_prop(o.cat, o.def.id, {"size": o.size, "yaw": o.yaw, "pitch": o.pitch, "roll": o.roll, "color": o.color, "collide": o.collide, "x": o.x + 1.0, "y": o.y, "z": o.z})
	if c != null:
		select({"kind": "prop", "ref": c})


func _delete_sel() -> void:
	if sel == null:
		return
	var kind: String = sel.kind
	var ref: Variant = sel.ref
	if kind == "prop":
		remove_prop(ref)
	elif kind == "npc":
		remove_npc(ref)
	elif kind == "weapon":
		remove_weapon(ref)
	else:
		remove_enemy(ref)
	select(null)


# ---- mouse tools
func _do_place() -> void:
	var P: Player = Game.player
	if brush.cat == "shape" or brush.cat == "prop" or brush.cat == "vendor":
		var p: Variant = _placement_for(brush.size, brush.yaw, null)
		if p == null:
			return
		var o := add_prop(brush.cat, brush.id, {"size": brush.size, "yaw": brush.yaw, "pitch": brush.pitch, "roll": brush.roll, "color": brush.color, "collide": brush.collide, "x": p.x, "y": p.y, "z": p.z})
		if o != null:
			select({"kind": "prop", "ref": o})
		return
	var p: Variant = _stand_point()
	if p == null:
		Game.hud.toast("CLICK A FLAT SURFACE")
		return
	var face := atan2(P.x - float(p.x), P.z - float(p.z))
	if brush.cat == "weapon":
		var d: Variant = spawn_weapon_at(brush.id, p.x, p.y, p.z)
		if d != null:
			Game.hud.toast("SPAWNED " + String(Weapons.WEAPONS[d.i].name))
			select({"kind": "weapon", "ref": d})
	elif brush.cat == "npc":
		var def: Variant = _npc_def(brush.id)
		if def != null:
			var n := spawn_npc_at(def, p.x, p.y, p.z, face + float(def.get("yaw", 0.0)))
			if n != null:
				Game.hud.toast("SPAWNED " + String(def.name))
				select({"kind": "npc", "ref": n})
	else:
		var e := spawn_enemy_at(brush.id, p.x, p.y, p.z, face)
		if e != null:
			Game.hud.toast("SPAWNED " + String(e.kind.name))
			select({"kind": "enemy", "ref": e})


func _set_pos(pk: Dictionary, x: float, y: float, z: float) -> void:
	var r: Variant = pk.ref
	if pk.kind == "prop":
		r.x = x
		r.y = y
		r.z = z
		_place_prop(r)
	elif pk.kind == "npc":
		move_npc(r, x, y, z)
	elif pk.kind == "weapon":
		move_weapon(r, x, y, z)
	else:
		move_enemy(r, x, y, z)


func _do_drag(ctrl: bool, shift: bool) -> void:
	if drag == null:
		return
	_set_ray()
	var pk: Dictionary = drag.pk
	if pk.kind == "weapon":
		pk.ref.pin = .12
	var mode := "free" if ctrl else ("vert" if shift else "surf")
	if mode != drag.mode:
		drag.mode = mode
		drag.q0 = null
		drag.c0 = Vector3(pk.ref.x, pk.ref.y, pk.ref.z)
	if mode == "surf":
		var p: Variant = _placement_for(pk.ref.size, pk.ref.yaw, pk.ref) if pk.kind == "prop" else _stand_point()
		if p != null:
			_set_pos(pk, p.x, p.y, p.z)
		return
	var nrm: Vector3 = -Game.camera.global_basis.z
	if mode == "vert":
		nrm.y = 0.0
		if nrm.length_squared() < 1e-4:
			return
		nrm = nrm.normalized()
	var pl := Plane(nrm, drag.c0)
	var q: Variant = pl.intersects_ray(r_o, r_d)
	if q == null:
		return
	if drag.q0 == null:
		drag.q0 = q
	var dlt: Vector3 = (q as Vector3) - (drag.q0 as Vector3)
	var c: Vector3 = drag.c0
	if mode == "vert":
		c.y += dlt.y
	else:
		c += dlt
	if snap and pk.kind == "prop":
		c = Vector3(_snap_v(c.x), _snap_v(c.y), _snap_v(c.z))
	if pk.kind != "prop":
		c.y = maxf(0.0, c.y)
	_set_pos(pk, c.x, c.y, c.z)


func _on_down() -> void:
	_set_ray()
	if tool == "place":
		_do_place()
	elif tool == "move" or tool == "select":
		var pk: Variant = _pick_object()
		select(pk)
		if pk != null and tool == "move":
			drag = {"pk": pk, "mode": "", "q0": null, "c0": Vector3(pk.ref.x, pk.ref.y, pk.ref.z)}
	elif tool == "delete":
		var pk: Variant = _pick_object()
		if pk != null:
			select(pk)
			_delete_sel()
	elif tool == "teleport":
		var p: Variant = _stand_point()
		var P: Player = Game.player
		if p != null and P != null:
			P.x = p.x
			P.z = p.z
			P.y = p.y
			P.vx = 0.0
			P.vz = 0.0
			P.vy = 0.0


func _input(event: InputEvent) -> void:
	if event is InputEventWithModifiers:
		shift_down = (event as InputEventWithModifiers).shift_pressed
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k := event as InputEventKey
		if k.keycode == KEY_F2:
			get_viewport().set_input_as_handled()
			if not Game.paused:
				set_edit(not edit)
			return
		if not edit:
			return
		if get_viewport().gui_get_focus_owner() is LineEdit:
			if k.keycode == KEY_ESCAPE:
				get_viewport().gui_release_focus()
				get_viewport().set_input_as_handled()
			return
		var used := true
		if k.keycode == KEY_ESCAPE or k.keycode == KEY_P:
			set_edit(false)
		elif k.keycode >= KEY_1 and k.keycode <= KEY_5:
			_set_tool(TOOLS[k.keycode - KEY_1][0])
		elif k.keycode == KEY_DELETE or k.keycode == KEY_BACKSPACE:
			_delete_sel()
		elif k.keycode == KEY_R:
			_nudge_yaw(-1.0 if k.shift_pressed else 1.0)
		elif k.keycode == KEY_D and k.ctrl_pressed:
			_duplicate()
		else:
			used = false
		if used:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and edit and drag != null:
		var m := event as InputEventMouseMotion
		_do_drag(m.ctrl_pressed, m.shift_pressed)
	elif event is InputEventMouseButton and edit:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT and not b.pressed:
			drag = null


func _unhandled_input(event: InputEvent) -> void:
	if not edit or not event is InputEventMouseButton:
		return
	var b := event as InputEventMouseButton
	if not b.pressed:
		return
	if b.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_on_down()
	elif b.button_index == MOUSE_BUTTON_WHEEL_UP or b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		get_viewport().set_input_as_handled()
		var k := 1.1 if b.button_index == MOUSE_BUTTON_WHEEL_DOWN else 1.0 / 1.1
		if b.shift_pressed:
			air_dist = clampf(air_dist * k, 1.0, 80.0)
		else:
			Config.cam_dist = clampf(Config.cam_dist * k, 2.0, 80.0)


# ---- ghost / selection marker (per frame)
func _ensure_ghost() -> void:
	var key := "%s:%s:%s:%s" % [brush.cat, brush.id, brush.color, brush.size]
	if key == ghost_key:
		return
	ghost_key = key
	if ghost != null:
		ghost.queue_free()
		ghost = null
	var d: Variant = _brush_def()
	if d != null:
		ghost = DevProps.build_object(d, brush.color, brush.size)
		for mi: Node in ghost.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var src: Material = m.material_override if m.material_override != null else m.mesh.surface_get_material(0)      # (an arms depot's parts carry their own)
			var mat: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = .5
			m.material_override = mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ghost)


func _update_ghost() -> void:
	var show_g: bool = edit and tool == "place" and Game.player != null
	if not show_g:
		if ghost != null:
			ghost.visible = false
		ring.visible = false
		return
	_set_ray()
	var d: Variant = _brush_def()
	if d != null:
		ring.visible = false
		_ensure_ghost()
		if ghost == null:
			return
		var p: Variant = _placement_for(brush.size, brush.yaw, null)
		ghost.visible = p != null
		if p != null:
			ghost.position = p
			ghost.rotation = Vector3(deg_to_rad(brush.pitch), deg_to_rad(brush.yaw), deg_to_rad(brush.roll))
	else:
		if ghost != null:
			ghost.visible = false
		var p: Variant = _stand_point()
		ring.visible = p != null
		if p != null:
			ring.position = Vector3(p.x, float(p.y) + .04, p.z)
			var col := 0xff5a4a if brush.cat == "enemy" else (0xe6eef6 if brush.cat == "weapon" else 0x38e8ff)
			(ring.material_override as StandardMaterial3D).albedo_color = Color(MsKit.srgb(col), .9)
			ring.scale = Vector3.ONE * (.5 if brush.cat == "weapon" else .8)


func _update_sel_mark() -> void:
	sel_box.visible = false
	sel_ring.visible = false
	if not edit or sel == null:
		return
	if sel.kind == "weapon":
		if not Game.combat.drops.has(sel.ref):      # picked up by the player
			select(null)
			return
		sel_ring.visible = true
		sel_ring.position = Vector3(sel.ref.x, float(sel.ref.y) + .04, sel.ref.z)
		sel_ring.scale = Vector3.ONE * .6
		return
	if sel.kind == "prop":
		var o: Prop = sel.ref
		var h := o.size / 2.0
		var xf := Transform3D(Basis.from_euler(o.root.rotation), o.root.position)
		sel_box_mesh.clear_surfaces()
		sel_box_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		var cs: Array[Vector3] = []
		for k in 8:
			cs.append(xf * Vector3(h.x * (1.0 if k & 1 else -1.0), h.y * (1.0 if k & 2 else -1.0), h.z * (1.0 if k & 4 else -1.0)))
		for e: Array in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
			sel_box_mesh.surface_add_vertex(cs[e[0]])
			sel_box_mesh.surface_add_vertex(cs[e[1]])
		sel_box_mesh.surface_end()
		sel_box.visible = true
		return
	var r: Variant = sel.ref if sel.kind == "npc" else sel.ref.rb
	var rad: float = sel.ref.def.radius if sel.kind == "npc" else r.r
	sel_ring.visible = true
	sel_ring.position = Vector3(r.x, float(r.y) + .04, r.z)
	sel_ring.scale = Vector3.ONE * (maxf(rad, .4) + .25)


# ---- frame
func tick(dt: float) -> void:
	super.tick(dt)
	clock += dt
	var P: Player = Game.player
	for n in npcs:
		n.inst.update(clock, dt)
		_place_npc(n, dt)
	for o in props:      # arms depot neon, screens, turntables
		if o.def.get("vendor", false) and o.root != null:
			(o.root.get_child(0).get_child(0) as ArmsDepot).update_at(clock)
	for e in enemies_:
		e.x = e.rb.x
		e.y = e.rb.y
		e.z = e.rb.z
	if drag != null and drag.pk.kind == "weapon":
		drag.pk.ref.pin = .12
	if P != null and god:
		P.invuln = maxf(P.invuln, 1.0)
	panel.visible = edit and not Game.paused and P != null
	_update_ghost()
	_update_sel_mark()
	var txt := ""
	if P != null:
		if edit:
			txt = tool.to_upper() + "  ·  SNAP " + ("0.5 M" if snap else "OFF") + ("  ·  MID-AIR (WHEEL = DISTANCE %.2f M)" % air_dist if shift_down else "  ·  HOLD SHIFT TO PLACE IN MID-AIR") + "  ·  RIGHT-DRAG ORBIT  ·  WHEEL ZOOM  ·  F2 CLOSE"
		else:
			txt = "F2 DEV TOOLS  ·  %d OBJECTS  ·  %d NPCS  ·  %d ENEMIES  ·  %d WEAPONS" % [props.size(), npcs.size(), enemies_.size(), Game.combat.drops.size()]
	hud_l.text = "DEV    " + txt
	hud_l.visible = show_info and txt != "" and not Game.paused


func on_exit() -> void:
	Inp.orbit_btn = 0
	Inp.capture_blocked = false
	if saved_cam != null:
		Config.cam_dist = saved_cam


# ---- edit mode
func set_edit(on: bool) -> void:
	if on == edit:
		return
	edit = on
	Inp.orbit_btn = MOUSE_BUTTON_RIGHT if on else 0
	Inp.capture_blocked = on
	if on:
		Game.ui.unlock()
		saved_cam = Config.cam_dist
		Config.cam_dist = maxf(Config.cam_dist, 9.0)
		_render_panel()
	else:
		drag = null
		if saved_cam != null:
			Config.cam_dist = saved_cam
		if ghost != null:
			ghost.visible = false
		ring.visible = false
		sel_ring.visible = false
		sel_box.visible = false
		Game.ui.lock()


func _set_tool(t: String) -> void:
	tool = t
	drag = null
	if t == "place":
		ghost_key = ""
	_render_panel()


func _kill_all() -> void:
	for e in enemies_:
		if not e.rb.dead:
			Game.combat.damage(e.rb, 1e5, Game.player)
	Game.hud.toast("ALL ENEMIES DOWN")


static func _arr3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func save_layout() -> void:
	var data := {"v": 1, "props": [], "npcs": [], "enemies": [], "weapons": []}
	for o in props:
		data.props.append({"cat": o.cat, "id": o.def.id, "size": _arr3(o.size), "yaw": o.yaw, "pitch": o.pitch, "roll": o.roll, "color": o.color, "collide": o.collide, "x": o.x, "y": o.y, "z": o.z})
	for n in npcs:
		data.npcs.append({"id": n.def.id, "x": n.x, "y": n.y, "z": n.z, "yaw": n.yaw})
	for e in enemies_:
		data.enemies.append({"id": e.kind.id, "x": e.x, "y": e.y, "z": e.z, "yaw": e.rb.yaw})
	for d: Variant in Game.combat.drops:
		data.weapons.append({"id": Weapons.WEAPONS[d.i].id, "x": d.x, "y": d.y, "z": d.z, "ammo": d.ammo, "reserve": d.reserve})
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		Game.hud.toast("COULD NOT SAVE")
		return
	f.store_string(JSON.stringify(data))
	Game.hud.toast("LAYOUT SAVED (%d items)" % (data.props.size() + data.npcs.size() + data.enemies.size() + data.weapons.size()))


func load_layout() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
	if data == null:
		Game.hud.toast("NO SAVED LAYOUT")
		return
	clear_all()
	for p: Dictionary in data.get("props", []):
		var q := p.duplicate()
		q.size = Vector3(p.size[0], p.size[1], p.size[2])
		add_prop(p.cat, p.id, q)
	for e: Dictionary in data.get("enemies", []):
		spawn_enemy_at(e.id, e.x, e.y, e.z, e.yaw)
	for w: Dictionary in data.get("weapons", []):
		spawn_weapon_at(w.id, w.x, w.y, w.z, w)
	for n: Dictionary in data.get("npcs", []):
		var d: Variant = _npc_def(n.id)
		if d != null:
			spawn_npc_at(d, n.x, n.y, n.z, n.yaw)
	Game.hud.toast("LAYOUT LOADED")
	_render_panel()


# ---- UI (JS the #devtools glass panel)
func _box(alpha: float = .5, line: float = .1, rad: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(8.0 / 255.0, 10.0 / 255.0, 12.0 / 255.0, alpha)
	s.border_color = Color(1, 1, 1, line)
	s.set_border_width_all(1)
	s.set_corner_radius_all(rad)
	return s


func _build_ui() -> void:
	font = load("res://assets/fonts/Rajdhani-SemiBold.ttf")
	layer = CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	hud_l = Label.new()
	hud_l.anchor_left = .5
	hud_l.anchor_right = .5
	hud_l.offset_left = -390.0
	hud_l.offset_right = 390.0
	hud_l.offset_top = 10.0
	hud_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_l.add_theme_font_override(&"font", font)
	hud_l.add_theme_font_size_override(&"font_size", 12)
	hud_l.add_theme_color_override(&"font_color", Color("#aab6c3"))
	hud_l.add_theme_stylebox_override(&"normal", _box())
	hud_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud_l)
	panel = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -352.0
	panel.offset_right = -12.0
	panel.offset_top = 12.0
	panel.offset_bottom = -12.0
	var st := _box()
	st.set_content_margin_all(12.0)
	panel.add_theme_stylebox_override(&"panel", st)
	panel.visible = false
	layer.add_child(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	panel_box = VBoxContainer.new()
	panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.add_theme_constant_override(&"separation", 6)
	sc.add_child(panel_box)
	_render_panel()


func _lbl(t: String, size: int = 11, col: Color = Color("#8f9cab"), wrap_: bool = false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override(&"font", font)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	if wrap_:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _btn(t: String, fn: Callable, on: bool = false, h_: bool = false) -> Button:
	var b := Button.new()
	b.text = t
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override(&"font", font)
	b.add_theme_font_size_override(&"font_size", 12)
	b.add_theme_color_override(&"font_color", Color.WHITE if on else Color("#b9c4d0"))
	b.add_theme_stylebox_override(&"normal", _box(.0 if not on else .35, .6 if on else .1, 9))
	b.add_theme_stylebox_override(&"hover", _box(.3, .28, 9))
	b.add_theme_stylebox_override(&"pressed", _box(.5, .6, 9))
	b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	if h_:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(fn)
	return b


func _row(cols: int = 0) -> Container:
	var c: Container
	if cols > 0:
		var g := GridContainer.new()
		g.columns = cols
		g.add_theme_constant_override(&"h_separation", 5)
		g.add_theme_constant_override(&"v_separation", 5)
		c = g
	else:
		c = HBoxContainer.new()
		c.add_theme_constant_override(&"separation", 5)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.add_child(c)
	return c


func _fld(parent: Container, label: String, key: String, val: float) -> void:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_lbl(label, 10))
	var e := LineEdit.new()
	e.text = str(snappedf(val, .01))
	e.add_theme_font_override(&"font", font)
	e.add_theme_font_size_override(&"font_size", 13)
	e.text_submitted.connect(func(t: String) -> void:
		if t.is_valid_float():
			_apply_field(key, t.to_float())
		_render_panel())
	e.focus_exited.connect(func() -> void:
		if e.text.is_valid_float():
			_apply_field(key, e.text.to_float()))
	v.add_child(e)
	parent.add_child(v)


func _chk(parent: Container, label: String, on: bool, fn: Callable) -> void:
	var c := CheckBox.new()
	c.text = label
	c.button_pressed = on
	c.add_theme_font_override(&"font", font)
	c.add_theme_font_size_override(&"font_size", 11)
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(fn)
	parent.add_child(c)


func _items() -> Array:
	match tab:
		"shape":
			return DevProps.SHAPES
		"prop":
			return DevProps.PROPS
		"vendor":
			return DevProps.VENDORS
		"enemy":
			return ENEMIES
		"weapon":
			var out: Array = []
			for w: Variant in Weapons.WEAPONS:
				out.append({"id": w.id, "name": w.name, "note": w.tag})
			return out
	return catalogue


func _pick(id: String) -> void:
	brush.cat = tab
	brush.id = id
	sel = null
	drag = null
	var d: Variant = _brush_def()
	if d != null:
		brush.size = Vector3(d.base[0], d.base[1], d.base[2])
		brush.color = d.color
		brush.yaw = 0.0
		brush.pitch = 0.0
		brush.roll = 0.0
		brush.collide = true
	ghost_key = ""
	tool = "place"
	_render_panel()


func _render_panel() -> void:
	if panel_box == null:
		return
	for c in panel_box.get_children():
		panel_box.remove_child(c)
		c.queue_free()
	var hd := _row()
	hd.add_child(_lbl("DEV TOOLS", 12))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(sp)
	hd.add_child(_lbl("F2", 11))
	var tr := _row(3)
	for i in TOOLS.size():
		var t: Array = TOOLS[i]
		tr.add_child(_btn("%d %s" % [i + 1, t[1]], func() -> void: _set_tool(t[0]), tool == t[0]))
	var tb := _row()
	for t: Array in TABS:
		tb.add_child(_btn(t[1], func() -> void:
			tab = t[0]
			_render_panel(), tab == t[0]))
	# the palette: long lists are paged so it never buries the rest of the panel
	var items := _items()
	var pal := _row(2)
	var pages := ceili(float(items.size()) / PAGE_SIZE)
	var pg := clampi(int(pal_page.get(tab, 0)), 0, maxi(0, pages - 1))
	pal_page[tab] = pg
	for i in range(pg * PAGE_SIZE, mini(items.size(), pg * PAGE_SIZE + PAGE_SIZE)):
		var d: Dictionary = items[i]
		pal.add_child(_btn(String(d.name) + "\n" + String(d.get("note", "")).left(46), func() -> void: _pick(d.id), brush.cat == tab and brush.id == d.id, true))
	if pages > 1:
		var pr := _row()
		var bp := _btn("< PREV", func() -> void:
			pal_page[tab] = pg - 1
			_render_panel())
		bp.disabled = pg == 0
		pr.add_child(bp)
		pr.add_child(_lbl("%d / %d" % [pg + 1, pages], 11))
		var bn := _btn("NEXT >", func() -> void:
			pal_page[tab] = pg + 1
			_render_panel())
		bn.disabled = pg >= pages - 1
		pr.add_child(bn)
	_props_ui()
	var tg := VBoxContainer.new()
	panel_box.add_child(tg)
	_chk(tg, "SNAP 0.5 M", snap, func(on: bool) -> void: snap = on)
	_chk(tg, "FREEZE ENEMY AI", freeze, func(on: bool) -> void:
		freeze = on
		Config.ai_freeze = 1 if on else 0)
	_chk(tg, "FIRST PERSON", Config.first_person, func(on: bool) -> void: Config.first_person = on)
	_chk(tg, "INVINCIBLE", god, func(on: bool) -> void: god = on)
	_chk(tg, "SHOW INFO BAR", show_info, func(on: bool) -> void: show_info = on)
	var ac := _row(2)
	var act := func(t: String, fn: Callable) -> void:
		ac.add_child(_btn(t, func() -> void:
			fn.call()
			_render_panel()))
	act.call("DUPLICATE", _duplicate)
	act.call("DELETE", _delete_sel)
	act.call("KILL ENEMIES", _kill_all)
	act.call("HEAL", func() -> void:
		var P: Player = Game.player
		if P != null:
			P.hp = P.max_hp
			P.dead = false
		Game.hud.toast("HEALED"))
	act.call("GIVE ALL WEAPONS", give_all)
	act.call("EMPTY WHEEL", empty_wheel)
	act.call("CLEAR OBJECTS", clear_props)
	act.call("CLEAR NPCS", clear_npcs)
	act.call("CLEAR ENEMIES", clear_enemies)
	act.call("CLEAR WEAPONS", clear_weapons)
	act.call("CLEAR ALL", func() -> void:
		clear_all()
		Game.hud.toast("CLEARED"))
	act.call("SAVE LAYOUT", save_layout)
	act.call("LOAD LAYOUT", load_layout)
	act.call("PLAYER TO 0,0", func() -> void:
		var P: Player = Game.player
		if P != null:
			P.x = 0.0
			P.z = 0.0
			P.y = 0.0
			P.vx = 0.0
			P.vz = 0.0
			P.vy = 0.0)
	panel_box.add_child(_lbl("Click = use the tool. Right-drag = orbit, wheel = zoom, WASD = walk. SHIFT while placing = mid-air; while dragging = up / down; CTRL while dragging = free. R rotates, Del removes, Ctrl+D duplicates.", 12, Color("#8f9cab"), true))


func _props_ui() -> void:
	var s: Variant = _subject()
	if s == null:
		panel_box.add_child(_lbl("Pick a shape, prop, NPC, enemy or weapon above, then click the world.", 12, Color("#8f9cab"), true))
		return
	panel_box.add_child(_lbl(s.title, 10))
	if s.kind == "prop" or s.kind == "brush":
		var is_p: bool = s.kind == "prop"
		var o: Variant = s.ref
		var size: Vector3 = o.size if is_p else o["size"]
		var r1 := _row(3)
		if s.def.has("kind") and DevProps.SHAPES.has(s.def):
			_fld(r1, "W", "sx", size.x)
			_fld(r1, "H", "sy", size.y)
			_fld(r1, "D", "sz", size.z)
		else:
			_fld(r1, "SCALE", "scale", size.x / float(s.def.base[0]))
		var r2 := _row(3)
		_fld(r2, "YAW", "yaw", o.yaw if is_p else o["yaw"])
		_fld(r2, "PITCH", "pitch", o.pitch if is_p else o["pitch"])
		_fld(r2, "ROLL", "roll", o.roll if is_p else o["roll"])
		if is_p:
			var r3 := _row(3)
			_fld(r3, "X", "px", o.x)
			_fld(r3, "Y", "py", o.y)
			_fld(r3, "Z", "pz", o.z)
		var r4 := _row()
		if not s.def.get("vendor", false):
			var cb := ColorPickerButton.new()
			cb.color = Color(o.color if is_p else o["color"])
			cb.custom_minimum_size = Vector2(60, 26)
			cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cb.color_changed.connect(func(c: Color) -> void: _apply_field("color", "#" + c.to_html(false)))
			r4.add_child(_lbl("COLOUR", 10))
			r4.add_child(cb)
		_chk(r4, "COLLIDES", o.collide if is_p else o["collide"], func(on: bool) -> void: _apply_field("collide", on))
		var pitch: float = o.pitch if is_p else o["pitch"]
		var roll: float = o.roll if is_p else o["roll"]
		if pitch != 0.0 or roll != 0.0:
			panel_box.add_child(_lbl("Tilted objects have no collision (colliders are upright only).", 12, Color("#8f9cab"), true))
		elif s.def.id == "sphere" or s.def.id == "cone":
			panel_box.add_child(_lbl("Collision is an upright cylinder.", 12, Color("#8f9cab"), true))
		elif s.def.get("vendor", false):
			panel_box.add_child(_lbl("Walk up to its front and press X to shop.", 12, Color("#8f9cab"), true))
	elif s.kind == "weapon":
		var d: Variant = s.ref
		var r1 := _row(3)
		_fld(r1, "X", "px", d.x)
		_fld(r1, "Y", "py", d.y)
		_fld(r1, "Z", "pz", d.z)
		var r2 := _row(3)
		_fld(r2, "MAG", "ammo", d.ammo)
		_fld(r2, "RESERVE", "reserve", d.reserve)
		panel_box.add_child(_lbl("Walk up to it and press X to put it on the weapon wheel.", 12, Color("#8f9cab"), true))
	else:
		var o: Variant = s.ref
		var yaw: float = rad_to_deg(o.yaw if s.kind == "npc" else o.rb.yaw)
		var r1 := _row(3)
		_fld(r1, "X", "px", o.x)
		_fld(r1, "Y", "py", o.y)
		_fld(r1, "Z", "pz", o.z)
		var r2 := _row(3)
		_fld(r2, "YAW", "yaw", fposmod(yaw, 360.0))
