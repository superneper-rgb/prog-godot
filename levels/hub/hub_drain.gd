class_name HubDrain
extends RefCounted
## The storm drain in FOINT CITY that leads down to UNDERFOINT (levels/underfoint): an open drain in the dark corner of the yard behind the Deck's last pier on Gleeman, its grate lifted off and left beside it.
## Nothing marks it and nothing lights it: it is found, not shown. A greybox stand-in built from boxes until it is modelled. The door itself is in HubLevel._doors_and_talkers.

const AT := Vector2(-84.2, 441.0)      # x, z of the opening (the yard's north-east corner; the pier stands at -80.6, 443.4)


static func build(level: Level, gy: float) -> void:
	var b := UfBuild.new(level.world)
	b.mat("drain_kerb", Color(0.1, 0.09, 0.12), {"rough": 0.6, "scale": 0.3})
	b.mat("drain_iron", Color(0.12, 0.08, 0.07), {"rough": 0.5, "metal": 0.7, "scale": 0.6})
	var hole := StandardMaterial3D.new()
	hole.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hole.albedo_color = Color.BLACK
	hole.disable_fog = true
	b.mats["drain_hole"] = hole
	var x := AT.x
	var z := AT.y
	b.box("drain_hole", x - 0.7, x + 0.7, gy + 0.005, gy + 0.02, z - 0.7, z + 0.7, false)
	for q: Array in [[-0.95, 0.95, -0.95, -0.7], [-0.95, 0.95, 0.7, 0.95], [-0.95, -0.7, -0.7, 0.7], [0.7, 0.95, -0.7, 0.7]]:      # the kerb round it
		b.box("drain_kerb", x + q[0], x + q[1], gy, gy + 0.14, z + q[2], z + q[3], false)
	b.box("drain_iron", x - 2.75, x - 1.25, gy, gy + 0.07, z - 0.5, z + 1.0, false)      # the grate, dragged aside
	var bar := -0.6
	while bar < 0.65:      # the rungs going down, just under the rim
		b.box("drain_iron", x - 0.7, x - 0.62, gy - 0.02, gy + 0.03, z + bar - 0.03, z + bar + 0.03, false)
		bar += 0.3
	b.commit(level)
