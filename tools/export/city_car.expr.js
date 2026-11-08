// What tools/export/export.mjs object evaluates in the JS game to export one drivable FOINT CITY car (replace __KIND__ first; --level=hub): traffic.kit.makeModel with every moving part named for levels/hub/city_driving.gd. Its numbers (seat, door, wheels) go out with life.json (page.js, car_models).
(() => {
  const K = '__KIND__', T = window.__game.view.city.district.traffic, m = T.kit.makeModel(K, 0xffffff, 0);
  m.root.name = 'C_root'; m.chassis.name = 'C_chassis';
  const fix = m.chassis.children[0]; fix.name = 'C_fix';
  const names = ['C_paint', 'C_trim', 'C_glass', 'C_neon'];
  fix.children.slice(0, 4).forEach((o, i) => { o.name = names[i]; });
  for (const c of fix.children.slice()) if (c.isPoints) fix.remove(c);      // the lamps: Godot draws its own from the numbers
  if (m.pivotSteer) m.pivotSteer.name = 'C_steer';
  for (const c of fix.children) if (c.isGroup && c !== m.pivotSteer) { c.name = 'C_door'; c.children.forEach((o, i) => { o.name = ['C_door_paint', 'C_door_glass', 'C_door_trim'][i]; }); }
  m.wheels.forEach((w, i) => { w.pivot.name = 'C_pivot' + i; w.spin.name = 'C_spin' + i; });
  for (const c of m.root.children.slice()) if (c.isMesh) m.root.remove(c);      // the headlight pool: the traffic's own quad
  return m.root;
})()
