class_name WeaponShop
extends VendorMenu
## HELIX ARMORY, the Foint n Shoot counter and the gun depots (JS class WeaponShop): browse the guns, buy, top up, equip. cfg (the arms depot machines; the gunshop counter passes none): {theme, mode, sub, cap, stock (weapon ids this machine sells; owned guns always show up for ammo), buy_mul / rd_mul (price multipliers on PRICE), full_load (a bought gun comes with every round it can carry), art}

const WEAPON_BLURB := {
	"pistol": "Compact jet-black service pistol. Fast semi-auto, modest recoil and a 15-round magazine. The weakest gun overall, but five body hits can drop a standard security robot.",
	"dual_silenced": "Two suppressed service pistols, one in each hand, firing alternately. A soft cough instead of a bang and almost no muzzle flash. Thirty rounds between them; the left gun goes to the hip while you reload.",
	"legacy_smg": "The original compact submachine gun: wire stock, straight magazine and ordinary bullets. Forty rounds of fast automatic fire. Separate from the Swarm launcher.",
	"legacy_deagle": "The original .50 hand cannon: deep angular slide, brass baseplate, ordinary heavy rounds. Two to drop a security robot; cheaper and softer than the Jawbreaker.",
	"legacy_rifle": "The original assault rifle: olive furniture, banana magazine, cyan-lens optic. Plain full-auto bullet fire. Cheaper and softer than the Lead Zeppelin.",
	"legacy_rocket": "The original rocket launcher: one explosive rocket per trigger pull, 4 m blast radius. Mind the backblast. Cheaper and softer than Heavy Rotation.",
	"legacy_sniper": "The original bolt sniper: variable-zoom scope, one round, one problem solved. A kill lets the round carry on into the next body, but it loses a lot on the way. Cheaper and softer than The Last Word.",
	"deagle": "Cream-and-brass heavy pistol. Oversized metal balls from a clear hopper, fired as slow, deliberate single shots that drop a security robot outright.",
	"shotgun": "Ten-pellet pump action. Clears a corridor at arm's length, falls off fast beyond it.",
	"rifle": "Blue bullpup with controlled full-auto bullet fire, steady recoil and a long effective range.",
	"smg": "Rapid-fire launcher of mechanical gnats from a red-orange pod. The highest rate of fire on the rack, and it eats ammo to match.",
	"rocket": "Shoulder-fired launcher with an exposed rocket carousel. One explosive rocket per trigger pull, 4.8 m blast radius. Mind the backblast.",
	"sniper": "Jade-and-purple scoped sniper that fires a thin violet needle. Variable-zoom scope. One round, one problem solved. The needle punches through anything it kills and keeps most of its bite: line them up.",
	"saw": "Launches a spinning ceramic disc that ricochets off every surface, faster and nastier with each bounce. Slices light targets, bounces off armour, and comes back to your hand.",
	"yoke": "Hold to gather rubble into a stone, release to sling it. The landing collapses into a gravity well that drags enemies in.",
	"bellows": "A brass-lunged horn cannon. One sonic blast pierces everything in a widening lane, hits hard and throws enemies out to either side, parting the crowd. Only two rounds a mag.",
	"arc": "A pylon that throws a glowing beam of lightning over a short range, then chains to two more enemies nearby. Hold to fire until the charge runs dry; it recharges itself.",
	"flail": "A grumpy spiked ball on a chain, from DreadZone surplus. Hold it low and drag it; press to haul it overhead and slam it down in front of you. Short reach, heavy hit, and everything near the impact gets the blast. Twenty swings, then find an ammo pod. Flyers can dodge it.",
}
const GUNSHOP_ART := {"url": "res://assets/ui/fointnneon-2400.png", "hole": {"x1": 0.1412, "y1": 0.2628, "x2": 0.8783, "y2": 0.8209}, "ratio": 2400.0 / 1480.0, "design_h": 540.0, "neon_region": {"x1": 0.09, "y1": 0.03, "x2": 0.62, "y2": 0.25}, "neon_white": true}

var cfg := {}


func _init(p_cfg: Dictionary = {}) -> void:
	cfg = p_cfg
	super({
		"theme": cfg.get("theme", "weapon"), "mode": cfg.get("mode", "w"), "sub": cfg.get("sub", "WEAPON TERMINAL <b>//</b> AUTHORISED SALE"), "items": Weapons.WEAPONS,
		"keys": {KEY_ENTER: "primary", KEY_SPACE: "primary", KEY_KP_ENTER: "primary", KEY_R: "fill", KEY_F: "fill", KEY_Q: "equip", KEY_M: "maxout"},
		"pad_keys": [[&"jump", "primary"], [&"attack", "fill"], [&"quick", "equip"], [&"crouch", "maxout"]],
	})
	wrap_art(cfg.get("art", GUNSHOP_ART))


static func vd_cost(n_: float, rd: float) -> int:      # rounds x $/round without float artefacts (5 x 1.2 = $6, not $7)
	return ceili(round(n_ * rd * 1000.0) / 1000.0 - 1e-9)


func _combat() -> Combat:
	return Game.combat


## what this machine charges for a weapon: PRICE with the depot's multipliers
func price(id: String) -> Dictionary:
	var P: Dictionary = Weapons.PRICE[id]
	if cfg.has("buy_mul") or cfg.has("rd_mul"):
		return {"buy": round(float(P.buy) * float(cfg.get("buy_mul", 1.0)) / 10.0) * 10.0, "rd": round(float(P.rd) * float(cfg.get("rd_mul", 1.0)) * 100.0) / 100.0}
	return P


func skip_item(w: Variant) -> bool:      # the arena prototypes are sold only where they belong (WEAPONS is one list for every level); a depot shows its own stock + the guns you carry
	if Weapons.ARENA_IDS.has(w.id) and not Weapons.arena_weapons_here():
		return true
	return cfg.has("stock") and not (cfg.stock as Array).has(w.id) and not _combat().owned.has(Weapons.WEAPONS.find(w))


func slot_hidden(i: int) -> bool:
	return skip_item(items[i])


func on_open() -> void:
	var C := _combat().cur
	if C >= 0:
		sel = C
	if skip_item(items[sel]):
		for i in n:
			if not skip_item(items[i]):
				sel = i
				break


func build_subject(w: Variant) -> Node3D:
	var path := "res://assets/weapons/%s.glb" % w.id
	if ResourceLoader.exists(path):
		return (load(path) as PackedScene).instantiate()
	return Node3D.new()


func prompts(d: String) -> Array:
	var own: bool = _combat().owned.has(sel)
	var p := d == "pad"
	return [[["◀", "▶"] if p else ["A", "D"], "BROWSE"], [["A" if p else "ENTER"], "+1 MAG" if own else "BUY", "primary"], [["X" if p else "R"], "REFILL", "fill"], [["Y" if p else "Q"], "EQUIP", "equip"], [["RB" if p else "M"], "MAX OUT AMMO", "maxout"], [["B" if p else "ESC"], "EXIT", "close"]]


func quote_max() -> Dictionary:
	var C := _combat()
	var cost := 0
	var rounds := 0
	var guns := 0
	for i in n:
		var w: Variant = items[i]
		if not C.owned.has(i):
			continue
		var room: float = 0.0 if w.energy else w.max - C.ammo[i] - C.reserve[i]
		if room > 0.0:
			cost += vd_cost(room, price(w.id).rd)
			rounds += int(room)
			guns += 1
	return {"cost": cost, "rounds": rounds, "guns": guns}


func draw_slot(p: MenuPage, w: Variant, i: int, r: Rect2) -> void:
	var C := _combat()
	var own: bool = C.owned.has(i)
	var cost: float = price(w.id).buy
	p.icon(WeaponIcons.tex(w.id), r, th("ink") if i == sel else th("ink2"))
	p.slot_marks(r, "%02d" % (i + 1), "OWNED" if own else CrtTheme.money(cost), "own" if own else ("poor" if Game.money < cost else ""), C.cur == i)


func draw_main(p: MenuPage, R: Rect2) -> void:
	var C := _combat()
	var U_ := u
	var i := sel
	var w: Variant = items[i]
	var P: Dictionary = price(w.id)
	var own: bool = C.owned.has(i)
	var cur_ := C.cur == i
	var have := roundi(C.ammo[i] + C.reserve[i])
	var room: int = 0 if w.energy else w.max - have
	var mag_n := mini(room, w.mag_size)
	var mag_cost := vd_cost(mag_n, P.rd)
	var fill_cost := vd_cost(room, P.rd)
	var poor: bool = not own and Game.money < P.buy
	var gap := 14.0 * U_
	var w1 := (R.size.x - gap) * 1.42 / 2.42
	var w2 := R.size.x - gap - w1
	var ph := 54.0 * U_
	var vr := Rect2(R.position, Vector2(w1, R.size.y - gap - ph))
	var pr := Rect2(R.position.x, vr.end.y + gap, w1, ph)
	var ir := Rect2(R.position.x + w1 + gap, R.position.y, w2, R.size.y)
	# ---- the preview
	var inr := p.panel(vr, true)
	p.schem(inr, "w")
	var chip: Array = ["EQUIPPED", "eq"] if cur_ else (["OWNED", "own"] if own else ["NOT OWNED", ""])
	var cap: String = cfg.get("cap", "FOINT N SHOOT")
	p.view_overlays(inr, "STATUS", chip[0], chip[1], "%02d" % (i + 1), "/ %02d" % n, cap + " // " + String(w.id).to_upper() + " // " + ("REGISTERED" if own else "FOR SALE"), "SCHEMATIC 7-HX // LIVE", false)
	# ---- the price strip: purchase price before you own it, the refill price after
	var lab := "PRICE"
	var val := CrtTheme.money(P.buy)
	var st := "INSUFFICIENT FUNDS" if poor else "AVAILABLE"
	var stc := "poor" if poor else ""
	if own:
		lab = "REFILL"
		val = CrtTheme.money(fill_cost) if room > 0 else ("SELF-CHARGING" if w.energy else "AMMO FULL")
		st = "EQUIPPED" if cur_ else "OWNED"
		stc = "eq" if cur_ else "own"
	var edge_c := th("edge")
	var ad: float = anim.get("deny", 9.0)
	if ad < 0.42:
		var q := ad / 0.42
		edge_c = edge_c.lerp(th("bad"), minf(1.0, q / 0.3) if q < 0.3 else (1.0 if q < 0.75 else 1.0 - (q - 0.75) / 0.25))
	p.poly(p.chamf_tr_bl(pr, 16.0), edge_c)
	var pi := pr.grow(-1.5)
	p.poly(p.chamf_tr_bl(pi, 15.0), th("glass2"))
	var f_l := 12.0 * U_
	var lw := p.w_of(p._f700, lab, roundi(f_l), f_l * 0.36) + 18.0 * U_ + 26.0 * U_
	var lpts := PackedVector2Array([pi.position, Vector2(pi.position.x + lw, pi.position.y), Vector2(pi.position.x + lw - 12.0, pi.end.y), Vector2(pi.position.x + 14.0, pi.end.y), Vector2(pi.position.x, pi.end.y - 14.0)])
	if theme_id == "weapon":
		p.poly_grad(lpts, Color("#b3182b"), Color("#6b0e1b"))
	else:
		p.poly(lpts, th("edge"))
	p.tx(pi.position.x + 18.0 * U_, CrtTheme.baseline(p._f700, roundi(f_l), pi.position.y, pi.size.y), lab, f_l, th("ink") if theme_id == "weapon" else th("glass2"), p._f700, 0.36)
	var f_v := 32.0 * U_
	p.tx(pi.position.x + lw + 18.0 * U_ + p.deny_dx(), CrtTheme.baseline(p._f700, roundi(f_v), pi.position.y, pi.size.y), val, f_v, p.price_col(th("ink")), p._f700, 0.05)
	var f_s := 13.0 * U_
	var sw := p.w_of(p._f700, st, roundi(f_s), f_s * 0.3) + 44.0 * U_
	var sr := Rect2(pi.end.x - sw, pi.position.y, sw, pi.size.y)
	var spts := PackedVector2Array([sr.position + Vector2(12, 0), Vector2(sr.end.x - 14.0, sr.position.y), Vector2(sr.end.x, sr.position.y + 14.0), sr.end, Vector2(sr.position.x, sr.end.y)])
	var sc := th("dim")
	if stc == "eq":
		p.poly(spts, th("sel"))
		sc = Color("#121212")
	else:
		p.poly(spts, th("glass2").lerp(th("edge"), 0.1))
		if stc == "own":
			sc = th("good")
		elif stc == "poor":
			sc = th("bad")
	p.tx(sr.position.x + 24.0 * U_, CrtTheme.baseline(p._f700, roundi(f_s), sr.position.y, sr.size.y), st, f_s, sc, p._f700, 0.3)
	# ---- the info column (a flex column: what does not fit is cut off at the panel's edge)
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
	p.tx(x + dx, y + f_n * 0.9, w.name, f_n, th("ink"), p._f700, 0.08)
	y += f_n * 1.05 + 5.0 * U_
	var f_t := 12.0 * U_
	p.tx(x + dx, y + f_t * 0.9, w.tag, f_t, Color("#ffaaa0") if theme_id == "weapon" else th("edge"), p._f700, 0.34)
	y += f_t * 1.2
	if not p.small:
		y += 12.0 * U_
		var f_d := 15.0 * U_
		for ln: String in CrtTheme.wrap(p._f500, WEAPON_BLURB.get(w.id, ""), roundi(f_d), minf(cw, f_d * 36.0), f_d * 0.03):
			p.tx(x + dx, y + f_d * 1.05, ln, f_d, th("ink2"), p._f500, 0.03)
			y += f_d * 1.35
	y += 14.0 * U_
	if y < p.clip_b:
		var rl := th("edge")
		p.rect_h(Rect2(x + dx, y, cw, 1.0), Color(rl.r, rl.g, rl.b, 0.6), Color(rl.r, rl.g, rl.b, 0.0))
	y += 6.0 * U_
	var dmg: float = w.dmg * w.pellets
	y = _stat(p, x + dx, y, cw, "DAMAGE", dmg / 160.0, "%d" % dmg, "%d×%d" % [w.pellets, w.dmg] if w.pellets > 1 else "")
	y = _stat(p, x + dx, y, cw, "FIRE RATE", w.rate / 17.0, "%s" % str(w.rate), "/S")
	y = _stat(p, x + dx, y, cw, "RANGE", w.range / 160.0, "%s" % str(w.range), "M")
	y = _stat(p, x + dx, y, cw, "MAGAZINE", w.mag_size / 40.0, "%d" % w.mag_size, "")
	# ammo
	y += 5.0 * U_      # (the rows' last 7 px collapse with the 12 of the ammo box)
	var f_a := 12.0 * U_
	var f_b := 19.0 * U_
	var ah := 7.0 * U_ * 2.0 + f_b * 1.37
	if y + ah < p.clip_b:
		p.rect(Rect2(x + dx, y, cw, ah), cm("edge", 7.0))
		p.rect(Rect2(x + dx, y, 3.0, ah), th("edge"))
		var bl := y + 7.0 * U_ + f_b
		p.tx(x + dx + 12.0, bl, "AMMUNITION", f_a, th("dim"), p._f700, 0.24)
		var mid := x + dx + cw / 2.0
		var amm := "%d / %d" % [have, w.max] if own else "— / %d" % w.max
		p.tx(mid, bl, amm, f_b, th("good") if own and room <= 0 else th("ink"), p._f700, 0.06, "c")
		if not p.tiny:
			p.tx(x + dx + cw - 12.0, bl, "SELF-CHARGING" if w.energy else "$%s / RD" % str(P.rd), f_a, th("ink2"), p._f700, 0.24, "r")
	y += ah + 4.0 * U_
	p.ga = old_ga
	# acts
	var key_a := "A" if dev == "pad" else "ENTER"
	var acts: Array = []
	if not own:
		acts.append({"k": key_a, "label": "INSUFFICIENT FUNDS" if poor else "BUY", "price": CrtTheme.money(P.buy), "cls": "poor" if poor else "main", "a": "buy"})
	else:
		if room > 0:
			acts.append({"k": key_a, "label": "+%d RDS" % mag_n, "price": CrtTheme.money(mag_cost), "a": "mag"})
			acts.append({"k": "X" if dev == "pad" else "R", "label": "REFILL", "price": CrtTheme.money(fill_cost), "a": "fill"})
		else:
			acts.append({"tick": true, "label": "AMMO FULL", "cls": "done", "a": "mag"})
		if cur_:
			acts.append({"tick": true, "label": "EQUIPPED", "cls": "done", "a": "equip"})
		else:
			acts.append({"k": "Y" if dev == "pad" else "Q", "label": "EQUIP", "cls": "main", "a": "equip"})
	y += 10.0 * U_
	y += p.btn_row(x, y, cw, acts)
	# the max-out button and the message stay at the foot of the column when there is room
	var q := quote_max()
	var key_m := "RB" if dev == "pad" else "M"
	var bh := 11.0 * U_ * 2.0 + 14.0 * U_ * 0.92 * 1.75
	var msg_h := maxf(22.0 * U_, 14.0 * U_ * 1.2) + 10.0 * U_
	var foot := ini.end.y - 18.0 * U_ - msg_h - bh
	var y_max := maxf(y + 10.0 * U_ + 6.0, foot)
	var spec := {"k": key_m, "label": "MAX OUT AMMO", "full": true, "a": "maxout"}
	if q.guns > 0:
		spec.small = "%d WPN%s" % [q.guns, "S" if q.guns > 1 else ""]
		spec.price = CrtTheme.money(q.cost)
		if Game.money < q.cost:
			spec.cls = "poor"
	else:
		spec.price = "ALL FULL"
		spec.cls = "off"
	p.btn(x, y_max, cw, spec)
	draw_msg(p, x, y_max + bh + 10.0 * U_)
	p.clip_b = 1e9


func _stat(p: MenuPage, x: float, y: float, cw: float, label: String, v: float, t: String, small_: String) -> float:
	var U_ := u
	var f := 12.0 * U_
	var f_v := 15.0 * U_
	var rh := f_v * 1.35
	var by := y + rh * 0.78
	p.tx(x, by, label, f, th("dim"), p._f700, 0.24)
	var lab_w := 7.2 * f
	var val_w := 4.6 * f
	var bx := x + lab_w + 12.0
	var bw := cw - lab_w - val_w - 24.0
	var bh := 9.0 * U_
	var r := Rect2(bx, y + (rh - bh) / 2.0, bw, bh)
	if y + rh < p.clip_b:
		p.poly(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x - 5.0, r.end.y), Vector2(r.position.x, r.end.y)]), cm("edge", 12.0))
		var fw_ := bw * clampf(v, 0.04, 1.0)
		var fr := Rect2(r.position, Vector2(fw_, bh))
		if theme_id == "weapon":
			p.rect_h(Rect2(fr.position, Vector2(fw_ * 0.7, bh)), Color("#ae1525"), Color("#ff514b"))
			p.rect_h(Rect2(fr.position + Vector2(fw_ * 0.7, 0), Vector2(fw_ * 0.3, bh)), Color("#ff514b"), Color("#ffe2bc"))
		else:
			p.rect_h(fr, th("edge2"), th("edge"))
		for q in range(1, 10):
			p.rect(Rect2(bx + bw * q / 10.0 - 1.0, r.position.y, 1.0, bh), Color(0, 0, 0, 0.6))
	var rx := x + cw
	var sw := 0.0
	if small_ != "":
		sw = p.tx(rx, by, small_, f_v * 0.7, th("dim"), p._f700, 0.06, "r")
	p.tx(rx - sw, by, t, f_v, th("ink"), p._f700, 0.06, "r")
	return y + rh + 7.0 * U_


func draw_msg(p: MenuPage, x: float, y: float) -> void:
	if msg_text == "":
		return
	var f := 14.0 * u
	var col := th("good")
	if msg_kind == "bad":
		col = th("bad")
	elif msg_kind == "info":
		col = th("sel")
	var am: float = anim.get("msg", 9.0)
	var old := p.ga
	var dy := 0.0
	if am < 0.25:
		p.ga *= am / 0.25
		dy = 4.0 * (1.0 - am / 0.25)
	p.tx(x, y + dy + f, msg_text, f, col, p._f700, 0.2)
	p.ga = old


func act(a: String) -> void:
	if a == "close":
		close()
		return
	if not open_ or busy():
		return
	var C := _combat()
	var i := sel
	var w: Variant = items[i]
	var P: Dictionary = price(w.id)
	var own: bool = C.owned.has(i)
	if a == "primary":
		a = "mag" if own else "buy"
	if a == "buy":
		if own:
			msg("ALREADY IN INVENTORY", "info")
			return
		if Game.money < P.buy:
			deny("INSUFFICIENT FUNDS — " + CrtTheme.money(P.buy - Game.money) + " SHORT")
			return
		if C.give(i, w.mag_size, w.max - w.mag_size if cfg.get("full_load", false) else mini(w.max - w.mag_size, w.mag_size * 2)) < 0:
			deny("WEAPON WHEEL FULL — DISCARD A WEAPON FIRST")
			return
		Game.add_money(-P.buy)
		Game.save_game()
		paid("ACQUIRED", w.name, w.name + " ACQUIRED  −" + CrtTheme.money(P.buy))
		return
	if a == "maxout":
		var q := quote_max()
		if q.guns == 0:
			deny("ALL AMMO ALREADY AT CAPACITY")
			return
		if Game.money < q.cost:
			deny("INSUFFICIENT FUNDS — MAX OUT COSTS " + CrtTheme.money(q.cost))
			return
		var spent := 0
		for k_ in n:
			var x: Variant = items[k_]
			if not C.owned.has(k_):
				continue
			var rm: float = 0.0 if x.energy else x.max - C.ammo[k_] - C.reserve[k_]
			if rm > 0.0:
				spent += vd_cost(rm, price(x.id).rd)
				C.reserve[k_] += rm
		Game.add_money(-spent)
		Game.save_game()
		paid("RESUPPLIED", "ALL WEAPONS AT CAPACITY", "+%d RDS ACROSS %d WEAPON%s  −%s" % [q.rounds, q.guns, "S" if q.guns > 1 else "", CrtTheme.money(spent)])
		return
	if a == "equip":
		if not own:
			deny("BUY THE " + w.name + " FIRST")
			return
		if C.cur == i:
			msg("ALREADY EQUIPPED", "info")
			return
		C.equip(i)
		Game.sfx.play("vendNav")
		close()
		return
	if a == "mag" or a == "fill":
		if not own:
			deny("BUY THE " + w.name + " FIRST")
			return
		var room: float = w.max - C.ammo[i] - C.reserve[i]
		if room <= 0.0:
			deny("AMMO FULL")
			return
		var nn: float = room if a == "fill" else minf(room, w.mag_size)
		var cost := vd_cost(nn, P.rd)
		if Game.money < cost:
			nn = minf(nn, floorf(Game.money / float(P.rd) + 1e-9))
			cost = vd_cost(nn, P.rd)
			if nn <= 0.0 or cost > Game.money:
				deny("INSUFFICIENT FUNDS")
				return
		Game.add_money(-cost)
		C.reserve[i] += nn
		Game.save_game()
		paid("+%d ROUNDS" % int(nn), w.name, "+%d ROUNDS  −%s" % [int(nn), CrtTheme.money(cost)])
