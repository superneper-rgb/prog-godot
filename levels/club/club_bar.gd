class_name BarMenu
extends VendorMenu
## CLUB 9's bar: the drinks list in green phosphor on the bartender's handheld pad (the vendor terminals' shell, ui/shop/vendor_menu.gd, round the user's painting of the pad, alien
## hand and all). X at the bar does not open it straight away: the bartender brings the pad over and the menu takes over from it on screen (levels/club/bar_order.gd). Buying one
## closes it, the bartender makes it and slides it over, and Prog downs it (player/drunk.gd counts what it does to him).
## (2026-11-16, user: was the SchleedTech monitor terminal, a wide three-column page; the pad is tall, so the page is stacked for it.)

const ART := {"url": "res://assets/ui/bar_pad/bar_pad_frame.png", "hole": {"x1": 0.1641, "y1": 0.1549, "x2": 0.6641, "y2": 0.7135}, "ratio": BarPad.RATIO, "design_h": 680.0,
	"neon_region": {"x1": 0.0, "y1": 0.0, "x2": 0.0, "y2": 0.0}, "neon_white": false, "name": "bar pad"}

## The drinks. strength: drinks it counts for (warm milk takes one away). glass: BarGlass.KINDS. icon: line-art paths on a 100 x 60 box.
const DRINKS := [
	{"id": "foint_light", "name": "FOINT LIGHT", "tag": "LAGER // 3% ABV, 97% MARKETING", "price": 12, "color": 0xe8a530, "glass": "can", "strength": 1,
		"desc": "FOINT's own lager, brewed in the same vats as the cleaning fluid. Every can comes with a coupon for another FOINT LIGHT.",
		"icon": ["M40 8 L60 8 L62 14 L62 54 L38 54 L38 14 Z", "M38 22 L62 22", "M38 46 L62 46", "M47 4 L53 4"]},
	{"id": "schleed_slammer", "name": "SCHLEED SLAMMER", "tag": "SHOT // COOLANT GRADE", "price": 25, "color": 0x6dff4a, "glass": "shot", "strength": 1,
		"desc": "Distilled from whatever SchleedTech flushes out of the reactor loop. Glows in the dark. Tastes like licking a battery.",
		"icon": ["M40 20 L60 20 L57 54 L43 54 Z", "M42 30 L58 30", "M50 6 L50 14", "M44 10 L56 10"]},
	{"id": "black_mass", "name": "BLACK MASS", "tag": "HOUSE SPECIAL // SERVED SMOKING", "price": 35, "color": 0x3a0b1e, "glass": "tumbler", "strength": 1,
		"desc": "CLUB 9's house poison: black as the DJ's soul, a red float on top, dry ice underneath. Nobody knows what's in it. The bartender won't say.",
		"icon": ["M36 18 L64 18 L61 54 L39 54 Z", "M38 28 L62 28", "M42 12 C44 6 48 6 50 12 C52 6 56 6 58 12"]},
	{"id": "sern_fizz", "name": "SERN PARTICLE FIZZ", "tag": "COLLIDER-SMASHED // HIGH ENERGY", "price": 45, "color": 0x38c8ff, "glass": "beaker", "strength": 1,
		"desc": "Smashed together in SERN's collider and served in a lab beaker. Side effects include remembering next week.",
		"icon": ["M40 10 L60 10 M43 10 L43 50 L57 50 L57 10", "M43 34 L57 34", "M48 26 A2 2 0 1 0 48.1 26", "M53 20 A2 2 0 1 0 53.1 20"]},
	{"id": "goint_reserve", "name": "GOINT PREMIUM RESERVE", "tag": "COCKTAIL // ACTUARIALLY AGED", "price": 60, "color": 0xffc23a, "glass": "coupe", "strength": 1,
		"desc": "Aged in a GOINT actuarial vault. Every sip is covered by a policy you are not allowed to read. Garnished with a tiny umbrella, coverage pending.",
		"icon": ["M32 14 L68 14 L50 34 Z", "M50 34 L50 52", "M40 54 L60 54", "M60 6 L66 16"]},
	{"id": "warm_milk", "name": "WARM MILK", "tag": "NON-ALCOHOLIC // SOBERS YOU UP", "price": 6, "color": 0xf4efe2, "glass": "pint", "strength": -1,
		"desc": "For the designated driver. Takes the edge off one drink. The bartender will judge you, and so will everyone at the bar.",
		"icon": ["M38 10 L62 10 L59 54 L41 54 Z", "M40 20 L60 20"]},
]

static var _icons: Dictionary = {}

var bar: Callable = Callable()      # the club: called with the drink when one is bought (the bartender makes it)
var summon: Callable = Callable()   # the club: X at the bar calls this instead of opening (the bartender brings the pad over), and it calls open_now() when the pad is up


func open() -> void:
	if summon.is_valid() and not open_:
		summon.call()
		return
	super.open()


## the pad is held up to the camera: the menu takes over from it
func open_now() -> void:
	super.open()


func _init() -> void:
	super({
		"theme": "bar", "mode": "b", "sub": "CLUB 9 BAR <b>//</b> ORDER AT YOUR OWN RISK", "items": DRINKS,
		"keys": {KEY_ENTER: "primary", KEY_SPACE: "primary", KEY_KP_ENTER: "primary"},
		"pad_keys": [[&"jump", "primary"]],
	})
	wrap_art(ART)


static func colors() -> Array:
	var a: Array = []
	for d: Dictionary in DRINKS:
		a.append(int(d["color"]))
	return a


static func icon_tex(d: Dictionary) -> Texture2D:
	var id: String = d["id"]
	if _icons.has(id):
		return _icons[id]
	var paths := ""
	for p: String in d["icon"]:
		paths += '<path d="%s"/>' % p
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 60" width="100" height="60" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" fill="#fff" fill-opacity=".14">' + paths + '</svg>'
	var img := Image.new()
	img.load_svg_from_string(svg, 3.0)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_icons[id] = t
	return t


## the glass on the preview stage (the stage fits it to the view)
func build_subject(d: Variant) -> Node3D:
	return BarGlass.make(String(d["glass"]), int(d["color"]))


func state(d: Dictionary) -> Dictionary:
	var dr: Drunk = Game.drunk
	return {"poor": Game.money < int(d["price"]), "busy": dr != null and dr.busy(), "full": dr != null and dr.drinks >= Drunk.MAX and int(d["strength"]) > 0}


func on_open() -> void:
	Game.sfx.crt_hum(true, 0.014)


func close(via_esc: bool = false) -> void:
	Game.sfx.crt_hum(false)
	super.close(via_esc)


func prompts(dv: String) -> Array:
	var p := dv == "pad"
	return [[["◀", "▶"] if p else ["A", "D"], "BROWSE"], [["A" if p else "ENTER"], "ORDER", "primary"], [["B" if p else "X"], "EXIT", "close"]]


func draw_slot(p: MenuPage, a: Variant, i: int, r: Rect2) -> void:
	var col := Color.hex((int(a["color"]) << 8) | 0xff)
	if col.v < 0.3:
		col = Color(0.85, 0.25, 0.35)      # (a black drink's icon still has to show on a black screen)
	p.icon(icon_tex(a), r, col)
	p.slot_marks(r, "%02d" % (i + 1), CrtTheme.money(int(a["price"])), "poor" if Game.money < int(a["price"]) else "", false)


## how many he has had, as the bartender sees it
static func verdict(n: int) -> String:
	return ["STONE COLD SOBER", "LOOSENING UP", "FEELING IT", "WOBBLY", "WASTED", "CUT OFF SOON"][clampi(n, 0, 5)]


## The pad's page, top to bottom: the glass on its stage beside the till (price, balance, how many he has had), the drink's name and story, then ORDER and EXIT.
func draw_main(p: MenuPage, R: Rect2) -> void:
	var a: Dictionary = items[sel]
	var s := state(a)
	var gap := 8.0
	var top_h := 196.0
	var vr := Rect2(R.position, Vector2(floorf(R.size.x * 0.5), top_h))
	var lr := Rect2(vr.end.x + gap, R.position.y, R.size.x - vr.size.x - gap, top_h)
	var bh := 11.0 * 2.0 + 14.0 * 0.92 * 1.75
	var by := R.end.y - bh
	var ir := Rect2(R.position.x, vr.end.y + gap, R.size.x, by - gap - (vr.end.y + gap))
	var dr: Drunk = Game.drunk
	var had := dr.drinks if dr != null else 0
	# the glass
	var inr := p.panel(vr, true)
	p.schem(inr, "p")
	p.view_overlays(inr, "GLASS", "ON TAP", "", "%02d" % (sel + 1), "/ %d" % n, "", "", true)
	# the till
	var led := p.panel(lr)
	var lx := led.position.x + 12.0
	var lw := led.size.x - 24.0
	var ly := led.position.y + 12.0
	var f_k := 10.5
	p.tx(lx, ly + f_k, "PRICE", f_k, th("dim"), p._f700, 0.3)
	ly += f_k + 4.0
	var f_b := 34.0
	p.tx(lx + p.deny_dx(), ly + f_b * 0.86, CrtTheme.money(int(a["price"])), f_b, p.price_col(th("ink")), p._f700, 0.04)
	ly += f_b + 8.0
	for e: Array in [["BALANCE", CrtTheme.money(Game.money), th("ink")], ["DRINKS IN YOU", "%d / %d" % [had, Drunk.MAX], th("bad") if had >= 3 else th("ink")]]:
		p.tx(lx, ly + f_k, e[0], f_k, th("dim"), p._f700, 0.24)
		ly += f_k + 3.0
		p.tx(lx + lw, ly + 14.0, e[1], 14.0, e[2], p._f700, 0.06, "r")
		ly += 14.0 + 7.0
	p.tx(lx, ly + f_k, verdict(had), f_k, th("edge") if had < 3 else th("bad"), p._f700, 0.24)
	ly += f_k + 8.0
	if msg_text != "":
		var f := 11.0
		var col := th("bad") if msg_kind == "bad" else (th("sel") if msg_kind == "info" else th("good"))
		var old_cb := p.clip_b
		p.clip_b = led.end.y - 4.0
		for ln: String in CrtTheme.wrap(p._f700, msg_text, roundi(f), lw, f * 0.12):
			p.tx(lx, ly + f, ln, f, col, p._f700, 0.12)
			ly += f * 1.2
		p.clip_b = old_cb
	# the drink
	var ini := p.panel(ir)
	p.clip_b = ini.end.y - 4.0
	var x := ini.position.x + 14.0
	var cw := ini.size.x - 28.0
	var ast: float = anim.get("swap", 9.0)
	var dx := 0.0
	var old_ga := p.ga
	if ast < 0.2:
		var q := CrtTheme.bezier(ast / 0.2, 0.2, 0.8, 0.3, 1.0)
		dx = 14.0 * (1.0 - q)
		p.ga *= lerpf(0.15, 1.0, q)
	var y := ini.position.y + 10.0
	var f_n := 25.0
	for ln: String in CrtTheme.wrap(p._f700, a["name"], roundi(f_n), cw, f_n * 0.06):
		p.tx(x + dx, y + f_n * 0.9, ln, f_n, th("ink"), p._f700, 0.06)
		y += f_n * 1.02
	y += 3.0
	var f_t := 10.5
	p.tx(x + dx, y + f_t * 0.9, a["tag"], f_t, th("edge"), p._f700, 0.22)
	y += f_t * 1.2 + 8.0
	var f_d := 13.5
	for ln: String in CrtTheme.wrap(p._f500, a["desc"], roundi(f_d), cw, f_d * 0.02):
		p.tx(x + dx, y + f_d * 1.05, ln, f_d, th("ink2"), p._f500, 0.02)
		y += f_d * 1.3
	y += 6.0
	var f_m := 10.5
	var mx := x + dx
	for e: Array in [["SERVED IN ", String(a["glass"]).to_upper()], ["   KICK ", "SOBERING" if int(a["strength"]) < 0 else "ONE DRINK"]]:
		mx += p.tx(mx, y + f_m, e[0], f_m, th("dim"), p._f700, 0.26)
		mx += p.tx(mx, y + f_m, e[1], f_m, th("edge"), p._f700, 0.26)
	p.ga = old_ga
	p.clip_b = 1e9
	# order / exit
	var key_a := "A" if dev == "pad" else "ENTER"
	var main_b: Dictionary
	if s.poor:
		main_b = {"k": key_a, "label": "CAN'T AFFORD", "cls": "poor", "a": "primary"}
	elif s.busy:
		main_b = {"k": key_a, "label": "FINISH IT FIRST", "cls": "poor", "a": "primary"}
	else:
		main_b = {"k": key_a, "label": "ORDER", "price": CrtTheme.money(int(a["price"])), "cls": "main", "a": "primary"}
	var ow := floorf(R.size.x * 0.64)
	p.btn(R.position.x, by, ow, main_b)
	p.btn(R.position.x + ow + gap, by, R.size.x - ow - gap, {"k": "B" if dev == "pad" else "X", "label": "EXIT", "a": "close"})


func act(a_: String) -> void:
	if a_ == "close":
		close()
		return
	if not open_ or busy() or a_ != "primary":
		return
	var d: Dictionary = items[sel]
	var s := state(d)
	if s.poor:
		deny("INSUFFICIENT FUNDS — " + CrtTheme.money(int(d["price"]) - Game.money) + " SHORT")
		return
	if s.busy:
		msg("ONE AT A TIME, PAL", "info")
		Game.sfx.play("vendInfo")
		busy_until = Time.get_ticks_msec() + 200
		return
	Game.add_money(-int(d["price"]))
	paid("SERVED", d["name"], String(d["name"]) + " — COMING RIGHT UP")
	busy_until = Time.get_ticks_msec() + 900
	Game.get_tree().create_timer(0.7).timeout.connect(func() -> void:
		close()
		if bar.is_valid():
			bar.call(d))
