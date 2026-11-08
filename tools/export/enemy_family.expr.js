// What tools/export/export.mjs object evaluates in the JS game to export one kind of the gray family (replace __KIND__ first): a live view with its merge undone and every part the view animates named J_<name>, so each stays a separate node. See enemy_alien.expr.js for the alien itself.
(() => {
  const KIND = '__KIND__';
  const g = window.__game, r = g.spawnEnemy({ x: 0, y: -400, z: 0, yaw: 0 }, { kind: KIND, noRespawn: true }), v = g.fx.botById[r.id];
  if (r._disposeRobotVisuals) { r._disposeRobotVisuals(); r._disposeRobotVisuals = null; }
  v.update = () => {}; r.update = () => {};      // held still: the export reads parents and children at different moments
  const drop = (o) => { if (o && o.parent) o.parent.remove(o); };
  // JS wetSkin keeps its rim and vein glow in a closure: ask it, then hand them over as a plain emissive and a name creature_model.gd reads (wet_<sss>_<strength %>_<glow source>)
  const wet = (root) => root.traverse((o) => { const m = o.material; if (!m || m._wetDone || !m.customProgramCacheKey || !/wetSkin/.test(m.customProgramCacheKey())) return; m._wetDone = true;
    const sh = { uniforms: {}, fragmentShader: '', vertexShader: '' }; m.onBeforeCompile(sh); const u = sh.uniforms;
    if (u.uGlowMap) { m.emissiveMap = u.uGlowMap.value; m.emissive = u.uGlowC.value.clone(); m.emissiveIntensity = 1; }
    m.name = 'wet_' + u.uSssC.value.getHexString() + '_' + Math.round(u.uSssK.value * 100) + '_' + (u.uGlowMap ? 1 : 0); delete m.onBeforeCompile; });
  if (KIND === 'tommygun' || KIND === 'buttonman') {           // the alien's body with its own hat and gun: the same joints as enemy_alien.expr.js
    for (const k of Object.keys(v.J)) v.J[k].name = 'J_' + k;
    v.belly.name = 'J_belly'; v.gun.name = 'J_gun'; v.palm.name = 'J_palm'; v.palmRing.name = 'J_palmRing'; v.orbit.name = 'J_orbit'; v.muzzleObj.name = 'J_muzzle'; v.mouthHole.name = 'J_mouthHole';
    v.motes.forEach((m, i) => { m.name = 'J_mote' + i; });
    for (const s of ['L', 'R']) { v.fingers[s].forEach((f, i) => { f.base.name = `J_f${s}${i}b`; f.mid.name = `J_f${s}${i}m`; }); v.fingers[s + 'T'].name = 'J_f' + s + 'T'; }
    for (const c of v.gun.children.slice()) if (!c.visible) drop(c);                   // the pistol he swapped for this gun
    for (const o of [v.bar, v.puddle, ...v.eyeGlow, v.muzSprite, v.gunGlow, v.palmGlow, ...v.sprites]) drop(o);
  } else if (KIND === 'butler') {
    v.eyeMat.name = 'butlerEye';
    v.body.name = 'J_body'; v.arm.name = 'J_arm'; v.tray.name = 'J_tray'; v.cloche.name = 'J_cloche'; v.probe.name = 'J_probe'; v.muz.name = 'J_muz';
    for (const o of [v.bar, v.eyeGlow, v.thruster, v.probeGlow]) drop(o);
    v.probe.visible = true;
  } else if (KIND === 'consigliere') {
    v.body.name = 'J_body'; v.ring.name = 'J_ring';
    v.body.children.forEach((c) => { if (c.material && c.material.blending === 2 && c.isMesh) c.name = 'J_liquid'; });      // the additive fluid draws in the glow layer
    for (const o of [v.bar, v.glow]) drop(o);
  } else if (KIND === 'brute') {
    wet(v.g); v.boneM.name = 'glow_2'; v.boneM.emissiveIntensity = 1;
    v.body.name = 'J_body'; v.torso.name = 'J_torso'; v.shield.name = 'J_shield'; v.plates[-1].name = 'J_plateL'; v.plates[1].name = 'J_plateR';
    v.legs.forEach((L, i) => { L.th.name = 'J_th' + i; L.sh.name = 'J_sh' + i; L.hoof.name = 'J_hoof' + i; });
    v.arms.forEach((A, i) => { A.u.name = 'J_u' + i; A.f.name = 'J_f' + i; A.hand.name = 'J_hand' + i; });
    v.heads.forEach((H, i) => { H.h.name = 'J_head' + i; H.jaw.name = 'J_jaw' + i; H.eyes.forEach((e, k) => { e.name = 'J_eye' + i + k; }); });
    v.eyeMats.forEach((m) => { m.name = 'bruteEye'; });
    const seen = {}; v.ribs.forEach((rb) => { rb.m.name = 'J_rib' + (rb.sx < 0 ? 0 : 1) + rb.i; });
    for (const o of [v.hb.bar, ...v.spineGlow, v.backGlow, ...v.sprites]) drop(o);
  } else if (KIND === 'crawler') {
    wet(v.g); v.eyeMat.name = 'glow_2'; v.eyeMat.emissive.setRGB(1, 0, 0.01); v.eyeMat.emissiveIntensity = 1;
    v.body.name = 'J_body'; v.head.name = 'J_head'; v.muzzleObj.name = 'J_muzzle';
    v.segs.forEach((S2, i) => { S2.s.name = 'J_s' + i; S2.legs.forEach((L) => { L.pv.name = 'J_p' + i + (L.sx < 0 ? 0 : 1); }); });
    v.mand.forEach((M) => { M.m.name = 'J_mand' + (M.sx < 0 ? 0 : 1); });
    for (const o of [v.hb.bar, v.ring, v.mouthGlow, ...v.sprites]) drop(o);
  } else if (KIND === 'spore') {
    v.sac.name = 'J_sac'; v.core.name = 'J_core';
    v.notes.forEach((N, i) => { N.n.name = 'J_note' + i; });
    v.tails.forEach((T, i) => T.segs.forEach((j, k) => { j.name = 'J_t' + i + k; }));
    for (const o of [v.hb.bar, v.coreGlow, ...v.sprites]) drop(o);
  } else if (KIND === 'tongue') {
    for (const c of v.wall.children.slice()) v.wall.remove(c); drop(v.wall);      // the slab: only a dev spawn shows it
    wet(v.g);
    v.flashMats.forEach((m, i) => { if (i < 3) m.emissive.setRGB(0.09, 0.0495, 0.045); });      // the JS sets this faint warm self-glow every frame
    v.flashMats[0].name += '_fleshTex';
    v.torso.name = 'J_torso'; v.head.name = 'J_head'; v.jaw.name = 'J_jaw'; v.mouthPt.name = 'J_mouthPt'; v.tip.name = 'J_tip';
    v.drips.forEach((d, i) => { d.name = 'J_drip' + i; });
    for (const o of [v.tongueMesh, v.aim, v.hb.bar, v.tipGlow, ...v.sprites]) drop(o);
  } else if (KIND === 'mimic') {
    v.irisM.name = 'glow_2'; v.irisM.emissive.setRGB(1, 0.055, 0.11); v.irisM.emissiveIntensity = 1;
    v.body.name = 'J_body'; v.jawA.name = 'J_jawA'; v.jawB.name = 'J_jawB'; v.lid.name = 'J_lid'; v.tongue.name = 'J_tongue'; v.muzzleObj.name = 'J_muzzle';
    v.teeth.forEach((m, i) => { m.name = 'J_tooth' + i; });
    for (const o of [v.hb.bar, v.mouthGlow, ...v.sprites]) drop(o);
  } else if (KIND === 'scream') {
    wet(v.g);
    v.box.name = 'J_box'; v.mouthG.name = 'J_mouthG'; v.door.name = 'J_door'; v.flag.name = 'J_flag'; v.bladder.name = 'J_bladder'; v.spit.name = 'J_spit'; v.muzzleObj.name = 'J_muzzle';
    v.drips.forEach((d, i) => { d.name = 'J_drip' + i; });
    // the parts the JS rewrites by hand are rebuilt in enemies/maw_views.gd: only their materials are needed, from what is left
    const inst = v.legInst; v.bladder.material.name += '_nestFlesh'; v.door.children[0].material.name += '_nestDark';
    inst[2].im.material.name = 'nestBone';
    v.tongueMesh.material.name = 'nestTongue';
    const tongueStandIn = new v.tongueMesh.constructor(new window.__game.THREE.BoxGeometry(0.001, 0.001, 0.001), v.tongueMesh.material); tongueStandIn.name = ''; v.box.add(tongueStandIn);
    for (const o of [v.tongueMesh, v.bar, v.mouthGlow, ...v.sprites, ...inst.map((e) => e.im)]) drop(o);
    for (const L of v.legs) for (const k of ['up', 'lo', 'kn', 'hp', 'claw', 'ball']) drop(L[k]);
    if (!v.spit.visible) v.spit.visible = true;
  } else if (KIND === 'prophet') {
    wet(v.g);
    v.muscleM.name = v.muscleM.name;
    const J = v.J; for (const k of ['fall', 'hips', 'spine', 'shL', 'elL', 'hdL', 'shR', 'elR', 'hdR']) J[k].name = 'J_' + k;
    v.mouth.name = 'J_mouth'; v.cavity.name = 'J_cavity'; v.crown.name = 'J_crown'; v.cleaver.name = 'J_cleaver'; v.hand.name = 'J_hand'; v.thumb.name = 'J_thumb'; v.muzzleObj.name = 'J_muzzle'; v.glob.name = 'J_glob'; v.glob.material.opacity = 0.95;
    v.lips.forEach((L, i) => { L.name = 'J_lip' + i; });
    v.eyes.forEach((e, i) => { e.eg.name = 'J_eg' + i; e.eye.name = 'J_eye' + i; e.lid.name = 'J_lid' + i; });
    v.tatters.forEach((T, i) => { T.tg.name = 'J_tg' + i; T.tg.children[0].name = 'J_tat' + i; });
    v.ribs.forEach((r2, i) => { r2.rg.name = 'J_rib' + i; });
    v.fingers.forEach((f, i) => { f.f1.name = 'J_f1_' + i; f.f2.name = 'J_f2_' + i; });
    v.cords.forEach((c, i) => c.links.forEach((L, k) => { L.name = 'J_cord' + i + '_' + k; }));
    for (const o of [v.bar, v.puddle, v.throatGlow, v.crownGlow, v.sauceGlow, v.summonGlow, ...v.sprites]) drop(o);
  } else if (KIND === 'follower') {
    v.J.fall.name = 'J_fall'; v.J.hips.name = 'J_hips'; v.J.spine.name = 'J_spine'; v.maw.name = 'J_maw';
    v.teeth.forEach((r2, i) => { r2.name = 'J_ring' + i; });
    v.legs.forEach((L, i) => { L.hip.name = 'J_hip' + i; L.up.name = 'J_up' + i; L.lo.name = 'J_lo' + i; L.k2.name = 'J_k2' + i; });
    v.cord.forEach((L, i) => { L.name = 'J_cord' + i; });
    for (const o of [v.bar, v.puddle]) drop(o);
  } else if (KIND === 'warden') {
    wet(v.g);
    v.boneM.name = 'glow_2'; v.boneM.emissiveIntensity = 1; v.plateM.name = 'glow_2'; v.plateM.emissiveIntensity = 1; v.plateM.emissive.setRGB(1, 0.32, 0.06); v.boneM.emissive.setRGB(1, 0.32, 0.06);
    v.heartM.name = 'glow_3'; v.heartM.emissiveIntensity = 1; v.bileM.name = 'glow_4'; v.bileM.emissiveIntensity = 1;
    v.emberM.name = 'wardenEmber'; v.sacM.emissive.setRGB(0.25, 0.02, 0.04);
    v.body.name = 'J_body'; v.abd.name = 'J_abd'; v.head.name = 'J_head'; v.block.name = 'J_block'; v.jaw.name = 'J_jaw'; v.throat.name = 'J_throat'; v.well.name = 'J_well'; v.heart.name = 'J_heart'; v.cage[-1].name = 'J_cageL'; v.cage[1].name = 'J_cageR'; v.sweepG.name = 'J_sweepG'; v.smear.name = 'J_smear'; v.muzzleObj.name = 'J_muzzle';
    v.bands.forEach((m, i) => { m.name = 'J_band' + i; });
    v.legs.forEach((L, i) => { L.hip.name = 'J_hip' + i; L.knee.name = 'J_knee' + i; });
    v.eyes.forEach((m, i) => { m.name = 'J_eye' + i; });
    v.tusks.forEach((m, i) => { m.name = 'J_tusk' + i; });
    v.mands.forEach((M) => { M.piv.name = 'J_mand' + (M.sx < 0 ? 0 : 1); });
    v.ribs.forEach((rb) => { rb.m.name = 'J_rib' + (rb.sx < 0 ? 0 : 1) + rb.i; });
    v.spines.forEach((m, i) => { m.name = 'J_spine' + i; });
    v.sacs.forEach((m, i) => { m.name = 'J_sac' + i; });
    v.sweepG.visible = true; v.smear.visible = true;
    for (const o of [v.hb.bar, v.deco, v.emberGlow, v.wellGlow, ...v.sprites]) drop(o);
  } else if (KIND === 'spider') {                                   // buildSpiderView keeps its parts in a closure: the group's order is the build order
    const kids = v.g.children, hull = kids[0]; hull.name = 'J_hull'; v.muzzleObj.name = 'J_muzzle';
    hull.children.filter((c) => c.material && c.material.isMeshBasicMaterial).forEach((m, i) => { m.name = 'J_eye' + i; m.material.name = 'spiderEye'; });
    const part = ['p0', 'p1', 'p2', 'armor', 'hip', 'knee', 'foot'];
    for (let i = 1; i < kids.length; i++) { const k = i - 1; kids[i].name = 'J_L' + Math.floor(k / 7) + '_' + part[k % 7]; }
  } else if (KIND === 'muscle') {
    for (const k of Object.keys(v.J)) v.J[k].name = 'J_' + k;
    v.core.name = 'J_core'; v.coreMat.name = 'muscleCore';
    for (const o of [v.bar, v.coreGlow, ...v.stacks]) drop(o);
  }
  v.g.position.set(0, 0, 0); v.g.rotation.set(0, 0, 0); v.g.scale.set(1, 1, 1); v.g.updateMatrixWorld(true);
  return v.g;
})()
