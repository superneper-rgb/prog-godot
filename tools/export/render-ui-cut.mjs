// Cuts the black screen out of a machine picture, the way the JS VendorMenu.wrapArt does when the image loads (flood from the middle over pixels darker than 45): in the port that is done once here, not at run time. Writes <name>.cut.png next to the picture and prints the screen's rectangle for the menu's `hole`.
//   node tools/export/render-ui-cut.mjs
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
const PICTURES = ['assets/ui/dorpimplant-2400.png'];
const browser = await pw.chromium.launch({ headless: true, channel: process.env.PROG_BROWSER || 'msedge' });
const page = await browser.newPage();
await page.route('http://local.test/**', (q) => q.fulfill({ body: fs.readFileSync(path.join(PROJECT, new URL(q.request().url()).pathname)), contentType: 'image/png', headers: { 'Access-Control-Allow-Origin': '*' } }));
await page.goto('about:blank');
for (const rel of PICTURES) {
  const src = path.join(PROJECT, rel);
  const r = await page.evaluate(async (u) => {
    const img = new Image(); img.crossOrigin = 'anonymous'; await new Promise((ok, no) => { img.onload = ok; img.onerror = no; img.src = u; });
    const W = img.naturalWidth, H = img.naturalHeight, art = document.createElement('canvas'); art.width = W; art.height = H;
    const cx = art.getContext('2d', { willReadFrequently: true }); cx.drawImage(img, 0, 0);
    const id = cx.getImageData(0, 0, W, H), d = id.data, seen = new Uint8Array(W * H), stk = [((H / 2) | 0) * W + ((W / 2) | 0)]; let x1 = W, x2 = 0, y1 = H, y2 = 0;
    while (stk.length) {
      const p = stk.pop(); if (seen[p]) continue; const i = p * 4;
      if (d[i + 3] < 128 || Math.max(d[i], d[i + 1], d[i + 2]) >= 45) continue;
      seen[p] = 1; d[i + 3] = 0;
      const x = p % W, y = (p - x) / W; if (x < x1) x1 = x; if (x > x2) x2 = x; if (y < y1) y1 = y; if (y > y2) y2 = y;
      if (x > 0) stk.push(p - 1); if (x < W - 1) stk.push(p + 1); if (y > 0) stk.push(p - W); if (y < H - 1) stk.push(p + W);
    }
    cx.putImageData(id, 0, 0);
    return { png: art.toDataURL('image/png').split(',')[1], W, H, hole: { x1: x1 / W, y1: y1 / H, x2: (x2 + 1) / W, y2: (y2 + 1) / H } };
  }, 'http://local.test/' + rel);
  const out = src.replace(/\.png$/, '.cut.png');
  fs.writeFileSync(out, Buffer.from(r.png, 'base64'));
  console.log(rel, r.W + 'x' + r.H, 'hole', JSON.stringify(r.hole));
}
await browser.close();
