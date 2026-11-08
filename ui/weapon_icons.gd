class_name WeaponIcons
extends RefCounted
## The weapon line-art silhouettes (viewBox 100x50), same SVG paths as ICON in the three.js game (index.html hud.js, weapons/starter-arms.js, weapons/scorpion-flail.js).
## Rasterised once on first use, white, so the UI tints them.

const ICON := {
	"deagle": '<rect x="14" y="24" width="50" height="15" rx="7"/><circle cx="36" cy="15" r="11"/><circle cx="31" cy="13" r="3.4"/><circle cx="40" cy="14" r="3.4"/><circle cx="35" cy="19" r="3.4"/><path d="M64 26h9v11h-9z"/><circle cx="48" cy="34" r="5.5"/><path d="M18 39l-4 9h12l3-9z"/>',
	"shotgun": '<path d="M34 14h60v5H34z"/><path d="M34 21h46v4H34z"/><path d="M4 22l20-4h12v14H24L8 38z"/><path d="M50 26h16v7H50z"/><path d="M36 32h10l-3 15H32z"/>',
	"rifle": '<path d="M2 24l4-4h42v17H8l-6-5z"/><path d="M10 20l5-9h22l5 9"/><path d="M18 14h14v4H18z"/><path d="M48 21h24v16H48z"/><path d="M54 25v8M60 25v8M66 25v8"/><path d="M72 25h14v8H72z"/><path d="M56 37h10v8H56z"/><path d="M24 37l-3 10h8l2-10z"/><path d="M8 37l-2 10h8l2-10z"/>',
	"smg": '<rect x="10" y="20" width="52" height="19" rx="9"/><path d="M24 20c0-10 26-10 26 0"/><rect x="24" y="25" width="30" height="9" rx="2"/><circle cx="33" cy="30" r="1.6"/><circle cx="43" cy="28" r="1.6"/><path d="M62 18h7v23h-7z"/><circle cx="76" cy="24" r="3"/><circle cx="76" cy="30" r="3"/><circle cx="76" cy="36" r="3"/><path d="M12 20L5 12l11 4zM14 39l-7 8 11-4z"/><path d="M24 39l-3 9h9l2-9z"/>',
	"rocket": '<path d="M14 12h52v27H14z"/><path d="M20 18h46M20 25h46M20 32h46"/><path d="M66 16l11 2-11 2zM66 23l11 2-11 2zM66 30l11 2-11 2z"/><path d="M5 25h9M5 19v12"/><circle cx="5" cy="19" r="2.5"/><circle cx="5" cy="31" r="2.5"/><path d="M30 39l-2 9h8l1-9zM54 39l-1 9h8l-1-9z"/>',
	"sniper": '<circle cx="14" cy="27" r="10"/><rect x="24" y="21" width="42" height="12" rx="5"/><rect x="28" y="10" width="36" height="7" rx="3"/><path d="M33 17v4M58 17v4"/><path d="M66 24c10-3 20-5 31-4M66 30c10 3 20 5 31 4"/><path d="M34 33l-3 12h8l2-12zM54 33l-2 12h7l1-12z"/>',
	"fists": '<path d="M10 14h26v22H10z"/><path d="M36 17h6v16h-6z"/><path d="M16 36h14v6H16z"/><path d="M58 14h26v22H58z"/><path d="M52 17h6v16h-6z"/><path d="M62 36h14v6H62z"/>',
	"arc": '<path d="M4 20h22v15H9z"/><path d="M26 24h52v7H26z"/><path d="M33 19v17M41 19v17M49 19v17M57 19v17M65 19v17"/><circle cx="86" cy="27" r="5"/><path d="M80 27h-3M92 22l5-4M92 32l5 4M88 20l1-7M88 34l1 7"/><path d="M12 35l-3 12h8l3-12"/><path d="M42 33h10v6H42z"/>',
	"saw": '<circle cx="62" cy="25" r="15"/><circle cx="62" cy="25" r="5"/><path d="M62 6l3 5h-6zM81 25l-5 3v-6zM62 44l-3-5h6zM43 25l5-3v6zM75 12l-1 6-4-3zM75 38l-6 0 2-4zM49 38l1-6 4 3zM49 12l5 2-3 4z"/><path d="M6 20h40v4H6zM6 28h40v4H6z"/><path d="M12 32h8l-3 14h-8z"/><path d="M30 34h12v4H30z"/>',
	"yoke": '<path d="M40 40V12M68 40V12"/><path d="M36 8h8v6h-8zM64 8h8v6h-8z"/><path d="M40 40h28"/><ellipse cx="54" cy="24" rx="17" ry="7"/><circle cx="54" cy="24" r="3"/><circle cx="44" cy="19" r="2"/><circle cx="64" cy="29" r="2"/><path d="M54 40v4"/><circle cx="54" cy="46" r="3"/><path d="M8 24h28v5H8z"/><path d="M14 29h8l-2 12h-8z"/>',
	"bellows": '<path d="M24 30C10 32 3 24 8 12c2-5 9-4 9 1"/><path d="M24 22h14v13H24z"/><path d="M38 19h22v19H38z"/><path d="M44 19v19M50 19v19M56 19v19"/><path d="M42 12v7M49 12v7M56 12v7"/><path d="M39 11h6M46 11h6M53 11h6"/><path d="M60 24l22-13v34L60 33z"/><path d="M82 11c5 8 5 26 0 34"/><path d="M28 35l-2 11h8l1-11"/><path d="M48 38l-1 8h6l1-8"/>',
	"pistol": '<path d="M18 14h59v11H42l-6 22H22l7-22H18z"/><path d="M42 25h15v10H39M23 17h48M65 10v4M25 10v4"/>',
	"legacy_smg": '<path d="M18 16h50v15H18zM68 20h24v7H68M2 18h16M2 18v20h6l10-9M26 31l-4 15h9l3-15M46 31v17h10V31M63 31l-1 10h6l3-10M25 12h35"/>',
	"dual_silenced": '<path d="M10 8h40v8H30l-4 15h-9l4-15H10zM50 10h22v4H50M30 30h40v8H50l-4 15h-9l4-15H30zM70 32h22v4H70"/>',
	"legacy_deagle": '<path d="M10 16l6-4h66l10 5v10H10z"/><path d="M12 8h17v4H12z"/><path d="M83 8h5v4h-5z"/><path d="M10 22h82M60 12v14"/><path d="M14 26h56l-4 6H46l-4 3H18z"/><path d="M42 32v7h13l3-7"/><path d="M14 26h14l4 20H20z"/><path d="M89 17v7"/>',
	"legacy_rifle": '<path d="M22 14h40v11H22z"/><path d="M62 17h28v4H62z"/><path d="M58 13h18v8H58z"/><path d="M2 18l20-3v14L6 31z"/><path d="M34 25h9l4 21h-9z"/><path d="M20 25h8l-3 16h-8z"/><path d="M32 8h14v5H32z"/>',
	"legacy_sniper": '<path d="M2 19l22-3h24v12H24L8 33z"/><path d="M48 20h44v4H48z"/><path d="M92 17h6v10h-6z"/><path d="M26 9h34v7H26z"/><path d="M60 10h6v5h-6z"/><path d="M22 28h8l-4 14h-8z"/><path d="M36 28h9l2 12h-8z"/><path d="M56 24l-6 11M62 24l-3 11"/>',
	"legacy_rocket": '<path d="M8 17h72v15H8z"/><path d="M2 14h10v21H2z"/><path d="M76 14h10v21H76z"/><path d="M86 17l12 8-12 8z"/><path d="M34 32h8l-1 14h-8z"/><path d="M52 32h8l1 12h-8z"/><path d="M30 10h14v7H30z"/>',
	"flail": '<path d="M5 40l15-11 5 6-14 12z"/><path d="M8 44l-3-3"/><ellipse cx="28" cy="29" rx="2.4" ry="1.6"/><ellipse cx="34" cy="23" rx="2.4" ry="1.6"/><ellipse cx="41" cy="19" rx="2.4" ry="1.6"/><ellipse cx="48" cy="18" rx="2.4" ry="1.6"/><circle cx="68" cy="26" r="12"/><path d="M68 14l-3-7h6zM80 26l7-3v6zM68 38l3 7h-6zM77 17l5-5 1 7zM77 35l6 3-5 4zM59 17l-6-4 1 7zM59 35l-6 4 1-7z"/><circle cx="63" cy="23" r="1.7"/><circle cx="73" cy="23" r="1.7"/><circle cx="68" cy="27" r="2.6"/><path d="M62 33q6-4 12 0M60 20l5 1M76 20l-5 1"/>',
}
static var _cache := {}


## The icon's texture (white strokes, faint fill). Unknown id: an empty transparent one, as ICON[id] || '' draws nothing.
static func tex(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 50" width="100" height="50" stroke="#fff" stroke-width="2" stroke-linejoin="round" fill-opacity=".13" fill="#fff">%s</svg>' % ICON.get(id, "")
	var img := Image.new()
	img.load_svg_from_string(svg, 3.0)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[id] = t
	return t
