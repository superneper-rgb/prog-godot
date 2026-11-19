## The folk kit's clay: signed distance shapes (numpy) that blend into one smooth surface, each surface point tagged with the part it belongs to.
# Every shape answers eval(P) -> (d, part) for P an (N, 3) float32 array: d < 0 inside, part an int16 array of part ids (see Parts).
# Blender space: metres, Z up, the figure faces -Y, its left is +X (the glTF exporter turns this into Godot's +Z forward, left +X).
# Shapes carry an axis-aligned bound so a union only evaluates a child on the points near it: that is what keeps a 60-shape figure fast.
import numpy as np

BIG = 1e3
F = np.float32


def v3(x):
    return np.asarray(x, dtype=F).reshape(3)


def _len(a):
    return np.sqrt(np.einsum("ij,ij->i", a, a))


def _dot(a, b):
    return np.einsum("ij,ij->i", a, b)


def smin(a, b, k):
    """polynomial smooth minimum: a fillet of radius ~k where two shapes meet"""
    if k <= 0.0:
        return np.minimum(a, b)
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def smax(a, b, k):
    return -smin(-a, -b, k)


def rot(rx=0.0, ry=0.0, rz=0.0):
    """rotation matrix from Euler angles in degrees (applied X, then Y, then Z)"""
    x, y, z = np.radians([rx, ry, rz])
    cx, sx, cy, sy, cz, sz = np.cos(x), np.sin(x), np.cos(y), np.sin(y), np.cos(z), np.sin(z)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return (Rz @ Ry @ Rx).astype(F)


def frame(fwd, up):
    """rotation whose local +Z is `fwd` and local +Y leans to `up` (for shapes laid along a direction)"""
    z = v3(fwd) / np.linalg.norm(fwd)
    x = np.cross(v3(up), z)
    if np.linalg.norm(x) < 1e-6:
        x = np.cross(v3((1, 0, 0)), z)
    x /= np.linalg.norm(x)
    y = np.cross(z, x)
    return np.stack([x, y, z], axis=1).astype(F)


def basis(z_dir, y_dir):
    """local-to-world rotation whose local +Z is z_dir and local +Y leans to y_dir (x = y cross z): aims a hand, a prop, a fin"""
    z = v3(z_dir) / np.linalg.norm(z_dir)
    y = v3(y_dir) - z * float(v3(y_dir) @ z)
    y /= np.linalg.norm(y)
    x = np.cross(y, z)
    return np.stack([x, y, z], 1).astype(F)


def place(child, at, R):
    """a shape built about the origin in its own frame, set down at `at` turned by R (local to world)"""
    return Move(child, R=R, pivot=(0, 0, 0), t=at)


class Shape:
    lo = np.full(3, -BIG, F)
    hi = np.full(3, BIG, F)
    part = 0

    def dist(self, P):
        raise NotImplementedError

    def eval(self, P):
        d = self.dist(P)
        return d, np.full(len(P), self.part, np.int16)

    def bound(self):
        return self.lo, self.hi

    # sugar for building recipes
    def __or__(self, o):
        return Union([self, o])

    def tag(self, part):
        self.part = part
        return self


# ---------------------------------------------------------------------------------------------------- primitives

class Sphere(Shape):
    def __init__(self, c, r, part=0):
        self.c, self.r, self.part = v3(c), F(r), part
        self.lo, self.hi = self.c - r, self.c + r

    def dist(self, P):
        return _len(P - self.c) - self.r


class Ellipsoid(Shape):
    """radii along the local axes of `R` (iq's bound-correct approximation)"""
    def __init__(self, c, radii, R=None, part=0):
        self.c, self.rad, self.part = v3(c), v3(radii), part
        self.R = np.eye(3, dtype=F) if R is None else np.asarray(R, F)
        m = float(self.rad.max())
        self.lo, self.hi = self.c - m, self.c + m

    def dist(self, P):
        q = (P - self.c) @ self.R
        k0 = _len(q / self.rad)
        k1 = _len(q / (self.rad * self.rad))
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


class RoundCone(Shape):
    """a capsule whose radius runs from r1 at a to r2 at b (iq sdRoundCone): limbs, necks, fingers"""
    def __init__(self, a, b, r1, r2=None, part=0):
        self.a, self.b, self.r1 = v3(a), v3(b), F(r1)
        self.r2 = F(r1 if r2 is None else r2)
        self.part = part
        m = max(self.r1, self.r2)
        self.lo, self.hi = np.minimum(self.a, self.b) - m, np.maximum(self.a, self.b) + m

    def dist(self, P):
        a, b, r1, r2 = self.a, self.b, self.r1, self.r2
        ba = b - a
        l2 = F(ba @ ba)
        rr = r1 - r2
        a2 = l2 - rr * rr
        il2 = 1.0 / l2
        pa = P - a
        y = pa @ ba
        z = y - l2
        x2v = pa * l2 - np.outer(y, ba)
        x2 = _dot(x2v, x2v)
        y2 = y * y * l2
        z2 = z * z * l2
        k = np.sign(rr) * rr * rr * x2
        d3 = (np.sqrt(np.maximum(x2 * a2 * il2, 0.0)) + y * rr) * il2 - r1
        d1 = np.sqrt(x2 + z2) * il2 - r2
        d2 = np.sqrt(x2 + y2) * il2 - r1
        return np.where(np.sign(z) * a2 * z2 > k, d1, np.where(np.sign(y) * a2 * y2 < k, d2, d3))


class CappedCone(Shape):
    """a flat-ended truncated cone from a (radius ra) to b (radius rb), edges rounded by rr (iq sdCappedCone): cups, cans, heels, pots"""
    def __init__(self, a, b, ra, rb, rr=0.0, part=0):
        a, b = v3(a), v3(b)
        ab = (b - a) / np.linalg.norm(b - a)
        self.a, self.b = a + ab * rr, b - ab * rr
        self.ra, self.rb, self.rr, self.part = F(ra - rr), F(rb - rr), F(rr), part
        m = max(ra, rb) + rr
        self.lo, self.hi = np.minimum(a, b) - m, np.maximum(a, b) + m

    def dist(self, P):
        a, b, ra, rb = self.a, self.b, self.ra, self.rb
        rba = rb - ra
        ba = b - a
        baba = F(ba @ ba)
        pa = P - a
        papa = _dot(pa, pa)
        paba = (pa @ ba) / baba
        x = np.sqrt(np.maximum(papa - paba * paba * baba, 0.0))
        cax = np.maximum(0.0, x - np.where(paba < 0.5, ra, rb))
        cay = np.abs(paba - 0.5) - 0.5
        k = rba * rba + baba
        f = np.clip((rba * (x - ra) + paba * baba) / k, 0.0, 1.0)
        cbx = x - ra - f * rba
        cby = paba - f
        s = np.where((cbx < 0.0) & (cay < 0.0), -1.0, 1.0)
        return s * np.sqrt(np.minimum(cax * cax + cay * cay * baba, cbx * cbx + cby * cby * baba)) - self.rr


class Box(Shape):
    """a box with rounded edges: `half` its half size, `rr` the edge radius"""
    def __init__(self, c, half, rr=0.0, R=None, part=0):
        self.c, self.half, self.rr, self.part = v3(c), v3(half), F(rr), part
        self.R = np.eye(3, dtype=F) if R is None else np.asarray(R, F)
        m = float(np.linalg.norm(self.half))
        self.lo, self.hi = self.c - m, self.c + m

    def dist(self, P):
        q = np.abs((P - self.c) @ self.R) - (self.half - self.rr)
        return _len(np.maximum(q, 0.0)) + np.minimum(q.max(axis=1), 0.0) - self.rr


class Torus(Shape):
    """ring of radius R and tube radius r around the local Z axis of `Rm`"""
    def __init__(self, c, R, r, Rm=None, part=0):
        self.c, self.R, self.r, self.part = v3(c), F(R), F(r), part
        self.M = np.eye(3, dtype=F) if Rm is None else np.asarray(Rm, F)
        m = R + r
        self.lo, self.hi = self.c - m, self.c + m

    def dist(self, P):
        q = (P - self.c) @ self.M
        a = np.sqrt(q[:, 0] ** 2 + q[:, 1] ** 2) - self.R
        return np.sqrt(a * a + q[:, 2] ** 2) - self.r


class Gem(Shape):
    """a rounded double pyramid: each half-axis its own extent (x-, x+, y-, y+, z-, z+), `soft` 0 = faceted .. 1 = ellipsoid. Heads, beaks, crests."""
    def __init__(self, c, ext, soft=0.3, R=None, edge=0.0, part=0):
        """edge: the radius the facets' meeting creases are rounded to (0 = knife-sharp)"""
        self.c, self.ext, self.soft, self.part = v3(c), np.asarray(ext, F).reshape(6), F(soft), part
        self.R = np.eye(3, dtype=F) if R is None else np.asarray(R, F)
        self.edge = F(edge)
        m = float(self.ext.max())
        self.lo, self.hi = self.c - m, self.c + m

    def dist(self, P):
        q = (P - self.c) @ self.R
        e = self.ext
        sx = np.where(q[:, 0] < 0, e[0], e[1])
        sy = np.where(q[:, 1] < 0, e[2], e[3])
        sz = np.where(q[:, 2] < 0, e[4], e[5])
        a = np.sqrt(q * q + self.edge * self.edge) - self.edge if self.edge > 0 else np.abs(q)
        s = a[:, 0] / sx + a[:, 1] / sy + a[:, 2] / sz
        d_oct = (s - 1.0) / np.sqrt(1.0 / sx ** 2 + 1.0 / sy ** 2 + 1.0 / sz ** 2)
        r = np.stack([sx, sy, sz], 1)
        k0 = _len(q / r)
        k1 = _len(q / (r * r))
        d_ell = k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)
        return d_oct * (1.0 - self.soft) + d_ell * self.soft


class Slab(Shape):
    """a flat plate: a 2D polygon (u, v) extruded `t` each side along the local Z of `R`, edges rounded by rr. Lapels, collars, fins, soles, buckles."""
    def __init__(self, c, poly, t, rr=0.0, R=None, part=0):
        self.c, self.poly, self.t, self.rr, self.part = v3(c), np.asarray(poly, F), F(t), F(rr), part
        self.R = np.eye(3, dtype=F) if R is None else np.asarray(R, F)
        m = float(np.abs(self.poly).max() + t + rr)
        self.lo, self.hi = self.c - m, self.c + m

    def dist(self, P):
        q = (P - self.c) @ self.R
        u, v = q[:, 0], q[:, 1]
        vs = self.poly
        n = len(vs)
        d = (u - vs[0, 0]) ** 2 + (v - vs[0, 1]) ** 2
        s = np.ones_like(u)
        j = n - 1
        for i in range(n):
            ex, ey = vs[j, 0] - vs[i, 0], vs[j, 1] - vs[i, 1]
            wx, wy = u - vs[i, 0], v - vs[i, 1]
            h = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey), 0.0, 1.0)
            bx, by = wx - ex * h, wy - ey * h
            d = np.minimum(d, bx * bx + by * by)
            c1 = v >= vs[i, 1]
            c2 = v < vs[j, 1]
            c3 = ex * wy > ey * wx
            flip = (c1 & c2 & c3) | (~c1 & ~c2 & ~c3)
            s = np.where(flip, -s, s)
            j = i
        d2 = s * np.sqrt(d) + self.rr
        w = np.abs(q[:, 2]) - (self.t - self.rr)
        out = np.sqrt(np.maximum(d2, 0.0) ** 2 + np.maximum(w, 0.0) ** 2)
        return out + np.minimum(np.maximum(d2, w), 0.0) - self.rr


class Half(Shape):
    """the half-space behind a plane: points with dot(P - c, n) < 0 are inside"""
    def __init__(self, c, n, part=0):
        self.c = v3(c)
        self.n = v3(n) / np.linalg.norm(n)
        self.part = part

    def dist(self, P):
        return (P - self.c) @ self.n


# ---------------------------------------------------------------------------------------------------- combinations

def _cull(child, P, margin):
    lo, hi = child.bound()
    m = np.all((P >= lo - margin) & (P <= hi + margin), axis=1)
    return m


class Union(Shape):
    """children merged; k > 0 fillets them together like clay. A child is only evaluated near its bound."""
    def __init__(self, kids, k=0.0, part=None):
        self.kids, self.k = list(kids), F(k)
        self.part = part
        los = [c.bound()[0] for c in self.kids]
        his = [c.bound()[1] for c in self.kids]
        self.lo, self.hi = np.min(los, axis=0) - k, np.max(his, axis=0) + k

    def eval(self, P):
        d = np.full(len(P), BIG, F)
        pt = np.zeros(len(P), np.int16)
        margin = float(self.k) + 0.02
        for c in self.kids:
            m = _cull(c, P, margin)
            if not m.any():
                continue
            cd, cp = c.eval(P[m])
            old = d[m]
            pt_m = pt[m]
            take = cd < old
            pt_m[take] = cp[take]
            pt[m] = pt_m
            d[m] = smin(old, cd, self.k)
        if self.part is not None:
            pt[:] = self.part
        return d, pt

    def dist(self, P):
        return self.eval(P)[0]


class Cut(Shape):
    """a minus everything in `cutters` (k rounds the cut edge); keeps a's parts"""
    def __init__(self, a, cutters, k=0.0):
        self.a, self.cut, self.k = a, list(cutters), F(k)
        self.lo, self.hi = a.bound()
        self.part = a.part

    def eval(self, P):
        d, pt = self.a.eval(P)
        margin = float(self.k) + 0.02
        for c in self.cut:
            m = _cull(c, P, margin)
            if not m.any():
                continue
            cd = c.eval(P[m])[0]
            d[m] = smax(d[m], -cd, self.k)
        return d, pt

    def dist(self, P):
        return self.eval(P)[0]


class Clip(Shape):
    """a intersected with every shape in `keep` (half-spaces for hems and openings); keeps a's parts"""
    def __init__(self, a, keep, k=0.0):
        self.a, self.keep, self.k = a, list(keep), F(k)
        self.lo, self.hi = a.bound()
        self.part = a.part

    def eval(self, P):
        d, pt = self.a.eval(P)
        for c in self.keep:
            d = smax(d, c.eval(P)[0], self.k)
        return d, pt

    def dist(self, P):
        return self.eval(P)[0]


class Mirror(Shape):
    """the child and its mirror image across X = 0 (build the figure's left side, get both)"""
    def __init__(self, child, k=0.0):
        self.child, self.k = child, F(k)
        lo, hi = child.bound()
        self.lo = np.array([min(lo[0], -hi[0]), lo[1], lo[2]], F)
        self.hi = np.array([max(hi[0], -lo[0]), hi[1], hi[2]], F)
        self.part = child.part

    def eval(self, P):
        Q = P.copy()
        Q[:, 0] = np.abs(Q[:, 0])
        return self.child.eval(Q)

    def dist(self, P):
        return self.eval(P)[0]


class Move(Shape):
    """the child turned by R about `pivot` and moved by t. Pose a hand, tilt a fin.
    R maps world to the child's space (eval reads the child at (P - pivot - t) @ R + pivot), so R = I/s draws the child s times bigger.
    The bound maps the child's box through the inverse: a scaling R used to get a box that shrank while the shape grew, and unions culled
    the child where it was (a stray part id on the mechanic's glove that skinned to the hips). The distance stays the child's own, unscaled,
    as recipes were tuned with it (a scaled child's Inflate or smooth blend is in its own units)."""
    def __init__(self, child, R=None, pivot=(0, 0, 0), t=(0, 0, 0)):
        self.child = child
        self.R = np.eye(3, dtype=F) if R is None else np.asarray(R, F)
        self.pv, self.t = v3(pivot), v3(t)
        lo, hi = child.bound()
        corners = np.array([[x, y, z] for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])], F)
        w = (corners - self.pv) @ np.linalg.inv(self.R).astype(F) + self.pv + self.t
        self.lo, self.hi = w.min(0), w.max(0)
        self.part = child.part

    def eval(self, P):
        return self.child.eval((P - self.pv - self.t) @ self.R + self.pv)

    def dist(self, P):
        return self.eval(P)[0]


class Inflate(Shape):
    """the child grown (or shrunk, r < 0) by r: a garment over a body, a lining under a coat"""
    def __init__(self, child, r, part=None):
        self.child, self.r = child, F(r)
        lo, hi = child.bound()
        self.lo, self.hi = lo - abs(r), hi + abs(r)
        self.part = child.part if part is None else part

    def eval(self, P):
        d, pt = self.child.eval(P)
        if self.part is not None and self.part != self.child.part:
            pt = np.full(len(P), self.part, np.int16)
        return d - self.r, pt

    def dist(self, P):
        return self.eval(P)[0]


class Bump(Shape):
    """the child's surface pushed out (amp > 0) or in by fn(P) * amp: creases, seams, folds, sculpt detail"""
    def __init__(self, child, fn, amp):
        self.child, self.fn, self.amp = child, fn, F(amp)
        lo, hi = child.bound()
        self.lo, self.hi = lo - abs(amp), hi + abs(amp)
        self.part = child.part

    def eval(self, P):
        d, pt = self.child.eval(P)
        return d - self.amp * self.fn(P), pt

    def dist(self, P):
        return self.eval(P)[0]


def loft(pts, part=0, k=0.0):
    """a smooth tube through [(point, radius), ...]: legs, arms, tails, necks"""
    segs = [RoundCone(pts[i][0], pts[i + 1][0], pts[i][1], pts[i + 1][1], part) for i in range(len(pts) - 1)]
    return segs[0] if len(segs) == 1 else Union(segs, k)


# ---------------------------------------------------------------------------------------------------- detail fields for Bump

def _hash3(ix, iy, iz):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791)
    h = (h ^ (h >> 13)) * 1274126177
    return ((h ^ (h >> 16)) & 0xFFFF).astype(F) / 65535.0


def noise3(P, scale):
    """smooth value noise in -1..1 at feature size `scale` metres"""
    q = P / scale
    i = np.floor(q).astype(np.int64)
    f = (q - i).astype(F)
    f = f * f * (3.0 - 2.0 * f)
    out = np.zeros(len(P), F)
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out += w * _hash3(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz)
    return out * 2.0 - 1.0


def ridge_line(a, b, width):
    """1 on the segment a-b falling to 0 at `width` from it (a crease or seam along a line)"""
    a, b = v3(a), v3(b)

    def fn(P):
        ba = b - a
        h = np.clip(((P - a) @ ba) / (ba @ ba), 0.0, 1.0)
        dd = _len(P - a - np.outer(h, ba))
        x = np.clip(1.0 - dd / width, 0.0, 1.0)
        return x * x * (3.0 - 2.0 * x)
    return fn
