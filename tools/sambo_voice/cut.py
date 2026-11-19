# Cuts Sambo Fenrir's scene takes into one .wav per line (python -I tools/sambo_voice/cut.py <manifest.json>), called by tools/sambo_voice/build.mjs.
# A take is a whole scene voiced in one Gemini request, its lines a long pause apart. faster-whisper (the cached "small" model) times every word of it;
# the script's words are lined up with the heard ones (difflib), each line runs from its first heard word to its last, and the cut between two lines
# goes at the quietest 40 ms of the gap between them, so a laugh or a gasp before or after the words stays with its own line. Each line is then trimmed
# to 60 ms of silence either side and faded in and out over 15 ms. Prints, per line, what was heard and how many of the script's words were.
import json
import re
import sys
import difflib
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

sys.dont_write_bytecode = True


def norm(w):
    return re.sub(r"[^a-z0-9']", '', w.lower().replace('’', "'"))


def words_of(text):
    text = re.sub(r'\[[^\]]*\]', ' ', text)
    return [w for w in (norm(x) for x in re.split(r"[\s\-…]+|\.\.\.", text)) if w]


def rms(x, sr, win=0.04):
    n = max(1, int(sr * win))
    k = np.ones(n) / n
    return np.sqrt(np.convolve(x * x, k, mode='same') + 1e-12)


def main():
    man = json.load(open(sys.argv[1], encoding='utf8'))
    from faster_whisper import WhisperModel
    model = WhisperModel('small', device='cpu', compute_type='int8')
    for take in man['takes']:
        sr, x = wavfile.read(take['wav'])
        x = x.astype(np.float32) / 32768.0
        if x.ndim > 1:
            x = x.mean(axis=1)
        g = np.gcd(sr, 16000)
        y = resample_poly(x, 16000 // g, sr // g).astype(np.float32)
        segs, _ = model.transcribe(y, language='en', beam_size=5, word_timestamps=True, vad_filter=False)
        heard = []
        for s in segs:
            for w in (s.words or []):
                for part in re.split(r'[\-…]+', w.word):
                    n = norm(part)
                    if n:
                        heard.append((n, w.start, w.end))
        lines = take['lines']
        script, owner = [], []
        for i, L in enumerate(lines):
            ws = words_of(L['text'])
            script += ws
            owner += [i] * len(ws)
        sm = difflib.SequenceMatcher(None, script, [h[0] for h in heard], autojunk=False)
        hit = {}
        for a, b, size in sm.get_matching_blocks():
            for k in range(size):
                hit[a + k] = b + k
        spans = []
        for i in range(len(lines)):
            idx = [hit[j] for j in range(len(script)) if owner[j] == i and j in hit]
            n_words = sum(1 for o in owner if o == i)
            spans.append((heard[min(idx)][1], heard[max(idx)][2], len(idx), n_words) if idx else None)
        # the cuts: the quietest point between one line's last word and the next one's first
        env = rms(x, sr)
        cuts = [0.0]
        for i in range(len(lines) - 1):
            a = spans[i][1] if spans[i] else cuts[-1]
            nxt = next((spans[j] for j in range(i + 1, len(lines)) if spans[j]), None)
            b = nxt[0] if nxt else len(x) / sr
            if b <= a:
                cuts.append((a + b) * 0.5)
                continue
            ia, ib = int(a * sr), int(b * sr)
            cuts.append((ia + int(np.argmin(env[ia:ib]))) / sr)
        cuts.append(len(x) / sr)
        thr = max(0.004, float(np.percentile(env, 20)) * 3.0)
        for i, L in enumerate(lines):
            s0, s1 = int(cuts[i] * sr), int(cuts[i + 1] * sr)
            seg = x[s0:s1]
            e = env[s0:s1]
            loud = np.nonzero(e > thr)[0]
            if loud.size:
                pad = int(0.06 * sr)
                seg = seg[max(0, loud[0] - pad):min(len(seg), loud[-1] + pad)]
            f = int(0.015 * sr)
            if len(seg) > 2 * f:
                seg = seg.copy()
                seg[:f] *= np.linspace(0, 1, f)
                seg[-f:] *= np.linspace(1, 0, f)
            wavfile.write(L['out'], sr, (np.clip(seg, -1, 1) * 32767).astype(np.int16))
            sp = spans[i]
            got = ' '.join(h[0] for h in heard if sp and sp[0] - 0.01 <= h[1] <= sp[1] + 0.01)
            score = f'{sp[2]}/{sp[3]}' if sp else '0'
            print(f"{L['id']:<14} {len(seg) / sr:5.1f}s  words {score:<7} | {got}", flush=True)


main()
