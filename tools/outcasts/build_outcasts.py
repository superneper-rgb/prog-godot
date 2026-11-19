# Builds UNDERFOINT's outcasts (assets/underfoint/outcast_<id>.glb): the people who live in the old city and are NOT the Sigil's. Five of them, each a different creature, all wrapped in what they could find.
# Proposals built to be looked at (user, 2026-11-12: "you design them"): names, species and looks are the user's to approve, rename or throw out.
#   stoker     squat mole-man in three coats, welder's goggles, a knitted cap         (stands in as FIREKEEPER)
#   ragwoman   tall stooped heron-woman, shawl of rags, headscarf                     (RAG WOMAN)
#   listener   small fox-eared thing in a jumper too big for it, blindfolded, an ear trumpet   (THE LISTENER)
#   ticketman  old tortoise in what is left of a tram conductor's uniform, ticket machine on a strap   (TICKET MAN)
#   collector  a hooded shape under a pack of dead television sets, leaning on a staff   (COLLECTOR)
# Rigid parts on joints, made with the Taken's tools (tools/taken/build_taken.py). All five share joint names, so enemies/outcast_npc.gd poses them with one piece of code.
#   Headless only: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/outcasts/build_outcasts.py -- --outcasts [--preview <folder>]
# Game space: metres, y up, the figure faces +z, its left is +x.
import bpy, math, random, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "taken"))
sys.path.insert(0, os.path.join(HERE, "..", "tethered"))
import build_taken as T
from build_taken import Geo, part, joint, lin, strip, TAU
from build_tethered import strut

OUT = "F:/prog-godot/assets/underfoint/outcast_%s.glb"
DARK = T.DARK
BRASS = lin("b08a3a")
TIN = lin("8a8c88")
WOOD = lin("5a4630")


def rig(h, sh, hip, arm, leg, neck=(0.0, 0.0), head_fwd=0.03, extra=()):
    """the joints, at this figure's sizes: h the height of the neck's base, sh half the shoulders, hip half the hips, arm and leg (upper, lower) lengths; neck = (its length, how far it juts forward)"""
    py = leg[0] + leg[1] + 0.07
    joint("pelvis", (0, py, 0))
    joint("spine", (0, py + (h - py) * 0.25, 0), "pelvis")
    joint("chest", (0, py + (h - py) * 0.6, 0), "spine")
    joint("neck", (0, h, 0.02), "chest")
    joint("head", (0, h + 0.05 + neck[0], head_fwd + neck[1]), "neck")
    joint("jaw", (0, h + 0.03 + neck[0], head_fwd + neck[1] + 0.05), "head")
    for s, t in ((1, "L"), (-1, "R")):
        joint("upper_arm" + t, (s * sh, h - 0.08, 0), "chest")
        joint("forearm" + t, (s * (sh + 0.04), h - 0.08 - arm[0], 0.01), "upper_arm" + t)
        joint("hand" + t, (s * (sh + 0.06), h - 0.08 - arm[0] - arm[1], 0.04), "forearm" + t)
        joint("thigh" + t, (s * hip, py - 0.03, 0), "pelvis")
        joint("shin" + t, (s * (hip + 0.01), leg[1] + 0.07, 0.01), "thigh" + t)
        joint("foot" + t, (s * (hip + 0.01), 0.07, 0), "shin" + t)
    for nm, pos, par in extra:
        joint(nm, pos, par)


def P(name):
    return T.J[name][1]


def limbs(sleeve, cuff, skin, trouser, boot, ra=0.05, rl=0.06, hand=0.05, claws=0, sleeve_to=1.0, mat_skin="hide"):
    """arms and legs between the joints as they stand: a sleeve, a forearm, a hand; a trouser leg, a shin, a boot"""
    for s, t in ((1, "L"), (-1, "R")):
        a, b, c = P("upper_arm" + t), P("forearm" + t), P("hand" + t)
        g = Geo()
        strut(g, [a, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, a[2]), b], [ra * 1.25, ra * 1.1, ra], 8, sleeve)
        g.ball(a, ra * 1.35, sleeve, 7, 4)
        part("upper_arm" + t, "cloth", g, 0.004)
        g = Geo()
        end = (b[0] + (c[0] - b[0]) * sleeve_to, b[1] + (c[1] - b[1]) * sleeve_to, b[2] + (c[2] - b[2]) * sleeve_to)
        strut(g, [b, end], [ra, ra * (1.15 if sleeve_to > 1.0 else 0.85)], 8, cuff)
        g.ball(b, ra * 1.05, cuff, 6, 3)
        part("forearm" + t, "cloth", g, 0.004)
        if sleeve_to <= 1.0:
            g = Geo()
            g.ball((c[0], c[1] - hand * 0.7, c[2] + 0.01), hand, skin, 7, 4, (0.8, 1.2, 1.0))
            for k in range(claws):
                dz = (k - (claws - 1) / 2) * hand * 0.55
                strut(g, [(c[0], c[1] - hand * 1.3, c[2] + 0.02 + dz), (c[0] + s * 0.005, c[1] - hand * 2.5, c[2] + 0.05 + dz * 1.3)], [hand * 0.24, hand * 0.07], 5, skin)
            part("hand" + t, mat_skin, g, 0.002)
        a, b, c = P("thigh" + t), P("shin" + t), P("foot" + t)
        g = Geo()
        strut(g, [a, b], [rl * 1.3, rl], 8, trouser)
        part("thigh" + t, "cloth", g, 0.004)
        g = Geo()
        strut(g, [b, c], [rl, rl * 0.8], 8, trouser)
        g.ball(b, rl * 1.05, trouser, 6, 3)
        part("shin" + t, "cloth", g, 0.004)
        g = Geo()
        g.loft([((c[0], 0.04, c[2] - rl * 1.1), rl * 0.9, 0.045), ((c[0], 0.05, c[2]), rl * 1.1, 0.055), ((c[0], 0.04, c[2] + rl * 1.6), rl * 1.15, 0.04), ((c[0], 0.03, c[2] + rl * 2.6), rl * 0.9, 0.03)], 8, boot, axis="z")
        g.loft([((c[0], 0.07, c[2]), rl * 0.85, rl * 0.9), ((c[0], 0.16, c[2]), rl * 0.8, rl * 0.82)], 8, boot)
        part("foot" + t, "cloth", g, 0.003)


def rags(g, cx, cy, cz, ra, rb, n, lo, hi, cols, seed):
    rr = random.Random(seed)
    for k in range(n):
        a = TAU * (k + rr.random() * 0.6) / n
        out = (math.cos(a), math.sin(a))
        strip(g, (cx + out[0] * ra, cy, cz + out[1] * rb), out, 0.05 + rr.random() * 0.06, lo + rr.random() ** 2 * (hi - lo), cols[rr.randrange(len(cols))])


def eyes(jname, pts, r, col=DARK):
    g = Geo()
    for p in pts:
        g.ball(p, r, col, 6, 4)
    part(jname, "eye", g, shade=False)


# ---- the five ----------------------------------------------------------------------------------------------------------------------------------------------------------

def stoker():
    COAT, COAT2, HIDE, PINK, CAP = lin("5a4632"), lin("3e4636"), lin("84706a"), lin("b48a84"), lin("6e2620")
    rig(1.06, 0.36, 0.17, (0.26, 0.24), (0.2, 0.2))
    g = Geo()
    g.loft([((0, 0.36, 0), 0.3, 0.25), ((0, 0.5, 0.01), 0.4, 0.33), ((0, 0.72, 0.02), 0.43, 0.35), ((0, 0.86, 0.01), 0.4, 0.31)], 14, COAT)
    rags(g, 0, 0.4, 0, 0.3, 0.25, 15, 0.05, 0.22, [COAT, COAT2], 3)
    part("spine", "cloth", g, 0.008)
    g = Geo()
    g.loft([((0, 0.82, 0.01), 0.41, 0.32), ((0, 0.96, 0), 0.4, 0.29), ((0, 1.06, 0), 0.3, 0.23), ((0, 1.12, 0.01), 0.16, 0.15)], 14, COAT2)
    g.arc((0, 1.1, 0.02), 0.17, 0.16, 0.0, TAU, 0.05, 0.05, CAP, 12)      # a scarf, wound twice
    strip(g, (0.1, 1.08, 0.17), (0.3, 0.95), 0.1, 0.3, CAP)
    for k in range(4):      # the top coat's buttons, three of them still on
        if k != 2:
            g.ball((0.02, 0.6 + k * 0.1, 0.34 - k * 0.012), 0.022, BRASS, 6, 3)
    part("chest", "cloth", g, 0.008)
    g = Geo()
    g.loft([((0, 1.1, 0.04), 0.17, 0.16), ((0, 1.2, 0.06), 0.25, 0.22), ((0, 1.31, 0.05), 0.25, 0.22), ((0, 1.4, 0.04), 0.18, 0.17)], 12, HIDE)
    g.ball((0, 1.2, 0.27), 0.085, PINK, 8, 5, (1.2, 0.9, 1.0))      # the snout
    part("head", "hide", g, 0.005)
    g = Geo()
    for s in (1, -1):
        for k in range(4):
            strut(g, [(s * 0.07, 1.2 + (k - 1.5) * 0.02, 0.33), (s * (0.2 + k * 0.01), 1.2 + (k - 1.5) * 0.06, 0.36)], 0.004, 4, lin("d8d2c0"))
    g.ball((0, 1.22, 0.36), 0.03, lin("3a2622"), 6, 4)
    part("head", "bone", g, shade=False)
    g = Geo()      # welder's goggles, and the strap round the back
    for s in (1, -1):
        g.loft([((s * 0.1, 1.31, 0.2), 0.075, 0.075), ((s * 0.1, 1.31, 0.29), 0.07, 0.07)], 10, TIN, axis="z", caps=(False, False))
    part("head", "metal", g, smooth=False)
    g = Geo()
    for s in (1, -1):
        g.loft([((s * 0.1, 1.31, 0.285), 0.064, 0.064), ((s * 0.1, 1.31, 0.29), 0.05, 0.05)], 10, lin("1a2a22"), axis="z", caps=(False, True))
    part("head", "eye", g, shade=False)
    g = Geo()
    g.arc((0, 1.31, 0.05), 0.25, 0.22, math.radians(150), math.radians(390), 0.012, 0.025, lin("2a2620"), 12)
    g.ball((0, 1.41, 0.04), 0.2, CAP, 10, 5, (1.0, 0.55, 0.95))      # the cap
    g.ball((0, 1.52, 0.04), 0.05, lin("b8a888"), 6, 4)
    part("head", "cloth", g, 0.006)
    g = Geo()
    g.box((0, 1.13, 0.2), 0.07, 0.022, 0.06, HIDE)
    part("jaw", "hide", g, 0.002)
    limbs(COAT2, COAT, PINK, lin("3a3430"), lin("241e1a"), ra=0.095, rl=0.1, hand=0.085, claws=4)


def ragwoman():
    SK, SHAWL, SKIRT, SCARF, BEAK = lin("9aa4a0"), lin("6a4a52"), lin("3c3e4a"), lin("8a6a3a"), lin("b89a4a")
    rig(1.6, 0.2, 0.1, (0.36, 0.33), (0.46, 0.45), neck=(0.2, 0.1))
    g = Geo()
    g.loft([((0, 0.22, 0), 0.26, 0.24), ((0, 0.6, 0), 0.22, 0.2), ((0, 0.95, 0), 0.16, 0.13), ((0, 1.1, 0), 0.13, 0.1)], 12, SKIRT, caps=(False, True))
    rags(g, 0, 0.26, 0, 0.25, 0.23, 17, 0.06, 0.2, [SKIRT, lin("4a4438")], 5)
    part("pelvis", "cloth", g, 0.008)
    g = Geo()
    g.loft([((0, 1.05, 0), 0.13, 0.1), ((0, 1.3, 0.0), 0.15, 0.11), ((0, 1.45, 0.0), 0.14, 0.1)], 10, lin("5a5448"))
    part("spine", "cloth", g, 0.005)
    g = Geo()      # the shawl: a cone of it off the shoulders, every edge in strips
    g.loft([((0, 1.22, 0), 0.27, 0.21), ((0, 1.42, 0), 0.25, 0.18), ((0, 1.56, 0.01), 0.17, 0.12), ((0, 1.63, 0.02), 0.07, 0.07)], 12, SHAWL, caps=(False, True))
    rags(g, 0, 1.24, 0, 0.265, 0.205, 19, 0.1, 0.5, [SHAWL, lin("7a5a4a"), lin("4a3a4a")], 9)
    part("chest", "cloth", g, 0.008)
    g = Geo()
    strut(g, [(0, 1.6, 0.02), (0, 1.72, 0.06), (0, 1.84, 0.12)], [0.045, 0.035, 0.04], 8, SK)
    part("neck", "hide", g, 0.004)
    g = Geo()
    g.ball((0, 1.9, 0.12), 0.085, SK, 9, 6, (0.9, 1.0, 1.15))
    strut(g, [(0, 1.89, 0.2), (0, 1.85, 0.36), (0, 1.8, 0.5)], [0.04, 0.024, 0.006], 6, BEAK)      # the upper bill
    part("head", "hide", g, 0.003)
    eyes("head", [(0.07, 1.915, 0.17), (-0.07, 1.915, 0.17)], 0.02)
    g = Geo()
    g.ball((0, 1.93, 0.09), 0.1, SCARF, 9, 5, (0.98, 0.8, 1.15))      # the headscarf, knotted under the bill
    strip(g, (0.03, 1.83, 0.14), (0.4, 0.9), 0.06, 0.2, SCARF)
    strip(g, (-0.03, 1.83, 0.14), (-0.5, 0.85), 0.05, 0.14, SCARF)
    part("head", "cloth", g, 0.004)
    g = Geo()
    strut(g, [(0, 1.87, 0.2), (0, 1.83, 0.34), (0, 1.79, 0.46)], [0.03, 0.018, 0.005], 6, [c * 0.8 for c in BEAK])
    part("jaw", "hide", g)
    limbs(SHAWL, lin("5a5448"), SK, lin("3a3a3a"), lin("2a2420"), ra=0.04, rl=0.045, hand=0.04, claws=3)


def listener():
    FUR, JUMPER, PINK = lin("a08a62"), lin("2e5a58"), lin("b88a80")
    rig(0.78, 0.17, 0.085, (0.19, 0.17), (0.17, 0.17), extra=(("earL", (0.11, 1.03, 0.03), "head"), ("earR", (-0.11, 1.03, 0.03), "head")))
    g = Geo()
    g.loft([((0, 0.3, 0), 0.2, 0.17), ((0, 0.44, 0.01), 0.23, 0.19), ((0, 0.6, 0.01), 0.2, 0.16)], 12, JUMPER)
    rags(g, 0, 0.33, 0, 0.2, 0.17, 11, 0.03, 0.1, [JUMPER], 2)
    part("spine", "cloth", g, 0.006)
    g = Geo()
    g.loft([((0, 0.56, 0.01), 0.2, 0.16), ((0, 0.7, 0), 0.19, 0.14), ((0, 0.78, 0.01), 0.12, 0.1), ((0, 0.82, 0.02), 0.07, 0.07)], 12, JUMPER)
    g.arc((0, 0.8, 0.02), 0.085, 0.08, 0.0, TAU, 0.03, 0.03, [c * 1.2 for c in JUMPER], 10)
    part("chest", "cloth", g, 0.006)
    g = Geo()
    g.ball((0, 0.96, 0.05), 0.165, FUR, 12, 7, (1.1, 0.92, 1.0))
    g.ball((0, 0.91, 0.19), 0.06, lin("c8b890"), 8, 5, (1.1, 0.8, 1.0))      # the muzzle
    part("head", "hide", g, 0.006)
    g = Geo()
    g.ball((0, 0.93, 0.245), 0.02, DARK, 6, 4)
    part("head", "eye", g, shade=False)
    g = Geo()
    g.arc((0, 0.985, 0.05), 0.178, 0.16, 0.0, TAU, 0.012, 0.035, lin("22201e"), 14)      # the blindfold
    strip(g, (-0.05, 0.98, -0.11), (-0.3, -0.95), 0.05, 0.22, lin("22201e"))
    part("head", "cloth", g, 0.003)
    for s, t in ((1, "L"), (-1, "R")):      # the ears: taller than the head
        def inner(p, n, col):
            return [col[i] + (PINK[i] - col[i]) * 0.8 for i in range(3)] if n.y < -0.3 else col      # (Blender -y is the figure's front)
        g = Geo()
        g.loft([((s * 0.11, 1.03, 0.03), 0.055, 0.03), ((s * 0.15, 1.16, 0.02), 0.095, 0.022), ((s * 0.19, 1.32, 0.0), 0.07, 0.014), ((s * 0.215, 1.45, -0.01), 0.008, 0.005)], 8, FUR)
        part("ear" + t, "hide", g, 0.002, paint=inner)
    g = Geo()      # an ear trumpet made from a tin funnel, tied on with string
    strut(g, [(0.2, 1.1, 0.03), (0.27, 1.13, 0.07), (0.4, 1.2, 0.14)], [0.012, 0.03, 0.1], 9, TIN, caps=False)
    part("earL", "metal", g, smooth=False)
    g = Geo()
    g.box((0, 0.875, 0.2), 0.035, 0.012, 0.04, lin("c8b890"))
    part("jaw", "hide", g, 0.001)
    limbs(JUMPER, JUMPER, FUR, lin("4a4034"), lin("2a2622"), ra=0.05, rl=0.05, hand=0.04, sleeve_to=1.45)


def ticketman():
    SK, NAVY, SHELL = lin("7a8058"), lin("263040"), lin("4a4a32")
    rig(1.2, 0.27, 0.13, (0.27, 0.25), (0.31, 0.3), neck=(0.08, 0.16))
    g = Geo()
    g.loft([((0, 0.5, 0), 0.22, 0.18), ((0, 0.68, 0.01), 0.27, 0.22), ((0, 0.9, 0.02), 0.28, 0.23)], 12, NAVY)
    rags(g, 0, 0.53, 0, 0.22, 0.18, 12, 0.04, 0.18, [NAVY], 4)
    part("spine", "cloth", g, 0.006)
    g = Geo()
    g.loft([((0, 0.86, 0.02), 0.28, 0.23), ((0, 1.04, 0.01), 0.3, 0.22), ((0, 1.16, 0.02), 0.22, 0.17), ((0, 1.22, 0.04), 0.1, 0.1)], 12, NAVY)
    g.ball((0, 1.0, -0.17), 0.27, SHELL, 10, 6, (1.05, 1.15, 0.75))      # the shell, through the back of the coat
    for k in range(5):
        g.ball((0.0, 0.62 + k * 0.11, 0.235 - abs(k - 2) * 0.008), 0.02, BRASS, 6, 3)
    part("chest", "cloth", g, 0.006)
    g = Geo()      # the ticket machine on its strap
    g.box((0.13, 0.86, 0.26), 0.075, 0.095, 0.05, TIN)
    g.loft([((0.215, 0.88, 0.26), 0.02, 0.02), ((0.26, 0.88, 0.26), 0.02, 0.02)], 6, BRASS, axis="z")
    g.box((0.13, 0.78, 0.315), 0.03, 0.04, 0.004, lin("d8d0b0"))
    part("chest", "metal", g, smooth=False)
    g = Geo()
    strut(g, [(0.2, 0.9, 0.2), (0.05, 1.08, 0.24), (-0.18, 1.2, 0.08)], [0.006, 0.006, 0.006], 4, lin("3a2a1a"))
    part("chest", "cloth", g, shade=False)
    g = Geo()
    strut(g, [(0, 1.18, 0.05), (0, 1.25, 0.12), (0, 1.33, 0.2)], [0.075, 0.055, 0.06], 9, SK)
    part("neck", "hide", g, 0.008)
    g = Geo()
    g.ball((0, 1.38, 0.23), 0.115, SK, 10, 6, (0.95, 0.85, 1.2))
    strut(g, [(0, 1.36, 0.32), (0, 1.335, 0.4)], [0.06, 0.02], 7, [c * 0.8 for c in SK])      # a blunt beak of a mouth
    for s in (1, -1):
        g.ball((s * 0.075, 1.4, 0.3), 0.03, [c * 0.7 for c in SK], 6, 4, (1.0, 0.6, 1.0))      # the lids, most of the way down
    part("head", "hide", g, 0.005)
    eyes("head", [(0.078, 1.39, 0.305), (-0.078, 1.39, 0.305)], 0.02)
    g = Geo()      # a conductor's cap: the crown, the band, the peak
    g.loft([((0, 1.45, 0.21), 0.115, 0.125), ((0, 1.52, 0.2), 0.135, 0.14), ((0, 1.54, 0.2), 0.12, 0.125)], 12, NAVY)
    g.arc((0, 1.455, 0.21), 0.117, 0.127, 0.0, TAU, 0.006, 0.014, BRASS, 12)
    g.box((0, 1.45, 0.36), 0.085, 0.006, 0.05, lin("101418"))
    part("head", "cloth", g, 0.003)
    g = Geo()
    strut(g, [(0, 1.335, 0.3), (0, 1.32, 0.38)], [0.05, 0.016], 7, [c * 0.7 for c in SK])
    part("jaw", "hide", g)
    limbs(NAVY, NAVY, SK, lin("20262e"), lin("16181a"), ra=0.06, rl=0.07, hand=0.05, claws=3)


def collector():
    CLOAK, SET = lin("3a4238"), lin("8c8672")
    rig(1.3, 0.22, 0.11, (0.29, 0.27), (0.36, 0.35), extra=(("pack", (0, 1.2, -0.22), "chest"),))
    g = Geo()
    g.loft([((0, 0.2, 0), 0.28, 0.25), ((0, 0.6, 0), 0.25, 0.22), ((0, 0.95, 0.01), 0.24, 0.19)], 12, CLOAK, caps=(False, True))
    rags(g, 0, 0.24, 0, 0.27, 0.24, 16, 0.05, 0.2, [CLOAK, lin("2a3028")], 6)
    part("spine", "cloth", g, 0.008)
    g = Geo()
    g.loft([((0, 0.9, 0.01), 0.24, 0.19), ((0, 1.14, 0), 0.26, 0.19), ((0, 1.28, 0.01), 0.2, 0.16), ((0, 1.34, 0.03), 0.12, 0.12)], 12, CLOAK)
    part("chest", "cloth", g, 0.008)
    g = Geo()      # the hood: deep, and nothing in it but two eyes
    g.ball((0, 1.46, 0.07), 0.17, CLOAK, 12, 7, (1.0, 1.1, 1.12))
    part("head", "cloth", g, 0.006)
    g = Geo()
    g.loft([((0, 1.45, 0.2), 0.105, 0.125), ((0, 1.45, 0.262), 0.1, 0.12)], 12, DARK, axis="z", caps=(False, True))
    part("head", "cable", g, shade=False)
    g = Geo()
    for s in (1, -1):
        g.ball((s * 0.04, 1.47, 0.262), 0.014, lin("e8e0a8"), 6, 4)
    part("head", "plastic", g, shade=False)
    # the pack: a frame of slats, three dead sets roped to it, a bedroll on top, two aerials
    g = Geo()
    for s in (1, -1):
        g.box((s * 0.2, 1.12, -0.26), 0.02, 0.5, 0.02, WOOD)
    for y in (0.72, 1.1, 1.5):
        g.box((0, y, -0.26), 0.22, 0.02, 0.02, WOOD)
    part("pack", "cloth", g, 0.002, smooth=False)
    g = Geo()
    for (x, y, w, hh) in ((0.0, 0.9, 0.2, 0.16), (-0.03, 1.24, 0.17, 0.15), (0.04, 1.52, 0.14, 0.11)):
        g.box((x, y, -0.44), w, hh, 0.16, SET, 0.95)
    part("pack", "plastic", g, smooth=False)
    g = Geo()
    for (x, y, w, hh) in ((0.0, 0.9, 0.2, 0.16), (-0.03, 1.24, 0.17, 0.15), (0.04, 1.52, 0.14, 0.11)):
        g.box((x - w * 0.12, y, -0.602), w * 0.7, hh * 0.72, 0.004, lin("101612"))
    part("pack", "eye", g, shade=False, smooth=False)
    g = Geo()
    strut(g, [(-0.27, 1.72, -0.4), (0.27, 1.72, -0.4)], 0.09, 9, lin("5a3a30"))      # the bedroll
    part("pack", "cloth", g, 0.004)
    g = Geo()
    strut(g, [(0.1, 1.62, -0.44), (0.2, 1.95, -0.5), (0.34, 2.12, -0.46)], [0.005, 0.004, 0.003], 4, TIN)
    strut(g, [(0.0, 1.62, -0.44), (-0.12, 2.0, -0.42)], [0.005, 0.003], 4, TIN)
    g.ball((-0.24, 1.0, -0.3), 0.07, TIN, 7, 4, (1.0, 0.8, 1.0))      # a pan, hung off the side
    part("pack", "metal", g, smooth=False)
    limbs(CLOAK, CLOAK, lin("2a2622"), lin("2a2e2a"), lin("1a1816"), ra=0.055, rl=0.06, hand=0.045)
    g = Geo()      # the staff, in his right hand
    c = P("handR")
    strut(g, [(c[0] - 0.01, 0.02, c[2] + 0.12), (c[0], c[1] - 0.03, c[2] + 0.04), (c[0] + 0.02, 1.62, c[2] - 0.02)], [0.016, 0.02, 0.024], 6, WOOD)
    part("handR", "cloth", g, 0.002)


ALL = {"stoker": stoker, "ragwoman": ragwoman, "listener": listener, "ticketman": ticketman, "collector": collector}

if "--outcasts" in sys.argv:
    T.SCENE = bpy.context.scene.name
    T.MAT_DEF["hide"] = (0.75, 0.0, None)
    T.MAT_DEF["eye"] = (0.08, 0.0, None)
    for o in list(bpy.context.scene.collection.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for name, fn in ALL.items():
        T.J.clear()
        T.PARTS.clear()
        fn()
        print("outcast", name, {"parts": len(T.PARTS), "joints": len(T.J), "tris": sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in T.PARTS)})
        if "--preview" in sys.argv:
            top = max(v[1][1] for v in T.J.values()) + 0.35
            T.preview(os.path.join(sys.argv[sys.argv.index("--preview") + 1], "outcast_%s.png" % name), "x", (1.3, top * 0.75, 2.2 + top * 0.9), (0.0, top * 0.5, 0.0), (560, 720))
            for nm in ("TakenCam", "TakenKey", "TakenRim", "TakenFill"):
                ob = bpy.data.objects.get(nm)
                if ob is not None:
                    bpy.data.objects.remove(ob, do_unlink=True)
        print("wrote", T.export(OUT % name))
        for o in list(bpy.context.scene.collection.all_objects):
            d = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if d is not None and d.users == 0 and isinstance(d, bpy.types.Mesh):
                bpy.data.meshes.remove(d)
