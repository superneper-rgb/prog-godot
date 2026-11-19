class_name UfChase
extends Node3D
## UNDERFOINT's way out (user 2026-11-12), rebuilt the same day after the user played the first pass: "nothing climactic or epic", "you just go straight down a track", "the creature isnt really up in
## your face", boarding "phases through a wall" and fades to black; they want a Hollywood-chase escape in the manner of an arcade dinosaur chase, with twists, bumps, explosions, scary noises and a
## Sigil that says aggressive things. This is that, built as an original. Run by the level's last stage:
## THE RUN: the heap is thrown apart (levels/underfoint/uf_throne.gd burst), the Sigil's body (enemies/sigil_beast_view.gd) rises where the cell was, the fallen get up as Taken, and the last train stands
## with its lamps lit in the tunnel through the chamber's north wall. Run to it and climb onto the flatcar. The Sigil is too big for the tunnel: it comes for the mouth, and when you are aboard it hits
## it and brings it down behind you, and the train goes. No fade and no teleport: the tunnel you ran into is the start of the line (levels/underfoint/uf_route.gd).
## THE RIDE: the train stands still and the whole line is moved past it (UfRoute), so it curves, tips and rolls round you while walking, aiming and enemies work as anywhere. The engine and tender are
## set on the line ahead and swing on the bends (levels/underfoint/uf_train.gd). Every beat is placed on the route (_beats): the Sigil bursts out of the fallen mouth, smashes the wall lamps as it scrapes
## along, takes the other bore and comes at you through the arches, burns in SERN's fuel depot, bursts out of the cavern wall behind the viaduct, bounds along the rooftops and throws its Taken at you,
## lands on the line ahead (shoot it off before the train hits it), the bridge comes down behind you, it climbs back up, the train rams SERN's blast door, it runs on the wall of SERN's spiral, and at the
## end it catches the car and holds it, its own television the last target, until you hit it. Then the train goes through SERN's gate, into a level that is not made yet: FOINT CITY's hub for now.
## Its attacks are the first pass's: screens light amber one after another (from behind, from the side, from the line ahead); shoot every lit one before it strikes and it reels, miss and the blow lands on
## you AND tears the last section off the flatcar (three, then the footplate, then nothing: health alone cannot carry you). Taken come off it, run down the line, drop from the roof, climb the parapet,
## are thrown across: frail (one good hit), and no more than ON_CAR on the deck at once (user 2026-11-12: Prog's fighting is not made for a crowd on a 3 m wide car).
## No timers on screen: the cue is the wind-up and the screens blinking faster. The Sigil's and the Ticket Man's words are the user's to replace (the Sigil's are voiced: levels/underfoint/uf_chase_audio.gd).
## THE FIGHT, reworked 2026-11-15 from an audit the user chose fixes from (9 of its 11 attacks were the same rear attack, ~10 s stretches with nothing to shoot, set pieces only to watch, weak hits, a torn
## section that drifted off and vanished). Its attacks are now kinds (Att): rear (it closes on the tail, the screens light one after another), far (they light 34 m back and it charges while you shoot:
## the targets grow as it comes), chain (one screen at a time, in order, each with its own short window), swipe (one arm raised over the car, one screen to shoot: miss it and the scythe sweeps the deck,
## JUMP it or be cut), side (through the arches, off the parapet: left or right), wall (from the spiral's wall, rolled over you), ceiling (upside down on the tunnel's roof), front (on the line ahead),
## climb (hauling itself up the viaduct's side: blind it and it loses its grip) and crt (the end). The curve is more than the count: windows shrink, the lighting quickens, the chains shorten, it
## charges from further, the track is bad while you shoot. The set pieces are the player's to use (Prop): shoot a fuel tank as it passes and it burns; shoot a roof's water tank before it lands
## and the roof goes in under it; shoot the blast door's two locks and the engine goes through clean (miss them and it hits hard, and the Sigil closes). Hits read (_react: its body kicked
## round from the screen, arms thrown, a hit-stop, sparks and a burst of glass-light) and score like an arcade rail shooter (_score: a chain multiplier, a speed bonus for each set, the set pieces):
## the running score sits in the objective panel, points rise off what you hit, and a grade is given at the gate. Lines queue (_line): one subtitle at a time, the Sigil's voice first.
## THE INTENSITY PASS, 2026-11-15 (user: the ride "feels kind of boring and unintimidating"; a bot ride measured the Sigil 35 to 45 m from the camera most of the way, no blow landed in 161 s, and one
## framing for 88% of it). What changed, and what the paragraphs above no longer say right:
## - Free shooting is back (user: "I like it better it just felt so difficult"): Prog fights from the deck with his own guns, the car's locker keeps his spare rounds up, a screen is one rifle
##   round, and the crosshair is pulled the last few degrees onto a lit screen (_aim_pull). SERN's gun is one moment: it comes alive when the Sigil is on the engine, and dies when it grabs the car.
## - It is close: it rests over the car's tail (REST_GAP), snaps at the car between attacks, and its attacks happen on the car.
## - Two rules, two colours (agreed with the user so a player can learn them in three minutes): AMBER IS SHOT (its screens, the sets it throws: _throw_set, the tanks, the door's locks), RED IS
##   JUMPED (the swipe: no screen now, its blade burns red and a jump clears it; the first one that lands only stings). The first minute is amber only.
## - A blow is health only. The car is taken apart by the ride (_rip), whatever the player does: the tail in the twin bores (_tick_rake), the middle on the viaduct (_pounce_land), the last
##   at the end (_uncouple). A stretch cleared gives 40 health back.
## - The big moments: its arm through the arches (_tick_rake); the depot going up behind the train and it coming out of the fire alight, burning from then on (_firestorm); the train jumping
##   the fallen span and it jumping after onto the tail, the car tipping (_tick_hop, _pounce); it on the engine and the gun (_to_engine, the "engine" attack); the Ticket Man cutting the car
##   loose with it still holding on (_uncouple).
## - Weight and speed: every foot that comes down throws dust, sparks and grit (_tick_feet); it goes through the signal frames over the line and its face is on the wall monitors
##   (levels/underfoint/uf_route.gd _dress); screens shot out stay dark (_dead); the cash and the objective panel are put away for the ride (_hide_hud).

const Y := UnderfointLevel.STATION_Y
const HOME := UfRoute.HOME
const DECK := UfTrain.DECK
const SEC := UfTrain.SEC
const BOARD := Vector2(70.0, 300.0)      # the step at the flatcar's tail, the train standing
const WALL_Z := 263.0                    # how far north the Sigil gets on foot: the tunnel's mouth is too small for it
const BODY_HP := 1000000.0
const POINT_HP := 18.0                   # (24: two rifle rounds. One now: free shooting is back and a screen is one good shot, user 2026-11-15)
const BLOW := 34.0
const MINION_HP := 20.0                  # one rifle round
const ON_CAR := 2                        # how many Taken may be on (or in the air to) the deck at once
const REST_GAP := 9.5                    # how far behind the tail its feet are between attacks (its head and arms reach a good way past them). (16 until 2026-11-15: a bot ride measured it
                                         # 35 to 45 m from the camera for most of the ride, a small figure down a tunnel. It now stands over the tail.)
## the ride's camera, in place of Config's walking values: [between its attacks, while it is over the car]
## (2026-11-15: the view stands higher and looks up a little: with the Sigil over the tail, a level view from behind Prog had Prog standing in front of it)
const CAM := {"cam_dist": [4.4, 3.9], "cam_dist_strafe": [4.0, 3.6], "cam_dist_aim": [3.1, 2.9], "cam_height": [1.75, 1.6], "cam_pitch_default": [-0.1, -0.2]}
const CAM_FOV := [4.0, 7.0]              # degrees wider than the game's lens
const PORTAL := preload("res://levels/shaders/uf_portal.gdshader")
## how fast the train runs through each named piece of the line, m/s
## (2026-11-15: a little faster out in the open, on the viaduct and the last straight)
const SPEED := {"portal": 20.0, "s1": 21.0, "sweep": 24.0, "right": 21.0, "twin": 25.0, "broken": 17.0, "hairpin": 16.0, "depot": 22.0, "climb": 20.0, "mouth": 22.0,
	"s2": 29.0, "roofs": 28.0, "side2": 27.0, "ahead": 29.0, "climbback": 28.0, "blast": 29.0, "s3": 28.0, "bend_l": 23.0, "bend_r": 23.0, "helix": 21.0, "straight": 33.0, "finale": 26.0, "beyond": 32.0}
## the air the line runs through (the haze's colour and thickness): the tunnels keep the level's own; out on the viaduct it thins and lightens so the dead city and FOINT's piles stand dark against it;
## SERN's line is cold, its gate hall violet
const AIR := {"viaduct": [Color("2c3b35"), 0.0062], "blast": [Color("2c3b35"), 0.0062], "sern": [Color("10161d"), 0.012], "gate": [Color("1b1628"), 0.0095]}
const AIR_HOME := [Color("16221c"), 0.011]
const BARKS := ["come", "still", "give", "mine"]
const BARK_TEXT := {"come": "COME HERE.", "still": "HOLD STILL.", "give": "GIVE HIM TO ME.", "mine": "MINE."}
const LINES := {"run1": "Run. They all ran.", "run2": "Your legs don't know it yet. You are already mine.", "board": "A train. Where could it take you that I am not?",
	"eyes": "You break my eyes. I have more.", "people": "Those were people, once.", "pieces": "Pieces. I can use pieces.", "take": "Take him.", "all": "All of you. NOW.",
	"down": "Look down. All of it is mine.", "ahead": "Where are you going? I am already there.", "obey": "I was made to be obeyed.", "portal": "That light is SERN's. No. NO.",
	"have": "I HAVE YOU.", "quiet": "Be quiet. Be QUIET.", "screens": "Every screen you pass. I will be in it."}
const SWIPE_FIRST := 10.0                 # the first red blade you fail to jump only stings: it is the lesson
const SWIPE_DMG := 24.0                  # the scythe across the deck (a swipe not interrupted and not jumped): health only, the car keeps its sections
const DOOR_DMG := 18.0                   # the blast door hit with its locks on: what comes across the deck
## points (an arcade rail shooter's: a screen, x the chain; a set cleared, and the time it had left; the set pieces)
const PTS := {"screen": 100, "set": 500, "fast": 1000, "tank": 2500, "roof": 2000, "door": 1500, "climb": 2000, "swipe": 800, "jump": 300, "taken": 50, "taken_air": 150, "crt": 5000, "tv": 250}
const CRT_GREEN := Color("7be34a")
## its body's collision: [bone, radius, half height] for an upright cylinder at each part, read off its skeleton every frame (see _tick_hull). Each leg's thigh gets one from hip to knee.
const HULL := [["body_0", 1.7, 1.8], ["body_1", 1.7, 1.7], ["body_2", 1.6, 1.7], ["body_3", 1.4, 1.4], ["body_4", 1.2, 1.2], ["tail_0", 0.9, 0.8], ["tail_1", 0.7, 0.7], ["tail_2", 0.6, 0.6],
	["neck_0", 0.8, 0.9], ["neck_1", 0.8, 0.9], ["neck_2", 0.75, 0.8], ["neck_3", 0.75, 0.8], ["neck_4", 0.75, 0.8], ["head", 1.3, 1.3], ["arm_L_1", 0.5, 1.4], ["arm_L_2", 0.5, 1.4],
	["arm_R_1", 0.5, 1.4], ["arm_R_2", 0.5, 1.4]]
const BEAST_W := 6.5                     # half its width across its feet (its stance; enemies/sigil_beast_view.gd fit_w narrows it where it has the property)
const ENCLOSED: Array[String] = ["trunk", "broken", "twin", "depot", "mouth", "blast", "sern", "gate"]
const CRT_AMBER := Color("ffb43c")


## One attack, as the line asks for it: what kind (see the header), how many screens, how long
class Att:
	var kind := "rear"
	var n := 3
	var window := 5.0                    # the set's time; chain: each screen's; swipe: the one screen's
	var stagger := 0.3                   # seconds between screens lighting
	var arm := 1.0                       # swipe: which arm (1 its left, -1 its right); side: which side of the line (1 left)
	var lit_t := 0.0                     # how long the set has been lit (its speed bonus)
	var at := 0.0                        # when the line asked for it (a queued one goes stale)
	var rounds := 1                      # engine: how many sets before it is off


## Something on the line you can shoot (a fuel tank, a roof's water tank, one of the blast door's locks): its target rides the moving line, an amber lamp on it says when it counts
class Prop:
	var kind := ""
	var sig := 0.0
	var u := 0.0
	var h := 0.0
	var k := 0                           # which tank, roof or lock
	var tgt: Target
	var lamp: MeshInstance3D
	var light: OmniLight3D               # its lamp lighting the thing it is on, pulsing (a lamp alone was a dot at 30 m)
	var live := false
	var gone := false


## A section torn off the car: hanging by its coupling, then down on the line and left behind (its place in the line's own terms, so the bends carry it)
class Torn:
	var nd: Node3D
	var k := 0
	var t := 0.0
	var free := false                    # off the coupling
	var sig := 0.0
	var u := 0.0
	var h := 0.0
	var vs := 0.0                        # along the line, m/s (the train's speed when it let go, shed in the skid)
	var vu := 0.0
	var vh := 0.0
	var rot := Basis.IDENTITY
	var spin := Vector3.ZERO
	var spark_cd := 0.0
	var kicked := false                  # the Sigil has come up on it and booted it off the line


## One of its dead television sets, thrown at the car: its screen burns amber (amber is shot), shoot it out of the air or it lands where he stood when it was thrown
class Thrown:
	var nd: Node3D
	var tgt: Target
	var live := false
	var t := 0.0
	var dur := 1.6
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var spin := Vector3.ZERO


## A line to show: one at a time, the Sigil's voice before the Ticket Man's shouts, and a shout that waited too long is dropped
class Line:
	var who := ""
	var key := ""
	var text := ""
	var prio := 0                        # 2 the Sigil (voiced), 1 a shout that tells you what to do, 0 colour
	var voiced := false
	var at := 0.0                        # when it was asked for

var lv: UnderfointLevel
var route: UfRoute
var train: UfTrain
var turret: UfTurret                     # SERN's gun at the front of the car (levels/underfoint/uf_turret.gd): he mans it for the ride
var audio: UfChaseAudio
var beast: SigilBeastView = null
var mode := &"off"                       # off | run | ride | out
var aboard := false
var stretch := 0
var done := 0                            # stretches finished
var sections := 3
var s := 0.0                             # where the train is on the line
var v := 0.0                             # and how fast it is going

# the Sigil, in the line's terms (route sigma, across it, up off it, rolled about it)
var b_mode := &"chase"                   # buried | chase | side | depot | roofs | gone | ahead | fallen | climb | wall | grab
var b_sig := 0.0
var b_u := 0.0
var b_h := 0.0
var b_roll := 0.0
var gap := 30.0
var gap_want := REST_GAP
var _b_t := 0.0
var _land_sig := 0.0
var _burn := 0.0
var _lunge := -1.0
var _step_t := 0.0
var _roof_k := -1
var _scrape_cd := 0.0
var _visible_b := true
var _mode_next := &""                    # a move the line asked for while it was in the middle of an attack: made when the attack is over
var _climb_sig := 0.0                    # the pier it is hauling itself up (a place on the line: the train leaves it behind)
var _climb_k := -1
var _turn_t := 0.0                       # the view is being turned to it (it has just changed sides)
var _on_bore := false                    # it is on (or coming down off) a bore's roof: it goes round the wall
var _roof_next := -1                     # the roof it will land on next
var _fov_now := 0.0
var _tail_soft := 1e9                    # the tail edge he is held ahead of: follows the real one up the car when a section goes

var _t := 0.0
var _rise := 0.0
var _slash_t := -1.0
var _slash_cd := 2.0
var _plug_t := -1.0                      # seconds since the mouth came down (the Sigil bursts through at 2.6)
var _wait_t := 0.0                       # aboard, the train not yet away
var _att: Att = null                     # the attack running (was [dir, n, window]: see Att)
var _att_q: Array[Att] = []             # what the line asked for while one was running: next, in order (one that waited over 6 s is dropped: the place it was meant for is gone)
var _chain_i := 0                        # chain: which screen of the set is lit now
var _swipe_hit := false                  # swipe: the sweep has crossed the deck
var _cur_pt := -1                        # chain / swipe: the one screen lit
var _kick := 0.0                         # its body thrown round by a hit (sway), eased out
var _kick_arm := 0.0                     # and its arms thrown out
var _stop_t := 0.0                       # hit-stop, real seconds left
var _stop_ms := 0
var _score := 0
var _score_saved := 0
var _combo := 0                          # screens shot without one lighting out unshot or a blow landing
var _lit_n := 0                          # every screen it lit, and every one shot: the grade
var _shot_n := 0
var _sets := 0
var _sets_clear := 0
var _uses := 0                           # set pieces used (tanks, roofs, the door, the climb)
var _graded := false
var _pops: Array[Label3D] = []
var _pop_t := PackedFloat32Array()
var _pop_i := 0
var _portal_warm := 4
var _beast_warm := 4
var _pop_warm := 4                      # frames left drawing the labels once, out of sight, so the first points do not stall on building their pipeline
var _props: Array[Prop] = []
var _prop_mat: StandardMaterial3D
var _door_clean := false
var _door_done := false
var _door_t := 0.0                       # the engine hit the door with its locks on: slowed this long
var _roof_drop := -1.0                     # the roof it was standing on went in: seconds since (it climbs out of the building)
var _roof_shot := {}                     # roof k -> its water tank was shot (the roof goes when it lands there)
var _lines: Array[Line] = []
var _line_t := 0.0                       # the line showing has this long left
var _line_prio := -1
var _ap := 0                             # where an attack is: 0 closing, 1 lighting, 2 the window, 3 it reels, 4 the blow, 5 after
var _ap_t := 0.0
var _armed: Array[int] = []
var _lit := 0
var _win := 0.0
var _flinch := 0.0
var _sec_saved := 3
var _targets: Array = []                 # per point: Target or null
var _body: Target                        # (the old single drum: only if the body has no skeleton to read)
var _sk: Skeleton3D = null
var _hull: Array = []                    # [bone, radius, half height, Target, hip bone (a thigh) or -1]
var _ok_t := 0.0                         # the lit screens were last checked for a clear shot this long ago
var _ok_all := true
var _unlit_t := 0.0                      # how long an attack has waited for a screen it could light that you could hit
var _crt_t: Target
var _ev: Array = []
var _ev_i := 0
var _minions: Array[Taken] = []
var _mp := {}                            # a Taken's instance id -> {m: line | hang | climb | deck | dead, p: its place in the line's space}
var _walls: Array[World.Solid] = []      # the boarding tunnel's walls and end: solid for the run on foot, gone for the ride
var _queue := 0
var _calm_t := 0.0                       # after an attack: this long before the Taken come on again
var _queue_cd := 0.0
var _throws := 0
var _throw_cd := 0.0
var _bumpy := false
var _bump_cd := 0.0
var _jolt_a := 0.0
var _jolt_t := 9.0
var _jolt_ax := Vector3.ZERO
var _fov_kick := 0.0
var _cam_k := 0.0
var _braked := false
var _front_k := 0.0                      # 1 while it stands on the line ahead (the view cranes up over the engine)
var _cam_walk := {}                      # Config's walking values for CAM's keys, as they were before the first ride
var _alarm := false
var _portal_rate := 0.0
var _portal_cd := 0.0
var _portals: Array[MeshInstance3D] = []
var _portal_mats: Array[ShaderMaterial] = []
var _portal_age := PackedFloat32Array()
var _spans_on := false
var _doors_hit := false
var _wall_done := false
var _veil: ColorRect
var _veil_a := 0.0
var _veil_want := 0.0
var _said := {}
var _statics: Array[Node] = []
var _torn: Array[Torn] = []
var _out_t := 0.0
var _bark_i := 0
var _blows := 0
var _swipes := 0                         # red blades swung so far (the first that lands only stings)
var _swipe_air := false                  # he was off the deck at some moment of the swing: it missed him
var _burning := false                    # it came through the depot's fire: it burns for the rest of the ride
var _rake_t := -1.0                      # the twin bores: its arm through the arches, down the car (seconds since it began, < 0 not)
var _feint_t := 5.0                      # between attacks: this long until it snaps at the car again
var _rake_want := false                  # the line asked for the rake while it was busy: as soon as it is free
var _rake_done := false
var _thrown: Array[Thrown] = []          # the sets it throws (a pool of four)
var _volley := 0                         # sets it still has to throw
var _volley_cd := 0.0
var _fire_t := -1.0                      # the depot going up behind the train: seconds since it began (< 0 not)
var _fire_front := 0.0                   # where the fire has got to on the line
var _fire_cd := 0.0
var _fire_out := false                   # it has come out of the fire
var _gap_dropped := false                # the viaduct: the span ahead has gone
var _hop_on := false                     # the train is in the air over the gap
var _hop := 0.0                          # and how high, metres
var _pounce_cd := -1.0                   # landed: this long until it jumps the gap after you
var _pounce_gap := 0.0
var _tip_t := -1.0                       # it landed on the tail: the car tips under it (seconds since)
var _wide_k := 0.0                       # the view pulled back and up (the jump: the train and what is after it in one shot)
var _wall_to_chase := false              # off the engine and along the wall: back onto the line once it is behind the car
var _unc_t := -1.0                       # the end: the Ticket Man is cutting the car loose (seconds since he said so)
var _gan_i := 0                          # the next signal frame it has not reached (levels/underfoint/uf_route.gd gantries)
var _gan_cd := 0.0
var _dead := PackedByteArray([0, 0, 0, 0, 0, 0])      # screens shot out: they stay dark and broken until it has no others to light
var _hud_hidden := false
var _foot_up := PackedByteArray()        # per foot: 1 while it is off the ground (its coming down is a footfall)
var _cleared := 0
var _mouth_done := false
var _air_c: Color = AIR_HOME[0]
var _air_d: float = AIR_HOME[1]
var _air_cd := 0.0
var _gen := 0                            # bumped at every (re)start: what a timer scheduled before it does not happen after


func _init(p_lv: UnderfointLevel) -> void:
	lv = p_lv
	name = "UfChase"


# ---- building it (at level load) -------------------------------------------------------------------------------------------------------------------------------------------

## Called by the level with nothing pending in the builder
func build(b: UfBuild, _arch: UfArch, _d: UfDistrict) -> void:
	for c in lv.get_children():      # everything the level has made so far: put away once the train is under way (the line moves through where it stands)
		if c != self:
			_statics.append(c)
	b.base_y = -1000.0
	route = UfRoute.new()
	add_child(route)
	route.build(b)
	train = UfTrain.new(lv, route)
	add_child(train)
	train.build(b)
	turret = UfTurret.new(lv)
	add_child(turret)
	turret.build()
	# what you run on in the tunnel to the train (the line itself is only drawn): its floor, its walls, and an end a little past the engine. Under the train they stay for the ride: what falls off
	# the car lands on that floor and goes back to running down the line.
	var w := lv.world
	var z0 := HOME.z + route.mark("portal")
	w.add({"kind": "box", "cx": HOME.x, "cz": (z0 + HOME.z + 45.0) * 0.5, "hx": 9.6, "hz": (HOME.z + 45.0 - z0) * 0.5, "bottom": Y - 1.5, "top": Y, "tag": "trackbed"})
	# (the walls and the end are for the run only: left standing through the ride they were 12 m of nothing-to-see round the train that stopped every shot at the Sigil in the other bore, beside
	# the bridge or on the line ahead. User 2026-11-13: "you cant see or shoot the screens". _tunnel_walls() takes them away once the train goes.)
	for side: float in [-1.0, 1.0]:
		_walls.append(w.add({"kind": "box", "cx": HOME.x + side * 10.0, "cz": (z0 + HOME.z + 45.0) * 0.5, "hx": 0.5, "hz": (HOME.z + 45.0 - z0) * 0.5, "bottom": Y, "top": Y + 12.0, "tag": "tunnel"}))
	_walls.append(w.add({"kind": "box", "cx": HOME.x, "cz": HOME.z + 44.0, "hx": 9.5, "hz": 0.5, "bottom": Y, "top": Y + 12.0, "tag": "tunnel", "no_cam": true}))
	audio = UfChaseAudio.new()
	add_child(audio)
	# every sound the ride makes, read now (at load), not off the disk the first time it plays
	audio.warm(["beast-roar1", "beast-roar2", "beast-snarl1", "beast-snarl2", "beast-snarl3", "beast-shriek1", "beast-shriek2", "beast-stomp1", "beast-stomp2", "train-horn", "train-bump",
		"train-start", "train-brake", "crash-rubble", "crash-metal", "omni:boom-big", "omni:boom", "omni:detonate", "omni:sphere-break", "omni:em-blow", "omni:sparks", "omni:groan", "omni:lift-snap",
		"omni:ff-tug-hit", "omni:arc", "omni:implode"])
	# (and its voice: a line was read off the disk the first time it was said, a 35-50 ms stall each, 2026-11-15)
	var voice: Array = []
	for k: String in LINES:
		voice.append("sigil-" + k)
	for k: String in BARK_TEXT:
		voice.append("sigil-" + k)
	audio.warm(voice)
	# (and Prog's own: his first hurt of the session read his voice off the disk, 51 ms, at the first blow that landed, or in the grab. The blood's first spray is drawn once below, in tick.)
	for k: String in ["progHurt1", "progHurt2", "progHurt3"]:
		Game.sfx.voice_clip(k)
	_build_portals()
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_veil = ColorRect.new()
	_veil.color = Color(0, 0, 0, 0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_veil)
	_build_props()
	_build_pops()
	_build_thrown()
	_ev = _beats()
	_set_sections(3)


## What the player can shoot on the line besides the Sigil: every fuel tank (a lamp on its valve), the water tank on every roof it bounds across, the blast door's two locks. Their lamps share one
## amber material, blinked by the director while any of them counts.
func _build_props() -> void:
	_prop_mat = StandardMaterial3D.new()
	_prop_mat.albedo_color = Color.BLACK
	_prop_mat.emission_enabled = true
	_prop_mat.emission = CRT_AMBER
	_prop_mat.emission_energy_multiplier = 4.0
	var bx := BoxMesh.new()
	bx.size = Vector3(0.8, 0.55, 0.8)
	var add := func(kind: String, sig: float, u: float, h: float, k: int, r: float, hh: float) -> void:
		var pp := Prop.new()
		pp.kind = kind
		pp.sig = sig
		pp.u = u
		pp.h = h
		pp.k = k
		pp.tgt = Target.new(91100 + _props.size(), 0.0, 0.0, 0.0, {"r": r, "h": hh, "max": 10.0, "hp": 10.0})
		pp.lamp = MeshInstance3D.new()
		pp.lamp.mesh = bx
		pp.lamp.material_override = _prop_mat
		pp.lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pp.lamp.visible = false
		pp.lamp.transform = route.frame_at(sig) * Transform3D(Basis.IDENTITY, Vector3(u, h, 0.0))
		route.add_child(pp.lamp)
		pp.light = OmniLight3D.new()
		pp.light.light_color = CRT_AMBER
		pp.light.omni_range = 7.0
		pp.light.omni_attenuation = 1.4
		pp.light.light_specular = 0.2
		pp.light.visible = false
		pp.light.position = route.pt(sig, u - signf(u) * 0.8, h + 0.6)
		route.add_child(pp.light)
		_props.append(pp)
	for i in route.tanks.size():      # the valve on the tank's top, toward the line
		var t := route.tanks[i]
		add.call("tank", t.sig, t.u + 1.2, t.h + 1.5, i, 1.9, 3.4)
	for i in route.towers.size():
		var t := route.towers[i]
		add.call("roof", t.sig, t.u - 1.5, t.h, int(roundf((t.sig - route.mark("roofs") - 30.0) / 45.0)), 1.9, 3.2)      # (its lamp on the tank's side toward the line, not inside it)
	for i in route.doors.size():      # the locks: a bolt housing on the frame's lintel over each leaf (up there they clear the engine's roof from the car: at the leaves' seam the engine hid them)
		var t := route.doors[i]
		add.call("door", t.sig - 1.3, signf(t.u) * 3.6, 10.4, i, 0.9, 1.6)


## The sets it throws: an old television's case with its glass burning amber, four of them, reused
func _build_thrown() -> void:
	var case_m := StandardMaterial3D.new()
	case_m.albedo_color = Color(0.09, 0.085, 0.1)
	case_m.roughness = 0.55
	case_m.metallic = 0.4
	var glass_m := StandardMaterial3D.new()
	glass_m.albedo_color = CRT_AMBER
	glass_m.emission_enabled = true
	glass_m.emission = CRT_AMBER
	glass_m.emission_energy_multiplier = 4.0
	var case_mesh := BoxMesh.new()
	case_mesh.size = Vector3(1.25, 1.0, 1.1)
	case_mesh.material = case_m
	var glass_mesh := BoxMesh.new()
	glass_mesh.size = Vector3(1.0, 0.76, 1.16)      # (proud of the case front and back: it tumbles, and the amber has to show from any side)
	glass_mesh.material = glass_m
	for k in 4:
		var th := Thrown.new()
		th.nd = Node3D.new()
		var a := MeshInstance3D.new()
		a.mesh = case_mesh
		th.nd.add_child(a)
		var g := MeshInstance3D.new()
		g.mesh = glass_mesh
		th.nd.add_child(g)
		var l := OmniLight3D.new()
		l.light_color = CRT_AMBER
		l.omni_range = 6.0
		l.light_energy = 1.6
		th.nd.add_child(l)
		th.nd.visible = false
		add_child(th.nd)
		th.tgt = Target.new(91030 + k, 0.0, 0.0, 0.0, {"r": 1.0, "h": 1.5, "max": POINT_HP, "hp": POINT_HP})
		_thrown.append(th)


func _throw_set() -> void:
	var p := Game.player
	for th in _thrown:
		if th.live:
			continue
		th.live = true
		th.t = 0.0
		th.from = beast.global_position + Vector3(randf_range(-2.0, 2.0), 8.5, 0.0)
		th.to = Vector3(clampf(p.x, HOME.x - 1.2, HOME.x + 1.2), Y + DECK + 0.5, clampf(p.z, _tail() + 0.8, HOME.z + 9.0))
		th.dur = clampf(th.from.distance_to(th.to) / 16.0, 1.3, 2.1)
		th.spin = Vector3(randf_range(-5.0, 5.0), randf_range(-3.0, 3.0), randf_range(-5.0, 5.0))
		th.tgt.hp = th.tgt.max
		th.tgt.dead = false
		_put(th.tgt, th.from.x, th.from.y - 0.75, th.from.z)
		if not Game.combat.targets.has(th.tgt):
			Game.combat.targets.append(th.tgt)
		th.nd.global_position = th.from
		th.nd.visible = true
		audio.play_at("beast-snarl%d" % (1 + randi() % 3), th.from, 3.0, 1.1)
		beast.flash = maxf(beast.flash, 0.3)
		_turn_t = maxf(_turn_t, 1.0)
		_shout("tvtip", "IT'S THROWING ITS SCREENS! SHOOT THEM DOWN!", true, true)
		return


func _thrown_off() -> void:
	for th in _thrown:
		th.live = false
		th.nd.visible = false
		Game.combat.targets.erase(th.tgt)
	_volley = 0


## The sets in the air: each on its arc from its hand to where he stood, turning over; shot, it bursts; landed, it bursts on the deck and hurts him if he is still there
func _tick_thrown(dt: float, p: Player) -> void:
	if _volley > 0 and _att == null and _rake_t < 0.0 and beast != null and beast.visible and not p.dead and b_mode in [&"chase", &"side", &"roofs", &"wall", &"depot", &"ceiling"]:
		_volley_cd -= dt
		if _volley_cd <= 0.0:
			_volley -= 1
			_volley_cd = 0.85
			_throw_set()
	for th in _thrown:
		if not th.live:
			continue
		th.t += dt
		var u := th.t / th.dur
		var pos := th.from.lerp(th.to, u) + Vector3(0.0, 5.5 * 4.0 * u * (1.0 - u), 0.0)
		th.nd.global_position = pos
		th.nd.rotation += th.spin * dt
		_put(th.tgt, pos.x, pos.y - 0.75, pos.z)
		var shot := th.tgt.dead or th.tgt.hp <= 0.0
		if not shot and u < 1.0:
			continue
		th.live = false
		th.nd.visible = false
		Game.combat.targets.erase(th.tgt)
		Game.fx.sparks(pos, 30, 9.0)
		var at := route.transform.affine_inverse() * pos
		route.fire(at, Vector3.ZERO, 2.0, 0.5, 0.14, Color(1.7, 1.4, 0.9))
		route.debris(at, 5, 6.0, 0.3, 0.8)
		audio.play_at("omni:em-blow", pos, 0.0, randf_range(1.1, 1.4))
		if shot:
			_combo += 1
			_add_score(PTS["tv"], pos + Vector3(0.0, 0.8, 0.0), "+%d" % PTS["tv"])
			_hitstop(0.03)
		else:
			audio.play_at("crash-metal", pos, 2.0, 1.3)
			_jolt(0.02)
			if not p.dead and Vector2(p.x - pos.x, p.z - pos.z).length() < 2.1 and p.y < Y + DECK + 2.0:
				_combo = 0
				Game.combat.hurt_player(p, 14.0, pos.x, pos.z, "melee")


## The points that rise off what you hit: a few phosphor-green labels, reused
func _build_pops() -> void:
	for i in 8:
		var l := Label3D.new()
		l.font = CrtTheme.font(&"monob")
		l.font_size = 46
		l.outline_size = 10
		l.outline_modulate = Color(0.01, 0.04, 0.01, 0.85)
		l.modulate = CRT_GREEN
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0011
		l.render_priority = 20
		l.visible = false
		add_child(l)
		_pops.append(l)
		_pop_t.append(-1.0)


func _build_portals() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	for k in 14:
		var m := ShaderMaterial.new()
		m.shader = PORTAL
		m.set_shader_parameter(&"seed", k * 0.37)
		var mi := MeshInstance3D.new()
		mi.name = "portal%d" % k
		mi.mesh = q
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		route.add_child(mi)
		_portals.append(mi)
		_portal_mats.append(m)
		_portal_age.append(-1.0)


## Every beat of the ride, placed on the line: [sigma, what, ...]. Fired as the train passes each.
func _beats() -> Array:
	var r := route
	# (2026-11-15: was eleven attacks, nine of them "rear" at one distance; the broken track and the hairpin had ~10 s with nothing to shoot. Now every stretch mixes the kinds, each one a little harder
	# than the last of its kind, the set pieces are fights, and no gap without a target runs past ~6 s except the two breathers on purpose: out onto the bridge, and into SERN's line.)
	# (2026-11-15: the one-screen attacks (swipe, chain, the wall chain) had 1.2 to 2.0 s from a screen lighting to the blow, too short to find it, turn and shoot; a set gets ~5 s and felt right.
	# User: "not that damn short". They now get 3.0 down to 2.3 s a screen, still tightening along the ride.)
	var e: Array = [
		[r.mark("s1") + 6.0, "shout", "HOLD ON!"],
		[r.mark("s1") + 40.0, "wave", 2],
		[r.mark("sweep") + 10.0, "tip", "WHEN ITS SCREENS LIGHT UP, SHOOT THEM OUT!"],
		[r.mark("sweep") + 22.0, "attack", {"kind": "rear", "n": 3, "win": 5.2, "stag": 0.35}],
		[r.mark("sweep") + 115.0, "attack", {"kind": "chain", "n": 3, "win": 3.0}],      # (a swipe until 2026-11-15: the first minute is amber only, the red blade comes in the depot)
		[r.mark("sweep") + 175.0, "wave", 3],
		[r.mark("sweep") + 225.0, "attack", {"kind": "far", "n": 3, "win": 4.8, "stag": 0.3}],
		[r.mark("twin") + 5.0, "beast", "side"],
		[r.mark("twin") + 10.0, "shout", "IT'S IN THE OTHER BORE! RIGHT SIDE!"],
		[r.mark("twin") + 20.0, "attack", {"kind": "chain", "n": 4, "win": 2.8}],      # (early: it has to be over before the other bore ends)
		[r.mark("twin") + 150.0, "rake"],      # its arm through the arches: the tail section goes
		[r.mark("twin") + 205.0, "beast", "chase"],
		[r.mark("broken"), "bumps", 1],
		[r.mark("broken") + 6.0, "shout", "TRACK'S GONE BAD! HOLD ON!"],
		[r.mark("broken") + 8.0, "drops", "roof"],
		[r.mark("broken") + 15.0, "attack", {"kind": "rear", "n": 3, "win": 4.4, "stag": 0.3}],      # (shot from a car that will not keep still)
		[r.mark("broken") + 120.0, "volley", 2],
		[r.mark("broken") + 150.0, "bumps", 0],
		[r.mark("hairpin") - 30.0, "beast", "ceiling"],
		[r.mark("hairpin") - 24.0, "shout", "IT'S ON THE ROOF! LOOK UP!"],
		[r.mark("hairpin") - 2.0, "attack", {"kind": "ceiling", "n": 3, "win": 4.6, "stag": 0.3}],
		[r.mark("depot") + 55.0, "tip", "FUEL TANKS! SHOOT ONE WHEN IT'S NEXT TO IT!"],      # (after the red blade: one thing at a time)
		[r.mark("depot") + 14.0, "beast", "depot"],
		[r.mark("hairpin") + 70.0, "attack", {"kind": "swipe", "win": 2.4, "arm": -1.0}],      # the first red blade: alone, and held a long time (2026-11-15: it was in the depot, under the fire)
		[r.mark("depot") + 60.0, "attack", {"kind": "rear", "n": 4, "win": 4.8, "stag": 0.3}],
		[r.mark("depot") + 170.0, "beast", "chase"],
		[r.mark("climb") + 8.0, "firestorm"],      # the depot goes up behind the train: it comes out of the fire burning, and burns from here on
		[r.mark("climb") + 40.0, "wave", 2],
		[r.mark("mouth"), "horn"],
		# the viaduct (a breather out onto the bridge: the city opens up, then it comes out of the cavern wall behind)
		[r.mark("s2") + 3.0, "shout", "OUT ON THE BRIDGE! HOLD ON!"],
		[r.mark("s2") + 55.0, "attack", {"kind": "swipe", "win": 2.0, "arm": 1.0}],      # (a far set until 2026-11-15: the second red blade, out in the open where it is seen whole)
		[r.mark("s2") + 110.0, "wave", 2],
		[r.mark("roofs") + 5.0, "beast", "roofs"],
		[r.mark("roofs") + 12.0, "tip", "IT'S ON THE ROOFS! SHOOT THE WATER TANK BEFORE IT LANDS!"],
		[r.mark("roofs") + 25.0, "volley", 3],
		[r.mark("side2") - 25.0, "beast", "gone"],               # off the last roof and down into the city...
		[r.mark("side2") + 14.0, "beast", "parapet"],             # ...and up the right side of the bridge out of it
		[r.mark("side2") + 16.0, "shout", "RIGHT SIDE! IT'S CLIMBING THE BRIDGE!"],
		[r.mark("side2") + 20.0, "attack", {"kind": "climb", "n": 3, "win": 3.4, "stag": 0.3}],
		[r.mark("side2") + 150.0, "beast", "gone"],             # (only if it is somehow still up there)
		[r.mark("side2") + 120.0, "climbers", 2],
		[r.mark("ahead") - 55.0, "ahead"],      # (was -80: later, so the climb on the right side is over first)
		[r.mark("ahead") + 60.0, "shout", "BRIDGE IS COMING DOWN! GO, GO!"],
		[r.mark("ahead") + 110.0, "climbers", 2],      # (over the parapet while the spans go behind: something to shoot in the fall)
		# (the train jumps the fallen span at the end of "ahead", _tick_hop, and it jumps after you onto the tail: no beat, it follows from the landing. It used to climb a pier behind the train here.)
		[r.mark("blast") - 140.0, "tip", "SERN DOOR AHEAD! SHOOT THE TWO LOCKS OR WE HIT IT HARD!"],
		[r.mark("blast") - 135.0, "locks"],
		[r.mark("blast") - 30.0, "horn"],
		# SERN's line (a breather through the door: the alarm, its voice, then it comes)
		[r.mark("s3") + 4.0, "alarm", 1],
		[r.mark("s3") + 14.0, "say", "obey"],
		[r.mark("s3") + 40.0, "portals", 0.3],
		[r.mark("s3") + 35.0, "attack", {"kind": "rear", "n": 5, "win": 4.4, "stag": 0.22}],
		[r.mark("s3") + 70.0, "drops", "ceiling"],
		[r.mark("bend_l") + 30.0, "attack", {"kind": "far", "n": 5, "win": 4.3, "stag": 0.2}],
		[r.mark("bend_l") + 120.0, "volley", 3],
		[r.mark("bend_r") + 50.0, "attack", {"kind": "swipe", "win": 1.6, "arm": -1.0}],
		[r.mark("bend_r") + 60.0, "portals", 0.9],
		[r.mark("bend_r") + 70.0, "say", "portal"],
		[r.mark("helix") + 30.0, "beast", "wall"],
		[r.mark("helix") + 40.0, "shout", "IT'S ON THE WALL!"],
		[r.mark("helix") + 60.0, "attack", {"kind": "wall", "n": 4, "win": 4.2, "stag": 0.25}],
		[r.mark("helix") + 120.0, "drops", "ceiling"],
		[r.mark("helix") + 150.0, "engine"],      # along the wall, past the car and onto the engine: SERN's gun comes alive (it stays there until it is blasted off, or the spiral ends)
		[r.mark("helix") + 400.0, "beast", "chase"],
		[r.mark("helix") + 412.0, "wave", 3],
		[r.mark("helix") + 414.0, "say", "all"],
		[r.mark("straight") + 30.0, "attack", {"kind": "far", "n": 6, "win": 4.0, "stag": 0.18}],
		[r.mark("straight") + 150.0, "portals", 2.0],
		[r.mark("finale"), "finale"],
	]
	e.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return e


# ---- the level's last stage calls these ------------------------------------------------------------------------------------------------------------------------------------

func _exit_tree() -> void:
	_end_stop()
	Game.time_scale = 1.0
	_hide_hud(false)
	if Game.music == audio:
		Game.music = null


## The talk is over (or you died running and are back outside the mouth): the heap goes, it comes up, they get up
func start_run(retry: bool) -> void:
	mode = &"run"
	turret.mount(false)
	aboard = false
	done = 0
	stretch = 0
	_veil_want = 0.0
	_show_statics(true)
	_air_home()
	_walk_cam()
	route.reset()
	route.plug.visible = false
	s = 0.0
	v = 0.0
	route.place(0.0)
	train.update(0.0, 0.0)
	_clear_minions()
	sections = 3
	_set_sections(3)
	lv.throne.burst(retry)
	for r: Robot in Game.enemies.robots.duplicate():
		if r is Tethered:      # (torn off the throne with the rest of it)
			Game.despawn_enemy(r)
	_ensure_beast()
	_clear_points()
	_att = null
	_att_q.clear()
	_mode_next = &""
	_turn_t = 0.0
	_reset_fight(true)
	_rise = 1.0 if retry else 0.0
	_slash_t = -1.0
	_slash_cd = 3.0
	_wait_t = 0.0
	_plug_t = -1.0
	_mouth_done = false
	_wall_done = false
	_doors_hit = false
	b_mode = &"chase"
	beast.visible = true
	beast.position = Vector3(70.0, Y, 237.0)
	beast.rotation = Vector3(0.0, PI, 0.0)
	beast.strike = 0.0
	beast.angry = true
	beast.rage = 1.0
	beast.state = &"run"
	for q: Array in [[58.0, 206.0], [82.0, 207.0], [64.0, 198.0], [77.0, 196.0], [70.0, 190.0], [61.0, 188.0]]:
		_spawn_free(Vector3(q[0], Y, q[1]))
	Game.fx.shake = maxf(Game.fx.shake, 1.2)
	Game.music = audio
	audio.music_loop(false)
	audio.music(0.0, 0.0)
	audio.sfx("beast-roar1", 2.0)
	audio.sfx("crash-rubble", -2.0, 0.8)
	_loops_on()
	_said.erase("run1")
	_said.erase("run2")
	_shout("run", "THE NORTH TUNNEL! LAST TRAIN OUT! RUN!", true)
	_gen += 1
	if not _said.has("credit"):      # (CC BY: the music is credited where it plays)
		_said["credit"] = true
		Game.hud.toast("MUSIC: \"APOCALYPSE\" BY HYPERREAL (CC BY 3.0)", 3.0)


## Every enemy the level has that is not the chase's (the stragglers in the streets, what is left of the throne's guard): gone once the train is under way, or they would stand in the moving line
func _clear_others() -> void:
	for r: Robot in Game.enemies.robots.duplicate():
		if not (r is Taken and _minions.has(r as Taken)):
			Game.despawn_enemy(r)


## A Taken of the chase's own (not the stage's: a stage change would clear those, and these must outlive it)
func _spawn_raw(at: Vector3, yaw: float, speed_k: float, hp: float) -> Taken:
	var spec := {"kind": "taken", "speed_k": speed_k, "no_respawn": true}
	if hp > 0.0:
		spec["hp"] = hp
	var r: Robot = Game.spawn_enemy({"x": at.x, "y": at.y, "z": at.z, "yaw": yaw}, spec)
	if not (r is Taken):
		if r != null:
			Game.despawn_enemy(r)
		return null
	var tk := r as Taken
	tk.blockout = true
	tk.wake(false)
	tk.wake_in = 0.0
	_minions.append(tk)
	return tk


## A stretch of the ride begins: going on from the one before (you are already on it), or again after dying in it, or from a checkpoint
func start_stretch(k: int, retry: bool) -> void:
	var cont := mode == &"ride" and not retry and stretch == k
	if mode == &"ride" and not retry and k == stretch + 1:
		cont = true
	stretch = k
	done = k
	if cont:      # rolling straight on (the run ended aboard, or the stretch before has just been cleared)
		# (2026-11-15: a blow is health only now, and nothing on the car heals: a stretch cleared gives some of it back, or two blows early would decide the whole ride)
		var pl := Game.player
		if pl != null and not pl.dead:
			pl.hp = minf(pl.max_hp, pl.hp + 40.0)
		_sec_saved = sections
		_score_saved = _score
		return
	# from a standstill: a retry, or a checkpoint
	var fresh := mode != &"ride"
	mode = &"ride"
	aboard = true
	_gen += 1
	_show_statics(false)
	route.reset()
	_clear_minions()
	_clear_others()
	_clear_points()
	_att = null
	_att_q.clear()
	_mode_next = &""
	_turn_t = 0.0
	_reset_fight(fresh and not retry)
	if retry:
		_score = _score_saved
	_score_saved = _score
	_cam_k = 0.0
	_front_k = 0.0
	_ensure_beast()
	# (2026-11-15: the car is taken apart by the ride, not by the blows it lands: the tail section goes in the twin bores, the middle one on the viaduct, the last at the end. So a stretch
	# always begins with the car as the ride had left it. A blow is health only now.)
	sections = [3, 2, 1][k]
	_sec_saved = sections
	_set_sections(sections)
	_bumpy = false
	_alarm = false
	_portal_rate = 0.0
	_spans_on = false
	_doors_hit = false
	_wall_done = k >= 2
	_mouth_done = k >= 2
	_burn = 0.0
	_veil_want = 0.0
	_veil_a = 0.0
	beast.visible = true
	beast.angry = true
	beast.rage = 0.4 + 0.3 * k
	beast.damage = maxi(beast.damage, k)      # (from a checkpoint: the fire in the depot and the bridge have already had their armour; it never grows back)
	beast.strike = 0.0
	beast.crt_armed = false
	b_roll = 0.0
	b_u = 0.0
	b_h = 0.0
	match k:
		0:      # the train standing at the fallen mouth: it bursts through
			s = 0.0
			v = 0.0
			route.plug.visible = true
			b_mode = &"buried"
			beast.visible = false
			_plug_t = 0.0
			b_sig = route.mark("portal") - 4.0
		1:
			s = route.mark("s2") - 30.0
			v = 21.0
			b_mode = &"chase"
			gap = 40.0
			b_sig = _tail_sig() - gap
		2:
			s = route.mark("s3") - 4.0
			v = 26.0
			b_mode = &"chase"
			gap = 30.0
			b_sig = _tail_sig() - gap
			for t in route.doors:
				t.alive = false
				t.node.visible = false
			_doors_hit = true
	_b_t = 0.0
	route.place(s)
	train.update(0.0, v)
	_ev_i = 0
	while _ev_i < _ev.size() and float(_ev[_ev_i][0]) < s + 0.5:
		_ev_i += 1
	if k == 2:
		_alarm = true
		_portal_rate = 0.3
	_ride_cam(0.0)
	lv.bo.teleport({"x": HOME.x, "y": Y + DECK + 0.1, "z": _tail() + 2.6, "yaw": PI})
	_arm_player()
	Game.rig.yaw = PI
	turret.yaw = PI
	turret.heat = 0.0
	turret.locked = false
	_ride_state(k)
	lv.bo._refill(Game.combat)
	Game.music = audio
	audio.music_loop(true)
	audio.music([UfChaseAudio.DROP, UfChaseAudio.DROP + 24.0 * UfChaseAudio.BAR, UfChaseAudio.DROP + 48.0 * UfChaseAudio.BAR][k], 0.05)
	_loops_on()


## What a ride begins with, from a checkpoint or straight on from the run: free shooting (2026-11-15, user: "I like it better"; SERN's gun is one moment of the ride now, it comes alive in the
## spiral: "engine" in _beats), none of the ride's moments under way, the cash and the objective panel put away for the ride (it is watched like a film: the Ticket Man says what to do)
func _ride_state(k: int) -> void:
	turret.mount(false)
	turret.live = false
	_burning = k >= 1        # (the depot is behind it)
	beast.burning = _burning
	_rake_t = -1.0
	_feint_t = 5.0
	_fire_t = -1.0
	_gap_dropped = false
	_hop_on = false
	_hop = 0.0
	_pounce_cd = -1.0
	_tip_t = -1.0
	_wide_k = 0.0
	_wall_to_chase = false
	_unc_t = -1.0
	_gan_i = 0
	train.tender.visible = true
	if _stop_ms == 0:
		Game.time_scale = 1.0
	_hide_hud(true)


func _hide_hud(on: bool) -> void:
	if on == _hud_hidden:
		return
	_hud_hidden = on
	Game.hud.cash_box.modulate.a = 0.0 if on else 1.0
	if lv.bo._hud != null:
		lv.bo._hud._panel.modulate.a = 0.0 if on else 1.0


## After the player's own frame (UnderfointLevel.after_player): at the gun, he is held at its grips
func after_player(_dt: float) -> void:
	if turret != null:
		turret.hold_player()


func stretch_clear(k: int) -> bool:
	return done > k


## A (re)start: the set pieces stand again, nothing is queued to be said, no points in the air. all: the score and the grade's counts from nothing too (a new run, or a checkpoint)
func _reset_fight(all: bool) -> void:
	for pp in _props:
		pp.live = false
		pp.gone = false
		pp.lamp.visible = false
		pp.light.visible = false
		Game.combat.targets.erase(pp.tgt)
	_roof_shot.clear()
	_roof_drop = -1.0
	_thrown_off()
	_rake_want = false
	_rake_done = false
	_dead.fill(0)
	_door_clean = false
	_door_done = false
	_lines.clear()
	_line_t = 0.0
	_line_prio = -1
	_kick = 0.0
	_kick_arm = 0.0
	_cur_pt = -1
	_end_stop()
	for i in _pops.size():
		_pop_t[i] = -1.0
		_pops[i].visible = false
	if all:
		_score = 0
		_score_saved = 0
		_combo = 0
		_lit_n = 0
		_shot_n = 0
		_sets = 0
		_sets_clear = 0
		_uses = 0
		_blows = 0
		_graded = false
		_swipes = 0


## The panel's line under the objective while the train runs (levels/_kit/blockout_hud.gd "detail"): the score, and the chain while one is going
func detail() -> String:
	var t := "SCORE %s" % _fmt(_score)
	if _combo >= 3:
		t += "  ·  CHAIN x%d" % _mult()
	return t


## What the panel says to do, by what is happening (it used to say "Shoot out its screens" all the way, the fight over or not)
func task() -> String:
	if mode == &"out":
		return "Through SERN's gate."
	if _att != null and _ap >= 1 and _ap <= 2:
		match _att.kind:
			"swipe":
				return "Red blade: jump it."
			"chain":
				return "Shoot each screen as it lights."
			"crt":
				return "Shoot the screen in its head."
			"engine":
				return "It is on the engine. Blast it off."
		return "Shoot out its screens before it strikes."
	for pp in _props:
		if pp.live and not pp.gone:
			match pp.kind:
				"tank":
					return "Shoot a fuel tank when it is beside one."
				"roof":
					return "Shoot the water tank on the roof it is jumping to."
				"door":
					return "Shoot the blast door's two locks."
	if _on_car() > 0:
		return "Keep the car clear."
	return "Hold on. Keep it off the car."


static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func _mult() -> int:
	return 1 + mini(4, _combo / 4)


# ---- every frame -----------------------------------------------------------------------------------------------------------------------------------------------------------

func tick(dt: float) -> void:
	_t += dt
	if _stop_ms != 0 and Time.get_ticks_msec() >= _stop_ms:
		_end_stop()
	_tick_lines(dt)
	if _pop_warm > 0:
		if _pop_warm == 3:      # one drop of blood in front of the camera: its pool's first draw stalled the frame ~50 ms at the first blow
			var cam := get_viewport().get_camera_3d()
			if cam != null:
				Game.fx._blood_spray(cam.global_position - cam.global_transform.basis.z * 2.5, 0.0, 0.0, 1, 0.1)
			turret.warm(cam)
		_warm_pops()
	if _portal_warm > 0:      # (the first of SERN's holes stalled the frame 50 ms building its pipeline: one is drawn, tiny, in front of the camera for the first frames)
		_portal_warm -= 1
		var cam := get_viewport().get_camera_3d()
		if cam != null and _portal_age[0] < 0.0:
			_portals[0].visible = _portal_warm > 0
			_portals[0].global_transform = cam.global_transform * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.01), Vector3(0.0, 0.0, -2.0))
			_portal_mats[0].set_shader_parameter(&"open", 0.02)
	_veil_a = move_toward(_veil_a, _veil_want, dt / 0.35)
	_veil.color.a = _veil_a
	route.update(dt)
	if mode == &"off":
		return
	var p := Game.player
	if mode == &"run":
		_tick_run(dt, p)
	else:
		_tick_ride(dt, p)
	turret.tick(dt, mode == &"ride" or mode == &"out")
	if beast != null:
		beast.speaking = 1.0 if audio.speaking() else 0.0
		route.tv_mat.emission_energy_multiplier = (1.0 + 1.6 * beast.speaking) * (0.82 + 0.18 * sin(_t * 23.0)) if mode != &"run" else 0.0
		beast.update(dt)
	_tick_loops(dt)


func _ensure_beast() -> void:
	if beast != null:
		return
	beast = SigilBeastView.new()
	lv.add_child(beast)
	_targets.resize(SigilBeastView.POINT_AT.size())
	_body = Target.new(91000, 0.0, 0.0, 0.0, {"r": 2.2, "h": 9.0, "max": BODY_HP, "hp": BODY_HP, "boss": true})
	_build_hull()
	_crt_t = Target.new(91001, 0.0, 0.0, 0.0, {"r": 1.5, "h": 2.4, "max": 60.0, "hp": 60.0})
	route.tv_mat.emission_texture = beast._view.get_texture()      # its face on every old monitor along the line ("Every screen you pass. I will be in it.")


## The level's own things (city, station, chamber, their lights): shown while you are in them, put away once the train is under way
func _show_statics(on: bool) -> void:
	for sd in _walls:
		sd.set_off(not on)
	for sd in train.blockers:
		sd.set_off(not on)
	for c in _statics:
		if is_instance_valid(c) and (c is Node3D):
			(c as Node3D).visible = on


## (Both used to go straight to the HUD, so a shout and the Sigil's line stood as two subtitles at once, three on the bridge. They queue now: _line.)
func _say(key: String, once: bool = true) -> void:
	if once and _said.has(key):
		return
	_said[key] = true
	_line("THE SIGIL", key, LINES.get(key, BARK_TEXT.get(key, "")), 2, true)


## tell: it says what to do (it waits its turn, but is not dropped for waiting)
func _shout(key: String, text: String, once: bool = true, tell: bool = false) -> void:
	if once and _said.has(key):
		return
	_said[key] = true
	_line("TICKET MAN", key, text, 1 if tell else 0, false)


func _line(who: String, key: String, text: String, prio: int, voiced: bool) -> void:
	var l := Line.new()
	l.who = who
	l.key = key
	l.text = text
	l.prio = prio
	l.voiced = voiced
	l.at = _t
	# (a barked line of its own replaces one still waiting: it never says two of them back to back)
	for q in _lines:
		if q.who == who and q.prio == prio and prio < 2:
			_lines.erase(q)
			break
	_lines.append(l)


## One line at a time: the one showing runs out, then the most important waiting one. A Sigil line cuts a shout short; a colour shout that waited over 2.5 s is old news and goes.
func _tick_lines(dt: float) -> void:
	_line_t -= dt
	if _lines.is_empty():
		return
	var best: Line = null
	for q: Line in _lines.duplicate():
		if q.prio == 0 and _t - q.at > 2.5:
			_lines.erase(q)
			continue
		if best == null or q.prio > best.prio:
			best = q
	if best == null:
		return
	if _line_t > 0.0 and not (best.prio == 2 and _line_prio < 2):
		return
	if best.prio == 2 and audio.speaking():      # (its voice never over itself)
		return
	_lines.erase(best)
	var dur := 2.6
	if best.voiced:
		dur = maxf(audio.say("sigil-" + best.key, beast if beast != null and beast.visible else null), 2.2)
	else:
		dur = clampf(1.2 + best.text.length() * 0.045, 1.8, 3.2)
	Game.hud.subtitles_clear()
	Game.hud.subtitle({"id": 0, "num": 0, "name": best.who, "text": best.text, "dur": dur, "speech": false})
	_line_t = dur + 0.25
	_line_prio = best.prio


func _roar(big: bool) -> void:
	if beast == null or not beast.visible:
		return
	audio.play_at("beast-roar%d" % (1 + randi() % 2) if big else "beast-snarl%d" % (1 + randi() % 3), beast.global_position + Vector3(0.0, 7.0, 0.0), 6.0 if big else 3.0, randf_range(0.92, 1.05))
	if big:
		_lunge = 0.0
		Game.fx.shake = maxf(Game.fx.shake, 0.7)
		beast.play(&"roar")


## The ride's own view (see CAM): k 0 between its attacks, 1 while it is over the car
func _ride_cam(k: float) -> void:
	for key: String in CAM:
		if not _cam_walk.has(key):
			_cam_walk[key] = Config.get(key)
		var a: Array = CAM[key]
		Config.set(key, lerpf(a[0], a[1], k))
	if turret != null and turret.mount_k > 0.0:      # at the gun: the view stands higher and looks over it, as an arcade gun cam does (eased in and out with turret.mount_k: it used to cut)
		var g := turret.mount_k * turret.mount_k * (3.0 - 2.0 * turret.mount_k)
		Config.cam_height += 1.6 * g      # (0.85: Prog's back hid the gun and its rounds; Halo 3's gun cam rides high enough to see over the gunner, user 2026-11-15)
		Config.cam_dist += 0.9 * g
		Config.cam_dist_strafe += 0.9 * g
		Config.cam_dist_aim += 0.7 * g
	# it is on the line ahead: the view cranes up and back to see it over the engine
	var f := _front_k * _front_k * (3.0 - 2.0 * _front_k)
	Config.cam_height += 1.35 * f
	Config.cam_dist += 0.9 * f
	Config.cam_dist_strafe += 0.9 * f
	Config.cam_dist_aim += 0.6 * f
	# the jump: pulled back and up, the train in the air and what comes after it in one shot
	var w := _wide_k * _wide_k * (3.0 - 2.0 * _wide_k)
	Config.cam_height += 1.3 * w
	Config.cam_dist += 3.4 * w
	Config.cam_dist_strafe += 3.4 * w
	Config.cam_dist_aim += 2.4 * w
	# (rig.fov_add, not rig.fov: that one is the driving camera's, and vehicles.gd eased it back from nothing every time this set it: the lens snapped to 2 degrees every other second)
	Game.rig.fov_add = lerpf(CAM_FOV[0], CAM_FOV[1], k) + _fov_now


## On foot again (the run, after a ride): the walking view back
func _walk_cam() -> void:
	_hide_hud(false)
	for key: String in _cam_walk:
		Config.set(key, _cam_walk[key])
	Game.rig.fov_add = 0.0
	_cam_k = 0.0
	_front_k = 0.0
	_fov_kick = 0.0
	_fov_now = 0.0


## It has just changed sides (into the other bore, onto the roofs, down on the line ahead, up over the parapet) or begun an attack: the view comes round to it by itself, as a rail shooter's does, so
## you are never hit by something you were not shown. Any look of your own (stick or mouse) takes it straight back, and it never moves while you sight down the gun.
func _tick_turn(dt: float, p: Player) -> void:
	if _turn_t <= 0.0:
		return
	_turn_t -= dt
	var r := Game.rig
	if beast == null or not beast.visible or p.dead or p.ads or p.scoped or r.manual_t < 0.7:
		return
	# what it turns to: what is lit if anything is (its set high in its head over the car was 40 degrees above the view, user 2026-11-15: "he only lights up in one spot you cant hit"), else it
	var bp := beast.global_position + Vector3(0.0, 6.0, 0.0)
	var lit := _lit_centre()
	if lit != Vector3.INF:
		bp = lit
	var dx := bp.x - p.x
	var dz := bp.z - p.z
	var d := U.wrap_angle(atan2(dx, dz) - r.yaw)
	if absf(d) > 0.12:
		r.yaw = U.wrap_angle(r.yaw + clampf(d * minf(1.0, dt * 3.2), -2.8 * dt, 2.8 * dt))
	var cam := get_viewport().get_camera_3d()
	if cam != null:      # and up (or down) to it: the rig's pitch is positive looking down
		var c := cam.global_position
		var want := clampf(atan2(c.y - bp.y, maxf(1.0, U.hyp(bp.x - c.x, bp.z - c.z))) + 0.05, -0.75, 0.5)
		r.pitch = lerpf(r.pitch, want, minf(1.0, dt * 2.0))


## A little pull of the crosshair onto a lit screen it is already near, as an arcade rail shooter's gun has: it never finds a target for you, it only forgives the last few degrees. Less on a
## mouse, which needs none of the pad's help.
func _aim_pull(dt: float, p: Player) -> void:
	if p.dead or turret.on:
		return
	var ar := UfTurret.aim_ray()
	var o: Vector3 = ar[0]
	var f: Vector3 = ar[1]
	var best := 0.1      # radians: only inside this
	var bd := Vector3.ZERO
	var all: Array = _targets.duplicate()
	if _crt_t != null and Game.combat.targets.has(_crt_t):
		all.append(_crt_t)
	for th: Thrown in _thrown:
		if th.live:
			all.append(th.tgt)
	for t: Target in all:
		if t == null:
			continue
		var d := (Vector3(t.x, t.y + t.h * 0.5, t.z) - o).normalized()
		var ang := acos(clampf(d.dot(f), -1.0, 1.0))
		if ang < best:
			best = ang
			bd = d
	if bd == Vector3.ZERO or best < 0.006:
		return
	var k := minf(1.0, dt * (3.2 if Inp.using_pad else 1.3))
	var r := Game.rig
	r.yaw = U.wrap_angle(r.yaw + U.wrap_angle(atan2(bd.x, bd.z) - atan2(f.x, f.z)) * k)
	r.pitch -= (asin(clampf(bd.y, -1.0, 1.0)) - asin(clampf(f.y, -1.0, 1.0))) * k      # (the rig's pitch is positive looking down)


## the middle of what is lit (its screens or its set), INF when nothing is
func _lit_centre() -> Vector3:
	var acc := Vector3.ZERO
	var n := 0
	for t: Target in _targets:
		if t != null:
			acc += Vector3(t.x, t.y + t.h * 0.5, t.z)
			n += 1
	if _crt_t != null and Game.combat.targets.has(_crt_t):
		acc += Vector3(_crt_t.x, _crt_t.y + _crt_t.h * 0.5, _crt_t.z)
		n += 1
	return acc / n if n > 0 else Vector3.INF


## Is there a clear shot from the camera to this point on its body? (Nothing of the world in the way, and the first thing a shot meets is it: its own hull, right at the point, counts.)
func _pt_ok(w: Vector3) -> bool:
	var o: Vector3 = UfTurret.aim_ray()[0]      # (from where a shot starts: the crosshair ray's origin, combat's own)
	var d := o.distance_to(w)
	if d < 0.5:
		return true
	var dir := (w - o) / d
	var r := Game.combat.cast_ray(o.x, o.y, o.z, dir.x, dir.y, dir.z, d + 2.0)
	if r.hit_world and r.target == null and r.d < d - 0.5:
		return false
	if r.target == null:
		return true
	return (o + dir * r.d).distance_to(w) < 1.5


## ...and to a lit target: does a shot at it meet it?
func _shot_ok(t: Target) -> bool:
	var o: Vector3 = UfTurret.aim_ray()[0]
	var to := Vector3(t.x, t.y + t.h * 0.5, t.z)
	var d := o.distance_to(to)
	var dir := (to - o) / maxf(d, 0.01)
	var r := Game.combat.cast_ray(o.x, o.y, o.z, dir.x, dir.y, dir.z, d + 2.0)
	return r.target == t or (r.target != null and (_targets.has(r.target) or r.target == _crt_t))      # (another lit screen in front of it: shooting that one is progress)


## A screen it may light now: one you could hit, from the ones it shows that way, not one already lit or shot out. -1: none (it waits).
func _pick_pt(kind: String, arm: float = 0.0, not_i: int = -1) -> int:
	var all := _visible_points(kind)
	if arm != 0.0:      # the swipe: the screen on the raised arm's side, if one is clear
		var side := all.filter(func(i: int) -> bool: return signf(SigilBeastView.POINT_AT[i].x) == signf(arm))
		if not side.is_empty():
			all = side
	all.shuffle()
	for again in 2:
		for i: int in all:
			if i == not_i or _targets[i] != null or beast.point_state[i] == SigilBeastView.BROKEN:
				continue
			if _pt_ok(beast.point_world(i)):
				return i
		# none whole that you can hit: the ones shot out earlier in the ride come back on ("You break my eyes. I have more."), and it looks again
		var revived := false
		for i: int in all:
			if _dead[i] == 1 and _targets[i] == null and i != not_i:
				_dead[i] = 0
				beast.point_state[i] = SigilBeastView.OFF
				revived = true
		if not revived:
			break
	return -1


## Every lit one still has a clear shot (looked at ten times a second): the window only runs while it does
func _tick_ok(dt: float) -> void:
	_ok_t -= dt
	if _ok_t > 0.0:
		return
	_ok_t = 0.1
	_ok_all = true
	for t: Target in _targets:
		if t != null and not _shot_ok(t):
			_ok_all = false
			return
	if _crt_t != null and Game.combat.targets.has(_crt_t) and not _shot_ok(_crt_t):
		_ok_all = false


func _tail() -> float:
	return HOME.z - 9.0 + SEC * (3 - sections)


## the car's tail on the line: the Sigil's distance behind the train (gap) is measured from it
func _tail_sig() -> float:
	return s + _tail() - HOME.z


# ---- the run ----------------------------------------------------------------------------------------------------------------------------------------------------------------

func _tick_run(dt: float, p: Player) -> void:
	_tick_free_minions()
	if _rise < 1.0:      # coming up through where the cell was
		_rise = minf(1.0, _rise + dt / 2.4)
		var e := _rise * _rise * (3.0 - 2.0 * _rise)
		beast.position.y = Y - 15.0 * (1.0 - e)
		beast.sway = sin(_t * 9.0) * 0.5 * (1.0 - e)
		beast.stride = 1.0 - e
		Game.fx.shake = maxf(Game.fx.shake, 0.7 * (1.0 - e))
		if _rise >= 1.0:
			_roar(true)
			_say("run1")
		return
	beast.position.y = Y
	var on_deck := not p.dead and p.y > Y + DECK - 0.25 and absf(p.x - HOME.x) < 1.8 and p.z > BOARD.y - 0.3 and p.z < HOME.z + 10.6
	var dx := p.x - beast.position.x
	var dz := p.z - beast.position.z
	if on_deck:      # he is on: it goes for the mouth, flat out
		dx = 70.0 - beast.position.x
		dz = WALL_Z + 3.0 - beast.position.z
		_wait_t += dt
		if _wait_t > 0.4:
			_shout("aboard", "HOLD ON!")
	var d := maxf(0.01, U.hyp(dx, dz))
	var yaw := atan2(dx, dz)
	beast.rotation.y += U.wrap_angle(yaw - beast.rotation.y) * minf(1.0, dt * 2.5)
	var speed := 11.0 if on_deck else 5.6
	var walking := (d > 8.5 or on_deck) and _slash_t < 0.0 and not p.dead
	if walking:      # slower than you on foot; it cannot follow into the tunnel (far too big) and rages at its mouth
		beast.position.x += dx / d * speed * dt
		beast.position.z = minf(beast.position.z + dz / d * speed * dt, WALL_Z)
	beast.stride = move_toward(beast.stride, 1.0 if walking else 0.0, dt * 3.0)
	beast.sway = sin(_t * 1.4) * 0.3
	_step(dt, beast.stride)
	var at_wall := beast.position.z > WALL_Z - 1.5 and absf(beast.position.x - 70.0) < 10.0
	if on_deck and (at_wall or _wait_t > 4.0):
		_collapse()
		return
	if at_wall and not on_deck and p.z > WALL_Z + 6.0:      # it has him in the tunnel and cannot get in
		_shout("geton", "GET ON! GET ON THE CAR!")
		_say("run2")
		_scrape_cd -= dt
		if _scrape_cd <= 0.0:
			_scrape_cd = randf_range(0.5, 1.1)
			route.scrape(Vector3(70.0 + randf_range(-9.0, 9.0), Y + randf_range(4.0, 11.0), 271.0), 6)
			Game.fx.shake = maxf(Game.fx.shake, 0.35)
			audio.play_at("crash-rubble", Vector3(70.0, Y + 8.0, 271.0), -6.0, randf_range(1.1, 1.3))
	_slash_cd -= dt
	if _slash_t < 0.0 and d < 10.5 and _slash_cd <= 0.0 and not p.dead and not on_deck:
		_slash_t = 0.0
		audio.play_at("beast-snarl%d" % (1 + randi() % 3), beast.global_position + Vector3(0, 6, 0), 2.0)
	if _slash_t >= 0.0:
		var was := _slash_t
		_slash_t += dt / 0.95
		beast.slash_l = _slash_t
		beast.strike = sin(minf(1.0, _slash_t) * PI) * 0.7
		if was < 0.55 and _slash_t >= 0.55 and d < 11.5 and not on_deck:
			p.invuln = 0.0
			Game.combat.hurt_player(p, 35.0, beast.position.x, beast.position.z, "melee")
			Game.fx.shake = maxf(Game.fx.shake, 1.0)
		if _slash_t >= 1.0:
			_slash_t = -1.0
			_slash_cd = 2.4
			beast.slash_l = 0.0
			beast.strike = 0.0


## He is aboard and it hits the mouth: the tunnel comes down between it and the train, the level goes away behind the dust, and the train goes
func _collapse() -> void:
	mode = &"ride"
	aboard = true
	stretch = 0
	done = 0
	s = 0.0
	v = 0.0
	_sec_saved = sections
	var mouth := route.mark("portal") + 2.0
	route.plug.visible = true
	route.blast(route.pt(mouth, 0.0, 6.0), 6.5, false, 26)
	for k in 30:      # dust filling the mouth, rolling up the tunnel at the train
		route.smoke(route.pt(mouth + randf_range(0.0, 6.0), randf_range(-9.0, 9.0), randf_range(0.0, 11.0)), Vector3(randf_range(-2.0, 2.0), randf_range(-0.5, 1.5), randf_range(4.0, 11.0)),
			randf_range(3.0, 5.5), 1.4, randf_range(2.5, 4.5), Color(0.26, 0.24, 0.21, 0.92))
	Game.fx.shake = maxf(Game.fx.shake, 1.8)
	Game.fx.vertical_shake = 0.6
	Game.fx.vertical_shake_t = 0.1
	audio.sfx("crash-rubble", 4.0, 0.85)
	audio.sfx("omni:sphere-break", 0.0, 0.9)
	audio.sfx("beast-roar2", 2.0, 0.9)
	audio.sfx("train-start", 0.0)
	audio.music(UfChaseAudio.DROP - 0.02, 0.0)
	audio.music_loop(true)
	_show_statics(false)
	turret.yaw = PI
	sections = 3
	_set_sections(3)
	_ride_state(0)
	b_mode = &"buried"
	beast.visible = false
	_plug_t = 0.0
	b_sig = route.mark("portal") - 4.0
	# the Taken: the ones in the chamber are on the far side of it now; the ones in the tunnel run after the train
	var inv := route.transform.affine_inverse()
	for r: Taken in _minions.duplicate():
		if not is_instance_valid(r) or not Game.enemies.robots.has(r):
			continue
		if r.z < 272.0:
			_minions.erase(r)
			Game.despawn_enemy(r)
		else:
			r.held = not r.dead and r.y < Y + 0.8
			_mp[r.get_instance_id()] = {"m": "line" if r.held else "deck", "p": inv * Vector3(r.x, r.y, r.z)}
	_clear_others()
	_gen += 1
	_ev_i = 0


# ---- the ride ---------------------------------------------------------------------------------------------------------------------------------------------------------------

func _tick_ride(dt: float, p: Player) -> void:
	# the train: its speed for this part of the line, held back while the Sigil holds it
	var want: float = SPEED.get(route.name_at(s), 24.0)
	if b_mode == &"grab" and mode == &"ride":
		want = 0.0 if s + 32.0 > route.mark("finale") + 205.0 else 3.0
	if mode == &"out":
		want = 34.0
	if b_mode == &"ahead" and _att != null:
		# (it was 27 m/s straight at it: the whole window was spent with the Sigil a speck 80 to 130 m off behind the engine's smoke. User 2026-11-13: it hit you from where you could not see it.)
		# The Ticket Man brakes as the train comes up to it, so its screens are shot from 40 m and closing, over the engine; blind it and he opens the regulator and goes through it.
		var room := _land_sig - (s + 32.0)
		want = 30.0 if _ap == 3 else clampf((room - 6.0) * 0.6, 5.0, 27.0)
		if want < v - 3.0 and not _braked:
			_braked = true
			audio.sfx("train-brake", 2.0)
			_jolt(0.03)
	if _door_t > 0.0:      # rammed the door with its locks on: the engine is slowed hard, and the Sigil closes
		want = minf(want, 11.0)
	var hard := b_mode == &"ahead" and _att != null      # (braking for it, then flat out through it)
	v = move_toward(v, want, dt * ((9.0 if hard else 4.5) if want > v else (14.0 if hard else 7.0)))
	s += v * dt
	_tick_hop(dt)
	_tick_jolts(dt)
	_tick_air(dt)
	route.place(s)
	train.update(dt, v)
	_tick_torn(dt)
	_tick_pops(dt)
	_tick_portals(dt)
	_tick_alarm()
	# you stay on the car
	var tail := _tail()
	# (when a section is torn off, the edge he may not pass moves up the car at a speed, not at once, and the camera's focus is carried with him: set forward 6 m in one frame he went through
	# his own camera, and the view was inside him for a moment at every blow)
	_tail_soft = move_toward(_tail_soft, tail, 30.0 * dt) if _tail_soft < tail else tail
	if not p.dead:
		if _tip_t >= 0.0 and _tip_t < 1.4 and not turret.on:      # the car tipped under it: he slides down the deck toward it
			p.z -= 3.4 * (1.0 - _tip_t / 1.4) * dt
		p.x = clampf(p.x, HOME.x - 1.45, HOME.x + 1.45)
		var z0 := p.z
		p.z = clampf(p.z, _tail_soft + 0.4, HOME.z + 10.2)
		if p.z > z0 and _tail_soft < tail + 0.5 and z0 < tail + 0.4:
			Game.rig.fz += p.z - z0
			p.y = maxf(p.y, Y + DECK + 0.05)
			p.vy = maxf(p.vy, 0.0)
	# the mouth came down: in a moment it comes through
	if _plug_t >= 0.0:
		_plug_t += dt
		if _plug_t > 2.6:
			_plug_t = -1.0
			_burst_through()
	# the beats on the line
	while _ev_i < _ev.size() and s >= float(_ev[_ev_i][0]):
		_event(_ev[_ev_i])
		_ev_i += 1
	_tick_beast(dt, p)
	_tick_minions(dt, p)
	_tick_spans()
	_tick_doors()
	_cam_k = move_toward(_cam_k, 1.0 if (_att != null and _ap >= 1 and _ap <= 4 and b_mode != &"ahead" and _att.kind != "far") or b_mode == &"grab" else 0.0, dt / 0.9)
	_front_k = move_toward(_front_k, 1.0 if b_mode == &"ahead" else (0.6 if b_mode == &"engine" and not turret.on else 0.0), dt / 0.8)
	_wide_k = move_toward(_wide_k, 1.0 if _hop_on or b_mode == &"pounce" else 0.0, dt / 0.6)
	_fov_kick = move_toward(_fov_kick, 0.0, dt * 9.0)
	_fov_now = move_toward(_fov_now, _fov_kick, dt * 70.0)      # (a kick opens the lens over a few frames, not in one: in one it read as a cut)
	_tick_turn(dt, p)
	_aim_pull(dt, p)
	# on the footplate (the car gone) the view, looking back, stands inside the power car a metre and a half behind him, and the screen was black: the power car is not drawn while the lens is in it
	var lens := get_viewport().get_camera_3d()
	train.tender.visible = not (sections == 0 and lens != null and lens.global_position.z > HOME.z + 10.7 and absf(lens.global_position.x - HOME.x) < 2.2)
	_ride_cam(_cam_k * _cam_k * (3.0 - 2.0 * _cam_k))
	# the car's ammunition locker is SERN's and does not run out (user 2026-11-15: free shooting "just felt so difficult" for the ammunition): the spare rounds are kept up, the magazine is still his to change
	var cb := Game.combat
	if cb.cur >= 0:
		var wd := Weapons.WEAPONS[cb.cur]
		if cb.reserve[cb.cur] < wd.mag_size:
			cb.reserve[cb.cur] = maxf(float(wd.mag_size), float(wd.max - wd.mag_size))
	# a stretch is done when its end goes under the train
	if mode == &"ride":
		if stretch == 0 and s >= route.mark("s2"):
			done = maxi(done, 1)
		elif stretch == 1 and s >= route.mark("s3"):
			done = maxi(done, 2)
	if p.dead:
		return
	if mode == &"out":
		_tick_out(dt)
		return
	if _att != null:
		_tick_attack(dt, p)
	else:
		while not _att_q.is_empty() and _t - _att_q[0].at > 6.0:
			_att_q.pop_front()
		if not _att_q.is_empty() and _can_attack():
			_att = _att_q.pop_front()
			_ap = 0
			_ap_t = 0.0
	_tick_props(dt)
	_tick_waves(dt)
	_tick_thrown(dt, p)
	_tick_rake(dt, p)
	_tick_firestorm(dt)
	_tick_uncouple(dt)
	if _pounce_cd >= 0.0:
		_pounce_cd -= dt
		if _pounce_cd < 0.0:
			_pounce()


func _event(e: Array) -> void:
	match String(e[1]):
		"say":
			_say(String(e[2]))
		"shout":
			_shout(String(e[2]), String(e[2]))
		"tip":      # a shout that says what to do: it waits its turn but is never dropped
			_shout(String(e[2]), String(e[2]), true, true)
		"locks":
			for pp in _props:
				if pp.kind == "door" and not pp.gone:
					_prop_on(pp)
		"roar":
			_roar(true)
		"wave":
			_queue += int(e[2])
			_queue_cd = 0.0
			_say("take")
			_roar(false)
		"throw":
			_throws += int(e[2])
			_throw_cd = 0.6
		"volley":
			_volley += int(e[2])
			_volley_cd = 0.4
		"rake":
			_rake_want = true
		"firestorm":
			_firestorm()
		"engine":
			_to_engine()
		"drops":
			_drops(String(e[2]))
		"climbers":
			for k in int(e[2]):
				var side := 1.0 if k % 2 == 0 else -1.0
				_spawn_held(route.pt(s + 60.0 + k * 9.0, side * 5.7, -1.5), "climb")
		"attack":
			var d: Dictionary = e[2]
			var a := Att.new()
			a.kind = String(d.get("kind", "rear"))
			a.n = int(d.get("n", 1))
			a.window = float(d.get("win", 4.5))
			a.stagger = float(d.get("stag", 0.3))
			a.arm = float(d.get("arm", 1.0))
			if bool(d.get("chain", false)):      # (a wall attack lit one at a time)
				a.stagger = -1.0
			if _att == null and _can_attack():
				_att = a
				_ap = 0
				_ap_t = 0.0
			else:
				a.at = _t
				_att_q.append(a)
		"beast":
			_beast_mode(StringName(String(e[2])))
		"gap":
			gap_want = float(e[2])
		"bumps":
			_bumpy = int(e[2]) == 1
		"horn":
			audio.sfx("train-horn", 0.0)
			var inv := route.transform.affine_inverse()
			for k in 8:
				route.smoke(inv * (train.engine.transform * Vector3(0.0, 3.8, -1.7)), inv.basis * Vector3(randf_range(-1.0, 1.0), 6.0, randf_range(-1.0, 1.0)), 0.5, 2.6, 1.4, Color(0.75, 0.78, 0.8, 0.45))
		"ahead":
			_land_ahead()
		"alarm":
			_alarm = int(e[2]) == 1
		"portals":
			_portal_rate = float(e[2])
		"finale":
			_finale()


func _can_attack() -> bool:
	return _rake_t < 0.0 and beast != null and beast.visible and b_mode in [&"chase", &"side", &"depot", &"roofs", &"wall", &"ahead", &"ceiling", &"parapet", &"engine"] and absf(b_roll - _roll_want()) < 0.25


# ---- the Sigil on the line ---------------------------------------------------------------------------------------------------------------------------------------------------

## The line asks it to move (into the other bore, onto the roofs, back behind the train...). In the middle of an attack it finishes that first: a move made under one left the attack running on a
## Sigil that had gone somewhere else, and the blow landed from under the bridge or from 16 m back (user 2026-11-13).
func _beast_mode(m: StringName) -> void:
	if b_mode == &"engine" and _att != null and m == &"chase":      # the spiral is over and it is still on the engine: the line shakes it off
		_discount()
		_clear_points()
		_end_attack()
	if _att != null:
		_mode_next = m
		return
	_mode_next = &""
	if m == b_mode or (m == &"gone" and (beast == null or not beast.visible)):
		return
	if m == &"chase" and (b_mode == &"engine" or (b_mode == &"wall" and gap < 9.0)):      # it is ahead of the car's tail: back along the wall first, never down the line through the train
		b_mode = &"wall"
		_wall_to_chase = true
		return
	b_mode = m
	_b_t = 0.0
	_roof_k = -1
	_turn_t = 1.6
	match m:
		&"side":
			_roar(false)
		&"roofs":
			_roar(true)
			audio.play_at("beast-stomp1", beast.global_position, 4.0, 0.8)
		&"gone":
			_turn_t = 0.0
			audio.play_at("beast-shriek1", beast.global_position + Vector3(0, 6, 0), 2.0, 0.85)
		&"climb":      # up a pier a little way behind the train, which leaves it there: it tops the parapet and comes after you at a run
			_climb_sig = _tail_sig() - 5.0
			_climb_k = -1
			b_sig = _climb_sig
			b_h = -26.0
			b_u = 6.6
			b_roll = 0.0
			gap = _tail_sig() - b_sig
			beast.visible = true
			_roar(true)
		&"parapet":      # out of the city and up the right side of the bridge, level with the tail, hauling itself up (its climb is an attack: blind it and it loses its grip)
			b_sig = _tail_sig() - 4.0
			b_u = -8.0
			b_h = -30.0
			b_roll = 0.0
			gap = 4.0
			beast.visible = true
			_climb_k = -1
			_roar(true)
		&"wall":
			_roar(false)
		&"ceiling":      # up the right wall and onto the roof of the bore, upside down, its screens hanging over the car
			_roar(true)
			audio.play_at("crash-rubble", beast.global_position + Vector3(0, 6, 0), 2.0, 1.2)
		&"chase":
			if b_roll != 0.0 or b_u < -12.0:
				_roar(false)


## What its whole body is doing, for the body's clips (enemies/sigil_beast_view.gd state): hauling itself up, clinging flat to a wall or a roof (not hanging into the car upside down),
## holding the car, falling; else running
func _body_state() -> StringName:
	match b_mode:
		&"climb", &"parapet":
			return &"climb"
		&"wall", &"ceiling":
			return &"wall"
		&"grab":
			return &"grab"
		&"fallen", &"gone":
			return &"fall"
	if _on_bore:
		return &"wall"
	return &"run"


## The roll it is turning to, by where it is: onto the spiral's wall, onto a bore's roof, or upright
func _roll_want() -> float:
	match b_mode:
		&"wall":
			return -1.15
		&"ceiling":
			return -PI
	return 0.0


## Feet on the bore's section for a roll (0 on the floor, -PI/2 on the right wall, -PI on the roof): the path it runs round the tunnel on, so it never hangs in the air turning over
func _bore_at(roll: float) -> Vector2:
	return Vector2(-8.6 * sin(-roll), 5.6 - 5.6 * cos(roll))


## The mouth fell on it; it comes through the rubble
func _burst_through() -> void:
	route.plug.visible = false
	var at := route.pt(route.mark("portal") + 2.5, 0.0, 5.0)
	route.blast(at, 5.5, false, 30)
	for k in 16:
		route.smoke(at + Vector3(randf_range(-8.0, 8.0), randf_range(-4.0, 5.0), 0.0), Vector3(randf_range(-3.0, 3.0), randf_range(0.0, 2.0), randf_range(2.0, 9.0)), randf_range(3.0, 5.0), 1.3, randf_range(2.0, 3.5), Color(0.27, 0.25, 0.22, 0.85))
	b_mode = &"chase"
	_turn_t = 2.0
	b_sig = route.mark("portal") + 1.0
	gap = _tail_sig() - b_sig
	gap_want = REST_GAP + 6.0
	_b_t = 0.0
	beast.visible = true
	_place_beast(0.0)
	audio.play_at("crash-rubble", beast.global_position + Vector3(0, 5, 0), 6.0, 0.9)
	_roar(true)
	_say("board")
	Game.fx.shake = maxf(Game.fx.shake, 0.9)


## The Sigil comes out of the cavern wall behind the viaduct after the train, the wall bursting round it (fired as it passes the mouth)
func _out_of_the_mouth() -> void:
	var m := route.mark("mouth") + 24.0
	route.blast(route.pt(m, 0.0, 9.0), 7.0, false, 30)
	for k in 12:      # the cavern face coming away round the arch, falling into the city
		var at := route.pt(m + 1.0, randf_range(-16.0, 16.0), randf_range(4.0, 22.0))
		route.smoke(at, Vector3(randf_range(-2.0, 2.0), randf_range(-3.0, 0.0), randf_range(1.0, 4.0)), randf_range(3.0, 6.0), 1.5, randf_range(3.0, 5.0), Color(0.24, 0.22, 0.2, 0.85))
	route.debris(route.pt(m, 0.0, 12.0), 16, 9.0, 1.3, 0.4)
	audio.play_at("crash-rubble", route.world(m, 0.0, 6.0), 8.0, 0.8)
	audio.play_at("omni:sphere-break", route.world(m, 0.0, 6.0), 4.0, 0.9)
	_roar(true)
	_say("down")
	Game.fx.shake = maxf(Game.fx.shake, 0.8)


## The train went through SERN's blast door; the Sigil is far too big for the doorway and comes through the wall round it
func _through_the_wall() -> void:
	var m: float = route.doors[0].sig
	route.blast(route.pt(m, 0.0, 6.0), 7.0, false, 30)
	for k in 14:
		var at := route.pt(m + 1.0, randf_range(-8.0, 8.0), randf_range(1.0, 11.0))
		route.smoke(at, Vector3(randf_range(-2.0, 2.0), randf_range(-1.0, 2.0), randf_range(3.0, 9.0)), randf_range(3.0, 5.5), 1.5, randf_range(2.5, 4.0), Color(0.3, 0.3, 0.31, 0.85))
	route.debris(route.pt(m + 1.0, 0.0, 6.0), 18, 12.0, 1.2, 0.5)
	audio.play_at("crash-rubble", route.world(m, 0.0, 6.0), 8.0, 0.8)
	audio.play_at("omni:boom-big", route.world(m, 0.0, 6.0), 4.0, 0.85)
	_roar(true)
	Game.fx.shake = maxf(Game.fx.shake, 1.0)
	_fov_kick = maxf(_fov_kick, 4.0)


## Gone from beside the bridge... and down on the line ahead, facing the train
func _land_ahead() -> void:
	_land_sig = s + 170.0
	_braked = false
	_discount()
	_clear_points()
	_mode_next = &""
	_turn_t = 2.2
	b_mode = &"ahead"
	b_sig = _land_sig
	b_u = 0.0
	b_h = 34.0
	b_roll = 0.0
	_b_t = 0.0
	beast.visible = true
	_att = _mk("front", 2, 3.0)
	_att_q.clear()
	_ap = 0
	_ap_t = 0.0


func _tick_beast(dt: float, p: Player) -> void:
	if beast == null:
		return
	_b_t += dt
	_burn = maxf(0.0, _burn - dt)
	var kind := route.kind_at(b_sig)
	match b_mode:
		&"buried":
			# (from a checkpoint its body had never been drawn: the frame it burst through the rubble stalled ~50 ms building its pipelines. The first few frames buried, it is drawn once, out of
			# sight under the floor ahead of the camera, so that happens behind the loading.)
			var cam := get_viewport().get_camera_3d()
			if _beast_warm > 0 and cam != null:
				_beast_warm -= 1
				beast.visible = true
				var f := -cam.global_transform.basis.z
				beast.global_position = cam.global_position + Vector3(f.x, 0.0, f.z).normalized() * 45.0 + Vector3(0.0, -14.0, 0.0)
			else:
				beast.visible = false
			_unbody()
			return
		&"chase", &"depot":
			gap = move_toward(gap, gap + (gap_want - gap) * minf(1.0, dt * 2.0), 26.0 * dt)      # (it gains on the train at a run, never faster: from a long way back it is seen coming)
			b_sig = _tail_sig() - gap
			var sway_u := 3.4 * sin(_t * 0.8) + 1.2 * sin(_t * 2.3)
			if b_mode == &"depot":      # it swings into the platform, along the tanks. (They no longer go up by themselves as it passes: 2026-11-15, the player shoots one beside it: _prop_hit.)
				sway_u = -7.0 + 1.5 * sin(_t * 1.7)
			if kind == "sern" or kind == "gate":
				sway_u *= 0.45
			if _on_bore:      # down off a bore's roof: round the right wall to the floor, not straight down through the air
				b_roll = move_toward(b_roll, 0.0, dt * 2.2)
				var q := _bore_at(b_roll)
				b_u = q.x
				b_h = q.y
				if b_roll >= -0.01:
					_on_bore = false
			else:
				b_u += (sway_u - b_u) * minf(1.0, dt * 1.6)
				b_h = move_toward(b_h, 0.0, dt * 12.0)
				b_roll = move_toward(b_roll, 0.0, dt * 1.5)
			# between its attacks it does not just run: every few seconds it snaps at the car, its head thrown down over the tail (2026-11-15: at rest it was a figure following at one distance)
			if _att == null and _att_q.is_empty() and _calm_t <= 0.0 and b_mode == &"chase" and gap < 13.0 and _rake_t < 0.0 and not p.dead:
				_feint_t -= dt
				if _feint_t <= 0.0:
					_feint_t = randf_range(4.5, 7.5)
					_lunge = 0.0
					beast.play(&"lunge")
					audio.play_at("beast-snarl%d" % (1 + randi() % 3), beast.global_position + Vector3(0.0, 7.0, 0.0), 5.0, randf_range(0.85, 1.0))
					Game.fx.shake = maxf(Game.fx.shake, 0.5)
					_jolt(0.02)
			if kind in ["trunk", "broken", "twin", "depot", "mouth"]:
				_scrape(dt)
			if kind == "twin":      # back out of the other bore, through the arches
				_piers()
			if not _mouth_done and b_sig >= route.mark("s2") - 2.0:
				_mouth_done = true
				_out_of_the_mouth()
			if not _wall_done and _doors_hit and not route.doors.is_empty() and b_sig >= route.doors[0].sig - 3.0:
				_wall_done = true
				_through_the_wall()
		&"side":      # in the other bore, level with the car, through the arches
			if s + 16.0 >= route.mark("broken"):      # the bore is ending: whatever it was doing, it is back behind the train
				_discount()
				_clear_points()
				_att = null
				_ap = 0
				_ap_t = 0.0
				beast.strike = 0.0
				if (_rake_want or (_rake_t >= 0.0 and not _rake_done)) and sections == 3:      # the bore ended before its arm came through: it takes the tail on its way out through the last arch
					_rip()
					_say("pieces")
				_rake_t = -1.0
				_rake_want = false
				beast.red_l = 0.0
				_beast_mode(&"chase")
			var want := s - 2.0 + 5.0 * sin(_t * 0.55)
			if _rake_t >= 0.0:      # level with the tail, to reach it
				want = _tail_sig() + 4.0
			b_sig += v * dt + (want - b_sig) * minf(1.0, dt * 1.2)      # (it runs at the train's speed and eases onto its place: the ease alone trailed that place by v / rate, 20 m back in the bore)
			var lean := (-11.5 if _ap == 4 else -13.5) if (_att != null and _ap >= 1 and _ap <= 5) else -19.5
			if _rake_t >= 0.0:
				lean = -11.0
			b_u += (lean - b_u) * minf(1.0, dt * 1.4)
			gap = _tail_sig() - b_sig
			_piers()
			_scrape(dt)
		&"roofs":
			if _att != null:      # its attack: off the roofs and onto the side of the bridge, level with the car, its claws over the parapet and its head over you. The blow comes across the deck.
				b_sig += v * dt + ((s - 1.0 + 2.0 * sin(_t * 0.7)) - b_sig) * minf(1.0, dt * 2.5)
				b_u += ((7.0 if _ap == 4 else 9.2) - b_u) * minf(1.0, dt * 2.4)
				b_h += (0.6 - b_h) * minf(1.0, dt * 3.0)      # (its feet on the parapet: at -3.2 its lower screens were under the deck, behind the bridge)
				if randf() < dt * 7.0:      # the parapet coming away under it
					route.debris(route.pt(b_sig + randf_range(-4.0, 4.0), 5.0, 0.7), 2, 4.0, 0.35)
					route.scrape(route.pt(b_sig + randf_range(-4.0, 4.0), 5.1, randf_range(0.2, 1.0)), 2)
			elif _roof_drop >= 0.0:      # the roof went in under it: down into the building, then out of it and on, well behind
				_roof_drop += dt
				b_u += (UfRoute.ROOF_U - 1.5 - b_u) * minf(1.0, dt * 1.6)
				if _roof_drop < 1.9:      # (it is not running: the train leaves it)
					b_h = UfRoute.ROOF_H - 15.0 * smoothstep(0.0, 0.8, _roof_drop)
					b_roll = 0.35 * sin(minf(1.0, _roof_drop / 0.8) * PI)
					if randf() < dt * 10.0:
						route.blast(route.pt(b_sig + randf_range(-6.0, 6.0), b_u + randf_range(-5.0, 5.0), UfRoute.ROOF_H - randf_range(2.0, 12.0)), 3.0, false, 3)
				else:      # out over the next roof's edge, at a run
					b_sig += v * dt + ((s - 3.0) - b_sig) * minf(1.0, dt * 0.9)
					b_h = move_toward(b_h, UfRoute.ROOF_H + 4.0, dt * 22.0)
					b_roll = 0.0
					if _roof_drop > 3.0:
						_roof_drop = -1.0
						_roof_k = int(floorf((b_sig - route.mark("roofs") - 30.0) / 45.0 + 0.5))
						_roar(true)
			else:      # bounding from roof to roof hard by the bridge, level with the car
				b_sig += v * dt + ((s - 3.0 + 7.0 * sin(_t * 0.45)) - b_sig) * minf(1.0, dt * 1.5)
				b_u += (UfRoute.ROOF_U - 1.5 - b_u) * minf(1.0, dt * 1.6)
				var f := (b_sig - route.mark("roofs") - 30.0) / 45.0
				var k := int(floorf(f + 0.5))
				# (was ROOF_H + 5.5 * sin(PI * frac), frac 0.5 over a roof's middle: it was highest over each roof and down at roof height over the gaps between them. Now it stands on a roof for its middle
				# third and arcs over the gap.)
				var d := absf(f - k) * 2.0
				var x := clampf((d - 0.3) / 0.7, 0.0, 1.0)
				b_h = UfRoute.ROOF_H + 7.0 * sin(PI * 0.5 * x)
				_roof_next = k + 1 if d < 0.3 or f > k else k
				if k != _roof_k and d < 0.3 and k >= 0:
					_roof_k = k
					_roof_land(k)
			gap = _tail_sig() - b_sig
		&"ceiling":      # round the right wall and onto the bore's roof, upside down over the line behind the car
			gap = move_toward(gap, gap + (gap_want - gap) * minf(1.0, dt * 2.0), 26.0 * dt)
			b_sig = _tail_sig() - gap
			b_roll = move_toward(b_roll, -PI, dt * 2.4)
			_on_bore = true
			var q := _bore_at(b_roll)
			b_u = q.x + (0.8 * sin(_t * 0.9) if b_roll < -3.0 else 0.0)
			b_h = q.y
			if randf() < dt * 9.0:      # the roof coming away under its feet
				route.scrape(route.pt(b_sig + randf_range(-3.0, 3.0), b_u + randf_range(-2.0, 2.0), b_h - 0.3), 2)
			if randf() < dt * 2.0:
				route.debris(route.pt(b_sig, b_u, b_h - 0.5), 2, 2.0, 0.4, -1.0)
		&"parapet":      # up the right side of the bridge out of the city, level with the tail (the climb attack hauls it up: see _tick_attack)
			b_sig += v * dt + ((_tail_sig() - 3.0) - b_sig) * minf(1.0, dt * 2.0)
			b_u += (-8.0 - b_u) * minf(1.0, dt * 2.0)
			b_roll = 0.0
			if _att == null:
				b_h = move_toward(b_h, -16.0, dt * 14.0)
			gap = _tail_sig() - b_sig
			if b_h < -1.0 and randf() < dt * 6.0:      # the side of the bridge coming away under its claws
				route.debris(route.pt(b_sig + randf_range(-3.0, 3.0), -5.6, b_h + randf_range(6.0, 10.0)), 2, 4.0, 0.4)
		&"gone":      # it lets go of the bridge and goes down into the city, turning over, left behind
			b_h -= (5.0 + 30.0 * _b_t) * dt
			b_u = move_toward(b_u, 20.0, dt * 7.0)
			b_roll = move_toward(b_roll, 1.2, dt * 0.9)
			b_sig = move_toward(b_sig, s - 60.0, dt * 12.0)
			gap = _tail_sig() - b_sig
			if b_h < -38.0:
				if beast.visible:
					route.blast(route.pt(b_sig, b_u, -35.0), 8.0, false, 16)
					audio.play_at("crash-rubble", route.world(b_sig, b_u, -30.0), 8.0, 0.65)
					_shout("gone", "WHERE'D IT GO?!")
				beast.visible = false
				b_roll = 0.0
				_unbody()
				return
		&"ahead":      # down from the sky onto the line, braced, facing the train
			b_sig = _land_sig
			if b_h > 0.0:
				b_h = maxf(0.0, b_h - dt * 70.0 * minf(1.0, _b_t * 2.5))
				if b_h <= 0.0:
					route.blast(route.pt(_land_sig, 0.0, 0.5), 6.0, false, 26)
					audio.play_at("omni:boom-big", route.world(_land_sig, 0.0, 2.0), 6.0, 0.8)
					audio.play_at("beast-stomp2", route.world(_land_sig, 0.0, 2.0), 8.0, 0.7)
					_roar(true)
					beast.play(&"land")
					_say("ahead")
					_shout("ahead", "IT'S ON THE LINE AHEAD! SHOOT IT OFF THE TRACK!")
					Game.fx.shake = maxf(Game.fx.shake, 1.2)
			gap = _tail_sig() - b_sig
		&"fallen":      # rammed off the bridge: over the parapet and down into the city
			b_u = move_toward(b_u, 24.0, dt * 9.0)
			b_h = move_toward(b_h, -45.0, dt * (6.0 + _b_t * 14.0))
			b_roll = move_toward(b_roll, 1.7, dt * 1.2)
			gap = _tail_sig() - b_sig
			if b_h < -38.0 and beast.visible:
				route.blast(route.pt(b_sig, 24.0, -36.0), 9.0, false, 20)
				audio.play_at("crash-rubble", route.world(b_sig, 24.0, -30.0), 10.0, 0.6)
				beast.visible = false
			if not beast.visible:
				_unbody()
				return
		&"climb":      # back up out of the city: hand over hand up a pier behind the train (four heaves, the stone coming away at each), over the parapet, and after you
			b_sig = _climb_sig
			gap = _tail_sig() - b_sig
			var q := clampf(_b_t / 1.6, 0.0, 1.0) * 4.0
			var st := int(minf(3.0, floorf(q)))
			var e := (st + smoothstep(0.0, 0.6, q - st)) / 4.0
			b_h = lerpf(-26.0, 0.0, minf(1.0, e))
			b_u = lerpf(6.6, 0.0, smoothstep(0.75, 1.0, e))
			b_roll = 0.0
			if st != _climb_k:
				_climb_k = st
				route.debris(route.pt(b_sig, 5.2, b_h + 6.0), 6, 5.0, 0.6)
				route.blast(route.pt(b_sig, 5.0, minf(0.0, b_h + 8.0)), 2.5, false, 4)
				audio.play_at("beast-stomp%d" % (1 + randi() % 2), beast.global_position, 6.0, 0.75)
				Game.fx.shake = maxf(Game.fx.shake, 0.45)
			if _b_t >= 1.6:
				b_mode = &"chase"
				_b_t = 0.0
				gap_want = REST_GAP
				route.debris(route.pt(b_sig, 4.0, 0.5), 10, 6.0, 0.7)
				route.blast(route.pt(b_sig, 4.8, 0.5), 3.5, false, 8)
				_roar(true)
		&"pounce":      # over the fallen span after the train, and down on the car's tail
			var u := clampf(_b_t / 1.25, 0.0, 1.0)
			gap = lerpf(_pounce_gap, 5.0, u)
			b_sig = _tail_sig() - gap
			b_u = 0.0
			b_h = lerpf(-14.0, 0.0, u) + 13.0 * sin(u * PI)
			b_roll = 0.0
			if u >= 1.0:
				_pounce_land()
		&"engine":      # along the spiral's wall past the car, and down onto the engine, facing back at you
			var tgt := s + 22.0
			b_sig = move_toward(b_sig, tgt, (v + 27.0) * dt)
			var there := absf(b_sig - tgt) < 5.0
			b_roll = move_toward(b_roll, 0.0 if there else -1.15, dt * 2.6)
			b_u = move_toward(b_u, 0.0 if there else -5.6, dt * 7.0)
			b_h = move_toward(b_h, 2.2 if there else 3.4, dt * 4.0)
			gap = _tail_sig() - b_sig
			if there and randf() < dt * 8.0:      # its feet on the engine's plating
				var inv := route.transform.affine_inverse()
				route.fire(inv * (train.engine.transform * Vector3(randf_range(-1.5, 1.5), 3.6, randf_range(-6.0, 6.0))), Vector3(randf_range(-4.0, 4.0), randf_range(1.0, 5.0), randf_range(-8.0, -2.0)), 0.09, 0.0, randf_range(0.3, 0.6), Color(1.0, 0.75, 0.35) * 2.2)
		&"wall":      # up on the outside wall of SERN's spiral
			gap += (13.0 - gap) * minf(1.0, dt * 1.5)
			b_sig = _tail_sig() - gap
			b_u = move_toward(b_u, -4.2 if gap > 2.0 else -5.6, dt * 4.0)
			b_h = move_toward(b_h, 3.4, dt * 3.0)
			b_roll = move_toward(b_roll, -1.15, dt * 1.6)
			if _wall_to_chase and gap > 9.0:      # (thrown off the engine: it is behind the car again)
				_wall_to_chase = false
				_beast_mode(&"chase")
			if randf() < dt * 12.0:
				route.scrape(route.pt(b_sig + randf_range(-3.0, 3.0), -6.9, randf_range(1.0, 7.0)), 2)
		&"grab":      # it has the car
			gap = move_toward(gap, 7.5, dt * 6.0)
			b_sig = _tail_sig() - gap
			b_u = move_toward(b_u, 0.0, dt * 4.0)
			b_h = move_toward(b_h, 0.0, dt * 6.0)
			b_roll = move_toward(b_roll, 0.0, dt * 2.0)
	beast.state = _body_state()
	_fit()
	_place_beast(dt)
	# the signal frames over the line: it goes through every one it reaches (they are in order along the line, so one index walks them)
	_gan_cd -= dt
	var gs := route.gantries
	while _gan_i < gs.size() and gs[_gan_i].sig < b_sig + 9.0:
		var g := gs[_gan_i]
		_gan_i += 1
		if g.alive and g.sig > b_sig - 16.0 and beast.visible and absf(b_u) < 8.0 and b_h < 7.0 and b_h > -3.0:
			route.smash_gantry(g)
			if _gan_cd <= 0.0:
				_gan_cd = 0.35
				audio.play_at("crash-metal", route.world(g.sig, 0.0, 5.0), -2.0, randf_range(1.15, 1.45))
				Game.fx.shake = maxf(Game.fx.shake, 0.3)
	_tick_feet(dt)
	# its body takes shots but is not hurt by them (no damage numbers off it: its hull is "crowd"), enough of them and it drops back a little. (2026-11-15: the whole of it now, _tick_hull, where it used to be one 2.2 m drum at its chest that was
	# taken away while its screens were lit. The screens stand proud of the hull where they sit, so a shot at a screen meets the screen.)
	var bp := beast.global_position
	var lit := _att != null and _ap >= 1 and _ap <= 2
	var took := _tick_hull()
	if _sk == null:
		_put(_body, bp.x, bp.y, bp.z)
		if lit:
			_unbody()
		elif not Game.combat.targets.has(_body):
			Game.combat.targets.append(_body)
		if _body.hp < BODY_HP:
			took += BODY_HP - _body.hp
			_body.hp = BODY_HP
			_body.dead = false
	if took > 0.0:
		_flinch += took
		beast.flash = maxf(beast.flash, 0.4)      # (under the view's own flinch threshold: a rifle on its hide is not a screen going)
		if _flinch > 170.0 and _att == null and b_mode == &"chase":
			_flinch = 0.0
			beast.flash = 1.0
			gap += 3.0
	beast.stride = 0.15 if b_mode == &"ahead" else (1.0 if b_mode == &"roofs" else (0.55 if b_mode == &"parapet" else clampf(v / 24.0, 0.3, 1.0)))
	_step(dt, beast.stride if b_mode != &"gone" and b_mode != &"fallen" else 0.0)
	if _att == null or _ap <= 2:      # (eased: a hit's kick, _react, is thrown into it and comes back out over a third of a second)
		beast.sway += (sin(_t * 1.1) * (0.12 if lit else 0.35) - beast.sway) * minf(1.0, dt * (5.0 if lit else 4.0))
	# its roar in your face: the head thrown down over the car
	if _lunge >= 0.0:
		_lunge += dt
		if _att == null:
			beast.strike = sin(minf(1.0, _lunge / 1.3) * PI) * (0.15 if b_mode == &"ceiling" else 0.55)
		_fov_kick = maxf(_fov_kick, 4.0 * sin(minf(1.0, _lunge / 1.3) * PI))
		if _lunge > 1.3:
			_lunge = -1.0
	# burning (the depot): fire off its body
	if (_burn > 0.0 or _burning) and randf() < dt * (30.0 if _burn > 0.0 else 11.0):
		var inv := route.transform.affine_inverse()
		var at := inv * (bp + Vector3(randf_range(-3.0, 3.0), randf_range(2.0, 9.0), randf_range(-3.0, 3.0)))
		route.fire(at, Vector3(0.0, randf_range(3.0, 6.0), 0.0), randf_range(0.8, 1.6), 0.8, randf_range(0.4, 0.7), Color(1.0, 0.45, 0.12) * 1.3)
		if randf() < 0.4:
			route.smoke(at, Vector3(0.0, 3.0, 0.0), 1.4, 2.0, 2.4, Color(0.05, 0.04, 0.04, 0.6))


## Where it is this frame: on the line at b_sig, b_u across, b_h up, rolled onto a wall; facing along the line, or the car while it attacks, or back at the train when it is ahead
func _place_beast(dt: float) -> void:
	var xf := route.world_xf(b_sig, b_u, b_h)
	# its body lies along the chord from its tail to its chest, not the line's tangent at its chest: on a bend the tangent swung its 20 m body out through the outside wall (2026-11-15)
	var tail := route.world(b_sig - 16.0, b_u, b_h)
	var ch := xf.origin - tail
	var yaw := atan2(ch.x, ch.z)
	if b_mode == &"ahead" or b_mode == &"engine":
		yaw += PI
	if (_att != null or _rake_t >= 0.0) and b_mode != &"ahead" and b_mode != &"engine":      # attacking: it squares up to YOU (not to the middle of the car, and not most of the way: its screens were turned off to one side)
		var pl := Game.player
		var want := atan2(pl.x - xf.origin.x, pl.z - xf.origin.z)
		var kind := route.kind_at(b_sig)
		var lim := PI if not ENCLOSED.has(kind) else (0.6 if kind == "gate" else 0.3)      # (in a bore it can only turn so far before its body is in the wall)
		yaw += clampf(U.wrap_angle(want - yaw), -lim, lim)
	var cur := beast.rotation.y
	var ny := yaw if dt <= 0.0 else cur + U.wrap_angle(yaw - cur) * minf(1.0, dt * 5.0)
	beast.transform = Transform3D(Basis(Vector3.UP, ny) * Basis(Vector3(0, 0, 1), b_roll), xf.origin)


func _unbody() -> void:
	Game.combat.targets.erase(_body)
	for h: Array in _hull:
		Game.combat.targets.erase(h[3])


## The hull's cylinders, one per part of its skeleton (and one per thigh). Without a skeleton (an older body) it keeps the single drum.
func _build_hull() -> void:
	var found := beast.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	_sk = found[0] as Skeleton3D
	var k := 0
	for q: Array in HULL:
		var bi := _sk.find_bone(String(q[0]))
		if bi < 0:
			continue
		_hull.append([bi, float(q[1]), float(q[2]), Target.new(91200 + k, 0.0, 0.0, 0.0, {"r": q[1], "h": float(q[2]) * 2.0, "max": BODY_HP, "hp": BODY_HP, "boss": true, "crowd": true}), -1])
		k += 1
	for i in _sk.get_bone_count():      # the legs: hip (leg_n_s_0) to knee (leg_n_s_1)
		var nm := _sk.get_bone_name(i)
		if nm.begins_with("leg_") and nm.ends_with("_1"):
			var hip := _sk.find_bone(nm.substr(0, nm.length() - 1) + "0")
			if hip >= 0:
				_hull.append([i, 0.45, 1.0, Target.new(91200 + k, 0.0, 0.0, 0.0, {"r": 0.45, "h": 2.0, "max": BODY_HP, "hp": BODY_HP, "boss": true, "crowd": true}), hip])
				k += 1


## Every cylinder onto its part this frame, in the fight while it is in sight. Returns the damage they took (it is not hurt by it: see the caller).
func _tick_hull() -> float:
	if _sk == null:
		return 0.0
	var on := beast.visible and b_mode != &"buried"
	var took := 0.0
	var gx := _sk.global_transform
	# what is lit owns the hull round it: a part of the hull close to a lit screen (or its set) steps aside while it is lit, or the chest's cylinder took the shots meant for the chest's screens
	var lit: Array[Vector3] = []
	for t: Target in _targets:
		if t != null:
			lit.append(Vector3(t.x, t.y + t.h * 0.5, t.z))
	if _crt_t != null and Game.combat.targets.has(_crt_t):
		lit.append(Vector3(_crt_t.x, _crt_t.y + _crt_t.h * 0.5, _crt_t.z))
	for h: Array in _hull:
		var t: Target = h[3]
		var near := false
		for q: Vector3 in lit:
			if U.hyp(q.x - t.x, q.z - t.z) < t.r + 1.6 and q.y > t.y - 1.2 and q.y < t.y + t.h + 1.2:
				near = true
				break
		if not on or near:
			Game.combat.targets.erase(t)
			if not on:
				continue
		var w := gx * _sk.get_bone_global_pose(int(h[0])).origin
		if int(h[4]) >= 0:      # a thigh: from its hip down to its knee (or up, on a wall)
			var hw := gx * _sk.get_bone_global_pose(int(h[4])).origin
			_put(t, (w.x + hw.x) * 0.5, minf(w.y, hw.y) - 0.3, (w.z + hw.z) * 0.5)
			t.h = absf(w.y - hw.y) + 0.8      # (to 0.5 over the higher joint: the mesh sits ~0.45 m above the knee bones, the top of it when it crouches)
		else:
			_put(t, w.x, w.y - float(h[2]), w.z)
		if t.hp < BODY_HP:
			took += BODY_HP - t.hp
			t.hp = BODY_HP
		t.dead = false
		if not near and not Game.combat.targets.has(t):
			Game.combat.targets.append(t)
	# and whatever of it is between you and a lit screen (its head and scythes hang out in front of its chest, and swing there in the wind-up) steps aside while that screen is lit:
	# a fair shot at every lit screen, the arcade's rule
	if on and not lit.is_empty():
		var o: Vector3 = UfTurret.aim_ray()[0]
		for q: Vector3 in lit:
			var d := o.distance_to(q)
			var dir := (q - o) / maxf(d, 0.01)
			for h: Array in _hull:
				var t: Target = h[3]
				if Game.combat.targets.has(t) and Game.combat.ray_cyl(o.x, o.y, o.z, dir.x, dir.y, dir.z, t) < d - 0.8:
					Game.combat.targets.erase(t)
	return took


## The room it has where it is: [lowest u its middle may take, highest, the roof over it] (huge when open). Its body is 13 m across its feet and its scythes stand 12.4 m up: the user asked that
## it never go through a wall or a roof (2026-11-15), so the director keeps its middle where its sides clear the walls, and tells the body (fit_h, fit_w, if it has them) how much room it has.
func _room(sig: float, u: float) -> Array:
	var bw := BEAST_W
	var big := 1e6
	match route.kind_at(sig):
		"trunk", "broken", "mouth":
			var top := 0.275 + sqrt(maxf(0.0, 11.525 * 11.525 - pow(minf(11.4, absf(u) + 4.5), 2.0)))      # (the vault, over its widest high parts: scythes and knees ~4 m out)
			return [-9.5 + bw + 0.3, 9.5 - bw - 0.3, top - 0.3]
		"twin":
			if u < -9.5:      # the other bore, past the piers
				return [-29.5 + bw + 0.3, -10.9 - bw, 12.2]
			return [-9.1 + bw, 9.5 - bw - 0.3, 12.2]
		"depot":
			return [-23.0 + bw + 0.3, 9.5 - bw - 0.3, 11.8]
		"blast", "sern":
			return [-UfRoute.SERN_W + bw + 0.3, UfRoute.SERN_W - bw - 0.3, UfRoute.SERN_H - 0.9]
		"gate":
			return [-16.0 + bw, 16.0 - bw, 14.6]
		"viaduct":
			return [-2.0, 2.0, big]
	return [-big, big, big]


## Where it runs inside a bore it is kept off the walls, and the body is told the room it has (only on the floor: on a wall or a roof, or off the line, it is placed by its mode)
func _fit() -> void:
	var r := _room(b_sig, b_u)
	if b_mode in [&"chase", &"depot", &"side", &"grab"] and not _on_bore:
		var lo: float = r[0]
		var hi: float = r[1]
		b_u = clampf(b_u, lo, hi) if lo <= hi else (lo + hi) * 0.5
	var free := b_mode in [&"roofs", &"gone", &"fallen", &"climb", &"parapet", &"ahead", &"pounce"] or b_roll != 0.0
	if &"fit_h" in beast:
		beast.set(&"fit_h", INF if free else float(r[2]) - maxf(0.0, b_h))
	if &"fit_w" in beast:
		var room := INF
		var rr := _room(b_sig, b_u)
		if not free and float(rr[0]) > -1e5:
			room = minf(b_u - float(rr[0]) + BEAST_W, float(rr[1]) + BEAST_W - b_u)
		beast.set(&"fit_w", room)


## Every foot that comes down lands on something (user 2026-11-15: its stomps should "have the appearance of actual impact", and its claws should dig into the walls it crawls on: particles
## that give its steps weight, no real digging). Each of its ten blade feet is read off its skeleton; when one comes down onto what it stands on, that spot gets: on masonry, a ring of dust,
## sparks off the blade and now and then a chip of stone; on SERN's steel or the engine's plating, a spray of sparks; on a wall or a roof it is clinging to, grit and sparks torn out of it, a
## lump pulled loose, and dust dragging from every claw that is dug in. All of it is made in the line's space, so it stays where the foot was and the train leaves it behind.
func _tick_feet(dt: float) -> void:
	if beast == null or not beast.visible or gap > 110.0 or b_mode == &"gone" or b_mode == &"fallen" or b_mode == &"buried":
		return
	var n := beast.foot_count()
	if _foot_up.size() != n:
		_foot_up.resize(n)
		_foot_up.fill(0)
	var wall := absf(b_roll) > 0.4 or _on_bore or b_mode in [&"wall", &"ceiling", &"climb", &"parapet"]
	var kind := route.kind_at(b_sig)
	var steel := b_mode == &"engine" or kind == "sern" or kind == "gate" or kind == "blast"
	var inv := route.transform.affine_inverse()
	var xf := beast.global_transform
	var down := -xf.basis.y      # into what it stands on
	for k in n:
		var l := beast.foot_local(k)
		if _foot_up[k] == 1:
			if l.y < 0.4:      # down
				_foot_up[k] = 0
				_footfall(inv * (xf * Vector3(l.x, 0.05, l.z)), inv.basis * down, wall, steel)
		elif l.y > 0.75:
			_foot_up[k] = 1
		elif wall and randf() < dt * 5.0:      # dug in and dragging
			var at := inv * (xf * Vector3(l.x, 0.1, l.z))
			route.smoke(at, Vector3(randf_range(-0.6, 0.6), randf_range(-2.5, -0.5), randf_range(-0.6, 0.6)), randf_range(0.5, 0.9), 1.4, randf_range(0.8, 1.4), Color(0.3, 0.28, 0.25, 0.5))
			route.fire(at, Vector3(randf_range(-3.0, 3.0), randf_range(-5.0, 1.0), randf_range(-3.0, 3.0)), 0.07, 0.0, randf_range(0.2, 0.4), Color(1.0, 0.72, 0.34) * 2.0)


## One foot down at a point of the line's space. into: the way into the surface (down, or into the wall).
func _footfall(at: Vector3, into: Vector3, wall: bool, steel: bool) -> void:
	var out := -into
	if wall:      # claws into brick or panel: torn-out grit falling, sparks, a lump now and then
		for j in 5:
			route.smoke(at + out * 0.3, out * randf_range(0.5, 2.4) + Vector3(randf_range(-1.2, 1.2), randf_range(-3.5, -0.5), randf_range(-1.2, 1.2)), randf_range(1.0, 1.7), 2.0, randf_range(1.3, 2.2), Color(0.5, 0.47, 0.41, 0.7))
		for j in 14:
			route.fire(at, out * randf_range(2.0, 9.0) + Vector3(randf_range(-5.0, 5.0), randf_range(-5.0, 2.0), randf_range(-5.0, 5.0)), 0.11, 0.0, randf_range(0.35, 0.8), Color(1.0, 0.72, 0.34) * 2.6)
		route.fire(at + out * 0.2, Vector3.ZERO, 0.9, 0.6, 0.1, Color(1.5, 1.1, 0.6))
		if randf() < 0.45:
			route.debris(at + out * 0.4, 1, 3.5, 0.3, -0.4)
		return
	if steel:      # a blade on plate: a hard spray of sparks, no dust
		for j in 18:
			var side := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
			route.fire(at, side * randf_range(4.0, 12.0) + out * randf_range(2.0, 8.0), 0.11, 0.0, randf_range(0.35, 0.8), Color(1.0, 0.8, 0.45) * 2.8)
		route.fire(at + out * 0.2, Vector3.ZERO, 1.0, 0.6, 0.1, Color(1.6, 1.3, 0.8))
		return
	# masonry, ballast, the bridge's deck: a low ring of dust thrown outward, sparks off the blade, a chip of stone
	# (first pass: four small dark puffs and four short sparks, which a side view in the tunnel showed as nothing at all. Paler, bigger, longer, and a burst of sparks that is seen from the car.)
	for j in 6:
		var side := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
		route.smoke(at + side * 0.5, side * randf_range(2.0, 5.0) + out * randf_range(0.4, 1.6), randf_range(1.1, 1.9), 2.6, randf_range(1.3, 2.2), Color(0.5, 0.47, 0.41, 0.7))
	route.smoke(at, out * 2.2, 1.6, 2.2, 1.6, Color(0.5, 0.47, 0.41, 0.6))
	for j in 12:
		var side := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
		route.fire(at, side * randf_range(3.0, 9.0) + out * randf_range(2.0, 7.0), 0.11, 0.0, randf_range(0.35, 0.75), Color(1.0, 0.72, 0.34) * 2.6)
	route.fire(at + out * 0.2, Vector3.ZERO, 0.9, 0.6, 0.1, Color(1.5, 1.1, 0.6))      # the strike itself: a hot flash on the stone
	if randf() < 0.3:
		route.debris(at + out * 0.2, 1, 4.5, 0.24, 1.0)


## Its feet: a stomp every stride, louder the closer
func _step(dt: float, stride: float) -> void:
	if stride < 0.2 or beast == null or not beast.visible:
		return
	_step_t -= dt * (1.2 + 1.6 * stride)
	if _step_t <= 0.0:
		_step_t = 1.0
		var d := beast.global_position.distance_to(Vector3(HOME.x, Y, HOME.z))
		audio.play_at("beast-stomp%d" % (1 + randi() % 2), beast.global_position, 2.0 - d * 0.04, randf_range(0.9, 1.1))
		if d < 30.0:      # (0.25: with it over the tail now, each stride is felt in the car)
			Game.fx.shake = maxf(Game.fx.shake, 0.42 * (1.0 - d / 30.0))
			if d < 18.0 and _jolt_t > 0.25:
				_jolt(0.012)


## Scraping the tunnel as it comes: dust and sparks off the wall on the side it leans to, and the lamps there go
func _scrape(dt: float) -> void:
	if absf(b_u) < 2.3 and b_mode != &"side":
		return
	var side := signf(b_u) if b_mode != &"side" else -1.0
	var hit := route.smash_lamps(b_sig + 4.0, 6.0, side)
	if hit > 0:
		audio.play_at("crash-metal", route.world(b_sig, side * 9.0, 5.4), -2.0, randf_range(1.2, 1.4))
	_scrape_cd -= dt
	if _scrape_cd <= 0.0:
		_scrape_cd = randf_range(0.08, 0.2)
		var wall := 9.2 if b_mode != &"side" else 29.2
		route.scrape(route.pt(b_sig + randf_range(-2.0, 4.0), side * wall, randf_range(2.0, 9.0)), 3)


func _piers() -> void:
	for t in route.piers:
		if t.alive and absf(t.sig - b_sig) < 5.0 and b_u > -15.5:
			route.break_thing(t, false, 2.2)
			audio.play_at("crash-rubble", route.world(t.sig, t.u, 4.0), 4.0, randf_range(0.9, 1.1))
			Game.fx.shake = maxf(Game.fx.shake, 0.6)


## SERN's fuel: a tank goes up (shot, or caught from the one before), and the next one along catches from it. Beside the Sigil, it burns: it reels, drops back, and whatever it was doing is over.
## (Until 2026-11-15 the Sigil set them off by walking into them and the player only watched.)
func _tank_up(i: int, gen: int) -> void:
	if gen != _gen or i >= route.tanks.size() or not route.tanks[i].alive:
		return
	var t := route.tanks[i]
	route.break_thing(t, true, 4.2)
	for pp in _props:
		if pp.kind == "tank" and pp.k == i:
			_prop_off(pp)
			pp.gone = true
	if i + 1 < route.tanks.size() and route.tanks[i + 1].sig - t.sig < 40.0:      # the next one catches from it
		get_tree().create_timer(0.5).timeout.connect(_tank_up.bind(i + 1, gen))
	var at := route.world(t.sig, t.u, t.h)
	audio.play_at("omni:detonate" if randf() < 0.5 else "omni:boom-big", at, 8.0, randf_range(0.85, 1.05))
	Game.fx.shake = maxf(Game.fx.shake, 1.1)
	Game.fx.vertical_shake = 0.5
	Game.fx.vertical_shake_t = 0.1
	_fov_kick = maxf(_fov_kick, 5.0)
	for k in 3:      # burning drums thrown along the line
		route.blast(route.pt(t.sig + randf_range(-8.0, 8.0), randf_range(-20.0, -12.0), randf_range(1.5, 4.0)), 1.6, true, 4)
	if beast == null or not beast.visible or absf(t.sig - b_sig) > 16.0 or _burn > 0.0:
		return
	# it was beside it
	_burn = 9.0
	beast.flash = 1.0
	beast.play(&"reel")
	beast.damage += 1      # (the fire takes armour off it: plates torn away)
	gap += 10.0
	_uses += 1
	audio.play_at("beast-shriek%d" % (1 + randi() % 2), beast.global_position + Vector3(0, 6, 0), 8.0, 0.85)
	_add_score(PTS["tank"], beast.global_position + Vector3(0.0, 8.0, 0.0), "BURNED  +%d" % PTS["tank"])
	_hitstop(0.12)
	_shout("burn", "IT'S BURNING! HA!")
	if _att != null and _att.kind != "crt":      # it is in no state to finish what it started
		_clear_points()
		_sets_clear += 1
		_ap = 3
		_ap_t = 0.0


## It lands on roof k. The roof holds, unless you shot its water tank: then it goes in under it (_roof_collapse).
func _roof_land(k: int) -> void:
	audio.play_at("beast-stomp%d" % (1 + randi() % 2), beast.global_position, 6.0, 0.8)
	Game.fx.shake = maxf(Game.fx.shake, 0.4)
	route.blast(route.pt(b_sig, b_u, UfRoute.ROOF_H + 0.3), 2.5, false, 4)
	if _roof_shot.has(k):
		_roof_collapse(k)


## The roof under it goes: the building comes down and the Sigil with it, into the floors; it is a while getting out, and the train leaves it behind. (Every roof it touched used to go down by itself.)
func _roof_collapse(k: int) -> void:
	var near: UfRoute.Thing = null
	var best := 1e9
	for t in route.blds:
		var d := absf(t.sig - (route.mark("roofs") + 30.0 + k * 45.0))
		if d < best:
			best = d
			near = t
	_roof_drop = 0.0
	_uses += 1
	_roar(true)
	beast.play(&"reel")
	audio.play_at("crash-rubble", beast.global_position, 10.0, 0.7)
	audio.play_at("beast-shriek1", beast.global_position + Vector3(0, 6, 0), 6.0, 0.9)
	Game.fx.shake = maxf(Game.fx.shake, 0.9)
	_hitstop(0.1)
	_add_score(PTS["roof"], beast.global_position + Vector3(0.0, 8.0, 0.0), "ROOF DOWN  +%d" % PTS["roof"])
	_shout("roofin", "IT WENT THROUGH THE ROOF!")
	if near == null or best > 20.0 or not near.alive:
		return
	route.blast(route.pt(near.sig, near.u, near.h), 6.0, false, 16)
	near.alive = false
	near.t = 0.0
	for q in 4:
		route.blast(route.pt(near.sig, near.u + randf_range(-6.0, 6.0), randf_range(-32.0, -10.0)), 6.0, false, 6)


func _prop_on(pp: Prop) -> void:
	if pp.live or pp.gone:
		return
	pp.live = true
	pp.lamp.visible = true
	pp.light.visible = true
	pp.tgt.hp = pp.tgt.max
	pp.tgt.dead = false
	if not Game.combat.targets.has(pp.tgt):
		Game.combat.targets.append(pp.tgt)


func _prop_off(pp: Prop) -> void:
	pp.live = false
	pp.lamp.visible = false
	pp.light.visible = false
	Game.combat.targets.erase(pp.tgt)


## The set pieces: each one's lamp is lit (and its target is there) while it counts, the targets ride the moving line, and a shot one does its thing
func _tick_props(dt: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 13.0)
	_prop_mat.emission_energy_multiplier = 1.2 + 5.0 * pulse
	_door_t = maxf(0.0, _door_t - dt)
	for pp in _props:
		if pp.gone:
			continue
		var want := pp.live
		match pp.kind:
			"tank":      # while it runs along the platform, the tanks in its reach
				want = b_mode == &"depot" and beast.visible and absf(pp.sig - b_sig) < 45.0 and pp.sig > s - 70.0
			"roof":      # the roof it stands on and the one it is going for
				want = b_mode == &"roofs" and _att == null and _roof_drop < 0.0 and not _roof_shot.has(pp.k) and (pp.k == _roof_next or pp.k == _roof_k)
		if want and not pp.live:
			_prop_on(pp)
		elif not want and pp.live:
			_prop_off(pp)
		if not pp.live:
			continue
		pp.light.light_energy = (0.4 + 2.2 * pulse) * UnderfointLevel.GAIN
		var w := route.world(pp.sig, pp.u, pp.h)
		_put(pp.tgt, w.x, w.y - pp.tgt.h * 0.5, w.z)
		if pp.tgt.dead or pp.tgt.hp <= 0.0:
			_prop_hit(pp)


func _prop_hit(pp: Prop) -> void:
	_prop_off(pp)
	pp.gone = true
	var at := route.world(pp.sig, pp.u, pp.h)
	match pp.kind:
		"tank":
			_tank_up(pp.k, _gen)
			if _burn <= 0.0:
				_add_score(250, at + Vector3(0.0, 2.0, 0.0), "+250")
		"roof":      # its water tank goes over the side; the roof will not hold it now
			_roof_shot[pp.k] = true
			if pp.k < route.towers.size():
				route.break_thing(route.towers[pp.k], false, 2.0)
			audio.play_at("crash-metal", at, 4.0, 1.1)
			_add_score(300, at + Vector3(0.0, 2.0, 0.0), "+300")
			if pp.k == _roof_k and b_h < UfRoute.ROOF_H + 1.0:      # it is standing on it
				_roof_collapse(pp.k)
		"door":      # a lock blown off its leaf
			route.fire(route.pt(pp.sig, pp.u, pp.h), Vector3.ZERO, 2.0, 0.4, 0.15, Color(1.7, 1.4, 1.0))
			for k in 16:
				route.fire(route.pt(pp.sig, pp.u, pp.h), Vector3(randf_range(-6.0, 6.0), randf_range(-2.0, 7.0), randf_range(-8.0, 2.0)), 0.09, 0.0, randf_range(0.3, 0.6), CRT_AMBER * 2.2)
			audio.play_at("omni:em-blow", at, 6.0, 0.9)
			_add_score(300, at + Vector3(0.0, 1.5, 0.0), "+300")


# ---- attacks ---------------------------------------------------------------------------------------------------------------------------------------------------------------

## An attack made here rather than on the line (it lands ahead, the end of the line, the door rammed with its locks on)
func _mk(kind: String, n: int, win: float, stag: float = 0.3) -> Att:
	var a := Att.new()
	a.kind = kind
	a.n = n
	a.window = win
	a.stagger = stag
	return a


## Which of its screens can be seen and hit from the car, by where it attacks from (measured by ray from where Prog stands, user 2026-11-13): ahead, its two highest (the only ones that clear the
## engine before the train is on it); from the side or hauling itself up the bridge, its four highest; upside down on a bore's roof, all but the one against the roof; from behind, all but the top one,
## which its stoop puts almost straight over your head
func _visible_points(kind: String) -> Array:
	match kind:
		"front":
			return range(2)
		"side", "climb":
			return range(4)
		"ceiling":
			return range(5)
		"engine":
			return range(SigilBeastView.POINT_AT.size())
	return range(1, SigilBeastView.POINT_AT.size())


## One attack (Att). Its phases: 0 it closes and winds up, 1 the screens light, 2 the window, 3 it reels (cleared), 4 the blow, 5 it draws back. The kinds differ in where it stands, how the screens
## light and what the blow is (see the header).
func _tick_attack(dt: float, p: Player) -> void:
	var a := _att
	var crt := a.kind == "crt"
	var front := a.kind == "front"
	var chain := a.kind == "chain" or a.stagger < 0.0
	var swipe := a.kind == "swipe"
	if not crt and not _can_attack():      # it is not there to do it (fallen, gone, buried): no screens, no blow
		_discount()
		_clear_points()
		_end_attack()
		return
	var first := _ap == 0 and _ap_t == 0.0
	if first:
		_turn_t = 1.6
		_clear_deck()
		if swipe:
			_shout("redtip", "RED BLADE! YOU CAN'T STOP THAT ONE! JUMP IT!", true, true)
	# the red of a blade you cannot stop (2026-11-15: the swipe had one screen to shoot OR a jump; the fight has two rules now, amber is shot and red is jumped, and this is the red one)
	var red := 0.0
	if swipe:
		match _ap:
			0:
				red = clampf(_ap_t / 0.6, 0.0, 1.0)
			1, 2, 4:
				red = 1.0
			5:
				red = maxf(0.0, 1.0 - _ap_t / 0.4)
	beast.red_l = red if a.arm > 0.0 else 0.0
	beast.red_r = red if a.arm <= 0.0 else 0.0
	_calm_t = 1.5
	_ap_t += dt
	match _ap:
		0:      # it closes and its arms go up
			var wind := 1.1
			match a.kind:
				"ceiling":      # (its head hangs a long way down off the roof: further back, or it is in the car)
					gap_want = 17.0
				"rear", "chain":
					gap_want = 10.0      # (8.5: its head hung 6 to 9 m forward of its feet, so at 8.5 its upper screens were straight overhead; it comes in to 6 for the blow. 12 until 2026-11-15.)
				"far":      # back to where it charges from
					gap_want = 28.0
					wind = 0.9 if gap > 23.0 else 2.6
				"swipe":
					gap_want = 9.5
					wind = 0.9
				"climb":      # up out of the dark beside the bridge, till its upper screens clear the deck's edge (only those can be shot: _pick_pt)
					b_h = move_toward(b_h, -6.0, dt * 14.0)
					wind = 1.4
				"crt":
					wind = 2.0
				"front":
					wind = 0.6
					if b_h > 0.0:
						_ap_t = 0.0      # (not until it is down)
			if swipe:      # one arm raised high over the car, the other held low
				var hi := minf(0.55, _ap_t * 0.75)
				beast.slash_l = hi if a.arm > 0.0 else 0.12
				beast.slash_r = hi if a.arm < 0.0 else 0.12
			else:
				beast.slash_l = minf(0.38 if crt else 0.36, _ap_t * (0.5 if crt else (0.6 if front else 0.4)))
				beast.slash_r = beast.slash_l
			if first and not crt and not front:      # (was "_ap_t < dt * 1.5": on an uneven frame that was true twice, and it spoke two lines at once)
				_roar(false)
				var key: String = BARKS[_bark_i % BARKS.size()]
				_bark_i += 1
				_say(key, false)
			if a.kind == "far" and gap > 23.0 and _ap_t > 0.9:
				wind = 0.0
			if _ap_t > wind:
				# (2026-11-15: it lights only screens you have a clear shot at. Up the side of the bridge it lit two that were still under the deck, every shot hit the deck, and the blow killed you.)
				_armed.clear()
				if not crt and not swipe:
					var first_pt := _pick_pt(a.kind, a.arm if swipe else 0.0)
					if first_pt < 0:      # nothing it shows can be hit from where you are: it holds its wind-up a little longer, and after 3 s it gives the attack up
						_unlit_t += dt
						_ap_t = wind
						if _unlit_t > 3.0:
							_unlit_t = 0.0
							_end_attack()
						return
					_armed.append(first_pt)
					if not swipe and not chain:      # the rest of a staggered set: picked as each lights (_tick_attack 1)
						for k in a.n - 1:
							_armed.append(-1)
				_unlit_t = 0.0
				_lit = 0
				_chain_i = 0
				_ap = 1
				_ap_t = 0.0
				if not swipe:
					_sets += 1
		1:      # the screens light, one after another
			if crt:
				beast.crt_armed = true
				_crt_t.hp = _crt_t.max
				_crt_t.dead = false
				if not Game.combat.targets.has(_crt_t):
					Game.combat.targets.append(_crt_t)
				_win = a.window
				_ap = 2
				_ap_t = 0.0
			elif swipe:      # nothing to shoot: the blade burns red at the top of its swing
				_win = a.window
				_ap = 2
				_ap_t = 0.0
				_swipe_air = false
				audio.play_at("omni:arc", beast.global_position + Vector3(0.0, 9.0, 0.0), 4.0, 0.55)
			elif chain:      # one at a time
				_cur_pt = _armed[0]
				_arm_point(_cur_pt)
				_lit = 1
				_win = a.window
				_ap = 2
				_ap_t = 0.0
			else:
				while _lit < _armed.size() and _ap_t >= _lit * a.stagger:
					var i := _armed[_lit]
					if i < 0:
						i = _pick_pt(a.kind)
					if i < 0:      # no other it can show you: the set is what is lit
						_armed.resize(_lit)
						break
					_armed[_lit] = i
					_arm_point(i)
					_lit += 1
				_track_points()
				if _lit >= _armed.size():
					_win = a.window
					if front:      # it lasts until the engine is into it
						_win = 99.0
					_ap = 2
					_ap_t = 0.0
		2:      # the window: the blink quickens as it runs out. It only runs while you have a clear shot at every lit screen (_tick_ok).
			a.lit_t += dt
			_tick_ok(dt)
			if _ok_all:
				_win -= dt
			beast.blink_rate = lerpf(10.0, 3.0, clampf(_win / maxf(a.window, 0.1), 0.0, 1.0))
			if front:
				beast.blink_rate = lerpf(10.0, 3.0, clampf((_land_sig - (s + 32.0) - 3.0) / 45.0, 0.0, 1.0))
			if not swipe and not crt:      # (a hit throws its arms out: they come back to where it holds them)
				beast.slash_l = move_toward(beast.slash_l, 0.36, dt * 1.4)
				beast.slash_r = move_toward(beast.slash_r, 0.36, dt * 1.4)
			match a.kind:
				"far":      # it charges while you shoot: the screens come at you, bigger every moment
					gap_want = lerpf(7.0, 28.0, clampf(_win / a.window, 0.0, 1.0))
				"swipe":      # the raised arm trembles at the top of its swing
					var hi := 0.56 + 0.035 * sin(_t * 38.0)
					if a.arm > 0.0:
						beast.slash_l = hi
					else:
						beast.slash_r = hi
				"climb":      # hand over hand up the side of the bridge while you shoot: at the top it is over the parapet
					var q := (1.0 - clampf(_win / a.window, 0.0, 1.0)) * 4.0
					var st := int(minf(3.0, floorf(q)))
					b_h = lerpf(-6.0, 0.6, (st + smoothstep(0.0, 0.5, q - st)) / 4.0)
					if st != _climb_k:
						_climb_k = st
						route.debris(route.pt(b_sig, -5.6, b_h + 7.0), 5, 5.0, 0.5)
						audio.play_at("beast-stomp%d" % (1 + randi() % 2), beast.global_position, 6.0, 0.75)
						Game.fx.shake = maxf(Game.fx.shake, 0.4)
			var cleared := false
			if crt:
				var cw := beast.crt_world()
				_put(_crt_t, cw.x, cw.y - 1.2, cw.z)
				cleared = _crt_t.dead or _crt_t.hp <= 0.0
			elif chain:      # the next lights the moment one goes, and its time starts over
				if _track_points() == 0:
					_chain_i += 1
					var nxt := -1
					if _chain_i < a.n:
						nxt = _pick_pt("rear" if a.kind == "chain" else a.kind, 0.0, _cur_pt)
					if nxt < 0:
						cleared = true
					else:
						_cur_pt = nxt
						_armed.append(nxt)
						_arm_point(_cur_pt)
						_lit += 1
						_win = a.window
			elif not swipe:
				cleared = _track_points() == 0
			if cleared:
				_set_cleared(a)
				if crt:
					_uncouple()
					return
				if a.kind == "engine":
					a.rounds -= 1
					if a.rounds > 0:      # it claws its way back up the engine: once more, quicker
						_ap = 0
						_ap_t = 0.01
						a.lit_t = 0.0
						a.window = 5.5
						_shout("again", "IT'S STILL ON! KEEP FIRING!")
					else:
						_engine_off()
					return
				_ap = 3
				_ap_t = 0.0
			elif _win <= 0.0 or (front and s + 32.0 >= _land_sig - 3.0):
				if not swipe:
					_combo = 0
				_ap = 4
				_ap_t = 0.0
				audio.play_at("beast-roar%d" % (1 + randi() % 2), beast.global_position + Vector3(0, 7, 0), 6.0, 1.1)
		3:      # it reels: thrown back, its head whipped aside
			if front:      # the train hits it, staggered, and throws it off the bridge
				if s + 32.0 >= _land_sig - 3.0:
					_rammed(false)
					return
			elif a.kind == "climb":      # blinded halfway up the bridge's side: it loses its grip and goes down into the city
				b_mode = &"gone"
				_b_t = 0.0
				_end_attack()
				return
			else:
				match a.kind:
					"rear", "chain", "ceiling":
						gap_want = 16.0
					"far":
						gap_want = 22.0
			beast.sway = sin(_ap_t * 14.0) * maxf(0.0, 1.0 - _ap_t)
			beast.slash_l = move_toward(beast.slash_l, 0.0, dt * 2.0)
			beast.slash_r = move_toward(beast.slash_r, 0.0, dt * 2.0)
			if _ap_t > 1.6 and not front:
				gap_want = REST_GAP
				_end_attack()
		4:      # the blow
			if swipe:      # the scythe comes across the deck: jump it, or it cuts you down
				# (0.3 s with the cut at one instant: a jump on seeing it move was too late. It takes half a second now, and being off the deck at any moment of it clears it.)
				var u := clampf(_ap_t / 0.5, 0.0, 1.0)
				if a.arm > 0.0:
					beast.slash_l = lerpf(0.56, 1.0, u)
				else:
					beast.slash_r = lerpf(0.56, 1.0, u)
				beast.strike = u * 0.35
				if not p.grounded and p.y > Y + DECK + 0.15:
					_swipe_air = true
				if not _swipe_hit and u >= 0.75:
					_swipe_hit = true
					_clear_points()
					_sweep(p)
				if _ap_t >= 0.5:
					_ap = 5
					_ap_t = 0.0
			else:
				var u := clampf(_ap_t / 0.32, 0.0, 1.0)
				beast.strike = u * (0.15 if a.kind == "ceiling" else 1.0)
				if a.kind in ["rear", "chain", "far", "crt"]:
					gap_want = 8.0 if crt else 6.0
				if a.kind == "climb":      # over the parapet
					b_h = move_toward(b_h, 0.6, dt * 20.0)
				beast.slash_l = lerpf(0.4, 0.72, u)
				beast.slash_r = lerpf(0.4, 0.72, u)
				if front and s + 32.0 < _land_sig - 3.0:
					_ap_t = minf(_ap_t, 0.3)      # (the blow is the engine meeting it)
				elif _ap_t >= 0.32:
					_clear_points()
					_blow(p)
					if front:
						_rammed(true)
						return
					_ap = 5
					_ap_t = 0.0
		5:      # it draws back
			beast.strike = maxf(0.0, beast.strike - dt / 0.7)
			beast.slash_l = move_toward(beast.slash_l, 0.38 if crt else 0.0, dt * 1.5)
			beast.slash_r = move_toward(beast.slash_r, 0.38 if crt else 0.0, dt * 1.5)
			if not crt and a.kind != "side" and a.kind != "wall":
				gap_want = REST_GAP
			if _ap_t > (1.5 if crt else 1.3):
				if crt:      # it has not let go: again
					_say("quiet")
					_ap = 1
					_ap_t = 0.0
				elif a.kind == "engine":      # it is still on the engine: again
					_ap = 0
					_ap_t = 0.01
					a.lit_t = 0.0
				else:
					_end_attack()


## An attack the line cut short (the bore ended, it landed ahead, it has the car): its screens still lit were never yours to miss, so they come off the grade's count
func _discount() -> void:
	if _att == null or _ap < 1 or _ap > 2:
		return
	for t in _targets:
		if t != null:
			_lit_n -= 1
	_sets -= 1


func _end_attack() -> void:
	var had := _att != null
	_att = null
	_ap = 0
	_ap_t = 0.0
	_cur_pt = -1
	_swipe_hit = false
	beast.strike = 0.0
	beast.red_l = 0.0
	beast.red_r = 0.0
	if had and (b_mode == &"roofs" or b_mode == &"parapet"):      # it was on the side of the bridge for that, and there is nothing to hold on to: down it goes (and what the line asked for meanwhile is moot)
		_mode_next = &""
		_beast_mode(&"gone")
	elif _mode_next != &"":
		_beast_mode(_mode_next)
	elif had and b_mode == &"ceiling":      # down off the roof and after you
		_beast_mode(&"chase")


## Every screen of a set shot out: it reels, and the set scores (more the faster it went)
func _set_cleared(a: Att) -> void:
	_clear_points()
	beast.flash = 1.0
	_cleared += 1
	_sets_clear += 1
	audio.play_at("beast-shriek%d" % (1 + randi() % 2), beast.global_position + Vector3(0, 7, 0), 6.0, randf_range(0.95, 1.08))
	audio.play_at("omni:boom", beast.global_position + Vector3(0, 5, 0), 2.0)
	Game.fx.shake = maxf(Game.fx.shake, 0.7)
	_fov_kick = maxf(_fov_kick, 3.0)
	_hitstop(0.09)
	beast.play(&"reel")
	var chest := beast.global_position + Vector3(0.0, 7.5, 0.0)
	match a.kind:
		"swipe":
			_add_score(PTS["swipe"], chest, "SWING STOPPED  +%d" % PTS["swipe"])
			return
		"climb":
			_uses += 1
			_add_score(PTS["climb"], chest, "IT LOST ITS GRIP  +%d" % PTS["climb"])
			_shout("grip", "IT LET GO! IT'S GOING DOWN!")
			return
		"crt":
			_add_score(PTS["crt"], chest, "+%d" % PTS["crt"])
			return
	if a.kind == "wall" and a.stagger < 0.0:      # the spiral's chain: its armour goes (a big beat, enemies/sigil_beast_view.gd damage)
		beast.damage += 1
	var whole := a.window * (float(a.n) if a.stagger < 0.0 or a.kind == "chain" else 1.0)
	var fast := clampf(1.0 - a.lit_t / maxf(whole, 0.1), 0.0, 1.0)
	var pts: int = PTS["set"] + int(roundf(PTS["fast"] * fast / 50.0)) * 50
	_add_score(pts, chest, "SET  +%d" % pts)
	if _cleared == 1:
		_say("eyes")


## A screen shot out: its body is thrown round from where it was hit, its arms fly out, a burst of glass-light and sparks, a hit-stop, and the points rise off it
func _react(i: int) -> void:
	var w := beast.point_world(i)
	var sd := signf(SigilBeastView.POINT_AT[i].x)
	if sd == 0.0:
		sd = 1.0 if randf() < 0.5 else -1.0
	beast.sway = clampf(beast.sway + 0.8 * sd, -1.0, 1.0)
	beast.flash = 1.0
	if sd > 0.0:
		beast.slash_l = minf(1.0, beast.slash_l + 0.24)
	else:
		beast.slash_r = minf(1.0, beast.slash_r + 0.24)
	if _att != null and _att.kind in ["rear", "chain", "ceiling", "far"]:
		gap += 0.8      # (staggered back a step)
	_shot_n += 1
	_combo += 1
	var m := _mult()
	var pts: int = PTS["screen"] * m
	_add_score(pts, w + Vector3(0.0, 0.6, 0.0), ("+%d  x%d" % [pts, m]) if m > 1 else "+%d" % pts)
	_hitstop(0.035)
	_fov_kick = maxf(_fov_kick, 1.6)
	Game.fx.shake = maxf(Game.fx.shake, 0.3)
	audio.play_at("omni:em-blow" if randf() < 0.5 else "omni:boom", w, -1.0, randf_range(1.2, 1.5))
	audio.play_at("omni:sparks", w, -2.0, randf_range(0.9, 1.15))
	Game.fx.sparks(w, 26, 9.0)
	var at := route.transform.affine_inverse() * w
	route.fire(at, Vector3.ZERO, 2.4, 0.4, 0.13, Color(1.7, 1.45, 1.0))      # the glass going: a white-hot flash
	for k in 14:
		route.fire(at, Vector3(randf_range(-9.0, 9.0), randf_range(-2.0, 9.0), randf_range(-9.0, 9.0)), 0.09, 0.0, randf_range(0.35, 0.7), CRT_AMBER * 2.2)
	route.smoke(at, Vector3(randf_range(-1.0, 1.0), 2.0, randf_range(-1.0, 1.0)), 0.9, 2.2, 1.6, Color(0.06, 0.05, 0.05, 0.7))
	route.flash(at, 1.6 * UnderfointLevel.GAIN, 7.0, 0.16, CRT_AMBER)      # (7 x GAIN over 12 m blew Prog out white when the screen was over the car: the tail lamp's mistake again)


## A very short slow-down on a hit that matters (real seconds): the frame holds for it, as an arcade's does
func _hitstop(sec: float) -> void:
	if Game.time_scale < 0.999 and _stop_ms == 0:      # (someone else has the clock slowed)
		return
	Game.time_scale = 0.12
	_stop_ms = maxi(_stop_ms, Time.get_ticks_msec() + int(sec * 1000.0))


func _end_stop() -> void:
	if _stop_ms != 0:
		_stop_ms = 0
		Game.time_scale = 1.0


func _add_score(n: int, at: Vector3, text: String) -> void:
	_score += n
	var l := _pops[_pop_i]
	_pop_t[_pop_i] = 0.0
	_pop_i = (_pop_i + 1) % _pops.size()
	l.text = text
	l.position = at + Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 0.5), randf_range(-0.6, 0.6))      # (screens shot close together stacked their points into one smudge)
	l.modulate = CRT_AMBER if n >= 1000 else CRT_GREEN
	l.font_size = 58 if n >= 1000 else 44
	l.visible = true


func _tick_pops(dt: float) -> void:
	for i in _pops.size():
		if _pop_t[i] < 0.0:
			continue
		_pop_t[i] += dt
		var l := _pops[i]
		l.position.y += dt * 1.4
		l.modulate.a = 1.0 - smoothstep(0.7, 1.1, _pop_t[i])
		if _pop_t[i] > 1.1:
			_pop_t[i] = -1.0
			l.visible = false


## (At level load: a measured 50 ms stall at the first set cleared was the labels' first draw.) Each is drawn for a few frames, tiny, just in front of the camera, at both its sizes.
func _warm_pops() -> void:
	_pop_warm -= 1
	var cam := get_viewport().get_camera_3d()
	for i in _pops.size():
		var l := _pops[i]
		if _pop_warm <= 0 or cam == null:
			l.visible = _pop_t[i] >= 0.0
			continue
		l.visible = true
		l.text = "SET +0123456789 x"
		l.font_size = 58 if i % 2 == 0 else 44
		l.modulate = Color(CRT_GREEN, 0.02)
		l.position = cam.global_position - cam.global_transform.basis.z * 3.0


## The swipe was not stopped: the scythe crosses the deck. In the air over it (a jump) it misses you; on the deck it cuts you, and anything of the hive standing there. The car is not torn.
func _sweep(p: Player) -> void:
	var side := _att.arm if _att != null else 1.0
	audio.play_at("crash-metal", Vector3(HOME.x, Y + 2.0, p.z), 4.0, 1.25)
	audio.sfx("omni:ff-tug-hit", 2.0, 0.8)
	Game.fx.shake = maxf(Game.fx.shake, 1.0)
	_jolt(0.035, Vector3(0.0, 0.0, side))
	var inv := route.transform.affine_inverse()
	for k in 30:      # sparks off the stanchions it takes
		var z := randf_range(_tail() + 0.3, HOME.z + 9.0)
		route.fire(inv * Vector3(HOME.x + side * 1.62, Y + randf_range(1.3, 2.1), z), inv.basis * Vector3(-side * randf_range(3.0, 10.0), randf_range(0.0, 5.0), randf_range(-3.0, 3.0)), 0.09, 0.0, randf_range(0.3, 0.6), Color(1.0, 0.75, 0.35) * 2.0)
	for r: Taken in _minions:
		if is_instance_valid(r) and not r.dead and not r.held and r.y > Y + 0.9 and absf(r.x - HOME.x) < 2.2:
			Game.combat.damage(r, 999.0, null, 0.0, null, true)
	if p.dead:
		return
	_swipes += 1
	if _swipe_air or (not p.grounded and p.y > Y + DECK + 0.15):      # in the air over it at some moment of the swing: it is at knee height
		_add_score(PTS["jump"], Vector3(p.x, p.y + 2.2, p.z), "JUMPED IT  +%d" % PTS["jump"])
		return
	_combo = 0
	p.invuln = 0.0
	Game.combat.hurt_player(p, SWIPE_FIRST if _swipes == 1 else SWIPE_DMG, beast.position.x, beast.position.z, "melee")
	_fov_kick = maxf(_fov_kick, 4.0)
	_shout("jumptip", "JUMP WHEN THE RED BLADE SWINGS!", true, true)


## The engine meets it on the line: off the bridge it goes (hurt: it braced, and the blow landed first)
func _rammed(_hurt: bool) -> void:
	_mode_next = &""
	_end_attack()
	_clear_points()
	b_mode = &"fallen"
	_b_t = 0.0
	b_sig = s + 33.0
	beast.damage += 1
	route.blast(route.pt(s + 34.0, 0.0, 3.0), 4.5, false, 22)
	audio.sfx("crash-metal", 6.0, 0.8)
	audio.sfx("omni:boom-big", 4.0, 0.9)
	audio.play_at("beast-shriek2", beast.global_position + Vector3(0, 6, 0), 8.0, 0.8)
	Game.fx.shake = maxf(Game.fx.shake, 1.8)
	Game.fx.vertical_shake = 0.7
	Game.fx.vertical_shake_t = 0.1
	_jolt(0.06)
	_spans_on = true


func _arm_point(i: int) -> void:
	beast.point_state[i] = SigilBeastView.ARMED
	var t := Target.new(91010 + i, 0.0, 0.0, 0.0, {"r": 1.2, "h": 2.0, "max": POINT_HP, "hp": POINT_HP})      # (a little proud of the hull it sits on: a shot at it meets it first)
	_targets[i] = t
	Game.combat.targets.append(t)
	_lit_n += 1
	audio.play_at("omni:arc", beast.point_world(i), -4.0, randf_range(1.2, 1.5))


## Keep each lit point's target on its screen; a shot-out one goes dark. Returns how many are still lit (or still to light).
func _track_points() -> int:
	var left := 0
	for i in _targets.size():
		var t: Target = _targets[i]
		if t == null:
			continue
		if t.dead or t.hp <= 0.0:
			Game.combat.targets.erase(t)
			_targets[i] = null
			beast.point_state[i] = SigilBeastView.BROKEN
			_dead[i] = 1
			_react(i)
			continue
		var w := beast.point_world(i)
		_put(t, w.x, w.y - 1.0, w.z)
		left += 1
	if _att != null and (_att.kind == "chain" or _att.kind == "swipe" or _att.stagger < 0.0):
		return left
	return left + (_armed.size() - _lit)


## Where a target is this frame. (Combat puts a plain target back on its `bx, bz` every frame, plus what the last hit knocked it: so those are what is set.)
func _put(t: Target, x: float, y: float, z: float) -> void:
	t.bx = x
	t.bz = z
	t.x = x
	t.z = z
	t.y = y
	t.kx = 0.0
	t.kz = 0.0


func _clear_points() -> void:
	for i in _targets.size():
		if _targets[i] != null:
			Game.combat.targets.erase(_targets[i])
			_targets[i] = null
		if beast != null:      # (a screen shot out stays dark and broken: 2026-11-15, they used to be whole again the moment the set was over)
			beast.point_state[i] = SigilBeastView.BROKEN if _dead[i] == 1 else SigilBeastView.OFF
	if _crt_t != null:
		Game.combat.targets.erase(_crt_t)
	if beast != null:
		beast.crt_armed = false
		beast.blink_rate = 3.0


## The twin bores' big moment (2026-11-15): its arm comes through the arches and down the car, and the tail section goes with it. Nothing to do but get forward: the ride takes the car apart, not
## your mistakes. It runs when the line asks (the "rake" beat) and it is free.
func _tick_rake(dt: float, p: Player) -> void:
	if _rake_t < 0.0:
		if _rake_want and b_mode == &"side" and beast.visible and not p.dead:
			if _att != null:      # (whatever it was doing in the other bore is over: the rake is the bore's moment, and waiting for a set to end it was sometimes never made)
				_discount()
				_clear_points()
				_mode_next = &""
				_end_attack()
			_rake_want = false
			_rake_t = 0.0
			_rake_done = false
			_turn_t = 2.0
			_clear_deck()
			_roar(true)
			_shout("rake", "ITS ARM! IT'S COMING THROUGH THE WALL! GET FORWARD!", true, true)
		return
	_rake_t += dt
	_calm_t = 1.5
	if _rake_t < 1.1:      # the arm goes up
		beast.slash_l = minf(0.56, _rake_t * 0.6)
		beast.red_l = clampf(_rake_t / 0.7, 0.0, 1.0)
	else:
		var u := clampf((_rake_t - 1.1) / 0.5, 0.0, 1.0)
		beast.slash_l = lerpf(0.56, 1.0, u)
		beast.strike = 0.4 * sin(u * PI)
		if not _rake_done and u >= 0.5:
			_rake_done = true
			var inv := route.transform.affine_inverse()
			for k in 36:      # down the right side of the car, tail to front
				var z := randf_range(_tail(), HOME.z + 6.0)
				route.fire(inv * Vector3(HOME.x - 1.6, Y + randf_range(1.2, 2.2), z), inv.basis * Vector3(randf_range(3.0, 11.0), randf_range(0.0, 6.0), randf_range(-4.0, 4.0)), 0.1, 0.0, randf_range(0.3, 0.7), Color(1.0, 0.75, 0.35) * 2.2)
			route.debris(inv * Vector3(HOME.x - 4.0, Y + 3.0, _tail() + 3.0), 12, 8.0, 0.5, 0.8)
			route.blast(inv * Vector3(HOME.x - 6.5, Y + 3.5, _tail() + 3.0), 3.0, false, 8)
			_jolt(0.08, Vector3(0.0, 0.0, -1.0))
			_rip()
			_say("pieces")
	if _rake_t > 2.4:
		_rake_t = -1.0
		beast.slash_l = 0.0
		beast.red_l = 0.0
		beast.strike = 0.0


## It lands: you are hit hard, and the car loses its last section (or, with none left, the train is gone and you with it)
func _blow(p: Player) -> void:
	Game.fx.shake = maxf(Game.fx.shake, 1.6)
	Game.fx.vertical_shake = 0.8
	Game.fx.vertical_shake_t = 0.1
	_fov_kick = maxf(_fov_kick, 6.0)
	audio.sfx("crash-metal", 6.0)
	audio.sfx("omni:boom", 2.0, 0.8)
	_combo = 0
	p.invuln = 0.0
	# (2026-11-15: a blow no longer tears a section off: the ride does that at its own moments, _rip. Its scythes come down on the deck either side of him.)
	Game.combat.hurt_player(p, BLOW, beast.position.x, beast.position.z, "melee")
	_blows += 1
	_jolt(0.07, Vector3(1.0, 0.0, randf_range(-0.3, 0.3)))
	var inv := route.transform.affine_inverse()
	for side: float in [-1.0, 1.0]:
		var at := Vector3(HOME.x + side * 1.2, Y + DECK + 0.1, clampf(p.z - 1.0, _tail() + 0.5, HOME.z + 8.0))
		Game.fx.sparks(at, 22, 8.0)
		route.debris(inv * at, 4, 5.0, 0.25, 0.9)
	_shout("car", "DON'T LET IT SWING! SHOOT THE LIGHTS OUT!")


## The ride takes the car apart at its own moments (the arm through the arches, the landing on the viaduct, the end): the last section goes, and he is carried up the car ahead of the edge
func _rip() -> void:
	if sections <= 0:
		return
	sections -= 1
	_tear(sections)
	if sections == 0:      # the front section, and SERN's gun on it, gone with it: he is on the footplate with what he carries
		turret.mount(false)
		turret.live = false
		turret.visible = false
	_set_sections(sections, false)
	Game.fx.shake = maxf(Game.fx.shake, 1.6)
	_fov_kick = maxf(_fov_kick, 6.0)
	audio.sfx("crash-metal", 6.0)
	_shout("car%d" % sections, "IT'S TAKING THE CAR APART! GET FORWARD!")


## Section k goes: the coupling shrieks and the tail of it drops onto the rails (the car you stand on pitches with it), then it lets go and is down on the line, skidding, tumbling, left behind
func _tear(k: int) -> void:
	var nd := train.sections[k]
	nd.set_meta(&"torn", 0.0)
	var q := Torn.new()
	q.nd = nd
	q.k = k
	_torn.append(q)
	_jolt(0.09, Vector3(1.0, 0.0, randf_range(-0.3, 0.3)))
	Game.fx.vertical_shake = 0.9
	Game.fx.vertical_shake_t = 0.12
	audio.sfx("omni:groan", 4.0, 1.2)
	audio.sfx("omni:sparks", 2.0, 0.9)
	var inv := route.transform.affine_inverse()
	var edge := HOME.z + 3.0 - k * SEC + SEC      # its front edge: where it hangs from the coupling
	route.debris(inv * Vector3(HOME.x, Y + 1.1, edge), 10, 6.0, 0.35, 0.8)      # bolts, planks and the coupling's pin
	for j in 40:
		route.fire(inv * Vector3(HOME.x + randf_range(-1.6, 1.6), Y + 1.0, edge), inv.basis * Vector3(randf_range(-5.0, 5.0), randf_range(1.0, 7.0), randf_range(-12.0, -2.0)), 0.1, 0.0, randf_range(0.4, 0.9), Color(1.0, 0.72, 0.32) * 2.2)


## k sections left: which floors are solid, and (reset) every section back where it belongs
func _set_sections(k: int, reset: bool = true) -> void:
	for i in 3:
		train.deck_solids[i].set_off(i >= k)
		if reset:
			train.sections[i].visible = i < k
			train.sections[i].transform = Transform3D.IDENTITY
			train.sections[i].set_meta(&"torn", -1.0)
	if reset:
		_torn.clear()
		if turret != null:
			turret.visible = k > 0


## The torn sections. (It used to swing away on one formula and vanish after 4 s.) First 0.45 s: hanging from the coupling, its tail on the rails throwing sparks. Then free: on the line in the line's own
## terms (so the bends carry it), skidding to a stop as the train pulls away, bouncing and turning over when it lands, off the side of the viaduct if it goes over, gone once it is far behind.
func _tick_torn(dt: float) -> void:
	var inv := route.transform.affine_inverse()
	for q: Torn in _torn.duplicate():
		q.t += dt
		var nd := q.nd
		var k := q.k
		var mid := Vector3(HOME.x, Y + 1.0, HOME.z + 6.0 - SEC * k)      # its middle, where it was built
		if not q.free:
			var hinge := Vector3(HOME.x, Y + 1.0, HOME.z + 3.0 - SEC * k + SEC)
			var u := minf(1.0, q.t / 0.3)
			var pitch := -0.2 * u * u + 0.025 * sin(q.t * 47.0) * u
			var roll := 0.06 * sin(q.t * 23.0) * u
			nd.transform = Transform3D(Basis.IDENTITY, hinge) * Transform3D(Basis.from_euler(Vector3(pitch, 0.0, roll)), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -hinge)
			if randf() < dt * 60.0:      # its tail grinding on the sleepers
				var tail := inv * Vector3(HOME.x + randf_range(-1.4, 1.4), Y + 0.15, hinge.z - SEC)
				route.fire(tail, inv.basis * Vector3(randf_range(-3.0, 3.0), randf_range(1.0, 5.0), randf_range(-14.0, -4.0)), 0.09, 0.0, randf_range(0.3, 0.6), Color(1.0, 0.72, 0.32) * 2.2)
			if q.t >= 0.45:      # the coupling goes
				q.free = true
				q.sig = s + (mid.z - HOME.z)
				q.u = 0.0
				q.h = 1.0
				q.vs = v * 0.92
				q.vu = randf_range(-1.6, 1.6)
				q.vh = 2.0
				q.rot = Basis.from_euler(Vector3(pitch, 0.0, roll))
				q.spin = Vector3(randf_range(-1.5, -0.5), randf_range(-1.2, 1.2), randf_range(-2.0, 2.0))
				audio.sfx("omni:lift-snap", 6.0, 0.8)
				audio.sfx("crash-metal", 2.0, 0.7)
				_jolt(0.05, Vector3(-1.0, 0.0, 0.0))
				route.debris(inv * hinge, 8, 7.0, 0.3, 0.6)
			continue
		# free on the line
		q.vs = move_toward(q.vs, 0.0, dt * 16.0)
		q.sig += q.vs * dt
		q.u += q.vu * dt
		q.vh -= 15.0 * dt
		q.h += q.vh * dt
		var floor_h := 0.6
		if route.kind_at(q.sig) == "viaduct" and absf(q.u) > 5.0:      # over the side: down into the city
			floor_h = UfRoute.VIA_H + 0.6
		if q.h < floor_h:
			q.h = floor_h
			if q.vh < -3.0:      # it lands hard: bounces, turns, throws dust and sparks
				audio.play_at("crash-metal", route.world(q.sig, q.u, q.h), clampf(-q.vh * 0.6 - 2.0, -6.0, 6.0), randf_range(0.7, 0.95))
				route.blast(route.pt(q.sig, q.u, q.h - 0.4), 1.6, false, 5)
				q.vh = -q.vh * 0.32
				q.spin *= 0.55
				q.vu *= 0.6
			else:
				q.vh = 0.0
				q.spin = q.spin.move_toward(Vector3.ZERO, dt * 4.0)
				q.rot = q.rot.slerp(Basis(Vector3.UP, q.rot.get_euler().y), minf(1.0, dt * 4.0))      # settling flat
			if q.vs > 3.0 and randf() < dt * 40.0:      # skidding on the rails
				route.fire(route.pt(q.sig - 2.5, q.u + randf_range(-1.4, 1.4), 0.15), route.frame_at(q.sig).basis * Vector3(randf_range(-2.0, 2.0), randf_range(1.0, 4.0), randf_range(-6.0, -1.0)), 0.09, 0.0, randf_range(0.3, 0.6), Color(1.0, 0.72, 0.32) * 2.2)
		if not q.kicked and beast != null and beast.visible and absf(q.sig - b_sig) < 4.0 and absf(q.u - b_u) < 6.0 and q.h < 3.0:      # it comes up on the wreck and kicks it out of its way
			q.kicked = true
			var side := -1.0 if q.u > b_u else 1.0
			q.vu = side * -randf_range(8.0, 11.0)
			q.vh = randf_range(6.0, 8.0)
			q.vs = randf_range(4.0, 8.0)
			q.spin = Vector3(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0), randf_range(3.0, 5.0) * side)
			audio.play_at("crash-metal", route.world(q.sig, q.u, q.h), 6.0, 0.75)
			route.blast(route.pt(q.sig, q.u, q.h), 2.2, false, 8)
		q.rot = Basis.from_euler(q.spin * dt) * q.rot
		nd.transform = route.world_xf(q.sig, q.u, q.h, q.rot.orthonormalized()) * Transform3D(Basis.IDENTITY, -mid)
		if q.sig < s - 170.0 or q.h < UfRoute.VIA_H - 5.0:
			nd.visible = false
			_torn.erase(q)


# ---- the Taken -------------------------------------------------------------------------------------------------------------------------------------------------------------

## one of the run's Taken, free on the ground
func _spawn_free(at: Vector3) -> void:
	var tk := _spawn_raw(at, PI, 1.25, -1.0)
	if tk != null:
		_mp[tk.get_instance_id()] = {"m": "free", "p": Vector3.ZERO}


## one placed on the line by the chase: running down it (line), waiting on a girder or the roof's edge (hang), hanging off the parapet (climb)
func _spawn_held(at_route: Vector3, m: String) -> Taken:
	var w := route.transform * at_route
	var tk := _spawn_raw(w, PI, 1.2, MINION_HP)
	if tk == null:
		return null
	tk.held = true
	_mp[tk.get_instance_id()] = {"m": m, "p": at_route}
	return tk


## a Taken thrown across at the car from the Sigil's hand
func _spawn_thrown() -> void:
	var from := beast.global_position + Vector3(0.0, 7.0, 0.0)
	var tk := _spawn_raw(from, PI, 1.2, MINION_HP)
	if tk == null:
		return
	_mp[tk.get_instance_id()] = {"m": "deck", "p": Vector3.ZERO}
	tk.leap(Vector3(HOME.x + randf_range(-1.0, 1.0), Y + DECK, clampf(HOME.z + randf_range(-6.0, 6.0), _tail() + 1.0, HOME.z + 8.0)), 1.05, 0.0)
	audio.play_at("beast-snarl%d" % (1 + randi() % 3), from, 2.0, 1.2)


func _drops(where: String) -> void:
	if where == "roof":      # one hanging in each hole in the roof ahead
		var k := 0
		for hb in route.breaches:
			if hb > s + 20.0 and k < 3:
				_spawn_held(route.pt(hb, randf_range(-1.0, 1.0), 10.6), "hang")
				k += 1
	else:      # off SERN's ceiling ahead
		for k in 2:
			_spawn_held(route.pt(s + 70.0 + k * 14.0, randf_range(-1.5, 1.5), 9.0), "hang")


func _clear_minions() -> void:
	for r: Taken in _minions:
		if is_instance_valid(r) and Game.enemies.robots.has(r):
			Game.despawn_enemy(r)
	_minions.clear()
	_mp.clear()
	_queue = 0
	_throws = 0


func _tick_free_minions() -> void:
	for r: Taken in _minions.duplicate():
		if not is_instance_valid(r) or not Game.enemies.robots.has(r):
			_minions.erase(r)


## The Taken keep off the car from the moment the Sigil winds up until a moment after its attack is over (user 2026-11-13: they walked up behind you or stood in the way "right when you need to
## shoot the screens"). The ones on the deck throw themselves back off it onto the line; none boards, drops or is thrown meanwhile.
func _stand_off() -> bool:
	return _att != null or _calm_t > 0.0


func _clear_deck() -> void:
	var k := 0
	for r: Taken in _minions:
		if not is_instance_valid(r) or r.dead or r.held or r.leap_t >= 0.0 or r.y < Y + 0.9:
			continue
		var side := -1.0 if k % 2 == 0 else 1.0
		k += 1
		r.slot = &""
		r.leap(Vector3(HOME.x + side * randf_range(2.6, 3.6), Y, _tail() - randf_range(4.0, 7.0)), 0.6, 0.0)


func _tick_waves(dt: float) -> void:
	_calm_t = maxf(0.0, _calm_t - dt)
	if _stand_off():
		if _att != null:
			_clear_deck()      # (every frame of it: one that was in the air when the attack began lands after)
		return
	if _queue > 0:      # they come off it one after another, not as a pack
		_queue_cd -= dt
		if _queue_cd <= 0.0 and _alive() < 5 and beast.visible:
			_queue -= 1
			_queue_cd = 1.3
			_spawn_held(route.pt(b_sig - 2.0, b_u + randf_range(-2.5, 2.5), maxf(b_h, 0.0)), "line")
	if _throws > 0:
		_throw_cd -= dt
		if _throw_cd <= 0.0 and _alive() < 5 and beast.visible and _on_car() < ON_CAR:
			_throws -= 1
			_throw_cd = 1.6
			_spawn_thrown()


func _alive() -> int:
	var n := 0
	for r: Taken in _minions:
		if is_instance_valid(r) and not r.dead:
			n += 1
	return n


func _on_car() -> int:
	var n := 0
	for r: Taken in _minions:
		if is_instance_valid(r) and not r.dead and not r.held and (r.leap_t >= 0.0 or r.y > Y + 0.9):
			n += 1
	return n


## The Taken on the line: the runners chase the tail at more than the train's speed and leap for it when there is room; the ones waiting ahead drop or climb on as the car comes under them; any that
## comes off the car goes back to running; the dead lie where they fell and are left behind
func _tick_minions(dt: float, p: Player) -> void:
	var inv := route.transform.affine_inverse()
	var tail_w := Vector3(HOME.x, Y, _tail())
	var tail_r := inv * tail_w
	var back := (inv.basis * Vector3(0.0, 0.0, -1.0)).normalized()
	var on_car := _on_car()
	for r: Taken in _minions.duplicate():
		if not is_instance_valid(r) or not Game.enemies.robots.has(r):
			_minions.erase(r)
			continue
		var id := r.get_instance_id()
		var d: Dictionary = _mp.get(id, {"m": "deck", "p": Vector3.ZERO})
		_mp[id] = d
		var m: String = d["m"]
		if r.dead:
			if not d.has("scored"):      # (points for it: more for one shot out of the air or off a girder, before it was on the car)
				d["scored"] = true
				var air := r.leap_t >= 0.0 or m == "hang" or m == "climb"
				var n: int = PTS["taken_air"] if air else PTS["taken"]
				_add_score(n, Vector3(r.x, r.y + 2.0, r.z), "+%d" % n)
			if m != "dead" and (r.held or r.y < Y + DECK - 0.3 or absf(r.x - HOME.x) > 1.9):
				d["m"] = "dead"
				d["p"] = inv * Vector3(r.x, r.y, r.z)
				r.held = true
				if not _said.has("people"):
					_say("people")
			if d["m"] == "dead":
				var w: Vector3 = route.transform * (d["p"] as Vector3)
				r.x = w.x
				r.y = w.y
				r.z = w.z
				if w.distance_to(tail_w) > 90.0:
					_minions.erase(r)
					Game.despawn_enemy(r)
			continue
		match m:
			"line":
				var target := tail_r + back * 2.2
				if _stand_off():      # they drop back behind the Sigil while its screens are the business
					target = tail_r + back * 28.0 + (inv.basis * Vector3(2.0 if id % 2 == 0 else -2.0, 0.0, 0.0))      # (well behind the Sigil: nearer, they stood in front of its low screens)
				var pr: Vector3 = d["p"]
				var to := target - pr
				var dist := to.length()
				pr += to / maxf(dist, 0.001) * minf(dist, (v + 6.5) * dt)
				d["p"] = pr
				var w: Vector3 = route.transform * pr
				r.x = w.x
				r.y = w.y
				r.z = w.z
				r.yaw = 0.0
				r.vx = 0.0
				r.vz = 5.0
				if dist < 2.5 and on_car < ON_CAR and not p.dead and not _stand_off():
					r.held = false
					r.vz = 0.0
					d["m"] = "deck"
					r.leap(Vector3(HOME.x + clampf(r.x - HOME.x, -1.1, 1.1), Y + DECK, _tail() + 1.1), 0.75, 0.3)
					on_car += 1
				elif w.distance_to(tail_w) > 120.0:
					_minions.erase(r)
					Game.despawn_enemy(r)
			"hang", "climb":
				var w: Vector3 = route.transform * (d["p"] as Vector3)
				r.x = w.x
				r.y = w.y
				r.z = w.z
				r.yaw = PI
				r.vx = 0.0
				r.vz = 0.0
				var over := w.z > _tail() - 1.0 and w.z < HOME.z + 8.5
				if over and on_car < ON_CAR and not p.dead and not _stand_off():
					r.held = false
					d["m"] = "deck"
					r.leap(Vector3(HOME.x + randf_range(-0.9, 0.9), Y + DECK, clampf(w.z - 2.0, _tail() + 1.0, HOME.z + 8.0)), 0.55 if m == "hang" else 0.7, 0.05)
					audio.play_at("beast-snarl%d" % (1 + randi() % 3), w, -4.0, 1.6)
					on_car += 1
				elif w.z < _tail() - 30.0:
					_minions.erase(r)
					Game.despawn_enemy(r)
			"deck":
				if r.leap_t < 0.0 and r.y < Y + 0.6:      # off the car: back on the line, running
					d["m"] = "line"
					d["p"] = inv * Vector3(r.x, Y, r.z)
					r.held = true


# ---- the ride's feel: bumps, the bends, the alarm, portals --------------------------------------------------------------------------------------------------------------------

## a: how hard; ax: about which axis the world rocks round the car (none given: a random one)
func _jolt(a: float, ax: Vector3 = Vector3.ZERO) -> void:
	_jolt_a = a
	_jolt_t = 0.0
	_jolt_ax = ax.normalized() if ax != Vector3.ZERO else Vector3(randf_range(0.4, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()


## The world shaken about the train: the bad track's jolts, and a rumble that never stops at speed
func _tick_jolts(dt: float) -> void:
	if _bumpy:
		_bump_cd -= dt
		if _bump_cd <= 0.0:
			_bump_cd = randf_range(0.25, 0.85)
			var k := randf_range(0.5, 1.0)
			_jolt(0.035 * k)
			Game.fx.shake = maxf(Game.fx.shake, 0.5 * k)
			Game.fx.vertical_shake = 0.5 * k
			Game.fx.vertical_shake_t = 0.1
			audio.sfx("train-bump", -3.0 + 4.0 * k, randf_range(0.9, 1.1))
			var inv := route.transform.affine_inverse()
			for side: float in [-1.0, 1.0]:
				var w := inv * Vector3(HOME.x + side * 1.2, Y + 0.3, HOME.z + randf_range(-8.0, 8.0))
				for j in 6:
					route.fire(w, Vector3(side * randf_range(1.0, 4.0), randf_range(1.0, 4.0), randf_range(-3.0, 3.0)), 0.08, 0.0, randf_range(0.2, 0.45), Color(1.0, 0.7, 0.3) * 2.0)
	_jolt_t += dt
	var a := _jolt_a * exp(-_jolt_t * 7.0) * sin(_jolt_t * 34.0)
	var rumble := (0.006 * sin(_t * 47.0) + 0.004 * sin(_t * 29.0)) * clampf(v / 25.0, 0.0, 1.2)
	var c := Vector3(HOME.x, Y + 1.2, HOME.z)
	var tip := 0.0      # the car tipped down at the tail under what landed on it: the world turns about the car
	if _tip_t >= 0.0:
		_tip_t += dt
		tip = 0.12 * exp(-_tip_t * 1.5) * minf(1.0, _tip_t / 0.12)
		if _tip_t > 2.4:
			_tip_t = -1.0
	# (the jump: the train does not move, so the world drops away under it by _hop; the engine and power car ride the route, and are lifted back by the same)
	route.jolt = Transform3D(Basis.IDENTITY, c + Vector3(0.0, a * 0.9 + rumble - _hop, 0.0)) * Transform3D(Basis.from_euler(_jolt_ax * a) * Basis(Vector3.RIGHT, tip), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -c)
	train.bounce = -a * 0.6 + rumble * 0.5 + _hop / 0.55


func _tick_air(dt: float) -> void:
	var want: Array = AIR.get(route.kind_at(s), AIR_HOME)
	_air_c = _air_c.lerp(want[0], minf(1.0, dt * 0.7))
	_air_d = lerpf(_air_d, want[1], minf(1.0, dt * 0.7))
	_air_cd -= dt
	if _air_cd <= 0.0:
		_air_cd = 0.1
		Game.view.apply_render_state({"background": _air_c, "fog": [_air_c, _air_d]})


func _air_home() -> void:
	_air_c = AIR_HOME[0]
	_air_d = AIR_HOME[1]
	Game.view.apply_render_state({"background": _air_c, "fog": [_air_c, _air_d]})


func _loops_on() -> void:
	audio.loop("train-run", train.engine, Vector3(0.0, 1.5, 0.0))
	audio.loop("train-screech", train, Vector3(HOME.x, Y + 0.5, HOME.z))
	if beast != null:
		audio.loop("beast-hive", beast, Vector3(0.0, 6.0, 0.0))
		audio.loop("beast-crt", beast, Vector3(0.0, 5.0, 2.0))


## The loops' levels: the train by its speed, the flanges by how hard it is turning, the beast's hive and set while it is in sight
func _tick_loops(_dt: float) -> void:
	var riding := mode != &"run" and mode != &"off"
	audio.set_loop("train-run", (-30.0 + 24.0 * clampf(v / 24.0, 0.0, 1.0)) if riding else -60.0, 0.75 + 0.35 * clampf(v / 28.0, 0.0, 1.3))
	var lat := absf(route.kappa_at(s)) * v * v      # m/s/s across
	audio.set_loop("train-screech", (-40.0 + 34.0 * clampf((lat - 1.2) / 3.0, 0.0, 1.0)) if riding else -60.0, 0.95 + 0.1 * sin(_t * 3.0))
	if riding and lat > 2.2 and randf() < 0.5:      # sparks off the wheels on a hard bend
		var inv := route.transform.affine_inverse()
		var side := -signf(route.kappa_at(s))
		var w := inv * Vector3(HOME.x + side * 0.8, Y + 0.25, HOME.z + randf_range(-9.0, 9.0))
		route.fire(w, Vector3(side * randf_range(1.0, 3.0), randf_range(0.5, 2.5), randf_range(-4.0, 0.0)), 0.07, 0.0, randf_range(0.2, 0.4), Color(1.0, 0.75, 0.35) * 2.2)
	var seen := beast != null and beast.visible
	var d := beast.global_position.distance_to(Vector3(HOME.x, Y, HOME.z)) if seen else 999.0
	audio.set_loop("beast-hive", (-8.0 - d * 0.1) if seen else -60.0, 1.0)
	audio.set_loop("beast-crt", (-14.0 - d * 0.15 + (8.0 if beast.crt_armed else 0.0)) if seen else -60.0, 1.0)


func _tick_alarm() -> void:
	if not _alarm:
		return
	var on := fmod(_t * 1.6, 1.0) < 0.5
	for l: Node in get_tree().get_nodes_in_group(&"uf_alarm"):
		(l as OmniLight3D).light_energy = (2.6 if on else 0.15) * UnderfointLevel.GAIN


## The spans behind the point where the Sigil hit the bridge go one by one, chasing the train
func _tick_spans() -> void:
	if not _spans_on:
		return
	for t in route.spans:
		if t.t < 0.0 and t.sig < s - 22.0:
			t.t = 0.0
			t.spin = Vector3(randf_range(-0.25, 0.25), randf_range(-0.1, 0.1), randf_range(-0.35, 0.35))
			route.blast(route.pt(t.sig, 0.0, -2.0), 5.0, false, 14)
			route.blast(route.pt(t.sig + 12.0, randf_range(-4.0, 4.0), -10.0), 4.0, false, 6)
			audio.play_at("crash-rubble", route.world(t.sig, 0.0, -4.0), 8.0, randf_range(0.75, 0.9))
			Game.fx.shake = maxf(Game.fx.shake, 0.5)


## The blast door. Both its locks shot off before the engine gets there: the leaves are blown out of the way and the train goes through clean. Not: the engine hits a locked door, the deck takes what
## comes off it, the train is slowed to a crawl for a few seconds, and the Sigil is on the car at once. (It used to be only to watch.)
func _tick_doors() -> void:
	if _doors_hit or route.doors.is_empty():
		return
	var any := false
	var locked := false
	for pp in _props:
		if pp.kind == "door":
			any = true
			if not pp.gone:
				locked = true
	var clean := any and not locked and not _door_done
	var reached := s + 32.5 >= route.doors[0].sig
	if not clean and not reached:
		return
	_doors_hit = true
	_door_done = true
	for t in route.doors:
		t.alive = false
		t.t = 0.0
		t.vel = Vector3(signf(t.u) * randf_range(14.0, 18.0), randf_range(4.0, 7.0), randf_range(24.0, 30.0))      # (out of the way, keeping up with the engine as they go)
		t.spin = Vector3(randf_range(-2.0, 2.0), randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))
	var at := route.pt(route.doors[0].sig, 0.0, 4.0)
	if clean:      # blown open ahead of the train
		_door_clean = true
		_uses += 1
		route.blast(at, 5.0, true, 14)
		audio.play_at("omni:boom-big", route.world(route.doors[0].sig, 0.0, 4.0), 8.0, 0.9)
		audio.play_at("crash-metal", route.world(route.doors[0].sig, 0.0, 4.0), 6.0, 0.8)
		_add_score(PTS["door"], route.world(route.doors[0].sig, 0.0, 7.0), "DOOR OPEN  +%d" % PTS["door"])
		_shout("dooropen", "IT'S OPEN! HOLD ON!")
		Game.fx.shake = maxf(Game.fx.shake, 0.6)
		return
	for pp in _props:
		if pp.kind == "door":
			_prop_off(pp)
			pp.gone = true
	route.blast(at, 4.0, false, 18)
	for k in 30:
		route.fire(at, Vector3(randf_range(-12.0, 12.0), randf_range(-2.0, 10.0), randf_range(4.0, 20.0)), 0.1, 0.0, randf_range(0.3, 0.7), Color(1.0, 0.75, 0.35) * 2.0)
	audio.sfx("crash-metal", 8.0, 0.75)
	audio.sfx("omni:boom-big", 2.0)
	Game.fx.shake = maxf(Game.fx.shake, 1.6)
	Game.fx.vertical_shake = 0.9
	Game.fx.vertical_shake_t = 0.12
	_jolt(0.1, Vector3(1.0, 0.0, 0.2))
	_fov_kick = maxf(_fov_kick, 7.0)
	_door_t = 3.0
	v = minf(v, 14.0)
	var p := Game.player
	if not p.dead:
		p.invuln = 0.0
		Game.combat.hurt_player(p, DOOR_DMG, p.x, p.z + 4.0, "melee")
	var inv := route.transform.affine_inverse()
	route.debris(inv * Vector3(HOME.x, Y + 3.0, HOME.z + 9.0), 12, 9.0, 0.5, 0.6)      # what comes back over the tender onto the deck
	_combo = 0
	_shout("doorhit", "IT WAS LOCKED! IT'S RIGHT ON US!")
	gap = minf(gap, 22.0)
	if _att == null:
		var a := _mk("rear", 4, 3.8, 0.2)
		a.at = _t
		_att_q.push_front(a)


## SERN's machinery leaking out of it: holes open in the air and on the walls round the train, more of them the angrier it is, and are left behind (they are made in the line's space)
func _tick_portals(dt: float) -> void:
	var rate := _portal_rate
	if mode == &"out":
		rate = 2.6
	_portal_cd -= dt * rate
	if _portal_cd <= 0.0 and rate > 0.0:
		_portal_cd = randf_range(0.6, 1.4)
		var k := _portal_age.find(-1.0)
		if k >= 0:
			var mi := _portals[k]
			var sz := randf_range(3.0, 7.0)
			var at := s + randf_range(-30.0, 70.0)
			var f := route.frame_at(at)
			if randf() < 0.3:
				mi.transform = f * Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(sz, sz, 1.0)), Vector3(randf_range(-4.0, 4.0), 9.3, 0.0))
			else:
				var side := -1.0 if randf() < 0.5 else 1.0
				mi.transform = f * Transform3D(Basis(Vector3.UP, -side * PI * 0.5).scaled(Vector3(sz, sz, 1.0)), Vector3(side * 6.8, randf_range(2.5, 6.5), 0.0))
			mi.visible = true
			_portal_age[k] = 0.0
			audio.play_at("omni:arc", route.transform * mi.position, -2.0, randf_range(0.6, 0.9))
	for k in _portals.size():
		if _portal_age[k] < 0.0:
			continue
		_portal_age[k] += dt
		var mi := _portals[k]
		_portal_mats[k].set_shader_parameter(&"open", clampf(_portal_age[k] / 0.35, 0.0, 1.0) * clampf((12.0 - _portal_age[k]) / 1.0, 0.0, 1.0))
		if randf() < dt * 1.5:      # what spills out of SERN's holes
			route.fire(mi.position, mi.transform.basis.z.normalized() * randf_range(3.0, 8.0), 0.3, 0.6, 0.5, Color(0.7, 0.5, 1.0) * 1.6)
		if _portal_age[k] > 12.0 or route.frame_at(s).origin.distance_to(mi.position) > 160.0:
			_portal_age[k] = -1.0
			mi.visible = false


# ---- the end of the line -------------------------------------------------------------------------------------------------------------------------------------------------------

## The depot's big moment (2026-11-15): whatever is left of SERN's fuel goes up behind the train and the fire comes down the tunnel after it. The Sigil drops back into it, and comes out of it
## burning: it burns for the rest of the ride. Nothing to do but watch it come.
func _firestorm() -> void:
	_fire_t = 0.0
	_fire_out = false
	_fire_cd = 0.0
	_fire_front = _tail_sig() - 95.0
	for i in route.tanks.size():      # every tank still standing, one after another
		if route.tanks[i].alive:
			get_tree().create_timer(0.15 * i).timeout.connect(_tank_up.bind(i, _gen))
	audio.sfx("omni:detonate", 4.0, 0.8)
	Game.fx.shake = maxf(Game.fx.shake, 1.4)
	_fov_kick = maxf(_fov_kick, 5.0)
	_turn_t = 2.0
	_shout("depotup", "THE WHOLE DEPOT'S GOING UP! HOLD ON!")
	if _att == null and b_mode == &"chase":
		gap_want = 26.0


func _tick_firestorm(dt: float) -> void:
	if _fire_t < 0.0:
		return
	_fire_t += dt
	_fire_front = move_toward(_fire_front, _tail_sig() - 16.0, (v + 30.0) * dt)
	_fire_cd -= dt
	if _fire_cd <= 0.0:
		_fire_cd = 0.11
		route.blast(route.pt(_fire_front + randf_range(-5.0, 3.0), randf_range(-8.0, 8.0), randf_range(1.0, 8.0)), randf_range(3.0, 4.6), true, 3)
		Game.fx.shake = maxf(Game.fx.shake, 0.55)
	if not _fire_out and _fire_t > 2.3:      # out of the fire, alight
		_fire_out = true
		_burning = true
		_burn = maxf(_burn, 4.0)
		beast.burning = true
		beast.damage = maxi(beast.damage, 1)
		if _att == null and b_mode == &"chase":
			gap_want = REST_GAP
		_roar(true)
		_fov_kick = maxf(_fov_kick, 5.0)
		_shout("alight", "IT'S ON FIRE AND IT'S STILL COMING!")
	if _fire_t > 3.6:
		_fire_t = -1.0


## The viaduct's big moment (2026-11-15): the bridge is coming down behind the train (_tick_spans), and the last of the falling spans goes before the train gets there. The train jumps it: the
## world drops away under the car (route.jolt), slowed for a moment, the view pulled back; it lands hard, and a second later the Sigil comes over the gap after it (_pounce).
func _tick_hop(_dt: float) -> void:
	if route.spans.is_empty() or not _spans_on:
		return
	var ah := route.mark("ahead")
	if not _gap_dropped and s + 32.0 > ah + 150.0 and s < ah + 205.0:
		_gap_dropped = true
		var t := route.spans[route.spans.size() - 1]
		if t.t < 0.0:
			t.t = 0.0
			t.spin = Vector3(randf_range(-0.2, 0.2), randf_range(-0.1, 0.1), randf_range(-0.3, 0.3))
			route.blast(route.pt(t.sig, 0.0, -2.0), 6.0, false, 18)
			route.blast(route.pt(t.sig - 10.0, randf_range(-4.0, 4.0), -6.0), 4.5, false, 8)
			audio.play_at("crash-rubble", route.world(t.sig, 0.0, -4.0), 10.0, 0.8)
		_shout("gapahead", "THE BRIDGE IS OUT AHEAD! HOLD ON TO SOMETHING!", true, true)
		audio.sfx("train-horn", 2.0)
	if not _gap_dropped:
		return
	var h0 := ah + 214.0
	var h1 := ah + 257.0
	if s >= h0 and s < h1:
		var u := (s - h0) / (h1 - h0)
		_hop = 2.8 * 4.0 * u * (1.0 - u)
		if not _hop_on:
			_hop_on = true
			_clear_deck()
			audio.sfx("omni:groan", 3.0, 1.3)
			Game.fx.shake = maxf(Game.fx.shake, 1.0)
			_fov_kick = maxf(_fov_kick, 7.0)
		if _stop_ms == 0:
			Game.time_scale = 0.5 if u > 0.18 and u < 0.82 else 1.0
	elif _hop_on:      # down on the far side
		_hop_on = false
		_hop = 0.0
		if _stop_ms == 0:
			Game.time_scale = 1.0
		_jolt(0.11, Vector3(1.0, 0.0, 0.0))
		Game.fx.shake = maxf(Game.fx.shake, 1.9)
		Game.fx.vertical_shake = 1.0
		Game.fx.vertical_shake_t = 0.12
		_fov_kick = maxf(_fov_kick, 6.0)
		audio.sfx("crash-metal", 6.0, 0.7)
		audio.sfx("train-bump", 6.0, 0.8)
		var inv := route.transform.affine_inverse()
		for k in 50:
			var side := -1.0 if k % 2 == 0 else 1.0
			route.fire(inv * Vector3(HOME.x + side * 1.2, Y + 0.3, HOME.z + randf_range(-9.0, 9.0)), inv.basis * Vector3(side * randf_range(1.0, 6.0), randf_range(1.0, 6.0), randf_range(-10.0, -2.0)), 0.09, 0.0, randf_range(0.3, 0.8), Color(1.0, 0.72, 0.32) * 2.2)
		_pounce_cd = 0.9


## It comes over the gap after the train...
func _pounce() -> void:
	_discount()
	_clear_points()
	_mode_next = &""
	_end_attack()
	b_mode = &"pounce"
	_b_t = 0.0
	_pounce_gap = 46.0
	gap = _pounce_gap
	b_sig = _tail_sig() - gap
	b_u = 0.0
	b_h = -14.0
	b_roll = 0.0
	beast.visible = true
	_turn_t = 2.0
	_roar(true)
	_shout("pounce", "IT'S JUMPING THE GAP!")


## ...and lands on the car's tail: the section under it goes, the car tips, and he slides toward it
func _pounce_land() -> void:
	b_mode = &"chase"
	_b_t = 0.0
	b_h = 0.0
	gap_want = REST_GAP
	beast.play(&"land")
	route.blast(route.pt(b_sig + 5.0, 0.0, 0.5), 4.0, false, 14)
	audio.play_at("omni:boom-big", beast.global_position + Vector3(0.0, 2.0, 0.0), 6.0, 0.8)
	audio.play_at("beast-stomp2", beast.global_position, 8.0, 0.7)
	Game.fx.vertical_shake = 1.0
	Game.fx.vertical_shake_t = 0.12
	_rip()
	_tip_t = 0.0
	_lunge = 0.0
	_say("mine", false)
	_calm_t = 2.0
	_feint_t = 3.5


## The spiral's big moment (2026-11-15): it runs the wall past the car and comes down on the engine, facing back at you over the Ticket Man's booth. SERN's gun on the car comes alive for it:
## the one stretch of the ride that is the gun's. Its screens light until they are all out (it is blasted off, back along the wall) or the spiral ends.
func _to_engine() -> void:
	if beast == null or not beast.visible:
		return
	_discount()
	_clear_points()
	_mode_next = &""
	_end_attack()
	b_mode = &"engine"
	_b_t = 0.0
	_turn_t = 2.8
	turret.live = sections > 0
	_roar(true)
	_shout("engine", "IT'S ON THE ENGINE! THE GUN'S LIVE! GET ON THE GUN!", true, true)
	_att_q.clear()
	var a := _mk("engine", 6, 7.0, 0.2)
	a.at = _t
	a.rounds = 2
	_att_q.append(a)


func _engine_off() -> void:
	var chest := beast.global_position + Vector3(0.0, 7.5, 0.0)
	_mode_next = &""
	_end_attack()
	b_mode = &"wall"
	_b_t = 0.0
	_wall_to_chase = true
	beast.damage += 1
	_uses += 1
	_add_score(3000, chest, "BLASTED OFF  +3000")
	route.blast(route.transform.affine_inverse() * chest, 4.0, true, 10)
	audio.play_at("beast-shriek1", chest, 8.0, 0.8)
	audio.sfx("omni:boom-big", 3.0, 0.9)
	Game.fx.shake = maxf(Game.fx.shake, 1.5)
	_hitstop(0.12)
	_shout("off", "IT'S OFF! IT'S OFF THE ENGINE!")


## The end, after its set is shot (2026-11-15: it used to let go there). It does not let go. The Ticket Man cuts the car loose: three seconds to get forward, then the last section goes with the
## Sigil still holding it, and the train runs for the gate. He is carried up the car ahead of the edge if he did not run, as at every section: this is a thing to watch, not to fail.
func _uncouple() -> void:
	_mode_next = &""
	_end_attack()
	_unc_t = 0.0
	turret.mount(false)
	turret.live = false
	_lines.clear()
	_line_t = 0.0
	Game.hud.subtitles_clear()
	_shout("cut", "IT WON'T LET GO! I'M CUTTING THE CAR LOOSE! GET UP HERE! RUN!", true, true)
	audio.play_at("beast-shriek1", beast.global_position + Vector3(0, 7, 0), 8.0, 0.8)
	audio.sfx("omni:groan", 4.0, 0.9)


func _tick_uncouple(dt: float) -> void:
	if _unc_t < 0.0:
		return
	_unc_t += dt
	_calm_t = 1.5
	Game.fx.shake = maxf(Game.fx.shake, 0.45 + 0.3 * _unc_t)
	if randf() < dt * 40.0:      # the coupling going, at the front of the last section
		var inv := route.transform.affine_inverse()
		route.fire(inv * Vector3(HOME.x + randf_range(-1.4, 1.4), Y + 1.0, HOME.z + 9.0), inv.basis * Vector3(randf_range(-5.0, 5.0), randf_range(1.0, 7.0), randf_range(-9.0, 2.0)), 0.1, 0.0, randf_range(0.3, 0.8), Color(1.0, 0.72, 0.32) * 2.2)
	if _unc_t > 3.2:
		_unc_t = -1.0
		_rip()
		_release()


## It catches the car and holds it; its own set is the last target
func _finale() -> void:
	_discount()
	_mode_next = &""
	_end_attack()
	b_mode = &"grab"
	_b_t = 0.0
	_turn_t = 2.0
	# (the gun cannot be raised to its head when it stands over the car: a bot at the gun here was hit until it died. Its grip on the car kills the gun's power: the end is fought on foot.)
	turret.mount(false)
	turret.live = false
	beast.visible = true
	_att_q.clear()
	_att = _mk("crt", 1, 3.2)
	_ap = 0
	_ap_t = 0.0
	audio.sfx("train-brake", 4.0)
	audio.sfx("crash-metal", 6.0, 0.7)
	_roar(true)
	_say("have")
	_shout("held", "IT'S GOT THE CAR! ITS OWN SCREEN, IN ITS HEAD! SHOOT IT!")
	Game.fx.shake = maxf(Game.fx.shake, 1.2)
	if route.gate_mat != null:
		route.gate_mat.set_shader_parameter(&"open", 0.0)
	_portal_rate = 2.2


## You hit its set: it lets go, and the train runs for the gate
func _release() -> void:
	_mode_next = &""
	_end_attack()
	mode = &"out"
	_out_t = 0.0
	b_mode = &"chase"
	gap_want = 60.0
	beast.crt_armed = false
	audio.play_at("beast-shriek1", beast.global_position + Vector3(0, 7, 0), 10.0, 0.75)
	audio.music_loop(false)
	audio.music(UfChaseAudio.FINAL, 0.3)
	audio.sfx("train-horn", 2.0)
	Game.fx.shake = maxf(Game.fx.shake, 1.0)
	_lines.clear()      # (what was shouted while it held the car is over)
	Game.hud.subtitles_clear()
	_line_t = 0.0
	_grade()


## The run's grade, as an arcade rail shooter gives one: by how many of its screens you shot, and how few blows it landed. Shown once, at the gate (a fuller results screen is a proposal for the user).
func _grade() -> void:
	if _graded:
		return
	_graded = true
	var acc := float(_shot_n) / maxf(1.0, float(_lit_n))
	var g := "D"
	if acc >= 0.95 and _blows == 0:
		g = "S"
	elif acc >= 0.85 and _blows <= 1:
		g = "A"
	elif acc >= 0.7:
		g = "B"
	elif acc >= 0.5:
		g = "C"
	Game.hud.toast("ESCAPED  ·  GRADE %s  ·  %s PTS  ·  SCREENS %d/%d  ·  SETS %d/%d  ·  SET PIECES %d" % [g, _fmt(_score), _shot_n, _lit_n, _sets_clear, _sets, _uses], 6.0)


func _tick_out(dt: float) -> void:
	_out_t += dt
	gap_want = 30.0 + _out_t * 18.0
	beast.sway = sin(_out_t * 13.0) * maxf(0.0, 1.0 - _out_t * 0.5)
	beast.slash_l = move_toward(beast.slash_l, 0.0, dt)
	beast.slash_r = move_toward(beast.slash_r, 0.0, dt)
	if _out_t > 1.2:
		_say("screens")
	var gz := route.mark("finale") + 230.0
	if route.gate_mat != null:
		route.gate_mat.set_shader_parameter(&"open", clampf(_out_t / 1.5, 0.0, 1.0))
	if s + 32.0 > gz and _veil_want < 1.0:
		_veil.color = Color(0.82, 0.7, 1.0, _veil_a)
		_veil_want = 1.0
		audio.sfx("omni:implode", 4.0)
	if s > gz - 6.0 and done < 3:
		done = 3
		if not Game.story_get("ufEscaped"):
			Game.story_set("ufEscaped")
		audio.music_stop(2.0)
		Game.call_deferred(&"enter_level", "hub", "")      # (where that gate really goes is a level that is not made yet)


# ---- you ---------------------------------------------------------------------------------------------------------------------------------------------------------------------

## The crate on the car is SERN's: if you came down here with nothing that shoots, there is a rifle in it
func _arm_player() -> void:
	var c := Game.combat
	var i := Weapons.index_of("rifle")
	if i < 0:
		return
	if c.owned.size() == 0:
		c.give(i)
	if c.cur < 0 and c.owned.has(i):
		c.equip(i)
