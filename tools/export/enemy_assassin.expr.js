// What tools/export/export.mjs object evaluates to export the Night Assassin: a live view with every joint it animates named J_<name>, its sprites and health bar left out (the batch draws those)
(() => {
  const g = window.__game, r = g.spawnEnemy({ x: 0, y: -400, z: 0, yaw: 0 }, { kind: 'assassin', noRespawn: true }), v = g.fx.botById[r.id];
  v.update = () => {}; r.update = () => {};      // held still: the export reads parents and children at different moments
  for (const k of Object.keys(v.J)) v.J[k].name = 'J_' + k;
  v.handKnife.name = 'J_handKnife'; v.sheathKnife.name = 'J_sheathKnife'; v.muz.name = 'J_muz'; v.gun.name = 'J_gun';
  v.tails.forEach((t, i) => { t.name = 'J_tail' + i; });
  v.lensMat.name = 'assassinLens'; v.handKnife.visible = true;
  for (const o of [v.bar, ...v.sprites]) if (o && o.parent) o.parent.remove(o);
  v.g.position.set(0, 0, 0); v.g.rotation.set(0, 0, 0); v.g.scale.set(1, 1, 1); v.g.updateMatrixWorld(true);
  return v.g;
})()
