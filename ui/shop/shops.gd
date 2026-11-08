class_name Shops
extends RefCounted
## Every vendor in the game and who is standing at which (JS index.html: nearClerk, nearArmory, nearDepot, nearVendor, DEPOT_SHOPS, MENUS). The ARMS DEPOTS are vending machines that sell guns / ammo and suits in the middle of a level. Foint and Goint are rival brands, so each sells its own stock at its own prices behind its own frame: Foint undercuts (cheap rounds, street hardware, resold suits, no warranty), Goint charges a premium (every gun sold fully loaded, precision hardware, its own Goint suits). A level shows machines by a `vendors` list: [{kind, x, y, z, prompt: {x, z, r}}]; X at the prompt spot opens that machine's menu. The implant machine joins with the powers.

const DEPOT_HINT := {"foint-ammo": ["FOINT-O-MATIC — GUNS & AMMO", ""], "goint-ammo": ["GOINT ASSURED ARMAMENTS — GUNS & AMMO", "armor"], "foint-armor": ["FOINT FLAK SHACK — ARMOR", ""], "goint-armor": ["GOINT POLICY BOOTH — ARMOR", "armor"]}
const ARMORY_PROMPT := {"x": 5.6, "z": -1.7, "r": 2.6}

var shop: WeaponShop = null
var armory: ArmorShop = null
var depot_shops := {}
var plasmids: PlasmidShop = null
var vend_ads_t := 8.0 + randf() * 4.0


func _init() -> void:
	shop = WeaponShop.new()
	armory = ArmorShop.new()
	plasmids = PlasmidShop.new()
	depot_shops = {
		"foint-ammo": WeaponShop.new({"sub": "FOINT-O-MATIC <b>//</b> LOW LOW PRICES, NO QUESTIONS", "cap": "FOINT-O-MATIC", "art": WeaponShop.GUNSHOP_ART, "stock": ["pistol", "legacy_smg", "legacy_deagle", "legacy_rifle", "shotgun", "smg", "rocket", "saw"], "buy_mul": 0.9, "rd_mul": 0.8}),
		"goint-ammo": WeaponShop.new({"theme": "armor", "mode": "gw", "sub": "GOINT ASSURED ARMAMENTS <b>//</b> EVERY ROUND COVERED", "cap": "GOINT ASSURED", "art": ArmorShop.GOINT_ART, "stock": ["deagle", "rifle", "sniper", "legacy_sniper", "legacy_rocket", "arc", "yoke", "bellows"], "buy_mul": 1.15, "rd_mul": 1.25, "full_load": true}),
		"foint-armor": ArmorShop.new({"theme": "weapon", "mode": "fa", "sub": "FOINT FLAK SHACK <b>//</b> ALL SALES FINAL", "art": WeaponShop.GUNSHOP_ART, "stock": ["standard", "phantom_suit", "schleedtech_combat"], "price": {"phantom_suit": 400, "schleedtech_combat": 5200}, "tag": {"phantom_suit": "FOINT RESALE // NO WARRANTY", "schleedtech_combat": "GRAY-MARKET IMPORT"}, "note": "<b>WE BEAT ANY GOINT PRICE</b>. SUITS ARE PRE-OWNED AND SOLD AS SEEN. NO REFUNDS."}),
		"goint-armor": ArmorShop.new({"sub": "GOINT POLICY BOOTH <b>//</b> PREMIUM COVERAGE", "art": ArmorShop.GOINT_ART, "stock": ["standard", "phantom_suit", "goint_gear_xl"], "tag": {"goint_gear_xl": "FLAGSHIP POLICY // GOINT CERTIFIED"}, "note": "EVERY SUIT FACTORY NEW AND <b>GOINT CERTIFIED</b>. DISCOUNT KNOCK-OFFS VOID YOUR COVERAGE."}),
	}


## quitting: a menu that was never opened is not in the tree yet, so nothing else frees it
func dispose() -> void:
	for m: VendorMenu in all():
		if not m.is_inside_tree():
			m.free()
	VendorMenu.stage = null


func all() -> Array:
	var a: Array = [shop, armory, plasmids]
	a.append_array(depot_shops.values())
	return a


func _hub() -> bool:
	return Game.level != null and Game.level.id == "hub"


func near_clerk() -> bool:
	var p := Game.player
	return _hub() and p.y < 1.5 and p.x > 9.0 and p.x < 16.6 and p.z > 5.5 and p.z < 15.5 and U.hyp(p.x - 18.9, p.z - 10.5) < 4.6


func near_armory() -> bool:
	var p := Game.player
	return _hub() and p.y < 1.5 and p.x > 2.4 and U.hyp(p.x - float(ARMORY_PROMPT.x), p.z - float(ARMORY_PROMPT.z)) < float(ARMORY_PROMPT.r)


## where the implant vending machine stands (dev level / hubworld street): { x, z, prompt: { x, z, r } }
func vending_spot() -> Variant:
	return Game.level.get(&"vending") if Game.level != null else null


func near_plasmid() -> bool:
	var M: Variant = vending_spot()
	var p := Game.player
	return M != null and p.y < 1.5 + float(M.get("y", 0.0)) and U.hyp(p.x - float(M.prompt.x), p.z - float(M.prompt.z)) < float(M.prompt.r)


## The machine's sound each frame (JS frame(): its hum within 15 m of the listener, its adverts within 30 m). Their dry sound and reflections fade together.
func vending_audio(dt: float, live: bool) -> void:
	var vm: Variant = vending_spot()
	var active := vm != null and live
	var distance := INF
	if vm != null:
		var y := float(vm.get("y", 0.0))
		distance = Vector3(float(vm.x) - Game.sfx.listener_x, y + 2.2 - Game.sfx.listener_y, float(vm.z) - Game.sfx.listener_z).length()
		Game.sfx.ambient_set("vending", Vector3(float(vm.x), y + 1.5, float(vm.z)), active and distance < 15.0)
	else:
		Game.sfx.ambient_set("vending", null, false)
	vend_ads_step(dt, active and distance < 30.0)


## JS vendAds: the machine's world adverts
func vend_ads_step(dt: float, on: bool) -> void:
	var vm: Variant = vending_spot()
	if not on:
		if vm != null and Game.sfx.ad_playing() and not plasmids.is_open:      # paused / in a menu: the world advert stops
			Game.sfx.ad_stop()
		return
	if Game.sfx.ad_playing():
		return
	vend_ads_t -= dt
	if vend_ads_t > 0.0:
		return
	vend_ads_t = 17.0 + randf() * 6.0
	Game.sfx.ad_play({"x": float(vm.x), "y": float(vm.get("y", 0.0)) + 2.2, "z": float(vm.z)})


## the arms depot the player stands at in the current level ({kind, ...} from its vendors), or an empty Dictionary
func near_depot() -> Dictionary:
	var L: Variant = Game.level.get(&"vendors") if Game.level != null else null
	if not (L is Array):
		return {}
	var p := Game.player
	for v: Dictionary in L:
		if depot_shops.has(v.kind) and v.has("prompt") and absf(p.y - float(v.get("y", 0.0))) < 1.5 and U.hyp(p.x - float(v.prompt.x), p.z - float(v.prompt.z)) < float(v.prompt.r):
			return v
	return {}


func near_tv() -> bool:
	var p := Game.player
	return _hub() and p.y < 1.5 and U.hyp(p.x - 14.09, p.z - 6.96) < 1.9


func near_vendor() -> VendorMenu:
	if near_clerk() and not near_tv():      # (the TV's spot wins over the clerk's prompt)
		return null if Game.combat.clerk == null or Game.combat.clerk.dead else shop
	if near_armory():
		return armory
	if near_plasmid():
		return plasmids
	var d := near_depot()
	return depot_shops[d.kind] if not d.is_empty() else null


## the #shophint for whoever is in reach, or an empty Dictionary
func hint() -> Dictionary:
	if near_tv():      # (the door system's action shows the TV's own prompt)
		return {}
	if near_clerk():
		if Game.combat.clerk != null and Game.combat.clerk.dead:
			return {"text": "SHOP CLOSED — THE CLERK IS DOWN", "cls": "closed", "key": ""}
		return {"text": "Foint n shoot — WEAPONS", "cls": "", "key": "X"}
	if near_armory():
		return {"text": "Goint Life Assurance — ARMOR", "cls": "armor", "key": "X"}
	if near_plasmid():
		return {"text": "DORBATELEPHINIUM IMPLANTS — PLASMIDS", "cls": "plasmid", "key": "X"}
	var d := near_depot()
	if not d.is_empty():
		var h: Array = DEPOT_HINT[d.kind]
		return {"text": h[0], "cls": h[1], "key": "X"}
	return {}
