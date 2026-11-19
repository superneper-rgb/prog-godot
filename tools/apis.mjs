// External asset and voice APIs as one dev tool: Sketchfab, Poly Haven, Gemini TTS, Fish Audio TTS, ElevenLabs TTS, plus a passthrough to the three.js game's devtools/assets.mjs (Polyfork, SimReady, Scenario, Internet Archive, Blender modify).
//
//   node tools/apis.mjs status                                   which keys are found (names only, never values)
//   node tools/apis.mjs sketchfab search "goblin" [--n 20]       downloadable models with licence; skip NC / ND ones
//   node tools/apis.mjs sketchfab get <uid> [--name out-name]    downloads the glTF into assets/third-party/sketchfab/<name>/ and logs the licence
//   node tools/apis.mjs polyhaven search <models|hdris|textures> [word]
//   node tools/apis.mjs polyhaven get <id> [--res 1k]            models -> .gltf + files, hdris -> .hdr, textures -> maps (CC0)
//   node tools/apis.mjs gemini tts "[sighs] text" --out file.wav [--style "who speaks, how, in what scene"] [--voice Charon] [--model gemini-3.1-flash-tts-preview] [--layout inline|notes]
//                                                                (the voice API for dialogue: always give --style and emotion tags; writes .wav)
//                                                                voices include Charon, Kore, Puck, Fenrir, Orus, Zephyr, Leda, Aoede, Enceladus, Algenib, Gacrux, Schedar
//                                                                --speakers "Sambo=Fenrir,Prog=Algenib": a two-speaker take; the text is "Sambo: ...", "Prog: ..." lines (the free tier allows 3 requests a minute,
//                                                                so a whole scene as one take, cut into lines afterwards, beats one request per line)
//   node tools/apis.mjs fish tts "text" --out file.mp3 [--voice <reference_id>] [--speed 1.0]    (the previous voice API; speech only)
//   node tools/apis.mjs eleven tts "text" --out file.mp3 [--voice <id>]                          (replaced by Fish; kept for old lines)
//   node tools/apis.mjs js polyfork search barrel                anything after `js` goes to the three.js game's devtools/assets.mjs
//                                                                (polyfork, simready, scenario, archive, modify); it writes to ITS assets/third-party
// Keys come from the environment, else the progectalp2 .env.local (never copied into this repo, never printed).
// Rules: ask the user before downloading; CC-BY needs credit in the game; skip NC / ND licences; new characters, enemies and weapons are proposed first (CLAUDE.md).
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { JS_ROOT } from './js_root.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT = path.join(ROOT, 'assets', 'third-party');
const CREDITS = path.join(OUT, 'CREDITS.json');
const ENV_FILES = [path.resolve(JS_ROOT, '../../../.env.local'), 'C:/Users/12147/Documents/GitHub/progectalp2/.env.local'];
const [, , api, verb, ...rest] = process.argv;
const flag = (k, d) => { const i = rest.indexOf('--' + k); return i >= 0 ? rest[i + 1] : d; };
const pos = rest.filter((a, i) => !a.startsWith('--') && !(rest[i - 1] || '').startsWith('--'));
const die = (m) => { console.error(m); process.exit(1); };

function key(name) {
  if (process.env[name]) return process.env[name];
  for (const f of ENV_FILES) {
    if (!fs.existsSync(f)) continue;
    const m = fs.readFileSync(f, 'utf8').match(new RegExp(`^${name}=(.+)$`, 'm'));
    if (m) return m[1].trim();
  }
  return die(`${name} not found (environment or ${ENV_FILES[1]})`);
}
const readCredits = () => (fs.existsSync(CREDITS) ? JSON.parse(fs.readFileSync(CREDITS, 'utf8')) : {});
function credit(file, row) {
  const c = readCredits();
  c[path.relative(OUT, file).replace(/\\/g, '/')] = row;
  fs.mkdirSync(OUT, { recursive: true });
  fs.writeFileSync(CREDITS, JSON.stringify(c, null, 1) + '\n');
}
async function json(url, headers = {}) {
  const r = await fetch(url, { headers });
  if (!r.ok) die(`${r.status} ${url}`);
  return r.json();
}
async function save(url, file) {
  const r = await fetch(url);
  if (!r.ok) die(`${r.status} ${url}`);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, Buffer.from(await r.arrayBuffer()));
}
const BAD_LICENCE = /\b(nc|nd)\b|non-?commercial|no-?deriv/i;

async function sketchfab() {
  const auth = { Authorization: `Token ${key('SKETCHFAB_API_TOKEN')}` };
  if (verb === 'search') {
    const q = encodeURIComponent(pos.join(' '));
    const j = await json(`https://api.sketchfab.com/v3/search?type=models&downloadable=true&count=${flag('n', 20)}&q=${q}`, auth);
    for (const m of j.results) {
      const lic = m.license?.label || m.license?.slug || '?';
      console.log(`${m.uid}  ${String(m.faceCount ?? '?').padStart(8)} faces  ${lic.padEnd(28)}${BAD_LICENCE.test(m.license?.slug || lic) ? ' SKIP ' : ' '}${m.name}  by ${m.user?.displayName}`);
    }
    return;
  }
  if (verb === 'get') {
    const uid = pos[0] || die('give a model uid');
    const meta = await json(`https://api.sketchfab.com/v3/models/${uid}`, auth);
    const lic = meta.license?.label || meta.license?.slug || '?';
    if (BAD_LICENCE.test(meta.license?.slug || lic)) die(`refusing ${meta.name}: licence ${lic}`);
    const dl = await json(`https://api.sketchfab.com/v3/models/${uid}/download`, auth);
    const name = flag('name') || meta.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
    const dir = path.join(OUT, 'sketchfab', name);
    const zip = path.join(dir, 'model.zip');
    await save((dl.gltf || die('no glTF download offered')).url, zip);
    const r = spawnSync('tar', ['-xf', zip, '-C', dir], { encoding: 'utf8' });
    if (r.status !== 0) die('unzip failed: ' + r.stderr);
    fs.unlinkSync(zip);
    credit(path.join(dir, 'scene.gltf'), { source: 'sketchfab', uid, title: meta.name, author: meta.user?.displayName, license: lic, url: meta.viewerUrl });
    return console.log('wrote', path.relative(ROOT, dir), `(${lic}, credit ${meta.user?.displayName})`);
  }
  die('sketchfab search|get');
}

async function polyhaven() {
  if (verb === 'search') {
    const j = await json(`https://api.polyhaven.com/assets?t=${pos[0] || 'models'}`);
    const w = (pos[1] || '').toLowerCase();
    for (const [id, a] of Object.entries(j)) if (!w || id.includes(w) || (a.name || '').toLowerCase().includes(w) || (a.tags || []).some((t) => t.includes(w))) console.log(id.padEnd(34), a.name);
    return;
  }
  if (verb === 'get') {
    const id = pos[0] || die('give an asset id'), res = flag('res', '1k');
    const f = await json(`https://api.polyhaven.com/files/${id}`);
    const dir = path.join(OUT, 'polyhaven');
    const log = (file, kind) => credit(file, { source: 'polyhaven', id, kind, license: 'CC0', url: `https://polyhaven.com/a/${id}` });
    if (f.hdri) { const u = f.hdri[res]?.hdr?.url || die('no such hdri res'); const file = path.join(dir, `${id}_${res}.hdr`); await save(u, file); log(file, 'hdri'); return console.log('wrote', path.relative(ROOT, file)); }
    if (f.gltf) {
      const g = f.gltf[res]?.gltf || die('no such model res');
      const base = path.join(dir, id);
      await save(g.url, path.join(base, `${id}.gltf`));
      for (const [rel, inc] of Object.entries(g.include || {})) await save(inc.url, path.join(base, rel));
      log(path.join(base, `${id}.gltf`), 'model');
      return console.log('wrote', path.relative(ROOT, base));
    }
    const maps = Object.entries(f).filter(([, v]) => v && v[res]?.jpg);
    if (!maps.length) die('nothing at that res');
    for (const [m, v] of maps) await save(v[res].jpg.url, path.join(dir, id, `${id}_${m}_${res}.jpg`));
    log(path.join(dir, id, id), 'textures');
    return console.log('wrote', path.relative(ROOT, path.join(dir, id)), maps.map(([m]) => m).join(' '));
  }
  die('polyhaven search|get');
}

async function tts(url, headers, body) {
  const out = flag('out') || die('--out file.mp3');
  const r = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', ...headers }, body: JSON.stringify(body) });
  if (!r.ok) die(`${r.status} ${await r.text()}`);
  fs.mkdirSync(path.dirname(path.resolve(out)), { recursive: true });
  fs.writeFileSync(out, Buffer.from(await r.arrayBuffer()));
  console.log('wrote', out, body.format === 'wav' ? '' : '(.mp3 cannot be played by Godot: convert to .wav before shipping)');
}

async function main() {
  if (api === 'status') {
    for (const n of ['SKETCHFAB_API_TOKEN', 'GEMINI_API_KEY', 'FISH_API_KEY', 'ELEVENLABS_API_KEY']) {
      const found = process.env[n] || ENV_FILES.some((f) => fs.existsSync(f) && new RegExp(`^${n}=.+`, 'm').test(fs.readFileSync(f, 'utf8')));
      console.log(n.padEnd(22), found ? 'found' : 'MISSING');
    }
    return console.log('JS devtools:', path.join(JS_ROOT, 'devtools/assets.mjs'));
  }
  if (api === 'sketchfab') return sketchfab();
  if (api === 'polyhaven') return polyhaven();
  if (api === 'gemini' && verb === 'tts') {
    // Gemini 3.1 Flash TTS (user, 2026-11-16): the voice API for dialogue. It reads a director's prompt, so a character
    // description in --style plus inline audio tags in the line ([whispers], [laughs], [sighs], [shouting], [sarcastically]...)
    // carry the emotion. It answers raw 24 kHz 16-bit mono PCM, written straight out as a .wav Godot can play.
    const out = flag('out') || die('--out file.wav');
    const text = pos[0] || die('give the text');
    const style = flag('style');
    const model = flag('model', 'gemini-3.1-flash-tts-preview');
    // 3.1 takes the style as plain text above the transcript and never speaks it. 3.8 reads that layout aloud (and refuses a
    // systemInstruction), so it gets "notes": a header that says the notes are direction only.
    const layout = flag('layout', model.includes('3.1') ? 'inline' : 'notes');
    const prompt = !style ? text : layout === 'notes'
      ? `Perform the transcript below as a voice actor. The director's notes are direction only: do not read them aloud.\n\n### DIRECTOR'S NOTES\n${style}\n\n#### TRANSCRIPT\n${text}`
      : `${style}\n\n#### TRANSCRIPT\n${text}`;
    const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'x-goog-api-key': key('GEMINI_API_KEY') },
      body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }], generationConfig: { responseModalities: ['AUDIO'],
        speechConfig: flag('speakers') ? { multiSpeakerVoiceConfig: { speakerVoiceConfigs: flag('speakers').split(',').map((kv) => {
          const [speaker, voiceName] = kv.split('=');
          return { speaker: speaker.trim(), voiceConfig: { prebuiltVoiceConfig: { voiceName: voiceName.trim() } } };
        }) } } : { voiceConfig: { prebuiltVoiceConfig: { voiceName: flag('voice', 'Charon') } } } } }),
    });
    if (!r.ok) die(`${r.status} ${await r.text()}`);
    const part = (await r.json()).candidates?.[0]?.content?.parts?.find((p) => p.inlineData);
    const pcm = Buffer.from(part?.inlineData?.data || die('no audio in the answer'), 'base64');
    const rate = +(/rate=(\d+)/.exec(part.inlineData.mimeType || '')?.[1] || 24000);
    const head = Buffer.alloc(44);
    head.write('RIFF', 0); head.writeUInt32LE(36 + pcm.length, 4); head.write('WAVEfmt ', 8); head.writeUInt32LE(16, 16);
    head.writeUInt16LE(1, 20); head.writeUInt16LE(1, 22); head.writeUInt32LE(rate, 24); head.writeUInt32LE(rate * 2, 28);
    head.writeUInt16LE(2, 32); head.writeUInt16LE(16, 34); head.write('data', 36); head.writeUInt32LE(pcm.length, 40);
    fs.mkdirSync(path.dirname(path.resolve(out)), { recursive: true });
    fs.writeFileSync(out, Buffer.concat([head, pcm]));
    return console.log('wrote', out, `(${(pcm.length / rate / 2).toFixed(1)} s, ${model}, ${flag('speakers') ? 'speakers ' + flag('speakers') : 'voice ' + flag('voice', 'Charon')})`);
  }
  if (api === 'fish' && verb === 'tts') {
    // Same call as the JS game's build-*-voice scripts: model s2.1-pro-free, default voice "ogre" (deep, raspy, slow).
    return tts('https://api.fish.audio/v1/tts', { Authorization: `Bearer ${key('FISH_API_KEY')}`, model: 's2.1-pro-free' },
      { text: pos[0] || die('give the text'), format: /\.wav$/i.test(flag('out') || '') ? 'wav' : 'mp3', /* --out x.wav asks Fish for WAV */ reference_id: flag('voice', '0b52f6e3ef62456595d94f899433f09e'), prosody: { speed: +flag('speed', 1), volume: 0 } });
  }
  if (api === 'eleven' && verb === 'tts') {
    const voice = flag('voice') || die('--voice <id>');
    return tts(`https://api.elevenlabs.io/v1/text-to-speech/${voice}`, { 'xi-api-key': key('ELEVENLABS_API_KEY') }, { text: pos[0] || die('give the text'), model_id: 'eleven_multilingual_v2' });
  }
  if (api === 'js') {
    const r = spawnSync('node', [path.join(JS_ROOT, 'devtools/assets.mjs'), verb, ...rest], { stdio: 'inherit', cwd: JS_ROOT });
    process.exit(r.status ?? 1);
  }
  console.log(fs.readFileSync(fileURLToPath(import.meta.url), 'utf8').split('\n').filter((l) => l.startsWith('//')).map((l) => l.slice(3)).join('\n'));
}
await main();
