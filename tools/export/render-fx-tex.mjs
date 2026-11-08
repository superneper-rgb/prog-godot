// Renders the canvases of the three.js FX to real PNGs: blood splats (_bloodInit), assets/fx/blood_0..2.png, and the flail impact's sprites (flail-impact-fx.js), assets/fx/flail_*.png. Same code, same seeds, drawn by a real canvas in a blank headless page.
//   node tools/export/render-fx-tex.mjs
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const PROJECT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const JS = path.resolve(PROJECT, '../progalpha-20261016T082732Z-1-001/progalpha');
const require = createRequire(path.join(JS, 'tests/render-fx-tex.cjs'));
const fsrt = 'C:/Users/12147/AppData/Local/OpenAI/Codex/runtimes';
const tries = [process.env.PROG_PLAYWRIGHT, 'C:/Users/12147/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright', 'playwright'];
try { for (const d of fs.readdirSync(fsrt)) tries.unshift(path.join(fsrt, d, 'bin/node_modules/playwright')); } catch { /* no runtime here */ }
let pw = null;
for (const t of tries) { if (!t) continue; try { pw = require(t); break; } catch { /* next */ } }
if (!pw) throw new Error('Playwright not found: set PROG_PLAYWRIGHT');
const browser = await pw.chromium.launch({ headless: true, channel: process.env.PROG_BROWSER || 'msedge' });
const page = await browser.newPage();
const urls = await page.evaluate(() => {
  const mk = (seed) => {                                 // JS FX._bloodInit, statement for statement
    const c = document.createElement('canvas'); c.width = c.height = 128; const x = c.getContext('2d'); let r = seed;
    const rnd = () => (r = (r * 16807) % 2147483647) / 2147483647;
    const blob = (px, py, rad) => { const g = x.createRadialGradient(px, py, 0, px, py, rad); g.addColorStop(0, 'rgba(125,8,10,1)'); g.addColorStop(0.7, 'rgba(100,6,8,.95)'); g.addColorStop(1, 'rgba(70,4,6,0)'); x.fillStyle = g; x.beginPath(); x.arc(px, py, rad, 0, 6.283); x.fill(); };
    blob(64, 64, 26 + rnd() * 8);
    for (let i = 0; i < 12; i++) { const a = rnd() * 6.283, d = 22 + rnd() * 28; blob(64 + Math.cos(a) * d, 64 + Math.sin(a) * d, 3 + rnd() * 9); }
    for (let i = 0; i < 3; i++) { const a = rnd() * 6.283; for (let k = 1; k < 4; k++) blob(64 + Math.cos(a) * (28 + k * 10), 64 + Math.sin(a) * (28 + k * 10), 7 - k * 1.5); }
    return c.toDataURL('image/png');
  };
  return [mk(11), mk(2027), mk(90901)];
});
// the flail impact's sprites: weapons/flail-impact-fx.js texture(), statement for statement
const flail = await page.evaluate(() => {
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const noise = n => { const x = Math.sin(n * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); };
  const smooth = x => { x = clamp(x, 0, 1); return x * x * (3 - 2 * x); };
  function field(x, y) { const ix = Math.floor(x), iy = Math.floor(y), u = smooth(x - ix), v = smooth(y - iy); const a = noise(ix + iy * 57), b = noise(ix + 1 + iy * 57), c = noise(ix + (iy + 1) * 57), d = noise(ix + 1 + (iy + 1) * 57); return (a + (b - a) * u) * (1 - v) + (c + (d - c) * u) * v; }
  const billow = (x, y) => field(x, y) * 0.58 + field(x * 2.1 + 7, y * 2.1) * 0.28 + field(x * 4.3, y * 4.3 + 9) * 0.14;
  const tex = (kind) => {
    const canvas = document.createElement('canvas'); canvas.width = canvas.height = 256;
    const ctx = canvas.getContext('2d'), pixels = ctx.createImageData(256, 256);
    for (let y = 0; y < 256; y++) for (let x = 0; x < 256; x++) {
      const u = (x + 0.5) / 128 - 1, v = (y + 0.5) / 128 - 1, r = Math.hypot(u, v), a = Math.atan2(v, u), i = (y * 256 + x) * 4;
      let alpha, red, green, blue;
      if (kind === 'flame') {
        const n = billow(u * 5 + 15, v * 5 + 19), curl = billow(u * 9 - v * 2, v * 7 + 31);
        const edge = 0.64 + n * 0.35, shape = Math.hypot(u * 0.93, (v - 0.14) * 0.90);
        alpha = smooth((edge - shape) * 6) * smooth((n + 0.24 - Math.abs(u) * 0.32) * 3);
        const heat = smooth((curl * 0.65 + n * 0.35 - 0.20) * 1.8) * (0.70 + 0.30 * smooth(v + 0.2));
        red = 255; green = 60 + 185 * heat; blue = 7 + 151 * heat ** 4;
      } else if (kind === 'dust' || kind === 'scorch') {
        const n = billow(u * 5 + 8, v * 5 + 14), edge = 0.62 + 0.30 * n + 0.055 * Math.sin(a * 7);
        alpha = smooth((edge - r) * 4.5) * (0.48 + 0.52 * n);
        const shade = 0.64 + 0.45 * n - 0.16 * v;
        [red, green, blue] = kind === 'dust' ? [155 * shade, 126 * shade, 91 * shade] : [39, 27, 18];
      } else { alpha = Math.exp(-r * r * 6) * clamp((1 - r) * 8, 0, 1); red = 255; green = 235; blue = 170; }
      pixels.data.set([red, green, blue, Math.round(clamp(alpha, 0, 1) * 255)], i);
    }
    ctx.putImageData(pixels, 0, 0); return canvas.toDataURL('image/png');
  };
  return { flail_flame: tex('flame'), flail_dust: tex('dust'), flail_flash: tex('flash'), flail_scorch: tex('scorch') };
});
await browser.close();
const out = path.join(PROJECT, 'assets/fx');
fs.mkdirSync(out, { recursive: true });
urls.forEach((u, i) => fs.writeFileSync(path.join(out, `blood_${i}.png`), Buffer.from(u.split(',')[1], 'base64')));
for (const [k, u] of Object.entries(flail)) fs.writeFileSync(path.join(out, `${k}.png`), Buffer.from(u.split(',')[1], 'base64'));
console.log('wrote ' + (urls.length + 4) + ' textures to ' + out);
