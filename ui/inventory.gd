class_name Inventory
extends Control
## The pause terminal's INVENTORY page: three tabs (ARMS, ARMOR, IMPLANTS) of everything carried or owned, a turning 3D preview and a readout. Nothing is sold here: it equips through Combat, ArmorStore and PowerStore, exactly as the shops do. PauseMenu hosts it on its glass and feeds it input.
## Laid out in its own 960-wide page (PauseMenu gives the glass that logical size while it is up). The 3D view is the shops' shared VendorStage and their own subject builders, so a model is built once for both.

const W := 960.0
const TABS: Array[String] = ["ARMS", "ARMOR", "IMPLANTS"]
const MODES: Array[String] = ["w", "a", "p"]
const GROUPS: Array[Array] = [["CARRIED", "NOT CARRIED"], ["OWNED", "NOT OWNED"], ["INSTALLED", "NOT INSTALLED"]]
const COLS := 5
const GAP := 8.0
const LOADOUT_H := 86.0
const LINE := Color(0.431, 1.0, 0.667)
const INK_DARK := Color(0.0, 0.02, 0.008)
const PLATE := Color(0.012, 0.1, 0.048)
const PIT := Color(0.004, 0.045, 0.02)

## One square of a grid.
class Cell:
	var kind := "w"
	var id := ""
	var name := ""
	var tag := ""
	var note := ""              # the small line under the icon
	var icon: Texture2D = null
	var tint := CrtTheme.PH
	var owned := false
	var ref: Variant = null     # Weapons.Def, ArmorStore.Suit or the plasmid's catalogue entry
	var widx := -1              # weapons: the index in Weapons.WEAPONS (-1 = fists)
	var has_model := true
	var group := 0
	var rect := Rect2()
	var s := 0.0                # eased selection, 0..1


class Tab:
	var cells: Array[Cell] = []
	var sel := 0
	var heads: Array[Array] = []    # [label, Rect2, count text]


## What the readout box says about the selected cell.
class Readout:
	var head := ""
	var value := ""
	var frac := -1.0
	var warn := false
	var rows: Array[Array] = []     # [label, 0..1, value text]
	var desc := ""


var back := Callable()          # PauseMenu: return to the pause page
var is_open := false
var tab := 0
var _tabs: Array[Tab] = []
var _prev: TextureRect
var _over: Control
var _pm: ShaderMaterial
var _ga := 1.0                  # the alpha everything drawn right now is multiplied by
var _t := 0.0
var _open_t := 9.0
var _tab_t := 9.0
var _tab_dir := 1
var _sel_t := 9.0
var _eq_t := 9.0
var _deny_t := 9.0
var _msg := ""
var _msg_bad := false
var _msg_t := 9.0
var _cur := Rect2()
var _cur_snap := true
var _tab_x := -1.0
var _rep_d := Vector2i.ZERO
var _rep_t := 0.0
var _hits := {}                 # what the mouse can press: id -> Rect2
var _left := Rect2()
var _right := Rect2()
var _well := Rect2()
var _h := 720.0


func _init() -> void:
	name = "Inventory"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	for i in TABS.size():
		_tabs.append(Tab.new())
	_prev = TextureRect.new()
	_prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_prev.stretch_mode = TextureRect.STRETCH_SCALE
	_prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pm = CrtTheme.mat("res://ui/inventory_preview.gdshader")
	_prev.material = _pm
	add_child(_prev)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_over)
	add_child(_over)


## Boot warm-up (GameUi.warm_up): the page and its preview shader drawn once behind the boot screen.
func warm(on: bool) -> void:
	if on:
		_prev.texture = VendorMenu.ensure_stage().get_texture()
		layout()
	visible = on
	_prev.visible = on


func open() -> void:
	is_open = true
	visible = true
	_build_cells()
	for t: Tab in _tabs:      # each tab opens on what is in use
		for i in t.cells.size():
			if _in_use(t.cells[i]):
				t.sel = i
		t.sel = clampi(t.sel, 0, maxi(0, t.cells.size() - 1))
		for i in t.cells.size():
			t.cells[i].s = 1.0 if i == t.sel else 0.0
	_open_t = 0.0
	_tab_t = 0.0
	_sel_t = 9.0
	_eq_t = 9.0
	_deny_t = 9.0
	_msg = ""
	_cur_snap = true
	_tab_x = -1.0
	_rep_d = Vector2i.ZERO
	_prev.texture = VendorMenu.ensure_stage().get_texture()
	layout()
	_attach()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if VendorMenu.stage != null:
		VendorMenu.stage.render_target_update_mode = SubViewport.UPDATE_DISABLED


# ---- what there is ----

func _build_cells() -> void:
	for t: Tab in _tabs:
		t.cells.clear()
	var combat: Combat = Game.combat
	# ARMS: fists, the wheel's slots in order, then what is not carried
	var arms := _tabs[0]
	var f := Cell.new()
	f.id = "fists"
	f.name = "FISTS"
	f.tag = "UNARMED"
	f.note = "ALWAYS"
	f.icon = WeaponIcons.tex("fists")
	f.owned = true
	f.has_model = false
	arms.cells.append(f)
	if combat != null:
		for v: Variant in combat.slots:
			if v != null:
				arms.cells.append(_weapon_cell(int(v), true))
		for i in Weapons.WEAPONS.size():
			if combat.owned.has(i):
				continue
			if Weapons.ARENA_IDS.has(Weapons.WEAPONS[i].id) and not Weapons.arena_weapons_here():      # (as the shops: the arena prototypes show only where they belong)
				continue
			arms.cells.append(_weapon_cell(i, false))
	# ARMOR
	for pass_owned: bool in [true, false]:
		for i in ArmorStore.ARMOR_CATALOG.size():
			var a := ArmorStore.ARMOR_CATALOG[i]
			if ArmorStore.is_owned(a.id) != pass_owned:
				continue
			var c := Cell.new()
			c.kind = "a"
			c.id = a.id
			c.name = a.name
			c.tag = a.tag
			c.note = "MK %d" % i
			c.icon = ArmorShop.armor_icon(a.id)
			c.owned = pass_owned
			c.ref = a
			c.group = 0 if pass_owned else 1
			_tabs[1].cells.append(c)
	# IMPLANTS: installed, then the ones on sale, then the ones not made yet
	var ps: PowerStore = Game.power_store
	for rank in 3:
		for p: Dictionary in PlasmidCatalog.PLASMIDS:
			var own := ps != null and ps.is_owned(String(p["id"]))
			var r := 0 if own else (1 if p["available"] else 2)
			if r != rank:
				continue
			var c := Cell.new()
			c.kind = "p"
			c.id = String(p["id"])
			c.name = String(p["name"])
			c.tag = String(p["tag"])
			c.note = c.name
			c.icon = PlasmidShop.icon_tex(p)
			c.tint = CrtTheme.PH.lerp(Color.hex((int(p["color"]) << 8) | 0xff), 0.6)
			c.owned = own
			c.ref = p
			c.group = 0 if own else 1
			_tabs[2].cells.append(c)


func _weapon_cell(i: int, own: bool) -> Cell:
	var w := Weapons.WEAPONS[i]
	var c := Cell.new()
	c.id = w.id
	c.name = w.name
	c.tag = w.tag
	c.icon = WeaponIcons.tex(w.id)
	c.owned = own
	c.ref = w
	c.widx = i
	c.has_model = ResourceLoader.exists("res://assets/weapons/%s.glb" % w.id)
	c.group = 0 if own else 1
	return c


func _cell() -> Cell:
	var t := _tabs[tab]
	return t.cells[t.sel] if t.sel >= 0 and t.sel < t.cells.size() else null


func _in_use(c: Cell) -> bool:
	if not c.owned:
		return false
	match c.kind:
		"w":
			return Game.combat != null and Game.combat.cur == c.widx
		"a":
			return ArmorStore.is_equipped(c.id)
		_:
			return Game.power_store != null and Game.power_store.is_equipped(c.id)


## Rounds carried for a weapon cell (mag + reserve; the charge for an energy weapon), and the most it holds.
func _ammo(c: Cell) -> Vector2:
	var w: Weapons.Def = c.ref
	var combat: Combat = Game.combat
	if w == null or combat == null or not c.owned:
		return Vector2(0.0, float(w.max) if w != null else 0.0)
	if w.energy:
		return Vector2(combat.ammo[c.widx], 100.0)
	return Vector2(combat.ammo[c.widx] + combat.reserve[c.widx], float(w.max))


func _num(v: float) -> String:
	return "%d" % roundi(v) if is_equal_approx(v, roundf(v)) else "%.1f" % v


func _readout(c: Cell) -> Readout:
	var r := Readout.new()
	match c.kind:
		"w":
			if c.widx < 0:
				r.head = "AMMO"
				r.value = "NOT REQUIRED"
				r.desc = "The unarmed three-punch combo. Always with you."
				return r
			var w: Weapons.Def = c.ref
			var am := _ammo(c)
			r.frac = am.x / maxf(1.0, am.y) if c.owned else 0.0
			r.warn = c.owned and r.frac < 0.25
			if w.energy:
				r.head = "CHARGE"
				r.value = "%03d%%" % roundi(am.x) if c.owned else "---%"
			else:
				r.head = "AMMO"
				r.value = "%03d/%03d" % [roundi(am.x), roundi(am.y)] if c.owned else "---/%03d" % roundi(am.y)
			var dmg := w.dmg * w.pellets
			r.rows.append(["DAMAGE", dmg / 160.0, _num(dmg)])
			r.rows.append(["FIRE RATE", w.rate / 17.0, _num(w.rate) + "/S"])
			r.rows.append(["RANGE", w.range / 160.0, _num(w.range) + " M"])
			r.rows.append(["MAGAZINE", w.mag_size / 40.0, "%d" % w.mag_size])
			r.desc = WeaponShop.WEAPON_BLURB.get(w.id, "")
		"a":
			var a: ArmorStore.Suit = c.ref
			r.head = "MAKER"
			r.value = a.maker
			r.rows.append(["DAMAGE CUT", a.dr / 50.0, "%d%%" % roundi(a.dr)])
			if a.shield != null:
				r.rows.append(["SHIELD", a.shield.max / 60.0, "+%d" % roundi(a.shield.max)])
				r.rows.append(["RECHARGE", a.shield.rate / 12.0, _num(a.shield.rate) + "/S"])
			else:
				r.rows.append(["SHIELD", 0.0, "NONE"])
			r.desc = a.desc
		_:
			var p: Dictionary = c.ref
			r.head = "MANA"
			var mana: float = p.get("mana", -1.0)
			var mana_max: float = p.get("mana_max", -1.0)
			var drain: float = p.get("drain", -1.0)
			r.value = "---" if mana < 0.0 else (_num(mana) + "-" + _num(mana_max) if mana_max > 0.0 else _num(mana))
			if mana >= 0.0:
				r.rows.append(["PER CAST", mana / 50.0, _num(mana)])
			if mana_max > 0.0:
				r.rows.append(["FULL CHARGE", mana_max / 50.0, _num(mana_max)])
			if drain > 0.0:
				r.rows.append(["DRAIN", drain / 30.0, _num(drain) + "/S"])
			r.desc = p.get("desc", "UNAVAILABLE.")
	return r


# ---- layout ----

func layout() -> void:
	if size.x < 10.0:
		return
	_h = size.y
	var top := 82.0
	var bottom := _h - 60.0
	_left = Rect2(22.0, top, 440.0, bottom - top)
	_right = Rect2(_left.end.x + 14.0, top, W - 22.0 - _left.end.x - 14.0, bottom - top)
	_well = Rect2(_right.position, Vector2(_right.size.x, floorf(_right.size.y * 0.47)))
	_over.size = size
	for ti in _tabs.size():
		var t := _tabs[ti]
		t.heads.clear()
		var x0 := _left.position.x + 14.0
		var inner := _left.size.x - 28.0
		var y := _left.position.y + 44.0
		var avail := _left.end.y - 12.0 - y - LOADOUT_H - 8.0
		var rows := 0
		var heads := 0
		var counts := [0, 0]
		for c: Cell in t.cells:
			counts[c.group] += 1
		for g in 2:
			if counts[g] > 0:
				heads += 1
				rows += ceili(counts[g] / float(COLS))
		var full := (inner - GAP * (COLS - 1)) / COLS
		var cs := clampf((avail - heads * 26.0) / maxf(1.0, rows) - GAP, 36.0, full)
		for g in 2:
			if counts[g] == 0:
				continue
			var cnt := "%02d" % counts[g]
			if ti == 0 and g == 0:
				cnt = "%02d / %02d" % [counts[g] - 1, Weapons.WHEEL_WEAPONS]      # (the fists do not take a slot)
			t.heads.append([GROUPS[ti][g], Rect2(x0, y, inner, 18.0), cnt])
			y += 26.0
			var k := 0
			for c: Cell in t.cells:
				if c.group != g:
					continue
				c.rect = Rect2(x0 + (k % COLS) * (cs + GAP), y + (k / COLS) * (cs + GAP), cs, cs)
				k += 1
			y += ceili(counts[g] / float(COLS)) * (cs + GAP) + 4.0
	_hits.clear()
	var lo := Rect2(_left.position.x + 14.0, _left.end.y - 12.0 - LOADOUT_H, _left.size.x - 28.0, LOADOUT_H)
	for i in TABS.size():
		_hits["tab%d" % i] = Rect2(74.0 + i * 158.0, 24.0, 150.0, 36.0)
		_hits["lo%d" % i] = Rect2(lo.position.x + i * lo.size.x / 3.0, lo.position.y, lo.size.x / 3.0, lo.size.y)
	_cur_snap = true


# ---- the 3D preview ----

func _attach() -> void:
	var st := VendorMenu.ensure_stage()
	st.attach(MODES[tab])
	for m: StandardMaterial3D in [st.deck_m, st.halo_m, st.pool_m]:      # the deck in the terminal's own light, not a vendor's
		m.albedo_color = Color(0.7, 1.0, 0.8, m.albedo_color.a)
	_show(true)


func _show(instant: bool) -> void:
	var c := _cell()
	_prev.visible = c != null and c.has_model
	if c == null or not c.has_model:
		return
	var shops: Shops = Game.shops
	var build := func() -> Node3D:
		if shops == null:
			return Node3D.new()
		match c.kind:
			"w":
				return shops.shop.build_subject(c.ref)
			"a":
				return shops.armory.build_subject(c.ref)
			_:
				return shops.plasmids.build_subject(c.ref)
	VendorMenu.ensure_stage().show_subject(MODES[tab] + ":" + c.id, build, instant)


# ---- input (PauseMenu calls these while the page is up) ----

func update(dt: float) -> void:
	var pad := Inp.using_pad
	var td := 0
	if Inp.key_hit(KEY_Q):
		td = -1
	elif Inp.key_hit(KEY_E) or Inp.key_hit(KEY_TAB):
		td = 1
	elif pad and Inp.btn(&"strafe").pressed:
		td = -1
	elif pad and Inp.btn(&"crouch").pressed:
		td = 1
	if td != 0:
		set_tab(posmod(tab + td, TABS.size()))
		return
	for i in TABS.size():
		if Inp.key_hit(KEY_1 + i):
			set_tab(i)
			return
	if Inp.key_hit(KEY_BACKSPACE) or Inp.key_hit(KEY_I) or (pad and Inp.btn(&"b").pressed):
		_back()
		return
	if Inp.btn(&"jump").pressed or Inp.key_hit(KEY_ENTER) or Inp.key_hit(KEY_KP_ENTER):
		equip()
		return
	# the keyboard steps on every press and OS repeat
	var kd := Vector2i.ZERO
	if Inp.key_hit(KEY_LEFT, true) or Inp.key_hit(KEY_A, true):
		kd.x = -1
	elif Inp.key_hit(KEY_RIGHT, true) or Inp.key_hit(KEY_D, true):
		kd.x = 1
	elif Inp.key_hit(KEY_UP, true) or Inp.key_hit(KEY_W, true):
		kd.y = -1
	elif Inp.key_hit(KEY_DOWN, true) or Inp.key_hit(KEY_S, true):
		kd.y = 1
	if kd != Vector2i.ZERO:
		_move(kd)
		return
	# the pad: d-pad or stick, held to repeat
	var d := Vector2i.ZERO
	if Inp.btn(&"d_left").held:
		d.x = -1
	elif Inp.btn(&"d_right").held:
		d.x = 1
	elif Inp.btn(&"d_up").held:
		d.y = -1
	elif Inp.btn(&"d_down").held:
		d.y = 1
	elif Vector2(Inp.raw_lx, Inp.raw_ly).length() > 0.55:
		if absf(Inp.raw_lx) >= absf(Inp.raw_ly):
			d.x = int(signf(Inp.raw_lx))
		else:
			d.y = int(signf(Inp.raw_ly))
	if d != _rep_d:
		_rep_d = d
		_rep_t = 0.26
		if d != Vector2i.ZERO:
			_move(d)
	elif d != Vector2i.ZERO:
		_rep_t -= dt
		if _rep_t <= 0.0:
			_rep_t = 0.085
			_move(d)


func mouse_move(p: Vector2) -> void:
	var t := _tabs[tab]
	for i in t.cells.size():
		if i != t.sel and t.cells[i].rect.has_point(p):
			_select(i)
			return


func mouse_click(p: Vector2) -> void:
	for id: String in _hits:
		if (_hits[id] as Rect2).has_point(p):
			if id.begins_with("tab"):
				set_tab(int(id.substr(3)))
			elif id.begins_with("lo"):
				set_tab(int(id.substr(2)))
			elif id == "back":
				_back()
			elif id == "equip":
				equip()
			return
	var t := _tabs[tab]
	for i in t.cells.size():
		if t.cells[i].rect.has_point(p):
			if i != t.sel:
				_select(i, true)
			equip()
			return


func _back() -> void:
	CrtTheme.menu_sound("pauseConfirm")
	if back.is_valid():
		back.call()


func set_tab(i: int) -> void:
	if i == tab:
		return
	_tab_dir = 1 if i > tab else -1
	tab = i
	_tab_t = 0.0
	_sel_t = 9.0
	_cur_snap = true
	_msg = ""
	CrtTheme.menu_sound("pauseConfirm")
	_attach()


func _move(d: Vector2i) -> void:
	var t := _tabs[tab]
	var n := t.cells.size()
	if n == 0:
		return
	var i := t.sel
	if d.x != 0:
		i = posmod(i + d.x, n)
	else:
		var here := t.cells[i].rect.position
		var best := -1
		var best_k := INF
		for j in n:      # the nearest cell in the next row that way
			var q := t.cells[j].rect.position
			var dy := (q.y - here.y) * d.y
			if dy < 1.0:
				continue
			var k := dy * 1000.0 + absf(q.x - here.x)
			if k < best_k:
				best_k = k
				best = j
		if best < 0:      # off the end: round to the far row
			for j in n:
				var q := t.cells[j].rect.position
				var k := q.y * d.y * 1000.0 + absf(q.x - here.x)
				if k < best_k:
					best_k = k
					best = j
		i = best
	_select(i)


func _select(i: int, quiet: bool = false) -> void:
	var t := _tabs[tab]
	if i < 0 or i >= t.cells.size() or i == t.sel:
		return
	t.sel = i
	_sel_t = 0.0
	_msg = ""
	if not quiet:
		CrtTheme.menu_sound("pauseNav")
	_show(false)


## Put the selected thing to use, through the same calls the shops make.
func equip() -> void:
	var c := _cell()
	if c == null:
		return
	if not c.owned:
		_deny(GROUPS[tab][1])
		return
	if _in_use(c):
		_say("ALREADY IN USE", false)
		CrtTheme.menu_sound("pauseNav")
		return
	var ok := true
	match c.kind:
		"w":
			Game.combat.equip(c.widx)
			ok = Game.combat.cur == c.widx
		"a":
			ok = ArmorStore.equip(c.id).ok
		_:
			ok = Game.power_store.equip(c.id).ok
	if not ok:
		_deny("CANNOT EQUIP")
		return
	_eq_t = 0.0
	_say(c.name + " IN USE", false)
	CrtTheme.menu_sound("confirm")


func _deny(m: String) -> void:
	_deny_t = 0.0
	_say(m, true)
	CrtTheme.menu_sound("deny")


func _say(m: String, bad: bool) -> void:
	_msg = m
	_msg_bad = bad
	_msg_t = 0.0


# ---- the frame ----

func frame(dt: float) -> void:
	if not is_open:
		return
	_t += dt
	_open_t += dt
	_tab_t += dt
	_sel_t += dt
	_eq_t += dt
	_deny_t += dt
	_msg_t += dt
	var ke := 1.0 - exp(-dt / 0.045)
	var t := _tabs[tab]
	for i in t.cells.size():
		var c := t.cells[i]
		c.s += ((1.0 if i == t.sel else 0.0) - c.s) * ke
	var cur := _cell()
	if cur != null:
		if _cur_snap:
			_cur = cur.rect
			_cur_snap = false
		else:
			_cur = Rect2(_cur.position.lerp(cur.rect.position, ke), _cur.size.lerp(cur.rect.size, ke))
	var tx: float = (_hits["tab%d" % tab] as Rect2).position.x
	_tab_x = tx if _tab_x < 0.0 else lerpf(_tab_x, tx, 1.0 - exp(-dt / 0.06))
	# the preview
	var st := VendorMenu.ensure_stage()
	var inner := _well.grow(-3.0)
	var sc := float(get_viewport().size.x) / maxf(1.0, size.x)
	st.set_view_size(Vector2i(maxi(2, roundi(inner.size.x * sc)), maxi(2, roundi(inner.size.y * sc))))
	st.frame(dt)
	var e := _body_e()
	_prev.position = inner.position + Vector2(_tab_dir * 22.0 * (1.0 - e), 0.0)
	_prev.size = inner.size
	_prev.modulate = Color(1, 1, 1, e * (1.0 if cur != null and cur.owned else 0.42))
	_pm.set_shader_parameter(&"reveal", st.reveal)
	_pm.set_shader_parameter(&"vertical", st.reveal_v)
	_pm.set_shader_parameter(&"lines", inner.size.y * sc / 3.0)
	queue_redraw()
	_over.queue_redraw()


## the body's slide-in after a tab change (and on open)
func _body_e() -> float:
	return CrtTheme.bezier(clampf(_tab_t / 0.2, 0.0, 1.0), 0.2, 0.8, 0.2, 1.0)


# ---- drawing: small pieces ----

func _c(col: Color, a: float = 1.0) -> Color:
	return Color(col.r, col.g, col.b, col.a * a * _ga)


func _tx(ci: CanvasItem, f: Font, x: float, y: float, text: String, fs: int, col: Color, sp: float = 0.0) -> float:
	return CrtTheme.draw_text(ci, f, x, y, text, fs, _c(col), sp)


## A raised steel plate: lit top and left edge, shadowed bottom and right, a rivet in each corner.
func _plate(ci: CanvasItem, r: Rect2, rivets: bool = true) -> void:
	CrtTheme.glow_box(ci, r, _c(LINE, 0.14), 8.0)
	ci.draw_rect(r, _c(PLATE, 0.9))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, minf(26.0, r.size.y * 0.42))), _c(LINE, 0.035))
	CrtTheme.glow_box(ci, r, _c(LINE, 0.1), 12.0, true)
	ci.draw_rect(r, _c(LINE, 0.6), false, 1.0)
	var a := r.position + Vector2(1.5, 1.5)
	var b := r.end - Vector2(1.5, 1.5)
	ci.draw_line(a, Vector2(b.x, a.y), _c(CrtTheme.PH_HI, 0.55), 1.0)
	ci.draw_line(a, Vector2(a.x, b.y), _c(CrtTheme.PH_HI, 0.4), 1.0)
	ci.draw_line(Vector2(a.x, b.y), b, _c(Color.BLACK, 0.6), 1.0)
	ci.draw_line(Vector2(b.x, a.y), b, _c(Color.BLACK, 0.5), 1.0)
	if rivets:
		for p: Vector2 in [Vector2(a.x + 5.0, a.y + 5.0), Vector2(b.x - 5.0, a.y + 5.0), Vector2(a.x + 5.0, b.y - 5.0), Vector2(b.x - 5.0, b.y - 5.0)]:
			ci.draw_circle(p + Vector2(0.6, 0.6), 1.9, _c(Color.BLACK, 0.6))
			ci.draw_circle(p, 1.7, _c(LINE, 0.55))
			ci.draw_circle(p - Vector2(0.5, 0.5), 0.6, _c(CrtTheme.PH_WHITE, 0.8))


## A recessed well: dark glass, shadow under its top and left lip, light caught on the bottom and right.
func _pit(ci: CanvasItem, r: Rect2, lit: float = 0.14) -> void:
	ci.draw_rect(r, _c(PIT, 0.94))
	CrtTheme.glow_box(ci, r, _c(LINE, lit), 30.0, true)
	CrtTheme.glow_box(ci, r, _c(Color.BLACK, 0.85), 10.0, true)
	ci.draw_rect(r, _c(LINE, 0.5), false, 1.0)
	var a := r.position + Vector2(1.5, 1.5)
	var b := r.end - Vector2(1.5, 1.5)
	ci.draw_line(a, Vector2(b.x, a.y), _c(Color.BLACK, 0.8), 1.0)
	ci.draw_line(a, Vector2(a.x, b.y), _c(Color.BLACK, 0.7), 1.0)
	ci.draw_line(Vector2(a.x, b.y), b, _c(CrtTheme.PH_HI, 0.4), 1.0)
	ci.draw_line(Vector2(b.x, a.y), b, _c(CrtTheme.PH_HI, 0.3), 1.0)


## A bar of n blocks, lit up to v (0..1).
func _segs(ci: CanvasItem, r: Rect2, v: float, n: int, col: Color) -> void:
	var w := (r.size.x - 2.0 * (n - 1)) / n
	var lit := clampf(v, 0.0, 1.0) * n
	for i in n:
		var sr := Rect2(r.position.x + i * (w + 2.0), r.position.y, w, r.size.y)
		ci.draw_rect(sr, _c(LINE, 0.11))
		var f := clampf(lit - i, 0.0, 1.0)
		if f > 0.0:
			ci.draw_rect(Rect2(sr.position, Vector2(w * f, sr.size.y)), _c(col))
			ci.draw_rect(Rect2(sr.position, Vector2(w * f, 1.0)), _c(CrtTheme.PH_WHITE, 0.55))


## A key cap. Returns its width.
func _key(ci: CanvasItem, x: float, y: float, h: float, label: String) -> float:
	var f := CrtTheme.font(&"raj700")
	var w := maxf(h + 2.0, CrtTheme.text_w(f, label, 12, 0.6) + 12.0)
	var r := Rect2(x, y, w, h)
	ci.draw_rect(r, _c(Color(0.02, 0.16, 0.08), 0.92))
	ci.draw_rect(Rect2(x, r.end.y - 3.0, w, 3.0), _c(LINE, 0.32))
	ci.draw_rect(r, _c(LINE, 0.75), false, 1.0)
	CrtTheme.draw_center(ci, f, x + w * 0.5 + 0.3, CrtTheme.baseline(f, 12, y, h - 2.0), label, 12, _c(CrtTheme.PH_WHITE), 0.6)
	return w


## Four corner brackets around a rectangle.
func _brackets(ci: CanvasItem, r: Rect2, arm: float, col: Color, width: float) -> void:
	for sx: float in [0.0, 1.0]:
		for sy: float in [0.0, 1.0]:
			var p := Vector2(r.position.x + r.size.x * sx, r.position.y + r.size.y * sy)
			var dx := arm if sx == 0.0 else -arm
			var dy := arm if sy == 0.0 else -arm
			ci.draw_polyline(PackedVector2Array([p + Vector2(dx, 0.0), p, p + Vector2(0.0, dy)]), col, width)


func _hatch(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var o := -r.size.y
	while o < r.size.x:
		var t0 := maxf(0.0, -o)
		var t1 := minf(r.size.y, r.size.x - o)
		if t0 < t1:
			ci.draw_line(Vector2(r.position.x + o + t0, r.end.y - t0), Vector2(r.position.x + o + t1, r.end.y - t1), col, 1.0)
		o += 9.0


func _icon(ci: CanvasItem, tex: Texture2D, box: Rect2, col: Color) -> void:
	if tex == null:
		return
	var ts := tex.get_size()
	var k := minf(box.size.x / ts.x, box.size.y / ts.y)
	var sz := ts * k
	ci.draw_texture_rect(tex, Rect2(box.get_center() - sz * 0.5, sz), false, col)


# ---- drawing: the page ----

func _draw() -> void:
	if _tabs.is_empty() or size.x < 10.0:
		return
	_ga = clampf(_open_t / 0.2, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), _c(Color(0.0, 0.035, 0.014), 0.74))      # the glass goes dark behind the page, so the lit lines carry it
	_draw_header()
	_ga = _body_e()
	draw_set_transform(Vector2(_tab_dir * 22.0 * (1.0 - _ga), 0.0))
	_draw_grid()
	_draw_detail()
	draw_set_transform(Vector2.ZERO)
	_draw_footer()
	_ga = 1.0


func _draw_header() -> void:
	var e := CrtTheme.bezier(clampf(_open_t / 0.22, 0.0, 1.0), 0.2, 0.8, 0.2, 1.0)
	_ga = e
	draw_set_transform(Vector2(0.0, -12.0 * (1.0 - e)))
	var bar := Rect2(22.0, 14.0, W - 44.0, 56.0)
	_plate(self, bar)
	var pad := Inp.using_pad
	var orb := CrtTheme.font(&"orb700")
	var raj := CrtTheme.font(&"raj700")
	var vt := CrtTheme.font(&"vt323")
	_key(self, 38.0, 32.0, 20.0, "LB" if pad else "Q")
	# the lit tab slides under the labels
	var ir := Rect2(_tab_x, 24.0, 150.0, 36.0)
	for i in TABS.size():
		var r: Rect2 = _hits["tab%d" % i]
		_pit(self, r, 0.08)
	CrtTheme.glow_box(self, ir, _c(LINE, 0.5), 14.0)
	draw_rect(ir, _c(LINE, 0.3))
	draw_rect(ir, _c(CrtTheme.PH_HI), false, 1.5)
	draw_rect(Rect2(ir.position.x, ir.end.y - 4.0, ir.size.x, 4.0), _c(CrtTheme.PH_WHITE))
	for i in TABS.size():
		var r: Rect2 = _hits["tab%d" % i]
		var on := clampf(1.0 - absf(_tab_x - r.position.x) / 60.0, 0.0, 1.0)
		var col := CrtTheme.PH_LOW.lerp(CrtTheme.PH_WHITE, on)
		_tx(self, vt, r.position.x + 7.0, r.position.y + 13.0, "%d" % (i + 1), 13, CrtTheme.PH_LOW.lerp(CrtTheme.PH_HI, on))
		CrtTheme.draw_center(self, orb, r.get_center().x + 1.5, CrtTheme.baseline(orb, 15, r.position.y, r.size.y), TABS[i], 15, _c(col), 3.0)
	_key(self, 74.0 + TABS.size() * 158.0 + 4.0, 32.0, 20.0, "RB" if pad else "E")
	# cash and health, at the right
	var rx := bar.end.x - 18.0
	var cash := CrtTheme.money(Game.money)
	var cw := CrtTheme.text_w(orb, cash, 19, 1.0)
	_tx(self, orb, rx - cw, 39.0, cash, 19, CrtTheme.PH_HI, 1.0)
	CrtTheme.draw_right(self, raj, rx - cw - 8.0, 39.0, "CASH", 11, _c(CrtTheme.PH_LOW), 2.6)
	var hp: float = Game.player.hp if Game.player != null else 0.0
	var mhp: float = Game.player.max_hp if Game.player != null else 100.0
	var frac := clampf(hp / maxf(1.0, mhp), 0.0, 1.0)
	var hs := "%03d" % roundi(hp)
	var hw := CrtTheme.text_w(vt, hs, 18)
	_tx(self, vt, rx - hw, 60.0, hs, 18, CrtTheme.AMBER if frac < 0.3 else CrtTheme.PH_HI)
	var br := Rect2(rx - hw - 8.0 - 150.0, 49.0, 150.0, 9.0)
	_segs(self, br, frac, 20, CrtTheme.AMBER if frac < 0.3 else CrtTheme.PH)
	CrtTheme.draw_right(self, raj, br.position.x - 8.0, 58.0, "INTEGRITY", 11, _c(CrtTheme.PH_LOW), 2.6)
	draw_set_transform(Vector2.ZERO)


func _draw_grid() -> void:
	var t := _tabs[tab]
	var vt := CrtTheme.font(&"vt323")
	var vtb := CrtTheme.font(&"vt323b")
	var raj := CrtTheme.font(&"raj700")
	_plate(self, _left)
	# the title strip
	var x0 := _left.position.x + 14.0
	var by := _left.position.y + 28.0
	var x := _tx(self, vtb, x0, by, "C:\\INV\\", 22, CrtTheme.PH_DIM, 1.0)
	x = _tx(self, vtb, x, by, TABS[tab], 22, CrtTheme.PH_HI, 3.0)
	if fmod(_t, 1.0) < 0.5:
		_tx(self, vtb, x, by, "_", 22, CrtTheme.PH_HI)
	draw_rect(Rect2(x0, _left.position.y + 36.0, _left.size.x - 28.0, 1.0), _c(LINE, 0.4))
	for h: Array in t.heads:
		var hr: Rect2 = h[1]
		var lab: String = h[0]
		var lw := CrtTheme.text_w(raj, lab, 11, 2.6) + 14.0
		draw_rect(Rect2(hr.position, Vector2(lw, hr.size.y)), _c(LINE, 0.2))
		draw_rect(Rect2(hr.position, Vector2(3.0, hr.size.y)), _c(CrtTheme.PH))
		_tx(self, raj, hr.position.x + 9.0, CrtTheme.baseline(raj, 11, hr.position.y, hr.size.y), lab, 11, CrtTheme.PH_HI, 2.6)
		var cnt: String = h[2]
		var cwid := CrtTheme.text_w(vt, cnt, 16)
		_tx(self, vt, hr.end.x - cwid, CrtTheme.baseline(vt, 16, hr.position.y, hr.size.y), cnt, 16, CrtTheme.PH_LOW)
		var dx := hr.position.x + lw + 8.0
		var my := hr.position.y + hr.size.y * 0.5
		while dx < hr.end.x - cwid - 10.0:
			draw_rect(Rect2(dx, my, 3.0, 1.0), _c(LINE, 0.35))
			dx += 7.0
	for i in t.cells.size():
		_draw_cell(t.cells[i], i, i == t.sel)
	_draw_loadout()
	# the cursor: bright brackets that slide to the cell and settle
	var pop := 1.0 - CrtTheme.bezier(clampf(_sel_t / 0.18, 0.0, 1.0), 0.2, 0.9, 0.3, 1.0)
	var cr := _cur.grow(3.0 + 6.0 * pop + 0.9 * sin(_t * 5.5))
	var shake := 5.0 * sin(_deny_t * 60.0) * (1.0 - clampf(_deny_t / 0.28, 0.0, 1.0))
	cr.position.x += shake
	var hot := CrtTheme.AMBER if _deny_t < 0.28 else CrtTheme.PH_WHITE
	_brackets(self, cr, 11.0, _c(LINE, 0.45), 6.0)
	_brackets(self, cr, 11.0, _c(hot), 2.4)


## The foot of the left panel: what is in hand, worn and installed right now, whichever tab is up. A column is a shortcut to its tab.
func _draw_loadout() -> void:
	var vt := CrtTheme.font(&"vt323")
	var raj := CrtTheme.font(&"raj700")
	var heads: Array[String] = ["IN HAND", "WORN", "IMPLANT"]
	for i in TABS.size():
		var r: Rect2 = (_hits["lo%d" % i] as Rect2).grow_individual(0.0, 0.0, -6.0 if i < 2 else 0.0, 0.0)
		var used: Cell = null
		for c: Cell in _tabs[i].cells:
			if _in_use(c):
				used = c
		_pit(self, r, 0.16 if i == tab else 0.05)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 15.0)), _c(LINE, 0.26 if i == tab else 0.12))
		_tx(self, raj, r.position.x + 7.0, CrtTheme.baseline(raj, 10, r.position.y, 15.0), heads[i], 10, CrtTheme.PH_HI if i == tab else CrtTheme.PH_LOW, 2.4)
		var nm := used.name if used != null else "NONE"
		if used != null:
			_icon(self, used.icon, Rect2(r.position.x + 8.0, r.position.y + 20.0, r.size.x - 16.0, 36.0), _c(used.tint if used.kind == "p" else CrtTheme.PH))
		var fs := 15
		while fs > 10 and CrtTheme.text_w(vt, nm, fs) > r.size.x - 10.0:
			fs -= 1
		CrtTheme.draw_center(self, vt, r.get_center().x, r.end.y - 9.0, nm, fs, _c(CrtTheme.PH_BTN if used != null else CrtTheme.PH_LOW))


func _draw_cell(c: Cell, i: int, sel: bool) -> void:
	var vt := CrtTheme.font(&"vt323")
	var raj := CrtTheme.font(&"raj700")
	# the cells drop in one after another when the page opens or the tab changes
	var pop := clampf((_tab_t - 0.03 - i * 0.012) / 0.15, 0.0, 1.0)
	if pop <= 0.0:
		return
	var k := lerpf(0.7, 1.0, CrtTheme.bezier(pop, 0.2, 0.9, 0.3, 1.3))
	var ga := _ga
	_ga *= pop
	var mid := c.rect.get_center()
	var r := Rect2(mid - c.rect.size * 0.5 * k, c.rect.size * k)
	var used := _in_use(c)
	_pit(self, r, 0.06 + 0.2 * c.s if c.owned else 0.02)
	if c.s > 0.01:
		draw_rect(r.grow(-2.0), _c(LINE, 0.13 * c.s))
	if not c.owned:
		_hatch(self, r.grow(-3.0), _c(LINE, 0.1))
	if used:
		draw_rect(r, _c(CrtTheme.PH_HI, 0.9), false, 1.5)
	var s := r.size.x
	var box := Rect2(r.position + Vector2(s * 0.1, s * 0.2), Vector2(s * 0.8, s * 0.48))
	box = box.grow(s * 0.05 * c.s)
	var ic := c.tint.lerp(CrtTheme.PH_WHITE, 0.55 * c.s)
	if c.kind != "p" and not sel:
		ic = CrtTheme.PH
	if c.owned:
		_icon(self, c.icon, box.grow(1.5), _c(LINE, 0.22))      # a little bloom under the lines
	_icon(self, c.icon, box, _c(ic, 1.0 if c.owned else 0.3))
	_tx(self, vt, r.position.x + 5.0, r.position.y + 12.0, "%02d" % (i + 1), 12, CrtTheme.PH_LOW, 0.5)
	# the foot of the cell: IN USE, or the count
	var foot := Rect2(r.position.x + 2.0, r.end.y - 15.0, s - 4.0, 13.0)
	if used:
		var wipe := CrtTheme.bezier(clampf(_eq_t / 0.2, 0.0, 1.0), 0.2, 0.8, 0.2, 1.0) if sel else 1.0
		draw_rect(Rect2(foot.position, Vector2(foot.size.x * wipe, foot.size.y)), _c(CrtTheme.PH, 0.92))
		if wipe > 0.6:
			CrtTheme.draw_center(self, raj, foot.get_center().x + 0.8, CrtTheme.baseline(raj, 11, foot.position.y, foot.size.y), "IN USE", 11, _c(INK_DARK), 1.4)
	else:
		var note := c.note
		var col := CrtTheme.PH_BTN
		if c.kind == "w" and c.widx >= 0 and c.owned:
			var am := _ammo(c)
			var w: Weapons.Def = c.ref
			note = "%d%%" % roundi(am.x) if w.energy else "%d" % roundi(am.x)
			if am.x / maxf(1.0, am.y) < 0.25:
				col = CrtTheme.AMBER
		elif c.kind == "w" and not c.owned:
			note = ""
		var fs := 13
		while fs > 9 and CrtTheme.text_w(vt, note, fs) > foot.size.x - 4.0:
			fs -= 1
		CrtTheme.draw_center(self, vt, foot.get_center().x, CrtTheme.baseline(vt, fs, foot.position.y, foot.size.y), note, fs, _c(col, 1.0 if c.owned else 0.4))
	# equipping: a flash and a ring that runs out from the cell
	if sel and _eq_t < 0.36:
		var q := _eq_t / 0.36
		draw_rect(r, _c(CrtTheme.PH_WHITE, 0.6 * (1.0 - q) * (1.0 - q)))
		draw_rect(r.grow(16.0 * CrtTheme.bezier(q, 0.2, 0.8, 0.2, 1.0)), _c(CrtTheme.PH_WHITE, 0.9 * (1.0 - q)), false, 2.0)
	_ga = ga


func _draw_detail() -> void:
	var c := _cell()
	var vt := CrtTheme.font(&"vt323")
	var raj := CrtTheme.font(&"raj700")
	var orb := CrtTheme.font(&"orb700")
	# the preview well: a drafting grid behind the model
	_pit(self, _well, 0.22)
	var inr := _well.grow(-3.0)
	var gx := inr.position.x + fmod(inr.size.x * 0.5, 26.0)
	while gx < inr.end.x:
		draw_rect(Rect2(gx, inr.position.y, 1.0, inr.size.y), _c(LINE, 0.055))
		gx += 26.0
	var gy := inr.position.y + fmod(inr.size.y * 0.5, 26.0)
	while gy < inr.end.y:
		draw_rect(Rect2(inr.position.x, gy, inr.size.x, 1.0), _c(LINE, 0.055))
		gy += 26.0
	if c == null:
		return
	# the name plate
	var np := Rect2(_right.position.x, _well.end.y + 10.0, _right.size.x, 60.0)
	_plate(self, np)
	var se := CrtTheme.bezier(clampf(_sel_t / 0.16, 0.0, 1.0), 0.2, 0.8, 0.3, 1.0)
	var ga := _ga
	_ga *= lerpf(0.15, 1.0, se)
	var sx := 12.0 * (1.0 - se)
	var fs := 24
	while fs > 13 and CrtTheme.text_w(orb, c.name, fs, 1.6) > np.size.x - 40.0:
		fs -= 1
	_tx(self, orb, np.position.x + 18.0 + sx, np.position.y + 30.0, c.name, fs, CrtTheme.PH_WHITE, 1.6)
	_tx(self, raj, np.position.x + 18.0 + sx, np.position.y + 48.0, c.tag, 11, CrtTheme.PH_DIM, 3.2)
	_ga = ga
	if _eq_t < 0.45:      # equipping: a band of light runs across the plate
		var q := _eq_t / 0.45
		var bx := np.position.x + (np.size.x + 120.0) * q - 120.0
		var x0 := maxf(np.position.x + 2.0, bx)
		var x1 := minf(np.end.x - 2.0, bx + 120.0)
		if x1 > x0:
			draw_rect(Rect2(x0, np.position.y + 2.0, x1 - x0, np.size.y - 4.0), _c(CrtTheme.PH_WHITE, 0.3 * (1.0 - q)))
	# the readout
	var rb := Rect2(_right.position.x, np.end.y + 10.0, _right.size.x, _right.end.y - np.end.y - 10.0)
	_pit(self, rb, 0.1)
	var ro := _readout(c)
	ga = _ga
	_ga *= lerpf(0.15, 1.0, se)
	var x := rb.position.x + 18.0 + sx
	var cw := rb.size.x - 36.0
	var y := rb.position.y + 12.0
	var grow := CrtTheme.bezier(clampf(_sel_t / 0.32, 0.0, 1.0), 0.2, 0.8, 0.2, 1.0)
	var warn_c := CrtTheme.AMBER if ro.warn else CrtTheme.PH_HI
	_tx(self, raj, x, y + 22.0, ro.head, 12, CrtTheme.PH_LOW, 2.8)
	var vs := 30
	while vs > 16 and CrtTheme.text_w(vt, ro.value, vs, 1.0) > cw - 90.0:
		vs -= 1
	CrtTheme.draw_right(self, vt, x + cw, y + 24.0, ro.value, vs, _c(warn_c), 1.0)
	y += 32.0
	if ro.frac >= 0.0:
		_segs(self, Rect2(x, y, cw, 9.0), ro.frac * grow, 30, CrtTheme.AMBER if ro.warn else CrtTheme.PH)
		y += 9.0
	y += 9.0
	draw_rect(Rect2(x, y, cw, 1.0), _c(LINE, 0.3))
	y += 8.0
	for row: Array in ro.rows:
		if y + 18.0 > rb.end.y - 8.0:
			break
		_tx(self, raj, x, y + 13.0, row[0], 11, CrtTheme.PH_LOW, 2.4)
		_segs(self, Rect2(x + 112.0, y + 4.0, cw - 112.0 - 64.0, 8.0), float(row[1]) * grow, 18, CrtTheme.PH)
		CrtTheme.draw_right(self, vt, x + cw, y + 14.0, row[2], 18, _c(CrtTheme.PH_HI))
		y += 19.0
	y += 5.0
	var ds := 15      # the blurb steps its type down until it fits the box
	var lines := CrtTheme.wrap(vt, ro.desc, ds, cw, 0.4)
	while ds > 12 and y + lines.size() * (ds + 0.5) > rb.end.y - 8.0:
		ds -= 1
		lines = CrtTheme.wrap(vt, ro.desc, ds, cw, 0.4)
	for ln: String in lines:
		if y + ds > rb.end.y - 6.0:
			break
		_tx(self, vt, x, y + ds * 0.8, ln, ds, CrtTheme.PH if c.owned else CrtTheme.PH_LOW, 0.4)
		y += ds + 0.5
	_ga = ga


func _draw_footer() -> void:
	_ga = clampf((_open_t - 0.12) / 0.16, 0.0, 1.0)
	var bar := Rect2(22.0, _h - 50.0, W - 44.0, 36.0)
	_plate(self, bar)
	var pad := Inp.using_pad
	var raj := CrtTheme.font(&"raj700")
	var vt := CrtTheme.font(&"vt323")
	var c := _cell()
	var eq := "EQUIP"
	if c != null and not c.owned:
		eq = "LOCKED"
	elif c != null and _in_use(c):
		eq = "IN USE"
	var list: Array[Array] = [[["A" if pad else "ENTER"], eq, "equip"], [["LB", "RB"] if pad else ["Q", "E"], "TAB", ""], [["B" if pad else "BKSP"], "BACK", "back"], [["START" if pad else "ESC"], "RESUME", ""]]
	var x := bar.position.x + 16.0
	var ky := bar.position.y + 8.0
	for p: Array in list:
		var x0 := x
		for kname: String in p[0]:
			x += _key(self, x, ky, 20.0, kname) + 4.0
		var dim: bool = p[2] == "equip" and eq != "EQUIP"
		x = _tx(self, raj, x + 3.0, CrtTheme.baseline(raj, 12, ky, 19.0), p[1], 12, CrtTheme.PH_LOW if dim else CrtTheme.PH_BTN, 2.6)
		if p[2] != "":
			_hits[p[2]] = Rect2(x0 - 4.0, bar.position.y, x - x0 + 8.0, bar.size.y)
		x += 20.0
	if _msg != "":
		var a := clampf(_msg_t / 0.12, 0.0, 1.0)
		if _msg_t < 0.5 and fmod(_msg_t, 0.16) > 0.1:
			a *= 0.45
		var col := CrtTheme.AMBER if _msg_bad else CrtTheme.PH_HI
		var m := "> " + _msg
		CrtTheme.draw_right(self, vt, bar.end.x - 16.0 + 6.0 * (1.0 - a), CrtTheme.baseline(vt, 19, bar.position.y, bar.size.y), m, 19, _c(col, a), 1.2)


## Over the 3D view: the well's brackets, the status chip, the index, the scan front; the icon large when there is no model to turn.
func _draw_over() -> void:
	var c := _cell()
	if c == null:
		return
	_ga = _body_e()
	_over.draw_set_transform(Vector2(_tab_dir * 22.0 * (1.0 - _ga), 0.0))
	var vt := CrtTheme.font(&"vt323")
	var raj := CrtTheme.font(&"raj700")
	var inr := _well.grow(-3.0)
	if not c.has_model:
		var k := minf(inr.size.x * 0.56, inr.size.y * 1.1)
		var box := Rect2(inr.get_center() - Vector2(k, k * 0.5) * 0.5, Vector2(k, k * 0.5))
		_icon(_over, c.icon, box.grow(3.0), _c(LINE, 0.25))
		_icon(_over, c.icon, box, _c(c.tint, (0.85 + 0.15 * sin(_t * 2.2)) * (1.0 if c.owned else 0.35)))
	var st := VendorMenu.stage
	if st != null and c.has_model and st.edge_a > 0.0:      # the scan front that draws the model in
		var ec := _c(CrtTheme.PH_WHITE, st.edge_a)
		if st.reveal_v:
			_over.draw_rect(Rect2(inr.position.x + inr.size.x * 0.08, inr.end.y - inr.size.y * st.reveal - 1.0, inr.size.x * 0.84, 2.0), ec)
		else:
			_over.draw_rect(Rect2(inr.position.x + inr.size.x * st.reveal - 1.0, inr.position.y + inr.size.y * 0.1, 2.0, inr.size.y * 0.8), ec)
	_brackets(_over, inr.grow(-8.0), 16.0, _c(LINE, 0.75), 1.5)
	# the chip: IN USE inverted, owned outlined, locked in amber
	var used := _in_use(c)
	var lab: String = "IN USE" if used else GROUPS[tab][0 if c.owned else 1]
	var lw := CrtTheme.text_w(raj, lab, 11, 2.6) + 18.0
	var cr := Rect2(inr.position.x + 22.0, inr.position.y + 22.0, lw, 20.0)
	var col := CrtTheme.PH_HI if c.owned else CrtTheme.AMBER
	if used:
		_over.draw_rect(cr, _c(CrtTheme.PH, 0.92))
		_tx(_over, raj, cr.position.x + 10.0, CrtTheme.baseline(raj, 11, cr.position.y, cr.size.y), lab, 11, INK_DARK, 2.6)
	else:
		_over.draw_rect(cr, _c(PIT, 0.8))
		_over.draw_rect(cr, _c(col, 0.8), false, 1.0)
		_tx(_over, raj, cr.position.x + 10.0, CrtTheme.baseline(raj, 11, cr.position.y, cr.size.y), lab, 11, col, 2.6)
	var t := _tabs[tab]
	var idx := "%02d / %02d" % [t.sel + 1, t.cells.size()]
	CrtTheme.draw_right(_over, vt, inr.end.x - 22.0, inr.position.y + 38.0, idx, 20, _c(CrtTheme.PH_HI), 1.0)
	_tx(_over, raj, inr.position.x + 22.0, inr.end.y - 20.0, "PREVIEW // LIVE", 10, CrtTheme.PH_LOW, 2.6)
	CrtTheme.draw_right(_over, raj, inr.end.x - 22.0, inr.end.y - 20.0, c.id.to_upper().replace("_", " "), 10, _c(CrtTheme.PH_LOW), 2.6)
	_over.draw_set_transform(Vector2.ZERO)
	_ga = 1.0
