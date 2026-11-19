## The folk kit's motion: poses built as rotations about each joint (in the rest pose's world axes), legs and arms placed by two-bone IK, written into Blender actions.
# A clip is a list of Pose objects, one per key; walk and run are one cycle each, left foot down at 0, played by phase in the game (so the feet stay planted at any speed).
import math
import bpy
from mathutils import Matrix, Vector, Euler

TAU = math.tau


def R(rx=0.0, ry=0.0, rz=0.0):
    """a rotation in degrees about the world axes, X then Y then Z"""
    return Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ").to_matrix()


def ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3.0 - 2.0 * t)


def _frame(a, p):
    a = a.normalized()
    p = (p - a * p.dot(a)).normalized()
    return Matrix((a, p, a.cross(p))).transposed()


def align(a_rest, a_new, p_rest, p_new):
    """the rotation taking direction a_rest to a_new, with p_rest (its side reference) going to p_new"""
    return _frame(a_new, p_new) @ _frame(a_rest, p_rest).transposed()


class Rig:
    """the rest skeleton of an armature object"""
    def __init__(self, arm):
        self.ob = arm
        ad = arm.data
        self.names = [b.name for b in ad.bones]
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in ad.bones}
        self.head = {b.name: b.head_local.copy() for b in ad.bones}
        self.tail = {b.name: b.tail_local.copy() for b in ad.bones}
        self.local = {b.name: b.matrix_local.copy() for b in ad.bones}
        order, seen = [], set()

        def visit(n):
            if n in seen:
                return
            if self.parent[n]:
                visit(self.parent[n])
            seen.add(n)
            order.append(n)
        for n in self.names:
            visit(n)
        self.order = order


class Pose:
    def __init__(self):
        self.delta = {}       # bone -> rotation about its joint, in its parent's posed frame
        self.world = {}       # bone -> rotation it must end with in the world (head kept level, a hand kept upright)
        self.offset = Vector((0.0, 0.0, 0.0))     # moves the root's child (the hips) and so everything
        self.ik = {}          # first bone of a two-bone chain -> (end target point, pole direction, end bone, end world rotation or None)

    def rot(self, b, rx=0.0, ry=0.0, rz=0.0):
        self.delta[b] = self.delta.get(b, Matrix.Identity(3)) @ R(rx, ry, rz)
        return self


def _T(v):
    return Matrix.Translation(v)


def solve(rig, pose):
    """{bone: 4x4 rest-to-posed transform}"""
    A, W = {}, {}
    chain_mid = {}
    for top, (tgt, pole, end, end_rot) in pose.ik.items():
        mid = next(n for n in rig.order if rig.parent[n] == top)
        chain_mid[top] = (mid, end, tgt, pole, end_rot)
    done_ik = {}
    for b in rig.order:
        p = rig.parent[b]
        Ap = A[p] if p else Matrix.Identity(4)
        Wp = W[p] if p else Matrix.Identity(3)
        h = rig.head[b]
        if b in done_ik:
            Wb = done_ik[b]
        elif b in chain_mid:
            mid, end, tgt, pole, end_rot = chain_mid[b]
            H = Ap @ h
            hm, he = rig.head[mid], rig.head[end]
            L1, L2 = (hm - h).length, (he - hm).length
            v = Vector(tgt) - H
            d = min(max(v.length, abs(L1 - L2) + 1e-4), L1 + L2 - 1e-4)
            dr = v.normalized()
            a = (L1 * L1 - L2 * L2 + d * d) / (2 * d)
            hh = math.sqrt(max(L1 * L1 - a * a, 0.0))
            pp = Vector(pole)
            pp = (pp - dr * pp.dot(dr)).normalized()
            K = H + dr * a + pp * hh
            E = H + dr * d
            prest = Vector(pole)          # the rest pose's own bend is small: the pole doubles as the rest side reference
            Wb = align(hm - h, K - H, prest, pp)
            done_ik[mid] = align(he - hm, E - K, prest, pp)
            if end_rot is not None:
                done_ik[end] = end_rot
        elif b in pose.world:
            Wb = pose.world[b]
        else:
            Wb = Wp @ pose.delta.get(b, Matrix.Identity(3))
        Rl = Wp.transposed() @ Wb
        local = _T(h) @ Rl.to_4x4() @ _T(-h)
        if p and rig.parent[p] is None:
            local = _T(pose.offset) @ local
        A[b] = Ap @ local
        W[b] = Wb
    return A


def write_action(rig, poses, name):
    """key one Blender action from the poses (frame i = pose i), linear between keys"""
    arm = rig.ob
    arm.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    prevq = {}
    for i, pose in enumerate(poses):
        A = solve(rig, pose)
        for b in rig.order:
            p = rig.parent[b]
            Ap = A[p] if p else Matrix.Identity(4)
            delta = Ap.inverted() @ A[b]
            basis = rig.local[b].inverted() @ delta @ rig.local[b]
            pb = arm.pose.bones[b]
            loc, q, _ = basis.decompose()
            if b in prevq and q.dot(prevq[b]) < 0:
                q.negate()
            prevq[b] = q
            pb.location = loc
            pb.rotation_quaternion = q
            pb.keyframe_insert("location", frame=i, group=b)
            pb.keyframe_insert("rotation_quaternion", frame=i, group=b)
    try:
        for fc in _fcurves(act):
            for k in fc.keyframe_points:
                k.interpolation = "LINEAR"
    except Exception:
        pass
    return act


def _fcurves(act):
    if hasattr(act, "fcurves") and len(act.fcurves):
        return list(act.fcurves)
    out = []
    for layer in getattr(act, "layers", []):
        for strip in layer.strips:
            for cb in strip.channelbags:
                out.extend(cb.fcurves)
    return out


# ---------------------------------------------------------------------------------------------------- bipeds

class Leg:
    """a leg's names and the points of its foot: `ball` touches the ground and is what the foot rolls about"""
    def __init__(self, thigh, shin, foot, ball, side):
        self.thigh, self.shin, self.foot, self.ball, self.side = thigh, shin, foot, Vector(ball), side


def biped_walk(rig, pose, u, g, legs):
    """the common body of a walk or run at phase u (0..1, left foot down at 0). g: stride, stance, foot_x, lift, bob, drop, sway, roll, yaw, counter, lean, toe_off, toe_out"""
    S, beta = g["stride"], g["stance"]
    pose.offset = Vector((g["sway"] * math.sin(TAU * u), 0.0, -g["drop"] + g["bob"] * math.cos(2 * TAU * (u - beta * 0.5))))
    roll = -g["roll"] * math.sin(TAU * u)
    yaw = -g["yaw"] * math.cos(TAU * u)
    pose.rot("hips", g["lean"], roll, yaw)
    pose.rot("spine", g.get("spine_lean", 0.0), -roll * 0.45, -yaw * 0.5 * g["counter"])
    pose.rot("chest", 0.0, -roll * 0.35, -yaw * 0.7 * g["counter"])
    for lg in legs:
        s = 1.0 if lg.side == "L" else -1.0
        uu = (u + (0.0 if lg.side == "L" else 0.5)) % 1.0
        if uu < beta:
            fy = -S * beta / 2 + S * uu
            lift = 0.0
            pitch = g["toe_off"] * ease((uu - (beta - 0.18)) / 0.18)
        else:
            t = (uu - beta) / (1.0 - beta)
            fy = S * beta / 2 - S * beta * ease(t)
            lift = g["lift"] * math.sin(math.pi * t) ** 0.8
            pitch = g["toe_off"] * (1.0 - ease(t * 1.6)) - g.get("swing_point", 0.0) * math.sin(math.pi * t)
        wf = R(0, 0, s * g["toe_out"]) @ R(pitch, 0, 0)
        ball = Vector((s * g["foot_x"], fy, lift))
        ankle = ball + wf @ (rig.head[lg.foot] - lg.ball)
        pose.ik[lg.thigh] = (ankle, Vector((s * 0.15, -1.0, 0.0)), lg.foot, wf)
    return roll, yaw


def stand(rig, pose, legs, feet, hip_shift=(0.0, 0.0, 0.0), roll=0.0, yaw=0.0):
    """feet planted where given ({side: (ball point, yaw degrees)}), hips shifted and tilted"""
    pose.offset = Vector(hip_shift)
    pose.rot("hips", 0.0, roll, yaw)
    for lg in legs:
        s = 1.0 if lg.side == "L" else -1.0
        bp, fyaw = feet[lg.side]
        wf = R(0, 0, fyaw)
        ankle = Vector(bp) + wf @ (rig.head[lg.foot] - lg.ball)
        pose.ik[lg.thigh] = (ankle, Vector((s * 0.15, -1.0, 0.0)), lg.foot, wf)
