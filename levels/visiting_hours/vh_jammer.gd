class_name VhJammer
extends RefCounted
## VISITING HOURS: the lockdown rack in 4F security (JS jammer.js): the cabinets that run Stair A's shutter and GOINT's phone jammer (why there has been no Boss since the radio check). Their lamps blink. Wrecked: sparks, a burst of static, the lamps die; the level then lets the Boss back through.

var parent: Node3D
var audio: VhAudio
var bank_a: Node3D
var bank_b: Node3D
var at: Array
var wrecked := false
var t := 0.0
var spark_t := 0.0
var x := 0.0
var y0 := 0.0
var z := 0.0
var m_on := VhKit.unlit(0xff3a20)
var m_on2 := VhKit.unlit(0x40ff70)
var m_dead := MsKit.std(0x2a1a18, 0.8, 0.1)


func _init(lv: ExportedLevel, admin: VhAdmin, p_audio: VhAudio) -> void:
	audio = p_audio
	parent = admin.floors[&"f4"]
	y0 = VhLayout.FLW[&"f4"]
	x = VhLayout.ad_x(float(VhLayout.AD_D.x0) + 0.35) + 0.15      # (the west wall's face; the room's middle)
	z = VhLayout.ad_z(965.4)
	at = [x + 1.5, y0, z]      # where you stand to wreck it (world [x, y, z])
	bank_a = VhKit.one(lv, "vh-bank-a")
	bank_b = VhKit.one(lv, "vh-bank-b")
	reset()


func _put(n: Node3D, m: Material) -> void:
	for mi in VhKit.meshes(n):
		mi.material_override = m


func reset() -> void:
	wrecked = false
	spark_t = 0.0
	_put(bank_a, m_on)
	_put(bank_b, m_on2)


## quiet: a checkpoint past it (no sparks, no static)
func wreck(quiet: bool = false) -> void:
	if wrecked:
		return
	wrecked = true
	_put(bank_a, m_dead)
	_put(bank_b, m_dead)
	if quiet:
		return
	spark_t = 1.6
	audio.noise_burst(1.0, 1.4)
	audio.thud(0.7)
	audio.tone(2400.0, 0.4, 0.08, &"sawtooth")


func update(dt: float) -> void:
	if not parent.visible:
		return
	t += dt
	if not wrecked:
		var b := int(floor(t * 3.0)) % 2 == 1
		_put(bank_a, m_on if b else m_dead)
		_put(bank_b, m_dead if b else m_on2)
	if spark_t > 0.0:
		spark_t -= dt
		if Game.fx != null and randf() < dt * 14.0:
			Game.fx.sparks(Vector3(x + 0.8, y0 + 1.0 + randf() * 1.4, z + (randf() - 0.5) * 4.0), 8, 4.0, Vector3(1.0, 0.3, 0.0))
