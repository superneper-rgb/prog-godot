# Bakes Prog V1's real grips into player/v1_grips.json: palm on each gun's real handle, fingers closed until they touch its mesh, index on the trigger, with clipping reported. python tools/v1_grips/bake.py [gun ...]
import json, math, os, struct, sys
import numpy as np
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'player', 'v1_grips.json')
MODEL = os.path.join(ROOT, 'assets', 'prog.glb')
def fb(f, k, sd): return f'{f}_0{k}.{sd}'
# measured off side-on grids of each gun, model units: handle = (z, y, tilt degrees, depth, width), trig = (z, y). left: ('v', z, y, tilt, depth, width) a vertical grip, ('u', z, y) under a handguard
GUNS = {
    'rifle': dict(handle=(-0.093, -0.145, 16, 0.065, 0.05), trig=(-0.01, -0.09), left=('u', 0.40, -0.17)),
    'shotgun': dict(handle=(-0.12, -0.115, 19, 0.045, 0.046), trig=(-0.03, -0.055), left=('u', 0.25, -0.075)),
    'sniper': dict(handle=(-0.175, -0.105, 13, 0.045, 0.045), trig=(-0.108, -0.06), left=('u', 0.10, -0.04)),
    'legacy_rifle': dict(handle=(-0.12, -0.115, 13, 0.05, 0.04), trig=(-0.06, -0.07), left=('u', 0.19, -0.03)),
    'legacy_smg': dict(handle=(-0.092, -0.105, 12, 0.05, 0.04), trig=(-0.02, -0.065), left=('v', 0.22, -0.085, 0, 0.05, 0.04)),
    'legacy_sniper': dict(handle=(-0.125, -0.115, 16, 0.045, 0.04), trig=(-0.05, -0.07), left=('u', 0.11, -0.03)),
    'smg': dict(handle=(-0.103, -0.095, 16, 0.045, 0.04), trig=(-0.01, -0.065), left=('v', 0.072, -0.12, 0, 0.045, 0.04)),
    'saw': dict(handle=(-0.067, -0.128, 6, 0.06, 0.045), trig=(-0.012, -0.075), left=('v', 0.2, -0.045, 0, 0.025, 0.025)),
    'yoke': dict(handle=(-0.067, -0.09, 0, 0.035, 0.03), trig=(-0.035, -0.065), left=('v', 0.15, -0.085, 0, 0.03, 0.03)),
    'arc': dict(handle=(-0.085, -0.13, 5, 0.07, 0.045), trig=(-0.015, -0.075), left=('v', 0.24, -0.115, 0, 0.05, 0.04)),
    'bellows': dict(handle=(-0.106, -0.145, 0, 0.07, 0.06), trig=(-0.05, -0.075), left=('v', 0.26, -0.115, 0, 0.05, 0.04)),
    'deagle': dict(handle=(-0.08, -0.118, 8, 0.1, 0.05), trig=(0.015, -0.06)),
    'pistol': dict(handle=(-0.067, -0.08, 6, 0.05, 0.035), trig=(-0.005, -0.025)),
    'legacy_deagle': dict(handle=(-0.088, -0.078, 14, 0.085, 0.04), trig=(0.04, -0.02)),
}
FINGERS = ['index', 'middle', 'ring', 'pinky', 'thumb']

def load_glb(p):
    r = open(p, 'rb').read(); n = struct.unpack('<I', r[12:16])[0]; j = json.loads(r[20:20 + n]); return j, r[20 + n + 8:]
def acc(j, b, i):
    a = j['accessors'][i]; v = j['bufferViews'][a['bufferView']]; w = dict(SCALAR=1, VEC2=2, VEC3=3, VEC4=4, MAT4=16)[a['type']]
    ct = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H', 5125: 'I', 5126: 'f'}[a['componentType']]; size = struct.calcsize(ct)
    off = v.get('byteOffset', 0) + a.get('byteOffset', 0); stride = v.get('byteStride', 0) or size * w
    arr = np.frombuffer(b, dtype=np.dtype('<' + ct), count=None if stride == size * w else None, offset=off) if False else None
    if stride == size * w:
        arr = np.frombuffer(b, dtype='<' + ct, count=a['count'] * w, offset=off).reshape(a['count'], w)
    else:
        arr = np.stack([np.frombuffer(b, dtype='<' + ct, count=w, offset=off + k * stride) for k in range(a['count'])])
    return arr.astype(np.float64) if ct == 'f' else arr
def qmat(q):
    x, y, z, w = q; return np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)], [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)], [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
def mat_q(R):
    t = np.trace(R)
    if t > 0:
        s = math.sqrt(t + 1) * 2; return np.array([(R[2, 1] - R[1, 2]) / s, (R[0, 2] - R[2, 0]) / s, (R[1, 0] - R[0, 1]) / s, s / 4])
    i = int(np.argmax(np.diag(R))); j_, k = (i + 1) % 3, (i + 2) % 3
    s = math.sqrt(1 + R[i, i] - R[j_, j_] - R[k, k]) * 2; q = np.zeros(4); q[i] = s / 4; q[j_] = (R[j_, i] + R[i, j_]) / s; q[k] = (R[k, i] + R[i, k]) / s; q[3] = (R[k, j_] - R[j_, k]) / s
    return q
def node_m(nd):
    M = np.eye(4)
    if 'matrix' in nd: return np.array(nd['matrix']).reshape(4, 4).T
    M[:3, :3] = qmat(nd.get('rotation', [0, 0, 0, 1])) * np.array(nd.get('scale', [1, 1, 1]))[None, :]; M[:3, 3] = nd.get('translation', [0, 0, 0]); return M
def rot_x(a):
    c, s = math.cos(a), math.sin(a); return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
def rot_z(a):
    c, s = math.cos(a), math.sin(a); return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
def rot_axis(ax, a):
    ax = ax / np.linalg.norm(ax); K = np.array([[0, -ax[2], ax[1]], [ax[2], 0, -ax[0]], [-ax[1], ax[0], 0]]); return np.eye(3) + math.sin(a) * K + (1 - math.cos(a)) * K @ K
# ---- his hand, as it is in the file
class Hand:
    def __init__(self, sd):
        j, b = load_glb(MODEL); self.sd = sd
        nodes = j['nodes']; par = {c: i for i, n in enumerate(nodes) for c in n.get('children', [])}
        def world(i): return (world(par[i]) @ node_m(nodes[i])) if i in par else node_m(nodes[i])
        byname = {n.get('name'): i for i, n in enumerate(nodes)}
        self.W = {nm: world(byname[nm]) for nm in byname if nm and (nm.endswith('.' + sd))}
        self.local = {nm: node_m(nodes[byname[nm]]) for nm in self.W}
        skin = j['skins'][0]; joints = [nodes[i]['name'] for i in skin['joints']]
        names = ['hand.' + sd] + [fb(f, k, sd) for f in FINGERS for k in (1, 2, 3)]
        self.verts = {nm: [] for nm in names}
        for m in j['meshes']:
            for p in m['primitives']:
                if j['materials'][p['material']]['name'] != 'bk_skin': continue
                P = acc(j, b, p['attributes']['POSITION']); J = acc(j, b, p['attributes']['JOINTS_0']); Wt = acc(j, b, p['attributes']['WEIGHTS_0']).astype(float)
                if Wt.max() > 1.5: Wt = Wt / 255.0
                top = J[np.arange(len(J)), Wt.argmax(1)]
                for i in range(len(P)):
                    nm = joints[int(top[i])]
                    if nm in self.verts: self.verts[nm].append(P[i])
        self.Hinv = np.linalg.inv(self.W['hand.' + sd])
        # each bone's verts in its own frame
        self.vl = {nm: (np.linalg.inv(self.W[nm])[:3, :3] @ np.array(v).T).T + np.linalg.inv(self.W[nm])[:3, 3] for nm, v in self.verts.items() if v}
        self.thumb_side = 1.0 if (self.Hinv[:3, :3] @ self.W[fb('thumb', 1, sd)][:3, 3] + self.Hinv[:3, 3])[2] > 0 else -1.0
        idx = self.Hinv[:3, :3] @ self.W[fb('middle', 1, sd)][:3, 3] + self.Hinv[:3, 3]
        self.mcp = float(idx[1])
        hv = self.vl['hand.' + sd]; self.palm_half = float(np.percentile(np.abs(hv[:, 0]), 92))
        # which way is the back of the hand in bone X: the fingers curl away from it
        self.back = -1.0 if (self.Hinv[:3, :3] @ self.W[fb('middle', 3, sd)][:3, 3] + self.Hinv[:3, 3])[0] > 0 else 1.0
    def finger_points(self, f, curls, spread=0.0):
        """hand frame points of one finger with curls (radians about each joint's X, added to rest), and each joint's rotation"""
        M = np.eye(4); out = []; tip = None; qs = []
        for k, a in enumerate(curls):
            nm = fb(f, k + 1, self.sd)
            L = self.local[nm] if k else (self.Hinv @ self.W[nm])
            R_ = rot_x(a * self.curl_sign(f))
            if k == 0 and spread: R_ = R_ @ rot_z(spread)
            M2 = np.eye(4); M2[:3, :3] = R_
            M = M @ L @ M2; qs.append(R_)
            v = self.vl.get(nm)
            if v is not None and len(v): out.append((M[:3, :3] @ v.T).T + M[:3, 3])
            if k == 2 and v is not None and len(v): tip = ((M[:3, :3] @ v.T).T + M[:3, 3])[np.argmax(v[:, 1])]
        return (np.concatenate(out) if out else np.zeros((0, 3))), tip, qs
    def curl_sign(self, f):
        return 1.0
    def palm_points(self): return self.vl['hand.' + self.sd]
# ---- a gun's real surface
class Gun:
    def __init__(self, id_):
        j, b = load_glb(os.path.join(ROOT, 'assets', 'weapons', id_ + '.glb')); nodes = j['nodes']
        tris = []
        def walk(i, M):
            M2 = M @ node_m(nodes[i]); nd = nodes[i]
            if 'display' in nd.get('name', ''): return
            if 'mesh' in nd:
                for p in j['meshes'][nd['mesh']]['primitives']:
                    P = acc(j, b, p['attributes']['POSITION']); idx = acc(j, b, p['indices']).reshape(-1) if 'indices' in p else np.arange(len(P))
                    W = (M2[:3, :3] @ P.T).T + M2[:3, 3]; tris.append(W[idx.reshape(-1, 3)])
            for c in nd.get('children', []): walk(c, M2)
        for r_ in j['scenes'][j.get('scene', 0)]['nodes']: walk(r_, np.eye(4))
        self.T = np.concatenate(tris); self.lo, self.hi = self.T.min((0, 1)), self.T.max((0, 1))
    def near(self, c, rad):
        mid = self.T.mean(1); keep = np.linalg.norm(mid - c, axis=1) < rad + np.linalg.norm(self.T - mid[:, None], axis=2).max(1)
        return self.T[keep]
def signed(pts, T):
    """for each point, distance to the nearest triangle, negative when behind its face"""
    if len(T) == 0 or len(pts) == 0: return np.full(len(pts), 9.0)
    a, b, c = T[:, 0], T[:, 1], T[:, 2]; ab, ac = b - a, c - a; n = np.cross(ab, ac); ln = np.linalg.norm(n, axis=1); ok = ln > 1e-10
    a, b, c, ab, ac, n, ln = a[ok], b[ok], c[ok], ab[ok], ac[ok], n[ok], ln[ok]; n = n / ln[:, None]
    res = np.zeros(len(pts))
    for i, p in enumerate(pts):
        ap = p - a; d1 = (ab * ap).sum(1); d2 = (ac * ap).sum(1); d11 = (ab * ab).sum(1); d12 = (ab * ac).sum(1); d22 = (ac * ac).sum(1)
        den = d11 * d22 - d12 * d12; v = (d22 * d1 - d12 * d2) / np.maximum(den, 1e-14); w = (d11 * d2 - d12 * d1) / np.maximum(den, 1e-14)
        u_ = 1 - v - w; v = np.clip(v, 0, 1); w = np.clip(w, 0, 1 - v); q = a + ab * v[:, None] + ac * w[:, None]
        e = p - q; dist = np.linalg.norm(e, axis=1); k = int(dist.argmin()); s = 1.0 if (e[k] * n[k]).sum() >= 0 else -1.0
        res[i] = dist[k] * s
    return res
def thin(p, n):
    return p[:: max(1, len(p) // n)]
def frame(T_, D_, hand):
    """the hand's bone rotation in gun axes from its back-of-hand and finger directions"""
    D_ = D_ / np.linalg.norm(D_); T_ = T_ - D_ * T_.dot(D_); T_ /= np.linalg.norm(T_)
    X = T_ * hand.back; Y = D_; Z = np.cross(X, Y)
    return np.stack([X, Y, Z], 1)
def place(hand, gun, R, wrist0, center, axes, rng=0.03, step=0.006):
    """slide the palm until it lies against the surface, not in it"""
    near = gun.near(center, 0.3); pv = thin(hand.palm_points(), 90); best = None
    for dT in np.arange(-rng, rng * 1.01, step):
        for dD in np.arange(-rng, rng * 1.01, step):
            w = wrist0 + axes[0] * dT + axes[1] * dD
            s = signed((R @ pv.T).T + w, near); depth = max(0.0, -s.min()); gap = max(0.0, s.min())
            cost = depth * 40 + gap * 8 + (abs(dT) + abs(dD)) * 0.5
            if best is None or cost < best[0]: best = (cost, w, depth, gap)
    return best[1], best[2], best[3], near
def close_finger(hand, f, R, w, near, ignore_near=None, ratio=(1.0, 1.15, 0.8), lim=1.75):
    """close a finger from open until it touches the mesh"""
    last = None
    for c in np.arange(-0.5, lim, 0.05):
        cs = (c * ratio[0], c * ratio[1], c * ratio[2])
        p, tip, qs = hand.finger_points(f, cs); pw = (R @ thin(p, 40).T).T + w
        s = signed(pw, near)
        if s.min() < -0.002 and last is not None: break
        last = (cs, qs, float(max(0.0, -s.min())), float(s.min()))
    return last if last else (cs, qs, float(max(0.0, -s.min())), float(s.min()))
def solve_index(hand, R, w, trig, near):
    """the index goes in through the guard and its pad lands on the trigger: searched on the tip first, then the mesh"""
    grid = []
    for a1 in np.arange(-0.5, 1.5, 0.15):
        for a2 in np.arange(-0.3, 1.6, 0.2):
            for a3 in np.arange(-0.2, 1.2, 0.2):
                for sp in (-0.2, -0.1, 0.0, 0.1, 0.2):
                    p, tip, qs = hand.finger_points('index', (a1, a2, a3), sp)
                    if tip is None: continue
                    grid.append((np.linalg.norm((R @ tip) + w - trig), a1, a2, a3, sp))
    grid.sort(key=lambda e: e[0]); best = None
    away = near[np.linalg.norm(near.mean(1) - trig, axis=1) > 0.012]
    for d, a1, a2, a3, sp in grid[:30]:
        p, tip, qs = hand.finger_points('index', (a1, a2, a3), sp); s = signed((R @ thin(p, 40).T).T + w, away); depth = max(0.0, -s.min())
        cost = d * 3 + depth * 12
        if best is None or cost < best[0]: best = (cost, (a1, a2, a3), sp, d, depth, qs)
    return best
def solve_thumb(hand, R, w, near, goal):
    """the thumb closes over the far side of what the hand holds: its tip goes to the goal, turned across the palm, without going in"""
    grid = []
    for sp in np.arange(-0.9, 0.91, 0.15):
        for a1 in np.arange(-0.5, 1.1, 0.15):
            for a2 in np.arange(-0.2, 1.3, 0.2):
                for a3 in np.arange(-0.2, 1.3, 0.2):
                    p, tip, qs = hand.finger_points('thumb', (a1, a2, a3), sp)
                    if tip is not None: grid.append((float(np.linalg.norm((R @ tip) + w - goal)), a1, a2, a3, sp))
    grid.sort(key=lambda e: e[0]); best = None
    for d, a1, a2, a3, sp in grid[:40]:
        p, tip, qs = hand.finger_points('thumb', (a1, a2, a3), sp); s = signed((R @ thin(p, 25).T).T + w, near); depth = max(0.0, -s.min())
        cost = d * 4 + depth * 25
        if best is None or cost < best[0]: best = (cost, (a1, a2, a3), depth, d, qs)
    return best
def bake(id_):
    g = GUNS[id_]; gun = Gun(id_); out = {}; rep = {}
    # right hand: palm on the handle's right side, knuckles round its front, fingers along the handle
    hz, hy, tilt, hd, hw = g['handle']; t = math.radians(tilt); HC = np.array([0.0, hy, hz])
    hand = Hand('R'); D_ = np.array([0.0, -math.sin(t), math.cos(t)]); T_ = np.array([-1.0, 0.0, 0.0])
    yr = math.radians(12.0); ax = np.array([0.0, math.cos(t), math.sin(t)]); Rot = rot_axis(ax, yr); D_, T_ = Rot @ D_, Rot @ T_
    R = frame(T_, D_, hand)
    w0 = HC + D_ * (hd / 2 + 0.006 - hand.mcp) + T_ * (hw / 2 + hand.palm_half)
    w, depth, gap, near = place(hand, gun, R, w0, HC, (T_, D_))
    side = {'p': w.tolist(), 'q': mat_q(R).tolist()}; f15 = []; r_ = {'palm': round(depth * 100, 1), 'gap': round(gap * 100, 1)}
    tr = np.array([0.0, g['trig'][1], g['trig'][0]])
    bi = solve_index(hand, R, w, tr, near); r_['tip_to_trigger'] = round(bi[3] * 100, 1); r_['index_clip'] = round(bi[4] * 100, 1)
    fingers = {'index': bi[5]}
    for f in ('middle', 'ring', 'pinky'):
        c = close_finger(hand, f, R, w, near); fingers[f] = c[1]; r_[f] = round(c[2] * 100, 1)
    th = solve_thumb(hand, R, w, near, HC + ax * (hd * 0.15 + 0.03) - T_ * (hw / 2 + 0.008)); fingers['thumb'] = th[4]; r_['thumb'] = round(th[2] * 100, 1); r_['thumb_gap'] = round(th[3] * 100, 1)
    for f in FINGERS:
        for Q in fingers[f]: f15.append(mat_q(Q).round(5).tolist())
    side['f'] = f15; out['r'] = side; rep['r'] = r_
    # left hand
    lf = g.get('left')
    if lf:
        hand = Hand('L')
        if lf[0] == 'v':
            lz, ly, lt, ld, lw = lf[1:]; t2 = math.radians(lt); P = np.array([0.0, ly, lz])
            D_ = np.array([0.0, -math.sin(t2), math.cos(t2)]); T_ = np.array([1.0, 0.0, 0.0]); ax = np.array([0.0, math.cos(t2), math.sin(t2)]); Rot = rot_axis(ax, -math.radians(25)); D_, T_ = Rot @ D_, Rot @ T_
            w0 = P + D_ * (ld / 2 + 0.006 - hand.mcp) + T_ * (lw / 2 + hand.palm_half)
        else:      # a C grip: the palm on the handguard's side, thumb over the top, fingers under
            lz, ly = lf[1:3]; P = np.array([0.0, ly, lz]); D_ = np.array([-0.25, -0.45, 0.85]); T_ = np.array([0.9, -0.35, 0.25])
            w0 = P - D_ * (hand.mcp * 0.75) + T_ * (hand.palm_half + 0.03)
        R = frame(T_, D_, hand); D2 = R[:, 1]; T2 = R[:, 0] * hand.back
        w, depth, gap, near = place(hand, gun, R, w0, P, (T2, D2))
        side = {'p': w.tolist(), 'q': mat_q(R).tolist()}; fingers = {}; r_ = {'palm': round(depth * 100, 1), 'gap': round(gap * 100, 1)}
        for f in ('index', 'middle', 'ring', 'pinky'):
            c = close_finger(hand, f, R, w, near); fingers[f] = c[1]; r_[f] = round(c[2] * 100, 1)
        th = solve_thumb(hand, R, w, near, P + np.array([-0.012, 0.075, 0.03])); fingers['thumb'] = th[4]; r_['thumb'] = round(th[2] * 100, 1); r_['thumb_gap'] = round(th[3] * 100, 1)
        side['f'] = [mat_q(Q).round(5).tolist() for f in FINGERS for Q in fingers[f]]; out['l'] = side; rep['l'] = r_
    return out, rep
if __name__ == '__main__':
    ids = sys.argv[1:] or list(GUNS)
    data = json.load(open(OUT)) if os.path.exists(OUT) else {}
    for id_ in ids:
        data[id_], rep = bake(id_); print(id_, rep, flush=True)
    json.dump(data, open(OUT, 'w'), separators=(',', ':'))
