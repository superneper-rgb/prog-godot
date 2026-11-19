# Shared audio helpers for tools/underfoint_audio: WAV in/out, filters, envelopes, pitch shifting, loops, loudness and measurements (numpy + scipy only).
import os
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt, resample_poly, lfilter

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(PROJECT, 'assets', 'sfx', 'underfoint')
SCRATCH = os.environ.get('UF_AUDIO_SCRATCH', 'F:/prog-godot-cache/underfoint-audio')
RNG = np.random.default_rng(7)


def read(path):
    """mono float at 44.1 kHz, whatever the file was"""
    sr, x = wavfile.read(path)
    x = x.astype(np.float64)
    if x.ndim > 1:
        x = x.mean(1)
    if np.abs(x).max() > 1.5:
        x /= 32768.0
    if sr != SR:
        g = np.gcd(sr, SR)
        x = resample_poly(x, SR // g, sr // g)
    return x


def write(name, x, peak_db=-1.0, out=None, loop=False):
    """mono 16-bit 44.1 kHz into assets/sfx/underfoint/<name>.wav with its peak at peak_db (None: as it is); loop marks it as a seamless loop"""
    x = np.asarray(x, np.float64)
    if peak_db is not None:
        x = x / (np.abs(x).max() + 1e-12) * 10 ** (peak_db / 20)
    d = out or OUT
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, name + '.wav')
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype(np.int16)
    wavfile.write(path, SR, pcm)
    if loop:
        mark_loop(path, len(pcm))
    return path


def mark_loop(path, frames):
    """a 'smpl' chunk saying the whole file loops forward: Godot's WAV import (loop mode Detect From WAV) loops it with no setting to remember"""
    import struct
    chunk = b'smpl' + struct.pack('<I', 36 + 24) + struct.pack('<9I', 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0) + struct.pack('<6I', 0, 0, 0, frames, 0, 0)
    with open(path, 'r+b') as f:
        f.seek(0, 2)
        f.write(chunk)
        size = f.tell()
        f.seek(4)
        f.write(struct.pack('<I', size - 8))


def t(n):
    return np.arange(n) / SR


def _sos(kind, f, order):
    if isinstance(f, (list, tuple)):
        return butter(order, [f[0] / (SR / 2), f[1] / (SR / 2)], kind, output='sos')
    return butter(order, f / (SR / 2), kind, output='sos')


def lp(x, f, order=2):
    return sosfilt(_sos('lowpass', f, order), x)


def hp(x, f, order=2):
    return sosfilt(_sos('highpass', f, order), x)


def bp(x, lo, hi, order=2):
    return sosfilt(_sos('bandpass', (lo, hi), order), x)


def peak_eq(x, f, gain_db, q=1.0):
    """RBJ peaking EQ"""
    a = 10 ** (gain_db / 40)
    w = 2 * np.pi * f / SR
    al = np.sin(w) / (2 * q)
    b = np.array([1 + al * a, -2 * np.cos(w), 1 - al * a])
    d = np.array([1 + al / a, -2 * np.cos(w), 1 - al / a])
    return lfilter(b / d[0], d / d[0], x)


def resonator(x, f, q):
    """a 2-pole resonance (band-pass with unity peak)"""
    w = 2 * np.pi * f / SR
    al = np.sin(w) / (2 * q)
    b = np.array([al, 0.0, -al])
    d = np.array([1 + al, -2 * np.cos(w), 1 - al])
    return lfilter(b / d[0], d / d[0], x)


def env(x, attack=0.005, release=0.08, hop=0.002):
    """amplitude envelope (RMS over hop frames, one-pole attack/release), one value per sample"""
    h = max(1, int(hop * SR))
    n = len(x) // h + 1
    pad = np.zeros(n * h)
    pad[: len(x)] = x
    r = np.sqrt((pad.reshape(n, h) ** 2).mean(1))
    ka = np.exp(-hop / attack)
    kr = np.exp(-hop / release)
    out = np.empty(n)
    s = 0.0
    for i in range(n):
        k = ka if r[i] > s else kr
        s = k * s + (1 - k) * r[i]
        out[i] = s
    return np.interp(np.arange(len(x)), np.arange(n) * h + h / 2, out)


def shift(x, semitones):
    """pitch AND time by resampling, the tape way: down is slower"""
    f = 2 ** (-semitones / 12)
    up = int(round(f * 1000))
    g = np.gcd(up, 1000)
    return resample_poly(x, up // g, 1000 // g)


def pv_stretch(x, rate, win=2048, hop=256):
    """phase vocoder: x made `rate` times longer, pitch kept"""
    w = np.hanning(win)
    frames = [np.fft.rfft(x[i:i + win] * w) for i in range(0, len(x) - win, hop)]
    if len(frames) < 2:
        return x.copy()
    F = np.array(frames)
    n_out = int((len(F) - 1) * rate)
    omega = 2 * np.pi * hop * np.arange(win // 2 + 1) / win
    phase = np.angle(F[0])
    out = np.zeros(n_out * hop + win)
    for k in range(n_out):
        p = k / rate
        i = int(p)
        fr = p - i
        mag = (1 - fr) * np.abs(F[i]) + fr * np.abs(F[i + 1])
        dphi = np.angle(F[i + 1]) - np.angle(F[i]) - omega
        dphi -= 2 * np.pi * np.round(dphi / (2 * np.pi))
        out[k * hop:k * hop + win] += np.fft.irfft(mag * np.exp(1j * phase)) * w
        phase = phase + omega + dphi
    return out / (np.sum(w ** 2) / hop)


def pitch(x, semitones):
    """pitch shift keeping the length (phase-vocoder stretch, then resample back)"""
    f = 2 ** (semitones / 12)
    y = pv_stretch(x, f)
    return fit(shift(y, semitones), len(x))


def noise(n, rng=RNG):
    return rng.standard_normal(n)


def brown(n, rng=RNG):
    y = np.cumsum(rng.standard_normal(n))
    y = hp(y, 12)
    return y / (np.abs(y).max() + 1e-9)


def adsr(n, a, d, s, r, sustain_end=None):
    """attack, decay, sustain level, release (seconds); the sustain holds until sustain_end, or until the release fits"""
    tt = t(n)
    se = sustain_end if sustain_end is not None else n / SR - r
    e = np.where(tt < a, tt / max(a, 1e-6), np.where(tt < a + d, 1 - (1 - s) * (tt - a) / max(d, 1e-6), s))
    return np.where(tt > se, e * np.clip(1 - (tt - se) / max(r, 1e-6), 0, 1), e)


def decay(n, tau, delay=0.0):
    tt = t(n) - delay
    return np.where(tt < 0, 0.0, np.exp(-np.maximum(tt, 0) / tau))


def place(buf, x, at, gain=1.0):
    """mix x into buf from `at` seconds on"""
    i = int(at * SR)
    if i >= len(buf) or i + len(x) <= 0:
        return buf
    a = max(i, 0)
    j = min(len(buf), i + len(x))
    buf[a:j] += gain * x[a - i:j - i]
    return buf


def fit(x, n):
    y = np.zeros(n)
    y[: min(n, len(x))] = x[:n]
    return y


def norm(x, peak=1.0):
    return x / (np.abs(x).max() + 1e-12) * peak


def softclip(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive)


def knee(x, c, k=0.8):
    """unity below k*c, bent smoothly into a hard stop at c"""
    a = np.abs(x)
    kk = k * c
    bent = kk + (c - kk) * np.tanh((a - kk) / (c - kk))
    return np.sign(x) * np.where(a < kk, a, bent)


def limiter(x, ceiling_db=-1.0, release=0.06):
    """rides the gain down under the ceiling (fast attack, slow release), then a knee for what slips through: never above the ceiling, unity below it"""
    c = 10 ** (ceiling_db / 20)
    e = env(np.abs(x), attack=0.0006, release=release, hop=0.0005) * 1.3
    g = np.minimum(1.0, c / np.maximum(e, 1e-9))
    g = np.minimum(g, np.convolve(g, np.ones(30) / 30, mode='same'))
    return knee(x * g, c)


def loop_seam(x, xf=0.5):
    """make x loop clean: its last xf seconds are crossfaded (equal power) over its start, and it is that much shorter"""
    n = int(xf * SR)
    ph = np.linspace(0, np.pi / 2, n)
    y = x[:-n].copy()
    y[:n] = x[:n] * np.sin(ph) + x[-n:] * np.cos(ph)
    return y


def comb_room(x, delays=(0.0233, 0.0297, 0.0319, 0.0371), fb=(0.72, 0.70, 0.68, 0.66), damp=4500.0, ap=((0.005, 0.7), (0.0017, 0.7))):
    """a small hard room (Schroeder): parallel damped combs, then two allpasses"""
    y = np.zeros(len(x))
    for d, g in zip(delays, fb):
        D = int(d * SR)
        a = np.zeros(D + 1)
        a[0] = 1.0
        a[D] = -g
        y += lp(lfilter([1.0], a, x), damp, 1)
    y /= len(delays)
    for d, g in ap:
        D = int(d * SR)
        b = np.zeros(D + 1)
        b[0] = -g
        b[D] = 1.0
        a = np.zeros(D + 1)
        a[0] = 1.0
        a[D] = -g
        y = lfilter(b, a, y)
    return y


def hall_ir(n_sec=2.5, rt=1.8, bright=6000.0, rng=RNG):
    """an impulse response: decaying noise, for big spaces"""
    n = int(n_sec * SR)
    ir = rng.standard_normal(n) * np.exp(-t(n) * 6.9 / rt)
    ir = lp(ir, bright, 1)
    k = int(0.012 * SR)
    ir[:k] *= np.linspace(0, 1, k)
    return ir / np.sqrt(np.sum(ir ** 2))


def convolve(x, ir):
    n = len(x) + len(ir) - 1
    N = 1 << int(np.ceil(np.log2(n)))
    return np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(ir, N), N)[:n]


def trim(x, lead=0.04, tail=0.15, floor_db=-42.0, fade=0.03):
    """cut to `lead` s before the first and `tail` s after the last 5 ms frame above floor_db (relative to the loudest frame)"""
    h = int(0.005 * SR)
    n = len(x) // h
    if n < 2:
        return x
    r = np.sqrt((x[: n * h].reshape(n, h) ** 2).mean(1)) + 1e-12
    on = np.where(20 * np.log10(r / r.max()) > floor_db)[0]
    if len(on) == 0:
        return x
    a = max(0, on[0] * h - int(lead * SR))
    b = min(len(x), (on[-1] + 1) * h + int(tail * SR))
    y = x[a:b].copy()
    f = int(fade * SR)
    k = int(0.004 * SR)
    if f > 0 and len(y) > 2 * f:
        y[-f:] *= np.linspace(1, 0, f) ** 2
    if len(y) > 2 * k:
        y[:k] *= np.linspace(0, 1, k)
    return y


def active_rms_db(x, floor_db=-30.0):
    """RMS over the 20 ms frames within floor_db of the loudest: speech loudness without the gaps"""
    h = int(0.02 * SR)
    n = len(x) // h
    if n == 0:
        return -120.0
    r = np.sqrt((x[: n * h].reshape(n, h) ** 2).mean(1)) + 1e-12
    db = 20 * np.log10(r)
    keep = db > db.max() + floor_db
    return 10 * np.log10(np.mean(r[keep] ** 2))


def f0_track(x, fmin=40.0, fmax=320.0, hop=0.01, win=0.05, thr=0.45):
    """per-frame F0 (0 = unvoiced) by normalised autocorrelation"""
    w = int(win * SR)
    h = int(hop * SR)
    lo, hi = int(SR / fmax), int(SR / fmin)
    starts = list(range(0, len(x) - w, h))
    rr = np.array([np.sqrt(np.mean(x[i:i + w] ** 2)) for i in starts])
    if len(rr) == 0:
        return np.zeros(0)
    gate = rr.max() * 0.06
    f0 = np.zeros(len(rr))
    nfft = 1 << int(np.ceil(np.log2(2 * w)))
    for k, i in enumerate(starts):
        if rr[k] < gate:
            continue
        f = x[i:i + w] - x[i:i + w].mean()
        F = np.fft.rfft(f, nfft)
        ac = np.fft.irfft(F * np.conj(F), nfft)[: hi + 2]
        if ac[0] <= 0:
            continue
        ac = ac / ac[0]
        j = lo + int(np.argmax(ac[lo:hi]))
        if ac[j] > thr:
            f0[k] = SR / j
    return f0


def stoi(ref, deg, fs=SR):
    """short-time objective intelligibility (Taal et al. 2011) of `deg` against the clean `ref` on the same timeline: ~1 = every word as clear as the reference, under ~0.6 words go"""
    g = np.gcd(int(fs), 10000)
    x = resample_poly(ref, 10000 // g, int(fs) // g)
    y = resample_poly(deg[: len(ref)], 10000 // g, int(fs) // g)
    N, K, J, beta = 30, 512, 15, -15.0
    w = np.hanning(258)[1:-1]
    frames = range(0, len(x) - 256, 128)
    X = np.array([x[i:i + 256] * w for i in frames])
    Y = np.array([y[i:i + 256] * w for i in frames])
    e = 20 * np.log10(np.linalg.norm(X, axis=1) + 1e-12)
    keep = e > e.max() - 40
    X, Y = X[keep], Y[keep]
    if len(X) <= N:
        return float('nan')
    fx = np.abs(np.fft.rfft(X, K)) ** 2
    fy = np.abs(np.fft.rfft(Y, K)) ** 2
    f = np.fft.rfftfreq(K, 1 / 10000)
    cf = 150 * 2 ** (np.arange(J) / 3)
    lo, hi = cf * 2 ** (-1 / 6), cf * 2 ** (1 / 6)
    bx = np.array([np.sqrt(fx[:, (f >= a) & (f < b)].sum(1)) for a, b in zip(lo, hi)])
    by = np.array([np.sqrt(fy[:, (f >= a) & (f < b)].sum(1)) for a, b in zip(lo, hi)])
    c = 10 ** (-beta / 20)
    ds = []
    for m in range(N, bx.shape[1] + 1):
        xs = bx[:, m - N:m]
        ys = by[:, m - N:m]
        a = np.linalg.norm(xs, axis=1, keepdims=True) / (np.linalg.norm(ys, axis=1, keepdims=True) + 1e-12)
        yp = np.minimum(ys * a, xs * (1 + c))
        xm = xs - xs.mean(1, keepdims=True)
        ym = yp - yp.mean(1, keepdims=True)
        ds.append(np.mean((xm * ym).sum(1) / (np.linalg.norm(xm, axis=1) * np.linalg.norm(ym, axis=1) + 1e-12)))
    return float(np.mean(ds))


def describe(x):
    pk = 20 * np.log10(np.abs(x).max() + 1e-12)
    rms = 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)
    return f"{len(x) / SR:5.2f}s  peak {pk:5.1f} dBFS  rms {rms:6.1f} dBFS"
