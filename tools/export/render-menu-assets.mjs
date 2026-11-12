// Renders the main menu backdrop's canvases and synth voices (menu/menu-scene.js, gear/night-vision.js) to real files: assets/ui/menu_scene/*.png, assets/sfx/menu/*.wav.
// The JS rolls its thunder afresh each strike: here each kind is baked three times and the scene picks one (a script cannot filter seconds of noise without a hitch).
//   node tools/export/render-menu-assets.mjs
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const PROJECT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const JS = (await import('../js_root.mjs')).JS_ROOT;
const require = createRequire(path.join(JS, 'tests/render-fx-tex.cjs'));
const fsrt = 'C:/Users/12147/AppData/Local/OpenAI/Codex/runtimes';
const tries = [process.env.PROG_PLAYWRIGHT, 'C:/Users/12147/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright', 'playwright'];
try { for (const d of fs.readdirSync(fsrt)) tries.unshift(path.join(fsrt, d, 'bin/node_modules/playwright')); } catch { /* no runtime here */ }
let pw = null;
for (const t of tries) { if (!t) continue; try { pw = require(t); break; } catch { /* next */ } }
if (!pw) throw new Error('Playwright not found: set PROG_PLAYWRIGHT');
const browser = await pw.chromium.launch({ headless: true, channel: process.env.PROG_BROWSER || 'msedge' });
const page = await browser.newPage();

const tex = await page.evaluate(() => {
  const rand = (a, b) => a + Math.random() * (b - a);
  const out = {};
  const canvasTex = (name, w, h, draw) => { const c = document.createElement('canvas'); c.width = w; c.height = h; draw(c.getContext('2d'), w, h); out[name] = c.toDataURL('image/png'); };
  canvasTex('glow', 64, 64, (g) => {
    const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32);
    gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.2, 'rgba(255,255,255,.55)'); gr.addColorStop(0.5, 'rgba(255,255,255,.12)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, 64, 64);
  });
  canvasTex('stone', 512, 1024, (g, w, h) => {
    g.fillStyle = '#1b1d20'; g.fillRect(0, 0, w, h);
    const bh = 72;
    for (let r = 0; r * bh < h; r++) {
      const off = (r % 2) * 90;
      for (let x = -off; x < w; x += 180) {
        const v = 26 + Math.random() * 18; g.fillStyle = `rgb(${v},${v + 2},${v + 5})`; g.fillRect(x + 3, r * bh + 3, 174, bh - 6);
      }
    }
    for (let i = 0; i < 26000; i++) { const v = Math.random() * 70; g.fillStyle = `rgba(${v},${v},${v + 6},${Math.random() * 0.5})`; g.fillRect(Math.random() * w, Math.random() * h, 2, 2); }
    for (let i = 0; i < 70; i++) { g.strokeStyle = 'rgba(0,0,0,.35)'; g.lineWidth = 1 + Math.random() * 2; g.beginPath(); let x = Math.random() * w, y = Math.random() * h; g.moveTo(x, y); for (let k = 0; k < 6; k++) { x += rand(-12, 12); y += rand(4, 22); g.lineTo(x, y); } g.stroke(); }
  });
  canvasTex('chain', 64, 64, (g) => {
    g.strokeStyle = 'rgba(150,160,170,1)'; g.lineWidth = 3;
    g.beginPath(); g.moveTo(0, 0); g.lineTo(64, 64); g.moveTo(64, 0); g.lineTo(0, 64); g.moveTo(-32, 32); g.lineTo(32, -32); g.moveTo(32, 96); g.lineTo(96, 32); g.moveTo(32, -32); g.lineTo(96, 32); g.moveTo(-32, 32); g.lineTo(32, 96); g.stroke();
  });
  canvasTex('bead', 32, 32, (g) => {
    const body = g.createRadialGradient(16, 16, 0, 16, 16, 14); body.addColorStop(0, 'rgba(255,255,255,.12)'); body.addColorStop(0.7, 'rgba(255,255,255,.2)'); body.addColorStop(0.85, 'rgba(255,255,255,.55)'); body.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = body; g.beginPath(); g.arc(16, 16, 14, 0, Math.PI * 2); g.fill();
    const gl = g.createRadialGradient(11, 10, 0, 11, 10, 5); gl.addColorStop(0, 'rgba(255,255,255,1)'); gl.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = gl; g.fillRect(0, 0, 32, 32);
  });
  canvasTex('ring', 32, 32, (g) => { g.strokeStyle = 'rgba(255,255,255,.9)'; g.lineWidth = 2.5; g.beginPath(); g.ellipse(16, 16, 13, 6, 0, 0, Math.PI * 2); g.stroke(); });
  canvasTex('refl', 64, 256, (g, w, h) => {
    for (let y = 0; y < h; y++) {
      const v = Math.pow(1 - y / h, 0.6) * (0.55 + 0.45 * Math.random()) * (y % 7 < 2 ? 0.45 : 1);
      for (let x = 0; x < w; x++) { const u = (x - w / 2) / (w / 2), a = Math.exp(-u * u * (3 + 6 * y / h)) * v; g.fillStyle = `rgba(255,255,255,${a.toFixed(3)})`; g.fillRect(x, y, 1, 1); }
    }
  });
  canvasTex('nv_glow', 64, 64, (g) => {                                                 // gear/night-vision.js glowTex
    const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32);
    gr.addColorStop(0, 'rgba(235,255,225,1)'); gr.addColorStop(0.18, 'rgba(140,255,90,.9)'); gr.addColorStop(0.45, 'rgba(60,220,40,.35)'); gr.addColorStop(1, 'rgba(20,120,10,0)');
    g.fillStyle = gr; g.fillRect(0, 0, 64, 64);
  });
  return out;
});

const snd = await page.evaluate(async () => {
  const SR = 44100, rand = (a, b) => a + Math.random() * (b - a);
  const enc = (f) => { const u = new Int16Array(f.length); for (let i = 0; i < f.length; i++) u[i] = Math.max(-32767, Math.min(32767, Math.round(f[i] * 32767))); let bin = ''; const b = new Uint8Array(u.buffer); for (let i = 0; i < b.length; i += 8192) bin += String.fromCharCode.apply(null, b.subarray(i, i + 8192)); return btoa(bin); };
  const trim = (f) => { let n = f.length; while (n > 64 && Math.abs(f[n - 1]) < 0.0004) n--; return f.subarray(0, Math.min(f.length, n + 32)); };
  const out = {}, peaks = {};
  // whine(): statement for statement
  {
    const ac = new OfflineAudioContext(1, Math.ceil(SR * 1.45), SR), master = ac.destination, t0 = 0.02;
    const nb = ac.createBuffer(1, ac.sampleRate * 0.03, ac.sampleRate), d = nb.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / d.length);
    const ck = ac.createBufferSource(), hp = ac.createBiquadFilter(), cg = ac.createGain(); ck.buffer = nb; hp.type = 'highpass'; hp.frequency.value = 3500; cg.gain.value = 0.35;
    ck.connect(hp); hp.connect(cg); cg.connect(master); ck.start(t0);
    for (const [type, mul, g0] of [['sine', 1, 0.09], ['triangle', 1.5, 0.03], ['sine', 2.01, 0.015]]) {
      const o = ac.createOscillator(), g = ac.createGain(); o.type = type;
      o.frequency.setValueAtTime(1400 * mul, t0); o.frequency.exponentialRampToValueAtTime(7800 * mul, t0 + 0.75); o.frequency.exponentialRampToValueAtTime(8600 * mul, t0 + 1.3);
      g.gain.setValueAtTime(0.0001, t0); g.gain.exponentialRampToValueAtTime(g0, t0 + 0.12); g.gain.setValueAtTime(g0, t0 + 0.7); g.gain.exponentialRampToValueAtTime(0.0001, t0 + 1.35);
      o.connect(g); g.connect(master); o.start(t0); o.stop(t0 + 1.4);
    }
    const f = trim((await ac.startRendering()).getChannelData(0)); out.whine = enc(f);
  }
  // thunder(): statement for statement, with power 1 and the pan left to the player
  const ENV = (g, t0, pts) => { g.gain.setValueAtTime(0.0001, t0); for (const [t, v] of pts) g.gain.exponentialRampToValueAtTime(Math.max(0.0001, v), t0 + t); };
  const DUR = { crack: 5.8, boom: 3.6, roll: 9.5, distant: 7.3 };
  for (const kind of ['crack', 'boom', 'roll', 'distant']) for (let v = 0; v < 3; v++) {
    const ac = new OfflineAudioContext(1, Math.ceil(SR * DUR[kind]), SR), out_ = ac.destination, t0 = 0, p = 1;
    const brown = ac.createBuffer(1, ac.sampleRate * 8, ac.sampleRate); { const d = brown.getChannelData(0); let l = 0; for (let i = 0; i < d.length; i++) { l = (l + 0.02 * (Math.random() * 2 - 1)) / 1.02; d[i] = l * 3.5; } }
    const noise = (t0, dur, out, { type = 'lowpass', f = 160, f1 = null, q = 0.7, env, rate = 1 }) => {
      const s = ac.createBufferSource(), fl = ac.createBiquadFilter(), g = ac.createGain();
      s.buffer = brown; s.playbackRate.value = rate; fl.type = type; fl.frequency.setValueAtTime(f, t0); fl.Q.value = q;
      if (f1) fl.frequency.exponentialRampToValueAtTime(f1, t0 + dur);
      ENV(g, t0, env); s.connect(fl); fl.connect(g); g.connect(out);
      s.start(t0, rand(0, Math.max(0, brown.duration - dur * rate - 0.1))); s.stop(t0 + dur + 0.05);
    };
    if (kind === 'crack') {
      noise(t0, 0.5, out_, { type: 'bandpass', f: rand(1200, 2200), q: 0.5, rate: rand(1.4, 2), env: [[0.008, 2.2 * p], [0.45, 0.001]] });
      for (let i = 0, n = 3 + ((Math.random() * 4) | 0); i < n; i++) { const t = rand(0.04, 0.5); noise(t0 + t, 0.18, out_, { type: 'bandpass', f: rand(500, 1600), q: 0.8, rate: rand(1, 1.8), env: [[0.006, rand(0.5, 1.2) * p], [0.16, 0.001]] }); }
      noise(t0 + 0.05, 5.5, out_, { f: 320, f1: 85, rate: rand(0.8, 1.1), env: [[0.15, 2.6 * p], [1.2, 2.0 * p], [5.4, 0.001]] });
    } else if (kind === 'boom') {
      const o = ac.createOscillator(), g = ac.createGain(); o.frequency.setValueAtTime(rand(70, 95), t0); o.frequency.exponentialRampToValueAtTime(rand(28, 38), t0 + 0.9);
      ENV(g, t0, [[0.02, 0.9 * p], [1.1, 0.001]]); o.connect(g); g.connect(out_); o.start(t0); o.stop(t0 + 1.2);
      noise(t0, 0.35, out_, { type: 'bandpass', f: rand(600, 900), q: 0.6, env: [[0.01, 1.2 * p], [0.3, 0.001]] });
      noise(t0 + 0.02, 3.2, out_, { f: 120, f1: 70, rate: rand(0.7, 0.9), env: [[0.08, 2.8 * p], [0.7, 1.5 * p], [3.1, 0.001]] });
    } else if (kind === 'roll') {
      let t = 0; for (let i = 0, n = 3 + ((Math.random() * 3) | 0); i < n; i++) {
        const dur = rand(1.4, 2.6), peak = rand(1.2, 2.2) * p * (i === 0 ? 0.8 : 1);
        noise(t0 + t, dur, out_, { f: rand(160, 260), f1: rand(90, 130), rate: rand(0.8, 1.15), env: [[dur * 0.3, peak], [dur, 0.001]] });
        t += rand(0.5, 1.1);
      }
    } else {
      noise(t0, 7, out_, { f: rand(95, 125), f1: 60, rate: rand(0.6, 0.8), env: [[1.6, 1.6 * p], [3.2, 1.3 * p], [6.9, 0.001]] });
      noise(t0 + rand(0.8, 1.6), 3.5, out_, { f: 150, f1: 80, rate: 0.7, env: [[1.0, 0.9 * p], [3.4, 0.001]] });
    }
    const f = trim((await ac.startRendering()).getChannelData(0)); let pk = 0; for (let i = 0; i < f.length; i++) pk = Math.max(pk, Math.abs(f[i]));
    peaks[`${kind}_${v}`] = +pk.toFixed(3); for (let i = 0; i < f.length; i++) f[i] *= 0.5; out[`thunder_${kind}_${v}`] = enc(f);      // half level: the voices pass full scale, the player doubles it
  }
  return { out, peaks };
});
await browser.close();

const tdir = path.join(PROJECT, 'assets/ui/menu_scene'), sdir = path.join(PROJECT, 'assets/sfx/menu');
fs.mkdirSync(tdir, { recursive: true }); fs.mkdirSync(sdir, { recursive: true });
for (const [k, u] of Object.entries(tex)) fs.writeFileSync(path.join(tdir, `${k}.png`), Buffer.from(u.split(',')[1], 'base64'));
for (const [k, b] of Object.entries(snd.out)) {
  const pcm = Buffer.from(b, 'base64'), h = Buffer.alloc(44);
  h.write('RIFF', 0); h.writeUInt32LE(36 + pcm.length, 4); h.write('WAVEfmt ', 8); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22); h.writeUInt32LE(44100, 24); h.writeUInt32LE(88200, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34); h.write('data', 36); h.writeUInt32LE(pcm.length, 40);
  fs.writeFileSync(path.join(sdir, `${k}.wav`), Buffer.concat([h, pcm]));
}
console.log('wrote ' + Object.keys(tex).length + ' textures, ' + Object.keys(snd.out).length + ' sounds');
console.log('peaks', JSON.stringify(snd.peaks));
