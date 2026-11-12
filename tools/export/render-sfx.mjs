// Renders every synthesised sound of the three.js game (class Sfx, enemies/robot-sounds.js, enemies/creature-audio.js, the prepared voice clips, the loops) to real WAV files, because Godot has no such synth.
//   node tools/export/render-sfx.mjs            everything: assets/sfx/synth/<key>_<take>.wav, audio/sfx_bank.gd, the 9 .m4a decoded to .wav next to themselves
//   node tools/export/render-sfx.mjs --only=re  only the keys matching the regular expression (the bank keeps the other entries)
// It boots the JS game headless (tests/lib/level-harness.cjs), points sfx.ctx / sfx.master / sfx.verb at an OfflineAudioContext with 4 channels (dry L R, reverb send L R) and calls the real s_<id>.
// DRY ONLY: the convolver tail is not in the files. The send stem is measured and stored per sound, audio/sfx.gd plays the same file into the Reverb bus at that level.
// TAKES: 1 when the sound is deterministic, 3 when only noise phases differ, 4 when the JS rolls dice in the sound itself (_j(), Math.random()). `_j()` is stratified over the takes so they really differ.
// Each file is peak-normalised to 0.97; the factor back to the JS level goes in the bank (`g`), so quiet sounds keep their resolution and loud ones (gain 2.6 explosions) do not clip.
// Add a level's own inline sfx.tone() / sfx.noise() sounds to EXTRA in the page code below when that level is ported.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const PROJECT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const JS = (await import('../js_root.mjs')).JS_ROOT;
const OUT = path.join(PROJECT, 'assets/sfx/synth');
const BANK = path.join(PROJECT, 'audio/sfx_bank.gd');
const LOG = path.join(process.env.RENDER_LOG_DIR || 'F:/prog-godot-cache/tmp/fx', 'render-sfx.json');
const only = (process.argv.find((a) => a.startsWith('--only=')) || '').slice(7);
const PEAK_TARGET = 0.97;

const require = createRequire(path.join(JS, 'tests/render-sfx.cjs'));
const { boot } = require('./lib/level-harness.cjs');

// ---------------------------------------------------------------- Node side: analysis, resampling, WAV ----------------------------------------------------------------
function fft(re, im) {                                                  // in-place radix-2
  const n = re.length;
  for (let i = 1, j = 0; i < n; i++) { let b = n >> 1; for (; j & b; b >>= 1) j ^= b; j ^= b; if (i < j) { [re[i], re[j]] = [re[j], re[i]]; [im[i], im[j]] = [im[j], im[i]]; } }
  for (let len = 2; len <= n; len <<= 1) {
    const ang = -2 * Math.PI / len, wr = Math.cos(ang), wi = Math.sin(ang);
    for (let i = 0; i < n; i += len) {
      let cr = 1, ci = 0;
      for (let j = 0; j < len / 2; j++) {
        const k = i + j, l = k + len / 2, xr = re[l] * cr - im[l] * ci, xi = re[l] * ci + im[l] * cr;
        re[l] = re[k] - xr; im[l] = im[k] - xi; re[k] += xr; im[k] += xi;
        const t = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = t;
      }
    }
  }
}
/** share of the signal's power above `hz` (0..1), from Hann windowed 2048 point frames */
function powerAbove(x, sr, hz) {
  const N = 2048, hop = N >> 1, re = new Float64Array(N), im = new Float64Array(N); let all = 1e-30, hi = 0;
  const bin = Math.floor(hz * N / sr);
  for (let s = 0; s < Math.max(1, x.length - N + 1); s += hop) {
    for (let i = 0; i < N; i++) { const w = 0.5 - 0.5 * Math.cos(2 * Math.PI * i / (N - 1)); re[i] = (x[s + i] || 0) * w; im[i] = 0; }
    fft(re, im);
    for (let k = 1; k < N / 2; k++) { const p = re[k] * re[k] + im[k] * im[k]; all += p; if (k >= bin) hi += p; }
  }
  return hi / all;
}
/** windowed sinc resampler (the browser's AudioBufferSourceNode only interpolates linearly, so resampling happens here) */
function resample(x, from, to) {
  if (from === to) return x;
  const ratio = to / from, cut = Math.min(1, ratio) * 0.97, half = 24, n = Math.ceil(x.length * ratio), y = new Float32Array(n), reach = half / Math.min(1, cut);
  for (let i = 0; i < n; i++) {
    const c = i / ratio, a = Math.max(0, Math.ceil(c - reach)), b = Math.min(x.length - 1, Math.floor(c + reach)); let s = 0;
    for (let j = a; j <= b; j++) {
      const d = j - c, u = d * cut, sinc = Math.abs(u) < 1e-6 ? 1 : Math.sin(Math.PI * u) / (Math.PI * u), v = d / reach, w = 0.42 + 0.5 * Math.cos(Math.PI * v) + 0.08 * Math.cos(2 * Math.PI * v);
      s += x[j] * sinc * w;
    }
    y[i] = s * cut;
  }
  return y;
}
function wav(channels, sr, loop) {
  const n = channels[0].length, ch = channels.length, data = n * ch * 2, smpl = loop ? 8 + 36 + 24 : 0, b = Buffer.alloc(44 + data + smpl);
  b.write('RIFF', 0); b.writeUInt32LE(36 + data + smpl, 4); b.write('WAVEfmt ', 8); b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(ch, 22); b.writeUInt32LE(sr, 24);
  b.writeUInt32LE(sr * ch * 2, 28); b.writeUInt16LE(ch * 2, 32); b.writeUInt16LE(16, 34); b.write('data', 36); b.writeUInt32LE(data, 40);
  let o = 44;
  for (let i = 0; i < n; i++) for (let c = 0; c < ch; c++) { b.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(channels[c][i] * 32767))), o); o += 2; }
  if (loop) {                                                           // the smpl chunk: Godot's importer reads loop points from it
    b.write('smpl', o); b.writeUInt32LE(36 + 24, o + 4); b.writeUInt32LE(0, o + 8); b.writeUInt32LE(0, o + 12); b.writeUInt32LE(Math.round(1e9 / sr), o + 16); b.writeUInt32LE(60, o + 20); b.writeUInt32LE(0, o + 24);
    b.writeUInt32LE(0, o + 28); b.writeUInt32LE(0, o + 32); b.writeUInt32LE(1, o + 36); b.writeUInt32LE(0, o + 40);
    b.writeUInt32LE(0, o + 44); b.writeUInt32LE(0, o + 48); b.writeUInt32LE(0, o + 52); b.writeUInt32LE(n - 1, o + 56); b.writeUInt32LE(0, o + 60); b.writeUInt32LE(0, o + 64);
  }
  return b;
}
const peakOf = (a) => { let p = 0; for (let i = 0; i < a.length; i++) { const v = Math.abs(a[i]); if (v > p) p = v; } return p; };
const rmsOf = (a) => { let s = 0; for (let i = 0; i < a.length; i++) s += a[i] * a[i]; return Math.sqrt(s / Math.max(1, a.length)); };

const bank = {}, log = {}; let totalBytes = 0, files = 0;
if (only && fs.existsSync(BANK)) { for (const m of fs.readFileSync(BANK, 'utf8').matchAll(/^\t"([^"]+)": (\{.*\}),$/gm)) bank[m[1]] = JSON.parse(m[2]); }   // a partial run keeps the rest of the bank

function onRender(meta, bytes) {
  const f = new Float32Array(bytes.buffer, bytes.byteOffset, bytes.length / 4), nc = meta.nc, frames = f.length / nc;
  const chan = Array.from({ length: nc }, (_, c) => { const a = new Float32Array(frames); for (let i = 0; i < frames; i++) a[i] = f[i * nc + c]; return a; });
  let L = chan[0], R = nc > 1 ? chan[1] : chan[0]; const sL = nc > 2 ? chan[2] : null, sR = nc > 3 ? chan[3] : null;
  const pk = Math.max(peakOf(L), peakOf(R));
  const e = meta.path ? {} : (bank[meta.key] || (bank[meta.key] = {}));
  if (pk < 1e-6) { if (meta.mustSound) console.log('SILENT ' + meta.key); log[meta.key] = { silent: true }; delete bank[meta.key]; return; }
  // stereo only when the channels really differ
  let diff = 0; for (let i = 0; i < frames; i++) diff = Math.max(diff, Math.abs(L[i] - R[i]));
  const stereo = diff > 2e-4;
  // cut the silent end (loops keep their exact length)
  let end = frames;
  if (!meta.loop) { const th = Math.max(2e-5, pk * 2e-4); while (end > 1 && Math.abs(L[end - 1]) < th && Math.abs(R[end - 1]) < th) end--; end = Math.min(frames, end + Math.round(meta.sr * 0.004)); }
  L = L.subarray(0, end); R = R.subarray(0, end);
  let send = 0;
  if (sL) { const a = sL.subarray(0, end), b = sR.subarray(0, end), dry = Math.hypot(rmsOf(L), rmsOf(R)), wet = Math.hypot(rmsOf(a), rmsOf(b)); send = dry > 1e-9 ? wet / dry : 0; }
  // sample rate: 22 kHz when almost nothing lives above 10 kHz, 32 kHz otherwise, the source rate for loops and anything that asks for it
  const hi = powerAbove(stereo ? L.map((v, i) => (v + R[i]) * 0.5) : L, meta.sr, 10000);
  let rate = meta.keepRate ? meta.sr : hi < 1e-4 ? 22050 : 32000;
  if (rate > meta.sr) rate = meta.sr;
  let oL = resample(L, meta.sr, rate), oR = stereo ? resample(R, meta.sr, rate) : null;
  const opk = Math.max(peakOf(oL), oR ? peakOf(oR) : 0), scale = meta.noNormalise ? 1 : PEAK_TARGET / opk;
  const n = oL.length, fadeOut = meta.loop ? 0 : Math.min(n >> 1, Math.round(rate * 0.003));
  const shaped = (x) => { const y = new Float32Array(n); for (let i = 0; i < n; i++) y[i] = x[i] * scale * (fadeOut && i >= n - fadeOut ? (n - i) / fadeOut : 1); return y; };
  const buf = wav(oR ? [shaped(oL), shaped(oR)] : [shaped(oL)], rate, meta.loop);
  const name = meta.path ? path.join(PROJECT, meta.path) : path.join(OUT, `${meta.key}_${meta.take}.wav`);
  fs.mkdirSync(path.dirname(name), { recursive: true }); fs.writeFileSync(name, buf); totalBytes += buf.length; files++;
  if (meta.path) { log[meta.path] = { peak: +opk.toFixed(4), len: +(n / rate).toFixed(3), sr: rate, ch: oR ? 2 : 1 }; return; }
  // the bank keeps the mean of the takes
  const g = meta.noNormalise ? 1 : 1 / scale;
  e.n = Math.max(e.n || 0, meta.take + 1); e.g = +(Math.max(e.g || 0, g)).toPrecision(5);
  // takes share one gain: each file was normalised on its own, so the per-take factor is needed too. `gs` holds them.
  (e.gs = e.gs || [])[meta.take] = +g.toPrecision(5);
  e.s = +(((e.s || 0) * meta.take + send) / (meta.take + 1)).toPrecision(4);
  e.len = +(n / rate).toFixed(3); if (meta.j) e.j = 1; if (meta.loop) { e.loop = 1; e.frames = n; e.base = meta.base || 0; }
  log[meta.key + '#' + meta.take] = { peak: +opk.toFixed(4), len: e.len, sr: rate, ch: oR ? 2 : 1, send: +send.toFixed(3), hi: +hi.toExponential(1), tail: meta.tail };
}

function writeBank() {
  const keys = Object.keys(bank).sort();
  const lines = keys.map((k) => { const e = bank[k]; delete e.g; return `\t"${k}": ${JSON.stringify(e)},`; });
  const body = `## Generated by tools/export/render-sfx.mjs: every rendered sound. n takes, gs per-take gain back to the JS level, s reverb send, len seconds, j the JS rolled _j() (small pitch jitter), loop / frames / base for loops.
class_name SfxBank
extends RefCounted

const BANK := {
${lines.join('\n')}
}
`;
  fs.mkdirSync(path.dirname(BANK), { recursive: true }); fs.writeFileSync(BANK, body);
}

// ---------------------------------------------------------------- page side ----------------------------------------------------------------
const PAGE = async (opt) => {
  const G = window.__game, game = G.sfx, sink = window.__rsSink, say = window.__rsLog, onlyRe = opt.only ? new RegExp(opt.only) : null;
  document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Shift', bubbles: true }));          // warmPlayerAudio: decodes and prepares every recorded clip into sfx.voiceBuf
  game.init();
  if (window.__pauseSfxLoad) await window.__pauseSfxLoad;
  if (window.__cherubLoad) await window.__cherubLoad();
  const live = game.ctx, sr = live.sampleRate;
  // a second Sfx: the game's own loop keeps running on its live one (the hub's ambience connects new nodes to sfx.ctx every frame), this one only ever sees offline contexts
  const S = new game.constructor();
  S.voiceBuf = game.voiceBuf; S.swarmParts = game.swarmParts;
  for (const k of Object.keys(game)) if (/^s_/.test(k)) S[k] = game[k];
  await say(`audio context ${sr} Hz, ${Object.keys(S.voiceBuf || {}).length} clips decoded`);
  const CA = await import('/enemies/creature-audio.js'), CG = await import('/enemies/creature-gameplay.js'), RS = await import('/enemies/robot-sounds.js');
  const CONFIG = G.CONFIG || (G.config) || null, AI = G.AI || null;
  const noise = (() => { const n = sr * 2, b = new AudioBuffer({ length: n, sampleRate: sr, numberOfChannels: 1 }), d = b.getChannelData(0); for (let i = 0; i < n; i++) d[i] = Math.random() * 2 - 1; return b; })();

  function graph(sec, nc = 4) {
    const c = new OfflineAudioContext(nc, Math.ceil(sr * sec), sr); c.resume = () => Promise.resolve();
    const stem = () => { const g = c.createGain(); g.channelCount = 2; g.channelCountMode = 'explicit'; g.channelInterpretation = 'speakers'; return g; };
    const master = stem(), verb = stem(), merge = c.createChannelMerger(nc), a = c.createChannelSplitter(2), b = c.createChannelSplitter(2);
    master.connect(a); a.connect(merge, 0, 0); a.connect(merge, 1, 1); verb.connect(b); b.connect(merge, 0, 2); b.connect(merge, 1, 3); merge.connect(c.destination);
    return { c, master, verb };
  }
  const realRandom = Math.random, realJ = S._j; let rolls = 0, jRolls = 0, noiseCalls = 0;
  const realNoise = S.noise;
  const J = [1, 0.975, 1.025, 0.99];
  /** one render of fn(ctx): returns the AudioBuffer. fn runs synchronously inside the counters. Doubles the length until the tail is silent. */
  async function render(fn, take, hint) {
    for (let len = hint; ; len *= 2) {
      const g = graph(len);
      Object.assign(S, { ctx: g.c, master: g.master, verb: g.verb, wet: g.master, comp: g.master, noiseBuf: noise, _bus: null, _busK: 1, _uiNavAt: -1e9, _pauseToneAt: -1e9, _sw: null, _organ: null, organSync: true, _weaponMixTrim: 1 });
      rolls = jRolls = noiseCalls = 0;
      Math.random = () => { rolls++; return realRandom(); };
      S._j = () => { jRolls++; return J[take % J.length]; };
      S.noise = function (...a) { noiseCalls++; return realNoise.apply(this, a); };
      try { fn(g.c); } finally { Math.random = realRandom; S._j = realJ; S.noise = realNoise; }
      const counts = { rolls, jRolls, noiseCalls };
      const buf = await g.c.startRendering();
      const tail = Math.round(sr * 0.03); let t = 0;
      for (let ch = 0; ch < 2; ch++) { const d = buf.getChannelData(ch); for (let i = d.length - tail; i < d.length; i++) t = Math.max(t, Math.abs(d[i])); }
      if (t < 2e-5 || len >= 40) return { buf, counts, tail: t };
    }
  }
  function b64(float32) {
    const u = new Uint8Array(float32.buffer, float32.byteOffset, float32.byteLength); let s = '';
    for (let i = 0; i < u.length; i += 0x8000) s += String.fromCharCode.apply(null, u.subarray(i, i + 0x8000));
    return btoa(s);
  }
  async function ship(meta, channels) {
    const n = channels[0].length, nc = channels.length, f = new Float32Array(n * nc);
    for (let c = 0; c < nc; c++) { const d = channels[c]; for (let i = 0; i < n; i++) f[i * nc + c] = d[i]; }
    await sink(JSON.stringify({ ...meta, nc, sr }), b64(f));
  }
  let done = 0, keys = 0;
  /** render one key (all its takes). r: { key, run(ctx, take), hint, takes (force), mustSound, keepRate } */
  async function bakeKey(r) {
    if (onlyRe && !onlyRe.test(r.key)) return;
    keys++;
    let takes = r.takes || 0, hasJ = false;
    for (let take = 0; take < (takes || 1); take++) {
      const { buf, counts, tail } = await render((c) => r.run(c, take), take, r.hint || 1.2);
      if (!r.takes && take === 0) { takes = counts.rolls === 0 && counts.noiseCalls === 0 && counts.jRolls === 0 ? 1 : (counts.jRolls > 0 || counts.rolls > counts.noiseCalls) ? 4 : 3; }
      hasJ = counts.jRolls > 0;
      await ship({ key: r.key, take, j: hasJ && !r.noJitter, mustSound: r.mustSound !== false, keepRate: !!r.keepRate, tail: +tail.toExponential(1) }, [buf.getChannelData(0), buf.getChannelData(1), buf.getChannelData(2), buf.getChannelData(3)]);
      done++;
    }
    if (keys % 40 === 0) await say(`${keys} keys, ${done} renders`);
  }
  const play = (id, o) => (c) => S.play(id, o);

  // ---- the s_* methods: every one, with the parameter values the game really uses ----
  const VARIANTS = {
    brass: [['', {}], ['big', { big: true }]],
    empty: [['', {}], ['deagle', { id: 'deagle' }], ['smg', { id: 'smg' }], ['sniper', { id: 'sniper' }], ['rocket', { id: 'rocket' }]],
    whoosh: [['', { stage: 1 }], ['3', { stage: 3 }]],
    punchHit: [['', { stage: 1 }], ['3', { stage: 3 }]],
    splash: [0.15, 0.3, 0.5, 0.75, 1].map((k) => [String(k), { k }]),
    stroke: [['', { k: 1 }]], rung: [['', { k: 1 }]], land: [['', { k: 0.6 }]],       // k only scales every partial: audio/sfx.gd scales the gain (land: 0.4 + 0.6 = 1)
    slap: [['', { k: 1 }]], skitter: [['', { k: 1 }]], step: [['', { k: 1 }]], playerHurt: [['', { k: 1 }]], bellowsHit: [['', { k: 1 }]],
    equip: [0.1, 0.2, 0.3, 0.4, 0.5, 0.7, 0.8, 0.9, 1].map((h) => [String(h), { heavy: h }]),
    sawPing: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].map((n) => [String(n), { n }]),
    yokeImpact: [0.6, 1, 1.3, 1.6].map((k) => [String(k), { k }]),
    flailSlam: [['', { k: 1 }], ['0.8', { k: 0.8 }]],
    explode: [['', { dist: 0 }]],
    clang: [['', {}], ['heavy', { heavy: true }]], alienHit: [['', {}], ['heavy', { heavy: true }]], humanHit: [['', {}], ['heavy', { heavy: true }]], meatHit: [['', {}], ['heavy', { heavy: true }]],
    meatDie: [['', {}], ['small', { small: true }]], wormGrow: [['', {}], ['quiet', { quiet: true }]], tongueLash: [['', {}], ['hit', { hit: true }]],
    shieldHit: [['', {}], ['hi', { hi: true }]], shieldBreak: [['', {}], ['hi', { hi: true }]], shieldUp: [['', {}], ['hi', { hi: true }]],
    boltHit: [['', { kind: 'wall' }], ['player', { kind: 'player' }], ['plasma', { bk: 'plasma', kind: 'wall' }], ['plasma.player', { bk: 'plasma', kind: 'player' }], ['mind', { bk: 'mind' }], ['dart', { bk: 'dart' }], ['ring', { bk: 'ring' }], ['sauce', { bk: 'sauce', kind: 'wall' }], ['sauce.player', { bk: 'sauce', kind: 'player' }]],
    vehPop: [0, 0.25, 0.5, 0.75, 1].map((k) => [String(k), { k }]),
    vehCrash: [0.25, 0.5, 0.75, 1].map((k) => [String(k), { k }]),
  };
  const weaponsTable = window.__rsWeapons || [];
  // sounds that take a duration from CONFIG / AI: the values the frame passes (index.html handle(), robotAtk)
  const cfg = (k, d) => { const v = CONFIG && CONFIG[k]; return v === undefined ? d : v; };
  const DUR = {
    mindWind: cfg('alienMindWind', 0.85), tongueWind: cfg('screamWhipWind', 0.45), dartWind: cfg('screamDartWind', 0.5), screamWind: cfg('screamCallWind', 1), ringerWind: cfg('wormRingWind', 0.6),
    slamWind: cfg('wormSlamWind', 0.75), sauceWind: cfg('prophetBlastWind', 0.5), summonWind: cfg('prophetSummonWind', 1),
  };
  await say('durations ' + JSON.stringify(DUR));
  for (const [id, d] of Object.entries(DUR)) VARIANTS[id] = [['', { dur: d }]];
  const aiW = opt.ai || { mWind: 0.66, sWind: 0.9 };
  VARIANTS.wind = [['melee', { kind: 'melee', dur: aiW.mWind }], ['shot', { kind: 'shot', dur: aiW.sWind }]];
  const SPECIAL = new Set(['rl', 'alienSyl', 'dogSyl', 'punchAir', 'creature']);
  // vehicles/damage.js adds its two sounds when a car is first made: same bodies, so the render does not depend on the level having a car (copied, statement for statement)
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  if (!S.s_vehPop) {
    S.s_vehPop = function (t, o) { const k = o.k || 0; this.noise(t, 0.07 + Math.random() * 0.05, { type: 'bandpass', f0: 700 + Math.random() * 900, q: 1.5, gain: 0.35 + 0.4 * k, wet: 0.3 }); if (Math.random() < 0.3 + k * 0.5) this.tone(t, 0.12, 160, 50, { gain: 0.3 + 0.4 * k, wet: 0.3 }); this.noise(t, 0.3 + k * 0.4, { type: 'highpass', f0: 3000, gain: 0.05 + 0.08 * k, wet: 0.2 }); };
    S.s_vehCrash = function (t, o) { const k = clamp(o.k || 0.5, 0, 1); this.tone(t, 0.35 + 0.3 * k, 110, 32, { gain: 0.8 + k, wet: 0.25 }); this.noise(t, 0.25 + 0.3 * k, { type: 'lowpass', f0: 2600, f1: 220, gain: 0.7 + 0.6 * k, wet: 0.25 }); for (let i = 0; i < 3 + (k * 6 | 0); i++) this.noise(t + Math.random() * 0.22, 0.05 + Math.random() * 0.06, { type: 'bandpass', f0: 1400 + Math.random() * 2600, q: 3, gain: 0.25 + 0.35 * k, wet: 0.2 }); if (k > 0.55) for (let i = 0; i < 5; i++) this.tone(t + 0.04 + Math.random() * 0.3, 0.12, 3800 + Math.random() * 2400, 2600, { type: 'triangle', gain: 0.04 + 0.05 * k, wet: 0.3 }); };
  }
  const proto = Object.getPrototypeOf(S), ids = [...new Set([...Object.getOwnPropertyNames(proto), ...Object.keys(S)])].filter((n) => /^s_/.test(n)).map((n) => n.slice(2)).sort();
  await say(`${ids.length} s_* methods: ${ids.join(' ')}`);
  // play() sends the UI ids to menuSound; their s_ bodies are dead code in the JS, so they are rendered by calling the s_ method itself (same proof count), under <id>.raw, and never played
  const UI_IDS = new Set(['wheelOpen', 'wheelClose', 'tick', 'vendOpen', 'vendClose', 'vendNav', 'vendBuy', 'vendDeny', 'vendInfo', 'uiMove', 'uiConfirm', 'uiBack']);
  for (const id of ids) {
    if (SPECIAL.has(id)) continue;
    const vars = VARIANTS[id] || [['', {}]];
    for (const [tag, o] of vars) {
      const key = tag ? `${id}.${tag}` : id;
      if (UI_IDS.has(id)) await bakeKey({ key: id + '.raw', run: (c) => S['s_' + id](c.currentTime + 0.001, o) });
      else await bakeKey({ key, run: play(id, o), hint: 2 });
    }
  }
  // ---- reloads: (id, phase) as Combat._reloadStep emits them ----
  const RL_MAG = ['grab', 'pull', 'pouch', 'fetch', 'insert', 'rack', 'chamber'], RL_SHELL = ['open', 'shell', 'pump', 'chamber'];
  const rlDur = opt.rlDur;
  for (const id of ['deagle', 'smg', 'sniper', 'rocket']) for (const ph of RL_MAG) await bakeKey({ key: `rl.${id}.${ph}`, run: play('rl', { id, ph, kind: 'mag', dur: rlDur[id], emp: true }), mustSound: false, hint: 2.5 });
  for (const ph of RL_MAG) { if (ph !== 'chamber') await bakeKey({ key: `rl.rifle.${ph}`, run: play('rl', { id: 'rifle', ph, kind: 'mag', dur: rlDur.rifle, emp: true }), mustSound: false }); }
  await bakeKey({ key: 'rl.rifle.chamber', run: play('rl', { id: 'rifle', ph: 'chamber', kind: 'mag', dur: rlDur.rifle, emp: true }) });     // (a partial reload keeps the round chambered: no sound, audio/sfx.gd checks emp)
  for (const ph of [...RL_MAG, ...RL_SHELL]) await bakeKey({ key: `rl.shotgun.${ph}`, run: play('rl', { id: 'shotgun', ph, kind: 'shell', dur: 3, emp: true }), mustSound: false });
  for (const ph of [...RL_MAG, ...RL_SHELL]) await bakeKey({ key: `rl.other.${ph}`, run: play('rl', { id: 'pistol', ph, kind: 'mag', dur: 1.5, emp: true }), mustSound: false });  // every other weapon: h = 0.5, generic phases
  // ---- syllables: the same line always sounds the same, so they are a fixed bank indexed by the hash's own fields ----
  let seed = 12345; const rnd24 = () => (seed = (seed * 1103515245 + 12345) & 0x7fffff);
  for (const last of [false, true]) {
    for (let kind = 0; kind < 6; kind++) for (let k = 0; k < 8; k++) {
      let h = 0; do { h = rnd24(); } while (h % 6 !== kind || ((h >> 3) % 8) !== k);
      await bakeKey({ key: `alienSyl.${kind}.${k}${last ? '.last' : ''}`, takes: 1, noJitter: true, run: (c) => S.s_alienSyl(c.currentTime + 0.001, { h, pitch: 1, last }), hint: 0.6 });
    }
    for (let kind = 0; kind < 5; kind++) for (let k = 0; k < 7; k++) {
      let h = 0; do { h = rnd24(); } while (h % 5 !== kind || ((h >> 3) % 7) !== k);
      await bakeKey({ key: `dogSyl.${kind}.${k}${last ? '.last' : ''}`, takes: 1, noJitter: true, run: (c) => S.s_dogSyl(c.currentTime + 0.001, { h, pitch: 1, last }), hint: 0.6 });
    }
  }
  // ---- _babble and _grayTongue: one syllable per vowel, the click, the whine (played under the gray tongue at three lengths) ----
  const V = [[700, 1100], [500, 1500], [350, 2200], [600, 900], [450, 1050]];
  for (let v = 0; v < 5; v++) await bakeKey({ key: `babble.${v}`, takes: 3, run: (c) => { const t = c.currentTime + 0.001, f = 118, d = 0.13; S._voice(t, d, f * 1.08, f * 0.92, 0.85, V[v]); S.tone(t, d, f * 2, f * 1.9, { type: 'square', gain: 0.035, wet: 0.1 }); }, hint: 0.5 });
  await bakeKey({ key: 'babble.click', takes: 3, run: (c) => S.noise(c.currentTime + 0.001, 0.05, { type: 'bandpass', f0: 2600, q: 3, gain: 0.12, wet: 0.1 }), hint: 0.3 });
  for (const L of [0.5, 1, 1.6]) {
    await bakeKey({ key: `whine.${L}`, takes: 1, run: (c) => { const w = 340; S.tone(c.currentTime + 0.001, L, w * 0.9, w * 1.25, { type: 'sine', gain: 0.035, attack: 0.08, wet: 0.6 }); }, hint: 2 });
    await bakeKey({ key: `whine.die.${L}`, takes: 1, run: (c) => { const w = 340; S.tone(c.currentTime + 0.001, L, w * 1.2, w * 0.4, { type: 'sine', gain: 0.035, attack: 0.08, wet: 0.6 }); }, hint: 2 });
  }
  // ---- creatures: every kind x every cue the views and CreatureAudio ask for ----
  S.s_creature = function (t, o) { CA.synthCreature(this, t, o); };
  const CUES = ['idle', 'step', 'alert', 'wind', 'impact', 'pain', 'death', 'roar', 'inhale', 'wheeze', 'squelch', 'whoosh', 'thud', 'crack'];
  for (const kind of Object.keys(CA.CREATURE_VOICES)) for (const cue of CUES) await bakeKey({ key: `creature.${kind}.${cue}`, takes: 4, run: play('creature', { kind, cue }), hint: 2 });
  // wind-ups last as long as the attack's wind-up (creatureWind): render the real lengths. The bank key carries the length, audio/sfx.gd takes the nearest.
  const winds = {};
  const C = { carapaceChargeWind: 0.9, carapaceSlamWind: 0.7, crawlerDropWind: opt.crawler.drop, crawlerLeapWind: opt.crawler.leap, crawlerBiteWind: 0.35, crawlerSpitWind: 0.6, wretchWind: 0.95, bloatFuse: 0.7, mimicWind: 0.55, prophetSummonWind: 1, prophetBlastWind: 0.5, screamWhipWind: 0.45, screamCallWind: 1, screamDartWind: 0.5, wormSlamWind: 0.75, wormRingWind: 0.6, alienMindWind: 0.85, ...(CONFIG || {}) };
  const FLAG = { alien: 'alien', spore: 'floater', follower: 'follower', prophet: 'prophet', scream: 'scream', worm: 'worm', crawler: 'crawler', mimic: 'mimic', warden: 'warden', brute: 'brute' };
  for (const kind of Object.keys(CA.CREATURE_VOICES)) {
    const set = new Set();
    for (const atk of ['charge', 'slam', 'drop', 'leap', 'melee', 'spit', 'summon', 'blast', 'whip', 'call', 'dart', 'ring', 'shot', 'sauce']) {
      const r = { atk, name: kind === 'tongue' ? 'WALLWRETCH' : '' }; if (FLAG[kind]) r[FLAG[kind]] = true;
      const w = CG.creatureKind(r) === kind ? CG.creatureWind(r, C) : undefined; if (w) set.add(Math.round(w * 100) / 100);
    }
    if (kind === 'alien') set.add(0.22);                                  // CreatureAudio.event: an alien's shot tell
    winds[kind] = [...set];
    for (const w of set) await bakeKey({ key: `creature.${kind}.wind-${w}`, takes: 4, run: play('creature', { kind, cue: 'wind', dur: w }), hint: 2 });
  }
  await say('creature wind lengths ' + JSON.stringify(winds));
  // ---- robot-sounds.js: three seeded takes per action, no Web Audio at all ----
  for (const id of Object.keys(RS.ROBOT_SOUNDS)) {
    if (onlyRe && !onlyRe.test(id)) continue;
    keys++;
    for (let take = 0; take < 3; take++) {
      const fake = { sampleRate: sr, createBuffer: (ch, len, rate) => new AudioBuffer({ length: len, sampleRate: rate, numberOfChannels: ch }) };
      const b = RS.synthesizeRobotSound(fake, id, take), d = b.getChannelData(0);
      await sink(JSON.stringify({ key: id, take, nc: 1, sr: b.sampleRate, keepRate: true, mustSound: true }), b64(d));
    }
  }
  // ---- the mixer envelope of synth-audio.js is a runtime fade, applied in audio/synth_audio.gd ----
  // ---- footsteps: updatePlayerFootsteps with level = 1 (the frame multiplies the level in) ----
  for (const run of [false, true]) for (let variant = 0; variant < 3; variant++) {
    await bakeKey({ key: `foot.${run ? 'run' : 'walk'}.${variant}`, takes: 2, run: (c) => {
      const buf = S.voiceBuf && S.voiceBuf[['footConcrete2', 'footConcrete3', 'footConcrete4'][variant]], level = 1, t = c.currentTime;
      if (buf) S.clip(buf, { gain: level, rate: run ? 1.06 : 0.94, duration: run ? 0.19 : 0.24, fade: 0.035, wet: 0 });
      S.tone(t, 0.075, run ? 115 : 100, 45, { gain: level * 0.3, wet: 0 });
      S.noise(t + 0.025, 0.035, { type: 'bandpass', f0: 2400 + variant * 180, f1: 1200, q: 2, gain: level * 0.075, wet: 0 });
    }, hint: 0.6 });
  }
  // ---- menuSound: kinds, including the clip they layer ----
  for (const kind of ['open', 'close', 'nav', 'buy', 'deny', 'confirm', 'pauseNav', 'pauseConfirm', 'pauseGlitch']) await bakeKey({ key: `menu.${kind}`, run: () => S.menuSound(kind), hint: 1 });
  // ---- recorded clips, as prepared by preparePlayerClip / prepareWeaponClip (never normalised again: they are peak-limited already) ----
  for (const [k, b] of Object.entries(S.voiceBuf || {})) {
    if (k === 'weaponSwarm') continue;
    const key = 'clip.' + k; if (onlyRe && !onlyRe.test(key)) continue; keys++;
    const ch = []; for (let c = 0; c < Math.min(2, b.numberOfChannels); c++) ch.push(b.getChannelData(c));
    await sink(JSON.stringify({ key, take: 0, nc: ch.length, sr: b.sampleRate, noNormalise: true, keepRate: false, mustSound: true }), b64((() => { const n = ch[0].length, f = new Float32Array(n * ch.length); for (let c = 0; c < ch.length; c++) for (let i = 0; i < n; i++) f[i * ch.length + c] = ch[c][i]; return f; })()));
  }
  if (S.swarmParts) for (const part of ['attack', 'loop', 'tail']) {
    const key = 'swarm.' + part; if (onlyRe && !onlyRe.test(key)) continue; keys++;
    const b = S.swarmParts[part], ch = []; for (let c = 0; c < Math.min(2, b.numberOfChannels); c++) ch.push(b.getChannelData(c));
    const n = ch[0].length, f = new Float32Array(n * ch.length); for (let c = 0; c < ch.length; c++) for (let i = 0; i < n; i++) f[i * ch.length + c] = ch[c][i];
    await sink(JSON.stringify({ key, take: 0, nc: ch.length, sr: b.sampleRate, keepRate: true, loop: part === 'loop', base: 0, mustSound: true }), b64(f));
  }
  // ---- loops: rendered long, the last whole period kept, so filters have settled and the seam is exact ----
  async function bakeLoop(key, periodFrames, base, build) {
    if (onlyRe && !onlyRe.test(key)) return; keys++;
    const warm = 4, len = periodFrames * (warm + 1) / sr, g = graph(len + 0.01);
    Object.assign(S, { ctx: g.c, master: g.master, verb: g.verb, wet: g.master, noiseBuf: noise, _bus: null });
    build(g.c, g.master);
    const buf = await g.c.startRendering(), a = periodFrames * warm;
    await ship({ key, take: 0, loop: true, keepRate: true, base, mustSound: true }, [buf.getChannelData(0).subarray(a, a + periodFrames), buf.getChannelData(1).subarray(a, a + periodFrames)]);
  }
  const osc = (c, out, type, f, a = 1, lp = 0) => { const o = c.createOscillator(), g = c.createGain(); o.type = type; o.frequency.value = f; g.gain.value = a; let n = o; if (lp) { const l = c.createBiquadFilter(); l.type = 'lowpass'; l.frequency.value = lp; o.connect(l); n = l; } n.connect(g); g.connect(out); o.start(0); return o; };
  // crtHum: 60 / 120 / 180 Hz + the flyback whine: all whole cycles in 1/20 s (the wobble and the fade are volume, applied per frame)
  await bakeLoop('hum.crt', Math.round(sr / 20), 0, (c, out) => { osc(c, out, 'sine', 60, 1); osc(c, out, 'sine', 120, 0.55); osc(c, out, 'sine', 180, 0.18); osc(c, out, 'sine', 15700, 0.05); });
  // the vending machine: compressor hum (50 / 100 / 150 / 120 Hz whole cycles in 1 s) + the 9 Hz rattle on the 2 s noise loop. The slow 0.075 Hz swell is volume, applied per frame.
  await bakeLoop('amb.vending', sr * 2, 0, (c, out) => {
    osc(c, out, 'sawtooth', 50, 0.5, 220); osc(c, out, 'sine', 100, 0.34); osc(c, out, 'sine', 150, 0.1); osc(c, out, 'triangle', 120, 0.05);
    const ns = c.createBufferSource(); ns.buffer = noise; ns.loop = true; const bp = c.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = 420; bp.Q.value = 3;
    const ng = c.createGain(); ng.gain.value = 0.05; const rl = c.createOscillator(), rg = c.createGain(); rl.frequency.value = 9; rg.gain.value = 0.04; rl.connect(rg); rg.connect(ng.gain); rl.start(0);
    ns.connect(bp); bp.connect(ng); ng.connect(out); ns.start(0);
  });
  // the gadgets' looping voices (Gadgets._voice): oscillators without their low-pass (the voice's bus filter is the low-pass, at the JS's fixed cutoff); base is the frequency at pitch_scale 1, kept at the top of each range so playback only pitches down and never aliases
  for (const [key, type, want] of [['loop.disc', 'sawtooth', 1000], ['loop.charge', 'triangle', 500], ['loop.well', 'sine', 140], ['loop.arc', 'sawtooth', 68], ['loop.arc2', 'square', 2300]]) {
    const per = Math.max(2, Math.round(sr / want)), cycles = Math.ceil(0.05 * sr / per), base = sr / per;     // (a whole number of cycles of a whole number of samples)
    await bakeLoop(key, per * cycles, base, (c, out) => { osc(c, out, type, base, 1); });
  }
  // the vending adverts through the cheap speaker chain (adPlay): one file each, at ad.vol = 0.36 straight at the listener
  try {
    const urls = ['assets/sfx/vending/ad1.m4a', 'assets/sfx/vending/ad2.m4a', 'assets/sfx/vending/ad3.m4a'];
    const bufs = await Promise.all(urls.map((u) => fetch('/' + u).then((r) => r.arrayBuffer()).then((b) => live.decodeAudioData(b))));
    for (let i = 0; i < bufs.length; i++) {
      S._adBufs = []; S._adBufs[i] = bufs[i]; S._adLast = -1; S._ad = null;
      await bakeKey({ key: `ad.${i}`, takes: 1, noJitter: true, run: () => { S._ad = null; S.adPlay(null); }, hint: bufs[i].duration / 0.86 + 3 });
    }
    S._adBufs = null;
  } catch (e) { await say('adverts failed: ' + e); }
  const rnd = (a, b) => a + Math.random() * (b - a);
  // BACK ALLEY's storm (levels/worldbackalley/storm.js thunder(), windGust()): the delay after the flash is played by levels/worldbackalley/storm.gd
  const thunder = (close, overhead) => (c) => {
    const t0 = c.currentTime + 0.001, k = overhead ? 1.25 : close ? 1 : 0.6;
    if (close) {
      S.noise(t0, 0.3, { type: 'highpass', f0: 5200, f1: 900, q: 0.6, gain: overhead ? 0.9 : 0.55, wet: 0.45 });
      S.noise(t0 + 0.02, 0.8, { type: 'bandpass', f0: 2000, f1: 240, q: 0.8, gain: overhead ? 0.9 : 0.6, wet: 0.6 });
      S.tone(t0, 1.6, 80, 26, { gain: overhead ? 0.8 : 0.5, wet: 0.3 });
      if (overhead) for (let i = 0; i < 5; i++) S.noise(t0 + 0.05 + i * rnd(0.04, 0.09), 0.12, { type: 'highpass', f0: rnd(2500, 4500), q: 0.7, gain: 0.35, wet: 0.4 });
    }
    const rolls = 4 + Math.floor(Math.random() * 4);
    for (let i = 0; i < rolls; i++) { const at = t0 + (close ? 0.12 : 0) + i * rnd(0.3, 0.8); S.noise(at, rnd(1.8, 3.6), { type: 'lowpass', f0: rnd(260, 460), f1: 50, q: 0.5, gain: 0.85 * k * (1 - i * 0.1), attack: rnd(0.06, 0.3), wet: 0.75 }); }
    S.tone(t0 + 0.1, 3.5, 48, 28, { gain: 0.35 * k, attack: 0.3, wet: 0.6 });
    S.noise(t0 + 0.4, 6.5, { type: 'lowpass', f0: 180, f1: 40, q: 0.5, gain: 0.38 * k, attack: 0.8, wet: 0.9 });
  };
  const wind = (len) => (c) => {
    const t0 = c.currentTime + 0.01, f = rnd(380, 620);
    S.noise(t0, len, { type: 'bandpass', f0: f * 0.6, f1: f * 1.5, q: 1.6, gain: 0.32, attack: len * 0.4, wet: 0.6 });
    S.noise(t0 + 0.2, len * 0.9, { type: 'lowpass', f0: 900, f1: 220, q: 0.4, gain: 0.3, attack: len * 0.35, wet: 0.5 });
  };
  for (const r of [{ key: 'storm.thunder.close', takes: 3, run: thunder(true, false), hint: 11 }, { key: 'storm.thunder.far', takes: 3, run: thunder(false, false), hint: 11 }, { key: 'storm.thunder.overhead', takes: 3, run: thunder(true, true), hint: 11 },
    { key: 'storm.wind.3', takes: 2, run: wind(3), hint: 4 }, { key: 'storm.wind.4', takes: 2, run: wind(4), hint: 5 }, { key: 'storm.wind.5', takes: 2, run: wind(5), hint: 6 }, { key: 'storm.wind.6', takes: 2, run: wind(6), hint: 7 }]) await bakeKey(r);
  // ---- the 9 .m4a decoded next to themselves ----
  const M4A = ['assets/sfx/cherub-death', 'assets/sfx/cherub-hey-prog', 'assets/sfx/cherub-hey-tommy', 'assets/sfx/cherub-hurt-1', 'assets/sfx/cherub-hurt-2', 'assets/sfx/cherub-hurt-3', 'assets/sfx/vending/ad1', 'assets/sfx/vending/ad2', 'assets/sfx/vending/ad3'];
  if (!onlyRe || onlyRe.test('m4a')) for (const p of M4A) {
    const b = await fetch('/' + p + '.m4a').then((r) => r.arrayBuffer()).then((x) => live.decodeAudioData(x)), ch = []; for (let c = 0; c < Math.min(2, b.numberOfChannels); c++) ch.push(b.getChannelData(c));
    const n = ch[0].length, f = new Float32Array(n * ch.length); for (let c = 0; c < ch.length; c++) for (let i = 0; i < n; i++) f[i * ch.length + c] = ch[c][i];
    await sink(JSON.stringify({ key: p, take: 0, nc: ch.length, sr: b.sampleRate, path: p + '.wav', noNormalise: true, mustSound: true }), b64(f));
  }
  return { ids, keys, done };
};

// ---------------------------------------------------------------- run ----------------------------------------------------------------
fs.mkdirSync(OUT, { recursive: true }); fs.mkdirSync(path.dirname(LOG), { recursive: true });
const t0 = Date.now();
let h = null;
for (let tries = 0; tries < 3 && !h; tries++) {
  try { h = await boot('hub', { timeout: 600000 }); } catch (e) { console.log('boot failed (the machine may be busy), retrying: ' + e.message); }
}
if (!h) process.exit(2);
console.log(`booted in ${((Date.now() - t0) / 1000).toFixed(0)} s`);
await h.page.exposeFunction('__rsSink', (meta, data) => onRender(JSON.parse(meta), Buffer.from(data, 'base64')));
await h.page.exposeFunction('__rsLog', (m) => console.log(m));
let res;
try {
  const src = fs.readFileSync(path.join(JS, 'index.html'), 'utf8'), rlDur = {};
  const table = src.slice(src.indexOf('const WEAPONS = ['), src.indexOf('];', src.indexOf('const WEAPONS = [')));
  for (const m of table.matchAll(/id: '(\w+)'[\s\S]*?reloadTime: ([\d.]+)/g)) rlDur[m[1]] = +m[2];
  const crawlerSrc = fs.readFileSync(path.join(JS, 'enemies/sinew-crawler.js'), 'utf8');
  const crawler = { drop: +(crawlerSrc.match(/crawlerDropWind: ([\d.]+)/) || [0, 0.7])[1], leap: +(crawlerSrc.match(/crawlerLeapWind: ([\d.]+)/) || [0, 0.4])[1] };
  console.log('reload times ' + JSON.stringify(rlDur) + ' crawler ' + JSON.stringify(crawler));
  res = await h.page.evaluate(PAGE, { only, rlDur, crawler });
} finally {
  writeBank();
  fs.writeFileSync(LOG, JSON.stringify(log, null, 0));
  await h.close();
}
console.log(`rendered: ${res.ids.length} s_* methods, ${res.keys} keys, ${files} files, ${(totalBytes / 1e6).toFixed(1)} MB in ${((Date.now() - t0) / 1000).toFixed(0)} s; log ${LOG}`);
process.exit(0);
