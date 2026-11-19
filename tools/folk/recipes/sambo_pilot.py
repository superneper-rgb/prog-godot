## SAMBO FENRIR out of his suit: the little green alien who drives the `disguised` rubber human, whole: the pilot's own head on a scrawny pot-bellied body, bare lime skin and one fat gold chain.
# A sleazy, dorky, wannabe-famous streamer. Not a crowd walker: his mission poses him on top of these clips (the suit's rubber body snaps off at the
# neck; at the end he falls out of a mech, begs for mercy while being a condescending prick, and walks off).
# The head IS the disguised pilot's, 1:1: the shapes are taken out of recipes/disguised.py's pilot() and moved down onto his neck (the skull and its
# muzzle, the big glossy black eyes, the two antennae with ball tips), and painted with the same colours, mottling and glints, read in the pilot's
# own space so even the noise falls the same. Left out: the lever arm and the blob of shoulders the pilot had down inside the hatch (a thin neck
# takes its place). Changed for the close-ups he gets: the eyes meshed finely as their own piece, crisp ink where each meets the skin, and the
# glints' edges sharpened (the same place and size).
# Measured: 0.34 m to the antennae's balls, 0.27 to the crown; the head 0.10 wide and 0.10 from chin to crown, so about three heads tall.
# Rest pose: standing, arms hanging a little out from the belly, hands relaxed (two fingers and a thumb with round pads). Bones beyond the kit's
# usual set: antenna/antenna_tip .L/.R (two per antenna) and finger1/finger2/thumb .L/.R, so his scenes can droop his antennae and close his fists.
import os
import importlib.util
import numpy as np
from kit.sdf import Sphere, Ellipsoid, RoundCone, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump, loft, rot, ridge_line, v3, basis, place, noise3


def _disguised():
    """recipes/disguised.py: his head comes out of its pilot()"""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "disguised.py")
    spec = importlib.util.spec_from_file_location("folk_recipe_disguised_for_sambo", path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


D = _disguised()

HEIGHT = 0.34
REF = ("old/disguised.png", None)

HSKIN, SKIN, EYE, GOLD = range(1, 5)
COLOURS = {
    HSKIN: D.COLOURS[D.ALIEN],
    SKIN: D.COLOURS[D.ALIEN],
    EYE: D.COLOURS[D.AEYE],
    GOLD: ((0.95, 0.68, 0.25), 0.25, 1.0),
}
F32 = np.float32


def unit(a):
    a = v3(a)
    return a / np.linalg.norm(a)


def _sm(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# the pilot's head moved from the suit's hatch (disguised.PILOT_C) onto his neck
T = v3((0.0, 0.008, -1.402))
HC = D.PILOT_C + T                                     # (0, -0.004, 0.226): the head's centre
ANT = [HC + v3((0.018, 0.0, 0.04)), HC + v3((0.03, -0.004, 0.08)), HC + v3((0.042, 0.004, 0.105))]     # the left antenna as pilot() draws it: root, bend, tip
ANT_BALL = HC + v3((0.043, 0.004, 0.108))

# landmarks, left side (+X); he faces -Y
NECK_A, NECK_B = v3((0.0, 0.0075, 0.143)), v3((0.0, 0.007, 0.197))
NECK_TOP = v3((0.0, 0.007, 0.183))                     # where the head turns on the neck
SHOULDER = v3((0.027, 0.005, 0.149))
ELBOW = v3((0.042, 0.011, 0.111))
WRIST = v3((0.053, 0.001, 0.0765))
HAND = basis(-(WRIST - ELBOW), v3((0, 1, 0)))           # hand space -> world: fingers along local -Z, the back of the hand +X (out), the thumb -Y (forward)
HIP = v3((0.0165, 0.005, 0.088))
KNEE = v3((0.018, -0.0015, 0.0495))
ANKLE = v3((0.019, 0.006, 0.0125))
BALL = v3((0.0195, -0.0125, 0.0))                      # the ball of the left foot
TOE = v3((0.0195, -0.025, 0.0035))

# the hand in hand space: two fingers (1 beside the thumb, 2 behind it) and the thumb, each [(point, radius), ...] from its knuckle to its tip.
# HS scales the hand up from these numbers (so a pleading pair of hands reads next to that head).
HS = 1.12
KNUCK = v3((0.0, 0.0, -0.0112)) * HS
DIGITS = {nm: [(v3(p) * HS, r * HS) for p, r in pts] for nm, pts in {
    "finger1": [((0.0, -0.0031, -0.0112), 0.0021), ((-0.0014, -0.0038, -0.0178), 0.0019), ((-0.0036, -0.0044, -0.0236), 0.0018)],
    "finger2": [((0.0, 0.0031, -0.0112), 0.0021), ((-0.0014, 0.0038, -0.0172), 0.0019), ((-0.0034, 0.0044, -0.0226), 0.0018)],
    "thumb": [((-0.0012, -0.0047, -0.0047), 0.0021), ((-0.0033, -0.0076, -0.0089), 0.0019), ((-0.0048, -0.0087, -0.0125), 0.0017)],
}.items()}
BULB = {"finger1": 0.0025 * HS, "finger2": 0.0025 * HS, "thumb": 0.0022 * HS}
PAD = v3((-0.0004, 0.0, -0.0006)) * HS                 # each round pad sits a little past its digit's tip
THUMB_FOLD = unit((0.71, 0.42, -0.51))                  # (hand space) the axis the thumb folds over the palm about


def in_world(p, sx=1.0):
    """a hand-space point of the left hand in the world (sx = -1: the same point of the right hand)"""
    w = WRIST + HAND @ v3(p)
    return (w * np.array([sx, 1.0, 1.0], F32)).astype(F32)


def front_y(shape, x, z, y0=-0.08, y1=0.04):
    ys = np.linspace(y0, y1, 2401).astype(F32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    return float(ys[int(np.argmax(shape.eval(P)[0] < 0))])


# ---------------------------------------------------------------------------------------------------- the head (the pilot's)

def head_parts():
    """(skin, eyes): pilot()'s skull and muzzle and its antennae, and its eyes, moved down onto his neck. Not its lever arm, the lever, or the
    third ellipsoid of the skull (the stub of shoulders it had down in the hatch)."""
    whole = D.pilot()                      # Union([Union([skull, antennae, arm, fist]), eyes, lever])
    inner, eyes = whole.kids[0], whole.kids[1]
    skull, ants = inner.kids[0], inner.kids[1]
    assert len(skull.kids) == 3 and all(type(k).__name__ == "Ellipsoid" for k in skull.kids), "disguised.pilot() changed: check sambo_pilot.head_parts()"
    skin = Union([Union(skull.kids[:2], k=float(skull.k)), ants], k=float(inner.k), part=HSKIN)
    return Move(skin, t=T), Move(Union([eyes], part=EYE), t=T)


def head():
    return head_parts()[0]


def eyes():
    """the eyes, meshed finely on their own (the glints' edges are only as crisp as the mesh under their paint); what lies deeper than 2 mm
    inside the skull is cut away"""
    skin, eyes_ = head_parts()
    return Cut(eyes_, [Inflate(skin, -0.002)], k=0.0)


# ---------------------------------------------------------------------------------------------------- the body

def trunk_core():
    """a narrow little chest, narrow shoulders, a round potbelly over a small pelvis and bum; the thin neck rising out of it into the head"""
    chest = Ellipsoid((0, 0.005, 0.1355), (0.0205, 0.0145, 0.0195))
    girdle = Ellipsoid((0, 0.0065, 0.1465), (0.0255, 0.0115, 0.0072))
    belly = Ellipsoid((0, -0.002, 0.1075), (0.023, 0.021, 0.0235))
    pelvis = Ellipsoid((0, 0.005, 0.0915), (0.0215, 0.0165, 0.0145))
    bum = Mirror(Ellipsoid((0.0085, 0.0125, 0.0885), (0.0105, 0.0085, 0.0105)))
    t = Union([chest, girdle, belly, pelvis, bum], k=0.009)
    neck = RoundCone(NECK_A, NECK_B, 0.0105, 0.0085)
    return Union([t, neck], k=0.008)


def _ribs(P):
    """three ribs each side across the scrawny chest, rising a little toward the back"""
    q = np.abs(P[:, 0])
    phi = np.arctan2(q, -(P[:, 1] - 0.005))            # 0 straight ahead, pi/2 at his side
    win = _sm(0.5, 0.85, phi) * _sm(2.1, 1.7, phi)
    out = np.zeros(len(P), F32)
    for z0 in (0.1262, 0.1322, 0.1382):
        out += np.exp(-((P[:, 2] - (z0 + 0.0042 * (phi - 1.0))) / 0.0013) ** 2)
    return (out * win).astype(F32)


def trunk():
    core = trunk_core()
    a = v3((0.0035, front_y(core, 0.0035, 0.1508) + 0.0003, 0.1508))
    b = v3((0.019, front_y(core, 0.019, 0.1528) + 0.0003, 0.1528))
    clav = ridge_line(a, b, 0.0023)

    def bones(P):
        Q = P.copy()
        Q[:, 0] = np.abs(Q[:, 0])
        return clav(Q) + _ribs(P) * 0.7
    return Bump(core, bones, 0.0007)


def navel():
    return v3((0.0, front_y(trunk_core(), 0.0, 0.1035) - 0.0003, 0.1035))


def arm():
    """the left arm from shoulder to wrist: spindly, a knobbly elbow"""
    a = loft([(SHOULDER, 0.0053), (ELBOW, 0.0043), (WRIST, 0.0037)], k=0.003)
    knob = Sphere(ELBOW + v3((0.0003, 0.0018, 0.0004)), 0.0047)
    return Union([a, knob], k=0.0022)


def hand():
    """the left hand in hand space (wrist at the origin, fingers along -Z, the back of the hand +X, the thumb -Y): a small palm, two long fingers
    and a thumb with round pads at their tips, relaxed and a little curled"""
    wrist = RoundCone((0, 0, 0.004), (0, 0, -0.003 * HS), 0.0037, 0.0035 * HS)
    palm = Ellipsoid((0.0, 0.0, -0.0068 * HS), v3((0.0029, 0.0056, 0.0062)) * HS)
    parts = [wrist, palm]
    for nm, pts in DIGITS.items():
        parts.append(loft(pts, k=0.0012))
        parts.append(Sphere(pts[-1][0] + PAD, BULB[nm]))
    return Union(parts, k=0.0016)


def leg():
    """the left leg: a thin thigh, a knobbly knee, a skinny shin with a bit of calf"""
    lg = loft([(HIP + v3((0.0, 0.0, 0.004)), 0.0088), (HIP, 0.0085), (KNEE, 0.0058), (ANKLE, 0.0045)], k=0.003)
    knee = Sphere(KNEE + v3((0.0, -0.0022, 0.0006)), 0.0057)
    calf = Ellipsoid(KNEE + (ANKLE - KNEE) * 0.32 + v3((0.0, 0.0016, 0.0)), (0.0057, 0.0058, 0.009))
    return Union([lg, knee, calf], k=0.0025)


def foot():
    """a small alien foot: a round heel, a short instep, three toes splayed a little; a flat sole"""
    x = float(ANKLE[0])
    heel = Ellipsoid((x, 0.0075, 0.0048), (0.0047, 0.0058, 0.0048))
    instep = loft([(ANKLE + v3((0.0, 0.0, -0.002)), 0.0047), (v3((x + 0.0003, -0.006, 0.0047)), 0.0052), (v3((x + 0.0006, -0.0145, 0.0038)), 0.005)], k=0.002)
    toes = [Ellipsoid((x + dx, -0.0205 + (0.0012 if dx else 0.0), 0.003), (0.0027, 0.0052, 0.0029), R=rot(rz=dx * 2200.0)) for dx in (-0.0047, 0.0, 0.0047)]
    f = Union([heel, instep] + toes, k=0.0025)
    return Clip(f, [Half((0, 0, 0.0), (0, 0, -1))], k=0.0012)


def body(arms=True):
    caps = Mirror(Sphere(SHOULDER + v3((-0.001, 0.0, -0.0005)), 0.0062))
    legs = Mirror(Union([leg(), foot()], k=0.0025))
    b = Union([trunk(), caps], k=0.006)
    if arms:
        b = Union([b, Mirror(Union([arm(), place(hand(), WRIST, HAND)], k=0.0016))], k=0.0045)
    b = Union([b, legs], k=0.006)
    b = Cut(b, [Ellipsoid(navel(), (0.0014, 0.0017, 0.0019))], k=0.0008)
    return Union([b], part=SKIN)


# ---------------------------------------------------------------------------------------------------- the chain

LINK = (0.0034, 0.0026, 0.0011)       # a link's half length, half width, half thickness
LINK_STEP = 0.0043                    # link to link along the chain (they overlap)
TWIST = 28.0                          # each link turned this far against the last, flat on the skin (Cuban links)
_LINKS = []


def _grad(shape, P, e=0.0002):
    ex = np.eye(3, dtype=F32) * e
    return np.stack([(shape.eval(P + ex[i])[0] - shape.eval(P - ex[i])[0]) / (2 * e) for i in range(3)], 1)


def _onto(shape, P, off, iters=8):
    """each point moved onto the surface `off` outside the shape"""
    for _ in range(iters):
        d = shape.eval(P)[0]
        g = _grad(shape, P)
        P = (P - ((d - off) / np.maximum((g * g).sum(1), 1e-6))[:, None] * g).astype(F32)
    return P


def links():
    """the left half of the chain (the right is its mirror): (centres (n, 3), frames (n, 3, 3), columns: along the chain, across it, out of the skin).
    A loop round the bottom of the neck: up on the trapezius behind, over the collarbones, sagging onto the chest in front; every link laid on the skin."""
    if not _LINKS:
        skin = body()
        th = np.linspace(0.0, 2 * np.pi, 180, endpoint=False).astype(F32)
        w = ((1.0 + np.cos(th)) * 0.5) ** 2.2
        # (started outside the skin, so each point finds the skin it would fall onto; then smoothed, so it drapes without kinks)
        P = np.stack([0.0168 * np.sin(th), 0.0072 - 0.0205 * np.cos(th), 0.1572 - 0.0236 * w], 1).astype(F32)
        off = LINK[2] * 0.85
        P = _onto(skin, P, off)
        for _ in range(60):
            P = _onto(skin, (P * 0.5 + (np.roll(P, 1, 0) + np.roll(P, -1, 0)) * 0.25).astype(F32), off, iters=2)
        seg = np.linalg.norm(np.roll(P, -1, 0) - P, axis=1)
        s = np.concatenate([[0.0], np.cumsum(seg)])
        L = float(s[-1])
        n = int(round(L / LINK_STEP / 2.0)) * 2
        Pl = np.concatenate([P, P[:1]], 0)

        def at(sv):
            return np.stack([np.interp(sv, s, Pl[:, i]) for i in range(3)], 1).astype(F32)
        sc = (np.arange(n // 2) + 0.5) / n * L          # link centres, the left half (theta 0..pi, front to back)
        C = _onto(skin, at(sc), off)
        tan = at(sc + 0.0008) - at(sc - 0.0008)
        nrm = _grad(skin, C)
        frames = []
        for i in range(len(C)):
            nn = unit(nrm[i])
            b = unit(np.cross(nn, tan[i]))
            t = np.cross(b, nn)
            a = np.radians(TWIST) * (1.0 if i % 2 == 0 else -1.0)
            t2 = t * np.cos(a) + b * np.sin(a)
            b2 = -t * np.sin(a) + b * np.cos(a)
            frames.append(np.stack([t2, b2, nn], 1).astype(F32))
        _LINKS.extend([C, np.array(frames, F32)])
    return _LINKS[0], _LINKS[1]


def chain():
    """a fat gold Cuban-link chain: flat oval links overlapping, each turned a little against the last, all the way round his neck"""
    C, Fr = links()
    return Mirror(Union([Ellipsoid(c, LINK, R=R, part=GOLD) for c, R in zip(C, Fr)], k=0.0003, part=GOLD))


def pieces():
    return [("head", head(), 0.0009), ("eyes", eyes(), 0.0006), ("body", body(), 0.0008), ("chain", chain(), 0.0004)]


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    n = len(P)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    N = c.N

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 else col
        c.rough[m] = rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def spk(m, col, amt):
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (int(m.sum()), 3)), np.full((int(m.sum()), 1), amt, F32)], 1)

    # the head: disguised.paint()'s pilot, line for line, read where each point sits on the pilot (Pd), so his mottling and glints fall the same
    Pd = (P - T).astype(F32)
    pc = D.PILOT_C
    m = c.mask(HSKIN)
    if m.any():
        mott = noise3(Pd, 0.05) * 0.5 + noise3(Pd, 0.012) * 0.25
        al = srgb(120, 204, 70) + (srgb(70, 150, 50) - srgb(120, 204, 70)) * smooth(pc[2] - 0.01, pc[2] + 0.06, Pd[:, 2])[:, None]
        put(m, al * (1.0 + 0.1 * mott)[:, None], 0.4, bump=0.2)
        spk(m, (60, 130, 40), 0.3)
    me = c.mask(EYE)
    if me.any():
        # (the glints as the pilot's, the same place and size, their edges crisp: 0.0036..0.0044 where the pilot's fade over 0.003..0.005)
        ae = np.broadcast_to(srgb(10, 10, 16), (n, 3)).copy()
        for s in (1.0, -1.0):
            gc = pc + v3((s * 0.018, -0.046, 0.012))
            ae = ae + (srgb(240, 240, 250) - ae) * smooth(0.0044, 0.0036, np.linalg.norm(Pd - gc, axis=1))[:, None]
        put(me, ae, 0.05)
    # crisp ink round each eye where it meets the skin
    if m.any() or me.any():
        skin_s, eyes_s = head_parts()
        de = eyes_s.eval(P)[0]
        c.draw(m & (de < 0.0025), np.abs(de), 0.0003, 0.95)
        ds = skin_s.eval(P)[0]
        c.draw(me & (ds < 0.0025), np.abs(ds), 0.0003, 0.95)

    # the body: the pilot's lime as it is at his jaw, darker down his back, paler on the potbelly, the pads of his fingers and his soles;
    # the same speckles as his head
    m = c.mask(SKIN)
    if m.any():
        # the arms swing in every clip: the occlusion they cast in the rest pose on his flanks and thighs would stay painted where they were,
        # so the trunk and legs take theirs from everything but the arms; the arms keep their own (blended across the shoulder)
        from kit.paint import occlusion
        ad, _ = _poly(Q, [SHOULDER, ELBOW, WRIST, in_world(KNUCK)])
        da = ad - 0.0055
        on_arm = smooth(-0.002, 0.002, trunk_core().eval(P)[0] - da) * (da < _poly(Q, [HIP, KNEE, ANKLE])[0] - 0.0085) * (Q[:, 0] > 0.018) * (z > 0.04)
        sel = m & (on_arm < 1.0)
        if sel.any():
            ao2 = occlusion(Union([head(), eyes(), body(arms=False), chain()]), P[sel], N[sel])
            c.ao[sel] = (c.ao[sel] * on_arm[sel] + ao2 * (1.0 - on_arm[sel])).astype(F32)
        mott = noise3(P, 0.05) * 0.5 + noise3(P, 0.012) * 0.25
        sk = np.broadcast_to(srgb(120, 204, 70), (n, 3)).copy()
        back = smooth(0.1, 0.85, N[:, 1])
        sk = sk + (srgb(88, 164, 52) - sk) * (back * 0.5)[:, None]
        bel = smooth(1.0, 0.3, np.sqrt((x / 0.021) ** 2 + ((z - 0.105) / 0.021) ** 2)) * smooth(-0.1, -0.6, N[:, 1])
        sk = sk + (srgb(168, 222, 110) - sk) * (bel * 0.5)[:, None]
        pads = np.zeros(n, F32)
        for sx in (1.0, -1.0):
            for nm, pts in DIGITS.items():
                tip = in_world(pts[-1][0] + PAD, sx)
                pads = np.maximum(pads, smooth(BULB[nm] + 0.0012, BULB[nm] - 0.0006, np.linalg.norm(P - tip, axis=1)))
        sole = smooth(0.0016, 0.0002, z) * (z < 0.004)
        sk = sk + (srgb(176, 226, 122) - sk) * (np.maximum(pads, sole) * 0.6)[:, None]
        put(m, sk * (1.0 + 0.1 * mott)[:, None], 0.42, bump=0.2)
        spk(m, (64, 136, 44), 0.18)
        nv = navel()
        r = np.sqrt(x ** 2 + (z - nv[2]) ** 2)
        c.draw(m & (y < nv[1] + 0.003) & (r < 0.004), np.abs(r - 0.0013), 0.00022, 0.55)

    # the chain: bright polished gold, darker in the crevices; inked where one link lies on the next
    m = c.mask(GOLD)
    if m.any():
        put(m, srgb(255, 206, 96) * (1.0 - 0.35 * c.cavity)[:, None], 0.2, metal=1.0, bump=0.04, grain=1.0)
        C, Fr = links()
        K = len(C)
        idx = np.nonzero(m)[0]
        rel = Q[idx][:, None, :] - C[None, :, :]
        loc = np.einsum("mki,kij->mkj", rel, Fr)
        rho = np.linalg.norm(loc / np.asarray(LINK, F32), axis=2)
        order = np.argsort(rho, axis=1)
        rows = np.arange(len(idx))
        i1, i2 = order[:, 0], order[:, 1]
        jd = (rho[rows, i2] - rho[rows, i1]) * 0.0017              # (about metres: the two links' fields part at ~2 / 3.4 mm)
        mid = (i1 == 0) | (i1 == K - 1)                  # the links either side of the middle front and back meet their mirrors at x = 0
        jd = np.where(mid, np.minimum(jd, np.abs(x[idx])), jd)
        J = np.ones(n, F32)
        J[idx] = jd
        c.draw(m, J, 0.0001, 0.6)
        # (no slot inked in the links: a dark line down each one made the chain a string of coffee beans)

    # light the room does not give: occlusion into the creases (the gold only a little: it lies on the skin, and dulled it went bronze)
    gm = c.mask(GOLD)
    c.col *= np.where(gm, 0.62 + 0.38 * c.ao, 0.32 + 0.68 * c.ao)[:, None]
    c.col *= (1.0 - np.where(gm, 0.15, 0.3) * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: rig and motion

WALK = dict(stride=0.11, stance=0.58, foot_x=0.0155, lift=0.0105, bob=0.0038, drop=0.0062, sway=0.003, roll=5.0, yaw=11.0, counter=1.7,
            lean=-3.0, toe_off=16.0, toe_out=10.0, swing_point=8.0)
RUN = dict(stride=0.17, stance=0.36, foot_x=0.0145, lift=0.023, bob=0.0045, drop=0.0085, sway=0.002, roll=4.0, yaw=7.0, counter=1.0,
           lean=17.0, toe_off=24.0, toe_out=3.0, swing_point=16.0, spine_lean=7.0)
BACK = 0.0135             # the hips moved back over the ankles (biped_walk centres the ball of the foot under them)

GAME = {
    "budget": {"head": 2700, "eyes": 500, "body": 5400, "chain": 900},
    "density": {"head": 1.8, "eyes": 1.8, "chain": 1.3},
    "tex": 2048,
    "stride": {"walk": WALK["stride"], "run": RUN["stride"]},
    "speed": 0.2,                       # (he is not in the crowd: about 0.24 m/s walking, were he)
    "look": ["head", "antenna.L", "antenna.R"], "neck": "neck",
    "look_pivot": tuple(float(v) for v in NECK_TOP),
    "radius": 0.06,
}


def rig_bones():
    from kit.rig import Bone, mirror
    bones = [
        Bone("root", (0, 0, 0), (0, 0.04, 0), None, 0.0),
        Bone("hips", (0, 0.005, 0.088), (0, 0.005, 0.1045), "root", 0.019),
        Bone("spine", (0, 0.005, 0.1045), (0, 0.004, 0.1245), "hips", 0.021),
        Bone("chest", (0, 0.004, 0.1245), (0, 0.006, 0.146), "spine", 0.017),
        Bone("neck", (0, 0.0072, 0.146), NECK_TOP, "chest", 0.009),
        Bone("head", NECK_TOP, (0, -0.002, 0.272), "neck", 0.04),
        Bone("antenna.L", ANT[0], ANT[1], "head", 0.0032),
        Bone("antenna_tip.L", ANT[1], ANT[2], "antenna.L", 0.003),
        Bone("shoulder.L", (0.006, 0.006, 0.147), SHOULDER, "chest", 0.0055),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.005),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.004),
        Bone("hand.L", WRIST, in_world(KNUCK), "forearm.L", 0.004),
    ]
    for nm, pts in DIGITS.items():
        bones.append(Bone(nm + ".L", in_world(pts[0][0]), in_world(pts[-1][0] + PAD), "hand.L", 0.002))
    bones += [
        Bone("thigh.L", HIP, KNEE, "hips", 0.008),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.0052),
        Bone("foot.L", ANKLE, TOE, "shin.L", 0.0045),
    ]
    return mirror(bones)


def _poly(P, pts):
    """distance from each point to a polyline, and the arc length along it of the nearest point (negative before its start, past the end after it)"""
    best_d = np.full(len(P), np.inf, F32)
    best_s = np.zeros(len(P), F32)
    s0 = 0.0
    last = len(pts) - 2
    for i in range(len(pts) - 1):
        a, b = v3(pts[i]), v3(pts[i + 1])
        ab = b - a
        L = float(np.linalg.norm(ab))
        t = ((P - a) @ ab) / (L * L)
        t = np.clip(t, -np.inf if i == 0 else 0.0, np.inf if i == last else 1.0)
        d = np.linalg.norm(P - a - np.outer(t, ab), axis=1)
        take = d < best_d
        best_d[take] = d[take]
        best_s[take] = (s0 + t * L)[take]
        s0 += L
    return best_d, best_s


def skin_rules(P, part, piece, names):
    """(the bones each vertex may take, a single bone for vertices that move rigidly). piece: 0 head, 1 eyes, 2 body, 3 chain.
    The kit's weights fall off over 12 mm, a third of his arm's length: so each joint gets a narrow zone where its two bones share, and between
    joints the limbs move rigidly (else his knees and elbows would bend like hoses)."""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    SIDES = (("L", x >= 0.0), ("R", x < 0.0))

    def only(m, *bn):
        A[m] = False
        rig[m] = -1
        for b in bn:
            A[m, ix[b]] = True

    def bind(m, b):
        A[m] = False
        A[m, ix[b]] = True
        rig[m] = ix[b]

    def dist(a, b):
        return float(np.linalg.norm(v3(b) - v3(a)))

    # the head and eyes move whole; each antenna bends from the skull and again at its kink
    hp = piece == 0
    bind(hp | (piece == 1), "head")
    ad, asl = _poly(Q, ANT + [ANT_BALL])
    a1 = dist(ANT[0], ANT[1])
    ant = hp & (z > ANT[0][2] - 0.004) & (asl > -0.002) & ((ad < 0.0048) | (np.linalg.norm(Q - ANT_BALL, axis=1) < 0.0088))
    for sd, S in SIDES:
        m = ant & S
        only(m & (asl < 0.0065), "head", "antenna." + sd)
        bind(m & (asl >= 0.0065) & (asl < a1 - 0.0045), "antenna." + sd)
        only(m & (np.abs(asl - a1) <= 0.0045), "antenna." + sd, "antenna_tip." + sd)
        bind(m & (asl > a1 + 0.0045), "antenna_tip." + sd)

    # the body: arms, legs, the trunk and neck
    bp = piece == 2
    td = trunk_core().eval(P)[0]
    L1, L2 = dist(SHOULDER, ELBOW), dist(ELBOW, WRIST)
    ad, asl = _poly(Q, [SHOULDER, ELBOW, WRIST, in_world(KNUCK)])
    M1, M2 = dist(HIP, KNEE), dist(KNEE, ANKLE)
    ld, lsl = _poly(Q, [HIP, KNEE, ANKLE])
    da, dl = ad - 0.0055, ld - 0.0085
    # (an arm must be nearer than the legs too: the outside of a knee is as far from the trunk as from the hand's line, and rode the hand)
    arms = bp & (Q[:, 0] > 0.018) & (z > 0.04) & (da < td) & (da < dl)
    legs = bp & ~arms & (z < 0.097) & ((dl < td) | (z < 0.074))
    torso = bp & ~arms & ~legs
    digit_d, digit_s, digit_k = np.full(n, np.inf, F32), np.zeros(n, F32), np.zeros(n, int)
    for k, (nm, pts) in enumerate(DIGITS.items()):
        fd, fs = _poly(Q, [in_world(p) for p, _ in pts] + [in_world(pts[-1][0] + PAD)])
        fd = fd - pts[0][1]
        take = fd < digit_d
        digit_d[take], digit_s[take], digit_k[take] = fd[take], fs[take], k
    for sd, S in SIDES:
        m = arms & S
        only(m & (asl < 0.0045), "chest", "shoulder." + sd, "upper_arm." + sd)
        bind(m & (asl >= 0.0045) & (asl < L1 - 0.0045), "upper_arm." + sd)
        only(m & (np.abs(asl - L1) <= 0.0045), "upper_arm." + sd, "forearm." + sd)
        bind(m & (asl > L1 + 0.0045) & (asl < L1 + L2 - 0.0035), "forearm." + sd)
        only(m & (np.abs(asl - (L1 + L2)) <= 0.0035), "forearm." + sd, "hand." + sd)
        hand_m = m & (asl > L1 + L2 + 0.0035)
        bind(hand_m, "hand." + sd)
        dig = hand_m & (digit_d < 0.0016) & (digit_s > -0.0008)
        for k, nm in enumerate(DIGITS):
            mk = dig & (digit_k == k)
            only(mk & (digit_s < 0.003), "hand." + sd, nm + "." + sd)
            bind(mk & (digit_s >= 0.003), nm + "." + sd)
        m = legs & S
        only(m & (lsl < 0.0065), "hips", "thigh." + sd)
        bind(m & (lsl >= 0.0065) & (lsl < M1 - 0.0048), "thigh." + sd)
        only(m & (np.abs(lsl - M1) <= 0.0048), "thigh." + sd, "shin." + sd)
        bind(m & (lsl > M1 + 0.0048) & (z > 0.017), "shin." + sd)
        foot_m = m & (z <= 0.017)
        fore = foot_m & ((z <= 0.0085) | (y <= ANKLE[1] - 0.0055))
        only(foot_m & ~fore, "shin." + sd, "foot." + sd)
        bind(fore, "foot." + sd)
    only(torso, "hips", "spine", "chest")
    neck = torso & (z > 0.146) & (np.sqrt(x ** 2 + (y - 0.0075) ** 2) < 0.0145)
    for sd, S in SIDES:
        sh = torso & S & ~neck & (Q[:, 0] > 0.013) & (z > 0.137)
        only(sh, "chest", "shoulder." + sd)
        A[sh & (Q[:, 0] > 0.021), ix["upper_arm." + sd]] = True
        lo = torso & S & (z < 0.088) & (Q[:, 0] > 0.011)
        A[lo, ix["thigh." + sd]] = True
    only(neck & (z < 0.158), "chest", "neck")
    bind(neck & (z >= 0.158) & (z < 0.17), "neck")
    only(neck & (z >= 0.17) & (z < 0.181), "neck", "head")
    bind(neck & (z >= 0.181), "head")

    # the chain lies on his chest
    bind(piece == 3, "chest")
    none = ~A.any(1)
    if none.any():
        print("sambo_pilot skin_rules: %d vertices had no bone, given the chest" % int(none.sum()), flush=True)
        bind(none, "chest")
    return A, rig


def motions(rig):
    """walk: a cocky little strut: chest out and chin up, a springy bounce in every step, the hips rolling and the shoulders rolling against them,
    the arms swinging loose and a little wide with the hands trailing, the antennae bobbing a beat behind. run: a frantic scurry: short quick
    steps leaning hard forward, both arms flailing over his head, the antennae streaming back. idle: an arrogant stand, weight on his right leg,
    right hand on his hip, chin up; he holds his left hand up to look his fingertips over and flicks them, taps his foot, looks about"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, solve, align, TAU, ease
    from mathutils import Vector, Matrix

    f = np.array([-1, 1, 1], F32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]
    SIDES = (("L", 1.0), ("R", -1.0))

    def V(a, sx=1.0):
        return Vector((float(a[0]) * sx, float(a[1]), float(a[2])))

    def ants(p, base, tip, lean=0.0, spread=0.0):
        """the antennae: base and tip pitch (degrees, + forward), a lean (+ toward his left) and a spread (+ apart)"""
        for sd, sx in SIDES:
            p.rot("antenna." + sd, base, sx * spread + lean, 0)
            p.rot("antenna_tip." + sd, tip, sx * spread * 0.5 + lean * 0.6, 0)

    def curl(p, sx, fingers, thumb=None):
        """close a hand: 0 the rest (relaxed), 1 a fist; about each digit's knuckle (the right hand mirrors the left)"""
        sd = "L" if sx > 0 else "R"
        thumb = fingers if thumb is None else thumb
        for nm, amt, ax, deg in (("finger1", fingers, HAND[:, 1], 85.0), ("finger2", fingers, HAND[:, 1], 90.0), ("thumb", thumb, HAND @ THUMB_FOLD, 55.0)):
            p.delta[nm + "." + sd] = Matrix.Rotation(math.radians(deg * amt * sx), 3, V(ax, sx).normalized())

    def wrist(p, sx, flex):
        """bend a wrist toward the palm (degrees; negative: back)"""
        sd = "L" if sx > 0 else "R"
        p.delta["hand." + sd] = Matrix.Rotation(math.radians(flex * sx), 3, V(HAND[:, 1], sx).normalized())

    # ------------------------------------------------------------------ walk: the strut
    def strut(u):
        p = Pose()
        biped_walk(rig, p, u, WALK, legs)
        p.offset = p.offset + Vector((0.0, BACK, 0.0))
        s, c = math.sin(TAU * u), math.cos(TAU * u)
        step = math.sin(2 * TAU * u - 0.9)                 # once a step
        p.rot("spine", -2.0, 0, 0)
        p.rot("chest", -7.0 - 1.5 * step, 0, 0)            # chest out
        for sd, sx in SIDES:
            fwd = max(0.0, -sx * c)                        # this arm swinging forward
            p.rot("shoulder." + sd, 0, 0, 6.0 * c)         # its shoulder rolling forward with it
            p.rot("upper_arm." + sd, sx * 15.0 * c, 0, 0)
            p.rot("upper_arm." + sd, 0, -sx * (11.0 + 3.0 * fwd), 0)
            p.rot("forearm." + sd, -(2.0 + 8.0 * fwd), 0, 0)       # (the forearm already leans 16 degrees forward at rest)
            wrist(p, sx, 14.0 - 16.0 * sx * s)             # the hands trailing, loose
            curl(p, sx, 0.25)
        p.rot("neck", -4.0, 0, 0)
        p.world["head"] = R(-10.0 + 3.5 * step, 3.0 * s, 4.0 * s)     # chin up, nodding to his own beat, swaying with the hips
        ants(p, 7.0 * math.sin(2 * TAU * u - 1.6), 10.0 * math.sin(2 * TAU * u - 2.5), lean=-3.0 * s, spread=2.0)
        return p

    # ------------------------------------------------------------------ run: the scurry
    def scurry(u):
        p = Pose()
        biped_walk(rig, p, u, RUN, legs)
        p.offset = p.offset + Vector((0.0, BACK * 0.7, 0.0))
        s = math.sin(TAU * u)
        p.rot("neck", -10.0, 0, 0)
        p.world["head"] = R(-6.0 + 4.0 * math.sin(2 * TAU * u - 0.5), 0.0, 4.0 * s)
        for sd, sx in SIDES:
            ph = TAU * u * 2.0 + (0.0 if sx > 0 else math.pi)      # flailing twice a stride, the arms in turn
            p.rot("upper_arm." + sd, -150.0 - 32.0 * math.sin(ph), 0, 0)
            p.rot("upper_arm." + sd, 0, -sx * (22.0 + 12.0 * math.cos(ph)), 0)
            p.rot("forearm." + sd, -(28.0 + 30.0 * math.sin(ph + 1.2)), 0, 0)
            wrist(p, sx, 25.0 * math.sin(ph + 2.2))
            curl(p, sx, 0.15 + 0.15 * math.sin(ph + 2.6))
        ants(p, -30.0 + 5.0 * math.sin(4 * TAU * u), -22.0 + 9.0 * math.sin(4 * TAU * u - 1.1), lean=-4.0 * s, spread=8.0)
        return p

    walk = [strut(i / 32.0) for i in range(33)]
    run = [scurry(i / 24.0) for i in range(25)]

    # ------------------------------------------------------------------ idle
    hip_wr = v3((-0.0305, 0.0105, 0.0968))         # the right wrist on his hip (rest space, riding the hips)
    look_wr = v3((0.0175, -0.05, 0.112))           # the left wrist out before his belly, palm up, to look his nails over (rest space, riding the chest:
                                                   # any higher and that head is in the way: up at his chin it read as stroking it)
    d0, b0 = V(-HAND[:, 2]), V(HAND[:, 0])         # the left hand at rest: where its fingers point, where its back faces
    rot_hip = align(V(-HAND[:, 2], -1.0), Vector((0.12, 0.8, -0.58)).normalized(), V(HAND[:, 0], -1.0), Vector((-1.0, 0.0, 0.15)).normalized())
    rot_look = align(d0, Vector((-0.2, -0.65, 0.73)).normalized(), b0, Vector((0.15, -0.6, -0.8)).normalized())
    heel = v3((ANKLE[0], 0.0105, 0.0))
    feet = {"L": (Vector((0.027, -0.0205, 0.0)), 21.0), "R": (Vector((-0.0175, -0.0105, 0.0)), -9.0)}
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        br = math.sin(TAU * t / 3.0)
        sw = math.sin(TAU * t / 6.0)
        insp = ease((t - 1.4) / 0.5) * (1.0 - ease((t - 3.2) / 0.5))
        fl = ease((t - 2.9) / 0.1) * (1.0 - ease((t - 3.2) / 0.3))
        stand(rig, p, legs, feet, hip_shift=(-0.0062 + 0.0004 * sw, 0.0012, -0.0021 + 0.0003 * br), roll=5.5, yaw=-7.0)
        # the foot tap: two slaps of the left toe, the heel kept down
        ph = (t - 4.1) / 0.36
        tap = math.sin(math.pi * (ph % 1.0)) ** 0.8 if 0.0 <= ph < 2.0 else 0.0
        if tap > 0.0:
            bp_, yaw_ = feet["L"]
            wf = R(0, 0, yaw_)
            hw = bp_ + wf @ (V(heel) - V(BALL))
            wft = wf @ R(-15.0 * tap, 0, 0)
            p.ik["thigh.L"] = (hw + wft @ (V(ANKLE) - V(heel)), Vector((0.15, -1.0, 0.0)), "foot.L", wft)
        p.rot("spine", -2.5, -2.0, 3.0)
        p.rot("chest", -4.5 + 0.9 * br, -2.5 - 1.5 * insp, 2.5 + 4.0 * insp)
        look = 12.0 * math.sin(TAU * t / 6.0 + 0.4) * (1.0 - insp) + 10.0 * insp
        p.rot("neck", -2.0 + 9.0 * insp, 0, 0.4 * look)
        p.world["head"] = R(-9.0 + 27.0 * insp, 5.0 - 3.0 * insp, look)
        A = solve(rig, p)
        Wh, Wc = A["hips"].to_3x3(), A["chest"].to_3x3()
        # right hand on his hip, the fingers gripping a little
        p.ik["upper_arm.R"] = (A["hips"] @ V(hip_wr), Vector((-0.8, 0.45, -0.1)), "hand.R", Wh @ rot_hip)
        curl(p, -1.0, 0.35, 0.1)
        # left hand: hanging loose; up to look the fingertips over (curled to see the backs of them), a flick, back down
        hang = A["chest"] @ V(WRIST + v3((0.0, -0.002, 0.0)))
        tgt = hang.lerp(A["chest"] @ V(look_wr), insp)
        q = Wc.to_quaternion().slerp((Wc @ rot_look).to_quaternion(), insp)
        p.ik["upper_arm.L"] = (tgt, Vector((0.5, 0.4, -0.6)), "hand.L", q.to_matrix())
        curl(p, 1.0, 0.15 + insp * (0.55 * (1.0 - fl) - 0.3 * fl), 0.1 + 0.3 * insp)
        tw = tap
        ants(p, 2.5 * math.sin(TAU * t / 3.0 + 0.3) + 6.0 * insp, 4.0 * math.sin(TAU * t / 3.0 - 0.5) + 8.0 * tw + 5.0 * insp, lean=1.5 * sw, spread=1.0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
