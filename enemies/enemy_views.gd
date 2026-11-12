class_name EnemyViews
extends RefCounted
## All the enemy views of the level being played (JS fx.bots / fx.botById for the robots). FX.update ticks them, as in the JS; this class makes them, hands FX the lists, and uploads the batches
## once all of them are posed. Each model kind is one RigidBatch: a view has only a row in it.

var bots: Array = []                 # RobotView / DroneView (JS fx.bots; FX holds the same list)
var bot_by_id: Dictionary = {}       # robot id -> view (JS fx.botById)
var _batches: Array[RigidBatch] = []
var npc_views: Array = []      # alien NPCs in the same batches (enemies/gray_alien_npc.gd): they move themselves, but the batch's box must reach them


## a level's own batch of robots (OMNISPHERE's heavies)
func add_batch(bt: RigidBatch) -> void:
	if not _batches.has(bt):
		_batches.append(bt)
		bt.warm()


## JS fx.setup(combat): a view for every robot the level's combat already holds (the range robots Combat builds itself).
func setup(en: Enemies) -> void:
	# JS warms one of every kind at load, so a level that spawns one mid-play does not build its textures or compile its shaders then
	for bt: RigidBatch in [RobotGfx.get_shared().batch, RobotGfx.get_shared().debris, DroneView.get_batch()]:
		if not _batches.has(bt):
			_batches.append(bt)
		bt.warm()
	for r in en.robots:
		if not bot_by_id.has(r.id):
			add_for(r)


## FX ticks the same list (its own loop is the JS one).
func link(fx: Variant) -> void:
	fx.bots = bots
	fx.bot_by_id = bot_by_id


## JS: const bv = o.drone ? new DroneView(rb) : ... : new RobotView(rb); fx.bots.push(bv); fx.scene.add(bv.g); fx.botById[rb.id] = bv
func add_for(rb: Robot) -> void:
	var bv: RefCounted = null
	if rb is TommyGunGray:
		bv = GrayFamilyViews.TommyGunView.new(rb)
	elif rb is ButtonMan:
		bv = GrayFamilyViews.ButtonManView.new(rb)
	elif rb is GrayAlien:
		bv = AlienView.new(rb)
	elif rb is Muscle:
		bv = GrayFamilyViews.MuscleView.new(rb)
	elif rb is GristleBrute:
		bv = GristleBruteView.new(rb)
	elif rb is SinewCrawler:
		bv = FleshViews.CrawlerView.new(rb)
	elif rb is BlisterBloat:
		bv = FleshViews.BloatView.new(rb)
	elif rb is WallWretch:
		bv = WallWretchView.new(rb)
	elif rb is MawLedge:
		bv = MawViews.LedgeView.new(rb)
	elif rb is MawNest:
		bv = MawViews.NestView.new(rb)
	elif rb is Prophet:
		bv = ProphetViews.ProphetView.new(rb)
	elif rb is Follower:
		bv = ProphetViews.FollowerView.new(rb)
	elif rb is MaintenanceSpider:
		bv = MaintenanceSpiderView.new(rb)
	elif rb is FointGoon:
		bv = FointGoonView.new(rb)
	elif rb is MarrowWarden:
		bv = MarrowWardenView.new(rb)
	elif rb is BriarDervish:
		bv = BriarDervishView.new(rb)
	elif rb is ProbeButler:
		bv = GrayFamilyViews.ButlerView.new(rb)
	elif rb is Consigliere:
		bv = GrayFamilyViews.ConsigliereView.new(rb)
	elif rb is NightAssassin:
		bv = NightAssassinView.new(rb)
	elif rb is Phoniworm:
		bv = PhoniwormView.new(rb)
	else:
		bv = DroneView.new(rb) if rb.drone else RobotView.new(rb)
	var bt: Variant = bv.get(&"batch")
	if bt != null and not _batches.has(bt):
		_batches.append(bt)
		(bt as RigidBatch).warm()
	bots.append(bv)
	bot_by_id[rb.id] = bv


## JS despawnEnemy
func remove_for(rb: Robot) -> void:
	var bv: RefCounted = bot_by_id.get(rb.id)
	if bv == null:
		return
	bot_by_id.erase(rb.id)
	bots.erase(bv)
	bv.dispose()


## JS resetCombatForLevel: every view of the old level is gone.
func clear_level() -> void:
	bots.clear()
	bot_by_id.clear()
	for b in _batches:
		b.clear_all()


## FX.update's loop, for when no FX is running (a test, a boot without it). Same rules: far views are hidden and not animated, a frozen pose holds.
func tick(dt: float, cam: Vector3) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for b: Variant in bots:
		var R: Robot = b.R
		if absf(R.y - cam.y) > 24.0 or U.hyp(R.x - cam.x, R.z - cam.z) > 140.0:
			b.set_culled(true)
			continue
		b.set_culled(false)
		if R.frozen_t > 0.0 and not R.dead:                                     # FROST: a frozen enemy's pose holds still inside the ice
			continue
		b.update(dt * (1.0 - 0.7 * minf(1.0, R.chill)) if R.chill > 0.0 else dt, now, null)


## All the views are posed: upload the rows. The batches are culled as one thing, so they get the box around the copies that are being drawn.
func flush() -> void:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for b: Variant in bots:
		if b.culled:
			continue
		var R: Robot = b.R
		lo.x = minf(lo.x, R.x)
		lo.y = minf(lo.y, R.y)
		lo.z = minf(lo.z, R.z)
		hi.x = maxf(hi.x, R.x)
		hi.y = maxf(hi.y, R.y)
		hi.z = maxf(hi.z, R.z)
	for b: Variant in npc_views:
		if b.culled:
			continue
		var R: Robot = b.R
		lo.x = minf(lo.x, R.x)
		lo.y = minf(lo.y, R.y)
		lo.z = minf(lo.z, R.z)
		hi.x = maxf(hi.x, R.x)
		hi.y = maxf(hi.y, R.y)
		hi.z = maxf(hi.z, R.z)
	var bounds := AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	if lo.x != INF:                                     # margin: the tallest pose, a toppled body, thrown debris, the call ring
		bounds = AABB(lo - Vector3(9, 4, 9), hi - lo + Vector3(18, 12, 18))
	for bt in _batches:
		bt.flush(bounds)
