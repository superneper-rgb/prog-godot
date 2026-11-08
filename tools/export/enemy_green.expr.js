// What tools/export/export.mjs object evaluates to export a green alien (replace __OUTFIT__ with goth, grunge or punk first): the view of enemies/green-alien-view.js with every part it animates named J_<name>, the same joints as enemy_alien.expr.js.
(async () => {
  const { createGrayAlienNPC } = await import(new URL('enemies/gray-alien-npc.js', location.href).href);
  const a = createGrayAlienNPC({}, { green: true, outfit: '__OUTFIT__', merge: false, pose: 'idle' }), v = a.view;
  for (const k of Object.keys(v.J)) v.J[k].name = 'J_' + k;
  v.belly.name = 'J_belly'; v.gun.name = 'J_gun'; v.palm.name = 'J_palm'; v.palmRing.name = 'J_palmRing'; v.orbit.name = 'J_orbit'; v.muzzleObj.name = 'J_muzzle'; v.mouthHole.name = 'J_mouthHole';
  v.motes.forEach((m, i) => { m.name = 'J_mote' + i; });
  for (const s of ['L', 'R']) { v.fingers[s].forEach((f, i) => { f.base.name = `J_f${s}${i}b`; f.mid.name = `J_f${s}${i}m`; }); v.fingers[s + 'T'].name = 'J_f' + s + 'T'; }
  for (const o of [v.bar, v.puddle, ...v.eyeGlow, v.muzSprite, v.gunGlow, v.palmGlow, ...v.sprites]) if (o && o.parent) o.parent.remove(o);
  v.g.position.set(0, 0, 0); v.g.rotation.set(0, 0, 0); v.g.scale.set(1, 1, 1); v.g.updateMatrixWorld(true);
  return v.g;
})()
