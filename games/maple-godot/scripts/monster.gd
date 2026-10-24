extends RefCounted
## A monster, including the boss attack patterns.

const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/rules.gd")
const Phys = preload("res://scripts/map_physics.gd")

var def_id: String
var def: Dictionary
var spawn: Dictionary
var w := 0.0
var h := 0.0
var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var on_ground := false
var fh = null
var spawn_fh = null
var drop_from = null
var jumps_used := 0
var max_hp := 0.0
var hp := 0.0
var facing := 1
var state := "idle"
var state_t := 0.0
var aggro := false
var hurt_t := 0.0
var dead := false
var death_t := 0.0
var hop_t := 0.0
var anim := 0.0
var skill_t := 5.0
var summon_t := 18.0


func _init(id: String, spawn_def: Dictionary, at_x: float, rng: RandomNumberGenerator) -> void:
	def_id = id
	def = Data.MONSTERS[id]
	spawn = spawn_def
	w = float(def.w)
	h = float(def.h)
	x = at_x
	y = float(spawn_def.y)
	max_hp = float(def.hp)
	hp = max_hp
	facing = -1 if rng.randf() < 0.5 else 1
	state_t = rng.randf_range(0.5, 2.0)
	hop_t = rng.randf_range(1.0, 3.0)
	anim = rng.randf_range(0.0, 10.0)


func level() -> int:
	return int(def.level)


func is_boss() -> bool:
	return def.get("boss", false)


func update(dt: float, world) -> void:
	anim += dt
	if dead:
		death_t -= dt
		return
	hurt_t = maxf(0.0, hurt_t - dt)
	var player = world.player
	var rng: RandomNumberGenerator = world.rng

	if is_boss():
		_update_boss(dt, world)
	if state == "stomp" or state == "charge":
		pass
	elif hurt_t > 0.0:
		vx *= 0.9
	elif aggro and not player.dead:
		var dx: float = player.x - x
		facing = 1 if dx >= 0.0 else -1
		vx = facing * float(def.speed) * 1.3 if absf(dx) > 10.0 else 0.0
	else:
		state_t -= dt
		if state_t <= 0.0:
			state = "idle" if state == "walk" else "walk"
			state_t = rng.randf_range(1.0, 3.0)
			if state == "walk" and rng.randf() < 0.5:
				facing *= -1
		vx = facing * float(def.speed) if state == "walk" else 0.0

	if def.get("hops", false) and on_ground and vx != 0.0:
		hop_t -= dt
		if hop_t <= 0.0:
			vy = -380.0
			on_ground = false
			hop_t = rng.randf_range(1.2, 2.5)

	# Stay on the home platform: turn around at its edges.
	var home = fh if fh != null else spawn_fh
	if home != null and on_ground:
		var nx := x + vx * dt
		var half := w / 2.0
		if nx - half < float(home.x1) or nx + half > float(home.x2):
			vx = 0.0
			if not aggro:
				facing *= -1
			x = clampf(x, float(home.x1) + half, float(home.x2) - half)
	Phys.step_body(self, world.map, dt)
	if on_ground and spawn_fh == null:
		spawn_fh = fh

	if not player.dead and player.invuln <= 0.0 and Phys.overlaps(self, player):
		world.hurt_player(Rules.monster_damage(float(def.atk), player.stats().def, world.roll), x)


func _update_boss(dt: float, world) -> void:
	var player = world.player
	var rng: RandomNumberGenerator = world.rng
	aggro = true
	if state == "stomp":
		vx = 0.0
		if on_ground and state_t <= 0.0:
			world.boss_shockwave(self)
			state = "idle"
			skill_t = rng.randf_range(4.0, 7.0)
		state_t -= dt
		return
	if state == "charge":
		state_t -= dt
		vx = facing * 420.0
		if state_t <= 0.0:
			state = "idle"
			skill_t = rng.randf_range(4.0, 7.0)
		return
	skill_t -= dt
	summon_t -= dt
	if hp < max_hp * 0.6 and summon_t <= 0.0:
		summon_t = 20.0
		world.boss_summon(self)
	if skill_t <= 0.0 and on_ground and not player.dead:
		if rng.randf() < 0.55:
			state = "stomp"
			state_t = 0.4
			vy = -820.0
			on_ground = false
			world.notice("Nấm Vua chuẩn bị dậm đất! Hãy nhảy lên để né!", Color("#ffcc33"))
		else:
			state = "charge"
			state_t = 1.4
			facing = 1 if player.x >= x else -1
			world.notice("Nấm Vua đang lao tới!", Color("#ff7043"))
