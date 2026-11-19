# The Sigil's skeleton and clips (tools/sigil/build_sigil.py calls this). Legs and scythe arms are posed by IK onto targets, the rest by hand; every clip is captured frame by frame
# into plain bone rotations ("visual keying") and the IK is removed before export, so Godot gets ordinary FK clips. Clip names are what enemies/sigil_beast_view.gd plays.
import bpy, math
from mathutils import Vector as V, Matrix, Euler, Quaternion
import build_sigil as S

FPS = 30
LEGS = [(k, sn, s) for k in range(5) for sn, s in S.SIDES]


def smooth(a, b, x):
    if b == a:
        return 1.0 if x >= b else 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def bell(a, b, c, d, x):
    """0 before a, up to 1 over a..b, held to c, down to 0 over c..d"""
    return smooth(a, b, x) * (1.0 - smooth(c, d, x))


def build_rig(ob):
    sc = bpy.context.scene
    ad = bpy.data.armatures.new("sigil_rig")
    rig = bpy.data.objects.new("sigil_rig", ad)
    sc.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    B = S.bones()
    made = {}
    def make(n):
        if n in made:
            return made[n]
        h, t, par = B[n]
        eb = ad.edit_bones.new(n)
        eb.head, eb.tail = h, t
        eb.roll = 0.0
        eb.use_deform = True
        if par:
            eb.parent = make(par)
        made[n] = eb
        return eb
    for n in B:
        make(n)
    bpy.ops.object.mode_set(mode='OBJECT')
    ob.parent = rig
    m = ob.modifiers.new("rig", "ARMATURE")
    m.object = rig
    for pb in rig.pose.bones:
        pb.rotation_mode = 'XYZ'
    return rig


def empty(name, at, parent=None, bone=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(e)
    if parent:
        e.parent = parent
        if bone:
            e.parent_type = 'BONE'
            e.parent_bone = bone
    bpy.context.view_layer.update()
    e.matrix_world = Matrix.Translation(at)
    return e


def markers(rig):
    """the weak points' and the screen's places (and a point 1 m out along each one's normal), riding their bones: the view reads where to aim and where the halo goes"""
    out = []
    for i, (c, n, size, bone) in enumerate(S.POINTS):
        g = c + n * 0.08 - n * 0.22 + n * 0.05
        out.append(empty("wp_%d" % i, g, rig, bone))
        out.append(empty("wpn_%d" % i, g + n, rig, bone))
    hx = S.head_frame()
    out.append(empty("crt", hx @ V((0, 1.02, 0)), rig, "head"))
    out.append(empty("crtn", hx @ V((0, 2.02, 0)), rig, "head"))
    return out


IK = {}       # lower bone of a chain -> (upper bone, its hinge's pole point at rest, the bone the pole rides)
TARGET = {}   # lower bone -> where its tail must go this frame


def setup_ik(rig):
    """(Blender's IK constraint flipped these long legs' knees; an exact two-bone solve keeps each limb in its own plane, hinge true)"""
    for k, sn, s in LEGS:
        IK["leg_%d_%s_1" % (k, sn)] = ("leg_%d_%s_0" % (k, sn), S.knee(k, s) + V((s * 2.0, 0.0, 4.0)), "body_%d" % k)
    for sn, s in S.SIDES:
        IK["arm_%s_1" % sn] = ("arm_%s_0" % sn, S.ELBOW(s) + V((s * 2.0, -1.0, 4.0)), "body_0")


def _frame(y, n):
    y = y.normalized()
    x = (n - y * n.dot(y)).normalized()
    z = x.cross(y)
    return Matrix((x, y, z)).transposed()


def solve(rig, lower, target, pole=None):
    """the two bones of a limb posed so its tip reaches target, its middle joint bent toward its pole (its own, riding its body bone, unless a pose gives one)"""
    pbs, bones = rig.pose.bones, rig.data.bones
    upper, pole_rest, pole_bone = IK[lower]
    bu, bl = bones[upper], bones[lower]
    Pm = pbs[bu.parent.name].matrix
    M0 = Pm @ bu.parent.matrix_local.inverted() @ bu.matrix_local      # the upper bone with no pose of its own
    H = M0.translation.copy()
    rest_rot = M0.to_3x3() @ bu.matrix_local.to_3x3().inverted()       # how its parent has turned it
    if pole is None:
        pole = pbs[pole_bone].matrix @ bones[pole_bone].matrix_local.inverted() @ pole_rest
    a = (bu.tail_local - bu.head_local).length
    b = (bl.tail_local - bl.head_local).length
    T = V(target)
    d = max(abs(a - b) + 1e-3, min(a + b - 1e-3, (T - H).length))
    e = (T - H).normalized()
    pp = pole - H
    u = (pp - e * pp.dot(e)).normalized()
    x = (a * a - b * b + d * d) / (2 * d)
    h = math.sqrt(max(0.0, a * a - x * x))
    K = H + e * x + u * h
    Tr = H + e * d
    n_rest = (bu.tail_local - bu.head_local).cross(bl.tail_local - bl.head_local).normalized()
    n0 = rest_rot @ n_rest
    n1 = (K - H).cross(Tr - K).normalized()
    if n1.dot(n0) < 0:
        n1 = -n1
    y0 = M0.to_3x3() @ V((0, 1, 0))
    R = _frame(K - H, n1) @ _frame(y0, n0).transposed()
    Mu = (R @ M0.to_3x3()).to_4x4()
    Mu.translation = H
    pbs[upper].matrix_basis = M0.inverted() @ Mu
    M1 = Mu @ bu.matrix_local.inverted() @ bl.matrix_local
    y1 = M1.to_3x3() @ V((0, 1, 0))
    n1b = R @ n0
    R2 = _frame(Tr - K, n1) @ _frame(y1, n1b).transposed()
    Ml = (R2 @ M1.to_3x3()).to_4x4()
    Ml.translation = M1.translation
    pbs[lower].matrix_basis = M1.inverted() @ Ml


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# the clips. Each is (frames, loop, filter note, fn(u) -> pose). A pose: {"fk": {bone: (x, y, z) euler}, "root": (loc, euler), "feet": {(k, sn): point or ("rel", bone, point)}, "wrist": {sn: ...}}

def rest_foot(k, s):
    return S.foot(k, s)


def gait(u, k, s, amp=2.3, lift=1.6, duty=0.5, lag=0.2, period=1.0):
    ph = ((u * period) - k * lag + (0.5 if s > 0 else 0.0)) % 1.0
    if ph < duty:
        y = amp * (1.0 - 2.0 * ph / duty)
        z = 0.0
    else:
        q = (ph - duty) / (1.0 - duty)
        y = -amp + 2.0 * amp * (q * q * (3 - 2 * q))
        z = lift * math.sin(math.pi * q)
    return V((0.0, y, z))


def neck_fk(xs, ys=(0, 0, 0, 0, 0), zs=(0, 0, 0, 0, 0)):
    return {"neck_%d" % i: (xs[i], ys[i], zs[i]) for i in range(5)}


def clip_idle(u):
    w = 2 * math.pi * u
    fk = {"body_%d" % k: (0.015 * math.sin(w + k * 0.5), 0.0, 0.0) for k in range(5)}
    look = smooth(0.25, 0.3, u) * (1 - smooth(0.62, 0.68, u))       # it snaps its head round to one side and holds, like a camera
    jerk = smooth(0.8, 0.82, u) * (1 - smooth(0.86, 0.9, u))
    fk.update(neck_fk([0.03 * math.sin(w + i * 0.6) for i in range(5)], zs=[0.05 * math.sin(w) + 0.06 * look for i in range(5)]))
    fk["head"] = (0.06 * math.sin(w * 2) + 0.18 * jerk, 0.0, 0.35 * look - 0.15 * jerk)
    for i in range(3):
        fk["tail_%d" % i] = (0.0, 0.0, 0.18 * math.sin(w + i * 0.9))
    for sn, s in S.SIDES:
        fk["arm_%s_2" % sn] = (0.06 * math.sin(w + s), 0.0, 0.0)
    feet = {}
    for k, sn, s in LEGS:
        f = rest_foot(k, s)
        if (k, sn) == (1, "L"):      # one foot lifts and taps down again
            q = bell(0.5, 0.58, 0.64, 0.74, u)
            f = f + V((0, 0.5 * q, 1.4 * q))
        feet[(k, sn)] = f
    wr = {sn: S.WRIST(s) + V((0, 0.15 * math.sin(w + s), 0.12 * math.sin(w + 1 + s))) for sn, s in S.SIDES}
    return {"fk": fk, "root": (V((0, 0, 0.08 * math.sin(w))), (0, 0, 0)), "feet": feet, "wrist": wr}


def run_pose(u, amp=2.3, lift=1.7):
    w = 2 * math.pi * u
    fk = {"body_%d" % k: (0.03 * math.sin(2 * w + k), 0.0, 0.07 * math.sin(w - k * 1.2)) for k in range(5)}
    fk.update(neck_fk([-0.1 + 0.05 * math.sin(2 * w + 1), 0.03 * math.sin(2 * w + 1.5), 0.02, 0.0, 0.0], zs=[-0.05 * math.sin(w - 1.2), 0, 0, 0, 0]))
    fk["head"] = (0.08 * math.sin(2 * w + 2.4), 0.0, 0.06 * math.sin(w))
    for i in range(3):
        fk["tail_%d" % i] = (0.05 * math.sin(2 * w), 0.0, 0.32 * math.sin(w - i * 0.8))
    for sn, s in S.SIDES:
        fk["arm_%s_2" % sn] = (0.25 + 0.06 * math.sin(2 * w), 0.0, 0.0)
    feet = {(k, sn): rest_foot(k, s) + gait(u, k, s, amp, lift) + V((s * 0.2 * math.sin(w), 0, 0)) for k, sn, s in LEGS}
    wr = {sn: S.WRIST(s) + V((-s * 0.3, -0.9, 0.9 + 0.2 * math.sin(2 * w + s))) for sn, s in S.SIDES}
    return {"fk": fk, "root": (V((0, 0, -0.25 + 0.3 * math.sin(2 * w))), (0.0, 0.03 * math.sin(w), 0.0)), "feet": feet, "wrist": wr}


def clip_run(u):
    return run_pose(u)


def clip_wall_run(u):
    """running on a wall or upside down on a bore's roof (the chase rolls the whole body): flattened against it, the body pulled in to the surface, the legs splayed wide and low, the neck
    arched back off the surface so the set does not hang down into the car, and twisted to keep the set the right way up"""
    p = run_pose(u, 2.0, 1.1)
    for (k, sn), f in list(p["feet"].items()):
        s = -1.0 if sn == "L" else 1.0
        p["feet"][(k, sn)] = f + V((s * 1.6, 0.0, 0.0))
    loc, rot = p["root"]
    p["root"] = (loc + V((0, 0, -2.4)), rot)
    xs = [0.5, 0.25, 0.0, -0.1, -0.15]
    for i in range(5):
        x, y, z = p["fk"]["neck_%d" % i]
        p["fk"]["neck_%d" % i] = (x + xs[i], y + 0.12, z)
    x, y, z = p["fk"]["head"]
    p["fk"]["head"] = (x - 0.45, y + 0.25, z)
    for sn, s in S.SIDES:
        p["wrist"][sn] = S.WRIST(s) + V((s * 1.0, -2.2, 1.6))
    return p


def clip_rear(u):
    """seeked by the swing (0..1): it rears its front up and bares its belly to strike (0.36..0.42 is the held wind-up the fight lights its screens in), then slams down and recovers"""
    a = smooth(0.0, 0.34, u) * (1 - smooth(0.42, 0.55, u))
    slam = bell(0.42, 0.52, 0.6, 0.95, u)
    fk = {"body_2": (0.07 * a - 0.03 * slam, 0, 0), "body_1": (0.05 * a - 0.03 * slam, 0, 0), "body_0": (0.05 * a - 0.05 * slam, 0, 0),
          "body_3": (-0.05 * a, 0, 0), "body_4": (-0.05 * a, 0, 0)}      # (these add up down the chain)
    fk.update(neck_fk([-0.32 * a - 0.2 * slam, -0.14 * a - 0.2 * slam, 0.05 * a - 0.1 * slam, 0.12 * a, 0.05 * a]))      # (the neck held forward and low as the front rears, so the set stays under an 11.8 m vault)
    fk["head"] = (-0.1 * a + 0.2 * slam, 0, 0)
    feet = {}
    for k, sn, s in LEGS:
        f = rest_foot(k, s)
        if k == 0:
            f = f + V((-s * 0.8, 1.2, 3.8)) * a + V((0, 1.6, 0)) * slam
        elif k == 1:
            f = f + V((-s * 0.4, 0.6, 1.9)) * a + V((0, 0.8, 0)) * slam
        feet[(k, sn)] = f
    wr = {sn: S.WRIST(s) for sn, s in S.SIDES}
    return {"fk": fk, "root": (V((0, -0.6 * a + 0.6 * slam, 0.5 * a - 0.35 * slam)), (0, 0, 0)), "feet": feet, "wrist": wr}


def swipe(side):
    def fn(u):
        p = clip_idle(0.0)
        p["fk"] = {}
        for sn, s in S.SIDES:
            w = S.WRIST(s)
            fk_b = 0.0
            if sn == side:
                wind = smooth(0.0, 0.34, u) * (1 - smooth(0.42, 0.5, u))
                thr = bell(0.42, 0.5, 0.62, 0.95, u)
                w = w + V((s * 0.8, -4.7, 4.3)) * wind + V((-s * 1.1, 1.0, -3.9)) * thr
                fk_b = 0.7 * wind - 0.55 * thr
            p["fk"]["arm_%s_2" % sn] = (fk_b, 0.0, 0.0)
            p["wrist"][sn] = w
        return p
    return fn


def strike_pose(a, shake=0.0):
    fk = {"body_0": (-0.05 * a, 0, 0), "body_1": (-0.02 * a, 0, 0)}
    fk.update(neck_fk([-0.3 * a, -0.12 * a, 0.08 * a, 0.16 * a, 0.14 * a]))      # the neck straightens out forward, the set held tipped down at the car
    fk["head"] = (0.12 * a, 0.0, shake)
    return fk


def clip_strike(u):
    p = clip_idle(0.0)
    p["fk"] = strike_pose(smooth(0.0, 1.0, u))
    p["root"] = (V((0, 0, -0.15 * u)), (0, 0, 0))
    for k, sn, s in LEGS:
        if k == 0:
            p["feet"][(k, sn)] = rest_foot(k, s) + V((0, 0.9 * u, 0))
    return p


def clip_lunge(u):
    a = smooth(0.0, 0.22, u) * (1 - smooth(0.62, 1.0, u))
    p = clip_idle(0.0)
    p["fk"] = strike_pose(a * 1.1, 0.18 * math.sin(u * 50) * bell(0.2, 0.3, 0.5, 0.65, u))
    for sn, s in S.SIDES:
        p["wrist"][sn] = S.WRIST(s) + V((s * 1.4, 0.4, 1.2)) * a
        p["fk"]["arm_%s_2" % sn] = (0.5 * a, 0, 0)
    return p


def clip_roar(u):
    env = smooth(0.0, 0.2, u) * (1 - smooth(0.78, 1.0, u))
    up = smooth(0.0, 0.18, u) * (1 - smooth(0.3, 0.45, u))       # it draws back first
    sh = math.sin(u * 2 * math.pi * 9) * bell(0.3, 0.38, 0.72, 0.85, u)
    p = clip_idle(0.0)
    fk = {"body_0": (0.12 * env + 0.08 * up, 0, 0), "body_1": (0.06 * env, 0, 0)}
    fk.update(neck_fk([0.2 * up - 0.1 * env * (1 - up), 0.15 * up, 0.1 * env, 0.05 * env, -0.05 * env], zs=[0.04 * sh, 0.04 * sh, 0.0, 0.0, 0.0]))
    fk["head"] = (0.35 * up + 0.12 * env + 0.08 * sh, 0.0, 0.22 * sh)
    p["fk"] = fk
    for sn, s in S.SIDES:
        p["wrist"][sn] = S.WRIST(s) + V((s * 2.4, -1.8, 2.4)) * env
        p["fk"]["arm_%s_2" % sn] = (0.6 * env, 0, 0)
    return p


def clip_hit(u):
    j = smooth(0.0, 0.12, u) * (1 - smooth(0.2, 1.0, u))
    p = clip_idle(0.0)
    fk = {"body_0": (0.07 * j, 0, 0.03 * j)}
    fk.update(neck_fk([0.15 * j, 0.1 * j, 0.05 * j, 0, 0], zs=[0.06 * j, 0, 0, 0, 0]))
    fk["head"] = (0.32 * j, 0.0, -0.2 * j)
    p["fk"] = fk
    for sn, s in S.SIDES:
        p["wrist"][sn] = S.WRIST(s) + V((s * 0.4, -0.8, 0.5)) * j
    return p


def clip_reel(u):
    e = smooth(0.0, 0.15, u) * (1 - smooth(0.55, 1.0, u))
    wob = math.sin(u * 2 * math.pi * 3.0) * e
    fk = {"body_%d" % k: (0.04 * e, 0.12 * wob, 0.06 * wob) for k in range(5)}
    fk.update(neck_fk([0.08 * e - 0.2 * smooth(0.3, 0.5, u) * e, 0.05 * e, 0.0, 0, 0], zs=[0.2 * wob, 0.1 * wob, 0, 0, 0]))
    fk["head"] = (0.4 * e, 0.0, -0.3 * wob)
    for i in range(3):
        fk["tail_%d" % i] = (0.0, 0.0, 0.4 * wob)
    feet = {}
    for k, sn, s in LEGS:
        f = rest_foot(k, s)
        if k <= 1:      # its front legs lose the ground and scrabble
            ph = (u * 3 + k * 0.3 + (0.5 if s > 0 else 0)) % 1.0
            f = f + V((s * 0.5, 0.8 * math.sin(ph * 2 * math.pi), 1.6 * max(0.0, math.sin(ph * 2 * math.pi)))) * e + V((0, -1.2, 1.2)) * e
        feet[(k, sn)] = f
    wr = {sn: S.WRIST(s) + V((s * 2.2, -1.5, 2.0)) * e + V((0, 0, 0.6 * wob * s)) for sn, s in S.SIDES}
    fk.update({"arm_%s_2" % sn: (0.5 * e, 0, 0) for sn, s in S.SIDES})
    return {"fk": fk, "root": (V((0, -1.6 * e, 0.3 * e)), (0.07 * e, 0.08 * wob, 0.0)), "feet": feet, "wrist": wr}


def clip_land(u):
    d = smooth(0.0, 0.12, u) * (1 - smooth(0.15, 0.7, u))
    over = bell(0.55, 0.7, 0.75, 1.0, u)
    fk = {"body_%d" % k: (-0.06 * d, 0, 0) for k in range(5)}
    fk.update(neck_fk([-0.22 * d + 0.06 * over, -0.06 * d, 0.05 * d, 0.05 * d, 0]))
    fk["head"] = (0.35 * d, 0, 0)
    for i in range(3):
        fk["tail_%d" % i] = (0.25 * d, 0, 0)
    feet = {(k, sn): rest_foot(k, s) + V((s * 0.6 * d, 0, 0)) for k, sn, s in LEGS}
    wr = {sn: S.WRIST(s) + V((s * 2.6, 0.5, -1.0)) * d for sn, s in S.SIDES}
    fk.update({"arm_%s_2" % sn: (-0.3 * d, 0, 0) for sn, s in S.SIDES})
    return {"fk": fk, "root": (V((0, 0, -1.5 * d + 0.18 * over)), (0, 0, 0)), "feet": feet, "wrist": wr}


def clip_climb(u):
    """up a wall: the whole body pitched nose-up and its gait laid on the wall in front of its belly; two heaves a loop"""
    P = 1.35
    Rr = Matrix.Rotation(P, 3, 'X')
    heave = 0.5 * math.sin(u * 2 * math.pi * 2)
    fk = {"body_%d" % k: (0.04 * math.sin(u * 4 * math.pi + k), 0.0, 0.05 * math.sin(u * 2 * math.pi - k)) for k in range(5)}
    fk.update(neck_fk([-0.55, -0.3, -0.1, 0.0, 0.05]))      # its neck bent over to look back down at the train
    fk["head"] = (0.4, 0.0, 0.1 * math.sin(u * 2 * math.pi))
    feet = {}
    for k, sn, s in LEGS:
        g = gait(u * 2, k, s, 1.8, 1.4, 0.55, 0.15)
        feet[(k, sn)] = Rr @ (rest_foot(k, s) + g)
    for i in range(3):
        fk["tail_%d" % i] = (0.3, 0.0, 0.25 * math.sin(u * 2 * math.pi - i))
    wr = {sn: Rr @ (S.WRIST(s) + V((s * 0.8, 1.0, 1.0 + 0.6 * math.sin(u * 4 * math.pi + s)))) for sn, s in S.SIDES}
    return {"fk": fk, "root": (Rr @ V((0, heave, 0)), (P, 0, 0)), "feet": feet, "wrist": wr}


def clip_grab(u):
    """it has the car: front feet and scythes hooked over the car's tail (9 m ahead of its chest in the chase, 14 m ahead of the model's root), its set pushed down at you, shaking"""
    p = run_pose(u, 1.6, 1.2)
    w = 2 * math.pi * u
    sh = 0.14 * math.sin(w * 3)
    jab = 0.06 * max(0.0, math.sin(w * 2))
    p["fk"].update(neck_fk([-0.35 - jab, -0.25, 0.0, 0.1, 0.1]))
    p["fk"]["head"] = (0.2, 0.0, sh)
    p["fk"]["body_0"] = (-0.08, 0, 0)
    loc, rot = p["root"]
    p["root"] = (loc + V((0, 1.5, 0)), rot)
    for sn, s in S.SIDES:
        p["feet"][(0, sn)] = V((s * 1.9, 14.8 + 0.2 * math.sin(w + s), 1.3))       # its front feet on the car
        p["wrist"][sn] = V((s * 1.6, 13.6, 3.0)) + V((0, 0.4, 0.5)) * max(0.0, math.sin(w * 2 + s))
        p["fk"]["arm_%s_2" % sn] = (-0.45, 0, 0)
    return p


def clip_fall(u):
    w = 2 * math.pi * u
    fk = {"body_%d" % k: (0.08 * math.sin(w + k), 0.1 * math.sin(w * 2 + k), 0.1 * math.sin(w - k)) for k in range(5)}
    fk.update(neck_fk([0.2 * math.sin(w * 2 + i) for i in range(5)], zs=[0.15 * math.sin(w + i) for i in range(5)]))
    fk["head"] = (0.3 * math.sin(w * 3), 0.0, 0.3 * math.sin(w * 2))
    feet = {}
    for k, sn, s in LEGS:
        ph = w * 2 + k * 1.3 + (math.pi if s > 0 else 0)
        feet[(k, sn)] = rest_foot(k, s) + V((s * -1.5 + math.cos(ph) * 1.2, math.sin(ph) * 1.5, 3.0 + math.sin(ph * 1.3) * 1.5))
    wr = {sn: S.WRIST(s) + V((s * 1.5 * math.sin(w * 2 + s), -1.0, 2.0 + 1.5 * math.cos(w * 2 + s))) for sn, s in S.SIDES}
    return {"fk": fk, "root": (V((0, 0, 0)), (0, 0, 0)), "feet": feet, "wrist": wr}


def clip_defeat(u):
    """it staggers back, screams, its legs give and it goes down on its belly, neck last; a twitch"""
    st = bell(0.0, 0.15, 0.25, 0.45, u)
    down = smooth(0.35, 0.7, u)
    neck = smooth(0.55, 0.85, u)
    tw = bell(0.9, 0.92, 0.94, 0.97, u)
    fk = {"body_%d" % k: (0.1 * st - 0.04 * down, 0.0, 0.0) for k in range(5)}
    fk.update(neck_fk([0.05 * st - 0.25 * neck, 0.05 * st - 0.15 * neck, -0.1 * neck, -0.05 * neck, 0.05 * neck + 0.2 * tw]))
    fk["head"] = (0.4 * st + 0.3 * neck, 0.0, 0.4 * neck + 0.15 * tw)
    for i in range(3):
        fk["tail_%d" % i] = (0.2 * down, 0.0, 0.2 * down)
    feet = {(k, sn): rest_foot(k, s) + V((s * 1.8 * down, 0.0, 0.0)) + V((0, -0.8, 0)) * st for k, sn, s in LEGS}
    wr = {sn: S.WRIST(s) + V((s * 1.8, 0.5, -3.0)) * neck for sn, s in S.SIDES}
    fk.update({"arm_%s_2" % sn: (-0.6 * neck, 0, 0) for sn, s in S.SIDES})
    return {"fk": fk, "root": (V((0, -1.0 * st, 0.4 * st - 3.0 * down)), (0.0, 0.15 * down, 0.0)), "feet": feet, "wrist": wr}


# ---- the tight versions: crouched low and narrow, for the low SERN line and the bores' sides (the view blends toward them by its fit_h / fit_w) ----
TIGHT_W = 4.3                                   # the feet's half-width
SPLAY = [4.6, 1.9, 0.0, -1.4, -2.6]             # and spread fore and aft instead
NECK_LOW = [-0.62, -0.18, 0.12, 0.2, 0.16]      # the neck carried low and forward, the set still looking ahead


def tighten(p, arms=True):
    loc, rot = p["root"]
    p["root"] = (V((loc.x, loc.y, -0.1 + (loc.z + 0.25) * 0.4)), rot)      # (barely lower, its bob damped: lower and its long shins no longer reach the floor this narrow)
    for i in range(5):
        x, y, z = p["fk"].get("neck_%d" % i, (0, 0, 0))
        p["fk"]["neck_%d" % i] = (x * 0.5 + NECK_LOW[i], y, z)
    x, y, z = p["fk"].get("head", (0, 0, 0))
    p["fk"]["head"] = (x * 0.5 + 0.22, y, z)
    x, y, z = p["fk"].get("body_0", (0, 0, 0))
    p["fk"]["body_0"] = (x - 0.04, y, z)
    p.setdefault("poles", {})
    for (k, sn), f in list(p["feet"].items()):
        s = -1.0 if sn == "L" else 1.0
        r = S.foot(k, s)
        g = 0.45 if k == 0 else 1.0      # (the front pair's stride kept short: drawn back, their knees rose above the line's roof)
        lift = 0.36 if k == 0 else (0.4 if k == 1 else 0.8)      # (feet lifted less: a lifted foot raises its knee)
        p["feet"][(k, sn)] = V((s * TIGHT_W + (f.x - s * S.SPAN[k]) * 0.6, r.y + SPLAY[k] + (f.y - r.y) * g, f.z * lift))
        p["poles"]["leg_%d_%s_1" % (k, sn)] = ("rel", "body_%d" % k, S.hip(k, s) + (V((s * 1.3, SPLAY[k] * 0.8, 0.8)) if k == 0 else V((s * (1.6 if k == 2 else 1.2), math.copysign(2.0, SPLAY[k]) if SPLAY[k] else 0.0, -0.4 if k == 1 else 0.3))))     # knees out, not up (the front pair reaching far ahead, knees forward)
    if arms:
        for sn, s in S.SIDES:
            p["wrist"][sn] = V((s * 1.4, 8.0, 4.6)) + (p["wrist"][sn] - S.WRIST(s)) * 0.2      # the scythes carried low in front of its chest, blades down
            p["fk"]["arm_%s_2" % sn] = (0.2, 0.0, 0.0)
    for sn, s in S.SIDES:
        p["poles"]["arm_%s_1" % sn] = ("rel", "body_0", S.shoulder(s) + V((s * 2.0, 1.0, -2.0)))      # elbows out and down, not up
    return p


def clip_idle_low(u):
    return tighten(clip_idle(u))


def clip_run_low(u):
    return tighten(run_pose(u, 1.6, 0.7))


def swipe_low(side):
    """the swing when it is crouched: wound back low along its flank, then across low and forward"""
    def fn(u):
        p = tighten(clip_idle(0.0))
        for sn, s in S.SIDES:
            if sn != side:
                continue
            wind = smooth(0.0, 0.34, u) * (1 - smooth(0.42, 0.5, u))
            thr = bell(0.42, 0.5, 0.62, 0.95, u)
            base = p["wrist"][sn]
            p["wrist"][sn] = base + V((-s * 0.2, -1.5, 1.2)) * wind + V((-s * 0.6, 4.0, -2.0)) * thr
            p["fk"]["arm_%s_2" % sn] = (0.2 + 0.4 * wind - 0.6 * thr, 0.0, 0.0)
        return p
    return fn


def clip_roar_low(u):
    env = smooth(0.0, 0.2, u) * (1 - smooth(0.78, 1.0, u))
    sh = math.sin(u * 2 * math.pi * 9) * bell(0.3, 0.38, 0.72, 0.85, u)
    p = tighten(clip_idle(0.0))
    p["fk"]["neck_0"] = (NECK_LOW[0] + 0.12 * env, 0.0, 0.04 * sh)
    p["fk"]["head"] = (0.22 - 0.1 * env + 0.08 * sh, 0.0, 0.22 * sh)
    for sn, s in S.SIDES:
        p["wrist"][sn] = p["wrist"][sn] + V((s * 0.9, 0.6, 0.6)) * env
        p["fk"]["arm_%s_2" % sn] = (0.2 + 0.3 * env, 0, 0)
    return p


CLIPS = {      # name: (frames, loop, fn)
    "idle": (90, True, clip_idle),
    "run": (24, True, clip_run),
    "wall_run": (24, True, clip_wall_run),
    "rear": (30, False, clip_rear),
    "swipe_l": (30, False, swipe("L")),
    "swipe_r": (30, False, swipe("R")),
    "strike": (30, False, clip_strike),
    "lunge": (39, False, clip_lunge),
    "roar": (66, False, clip_roar),
    "hit": (15, False, clip_hit),
    "reel": (48, False, clip_reel),
    "land": (30, False, clip_land),
    "climb": (48, True, clip_climb),
    "grab": (24, True, clip_grab),
    "fall": (30, True, clip_fall),
    "defeat": (75, False, clip_defeat),
    "idle_low": (90, True, clip_idle_low),
    "run_low": (24, True, clip_run_low),
    "swipe_l_low": (30, False, swipe_low("L")),
    "swipe_r_low": (30, False, swipe_low("R")),
    "roar_low": (66, False, clip_roar_low),
}


def _group(ob, i):
    g = max(ob.data.vertices[i].groups, key=lambda e: e.weight, default=None)
    return ob.vertex_groups[g.group].name if g else "?"


def measure(rig, ob, names, steps=12):
    """how high and how wide each clip reaches (max over sampled frames), from the skinned mesh itself"""
    import numpy as np
    sc = bpy.context.scene
    for t in rig.animation_data.nla_tracks:
        t.mute = True
    out = {}
    for name in names:
        act = bpy.data.actions[name]
        rig.animation_data.action = act
        try:
            rig.animation_data.action_slot = act.slots[0]
        except Exception:
            pass
        f0, f1 = act.frame_range
        hi, wide, lo = -1e9, 0.0, 1e9
        hi_by = wide_by = ""
        for i in range(steps + 1):
            sc.frame_set(int(round(f0 + (f1 - f0) * i / steps)))
            dg = bpy.context.evaluated_depsgraph_get()
            me = ob.evaluated_get(dg).to_mesh()
            co = np.empty(len(me.vertices) * 3, dtype=np.float32)
            me.vertices.foreach_get("co", co)
            co = co.reshape(-1, 3)
            iz, ix = int(co[:, 2].argmax()), int(np.abs(co[:, 0]).argmax())
            if co[iz, 2] > hi:
                hi, hi_by = float(co[iz, 2]), _group(ob, iz)
            if abs(co[ix, 0]) > wide:
                wide, wide_by = float(abs(co[ix, 0])), _group(ob, ix)
            lo = min(lo, float(co[:, 2].min()))
            ob.evaluated_get(dg).to_mesh_clear()
        out[name] = (round(hi, 2), round(wide, 2), round(lo, 2))
        print("MEASURE %-12s top %.2f (%s)  half-width %.2f (%s)  bottom %.2f" % (name, hi, hi_by, wide, wide_by, lo))
    rig.animation_data.action = None
    for t in rig.animation_data.nla_tracks:
        t.mute = False
    return out

KEYED = None


def apply(rig, pose):
    pbs = rig.pose.bones
    for pb in pbs:      # everything back to rest first
        pb.matrix_basis = Matrix.Identity(4)
    loc, rot = pose["root"]
    pbs["root"].location = rig.data.bones["root"].matrix_local.to_3x3().inverted() @ V(loc)
    pbs["root"].rotation_euler = rot
    for bn, e in pose["fk"].items():
        pbs[bn].rotation_euler = e
    bpy.context.view_layer.update()
    def resolve(p):
        if isinstance(p, tuple) and p and p[0] == "rel":
            _, bn, pt = p
            return pbs[bn].matrix @ rig.data.bones[bn].matrix_local.inverted() @ V(pt)
        return V(p)
    poles = pose.get("poles", {})
    pole = lambda bn: resolve(poles[bn]) if bn in poles else None
    for (k, sn), p in pose["feet"].items():
        bn = "leg_%d_%s_1" % (k, sn)
        solve(rig, bn, resolve(p), pole(bn))
    for sn, p in pose["wrist"].items():
        bn = "arm_%s_1" % sn
        solve(rig, bn, resolve(p), pole(bn))
    bpy.context.view_layer.update()


def capture(rig):
    """every clip, every frame: the local transform of every bone after IK"""
    data = {}
    for name, (n, loop, fn) in CLIPS.items():
        frames = []
        count = n if loop else n + 1
        for f in range(count):
            u = f / n
            apply(rig, fn(u))
            row = {}
            for pb in rig.pose.bones:
                m = rig.convert_space(pose_bone=pb, matrix=pb.matrix, from_space='POSE', to_space='LOCAL')
                row[pb.name] = (m.to_translation(), m.to_quaternion())
            frames.append(row)
        if loop:
            frames.append(frames[0])
        data[name] = frames
        print("captured", name, len(frames))
    return data


def write_actions(rig, data):
    for pb in rig.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    rig.animation_data_create()
    skip = tuple(S.PLATES) + ("shell_t", "shell_L", "shell_R")      # the view owns these (torn plates, the opening armour)
    for name, frames in data.items():
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        rig.animation_data.action = act
        prev = {}
        for f, row in enumerate(frames):
            for bn, (loc, q) in row.items():
                if bn in skip:
                    continue
                pb = rig.pose.bones[bn]
                if bn in prev and prev[bn].dot(q) < 0:
                    q = -q
                prev[bn] = q
                pb.rotation_quaternion = q
                pb.keyframe_insert("rotation_quaternion", frame=f + 1, group=bn)
                if bn == "root":
                    pb.location = loc
                    pb.keyframe_insert("location", frame=f + 1, group=bn)
        tr = rig.animation_data.nla_tracks.new()
        tr.name = name
        st = tr.strips.new(name, 1, act)
        try:
            st.action_slot = act.slots[0]
        except Exception:
            pass
        rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)


def export(path):
    import os
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')      # only the rig, the body and the markers (not the preview's ground, lights or reference boxes)
    rig = bpy.data.objects["sigil_rig"]
    rig.select_set(True)
    for o in rig.children:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False, export_yup=True, export_normals=True, export_tangents=False,
                              export_materials="EXPORT", export_vertex_color="NONE", export_all_vertex_colors=False, export_extras=False, export_cameras=False, export_lights=False,
                              export_skins=True, export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True, export_frame_range=False,
                              export_anim_single_armature=True, export_reset_pose_bones=True, export_optimize_animation_size=True, export_def_bones=False)
    return path
