## FOINT CITY townsfolk: the jelly cube (slime). A wobbly cube of green jelly with googly eyes and a grin; a lost boot's toe sticks out of its front, a bone out of its side, and more it swallowed shows through.
# Upgrade of the three.js folk species "slime" (progalpha levels/hub/folk-species-d.js; old render refs/old/slime.png): kept the pale green rounded cube on its
# darker puddle, the gloss highlights and the bubble on top, the big white googly eyes, pink cheeks and dark green smile, the brown boot poking out of the
# front at the bottom and the bone out of its side. 0.80 m tall.
# Jelly is opaque in the game (no transparency in the folk shader): what is inside it is painted on its surface (rays cast in from every point of the jelly
# find the boot, the bone, two coins and a key), tinted and fogged by the jelly.
# Moves: squash and slide: it surges forward long and low, snaps back into a squat and jiggles, again (its body bones scale: the kit has no scale, so
# this recipe keys it itself, see _write_action_s). Its top half wobbles on its own and turns to look.
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 0.80
REF = ("old/slime.png", None)

JELLY, EYE, MOUTH, LEATHER, SOLE, LACE, BONE = range(1, 8)
COLOURS = {
    JELLY: ((0.45, 0.85, 0.4), 0.08, 0.0),
    EYE: ((0.97, 0.97, 0.94), 0.12, 0.0),
    MOUTH: ((0.06, 0.25, 0.08), 0.3, 0.0),
    LEATHER: ((0.35, 0.22, 0.11), 0.6, 0.0),
    SOLE: ((0.12, 0.1, 0.08), 0.8, 0.0),
    LACE: ((0.8, 0.75, 0.6), 0.8, 0.0),
    BONE: ((0.92, 0.88, 0.78), 0.5, 0.0),
}

GRIN = Clip(Ellipsoid((0.0, -0.335, 0.36), (0.09, 0.045, 0.05)), [Half((0, 0, 0.372), (0, 0, 1))], k=0.012)
EYE_R = 0.072
EYE_C = v3((0.128, -0.318, 0.512))
MID = 0.4                      # where the body bone hands over to the top one
# the boot: lying with its toe out of the front, low on its left (+X); the bone: through its right side, near the front
BOOT_TOE = v3((0.2, -0.42, 0.075))
BONE_A, BONE_B = v3((-0.2, -0.2, 0.36)), v3((-0.47, -0.27, 0.31))


class Bounded(Shape):
    """the child with a tighter box than the kit's spheres give it (keeps the mesher's grid small)"""
    def __init__(self, child, lo, hi):
        self.child, self.lo, self.hi, self.part = child, v3(lo), v3(hi), child.part

    def eval(self, P):
        return self.child.eval(P)

    def dist(self, P):
        return self.eval(P)[0]


def jelly_shape():
    cube = Box((0, 0, 0.395), (0.36, 0.33, 0.35), rr=0.17)
    sag = Ellipsoid((0, 0, 0.12), (0.41, 0.38, 0.13))
    puddle = Ellipsoid((0, 0, 0.022), (0.46, 0.43, 0.04))
    blob = Sphere((0.13, 0.06, 0.7), 0.085)
    j = Union([cube, sag, puddle, blob], k=0.07)
    j = Clip(j, [Half((0, 0, 0.0), (0, 0, -1))], k=0.0)

    def wob(P):
        return noise3(P, 0.12) * 0.7 + noise3(P, 0.05) * 0.3
    return Bump(j, wob, 0.006)


def body():
    jj = Union([jelly_shape()], part=JELLY)
    # a wide open grin under the eyes, the dark of it inside
    jj = Cut(jj, [GRIN], k=0.01)            # (its dark inside is painted: a lining shape in the cut left a thin gap that breaks the mesher)
    eyes = Mirror(Sphere(EYE_C, EYE_R, part=EYE))
    return Union([jj, eyes], k=0.0)


def boot():
    """a brown work boot, toe forward (-Y), its heel and shaft buried in the jelly"""
    t = BOOT_TOE
    foot = Union([Ellipsoid(t + v3((0, 0.1, 0.0)), (0.062, 0.13, 0.058)), Ellipsoid(t + v3((0, 0.17, 0.0)), (0.064, 0.07, 0.07))], k=0.03, part=LEATHER)
    shaft = CappedCone(t + v3((0, 0.19, 0.0)), t + v3((0, 0.2, 0.17)), 0.06, 0.058, rr=0.01, part=LEATHER)
    b = Union([foot, shaft], k=0.03)
    b = Clip(b, [Half(t + v3((0, 0, -0.045)), (0, 0, -1))], k=0.004)
    sole = Box(t + v3((0, 0.105, -0.052)), (0.066, 0.145, 0.012), rr=0.01, part=SOLE)
    toe = Clip(Inflate(Ellipsoid(t + v3((0, 0.1, 0.0)), (0.062, 0.13, 0.058)), 0.003, part=SOLE), [Half(t + v3((0, 0.035, 0)), (0, 1, 0)), Half(t + v3((0, 0, 0.01)), (0, 0, -1))], k=0.003)
    laces = [RoundCone(t + v3((-0.03, 0.06 + i * 0.03, 0.05 + i * 0.004)), t + v3((0.03, 0.06 + i * 0.03, 0.05 + i * 0.004)), 0.0045, 0.0045, part=LACE) for i in range(3)]
    return Union([b, sole, toe] + laces, k=0.0)


def bone():
    """a cartoon bone: a shaft with two knuckles at each end"""
    d = (BONE_B - BONE_A) / np.linalg.norm(BONE_B - BONE_A)
    side = np.cross(d, v3((0, 0, 1)))
    side /= np.linalg.norm(side)
    up = np.cross(side, d)
    shaft = RoundCone(BONE_A, BONE_B, 0.024, 0.022, part=BONE)
    knobs = [Sphere(e + up * s * 0.022 + d * o, 0.033, part=BONE) for e, o in ((BONE_A, -0.01), (BONE_B, 0.01)) for s in (-1, 1)]
    return Union([shaft] + knobs, k=0.012)


def pieces():
    return [("jelly", Bounded(body(), (-0.49, -0.47, -0.01), (0.49, 0.47, 0.83)), 0.0026), ("boot", boot(), 0.0018), ("bone", bone(), 0.0016)]


# ---------------------------------------------------------------------------------------------------- paint

def swallowed():
    """everything inside the jelly, for the paint's rays: (shape, colour) pairs"""
    coins = [CappedCone(c, c + v3(n) * 0.006, 0.03, 0.03, rr=0.002) for c, n in ((v3((-0.1, 0.05, 0.2)), (0.3, 0.2, 0.93)), (v3((0.06, 0.1, 0.55)), (0.8, 0.0, 0.6)))]
    key = Union([Torus((-0.12, -0.05, 0.6), 0.022, 0.006, Rm=rot(rx=70, rz=30)), RoundCone((-0.1, -0.06, 0.585), (-0.03, -0.09, 0.53), 0.007, 0.007),
                 Box((-0.04, -0.095, 0.53), (0.008, 0.004, 0.012), rr=0.002)], k=0.004)
    return [(boot(), "boot"), (bone(), "bone"), (Union(coins), "coin"), (key, "key")]


def paint(c):
    from kit.paint import srgb, smooth
    P, N = c.P, c.N
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    mott = noise3(P, 0.04) * 0.5 + noise3(P, 0.012) * 0.25

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 and len(col) == n else col
        c.rough[m] = rough[m] if np.ndim(rough) == 1 and np.size(rough) == n else rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    # the jelly: rays in from the surface; what they meet is drawn tinted and fogged by the depth of jelly they crossed; the jelly itself paler at
    # its edges (light through it), deep green in its heart; little bubbles; two gloss highlights up on its left
    m = c.mask(JELLY)
    if m.any():
        G = P[m]
        D = -N[m]
        things = swallowed()
        t = np.full(len(G), 0.004, np.float32)
        hit = np.full(len(G), -1, np.int16)
        for _ in range(70):
            p = G + D * t[:, None]
            ds = np.stack([s.eval(p)[0] for s, _ in things], 1)
            d = ds.min(1)
            k = ds.argmin(1)
            new = (hit < 0) & (d < 0.001)
            hit[new] = k[new]
            t = np.where(hit >= 0, t, t + np.clip(d * 0.85, 0.003, 0.012))      # (capped: far from every part the field reads 1000)
        hit[t > 0.5] = -1
        depth = np.clip(t / 0.6, 0, 1)
        jc = srgb(170, 240, 140) + (srgb(76, 186, 84) - srgb(170, 240, 140)) * smooth(0.0, 1.0, depth)[:, None]
        names = {i: nm for i, (_, nm) in enumerate(things)}
        tint = srgb(150, 236, 128)
        cols = {"boot": srgb(110, 66, 30), "bone": srgb(236, 226, 200), "coin": srgb(250, 196, 60), "key": srgb(190, 190, 180)}
        col = jc.copy()
        for i, nm in names.items():
            mm = hit == i
            if mm.any():
                oc = cols[nm] * 0.7 + cols[nm] * tint * 0.4
                col[mm] = oc + (jc[mm] - oc) * (0.15 + 0.5 * depth[mm])[:, None]
        # the boot's sole and laces under the jelly
        bub = np.zeros(len(G), np.float32)
        rng = np.random.default_rng(5)
        for _ in range(40):
            bc = v3((rng.uniform(-0.36, 0.36), rng.uniform(-0.34, 0.34), rng.uniform(0.08, 0.72)))
            rr = rng.uniform(0.004, 0.013)
            dd = np.linalg.norm(G - bc, axis=1)
            bub = np.maximum(bub, smooth(rr, rr * 0.5, dd) - smooth(rr * 0.6, rr * 0.2, dd) * 0.5)
        col = col + (srgb(225, 255, 210) - col) * (bub * 0.7)[:, None]
        wear = c.wear[m]
        col = col + (srgb(200, 255, 180) - col) * (wear * 0.35)[:, None]
        hl = smooth(0.06, 0.02, np.sqrt(((G[:, 0] + 0.17) / 1.3) ** 2 + (G[:, 2] - 0.66) ** 2 + (np.maximum(G[:, 1] + 0.2, 0) * 0.5) ** 2))
        hl = np.maximum(hl, smooth(0.03, 0.01, np.sqrt((G[:, 0] + 0.29) ** 2 + (G[:, 2] - 0.55) ** 2)) * (G[:, 1] < 0))
        col = col + (srgb(240, 255, 236) - col) * (hl * 0.45)[:, None]
        # pink cheeks under the eyes
        for sx in (1, -1):
            ck = np.sqrt(((G[:, 0] - sx * 0.2) / 0.05) ** 2 + ((G[:, 2] - 0.4) / 0.028) ** 2)
            col = col + (srgb(250, 140, 150) - col) * (smooth(1.0, 0.5, ck) * 0.7 * (G[:, 1] < -0.2))[:, None]
        # the grin's inside: dark green going black at the back, a pink tongue low in it
        gd = GRIN.eval(G)[0]
        ins = (np.abs(gd) < 0.004) & (G[:, 1] > -0.335) & (G[:, 1] < -0.2)
        mc = srgb(24, 70, 30) * (1.0 - 0.6 * smooth(-0.33, -0.3, G[:, 1]))[:, None]
        tongue = ins & (G[:, 2] < 0.345) & (np.abs(G[:, 0]) < 0.05)
        col[ins] = mc[ins]
        col[tongue] = srgb(220, 110, 120) * 0.8
        c.col[m] = col
        c.rough[m] = 0.06
        c.bump[m] = 0.0
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(210, 255, 200), (int(m.sum()), 3)), np.full((int(m.sum()), 1), 0.12, np.float32)], 1)
    # the eyes: googly, big black pupils rolled up and in a little, a hard glint
    m = c.mask(EYE)
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    de = Q - EYE_C
    r = np.linalg.norm(de, axis=1)
    d = de / np.maximum(r, 1e-6)[:, None]
    look = v3((-0.12, -0.97, 0.2)) / np.linalg.norm((-0.12, -0.97, 0.2))
    a = np.arccos(np.clip(d @ look, -1, 1))
    ec = np.broadcast_to(srgb(248, 248, 242), (n, 3)).copy()
    c.draw(m, (a - 0.42) * EYE_R, 0.0)
    gl = smooth(0.01, 0.004, (d[:, 0] * np.sign(x) + 0.2) ** 2 + (d[:, 2] - 0.42) ** 2)
    ec = ec + (srgb(255, 255, 255) - ec) * gl[:, None]
    c.draw(m & (gl > 0.5), np.full(n, 1.0), 0.0, 0.0)
    put(m, ec * (1.0 - 0.15 * smooth(0.5, 1.5, np.arccos(np.clip(-d[:, 1], -1, 1))))[:, None], 0.08)
    m = c.mask(MOUTH)
    put(m, srgb(30, 90, 36) * (0.5 + 0.5 * smooth(0.33, 0.37, z))[:, None], 0.2)
    # the boot: oiled brown leather, scuffed pale at the toe, a dark sole, pale laces; the bone: old ivory, darker in its knuckles
    m = c.mask(LEATHER)
    lc = srgb(112, 70, 36) * (1.0 + 0.1 * mott)[:, None]
    lc = lc + (srgb(176, 132, 90) - lc) * (c.wear * 0.6)[:, None]
    put(m, lc * (1.0 - 0.3 * c.cavity)[:, None], 0.45, bump=0.8, grain=1.0)
    m = c.mask(SOLE)
    put(m, srgb(40, 32, 26), 0.8, bump=0.6, grain=1.0)
    m = c.mask(LACE)
    put(m, srgb(214, 200, 160), 0.8, bump=0.5)
    m = c.mask(BONE)
    bc = srgb(236, 226, 198) * (1.0 + 0.06 * mott)[:, None]
    bc = bc + (srgb(170, 150, 110) - bc) * (smooth(0.0, 0.5, c.cavity) * 0.6)[:, None]
    put(m, bc, 0.55, bump=0.4, grain=1.0)
    c.spk[m] = np.concatenate([np.broadcast_to(srgb(190, 170, 130), (int(m.sum()), 3)), np.full((int(m.sum()), 1), 0.25, np.float32)], 1)

    c.col *= (0.4 + 0.6 * c.ao)[:, None]
    jm = c.mask(JELLY, EYE)
    c.col[jm] /= (0.4 + 0.6 * c.ao[jm])[:, None] ** 0.6
    c.col *= (1.0 - 0.2 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model

GAME = {
    "budget": {"jelly": 5200, "boot": 1600, "bone": 700},
    "density": {"jelly": 1.3},
    "tex": 2048,
    "stride": {"walk": 0.5, "run": 0.85},
    "speed": 0.55,
    "look": ["top"], "neck": "none",
    "look_pivot": (0.0, 0.0, 0.4),
    "radius": 0.42,
}
TOP_HEAD = v3((0.0, 0.0, MID))


def rig_bones():
    from kit.rig import Bone
    return [
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("base", (0, 0, 0.0), (0, 0, 0.1), "root", 0.2),
        Bone("body", (0, 0, 0.0), (0, 0, MID), "base", 0.35),
        Bone("top", TOP_HEAD, (0, 0, 0.8), "base", 0.35),
    ]


def skin_rules(P, part, piece, names):
    """piece: 0 jelly (the eyes ride the top), 1 boot (low: the body), 2 bone; the jelly blends from body to top through its middle"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    z = P[:, 2]
    A[:, ix["body"]] = True
    A[:, ix["top"]] = True
    rig[z < MID - 0.12] = ix["body"]
    rig[z > MID + 0.12] = ix["top"]
    rig[(piece == 0) & (part == EYE)] = ix["top"]
    rig[(piece == 0) & (part == MOUTH)] = ix["top"]
    rig[piece == 1] = ix["body"]
    rig[piece == 2] = ix["top"]
    return A, rig


# ---------------------------------------------------------------------------------------------------- squash and stretch: the kit's solve plus joint moves and leaf-bone scale

def _solve_s(rig, pose):
    """kit.gait.solve, then `pose.move` {bone: world offset carried by its whole (FK) subtree} and `pose.scale` {leaf bone: (sx, sy, sz) in its own axes, y along it}"""
    from kit.gait import solve
    from mathutils import Matrix
    A = solve(rig, pose)
    kids = {}
    for b in rig.order:
        kids.setdefault(rig.parent[b], []).append(b)
    for b, mv in getattr(pose, "move", {}).items():
        T = Matrix.Translation(mv)
        stack = [b]
        while stack:
            q = stack.pop()
            A[q] = T @ A[q]
            stack += kids.get(q, [])
    for b, (sx, sy, sz) in getattr(pose, "scale", {}).items():
        L = rig.local[b]
        A[b] = A[b] @ L @ Matrix.Diagonal((sx, sy, sz, 1.0)) @ L.inverted()
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
            bas = rig.local[b].inverted() @ (Ap.inverted() @ A[b]) @ rig.local[b]
            pb = arm.pose.bones[b]
            loc, q, sc = bas.decompose()
            if b in prevq and q.dot(prevq[b]) < 0:
                q.negate()
            prevq[b] = q
            pb.location = loc
            pb.rotation_quaternion = q
            pb.scale = sc
            for path in ("location", "rotation_quaternion", "scale"):
                pb.keyframe_insert(path, frame=i, group=b)
    for fc in gait._fcurves(act):
        for k in fc.keyframe_points:
            k.interpolation = "LINEAR"
    return act


def motions(rig):
    """walk: squash and slide (surge forward long and low, snap back into a squat, jiggle); run: the same, quicker and bigger, a little hop as it
    snaps; idle: breathing, a shiver of a jiggle now and then, the top half looking about"""
    import math
    from kit import gait
    from kit.gait import Pose, R, TAU, ease
    from mathutils import Vector, Matrix
    gait.write_action = _write_action_s          # (this build only: scale keys for the squash; see the header)
    hd = Vector(TOP_HEAD.tolist())

    def jelly(p, h, w, lean, wob_x, wob_y, surge=0.0, lift=0.0):
        """the jelly squashed (h tall, w wide), leaning `lean` degrees forward about its bottom, its top half wobbling on top of that"""
        Rl = R(lean, 0, 0)                     # (about +X: a positive angle tips the top forward, to -Y)
        p.offset = Vector((0.0, -surge, lift))
        p.world["body"] = Rl
        p.world["top"] = Rl @ R(wob_x, wob_y, 0)
        p.scale = {"body": (w, h, w), "top": (w, h, w)}
        S = Matrix.Diagonal((w, w, h))
        p.move = {"top": Rl @ (S @ hd) - hd}

    def cycle(u, big):
        # surge (0-0.4): stretch long and low leaning in; snap (0.4-0.6): squat; jiggle (0.6-1): a damped wobble back to round
        a = 1.6 if big else 1.0
        if u < 0.4:
            k = ease(u / 0.4)
            h = 1.0 - 0.1 * a * k
            lean = 9.0 * a * k
            wob = -4.0 * a * k
            surge = 0.03 * a * k
            lift = 0.0
        elif u < 0.6:
            k = (u - 0.4) / 0.2
            # the back pulls in: up tall for a moment, then down into the squat
            h = (1.0 - 0.1 * a) + 0.18 * a * ease(k / 0.5) if k < 0.5 else (1.0 + 0.08 * a) - 0.22 * a * ease((k - 0.5) / 0.5)
            k = ease(k)
            lean = 9.0 * a * (1.0 - k) - 3.0 * a * k
            wob = -4.0 * a * (1.0 - k) + 8.0 * a * k
            surge = 0.03 * a * (1.0 - k) - 0.02 * a * k
            lift = (0.035 if big else 0.0) * math.sin(math.pi * k)
        else:
            k = (u - 0.6) / 0.4
            dmp = math.exp(-k * 3.5)
            h = 1.0 - 0.14 * a * dmp * math.cos(k * 9.4)
            lean = -3.0 * a * dmp * math.cos(k * 9.4)
            wob = 8.0 * a * dmp * math.cos(k * 9.4)
            surge = -0.02 * a * (1.0 - ease(k))
            lift = 0.0
        w = 1.0 / math.sqrt(max(h, 0.5))
        p = Pose()
        jelly(p, h, w, lean, wob, 3.0 * math.sin(TAU * u), surge, lift)
        return p

    walk = [cycle(i / 32.0, False) for i in range(33)]
    run = [cycle(i / 24.0, True) for i in range(25)]

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        br = 0.025 * math.sin(TAU * t / 3.0)
        shiver = 0.0
        for t0 in (1.2, 4.4):
            dt = t - t0
            if dt > 0:
                shiver += math.exp(-dt * 3.0) * math.sin(dt * 14.0)
        h = 1.0 + br + 0.05 * shiver
        look = 9.0 * math.sin(TAU * t / 6.0)
        jelly(p, h, 1.0 / math.sqrt(h), 1.5 * math.sin(TAU * t / 3.0 + 1.0), 4.0 * shiver, 6.0 * shiver)
        p.world["top"] = p.world["top"] @ R(0, 0, look)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
