extends SceneTree
## Headless logic tests:
##   godot --headless --path games/maple-godot --script res://tests/run_tests.gd

const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/rules.gd")
const Phys = preload("res://scripts/map_physics.gd")
const World = preload("res://scripts/world.gd")
const Monster = preload("res://scripts/monster.gd")
const Player = preload("res://scripts/player.gd")

const STEP := 1.0 / 60.0

var failures := 0
var current := ""


func _initialize() -> void:
	for t in [
		"test_exp_curve", "test_gain_exp", "test_damage", "test_enhance",
		"test_maps_consistent", "test_jump", "test_ladder_and_drop",
		"test_kill_and_loot", "test_projectile_pierce", "test_portal",
		"test_auto_battle", "test_boss",
	]:
		current = t
		call(t)
	print("FAILED %d" % failures if failures else "ALL TESTS PASSED")
	quit(1 if failures else 0)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL %s: %s" % [current, msg])


func run(world, seconds: float, make: Callable = Callable()) -> void:
	for i in int(seconds * 60.0):
		world.update(STEP, make.call(i) if make.is_valid() else Player.empty_input())


func input_with(fields: Dictionary) -> Dictionary:
	var input := Player.empty_input()
	input.merge(fields, true)
	return input


func test_exp_curve() -> void:
	check(Rules.exp_to_next(1) == 20, "lv1 needs 20")
	for lv in range(1, 30):
		check(Rules.exp_to_next(lv + 1) > Rules.exp_to_next(lv), "curve grows at %d" % lv)


func test_gain_exp() -> void:
	var p := Rules.new_progress("t", "warrior")
	var gained := Rules.gain_exp(p, Rules.exp_to_next(1) + Rules.exp_to_next(2) + 5)
	check(gained == 2 and p.level == 3 and p.exp == 5, "overflow carries: %s" % p)


func test_damage() -> void:
	var hit := Rules.calc_damage(100, 100, 0, 1, 0, func(): return 0.0)
	check(hit.crit and hit.amount == int(round(100 * 0.9 * 1.5)), "crit %s" % hit)
	check(Rules.calc_damage(1, 10, 999, 0, 0, func(): return 0.99).amount == 1, "min 1")
	var even: int = Rules.calc_damage(200, 100, 0, 0, 0, func(): return 0.5).amount
	var harder: int = Rules.calc_damage(200, 100, 0, 0, 5, func(): return 0.5).amount
	check(harder < even, "level penalty")


func test_enhance() -> void:
	var p := Rules.new_progress("t", "thief")
	check(Rules.try_enhance(p, func(): return 0.0) == "nomoney", "nomoney")
	p.meso = 100000
	check(Rules.try_enhance(p, func(): return 0.0) == "success" and p.weaponLv == 1, "success")
	check(p.meso == 100000 - Rules.enhance_cost(0), "cost paid")
	check(Rules.try_enhance(p, func(): return 0.999) == "fail" and p.weaponLv == 1, "fail keeps level")


func test_maps_consistent() -> void:
	for id in Data.MAPS:
		var map: Dictionary = Data.MAPS[id]
		for l in map.ladders:
			check(Phys.foothold_at(map, l.x, l.top) != null, "%s ladder top %d" % [id, l.x])
			check(Phys.foothold_at(map, l.x, l.bottom) != null, "%s ladder bottom %d" % [id, l.x])
		for pt in map.portals:
			check(Phys.foothold_at(map, pt.x, pt.y) != null, "%s portal %s on ground" % [id, pt.id])
			if pt.has("to"):
				var back = null
				for q in Data.MAPS[pt.to].portals:
					if q.id == pt.toPortal:
						back = q
				check(back != null and back.to == id, "%s portal %s links back" % [id, pt.id])


func test_jump() -> void:
	var world = World.new(Rules.new_progress("t", "warrior"), 1)
	run(world, 0.5)
	var p = world.player
	check(p.on_ground and p.y == 1000.0, "landed at 1000, got %s" % p.y)
	world.update(STEP, input_with({"jump_pressed": true}))
	check(p.vy < 0.0, "jumped")
	run(world, 1.5)
	check(p.on_ground, "landed again")


func test_ladder_and_drop() -> void:
	var world = World.new(Rules.new_progress("t", "warrior"), 2)
	world.monsters = []
	world.respawn_t = INF
	var p = world.player
	p.place_at(600, 1000)
	run(world, 0.2)
	run(world, 2.0, func(_i): return input_with({"up": true}))
	check(p.y == 820.0 and p.on_ground, "climbed to 820, got %s" % p.y)
	run(world, 0.1)
	world.update(STEP, input_with({"down": true, "jump_pressed": true}))
	run(world, 1.0)
	check(p.y == 1000.0, "dropped to 1000, got %s" % p.y)


func test_kill_and_loot() -> void:
	var world = World.new(Rules.new_progress("t", "warrior"), 3)
	var p = world.player
	world.monsters = []
	world.respawn_t = INF
	run(world, 0.3)
	var mob = Monster.new("snail", {"mob": "snail", "x1": 0, "x2": 3000, "y": 1000, "count": 1}, p.x + 60.0, world.rng)
	mob.max_hp = 1.0
	mob.hp = 1.0
	world.monsters.append(mob)
	run(world, 0.2)
	p.facing = 1
	world.use_skill(p, 0)
	run(world, 0.2)
	check(mob.dead, "mob died")
	check(world.progress.exp == int(Data.MONSTERS.snail.exp), "exp granted")
	run(world, 2.0)
	check(world.progress.meso > 0, "meso looted")


func test_projectile_pierce() -> void:
	var world = World.new(Rules.new_progress("t", "bowman"), 4)
	var p = world.player
	world.monsters = []
	world.respawn_t = INF
	run(world, 0.3)
	var sp := {"mob": "pig", "x1": 0, "x2": 3000, "y": 1000, "count": 0}
	for i in range(1, 8):
		var m = Monster.new("pig", sp, p.x + 80.0 * i, world.rng)
		m.y = 1000.0
		m.on_ground = true
		world.monsters.append(m)
	# Freeze monsters by stepping only the player and projectiles.
	p.facing = 1
	world.use_skill(p, 1)
	for i in 60:
		world._update_projectiles(STEP)
		world._update_hits(STEP)
	var hit: int = world.monsters.filter(func(m): return m.hp < m.max_hp).size()
	check(hit == int(Data.JOBS.bowman.skills[1].maxTargets), "pierced %d" % hit)


func test_portal() -> void:
	var world = World.new(Rules.new_progress("t", "magician"), 5)
	var p = world.player
	p.place_at(2900, 1000)
	run(world, 0.2)
	world.update(STEP, input_with({"up_pressed": true, "up": true}))
	check(world.map_id == "forest" and p.x == 100.0, "moved to forest at 100")


func test_auto_battle() -> void:
	for job in Data.JOBS:
		var world = World.new(Rules.new_progress("t", job), 6)
		world.auto = true
		run(world, 90.0)
		print("  auto %s: level %d" % [job, world.progress.level])
		check(world.progress.level >= 3, "%s reached level %d" % [job, world.progress.level])


func test_boss() -> void:
	var progress := Rules.new_progress("t", "warrior")
	progress.level = 30
	progress.weaponLv = 15
	progress.map = "kingRoom"
	var world = World.new(progress, 7)
	var b = world.boss()
	check(b != null, "boss spawned")
	var start: float = world.boss_timer
	run(world, 1.0)
	check(world.boss_timer < start, "timer runs")
	var p = world.player
	p.place_at(b.x - 200.0, 1000)
	run(world, 0.1)
	p.invuln = 0.0
	var hp: float = p.hp
	world.boss_shockwave(b)
	check(p.hp < hp, "shockwave hurts grounded player")
	b.hp = 1.0
	world.damage_monster(b, {"amount": 5, "crit": false}, 0, 1)
	check(world.boss_result == "clear" and progress.bossCleared, "boss cleared")
