class_name KitLevel
extends ExportedLevel
## A level built on the blockout kit: its world comes from the export, its flow from Blockout. A subclass overrides setup() to describe stages and objectives (a statement-for-statement port of the JS level's bo.stage calls,
## leaving out bo.box / bo.wall / bo.ramp for static geometry, which is already in the export) and returns what createBlockout was given as kit_options().

var bo: Blockout = null


## What the JS level passes to createBlockout: {id, name, spawn, ...}.
func kit_options() -> Dictionary:
	return {"id": id, "name": id.to_upper()}


## Describe the level: bo.stage({...}).
func setup() -> void:
	pass


## Whatever else a level's update does each frame (JS opts.onUpdate runs inside Blockout.update).
func tick_level(_dt: float) -> void:
	pass


func build() -> void:
	super.build()
	var o := kit_options()
	if o.has("portals"):      # the level lists its own doors: the export's copies have lost their `active` conditions
		portals.clear()
	bo = Blockout.new(self, o)
	setup()
	bo.build_checkpoints()


func on_enter() -> void:
	bo.on_level_entered()


func on_exit() -> void:
	bo.dispose()


func tick(dt: float) -> void:
	bo.update(dt, Game.player, Game.combat)
	tick_level(dt)


## the console's `cp` and CONTINUE
var checkpoints: Array:
	get:
		return bo.checkpoints if bo != null else []


func load_checkpoint(which: Variant) -> bool:
	return bo.load_cp(which)
