// What tools/export/export.mjs object evaluates in the JS game to export the gray alien's model: a live AlienView with its merge undone and every part the view animates named, so each stays a separate node.
(() => {
  const g = window.__game, r = g.spawnEnemy({ x: 0, y: -400, z: 0, yaw: 0 }, { kind: 'alien', noRespawn: true }), v = g.fx.botById[r.id];
  if (r._disposeRobotVisuals) { r._disposeRobotVisuals(); r._disposeRobotVisuals = null; }
  v.update = () => {}; r.update = () => {};      // held still: the export reads parents and children at different moments
  for (const k of Object.keys(v.J)) v.J[k].name = 'J_' + k;
  v.belly.name = 'J_belly'; v.gun.name = 'J_gun'; v.palm.name = 'J_palm'; v.palmRing.name = 'J_palmRing'; v.orbit.name = 'J_orbit'; v.muzzleObj.name = 'J_muzzle'; v.mouthHole.name = 'J_mouthHole';
  v.motes.forEach((m, i) => { m.name = 'J_mote' + i; });
  for (const s of ['L', 'R']) { v.fingers[s].forEach((f, i) => { f.base.name = `J_f${s}${i}b`; f.mid.name = `J_f${s}${i}m`; }); v.fingers[s + 'T'].name = 'J_f' + s + 'T'; }
  // the sprites, the bar and the puddle are drawn by the batch's own layers
  for (const o of [v.bar, v.puddle, ...v.eyeGlow, v.muzSprite, v.gunGlow, v.palmGlow, ...v.sprites]) if (o && o.parent) o.parent.remove(o);
  v.g.position.set(0, 0, 0); v.g.rotation.set(0, 0, 0); v.g.scale.set(1, 1, 1); v.g.updateMatrixWorld(true);
  return v.g;
})()
