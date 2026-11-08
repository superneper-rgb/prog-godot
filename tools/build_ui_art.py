# Bakes the UI art the three.js game cut at run time (Wheel._buildPip / _buildPress / _whiteHands, pcArt in index.html) into real files, so the game loads them instead of
# flood-filling 4200 px sheets in GDScript. Same steps, same numbers. Run: python tools/build_ui_art.py, then node tools/import.mjs
#   assets/ui/cut/pausecrt.png     the monitor with its glass cut out; ekgbox.png, weaponwrap.png the HUD frames with theirs
#   assets/ui/cut/pip-N.png        the handheld terminal, 3 frames (glass = the phosphor gradient), press-N.png the 4 button-press frames
#   assets/ui/cut/pip-glass.png    the last frame's glass shape; pip-bloom.png / pip-bloom-wide.png the light spilling from it (blurred, quarter size)
#   assets/ui/cut/pip-hand-N.png, press-hand-N.png   where the skin is (half size): Tommy's hands are white
#   ui/ui_art.gd                   the numbers that go with them (generated)
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
SRC = os.path.join(ROOT, 'assets', 'ui')
OUT = os.path.join(SRC, 'cut')
os.makedirs(OUT, exist_ok=True)
rnd = lambda v: int(math.floor(v + 0.5))     # JS Math.round


def seed_region(mask, sx, sy):
    """the connected region of mask (4-neighbour) holding the seed, as a bool array; None when the seed is not in mask"""
    if not mask[sy, sx]:
        return None
    lab, _ = ndimage.label(mask)
    return lab == lab[sy, sx]


def write_import(png, big=False):
    """ask for mipmaps (and block compression on the big sheets) before Godot first imports the file; every other setting stays the default"""
    rel = 'res://assets/ui/cut/' + os.path.basename(png)
    txt = '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\n\nsource_file="%s"\n\n[params]\n\ncompress/mode=%d\ncompress/high_quality=%s\nmipmaps/generate=true\nprocess/fix_alpha_border=true\ndetect_3d/compress_to=0\n' % (rel, 2 if big else 0, 'true' if big else 'false')
    if not os.path.exists(png + '.import'):
        open(png + '.import', 'w').write(txt)


def save(name, arr, big=False, mode=None):
    p = os.path.join(OUT, name)
    Image.fromarray(arr, mode).save(p, optimize=False, compress_level=6)
    write_import(p, big)
    return p


def phosphor_glass(d, mark_glass, bcx, bcy, bw, bh, H):
    """terminal glass: dark green, brighter in the middle, faint scanlines (spacing scales with the art's resolution)"""
    ys, xs = np.nonzero(mark_glass)
    dx = (xs - bcx) / (bw * 0.6)
    dy = (ys - bcy) / (bh * 0.6)
    k = np.maximum(0.0, 1.0 - (dx * dx + dy * dy))
    sl = np.where((np.floor(ys * 667.0 / H).astype(int) & 3) == 0, 0.88, 1.0)
    kk = np.power(k, 0.8)                     # phosphor glow: bright centre, dark vignetted corners like curved CRT glass
    d[ys, xs, 0] = ((4 + 40 * kk) * sl).astype(np.uint8)
    d[ys, xs, 1] = ((26 + 175 * kk) * sl).astype(np.uint8)
    d[ys, xs, 2] = ((10 + 70 * kk) * sl).astype(np.uint8)
    d[ys, xs, 3] = 255


def hand_mask(d, seeds):
    """_whiteHands: skin connected to a hand seed; leave the terminal and alpha intact"""
    r, g, b, a = [d[..., i].astype(np.float32) for i in range(4)]
    skin = (a > 0) & (r > g * 1.25) & (r < g * 2.1) & (g > b * 1.15) & (g < b * 1.85)
    out = np.zeros(skin.shape, bool)
    lab, _ = ndimage.label(skin)
    for x, y in seeds:
        y = int(y); x = int(x)
        if skin[y, x]:
            out |= lab == lab[y, x]
    return out


def half_mask(mask):
    im = Image.fromarray((mask * 255).astype(np.uint8), 'L')
    return np.asarray(im.resize((im.width // 2, im.height // 2), Image.BILINEAR))


# ---- the pause monitor (pcArt): cut the black glass out, and the pale reflection patch the dark flood cannot reach
def build_pause():
    d = np.array(Image.open(os.path.join(SRC, 'pausecrt-2400.png')).convert('RGBA'))
    H, W = d.shape[:2]
    dark = (d[..., 3] >= 128) & (d[..., :3].max(axis=2) < 45)
    seen = seed_region(dark, W // 2, H // 2)
    d[seen, 3] = 0
    ys, xs = np.nonzero(seen)
    x1, x2, y1, y2 = xs.min(), xs.max(), ys.min(), ys.max()
    pts = []
    for y in range(y1, y2 + 1, 3):
        r = np.nonzero(seen[y])[0]
        if r.size:
            pts += [(int(r[0]), y), (int(r[-1]), y)]
    for x in range(x1, x2 + 1, 3):
        c = np.nonzero(seen[:, x])[0]
        if c.size:
            pts += [(x, int(c[0])), (x, int(c[-1]))]
    pts = sorted(set(pts))
    cr = lambda o, a, b: (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) > 1 and cr(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) > 1 and cr(up[-2], up[-1], p) <= 0:
            up.pop()
        up.append(p)
    hull = lo[:-1] + up[:-1]
    im = Image.new('L', (W, H), 0)
    ImageDraw.Draw(im).polygon(hull, fill=255)
    inside = np.asarray(im) > 128
    box = np.zeros(seen.shape, bool)
    box[y1:y2 + 1, x1:x2 + 1] = True
    patch = inside & box & ~seen
    d[patch, 3] = np.round(d[patch, 3] * 0.16).astype(np.uint8)
    save('pausecrt.png', d, big=True)
    return {'ratio': W / H, 'hole': (x1 / W, y1 / H, (x2 + 1) / W, (y2 + 1) / H)}


# ---- the handheld terminal (Wheel._buildPip): 3 frames
def build_pip():
    img = np.array(Image.open(os.path.join(SRC, 'pip4-4200.png')).convert('RGBA'))
    H, W = img.shape[:2]
    seeds = [(0.1725, 0.735), (0.5, 0.465), (0.855, 0.412)]     # screen centre of each frame (fraction of the sheet)
    scr = None
    glass_mask = None
    fw_last = 0
    for f in range(3):
        x0 = rnd(f * W / 3)
        cell = rnd((f + 1) * W / 3) - x0
        pad = rnd(0.17 * H)                                      # empty room on the left, where the cut-off arm is continued
        fw = cell + pad
        d = np.zeros((H, fw, 4), np.uint8)
        d[:, pad:pad + cell] = img[:, x0:x0 + cell]
        # the arm runs off the frame's left edge (the sheet is cut into thirds): continue it down-left along its own edge, so there is no hard vertical cut
        def run(x):
            y = H - 1
            if d[y, x, 3] < 200:
                return H
            while y > 0 and d[y - 1, x, 3] >= 200:
                y -= 1
            return y
        dxs = rnd(0.03 * H)
        t0, t1 = run(pad), run(pad + dxs)
        if t0 < H - 4 and t1 < t0:
            slope = (t0 - t1) / dxs                              # how many rows the top edge drops per column going left
            for x in range(pad - 1, -1, -1):
                sh = (pad - x) * slope
                top = rnd(t0 + sh)
                if top >= H:
                    break
                ys = np.arange(top, H)
                src = np.minimum(H - 1, np.maximum(t0, np.floor(ys - sh + 0.5).astype(int)))
                d[ys, x] = d[src, pad]
        # the next frame's arm pokes into this cell's right edge: remove small opaque pieces that touch the right edge
        opaque = d[..., 3] >= 128
        lab, _ = ndimage.label(opaque)
        for l in np.unique(lab[:, fw - 1]):
            if l and (lab == l).sum() < fw * H * 0.03:
                d[lab == l, 3] = 0
        white = (d[..., 3] < 128) | (d[..., :3].min(axis=2) >= 215)
        dark = (d[..., 3] >= 128) & (d[..., :3].max(axis=2) < 22)
        # background: every "white" region touching the border
        lab, _ = ndimage.label(white)
        border = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
        bg = np.isin(lab, border[border > 0])
        # the glass: from the screen's centre, through white or dark, not through what the background flood took
        sc = (min(fw - 1, max(0, rnd(seeds[f][0] * W - x0) + pad)), min(H - 1, max(0, rnd(seeds[f][1] * H))))
        glass = seed_region((white | dark) & ~bg, sc[0], sc[1])
        if glass is None:
            glass = np.zeros(white.shape, bool)
            bcx, bcy, bw, bh = sc[0], sc[1], 200, 160
        else:
            ys, xs = np.nonzero(glass)
            bcx, bcy, bw, bh = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2, xs.max() - xs.min(), ys.max() - ys.min()
        # soften the fringe where the white background met the device
        edge = ndimage.binary_dilation(bg, structure=ndimage.generate_binary_structure(2, 1)) & ~bg & ~glass
        m = d[..., :3].min(axis=2).astype(np.float32)
        fr = edge & (m > 170)
        d[fr, 3] = np.round(np.clip((235 - m[fr]) / 65, 0, 1) * 255).astype(np.uint8)
        d[bg, 3] = 0
        phosphor_glass(d, glass, bcx, bcy, bw, bh, H)
        hands = hand_mask(d, [(pad + cell * (0.08 if f == 0 else 0.13), H * 0.8)])
        save('pip-%d.png' % f, d, big=True)
        save('pip-hand-%d.png' % f, half_mask(hands), mode='L')
        scr = (bcx, bcy, int(bw), int(bh))
        fw_last = fw
        if f == 2:
            glass_mask = glass
    save('pip-glass.png', (glass_mask * 255).astype(np.uint8), mode='L')
    # light spilling out of the glass onto the bezel: the screen shape blurred, a tight halo + a wide one (the shader cuts the glass itself out)
    g = Image.fromarray((glass_mask * 255).astype(np.uint8), 'L')
    for name, blur in (('pip-bloom.png', 7 * H / 667), ('pip-bloom-wide.png', 22 * H / 667)):
        b = g.filter(ImageFilter.GaussianBlur(blur)).resize((g.width // 4, g.height // 4), Image.BILINEAR)
        save(name, np.asarray(b), mode='L')
    return {'fw': fw_last, 'fh': H, 'scr': scr}


# ---- the button-press sheet (Wheel._buildPress): 4 frames of a finger pressing a button, not on a clean grid: separated by connected shapes
def build_press():
    A = np.array(Image.open(os.path.join(SRC, 'pippressed-4200.png')).convert('RGBA'))
    H, W = A.shape[:2]
    G = 4
    gw, gh = math.ceil(W / G), math.ceil(H / G)
    occ = np.zeros((gh, gw), bool)
    ys, xs = np.nonzero(A[..., 3] > 60)
    occ[ys // G, xs // G] = True
    lab, n = ndimage.label(occ, structure=np.ones((3, 3)))       # coarse grid, 8-neighbour
    comps = []
    for i in range(1, n + 1):
        yy, xx = np.nonzero(lab == i)
        if yy.size > 400:
            comps.append((xx.min(), yy.min(), xx.max(), yy.max(), i))
    comps.sort()
    if len(comps) != 4:
        sys.exit('expected 4 press frames, found %d' % len(comps))
    seeds = [(0.1475, 0.39), (0.396, 0.39), (0.6425, 0.39), (0.8875, 0.39)]
    frames = []
    labx = np.repeat(np.repeat(lab, G, axis=0), G, axis=1)[:H, :W]
    for k, (cx1, cy1, cx2, cy2, cid) in enumerate(comps):
        m = 6
        bx, by = max(0, cx1 * G - m), max(0, cy1 * G - m)
        w, h = min(W, (cx2 + 1) * G + m) - bx, min(H, (cy2 + 1) * G + m) - by
        d = np.zeros((h, w, 4), np.uint8)
        sel = (A[by:by + h, bx:bx + w, 3] > 0) & (labx[by:by + h, bx:bx + w] == cid)
        d[sel] = A[by:by + h, bx:bx + w][sel]
        dark = (d[..., 3] >= 128) & (d[..., :3].max(axis=2) < 30)
        sx, sy = rnd(seeds[k][0] * W) - bx, rnd(seeds[k][1] * H) - by
        glass = seed_region(dark, sx, sy)                        # flood the black glass from the screen's centre
        yy, xx = np.nonzero(glass)
        bcx, bcy, bw, bh = (xx.min() + xx.max()) / 2, (yy.min() + yy.max()) / 2, xx.max() - xx.min(), yy.max() - yy.min()
        phosphor_glass(d, glass, bcx, bcy, bw, bh, H)
        hands = hand_mask(d, [(w * 0.13, h * 0.65), (w * 0.65, h * 0.88)])
        save('press-%d.png' % k, d, big=True)
        save('press-hand-%d.png' % k, half_mask(hands), mode='L')
        frames.append({'w': w, 'h': h, 'scr': (bcx, bcy, int(bw), int(bh))})
    return frames


# ---- the HUD frames (cutFrameArt): their screens are opaque black in the picture; flood the dark glass from the middle so the readout behind shows through
def build_frame(src, out):
    d = np.array(Image.open(os.path.join(SRC, src)).convert('RGBA'))
    H, W = d.shape[:2]
    dark = (d[..., 3] >= 128) & (d[..., :3].max(axis=2) < 45)
    seen = seed_region(dark, W // 2, H // 2)
    d[seen, 3] = 0
    save(out, d)


build_frame('ekgbox-1100.png', 'ekgbox.png')
build_frame('weaponwrap-1000.png', 'weaponwrap.png')
if len(sys.argv) > 1 and sys.argv[1] == 'frames':
    sys.exit(0)
pause = build_pause()
pip = build_pip()
press = build_press()
vec = lambda s: 'Rect2(%.2f, %.2f, %d, %d)' % (s[0], s[1], s[2], s[3])
gd = '''class_name UiArt
extends RefCounted
## The numbers that go with the baked UI art in assets/ui/cut (generated by tools/build_ui_art.py; do not edit by hand). A Rect2 here is a glass: position = its centre, size = its size, in sheet pixels.

const PAUSE_RATIO := %.6f
const PAUSE_HOLE := [%.5f, %.5f, %.5f, %.5f]
const PIP_FW := %d
const PIP_FH := %d
const PIP_SCR := %s
const PRESS_SIZE: Array[Vector2] = [%s]
const PRESS_SCR: Array[Rect2] = [%s]
''' % (pause['ratio'], *pause['hole'], pip['fw'], pip['fh'], vec(pip['scr']),
       ', '.join('Vector2(%d, %d)' % (f['w'], f['h']) for f in press), ', '.join(vec(f['scr']) for f in press))
open(os.path.join(ROOT, 'ui', 'ui_art.gd'), 'w', newline='\n').write(gd)
print(gd)
