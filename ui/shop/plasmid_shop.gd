class_name PlasmidShop
extends VendorMenu
## DORBATELEPHINIUM IMPLANTS (JS class PlasmidShop): the implant vending machine's terminal. Buying a new implant closes the menu and the machine injects it (cutscenes/implant_inject.gd).

# ENGINE DIFFERENCE: the JS floods the picture's black screen out of it when it loads, and the hole it measures replaces the one in its config. tools/export/render-ui-cut.mjs did that once: the .cut.png and this hole are its output.
const ART := {"url": "res://assets/ui/dorpimplant-2400.cut.png", "hole": {"x1": 0.16041666666666668, "y1": 0.2225, "x2": 0.8395833333333333, "y2": 0.7875}, "ratio": 1.5, "design_h": 620.0, "neon_region": {"x1": 0.27, "y1": 0.01, "x2": 0.77, "y2": 0.2}, "neon_white": true, "name": "implant terminal"}
const MECH := ["mechClunk", "mechRelay", "mechWhir", "mechKnock", "mechHiss"]

static var _icons: Dictionary = {}

var _mt := 0.0
var _injecting := -1.0


func _init() -> void:
	super({
		"theme": "plasmid", "mode": "p", "title": "DORBATELEPHINIUM", "title2": "IMPLANTS", "sub": "IMPLANT VENDING UNIT <b>//</b> PLASMID DISPENSARY", "items": PlasmidCatalog.PLASMIDS,
		"keys": {KEY_ENTER: "primary", KEY_SPACE: "primary", KEY_KP_ENTER: "primary"},
		"pad_keys": [[&"jump", "primary"]],
	})
	wrap_art(ART)


## menu icon: line-art SVG (same style as the weapon / armor icons)
static func icon_tex(p: Dictionary) -> Texture2D:
	var id: String = p["id"]
	if _icons.has(id):
		return _icons[id]
	var paths := ""
	for d: String in p["icon"]:
		paths += '<path d="%s"/>' % d
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 60" width="100" height="60" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" fill="#fff" fill-opacity=".14">' + paths + '</svg>'
	var img := Image.new()
	img.load_svg_from_string(svg, 3.0)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_icons[id] = t
	return t


## the 3D vial shown on the preview stage: glass tube, glowing core, brass caps
func build_subject(p: Variant) -> Node3D:
	var root := Node3D.new()
	var col := Color.hex((int(p["color"]) << 8) | 0xff)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(col, 0.32)
	glass.roughness = 0.08
	glass.metallic = 0.1
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var core := StandardMaterial3D.new()
	core.albedo_color = col
	core.emission_enabled = true
	core.emission = col
	core.emission_energy_multiplier = 1.6
	core.roughness = 0.4
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color.hex(0xb08a42ff)
	brass.roughness = 0.4
	brass.metallic = 0.85
	var open_tube := CylinderMesh.new()
	open_tube.top_radius = 0.22
	open_tube.bottom_radius = 0.22
	open_tube.height = 0.8
	open_tube.radial_segments = 24
	open_tube.cap_top = false
	open_tube.cap_bottom = false
	Goggles.part(root, open_tube, glass)
	Goggles.part(root, Goggles.cyl_mesh(0.16, 0.16, 0.7, 20), core)
	Goggles.part(root, Goggles.cyl_mesh(0.25, 0.25, 0.1, 24), brass, Vector3(0.0, 0.45, 0.0))
	Goggles.part(root, Goggles.cyl_mesh(0.25, 0.25, 0.1, 24), brass, Vector3(0.0, -0.45, 0.0))
	Goggles.part(root, Goggles.cyl_mesh(0.12, 0.12, 0.08, 16), brass, Vector3(0.0, 0.54, 0.0))
	for y: float in [0.36, -0.36]:
		var t := TorusMesh.new()
		t.inner_radius = 0.24 - 0.018
		t.outer_radius = 0.24 + 0.018
		t.rings = 24
		t.ring_segments = 8
		Goggles.part(root, t, brass, Vector3(0.0, y, 0.0))
	return root


func state(p: Dictionary) -> Dictionary:
	var ps: PowerStore = Game.power_store
	var own := ps.is_owned(p["id"])
	return {"own": own, "eq": ps.is_equipped(p["id"]), "soon": not p["available"], "poor": p["available"] and not own and p["price"] != null and Game.money < int(p["price"])}


func primary_label() -> String:
	var s := state(items[sel])
	return "EQUIPPED" if s.eq else ("EQUIP" if s.own else ("UNAVAILABLE" if s.soon else "BUY & EQUIP"))


func on_open() -> void:
	_mt = 1.8 + randf() * 2.5
	Game.sfx.crt_hum(true, 0.016)      # faint CRT hum while the terminal is up
	Game.sfx.ad_stop()
	Game.sfx.ad_play(null)      # an advert in progress is cut off; a different random one plays on the terminal's speaker


func close(via_esc: bool = false) -> void:
	_mt = 0.0
	Game.sfx.crt_hum(false)
	Game.sfx.ad_stop()
	Game.shops.vend_ads_t = 14.0 + randf() * 6.0
	super.close(via_esc)


func _process(delta: float) -> void:
	super._process(delta)
	if open_ and _mt > 0.0:      # an occasional mechanical sound from inside the machine (relay, clunk, servo whir, pipe knock, steam hiss), every 4-11 s
		_mt -= delta
		if _mt <= 0.0:
			Game.sfx.play(MECH[randi() % MECH.size()])
			_mt = 4.0 + randf() * 7.0
	if _injecting >= 0.0:      # a new implant: the menu closes, the machine injects it
		_injecting -= delta
		if _injecting < 0.0:
			var p: Dictionary = items[sel]
			close()
			var ok := false
			if Game.implant_cs != null:
				ok = Game.implant_cs.play(p)
			if not ok:
				Game.hud.toast(String(p["name"]) + " IMPLANTED - PRESS Z FOR POWER MODE")


func prompts(d: String) -> Array:
	var p := d == "pad"
	return [[["◀", "▶"] if p else ["A", "D"], "BROWSE"], [["A" if p else "ENTER"], primary_label(), "primary"], [["B" if p else "X"], "EXIT", "close"]]


func draw_slot(p: MenuPage, a: Variant, i: int, r: Rect2) -> void:
	var s := state(a)
	var t := "EQUIPPED" if s.eq else ("OWNED" if s.own else ((CrtTheme.money(int(a["price"])) if a["price"] != null else "READY") if a["available"] else "SOON"))
	var col := Color.hex((int(a["color"]) << 8) | 0xff)
	p.icon(icon_tex(a), r, col)
	p.slot_marks(r, "%02d" % (i + 1), t, "own" if s.own else ("poor" if s.soon else ""), s.eq)


func _lr(p: MenuPage, x: float, y: float, w: float, label: String, val: String, col: Color) -> float:
	var f := 12.0 * u
	y += 10.0 * u
	p.tx(x, y + f, label, f, th("dim"), p._f700, 0.3)
	p.tx(x + w, y + f, val, 14.0 * u, col, p._f700, 0.06, "r")
	return y + f * 1.2


func draw_main(p: MenuPage, R: Rect2) -> void:
	var a: Dictionary = items[sel]
	var s := state(a)
	var U_ := u
	var gap := 14.0 * U_
	var tot := R.size.x - 2.0 * gap
	var w1 := tot * 1.0 / 2.94
	var w2 := tot * 1.12 / 2.94
	var w3 := tot * 0.82 / 2.94
	var ir := Rect2(R.position, Vector2(w1, R.size.y))
	var vr := Rect2(R.position.x + w1 + gap, R.position.y, w2, R.size.y)
	var lr := Rect2(vr.end.x + gap, R.position.y, w3, R.size.y)
	var state_txt := "EQUIPPED" if s.eq else ("OWNED" if s.own else ("COMING SOON" if s.soon else ("INSUFFICIENT FUNDS" if s.poor else "AVAILABLE")))
	# ---- info
	var ini := p.panel(ir)
	p.clip_b = ini.end.y - 4.0
	var x := ini.position.x + 22.0 * U_
	var cw := ini.size.x - 44.0 * U_
	var ast: float = anim.get("swap", 9.0)
	var dx := 0.0
	var old_ga := p.ga
	if ast < 0.2:
		var q := CrtTheme.bezier(ast / 0.2, 0.2, 0.8, 0.3, 1.0)
		dx = 14.0 * (1.0 - q)
		p.ga *= lerpf(0.15, 1.0, q)
	var y := ini.position.y + 18.0 * U_
	var f_n := minf(32.0 * U_, maxf(12.0, cw * 0.084))
	p.tx(x + dx, y + f_n * 0.9, a["name"], f_n, th("ink"), p._f700, 0.08)
	y += f_n * 1.05 + 5.0 * U_
	var f_t := 12.0 * U_
	p.tx(x + dx, y + f_t * 0.9, a["tag"], f_t, th("edge"), p._f700, 0.34)
	y += f_t * 1.2
	var f_m := 11.0 * U_
	if not p.tiny:
		y += 8.0 * U_
		var mw := p.tx(x + dx, y + f_m, "MFR ", f_m, th("dim"), p._f700, 0.32)
		p.tx(x + dx + mw, y + f_m, "DORBATELEPHINIUM CORP.", f_m, th("edge"), p._f700, 0.32)
		y += f_m * 1.2 + 10.0 * U_
	if not p.small:
		var f_d := 15.0 * U_
		var desc: String = a.get("desc", "Implant data has not been loaded into this unit yet. Stock arrives with a future update.")
		for ln: String in CrtTheme.wrap(p._f500, desc, roundi(f_d), minf(cw, f_d * 36.0), f_d * 0.03):
			p.tx(x + dx, y + f_d * 1.05, ln, f_d, th("ink2"), p._f500, 0.03)
			y += f_d * 1.35
		y += 8.0 * U_
	for e: Array in [["WHEEL SLOT ", "LEFT SIDE (POWERS)"], ["TYPE ", "ACTIVE POWER"], ["STATUS ", state_txt]]:
		var mw := p.tx(x + dx, y + f_m, e[0], f_m, th("dim"), p._f700, 0.32)
		p.tx(x + dx + mw, y + f_m, e[1], f_m, th("edge"), p._f700, 0.32)
		y += f_m * 1.2 + 6.0 * U_
	p.ga = old_ga
	var mana_t := "—"
	if a.has("mana"):
		if a.has("drain"):
			mana_t = "%s PER SECOND (HOLD)" % str(int(a["drain"]))
		elif a.has("mana_max"):
			mana_t = "%s-%s (HOLD TO CHARGE)" % [str(int(a["mana"])), str(int(a["mana_max"]))]
		else:
			mana_t = "%s PER CAST" % str(int(a["mana"]))
	var mw2 := p.tx(x, y + f_m, "MANA ", f_m, th("dim"), p._f700, 0.32)
	p.tx(x + mw2, y + f_m, mana_t, f_m, th("edge"), p._f700, 0.32)
	y += f_m * 1.2
	if not p.small:      # .vd-note, at the foot
		var note := "EQUIPPED IMPLANT: Z (PAD: D-PAD UP) TOGGLES POWER MODE, FIRE CASTS. IMPLANTS MARKED SOON ARRIVE WITH A FUTURE UPDATE."
		var f_no := 10.5 * U_
		var lines := CrtTheme.wrap(p._f600, note, roundi(f_no), cw, f_no * 0.22)
		var ny := ini.end.y - 18.0 * U_ - lines.size() * f_no * 1.5
		if ny > y + 6.0:
			for ln: String in lines:
				p.tx(x, ny + f_no * 1.1, ln, f_no, th("dim"), p._f600, 0.22)
				ny += f_no * 1.5
	p.clip_b = 1e9
	# ---- preview
	var inr := p.panel(vr, true)
	p.schem(inr, "p")
	p.view_overlays(inr, "VIAL", "EQUIPPED" if s.eq else ("OWNED" if s.own else ("IN STOCK" if a["available"] else "SOON")), "eq" if s.eq else ("own" if s.own else ""), "%02d" % (sel + 1), "/ %d" % n, "IMPLANT PREVIEW", String(a["id"]).to_upper(), true)
	# ---- the price column
	var led := p.panel(lr)
	var lx := led.position.x + 18.0 * U_
	var lw := led.size.x - 36.0 * U_
	var ly := led.position.y + 18.0 * U_
	var f_k := 11.0 * U_
	p.tx(lx, ly + f_k, "PRICE", f_k, th("dim"), p._f700, 0.34)
	ly += f_k * 1.2 + 4.0
	var f_b := 38.0 * U_
	if led.size.x <= 200.0:
		f_b = 26.0
	p.tx(lx + p.deny_dx(), ly + f_b * 0.86, CrtTheme.money(int(a["price"])) if a["price"] != null else "—", f_b, p.price_col(th("ink")), p._f700, 0.04)
	ly += f_b
	ly = _lr(p, lx, ly, lw, "BALANCE", CrtTheme.money(Game.money), th("ink"))
	ly += 6.0 if p.tiny else 14.0 * U_
	var f_s := 12.0 * U_
	var sh := 8.0 * U_ * 2.0 + f_s * 1.2
	var sr := Rect2(lx, ly, lw, sh)
	var sc := th("dim")
	var bc := cm("edge", 30.0)
	if s.eq:
		sc = Color("#111")
		p.rect(sr, th("sel"))
		bc = Color(0, 0, 0, 0)
	elif s.own:
		sc = th("good")
		bc = cm("good", 50.0)
	elif s.soon or s.poor:
		sc = th("bad")
		bc = cm("bad", 55.0)
	if bc.a > 0.0:
		for e: Rect2 in [Rect2(sr.position, Vector2(sr.size.x, 1.0)), Rect2(sr.position + Vector2(0.0, sr.size.y - 1.0), Vector2(sr.size.x, 1.0)), Rect2(sr.position, Vector2(1.0, sr.size.y)), Rect2(sr.position + Vector2(sr.size.x - 1.0, 0.0), Vector2(1.0, sr.size.y))]:
			p.rect(e, bc)
	p.tx(sr.get_center().x, CrtTheme.baseline(p._f700, roundi(f_s), sr.position.y, sh), state_txt, f_s, sc, p._f700, 0.3, "c")
	var key_a := "A" if dev == "pad" else "ENTER"
	var main_b: Dictionary
	if s.eq:
		main_b = {"tick": true, "label": "EQUIPPED", "cls": "done", "a": "primary", "full": true}
	elif s.own:
		main_b = {"k": key_a, "label": "EQUIP", "cls": "main", "a": "primary", "full": true}
	elif s.soon or s.poor:
		main_b = {"k": key_a, "label": "UNAVAILABLE" if s.soon else "INSUFFICIENT FUNDS", "cls": "poor", "a": "primary", "full": true}
	else:
		main_b = {"k": key_a, "label": "BUY & EQUIP", "price": CrtTheme.money(int(a["price"])), "cls": "main", "a": "primary", "full": true}
	var exit_b := {"k": "B" if dev == "pad" else "X", "label": "EXIT", "a": "close", "full": true}
	var bh := 11.0 * U_ * 2.0 + 14.0 * U_ * 0.92 * 1.75
	var msg_h := maxf(22.0 * U_, 14.0 * U_ * 1.2) + 10.0 * U_
	var by := led.end.y - 18.0 * U_ - msg_h - bh * 2.0 - 9.0 * U_
	p.btn(lx, by, lw, main_b)
	p.btn(lx, by + bh + 9.0 * U_, lw, exit_b)
	if msg_text != "":
		var f := 14.0 * U_
		var col := th("bad") if msg_kind == "bad" else (th("sel") if msg_kind == "info" else th("good"))
		var ym := by + bh * 2.0 + 9.0 * U_ + 10.0 * U_
		for ln: String in CrtTheme.wrap(p._f700, msg_text, roundi(f), lw, f * 0.2):
			p.tx(lx, ym + f, ln, f, col, p._f700, 0.2)
			ym += f * 1.2


func act(a_: String) -> void:
	if a_ == "close":
		close()
		return
	if not open_ or busy() or a_ != "primary":
		return
	var p: Dictionary = items[sel]
	var s := state(p)
	if s.soon:
		msg("IMPLANT STOCK NOT YET AVAILABLE — CHECK BACK AFTER THE NEXT UPDATE", "info")
		Game.sfx.play("vendInfo")
		busy_until = Time.get_ticks_msec() + 200
		return
	if s.eq:
		msg(String(p["name"]) + " IS ALREADY EQUIPPED", "info")
		return
	if s.poor:
		deny("INSUFFICIENT FUNDS — " + CrtTheme.money(int(p["price"]) - Game.money) + " SHORT")
		return
	var r: Dictionary = Game.power_store.equip(p["id"]) if s.own else Game.power_store.purchase(p["id"])
	if not r.get("ok", false):
		msg("INSUFFICIENT FUNDS" if r.get("reason", "") == "funds" else "DISPENSER JAMMED - TRY AGAIN", "info")
		Game.sfx.play("vendInfo")
		busy_until = Time.get_ticks_msec() + 200
		return
	paid("EQUIPPED" if s.own else "DISPENSED", p["name"], String(p["name"]) + (" EQUIPPED" if s.own else " IMPLANTED") + " — PRESS Z FOR POWER MODE")
	if not s.own:
		_injecting = 0.75
