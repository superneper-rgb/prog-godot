// What tools/export/export.mjs object evaluates to export the Dirgeworm: a live view with every joint it animates named J_<name>, its instanced body turned into real parts on each segment, wetSkin's rim and glow handed over as a material name (see enemy_family.expr.js), its sprites and health bar left out (the batch draws those)
(() => {
  const g = window.__game, T = g.THREE, r = g.spawnEnemy({ x: 0, y: -400, z: 0, yaw: 0 }, { kind: 'worm', noRespawn: true }), v = g.fx.botById[r.id];
  v.update = () => {}; r.update = () => {};      // held still: the export reads parents and children at different moments
  // the head's veins follow the copy's glow A, the sacs' its glow B, the rest of the hide stays dark (its glow is never raised in the JS)
  const srcOf = (m) => (m === v.headM ? 1 : m === v.sacM ? 2 : 3);
  v.g.traverse((o) => { const m = o.material; if (!m || m._wetDone || !m.customProgramCacheKey || !/wetSkin/.test(m.customProgramCacheKey())) return; m._wetDone = true;
    const sh = { uniforms: {}, fragmentShader: '', vertexShader: '' }; m.onBeforeCompile(sh); const u = sh.uniforms;
    if (u.uGlowMap) { m.emissiveMap = u.uGlowMap.value; m.emissive = u.uGlowC.value.clone(); m.emissiveIntensity = 1; }
    m.name = 'wet_' + u.uSssC.value.getHexString() + '_' + Math.round(u.uSssK.value * 100) + '_' + (u.uGlowMap ? srcOf(m) : 0) + '_' + m.uuid.slice(0, 4); delete m.onBeforeCompile; });
  for (const { im, list } of v.inst) {
    const m0 = im.material;
    if (m0.customProgramCacheKey && /wetSkin/.test(m0.customProgramCacheKey()) && !m0._wetDone) { m0._wetDone = true; const sh = { uniforms: {}, fragmentShader: '', vertexShader: '' }; m0.onBeforeCompile(sh); const u = sh.uniforms;
      if (u.uGlowMap) { m0.emissiveMap = u.uGlowMap.value; m0.emissive = u.uGlowC.value.clone(); m0.emissiveIntensity = 1; }
      m0.name = 'wet_' + u.uSssC.value.getHexString() + '_' + Math.round(u.uSssK.value * 100) + '_' + (u.uGlowMap ? 3 : 0) + '_' + m0.uuid.slice(0, 4); delete m0.onBeforeCompile; }
    for (const e of list) { const m = new T.Mesh(im.geometry, m0); e.m.decompose(m.position, m.quaternion, m.scale); v.segs[e.i].pit.add(m); }
    v.g.remove(im);
  }
  v.segs.forEach((S, i) => { S.root.name = 'J_r' + i; S.pit.name = 'J_p' + i; S.root.visible = true; S.root.scale.setScalar(1); });
  v.tail.name = 'J_tail'; v.tail.visible = true; v.headRoot.name = 'J_headRoot'; v.headPit.name = 'J_headPit'; v.midNode.name = 'J_mid'; v.mouthObj.name = 'J_mouth';
  v.petals.forEach((p, i) => { p.name = 'J_pet' + i; });
  v.sacs.forEach((s, i) => { s.name = 'J_sac' + i; });
  v.sonic.forEach((s, i) => { s.name = 'J_sonic' + i; s.visible = true; s.material.opacity = 1; });
  v.throatGlow.parent.name = 'J_throat';
  for (const o of [v.bar, v.throatGlow, ...v.sacGlow, ...v.sprites]) if (o && o.parent) o.parent.remove(o);
  v.g.position.set(0, 0, 0); v.g.rotation.set(0, 0, 0); v.g.scale.set(1, 1, 1); v.g.updateMatrixWorld(true);
  return v.g;
})()
