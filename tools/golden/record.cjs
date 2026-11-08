// Records what the three.js game's real Player and CameraRig do on the movement test ground (buildArena) for tools/golden/scenarios.json,
// at a fixed 60 fps: node tools/golden/record.cjs -> tools/golden/golden.json. The Godot port replays the same input: tools/golden/replay.gd.
const fs = require('node:fs'), path = require('node:path');
const JS = path.resolve(__dirname, '../../../progalpha-20261016T082732Z-1-001/progalpha');
const { boot } = require(path.join(JS, 'tests/lib/level-harness.cjs'));

(async () => {
  const scenarios = JSON.parse(fs.readFileSync(path.join(__dirname, 'scenarios.json'), 'utf8'));
  const h = await boot('jetpack-yard', { god: false, patch: { 'index.html': (s) => s.replace('function frame(now) {', 'window.__port = { Player, World, buildArena, CONFIG, CameraRig, BUTTONS };\nfunction frame(now) {') } });
  const out = await h.page.evaluate((scenarios) => {
    const { Player, buildArena, CameraRig, BUTTONS, CONFIG } = window.__port;
    const snapshot = JSON.parse(JSON.stringify(CONFIG));
    const defaults = { jetFuel: 0, poleSwing: 0, wallRun: 0 };
    Object.assign(CONFIG, defaults);
    const world = buildArena();
    const res = {};
    const input = { btn: {}, move: { x: 0, y: 0, mag: 0 }, lookDelta: { yaw: 0, pitch: 0 }, lookActive: false, lookTight: false, sub: { btn: {}, move: null, lookDelta: null, lookActive: false } };
    for (const n of BUTTONS) { input.btn[n] = { held: false, pressed: false, released: false, value: 0 }; input.sub.btn[n] = { held: false, pressed: false, released: false, value: 0 }; }
    input.sub.move = input.move; input.sub.lookDelta = input.lookDelta;
    const dt = 1 / 60;
    for (const sc of scenarios) {
      for (const n of BUTTONS) { const o = input.btn[n]; o.held = o.pressed = o.released = false; o.value = 0; const s = input.sub.btn[n]; s.held = s.pressed = s.released = false; s.value = 0; }
      input.move.x = input.move.y = input.move.mag = 0;
      world.spawn = { x: sc.start[0], y: sc.start[1], z: sc.start[2], yaw: sc.start[3] };
      const p = new Player(world), rig = new CameraRig(world);
      p.reset(); rig.snapTo(p);
      const rows = [];
      let f = 0;
      for (const [dur, st] of sc.steps) {
        const n = Math.round(dur * 60), hold = st.hold || [], mv = st.move || [0, 0], lk = st.look || [0, 0];
        for (let i = 0; i < n; i++) {
          const m = Math.min(1, Math.hypot(mv[0], mv[1]));
          input.move.x = mv[0]; input.move.y = mv[1]; input.move.mag = m;
          for (const b of BUTTONS) {
            const o = input.btn[b], held = hold.includes(b), prev = o.held;
            o.held = held; o.pressed = held && !prev; o.released = !held && prev; o.value = held ? 1 : 0;
            const s = input.sub.btn[b]; s.held = held; s.value = o.value;
          }
          input.lookDelta.yaw = lk[0]; input.lookDelta.pitch = lk[1]; input.lookActive = lk[0] !== 0 || lk[1] !== 0; input.sub.lookActive = input.lookActive;
          p.update(dt, input, rig.yaw);
          rig.update(dt, input, p);
          p.events.length = 0;
          rows.push([p.x, p.y, p.z, p.yaw, p.vx, p.vy, p.vz, p.grounded ? 1 : 0, p.mode, p.flip, rig.pos.x, rig.pos.y, rig.pos.z, rig.yaw, rig.pitch, rig.look.x, rig.look.y, rig.look.z].map((v) => typeof v === 'number' ? +v.toFixed(5) : v));
          f++;
        }
      }
      res[sc.name] = rows;
    }
    Object.assign(CONFIG, snapshot);
    return res;
  }, scenarios);
  fs.writeFileSync(path.join(__dirname, 'golden.json'), JSON.stringify(out));
  console.log('recorded', Object.keys(out).length, 'scenarios', fs.statSync(path.join(__dirname, 'golden.json')).size, 'bytes');
  await h.close();
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
