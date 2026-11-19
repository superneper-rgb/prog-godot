// Decodes MP3s (Godot cannot read an MP3's samples) to 16-bit WAV through the browser (Edge via Playwright, as tools/export/voice-trim.mjs does): node tools/underfoint_audio/decode.mjs in.mp3 out.wav [in2 out2 ...]
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const JS = (await import('../js_root.mjs')).JS_ROOT;
const require = createRequire(path.join(JS, 'tests/render-fx-tex.cjs'));
const fsrt = 'C:/Users/12147/AppData/Local/OpenAI/Codex/runtimes';
const tries = [process.env.PROG_PLAYWRIGHT, 'C:/Users/12147/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright', 'playwright'];
try { for (const d of fs.readdirSync(fsrt)) tries.unshift(path.join(fsrt, d, 'bin/node_modules/playwright')); } catch { /* no runtime here */ }
let pw = null;
for (const t of tries) { if (!t) continue; try { pw = require(t); break; } catch { /* next */ } }
if (!pw) throw new Error('Playwright not found: set PROG_PLAYWRIGHT');
const args = process.argv.slice(2);
const browser = await pw.chromium.launch({ headless: true, channel: process.env.PROG_BROWSER || 'msedge' });
const page = await browser.newPage();
for (let j = 0; j + 1 < args.length; j += 2) {
  const [inp, out] = [args[j], args[j + 1]];
  const info = await page.evaluate(async (b) => {
    const bin = atob(b), u = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i);
    const buf = await new OfflineAudioContext(2, 1, 44100).decodeAudioData(u.buffer);
    window._buf = buf;
    return { sr: buf.sampleRate, n: buf.length, ch: buf.numberOfChannels };
  }, fs.readFileSync(inp).toString('base64'));
  const nch = Math.min(2, info.ch);
  const pcm = Buffer.alloc(info.n * nch * 2);
  const CH = 44100 * 20;
  for (let s = 0; s < info.n; s += CH) {
    const part = await page.evaluate(([s, CH, nch]) => {
      const buf = window._buf, e = Math.min(buf.length, s + CH), L = buf.getChannelData(0), R = nch > 1 ? buf.getChannelData(1) : L;
      const a = new Int16Array((e - s) * nch);
      for (let i = s, k = 0; i < e; i++) { a[k++] = Math.max(-32768, Math.min(32767, Math.round(L[i] * 32767))); if (nch > 1) a[k++] = Math.max(-32768, Math.min(32767, Math.round(R[i] * 32767))); }
      const u = new Uint8Array(a.buffer);
      let str = '';
      for (let i = 0; i < u.length; i += 0x8000) str += String.fromCharCode.apply(null, u.subarray(i, i + 0x8000));
      return btoa(str);
    }, [s, CH, nch]);
    Buffer.from(part, 'base64').copy(pcm, s * nch * 2);
  }
  const h = Buffer.alloc(44);
  h.write('RIFF', 0); h.writeUInt32LE(36 + pcm.length, 4); h.write('WAVE', 8); h.write('fmt ', 12); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(nch, 22);
  h.writeUInt32LE(info.sr, 24); h.writeUInt32LE(info.sr * nch * 2, 28); h.writeUInt16LE(nch * 2, 32); h.writeUInt16LE(16, 34); h.write('data', 36); h.writeUInt32LE(pcm.length, 40);
  fs.mkdirSync(path.dirname(path.resolve(out)), { recursive: true });
  fs.writeFileSync(out, Buffer.concat([h, pcm]));
  console.log('decoded', path.basename(inp), `${(info.n / info.sr).toFixed(2)} s`);
}
await browser.close();
