# The flying cars over FOINT CITY (2026-11-10): the people above, in the same language as the street fleet but none of its wear. exec'd by build_cars.py (uses its helpers and more_cars.py's).
# No wheels: they hover. The lane anchor is the craft's middle, so u runs about -0.4 .. 0.85 round it. The accent (M['neon']) is keyed pure green: the game paints it each craft's engine colour
# (levels/shaders/sky_traffic_hull.gdshader), and the paint takes each craft's own colour as the street's do.
SKY_KEY = 0x00ff00


def sky_nacelle(parts, M, sd, s0, u0, f_front, f_back, r, band_f):
    """an engine pod along the hull: an intake ring at the front, a chrome bell and the engine's fire at the back, a lit band round its waist"""
    prof = [(f_front, r * 0.40), (f_front - 0.06, r * 0.80), (f_front - 0.30, r), (f_back + 0.55, r), (f_back + 0.10, r * 0.86), (f_back, r * 0.76)]
    parts['paint'].append(lathe_f('nacelle', prof, s0, u0, M['paint'], segs=24))
    parts['trim'].append(lathe_f('intake', [(f_front, r * 0.40), (f_front - 0.10, r * 0.34), (f_front - 0.10, 0.0005)], s0, u0, M['trim'], segs=24))
    parts['neon'].append(lathe_f('intake_glow', [(f_front - 0.095, r * 0.33), (f_front - 0.095, r * 0.10)], s0, u0, M['neon'], segs=24))
    parts['chrome'].append(lathe_f('bell', [(f_back, r * 0.76), (f_back - 0.07, r * 0.82), (f_back - 0.07, r * 0.66), (f_back + 0.08, r * 0.52)], s0, u0, M['chrome'], segs=24))
    parts['neon'].append(lathe_f('fire', [(f_back + 0.08, r * 0.52), (f_back + 0.08, 0.0005)], s0, u0, M['neon'], segs=24))
    parts['neon'].append(lathe_f('band', [(band_f + 0.03, r * 1.012), (band_f + 0.03, r * 1.03), (band_f - 0.03, r * 1.03), (band_f - 0.03, r * 1.012)], s0, u0, M['neon'], segs=24))


def sky_wing(parts, M, sd, s_in, s_out, prof, sweep=0.0, drop=0.0, material=None):
    """a thin stub wing from the hull out to a pod: prof is its (f, u) section at the root"""
    root = [P(f, sd * s_in, u) for f, u in prof]
    tip = [P(f - sweep, sd * s_out, u - drop) for f, u in prof]
    w = loft('wing', [root, tip], material or M['paint'], cap_start=True, cap_end=True)
    outward(w, P(sum(f for f, _u in prof) / len(prof) - sweep / 2, sd * (s_in + s_out) / 2, sum(u for _f, u in prof) / len(prof) - drop / 2), 40)
    parts['paint'].append(w)


def sky_limo():
    """SKY LIMO: a long, quiet sky yacht: a boat hull with a teardrop canopy, a chrome spine, engine pods slung low on stub wings, lift strips under the keel"""
    M = materials(0x1a1424, SKY_KEY, lit=True)
    st = [(-2.72, 0.20, 0.02, 0.14, 0.22, 0.70), (-2.52, 0.50, -0.12, 0.16, 0.36, 0.76), (-2.00, 0.78, -0.24, 0.18, 0.46, 0.78), (-1.20, 0.90, -0.30, 0.20, 0.50, 0.80),
          (-0.20, 0.93, -0.32, 0.20, 0.48, 0.80), (0.80, 0.88, -0.31, 0.17, 0.40, 0.80), (1.60, 0.74, -0.27, 0.12, 0.28, 0.80), (2.20, 0.52, -0.20, 0.06, 0.16, 0.82),
          (2.60, 0.26, -0.12, 0.01, 0.07, 0.80), (2.78, 0.07, -0.06, -0.01, 0.02, 0.80)]
    body = build_body('body', st, M['paint'], shoulder=0.45, sill=0.2)
    bvh = bvh_of(body)
    parts = new_parts(body)
    can = [(1.55, 0.18, 0.30, 0.31), (1.30, 0.46, 0.33, 0.55), (0.85, 0.62, 0.38, 0.74), (0.20, 0.68, 0.42, 0.84), (-0.50, 0.66, 0.45, 0.84),
           (-1.15, 0.56, 0.46, 0.74), (-1.65, 0.36, 0.46, 0.60), (-1.95, 0.14, 0.44, 0.48)]
    canopy = build_canopy('glass', can, M['glass'], expo=2.4, sink=0.14)
    canopy.name = 'Glass'
    cb = bvh_of(canopy)
    parts['chrome'].append(ribbon('spine', cb, top_rays([(1.05, 0.0), (-1.85, 0.0)], 0.05), lambda k: 0.05 + 0.05 * math.sin(math.pi * k), 0.006, M['chrome'], across=2))
    for sd in (1, -1):
        parts['trim'].append(ribbon('hoop', cb, side_rays([(-0.62, 0.40), (-0.70, 1.2)], sd, 0.03), 0.06, 0.005, M['chrome'], across=2))
        parts['chrome'].append(ribbon('belt', bvh, side_rays([(2.30, 0.10), (1.20, 0.19), (-0.80, 0.21), (-2.40, 0.18)], sd), 0.022, 0.004, M['chrome']))
        parts['neon'].append(ribbon('pin', bvh, side_rays([(1.90, 0.02), (0.40, 0.06), (-1.60, 0.07)], sd), 0.012, 0.004, M['head']))
        parts['gap'].append(ribbon('door', bvh, side_rays([(0.70, -0.20), (0.62, 0.05), (0.72, 0.20)], sd, 0.03), 0.009, 0.0025, M['gap']))
        parts['gap'].append(ribbon('door2', bvh, side_rays([(-0.70, -0.22), (-0.74, 0.05), (-0.66, 0.21)], sd, 0.03), 0.009, 0.0025, M['gap']))
        # the pods, low and well out, on swept stub wings
        sky_nacelle(parts, M, sd, sd * 1.10, -0.04, 1.05, -2.10, 0.20, -0.45)
        sky_wing(parts, M, sd, 0.70, 1.02, [(0.45, -0.02), (0.15, 0.03), (-0.80, 0.02), (-1.35, -0.02), (-0.80, -0.07), (0.15, -0.07)], sweep=0.12, drop=0.02)
    parts['paint'].append(blade('fin', [(-1.20, 0.46, 0.50, 0.03, 0.012), (-1.70, 0.41, 0.58, 0.03, 0.008), (-2.20, 0.34, 0.68, 0.025, 0.005), (-2.52, 0.40, 0.76, 0.016, 0.004), (-2.70, 0.66, 0.77, 0.008, 0.003)], M['paint']))      # (raked: low at the root, its tip trailing)
    parts['trim'].append(ribbon('head_bezel', bvh, water_rays(1.3, 0.085, -62, 62, 70), 0.08, 0.003, M['trim'], across=2))
    parts['head'].append(ribbon('head', bvh, water_rays(1.3, 0.09, -58, 58, 70), 0.026, 0.006, M['head']))
    parts['trim'].append(ribbon('tail_bezel', bvh, water_rays(-1.6, 0.20, 128, 232, 70), 0.09, 0.003, M['trim'], across=2))
    parts['tail'].append(ribbon('tail', bvh, water_rays(-1.6, 0.205, 132, 228, 70), 0.032, 0.006, M['tail']))
    for sd in (1, -1):      # the lift strips under the keel
        parts['neon'].append(ribbon('lift', bvh, bottom_rays([(1.70, sd * 0.26), (-2.10, sd * 0.30)]), 0.06, 0.006, M['neon']))
    parts['trim'].append(ribbon('keel', bvh, bottom_rays([(2.20, 0.0), (-2.40, 0.0)]), 0.22, 0.004, M['trim'], across=3))
    return finish(parts, [canopy], [], M)


def sky_dart():
    """SKY DART: a short, quick wedge for one or two: the canopy far back, twin engines in the flanks, canards at the nose and swept fins at the tail"""
    M = materials(0x24101c, SKY_KEY, lit=True)
    st = [(-2.12, 0.34, 0.00, 0.14, 0.24, 0.80), (-1.96, 0.66, -0.10, 0.18, 0.34, 0.84), (-1.40, 0.86, -0.18, 0.20, 0.40, 0.84), (-0.50, 0.90, -0.22, 0.20, 0.42, 0.84),
          (0.40, 0.84, -0.22, 0.16, 0.34, 0.84), (1.20, 0.64, -0.18, 0.08, 0.20, 0.84), (1.80, 0.38, -0.12, 0.02, 0.09, 0.85), (2.16, 0.12, -0.07, -0.01, 0.02, 0.80)]
    body = build_body('body', st, M['paint'], shoulder=0.6, sill=0.25)
    bvh = bvh_of(body)
    parts = new_parts(body)
    can = [(0.85, 0.16, 0.25, 0.26), (0.60, 0.42, 0.29, 0.50), (0.15, 0.56, 0.34, 0.66), (-0.45, 0.58, 0.38, 0.68), (-1.00, 0.46, 0.39, 0.56), (-1.40, 0.22, 0.37, 0.44)]
    canopy = build_canopy('glass', can, M['glass'], expo=2.6, sink=0.14)
    canopy.name = 'Glass'
    cb = bvh_of(canopy)
    for sd in (1, -1):
        parts['trim'].append(ribbon('edge', cb, top_rays([(0.70, sd * 0.30), (-0.40, sd * 0.40), (-1.30, sd * 0.16)], 0.05), 0.02, 0.008, M['chrome']))
        sky_nacelle(parts, M, sd, sd * 0.78, 0.02, 0.10, -2.28, 0.17, -0.90)
        sky_wing(parts, M, sd, 0.85, 1.32, [(-1.10, 0.06), (-1.35, 0.09), (-2.00, 0.08), (-1.35, 0.05)], sweep=0.45, drop=-0.06)
        sky_wing(parts, M, sd, 0.50, 0.86, [(1.50, 0.05), (1.40, 0.07), (1.10, 0.06), (1.40, 0.04)], sweep=0.15, drop=-0.03)
        parts['neon'].append(ribbon('pin', bvh, side_rays([(1.60, 0.04), (0.20, 0.14), (-1.80, 0.16)], sd), 0.012, 0.004, M['head']))
        parts['gap'].append(ribbon('door', bvh, side_rays([(0.30, -0.15), (0.22, 0.05), (0.32, 0.16)], sd, 0.03), 0.009, 0.0025, M['gap']))
        parts['paint'].append(blade('fin', [(-1.45, 0.30, 0.34, 0.025, 0.012), (-1.80, 0.30, 0.46, 0.022, 0.007), (-2.10, 0.32, 0.56, 0.016, 0.004), (-2.28, 0.48, 0.60, 0.008, 0.003)], M['paint']))
        parts['paint'][-1].data.transform(__import__('mathutils').Matrix.Translation(Vector((sd * 0.42, 0, 0))))
    parts['trim'].append(ribbon('head_bezel', bvh, water_rays(1.0, 0.035, -60, 60, 60), 0.07, 0.003, M['trim'], across=2))
    parts['head'].append(ribbon('head', bvh, water_rays(1.0, 0.04, -55, 55, 60), 0.024, 0.006, M['head']))
    parts['tail'].append(ribbon('tail', bvh, water_rays(-1.2, 0.20, 140, 220, 50), 0.03, 0.006, M['tail']))
    for sd in (1, -1):
        parts['neon'].append(ribbon('lift', bvh, bottom_rays([(1.30, sd * 0.24), (-1.60, sd * 0.30)]), 0.05, 0.006, M['neon']))
    return finish(parts, [canopy], [], M)
