extends RefCounted
## The player character. Reads the same input dictionary from the keyboard
## and from auto-battle.

const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/rules.gd")
const Phys = preload("res://scripts/map_physics.gd")

var p: Dictionary
var w := 36.0
var h := 66.0
var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var facing := 1
var on_ground := false
var fh = null
var drop_from = null
var jumps_used := 0
var climbing = null
var cooldowns := [0.0, 0.0, 0.0, 0.0, 0.0]
var buffs: Array = []
var invuln := 0.0
var potion_cd := 0.0
var action_t := 0.0
var action_fx := ""
var dead := false
var respawn_t := 0.0
var walk_phase := 0.0
var hp := 0.0
var mp := 0.0


func _init(progress: Dictionary) -> void:
	p = progress
	var s := stats()
	hp = s.maxHp
	mp = s.maxMp


static func empty_input() -> Dictionary:
	return {
		"left": false, "right": false, "up": false, "down": false,
		"up_pressed": false, "jump_pressed": false,
		"skills": [false, false, false, false, false],
		"hp_pressed": false, "mp_pressed": false,
	}


func job() -> Dictionary:
	return Data.JOBS[p.job]


func stats() -> Dictionary:
	return Rules.player_stats(p, buffs)


func place_at(px: float, py: float) -> void:
	x = px
	y = py
	vx = 0.0
	vy = 0.0
	climbing = null
	on_ground = false
	fh = null


func update(dt: float, input: Dictionary, world) -> void:
	for i in cooldowns.size():
		cooldowns[i] = maxf(0.0, cooldowns[i] - dt)
	for b in buffs:
		b.t -= dt
	buffs = buffs.filter(func(b): return b.t > 0.0)
	invuln = maxf(0.0, invuln - dt)
	potion_cd = maxf(0.0, potion_cd - dt)
	action_t = maxf(0.0, action_t - dt)
	if dead:
		return

	var s := stats()
	hp = minf(hp, s.maxHp)
	mp = minf(s.maxMp, mp + s.maxMp * 0.01 * dt)

	if input.hp_pressed:
		world.use_potion("hpPotion")
	if input.mp_pressed:
		world.use_potion("mpPotion")

	var dir := (1 if input.right else 0) - (1 if input.left else 0)
	if climbing != null:
		_update_climb(dt, input, dir)
	else:
		_update_move(dt, input, dir, world)

	if action_t <= 0.0:
		for i in input.skills.size():
			if input.skills[i] and world.can_use_skill(self, i):
				world.use_skill(self, i)
				break

	if input.up_pressed and on_ground:
		world.try_portal(self)


func _update_climb(dt: float, input: Dictionary, dir: int) -> void:
	var l = climbing
	if input.jump_pressed and dir != 0:
		climbing = null
		facing = dir
		vx = dir * Rules.WALK_SPEED * 0.8
		vy = -Rules.JUMP_SPEED * 0.55
		jumps_used = 1
		return
	vx = 0.0
	vy = ((1 if input.down else 0) - (1 if input.up else 0)) * Rules.CLIMB_SPEED
	y += vy * dt
	if vy != 0.0:
		walk_phase += dt * 8.0
	if y <= float(l.top) or y >= float(l.bottom):
		y = float(l.top) if y <= float(l.top) else float(l.bottom)
		climbing = null
		on_ground = true
		fh = null
		vy = 0.0
		jumps_used = 0


func _update_move(dt: float, input: Dictionary, dir: int, world) -> void:
	var map: Dictionary = world.map
	if input.up and not input.jump_pressed:
		var l = Phys.find_ladder(map, x, y, true)
		if l != null and world.portal_near(self) == null:
			_grab(l, y)
			return
	if input.down and on_ground and not input.jump_pressed:
		var l = Phys.find_ladder(map, x, y, false)
		if l != null:
			_grab(l, float(l.top) + 2.0)
			return

	var locked := action_t > 0.0 and on_ground
	if dir != 0 and not locked:
		facing = dir
	if on_ground:
		vx = 0.0 if locked else dir * Rules.WALK_SPEED
	elif dir != 0:
		vx += clampf(dir * Rules.WALK_SPEED - vx, -900.0 * dt, 900.0 * dt)
	if on_ground and vx != 0.0:
		walk_phase += dt * 10.0

	if input.jump_pressed:
		var below = null
		if on_ground:
			below = Phys.foothold_between(map, x, y + 1.0, float(map.height), fh)
		if input.down and below != null:
			drop_from = fh
			on_ground = false
			fh = null
			vy = 0.0
		elif on_ground:
			vy = -Rules.JUMP_SPEED
			on_ground = false
			fh = null
			jumps_used = 1
		elif jumps_used < Rules.JUMP_COUNT:
			jumps_used += 1
			vx = facing * Rules.DOUBLE_JUMP_SPEED_X
			vy = -Rules.DOUBLE_JUMP_SPEED_Y
			world.add_effect("flash", x, y - 30.0, facing, 0.3)

	if not Phys.step_body(self, map, dt):
		world.respawn_player()


func _grab(ladder, at_y: float) -> void:
	climbing = ladder
	x = float(ladder.x)
	y = at_y
	vx = 0.0
	vy = 0.0
	on_ground = false
	fh = null
