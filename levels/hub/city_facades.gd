class_name CityFacades
extends RefCounted
## FOINT CITY's buildings, finished in Godot: puts levels/shaders/city_facade.gdshader on the exported tower and podium walls (JS CityWalls0-2 and the far shore's, all drawn with the
## JS facadeMaterial over one of three mass skins), levels/shaders/city_shop.gdshader on the shop fronts (JS CityShops, the same material over the shop atlas) and
## levels/shaders/city_roof.gdshader on the roofs (JS CityRoofs), in place of their ported materials. Walls and shops are told apart by the texture the export gave them.
## The district's plain solids get city_trim.gdshader and its glow merge city_glow.gdshader: both fold away the Deck lamps that were cut (levels/hub/deck_look.gd).
## Made at level load, lives with the level.

const OLD := "res://levels/shaders/shader_65916e.gdshader"
## The JS mass skins (city-style.js makeMassSkins), by the name the exporter gave their texture: 0 concrete, 1 steel, 2 glass.
const SKIN_TEX := {"0615ad8a37d12726": 0, "cd6a17f234606b98": 1, "30c82c8aceba5427": 2}
const SHOP_TEX := "512a34e938bbfc35"      # the shop atlas (city-textures.js makeShopUnits)
## Per skin: the base colour, then the windows (bay spacing, the opening in its bay: x0, x1, sill, head, how deep the glass sits, bays to a room).
## Every skin's windows are long low strips (Batman Beyond's towers: runs of light, never a grid of punched holes); the base colours are the JS's.
const SKINS := [
	{"mass": "#191325", "bay": 1.8, "win": Vector4(0.03, 1.77, 1.25, 2.35), "reveal": 0.16, "room_bays": 2.0},
	{"mass": "#15151f", "bay": 1.8, "win": Vector4(0.09, 1.71, 1.2, 2.4), "reveal": 0.12, "room_bays": 3.0},
	{"mass": "#111622", "bay": 1.5, "win": Vector4(0.02, 1.48, 1.15, 2.45), "reveal": 0.04, "room_bays": 3.0},
]

var mats: Array[ShaderMaterial] = []


## Swap the facade material on every wall surface under `root`. `deck`: the Deck, for the lamps it cut. Returns how many surfaces it took.
func build(root: Node, deck: DeckLook) -> int:
	var shader: Shader = load("res://levels/shaders/city_facade.gdshader")
	var shop: Shader = load("res://levels/shaders/city_shop.gdshader")
	var made := {}      # old material -> new
	var n := 0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var old := mi.get_active_material(s) as ShaderMaterial
			if old == null or old.shader == null or old.shader.resource_path != OLD:
				continue
			var tex := old.get_shader_parameter(&"map") as Texture2D
			var key := tex.resource_path.get_file().get_slice("_", 0) if tex != null else ""
			if not SKIN_TEX.has(key) and key != SHOP_TEX:
				continue      # the alley's brick, the signs: neither
			if not made.has(old):
				made[old] = _shop(shop, old) if key == SHOP_TEX else _material(shader, SKIN_TEX[key], float(old.get_shader_parameter(&"uGlow")))
			mi.set_surface_override_material(s, made[old])
			n += 1
	if n == 0:
		push_warning("CityFacades: no tower walls found (were the mass skins re-exported under new names?)")
	n += _roofs(root)
	n += _kit(root, deck)
	return n


## The district's plain solids and its glow merge (JS district-view.js `flat` and `glow`, unlit vertex-colour materials over many pieces). levels/shaders/city_trim.gdshader picks
## the building kit out of the solids by its colours and darkens it; every other colour draws as the plain material drew it. The glow keeps its look in city_glow.gdshader. Both
## fold away the Deck's cut lamps.
func _kit(root: Node, deck: DeckLook) -> int:
	var trim: Shader = load("res://levels/shaders/city_trim.gdshader")
	var glow: Shader = load("res://levels/shaders/city_glow.gdshader")
	var made := {}
	var n := 0
	for d: Node in root.find_children("*FointDistrict", "", true, false):
		for mi: MeshInstance3D in d.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var old := mi.get_active_material(s) as StandardMaterial3D
				if old == null or old.albedo_texture != null or not old.vertex_color_use_as_albedo or not old.vertex_color_is_srgb:
					continue
				if old.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED or old.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or old.next_pass != null or old.disable_fog:
					continue
				var is_glow := old.cull_mode == BaseMaterial3D.CULL_DISABLED and old.albedo_color.r > 1.5      # (the glow merge: both sides, and the export's untone-mapped gain)
				if not is_glow and (old.cull_mode != BaseMaterial3D.CULL_BACK or old.albedo_color != Color.WHITE):
					continue
				if not made.has(old):
					var m := ShaderMaterial.new()
					m.shader = glow if is_glow else trim
					if is_glow:
						m.set_shader_parameter(&"gain", Vector3(old.albedo_color.r, old.albedo_color.g, old.albedo_color.b))
					if deck != null:
						deck.set_cut(m)
					mats.append(m)
					made[old] = m
				mi.set_surface_override_material(s, made[old])
				n += 1
	return n


## JS CityRoofs: one mesh, the membrane texture under the caps' baked colour.
func _roofs(root: Node) -> int:
	var roof: Shader = load("res://levels/shaders/city_roof.gdshader")
	var made := {}
	var n := 0
	for node: Node in root.find_children("*CityRoofs", "", true, false):
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var old := mi.get_active_material(s) as StandardMaterial3D
				if old == null or old.albedo_texture == null:
					continue
				if not made.has(old):
					var m := ShaderMaterial.new()
					m.shader = roof
					m.set_shader_parameter(&"map", old.albedo_texture)
					mats.append(m)
					made[old] = m
				mi.set_surface_override_material(s, made[old])
				n += 1
	if n == 0:
		push_warning("CityFacades: no CityRoofs mesh in the export")
	return n


func _material(shader: Shader, skin: int, glow: float) -> ShaderMaterial:
	var d: Dictionary = SKINS[skin]
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter(&"skin", skin)
	m.set_shader_parameter(&"mass", Color.html(d.mass))
	m.set_shader_parameter(&"glow_k", glow)
	m.set_shader_parameter(&"bay", d.bay)
	m.set_shader_parameter(&"win", d.win)
	m.set_shader_parameter(&"reveal", d.reveal)
	m.set_shader_parameter(&"room_bays", d.room_bays)
	mats.append(m)
	return m


func _shop(shader: Shader, old: ShaderMaterial) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	for p: StringName in [&"map", &"glowMap", &"uGlow"]:
		m.set_shader_parameter(p, old.get_shader_parameter(p))
	mats.append(m)
	return m


## The sky as it drifts (hub_level.gd VIOLET / EMBER, as radiance): the glass and the wet walls carry it.
func set_sky(hor: Vector3, band: Vector3, zen: Vector3) -> void:
	for m in mats:
		m.set_shader_parameter(&"sky_hor", hor)
		m.set_shader_parameter(&"sky_band", band)
		m.set_shader_parameter(&"sky_zen", zen)
