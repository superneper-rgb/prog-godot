## FOINT CITY townsfolk: the traffic cone that got up and left (cone). A scuffed orange cone with two reflective bands, heavy-lidded eyes and a smirk, its square rubber base on two stubby legs in grubby sneakers; it hops.
# Upgrade of the three.js folk species "cone" (progalpha levels/hub/folk-species-d.js; old render refs/old/cone.png): kept the orange cone with its two white
# bands, the black square base on two little black legs, the googly eyes and little mouth between the bands, the thin black arms. 0.90 m to the tip.
# Moves: it hops, both feet together, squashing as it lands and stretching as it takes off (the cone's bone scales: the kit has no scale, so this
# recipe keys it itself, see _write_action_s); idle, it rocks on its base like a cone knocked by a passing car.
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 0.90
REF = ("old/cone.png", None)

PVC, BAND, RUBBER, EYE, ARM, CANVAS, SOLE, LACE, MOUTH = range(1, 10)
COLOURS = {
    PVC: ((0.9, 0.3, 0.06), 0.45, 0.0),
    BAND: ((0.92, 0.92, 0.9), 0.3, 0.0),
    RUBBER: ((0.05, 0.05, 0.05), 0.8, 0.0),
    EYE: ((0.95, 0.94, 0.9), 0.15, 0.0),
    ARM: ((0.06, 0.06, 0.06), 0.6, 0.0),
    CANVAS: ((0.85, 0.83, 0.78), 0.8, 0.0),
    SOLE: ((0.9, 0.88, 0.84), 0.7, 0.0),
    LACE: ((1.0, 0.45, 0.1), 0.7, 0.0),
    MOUTH: ((0.2, 0.05, 0.03), 0.5, 0.0),
}

Z0, Z1, R0, R1 = 0.27, 0.897, 0.152, 0.03         # the cone: foot, tip, their radii


def cone_r(z):
    return R0 + (R1 - R0) * (z - Z0) / (Z1 - Z0)


EZ = 0.578                                          # the eyes' height
EYE_R = 0.033
EYE_X = 0.042
EYE_C = v3((EYE_X, -float(np.sqrt(cone_r(EZ) ** 2 - EYE_X ** 2)) + 0.011, EZ))
LID_N = v3((0.18, 0.25, -1.0)) / np.linalg.norm((0.18, 0.25, -1.0))      # the heavy upper lid's edge plane: drooping toward the outer corner
LID_PT = EYE_C + v3((0, 0, 0.004))
MZ = 0.508                                          # the mouth
SHOULDER = v3((0.108, 0.0, 0.49))
ELBOW = v3((0.18, 0.012, 0.405))
WRIST = v3((0.2, -0.008, 0.318))
HIP = v3((0.07, 0.0, 0.222))
KNEE = v3((0.074, -0.014, 0.142))
ANKLE = v3((0.075, 0.006, 0.064))
HAND = basis(-(WRIST - ELBOW), v3((0, 1, 0)))


class Bounded(Shape):
    """the child with a tighter box than the kit's spheres give it (keeps the mesher's grid small)"""
    def __init__(self, child, lo, hi):
        self.child, self.lo, self.hi, self.part = child, v3(lo), v3(hi), child.part

    def eval(self, P):
        return self.child.eval(P)

    def dist(self, P):
        return self.eval(P)[0]


def cone_shape():
    return CappedCone((0, 0, Z0 - 0.01), (0, 0, Z1), R0, R1, rr=0.022)


def body():
    """the cone with its bands, its eyes and lids, its mouth"""
    shell = Union([cone_shape(), CappedCone((0, 0, Z0 - 0.015), (0, 0, Z0 + 0.03), R0 + 0.022, R0 - 0.002, rr=0.01)], k=0.02, part=PVC)
    # the mouth: a short smirk pressed into the plastic, up at its left
    mouth = Union([RoundCone((-0.03, -0.12, MZ - 0.003), (0.012, -0.12, MZ - 0.004), 0.0042, 0.0045), RoundCone((0.012, -0.12, MZ - 0.004), (0.032, -0.12, MZ + 0.006), 0.0045, 0.0035)], k=0.004)
    shell = Cut(shell, [mouth], k=0.003)
    bands = []
    for za, zb in ((0.405, 0.462), (0.655, 0.703)):
        bands.append(Clip(Inflate(cone_shape(), 0.0035, part=BAND), [Half((0, 0, zb), (0, 0, 1)), Half((0, 0, za), (0, 0, -1))], k=0.0025))
    lid = Clip(Ellipsoid(EYE_C + v3((0, -0.001, 0.001)), (EYE_R + 0.005, EYE_R + 0.005, EYE_R + 0.005), part=PVC), [Half(LID_PT, LID_N)], k=0.004)
    lower = Clip(Ellipsoid(EYE_C, (EYE_R + 0.0035, EYE_R + 0.0035, EYE_R + 0.0035), part=PVC), [Half(EYE_C + v3((0, 0, -0.022)), (0, 0.3, 1.0))], k=0.003)
    face = Union([shell, Mirror(lid), Mirror(lower)], k=0.007)
    eyes = Mirror(Sphere(EYE_C, EYE_R, part=EYE))
    return Union([face, eyes] + bands, k=0.0)


def base():
    b = Box((0, 0, 0.247), (0.2, 0.2, 0.026), rr=0.018, part=RUBBER)
    b = Bump(b, lambda P: 1.0 - (P[:, 0] / 0.22) ** 2 - (P[:, 1] / 0.22) ** 2, 0.004)      # a slight dome (no dead-flat faces: the decimator flips them)
    lip = Box((0, 0, 0.226), (0.203, 0.203, 0.008), rr=0.006, part=RUBBER)
    return Union([b, lip], k=0.006)


def mitten():
    """a little black rubber mitten in hand space (wrist at the origin, fingers -Z, back +X, thumb -Y)"""
    palm = Ellipsoid((0, 0, -0.035), (0.016, 0.026, 0.036), part=ARM)
    tip = Ellipsoid((-0.006, 0.002, -0.062), (0.015, 0.024, 0.018), part=ARM)
    thumb = loft([(v3((-0.004, -0.02, -0.02)), 0.0095), (v3((-0.014, -0.034, -0.042)), 0.0085)], part=ARM, k=0.004)
    return Union([palm, tip, thumb], k=0.012)


def arms():
    a = loft([(SHOULDER + v3((-0.02, 0, 0.004)), 0.017), (ELBOW, 0.0155), (WRIST, 0.014)], part=ARM, k=0.008)
    return Mirror(Union([a, place(mitten(), WRIST, HAND)], k=0.006))


def legs():
    leg = loft([(HIP + v3((0, 0, 0.01)), 0.022), (KNEE, 0.02), (ANKLE + v3((0, 0, 0.012)), 0.019)], part=RUBBER, k=0.006)
    # a scuffed little high-top: canvas upper, white rubber sole and toe cap, orange laces
    ax = ANKLE[0]
    upper = Union([Ellipsoid((ax, -0.03, 0.04), (0.04, 0.068, 0.032), part=CANVAS), CappedCone((ax, 0.004, 0.02), (ax, 0.004, 0.088), 0.034, 0.03, rr=0.01, part=CANVAS)], k=0.02)
    upper = Clip(upper, [Half((0, 0, 0.016), (0, 0, -1))], k=0.003)
    sole = Box((ax, -0.026, 0.01), (0.043, 0.078, 0.0105), rr=0.009, part=SOLE)
    toe = Clip(Inflate(Ellipsoid((ax, -0.03, 0.04), (0.04, 0.068, 0.032)), 0.0025, part=SOLE), [Half((ax, -0.072, 0), (0, 1, 0)), Half((0, 0, 0.034), (0, 0, -1))], k=0.002)
    laces = [RoundCone((ax - 0.016, -0.045 + i * 0.016, 0.066 + i * 0.006), (ax + 0.016, -0.045 + i * 0.016, 0.066 + i * 0.006), 0.0032, 0.0032, part=LACE) for i in range(3)]
    tongue = Ellipsoid((ax, -0.012, 0.075), (0.02, 0.03, 0.012), R=rot(rx=-30), part=CANVAS)
    return Mirror(Union([leg, upper, sole, toe, tongue] + laces, k=0.0))


def pieces():
    return [("cone", Bounded(body(), (-0.2, -0.2, 0.235), (0.2, 0.2, 0.91)), 0.0014), ("base", base(), 0.002), ("arms", arms(), 0.0014), ("legs", legs(), 0.0013)]


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    mott = noise3(P, 0.03) * 0.5 + noise3(P, 0.01) * 0.25
    grime = np.clip(noise3(P + 3.1, 0.03) * 0.8 + 0.25, 0, 1)

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 and len(col) == n else col
        c.rough[m] = rough[m] if np.ndim(rough) == 1 and np.size(rough) == n else rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def spk(m, col, amt):
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (int(m.sum()), 3)), np.full((int(m.sum()), 1), amt, np.float32)], 1)

    # PVC: safety orange, sun-faded toward the tip, street grime rising from the base, a black tyre scuff across its back, scratches
    m = c.mask(PVC)
    pc = np.broadcast_to(srgb(244, 98, 24), (n, 3)).copy()
    pc = pc + (srgb(250, 150, 90) - pc) * (smooth(0.6, 0.9, z) * 0.35)[:, None]
    pc *= (1.0 + 0.06 * mott)[:, None]
    pc = pc * (1.0 - 0.45 * grime * smooth(0.42, 0.26, z))[:, None]
    ang = np.arctan2(x, -y)
    scuff = smooth(0.03, 0.0, np.abs(z - 0.56 - 0.12 * np.sin(ang * 1.2)) - 0.01 * (1 + noise3(P, 0.01))) * smooth(1.6, 2.2, np.abs(ang))
    pc = pc + (srgb(30, 26, 24) - pc) * (scuff * 0.8 * np.clip(noise3(P * 3, 0.02) + 0.6, 0, 1))[:, None]
    pc = pc + (srgb(255, 190, 150) - pc) * (c.wear * 0.3)[:, None]
    put(m, pc, 0.42, bump=0.15, grain=1.0)
    spk(m, (190, 60, 16), 0.2)
    sc = (np.abs(np.sin(ang * 14.0 + z * 40.0)) < 0.03) & (np.abs(ang) > 1.2) & (z > 0.45) & (z < 0.8)
    c.draw(m & sc, np.full(n, 0.0), 0.0004, 0.35)
    # the eyes' lids: a deeper orange crease, an inked lid line
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    de = Q - EYE_C
    r = np.linalg.norm(de, axis=1)
    pd = (Q - LID_PT) @ LID_N
    near = (r < EYE_R + 0.008) & (pd > -0.008) & (pd < 0.004) & (de[:, 1] < 0.01)
    c.draw(m & near, np.abs(pd + 0.0012), 0.0013)
    lowl = (r < EYE_R + 0.006) & (de[:, 2] < -0.012) & (de[:, 1] < 0.01)
    c.draw(m & lowl, np.abs(r - (EYE_R + 0.0018)), 0.0007, 0.6)
    # the mouth: its groove inked dark
    mo = m & (np.abs(z - MZ) < 0.02) & (y < -0.09) & (np.abs(x) < 0.045)
    seg1 = np.maximum(np.abs(z - (MZ - 0.0035)), np.maximum(-0.03 - x, x - 0.012))
    t2 = np.clip((x - 0.012) / 0.02, 0, 1)
    seg2 = np.sqrt((x - (0.012 + 0.02 * t2)) ** 2 + (z - (MZ - 0.004 + 0.01 * t2)) ** 2)
    c.draw(mo, np.minimum(seg1, seg2), 0.0014)
    # bands: retroreflective white, glass-bead sparkle, grubby
    m = c.mask(BAND)
    bc = srgb(232, 232, 226) * (1.0 - 0.3 * grime * (np.abs(np.arctan2(x, -y)) > 1.8))[:, None]
    put(m, bc, 0.3, bump=0.1, grain=1.0)
    spk(m, (255, 255, 255), 0.5)
    c.strp[m, 0] = (np.arctan2(x, -y) * 0.12 * 3.0)[m]
    c.strp[m, 1] = 0.4
    # eyes: a yellowish white, small amber irises glancing to its left, inked pupils, the lid's shadow
    m = c.mask(EYE)
    d = de / np.maximum(r, 1e-6)[:, None]
    look = v3((0.28, -0.94, 0.05)) / np.linalg.norm((0.28, -0.94, 0.05))       # both eyes glance to its left (+X); d is mirrored to the left side
    look_r = look * np.array([-1, 1, 1], np.float32)
    a = np.arccos(np.clip(np.where(x > 0, d @ look, d @ look_r), -1, 1))
    ec = np.broadcast_to(srgb(244, 238, 222), (n, 3)).copy()
    ec = ec + (srgb(210, 150, 40) - ec) * smooth(0.42, 0.39, a)[:, None]
    ec = ec * (1.0 - 0.5 * smooth(0.0, 0.4, d[:, 2]))[:, None]
    c.draw(m, (a - 0.2) * EYE_R, 0.0)
    gl = smooth(0.012, 0.004, (d[:, 0] * np.sign(x) + 0.22) ** 2 + (d[:, 2] - 0.12) ** 2)
    ec = ec + (srgb(255, 255, 255) - ec) * gl[:, None]
    put(m, ec, 0.08)
    # rubber base: black, recycled-crumb flecks, edges worn grey, street dust
    m = c.mask(RUBBER)
    rb = srgb(30, 30, 32) + (srgb(96, 92, 86) - srgb(30, 30, 32)) * (c.wear * 0.6)[:, None]
    rb = rb + (srgb(100, 90, 76) - rb) * (grime * 0.25)[:, None]
    put(m, rb, 0.85, bump=0.6, grain=1.0)
    spk(m, (70, 70, 70), 0.4)
    m = c.mask(ARM)
    put(m, srgb(36, 36, 38) + (srgb(90, 90, 92) - srgb(36, 36, 38)) * (c.wear * 0.5)[:, None], 0.6, bump=0.3, grain=1.0)
    m = c.mask(CANVAS)
    cv = srgb(226, 222, 210) * (1.0 - 0.35 * grime)[:, None]
    put(m, cv, 0.85, bump=1.0)
    m = c.mask(SOLE)
    put(m, srgb(236, 232, 222) * (1.0 - 0.4 * grime * smooth(0.02, 0.0, z))[:, None], 0.7, bump=0.3, grain=1.0)
    c.strp[m, 0] = (z * 4.0)[m]
    c.strp[m, 1] = 0.6
    m = c.mask(LACE)
    put(m, srgb(255, 120, 30), 0.8, bump=0.5)
    m = c.mask(MOUTH)
    put(m, srgb(60, 16, 10), 0.5)

    c.col *= (0.35 + 0.65 * c.ao)[:, None]
    c.col *= (1.0 - 0.25 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model

GAME = {
    "budget": {"cone": 3400, "base": 600, "arms": 1600, "legs": 2400},
    "density": {"cone": 1.6},
    "tex": 2048,
    "stride": {"walk": 0.42, "run": 0.75},
    "speed": 0.7,
    "look": ["cone"], "neck": "none",          # the whole cone turns to look (it is round: the arms stay put on its surface)
    "look_pivot": (0.0, 0.0, 0.5),
    "radius": 0.24,
}
BALL = v3((0.075, -0.02, 0.0))


def rig_bones():
    from kit.rig import Bone, mirror
    hand_end = WRIST - HAND[:, 2] * 0.07
    return mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("base", (0, 0, 0.222), (0, 0, 0.29), "root", 0.15),
        Bone("cone", (0, 0, Z0), (0, 0, Z1), "base", 0.1),
        Bone("shoulder.L", (0.05, 0.0, 0.49), SHOULDER, "base", 0.02),
        Bone("arm.L", SHOULDER, ELBOW, "shoulder.L", 0.017),
        Bone("fore.L", ELBOW, WRIST, "arm.L", 0.015),
        Bone("hand.L", WRIST, hand_end, "fore.L", 0.03),
        Bone("thigh.L", HIP, KNEE, "base", 0.022),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.02),
        Bone("foot.L", ANKLE, (0.075, -0.09, 0.02), "shin.L", 0.04),
    ])


def skin_rules(P, part, piece, names):
    """piece: 0 cone (rigid on its scaling bone), 1 base, 2 arms, 3 legs"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, z = P[:, 0], P[:, 2]
    A[:, ix["base"]] = True
    rig[piece == 0] = ix["cone"]
    rig[piece == 1] = ix["base"]
    for s, sx in (("L", 1), ("R", -1)):
        ap = (piece == 2) & (sx * x > 0)
        for b in ("shoulder", "arm", "fore", "hand"):
            A[ap, ix["%s.%s" % (b, s)]] = True
        A[ap, ix["base"]] = False
        wr = WRIST * np.array([sx, 1, 1], np.float32)
        hd = HAND[:, 2] * np.array([sx, 1, 1], np.float32)
        rig[ap & ((P - wr) @ (-hd) > -0.004)] = ix["hand.%s" % s]
        rig[ap & (np.abs(x) < 0.125)] = ix["shoulder.%s" % s]
        lp = (piece == 3) & (sx * x > 0)
        for b in ("thigh", "shin", "foot"):
            A[lp, ix["%s.%s" % (b, s)]] = True
        rig[lp & (z < 0.05)] = ix["foot.%s" % s]
        rig[lp & (z > 0.215)] = ix["base"]
    return A, rig


# ---------------------------------------------------------------------------------------------------- squash and stretch: the kit's solve plus joint moves and leaf-bone scale

def _solve_s(rig, pose):
    """kit.gait.solve, then `pose.move` {bone: world offset carried by its whole (FK) subtree} and `pose.scale` {leaf bone: (sx, sy, sz) in its own axes, y along it}"""
    from kit.gait import solve
    from mathutils import Matrix
    A = solve(rig, pose)
    kids = {}
    for b in rig.order:
        p = rig.parent[b]
        kids.setdefault(p, []).append(b)
    for b, mv in getattr(pose, "move", {}).items():
        T = Matrix.Translation(mv)
        stack = [b]
        while stack:
            q = stack.pop()
            A[q] = T @ A[q]
            stack += kids.get(q, [])
    for b, (sx, sy, sz) in getattr(pose, "scale", {}).items():
        L = rig.local[b]
        S = Matrix.Diagonal((sx, sy, sz, 1.0))
        A[b] = A[b] @ L @ S @ L.inverted()
    return A


def _write_action_s(rig, poses, name):
    """kit.gait.write_action, keying scale as well"""
    import bpy
    from mathutils import Matrix
    from kit import gait
    arm = rig.ob
    arm.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    prevq = {}
    for i, pose in enumerate(poses):
        A = _solve_s(rig, pose)
        for b in rig.order:
            p = rig.parent[b]
            Ap = A[p] if p else Matrix.Identity(4)
            delta = Ap.inverted() @ A[b]
            bas = rig.local[b].inverted() @ delta @ rig.local[b]
            pb = arm.pose.bones[b]
            loc, q, sc = bas.decompose()
            if b in prevq and q.dot(prevq[b]) < 0:
                q.negate()
            prevq[b] = q
            pb.location = loc
            pb.rotation_quaternion = q
            pb.scale = sc
            pb.keyframe_insert("location", frame=i, group=b)
            pb.keyframe_insert("rotation_quaternion", frame=i, group=b)
            pb.keyframe_insert("scale", frame=i, group=b)
    for fc in gait._fcurves(act):
        for k in fc.keyframe_points:
            k.interpolation = "LINEAR"
    return act


def motions(rig):
    """walk: one hop a cycle (land and squash, gather, spring and stretch, tuck the feet, stretch for the landing); run: bigger, faster hops;
    idle: it rocks on its base, settles, gives a long stretch"""
    import math
    from kit import gait
    from kit.gait import Pose, R, TAU, ease
    from mathutils import Vector
    gait.write_action = _write_action_s          # (this build only: scale keys for the squash; see the header)

    def squash_pose(p, h, w):
        """the cone's squash (h along it, w across), and the shoulders carried where the squashed surface takes them"""
        p.scale = {"cone": (w, h, w)}
        p.move = {}
        for s, sx in (("L", 1.0), ("R", -1.0)):
            p.move["shoulder.%s" % s] = Vector((sx * SHOULDER[0] * (w - 1.0), 0.0, (SHOULDER[2] - Z0) * (h - 1.0)))

    def feet(p, fy, lz, pitch):
        for s, sx in (("L", 1.0), ("R", -1.0)):
            rest = Vector((sx * ANKLE[0], ANKLE[1], ANKLE[2]))
            ball = Vector((sx * BALL[0], BALL[1], BALL[2]))
            wf = R(pitch, 0, 0)
            ankle = Vector((sx * BALL[0], fy, lz)) + wf @ (rest - ball)
            p.ik["thigh.%s" % s] = (ankle, Vector((sx * 0.1, -1.0, 0.0)), "foot.%s" % s, wf)

    def hop(u, S, apex, run):
        p = Pose()
        beta = 0.38
        if u < beta:
            # on the ground: land (squash), gather, push off
            k = u / beta
            fy = -S * beta / 2 + S * u
            dip = math.sin(math.pi * k) * (0.05 if run else 0.035)
            land = math.exp(-k * 7.0) * math.sin(k * 7.0 + 0.3)
            h = 1.0 - 0.17 * math.sin(math.pi * min(1.0, k * 1.6)) * (1.0 - k) - 0.06 * ease((k - 0.6) / 0.4) + 0.2 * ease((k - 0.88) / 0.12)
            p.offset = Vector((0.0, 0.0, -dip))
            feet(p, fy, 0.0, 14.0 * ease((k - 0.75) / 0.25))
            lean = -4.0 * (1.0 - k) + 8.0 * ease((k - 0.6) / 0.4)
            arm = -25.0 * (1.0 - k) + 30.0 * ease((k - 0.7) / 0.3)
        else:
            # in the air: up and over in a slow arc, feet tucked, stretching long at take-off and again reaching for the ground
            k = (u - beta) / (1.0 - beta)
            fy = S * beta / 2 - S * beta * ease(k)
            z = 4.0 * apex * k * (1.0 - k)
            h = 1.0 + 0.14 * (1.0 - ease(k / 0.35)) + 0.06 * ease((k - 0.75) / 0.25) - 0.03 * math.sin(math.pi * k)
            p.offset = Vector((0.0, 0.0, z))
            tuck = 0.05 * math.sin(math.pi * k) ** 0.7
            feet(p, fy, z + tuck, 14.0 * (1.0 - ease(k / 0.3)) - 18.0 * math.sin(math.pi * k))
            lean = 8.0 * (1.0 - ease(k / 0.5)) - 5.0 * ease((k - 0.6) / 0.4)
            arm = 30.0 * (1.0 - k) - 40.0 * math.sin(math.pi * k)
        w = 1.0 / math.sqrt(max(h, 0.5))
        squash_pose(p, h, w)
        p.rot("base", lean, 0, 0)
        for s, sx in (("L", 1.0), ("R", -1.0)):
            p.rot("arm.%s" % s, arm * 0.4, -sx * abs(arm) * 0.8, 0)
            p.rot("fore.%s" % s, -15.0, 0, 0)
        return p

    walk = [hop(i / 32.0, 0.42, 0.11, False) for i in range(33)]
    run = [hop(i / 24.0, 0.75, 0.17, True) for i in range(25)]

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        feet(p, 0.0, 0.0, 0.0)
        # rocking: knocked at 0.6 s, a damped wobble on its base; a long stretch (tall and thin) at 3.6 s with the arms up
        rk = math.exp(-max(0.0, t - 0.6) * 1.6) * math.sin(max(0.0, t - 0.6) * 9.0) * (t > 0.6)
        rk += 0.15 * math.sin(TAU * t / 3.0)
        st = ease((t - 3.3) / 0.5) * (1.0 - ease((t - 4.6) / 0.6))
        h = 1.0 + 0.1 * st + 0.012 * math.sin(TAU * t / 2.0)
        squash_pose(p, h, 1.0 / math.sqrt(h))
        p.offset = Vector((0.0, 0.0, -0.01 + 0.012 * st))
        p.rot("base", 2.0 * st, 7.0 * rk, 0)
        for s, sx in (("L", 1.0), ("R", -1.0)):
            p.rot("arm.%s" % s, -30.0 * st, -sx * (10.0 + 110.0 * st), 0)
            p.rot("fore.%s" % s, -10.0 - 30.0 * st, 0, 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
