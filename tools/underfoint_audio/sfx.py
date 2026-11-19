# The UNDERFOINT chase's sounds, designed from scratch and from the project's own recordings: python -I tools/underfoint_audio/sfx.py [name ...]
# Sources: synthesis here; the user's ElevenLabs-made effects in assets/sfx/omnisphere and assets/sfx/frug-showdown (decoded by decode.mjs into the scratch folder's src/); the Sigil's own
# processed voice (sigil_voice.py) and raw Fish moans/screams (fish_fetch.mjs, scratch moan/). Writes mono 16-bit 44.1 kHz WAVs to assets/sfx/underfoint/. Loops are crossfaded at the seam.
import os
import sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True      # (no __pycache__ left in the project)
sys.path.insert(0, HERE)      # (run with -I: the tool's own folder only)
import dsp  # noqa: E402
from dsp import SR  # noqa: E402

SRC = os.path.join(dsp.SCRATCH, 'src')
MOAN = os.path.join(dsp.SCRATCH, 'moan')
VOWEL = {      # formants: (Hz, bandwidth Hz, gain)
    'a': [(730, 90, 1.0), (1090, 110, 0.5), (2440, 160, 0.25), (3400, 250, 0.12)],
    'o': [(570, 80, 1.0), (840, 100, 0.45), (2410, 160, 0.15), (3300, 250, 0.08)],
    'u': [(320, 70, 1.0), (870, 100, 0.3), (2240, 160, 0.1), (3200, 250, 0.05)],
    'e': [(530, 80, 1.0), (1840, 110, 0.4), (2480, 160, 0.25), (3500, 250, 0.1)],
    'aw': [(650, 90, 1.0), (950, 110, 0.55), (2500, 170, 0.2), (3300, 250, 0.1)],
}


def src(name):
    return dsp.read(os.path.join(SRC, name + '.wav'))


def moan(name):
    return dsp.read(os.path.join(MOAN, name + '.wav'))


def wobble(n, rate, rng):
    """smooth random motion: values at `rate` per second, eased between"""
    k = max(3, int(n / SR * rate) + 3)
    pts = rng.standard_normal(k)
    x = np.linspace(0, k - 2, n)
    i = x.astype(int)
    f = x - i
    f = f * f * (3 - 2 * f)
    return pts[i] * (1 - f) + pts[i + 1] * f


def seg(x, a, b):
    return x[int(a * SR):int(b * SR)].copy()


def fade(x, a=0.005, b=0.05):
    y = x.copy()
    na, nb = int(a * SR), int(b * SR)
    if na:
        y[:na] *= np.linspace(0, 1, na)
    if nb:
        y[-nb:] *= np.linspace(1, 0, nb) ** 1.5
    return y


def voice(n, f0, vowel='a', size=1.0, rough=0.0, breath=0.08, rng=None, jitter=0.012):
    """a throat: a jittered sawtooth (f0 per sample), roughened by a 20-40 Hz flutter, through a vowel's formants scaled by size (< 1 is bigger)"""
    rng = rng or np.random.default_rng(1)
    f0 = np.broadcast_to(f0, (n,)).astype(float) * (1 + jitter * wobble(n, 40, rng))
    ph = np.cumsum(f0 / SR)
    saw = 2 * (ph % 1.0) - 1
    fl = np.sin(2 * np.pi * np.cumsum((26 + 9 * wobble(n, 3, rng)) / SR))
    s = saw * (1 + rough * fl) + breath * rng.standard_normal(n) * (1 + rough * fl)
    out = np.zeros(n)
    for F, bw, g in VOWEL[vowel]:
        out += g * dsp.resonator(s, F * size, F * size / bw)
    return out / (np.abs(out).max() + 1e-9)


def metal(n, freqs, decays, amps=None, rng=None):
    """a struck steel thing: damped partials"""
    rng = rng or np.random.default_rng(2)
    tt = dsp.t(n)
    y = np.zeros(n)
    for i, (f, d) in enumerate(zip(freqs, decays)):
        a = 1.0 if amps is None else amps[i]
        y += a * np.sin(2 * np.pi * f * (1 + 0.002 * rng.standard_normal()) * tt + rng.uniform(0, 6.28)) * np.exp(-tt / d)
    y[: int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    return y / (np.abs(y).max() + 1e-9)


def thud(n, f_hi=70.0, f_lo=32.0, tau=0.3, rng=None):
    """the body of a heavy impact: a falling sine and a low noise burst"""
    rng = rng or np.random.default_rng(3)
    tt = dsp.t(n)
    f = f_lo + (f_hi - f_lo) * np.exp(-tt / 0.08)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / tau)
    nz = dsp.lp(rng.standard_normal(n), 220.0, 2) * np.exp(-tt / (tau * 0.4))
    y = s + 0.6 * nz / (np.abs(nz).max() + 1e-9)
    y[: int(0.0015 * SR)] *= np.linspace(0, 1, int(0.0015 * SR))
    return y / (np.abs(y).max() + 1e-9)


def debris(n, rate_fn, rng, lo=900.0, hi=5200.0, size=1.0):
    """falling stone and grit: short resonant clacks at a rate that changes over time (rate_fn(t) per second)"""
    y = np.zeros(n)
    tcur = 0.0
    while True:
        r = max(rate_fn(tcur), 0.5)
        tcur += rng.exponential(1.0 / r)
        if tcur >= n / SR:
            break
        L = int(rng.uniform(0.003, 0.03) * size * SR) + 8
        g = rng.standard_normal(L) * np.exp(-np.arange(L) / (L * 0.25))
        f = np.exp(rng.uniform(np.log(lo), np.log(hi)))
        c = dsp.resonator(np.pad(g, (0, int(0.03 * SR))), f, rng.uniform(3, 14))
        c = c / (np.abs(c).max() + 1e-9) * rng.uniform(0.15, 1.0) * min(1.0, rate_fn(tcur) / 40.0 + 0.3)
        dsp.place(y, c, tcur)
        if rng.random() < 0.08:      # now and then a lump
            dsp.place(y, thud(int(0.25 * SR), rng.uniform(90, 160), rng.uniform(50, 80), 0.06, rng) * rng.uniform(0.3, 0.8), tcur)
    return y


def crackle(n, rate, rng, lo=2500.0, hi=7500.0):
    """electrical arcing: sparse sharp ticks with a ring"""
    y = np.zeros(n)
    tcur = 0.0
    while True:
        tcur += rng.exponential(1.0 / rate)
        if tcur >= n / SR:
            break
        L = int(rng.uniform(0.001, 0.006) * SR) + 4
        b = dsp.hp(rng.standard_normal(L), 2000.0, 2) * np.exp(-np.arange(L) / (L * 0.3))
        r = dsp.resonator(np.pad(b, (0, int(0.015 * SR))), rng.uniform(lo, hi), 10.0)
        dsp.place(y, r / (np.abs(r).max() + 1e-9) * rng.uniform(0.2, 1.0), tcur)
    return y


def buzz(n, base=50.0, rng=None):
    """mains: 50 Hz and up, leaning on 100 Hz like a transformer, with a rectifier's edge"""
    tt = dsp.t(n)
    h = np.zeros(n)
    for k in range(1, 36):
        a = (1.0 if k == 2 else 0.55 if k == 1 else 0.7 / k ** 0.7) * (1.4 if k % 2 == 1 and k > 2 else 1.0)
        h += a * np.sin(2 * np.pi * base * k * tt + k * 1.3)
    return h / (np.abs(h).max() + 1e-9)


def ring(x, f):
    return x * np.sin(2 * np.pi * f * dsp.t(len(x)))


def crush(x, rate=11025.0, bits=8):
    n = np.arange(len(x))
    s = np.minimum(len(x) - 1, (np.floor(n * rate / SR) * SR / rate).astype(int))
    p = np.abs(x).max() + 1e-12
    q = 2 ** (bits - 1)
    return np.round(x[s] / p * q) / q * p


def stutter(x, at, grain, reps, rng):
    """a digital stammer: the grain at `at` repeated, each time a little quieter"""
    g = seg(x, at, at + grain)
    g = fade(g, 0.002, 0.004)
    y = x.copy()
    for k in range(reps):
        dsp.place(y, g * (0.9 ** k), at + grain * (k + 1), 1.0)
    return y


def space(x, rt=1.6, wet=0.25, bright=5000.0, seed=11):
    """a big stone tunnel around it"""
    ir = dsp.hall_ir(rt * 1.4, rt, bright, np.random.default_rng(seed))
    w = dsp.convolve(x, ir)
    d = np.zeros(len(w))
    d[: len(x)] = x
    return d + wet * w / (np.sqrt(np.mean(w ** 2)) + 1e-12) * np.sqrt(np.mean(x ** 2))


def lv(x, db):
    """x scaled to peak 1, then by db"""
    return x / (np.abs(x).max() + 1e-12) * 10 ** (db / 20)


def master(x, drive=1.4, rt=None, wet=0.0, length=None):
    if rt:
        x = space(x, rt, wet)
    x = dsp.hp(x, 22.0, 2)
    x = np.tanh(x / (np.abs(x).max() + 1e-12) * drive) / np.tanh(drive)
    if length:
        x = dsp.fit(x, int(length * SR))
    return fade(dsp.trim(x, 0.0, 0.25, -50.0, 0.08), 0.0, 0.08)


def choir_voices(n, rng, notes, vowels, size=0.9, swell=0.25):
    """the hive: a cluster of throats that drift and moan, never quite together"""
    y = np.zeros(n)
    for i, f in enumerate(notes):
        f0 = f * (1 + 0.02 * wobble(n, 0.4 + 0.2 * rng.random(), rng)) * (1 + 0.006 * np.sin(2 * np.pi * (4.5 + rng.random()) * dsp.t(n)))
        v = voice(n, f0, vowels[i % len(vowels)], size * rng.uniform(0.9, 1.1), 0.15, 0.12, rng)
        amp = np.clip(0.55 + swell * wobble(n, 0.35, rng) + 0.25 * np.sin(2 * np.pi * rng.uniform(0.1, 0.25) * dsp.t(n) + rng.uniform(0, 6)), 0.05, 1.0)
        y += v * amp
    return y / (np.abs(y).max() + 1e-9)


# ---- the beast -----------------------------------------------------------------------------------------------------------------------------------------------------------

def roar(variant):
    rng = np.random.default_rng(100 + variant)
    L = 3.3 if variant == 1 else 3.0
    n = int(L * SR)
    tt = dsp.t(n)
    out = np.zeros(n)
    # the throat: the brute's roar taken down to something forty metres long
    r = src('roar')
    core = seg(r, 0.35, 2.55) if variant == 1 else seg(r, 1.2, 3.3)
    core = dsp.shift(core, -7.0 if variant == 1 else -8.5)
    dsp.place(out, lv(fade(core, 0.01, 0.4), -2), 0.08)
    # its own growl: a huge slow throat, rough, rising then breaking
    f0 = np.interp(tt, [0, 0.35, 1.6, L], [38, 58, 52, 34] if variant == 1 else [44, 66, 49, 30])
    g = voice(n, f0, 'aw' if variant == 1 else 'a', 0.52, 0.85, 0.3, rng)
    g = np.tanh(g * 3.0)
    dsp.place(out, lv(g * dsp.adsr(n, 0.12, 0.3, 0.8, 0.9), -5), 0.0)
    # the Sigil in it: its growl through the voice's machine (ring mod, crushed and driven)
    s = moan('growl-a')
    s = dsp.shift(seg(s, 0.1, 1.4), -10.0)
    s = crush(np.tanh(ring(s, 45.0) * 4 + s * 2), 11025.0, 8)
    dsp.place(out, lv(fade(s, 0.02, 0.3), -9), 0.15)
    # the people inside it screaming, far down
    sc = moan('scream-a')
    sc = dsp.pitch(seg(sc, 2.0 + variant * 3.1, 4.6 + variant * 3.1), -12.0)
    dsp.place(out, lv(fade(dsp.bp(sc, 150, 3500), 0.2, 0.6), -13), 0.25)
    # the electricity: a buzz that swells with it, arcs, a flyback whine climbing
    b = buzz(n, 50.0) * dsp.adsr(n, 0.25, 0.4, 0.7, 1.0)
    dsp.place(out, lv(b, -17), 0.0)
    dsp.place(out, lv(crackle(n, 22.0, rng), -14) * dsp.adsr(n, 0.1, 0.5, 0.6, 1.0), 0.0)
    wh = np.sin(2 * np.pi * np.cumsum(np.interp(tt, [0, L * 0.6, L], [5200, 9400, 7000])) / SR) * dsp.adsr(n, 0.4, 0.3, 0.6, 1.0)
    dsp.place(out, lv(wh, -26), 0.0)
    # weight: a falling sub under the onset
    dsp.place(out, lv(thud(int(1.6 * SR), 62, 26, 0.7, rng), -4), 0.03)
    out = dsp.peak_eq(dsp.peak_eq(out, 2400.0, 5.0, 0.8), 4500.0, 3.0, 1.0)      # (presence, so it cuts through gunfire and the music)
    return master(out, 1.6, 1.7, 0.28, L)


def snarl(variant):
    rng = np.random.default_rng(200 + variant)
    L = 1.25
    n = int(L * SR)
    tt = dsp.t(n)
    out = np.zeros(n)
    f0 = np.interp(tt, [0, 0.15, 0.7, L], [[55, 72, 60, 40], [48, 66, 70, 45], [60, 80, 55, 38]][variant - 1])
    g = voice(n, f0, ['e', 'a', 'aw'][variant - 1], 0.6, 1.0, 0.45, rng)
    dsp.place(out, lv(np.tanh(g * 4) * dsp.adsr(n, 0.04, 0.2, 0.75, 0.45), -3), 0.0)
    if variant == 1:      # breath through it
        h = dsp.shift(seg(src('huff'), 0.4, 1.4), -6.0)
        dsp.place(out, lv(fade(h, 0.01, 0.2), -6), 0.0)
    elif variant == 2:    # a scream folded into it
        sc = dsp.pitch(seg(moan('scream-a'), 12.0, 13.2), -9.0)
        dsp.place(out, lv(fade(dsp.bp(sc, 200, 3000), 0.03, 0.3), -9), 0.05)
    else:                 # a bite of the roar
        r = dsp.shift(seg(src('roar'), 1.0, 1.8), -6.0)
        dsp.place(out, lv(fade(r, 0.01, 0.25), -5), 0.0)
    s = dsp.shift(seg(moan('growl-a'), 0.2, 0.9), -9.0)
    dsp.place(out, lv(crush(np.tanh(ring(s, 45.0) * 5), 11025.0, 8), -11), 0.02)
    dsp.place(out, lv(crackle(n, 30.0, rng) * dsp.adsr(n, 0.02, 0.2, 0.5, 0.5), -15), 0.0)
    dsp.place(out, lv(thud(int(0.6 * SR), 80, 40, 0.25, rng), -9), 0.0)
    return master(out, 1.8, 1.1, 0.2, L)


def shriek(variant):
    rng = np.random.default_rng(300 + variant)
    L = 1.55
    n = int(L * SR)
    tt = dsp.t(n)
    out = np.zeros(n)
    if variant == 1:      # the hive screams, the machine squeals
        sc = dsp.shift(seg(moan('scream-a'), 20.0, 21.3), -4.0)
        sc = stutter(sc, 0.18, 0.045, 3, rng)
    else:
        sc = dsp.shift(seg(src('scream'), 0.25, 1.5), -4.5)
        sc = stutter(sc, 0.3, 0.06, 2, rng)
    dsp.place(out, lv(fade(sc, 0.01, 0.35), -2), 0.0)
    f = np.interp(tt, [0, 0.12, 0.6, L], [900, 2600, 2100, 1300] if variant == 1 else [1200, 3100, 1800, 900])
    fm = np.sin(2 * np.pi * np.cumsum(f + f * 0.8 * np.sin(2 * np.pi * np.cumsum(f * 0.5) / SR)) / SR)
    sq = np.tanh(fm * 3) * dsp.adsr(n, 0.02, 0.3, 0.5, 0.6)
    dsp.place(out, lv(crush(sq, 16000.0, 10), -12), 0.0)
    ch = choir_voices(n, rng, [196, 233, 277, 330], ['a', 'e'], 1.1, 0.4)
    dsp.place(out, lv(ch * dsp.adsr(n, 0.05, 0.3, 0.6, 0.6), -14), 0.0)
    dsp.place(out, lv(crackle(n, 45.0, rng), -12) * dsp.adsr(n, 0.01, 0.2, 0.5, 0.8), 0.0)
    em = seg(src('em-blow'), 0.0, 1.2)
    dsp.place(out, lv(fade(dsp.hp(em, 600), 0.002, 0.4), -12), 0.0)
    return master(out, 1.7, 1.2, 0.22, L)


def stomp(variant):
    rng = np.random.default_rng(400 + variant)
    L = 0.85
    n = int(L * SR)
    out = np.zeros(n)
    dsp.place(out, lv(thud(n, 75 if variant == 1 else 64, 30, 0.32, rng), -1), 0.0)
    land = dsp.shift(src('ff-land'), -8.0 if variant == 1 else -10.0)
    dsp.place(out, lv(fade(seg(land, 0.0, 0.8), 0.001, 0.2), -6), 0.0)
    dsp.place(out, lv(metal(int(0.6 * SR), [118, 263, 431, 702, 1180], [0.35, 0.22, 0.15, 0.1, 0.06], [1, 0.7, 0.5, 0.35, 0.2], rng), -12), 0.004)
    dsp.place(out, lv(debris(n, lambda s: 140 * np.exp(-s / 0.12), rng, 700, 4200), -13), 0.02)
    return master(out, 1.5, 0.9, 0.12, L)


def hive():
    rng = np.random.default_rng(500)
    L = 6.6
    n = int(L * SR)
    out = np.zeros(n)
    ch = choir_voices(n, rng, [92.5, 98.0, 116.5, 138.6, 146.8, 185.0], ['o', 'u', 'aw', 'o', 'e', 'u'], 0.95, 0.35)
    dsp.place(out, lv(ch, -4), 0.0)
    names = ['moan-horror-o', 'moan-adrian-o', 'moan-analog-o', 'moan-robot-o', 'moan-devesto-o', 'moan-horror-a', 'moan-analog-a', 'moan-robot-a']
    tcur = 0.0
    k = 0
    while tcur < L - 1.0:      # real throats too: slowed, smeared, overlapping
        m = moan(names[k % len(names)])
        m = dsp.pv_stretch(dsp.hp(m, 90.0), rng.uniform(2.2, 3.4))
        m = dsp.shift(m, rng.uniform(-5.0, 1.0))
        m = fade(dsp.trim(m, 0.0, 0.0, -36.0, 0.0), 0.35, 0.8)
        dsp.place(out, lv(m, rng.uniform(-14, -9)), tcur)
        tcur += rng.uniform(0.5, 1.2)
        k += 1
    b = buzz(n, 50.0) * (0.75 + 0.25 * np.sin(2 * np.pi * dsp.t(n) / L * 2))
    dsp.place(out, lv(b, -16), 0.0)
    dsp.place(out, lv(crackle(n, 3.0, rng), -22), 0.0)
    out = space(out, 1.4, 0.3, 4000.0)[:n]
    out = dsp.hp(out, 30.0, 2)
    y = dsp.loop_seam(out, 0.6)
    return lv(np.tanh(y / np.abs(y).max() * 1.2), -1)


def crt():
    rng = np.random.default_rng(600)
    L = 3.0
    n = int((L + 0.4) * SR)
    tt = dsp.t(n)
    whine = np.sin(2 * np.pi * 15734.0 * tt) * (0.8 + 0.2 * np.sin(2 * np.pi * 0.6667 * tt))
    sub = np.sin(2 * np.pi * 7867.0 * tt) * 0.25
    hum = buzz(n, 60.0) * (0.85 + 0.15 * np.sin(2 * np.pi * 1.0 * tt))
    hiss = dsp.bp(rng.standard_normal(n), 3000.0, 9000.0, 2)
    fizz = dsp.bp(rng.standard_normal(n), 1200.0, 3500.0, 2) * (0.5 + 0.5 * np.sin(2 * np.pi * 120.0 * tt)) ** 8
    y = lv(whine + sub, -14) + lv(hum, -6) + lv(hiss, -24) + lv(fizz, -16) + lv(crackle(n, 4.0, rng, 3000, 9000), -16)
    y = dsp.loop_seam(y, 0.4)
    return lv(y, -1)


# ---- the train -----------------------------------------------------------------------------------------------------------------------------------------------------------

def clack(rng, heavy=1.0):
    n = int(0.25 * SR)
    m = metal(n, [380, 720, 1150, 1900, 2950, 4100], [0.06, 0.05, 0.04, 0.03, 0.02, 0.012], [1, 0.8, 0.6, 0.5, 0.4, 0.3], rng)
    tick = dsp.hp(rng.standard_normal(int(0.006 * SR)), 2500.0, 2) * np.exp(-np.arange(int(0.006 * SR)) / (0.0015 * SR))
    return lv(m, -5) + lv(dsp.fit(tick, n), -8) + lv(thud(n, 110, 60, 0.05, rng), -2 + 3 * (heavy - 1))


def train_run():
    """rendered two loops long and the second kept, so the tunnel's tail from the loop before is already in it"""
    rng = np.random.default_rng(700)
    L = 6.0
    xf = 0.5
    n = int((2 * L + xf) * SR)
    tt = dsp.t(n)
    out = np.zeros(n)
    rumble = dsp.lp(dsp.brown(n, rng), 140.0, 2)
    roll = dsp.bp(rng.standard_normal(n), 220.0, 900.0, 2) * (0.8 + 0.2 * np.sin(2 * np.pi * 7.5 * tt))
    out += lv(rumble, -8) + lv(roll, -14)
    eng = np.zeros(n)      # the engine's throb
    for k in range(1, 14):
        eng += np.sin(2 * np.pi * 27.0 * k * tt + k) / k ** 0.9
    eng = dsp.lp(eng * (1 + 0.25 * np.sin(2 * np.pi * 13.5 * tt)), 420.0, 2)
    out += lv(eng, -10)
    joint = L / 7.0        # 7 rail joints a loop: 21 m rails at ~24 m/s; each truck's two axles, then the other truck's
    for j in range(16):
        t0 = j * joint + 0.05
        for dt_, hv in ((0.0, 1.0), (0.09, 0.9), (0.55, 0.85), (0.64, 0.8)):
            at = t0 + dt_
            if at < 2 * L + xf:
                dsp.place(out, clack(np.random.default_rng(int(round((at % L) * 1000)))) * hv * 10 ** (-1 / 20), at)      # (the same clack every loop)
    dsp.place(out, lv(crackle(n, 1.5, rng, 1500, 4000), -24), 0.0)      # chains and couplings ticking
    out = space(out, 0.9, 0.18, 3500.0)[int(L * SR):n]
    y = dsp.loop_seam(out, xf)
    return lv(np.tanh(y / np.abs(y).max() * 1.3), -1)


def train_screech():
    rng = np.random.default_rng(800)
    L = 3.0
    xf = 0.5
    n = int((L + xf) * SR)
    tt = dsp.t(n)
    y = np.zeros(n)
    for f, a in ((2110.0, 1.0), (4220.0, 0.35), (3390.0, 0.45), (6330.0, 0.12)):
        fr = f * (1 + 0.012 * wobble(n, 0.8, rng) + 0.002 * wobble(n, 25, rng))
        am = np.clip(0.6 + 0.5 * wobble(n, 4, rng), 0, 1.2) * (0.75 + 0.25 * np.sin(2 * np.pi * np.cumsum(28 + 8 * wobble(n, 2, rng)) / SR))
        y += a * np.sin(2 * np.pi * np.cumsum(fr) / SR) * am
    grind = dsp.bp(rng.standard_normal(n), 1200.0, 6500.0, 2) * np.clip(0.6 + 0.4 * wobble(n, 6, rng), 0, 1)
    y = lv(np.tanh(y * 1.5), -3) + lv(grind, -14) + lv(crackle(n, 12.0, rng, 3000, 8000), -18)
    y = dsp.loop_seam(y, xf)
    return lv(y, -1)


def chime(n, f, rng):
    tt = dsp.t(n)
    bend = 1 - 0.02 * np.exp(-tt / 0.08)
    fr = f * bend * (1 + 0.0025 * np.sin(2 * np.pi * 5.2 * tt))
    y = np.zeros(n)
    for det in (0.0, 0.0035):
        ph = np.cumsum(fr * (1 + det) / SR)
        y += 2 * (ph % 1.0) - 1
    y = dsp.resonator(y, f * 3.1, 2.0) * 0.6 + dsp.resonator(y, 1250.0, 3.0) + 0.25 * y
    return y / (np.abs(y).max() + 1e-9)


def train_horn():
    rng = np.random.default_rng(900)
    L = 2.5
    n = int(L * SR)
    y = np.zeros(n)
    for f in (233.1, 277.2, 349.2):      # B-flat minor: old, low, sorry for itself
        y += chime(n, f, rng)
    env = dsp.adsr(n, 0.06, 0.15, 0.85, 0.3, 1.85)
    air = dsp.bp(rng.standard_normal(n), 800.0, 4000.0, 2) * env
    y = np.tanh(y / np.abs(y).max() * 1.6) * env + lv(air, -22)
    return master(y, 1.2, 1.8, 0.35, L)


def train_bump():
    rng = np.random.default_rng(1000)
    L = 0.8
    n = int(L * SR)
    out = np.zeros(n)
    dsp.place(out, lv(thud(n, 66, 38, 0.18, rng), -1), 0.0)
    dsp.place(out, lv(metal(int(0.7 * SR), [221, 509, 861, 1333, 2102, 3010], [0.4, 0.25, 0.18, 0.12, 0.08, 0.05], [1, 0.8, 0.6, 0.5, 0.3, 0.2], rng), -6), 0.012)
    land = dsp.shift(src('ff-land'), -3.0)
    dsp.place(out, lv(fade(seg(land, 0.0, 0.7), 0.001, 0.2), -8), 0.0)
    for k in range(5):      # the rattle after
        dsp.place(out, clack(rng, 0.6) * 10 ** (-(14 + 3 * k) / 20), 0.08 + k * rng.uniform(0.05, 0.09))
    return master(out, 1.4, 0.7, 0.1, L)


def train_brake():
    rng = np.random.default_rng(1100)
    L = 3.0
    n = int(L * SR)
    tt = dsp.t(n)
    hiss = dsp.bp(rng.standard_normal(n), 2000.0, 8000.0, 2) * np.exp(-tt / 0.35)
    f = np.interp(tt, [0, 0.3, 2.4, L], [2950, 2900, 2450, 2400])
    sq = np.zeros(n)
    for k, a in ((1, 1.0), (2, 0.3), (3, 0.12)):
        sq += a * np.sin(2 * np.pi * np.cumsum(f * k * (1 + 0.004 * wobble(n, 18, rng))) / SR)
    stick = 0.7 + 0.3 * np.sin(2 * np.pi * np.cumsum(24 + 6 * wobble(n, 3, rng)) / SR)
    env = np.interp(tt, [0, 0.25, 0.6, 2.5, L], [0, 0.5, 1.0, 0.9, 0])
    grind = dsp.bp(rng.standard_normal(n), 900.0, 5000.0, 2) * env
    y = lv(hiss, -6) + lv(np.tanh(sq * 2) * stick * env, -3) + lv(grind, -13)
    dsp.place(y, lv(thud(int(0.4 * SR), 90, 45, 0.1, rng), -6), 2.55)
    return master(y, 1.2, 0.9, 0.15, L)


def train_start():
    rng = np.random.default_rng(1200)
    L = 3.0
    n = int(L * SR)
    tt = dsp.t(n)
    rpm = np.interp(tt, [0, 0.4, 2.2, L], [16, 19, 38, 40])
    eng = np.zeros(n)
    for k in range(1, 16):
        eng += np.sin(2 * np.pi * np.cumsum(rpm * k) / SR + k) / k ** 0.8
    eng = dsp.lp(np.tanh(eng * 1.5), 600.0, 2) * np.interp(tt, [0, 0.3, 2.0, L], [0.2, 0.6, 1.0, 1.0])
    turbo = np.sin(2 * np.pi * np.cumsum(np.interp(tt, [0, 2.5], [900, 3400])) / SR) * np.interp(tt, [0, 0.8, L], [0, 0.3, 0.6])
    smoke = dsp.bp(rng.standard_normal(n), 300.0, 2000.0, 2) * (0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(rpm * 0.5) / SR)) ** 4
    y = lv(eng, -3) + lv(turbo, -24) + lv(smoke, -14)
    for k, at in enumerate((0.55, 0.95, 1.3, 1.6, 1.85)):      # the slack running out down the train: bang, bang, bang
        dsp.place(y, clack(np.random.default_rng(1300 + k), 1.4) * 10 ** (-(2 + 3 * k) / 20), at)
        dsp.place(y, lv(thud(int(0.3 * SR), 85, 45, 0.08, rng), -(4 + 3 * k)), at)
    return master(y, 1.3, 1.2, 0.2, L)


# ---- things breaking -----------------------------------------------------------------------------------------------------------------------------------------------------

def crash_rubble():
    rng = np.random.default_rng(1400)
    L = 3.0
    n = int(L * SR)
    out = np.zeros(n)
    b = dsp.lp(seg(src('boom'), 0.0, 2.4), 500.0, 2)
    dsp.place(out, lv(fade(b, 0.001, 0.8), -6), 0.0)
    crack = dsp.hp(rng.standard_normal(int(0.04 * SR)), 1500.0, 2) * np.exp(-np.arange(int(0.04 * SR)) / (0.01 * SR))
    dsp.place(out, lv(crack, -4), 0.0)
    for k in range(7):      # the big pieces
        at = rng.uniform(0.0, 0.9) if k else 0.0
        dsp.place(out, lv(thud(int(0.5 * SR), rng.uniform(70, 120), rng.uniform(35, 55), rng.uniform(0.08, 0.2), rng), -rng.uniform(2, 9)), at)
    dsp.place(out, lv(debris(n, lambda s: 260 * np.exp(-s / 0.7) + 8, rng, 700, 5000), 0), 0.03)
    dust = dsp.bp(rng.standard_normal(n), 3000.0, 9000.0, 2) * np.exp(-dsp.t(n) / 0.9)
    dsp.place(out, lv(dust, -14), 0.05)
    dt = dsp.lp(seg(src('detonate'), 2.0, 5.0), 200.0, 2)
    dsp.place(out, lv(fade(dt, 0.2, 1.0), -10), 0.1)
    return master(out, 1.5, 1.3, 0.22, L)


def crash_metal():
    rng = np.random.default_rng(1500)
    L = 2.5
    n = int(L * SR)
    tt = dsp.t(n)
    out = np.zeros(n)
    sb = dsp.shift(seg(src('sphere-break'), 0.6, 2.8), -3.0)
    dsp.place(out, lv(fade(sb, 0.005, 0.6), -2), 0.0)
    tear = np.zeros(n)      # bending steel: partials sliding down, jittering
    for f0 in (420.0, 690.0, 1130.0, 1720.0, 2650.0):
        f = f0 * np.interp(tt, [0, 0.5, L], [1.0, 0.86, 0.7]) * (1 + 0.01 * wobble(n, 30, rng))
        tear += np.sin(2 * np.pi * np.cumsum(f) / SR) * np.clip(0.5 + 0.6 * wobble(n, 9, rng), 0, 1)
    dsp.place(out, lv(np.tanh(tear * 1.5) * np.interp(tt, [0, 0.05, 1.6, L], [0, 1, 0.6, 0]), -8), 0.0)
    snap = seg(src('lift-snap'), 0.0, 1.5)
    dsp.place(out, lv(fade(snap, 0.001, 0.5), -6), 0.0)
    dsp.place(out, lv(thud(int(0.8 * SR), 80, 40, 0.2, rng), -4), 0.0)
    dsp.place(out, lv(debris(n, lambda s: 120 * np.exp(-s / 0.5) + 4, rng, 1500, 7000), -12), 0.05)
    return master(out, 1.5, 1.2, 0.2, L)


MAKE = {
    'beast-roar1': lambda: roar(1), 'beast-roar2': lambda: roar(2),
    'beast-snarl1': lambda: snarl(1), 'beast-snarl2': lambda: snarl(2), 'beast-snarl3': lambda: snarl(3),
    'beast-shriek1': lambda: shriek(1), 'beast-shriek2': lambda: shriek(2),
    'beast-stomp1': lambda: stomp(1), 'beast-stomp2': lambda: stomp(2),
    'beast-hive': hive, 'beast-crt': crt,
    'train-run': train_run, 'train-screech': train_screech, 'train-horn': train_horn, 'train-bump': train_bump, 'train-brake': train_brake, 'train-start': train_start,
    'crash-rubble': crash_rubble, 'crash-metal': crash_metal,
}
LOOPS = {'beast-hive', 'beast-crt', 'train-run', 'train-screech'}

if __name__ == '__main__':
    want = [a for a in sys.argv[1:] if not a.startswith('-')] or list(MAKE)
    for name in want:
        y = MAKE[name]()
        dsp.write(name, y, -1.0, None, name in LOOPS)
        seam = ''
        if name in LOOPS:      # how big the jump is where it wraps, against a typical step inside it
            s = np.abs(y[0] - y[-1])
            seam = f"  seam step {s:.4f} (median step {np.median(np.abs(np.diff(y))):.4f})"
        print(f"{name:14s} {dsp.describe(dsp.norm(y, 10 ** (-1 / 20)))}{seam}")
