# The Sigil's voice: Fish takes (fish_fetch.mjs) through a power-electronics chain into assets/sfx/underfoint/<id>.wav. python -I tools/underfoint_audio/sigil_voice.py [--only id,id] [--measure]
# The chain, in order: tape-style pitch down (deeper and slower), the dry voice kept clear (presence lift, gentle compression), an analog octaver's square an octave under it, a 45 Hz ring modulator,
# a hard-driven 250-3000 Hz band, a mains hum and transformer buzz that only sounds while it speaks with arcs crackling in it, the wet layers crushed to 12 bit / 16 kHz, a small hard metal room.
# Calm lines are driven lightly, shouted ones hard, and inside a line the drive follows its loudness. Every line comes out at the same speech loudness with peaks at -1 dBFS.
import json
import os
import re
import sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True      # (no __pycache__ left in the project)
sys.path.insert(0, HERE)      # (run with -I: the tool's own folder only)
import dsp  # noqa: E402
CFG = json.load(open(os.path.join(HERE, 'lines.json'), encoding='utf8'))
RAW = os.path.join(dsp.SCRATCH, 'raw')
PITCH = 62.0           # Hz: where every line's median F0 is put (the takes sit at 68-83 Hz; the brief was 55-65), by a tape-style drop of 2.2-3.6 semitones that slows it as much
STYLE = {              # base drive of the saturated band, its mix, the ring mod's mix, the octaver's mix, the room's mix, speech loudness (dB)
    'calm': dict(drive=5.0, sat=0.24, ring=0.27, sub=0.3, room=0.13, level=-17.0),
    'tense': dict(drive=9.0, sat=0.32, ring=0.29, sub=0.32, room=0.14, level=-16.0),
    'shout': dict(drive=16.0, sat=0.42, ring=0.31, sub=0.34, room=0.16, level=-15.0),
}
LAYERS = set(os.environ.get('UF_VOICE_LAYERS', 'sub,ring,sat,hum,room,crush').split(','))      # (for trying the chain a layer at a time)
OUTDIR = os.environ.get('UF_VOICE_OUT') or None


def octaver(x):
    """the analog octave-down: isolate the fundamental, square it with hysteresis, flip a flip-flop on every rising edge (half the frequency), follow the voice's loudness, round it off"""
    f = dsp.bp(x, 38.0, 150.0, 2)
    e = dsp.env(f, 0.004, 0.05)
    th = 0.12 * e
    out = np.zeros(len(x))
    state = -1.0
    hi = False
    for i in range(len(x)):
        v = f[i]
        if not hi and v > th[i]:
            hi = True
            state = -state
        elif hi and v < -th[i]:
            hi = False
        out[i] = state
    voiced = np.clip((dsp.env(x, 0.01, 0.08) / (np.percentile(dsp.env(x, 0.01, 0.08), 95) + 1e-9) - 0.08) * 3.0, 0, 1)
    return dsp.lp(out * e * voiced, 230.0, 2)


def hum_bed(n, gate, rng):
    """mains hum: 50 Hz and its harmonics leaning on 100 Hz the way a transformer sings, a rectifier's buzz on top, noise grit chopped at 100 Hz, and arcs crackling now and then"""
    tt = dsp.t(n)
    h = np.zeros(n)
    for k in range(1, 41):
        a = (1.0 if k == 2 else 0.55 if k == 1 else 0.7 / k ** 0.75) * (1.35 if k % 2 == 1 and k > 2 else 1.0)
        h += a * np.sin(2 * np.pi * 50.0 * k * tt + k * 1.7)
    h /= np.abs(h).max()
    grit = dsp.bp(rng.standard_normal(n), 900.0, 4200.0, 2) * (0.5 + 0.5 * np.sin(2 * np.pi * 100.0 * tt)) ** 6
    grit /= np.abs(grit).max() + 1e-9
    bed = (h + 0.55 * grit) * gate
    arcs = np.zeros(n)
    rate = 7.0
    i = 0
    while i < n:
        i += int(rng.exponential(1.0 / rate) * dsp.SR)
        if i >= n:
            break
        if rng.random() > gate[i] * 1.3:
            continue
        L = int(rng.uniform(0.002, 0.008) * dsp.SR)
        burst = dsp.hp(rng.standard_normal(L), 2500.0, 2) * np.exp(-np.arange(L) / (L * 0.3))
        ring = dsp.resonator(np.pad(burst, (0, int(0.02 * dsp.SR))), rng.uniform(2500.0, 7000.0), 12.0)
        dsp.place(arcs, ring / (np.abs(ring).max() + 1e-9) * rng.uniform(0.4, 1.0), i / dsp.SR)
    return bed, arcs


def crush(x, rate=16000.0, bits=12):
    """sample-and-hold down to `rate`, quantise to `bits`"""
    n = np.arange(len(x))
    src = np.minimum(len(x) - 1, (np.floor(n * rate / dsp.SR) * dsp.SR / rate).astype(int))
    p = np.abs(x).max() + 1e-12
    q = 2 ** (bits - 1)
    return np.round(x[src] / p * q) / q * p


def process(x, style, seed, f0):
    rng = np.random.default_rng(seed)
    st = STYLE[style]
    x = dsp.hp(x, 45.0, 2)
    v = dsp.shift(x, float(np.clip(12.0 * np.log2(PITCH / f0), -3.6, -2.2)))
    n = len(v)
    # the dry voice: weight kept, a lift where the words are, gently levelled
    dry = dsp.peak_eq(v, 2600.0, 3.5, 0.9)
    dry = dsp.peak_eq(dry, 180.0, 2.0, 0.8)
    e = dsp.env(dry, 0.01, 0.12)
    ref = np.percentile(e[e > e.max() * 0.05], 70) + 1e-9
    dry = dry * (ref / np.maximum(e, ref)) ** 0.35        # 1.5:1-ish above the speech's usual level
    rms = np.sqrt(np.mean(dry[e > e.max() * 0.05] ** 2)) + 1e-12
    lvl = lambda y: y / (np.sqrt(np.mean(y[e > e.max() * 0.05] ** 2)) + 1e-12) * rms
    loud = np.clip(dsp.env(v, 0.01, 0.15) / (np.percentile(dsp.env(v, 0.01, 0.15), 90) + 1e-9), 0, 1.6)
    # the octaver
    sub = lvl(octaver(v)) * st['sub']
    # the ring modulator
    tt = dsp.t(n)
    ring = lvl(dry * np.sin(2 * np.pi * 45.0 * tt)) * st['ring']
    # the driven band: harder where it is louder
    band = dsp.bp(v, 250.0, 3000.0, 2)
    band = band / (np.abs(band).max() + 1e-12)
    g = st['drive'] * (0.6 + 0.6 * loud)
    sat = dsp.lp(np.tanh(band * g), 6000.0, 2)
    sat = lvl(sat) * st['sat'] * (0.75 + 0.35 * loud)
    on = lambda k, y: y if k in LAYERS else np.zeros(n)
    wet = on('ring', ring) + on('sat', sat)
    if 'crush' in LAYERS:
        wet = crush(wet, 16000.0, 12)
    # the hum it carries
    gate = np.clip(dsp.env(v, 0.015, 0.16) / (np.percentile(dsp.env(v, 0.015, 0.16), 90) + 1e-9), 0, 1.2)
    bed, arcs = hum_bed(n, gate, rng)
    bed = bed * rms * 10 ** (-24 / 20) * 3.2
    arcs = arcs * rms * 10 ** (-24 / 20) * 4.0
    mix = np.concatenate([dry + on('sub', sub) + wet + on('hum', bed + arcs), np.zeros(int(0.3 * dsp.SR))])      # (room for the room's tail)
    room = dsp.comb_room(mix)
    room = room / (np.sqrt(np.mean(room ** 2)) + 1e-12) * np.sqrt(np.mean(mix ** 2))
    full = mix + (room * st['room'] if 'room' in LAYERS else 0.0)
    global LAST_STOI
    LAST_STOI = dsp.stoi(dry, full[:n])      # (how much of the clear voice the layers leave: measured against the dry voice itself)
    out = dsp.trim(full, 0.04, 0.15, -44.0)
    out = out * 10 ** ((st['level'] - dsp.active_rms_db(out)) / 20)
    return dsp.limiter(out, -1.0), dry


LAST_STOI = 0.0


def syllables(text):
    words = re.findall(r"[a-zA-Z']+", text.lower())
    n = 0
    for w in words:
        k = len(re.findall(r'[aeiouy]+', w))
        if w.endswith('e') and k > 1 and not w.endswith('le'):
            k -= 1
        n += max(1, k)
    return n


def speech_secs(x):
    h = int(0.02 * dsp.SR)
    m = len(x) // h
    r = np.sqrt((x[: m * h].reshape(m, h) ** 2).mean(1)) + 1e-12
    return float(np.sum(20 * np.log10(r / r.max()) > -30.0)) * 0.02


def main():
    only = []
    if '--only' in sys.argv:
        only = sys.argv[sys.argv.index('--only') + 1].split(',')
    measure = '--measure' in sys.argv
    for k, l in enumerate(CFG['lines']):
        if only and l['id'] not in only:
            continue
        src = os.path.join(RAW, l['id'] + '.wav')
        if not os.path.exists(src):
            print('missing take', l['id'])
            continue
        x = dsp.read(src)
        syl = syllables(l['text'])
        f0a = dsp.f0_track(x)
        if measure:
            print(f"{l['id']:14s} raw F0 {np.median(f0a[f0a > 0]):5.1f} Hz  {syl / max(speech_secs(x), 0.1):4.2f} syl/s  {dsp.describe(x)}")
            continue
        y, dry = process(x, l['style'], 1000 + k, float(np.median(f0a[f0a > 0])))
        f0b = dsp.f0_track(dry)
        dsp.write(l['id'], y, None, OUTDIR)
        print(f"{l['id']:14s} {l['style']:5s} F0 {np.median(f0a[f0a > 0]):5.1f} -> {np.median(f0b[f0b > 0]):5.1f} Hz  rate {syl / max(speech_secs(x), 0.1):4.2f} -> {syl / max(speech_secs(y), 0.1):4.2f} syl/s  "
              f"speech {dsp.active_rms_db(y):5.1f} dB  stoi {LAST_STOI:.2f}  {dsp.describe(y)}")


if __name__ == '__main__':
    main()
