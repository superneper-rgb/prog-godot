// Draft a Godot shader from an exported three.js ShaderMaterial: node tools/export/port_shader.mjs <level> <shader name> [--dome] [--force]
// Writes levels/shaders/<name>.gdshader. It does the mechanical part (syntax, built-ins, render modes, how the colour reaches the frame); the result is a hand port's first draft, so read it and look at it in the game.
// Per-point attributes arrive in CUSTOM0.. in alphabetical order, and a point's corner in UV (ShaderPorts._expand builds that mesh): add the shader to ShaderPorts.EXPANDED.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const [level, name, ...flags] = process.argv.slice(2);
const dome = flags.includes('--dome'), force = flags.includes('--force');
const j = JSON.parse(fs.readFileSync(path.join(ROOT, 'assets/levels', level, 'shaders', name + '.json'), 'utf8'));
const out = path.join(ROOT, 'levels/shaders', name + '.gdshader');
if (fs.existsSync(out) && !force) { console.log('exists, skipped (--force to redo): ' + name); process.exit(0); }

const STD = ['position', 'normal', 'uv', 'uv1', 'color'];
const customs = [...new Set(j.attributes || [])].filter((a) => !STD.includes(a)).sort();
if (customs.length > 4) { console.log('more than 4 per-point attributes, write by hand: ' + name); process.exit(2); }
const isPoints = /gl_PointSize|gl_PointCoord/.test(j.vertexShader + j.fragmentShader);

const stripComments = (s) => s.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/\/\/[^\n]*/g, '');
const toneMapped = /<tonemapping_fragment>/.test(j.fragmentShader), fogged = /<fog_fragment>/.test(j.fragmentShader), encoded = /<colorspace_fragment>/.test(j.fragmentShader);

/** the body of main(), and everything around it */
function split(src) {
  const m = /void\s+main\s*\(\s*(?:void)?\s*\)\s*\{/.exec(src);
  if (!m) throw new Error('no main()');
  let d = 1, i = m.index + m[0].length;
  for (; i < src.length && d; i++) { if (src[i] === '{') d++; else if (src[i] === '}') d--; }
  return { head: src.slice(0, m.index) + src.slice(i), body: src.slice(m.index + m[0].length, i - 1) };
}
const defines = {};
const V = split(stripComments(j.vertexShader)), F = split(stripComments(j.fragmentShader));
const clean = (s) => s.replace(/#include\s*<[^>]+>/g, '').replace(/precision\s+\w+\s+\w+\s*;/g, '').replace(/#define\s+(\w+)\s+([^\n]*)/g, (a, k, v) => { defines[k] = v.trim(); return ''; });

/** top-level statements: uniforms, varyings, consts, functions. Split so the vertex and fragment copies can be merged. */
function items(src) {
  const out = []; let cur = '', depth = 0;
  for (const ch of src) {
    cur += ch;
    if (ch === '{') depth++;
    else if (ch === '}') { depth--; if (depth === 0) { out.push(cur.trim()); cur = ''; } }
    else if (ch === ';' && depth === 0) { out.push(cur.trim()); cur = ''; }
  }
  return out.filter(Boolean);
}
const decls = [], seen = new Set();
const add = (t) => { const k = t.replace(/\s+/g, ' '); if (!seen.has(k)) { seen.add(k); decls.push(t); } };
const uni = j.variants?.[0] || j.uniforms || {};
const usesTime = new Set();
const attrTypes = {};
for (const it of [...items(clean(V.head)), ...items(clean(F.head))]) {
  const m = /^(uniform|varying|attribute)\s+(?:(?:highp|mediump|lowp)\s+)?(\w+)\s+([^;]+);$/.exec(it);
  if (!m) { add(it); continue; }
  for (const raw of m[3].split(',')) {
    const nm = raw.trim();
    if (m[1] === 'varying') { add(`varying ${m[2]} ${nm};`); continue; }
    if (m[1] === 'attribute') { attrTypes[nm] = m[2]; continue; }
    const base = nm.replace(/\[.*/, '');
    if (/^(uTime|time)$/.test(base)) { usesTime.add(base); continue; }      // the engine's clock
    if (base === 'uCam' || base === 'uH') continue;      // the camera and the viewport height, which the JS level passes in every frame: the engine has both
    if (m[2] === 'sampler2D') {
      const srgb = uni[base]?.srgb !== false && !/mask|noise|rip|height|normal|data|light/i.test(base);
      add(`uniform sampler2D ${nm} : ${srgb ? 'source_color, ' : ''}repeat_enable, filter_linear_mipmap_anisotropic;`);
    } else add(`uniform ${m[2]} ${nm};`);
  }
}

/** GLSL to Godot's dialect, in either stage */
function dialect(s) {
  for (const t of usesTime) s = s.replace(new RegExp('\\b' + t + '\\b', 'g'), 'TIME');
  s = s.replace(/\buCam\b/g, 'CAMERA_POSITION_WORLD').replace(/\buH\b/g, 'VIEWPORT_SIZE.y').replace(/\binstanceMatrix\s*\*\s*/g, '');
  s = s.replace(/\btexture2D\b/g, 'texture')
    .replace(/\bcameraPosition\b/g, 'CAMERA_POSITION_WORLD')
    .replace(/\bmodelMatrix\b/g, 'MODEL_MATRIX').replace(/\bviewMatrix\b/g, 'VIEW_MATRIX').replace(/\bprojectionMatrix\b/g, 'PROJECTION_MATRIX').replace(/\bmodelViewMatrix\b/g, 'MODELVIEW_MATRIX');
  // Godot's constructors want floats: vec3(1, 0, 0)
  s = s.replace(/\b(vec[234])\(([^()]*)\)/g, (a, t, args) => `${t}(${args.replace(/(^|[,\s(*+\-/])(\d+)(?=\s*(?:,|$))/g, '$1$2.0')})`);
  return s;
}
let vb = clean(V.body), fb = clean(F.body);
customs.forEach((a, i) => { const sw = { float: '.x', vec2: '.xy', vec3: '.xyz', vec4: '' }[attrTypes[a] || 'vec4']; vb = vb.replace(new RegExp('\\b' + a + '\\b', 'g'), 'CUSTOM' + i + sw); });
if (isPoints) { vb = vb.replace(/\bgl_PointSize\s*=/g, 'px_ ='); vb = 'float px_ = 1.0;\n' + vb + '\nvPc_ = UV * vec2(0.5, -0.5) + 0.5;\nPOSITION.xy += UV * px_ / VIEWPORT_SIZE * POSITION.w;\n'; fb = fb.replace(/\bgl_PointCoord\b/g, 'vPc_'); decls.push('varying vec2 vPc_;'); }
vb = dialect(vb).replace(/\bnormalMatrix\s*\*\s*normal\b/g, '(MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz').replace(/\bposition\b/g, dome ? 'dome_p' : 'VERTEX').replace(/\bnormal\b/g, 'NORMAL').replace(/\buv\b/g, 'UV').replace(/\bcolor\b/g, 'COLOR.rgb').replace(/\bgl_Position\b/g, 'POSITION');
fb = dialect(fb).replace(/\bgl_FragColor\b/g, 'fc_').replace(/\bgl_FragCoord\b/g, 'FRAGCOORD');
if (dome) vb = 'vec3 dome_p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - uCenter;\n' + vb + '\nvec4 dome_c = PROJECTION_MATRIX * VIEW_MATRIX * vec4(CAMERA_POSITION_WORLD + dome_p, 1.0);\nPOSITION = vec4(dome_c.xy, 0.0, dome_c.w);\n';
else vb = vb.replace(/(\w+)\.xyww/g, 'vec4($1.xy, 0.0, $1.w)');      // on the far plane: 0 with Godot's reversed depth
// the default transform needs no line: a plain gl_Position line goes
vb = vb.replace(/POSITION\s*=\s*PROJECTION_MATRIX\s*\*\s*MODELVIEW_MATRIX\s*\*\s*vec4\(\s*VERTEX\s*,\s*1\.?0?\s*\)\s*;/g, '');

const add_ = j.blend === 'add', transparent = !!j.transparent;
let finish;
const disp = encoded ? 'srgb_encode(fc_.rgb)' : 'fc_.rgb';      // no tone map: the value is written straight to the screen, sRGB-encoded first if the shader asks for it
if (add_) finish = toneMapped ? 'ALBEDO = add_display(fc_.rgb, fc_.a);' : `ALBEDO = display_to_radiance(${disp} * fc_.a);`;      // three.js blends on the display value
else {
  finish = toneMapped ? 'ALBEDO = fc_.rgb;' : `ALBEDO = display_to_radiance(${disp});`;
  if (transparent) finish += '\n\tALPHA = fc_.a;';
}
const modes = ['unshaded', 'shadows_disabled'];
if (isPoints) modes.push('cull_disabled');
if (add_) modes.push('blend_add');
if (j.side === 'double') modes.push('cull_disabled'); else if (j.side === 'back') modes.push(dome ? 'cull_disabled' : 'cull_front');
if (j.depthWrite === false || dome) modes.push('depth_draw_never');
if (j.depthTest === false) modes.push('depth_test_disabled');
if (!fogged) modes.push('fog_disabled');

const uses = new Set((j.nodes || []).filter(Boolean));
const lines = [
  `// ${[...uses].slice(0, 3).join(', ') || name} (three.js ShaderMaterial, level ${level}). Drafted by tools/export/port_shader.mjs and checked by eye.`,
  'shader_type spatial;',
  `render_mode ${modes.join(', ')};`,
  '',
  '#include "res://levels/shaders/common.gdshaderinc"',
  '',
  ...Object.entries({ ...defines, ...(j.defines || {}) }).map(([k, v]) => `#define ${k} ${v}`),
  ...(dome ? ['uniform vec3 uCenter;'] : []),
  ...decls.map((d) => dialect(d)),
  '',
  'void vertex() {',
  ...vb.split('\n').map((l) => l.trim()).filter(Boolean).map((l) => '\t' + l),
  '}',
  '',
  'void fragment() {',
  '\tvec4 fc_ = vec4(0.0, 0.0, 0.0, 1.0);',
  ...fb.split('\n').map((l) => l.trim()).filter(Boolean).map((l) => '\t' + l),
  '\t' + finish,
  '}',
  '',
];
fs.writeFileSync(out, lines.join('\n'));
console.log('wrote ' + name + (toneMapped ? '' : ' (no tone map)') + (add_ ? ' (add)' : ''));
