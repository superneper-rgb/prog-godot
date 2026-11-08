class_name ArmorShop
extends VendorMenu
## HELIX DEFENSE, the Goint fitting bay and the suit depots (JS class ArmorShop). cfg (the arms depot machines; the fitting bay passes none): {theme, mode, sub, stock (suit ids, in order), price / tag ({suit id: override}), note, art}

const GOINT_ART := {"url": "res://assets/ui/goinglife-2400.png", "hole": {"x1": 0.1529, "y1": 0.2469, "x2": 0.8496, "y2": 0.8145}, "ratio": 2400.0 / 1515.0, "design_h": 540.0, "neon_region": {"x1": 0.185, "y1": 0.01, "x2": 0.87, "y2": 0.22}, "neon_white": true}
const ARMOR_ICON := {
	"phantom_suit": '<circle cx="50" cy="16" r="10"/><path d="M43 27h14v5H43z"/><path d="M13 36l9-11 15 3-1 15-16 2z"/><path d="M87 36l-9-11-15 3 1 15 16 2z"/><path d="M37 28h26l3 30H34z"/><path d="M42 29l-3 29M58 29l3 29"/><path d="M34 49h32"/><path d="M46 46h8v6h-8z"/>',
	"standard": '<circle cx="50" cy="19" r="11"/><path d="M42 20h16"/><path d="M26 58c0-14 10-22 24-22s24 8 24 22z"/><path d="M44 36l6 10 6-10"/>',
	"goint_gear_xl": '<circle cx="50" cy="15" r="10"/><path d="M12 36l8-11h14l-1 13z"/><path d="M88 36l-8-11H66l1 13z"/><path d="M34 26h32l3 32H31z"/><path d="M36 28l14 14 14-14"/><path d="M45 36h10l3 5-3 5H45l-3-5z"/><path d="M33 50h34M33 54h34"/>',
	"omen": '<circle cx="50" cy="15" r="9"/><path d="M36 27L6 42l16-17 12-3z"/><path d="M64 27l30 15-16-17-12-3z"/><path d="M26 22c-2-7 2-13 9-16-3 5-4 10-2 15z"/><path d="M74 22c2-7-2-13-9-16 3 5 4 10 2 15z"/><path d="M34 26h32l3 32H31z"/><path d="M50 30l8 7-7 3-1 11-1-11-7-3z"/><path d="M38 28l4 7 4-5zM62 28l-4 7-4-5z"/><path d="M33 52l17-4 17 4"/>',
	"schleedtech_combat": '<path d="M38 26c0-11 5-18 12-18s12 7 12 18z"/><path d="M40 13h20"/><circle cx="45" cy="13" r="3"/><circle cx="55" cy="13" r="3"/><path d="M8 40l8-15h20l-2 14z"/><path d="M92 40l-8-15H64l2 14z"/><path d="M14 25l-3-7M86 25l3-7"/><path d="M34 28h32l3 30H31z"/><path d="M44 34h12l3 6-3 6H44l-3-6z"/><path d="M34 52h32"/>',
}
static var _icons := {}

var cfg := {}


func _init(p_cfg: Dictionary = {}) -> void:
	cfg = p_cfg
	var list: Array = []
	if cfg.has("stock"):
		for id: String in cfg.stock:
			if ArmorStore.ARMOR_BY_ID.has(id):
				list.append(ArmorStore.ARMOR_BY_ID[id])
	else:
		list = ArmorStore.ARMOR_CATALOG
	super({
		"theme": cfg.get("theme", "armor"), "mode": cfg.get("mode", "a"), "sub": cfg.get("sub", "FITTING TERMINAL <b>//</b> PERSONAL PROTECTION"), "items": list,
		"keys": {KEY_ENTER: "primary", KEY_SPACE: "primary", KEY_KP_ENTER: "primary"},
		"pad_keys": [[&"jump", "primary"]],
	})
	wrap_art(cfg.get("art", GOINT_ART))


static func armor_icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 60" width="100" height="60" stroke="#fff" stroke-width="2" stroke-linejoin="round" fill-opacity=".13" fill="#fff">' + String(ARMOR_ICON.get(id, "")) + "</svg>"
	var img := Image.new()
	img.load_svg_from_string(svg, 3.0)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_icons[id] = t
	return t


## this machine's price / tag line for a suit (a depot can undercut or relabel the catalogue)
func cost(a: Variant) -> int:
	var c: Dictionary = cfg.get("price", {})
	return c[a.id] if c.has(a.id) else a.price


func tag_of(a: Variant) -> String:
	var c: Dictionary = cfg.get("tag", {})
	return c.get(a.id, a.tag)


func mk(a: Variant) -> int:
	return ArmorStore.ARMOR_CATALOG.find(a)


func state(a: Variant) -> Dictionary:
	var own := ArmorStore.is_owned(a.id)
	var eq := ArmorStore.is_equipped(a.id)
	var soon: bool = a.soon and not own
	return {"own": own, "eq": eq, "soon": soon, "poor": not own and not soon and Game.money < cost(a)}


func primary_label() -> String:
	var s := state(items[sel])
	return "EQUIPPED" if s.eq else ("EQUIP" if s.own else ("COMING SOON" if s.soon else "BUY & EQUIP"))


func on_open() -> void:
	var id := ArmorStore.equipped_id()
	for i in n:
		if items[i].id == id:
			sel = i
			break


func prompts(d: String) -> Array:
	var p := d == "pad"
	return [[["◀", "▶"] if p else ["A", "D"], "BROWSE"], [["A" if p else "ENTER"], primary_label(), "primary"], [["B" if p else "ESC"], "EXIT", "close"]]


func build_subject(a: Variant) -> Node3D:
	if PhantomSuit.WEARABLE_SUITS.has(a.id):
		var pair := build_suited_pair(a.id)
		if pair.get_child_count() > 0:
			return pair
	return ArmorFigure.build(a.id)


## A wearable suit's fitting-bay preview: the real Prog and Tommy models wearing it, side by side like the reference art (built once per suit by the vendor stage, then cached). Each gets its own copy of the rig, so the in-game characters are untouched.
static func build_suited_pair(suit_id: String) -> Node3D:
	var pair := Node3D.new()
	pair.name = "armor-figure:" + suit_id
	for e: Array in [["prog", -0.62], ["tommy", 0.74]]:
		var B: Builds.Build = Builds.character_build(e[0])
		var ps: PackedScene = load(B.file)
		var an := Animator.new(ps.instantiate(), B)
		PhantomSuit.wear_suit_by_id(an, suit_id)
		var m := an.model
		m.get_parent().remove_child(m)
		m.position = Vector3.ZERO      # the Animator lowers the model by its pivot; here the feet simply stand on y = 0
		var holder := Node3D.new()
		holder.scale = Vector3.ONE * B.scale
		holder.position.x = e[1]
		holder.add_child(m)      # the model only: the Animator's weapon rack stays behind
		pair.add_child(holder)
		holder.set_meta(&"an", an)      # (keeps the Animator and its suit alive with the figure)
	return pair


func draw_slot(p: MenuPage, a: Variant, i: int, r: Rect2) -> void:
	var s := state(a)
	var c0 := cost(a)
	var t := "WORN" if s.eq else ("OWNED" if s.own else ("SOON" if s.soon else (CrtTheme.money(c0) if c0 != 0 else "FREE")))
	var cls := "own" if s.own else ("poor" if s.poor or s.soon else "")
	p.icon(armor_icon(a.id), r, th("ink") if i == sel else th("ink2"))
	p.slot_marks(r, "MK %d" % mk(a), t, cls, s.eq)


func draw_main(p: MenuPage, R: Rect2) -> void:
	var a: Variant = items[sel]
	var s := state(a)
	var cur_: Variant = ArmorStore.ARMOR_BY_ID.get(ArmorStore.equipped_id(), ArmorStore.ARMOR_CATALOG[0])
	var U_ := u
	var gap := 14.0 * U_
	var tot := R.size.x - 2.0 * gap
	var w1 := tot * 1.0 / 2.94
	var w2 := tot * 1.12 / 2.94
	var w3 := tot * 0.82 / 2.94
	var ir := Rect2(R.position, Vector2(w1, R.size.y))
	var vr := Rect2(R.position.x + w1 + gap, R.position.y, w2, R.size.y)
	var lr := Rect2(vr.end.x + gap, R.position.y, w3, R.size.y)
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
	p.tx(x + dx, y + f_n * 0.9, a.name, f_n, th("ink"), p._f700, 0.08)
	y += f_n * 1.05 + 5.0 * U_
	var f_t := 12.0 * U_
	p.tx(x + dx, y + f_t * 0.9, tag_of(a), f_t, Color("#ffaaa0") if theme_id == "weapon" else th("edge"), p._f700, 0.34)
	y += f_t * 1.2
	if not p.tiny:
		y += 8.0 * U_
		var f_m := 11.0 * U_
		var mw := p.tx(x + dx, y + f_m, "MFR ", f_m, th("dim"), p._f700, 0.32)
		p.tx(x + dx + mw, y + f_m, a.maker, f_m, th("edge"), p._f700, 0.32)
		y += f_m * 1.2 + 10.0 * U_
		for t in range(1, 6):
			var tr := Rect2(x + dx + (t - 1) * (22.0 * U_ + 4.0), y, 22.0 * U_, 6.0)
			var col := th("edge") if t <= mk(a) else cm("edge", 18.0)
			p.poly(PackedVector2Array([tr.position + Vector2(4, 0), Vector2(tr.end.x, tr.position.y), tr.end - Vector2(4, 0), Vector2(tr.position.x, tr.end.y)]), col)
		y += 6.0
	if not p.small:
		y += 12.0 * U_
		var f_d := 15.0 * U_
		for ln: String in CrtTheme.wrap(p._f500, a.desc, roundi(f_d), minf(cw, f_d * 36.0), f_d * 0.03):
			p.tx(x + dx, y + f_d * 1.05, ln, f_d, th("ink2"), p._f500, 0.03)
			y += f_d * 1.35
	# the comparison
	y += (6.0 if p.tiny else 16.0 * U_)
	var pad_c := (6.0 if p.tiny else 12.0 * U_)
	var f_c := 11.0 * U_
	var rh := maxf(16.0 * U_ * 1.2, f_c * 1.2)
	var head_h := 0.0 if p.tiny else f_c * 1.2 + 8.0 * U_
	var delta_h := 13.0 * U_ * 1.2 + 8.0 * U_
	var cmp_h := pad_c * 2.0 + head_h + 2.0 * (rh + 12.0 * U_) + delta_h
	if y + cmp_h < p.clip_b + 4.0:
		var cr := Rect2(x + dx, y, cw, cmp_h)
		p.rect(cr, cm("edge", 6.0))
		draw_rect_outline(p, cr, cm("edge", 25.0))
		var cy := y + pad_c
		var ix := x + dx + 14.0 * U_
		var iw := cw - 28.0 * U_
		if not p.tiny:
			p.tx(ix, cy + f_c, "RATED DAMAGE REDUCTION", f_c, th("dim"), p._f700, 0.34)
			cy += head_h
		cy = _cmp_row(p, ix, cy, iw, "CURRENT", cur_.dr, true)
		cy = _cmp_row(p, ix, cy, iw, "SELECTED", a.dr, false)
		var dv: float = a.dr - cur_.dr
		var dt_ := "+%d%% VS CURRENT SUIT" % dv if dv > 0.0 else ("%d%% VS CURRENT SUIT" % dv if dv < 0.0 else "SAME RATING AS CURRENT")
		p.tx(ix, cy + 8.0 * U_ + 13.0 * U_, dt_, 13.0 * U_, th("bad") if dv < 0.0 else (th("dim") if dv == 0.0 else th("good")), p._f700, 0.24)
	y += cmp_h
	p.ga = old_ga
	if not p.small:      # .vd-note, at the foot
		var note: String = cfg.get("note", "RATED REDUCTION APPLIES TO ALL DAMAGE YOU TAKE. FITTING BAY ONLINE - SUITS SHOWN AS COMING SOON ARE NOT STOCKED YET.")
		note = note.replace("<b>", "").replace("</b>", "")
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
	p.schem(inr, "a")
	p.view_overlays(inr, "SUIT", "EQUIPPED" if s.eq else ("OWNED" if s.own else "NOT OWNED"), "eq" if s.eq else ("own" if s.own else ""), "MK %d" % mk(a), "/ %d" % (ArmorStore.ARMOR_CATALOG.size() - 1), "FULL-BODY PREVIEW", String(a.id).to_upper().replace("_", " "), true)
	# ---- the price column
	var led := p.panel(lr)
	var lx := led.position.x + 18.0 * U_
	var lw := led.size.x - 36.0 * U_
	var ly := led.position.y + 18.0 * U_
	var f_k := 11.0 * U_
	p.tx(lx, ly + f_k, "PRICE", f_k, th("dim"), p._f700, 0.34)
	ly += f_k * 1.2 + 4.0
	var pr := cost(a)
	var f_b := 38.0 * U_
	var narrow := led.size.x <= 200.0
	if narrow:
		f_b = 26.0
	p.tx(lx + p.deny_dx(), ly + f_b * 0.86, CrtTheme.money(pr) if pr != 0 else "FREE", f_b, p.price_col(th("good") if pr == 0 else th("ink")), p._f700, 0.04)
	ly += f_b
	ly = _lr(p, lx, ly, lw, "BALANCE", CrtTheme.money(Game.money), th("ink"))
	var after: int = Game.money - (0 if s.own else pr)
	var at := "-" if s.own or s.soon else (CrtTheme.money(after) if after >= 0 else CrtTheme.money(-after) + " SHORT")
	ly = _lr(p, lx, ly, lw, "AFTER PURCHASE", at, th("bad") if after < 0 and not s.own and not s.soon else th("ink"))
	var st: Array = ["EQUIPPED", "eq"] if s.eq else (["OWNED", "own"] if s.own else (["COMING SOON", "poor"] if s.soon else (["INSUFFICIENT FUNDS", "poor"] if s.poor else ["AVAILABLE", ""])))
	ly += 6.0 if p.tiny else 14.0 * U_
	var f_s := 12.0 * U_
	var sh := 8.0 * U_ * 2.0 + f_s * 1.2
	var sr := Rect2(lx, ly, lw, sh)
	var sc := th("dim")
	var bc := cm("edge", 30.0)
	match st[1]:
		"own":
			sc = th("good")
			bc = cm("good", 50.0)
		"eq":
			sc = Color("#111")
			p.rect(sr, th("sel"))
			bc = Color(0, 0, 0, 0)
		"poor":
			sc = th("bad")
			bc = cm("bad", 55.0)
	if bc.a > 0.0:
		draw_rect_outline(p, sr, bc)
	p.tx(sr.get_center().x, CrtTheme.baseline(p._f700, roundi(f_s), sr.position.y, sh), st[0], f_s, sc, p._f700, 0.3, "c")
	# the buttons: a column at the foot, then the message
	var key_a := "A" if dev == "pad" else "ENTER"
	var main_b: Dictionary
	if s.eq:
		main_b = {"tick": true, "label": "EQUIPPED", "cls": "done", "a": "primary", "full": true}
	elif s.soon:
		main_b = {"k": key_a, "label": "COMING SOON", "cls": "poor", "a": "primary", "full": true}
	elif s.own:
		main_b = {"k": key_a, "label": "EQUIP", "cls": "main", "a": "primary", "full": true}
	elif s.poor:
		main_b = {"k": key_a, "label": "INSUFFICIENT FUNDS", "cls": "poor", "a": "primary", "full": true}
	else:
		main_b = {"k": key_a, "label": "BUY & EQUIP", "price": CrtTheme.money(pr) if pr != 0 else "FREE", "cls": "main", "a": "primary", "full": true}
	var exit_b := {"k": "B" if dev == "pad" else "ESC", "label": "EXIT", "a": "close", "full": true}
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


func draw_rect_outline(p: MenuPage, r: Rect2, col: Color) -> void:
	p.draw_rect(r, p.c(col), false, 1.0)


func _cmp_row(p: MenuPage, x: float, y: float, w: float, label: String, v: float, is_cur: bool) -> float:
	var U_ := u
	var f := 11.0 * U_
	var f_v := 16.0 * U_
	var rh := maxf(f_v * 1.2, f * 1.2)
	y += 6.0 * U_
	var by := y + rh * 0.78
	p.tx(x, by, label, f, th("dim"), p._f700, 0.24)
	var lab_w := 6.4 * f
	var val_w := 3.4 * f
	var bx := x + lab_w + 10.0
	var bw := w - lab_w - val_w - 20.0
	var bh := 12.0 * U_
	var r := Rect2(bx, y + (rh - bh) / 2.0, bw, bh)
	p.poly(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x - 6.0, r.end.y), Vector2(r.position.x, r.end.y)]), cm("edge", 10.0))
	var fr := Rect2(r.position, Vector2(bw * v / 100.0, bh))
	if v > 0.0:
		if is_cur:
			var ink := th("ink2")
			p.rect_h(fr, Color(ink.r, ink.g, ink.b, 0.4), ink)
		else:
			p.rect_h(fr, th("edge2"), th("edge"))
	for q in range(1, 15):
		p.rect(Rect2(bx + bw * q / 15.0 - 1.0, r.position.y, 1.0, bh), Color(0, 0, 0, 0.65))
	p.tx(x + w, by, "%d%%" % v, f_v, th("ink"), p._f700, 0.04, "r")
	return y + rh + 6.0 * U_


func _lr(p: MenuPage, x: float, y: float, w: float, label: String, val: String, col: Color) -> float:
	var U_ := u
	var m := 4.0 if p.tiny else 9.0 * U_
	y += m
	p.rect(Rect2(x, y, w, 1.0), cm("edge", 22.0))
	y += m
	var f := 11.0 * U_
	var f_v := 16.0 * U_
	p.tx(x, y + f_v, label, f, th("dim"), p._f700, 0.26)
	p.tx(x + w, y + f_v, val, f_v, col, p._f700, 0.04, "r")
	return y + f_v * 1.2


func act(a_: String) -> void:
	if a_ == "close":
		close()
		return
	if not open_ or busy() or a_ != "primary":
		return
	var it: Variant = items[sel]
	var s := state(it)
	if s.eq:
		msg(it.name + " IS ALREADY FITTED", "info")
		return
	if s.soon:
		msg(it.name + " IS NOT IN STOCK YET - COMING SOON", "info")
		Game.sfx.play("vendInfo")
		busy_until = Time.get_ticks_msec() + 200
		return
	if not s.own and s.poor:
		deny("INSUFFICIENT FUNDS - " + CrtTheme.money(cost(it) - Game.money) + " SHORT")
		return
	var r: Dictionary = ArmorStore.equip(it.id) if s.own else ArmorStore.purchase(it.id, cost(it))
	if not r.get("ok", false):
		msg("INSUFFICIENT FUNDS" if r.get("reason", "") == "funds" else "FITTING FAILED - TRY AGAIN", "info")
		Game.sfx.play("vendInfo")
		busy_until = Time.get_ticks_msec() + 200
		return
	# the real store charged / equipped; celebrate with the shared purchase feedback
	paid("FITTED" if s.own else "PURCHASED", it.name, it.name + (" FITTED" if s.own else " PURCHASED & FITTED"))
