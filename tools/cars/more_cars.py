# The rest of FOINT CITY's fleet, in the same language as the sedan and the hatch. exec'd by build_cars.py (uses its helpers).
VIEW_K = 1.0


def back_rays(pts, step=0.04, front=False):
    """(s, u) polyline seen from behind (or from in front) -> rays"""
    y0 = -12.0 if front else 12.0
    step *= 1 + LOD
    d = Vector((0, 1, 0)) if front else Vector((0, -1, 0))
    out = []
    for (s0, u0), (s1, u1) in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(s1 - s0, u1 - u0) / step))
        for k in range(n):
            q = k / n
            out.append((Vector((s0 + (s1 - s0) * q, y0, u0 + (u1 - u0) * q)), d))
    out.append((Vector((pts[-1][0], y0, pts[-1][1])), d))
    return out


def bottom_rays(pts, step=0.05):
    out = []
    for (f0, s0), (f1, s1) in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(f1 - f0, s1 - s0) / step))
        for k in range(n + 1):
            q = k / n
            out.append((P(f0 + (f1 - f0) * q, s0 + (s1 - s0) * q, -3.0), Vector((0, 0, 1))))
    return out


def lathe_up(name, profile, material, sf=1.0, sx=1.0, f0=0.0, segs=56, sharp=35):
    """(radius, u) revolved about the vertical axis, stretched sf along the car and sx across it"""
    segs = segs * 5 // 8 if LOD and segs > 16 else segs
    rings = [[P(f0 + r * sf * math.cos(math.tau * k / segs), r * sx * math.sin(math.tau * k / segs), u) for k in range(segs)] for r, u in profile]
    ob = loft(name, rings, material)
    us = [u for _r, u in profile]
    outward(ob, P(f0, 0, (min(us) + max(us)) / 2), sharp)
    return ob


def lathe_f(name, profile, s, u, material, segs=20, sharp=35, cap_first=False, cap_last=False):
    """(f, radius) revolved about a line running along the car"""
    rings = [[P(f, s + r * math.cos(math.tau * k / segs), u + r * math.sin(math.tau * k / segs)) for k in range(segs)] for f, r in profile]
    ob = loft(name, rings, material, cap_start=cap_first, cap_end=cap_last)
    fs = [f for f, _r in profile]
    outward(ob, P((min(fs) + max(fs)) / 2, s, u), sharp)
    return ob


def box(name, f0, f1, s0, s1, u0, u1, material, r=0.03):
    """a box with softened long edges"""
    def ring(f, k):
        a, b, c, d = s0 + r * k, s1 - r * k, u0 + r * k, u1 - r * k
        return [P(f, a, c + r), P(f, a, d - r), P(f, a + r, d), P(f, b - r, d), P(f, b, d - r), P(f, b, c + r), P(f, b - r, c), P(f, a + r, c)]
    ob = loft(name, [ring(f0, 1.0), ring(f0 + r, 0.0), ring(f1 - r, 0.0), ring(f1, 1.0)], material, cap_start=True, cap_end=True)
    outward(ob, P((f0 + f1) / 2, (s0 + s1) / 2, (u0 + u1) / 2), 30)
    return ob


def solid_box(f0, f1, s0, s1, u0, u1, material):
    """a plain box, for cutting"""
    v = [P(f, s_, u) for f in (f0, f1) for s_ in (s0, s1) for u in (u0, u1)]
    ob = mesh_obj('cut', v, [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)], material, smooth=False)
    outward(ob, P((f0 + f1) / 2, (s0 + s1) / 2, (u0 + u1) / 2))
    return ob


def take_faces(ob, test):
    """the faces of ob whose centre passes test, as a new object (None: none of them); they leave ob"""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    pick = set(f.index for f in bm.faces if test(f.calc_center_median()))
    if not pick:
        bm.free()
        return None
    bm2 = bm.copy()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index in pick], context='FACES')
    bmesh.ops.delete(bm2, geom=[f for f in bm2.faces if f.index not in pick], context='FACES')
    me2 = me.copy()
    bm2.to_mesh(me2)
    bm.to_mesh(me)
    bm.free()
    bm2.free()
    ob2 = bpy.data.objects.new('taken', me2)
    bpy.context.scene.collection.objects.link(ob2)
    return ob2


def steering(d, M):
    """the wheel the driver's hands go to: a rim, three spokes and a boss, on a column. Origin at the rim's centre."""
    f, s_, u, tilt, r = d['wheel']
    c = P(f, s_, u)
    ax = P(-math.cos(tilt), 0.0, math.sin(tilt)).normalized() - Vector((0, 0, 0))      # the column: back and up, toward the driver
    ax = Vector((0.0, math.cos(tilt), math.sin(tilt)))                                   # (blender: -y is forward)
    e1 = Vector((1, 0, 0))
    e2 = ax.cross(e1).normalized()
    obs = []
    rings = []
    for k in range(20):
        a = math.tau * k / 20
        o = c + (e1 * math.cos(a) + e2 * math.sin(a)) * r
        rd = (o - c).normalized()
        rings.append([o + (rd * math.cos(b) + ax * math.sin(b)) * 0.017 for b in [math.tau * q / 6 for q in range(6)]])
    rings.append(rings[0])
    rim = loft('rim', rings, M['trim'])
    outward(rim, None, 50)
    obs.append(rim)
    for k in range(3):
        a = math.tau * k / 3 + math.pi / 2
        d_ = e1 * math.cos(a) + e2 * math.sin(a)
        t_ = ax.cross(d_)
        sp = mesh_obj('spoke', [c + d_ * 0.03 + t_ * 0.014, c + d_ * r + t_ * 0.012, c + d_ * r - t_ * 0.012, c + d_ * 0.03 - t_ * 0.014,
                                c + d_ * 0.03 + t_ * 0.014 - ax * 0.012, c + d_ * r + t_ * 0.012 - ax * 0.012, c + d_ * r - t_ * 0.012 - ax * 0.012, c + d_ * 0.03 - t_ * 0.014 - ax * 0.012],
                      [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (3, 2, 6, 7)], M['chrome'], smooth=False)
        obs.append(sp)
    col = loft('column', [[c - ax * q + (e1 * math.cos(b) + e2 * math.sin(b)) * rr for b in [math.tau * k / 10 for k in range(10)]] for q, rr in ((-0.012, 0.0005), (-0.012, 0.045), (0.02, 0.045), (0.02, 0.022), (0.34, 0.022))], M['trim'])
    outward(col, None, 40)
    obs.append(col)
    ob = join('Steer', obs)
    ob.data.transform(__import__('mathutils').Matrix.Translation(-c))
    ob.location = c
    return ob


def door_split(parts, extra, d, M, side=1):
    """the driver's door: a slab cut out of the body's flank (with whatever trim, glass and gaps lie on it), the hole it leaves, and behind it a cabin hollowed out of the body with a seat,
    a dash and the steering wheel. d: f0, f1, u0, u1 (the door, along the car and up), s_in (its inner face), s_out (the hinge line), belt (above it, the side glass from 0.5 outward goes with
    the door; None: the glass is on the body), cab (f0, f1, u0, u1: the cabin), seat (f, s, hips), wheel (f, s, u, tilt, r). Returns [Door, Steer]."""
    body = parts['paint'][0]
    f0, f1, u0, u1, s_in = d['f0'], d['f1'], d['u0'], d['u1'], d['s_in']
    c0, c1, cu0, cu1 = d['cab']
    boolean(body, solid_box(c0, c1, -s_in, s_in, cu0, cu1, M['cabin']))
    chunk = body.copy()
    chunk.data = body.data.copy()
    bpy.context.scene.collection.objects.link(chunk)
    boolean(chunk, solid_box(f0, f1, side * s_in, side * 3.0, u0, u1, M['cabin']), 'INTERSECT')
    g = 0.007
    boolean(body, solid_box(f0 - g, f1 + g, side * (s_in - 0.012), side * 3.0, u0 - g, u1 + g, M['cabin']))
    outward(body, None, 38)
    outward(chunk, None, 38)
    belt = d.get('belt')

    def on_door(c):
        f, s_, u = -c.y, c.x * side, c.z
        if f <= f0 or f >= f1:
            return False
        if s_ > s_in - 0.03 and u0 < u < u1 and (belt is None or u < belt + 0.03):
            return True
        return belt is not None and u >= belt - 0.02 and s_ > 0.5

    moved = [chunk]
    for key in list(parts.keys()):
        keep = []
        for ob in parts[key]:
            if ob is None or ob is body:
                keep.append(ob)
                continue
            t = take_faces(ob, on_door)
            if t is not None:
                moved.append(t)
            if len(ob.data.polygons) > 0:
                keep.append(ob)
            else:
                bpy.data.objects.remove(ob)
        parts[key] = keep
    for ob in list(extra):
        t = take_faces(ob, on_door)
        if t is not None:
            moved.append(t)
    # the cabin: a seat and its back, a dash across the front
    sf, ss, su = d['seat']
    parts['trim'].append(box('cushion', sf - 0.28, sf + 0.24, ss - 0.24, ss + 0.24, su - 0.20, su - 0.08, M['seat'], 0.035))
    parts['trim'].append(box('back', sf - 0.42, sf - 0.26, ss - 0.24, ss + 0.24, su - 0.12, su + 0.50, M['seat'], 0.035))
    parts['trim'].append(box('cushion2', sf - 0.28, sf + 0.24, -ss - 0.24, -ss + 0.24, su - 0.20, su - 0.08, M['seat'], 0.035))
    parts['trim'].append(box('back2', sf - 0.42, sf - 0.26, -ss - 0.24, -ss + 0.24, su - 0.12, su + 0.50, M['seat'], 0.035))
    wf, ws, wu, tilt, r = d['wheel']
    dash_f = wf + 0.30
    if dash_f + 0.02 < c1:
        top = min(wu - 0.02, (belt if belt is not None else 9.0) - 0.08)      # (under the scuttle: it must not come up through the bonnet)
        parts['trim'].append(box('dash', dash_f, c1 + 0.02, -s_in + 0.01, s_in - 0.01, top - 0.30, top, M['trim'], 0.03))
    door = join('Door', moved)
    hinge = P(f1, side * d['s_out'], 0.0)
    door.data.transform(__import__('mathutils').Matrix.Translation(-hinge))
    door.location = hinge
    return [door, steering(d, M)]


def greenhouse(parts, cb, M, roof, pillars, belt):
    """a painted roof and pillars over a canopy, so it reads as a car's windows and not a glass bubble. roof: (f front, f back, width, how much narrower at the very front, and at the back, 0..1);
    pillars: (f at the belt, f at the roof, width) each side. cb: the canopy's bvh."""
    r0, r1, rw, pinch, pinch_b = roof
    parts['paint'].append(ribbon('roof', cb, top_rays([(r0, 0.0), (r1, 0.0)], 0.06), lambda k: rw * (1.0 - pinch * max(0.0, 1.0 - k * 4.0) ** 2) * (1.0 - pinch_b * max(0.0, (k - 0.7) / 0.3) ** 2), 0.007, M['paint'], across=12, snap=1.0))
    for sd in (1, -1):
        for fb, ft, w in pillars:
            parts['paint'].append(ribbon('pillar', cb, side_rays([(fb, belt), (ft, belt + 0.8)], sd, 0.025), w, 0.008, M['paint'], across=2))


def front_face(parts, bvh, M, f0, u, a, h, bumper=None, grille=True):
    """the face of a car: a lamp block at each corner with an amber indicator inboard of it, a slatted chrome grille between, a plate, a heavy bumper under it (bumper: its height)"""
    parts['trim'].append(ribbon('head_bezel', bvh, water_rays(f0, u, -a - 4, a + 4, 70), h + 0.06, 0.003, M['trim'], across=2))
    for sd in (1, -1):
        parts['head'].append(ribbon('head', bvh, water_rays(f0, u, sd * a * 0.56, sd * a, 24), h, 0.006, M['head'], across=2))
        parts['head'].append(ribbon('ind', bvh, water_rays(f0, u, sd * a * 0.44, sd * a * 0.53, 8), h, 0.006, M['amber'], across=2))
    if grille:
        for i in range(4):
            parts['chrome'].append(ribbon('slat', bvh, water_rays(f0, u - h * 0.5 + h * (i + 0.5) / 4.0, -a * 0.38, a * 0.38, 30), h * 0.11, 0.006, M['chrome']))
    if bumper is not None:
        parts['trim'].append(tube('bump_f', bvh, water_rays(f0, bumper, -a - 2, a + 2, 44), 0.06, 0.012, M['trim'], squash=0.75))
        parts['chrome'].append(ribbon('plate_f', bvh, water_rays(f0, bumper, -7, 7, 8), 0.095, 0.07, M['plate']))


def rear_face(parts, bvh, M, f0, u, a, h, bumper=None):
    """the tail: a dark panel across it with a red lamp block at each end, an amber indicator inboard, the plate in the middle; a bumper under it. a: the angle the panel starts at (180 is dead astern)"""
    parts['trim'].append(ribbon('tail_bezel', bvh, water_rays(f0, u, a - 3, 360 - a + 3, 80), h + 0.06, 0.003, M['trim'], across=2))
    w = 180.0 - a
    for sd in (1, -1):
        parts['tail'].append(ribbon('tail', bvh, water_rays(f0, u, 180 + sd * w * 0.50, 180 + sd * w, 24), h, 0.006, M['tail'], across=2))
        parts['tail'].append(ribbon('ind_r', bvh, water_rays(f0, u, 180 + sd * w * 0.36, 180 + sd * w * 0.47, 8), h, 0.006, M['amber'], across=2))
    parts['chrome'].append(ribbon('plate_r', bvh, water_rays(f0, u, 180 - w * 0.2, 180 + w * 0.2, 8), h * 1.05, 0.006, M['plate']))
    if bumper is not None:
        parts['trim'].append(tube('bump_r', bvh, water_rays(f0, bumper, a - 2, 360 - a + 2, 44), 0.06, 0.012, M['trim'], squash=0.75))


def fittings(parts, bvh, M, mirror=None, handles=(), antenna=None, exhaust=None, roof_rack=None):
    """the small things a real car carries. mirror: (f, u) on each flank; handles: (f, u) on each flank; antenna: (f, s) a whip; exhaust: (s, u) a pipe out of the tail;
    roof_rack: (bvh of the roof, f front, f back, s): two rails and their feet"""
    for sd in (1, -1):
        if mirror is not None:
            hit = bvh.ray_cast(P(mirror[0], sd * 3.0, mirror[1]), Vector((-sd, 0, 0)))[0]
            if hit is not None:
                s0 = abs(hit.x)
                parts['trim'].append(box('mirror_arm', mirror[0] - 0.02, mirror[0] + 0.03, sd * (s0 - 0.03), sd * (s0 + 0.09), mirror[1] + 0.0, mirror[1] + 0.035, M['trim'], 0.012))
                parts['paint'].append(box('mirror', mirror[0] - 0.035, mirror[0] + 0.045, sd * (s0 + 0.07), sd * (s0 + 0.22), mirror[1] - 0.02, mirror[1] + 0.085, M['paint'], 0.02))
                parts['chrome'].append(box('mirror_glass', mirror[0] - 0.04, mirror[0] - 0.03, sd * (s0 + 0.085), sd * (s0 + 0.205), mirror[1] - 0.008, mirror[1] + 0.073, M['chrome'], 0.004))
        for hf, hu in handles:
            parts['chrome'].append(ribbon('handle', bvh, side_rays([(hf, hu), (hf - 0.14, hu)], sd, 0.03), 0.03, 0.014, M['chrome']))
            parts['gap'].append(ribbon('handle_cup', bvh, side_rays([(hf + 0.02, hu), (hf - 0.16, hu)], sd, 0.03), 0.06, 0.004, M['gap']))
        if roof_rack is not None:
            rb, r0, r1, rs = roof_rack
            pts = []
            for k in range(9):
                f = r0 + (r1 - r0) * k / 8
                hit = rb.ray_cast(P(f, sd * rs, 4.0), Vector((0, 0, -1)))[0]
                if hit is not None:
                    pts.append(hit + Vector((0, 0, 0.06)))
            if len(pts) > 1:
                rail = loft('rail', [[q + Vector((0.014 * math.cos(b), 0, 0.014 * math.sin(b))) for b in [math.tau * i / 6 for i in range(6)]] for q in pts], M['trim'], cap_start=True, cap_end=True)
                outward(rail, None, 50)
                parts['trim'].append(rail)
                for q in (pts[1], pts[-2]):
                    parts['trim'].append(box('foot', -q.y - 0.03, -q.y + 0.03, q.x - 0.02, q.x + 0.02, q.z - 0.075, q.z + 0.005, M['trim'], 0.008))
    if antenna is not None:
        hit = bvh.ray_cast(P(antenna[0], antenna[1], 4.0), Vector((0, 0, -1)))[0]
        if hit is not None:
            rod = loft('antenna', [[hit + Vector((rr * math.cos(b), q * 0.22, q + rr * math.sin(b) * 0.0)) + Vector((0, rr * math.sin(b), 0)) for b in [math.tau * i / 5 for i in range(5)]] for q, rr in ((-0.01, 0.012), (0.03, 0.012), (0.03, 0.005), (0.62, 0.003))], M['trim'], cap_end=True)
            outward(rod, None, 50)
            parts['trim'].append(rod)
    if exhaust is not None:
        hit = bvh.ray_cast(P(-9.0, exhaust[0], exhaust[1]), Vector((0, -1, 0)))[0]      # (blender -y is forward: from behind)
        if hit is not None:
            ft = -hit.y
            parts['chrome'].append(lathe_f('exhaust', [(ft + 0.10, 0.034), (ft - 0.07, 0.034), (ft - 0.07, 0.026), (ft + 0.02, 0.026)], exhaust[0], exhaust[1], M['chrome'], segs=12))


def finish(parts, extra, wheels, M, blades=9, door=None):
    more = []
    if door is not None and not LOD:      # (the street's lighter mesh keeps its body whole)
        more = door_split(parts, extra, door, M)
    out = [join('Body', [o for k in ('paint', 'paint2', 'trim', 'gap', 'glass', 'head', 'tail', 'neon', 'chrome', 'sign') for o in parts.get(k, [])])] + extra + more
    for i, (f, s, r, w) in enumerate(wheels):
        out.append(wheel('Wheel_%d' % i, f, s, r, r, w, M, blades=blades))
    return out


def new_parts(body):
    return {'paint': [body], 'paint2': [], 'trim': [], 'gap': [], 'glass': [], 'head': [], 'tail': [], 'neon': [], 'chrome': [], 'sign': []}


def arches(body, M, spec):
    """spec: (f, r_wheel, s_inner, clip_top or None). Cuts both sides."""
    for f, r, s_in, clip in spec:
        for sd in (1, -1):
            boolean(body, cyl_cutter(f, r, r + 0.075, sd * s_in, sd * 2.2, M['trim'], clip_top=clip))
    outward(body, None, 38)


def taxi():
    """TAXI: the cruiser's platform as an upright cab: tall boxy glasshouse, amber paint, checker band, a lit roof sign"""
    M = materials(0xb07c08, 0xffa424)
    M['sign'] = mat('Sign', (1.0, 0.55, 0.10), emit=(1.0, 0.50, 0.08), strength=8.0)
    AX_F, AX_R, TRACK, WR, WW = 1.42, -1.42, 0.80, 0.35, 0.25
    st = [(-2.31, 0.62, 0.42, 0.74, 0.84, 0.82), (-2.18, 0.86, 0.32, 0.80, 0.92, 0.86), (-1.85, 0.94, 0.23, 0.86, 0.96), (-1.42, 0.975, 0.20, 0.88, 0.97),
          (-0.60, 0.96, 0.20, 0.88, 0.97), (0.30, 0.95, 0.20, 0.86, 0.93), (0.90, 0.95, 0.20, 0.86, 0.88), (1.42, 0.965, 0.21, 0.87, 0.83),
          (1.85, 0.93, 0.23, 0.80, 0.76), (2.12, 0.84, 0.28, 0.66, 0.66, 0.86), (2.26, 0.68, 0.34, 0.56, 0.57, 0.84), (2.32, 0.48, 0.39, 0.50, 0.52, 0.80)]
    body = build_body('body', st, M['paint'])
    arches(body, M, [(AX_F, WR, 0.66, None), (AX_R, WR, 0.66, None)])
    bvh = bvh_of(body)
    parts = new_parts(body)
    for f in (AX_F, AX_R):
        for sd in (1, -1):
            parts['trim'].append(arch_lip('lip', f, WR, WR + 0.075, sd * 0.94, M['trim']))
    can = [(1.10, 0.25, 0.82, 0.82), (0.92, 0.56, 0.84, 1.00), (0.55, 0.70, 0.86, 1.22), (0.10, 0.75, 0.88, 1.36), (-0.50, 0.76, 0.90, 1.40),
           (-1.05, 0.74, 0.90, 1.36), (-1.45, 0.66, 0.90, 1.20), (-1.72, 0.50, 0.90, 1.02), (-1.86, 0.30, 0.88, 0.90)]
    canopy = build_canopy('glass', can, M['glass'], expo=4.2)
    canopy.name = 'Glass'
    cb = bvh_of(canopy)
    greenhouse(parts, cb, M, (0.50, -1.72, 1.30, 0.22, 0.45), [(0.66, 0.30, 0.11), (-0.36, -0.40, 0.12), (-1.52, -1.22, 0.20)], 0.84)
    # the roof sign: a lit amber box on a dark foot
    parts['trim'].append(box('sign_foot', -0.36, -0.10, -0.36, 0.36, 1.37, 1.43, M['trim'], 0.02))
    parts['sign'].append(box('sign', -0.33, -0.13, -0.33, 0.33, 1.425, 1.56, M['sign'], 0.03))
    front_face(parts, bvh, M, 1.0, 0.508, 58, 0.08, bumper=0.355)
    rear_face(parts, bvh, M, -1.0, 0.765, 121, 0.09, bumper=0.44)
    for sd in (1, -1):
        # the checker band: two rows of squares down each flank
        for row in range(2):
            for i in range(11):
                if (i + row) % 2 == 0:
                    f0 = 0.84 - i * 0.17
                    parts['gap'].append(ribbon('chk', bvh, side_rays([(f0, 0.60 + row * 0.085), (f0 - 0.17, 0.60 + row * 0.085)], sd, 0.03), 0.085, 0.003, M['gap']))
        parts['trim'].append(ribbon('sill', bvh, side_rays([(0.98, 0.27), (-0.98, 0.265)], sd), 0.12, 0.004, M['trim'], across=2))
        parts['gap'].append(ribbon('door_f', bvh, side_rays([(0.70, 0.33), (0.70, 0.90)], sd, 0.03), 0.012, 0.0025, M['gap']))
        parts['gap'].append(ribbon('door_m', bvh, side_rays([(-0.36, 0.33), (-0.36, 0.92)], sd, 0.03), 0.012, 0.0025, M['gap']))
        parts['gap'].append(ribbon('door_r', bvh, side_rays([(-0.98, 0.52), (-1.08, 0.70), (-1.20, 0.92)], sd, 0.03), 0.009, 0.0025, M['gap']))
    fittings(parts, bvh, M, mirror=(0.86, 0.82), handles=[(0.12, 0.80), (-0.52, 0.80)], antenna=(-1.80, -0.55), exhaust=(-0.45, 0.31))
    door = {'f0': -0.36, 'f1': 0.70, 'u0': 0.33, 'u1': 3.0, 's_in': 0.80, 's_out': 0.95, 'belt': 0.87, 'cab': (-0.95, 0.95, 0.27, 3.0),
            'seat': (0.10, 0.42, 0.46), 'wheel': (0.50, 0.42, 0.88, 0.55, 0.17)}
    return finish(parts, [canopy], [(AX_F, TRACK, WR, WW), (AX_F, -TRACK, WR, WW), (AX_R, TRACK, WR, WW), (AX_R, -TRACK, WR, WW)], M, blades=11, door=door)


def van():
    """VAN: a one-box bullet: sloped visor of glass wrapping the nose, slab flanks with a light line, tall lamps up the back corners"""
    global VIEW_K
    VIEW_K = 1.25
    M = materials(0x24262c, 0x8a3aff)
    AX_F, AX_R, TRACK, WR, WW = 1.62, -1.62, 0.86, 0.36, 0.25
    st = [(-2.50, 0.80, 0.50, 1.70, 1.86, 0.90), (-2.42, 0.93, 0.36, 1.82, 1.98, 0.92), (-1.90, 0.985, 0.27, 1.88, 2.04, 0.94), (-0.50, 0.985, 0.26, 1.88, 2.05, 0.94),
          (0.60, 0.985, 0.26, 1.86, 2.03, 0.94), (1.30, 0.98, 0.26, 1.74, 1.93, 0.94), (1.85, 0.95, 0.28, 1.45, 1.66, 0.92), (2.25, 0.87, 0.32, 1.02, 1.16, 0.90),
          (2.44, 0.70, 0.38, 0.76, 0.84, 0.86), (2.51, 0.50, 0.44, 0.62, 0.68, 0.80)]
    body = build_body('body', st, M['paint'], shoulder=0.85)
    arches(body, M, [(AX_F, WR, 0.70, None), (AX_R, WR, 0.70, None)])
    bvh = bvh_of(body)
    parts = new_parts(body)
    for f in (AX_F, AX_R):
        for sd in (1, -1):
            parts['trim'].append(arch_lip('lip', f, WR, WR + 0.075, sd * 0.965, M['trim'], radial=0.04))
    # glass: one visor round the nose
    parts['trim'].append(ribbon('visor_frame', bvh, water_rays(1.0, 1.42, -104, 104, 110), 0.70, 0.003, M['trim'], across=6, snap=0.6))
    parts['glass'].append(ribbon('visor', bvh, water_rays(1.0, 1.42, -101, 101, 110), 0.60, 0.006, M['glass'], across=6, snap=0.6))
    front_face(parts, bvh, M, 1.2, 0.705, 56, 0.10, bumper=0.46)
    parts['chrome'].append(ribbon('plate_r', bvh, back_rays([(-0.22, 0.70), (0.22, 0.70)]), 0.11, 0.006, M['plate']))
    parts['trim'].append(tube('bump_r', bvh, water_rays(-1.2, 0.50, 132, 228, 40), 0.055, 0.01, M['trim'], squash=0.8))
    # the back: a split door, a lamp up each corner, a bar across the top
    for sd in (1, -1):
        parts['trim'].append(ribbon('tail_bezel', bvh, back_rays([(sd * 0.74, 0.80), (sd * 0.76, 1.72)]), 0.12, 0.003, M['trim'], across=2))
        parts['tail'].append(ribbon('tail', bvh, back_rays([(sd * 0.74, 0.84), (sd * 0.76, 1.68)]), 0.05, 0.006, M['tail']))
    parts['tail'].append(ribbon('tail_top', bvh, back_rays([(-0.55, 1.80), (0.55, 1.80)]), 0.035, 0.006, M['tail']))
    parts['gap'].append(ribbon('door_split', bvh, back_rays([(0.0, 0.60), (0.0, 1.74)], 0.03), 0.010, 0.0025, M['gap']))
    for sd in (1, -1):
        parts['neon'].append(ribbon('pin', bvh, side_rays([(0.72, 1.02), (-2.30, 1.02)], sd), 0.02, 0.004, M['neon']))
        parts['trim'].append(ribbon('band', bvh, side_rays([(0.72, 0.92), (-2.30, 0.92)], sd), 0.14, 0.003, M['trim'], across=2))
        parts['trim'].append(ribbon('sill', bvh, side_rays([(1.15, 0.33), (-1.15, 0.33)], sd), 0.13, 0.004, M['trim'], across=2))
        parts['gap'].append(ribbon('door_f', bvh, side_rays([(0.82, 0.42), (0.82, 1.80)], sd, 0.03), 0.012, 0.0025, M['gap']))
        # the sliding door and its rail
        parts['gap'].append(ribbon('slide', bvh, side_rays([(-0.20, 0.42), (-0.20, 1.80), (-1.25, 1.80), (-1.25, 0.60)], sd, 0.03), 0.010, 0.0025, M['gap']))
        parts['gap'].append(ribbon('rail', bvh, side_rays([(-0.20, 1.30), (-2.20, 1.30)], sd, 0.03), 0.02, 0.003, M['gap']))
        for i in range(4):      # vents high on the rear quarter
            parts['gap'].append(ribbon('vent', bvh, side_rays([(-1.55 - i * 0.14, 1.50), (-1.62 - i * 0.14, 1.74)], sd, 0.03), 0.045, 0.003, M['gap']))
    # a roof pod
    parts['trim'].append(box('roof_pod', -1.9, -0.3, -0.5, 0.5, 2.0, 2.13, M['trim'], 0.05))
    fittings(parts, bvh, M, mirror=(0.95, 1.12), handles=[(-0.02, 0.80), (-1.02, 0.80)], antenna=(1.0, 0.6), exhaust=(-0.55, 0.36), roof_rack=(bvh, 0.9, -2.2, 0.72))
    door = {'f0': -0.20, 'f1': 0.82, 'u0': 0.42, 'u1': 1.80, 's_in': 0.84, 's_out': 0.98, 'belt': None, 'cab': (-1.2, 1.15, 0.45, 1.85),
            'seat': (0.12, 0.50, 0.90), 'wheel': (0.54, 0.50, 1.34, 0.95, 0.19)}
    return finish(parts, [], [(AX_F, TRACK, WR, WW), (AX_F, -TRACK, WR, WW), (AX_R, TRACK, WR, WW), (AX_R, -TRACK, WR, WW)], M, door=door)


def truck():
    """BOX TRUCK: a cab-over bullet nose pulling a rounded cargo pod on a dark spine: six fat wheels, big mudguards, light lines along the pod's edges"""
    global VIEW_K
    VIEW_K = 1.75
    M = materials(0x3a1012, 0xff2a3a)
    M['paint2'] = mat('Paint2', srgb(0x26282e), metallic=0.75, rough=0.36, coat=1.0)
    WR, WW, TRACK = 0.44, 0.32, 1.03
    cab_st = [(1.70, 1.00, 0.62, 2.30, 2.46, 0.92), (1.80, 1.12, 0.52, 2.38, 2.54, 0.94), (2.40, 1.17, 0.46, 2.36, 2.52, 0.94), (2.90, 1.16, 0.46, 2.15, 2.32, 0.94),
              (3.30, 1.10, 0.48, 1.55, 1.75, 0.92), (3.52, 1.00, 0.54, 1.05, 1.16, 0.90), (3.63, 0.78, 0.62, 0.82, 0.88, 0.85)]
    cab = build_body('cab', cab_st, M['paint'], shoulder=0.85)
    arches(cab, M, [(2.7, WR, 0.82, None)])
    bvh = bvh_of(cab)
    parts = new_parts(cab)
    for sd in (1, -1):
        parts['trim'].append(arch_lip('lip', 2.7, WR, WR + 0.075, sd * 1.14, M['trim'], radial=0.05, axial=0.06))
    parts['trim'].append(ribbon('visor_frame', bvh, water_rays(2.2, 1.78, -106, 106, 110), 0.80, 0.003, M['trim'], across=6, snap=0.6))
    parts['glass'].append(ribbon('visor', bvh, water_rays(2.2, 1.78, -103, 103, 110), 0.70, 0.006, M['glass'], across=6, snap=0.6))
    front_face(parts, bvh, M, 2.4, 0.985, 54, 0.12, bumper=0.70)
    parts['gap'].append(ribbon('grille', bvh, water_rays(2.4, 1.18, -30, 30, 40), 0.16, 0.003, M['gap'], across=3))
    for sd in (1, -1):
        parts['gap'].append(ribbon('door', bvh, side_rays([(2.05, 0.70), (2.05, 2.20), (3.00, 2.20), (3.00, 0.70)], sd, 0.03), 0.012, 0.0025, M['gap']))
        parts['neon'].append(ribbon('pin', bvh, side_rays([(3.05, 1.24), (1.85, 1.24)], sd), 0.02, 0.004, M['neon']))
        for i in range(3):      # roof marker lamps
            parts['sign_'] = None
    # the cargo pod
    pod_st = [(-3.63, 1.06, 1.08, 3.00, 3.14, 0.95), (-3.52, 1.19, 0.98, 3.10, 3.26, 0.97), (-1.00, 1.20, 0.96, 3.12, 3.30, 0.97), (1.48, 1.19, 0.98, 3.10, 3.26, 0.97), (1.60, 1.06, 1.08, 3.00, 3.14, 0.95)]
    cargo = build_body('cargo', pod_st, M['paint2'], shoulder=0.95, sill=0.95)
    pb = bvh_of(cargo)
    parts['paint2'].append(cargo)
    for sd in (1, -1):
        parts['neon'].append(ribbon('edge', pb, side_rays([(1.40, 2.98), (-3.45, 2.98)], sd), 0.022, 0.004, M['neon']))
        parts['trim'].append(ribbon('band', pb, side_rays([(1.45, 1.42), (-3.50, 1.42)], sd), 0.34, 0.003, M['trim'], across=2))
        parts['neon'].append(ribbon('band_line', pb, side_rays([(1.40, 1.61), (-3.45, 1.61)], sd), 0.016, 0.005, M['neon']))
        for f in (0.45, -0.70, -1.85, -3.0):
            parts['gap'].append(ribbon('seam', pb, side_rays([(f, 1.02), (f, 3.08)], sd, 0.05), 0.012, 0.0025, M['gap']))
        parts['trim'].append(ribbon('tail_bezel', pb, back_rays([(sd * 0.98, 1.25), (sd * 0.98, 2.95)]), 0.12, 0.003, M['trim'], across=2))
        parts['tail'].append(ribbon('tail', pb, back_rays([(sd * 0.98, 1.30), (sd * 0.98, 2.90)]), 0.05, 0.006, M['tail']))
        # mudguards over the twin rear axles, tanks between the axles
        parts['trim'].append(arch_lip('guard', -1.9, WR, WR + 0.07, sd * 1.03, M['trim'], a0=20, a1=175, radial=0.035, axial=0.19))
        parts['trim'].append(arch_lip('guard', -2.9, WR, WR + 0.07, sd * 1.03, M['trim'], a0=5, a1=160, radial=0.035, axial=0.19))
        parts['chrome'].append(lathe_f('tank', [(1.25, 0.0005), (1.25, 0.24), (1.18, 0.27), (-0.72, 0.27), (-0.80, 0.24), (-0.80, 0.0005)], sd * 0.90, 0.70, M['rim']))
    parts['gap'].append(ribbon('door_split', pb, back_rays([(0.0, 1.10), (0.0, 3.05)], 0.05), 0.012, 0.0025, M['gap']))
    parts['gap'].append(ribbon('door_frame', pb, back_rays([(-0.86, 1.10), (-0.86, 3.05), (0.86, 3.05), (0.86, 1.10), (-0.86, 1.10)], 0.05), 0.012, 0.0025, M['gap']))
    parts['tail'].append(ribbon('tail_top', pb, back_rays([(-0.70, 3.12), (0.70, 3.12)]), 0.035, 0.006, M['tail']))
    # the spine it all sits on
    parts['trim'].append(box('spine', -3.55, 1.80, -0.52, 0.52, 0.52, 1.00, M['trim'], 0.05))
    parts['trim'].append(box('underrun', -3.66, -3.50, -1.10, 1.10, 0.52, 0.72, M['trim'], 0.04))
    parts.pop('sign_', None)
    wl = [(2.7, TRACK, WR, WW), (2.7, -TRACK, WR, WW), (-1.9, TRACK, WR, WW + 0.04), (-1.9, -TRACK, WR, WW + 0.04), (-2.9, TRACK, WR, WW + 0.04), (-2.9, -TRACK, WR, WW + 0.04)]
    fittings(parts, bvh, M, mirror=(3.05, 1.62), handles=[(2.30, 1.20)], antenna=(2.0, 0.9))
    door = {'f0': 2.05, 'f1': 3.00, 'u0': 0.70, 'u1': 2.20, 's_in': 1.00, 's_out': 1.16, 'belt': None, 'cab': (1.90, 2.95, 1.00, 2.20),
            'seat': (2.46, 0.55, 1.18), 'wheel': (2.86, 0.55, 1.60, 1.0, 0.21)}
    return finish(parts, [], wl, M, door=door)


def bus():
    """CITY BUS: a streamliner: bullet nose, one band of glass down each flank, skirted rear wheels, an amber destination bar"""
    global VIEW_K
    VIEW_K = 2.6
    M = materials(0x1c2230, 0xff7a18)
    M['sign'] = mat('Sign', (1.0, 0.55, 0.10), emit=(1.0, 0.50, 0.08), strength=8.0)
    AX_F, AX_R, TRACK, WR, WW = 3.8, -3.5, 1.10, 0.48, 0.32
    st = [(-5.76, 1.00, 0.62, 2.60, 2.78, 0.92), (-5.62, 1.20, 0.46, 2.78, 2.96, 0.95), (-4.60, 1.27, 0.36, 2.84, 3.04, 0.96), (-2.00, 1.27, 0.35, 2.85, 3.05, 0.96),
          (1.00, 1.27, 0.35, 2.85, 3.05, 0.96), (3.90, 1.27, 0.35, 2.84, 3.04, 0.96), (4.90, 1.24, 0.36, 2.66, 2.90, 0.95), (5.40, 1.14, 0.40, 2.10, 2.36, 0.93),
          (5.68, 0.96, 0.48, 1.30, 1.45, 0.90), (5.77, 0.70, 0.56, 0.95, 1.02, 0.85)]
    body = build_body('body', st, M['paint'], shoulder=0.85)
    arches(body, M, [(AX_F, WR, 0.92, None), (AX_R, WR, 0.92, 0.72)])
    bvh = bvh_of(body)
    parts = new_parts(body)
    for sd in (1, -1):
        parts['trim'].append(arch_lip('lip', AX_F, WR, WR + 0.075, sd * 1.25, M['trim'], radial=0.05, axial=0.06))
    # glass: the windscreen wraps the nose, then one long band down each flank
    parts['trim'].append(ribbon('screen_frame', bvh, water_rays(3.0, 1.78, -52, 52, 90), 1.24, 0.003, M['trim'], across=8, snap=0.8))
    parts['glass'].append(ribbon('screen', bvh, water_rays(3.0, 1.78, -50, 50, 90), 1.12, 0.006, M['glass'], across=8, snap=0.8))
    for sd in (1, -1):
        parts['trim'].append(ribbon('band_frame', bvh, side_rays([(4.25, 1.78), (-5.25, 1.78)], sd, 0.12), 1.14, 0.003, M['trim'], across=4, snap=0.8))
        parts['glass'].append(ribbon('band', bvh, side_rays([(4.20, 1.78), (-5.20, 1.78)], sd, 0.12), 1.02, 0.006, M['glass'], across=4, snap=0.8))
        for f in (3.05, 1.55, 0.05, -1.45, -2.95, -4.45):      # pillars
            parts['trim'].append(ribbon('pillar', bvh, side_rays([(f, 1.22), (f, 2.34)], sd, 0.06), 0.09, 0.008, M['trim']))
        parts['neon'].append(ribbon('pin', bvh, side_rays([(4.6, 1.08), (-5.4, 1.08)], sd, 0.12), 0.03, 0.004, M['neon']))
        parts['neon'].append(ribbon('roofline', bvh, side_rays([(4.2, 2.52), (-5.3, 2.52)], sd, 0.12), 0.02, 0.004, M['neon']))
        parts['trim'].append(ribbon('sill', bvh, side_rays([(3.15, 0.46), (-2.85, 0.46)], sd, 0.12), 0.16, 0.004, M['trim'], across=2))
        parts['neon'].append(ribbon('under', bvh, side_rays([(3.10, 0.39), (-2.80, 0.39)], sd, 0.12), 0.02, 0.006, M['neon']))
        parts['gap'].append(ribbon('skirt', bvh, side_rays([(-2.85, 0.76), (-4.15, 0.76)], sd, 0.05), 0.012, 0.0025, M['gap']))
        parts['trim'].append(ribbon('tail_bezel', bvh, back_rays([(sd * 1.0, 0.90), (sd * 1.0, 2.40)]), 0.13, 0.003, M['trim'], across=2))
        parts['tail'].append(ribbon('tail', bvh, back_rays([(sd * 1.0, 0.95), (sd * 1.0, 2.35)]), 0.055, 0.006, M['tail']))
    # doors on the kerb side
    for f0, f1 in ((4.05, 3.15), (-0.55, -1.40)):
        parts['gap'].append(ribbon('door', bvh, side_rays([(f0, 0.50), (f0, 2.36), (f1, 2.36), (f1, 0.50)], -1, 0.05), 0.016, 0.009, M['gap']))
        parts['gap'].append(ribbon('door_mid', bvh, side_rays([((f0 + f1) / 2, 0.50), ((f0 + f1) / 2, 2.36)], -1, 0.05), 0.012, 0.009, M['gap']))
    parts['trim'].append(ribbon('sign_bezel', bvh, water_rays(3.0, 2.52, -24, 24, 40), 0.30, 0.004, M['trim'], across=3, snap=0.5))
    parts['sign'].append(ribbon('sign', bvh, water_rays(3.0, 2.52, -21, 21, 40), 0.18, 0.008, M['sign'], across=3, snap=0.5))
    front_face(parts, bvh, M, 3.6, 1.025, 47, 0.13, bumper=0.68)
    fittings(parts, bvh, M, mirror=(5.05, 1.95))
    parts['trim'].append(tube('bump_r', bvh, water_rays(-3.6, 0.66, 135, 225, 40), 0.07, 0.01, M['trim'], squash=0.8))
    parts['tail'].append(ribbon('tail_top', bvh, back_rays([(-0.8, 2.62), (0.8, 2.62)]), 0.04, 0.006, M['tail']))
    parts['trim'].append(ribbon('rear_screen', bvh, back_rays([(-0.80, 1.95), (0.80, 1.95)], 0.08), 0.70, 0.004, M['glass'], across=4, snap=0.6))
    for i in range(5):      # engine grille
        parts['gap'].append(ribbon('grille', bvh, back_rays([(-0.62, 0.95 + i * 0.09), (0.62, 0.95 + i * 0.09)], 0.08), 0.04, 0.003, M['gap']))
    # roof pods
    parts['trim'].append(box('pod_a', 0.6, 3.2, -0.62, 0.62, 2.98, 3.17, M['trim'], 0.07))
    parts['trim'].append(box('pod_b', -4.4, -1.6, -0.62, 0.62, 2.98, 3.17, M['trim'], 0.07))
    wl = [(AX_F, TRACK, WR, WW), (AX_F, -TRACK, WR, WW), (AX_R, TRACK, WR, WW), (AX_R, -TRACK, WR, WW)]
    return finish(parts, [], wl, M, blades=13)


def saucer_g():
    """GRAY SAUCER: a hovering disc, a little longer than wide: gunmetal hull, a lit rim, a tall glass dome, a ring of light underneath"""
    M = materials(0x40454e, 0x9fe8ff, lit=True)
    SF, SX = 1.90, 1.30
    hull = lathe_up('hull', [(0.0005, 0.44), (0.30, 0.40), (0.42, 0.36), (0.70, 0.40), (0.93, 0.52), (1.0, 0.60), (0.94, 0.67), (0.72, 0.77), (0.46, 0.85), (0.40, 0.90), (0.0005, 0.92)], M['paint'], SF, SX, sharp=50)
    bvh = bvh_of(hull)
    parts = new_parts(hull)
    parts['neon'].append(lathe_up('rim', [(0.985, 0.572), (1.006, 0.585), (1.006, 0.615), (0.985, 0.628)], M['neon'], SF, SX))
    parts['trim'].append(lathe_up('rim_bezel', [(0.955, 0.535), (1.002, 0.57), (1.002, 0.63), (0.955, 0.662)], M['trim'], SF, SX))
    parts['neon'].append(lathe_up('lift', [(0.44, 0.352), (0.66, 0.385)], M['neon'], SF, SX))
    parts['trim'].append(lathe_up('lift_dish', [(0.0005, 0.42), (0.26, 0.385), (0.43, 0.345), (0.445, 0.36)], M['trim'], SF, SX))
    parts['trim'].append(lathe_up('lift_lip', [(0.655, 0.392), (0.69, 0.385), (0.70, 0.405)], M['trim'], SF, SX))
    # the dome and its collar. 2026-11-11 (user: the domes must fit the aliens): the pilot stands at full size with his feet at 0.55 (city_drivers.gd SPOT) and his head tops out near 2.05,
    # so the dome is 2.25 tall and still 0.5 wide at his head, and clear enough to see him through (the Dome material: levels/hub/city_cars.gd CarDome)
    dome = lathe_up('Glass', [(0.88, 0.74), (0.88, 1.12), (0.85, 1.46), (0.75, 1.78), (0.58, 2.02), (0.34, 2.19), (0.14, 2.245), (0.0005, 2.25)], M['dome'], 1.0, 1.0, sharp=60)
    parts['chrome'].append(lathe_up('collar', [(0.99, 0.72), (0.97, 0.84), (0.895, 0.875), (0.882, 0.84)], M['chrome'], 1.0, 1.0))
    # lamps: a cold blade at the bow, a red one astern
    parts['head'].append(ribbon('head', bvh, water_rays(0.0, 0.60, -30, 30, 50), 0.05, 0.012, M['head']))
    parts['tail'].append(ribbon('tail', bvh, water_rays(0.0, 0.60, 150, 210, 50), 0.05, 0.012, M['tail']))
    for k in range(10):      # plates
        a = math.tau * (k + 0.5) / 10
        parts['gap'].append(ribbon('plate', bvh, top_rays([(0.50 * SF * math.cos(a), 0.50 * SX * math.sin(a)), (0.93 * SF * math.cos(a), 0.93 * SX * math.sin(a))], 0.04), 0.010, 0.0025, M['gap']))
    for k in range(10):      # a ring of small lamps on the upper deck
        a = math.tau * k / 10
        parts['neon'].append(lathe_up('dot', [(0.045, 0.0), (0.03, 0.02), (0.0005, 0.026)], M['neon'], 1.0, 1.0, segs=10))
        f_, s_ = 0.60 * SF * math.cos(a), 0.60 * SX * math.sin(a)
        hit = bvh.ray_cast(P(f_, s_, 3.0), Vector((0, 0, -1)))[0]
        parts['neon'][-1].data.transform(__import__('mathutils').Matrix.Translation(Vector((s_, -f_, hit.z - 0.004))))
    return finish(parts, [dome], [], M)


def saucer_n():
    """GREEN POD: a teardrop hull slung between two engine pods: bubble canopy forward, a tail fin, green fire out of the back"""
    M = materials(0x1f4f16, 0x48ff5a, lit=True)
    st = [(-2.15, 0.20, 0.66, 0.74, 0.80, 0.80), (-1.90, 0.45, 0.52, 0.76, 0.90, 0.85), (-1.20, 0.70, 0.42, 0.80, 1.04, 0.88), (-0.30, 0.82, 0.38, 0.82, 1.14, 0.88),
          (0.60, 0.80, 0.38, 0.80, 1.10, 0.88), (1.30, 0.66, 0.42, 0.74, 0.96, 0.86), (1.75, 0.44, 0.50, 0.68, 0.80, 0.84), (1.95, 0.22, 0.58, 0.66, 0.70, 0.80)]
    body = build_body('body', st, M['paint'], shoulder=0.3, sill=0.1)
    bvh = bvh_of(body)
    parts = new_parts(body)
    # 2026-11-11 (user: the domes must fit the aliens): the green pilot stands at 0.35 forward with his feet at 0.62 and his head tops out near 2.2 (city_drivers.gd SPOT): the bubble is 2.42 tall over him
    can = [(1.32, 0.20, 0.90, 0.92), (1.14, 0.46, 0.96, 1.42), (0.82, 0.63, 1.00, 2.02), (0.44, 0.70, 1.04, 2.40), (0.06, 0.68, 1.06, 2.42), (-0.30, 0.56, 1.06, 2.10), (-0.54, 0.30, 1.04, 1.40)]
    canopy = build_canopy('glass', can, M['dome'], expo=2.2, sink=0.2)
    canopy.name = 'Glass'
    for sd in (1, -1):
        s0 = sd * 1.03
        parts['paint'].append(lathe_f('nacelle', [(0.62, 0.10), (0.56, 0.17), (0.20, 0.215), (-1.20, 0.215), (-1.80, 0.17), (-1.92, 0.15)], s0, 0.62, M['paint'], segs=24))
        parts['trim'].append(lathe_f('intake', [(0.62, 0.10), (0.50, 0.085), (0.50, 0.0005)], s0, 0.62, M['trim'], segs=24))
        parts['trim'].append(lathe_f('nozzle', [(-1.92, 0.15), (-1.96, 0.155), (-1.96, 0.125), (-1.80, 0.10)], s0, 0.62, M['chrome'], segs=24))
        parts['neon'].append(lathe_f('fire', [(-1.80, 0.10), (-1.80, 0.0005)], s0, 0.62, M['neon'], segs=24))
        parts['neon'].append(lathe_f('band', [(-0.20, 0.218), (-0.20, 0.222), (-0.26, 0.222), (-0.26, 0.218)], s0, 0.62, M['neon'], segs=24))
        # the stub wing that carries it
        prof = [(0.30, 0.64), (0.05, 0.70), (-0.70, 0.69), (-1.25, 0.64), (-0.70, 0.59), (0.05, 0.58)]
        wing = loft('wing', [[P(f, sd * 0.55, u) for f, u in prof], [P(f * 0.92 - 0.05, sd * 0.95, u) for f, u in prof]], M['paint'])
        outward(wing, P(-0.4, sd * 0.75, 0.64), 40)
        parts['paint'].append(wing)
        parts['neon'].append(ribbon('pin', bvh, side_rays([(1.30, 0.70), (-1.70, 0.74)], sd), 0.016, 0.004, M['neon']))
    parts['paint'].append(blade('fin', [(-0.90, 0.95, 1.06, 0.04, 0.015), (-1.40, 0.86, 1.30, 0.035, 0.008), (-1.90, 0.76, 1.52, 0.03, 0.005), (-2.20, 0.90, 1.60, 0.012, 0.004)], M['paint']))
    parts['trim'].append(ribbon('head_bezel', bvh, water_rays(0.8, 0.66, -60, 60, 60), 0.09, 0.003, M['trim'], across=2))
    parts['head'].append(ribbon('head', bvh, water_rays(0.8, 0.665, -55, 55, 60), 0.035, 0.006, M['head']))
    parts['tail'].append(ribbon('tail', bvh, water_rays(-1.0, 0.76, 150, 210, 40), 0.04, 0.006, M['tail']))
    for sd in (1, -1):      # the lift strips under the hull
        parts['neon'].append(ribbon('lift', bvh, bottom_rays([(1.10, sd * 0.30), (-1.30, sd * 0.34)]), 0.07, 0.006, M['neon']))
    parts['gap'].append(ribbon('hatch', bvh, top_rays([(-0.70, -0.45), (-0.74, 0.0), (-0.70, 0.45)], 0.03), 0.010, 0.0025, M['gap']))
    return finish(parts, [canopy], [], M)


def emitter(name, f, s, u, r, w, M):
    """a hover emitter in a wheel's place (the BLUE SAUCER): a gunmetal drum, a lit ring on its face, a chrome hub, and the axle it rides on running in toward the hull.
    s is its centre plane, + the left side. Origin at its centre, so it can be taken off whole (CLUB 9's rig has one lying in the street, axle and all)."""
    side = 1.0 if s > 0 else -1.0
    hw = w / 2
    parts = [lathe('drum', [(-hw * 0.80, r * 0.72), (-hw, r * 0.86), (-hw, r * 0.97), (-hw * 0.84, r), (hw * 0.84, r), (hw, r * 0.97), (hw, r * 0.86), (hw * 0.92, r * 0.84)], f, s, u, M['rim'], side=side),
             lathe('vents', [(-hw * 0.5 - 0.012, r + 0.002), (-hw * 0.5 + 0.012, r + 0.002)], f, s, u, M['trim'], side=side),
             lathe('vents', [(hw * 0.5 - 0.012, r + 0.002), (hw * 0.5 + 0.012, r + 0.002)], f, s, u, M['trim'], side=side),
             lathe('bezel', [(hw * 0.92, r * 0.84), (hw * 0.96, r * 0.82), (hw * 0.96, r * 0.76), (hw * 0.90, r * 0.74)], f, s, u, M['chrome'], side=side),
             lathe('ring', [(hw * 0.90, r * 0.74), (hw * 0.90, r * 0.50)], f, s, u, M['neon'], side=side),
             lathe('throat', [(hw * 0.90, r * 0.50), (hw * 0.60, r * 0.40), (hw * 0.60, r * 0.30)], f, s, u, M['trim'], side=side),
             lathe('hub', [(hw * 0.60, r * 0.30), (hw * 0.86, r * 0.26), (hw * 0.98, r * 0.16), (hw * 1.0, 0.0005)], f, s, u, M['chrome'], side=side),
             lathe('back', [(-hw * 0.80, r * 0.72), (-hw * 0.70, r * 0.30), (-hw * 0.70, 0.0005)], f, s, u, M['trim'], side=side),
             lathe('axle', [(-hw * 0.70, 0.05), (-hw - 0.24, 0.045), (-hw - 0.26, 0.07), (-hw - 0.30, 0.07), (-hw - 0.30, 0.0005)], f, s, u, M['chrome'], side=side, segs=14)]
    verts, faces = [], []      # the vanes across the throat
    for b in range(6):
        a = math.tau * b / 6
        for (rr, da, ax) in ((r * 0.30, -0.10, hw * 0.62), (r * 0.30, 0.10, hw * 0.62), (r * 0.50, 0.30, hw * 0.88), (r * 0.50, 0.10, hw * 0.88)):
            verts.append(P(f + rr * math.cos(a + da), s + side * ax, u + rr * math.sin(a + da)))
        faces.append((b * 4, b * 4 + 1, b * 4 + 2, b * 4 + 3))
    vn = mesh_obj('vanes', verts, faces, M['rim2'], smooth=False)
    outward(vn, P(f, s - side * 0.5, u))
    parts.append(vn)
    ob = join(name, parts)
    c = P(f, s, u)
    ob.data.transform(__import__('mathutils').Matrix.Translation(-c))
    ob.location = c
    return ob


def saucer_b():
    """BLUE SAUCER (2026-11-17, CLUB 9: Pauly's racing rig): a round bubble car of a saucer on four hover emitters in arches where a car has its wheels, its flank tall enough to
    hang a driver's door on, and under its canopy two seats side by side sized for Prog at full size (1.85 m, seated 1.01 m hips to crown, a metre across the shoulders) and Pauly
    beside him (2026-11-17, user: "big enough that it can fit Prog and the alien"). Driver on the left (the door side). No steering wheel (user): like the GRAY SAUCER and the GREEN
    POD, it is driven with the mind. Paint takes the car's colour (blue); the lit lines are cold cyan."""
    M = materials(0x1b3f9a, 0x7fe6ff, lit=True)
    SF, SX = 2.1, 1.28
    AX, TRACK, WR, WW = 1.35, 1.0, 0.34, 0.26
    hull = lathe_up('hull', [(0.0005, 0.38), (0.50, 0.34), (0.80, 0.38), (0.95, 0.48), (1.0, 0.60), (1.0, 0.82), (0.97, 0.93), (0.90, 1.0), (0.70, 1.05), (0.0005, 1.07)], M['paint'], SF, SX, sharp=40)
    arches(hull, M, [(AX, WR, 0.76, None), (-AX, WR, 0.76, None)])
    bvh = bvh_of(hull)
    parts = new_parts(hull)
    for f in (AX, -AX):
        for sd in (1, -1):
            parts['trim'].append(arch_lip('lip', f, WR, WR + 0.08, sd * (TRACK + 0.05), M['trim']))
    parts['neon'].append(lathe_up('rim', [(1.003, 0.700), (1.010, 0.708), (1.010, 0.732), (1.003, 0.740)], M['neon'], SF, SX))
    parts['trim'].append(lathe_up('skirt', [(0.80, 0.375), (0.83, 0.37), (0.96, 0.47), (0.955, 0.48)], M['trim'], SF, SX))
    parts['neon'].append(lathe_up('lift', [(0.40, 0.343), (0.62, 0.355)], M['neon'], SF, SX))
    # the canopy over the seats (2.4 tall: Prog's crown clears it by 0.17 seated upright) and its collar on the deck
    DF, DX = 1.12, 1.04
    dome = lathe_up('Glass', [(1.0, 0.98), (1.0, 1.30), (0.95, 1.62), (0.84, 1.92), (0.66, 2.16), (0.40, 2.32), (0.0005, 2.38)], M['dome'], DF, DX, sharp=60)
    parts['chrome'].append(lathe_up('collar', [(1.10, 1.02), (1.08, 1.08), (1.01, 1.10), (1.0, 1.06)], M['chrome'], DF, DX))
    parts['head'].append(ribbon('head', bvh, water_rays(0.0, 0.80, -26, 26, 60), 0.07, 0.012, M['head']))
    parts['tail'].append(ribbon('tail', bvh, water_rays(0.0, 0.80, 154, 206, 60), 0.07, 0.012, M['tail']))
    for k in range(8):      # deck plates
        a = math.tau * (k + 0.5) / 8
        parts['gap'].append(ribbon('plate', bvh, top_rays([(0.62 * SF * math.cos(a), 0.62 * SX * math.sin(a)), (0.84 * SF * math.cos(a), 0.84 * SX * math.sin(a))], 0.04), 0.010, 0.0025, M['gap']))
    door = {'f0': -0.62, 'f1': 0.55, 'u0': 0.44, 'u1': 0.92, 's_in': 1.12, 's_out': 1.28, 'belt': None, 'cab': (-0.55, 0.50, 0.42, 0.88),
            'seat': (-0.10, 0.46, 1.12), 'wheel': (0.48, 0.46, 1.50, 0.55, 0.17)}
    out = finish(parts, [dome], [], M, door=door)
    for o in [o for o in out if o.name.startswith('Steer')]:      # (door_split makes one; this craft has none)
        out.remove(o)
        bpy.data.objects.remove(o)
    for i, (f, s_) in enumerate([(AX, TRACK), (AX, -TRACK), (-AX, TRACK), (-AX, -TRACK)]):
        out.append(emitter('Wheel_%d' % i, f, s_, WR, WR, WW, M))
    return out
