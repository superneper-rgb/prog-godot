class_name AI
extends RefCounted
## The AI tuning table of the hostile robots, value for value from `const AI` in the three.js game (index.html enemy.js). Every Robot subclass reads these.

const hp := 60.0
const r := 0.52
const h := 2.05
const step := 0.42
const walk := 1.5
const run := 4.4
const accel := 13.0
const alert_delay := 0.55                       # startle pause between noticing and moving
const reach := 2.15                             # melee reach (centre to centre minus the player's radius is checked in the swing)
# melee: windup, active swing, damage moment inside the swing, recovery, damage
const m_wind := 0.66
const m_act := 0.34
const m_hit := 0.12
const m_rec := 0.95
const m_dmg := 22.0
# ranged bolt
const s_wind := 0.9
const s_act := 0.16
const s_rec := 1.4
const s_dmg := 9.0
const s_speed := 21.0
const s_min := 5.5
const s_max := 26.0
const s_cd := 2.8
# short additive flinch; a flinch never interrupts anything
const flinch := 0.3
const flinch_cd := 0.3
# heavy stagger interrupts; immunity afterwards prevents stun-lock
const stagger := 0.95
const stagger_immune := 1.7
const poise_max := 70.0
const poise_regen := 30.0
const voice_range := 30.0
