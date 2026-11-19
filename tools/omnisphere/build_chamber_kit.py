# Builds OMNISPHERE's containment-chamber dressing (assets/omnisphere/chamber_kit.glb) in headless Blender: the lab and engine-room set the bare drum was missing, and
# the moving platforms' models. levels/omnisphere/om_lab.gd places it and runs the movers.
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/omnisphere/build_chamber_kit.py -- [--preview a.png [b.png]] [--fast] [--no-export]
# Space: the drum's own. Origin at the drum's centre on its floor (world -200, 18, -265), y up, metres, no rotation against the world. A polar point is
# (cos a * r, y, sin a * r), the angle the level's colliders use: 0 = east, 90 = the south door (the way in), 180 = west (the wall Juniper breaks out through), -90 = north.
# What was already there (the export; keep clear of it): the plinth r 9 at (0, -4), the frame over it to y 30 (columns x +-13.5), seven capacitor banks r 2.4 at r 24
# (y 0..14.4, angles BANKS), the walkway ring r 29.1..34.9 at y 4.5 (angles -145..145) with four ramps (35, 125, -145, -55), four doors (0, 90, 180, -90), the
# output board on the wall (y 26..38, angles -45..-19), the ceiling at y 52. Juniper walks out west down the corridor |z| < 12: nothing static stands in it but the
# ring's west arc, which is its own object so the level can bring it down when he goes.
# One material: the level's own paint (levels/shaders/omni_paint.gdshaderinc) reads everything from the vertices, as the export does:
#   COLOR.rgb = tint, COLOR.a = occlusion (ray cast here), UV = glow.rg, UV2 = (glow.b, style + wear * 0.99). Styles are the paint's numbers (S_* below).
# Static collision is carried as empties: SOL_<tag>_<n> is a box (location = centre of its base, scale = half width, height, half depth, turned by its yaw),
# SOLD_<tag>_<n> a disc (scale = radius, height, radius).
import bpy, bmesh, math, os, random, sys
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

GUN, STEEL, RED, DRED, HAZ, CONC, DECK, GRATE, RUST, BRASS, RUBBER, BEIGE, BRIGHT, BLACK = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15
LIGHT, GLASS, SCREEN, BLINK, FLOW = 16, 21, 22, 23, 24
WHITE = (1.0, 1.0, 1.0)
NOGLOW = (0.0, 0.0, 0.0)
CRT = (0.22, 1.0, 0.5)          # phosphor green
AMBER = (1.0, 0.55, 0.1)
TEAL = (0.3, 1.0, 0.8)          # the siphon's own colour (the hoses, the bank tubes)
WARM = (1.0, 0.82, 0.55)
BANKS = [30, 75, 115, -150, -110, -70, -30]
LIFTS = [75, 115, -30, -110]    # banks with a mast lift beside them (om_lab.gd LIFTS)
LIFT_OFF = 7.0                  # ...standing this far round from the bank, clear of its busbars
BASKET_Z, BASKET_X = 24.0, 3.1  # where a hoist basket hangs off the crane: over the banks' radius, beside the girder
GAL_LIFT = -122                 # the long lift to the upper gallery
RING_R, RING_Y, RAIL_Y = 19.5, 14.4, 19.0
WEST = (140.0, 220.0)           # the ring's arc over Juniper's way out
GAL_Y, GAL_A0, GAL_A1 = 34.0, -138.0, -58.0
CRANE_Y = 40.0
CEIL = 52.0
UP = Vector((0, 1, 0))
R = random.Random(1811)

VERTS = []
FACES = {}       # group -> [(indices, style, tint, glow, wear)]
SOLIDS = []      # (name, base centre, hx, h, hz, yaw, disc)
cur = "lab_floor"


def D(a):
    return math.radians(a)


def RAD(a):
    return Vector((math.cos(D(a)), 0, math.sin(D(a))))


def TAN(a):
    return Vector((-math.sin(D(a)), 0, math.cos(D(a))))


def PP(a, r, y=0.0, t=0.0):
    """polar point: angle a (degrees), radius r, height y, t metres along the tangent"""
    return RAD(a) * r + TAN(a) * t + UP * y


def solid(tag, base, hx, h, hz, yaw=0.0, disc=False):
    SOLIDS.append(("%s_%s_%d" % ("SOLD" if disc else "SOL", tag, len(SOLIDS)), Vector(base), hx, h, hz, yaw, disc))


def psolid(tag, a, r, y, half_t, h, half_r, t=0.0):
    """a box solid placed polar: half_t along the tangent, half_r along the radius"""
    solid(tag, PP(a, r, y, t), half_t, h, half_r, D(90 - a))


def emit(bm, st, tint, glow, worn=()):
    bm.verts.index_update()
    i0 = len(VERTS)
    VERTS.extend(v.co.copy() for v in bm.verts)
    worn = set(worn)
    out = FACES.setdefault(cur, [])
    for f in bm.faces:
        out.append(([i0 + v.index for v in f.verts], st, tint, glow, 0.9 if f in worn else 0.12))


def finish(bm, st, bevel=0.0, tint=WHITE, glow=NOGLOW):
    """outward normals, a chamfer on the hard edges (those faces carry the paint's edge wear), then onto the pile"""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    new = ()
    if bevel > 0:
        edges = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > 0.5]
        if edges:
            before = set(bm.faces)
            bmesh.ops.bevel(bm, geom=edges, offset=bevel, offset_type='OFFSET', segments=1, profile=0.5, affect='EDGES', clamp_overlap=True)
            new = [f for f in bm.faces if f not in before]
    emit(bm, st, tint, glow, new)
    bm.free()


def obox(O, X, Y, Z, hx, hy, hz, st, bevel=0.0, tint=WHITE, glow=NOGLOW):
    bm = bmesh.new()
    vs = [bm.verts.new(O + X * (sx * hx) + Y * (sy * hy) + Z * (sz * hz)) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    for f in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
        bm.faces.new([vs[i] for i in f])
    finish(bm, st, bevel, tint, glow)


def box(c, size, st, yaw=0.0, bevel=0.0, tint=WHITE, glow=NOGLOW):
    """a box centred at c, size (x, y, z), turned yaw (radians, the game's yaw: local +z looks along sin, cos)"""
    cs, sn = math.cos(yaw), math.sin(yaw)
    obox(Vector(c), Vector((cs, 0, -sn)), UP, Vector((sn, 0, cs)), size[0] / 2, size[1] / 2, size[2] / 2, st, bevel, tint, glow)


def pbox(a, r, y, size, st, t=0.0, bevel=0.0, tint=WHITE, glow=NOGLOW):
    """a box standing at the polar point (its base at y): size = (along the tangent, height, along the radius)"""
    obox(PP(a, r, y + size[1] / 2, t), TAN(a), UP, RAD(a), size[0] / 2, size[1] / 2, size[2] / 2, st, bevel, tint, glow)


def prism(prof, O, U, V, Wd, w, st, bevel=0.0, tint=WHITE, glow=NOGLOW):
    """a profile [(u, v)...] in the plane (U, V) at O, extruded w along Wd, centred"""
    bm = bmesh.new()
    a = [bm.verts.new(O + U * u + V * v - Wd * (w / 2)) for u, v in prof]
    b = [bm.verts.new(O + U * u + V * v + Wd * (w / 2)) for u, v in prof]
    bm.faces.new(a)
    bm.faces.new(b[::-1])
    for i in range(len(prof)):
        j = (i + 1) % len(prof)
        bm.faces.new((a[i], a[j], b[j], b[i]))
    finish(bm, st, bevel, tint, glow)


def frame_of(d):
    d = d.normalized()
    x = d.cross(UP)
    if x.length < 0.05:
        x = d.cross(Vector((1, 0, 0)))
    x.normalize()
    return x, d.cross(x).normalized()


def cyl(a, b, r, st, n=10, r2=None, bevel=0.0, tint=WHITE, glow=NOGLOW):
    """a cylinder (or cone, r at a to r2 at b) from a to b"""
    a, b = Vector(a), Vector(b)
    r2 = r if r2 is None else r2
    x, y = frame_of(b - a)
    bm = bmesh.new()
    ra = [bm.verts.new(a + (x * math.cos(i * math.tau / n) + y * math.sin(i * math.tau / n)) * r) for i in range(n)]
    rb = [bm.verts.new(b + (x * math.cos(i * math.tau / n) + y * math.sin(i * math.tau / n)) * r2) for i in range(n)]
    bm.faces.new(ra)
    bm.faces.new(rb[::-1])
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ra[i], ra[j], rb[j], rb[i]))
    finish(bm, st, bevel, tint, glow)


def lathe(c, prof, st, n=14, bevel=0.0, tint=WHITE, glow=NOGLOW):
    """a profile [(r, y)...] bottom to top, turned round the vertical through c"""
    c = Vector(c)
    bm = bmesh.new()
    rings = [[bm.verts.new(c + Vector((math.cos(i * math.tau / n) * r, y, math.sin(i * math.tau / n) * r))) for i in range(n)] for r, y in prof]
    bm.faces.new(rings[0])
    bm.faces.new(rings[-1][::-1])
    for k in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    finish(bm, st, bevel, tint, glow)


def tube(pts, r, st, n=6, tint=WHITE, glow=NOGLOW):
    """a round pipe along a polyline"""
    pts = [Vector(p) for p in pts]
    bm = bmesh.new()
    rings = []
    nx = None
    for k, p in enumerate(pts):
        t = (pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]).normalized()
        if nx is None:
            nx, _ = frame_of(t)
        nx = (nx - t * nx.dot(t))
        if nx.length < 1e-4:
            nx, _ = frame_of(t)
        nx.normalize()
        ny = t.cross(nx)
        rings.append([bm.verts.new(p + (nx * math.cos(i * math.tau / n) + ny * math.sin(i * math.tau / n)) * r) for i in range(n)])
    bm.faces.new(rings[0])
    bm.faces.new(rings[-1][::-1])
    for k in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    finish(bm, st, 0.0, tint, glow)


def steps(a0, a1, step):
    n = max(1, int(math.ceil(abs(a1 - a0) / step)))
    return [a0 + (a1 - a0) * i / n for i in range(n + 1)]


def arc(a0, a1, r0, r1, y0, y1, st, step=6.0, c=(0, 0, 0), bevel=0.0, tint=WHITE, glow=NOGLOW):
    """a piece of a flat ring: angles a0..a1, radii r0..r1, heights y0..y1 (a full turn closes on itself)"""
    c = Vector(c)
    full = abs(a1 - a0) >= 359.9
    an = steps(a0, a1, step)
    if full:
        an = an[:-1]
    bm = bmesh.new()
    cols = [[bm.verts.new(c + PP(a, r, y)) for r, y in ((r0, y0), (r1, y0), (r1, y1), (r0, y1))] for a in an]
    m = len(cols)
    for k in range(m if full else m - 1):
        p, q = cols[k], cols[(k + 1) % m]
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((p[i], p[j], q[j], q[i]))
    if not full:
        bm.faces.new(cols[0])
        bm.faces.new(cols[-1][::-1])
    finish(bm, st, bevel, tint, glow)


def arc_tube(a0, a1, r, y, tr, st, step=5.0, n=6, tint=WHITE, glow=NOGLOW):
    tube([PP(a, r, y) for a in steps(a0, a1, step)], tr, st, n, tint, glow)


def bez(p0, p1, p2, p3, n=10):
    out = []
    for i in range(n + 1):
        t = i / n
        out.append(p0 * (1 - t) ** 3 + p1 * 3 * t * (1 - t) ** 2 + p2 * 3 * t * t * (1 - t) + p3 * t ** 3)
    return out


def insulator(base, h, r=0.22, st=BEIGE, tint=(0.75, 0.7, 0.62)):
    """a ribbed porcelain stack standing on base"""
    prof = [(r * 0.6, 0.0)]
    n = max(2, int(h / 0.22))
    for i in range(n):
        y = h * i / n
        prof += [(r, y + h / n * 0.25), (r * 0.55, y + h / n * 0.8)]
    prof.append((r * 0.5, h))
    lathe(base, prof, st, 10, 0.0, tint)


def rail(a0, a1, r, y, h=1.1, post=6.0, st=RED):
    """a railing along an arc: posts, a top tube and a mid tube"""
    arc_tube(a0, a1, r, y + h, 0.045, st, 4.0, 5)
    arc_tube(a0, a1, r, y + h * 0.55, 0.03, st, 4.0, 5)
    for a in steps(a0, a1, post):
        cyl(PP(a, r, y), PP(a, r, y + h), 0.04, st, 5)


def crt(base, yaw, w=0.62, h=0.5, d=0.55, col=CRT):
    """a boxy monitor standing on base, its screen looking along the yaw"""
    f = Vector((math.sin(yaw), 0, math.cos(yaw)))
    c = Vector(base) + UP * (h / 2)
    box(c, (w, h, d), BEIGE, yaw, 0.03, (0.8, 0.78, 0.7))
    box(c + f * (d / 2 + 0.006) + UP * 0.02, (w * 0.76, h * 0.66, 0.012), SCREEN, yaw, 0.0, WHITE, col)
    box(c + f * (d / 2 + 0.004) - UP * (h * 0.4) + Vector((math.cos(yaw), 0, -math.sin(yaw))) * (w * 0.3), (0.05, 0.03, 0.01), BLINK, yaw, 0.0, WHITE, AMBER)


# ---------------------------------------------------------------------------------------------------------------- the floor

def cabinet_row(a, n=5):
    """switchgear against the wall: a row of tall cabinets on a plinth, each with a door seam, a vent, a meter and lamps, and a conduit up the wall"""
    w, d, h, r = 1.25, 0.95, 2.35, 44.2
    pbox(a, r, 0, (n * w + 0.3, 0.14, d + 0.25), GUN, 0, 0.03)
    for i in range(n):
        t = (i - (n - 1) / 2) * w
        beige = (i % 3) != 1
        hh = h + (0.25 if i == n // 2 else 0.0)
        pbox(a, r, 0.14, (w - 0.04, hh, d), BEIGE if beige else STEEL, t, 0.035, (0.82, 0.8, 0.72) if beige else (0.75, 0.78, 0.82))
        fr = r - d / 2 - 0.012
        pbox(a, fr, 0.34, (w - 0.3, hh - 0.75, 0.02), BEIGE if beige else STEEL, t, 0.0, (0.66, 0.64, 0.58) if beige else (0.58, 0.6, 0.64))      # the door
        pbox(a, fr - 0.012, 0.5, (w - 0.5, 0.34, 0.02), BLACK, t)                                                  # vent
        pbox(a, fr - 0.014, hh - 0.72, (0.3, 0.22, 0.02), SCREEN, t - 0.2, 0.0, WHITE, CRT if i % 2 else AMBER)       # meter
        for k in range(3):
            pbox(a, fr - 0.014, hh - 0.66 + k * 0.0, (0.07, 0.07, 0.03), BLINK, t + 0.12 + k * 0.13, 0.0, WHITE, (AMBER, CRT, (1.0, 0.2, 0.1))[k])
        pbox(a, fr - 0.03, 1.15, (0.05, 0.3, 0.05), BRIGHT, t + w / 2 - 0.22)                                         # handle
    for t in (-n * w / 2 + 0.5, n * w / 2 - 0.5):                                                                      # conduits to the pipe band
        tube([PP(a, r + 0.1, h + 0.1, t), PP(a, 45.25, h + 0.6, t), PP(a, 45.25, 8.7, t)], 0.07, RUBBER, 6)
    psolid("cab", a, r, 0, n * w / 2 + 0.1, h + 0.14, d / 2 + 0.1)


def transformer(a):
    """a big oil transformer: tank on a skid, cooling fins both sides, three bushings on top, a conservator drum"""
    r = 41.8
    pbox(a, r, 0, (3.6, 0.3, 2.8), GUN, 0, 0.04)
    pbox(a, r, 0.3, (3.0, 2.9, 2.2), STEEL, 0, 0.06, (0.5, 0.56, 0.52))
    for s in (-1, 1):
        for k in range(9):
            pbox(a, r - 0.85 + k * 0.21, 0.6, (0.42, 2.2, 0.05), GUN, s * 1.72)
        pbox(a, r, 2.75, (0.5, 0.12, 1.9), GUN, s * 1.72)
    for k in (-1, 0, 1):
        b = PP(a, r - 0.1, 3.2, k * 0.95)
        insulator(b, 1.5, 0.26)
        cyl(b + UP * 1.5, b + UP * 1.75, 0.07, BRASS, 6)
        tube(bez(b + UP * 1.75, b + UP * 2.6, PP(a, 44.6, 7.0, k * 0.95), PP(a, 45.2, 8.75, k * 0.5), 8), 0.05, BRASS, 5)
    cyl(PP(a, r + 0.75, 3.75, -1.3), PP(a, r + 0.75, 3.75, 1.3), 0.42, STEEL, 12, None, 0.03, (0.5, 0.56, 0.52))
    pbox(a, r - 1.12, 1.2, (1.3, 0.9, 0.06), HAZ)
    pbox(a, r - 1.16, 1.42, (0.4, 0.3, 0.03), SCREEN, 0.25, 0.0, WHITE, AMBER)
    psolid("xfmr", a, r, 0, 2.0, 3.3, 1.4)


def cart(p, yaw, tall=False):
    """an instrument trolley: two shelves on castors, a monitor and a recorder on it"""
    p = Vector(p)
    x = Vector((math.cos(yaw), 0, -math.sin(yaw)))
    z = Vector((math.sin(yaw), 0, math.cos(yaw)))
    top = 1.35 if tall else 0.92
    for sx in (-1, 1):
        for sz in (-1, 1):
            q = p + x * (sx * 0.42) + z * (sz * 0.27)
            cyl(q + UP * 0.1, q + UP * top, 0.022, BRIGHT, 5)
            cyl(q + x * 0.03, q - x * 0.03, 0.06, RUBBER, 8)
            q.y = 0.06
            cyl(q - x * 0.025, q + x * 0.025, 0.06, RUBBER, 8)
    for y in ((0.2, 0.62, top) if not tall else (0.2, 0.62, 0.98, top)):
        box(p + UP * y, (0.92, 0.035, 0.62), STEEL, yaw, 0.01)
    crt(p + UP * (top + 0.02), yaw)
    box(p + UP * 0.72 - x * 0.15, (0.5, 0.16, 0.45), GUN, yaw, 0.02)
    box(p + UP * 0.72 - x * 0.15 + z * 0.23, (0.36, 0.08, 0.01), SCREEN, yaw, 0.0, WHITE, AMBER)
    box(p + UP * 0.3 + x * 0.1, (0.55, 0.16, 0.5), BEIGE, yaw, 0.02, (0.6, 0.62, 0.6))


def floor_cable(pts, r=0.045):
    out = []
    for i in range(len(pts) - 1):
        a, b = Vector(pts[i]), Vector(pts[i + 1])
        side = (b - a).cross(UP).normalized()
        n = max(2, int((b - a).length / 0.8))
        for k in range(n):
            u = k / n
            out.append(a.lerp(b, u) + side * math.sin(u * math.pi * 2 + i) * 0.22 + UP * r)
    out.append(Vector(pts[-1]) + UP * r)
    tube(out, r, RUBBER, 5)


def build_floor():
    global cur
    cur = "lab_floor"
    JC = (0, 0, -4)
    arc(0, 360, 9.35, 9.95, 0.0, 0.06, HAZ, 6.0, JC)                         # keep-clear ring round the plinth
    arc(0, 360, 20.1, 20.75, 0.0, 0.09, BRASS, 5.0, (0, 0, 0), 0.02)        # the grounding plate's copper ring
    for k in range(24):                                                     # its bonding lugs
        pbox(k * 15 + 7.5, 20.42, 0.09, (0.5, 0.06, 0.9), BRIGHT, 0, 0.015)
    for a in BANKS:
        # cable trench under grates: plinth side of the bank, then out to the wall
        pbox(a, 18.0, 0, (1.3, 0.05, 7.0), GRATE)
        pbox(a, 36.0, 0, (1.0, 0.05, 18.6), GRATE)
        for s in (-1, 1):
            pbox(a, 18.0, 0, (0.12, 0.08, 7.0), HAZ, s * 0.71)
            pbox(a, 36.0, 0, (0.1, 0.07, 18.6), GUN, s * 0.55)
        # the bank's local control box and the cable down into the trench
        pbox(a, 21.0, 0, (0.9, 1.25, 0.5), BEIGE, 1.9, 0.03, (0.8, 0.78, 0.7))
        pbox(a, 20.73, 0.75, (0.5, 0.3, 0.02), SCREEN, 1.9, 0.0, WHITE, CRT)
        for k in range(3):
            pbox(a, 20.73, 0.45, (0.08, 0.08, 0.03), BLINK, 1.9 - 0.2 + k * 0.2, 0.0, WHITE, (CRT, AMBER, CRT)[k])
        tube([PP(a, 21.25, 0.9, 1.9), PP(a, 21.6, 0.9, 1.5), PP(a, 21.75, 0.5, 0.9), PP(a, 21.4, 0.08, 0.4)], 0.07, RUBBER, 6)
    for a in (20, 62, 118, 160, -20, -68, -112, -160):
        cabinet_row(a)
    for a in (40, 140, -40, -140):
        transformer(a)
    # ---- the monitoring station east of the plinth, past Doug's corner (the export's: his rug, table, chair and the care log at about 8..14, 3..9, left as it is)
    desk = Vector((16.6, 0, 1.2))
    yw = D(78)      # screens to the outside: the operator looks over them at him
    dx = Vector((math.cos(yw), 0, -math.sin(yw)))
    dz = Vector((math.sin(yw), 0, math.cos(yw)))
    box(desk + UP * 0.76, (2.3, 0.05, 0.95), BEIGE, yw, 0.015, (0.62, 0.52, 0.4))
    for sx in (-1.0, 1.0):
        box(desk + UP * 0.37 + dx * sx, (0.06, 0.74, 0.85), GUN, yw)
    crt(desk + UP * 0.79 - dx * 0.55 - dz * 0.1, yw)
    crt(desk + UP * 0.79 + dx * 0.2 - dz * 0.1, yw, 0.5, 0.42, 0.5, AMBER)
    box(desk + UP * 0.8 - dx * 0.5 + dz * 0.3, (0.5, 0.03, 0.18), BEIGE, yw, 0.0, (0.7, 0.68, 0.62))      # keyboard
    cyl(desk + UP * 0.785 + dx * 0.85 + dz * 0.2, desk + UP * 1.07 + dx * 0.85 + dz * 0.2, 0.05, STEEL, 8, None, 0.0, (0.5, 0.2, 0.15))      # thermos
    box(desk + UP * 0.8 + dx * 0.3 + dz * 0.28, (0.3, 0.02, 0.22), BEIGE, yw + 0.2, 0.0, (0.95, 0.93, 0.85))      # papers
    solid("desk", desk, 1.2, 0.8, 0.5, yw)
    cart((7.2, 0, 3.4), D(30))
    cart((8.9, 0, 1.2), D(60), True)
    cart((-7.6, 0, 3.2), D(-30), True)
    rk = Vector((17.0, 0, -1.9))      # an equipment rack beside it
    ry = D(95)
    box(rk + UP * 1.0, (0.7, 2.0, 0.75), GUN, ry, 0.03)
    for k in range(6):
        f = Vector((math.sin(ry), 0, math.cos(ry)))
        box(rk + UP * (0.3 + k * 0.3) + f * 0.38, (0.6, 0.24, 0.02), BEIGE if k % 2 else BLACK, ry, 0.0, (0.6, 0.6, 0.58))
        box(rk + UP * (0.3 + k * 0.3) + f * 0.395 + Vector((math.cos(ry), 0, -math.sin(ry))) * 0.2, (0.06, 0.05, 0.02), BLINK, ry, 0.0, WHITE, CRT if k % 3 else AMBER)
    solid("rack", rk, 0.4, 2.0, 0.42, ry)
    # a cable reel and the leads snaking to the plinth
    cyl((5.2, 0.55, 7.0), (5.9, 0.55, 7.3), 0.55, BEIGE, 12, None, 0.02, (0.5, 0.36, 0.2))
    cyl((5.3, 0.55, 7.04), (5.8, 0.55, 7.26), 0.38, RUBBER, 12)
    floor_cable([(7.2, 0, 3.4), (6.0, 0, 1.4), (5.4, 0, -0.4)])
    floor_cable([(8.9, 0, 1.2), (8.2, 0, -0.6), (7.4, 0, -2.0)])
    floor_cable([(16.0, 0, 1.0), (12.5, 0, 1.8), (9.4, 0, 1.4)])
    floor_cable([(5.5, 0, 6.6), (4.6, 0, 3.4), (3.8, 0, 1.2)], 0.06)
    floor_cable([(-7.6, 0, 3.2), (-6.2, 0, 1.2), (-5.6, 0, -0.6)])


# ---------------------------------------------------------------------------------------------------------------- the middle of the room

def lift_mast(a, r, y0, y1):
    """two guide rails for a lift platform that rides between them: channel posts, ties, a head beam with the motor, a hazard foot"""
    for s in (-1, 1):
        t = s * 1.62
        pbox(a, r, 0, (0.5, 0.25, 0.9), HAZ, t)
        pbox(a, r, 0.25, (0.24, y1 + 1.6 - 0.25, 0.3), STEEL, t, 0.02)
        pbox(a, r, 0.25, (0.06, y1 + 1.2, 0.08), BRASS, t - s * 0.15)                # the pickup strip
        y = 2.2
        while y < y1 + 1.2:
            pbox(a, r + 0.2, y, (0.34, 0.1, 0.12), GUN, t)
            y += 2.4
        psolid("mast", a, r, 0, 0.14, y1 + 1.6, 0.17, t)
    pbox(a, r, y1 + 1.6, (3.6, 0.3, 0.42), STEEL, 0, 0.03)
    pbox(a, r + 0.1, y1 + 1.9, (0.9, 0.55, 0.6), GUN, 0.9, 0.03)
    pbox(a, r - 0.2, y1 + 1.95, (0.12, 0.12, 0.04), BLINK, 0.9, 0.0, WHITE, AMBER)
    cyl(PP(a, r + 0.1, y1 + 2.15, -0.2), PP(a, r + 0.1, y1 + 2.15, 0.45), 0.24, GUN, 10)
    for s in (-1, 1):                                                               # a painted stop at the bottom landing
        pbox(a, r, y0 - 0.5, (0.2, 0.08, 0.5), HAZ, s * 1.4)


def bank_dress(a):
    """a capacitor bank's plant: two busbars off its shoulder that rise and run out to the wall's collector, on porcelain"""
    for s in (-1, 1):
        p0 = PP(a, 26.0, 12.2, s * 0.55)
        tube(bez(p0, PP(a, 28.5, 17.0, s * 0.55), PP(a, 38.0, 22.6, s * 0.55), PP(a, 45.2, 22.0, s * 0.55), 14), 0.11, BRASS, 6)
        cyl(PP(a, 25.2, 12.2, s * 0.55), p0, 0.11, BRASS, 6)
        insulator(PP(a, 25.3, 10.9, s * 0.55), 1.2, 0.2)
    pbox(a, 25.3, 10.6, (1.9, 0.3, 0.7), GUN, 0, 0.03)
    for u in (0.35, 0.7):                                                           # spreaders along the run
        q = bez(PP(a, 26.0, 12.2), PP(a, 28.5, 17.0), PP(a, 38.0, 22.6), PP(a, 45.2, 22.0), 20)[int(u * 20)]
        obox(q, TAN(a), UP, RAD(a), 0.85, 0.06, 0.1, GUN)
    # the brush arm: a bracket off the bank's inner shoulder that carries the ring rail
    b0, b1 = PP(a, 21.7, 12.6), PP(a, RING_R, RAIL_Y)
    obox((b0 + b1) / 2, TAN(a), (b1 - b0).normalized(), TAN(a).cross((b1 - b0).normalized()), 0.14, (b1 - b0).length / 2, 0.1, STEEL, 0.02)
    pbox(a, 21.75, 12.2, (0.9, 0.8, 0.35), GUN, 0, 0.03)


def ring_rail(a0, a1):
    """the commutator ring's overhead rail: twin tubes with ties, carried on the banks' brush arms"""
    for dr in (-0.55, 0.55):
        arc_tube(a0, a1, RING_R + dr, RAIL_Y, 0.11, STEEL, 4.0, 6)
    arc(a0, a1, RING_R - 0.1, RING_R + 0.1, RAIL_Y - 0.5, RAIL_Y - 0.38, BRASS, 4.0)          # the live strip the carriages' brushes ride
    for a in steps(a0, a1, 8.0):
        pbox(a, RING_R, RAIL_Y + 0.08, (0.14, 0.1, 1.4), GUN)
        pbox(a, RING_R, RAIL_Y - 0.42, (0.1, 0.5, 0.1), GUN)


def station(a):
    """an instrument console on the walkway's outer rail: a sloped desk, a screen and lamps on each bay"""
    console(a, 34.15, 4.5, 3, 1)


def console(a, r, y, bays, face, wide=1.15):
    """a control desk along the tangent at (a, r); face = 1 when the operator stands on the inner side (towards the centre), -1 on the outer side"""
    U = RAD(a) * -face                      # towards the operator
    T = TAN(a)
    O = PP(a, r, y)
    w = bays * wide
    prism([(-0.4, 0.0), (0.38, 0.0), (0.38, 0.72), (0.16, 0.9), (-0.4, 1.28)], O, U, UP, T, w, GUN, 0.025)
    prism([(0.36, 0.72), (0.5, 0.72), (0.5, 0.78), (0.36, 0.78)], O, U, UP, T, w + 0.06, BRIGHT)             # the grab bar
    sl = (U * -0.56 + UP * 0.38).normalized()      # up the sloped panel
    nn = sl.cross(T) * (1 if sl.cross(T).dot(U) > 0 else -1)
    mid = O + U * -0.12 + UP * 1.09
    kb = (U * -0.22 + UP * 0.18).normalized()
    kn = kb.cross(T) * (1 if kb.cross(T).dot(UP) > 0 else -1)
    for i in range(bays):
        t = (i - (bays - 1) / 2) * wide
        obox(mid + T * t + nn * 0.012, T, sl, nn, 0.4, 0.21, 0.008, SCREEN, 0.0, WHITE, CRT if (i + bays) % 3 else AMBER)
        km = O + U * 0.27 + UP * 0.81 + T * t
        obox(km + kn * 0.012, T, kb, kn, 0.36, 0.09, 0.008, BEIGE, 0.0, (0.55, 0.55, 0.52))
        for k in range(4):
            obox(km + kn * 0.02 + T * (-0.42 + k * 0.1) + kb * 0.0, T, kb, kn, 0.022, 0.022, 0.012, BLINK, 0.0, WHITE, (CRT, AMBER, CRT, (1.0, 0.2, 0.1))[k])
    psolid("console", a, r, y, w / 2, 1.25, 0.42)


def build_mid():
    global cur
    cur = "lab_mid"
    for a in BANKS:
        bank_dress(a)
    for a in LIFTS:
        lift_mast(a + LIFT_OFF, 27.75, 4.5, RING_Y)
    lift_mast(GAL_LIFT, 37.5, 4.5, GAL_Y)
    ring_rail(WEST[1] - 360.0, WEST[0])
    for a in (58, -18, -98):
        station(a)
    # the wall's pipe bands (broken at the west panel he breaks out through): service pipes low, the bus collector higher
    for a0, a1 in ((-163.0, 163.0),):
        arc_tube(a0, a1, 45.3, 8.75, 0.2, STEEL, 5.0, 8, (0.5, 0.56, 0.52))
        arc_tube(a0, a1, 45.35, 9.3, 0.11, BRASS, 5.0, 6)
        arc_tube(a0, a1, 45.38, 8.2, 0.09, RUST, 5.0, 6)
        arc(a0, a1, 44.9, 45.6, 21.6, 22.4, GUN, 5.0, (0, 0, 0), 0.04)
        arc(a0, a1, 44.86, 44.9, 21.9, 22.1, FLOW, 5.0, (0, 0, 0), 0.0, WHITE, TEAL)
        for a in steps(a0, a1, 10.0):
            pbox(a, 45.4, 8.0, (0.16, 1.6, 0.5), GUN)
            pbox(a, 45.3, 21.2, (0.3, 1.5, 0.6), GUN, 0, 0.03)
    cur = "lab_ring_west"
    ring_rail(WEST[0], WEST[1])


# ---------------------------------------------------------------------------------------------------------------- up top

def build_upper():
    global cur
    cur = "lab_upper"
    # ---- the observation gallery: a deck on brackets, a rail on the drop, the control room in the middle of it
    arc(GAL_A0, GAL_A1, 40.0, 45.7, GAL_Y - 0.4, GAL_Y, DECK, 5.0, (0, 0, 0), 0.04)
    arc(GAL_A0, GAL_A1, 39.9, 40.15, GAL_Y - 0.5, GAL_Y + 0.12, HAZ, 5.0)
    for a in steps(GAL_A0, GAL_A1, 10.0):
        prism([(0.0, 0.0), (5.2, 0.0), (5.2, -0.5), (0.3, -4.2), (0.0, -4.2)], PP(a, 45.7, GAL_Y - 0.4), RAD(a) * -1, UP, TAN(a), 0.3, STEEL, 0.03)
    n = int(round((GAL_A1 - GAL_A0) / 10.0))
    for i in range(n):
        psolid("gallery", GAL_A0 + 5.0 + i * 10.0, 42.85, GAL_Y - 0.4, 3.85, 0.4, 2.85)
    room0, room1 = -104.0, -76.0
    rail(GAL_A0, room0, 40.25, GAL_Y)
    rail(room1, GAL_A1, 40.25, GAL_Y)
    for a in (GAL_A0, GAL_A1):                                                          # end rails
        for k in range(6):
            cyl(PP(a, 40.25 + k * 1.05, GAL_Y), PP(a, 40.25 + k * 1.05, GAL_Y + 1.1), 0.04, RED, 5)
        tube([PP(a, 40.25, GAL_Y + 1.1), PP(a, 45.6, GAL_Y + 1.1)], 0.045, RED, 5)
        tube([PP(a, 40.25, GAL_Y + 0.6), PP(a, 45.6, GAL_Y + 0.6)], 0.03, RED, 5)
    # the control room: the desk along the drop looking down at him, racks and a wall of screens behind, a canopy with its lamps, window frames over the desk
    for a in (-97.0, -90.0, -83.0):
        console(a, 40.75, GAL_Y, 4, -1)
    for a in steps(room0, room1, 7.0):
        cyl(PP(a, 40.2, GAL_Y), PP(a, 40.2, GAL_Y + 3.3), 0.07, GUN, 6)
    arc(room0, room1, 40.1, 40.3, GAL_Y + 3.2, GAL_Y + 3.4, GUN, 3.5)
    arc(room0, room1, 40.12, 40.3, GAL_Y + 1.32, GAL_Y + 1.42, GUN, 3.5)
    arc(room0, room1, 40.18, 40.22, GAL_Y + 2.2, GAL_Y + 3.2, GLASS, 3.5, (0, 0, 0), 0.0, WHITE, TEAL)
    arc(room0 - 1.0, room1 + 1.0, 39.9, 45.7, GAL_Y + 3.4, GAL_Y + 3.6, GUN, 3.5, (0, 0, 0), 0.04)      # canopy
    for a in steps(room0 + 3.0, room1 - 3.0, 5.5):
        pbox(a, 42.6, GAL_Y + 3.3, (1.6, 0.1, 0.35), LIGHT, 0, 0.0, WHITE, WARM)
    for i, a in enumerate(steps(room0 + 2.5, room1 - 2.5, 4.2)):                         # the back wall: screens over racks
        pbox(a, 45.2, GAL_Y, (2.5, 1.5, 0.8), GUN, 0, 0.03)
        pbox(a, 44.78, GAL_Y + 0.25, (2.2, 1.0, 0.03), BEIGE, 0, 0.0, (0.5, 0.5, 0.48))
        for k in range(5):
            pbox(a, 44.76, GAL_Y + 1.1, (0.08, 0.08, 0.03), BLINK, -0.8 + k * 0.4, 0.0, WHITE, (CRT, AMBER)[k % 2])
        pbox(a, 45.3, GAL_Y + 1.6, (2.5, 1.6, 0.5), BLACK, 0, 0.03)
        pbox(a, 45.03, GAL_Y + 1.7, (2.2, 1.35, 0.03), SCREEN, 0, 0.0, WHITE, (CRT, CRT, AMBER, CRT)[i % 4])
    for a in (-94.0, -90.0, -86.0):                                                      # operators' stools
        cyl(PP(a, 41.8, GAL_Y), PP(a, 41.8, GAL_Y + 0.55), 0.035, BRIGHT, 6)
        cyl(PP(a, 41.8, GAL_Y + 0.55), PP(a, 41.8, GAL_Y + 0.62), 0.22, RUBBER, 10)
        cyl(PP(a, 41.8, GAL_Y), PP(a, 41.8, GAL_Y + 0.04), 0.26, BRIGHT, 10)
    for a in (-128.0, -68.0):                                                            # lockers at the ends
        pbox(a, 45.15, GAL_Y, (2.4, 2.0, 0.6), BEIGE, 0, 0.03, (0.45, 0.5, 0.48))
        for k in range(4):
            pbox(a, 44.84, GAL_Y + 0.1, (0.02, 1.8, 0.02), BLACK, -0.9 + k * 0.6)
    # ---- the polar crane's ring rail on corbels, right round under the roof
    arc(0, 360, 43.5, 45.7, CRANE_Y - 2.2, CRANE_Y - 1.55, STEEL, 5.0, (0, 0, 0), 0.05)
    arc(0, 360, 44.1, 44.3, CRANE_Y - 1.55, CRANE_Y - 1.4, BRIGHT, 5.0)
    arc(0, 360, 43.46, 43.5, CRANE_Y - 2.05, CRANE_Y - 1.7, HAZ, 5.0)
    for a in steps(0, 345, 15.0):
        prism([(0.0, 0.0), (2.0, 0.0), (0.25, -2.4), (0.0, -2.4)], PP(a, 45.7, CRANE_Y - 2.2), RAD(a) * -1, UP, TAN(a), 0.4, STEEL, 0.03)
    # ---- the kingpost the crane turns on, down from the roof, with its slip-ring housing; the roof's radial trusses and lamps
    lathe((0, 0, 0), [(0.0, CRANE_Y + 0.25), (1.15, CRANE_Y + 0.25), (1.15, CRANE_Y + 1.6), (2.3, CRANE_Y + 2.0), (2.3, CRANE_Y + 4.4), (1.5, CRANE_Y + 4.9), (1.5, CEIL)], GUN, 16, 0.05)
    for y in (CRANE_Y + 2.5, CRANE_Y + 3.2, CRANE_Y + 3.9):
        lathe((0, 0, 0), [(2.32, y), (2.42, y), (2.42, y + 0.3), (2.32, y + 0.3)], BRASS, 16)
    lathe((0, 0, 0), [(1.17, CRANE_Y + 0.6), (1.22, CRANE_Y + 0.6), (1.22, CRANE_Y + 1.3), (1.17, CRANE_Y + 1.3)], HAZ, 16)
    solid("kingpost", (0, CRANE_Y, 0), 1.25, CEIL - CRANE_Y, 1.25, 0.0, True)
    for k in range(8):
        a = k * 45.0 + 22.5
        obox(PP(a, 23.6, CEIL - 0.6), RAD(a), UP, TAN(a), 22.0, 0.45, 0.22, GUN)
        obox(PP(a, 23.6, CEIL - 1.55), RAD(a), UP, TAN(a), 22.0, 0.1, 0.16, GUN)
        for r in range(4, 44, 4):
            x0, x1 = PP(a, r, CEIL - 1.5), PP(a, r + 2.0, CEIL - 1.0)
            cyl(x0, x1, 0.06, GUN, 4)
            cyl(x1, PP(a, r + 4.0, CEIL - 1.5), 0.06, GUN, 4)
        for r in (14.0, 30.0):
            cyl(PP(a, r, CEIL - 1.6), PP(a, r, CEIL - 2.6), 0.03, BRIGHT, 4)
            lathe(PP(a, r, CEIL - 3.2), [(0.75, 0.0), (0.2, 0.55), (0.2, 0.6)], GUN, 10)
            lathe(PP(a, r, CEIL - 3.22), [(0.0, 0.0), (0.6, 0.0), (0.6, 0.05)], LIGHT, 10, 0.0, WHITE, WARM)
        for s in (-1, 1):                                                               # cable looms along the trusses
            tube([PP(a, r, CEIL - 1.75 - 0.25 * math.sin((r - 3) * 0.9) ** 2, s * 0.3) for r in range(3, 45, 2)], 0.06, RUBBER, 5)


# ---------------------------------------------------------------------------------------------------------------- the movers (each in its own space)

def build_lift():
    """the lift platform: top at y = 0, its guide shoes at x = +-1.45 (the masts), 2.6 m square"""
    global cur
    cur = "lab_lift"
    box((0, -0.16, 0), (2.6, 0.32, 2.6), GUN, 0, 0.04)
    box((0, -0.01, 0), (2.2, 0.03, 2.2), GRATE)
    for s in (-1, 1):
        box((0, -0.05, s * 1.24), (2.6, 0.12, 0.14), HAZ)
        box((s * 1.45, 0.1, 0), (0.34, 0.9, 0.5), STEEL, 0, 0.03)
        cyl((s * 1.3, 0.35, -0.12), (s * 1.3, 0.35, 0.12), 0.09, RUBBER, 8)
        box((s * 1.32, 0.58, 0), (0.1, 0.1, 0.03), BLINK, 0, 0.0, WHITE, AMBER)
    box((0, -0.42, 0), (2.0, 0.2, 0.3), GUN)
    box((0, -0.42, 0), (0.3, 0.2, 2.0), GUN)


def build_carriage():
    """a ring carriage: a deck (top at y = 0, 3.2 along the ring = x, 2.4 across) under two hangers from its truck on the rail, a glowing brush on the live strip"""
    global cur
    cur = "lab_carriage"
    up = RAIL_Y - RING_Y
    box((0, -0.15, 0), (3.2, 0.3, 2.4), GUN, 0, 0.04)
    box((0, -0.005, 0), (2.8, 0.03, 2.0), GRATE)
    for s in (-1, 1):
        box((s * 1.53, -0.05, 0), (0.14, 0.12, 2.4), HAZ)
        box((s * 1.45, up / 2 - 0.2, 0), (0.12, up - 0.4, 0.2), STEEL, 0, 0.02)
        tube([(s * 1.45, 1.1, 0.0), (s * 0.7, 1.1, 0.0)], 0.035, RED, 5)
        box((s * 1.2, up - 0.02, 0), (0.7, 0.34, 1.5), GUN, 0, 0.03)
        for dz in (-0.55, 0.55):
            cyl((s * 1.2 - 0.14, up + 0.0, dz), (s * 1.2 + 0.14, up + 0.0, dz), 0.2, BRIGHT, 10)
    box((0, up - 0.35, 0), (2.9, 0.18, 0.3), STEEL, 0, 0.02)
    box((0, up - 0.52, 0), (0.5, 0.16, 0.24), BRASS, 0, 0.02)
    box((0, up - 0.6, 0), (0.42, 0.05, 0.2), FLOW, 0, 0.0, WHITE, TEAL)
    box((0, -0.4, 0), (1.2, 0.22, 1.0), GUN, 0, 0.03)
    box((0, -0.52, 0), (0.5, 0.04, 0.5), LIGHT, 0, 0.0, WHITE, TEAL)


def build_crane():
    """the polar crane: twin box girders 85 m across the drum (along z), a deck between them (top at y = 0), a walkable hub ring round the kingpost, end trucks on the ring rail"""
    global cur
    cur = "lab_crane"
    L = 42.6
    for s in (-1, 1):
        for sz in (-1, 1):
            box((s * 1.25, -0.75, sz * (L + 2.6) / 2), (0.7, 1.5, L - 2.6), STEEL, 0, 0.05, (0.9, 0.62, 0.2))
            box((0, -0.06, sz * (L + 3.4) / 2), (1.9, 0.12, L - 3.4), DECK)
            box((s * 1.56, 0.09, sz * (L + 2.6) / 2), (0.08, 0.18, L - 2.6), HAZ)
            z = 5.0
            while z < L - 1:
                box((s * 1.25, -0.75, sz * z), (0.78, 1.56, 0.12), GUN)
                z += 4.0
    for sz in (-1, 1):
        z = 4.0
        while z < L:
            box((0, -0.5, sz * z), (2.0, 0.25, 0.25), GUN)
            z += 4.0
        box((0, -0.75, sz * (L + 0.9)), (4.6, 1.1, 2.4), GUN, 0, 0.05)                   # end truck, its wheels on the ring rail (r 44.2, top at -1.4)
        for sx in (-1.6, 1.6):
            cyl((sx - 0.16, -1.06, sz * 44.2), (sx + 0.16, -1.06, sz * 44.2), 0.34, BRIGHT, 12)
        box((0, -0.55, sz * (L + 2.12)), (1.0, 0.3, 0.06), BLINK, 0, 0.0, WHITE, AMBER)
        box((0, -0.3, sz * (L - 0.6)), (3.0, 0.14, 1.2), HAZ)
        # the hoist over each basket: two posts off the girder, a jib out over the basket, the drum on it (the basket's hook block stops under it at y = 4.6)
        x0, zc = sz * 1.25, sz * BASKET_Z
        for dz in (-1.7, 1.7):
            box((x0, 2.75, zc + dz), (0.3, 5.5, 0.3), STEEL, 0, 0.03, (0.9, 0.62, 0.2))
            box(((x0 + sz * 4.4) / 2, 5.35, zc + dz), (abs(sz * 4.4 - x0) + 0.3, 0.3, 0.3), STEEL, 0, 0.03, (0.9, 0.62, 0.2))
            tube([(x0, 0.2, zc + dz), (sz * 3.0, 5.2, zc + dz)], 0.06, GUN, 5)
        box((sz * BASKET_X, 5.35, zc), (1.5, 0.5, 3.7), GUN, 0, 0.04)
        cyl((sz * BASKET_X - 0.6, 5.0, zc), (sz * BASKET_X + 0.6, 5.0, zc), 0.36, BRIGHT, 12)
        box((sz * BASKET_X, 5.75, zc + 0.9), (0.6, 0.5, 0.7), GUN, 0, 0.03)
        box((sz * BASKET_X, 5.75, zc + 1.27), (0.12, 0.12, 0.04), BLINK, 0, 0.0, WHITE, AMBER)
    arc(0, 360, 1.45, 3.5, -0.3, 0.0, DECK, 15.0, (0, 0, 0), 0.04)                      # the hub
    arc(0, 360, 3.4, 3.55, -0.36, 0.12, HAZ, 15.0)
    arc(0, 360, 1.3, 1.5, -0.6, 0.3, GUN, 15.0)


def build_basket():
    """a hoist basket: floor top at y = 0, 2.6 m square, rails on three sides (open towards -x, the girder), four slings up to the hook block at y = 4.2"""
    global cur
    cur = "lab_basket"
    box((0, -0.14, 0), (2.6, 0.28, 2.6), GUN, 0, 0.04, (0.9, 0.62, 0.2))
    box((0, -0.005, 0), (2.3, 0.03, 2.3), GRATE)
    box((-1.24, -0.04, 0), (0.14, 0.12, 2.6), HAZ)
    for sx in (-1, 1):
        for sz in (-1, 1):
            cyl((sx * 1.22, 0, sz * 1.22), (sx * 1.22, 1.1, sz * 1.22), 0.045, RED, 6)
            tube([(sx * 1.22, 1.1, sz * 1.22), (0, 4.2, 0)], 0.025, BRIGHT, 4)
    for y in (0.6, 1.1):
        tube([(-1.22, y, -1.22), (1.22, y, -1.22), (1.22, y, 1.22), (-1.22, y, 1.22)], 0.035, RED, 5)
    box((0, 4.35, 0), (0.5, 0.5, 0.36), GUN, 0, 0.04)
    cyl((-0.2, 4.45, 0), (0.2, 4.45, 0), 0.24, BRIGHT, 10)
    box((0, 4.1, 0.2), (0.12, 0.12, 0.04), BLINK, 0, 0.0, WHITE, AMBER)
    box((0, -0.3, 0), (0.6, 0.06, 0.6), LIGHT, 0, 0.0, WHITE, AMBER)


# ---------------------------------------------------------------------------------------------------------------- bake and write

STATIC = ("lab_floor", "lab_mid", "lab_ring_west", "lab_upper")
FAN = []
for _i in range(10):
    _z = 1 - (_i + 0.5) / 10 * 0.9
    _a = _i * 2.39996
    _r = math.sqrt(max(0.0, 1 - _z * _z))
    FAN.append((math.cos(_a) * _r, math.sin(_a) * _r, _z))


def bake(groups, floor):
    """occlusion per face corner by ray casting against the groups' own geometry (and the drum's floor under the static set)"""
    polys = [f[0] for g in groups for f in FACES.get(g, [])]
    verts = VERTS
    if floor:
        g0 = len(VERTS)
        verts = VERTS + [Vector((-60, -0.01, -60)), Vector((60, -0.01, -60)), Vector((60, -0.01, 60)), Vector((-60, -0.01, 60))]
        polys = polys + [[g0, g0 + 1, g0 + 2, g0 + 3]]
    tree = BVHTree.FromPolygons(verts, polys, all_triangles=False, epsilon=0.0)
    MAXD = 2.6
    wsum = sum(d[2] for d in FAN)
    out = {}
    for g in groups:
        res = []
        for idx, st, _, _, _ in FACES.get(g, []):
            pts = [VERTS[i] for i in idx]
            n = Vector((0, 0, 0))
            for i, a in enumerate(pts):
                b = pts[(i + 1) % len(pts)]
                n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
            if st > 15.5 or n.length < 1e-9:
                res.append([1.0] * len(idx))
                continue
            n.normalize()
            t, b = frame_of(n)
            c = sum(pts, Vector((0, 0, 0))) / len(pts)
            small = (pts[0] - c).length < 0.12
            ao = []
            for p in pts:
                if small and ao:
                    ao.append(ao[0])
                    continue
                o = p + (c - p) * 0.12 + n * 0.03
                occ = 0.0
                for dx, dy, dz in FAN:
                    hit = tree.ray_cast(o, t * dx + b * dy + n * dz, MAXD)
                    if hit[0] is not None:
                        occ += (1.0 - hit[3] / MAXD) * dz
                ao.append(max(0.15, 1.0 - 0.95 * occ / wsum))
            res.append(ao)
        out[g] = res
    return out


VIEW = {GUN: (0.1, 0.1, 0.11), STEEL: (0.32, 0.33, 0.35), RED: (0.45, 0.05, 0.03), DRED: (0.2, 0.04, 0.03), HAZ: (0.6, 0.4, 0.05), CONC: (0.27, 0.26, 0.24), DECK: (0.2, 0.2, 0.21),
        GRATE: (0.22, 0.2, 0.18), RUST: (0.3, 0.14, 0.07), BRASS: (0.5, 0.3, 0.08), RUBBER: (0.03, 0.03, 0.03), BEIGE: (0.5, 0.44, 0.33), BRIGHT: (0.55, 0.56, 0.6), BLACK: (0.03, 0.03, 0.04)}


def make_objects(ao):
    col = bpy.data.collections.new("COL_ChamberKit")
    bpy.context.scene.collection.children.link(col)
    mat = bpy.data.materials.new("om_paint")
    obs = []
    total = 0
    for g, faces in FACES.items():
        remap, verts, fl = {}, [], []
        for idx, _, _, _, _ in faces:
            f = []
            for i in idx:
                if i not in remap:
                    remap[i] = len(verts)
                    v = VERTS[i]
                    verts.append((v.x, -v.z, v.y))                                 # y up here -> Blender's z up; the exporter turns it back
                f.append(remap[i])
            fl.append(f)
        me = bpy.data.meshes.new("SM_" + g)
        me.from_pydata(verts, [], fl)
        n = len(me.loops)
        cols = np.ones((n, 4), dtype=np.float32)
        view = np.ones((n, 4), dtype=np.float32)
        uv0 = np.zeros((n, 2), dtype=np.float32)
        uv1 = np.zeros((n, 2), dtype=np.float32)
        li = 0
        for fi, (idx, st, tint, glow, wear) in enumerate(faces):
            for c in range(len(idx)):
                o = ao[g][fi][c]
                cols[li] = (min(tint[0], 1.0), min(tint[1], 1.0), min(tint[2], 1.0), o)
                vc = VIEW.get(st, glow)
                view[li] = (vc[0] * tint[0] * o, vc[1] * tint[1] * o, vc[2] * tint[2] * o, 1.0)
                uv0[li] = (glow[0], 1.0 - glow[1])                                 # (the exporter flips v: written flipped so it arrives as meant)
                uv1[li] = (glow[2], 1.0 - (st + wear * 0.99))
                li += 1
        ca = me.color_attributes.new("Col", 'FLOAT_COLOR', 'CORNER')
        ca.data.foreach_set("color", cols.ravel())
        cv = me.color_attributes.new("View", 'FLOAT_COLOR', 'CORNER')
        cv.data.foreach_set("color", view.ravel())
        me.uv_layers.new(name="UVMap").data.foreach_set("uv", uv0.ravel())
        me.uv_layers.new(name="UV2").data.foreach_set("uv", uv1.ravel())
        for p in me.polygons:
            p.use_smooth = True
        me.set_sharp_from_angle(angle=math.radians(32))
        me.update()
        me.materials.append(mat)
        ob = bpy.data.objects.new(g, me)
        col.objects.link(ob)
        obs.append(ob)
        tris = sum(len(p.vertices) - 2 for p in me.polygons)
        total += tris
        print("  %-14s %7d tris" % (g, tris))
    print("  total          %7d tris, %d solids" % (total, len(SOLIDS)))
    for name, base, hx, h, hz, yaw, disc in SOLIDS:
        e = bpy.data.objects.new(name, None)
        e.location = (base.x, -base.z, base.y)
        e.rotation_euler = (0, 0, yaw)
        e.scale = (hx, hz, h)
        col.objects.link(e)
        obs.append(e)
    return obs


def set_active(obs, name):
    for o in obs:
        if o.type == 'MESH':
            a = o.data.color_attributes[name]
            o.data.color_attributes.active_color = a
            o.data.color_attributes.render_color_index = list(o.data.color_attributes).index(a)


def preview(path, cam, look, lens=30):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.color_type = 'VERTEX'
    sc.display.shading.show_cavity = True
    sc.render.resolution_x, sc.render.resolution_y = 1400, 900
    sc.render.filepath = path
    cd = bpy.data.cameras.new("cam")
    cd.lens = lens
    cd.clip_end = 400
    co = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(co)
    c = Vector((cam[0], -cam[2], cam[1]))
    l = Vector((look[0], -look[2], look[1]))
    co.location = c
    co.rotation_euler = (l - c).to_track_quat('-Z', 'Y').to_euler()
    sc.camera = co
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(co)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    build_floor()
    build_mid()
    build_upper()
    build_lift()
    build_carriage()
    build_crane()
    build_basket()
    print("built: %d faces" % sum(len(f) for f in FACES.values()))
    if "--fast" in argv:
        ao = {g: [[1.0] * len(f[0]) for f in fs] for g, fs in FACES.items()}
    else:
        ao = bake(STATIC, True)
        for g in FACES:
            if g not in STATIC:
                ao.update(bake((g,), False))
    obs = make_objects(ao)
    if "--preview" in argv:
        i = argv.index("--preview")
        set_active(obs, "View")
        movers = [o for o in obs if o.type == 'MESH' and o.name not in STATIC]
        spots = {"lab_lift": (27.75 * math.cos(D(82)), -27.75 * math.sin(D(82)), 9.0), "lab_carriage": (RING_R, 0, RING_Y), "lab_crane": (0, 0, CRANE_Y), "lab_basket": (BASKET_X, -BASKET_Z, 24.0)}
        for o in movers:
            o.location = spots[o.name]
        preview(argv[i + 1], (6, 30, 62), (0, 14, -6), 24)
        if len(argv) > i + 2 and not argv[i + 2].startswith("--"):
            preview(argv[i + 2], (22, 3.2, 18), (6, 1.4, 2), 28)
        for o in movers:
            o.location = (0, 0, 0)
    if "--no-export" not in argv:
        set_active(obs, "Col")
        for o in obs:
            if o.type == 'MESH':
                o.data.color_attributes.remove(o.data.color_attributes["View"])
        out = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "omnisphere", "chamber_kit.glb"))
        os.makedirs(os.path.dirname(out), exist_ok=True)
        for o in bpy.data.objects:
            o.select_set(o in obs)
        bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True, export_apply=True, export_yup=True, export_normals=True, export_tangents=False,
                                  export_materials='EXPORT', export_vertex_color='ACTIVE', export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True,
                                  export_texcoords=True, export_cameras=False, export_lights=False, export_animations=False)
        print("wrote", out)


main()
