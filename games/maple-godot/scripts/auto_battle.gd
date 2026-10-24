extends RefCounted
## Auto-battle ("Tự động săn"), the mobile client's AutoHunt mode. It builds
## the same input dictionary as the keyboard, so the player follows the
## normal movement and skill rules.

const Phys = preload("res://scripts/map_physics.gd")
const SAME_LEVEL := 30.0


static func empty_input() -> Dictionary:
	return {
		"left": false, "right": false, "up": false, "down": false,
		"up_pressed": false, "jump_pressed": false,
		"skills": [false, false, false, false, false],
		"hp_pressed": false, "mp_pressed": false,
	}


static func reach(skill: Dictionary) -> float:
	match skill.kind:
		"hit":
			return float(skill.offsetX) + float(skill.w) / 2.0 - 10.0
		"projectile":
			return float(skill.range) - 40.0
		"dash":
			return float(skill.distance) + 30.0 if float(skill.distance) > 0.0 else 90.0
	return 0.0


## Best damaging skill that is ready and reaches dist, or -1.
static func pick_skill(world, p, dist: float) -> int:
	var best := -1
	var best_score := 0.0
	var skills: Array = p.job().skills
	for i in skills.size():
		var skill: Dictionary = skills[i]
		if skill.kind == "buff" or skill.kind == "teleport":
			continue
		if not world.can_use_skill(p, i) or dist > reach(skill):
			continue
		var score := float(skill.pct) * float(skill.hits) * minf(float(skill.maxTargets), 3.0)
		if score > best_score:
			best = i
			best_score = score
	return best


static func pick_target(world, p):
	var best = null
	var best_score := INF
	for m in world.monsters:
		if m.dead or (world.auto_skip != null and is_same(m, world.auto_skip)):
			continue
		var score := absf(m.x - p.x) + absf(m.y - p.y) * 3.0
		if score < best_score:
			best = m
			best_score = score
	return best


static func input_for(world, manual: Dictionary) -> Dictionary:
	# Manual movement always wins, so the player can steer during auto.
	if manual.left or manual.right or manual.jump_pressed:
		return manual
	var p = world.player
	var input := empty_input()
	var s: Dictionary = p.stats()
	var pots: Dictionary = world.progress.potions
	input.hp_pressed = p.hp < s.maxHp * 0.4 and pots.hpPotion > 0
	input.mp_pressed = p.mp < s.maxMp * 0.25 and pots.mpPotion > 0

	var skills: Array = p.job().skills
	for i in skills.size():
		if skills[i].kind == "buff" and world.can_use_skill(p, i) and p.buffs.is_empty():
			input.skills[i] = true
			return input

	var ai: Dictionary = world.auto_state
	var target = ai.get("target")
	if target == null or target.dead or not world.monsters.has(target):
		target = pick_target(world, p)
		ai.target = target
		ai.stuck_t = 0.0
		world.auto_skip = null
	if target == null:
		return input

	ai.stuck_t = ai.get("stuck_t", 0.0) + 1.0 / 60.0
	if absf(p.x - ai.get("last_x", 0.0)) > 30.0 or absf(p.y - ai.get("last_y", 0.0)) > 30.0:
		ai.stuck_t = 0.0
		ai.last_x = p.x
		ai.last_y = p.y
	if ai.stuck_t > 4.0:
		world.auto_skip = target
		ai.target = null
		return input

	var dx: float = target.x - p.x
	var dy: float = target.y - p.y

	if p.climbing != null:
		if dy < -SAME_LEVEL:
			input.up = true
		else:
			input.down = true
		return input

	if absf(dy) <= SAME_LEVEL:
		var dist := absf(dx)
		var facing_ok: bool = (1 if dx >= 0.0 else -1) == p.facing or dist < 20.0
		var idx := pick_skill(world, p, dist)
		# When facing away, step toward the target first; attack next frame.
		if idx >= 0 and facing_ok:
			input.skills[idx] = true
			ai.stuck_t = 0.0
		elif dx > 0.0:
			input.right = true
		else:
			input.left = true
		return input

	if dy < 0.0:
		# Target is higher: walk to a ladder that starts at this level.
		var ladder = null
		for l in world.map.ladders:
			if absf(float(l.bottom) - p.y) < 6.0 and float(l.top) < p.y:
				if ladder == null or absf(float(l.x) - p.x) < absf(float(ladder.x) - p.x):
					ladder = l
		if ladder == null:
			world.auto_skip = target
			ai.target = null
			return input
		if absf(float(ladder.x) - p.x) < 8.0:
			input.up = true
		elif float(ladder.x) > p.x:
			input.right = true
		else:
			input.left = true
		return input

	# Target is lower: drop through the platform, or walk off its edge.
	var below = null
	if p.on_ground:
		below = Phys.foothold_between(world.map, p.x, p.y + 1.0, float(world.map.height), p.fh)
	if below != null:
		input.down = true
		input.jump_pressed = true
	elif dx > 0.0:
		input.right = true
	else:
		input.left = true
	return input
