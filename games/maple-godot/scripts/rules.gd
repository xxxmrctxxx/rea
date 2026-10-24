extends RefCounted
## Movement constants, progression and damage rules (ported from maple-pc).

const Data = preload("res://scripts/game_data.gd")

const GRAVITY := 2100.0
const MAX_FALL := 950.0
const WALK_SPEED := 230.0
const JUMP_SPEED := 640.0
const DOUBLE_JUMP_SPEED_X := 520.0
const DOUBLE_JUMP_SPEED_Y := 380.0
const JUMP_COUNT := 2
const CLIMB_SPEED := 150.0
const LADDER_GRAB_RANGE := 14.0
const STEP_HEIGHT := 10.0
const VIEW_W := 1280.0
const VIEW_H := 720.0
const HIT_INVULN := 1.0
const PICKUP_RANGE := 60.0

const MAX_LEVEL := 60
const MAX_ENHANCE := 15


static func exp_to_next(level: int) -> int:
	return int(floor(12.0 * pow(level, 1.6) + 8.0))


static func enhance_bonus(lv: int) -> int:
	return lv * 8 + lv * lv


static func enhance_cost(lv: int) -> int:
	return 100 * (lv + 1) * (lv + 1)


static func enhance_chance(lv: int) -> float:
	return max(0.3, 0.95 - lv * 0.05)


## Explorer AP is assigned automatically, so stats depend only on job,
## level, weapon level and active buffs.
static func player_stats(p: Dictionary, buffs: Array) -> Dictionary:
	var job: Dictionary = Data.JOBS[p.job]
	var main_stat := 4 + int(p.level) * 5
	var atk := int(floor(main_stat * float(job.atkMul) + 10 + enhance_bonus(int(p.weaponLv))))
	var crit := float(job.crit)
	for b in buffs:
		atk = int(floor(atk * (1.0 + float(b.atkBonus))))
		crit += float(b.critBonus)
	return {
		"maxHp": 50 + int(p.level) * int(job.hpPerLv),
		"maxMp": 30 + int(p.level) * int(job.mpPerLv),
		"atk": atk,
		"def": int(p.level) * 2,
		"crit": min(1.0, crit),
	}


## rng is a Callable returning a float in [0, 1).
static func calc_damage(atk: float, pct: float, target_def: float, crit_rate: float, level_diff: int, rng: Callable) -> Dictionary:
	var roll: float = 0.9 + rng.call() * 0.2
	var amount := atk * pct / 100.0 * roll - target_def * 0.6
	if level_diff > 0:
		amount *= max(0.4, 1.0 - 0.05 * level_diff)
	var crit: bool = rng.call() < crit_rate
	if crit:
		amount *= 1.5
	return {"amount": max(1, int(round(amount))), "crit": crit}


static func monster_damage(mob_atk: float, player_def: float, rng: Callable) -> int:
	return max(1, int(round(mob_atk * (0.85 + rng.call() * 0.2) - player_def * 0.5)))


## Adds exp and returns how many levels were gained.
static func gain_exp(p: Dictionary, amount: int) -> int:
	var gained := 0
	p.exp += amount
	while p.level < MAX_LEVEL and p.exp >= exp_to_next(p.level):
		p.exp -= exp_to_next(p.level)
		p.level += 1
		gained += 1
	if p.level >= MAX_LEVEL:
		p.exp = 0
	return gained


static func try_enhance(p: Dictionary, rng: Callable) -> String:
	if p.weaponLv >= MAX_ENHANCE:
		return "max"
	var cost := enhance_cost(p.weaponLv)
	if p.meso < cost:
		return "nomoney"
	p.meso -= cost
	if rng.call() < enhance_chance(p.weaponLv):
		p.weaponLv += 1
		return "success"
	return "fail"


static func new_progress(player_name: String, job: String) -> Dictionary:
	return {
		"name": player_name,
		"job": job,
		"level": 1,
		"exp": 0,
		"meso": 0,
		"weaponLv": 0,
		"potions": {"hpPotion": 20, "mpPotion": 20},
		"map": "hill",
		"bossCleared": false,
	}


static func format_number(n: float) -> String:
	var v := int(floor(n))
	if v >= 1000000000:
		return "%.1fB" % (v / 1e9)
	if v >= 1000000:
		return "%.1fM" % (v / 1e6)
	if v >= 10000:
		return "%.1fK" % (v / 1e3)
	return str(v)


static func format_time(sec: float) -> String:
	var s := int(max(0.0, ceil(sec)))
	return "%02d:%02d" % [s / 60, s % 60]


static func combat_power(stats: Dictionary) -> int:
	return int(floor(stats.atk * 12 + stats.maxHp * 0.6 + stats.def * 8 + stats.crit * 2000))
