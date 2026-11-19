# Rough intelligibility check of the Sigil's lines: Windows dictation on the raw takes and on the finished files, word recall against lines.json. python -I tools/underfoint_audio/stt_check.py
import json
import os
import re
import subprocess
import sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True      # (no __pycache__ left in the project)
sys.path.insert(0, HERE)
import dsp  # noqa: E402

CFG = json.load(open(os.path.join(HERE, 'lines.json'), encoding='utf8'))


def copies(src_dir, tag):
    d = os.path.join(dsp.SCRATCH, 'stt', tag)
    os.makedirs(d, exist_ok=True)
    for l in CFG['lines']:
        p = os.path.join(src_dir, l['id'] + '.wav')
        if not os.path.exists(p):
            continue
        x = dsp.read(p)
        y = resample_poly(x, 160, 441)
        y = y / (np.abs(y).max() + 1e-9) * 0.7
        lead = np.zeros(8000)      # (a little silence first: the recogniser needs it)
        wavfile.write(os.path.join(d, l['id'] + '.wav'), 16000, (np.concatenate([lead, y, lead]) * 32767).astype(np.int16))
    return d


def heard(d):
    r = subprocess.run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', os.path.join(HERE, 'stt_check.ps1'), d], capture_output=True, text=True, timeout=900)
    out = {}
    for line in r.stdout.splitlines():
        if '\t' in line:
            k, v = line.split('\t', 1)
            out[k.strip()] = v.strip()
    return out


def words(s):
    return re.findall(r"[a-z']+", s.lower().replace("sern's", 'sern'))


def recall(ref, hyp):
    h = words(hyp)
    r = words(ref)
    got = 0
    for w in r:
        if w in h:
            got += 1
            h.remove(w)
    return got / max(1, len(r))


sets = sys.argv[1:] or [dsp.OUT]      # folders to score (default: the finished files), each against the raw takes
quiet = '--quiet' in sets
sets = [s for s in sets if s != '--quiet']
raw = heard(copies(os.path.join(dsp.SCRATCH, 'raw'), 'raw'))
res = [heard(copies(s, 'set%d' % i)) for i, s in enumerate(sets)]
n = len(CFG['lines'])
tot = [0.0] * (len(sets) + 1)
for l in CFG['lines']:
    a = recall(l['text'], raw.get(l['id'], ''))
    tot[0] += a
    row = f"{l['id']:14s} raw {a:4.0%}"
    for i, r in enumerate(res):
        b = recall(l['text'], r.get(l['id'], ''))
        tot[i + 1] += b
        row += f"  {os.path.basename(sets[i].rstrip('/'))[:8]} {b:4.0%}"
    if not quiet:
        print(row + (f"   | {res[-1].get(l['id'], '')}" if res else ''))
print('mean word recall: raw %.0f%%  ' % (100 * tot[0] / n) + '  '.join('%s %.0f%%' % (os.path.basename(s.rstrip('/')), 100 * tot[i + 1] / n) for i, s in enumerate(sets)))
