// What tools/export/export.mjs object evaluates in the JS game to export a FOINT goon's kit (replace __WHAT__ first): gun_pistol, gun_smg, gun_acid, or dress_goint_guard, dress_goint_adjuster: a guard's or adjuster's pieces, grouped per bone
(async () => {
  const WHAT = '__WHAT__', g = window.__game, gunKind = WHAT.startsWith('gun_') ? WHAT.slice(4) : '';
  const costume = gunKind === 'acid' ? 'hazmat' : gunKind ? 'goint_guard' : WHAT.slice(6);
  // (VISITING HOURS' suits are not a costume the AI spawns: a GoonView without its AI, as levels/visiting-hours/people.js makes them)
  let v;
  if (['goint_suit', 'goint_undertaker', 'goint_warden'].includes(costume)) {
    const { createGoonView } = await import(new URL('enemies/foint-goon-view.js', location.href).href);
    const GV = createGoonView({ CONFIG: {}, clamp: (x, a, b) => Math.max(a, Math.min(b, x)), acidState: {} }).GoonView;
    v = new GV({ id: 7, x: 0, y: -400, z: 0, yaw: 0, costume, role: 'security', gun: 'pistol', h: 1.6, hp: 1, max: 1, state: 'idle', onBreak: false, drag: 0, flashlight: false });
  } else {
    const r = g.spawnEnemy({ x: 0, y: -400, z: 0, yaw: 0 }, { kind: 'goon', costume, gun: gunKind && gunKind !== 'acid' ? gunKind : 'smg', noRespawn: true });
    v = g.fx.botById[r.id]; r.update = () => {};
  }
  for (let i = 0; i < 600 && !v.ready; i++) await new Promise((f) => setTimeout(f, 50));
  if (!v.ready) throw new Error('goon not ready');
  v.update = () => {};
  const Group = v.g.constructor, out = new Group();
  if (gunKind) {                                                                  // the gun at its own origin, the flashlight (a guard's) in its own group, without the beam: the port draws that
    const G = v.gun.g, D = v.dress;
    v.gun.lamp.name = 'gunLamp';
    if (D && D.torch) { D.torch.g.name = 'J_torch'; D.torch.origin.parent.remove(D.torch.origin); }
    G.position.set(0, 0, 0); G.quaternion.identity(); G.updateMatrix(); out.add(G);
  } else {
    const D = v.dress, fo = new Map(D.follows.map((f) => [f.o, f])), key = (n) => n.replace('.', '_');
    for (const n of v.bones) {
      const h = new Group(); h.name = 'J_' + key(n);
      for (const c of v.B[n].children.slice()) {
        if (c.isBone || c === D.badge) continue;
        const f = fo.get(c); if (f) c.name = `Fo_${key(f.bone)}__${key(f.follow)}__${Math.round(f.k * 1000)}`;
        h.add(c);
      }
      if (h.children.length) out.add(h);
    }
    const mark = (bone, name, p) => { let h = out.children.find((o) => o.name === 'J_' + bone); if (!h) { h = new Group(); h.name = 'J_' + bone; out.add(h); } const e = new Group(); e.name = name; e.position.copy(p); h.add(e); };
    if (D.badge) mark('head', 'P_badge', D.badge.position);
    if (D.core) { mark('chest', 'P_core', D.core); mark('chest', 'P_coreN', D.core.clone().add(D.coreN)); }
  }
  out.updateMatrixWorld(true);
  return out;
})()
