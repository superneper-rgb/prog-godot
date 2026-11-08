class_name WeaponView
extends RefCounted
## The gun held in the hand (JS class WeaponView): one model per weapon loaded from res://assets/weapons/<id>.glb (tools/export/export.mjs), moving parts found by node name;
## muzzle flash, firing kick springs, recoil cycle, the reload's hand path and part motion, each gun's own little animations. The animator reads k / tk / bp / br / reach / open / hand_out
## and writes info.pouch; FX calls flash / fire / dry. Local axes of a model: +Z = muzzle direction, +Y up, +X = character's left.
## A gun without a GLB draws placeholder boxes and warns once. Parts every model needs are listed in PORT_STATUS.md.

const M_NONE := 0
const M_HOLD := 1   # a contact: grab, seat, grip. The hand comes to rest.
const M_SLAM := 2   # arrives fast, accelerating into the stop

# Per-weapon firing response. z / p / y / r: peak weapon kick (metres back, radians muzzle-up, yaw, roll); w / zeta: spring frequency and damping
# (higher w = quicker recovery, low zeta = a little bounce); tp / ty: torso kick (spine lean-back, twist). Heavier weapons kick more and recover slower.
const KICK := {
	"deagle": {"z": 0.07, "p": 0.20, "y": 0.03, "r": 0.06, "w": 24.0, "zeta": 0.42, "tp": 0.10, "ty": 0.03, "flash": 0.065},
	"shotgun": {"z": 0.12, "p": 0.30, "y": 0.03, "r": 0.07, "w": 17.0, "zeta": 0.55, "tp": 0.17, "ty": 0.04, "flash": 0.075},
	"rifle": {"z": 0.035, "p": 0.07, "y": 0.025, "r": 0.03, "w": 34.0, "zeta": 0.60, "tp": 0.04, "ty": 0.02, "flash": 0.045},
	"smg": {"z": 0.022, "p": 0.045, "y": 0.03, "r": 0.025, "w": 40.0, "zeta": 0.60, "tp": 0.03, "ty": 0.02, "flash": 0.04},
	"rocket": {"z": 0.17, "p": 0.18, "y": 0.02, "r": 0.05, "w": 12.0, "zeta": 0.62, "tp": 0.22, "ty": 0.05, "flash": 0.1},
	"sniper": {"z": 0.14, "p": 0.24, "y": 0.025, "r": 0.05, "w": 13.0, "zeta": 0.5, "tp": 0.2, "ty": 0.04, "flash": 0.09},
	"saw": {"z": 0.05, "p": 0.08, "y": 0.025, "r": 0.03, "w": 28.0, "zeta": 0.55, "tp": 0.05, "ty": 0.02, "flash": 0.04},
	"yoke": {"z": 0.14, "p": 0.16, "y": 0.02, "r": 0.04, "w": 12.0, "zeta": 0.6, "tp": 0.2, "ty": 0.04, "flash": 0.04},
	"arc": {"z": 0.02, "p": 0.03, "y": 0.01, "r": 0.01, "w": 30.0, "zeta": 0.6, "tp": 0.02, "ty": 0.01, "flash": 0.04},
	"bellows": {"z": 0.2, "p": 0.2, "y": 0.03, "r": 0.05, "w": 10.0, "zeta": 0.55, "tp": 0.3, "ty": 0.05, "flash": 0.04},
	"pistol": {"z": 0.024, "p": 0.065, "y": 0.012, "r": 0.02, "w": 38.0, "zeta": 0.65, "tp": 0.025, "ty": 0.01, "flash": 0.035},
	"legacy_smg": {"z": 0.022, "p": 0.045, "y": 0.03, "r": 0.025, "w": 40.0, "zeta": 0.60, "tp": 0.03, "ty": 0.02, "flash": 0.04},
	"legacy_deagle": {"z": 0.07, "p": 0.20, "y": 0.03, "r": 0.06, "w": 24.0, "zeta": 0.42, "tp": 0.10, "ty": 0.03, "flash": 0.065},
	"legacy_rifle": {"z": 0.035, "p": 0.07, "y": 0.025, "r": 0.03, "w": 34.0, "zeta": 0.60, "tp": 0.04, "ty": 0.02, "flash": 0.045},
	"legacy_rocket": {"z": 0.17, "p": 0.18, "y": 0.02, "r": 0.05, "w": 12.0, "zeta": 0.62, "tp": 0.22, "ty": 0.05, "flash": 0.1},
	"legacy_sniper": {"z": 0.14, "p": 0.24, "y": 0.025, "r": 0.05, "w": 13.0, "zeta": 0.5, "tp": 0.2, "ty": 0.04, "flash": 0.09},
	"dual_silenced": {"z": 0.012, "p": 0.03, "y": 0.01, "r": 0.015, "w": 40.0, "zeta": 0.65, "tp": 0.012, "ty": 0.008, "flash": 0.025},
	"flail": {"z": 0.08, "p": 0.2, "y": 0.02, "r": 0.05, "w": 14.0, "zeta": 0.5, "tp": 0.26, "ty": 0.04, "flash": 0.04},
}

# muzzle flash / light colour per weapon: warm orange, cyan pod, violet needle, ordinary yellow-white bullet flash, rocket fire
const FLASH_COL := {"deagle": 0xffa040, "smg": 0x6ff0ff, "sniper": 0xb98cff, "rifle": 0xffe0a0, "rocket": 0xff9a30, "shotgun": 0xffd27a,
	"pistol": 0xffdc9a, "legacy_smg": 0xffdc9a, "dual_silenced": 0xffe6c0, "legacy_deagle": 0xffdc9a, "legacy_rifle": 0xffdc9a, "legacy_sniper": 0xffdc9a, "legacy_rocket": 0xff9a30}
const FLASH_DEFAULT := 0xffd27a
const LIGHT_DEFAULT := 0xffa640


## The weapon kick springs (see KICK), read by the Animator.
class Kick:
	var z := 0.0
	var vz := 0.0
	var p := 0.0
	var vp := 0.0
	var y := 0.0
	var vy := 0.0
	var r := 0.0
	var vr := 0.0


## The torso kick springs.
class TorsoKick:
	var p := 0.0
	var vp := 0.0
	var y := 0.0
	var vy := 0.0


class RlPose:
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var pitch := 0.0
	var roll := 0.0
	var yaw := 0.0

	func _init(p_x: float, p_y: float, p_z: float, p_pitch: float, p_roll: float, p_yaw: float) -> void:
		x = p_x
		y = p_y
		z = p_z
		pitch = p_pitch
		roll = p_roll
		yaw = p_yaw


## removable magazine description: axis = direction the mag leaves the weapon, grab = where the left hand holds it
class MagInfo:
	var obj: Node3D
	var rest := Vector3.ZERO
	var axis := Vector3.ZERO
	var len := 0.0
	var rot_x := 0.0
	var grab := Vector3.ZERO


class FireCycle:
	var amt := 0.0
	var t0 := 0.0
	var t1 := 0.0
	var t2 := 0.0

	func _init(p_amt: float, p_t0: float, p_t1: float, p_t2: float) -> void:
		amt = p_amt
		t0 = p_t0
		t1 = p_t1
		t2 = p_t2


class RackInfo:
	var obj: Node3D = null
	var rest := Vector3.ZERO
	var dz := 0.0
	var handle := Vector3.ZERO
	var fire: FireCycle = null


## What the animator and FX know about a gun (JS the object BUILD[id](g) returns). Same names, snake_case.
class Info:
	var id := ""
	var grip_r := Vector3.ZERO
	var grip_l := Vector3.ZERO
	var muzzle := Vector3.ZERO
	var carry := 0.35
	var two := true
	var pistol := false
	var shoulder := false
	var back := 0.0
	var scale := 1.0            # models drawn too large are shrunk as a whole (grips / muzzle follow)
	var kind := "mag"           # mag | shell | pour | carousel | rocket | melee
	var mag: MagInfo = null
	var rack: RackInfo = null
	var rack_on_empty := false  # a partial reload on a bolt-type gun keeps the round in the chamber: no charging handle
	var spare: Node3D = null    # JS info.spare.obj: the spare cartridge / shell / rocket in the left hand
	var hatch: Node3D = null
	var hatch_axis := "x"
	var well := Vector3.ZERO
	var eject: Variant = null   # Vector3 where the brass leaves, or null
	var flash_len := 1.0
	var rl_pose: RlPose = null
	var pouch := Vector3(0.3, -0.5, -0.2)   # the animator writes it every frame
	var dual: AnimDual = null   # dual pistols: next() swaps guns, hold(w, mp, mq) draws them together
	var holster := Vector3.ZERO
	var pour_top := Vector3.ZERO
	var pour_away := Vector3.ZERO
	var mouth := Vector3.ZERO
	var pour_p := 0.0
	var seat := Vector3.ZERO
	var key_hand := Vector3.ZERO
	var appr := Vector3.ZERO
	var appr2 := Vector3.ZERO
	var anim: Anim = null       # the model's own animation (JS tick / post / resync)
	var pose: Callable          # melee models (the flail) place the whole hold themselves: (wv, c, dt, animator)
	var torso: Callable         # melee models twist and fold the body into the swing: (animator, w)
	var display: Node3D = null


## A model's own animation. JS info.tick / info.post / info.resync closures: the state they kept lives in the subclass.
class Anim:
	func tick(_wv: WeaponView) -> void:
		pass

	func post(_wv: WeaponView, _rl: Variant) -> void:
		pass

	func resync() -> void:
		pass


## JAWBREAKER: indexing wheels (one tooth per shot), hopper of balls = the rounds in the gun, refill balls tumbling in.
class AnimDeagle extends Anim:
	var info: Info
	var gears: Array = []          # [big spin node, small spin node, side]
	var balls: Node3D
	var ball_m: Array[Node3D] = []
	var pour: Array[Node3D] = []
	var glow: BaseMaterial3D = null
	var entry := Vector3.ZERO
	var fall := Vector3.ZERO
	var last := 99.0
	var idx := 0
	var cur := 0.0
	var prev_rl := -1.0
	var flash := 0.0

	func tick(wv: WeaponView) -> void:
		var t := WeaponView.now()
		var dt := wv.dt_or_default()
		var rl := wv.rl_u
		if wv.kt < last:                                # one shot = one tooth on the indexing wheels
			idx += 1
			flash = 1.0
		last = wv.kt
		flash = maxf(0.0, flash - dt * 9.0)
		# wheels: index per shot, one more full tooth during the reload's final "cycle the wheel" step
		if prev_rl >= 0.94 and rl < 0.0:
			idx += 1
		prev_rl = rl
		var step := PI * 2.0 / 14.0
		var extra := WeaponView.sstep(0.84, 0.94, rl) if rl >= 0.0 else 0.0
		var tgt := (idx + extra) * step
		cur += (tgt - cur) * (1.0 - exp(-dt * 30.0))
		for G: Array in gears:
			var s: float = G[2]
			var big: Node3D = G[0]
			var sml: Node3D = G[1]
			big.rotation.y = cur * s
			sml.rotation.y = -cur * s * 1.75
		# hopper level = the rounds in the gun; the hopper fills as the reload pours
		var N := Weapons.NEWW
		var mag: float = N.mag if N.mag != 0 else 8.0
		var a := N.ammo
		var take := minf(mag - a, N.reserve)
		var pouring := rl >= 0.0 and rl < 0.78
		var pour_u := clampf((rl - 0.5) / 0.26, 0.0, 1.0) if pouring else 1.0
		var level := a + take * WeaponView.smooth01(pour_u) if pouring else a
		var n := roundi(clampf(level, 0.0, 8.0))
		for i in ball_m.size():
			ball_m[i].visible = i < n
		balls.position.y = 0.004 * sin(wv.kt * 70.0) * exp(-wv.kt * 11.0) + 0.0015 * sin(t * 1.7)   # the balls rattle after each shot, and rock a little at idle
		balls.rotation.y = 0.05 * sin(t * 0.8) + flash * 0.3
		if glow != null:
			glow.albedo_color = Color(1.0, 0.35 + 0.25 * flash + 0.06 * sin(t * 3.0), 0.05 + 0.2 * flash).linear_to_srgb()
		# refill balls tumbling from the container into the hopper
		var pp := info.pour_p
		var live := rl >= 0.0 and rl < 0.8
		for i in pour.size():
			var b := pour[i]
			var q := (pp - 0.04 - i * 0.15) / 0.22 if live else -1.0
			b.visible = q > 0.0 and q < 1.0 and i < maxf(1.0, take)
			if b.visible:
				var p := info.mouth.lerp(entry, minf(1.0, q * 1.6))
				p.y = lerpf(info.mouth.y, fall.y, q * q)
				p.x += sin(i * 2.3) * 0.02 * q
				b.position = p


## LEAD ZEPPELIN: the counterweight cycles in rhythm with every shot, sustained fire shivers the whole assembly.
class AnimRifle extends Anim:
	var body: Node3D
	var cw: Node3D
	var last := 99.0
	var idx := 0

	func tick(wv: WeaponView) -> void:
		var t := WeaponView.now()
		var k := wv.kt
		if k < last:
			idx += 1
		last = k
		cw.position.z = -0.15 - 0.07 * sin(PI * minf(1.0, k / 0.1)) * (1.0 if k < 0.1 else 0.0)   # the counterweight cycles in rhythm with every shot
		var burst := exp(-k * 14.0)
		body.rotation.z = 0.006 * sin(t * 95.0) * burst                  # sustained fire shivers the whole assembly
		body.position.y = 0.0025 * sin(t * 120.0) * burst
		cw.rotation.z += wv.dt_or_default() * 8.0 * burst


## THE SWARM: mechanical gnats streaming in the side chambers, the fresh canister buzzing, launch cells pulsing in turn.
class AnimSmg extends Anim:
	var g: Node3D
	var y0 := 0.0
	var gnats: Array = []          # [node, ph, yy, sp]
	var cg: Array = []             # [node, ph]
	var cells: Array = []          # materials
	var last := 99.0
	var shots := 0

	func tick(wv: WeaponView) -> void:
		var t := WeaponView.now()
		var dt := wv.dt_or_default()
		var rl := wv.rl_u
		if wv.kt < last:                                # one shot = the next launch cell pulses
			shots += 1
		last = wv.kt
		var fire := exp(-wv.kt * 5.0)
		var buzz := 0.3 + fire
		for n: Array in gnats:                          # gnats stir and stream toward the feed at the back
			var sp: float = n[3]
			n[1] = fmod(float(n[1]) + dt * sp * (0.07 + 0.55 * fire), 1.0)
			var k: float = n[1]
			var sc := sin(PI * k)
			var ng: Node3D = n[0]
			ng.position.z = 0.11 - 0.24 * k
			ng.position.y = y0 + float(n[2]) + sin(t * 11.0 + sp * 9.0) * 0.006 * buzz
			ng.scale = Vector3.ONE * (0.3 + 0.7 * minf(1.0, sc * 3.0))
			ng.rotation.x = sin(t * 17.0 + sp * 5.0) * 0.4 * buzz
		var live := 1.0 if (rl >= 0.0 and rl > 0.5 and rl < 0.85) else 0.0
		var amp := 0.004 + 0.006 * live
		for i in cg.size():                             # the fresh canister buzzes
			var c: Array = cg[i]
			var ph: float = c[1]
			var cm: Node3D = c[0]
			cm.position = Vector3(sin(t * 13.0 + ph) * 0.008, -0.04 + i * 0.016 + sin(t * 17.0 + ph * 2.0) * amp, cos(t * 11.0 + ph) * 0.007)
		for i in cells.size():
			var b: float
			if i == shots % 6:
				b = exp(-wv.kt * 10.0)
			else:
				b = 0.15 + 0.08 * sin(t * 6.0 + i)
			if rl >= 0.0:                               # reload: dark until the cells light up in sequence as the gun becomes ready
				if rl < 0.8:
					b = 0.02
				else:
					b = 0.9 if i < (rl - 0.8) * 6.0 / 0.2 else 0.02
			var m: BaseMaterial3D = cells[i]
			var e := 0.25 + 0.75 * minf(1.0, b * 1.4 + 0.2)
			m.albedo_color = Color((0.1 + 0.3 * b) * e, (0.55 + 0.45 * b) * e, (0.8 + 0.2 * b) * e).linear_to_srgb()
		g.position.y = 0.0012 * sin(t * 150.0) * fire   # quick vibrating recoil


## THE LAST WORD: the tuning-fork prongs ring after each shot, the energy chamber dims while the cartridge is out.
class AnimSniper extends Anim:
	var p_t: Node3D
	var p_b: Node3D
	var pt: Node3D
	var bolt: Node3D
	var core: Array = []           # materials of the glowing band and porthole
	var gloss: BaseMaterial3D = null
	var pt_mat: BaseMaterial3D = null

	func tick(wv: WeaponView) -> void:
		var t := WeaponView.now()
		var k := wv.kt
		var rl := wv.rl_u
		var vib := 0.1 * sin(k * 95.0) * exp(-k * 7.0) + 0.004 * sin(t * 40.0)   # prongs ring after each shot, and hum faintly at idle
		var br := 0.7 + 0.3 * exp(-k * 4.0)
		var pv := 0.45 + 0.1 * sin(t * 5.0) + exp(-k * 14.0)
		if rl >= 0.0:                                   # reload: the chamber dims while the cartridge is out, then returns to full brightness
			br = 1.0 - 0.75 * WeaponView.sstep(0.0, 0.3, rl) if rl < 0.3 else (0.25 if rl < 0.8 else 0.25 + 0.75 * WeaponView.sstep(0.8, 1.0, rl))
			pv *= br
			if rl > 0.86:                               # short prong calibration movement
				vib += 0.06 * sin((rl - 0.86) * 60.0) * (1.0 - (rl - 0.86) / 0.14)
		p_t.rotation.x = vib
		p_b.rotation.x = -vib
		var cc := Color(0.75 * br, 0.55 * br, 1.0 * br).linear_to_srgb()
		for m: BaseMaterial3D in core:
			m.albedo_color = cc
		if gloss != null:
			gloss.emission_energy_multiplier = 0.4 + 1.6 * br
		pt.scale = Vector3.ONE * maxf(0.05, pv)
		if pt_mat != null:
			pt_mat.albedo_color = Color(0.85 * minf(1.0, pv + 0.3), 0.7, 1.0).linear_to_srgb()
		bolt.position.z = -0.012 * exp(-k * 6.0) * (1.0 if k < 0.4 else 0.0)   # the side handle twitches as the mechanism settles


## HEAVY ROTATION: the drum indexes to the next rocket after a shot, a physical rocket per chamber, recoil springs, winding key.
class AnimRocket extends Anim:
	var car: Node3D
	var key: Node3D
	var chambers: Array[Node3D] = []
	var springs: Array[Node3D] = []
	var glow: BaseMaterial3D = null
	var last := 99.0
	var idx := 0
	var cur := 0.0
	var key_x := 0.0
	var synced := false
	var prev_rl := -1.0
	var flare := 0.0
	var loaded: Array[bool] = [true, true, true, true, true, true]

	func _sync() -> void:
		var N := Weapons.NEWW
		var want := int(minf(6.0, N.ammo + N.reserve))
		for j in 6:
			loaded[(idx + j) % 6] = j < want

	func resync() -> void:
		synced = false

	func tick(wv: WeaponView) -> void:
		var t := WeaponView.now()
		var dt := wv.dt_or_default()
		var rl := wv.rl_u
		if not synced:
			_sync()
			synced = true
		if wv.kt < last:                                # fire: the ready rocket leaves, the drum indexes to the next chamber
			loaded[idx % 6] = false
			idx += 1
			flare = 1.0
		last = wv.kt
		flare = maxf(0.0, flare - dt * 6.0)
		if rl >= 0.66 and rl < 1.0:
			var N := Weapons.NEWW
			var want := int(minf(6.0, N.ammo + N.reserve))
			var have := loaded.count(true)
			var j := 5
			while j >= 0 and have < want:
				if not loaded[(idx + j) % 6]:
					loaded[(idx + j) % 6] = true
					have += 1
				j -= 1
		if rl < 0.0 and prev_rl >= 0.9:                 # the winding step is done
			key_x += PI
		prev_rl = rl
		var wind := WeaponView.sstep(0.8, 0.93, rl) * PI if rl >= 0.0 else 0.0
		cur += (-idx * PI / 3.0 - cur) * (1.0 - exp(-dt * 24.0))
		car.rotation.z = cur
		key.rotation.z = cur * 2.0 + key_x + wind
		for k in 6:
			chambers[k].visible = loaded[k]
		var sq := 0.22 * sin(minf(wv.kt, 0.3) / 0.3 * PI)   # recoil springs compress, drum kicks back
		for s: Node3D in springs:
			s.scale.z = maxf(1e-3, 1.0 - sq)
		car.position.z = -0.03 * sq * 4.0
		key.position.z = 0.22 - 0.03 * sq * 4.0
		if glow != null:
			glow.albedo_color = Color(1.0, 0.35 + 0.4 * flare, 0.08 + 0.3 * flare).linear_to_srgb()
		car.position.y = 0.002 * sin(t * 1.3)


## SAW-LOOP: after a launch the next disc spins up.
class AnimSaw extends Anim:
	var disc: Node3D
	var pul: Node3D
	var fp: Node3D

	func tick(wv: WeaponView) -> void:
		var k := wv.kt
		var dt := wv.dt_or_default()
		var has := Weapons.NEWW.ammo > 0.0
		var spin := 0.0
		if has:
			spin = 4.0 if k < 0.3 else 4.0 + minf(40.0, (k - 0.3) * 60.0)
		disc.visible = has and k > 0.12
		disc.rotation.y += spin * dt
		pul.rotation.x -= (spin + 2.0) * dt * 0.8
		fp.rotation.x -= spin * dt * 1.8


## MOON YOKE: stones circling the cage as the charge grows, a hanging counterweight lifted by the shot.
class AnimYoke extends Anim:
	var cage: Node3D
	var core: Node3D
	var halo: Node3D
	var cw: Node3D
	var stones: Array[Node3D] = []

	func tick(wv: WeaponView) -> void:
		var dt := wv.dt_or_default()
		var N := Weapons.NEWW
		var ch := N.charge
		N.o += dt * (1.6 + ch * 7.0)
		cage.rotation.z += dt * (0.9 + ch * 6.0)
		cage.rotation.y += dt * 0.5
		var n := 3 + roundi(ch * 5.0)
		var R := 0.07 + ch * 0.045
		for i in stones.size():
			var s := stones[i]
			s.visible = i < n
			var a := N.o + i * 6.2832 / n
			var b := i * 1.9
			s.position = Vector3(cos(a) * R, sin(a * 1.3 + b) * R * 0.55, 0.34 + sin(a) * R)
			s.rotation.x += dt * 3.0
			s.rotation.y += dt * 2.0
		var pulse := 1.0 + 0.15 * sin(N.o * 2.0)
		core.scale = Vector3.ONE * ((0.5 + ch * 1.8) * pulse)
		halo.scale = Vector3.ONE * ((0.6 + ch * 2.4) * pulse)
		var k := wv.kt
		var lift := sin(k / 0.6 * PI) if k < 0.6 else 0.0   # firing briefly lifts the hanging counterweight
		cw.rotation.x = -lift * 0.9 + sin(N.o * 0.4) * 0.03


## ELECTRANATOR: the emitter orb and coils pulse, the charge strip shows the charge.
class AnimArc extends Anim:
	var orb: Node3D
	var halo: Node3D
	var rings: Array[Node3D] = []
	var cells_l: Array[Node3D] = []
	var cells_r: Array[Node3D] = []

	func tick(wv: WeaponView) -> void:
		var dt := wv.dt_or_default()
		var N := Weapons.NEWW
		var on := N.arc
		var ch := clampf(N.ammo / 100.0, 0.0, 1.0)
		N.o2 += dt * (2.0 + on * 24.0)
		orb.scale = Vector3.ONE * ((0.7 + 0.9 * on) * (0.85 + 0.15 * sin(N.o2 * 2.0)) * (0.6 + 0.4 * ch))
		halo.scale = Vector3.ONE * ((0.8 + 1.7 * on) * (0.85 + 0.15 * sin(N.o2 * 1.3)) * ((0.8 + 0.4 * randf()) if on != 0.0 else 1.0) * (0.5 + 0.5 * ch))
		for i in rings.size():
			rings[i].scale = Vector3.ONE * (1.0 + (0.04 + on * 0.16) * sin(N.o2 * 2.0 - i * 0.9))
		var lit := ch * 5.0
		for i in 5:
			var v := lit > i + 0.05 and not (on != 0.0 and i == ceili(lit) - 1 and randf() < 0.5)
			cells_l[i].visible = v
			cells_r[i].visible = v


## BELLOWS BEAST: the accordion squeezes on the shot and breathes at rest, the bell glows.
class AnimBellows extends Anim:
	var bel: Node3D
	var knobs: Array[Node3D] = []
	var glow: BaseMaterial3D = null

	func tick(wv: WeaponView) -> void:
		var dt := wv.dt_or_default()
		var N := Weapons.NEWW
		var k := wv.kt
		var pr := 1.0 - k / 0.5 if k < 0.5 else 0.0
		var rdy := 1.0 if N.ammo > 0.0 else 0.0
		N.o3 += dt * 1.7
		bel.scale.z = 1.0 - 0.32 * pr * pr + 0.012 * sin(N.o3 * 2.6) * rdy   # squeezes on the shot, breathes at rest
		for i in knobs.size():
			knobs[i].position.y = 0.11 - 0.03 * pr * (1.0 - i * 0.2) + 0.004 * sin(N.o3 * 3.0 + i)
		if glow != null:                                 # flashes after a shot, faint hum while loaded
			var c := glow.albedo_color
			c.a = ((1.0 - k / 0.35) * 0.8 if k < 0.35 else 0.0) + rdy * (0.07 + 0.04 * sin(N.o3 * 3.0))
			glow.albedo_color = c


## HUSH TWINS: a suppressed pistol in each hand. R sits at the weapon origin (the right hand, mag and reload work as for one pistol);
## L rides beside it on the character's left (+X), spread wide at low carry and drawn in when aimed (hold).
class AnimDual extends Anim:
	var info: Info
	var R_p: Node3D
	var L_p: Node3D
	var L_slide: Node3D
	var l_rest := Vector3.ZERO
	var r_muz := Vector3.ZERO
	var r_eject := Vector3.ZERO
	var l_grip_r := Vector3.ZERO
	var side := 1
	var spread := 0.44
	var off := Vector3.ZERO
	var k := 0.0
	var last := 0
	var lf := 0.0
	var mq := Quaternion.IDENTITY

	func _l_pos() -> void:
		L_p.position = Vector3(spread, 0.0, 0.0)

	## next shot: swap guns; the flash, tracer start and brass follow whichever one fires, and only that gun's slide cycles
	func next() -> void:
		side ^= 1
		var l := side == 1
		info.muzzle = r_muz
		info.eject = r_eject
		if l:
			info.muzzle = L_p.quaternion * r_muz + L_p.position
			info.eject = L_p.quaternion * r_eject + L_p.position
		info.rack.fire.amt = 0.0 if l else 1.0
		last = side
		k = 0.0

	## aim weight (0 low carry .. 1 aimed): the guns draw together as they come up. With a mirror pose (pos / quat of the left gun
	## in weapon space, mirrored from the right gun across the body) the carry blends to it, so the left arm is the right arm mirrored
	func hold(w: float, mp: Variant, p_mq: Variant) -> void:
		spread = 0.44 + (0.26 - 0.44) * w
		_l_pos()
		mq = Quaternion.IDENTITY
		if mp != null:
			var q_k := 1.0 - w
			mq = Quaternion.IDENTITY.slerp(p_mq, q_k)
			L_p.position = L_p.position.lerp(mp, q_k)
		info.grip_l = mq * l_grip_r + L_p.position

	func tick(wv: WeaponView) -> void:
		var dt := wv.dt_or_default()
		var kt := wv.kt
		k += dt
		# per-gun muzzle flip on the gun that fired; the left gun's slide runs its own recoil cycle (fire.amt keeps R's still)
		var flip := 0.22 * exp(-kt * 22.0) * (1.0 - exp(-kt * 160.0)) if kt < 0.3 else 0.0
		R_p.rotation.x = -flip if last == 0 else 0.0
		lf += ((-flip if last == 1 else 0.0) - lf) * minf(1.0, dt * 60.0)
		var rk := 0.0
		if last == 1 and kt < 0.075:
			rk = kt / 0.014 if kt < 0.014 else 1.0 - (kt - 0.014) / 0.061
		L_slide.position = Vector3(l_rest.x, l_rest.y, l_rest.z - 0.033 * rk)
		# holster for the reload: near the left-hip pouch (the animator sets info.pouch in weapon space before pose_parts)
		info.holster = info.grip_l.lerp(info.pouch, 0.8)

	## reload: the left hand takes its gun to the holster, reloads the right one, then draws it back (hand path in WeaponView._reload_hand)
	func post(wv: WeaponView, rl: Variant) -> void:
		var to := Vector3.ZERO
		var hol := 0.0
		if rl != null:
			var u: float = rl.u
			to = (wv.hand_out if (u <= 0.08 or u >= 0.92) else info.holster) - info.grip_l
			hol = minf(1.0, to.length() / maxf(0.05, info.holster.distance_to(info.grip_l)))
		off = off.lerp(to, minf(1.0, wv.dt_or_default() * (40.0 if rl != null else 14.0)))
		L_p.position += off
		L_p.quaternion = mq * Quaternion.from_euler(Vector3(lf + 1.25 * hol, 0.0, -0.4 * hol))


## SCORPION FLAIL handle: the chain starts at its tip; the arm hangs off the shoulder pivot at swing angle FLAIL.th; the swing's torque spreads over the body.
class AnimFlail extends Anim:
	var g: Node3D
	var disp: Node3D
	var legs := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	var legs_time := -1.0
	var reach := 0.0              # JS wv._flailReach

	## where the chain starts; the real chain replaces the preview one
	func tick(_wv: WeaponView) -> void:
		var F := FlailSim.FLAIL
		F.hand = g.to_global(Vector3(0.0, 0.0, 0.24))
		F.hand_ok = true
		disp.visible = false

	## Retarget the planted ankle to the actual rig's two leg bones; the smaller rig must not slide its lead boot while the hips drive.
	func _plant_leg(an: Animator, side: String, goal: Vector3) -> void:
		var U_b: int = an.by_key[StringName("thigh" + side)].bone
		var S_b: int = an.by_key[StringName("shin" + side)].bone
		var E_b: int = an.by_key[StringName("foot" + side)].bone
		var root := an.bone_world_pos(U_b)
		var knee := an.bone_world_pos(S_b)
		var ankle := an.bone_world_pos(E_b)
		var foot_q := an.bone_world_quat(E_b)
		var a := root.distance_to(knee)
		var b := knee.distance_to(ankle)
		var d := clampf(root.distance_to(goal), 0.001, a + b - 0.001)
		var axis := (goal - root).normalized()
		var goal2 := root + axis * d
		var pole := an.actor.global_transform.basis.get_rotation_quaternion() * Vector3(0.0, 0.0, 1.0)
		pole = (pole - axis * pole.dot(axis)).normalized()
		var along := (a * a - b * b + d * d) / (2.0 * d)
		var out := sqrt(maxf(0.0, a * a - along * along))
		var mark := root + axis * along + pole * out
		an._turn(U_b, (knee - root).normalized(), (mark - root).normalized(), 1.0)
		knee = an.bone_world_pos(S_b)
		ankle = an.bone_world_pos(E_b)
		an._turn(S_b, (ankle - knee).normalized(), (goal2 - knee).normalized(), 1.0)
		an.skel.set_bone_pose_rotation(E_b, (Animator.q_inv(an.bone_world_quat(an._bone_parent[E_b])) * foot_q).normalized())

	## called by the animator (Animator._weapon) once the usual hold has been set: the handle goes to the carry pose (low at the right hip, pointing forward-down) or follows
	## the swing (the arm hangs off the shoulder pivot at swing angle FLAIL.th); the arm IK then follows the grip. c = chest in actor space.
	func pose(wv: WeaponView, c: Vector3, _dt: float, an: Animator) -> void:
		var F := FlailSim.FLAIL
		var k := wv.k
		var pw := F.weight if F.on else 0.0
		var sides: Array[String] = ["L", "R"]
		if pw < 0.001 or F.elapsed < legs_time:
			for i in 2:
				legs[i] = an.actor.to_local(an.bone_world_pos(an.by_key[StringName("foot" + sides[i])].bone))
		legs_time = F.elapsed
		if pw > 0.001:
			var leg_k := (an.B.l1 + an.B.l2) / 0.65
			var step := clampf((F.elapsed - 0.015) / 0.145, 0.0, 1.0)
			var toe_off := FlailSim.sm((F.elapsed - F.wind) / 0.15) * (1.0 - FlailSim.sm((F.elapsed - 0.39) / 0.06))
			for i in 2:
				var target := legs[i]
				target.z += (-0.34 if i == 1 else 0.14) * leg_k * FlailSim.sm(step)
				if i == 1:
					target.y += (0.10 * sin(PI * step) + 0.045 * toe_off) * leg_k
				var w_target := an.actor.to_global(target)
				var ankle := an.bone_world_pos(an.by_key[StringName("foot" + sides[i])].bone)
				_plant_leg(an, sides[i], w_target.lerp(ankle, 1.0 - pw))
		var th := F.th
		var S := 1.15
		var psi := 0.0                                   # hand and head stay in a vertical plane while the body twists underneath
		var cp := 1.0
		var sp := 0.0
		var cx := c.x - 0.3
		var cy := c.y - 0.46
		var cz := c.z + 0.24
		var U_b: int = an.by_key[&"upper_armR"].bone
		var E_b: int = an.by_key[&"forearmR"].bone
		var H_b: int = an.by_key[&"handR"].bone
		var shoulder := an.actor.to_local(an.bone_world_pos(U_b))
		if reach == 0.0:
			reach = (an.bone_world_pos(U_b).distance_to(an.bone_world_pos(E_b)) + an.bone_world_pos(E_b).distance_to(an.bone_world_pos(H_b))) / an.B.scale
		# 45 degree elbow in the coil, nearly straight through the downward drive.
		var extension := lerpf(cos(PI / 8.0), 0.99, FlailSim.sm((F.elapsed - 0.4) / 0.05))
		var rh := reach * extension
		var hx := cx + (shoulder.x + rh * sin(th) * sp - cx) * pw
		var hy := cy + (shoulder.y + rh * cos(th) - cy) * pw
		var hz := cz + (shoulder.z + rh * sin(th) * cp - cz) * pw
		var angle := th - PI / 2.0
		var pitch := lerpf(0.85, atan2(sin(angle), cos(angle)), pw) - k.p
		var cs := cos(pitch)
		var sn := sin(pitch)
		var gz := -0.03 * S
		wv.group.position = Vector3(hx - gz * cs * sp, hy - (-gz * sn), hz - gz * cs * cp - k.z)    # origin = hand - R * grip_r (grip_r only has a z part), turned by the yaw too
		wv.group.rotation = Vector3(pitch, 0.05 * (1.0 - pw) + k.y + psi, 0.1 * (1.0 - pw))

	## called by the animator with the torso poses (Animator.update, next to the firing kick): the swing's torque spread over the hips, spine and chest so no single bone
	## bends far (the head counter-turns to keep looking at the target). psi = turn to his left, lean = forward fold; both are 0 outside a swing.
	func torso(an: Animator, w: float) -> void:
		var F := FlailSim.FLAIL
		var tw := F.psi * w
		var hip := F.hip * w
		var ln := F.lean * w
		var B := an.B
		var stance := F.weight * w
		var pel := an.pose[Animator.PELVIS]
		pel.y = lerpf(pel.y, hip, stance)
		an.pose[Animator.PELVIS] = pel
		an._add(Animator.SPINE1, ln * 0.3, tw * 0.65, 0.0)
		an._add(Animator.SPINE2, ln * 0.7, tw * 0.85, 0.0)
		an._add(Animator.CHEST, ln, tw, 0.0)
		an._add(Animator.HEAD, -ln * 0.3, -tw * 0.2, 0.0)
		an._add(Animator.CLAVICLE_R, 0.0, -0.18 * stance, 0.0)
		an._add(Animator.UPPER_ARM_L, -0.35 * stance + F.settle * 0.12, 0.0, 0.85 * stance)
		an._add(Animator.FOREARM_L, -0.55 * stance, 0.0, -0.2 * stance)
		# Rear foot steps back and plants before the coil finishes. Load that knee, then push off it into the slam.
		var t := F.elapsed
		var leg_k := (B.l1 + B.l2) / 0.65
		var step := clampf((t - 0.015) / 0.145, 0.0, 1.0)
		var load := FlailSim.sm(t / F.wind) * (1.0 - FlailSim.sm((t - F.wind) / 0.14))
		var drive := FlailSim.sm((t - F.wind) / 0.15)
		var toe_off := drive * (1.0 - FlailSim.sm((t - 0.39) / 0.06))
		var hip_z := (-0.16 * load + 0.18 * drive) * leg_k
		var lead_z := 0.14 * leg_k
		var rear_z := -0.34 * leg_k * FlailSim.sm(step)
		var rear_lift := (0.10 * sin(PI * step) + 0.045 * toe_off) * leg_k
		# Both ankles stay reachable as weight travels from the rear leg to the braced lead leg.
		var reach2 := B.l1 + B.l2 - 0.008
		var h_lead := B.ank + sqrt(maxf(0.01, reach2 * reach2 - (lead_z - hip_z) * (lead_z - hip_z)))
		var h_rear := B.ank + rear_lift + sqrt(maxf(0.01, reach2 * reach2 - (rear_z - hip_z) * (rear_z - hip_z)))
		var H := minf(minf(B.hip * (1.0 - F.drop), h_lead), h_rear)
		an.py.y = lerpf(an.py.y, H - B.hip, stance)
		an.py.z = lerpf(an.py.z, hip_z, stance)
		for sd in 2:
			var rear := sd == 1
			var z := (rear_z if rear else lead_z) - hip_z
			var y := H - B.ank - (rear_lift if rear else 0.0)
			var d := clampf(U.hyp(y, z), 0.02, reach2)
			var th := -atan2(z, y) - acos(clampf((B.l1 * B.l1 + d * d - B.l2 * B.l2) / (2.0 * B.l1 * d), -1.0, 1.0))
			var sh := PI - acos(clampf((B.l1 * B.l1 + B.l2 * B.l2 - d * d) / (2.0 * B.l1 * B.l2), -1.0, 1.0))
			var thigh := an.pose[Animator.THIGH_L + sd]
			var shin := an.pose[Animator.SHIN_L + sd]
			var foot := an.pose[Animator.FOOT_L + sd]
			thigh.x = lerpf(thigh.x, th, stance)
			shin.x = lerpf(shin.x, sh, stance)
			thigh.y *= 1.0 - stance
			shin.y *= 1.0 - stance
			foot.x = lerpf(foot.x, -(th + sh) + (0.28 * toe_off if rear else 0.0), stance)
			foot.y = lerpf(foot.y, 0.0 if rear else PI / 9.0, stance)
			an.pose[Animator.THIGH_L + sd] = thigh
			an.pose[Animator.SHIN_L + sd] = shin
			an.pose[Animator.FOOT_L + sd] = foot
			an._g_th[sd] = lerpf(an._g_th[sd], th, stance)
			an._g_sh[sd] = lerpf(an._g_sh[sd], sh, stance)
		# The hair trails a small delayed impulse through recovery.
		if F.settle != 0.0 and an.hair != null:
			an.hair.kick(F.settle * 0.03)


## What an interrupted reload left where: every moving part glides back to rest from it.
class Snap:
	var has_m := false
	var m_pos := Vector3.ZERO
	var m_rx := 0.0
	var m_rz := 0.0
	var m_s := 1.0
	var has_r := false
	var r_pos := Vector3.ZERO
	var has_s := false
	var s_vis := false
	var s_pos := Vector3.ZERO
	var s_rx := 0.0
	var s_s := 1.0
	var h := 0.0


# Polished-finish matcaps for the HUSH TWINS (JS HUSH_FIN): gradient stops over the reflected ray's height, highlight strength, iridescence
const SHADER_HUSH := preload("res://combat/hush_matcap.gdshader")
const HUSH_FIN := {
	"chrome": {"g": [[-1.0, [0.16, 0.15, 0.15]], [-0.05, [0.46, 0.44, 0.42]], [0.0, [0.07, 0.07, 0.08]], [0.08, [0.5, 0.56, 0.66]], [1.0, [0.97, 0.98, 1.0]]], "hl": 1.0, "tint": 0.0},
	"gold": {"g": [[-1.0, [0.22, 0.12, 0.03]], [-0.05, [0.62, 0.41, 0.12]], [0.0, [0.14, 0.08, 0.02]], [0.08, [0.82, 0.58, 0.22]], [1.0, [1.0, 0.93, 0.62]]], "hl": 0.9, "tint": 0.0},
	"ink": {"g": [[-1.0, [0.015, 0.015, 0.02]], [-0.05, [0.05, 0.05, 0.06]], [0.0, [0.01, 0.01, 0.012]], [0.08, [0.1, 0.11, 0.14]], [1.0, [0.42, 0.45, 0.52]]], "hl": 0.85, "tint": 0.0},
	"pearl": {"g": [[-1.0, [0.6, 0.56, 0.5]], [0.0, [0.84, 0.8, 0.74]], [1.0, [0.99, 0.97, 0.93]]], "hl": 0.35, "tint": 0.035},
}
static var _hush_mc: Dictionary = {}
static var _warned := false
static var _placeholder_mat: StandardMaterial3D = null
static var _flash_quad: QuadMesh = null

var group: Node3D
var models: Array[Node3D] = []
var infos: Array[Info] = []
var cur := -1
var pop := 0.0
var bp := Vector3.ZERO          # little weapon kicks during a reload (position, rotation), weapon space
var br := Vector3.ZERO
var reach := 0.0                # how far the hand is toward the pouch
var open := 0.0                 # how open the left hand is
var hand_out := Vector3.ZERO    # JS poseParts(rl, hand): the left-hand target in weapon space
var kt := 99.0
var k := Kick.new()
var tk := TorsoKick.new()
var kw := 20.0
var kzeta := 0.5
var lock := false
var rl_u := -1.0                # reload progress for the model's own animation (-1 = not reloading)
var flash_g: Node3D
var flash_mat: StandardMaterial3D
var flash_cone: MeshInstance3D
var light: OmniLight3D
var flash_t := 0.0
var flash_scale := 1.0
var _dt := 0.016
var _was_rl := false
var _snap: Snap = null
var _blend := 0.0
var _parts: Dictionary = {}     # while a model is built: part name -> node
var _building: Node3D = null
var _building_id := ""
var _from_glb := false
var _missing: PackedStringArray = []
var _bad_parts: PackedStringArray = []


var info: Info:
	get:
		return infos[cur] if cur >= 0 else null


func _init(parent: Node3D) -> void:
	group = Node3D.new()
	group.name = "WeaponView"
	parent.add_child(group)
	for w: Weapons.Def in Weapons.WEAPONS:
		var g := _load_model(w.id)
		g.visible = false
		var i := _build(w.id, g)
		i.id = w.id
		models.append(g)
		infos.append(i)
	if not _warned and not _missing.is_empty():
		_warned = true
		push_warning("weapon models missing (placeholder boxes until tools/export/export.mjs weapons runs): %s" % ", ".join(_missing))
	if not _bad_parts.is_empty():
		push_warning("weapon GLB parts not found by name: %s" % ", ".join(_bad_parts))
	_make_flash()
	group.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for i: Info in infos:                 # ENGINE DIFFERENCE: an Info and its Anim point at each other (AnimDeagle, AnimDual), and RefCounted does not free cycles
			i.anim = null
		for m in models:                     # only the drawn weapon stays in the scene graph: the others are ours to free
			if is_instance_valid(m) and m.get_parent() == null:
				m.free()


static func now() -> float:
	return Time.get_ticks_usec() * 1e-6


static func smooth01(x: float) -> float:
	return 0.0 if x <= 0.0 else (1.0 if x >= 1.0 else x * x * (3.0 - 2.0 * x))


static func sstep(a: float, b: float, x: float) -> float:
	return smooth01((x - a) / (b - a))


## fast attack / slow decay impulse starting at x0 (little weapon kicks when parts seat, slides snap home ...)
static func _kick(x: float, x0: float, w: float) -> float:
	var d := x - x0
	return 0.0 if d <= 0.0 else exp(-d / w) * (1.0 - exp(-d / (w * 0.2)))


func dt_or_default() -> float:
	return _dt if _dt != 0.0 else 0.016


# ---------------------------------------------------------------- models ----
func _load_model(id: String) -> Node3D:
	var path := "res://assets/weapons/%s.glb" % id
	_parts = {}
	_building_id = id
	if ResourceLoader.exists(path):
		var ps: PackedScene = load(path)
		var g: Node3D = ps.instantiate()
		_from_glb = true
		_building = g
		_index_parts(g)
		return g
	_missing.append(id)
	_from_glb = false
	var g := Node3D.new()
	g.name = id
	_building = g
	return g


## part names: the exporter names a node n<idx>_<js name> (exact names are fine too)
func _index_parts(n: Node) -> void:
	for c: Node in n.get_children():
		var nm := String(c.name)
		if c is Node3D:
			if nm.begins_with("n") and nm.find("_") > 1 and nm.substr(1, nm.find("_") - 1).is_valid_int():
				nm = nm.substr(nm.find("_") + 1)
			if not _parts.has(nm):
				_parts[nm] = c
		_index_parts(c)


## A moving part. Missing from the model (no GLB yet): an empty node at the JS rest position, with a box if it is worth seeing.
func _part(nm: String, pos: Vector3 = Vector3.ZERO, rot_x: float = 0.0, box: Vector3 = Vector3.ZERO) -> Node3D:
	var n: Node3D = _parts.get(nm)
	if n == null:
		if _from_glb:
			_bad_parts.append(_building_id + ":" + nm)
		n = Node3D.new()
		n.name = nm
		n.position = pos
		n.rotation.x = rot_x
		_building.add_child(n)
		_parts[nm] = n
		if not _from_glb and box != Vector3.ZERO:
			_add_box(n, box, Vector3.ZERO)
	n.rotation_order = EULER_ORDER_XYZ       # the JS parts turn in Euler XYZ (the group itself keeps YXZ)
	return n


static func _add_box(n: Node3D, size: Vector3, at: Vector3) -> void:
	if _placeholder_mat == null:
		_placeholder_mat = StandardMaterial3D.new()
		_placeholder_mat.albedo_color = Color(0.45, 0.47, 0.5)
		_placeholder_mat.roughness = 0.6
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _placeholder_mat
	mi.mesh = bm
	mi.position = at
	n.add_child(mi)


## the first mesh on or under a part
static func _mesh_of(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c: Node in n.get_children():
		var m := _mesh_of(c)
		if m != null:
			return m
	return null


## A part whose colour the game animates: its own copy of the material, the exporter's baked vertex colours off (the colour is set in full every frame). null without a mesh.
static func _own_mat(n: Node3D) -> BaseMaterial3D:
	var mi := _mesh_of(n)
	if mi == null or mi.mesh == null:
		return null
	var src := mi.mesh.surface_get_material(0) as BaseMaterial3D
	if src == null:
		return null
	var m: BaseMaterial3D = src.duplicate()
	m.vertex_color_use_as_albedo = false
	mi.material_override = m
	return m


## The material a part shares with others (the JS material was one object for all of them).
static func _shared_mat(n: Node3D) -> BaseMaterial3D:
	var mi := _mesh_of(n)
	if mi == null or mi.mesh == null:
		return null
	return mi.mesh.surface_get_material(0) as BaseMaterial3D


## JS magInfo
func _mag_info(obj: Node3D, len: float, grab_at: float = 0.4) -> MagInfo:
	var m := MagInfo.new()
	m.obj = obj
	m.axis = obj.quaternion * Vector3(0.0, -1.0, 0.0)
	m.rest = obj.position
	m.len = len
	m.rot_x = obj.rotation.x
	m.grab = m.rest + m.axis * (len * grab_at)
	return m


## JS rackInfo
func _rack_info(obj: Node3D, dz: float, handle: Vector3, fire: FireCycle) -> RackInfo:
	var r := RackInfo.new()
	r.obj = obj
	r.rest = obj.position if obj != null else Vector3.ZERO
	r.dz = dz
	r.handle = handle
	r.fire = fire
	return r


func _body_box(g: Node3D, i: Info) -> void:
	if not _from_glb:
		_add_box(g, Vector3(0.05, 0.1, i.muzzle.z + i.back), Vector3(0.0, i.muzzle.y, (i.muzzle.z - i.back) * 0.5))


## HUSH TWINS: the matcap materials have no glTF field, so they come through by name and get their reflection here.
func _hush_finish(n: Node) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			if m != null and m.resource_name.begins_with("hush_"):
				var k := m.resource_name.get_slice("_", 1)
				var sm := ShaderMaterial.new()
				sm.shader = SHADER_HUSH
				sm.set_shader_parameter(&"matcap", _hush_matcap(k))
				mi.set_surface_override_material(s, sm)
	for c: Node in n.get_children():
		_hush_finish(c)


## JS hushMatcap: a polished-finish reflection, painted once: a studio sky / horizon / floor plus a hard key highlight.
static func _hush_matcap(k: String) -> ImageTexture:
	if _hush_mc.has(k):
		return _hush_mc[k]
	var f: Dictionary = HUSH_FIN[k]
	var G: Array = f.g
	var hl: float = f.hl
	var tint: float = f.tint
	var N := 128
	var L := Vector3(-0.45, 0.62, 0.64)
	var ll := L.length()
	var data := PackedByteArray()
	data.resize(N * N * 4)
	for j in N:
		for i in N:
			var nx := (i + 0.5) / N * 2.0 - 1.0
			var ny := 1.0 - (j + 0.5) / N * 2.0
			var r2 := nx * nx + ny * ny
			if r2 > 1.0:
				continue
			var nz := sqrt(1.0 - r2)
			var v := maxf(-1.0, minf(1.0, 2.0 * nz * ny + 0.3))      # the reflected ray's height, tilted so faces toward the camera catch sky
			var a: Array = G[0]
			var b: Array = G[G.size() - 1]
			for q in G.size() - 1:
				if v >= float(G[q][0]) and v <= float(G[q + 1][0]):
					a = G[q]
					b = G[q + 1]
					break
			var t := (v - float(a[0])) / maxf(1e-4, float(b[0]) - float(a[0]))
			var d := maxf(0.0, (nx * L.x + ny * L.y + nz * L.z) / ll)
			var h := hl * (pow(d, 70.0) * 1.4 + pow(d, 12.0) * 0.25)
			var o := (j * N + i) * 4
			for ch in 3:
				var cv: float = float(a[1][ch]) + (float(b[1][ch]) - float(a[1][ch])) * t + h
				if tint != 0.0:                                       # pearl: a faint shifting iridescence
					cv += tint * (sin(nx * 5.0) if ch == 0 else (sin(nx * 5.0 + 2.0) if ch == 1 else sin(ny * 5.0 + 4.0)))
				data[o + ch] = clampi(int(cv * 255.0), 0, 255)
			data[o + 3] = 255
	var tx := ImageTexture.create_from_image(Image.create_from_data(N, N, false, Image.FORMAT_RGBA8, data))
	_hush_mc[k] = tx
	return tx


## JS BUILD[id](g), less the modelling: the numbers of the gun, and which nodes move.
func _build(id: String, g: Node3D) -> Info:
	var i := Info.new()
	match id:
		"deagle":
			# JAWBREAKER: cream barrel body with brass bands, a clear spherical hopper of coloured metal balls on top (hinged brass filler cap), brass indexing gears on both sides, brass bell muzzle with an orange core
			var Y := 0.03
			var HY := 0.17
			var HZ := -0.03
			var HR := 0.105
			i.grip_r = Vector3(-0.008, -0.07, -0.06)
			i.grip_l = Vector3(0.014, -0.105, -0.015)
			i.muzzle = Vector3(0.0, Y, 0.27)
			i.carry = 1.4
			i.pistol = true
			i.back = 0.06
			i.kind = "pour"
			i.hatch = _part("hatch", Vector3(0.0, HY + HR - 0.006, HZ - 0.045), 0.0, Vector3(0.09, 0.016, 0.09))
			i.spare = _part("spare", Vector3.ZERO, 0.0, Vector3(0.07, 0.1, 0.07))
			i.spare.visible = false
			i.pour_top = Vector3(0.04, HY + 0.15, HZ)
			i.pour_away = Vector3(0.1, HY + 0.22, HZ - 0.06)
			i.mouth = Vector3(0.0, HY + 0.15, HZ)
			i.rack = _rack_info(null, 0.0, Vector3(0.1, Y - 0.01, 0.07), FireCycle.new(0.0, 0.0, 0.03, 0.17))
			i.flash_len = 1.0
			i.rl_pose = RlPose.new(0.0, -0.05, -0.15, -0.2, 0.9, -0.1)
			var a := AnimDeagle.new()
			a.info = i
			a.balls = _part("balls")
			for n in 8:
				a.ball_m.append(_part("ball%d" % n))
			for n in 5:
				var b := _part("pour%d" % n)
				b.visible = false
				a.pour.append(b)
			for n in 2:
				a.gears.append([_part("gear_big%d" % n), _part("gear_sml%d" % n), 1.0 if n == 0 else -1.0])
			a.glow = _own_mat(_part("glow"))
			a.entry = Vector3(0.0, HY + HR + 0.01, HZ)
			a.fall = Vector3(0.0, HY - 0.02, HZ)
			i.anim = a
		"shotgun":
			# pump shotgun: vented heat shroud, long wooden forend with action bars, side-saddle shells, chunky stock
			i.grip_r = Vector3(0.0, -0.085, -0.095)
			i.grip_l = Vector3(0.0, -0.06, 0.32)
			i.muzzle = Vector3(0.0, 0.03, 0.87)
			i.carry = 0.35
			i.back = 0.34
			i.kind = "shell"
			i.rack = _rack_info(_part("pump", Vector3.ZERO, 0.0, Vector3(0.074, 0.08, 0.1)), -0.15, Vector3(0.0, -0.06, 0.34), FireCycle.new(1.0, 0.16, 0.3, 0.52))
			i.spare = _part("spare", Vector3.ZERO, 0.0, Vector3(0.03, 0.03, 0.07))
			i.spare.visible = false
			i.well = Vector3(0.0, -0.07, -0.02)
			i.eject = Vector3(-0.04, 0.025, -0.03)
			i.flash_len = 1.5
			i.rl_pose = RlPose.new(0.0, -0.02, -0.1, -0.45, 0.95, -0.2)
		"rifle":
			# LEAD ZEPPELIN: blue-and-white bullpup. Magazine behind the grip, angular blue carry handle framing a black-and-brass counterweight, ivory vented handguard, tan forward support, black muzzle brake
			i.grip_r = Vector3(0.0, -0.11, -0.09)
			i.grip_l = Vector3(0.0, -0.1, 0.42)
			i.muzzle = Vector3(0.0, 0.0, 0.8)
			i.carry = 0.35
			i.back = 0.33
			i.scale = 0.7
			i.kind = "mag"
			i.mag = _mag_info(_part("mag", Vector3(0.0, -0.1, -0.22), 0.08, Vector3(0.05, 0.17, 0.08)), 0.17, 0.45)
			i.rack = _rack_info(_part("bolt", Vector3.ZERO, 0.0, Vector3(0.022, 0.02, 0.05)), -0.08, Vector3(0.07, 0.07, -0.02), FireCycle.new(0.9, 0.0, 0.02, 0.09))
			i.rack_on_empty = true
			i.eject = Vector3(-0.05, 0.03, 0.1)
			i.flash_len = 1.0
			i.rl_pose = RlPose.new(0.0, -0.06, -0.1, -0.35, 0.5, -0.1)
			var a := AnimRifle.new()
			a.body = _part("body")
			a.cw = _part("counterweight", Vector3(0.0, 0.154, -0.15))
			i.anim = a
		"smg":
			# THE SWARM: slim red-orange pod with skull emblems, arched top handle, transparent side chambers of mechanical gnats, six cyan launch cells in a steel nose plate, black spikes, brass hardware and status lights
			var Y := 0.03
			i.grip_r = Vector3(0.0, -0.09, -0.09)
			i.grip_l = Vector3(0.0, -0.075, 0.065)
			i.muzzle = Vector3(0.0, Y, 0.28)
			i.carry = 0.35
			i.back = 0.38
			i.kind = "mag"
			i.mag = _mag_info(_part("mag", Vector3(0.0, -0.12, 0.08), 0.0, Vector3(0.05, 0.115, 0.05)), 0.15, 0.45)
			i.rack = _rack_info(_part("latch", Vector3.ZERO, 0.0, Vector3(0.014, 0.018, 0.045)), -0.035, Vector3(0.055, -0.066, 0.1), FireCycle.new(0.4, 0.0, 0.015, 0.05))
			i.flash_len = 0.7
			i.rl_pose = RlPose.new(0.0, -0.06, -0.1, -0.4, 0.5, -0.1)
			var a := AnimSmg.new()
			a.g = g
			a.y0 = Y
			var seed := 77                               # JS armRng(77): the same gnats every time
			for n in 14:
				seed = (seed * 16807) % 2147483647
				var ph := seed / 2147483647.0
				seed = (seed * 16807) % 2147483647
				var yy := (seed / 2147483647.0 - 0.5) * 0.04
				seed = (seed * 16807) % 2147483647
				var sp := 0.7 + seed / 2147483647.0 * 0.6
				a.gnats.append([_part("gnat%d" % n), ph, yy, sp])
			for n in 6:
				a.cg.append([_part("can_gnat%d" % n), n * 1.1])
			for n in 6:
				var m := _own_mat(_part("cell%d" % n))
				if m != null:
					a.cells.append(m)
			i.anim = a
		"sniper":
			# THE LAST WORD: a long, slim jade rifle. Purple energy chamber behind a skinny receiver, a thin skeletal stock and pistol grip, brass tuning-fork muzzle with a violet point, slim mounted scope with violet lenses, brass hardware
			i.grip_r = Vector3(0.0, -0.09, -0.17)
			i.grip_l = Vector3(0.0, -0.1, 0.225)
			i.muzzle = Vector3(0.0, 0.0, 0.8)
			i.carry = 0.35
			i.back = 0.62
			i.kind = "mag"
			i.mag = _mag_info(_part("mag", Vector3(0.0, -0.09, 0.02), 0.0, Vector3(0.044, 0.08, 0.044)), 0.09, 0.45)
			i.rack = _rack_info(_part("latch", Vector3.ZERO, 0.0, Vector3(0.018, 0.012, 0.036)), -0.03, Vector3(0.04, -0.054, 0.09), FireCycle.new(0.0, 0.0, 0.03, 0.14))
			i.flash_len = 1.2
			i.rl_pose = RlPose.new(0.03, -0.05, 0.12, -0.3, 0.4, -0.05)
			var a := AnimSniper.new()
			a.p_t = _part("prong_top", Vector3(0.0, 0.0, 0.46))
			a.p_b = _part("prong_bot", Vector3(0.0, 0.0, 0.46))
			a.pt = _part("point", Vector3(0.0, 0.0, 0.8))
			a.bolt = _part("bolt")
			for nm: String in ["band", "porthole"]:
				var m := _own_mat(_part(nm))
				if m != null:
					a.core.append(m)
			a.gloss = _shared_mat(_part("gloss"))
			a.pt_mat = _own_mat(a.pt)
			i.anim = a
		"rocket":
			# HEAVY ROTATION: yellow-and-purple launcher with an exposed rocket carousel (six red-nosed finned rockets), a big brass winding key, coiled recoil springs and a launch collar on the ready chamber
			var R := 0.112
			var CHZ := 0.19
			i.grip_r = Vector3(0.0, -0.22, -0.055)
			i.grip_l = Vector3(0.0, -0.22, 0.28)
			i.muzzle = Vector3(0.0, R, 0.52)
			i.carry = -0.04
			i.back = 0.4
			i.shoulder = true
			i.hatch = _part("hatch", Vector3(R * 1.43 * cos(0.09), R * 1.43 * sin(0.09), CHZ), 0.0, Vector3(0.012, 0.09, 0.3))
			i.hatch_axis = "z"
			i.kind = "carousel"
			i.rack = _rack_info(null, 0.0, Vector3(0.34, -0.04, 0.2), FireCycle.new(0.0, 0.0, 0.0, 0.0))
			i.spare = _part("spare", Vector3.ZERO, 0.0, Vector3(0.06, 0.06, 0.4))
			i.spare.visible = false
			var s6 := cos(PI / 6.0) * R
			var c6 := sin(PI / 6.0) * R
			i.seat = Vector3(s6, c6, CHZ)
			i.key_hand = Vector3(0.34, -0.04, 0.2)
			i.appr = Vector3(s6 + 0.22, c6 - 0.06, CHZ + 0.16)
			i.appr2 = Vector3(s6 + 0.2, c6 - 0.06, CHZ + 0.1)
			i.flash_len = 2.0
			i.rl_pose = RlPose.new(0.04, -0.06, 0.12, 0.08, 0.12, 0.0)
			var a := AnimRocket.new()
			a.car = _part("carousel")
			a.key = _part("key", Vector3(0.24, -0.04, 0.22))
			for n in 6:
				a.chambers.append(_part("chamber%d" % n))
			for n in 2:
				a.springs.append(_part("spring%d" % n))
			a.glow = _own_mat(_part("glow"))
			i.anim = a
		"saw":
			# SAW-LOOP: teal enamel frame, twin rails carrying a copper-toothed ceramic disc, rear belt-pulley drive, vertical underside grip, forward handle bar (~1.1 m)
			i.grip_r = Vector3(0.0, -0.12, -0.06)
			i.grip_l = Vector3(0.0, -0.07, 0.2)
			i.muzzle = Vector3(0.0, 0.0, 0.68)
			i.carry = 0.35
			i.back = 0.34
			i.kind = "mag"
			i.mag = _mag_info(_part("mag", Vector3(0.0, -0.07, 0.06), 0.0, Vector3(0.07, 0.08, 0.1)), 0.1, 0.5)
			i.rack = _rack_info(_part("pull", Vector3.ZERO, 0.0, Vector3(0.012, 0.03, 0.05)), -0.05, Vector3(0.055, 0.1, -0.12), FireCycle.new(0.8, 0.0, 0.03, 0.14))
			i.eject = Vector3(-0.04, 0.02, 0.0)
			i.flash_len = 0.3
			i.rl_pose = RlPose.new(0.0, -0.06, -0.1, -0.4, 0.45, -0.1)
			var a := AnimSaw.new()
			a.disc = _part("disc", Vector3(0.0, 0.0, 0.47), 0.0, Vector3(0.2, 0.012, 0.2))
			a.pul = _part("pulley", Vector3(0.0, 0.03, -0.17))
			a.fp = _part("front_pulley", Vector3(0.0, 0.0, 0.42))
			i.anim = a
		"yoke":
			# MOON YOKE: navy enamel U-fork with ceramic tips, a brass orbital cage with stones circling it, crossbar grips, a stone counterweight on a rod
			i.grip_r = Vector3(0.0, -0.11, -0.06)
			i.grip_l = Vector3(0.0, -0.085, 0.15)
			i.muzzle = Vector3(0.0, 0.0, 0.34)
			i.carry = 0.35
			i.back = 0.3
			i.kind = "mag"
			i.mag = _mag_info(_part("mag", Vector3(0.0, -0.06, 0.02), 0.0, Vector3(0.06, 0.07, 0.07)), 0.09, 0.5)
			i.rack = _rack_info(_part("lever", Vector3.ZERO, 0.0, Vector3(0.012, 0.03, 0.05)), -0.05, Vector3(0.075, 0.07, -0.1), FireCycle.new(0.0, 0.0, 0.03, 0.14))
			i.eject = Vector3(-0.04, 0.02, 0.0)
			i.flash_len = 0.2
			i.rl_pose = RlPose.new(0.0, -0.06, -0.1, -0.4, 0.45, -0.1)
			var a := AnimYoke.new()
			a.cage = _part("cage", Vector3(0.0, 0.0, 0.34))
			a.core = _part("core", Vector3(0.0, 0.0, 0.34))
			a.halo = _part("halo", Vector3(0.0, 0.0, 0.34))
			a.cw = _part("counterweight", Vector3(0.0, -0.09, -0.19))
			for n in 8:
				a.stones.append(_part("stone%d" % n))
			i.anim = a
		"arc":
			# ELECTRANATOR: gunmetal-blue housing, a copper-coiled steel pylon down the middle with a glowing emitter at its tip, insulator fins either side, charge cells along the frame
			i.grip_r = Vector3(0.0, -0.12, -0.065)
			i.grip_l = Vector3(0.0, -0.115, 0.24)
			i.muzzle = Vector3(0.0, 0.02, 0.8)
			i.carry = 0.4
			i.back = 0.3
			i.kind = "mag"
			i.mag = _mag_info(_part("mag", Vector3(0.0, -0.06, 0.02), 0.0, Vector3(0.05, 0.04, 0.06)), 0.06, 0.5)
			i.rack = _rack_info(null, 0.0, Vector3(0.0, 0.08, -0.1), FireCycle.new(0.0, 0.0, 0.03, 0.14))
			i.eject = Vector3(-0.04, 0.02, 0.0)
			i.flash_len = 0.2
			i.rl_pose = RlPose.new(0.0, -0.06, -0.1, -0.4, 0.45, -0.1)
			var a := AnimArc.new()
			a.orb = _part("orb", Vector3(0.0, 0.02, 0.78))
			a.halo = _part("halo", Vector3(0.0, 0.02, 0.78))
			for n in 6:
				a.rings.append(_part("ring%d" % n, Vector3(0.0, 0.02, 0.2 + n * 0.085)))
			for n in 5:
				a.cells_l.append(_part("cell_l%d" % n))
				a.cells_r.append(_part("cell_r%d" % n))
			i.anim = a
		"bellows":
			# BELLOWS BEAST: purple enamel barrel with a curled cream-plated horn at the back, a black accordion bellows ribbed with coral bands, three brass pressure knobs,
			# and a big scalloped coral horn bell at the muzzle (~1.2 m). The bellows squeezes and the bell glows when it fires.
			i.grip_r = Vector3(0.0, -0.15, -0.1)
			i.grip_l = Vector3(0.0, -0.12, 0.26)
			i.muzzle = Vector3(0.0, 0.0, 0.83)
			i.carry = 0.4
			i.back = 0.34
			i.kind = "mag"
			i.mag = _mag_info(_part("mag", Vector3(0.0, -0.085, 0.04), 0.0, Vector3(0.07, 0.06, 0.11)), 0.1, 0.5)
			i.rack = _rack_info(_part("lever", Vector3.ZERO, 0.0, Vector3(0.016, 0.03, 0.05)), -0.05, Vector3(0.088, 0.03, -0.1), FireCycle.new(0.0, 0.0, 0.03, 0.14))
			i.eject = Vector3(-0.04, 0.02, 0.0)
			i.flash_len = 0.3
			i.rl_pose = RlPose.new(0.0, -0.06, -0.1, -0.4, 0.45, -0.1)
			var a := AnimBellows.new()
			a.bel = _part("bellows", Vector3(0.0, 0.0, 0.215))
			for n in 3:
				a.knobs.append(_part("knob%d" % n, Vector3(0.0, 0.11, 0.1 + n * 0.115)))
			a.glow = _own_mat(_part("glow"))
			i.anim = a
		"pistol":
			# Compact, unbranded black polymer pistol. +Z points down the barrel.
			i.grip_r = Vector3(-0.004, -0.052, -0.056)
			i.grip_l = Vector3(0.011, -0.063, -0.024)
			i.muzzle = Vector3(0.0, 0.045, 0.127)
			i.carry = 1.4
			i.pistol = true
			i.back = 0.06
			i.kind = "mag"
			i.mag = _mag_info(_part("mag", Vector3(0.0, -0.09, -0.063), -0.1, Vector3(0.032, 0.09, 0.034)), 0.10, 0.5)
			i.rack = _rack_info(_part("slide", Vector3(0.0, 0.046, 0.012), 0.0, Vector3(0.05, 0.04, 0.2)), -0.033, Vector3(0.035, 0.055, -0.07), FireCycle.new(1.0, 0.0, 0.014, 0.075))
			i.rack_on_empty = true
			i.eject = Vector3(-0.028, 0.052, -0.003)
			i.flash_len = 0.35
			i.rl_pose = RlPose.new(0.0, -0.035, -0.09, -0.2, 0.65, -0.1)
		"legacy_smg":
			i.grip_r = Vector3(0.0, -0.09, -0.075)
			i.grip_l = Vector3(0.0, -0.05, 0.2)
			i.muzzle = Vector3(0.0, 0.005, 0.485)
			i.carry = 0.35
			i.back = 0.38
			i.kind = "mag"
			i.mag = _mag_info(_part("mag", Vector3(0.0, -0.16, 0.12), 0.05, Vector3(0.03, 0.2, 0.06)), 0.2, 0.45)
			i.rack = _rack_info(_part("bolt", Vector3.ZERO, 0.0, Vector3(0.014, 0.016, 0.03)), -0.06, Vector3(0.04, 0.03, -0.03), FireCycle.new(0.9, 0.0, 0.015, 0.055))
			i.eject = Vector3(-0.04, 0.02, 0.08)
			i.flash_len = 0.7
			i.rl_pose = RlPose.new(0.0, -0.06, -0.1, -0.4, 0.45, -0.1)
		"legacy_deagle":
			# Desert Eagle Mark XIX, 6" barrel, stainless. mag: Y(-92), Z(17) of the JS model's millimetre layout (S = .00138, Z = -.105 + z * S, Y = .04 + y * S)
			i.grip_r = Vector3(-0.008, -0.07, -0.06)
			i.grip_l = Vector3(0.014, -0.105, -0.015)
			i.muzzle = Vector3(0.0, 0.04, 0.272)
			i.carry = 1.4
			i.pistol = true
			i.back = 0.06
			i.kind = "mag"
			i.mag = _mag_info(_part("mag", Vector3(0.0, 0.04 - 92.0 * 0.00138, -0.105 + 17.0 * 0.00138), 0.265, Vector3(0.03, 0.13, 0.055)), 0.13, 0.55)
			i.rack = _rack_info(_part("slide", Vector3.ZERO, 0.0, Vector3(0.05, 0.05, 0.2)), -0.085, Vector3(0.0, 0.075, -0.07), FireCycle.new(1.0, 0.0, 0.03, 0.17))
			i.eject = Vector3(-0.03, 0.055, 0.02)
			i.flash_len = 1.0
			i.rl_pose = RlPose.new(0.0, -0.05, -0.2, -0.5, 0.45, -0.15)
		"legacy_rifle":
			i.grip_r = Vector3(0.0, -0.09, -0.115)
			i.grip_l = Vector3(0.0, -0.045, 0.26)
			i.muzzle = Vector3(0.0, 0.012, 0.84)
			i.carry = 0.35
			i.back = 0.44
			i.kind = "mag"
			i.mag = _mag_info(_part("mag", Vector3(0.0, -0.098, 0.034), -0.06, Vector3(0.034, 0.2, 0.08)), 0.17, 0.45)
			i.rack = _rack_info(_part("bolt", Vector3.ZERO, 0.0, Vector3(0.016, 0.014, 0.03)), -0.08, Vector3(0.045, 0.04, -0.08), FireCycle.new(0.9, 0.0, 0.02, 0.09))
			i.eject = Vector3(-0.04, 0.02, 0.05)
			i.flash_len = 1.0
			i.rl_pose = RlPose.new(0.0, -0.06, -0.1, -0.35, 0.42, -0.1)
		"legacy_sniper":
			i.grip_r = Vector3(0.0, -0.1, -0.135)
			i.grip_l = Vector3(0.0, -0.045, 0.27)
			i.muzzle = Vector3(0.0, 0.012, 1.27)
			i.carry = 0.35
			i.back = 0.57
			i.kind = "mag"
			i.mag = _mag_info(_part("mag", Vector3(0.0, -0.115, 0.08), 0.05, Vector3(0.04, 0.13, 0.075)), 0.14, 0.45)
			i.rack = _rack_info(_part("bolt", Vector3.ZERO, 0.0, Vector3(0.04, 0.04, 0.2)), -0.13, Vector3(0.095, 0.05, -0.13), FireCycle.new(1.0, 0.3, 0.42, 0.62))
			i.eject = Vector3(-0.04, 0.03, 0.06)
			i.flash_len = 1.9
			i.rl_pose = RlPose.new(0.03, -0.05, 0.12, -0.3, 0.25, -0.05)
		"legacy_rocket":
			# modern recoilless launcher: OD tube with steel reinforcement bands, flared muzzle with the warhead seated inside, rear venturi, top loading hatch
			i.grip_r = Vector3(0.0, -0.2, -0.03)
			i.grip_l = Vector3(0.0, -0.2, 0.3)
			i.muzzle = Vector3(0.0, 0.0, 0.8)
			i.carry = -0.04
			i.back = 0.4
			i.shoulder = true
			i.hatch = _part("hatch", Vector3(0.0, 0.098, 0.28), 0.0, Vector3(0.1, 0.012, 0.16))
			i.kind = "rocket"
			i.rack = _rack_info(null, 0.0, Vector3(0.0, 0.13, 0.36), FireCycle.new(0.0, 0.0, 0.0, 0.0))
			i.spare = _part("spare", Vector3.ZERO, 0.0, Vector3(0.1, 0.2, 0.1))
			i.spare.visible = false
			i.well = Vector3(0.0, 0.0, 0.36)
			i.flash_len = 2.0
			i.rl_pose = RlPose.new(0.0, -0.1, 0.0, 0.12, 0.22, 0.0)
		"dual_silenced":
			# A suppressed pistol in each hand. Boutique hitman pair: mirrored colourways (R chrome slide on black, L black slide on chrome), gold barrels in open slide windows.
			var pos_r := _part("gun_r", Vector3.ZERO, 0.0, Vector3(0.03, 0.1, 0.25))
			var pos_l := _part("gun_l", Vector3.ZERO, 0.0, Vector3(0.03, 0.1, 0.25))
			var r_slide := _part("gun_r_slide", Vector3(0.0, 0.046, 0.012))
			var l_slide := _part("gun_l_slide", Vector3(0.0, 0.046, 0.012))
			var r_mag := _part("gun_r_mag", Vector3(0.0, -0.09, -0.063), -0.1)
			_part("gun_l_mag", Vector3(0.0, -0.09, -0.063), -0.1)
			var muz := Vector3(0.0, 0.046, 0.277)
			var ej := Vector3(-0.028, 0.052, -0.003)
			i.grip_r = Vector3(-0.004, -0.052, -0.056)
			i.grip_l = Vector3.ZERO
			i.muzzle = muz
			i.carry = 1.4
			i.pistol = true
			i.back = 0.06
			i.kind = "mag"
			i.mag = _mag_info(r_mag, 0.10, 0.5)
			i.rack = _rack_info(r_slide, -0.033, Vector3(0.035, 0.055, -0.07), FireCycle.new(1.0, 0.0, 0.014, 0.075))
			i.rack_on_empty = true
			i.eject = ej
			i.flash_len = 0.12
			i.rl_pose = RlPose.new(0.0, -0.035, -0.09, -0.2, 0.65, -0.1)
			var a := AnimDual.new()
			a.info = i
			a.R_p = pos_r
			a.L_p = pos_l
			a.L_slide = l_slide
			a.l_rest = l_slide.position
			a.r_muz = muz
			a.r_eject = ej
			a.l_grip_r = Vector3(-0.004, -0.052, -0.056)
			a._l_pos()
			_hush_finish(g)
			i.grip_l = a.l_grip_r + pos_l.position
			i.dual = a
			i.anim = a
		"flail":
			# SCORPION FLAIL handle: black segmented rubber grip with amber bands, a hexagonal steel butt with glowing amber windows, a bronze-ringed head collar
			# with the chain loop. ~0.5 m. In the shop preview the ball hangs from it (display); in the game the ball and chain are drawn in the world and tick hides this one.
			i.grip_r = Vector3(0.0, 0.0, -0.03)
			i.grip_l = Vector3(0.0, -0.08, 0.02)
			i.muzzle = Vector3(0.0, 0.0, 0.24)
			i.carry = 0.35
			i.two = false
			i.back = 0.2
			i.kind = "melee"
			i.eject = Vector3.ZERO
			i.flash_len = 0.1
			i.rl_pose = RlPose.new(0.0, -0.06, -0.1, -0.4, 0.45, -0.1)
			i.display = _part("display", Vector3(0.0, 0.0, 0.238))
			var a := AnimFlail.new()
			a.g = g
			a.disp = i.display
			i.pose = a.pose
			i.torso = a.torso
			i.anim = a
		_:
			push_error("no gun table for weapon '%s'" % id)
	_body_box(g, i)
	return i


func _make_flash() -> void:
	# muzzle flash: two crossed additive quads + a short-lived light
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.disable_fog = true
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	fm.albedo_color = Color(Color.hex(0xffd27aff), 0.95)
	flash_mat = fm
	flash_g = Node3D.new()
	flash_g.name = "Flash"
	if _flash_quad == null:
		_flash_quad = QuadMesh.new()
		_flash_quad.size = Vector2(0.34, 0.34)
	for n in 3:
		var q := MeshInstance3D.new()
		q.mesh = _flash_quad
		q.material_override = fm
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.rotation.z = n * 1.05
		flash_g.add_child(q)
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 0.07
	cone_mesh.height = 0.4
	cone_mesh.radial_segments = 6
	cone_mesh.rings = 1
	cone_mesh.cap_top = false
	cone_mesh.cap_bottom = false
	flash_cone = MeshInstance3D.new()
	flash_cone.mesh = cone_mesh
	flash_cone.material_override = fm
	flash_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash_cone.rotation.x = -PI / 2.0
	flash_cone.position.z = 0.2
	flash_g.add_child(flash_cone)
	flash_g.visible = false
	group.add_child(flash_g)
	light = OmniLight3D.new()
	light.light_color = Color.hex(0xffa640ff)
	light.omni_range = 9.0
	light.omni_attenuation = 2.0         # (three.js' inverse square inside its window)
	light.light_energy = 0.0
	light.visible = false
	group.add_child(light)


## JS wv.set(i)
func set_weapon(i: int) -> void:
	if i == cur:
		return
	cur = i
	pop = 0.0
	lock = false
	_snap = null
	_blend = 0.0
	_was_rl = false
	k = Kick.new()
	tk = TorsoKick.new()
	for n in models.size():
		var m := models[n]
		m.visible = n == i
		if n == i:
			if m.get_parent() != group:
				group.add_child(m)
		elif m.get_parent() != null:
			group.remove_child(m)                # only the drawn weapon stays in the scene graph
	if i >= 0 and infos[i].anim != null:
		infos[i].anim.resync()
	if i >= 0:
		flash_g.position = infos[i].muzzle
		light.position = infos[i].muzzle


func flash(scale: float = 1.0, id: String = "") -> void:
	var col: int = FLASH_COL.get(id, FLASH_DEFAULT)
	flash_mat.albedo_color = Color(Color.hex((col << 8) | 0xff), 0.95)
	light.light_color = Color.hex(((FLASH_COL[id] if FLASH_COL.has(id) else LIGHT_DEFAULT) << 8) | 0xff)
	flash_t = KICK[id].flash if KICK.has(id) else 0.06
	flash_scale = scale
	flash_g.rotation.z = randf() * 6.0
	kt = 0.0
	var i := info
	var L := i.flash_len if (i != null and i.flash_len != 0.0) else 1.0
	flash_cone.scale = Vector3(1.0, L, 1.0)
	flash_cone.position.z = 0.2 * L
	if i != null:                                # dual pistols move the muzzle to whichever gun fires
		flash_g.position = i.muzzle
		light.position = i.muzzle


## firing response: restarts the slide / bolt / pump cycle, kicks the weapon and torso springs, locks the slide back on an empty mag
func fire(id: String, left: float = 1.0) -> void:
	var i := info
	if not KICK.has(id) or i == null:
		return
	var K: Dictionary = KICK[id]
	var kw_v: float = K.w
	kt = 0.0
	kw = kw_v
	kzeta = K.zeta
	lock = left <= 0.0 and i.kind == "mag" and i.rack.obj != null
	var imp := 1.25 * kw_v
	k.vz += float(K.z) * imp
	k.vp += float(K.p) * imp * (0.85 + 0.3 * randf())
	k.vy += float(K.y) * imp * (randf() * 2.0 - 1.0)
	k.vr += float(K.r) * imp * (randf() * 2.0 - 1.0)
	tk.vp += float(K.tp) * imp
	tk.vy += float(K.ty) * imp * (randf() * 2.0 - 1.0)


## empty-fire response: a small dry kick of the weapon
func dry(id: String) -> void:
	if not KICK.has(id) or info == null:
		return
	var K: Dictionary = KICK[id]
	var kw_v: float = K.w
	kt = 0.0
	kw = kw_v
	kzeta = K.zeta
	k.vz += 0.15 * float(K.z) * kw_v
	k.vp += 0.1 * float(K.p) * kw_v


func _springs(dt: float) -> void:
	var n := maxi(1, ceili(dt / 0.007))
	var h := dt / n
	var w := kw
	var z2 := 2.0 * kzeta * w
	var w2 := w * w
	var K := k
	var T := tk
	for _i in n:
		K.vz += (-w2 * K.z - z2 * K.vz) * h
		K.z += K.vz * h
		K.vp += (-w2 * K.p - z2 * K.vp) * h
		K.p += K.vp * h
		K.vy += (-w2 * K.y - z2 * K.vy) * h
		K.y += K.vy * h
		K.vr += (-w2 * K.r - z2 * K.vr) * h
		K.r += K.vr * h
		T.vp += (-w2 * 0.8 * T.p - z2 * 0.8 * T.vp) * h
		T.p += T.vp * h
		T.vy += (-w2 * 0.8 * T.y - z2 * 0.8 * T.vy) * h
		T.y += T.vy * h
	K.z = clampf(K.z, -0.25, 0.25)
	K.p = clampf(K.p, -0.5, 0.5)
	K.y = clampf(K.y, -0.12, 0.12)
	K.r = clampf(K.r, -0.15, 0.15)
	T.p = clampf(T.p, -0.4, 0.4)
	T.y = clampf(T.y, -0.12, 0.12)


## catmull-rom tangent at key k
static func _cat(keys: Array, c: int) -> Vector3:
	var n := keys.size()
	var p0: Array = keys[maxi(0, c - 1)]
	var p1: Array = keys[mini(n - 1, c + 1)]
	var d: float = float(p1[0]) - float(p0[0])
	if d == 0.0:
		d = 1.0
	return (Vector3(p1[1]) - Vector3(p0[1])) / d


## Timed Hermite path through keys [u, p, m]. Velocity is continuous through every key except M_HOLD (a contact: grab, seat, grip)
## where the hand comes to rest, and M_SLAM keys arrive fast (accelerating into the stop). Replaces per-phase smoothstep lerps,
## which stopped dead at every phase boundary and read as robotic.
static func _path(keys: Array, u: float) -> Vector3:
	var n := keys.size()
	if u <= float(keys[0][0]):
		return keys[0][1]
	if u >= float(keys[n - 1][0]):
		return keys[n - 1][1]
	var i := 0
	while i < n - 2 and u > float(keys[i + 1][0]):
		i += 1
	var a: Array = keys[i]
	var b: Array = keys[i + 1]
	var au: float = a[0]
	var du: float = float(b[0]) - au
	var t := (u - au) / du
	var t2 := t * t
	var t3 := t2 * t
	var ap: Vector3 = a[1]
	var bp_: Vector3 = b[1]
	var am: int = a[2]
	var bm: int = b[2]
	var m0 := Vector3.ZERO
	var m1 := Vector3.ZERO
	if am != M_HOLD and am != M_SLAM and i > 0:
		m0 = _cat(keys, i)
	if bm == M_SLAM:
		m1 = (bp_ - ap) * (2.2 / du)
	elif bm != M_HOLD and i + 1 < n - 1:
		m1 = _cat(keys, i + 1)
	return ap * (2.0 * t3 - 3.0 * t2 + 1.0) + m0 * ((t3 - 2.0 * t2 + t) * du) + bp_ * (-2.0 * t3 + 3.0 * t2) + m1 * ((t3 - t2) * du)


static func _set_scale(n: Node3D, s: float) -> void:
	n.scale = Vector3.ONE * maxf(s, 1e-4)        # (a zero scale makes the basis singular)


## Pose the moving parts (slide / bolt / pump / mag / spare cartridge). While reloading (rl != null: { ph, pu, u, k, dur, empty }) this also solves the
## left-hand target in weapon space (hand_out) and fills `bp` / `br` (little weapon kicks), `reach` (how far the hand is toward the pouch)
## and `open` (how open the left hand is). Returns true if hand_out was written.
func pose_parts(rl: Variant) -> bool:
	var i := info
	if i == null:
		return false
	rl_u = float(rl.u) if rl != null else -1.0   # reload progress for the model's own animation (-1 = not reloading)
	var M := i.mag
	var R := i.rack
	var S := i.spare
	if i.anim != null:
		i.anim.tick(self)
	# interrupted reload: remember where every moving part was so it can glide back to rest instead of popping there
	if _was_rl and rl == null:
		var sn := Snap.new()
		if M != null:
			sn.has_m = true
			sn.m_pos = M.obj.position
			sn.m_rx = M.obj.rotation.x
			sn.m_rz = M.obj.rotation.z
			sn.m_s = M.obj.scale.x
		if R != null and R.obj != null:
			sn.has_r = true
			sn.r_pos = R.obj.position
		if S != null:
			sn.has_s = true
			sn.s_vis = S.visible
			sn.s_pos = S.position
			sn.s_rx = S.rotation.x
			sn.s_s = S.scale.x
		if i.hatch != null:
			sn.h = i.hatch.rotation.z if i.hatch_axis == "z" else i.hatch.rotation.x
		_snap = sn
		_blend = 0.2
	_was_rl = rl != null
	if rl != null:
		lock = false
	if i.hatch != null:
		i.hatch.rotation = Vector3.ZERO
	if M != null:
		M.obj.visible = true
		M.obj.position = M.rest
		M.obj.rotation = Vector3(M.rot_x, 0.0, 0.0)
		M.obj.scale = Vector3.ONE
	if S != null:
		S.visible = false
		S.scale = Vector3.ONE
		S.rotation = Vector3.ZERO
	bp = Vector3.ZERO
	br = Vector3.ZERO
	reach = 0.0
	open = 0.0
	var rack := 0.0
	if rl != null:
		rack = _reload_hand(i, rl)
	elif R != null and R.fire != null and R.fire.amt != 0.0:     # recoil cycle: slide / bolt back and forward, pump after the shot
		var f := R.fire
		var c := kt
		if c >= f.t0 and c < f.t1:
			rack = f.amt * smooth01((c - f.t0) / (f.t1 - f.t0))
		elif c >= f.t1 and c < f.t2:
			rack = f.amt * (1.0 - smooth01((c - f.t1) / (f.t2 - f.t1)))
		if lock:                                 # empty: the slide / bolt stays locked back
			rack = maxf(rack, f.amt * smooth01(c / maxf(0.01, f.t1)))
	if R != null and R.obj != null:
		R.obj.position = Vector3(R.rest.x, R.rest.y, R.rest.z + R.dz * rack)
	if rl == null and _blend > 0.0 and _snap != null:   # glide the parts from where the interrupted reload left them back to rest
		_blend = maxf(0.0, _blend - _dt)
		var b := smooth01(1.0 - _blend / 0.2)
		var sn := _snap
		if sn.has_m and M != null:
			M.obj.position = sn.m_pos.lerp(M.obj.position, b)
			M.obj.rotation = Vector3(lerpf(sn.m_rx, M.obj.rotation.x, b), 0.0, lerpf(sn.m_rz, 0.0, b))
			_set_scale(M.obj, lerpf(sn.m_s, 1.0, b))
		if sn.has_r and R != null and R.obj != null:
			R.obj.position = sn.r_pos.lerp(R.obj.position, b)
		if sn.has_s and S != null and sn.s_vis:
			S.visible = b < 0.98
			S.position = sn.s_pos
			S.rotation.x = sn.s_rx
			_set_scale(S, sn.s_s * (1.0 - b))
		if i.hatch != null:
			var hv := lerpf(sn.h, 0.0, b)
			if i.hatch_axis == "z":
				i.hatch.rotation.z = hv
			else:
				i.hatch.rotation.x = hv
		if _blend <= 0.0:
			_snap = null
	if i.anim != null:                           # after the hand path: models with a second piece the left hand carries (dual pistols)
		i.anim.post(self, rl)
	return rl != null


func _reload_hand(i: Info, rl: Variant) -> float:
	var u: float = rl.u
	var ph: String = rl.ph
	var p: float = rl.pu
	var rl_k: int = rl.k
	var M := i.mag
	var R := i.rack
	var S := i.spare
	var gl := i.grip_l
	var pouch := i.pouch
	var hand := Vector3.ZERO
	var rack := 0.0
	var op := 0.0
	var HOLD := M_HOLD
	if i.kind == "mag":
		var ax := M.axis
		var len := M.len
		var gr := M.grab
		var hdl := R.handle
		var skip_rack: bool = i.rack_on_empty and not rl.empty     # a partial reload on a bolt-type gun keeps the round in the chamber: no charging handle
		var mid := gr + ax * (len * 0.5)
		var out := gr + ax * len
		var below := gr + ax * (len * 1.15)
		var dual := i.dual != null                                 # dual pistols: the left hand holsters its own gun first and draws it again last
		var hol := i.holster
		var keys: Array = [[0.0, gl, HOLD]]
		if dual:
			keys.append([0.08, hol, HOLD])
			keys.append([0.16, gr, HOLD])                          # reach for the mag, fingers close
		else:
			keys.append([0.14, gr, HOLD])
		keys.append([0.22, mid, M_NONE])                           # strip it straight out of the well
		keys.append([0.30, out, M_NONE])
		keys.append([0.50, pouch, HOLD])                           # sweep to the pouch and grab a fresh one
		keys.append([0.68, below, M_NONE])                         # bring it up under the well
		keys.append([0.775, gr, M_SLAM])                           # slap it home
		keys.append([0.80, gr, HOLD])
		if skip_rack:
			keys.append([0.9, gr, HOLD])
		else:
			keys.append([0.855, hdl, HOLD])                        # hand on the slide / charging handle
			keys.append([0.895, hdl, HOLD])
		if dual:
			keys.append([0.92, hol, HOLD])
		keys.append([0.98, gl, HOLD])
		hand = _path(keys, u)
		rack = 0.0 if skip_rack else sstep(0.857, 0.88, u) * (1.0 - sstep(0.883, 0.895, u))   # slow pull, snappy release
		hand.z += R.dz * rack
		# magazine: follows the hand while stripping, then falls away with a tumble; the fresh one rides the hand up
		if u < 0.30:
			M.obj.position = M.rest + ax * clampf((hand - gr).dot(ax), 0.0, len)
		elif u < 0.5:
			var tau: float = (u - 0.30) * float(rl.dur)
			var G := 7.5
			var dn := group.global_transform.basis.get_rotation_quaternion().inverse() * Vector3(0.0, -1.0, 0.0)
			M.obj.position = M.rest + ax * (len + 0.4 * tau) + dn * (0.5 * G * tau * tau)
			M.obj.rotation = Vector3(M.rot_x + tau * 4.2, 0.0, tau * 2.3)
			_set_scale(M.obj, 1.0 - maxf(sstep(0.17, 0.3, tau), sstep(0.4, 0.49, u)))
		else:
			_set_scale(M.obj, sstep(0.5, 0.54, u))
			if u < 0.8:
				M.obj.position = M.rest + (hand - gr)
		# weapon: tugs as the mag leaves, cants toward the free hand, bumps when the mag seats, nudges on the rack
		var tilt := sstep(0.44, 0.66, u) * (1.0 - sstep(0.8, 0.88, u))
		bp.y += -0.012 * _kick(u, 0.17, 0.04) + 0.028 * _kick(u, 0.775, 0.045) - 0.01 * _kick(u, 0.886, 0.03)
		bp.z += 0.018 * rack - 0.014 * _kick(u, 0.886, 0.03)
		br.x += 0.05 * _kick(u, 0.17, 0.04) - 0.06 * _kick(u, 0.775, 0.045) - 0.05 * _kick(u, 0.886, 0.03) - 0.08 * tilt
		br.z += 0.13 * tilt
		op = 0.55 * sstep(0.02, 0.10, u) * (1.0 - sstep(0.12, 0.145, u)) + 0.85 * sstep(0.3, 0.36, u) * (1.0 - sstep(0.46, 0.5, u)) \
			+ 0.7 * sstep(0.77, 0.8, u) * (1.0 - sstep(0.82, 0.85, u)) + 0.5 * sstep(0.9, 0.93, u) * (1.0 - sstep(0.96, 1.0, u))
	elif i.kind == "pour":
		# JAWBREAKER: the gun cants to show its hopper, the filler cap opens, a container is tipped in, the cap closes, the left hand turns the indexing wheel
		var top := i.pour_top
		var away := i.pour_away
		var hdl := R.handle
		var sp := S
		hand = _path([[0.0, gl, HOLD], [0.16, pouch, HOLD], [0.32, pouch, HOLD], [0.48, top, M_NONE], [0.74, top, M_NONE],
			[0.8, away, M_NONE], [0.86, hdl, HOLD], [0.94, hdl, HOLD], [0.99, gl, HOLD]], u)
		i.hatch.rotation.x = -1.35 * sstep(0.1, 0.22, u) * (1.0 - sstep(0.76, 0.86, u))
		var tilt := sstep(0.5, 0.6, u) * (1.0 - sstep(0.7, 0.78, u))
		var a := 2.4 * tilt
		sp.visible = u >= 0.3 and u < 0.8
		sp.position = hand
		sp.rotation = Vector3(0.0, 0.0, a)
		_set_scale(sp, sstep(0.3, 0.34, u))
		i.pour_p = clampf((u - 0.5) / 0.26, 0.0, 1.0)
		i.mouth = Vector3(hand.x - sin(a) * 0.07, hand.y + cos(a) * 0.07, hand.z)
		bp.y += 0.01 * _kick(u, 0.3, 0.04) - 0.012 * _kick(u, 0.84, 0.03)
		br.x += -0.04 * _kick(u, 0.84, 0.03)
		br.z += 0.12 * sstep(0.1, 0.3, u) * (1.0 - sstep(0.8, 0.9, u))
		op = 0.8 * sstep(0.1, 0.24, u) * (1.0 - sstep(0.3, 0.36, u)) + 0.5 * sstep(0.76, 0.8, u) * (1.0 - sstep(0.82, 0.86, u)) + 0.6 * sstep(0.95, 0.98, u)
	elif i.kind == "carousel":
		# HEAVY ROTATION: the retaining plate swings open, a physical rocket is pressed into the emptied chamber, the plate closes, the winding key is turned
		var sp := S
		var seat := i.seat
		var kh := i.key_hand
		# Pick up the rocket in front of the left hip. The hand travels around the torso, then comes in from the side of the carousel.
		var pickup := Vector3(maxf(seat.x + 0.28, minf(pouch.x, seat.x + 0.42)), maxf(pouch.y, seat.y - 0.34), maxf(pouch.z + 0.26, seat.z + 0.3))
		var clear := Vector3(seat.x + 0.28, seat.y - 0.15, seat.z + 0.32)
		hand = _path([[0.0, gl, HOLD], [0.16, pickup, HOLD], [0.3, pickup, HOLD], [0.43, clear, M_NONE], [0.53, i.appr, M_NONE], [0.64, seat, M_SLAM],
			[0.7, seat, HOLD], [0.78, i.appr2, M_NONE], [0.84, kh, HOLD], [0.93, kh, HOLD], [0.99, gl, HOLD]], u)
		i.hatch.rotation.z = -1.25 * sstep(0.05, 0.17, u) * (1.0 - sstep(0.72, 0.82, u))
		sp.visible = u >= 0.28 and u < 0.66
		sp.position = hand
		_set_scale(sp, sstep(0.28, 0.32, u))
		bp.y += 0.03 * _kick(u, 0.66, 0.05) - 0.012 * _kick(u, 0.86, 0.04)
		br.x += -0.05 * _kick(u, 0.66, 0.05) + 0.05 * _kick(u, 0.88, 0.04)
		br.z += 0.1 * sstep(0.4, 0.62, u) * (1.0 - sstep(0.8, 0.9, u))
		op = 0.8 * sstep(0.1, 0.28, u) * (1.0 - sstep(0.3, 0.36, u)) + 0.6 * sstep(0.62, 0.68, u) * (1.0 - sstep(0.7, 0.76, u)) + 0.5 * sstep(0.93, 0.95, u)
	elif i.kind == "shell":
		var well := i.well
		var bl := Vector3(well.x, well.y - 0.09, well.z)
		var sp := S
		if ph == "open":
			hand = _path([[0.0, gl, HOLD], [1.0, pouch, HOLD]], p)
			br.z += 0.1 * sstep(0.0, 1.0, p)
			op = 0.8 * sstep(0.3, 0.9, p)
		elif ph == "load":
			var first := rl_k <= 0
			var start := pouch if first else well
			hand = _path([[0.0, start, HOLD], [0.08 if first else 0.26, pouch, HOLD],
				[0.66, bl, M_NONE], [0.9, well, M_SLAM], [1.0, well, HOLD]], p)
			sp.visible = p >= (0.04 if first else 0.24) and p < 0.93
			sp.position = hand
			sp.rotation.x = -0.9 * sstep(0.45, 0.85, p)
			_set_scale(sp, sstep(0.04 if first else 0.24, 0.1 if first else 0.3, p))
			bp.y += 0.016 * _kick(p, 0.9, 0.05)
			br.x += -0.04 * _kick(p, 0.9, 0.05)
			br.z += 0.1
			op = 0.8 * (1.0 - sstep(0.1, 0.28, p)) + 0.6 * sstep(0.9, 0.97, p)
		else:   # pump
			var hdl := R.handle
			hand = _path([[0.0, well, HOLD], [0.22, hdl, HOLD], [0.78, hdl, HOLD], [1.0, gl, HOLD]], p)
			rack = sstep(0.24, 0.48, p) * (1.0 - sstep(0.58, 0.70, p))
			hand.z += R.dz * rack
			bp.z += 0.02 * rack - 0.016 * _kick(p, 0.70, 0.05)
			br.x += -0.05 * _kick(p, 0.70, 0.05) - 0.03 * _kick(p, 0.48, 0.05)
			br.z += 0.1 * (1.0 - sstep(0.1, 0.5, p))
			op = 0.5 * sstep(0.78, 0.86, p) * (1.0 - sstep(0.92, 1.0, p))
		if ph != "load":
			sp.visible = false
	else:   # rocket: a cartridge from the pouch drops into the top hatch
		var w0 := i.well
		var sp := S
		var top := Vector3(w0.x, w0.y + 0.53, w0.z)
		var seat := Vector3(w0.x, w0.y + 0.15, w0.z)
		var press := Vector3(w0.x, w0.y + 0.11, w0.z)
		hand = _path([[0.0, gl, HOLD], [0.46, pouch, HOLD], [0.68, top, M_NONE], [0.77, seat, M_SLAM],
			[0.81, seat, HOLD], [0.85, press, HOLD], [0.97, gl, HOLD]], u)
		if i.hatch != null:                      # hatch swings open for the cartridge
			i.hatch.rotation.x = -1.25 * sstep(0.4, 0.52, u) * (1.0 - sstep(0.8, 0.9, u))
		sp.visible = u >= 0.46 and u < 0.775
		sp.position = Vector3(hand.x, hand.y - 0.15, hand.z)
		_set_scale(sp, sstep(0.46, 0.5, u))
		var tilt := sstep(0.4, 0.62, u) * (1.0 - sstep(0.8, 0.9, u))
		bp.y += 0.034 * _kick(u, 0.775, 0.05) - 0.012 * _kick(u, 0.85, 0.04)
		br.x += -0.05 * _kick(u, 0.775, 0.05) - 0.05 * tilt
		br.z += 0.1 * tilt
		op = 0.8 * sstep(0.12, 0.3, u) * (1.0 - sstep(0.4, 0.46, u)) + 0.6 * sstep(0.78, 0.82, u) * (1.0 - sstep(0.86, 0.9, u)) + 0.5 * sstep(0.9, 0.93, u) * (1.0 - sstep(0.96, 1.0, u))
	hand_out = hand
	reach = clampf(1.0 - hand.distance_to(pouch) / 0.6, 0.0, 1.0)
	open = clampf(op, 0.0, 1.0)
	return rack


func update(dt: float, show: bool) -> void:
	pop = minf(1.0, pop + dt * 6.0)
	_dt = dt
	kt += dt
	_springs(dt)
	var c := (1.0 - pow(1.0 - pop, 3.0)) if (show and cur >= 0) else 0.0
	group.visible = c > 0.02
	var i := info
	group.scale = Vector3.ONE * maxf(0.001, c * 1.15 * (i.scale if i != null else 1.0))   # info.scale: models drawn too large are shrunk as a whole (grips / muzzle follow)
	flash_t = maxf(0.0, flash_t - dt)
	flash_g.visible = flash_t > 0.0
	flash_g.scale = Vector3.ONE * (flash_scale * (0.7 + flash_t * 8.0))
	light.visible = flash_t > 0.0
	light.light_energy = 3.2 * flash_scale / PI if flash_t > 0.0 else 0.0   # (three.js candela -> Godot energy: its lights already multiply by pi)


func muzzle_world() -> Vector3:
	var i := info
	return group.to_global(i.muzzle if i != null else Vector3.ZERO)
