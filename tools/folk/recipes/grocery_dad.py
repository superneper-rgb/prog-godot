## FOINT CITY townsfolk: the grocery dad (working name; the user names him). A big burly pink fellow with a small head sunk in his shoulders: bushy grey crop, thick black glasses, a long drooping nose, stubble; green striped polo, khaki pleats, belt, watch, boots.
# Concept: the user's sheet, image 1 bottom (F:/prog-godot-cache/folk/refs/1.png). Measured off a 3x crop (1.68 mm a pixel): 1.90 m to the top of his hair; the head only 0.31 tall
# (chin 1.57, glasses 1.73, nose tip hanging to 1.63) sits straight in his trapezius; shoulders 1.47 and 0.9 wide across the sleeves; a barrel belly over the belt at 1.06;
# wide pleated trousers turned up at 0.12; work boots. The grocery bags are dropped (roster): his big hairy hands hang loose. The arms are their own piece.
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, ridge_line, noise3, v3, basis, place)

HEIGHT = 1.90
REF = ("1.png", (31, 380, 319, 765))

SKIN, EYE, BROW, HAIR, LIP, GLASSES, POLO, UNDER, BUTTON, BELT, GOLD, TROUSERS, BOOT, SOLE, LACE, STRAP, DIAL, NAIL, PEN, PENCAP = range(1, 21)
COLOURS = {
    SKIN: ((0.70, 0.36, 0.30), 0.55, 0.0),
    EYE: ((0.85, 0.80, 0.72), 0.2, 0.0),
    BROW: ((0.03, 0.025, 0.025), 0.7, 0.0),
    HAIR: ((0.14, 0.13, 0.13), 0.7, 0.0),
    LIP: ((0.55, 0.22, 0.20), 0.45, 0.0),
    GLASSES: ((0.02, 0.02, 0.02), 0.2, 0.0),
    POLO: ((0.16, 0.24, 0.14), 0.85, 0.0),
    UNDER: ((0.80, 0.78, 0.72), 0.8, 0.0),
    BUTTON: ((0.65, 0.52, 0.30), 0.4, 0.0),
    BELT: ((0.18, 0.08, 0.04), 0.5, 0.0),
    GOLD: ((0.95, 0.68, 0.25), 0.3, 1.0),
    TROUSERS: ((0.50, 0.42, 0.30), 0.85, 0.0),
    BOOT: ((0.20, 0.10, 0.05), 0.5, 0.0),
    SOLE: ((0.08, 0.06, 0.05), 0.7, 0.0),
    LACE: ((0.55, 0.40, 0.20), 0.7, 0.0),
    STRAP: ((0.20, 0.10, 0.05), 0.5, 0.0),
    DIAL: ((0.05, 0.05, 0.06), 0.2, 0.0),
    NAIL: ((0.75, 0.50, 0.45), 0.3, 0.0),
    PEN: ((0.25, 0.25, 0.45), 0.3, 0.0),
    PENCAP: ((0.85, 0.65, 0.20), 0.3, 1.0),
}


def _unit(a):
    a = v3(a)
    return a / np.linalg.norm(a)


def bounded(s, lo, hi):
    """narrow a shape's bound (a clipped garment layer is far smaller than the body it was grown from): unions then skip it everywhere else"""
    s.lo, s.hi = v3(lo), v3(hi)
    return s


def _surface_y(shape, x, z, y0=-0.6, y1=0.3):
    """where the shape's front surface is at (x, z), marching back from the front"""
    ys = np.linspace(y0, y1, 1800, dtype=np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    d = shape.eval(P)[0]
    return float(ys[int(np.argmax(d < 0))])


def prism(poly_xz, y0=-0.7, y1=0.0):
    """a front-view outline (x, z) pushed through the figure from the front (y0) to y1"""
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


class Eye:
    """an eye: centre, radii (across, up, deep), where it looks, the lid edges' heights at the front of the ball (fractions of the up radius)"""
    def __init__(self, c, rad, fwd, roll=0.0, lid_up=0.3, lid_lo=0.5, arch=22.0, rim=0.006):
        self.c, self.rad = v3(c), v3(rad)
        self.f = _unit(fwd)
        u = v3((0, 0, 1)) - self.f * self.f[2]
        u /= np.linalg.norm(u)
        s = np.cross(self.f, u)
        a = np.radians(roll)
        self.u = (u * np.cos(a) + s * np.sin(a)).astype(np.float32)
        self.s = np.cross(self.u, self.f).astype(np.float32)
        self.M = np.stack([self.s, self.u, self.f], 1).astype(np.float32)
        self.lid_up, self.lid_lo, self.arch, self.rim = lid_up, lid_lo, np.radians(arch), rim

    def mound(self):
        rs, ru, rf = self.rad
        return Ellipsoid(self.c - self.f * 0.003, (rs + self.rim * 1.3, ru + self.rim, rf + self.rim * 0.8), R=self.M, part=SKIN)

    def opening(self):
        c, f, u, a = self.c, self.f, self.u, self.arch
        rs, ru, rf = self.rad
        nu = u * np.cos(a) - f * np.sin(a)
        nl = -u * np.cos(a) - f * np.sin(a)
        front = c + f * rf
        return Clip(Sphere(c + f * rf * 0.6, rs * 1.6), [Half(front + u * self.lid_up * ru, nu), Half(front - u * self.lid_lo * ru, nl), Half(c + f * 0.1 * rf, -f)])

    def ball(self):
        return Ellipsoid(self.c, self.rad, R=self.M, part=EYE)

    def local(self, P):
        return ((P - self.c) @ self.M) / self.rad


# ---------------------------------------------------------------------------------------------------- the head: small, long-jawed, sunk into his shoulders
EYE_L = Eye((0.038, -0.084, 1.736), (0.021, 0.018, 0.016), (0.10, -0.99, 0.0), roll=-5.0, lid_up=0.28, lid_lo=0.55, arch=14.0)
LENS_C = v3((0.043, -0.112, 1.732))          # the middle of his left lens
NOSE_TIP = v3((0.0, -0.155, 1.654))
MOUTH = v3((0.0, 0.0, 1.604))                 # a pleased closed smile under the nose bulb, the corners rising into his cheeks
# the head is modelled at these sizes and then set 20% bigger, sunk 4 cm into his shoulders (lead review, round 2: a big friendly head, as the concept)
HEAD_S = 1.2
HEAD_PV = v3((0.0, 0.0, 1.66))
HEAD_T = v3((0.0, 0.01, -0.04))


def big(s):
    return Move(s, R=np.eye(3, dtype=np.float32) / HEAD_S, pivot=HEAD_PV, t=HEAD_T)


def unbig(P):
    """world points back into the frame the head was modelled in"""
    return ((P - HEAD_PV - HEAD_T) / HEAD_S + HEAD_PV).astype(np.float32)
SKULL = Ellipsoid((0, 0.012, 1.762), (0.099, 0.105, 0.108))


def skull():
    return Union([
        SKULL,
        Ellipsoid((0, -0.022, 1.70), (0.11, 0.09, 0.088)),                  # a broad round face
        Mirror(Ellipsoid((0.062, -0.06, 1.655), (0.056, 0.05, 0.05))),      # fleshy cheeks under the glasses
        Mirror(Ellipsoid((0.058, -0.03, 1.632), (0.066, 0.072, 0.068))),   # heavy jowls
        Ellipsoid((0, -0.07, 1.578), (0.052, 0.04, 0.034)),                 # the chin
        Ellipsoid((0, -0.045, 1.553), (0.085, 0.06, 0.04)),                 # the double chin under it
        Ellipsoid((0, -0.012, 1.575), (0.10, 0.09, 0.06)),                  # down into the neck
        Mirror(Ellipsoid((0.045, -0.078, 1.781), (0.04, 0.02, 0.014))),     # a heavy brow
    ], k=0.035, part=SKIN)


def head():
    sk = skull()
    face = Union([sk, Mirror(EYE_L.mound()), Mirror(Ellipsoid(EYE_L.c + v3((0.002, -0.004, -0.022)), (0.022, 0.012, 0.009), part=SKIN))], k=0.012)   # lids and the bags under them
    face = Cut(face, [Mirror(EYE_L.opening())], k=0.003)
    # the nose: a long drooping trunk from between the eyes to a heavy bulb hanging over the mouth, wings either side, nostrils underneath
    nose = Union([
        loft([(v3((0, -0.088, 1.752)), 0.012), (v3((0, -0.11, 1.722)), 0.0145), (v3((0, -0.132, 1.69)), 0.018), (v3((0, -0.148, 1.662)), 0.024)], part=SKIN, k=0.01),
        Ellipsoid(NOSE_TIP, (0.03, 0.027, 0.027), part=SKIN),
        Mirror(Ellipsoid((0.022, -0.125, 1.652), (0.014, 0.017, 0.015), part=SKIN)),
    ], k=0.008)
    face = Union([face, nose], k=0.008)
    face = Cut(face, [Mirror(Ellipsoid((0.011, -0.144, 1.634), (0.0065, 0.01, 0.0055), R=rot(rx=-20)))], k=0.003)
    # ears
    ear = Cut(Ellipsoid((0.097, 0.015, 1.722), (0.014, 0.024, 0.034), R=rot(rz=-18), part=SKIN),
              [Ellipsoid((0.106, 0.01, 1.724), (0.007, 0.015, 0.022), R=rot(rz=-18))], k=0.003)
    face = Union([face, Mirror(ear)], k=0.008)
    # a pleased closed smile under the nose: thin lips, no gap between them (the line is inked), the corners rising into soft creases
    up, lo = [], []
    for t in np.linspace(-1.0, 1.0, 21):
        x = 0.06 * t
        z = MOUTH[2] + 0.022 * t * t
        y = _surface_y(sk, x, z)
        up.append((v3((x, y + 0.0025, z + 0.003)), 0.003 * (1.0 - 0.4 * t * t) + 0.0017))
        if abs(t) <= 0.85:
            lo.append((v3((x, y + 0.0025, z - 0.0045)), 0.0048 * (1.0 - 0.7 * t * t) + 0.0018))
    face = Union([face, loft(up, part=LIP, k=0.008), loft(lo, part=LIP, k=0.008)], k=0.005)
    for t, dz in ((-1.0, 0.018), (1.0, 0.018)):           # the smile creases: short soft grooves up from each corner toward the nose
        x0 = 0.06 * t
        z0 = MOUTH[2] + 0.022
        a = v3((x0, _surface_y(sk, x0, z0) - 0.002, z0))
        b = v3((x0 * 0.72, _surface_y(sk, x0 * 0.72, z0 + dz) - 0.002, z0 + dz))
        face = Cut(face, [RoundCone(a, b, 0.0025, 0.002)], k=0.004)
    # brows: thick black bars, his left one cocked up
    brows = []
    for sx, lift in ((1.0, 0.004), (-1.0, -0.002)):
        pts = []
        for t in np.linspace(0.0, 1.0, 7):
            x = sx * (0.012 + 0.062 * t)
            z = 1.786 + lift + 0.008 * np.sin(np.pi * min(1.0, t * 1.15)) - 0.006 * t
            pts.append((v3((x, _surface_y(sk, x, z) + 0.002, z)), 0.0062 - 0.0022 * t))
        brows.append(loft(pts, part=BROW, k=0.004))
    neck = RoundCone((0, 0.03, 1.42), (0, 0.0, 1.61), 0.135, 0.098, part=SKIN)
    return big(Union([Union([neck, face], k=0.04), Mirror(EYE_L.ball())] + brows, k=0.0))


HAIR_ZONE = [Half((0, -0.068, 1.80), (0.0, -0.8, -0.6)), Half((0, 0, 1.69), (0, 0.4, -1.0))]


def hair():
    cap = Clip(Inflate(SKULL, 0.02, part=HAIR), HAIR_ZONE, k=0.01)
    # a short crop: fine spiky grain combed up and back, the top standing up a little, flat at the sides
    def grain(P):          # plain noise: grooves round an axis pinch to a point on the crown, finer than the voxels, and break the mesh
        return 0.6 * noise3(P, 0.009) + 0.4 * noise3(P, 0.006)
    cap = Bump(cap, grain, 0.0016)
    # real volume on top, swept from a side part over his right eye across to his left
    tuft = Clip(Ellipsoid((0.012, -0.012, 1.86), (0.085, 0.095, 0.042), part=HAIR), HAIR_ZONE, k=0.01)
    tuft = Bump(tuft, grain, 0.002)
    hair = Union([cap, tuft], k=0.02)
    part_line = ridge_line((-0.04, -0.075, 1.85), (-0.045, 0.06, 1.875), 0.005)
    return big(Bump(hair, part_line, -0.005))


def glasses():
    """thick black frames: two rounded rectangles, a bridge over the nose, arms back to the ears"""
    parts = []
    for sx in (1.0, -1.0):
        c = LENS_C * np.array([sx, 1, 1], np.float32)
        Rm = rot(rz=9.0 * sx)                  # the frames wrap back round his face
        rimo = Box(c, (0.038, 0.0045, 0.027), rr=0.01, R=Rm)          # thick black frames
        rimi = Box(c, (0.026, 0.02, 0.0155), rr=0.005, R=Rm)
        parts.append(Cut(rimo, [rimi], k=0.001))
        hinge = c + Rm @ v3((0.036 * sx, 0.004, 0.012))
        ear = v3((0.103 * sx, 0.0, 1.728))
        parts.append(RoundCone(hinge, ear, 0.0038, 0.003))
    parts.append(loft([(LENS_C * np.array([-1, 1, 1], np.float32) + v3((0.033, 0.0, 0.007)), 0.004), (v3((0.0, -0.121, 1.745)), 0.0042),
                       (LENS_C + v3((-0.033, 0.0, 0.007)), 0.004)]))
    return big(Union(parts, k=0.002, part=GLASSES))


# ---------------------------------------------------------------------------------------------------- body: polo, belt, trousers, boots

WAIST = Ellipsoid((0, -0.01, 1.07), (0.33, 0.25, 0.10))


def torso_core():
    return Union([
        Ellipsoid((0, 0.025, 1.32), (0.335, 0.215, 0.18)),                 # a broad barrel chest
        Ellipsoid((0, 0.04, 1.43), (0.37, 0.175, 0.075)),                  # big shoulders
        Mirror(RoundCone((0.06, 0.045, 1.60), (0.28, 0.035, 1.46), 0.085, 0.09)),   # the trapezius sloping up to his ears: no neck to speak of
        Ellipsoid((0, -0.035, 1.17), (0.35, 0.26, 0.165)),                 # the belly
        WAIST,
    ], k=0.08, part=POLO)


def polo():
    core = torso_core()
    shell = Clip(Inflate(core, 0.006, part=POLO), [Half((0, 0, 1.05), (0, 0, -1))], k=0.006)
    # the open neck: a V down the placket showing the white undershirt
    vee = prism([(-0.035, 1.62), (0.035, 1.62), (0.02, 1.48), (0.0, 1.455), (-0.02, 1.48)])
    shell = Cut(shell, [vee], k=0.004)
    under = bounded(Clip(Inflate(core, 0.002, part=UNDER), [prism([(-0.05, 1.62), (0.05, 1.62), (0.03, 1.46), (-0.03, 1.46)])], k=0.003), (-0.08, -0.4, 1.4), (0.08, 0.1, 1.65))
    # the collar: flat points lying on his chest round the neck, and its band round the back of the neck
    collar = bounded(Clip(Inflate(core, 0.019, part=POLO),
                          [Mirror(prism([(0.012, 1.55), (0.07, 1.585), (0.14, 1.57), (0.125, 1.52), (0.05, 1.45), (0.02, 1.475)], y1=0.15))], k=0.004),
                     (-0.2, -0.35, 1.4), (0.2, 0.2, 1.62))
    band = bounded(Clip(Inflate(RoundCone((0, 0.03, 1.42), (0, 0.0, 1.61), 0.135, 0.098), 0.012, part=POLO),
                        [Half((0, 0, 1.575), (0, -0.25, 1.0)), Half((0, 0, 1.48), (0, 0, -1)), Half((0, -0.06, 0), (0, -1, 0))], k=0.004),
                   (-0.2, -0.1, 1.4), (0.2, 0.2, 1.62))
    placket = bounded(Clip(Inflate(core, 0.011, part=POLO), [prism([(-0.024, 1.475), (0.024, 1.475), (0.024, 1.36), (-0.024, 1.36)])], k=0.003), (-0.05, -0.4, 1.33), (0.05, 0.0, 1.5))
    buttons = [Ellipsoid((0.0, _surface_y(core, 0.0, zb) - 0.016, zb), (0.0075, 0.004, 0.0075), part=BUTTON) for zb in (1.45, 1.415, 1.38)]
    # the chest pocket on his left, pens clipped in it
    pk = prism([(0.10, 1.37), (0.20, 1.37), (0.20, 1.27), (0.185, 1.255), (0.115, 1.255), (0.10, 1.27)])
    pocket = bounded(Cut(Clip(Inflate(core, 0.016, part=POLO), [pk], k=0.003), [Cut(prism([(0.105, 1.38), (0.195, 1.38), (0.195, 1.362), (0.105, 1.362)]), [Inflate(core, 0.009)])], k=0.002),
                     (0.08, -0.4, 1.23), (0.22, 0.0, 1.4))
    pens = []
    for x, h, cap in ((0.125, 0.045, PENCAP), (0.145, 0.052, PEN), (0.165, 0.04, PENCAP)):
        y = _surface_y(core, x, 1.33) - 0.012
        pens.append(RoundCone((x, y, 1.33), (x, y - 0.003, 1.33 + h), 0.0055, 0.005, part=PEN))
        pens.append(Box((x, y - 0.007, 1.36 + h * 0.3), (0.0018, 0.002, 0.014), rr=0.0012, part=GOLD))
        pens.append(Sphere((x, y - 0.003, 1.33 + h), 0.0058, part=cap))
    return Union([shell, under, collar, band, placket, pocket] + buttons + pens, k=0.0)


def belt():
    b = bounded(Clip(Inflate(WAIST, 0.016, part=BELT), [Half((0, 0, 1.092), (0, 0, 1)), Half((0, 0, 1.045), (0, 0, -1))], k=0.003), (-0.4, -0.32, 1.0), (0.4, 0.32, 1.12))
    y = _surface_y(WAIST, 0.0, 1.068) - 0.016
    buckle = Cut(Box((0, y - 0.004, 1.068), (0.036, 0.006, 0.027), rr=0.004, part=GOLD), [Box((0.004, y - 0.004, 1.068), (0.022, 0.02, 0.016), rr=0.002)], k=0.001)
    tongue = Box((-0.012, y - 0.002, 1.068), (0.004, 0.003, 0.016), rr=0.0015, part=GOLD)
    loops = []
    for x in (-0.20, -0.09, 0.09, 0.20):
        yl = _surface_y(WAIST, x, 1.068) - 0.018
        loops.append(Box((x, yl, 1.068), (0.008, 0.004, 0.032), rr=0.003, R=rot(rz=np.degrees(np.arctan2(x, 0.3)) * 0.8), part=TROUSERS))
    return Union([b, buckle, tongue] + loops, k=0.0)


HIP_J = v3((0.152, 0.025, 0.93))
KNEE = v3((0.168, -0.01, 0.51))
ANKLE = v3((0.168, 0.035, 0.105))
TOE = v3((0.173, -0.165, 0.03))


def trousers():
    seat = Ellipsoid((0, 0.03, 0.97), (0.315, 0.23, 0.14))
    # the legs clear of each other below the seat: touching legs bake their insides dark, and that shows once they stride apart
    leg = loft([(v3((0.16, 0.015, 0.94)), 0.155), (v3((0.17, -0.005, 0.52)), 0.12), (v3((0.172, 0.012, 0.17)), 0.11)], k=0.05)
    tr = Union([seat, Mirror(leg), WAIST], k=0.07, part=TROUSERS)
    # pleats down from the waistband, a pressed crease down each leg, soft breaks at the knees and the ankles
    pl = [ridge_line((x, -0.27, 1.04), (x * 0.98, -0.24, 0.84), 0.01) for x in (0.06, 0.115)]
    cr = ridge_line((0.165, -0.14, 0.84), (0.172, -0.12, 0.17), 0.012)

    def detail(P):
        Q = P.copy()
        Q[:, 0] = np.abs(Q[:, 0])
        n = noise3(Q, 0.06)
        return (pl[0](Q) + pl[1](Q)) * 1.2 + cr(Q) * 0.8 + n * 0.5 * np.clip((0.7 - Q[:, 2]) / 0.4, 0, 1)
    tr = Bump(tr, detail, 0.004)
    tr = Clip(tr, [Half((0, 0, 1.06), (0, 0, 1)), Half((0, 0, 0.115), (0, 0, -1))], k=0.003)
    cuff = Mirror(Clip(Inflate(loft([(v3((0.172, 0.012, 0.20)), 0.11), (v3((0.172, 0.014, 0.10)), 0.111)]), 0.008, part=TROUSERS),
                       [Half((0, 0, 0.158), (0, 0, 1)), Half((0, 0, 0.112), (0, 0, -1))], k=0.003))
    return Union([tr, cuff], k=0.0)


def boots():
    foot = loft([(v3((0.17, 0.07, 0.058)), 0.056), (v3((0.172, -0.04, 0.053)), 0.064), (v3((0.176, -0.15, 0.047)), 0.054)], k=0.03)       # chunky work boots
    shaft = RoundCone((0.17, 0.035, 0.07), (0.17, 0.035, 0.17), 0.066, 0.062)
    boot = Union([foot, shaft], k=0.03, part=BOOT)
    boot = Clip(boot, [Half((0, 0, 0.026), (0, 0, -1))], k=0.003)
    sole = Clip(Inflate(foot, 0.009, part=SOLE), [Half((0, 0, 0.032), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.003)
    welt = Clip(Inflate(foot, 0.006, part=SOLE), [Half((0, 0, 0.042), (0, 0, 1)), Half((0, 0, 0.03), (0, 0, -1))], k=0.002)
    laces = []
    for i, yy in enumerate((-0.05, -0.025, 0.0)):
        zz = 0.117 + 0.011 * i
        laces.append(Box((0.172, yy - 0.02, zz), (0.022, 0.0055, 0.0045), rr=0.002, R=rot(rx=35), part=LACE))
    toecap = Clip(Inflate(foot, 0.003, part=BOOT), [Half((0, -0.09, 0), (0, 1, 0)), Half((0, 0, 0.026), (0, 0, -1))], k=0.004)
    return Mirror(Union([boot, sole, welt, toecap] + laces, k=0.0))


# ---------------------------------------------------------------------------------------------------- arms (their own piece)
SHOULDER = v3((0.345, 0.035, 1.40))
ELBOW = v3((0.465, 0.07, 1.075))
WRIST = v3((0.49, 0.0, 0.835))
HAND = basis(-(WRIST - ELBOW), v3((0.25, 1.0, 0.0)))


def hand_loose():
    """a big loose half-fist in hand space (wrist at the origin, fingers along -Z, back of the hand +X, thumb -Y)"""
    palm = Ellipsoid((0.0, 0.0, -0.057), (0.03, 0.055, 0.062), part=SKIN)
    wrist = RoundCone((0, 0, 0.03), (0, 0, -0.02), 0.056, 0.048, part=SKIN)
    parts = [palm, wrist]
    for f, L in ((-0.037, 0.85), (-0.0125, 1.0), (0.0125, 0.97), (0.037, 0.82)):
        pts = [((0.0, f, -0.104), 0.0158), ((-0.013, f, -0.104 - 0.036 * L), 0.015), ((-0.036, f, -0.104 - 0.053 * L), 0.014), ((-0.055, f, -0.104 - 0.044 * L), 0.0128)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.005))
        parts.append(Ellipsoid(v3(pts[-1][0]) + v3((-0.002, 0, 0.006)), (0.008, 0.0095, 0.007), part=NAIL))
    parts.append(loft([(v3((-0.01, -0.04, -0.03)), 0.018), (v3((-0.03, -0.058, -0.068)), 0.0155), (v3((-0.046, -0.05, -0.096)), 0.0135)], part=SKIN, k=0.005))
    return Union(parts, k=0.011)


def arm(watch):
    mid = SHOULDER + (ELBOW - SHOULDER) * 0.45
    d = _unit(ELBOW - SHOULDER)
    end = SHOULDER + (ELBOW - SHOULDER) * 0.62
    sleeve = Clip(loft([(SHOULDER + v3((-0.03, 0, 0.03)), 0.118), (mid, 0.118), (end + d * 0.03, 0.11)], part=POLO, k=0.03), [Half(end, d)], k=0.004)
    cuffband = Clip(Inflate(loft([(mid, 0.116), (end + d * 0.03, 0.11)]), 0.004, part=POLO), [Half(end, d), Half(end - d * 0.03, -d)], k=0.003)
    upper = RoundCone(SHOULDER + d * 0.07, ELBOW, 0.09, 0.082, part=SKIN)      # starting inside the sleeve: from the shoulder it poked through it
    fore = loft([(ELBOW, 0.08), (ELBOW + (WRIST - ELBOW) * 0.3, 0.088), (WRIST, 0.058)], part=SKIN, k=0.03)          # Popeye forearms
    parts = [Union([upper, fore], k=0.03, part=SKIN), sleeve, cuffband, place(hand_loose(), WRIST, HAND)]
    if watch:
        dw = _unit(WRIST - ELBOW)
        at = WRIST - dw * 0.03
        Rm = basis(dw, v3((0, 1, 0)))
        parts.append(Torus(at, 0.058, 0.0078, Rm=Rm, part=STRAP))
        out = HAND[:, 0]
        parts.append(CappedCone(at + out * 0.054, at + out * 0.068, 0.021, 0.02, rr=0.003, part=GOLD))
        parts.append(CappedCone(at + out * 0.066, at + out * 0.0695, 0.017, 0.017, rr=0.0008, part=DIAL))
    return Union(parts, k=0.008)


def pieces():
    body = Union([polo(), belt(), trousers(), boots()], k=0.0)
    arms = Union([arm(True), Move(arm(False), R=np.diag([-1, 1, 1]).astype(np.float32))])
    return [("head", head(), 0.0018), ("hair", hair(), 0.0022), ("glasses", glasses(), 0.0013), ("body", body, 0.0038), ("arms", arms, 0.0032)]


# ---------------------------------------------------------------------------------------------------- paint (kit/paint.py fills the shader's layers from these)

def paint(c):
    from kit.paint import srgb, smooth
    P, N = c.P, c.N
    n = len(P)
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    H = unbig(P)                                    # head features are placed in the frame the head was modelled in
    HQ = H.copy()
    HQ[:, 0] = np.abs(HQ[:, 0])
    hx, hy, hz = H[:, 0], H[:, 1], H[:, 2]
    head_zone = (np.abs(x) < 0.25) & (z > 1.42)
    mott = noise3(P, 0.035) * 0.5 + noise3(P, 0.011) * 0.25
    u1 = (x + z) / 0.06
    u2 = (x - z) / 0.06
    diamond = np.minimum(0.5 - np.abs(u1 - np.floor(u1) - 0.5), 0.5 - np.abs(u2 - np.floor(u2) - 0.5))   # the sheet's faint diamond weave on every cloth

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 else col
        c.rough[m] = rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def speck(m, col, amt):
        amt = np.broadcast_to(np.asarray(amt, np.float32), (n,))
        c.spk[m] = np.concatenate([np.broadcast_to(col, (int(m.sum()), 3)), amt[m][:, None]], 1)

    # skin: warm pink, ruddy on the nose, cheeks and ears, a sheen on the brow; stubble on the jaw and neck, dark hair on his arms
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(240, 170, 146), (n, 3)).copy()
    ruddy = smooth(0.045, 0.0, np.linalg.norm(H - NOSE_TIP, axis=1) - 0.02)
    ruddy = np.maximum(ruddy, smooth(1.0, 0.3, np.linalg.norm((HQ - v3((0.07, -0.07, 1.67))) / v3((0.035, 0.04, 0.03)), axis=1)) * 0.6)
    ruddy = np.maximum(ruddy, ((HQ[:, 0] > 0.085) & (np.abs(hz - 1.722) < 0.04) & (np.abs(hy - 0.015) < 0.03)) * 0.6)
    sk = sk + (srgb(214, 106, 96) - sk) * (ruddy * head_zone)[:, None]
    sk = sk + (srgb(236, 172, 150) - sk) * (smooth(1.76, 1.83, hz) * 0.6 * head_zone)[:, None]
    sk *= (1.0 + 0.06 * mott)[:, None]
    # stubble: a light grey shadow on the chin and jaw only (lead review: the first pass read as a dark smear down his jaw)
    stub = head_zone & (hz > 1.535) & (hz < 1.598) & (hy < -0.02) & (np.abs(hx) < 0.095)
    sk = np.where(stub[:, None], sk * np.array([0.94, 0.91, 0.92], np.float32), sk)
    put(m, sk, 0.5, bump=0.12)
    arms = m & (z < 1.45) & (Q[:, 0] > 0.33)
    speck(m, srgb(120, 100, 98), np.where(stub, 0.4, np.where(arms, 0.85, 0.06)))
    # the eyes: small, heavy-lidded, glancing to his left; inked liner on the upper lid
    for sx in (1.0, -1.0):
        PP = H * np.array([sx, 1, 1], np.float32)
        q = EYE_L.local(PP)
        rq = np.linalg.norm(q, axis=1)
        dball = (rq - 1.0) * float(EYE_L.rad[1])
        rim = m & (rq < 2.2) & (q[:, 2] > -0.2) & (PP[:, 0] > 0)
        c.draw(rim & (q[:, 1] > -0.3) & (dball < 0.004), np.abs(dball), 0.0011, 1.0)
        c.draw(rim & (q[:, 1] < -0.3) & (dball < 0.003), np.abs(dball), 0.0006, 0.4)
    m = c.mask(EYE)
    ew = np.broadcast_to(srgb(236, 228, 214), (n, 3)).copy()
    for sx in (1.0, -1.0):
        PP = H * np.array([sx, 1, 1], np.float32)
        q = EYE_L.local(PP)
        qn = q / np.maximum(np.linalg.norm(q, axis=1), 1e-6)[:, None]
        mine = m & (PP[:, 0] > 0)
        g = _unit((0.42 * sx, 0.05, 0.9))                 # both look to his left: outward for the left eye, inward for the right
        ang = np.arccos(np.clip(qn @ g, -1, 1))
        col = np.where((ang < 0.5)[:, None], srgb(92, 62, 40), ew)
        col *= (1.0 - 0.4 * smooth(-0.1, 0.7, qn[:, 1]))[:, None]
        gl = smooth(0.16, 0.08, np.linalg.norm(qn - _unit((-0.3, 0.5, 0.8)), axis=1))
        col = col + (srgb(255, 252, 240) - col) * gl[:, None]
        c.col[mine] = col[mine]
        c.draw(mine, (ang - 0.24) * 0.02, 0.0)
    c.rough[m] = 0.08
    # brows and hair: near-black brows; the crop dark grey on top going silver at the temples and over the ears
    m = c.mask(BROW)
    put(m, srgb(30, 26, 26) * (1.0 + 0.4 * c.wear)[:, None], 0.7, bump=0.8)
    m = c.mask(HAIR)
    hr = srgb(104, 100, 98) + (srgb(176, 174, 172) - srgb(104, 100, 98)) * (smooth(1.83, 1.77, hz) * smooth(0.04, 0.075, HQ[:, 0]))[:, None]
    hr = hr * (1.0 + 0.5 * c.wear - 0.4 * c.cavity)[:, None]
    put(m, hr, 0.7, bump=1.0)
    speck(m, srgb(176, 174, 170), 0.25)
    # lips, the parting inked
    m = c.mask(LIP)
    put(m, srgb(190, 106, 96) * (1.0 + 0.1 * mott)[:, None], 0.4)
    zc = MOUTH[2] + 0.022 * (hx / 0.06) ** 2
    c.draw(c.mask(LIP, SKIN) & head_zone & (np.abs(hx) < 0.064) & (np.abs(hz - zc) < 0.008) & (hy < -0.07), np.abs(hz - zc), 0.0008)
    put(c.mask(GLASSES), srgb(14, 13, 15) * (1.0 + 2.0 * c.wear)[:, None], 0.14)
    # the polo: sage green pique with thin tan stripes, the collar tipped in tan
    m = c.mask(POLO)
    st = (z - 1.0) / 0.105
    fr = st - np.floor(st)
    stripe = (np.abs(fr - 0.5) < 0.06).astype(np.float32)
    thin = (np.abs(fr - 0.66) < 0.012).astype(np.float32)
    pl = np.broadcast_to(srgb(100, 130, 92), (n, 3)) * (1.0 + 0.06 * mott - 0.08 * smooth(0.06, 0.0, diamond))[:, None]
    pl = pl + (srgb(198, 170, 112) - pl) * stripe[:, None]
    pl = pl + (srgb(198, 170, 112) - pl) * (thin * 0.6)[:, None]
    collar = (z > 1.455) & (z < 1.6) & (np.abs(x) < 0.17) & (y < 0.06)
    pl = np.where(collar[:, None], np.broadcast_to(srgb(100, 130, 92), (n, 3)) * (1.0 + 0.06 * mott)[:, None], pl)    # the collar plain green
    tip = collar & (c.wear > 0.75)
    pl = np.where(tip[:, None], srgb(198, 170, 112), pl)
    put(m, pl * (1.0 + 0.25 * c.wear)[:, None], 0.85, bump=1.0)
    put(c.mask(UNDER), srgb(232, 226, 214), 0.85, bump=1.0)
    put(c.mask(BUTTON), srgb(204, 182, 132), 0.4)
    # belt, gold, trousers, boots
    m = c.mask(BELT)
    put(m, srgb(96, 54, 32) * (1.0 + 0.8 * c.wear)[:, None], 0.5, bump=0.8, grain=1.0)
    stitch = m & ((np.abs(z - 1.087) < 0.0018) | (np.abs(z - 1.05) < 0.0018)) & (np.sin(np.arctan2(x, y) * 260.0) > -0.2)
    c.col[stitch] = srgb(176, 136, 90)
    put(c.mask(GOLD), srgb(236, 180, 86) * (1.0 - 0.4 * c.cavity)[:, None], 0.25, metal=1.0, bump=0.05, grain=1.0)
    m = c.mask(TROUSERS)
    tr = np.broadcast_to(srgb(198, 176, 140), (n, 3)) * (1.0 + 0.06 * mott - 0.07 * smooth(0.06, 0.0, diamond) + 0.2 * c.wear)[:, None]
    put(m, tr, 0.85, bump=1.0)
    speck(m, srgb(168, 132, 92), 0.1)
    fly = m & (z > 0.84) & (z < 1.04) & (y < 0) & (np.abs(x - 0.012) < 0.004)
    c.draw(fly, np.abs(x - 0.012), 0.0007, 0.5)
    m = c.mask(BOOT)
    put(m, srgb(104, 64, 40) * (1.0 + 0.9 * c.wear + 0.1 * mott)[:, None], 0.45, bump=0.6, grain=1.0)
    put(c.mask(SOLE), srgb(44, 34, 30), 0.7, bump=0.4, grain=1.0)
    put(c.mask(LACE), srgb(186, 150, 96), 0.7)
    put(c.mask(STRAP), srgb(84, 48, 30) * (1.0 + 0.6 * c.wear)[:, None], 0.5, bump=0.6, grain=1.0)
    put(c.mask(DIAL), srgb(24, 24, 30), 0.15)
    put(c.mask(NAIL), srgb(226, 176, 160), 0.3)
    put(c.mask(PEN), srgb(70, 64, 140), 0.3)
    put(c.mask(PENCAP), srgb(226, 176, 70), 0.3, metal=1.0)

    ao = np.where(c.mask(TROUSERS) & (z < 0.85), 0.6 + 0.4 * c.ao, 0.4 + 0.6 * c.ao)     # lighter between the legs: those insides show in the stride
    c.col *= ao[:, None]
    c.col *= (1.0 - 0.25 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"head": 2400, "hair": 700, "glasses": 500, "body": 4300, "arms": 1700},
    "density": {"head": 1.8, "hair": 1.0, "glasses": 0.6, "arms": 1.1},
    "tex": 2048,
    "stride": {"walk": 0.95, "run": 1.55},
    "speed": 0.8,
    "look": ["head"], "neck": "neck",
    "look_pivot": (0.0, 0.02, 1.62),
    "radius": 0.45,
}
BALL = v3((0.172, -0.14, 0.0))            # the boot rolls near its toe: a pivot further back sinks the toe into the floor
STANCE_Y = 0.12         # his hips only 3 cm ahead of mid-stance (kit.gait centres the stance on the ball): he leans back and lets the belly lead


def rig_bones():
    from kit.rig import Bone, mirror
    return mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.03, 0.93), (0, 0.03, 1.10), "root", 0.24),
        Bone("spine", (0, 0.03, 1.10), (0, 0.02, 1.28), "hips", 0.26),
        Bone("chest", (0, 0.02, 1.28), (0, 0.035, 1.47), "spine", 0.22),
        Bone("neck", (0, 0.035, 1.47), (0, 0.02, 1.62), "chest", 0.11),
        Bone("head", (0, 0.02, 1.62), (0, 0.0, 1.88), "neck", 0.1),
        Bone("shoulder.L", (0.09, 0.035, 1.46), SHOULDER, "chest", 0.08),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.1),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.08),
        Bone("hand.L", WRIST, WRIST - HAND[:, 2] * 0.15, "forearm.L", 0.045),
        Bone("thigh.L", HIP_J, KNEE, "hips", 0.16),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.11),
        Bone("foot.L", ANKLE, TOE, "shin.L", 0.05),
    ])


def skin_rules(P, part, piece, names):
    """piece: 0 head, 1 hair, 2 glasses, 3 body, 4 arms"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, z = P[:, 0], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    hp = piece == 0
    allow(hp, "chest", "neck", "head")
    rig[hp & (unbig(P)[:, 2] > 1.6)] = ix["head"]
    for pc in (1, 2):
        rig[piece == pc] = ix["head"]
        allow(piece == pc, "head")
    bp = piece == 3
    legs = bp & ((np.isin(part, (TROUSERS, BOOT, SOLE, LACE)) & (z < 1.03)) | (z < 0.25))
    allow(legs, "hips")
    seat = legs & (z > 0.76) & (np.abs(x) < 0.07)            # the crotch and seat stay with the hips: a stretch there reads better than a crease
    allow(legs & ~seat & (x > -0.05), "thigh.L", "shin.L", "foot.L")
    allow(legs & ~seat & (x < 0.05), "thigh.R", "shin.R", "foot.R")
    torso = bp & ~legs
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.17) & (z > 1.3), "shoulder.L")
    allow(torso & (x < -0.17) & (z > 1.3), "shoulder.R")
    rig[torso & np.isin(part, (PEN, PENCAP))] = ix["chest"]
    ap = piece == 4
    allow(ap & (x > 0), "shoulder.L", "upper_arm.L", "forearm.L", "hand.L")
    allow(ap & (x <= 0), "shoulder.R", "upper_arm.R", "forearm.R", "hand.R")
    allow(ap & (z > 1.32) & (np.abs(x) < 0.36), "chest")
    rig[ap & np.isin(part, (STRAP, DIAL, GOLD))] = ix["forearm.L"]
    return A, rig


WALK = dict(stride=0.95, stance=0.6, foot_x=0.195, lift=0.06, bob=0.022, drop=0.07, sway=0.02, roll=4.0, yaw=7.0, counter=1.1,
            lean=-4.0, toe_off=11.0, toe_out=11.0, swing_point=6.0, spine_lean=-3.0)       # a wide stance: his big trouser legs must pass clear of each other
RUN = dict(stride=1.55, stance=0.42, foot_x=0.18, lift=0.12, bob=0.04, drop=0.10, sway=0.018, roll=4.0, yaw=9.0, counter=1.3,
           lean=6.0, toe_off=16.0, toe_out=8.0, swing_point=12.0, spine_lean=0.0)


def motions(rig):
    """walk: a heavy plod (leaning back, the belly leading, a deep bob with each heavy footfall, arms swinging from the shoulder, the head
    pushed a little forward); run: a lumbering jog; idle: big breaths, weight from foot to foot, a hitch of the belt, a sly look about"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]

    def walkish(u, g, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        p.offset = p.offset + Vector((0.0, STANCE_Y, 0.0))
        c1 = math.cos(TAU * u)
        thud = math.exp(-((u % 0.5) / 0.08) ** 2)               # each heavy footfall
        p.rot("chest", -1.5 * thud, 0, 0)
        sw = 30.0 if run else 14.0
        p.rot("upper_arm.L", sw * c1, -4.0, 0)
        p.rot("upper_arm.R", -sw * c1, 4.0, 0)
        p.rot("forearm.L", -(50.0 if run else 8.0) - (12.0 if run else 8.0) * max(0.0, -c1), 0, 0)
        p.rot("forearm.R", -(50.0 if run else 8.0) - (12.0 if run else 8.0) * max(0.0, c1), 0, 0)
        p.rot("neck", 6.0 if not run else 8.0, 0, 0)
        p.world["head"] = R((2.0 if not run else 6.0) + 1.5 * thud, 0, -3.0 * c1)
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    idle = []
    sh, el, wr = Vector(SHOULDER.tolist()), Vector(ELBOW.tolist()), Vector(WRIST.tolist())
    line = (wr - sh).normalized()
    pole = ((el - sh) - line * (el - sh).dot(line)).normalized()
    for i in range(181):
        t = i / 30.0
        p = Pose()
        w = math.sin(TAU * t / 6.0)
        b = math.sin(TAU * t / 3.0)
        stand(rig, p, legs, {"L": (Vector(BALL.tolist()), 9.0), "R": (Vector((BALL * f).tolist()), -9.0)},
              hip_shift=(0.025 * w, 0.0, -0.012), roll=-2.5 * w, yaw=2.0 * w)
        p.rot("spine", -1.5 + 1.5 * b, 2.5 * w, 0)
        p.rot("chest", 1.5 * b, 1.0 * w, 0)
        # the belt hitch (2.2 s to 3.4 s): both hands to the belt at his hips, a heave up, back down
        hs = ease((t - 2.2) / 0.35) * (1.0 - ease((t - 3.1) / 0.4))
        heave = math.sin(math.pi * min(1.0, max(0.0, (t - 2.55) / 0.5))) * hs
        for side, sx in (("L", 1.0), ("R", -1.0)):
            tgt = Vector((0.345 * sx, -0.07, 1.02 + 0.03 * heave))
            rest = Vector((wr.x * sx, wr.y, wr.z))
            pl = Vector((pole.x * sx, pole.y, pole.z))
            p.ik["upper_arm." + side] = (rest.lerp(tgt, hs), pl, "hand." + side, None)
        p.offset = p.offset + Vector((0.0, 0.0, 0.012 * heave))
        look = ease((t - 0.6) / 0.8) * (1.0 - ease((t - 1.9) / 0.6)) * 22.0 + ease((t - 4.0) / 0.7) * (1.0 - ease((t - 5.3) / 0.6)) * -10.0
        p.world["head"] = R(2.0 + 1.0 * b - 3.0 * heave, 0, look)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
