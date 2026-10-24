extends RefCounted
## Simulation for the current map: spawning, skills, damage, drops, portals
## and the boss fight. Rendering lives in world_view.gd.

const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/rules.gd")
const Phys = preload("res://scripts/map_physics.gd")
const Player = preload("res://scripts/player.gd")
const Monster = preload("res://scripts/monster.gd")
const AutoBattle = preload("res://scripts/auto_battle.gd")

const RESPAWN_INTERVAL := 7.0
const HIT_INTERVAL := 0.09


class Drop:
	extends RefCounted
	var x := 0.0
	var y := 0.0
	var w := 20.0
	var h := 20.0
	var vx := 0.0
	var vy := -380.0
	var on_ground := false
	var fh = null
	var drop_from = null
	var jumps_used := 0
	var kind := ""
	var amount := 0
	var t := 0.0
	var taken := false


signal map_changed
signal noticed(text: String, color: Color)

var rng := RandomNumberGenerator.new()
var roll: Callable = rng.randf
var progress: Dictionary
var player
var auto := false
var auto_state := {}
var auto_skip = null
var map_id := ""
var map: Dictionary
var monsters: Array = []
var drops: Array = []
var projectiles: Array = []
var pending_hits: Array = []
var effects: Array = []
var texts: Array = []
var respawn_t := RESPAWN_INTERVAL
var boss_timer := 0.0
var boss_result := ""
var delayed_warp := 0.0
var last_notice := {}


func _init(p: Dictionary, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	progress = p
	player = Player.new(p)
	load_map(p.map, "")


func load_map(id: String, portal_id: String) -> void:
	map_id = id
	map = Data.MAPS[id]
	progress.map = id
	monsters = []
	drops = []
	projectiles = []
	pending_hits = []
	effects = []
	texts = []
	auto_state = {}
	respawn_t = RESPAWN_INTERVAL
	boss_timer = float(map.get("bossTimeLimit", 0))
	boss_result = ""
	delayed_warp = 0.0
	for sp in map.spawns:
		fill_spawn(sp)
	var portal = null
	for want in [portal_id, "spawn"]:
		for pt in map.portals:
			if portal == null and pt.id == want:
				portal = pt
	if portal == null:
		portal = map.portals[0]
	player.place_at(float(portal.x), float(portal.y))
	notice(map.name, Color.WHITE)
	map_changed.emit()


func fill_spawn(sp: Dictionary) -> void:
	var alive := 0
	for m in monsters:
		if is_same(m.spawn, sp) and not m.dead:
			alive += 1
	for i in range(alive, int(sp.count)):
		var at := rng.randf_range(float(sp.x1) + 40.0, float(sp.x2) - 40.0)
		monsters.append(Monster.new(sp.mob, sp, at, rng))


func boss():
	for m in monsters:
		if m.is_boss() and not m.dead:
			return m
	return null


func update(dt: float, input: Dictionary) -> void:
	if auto and not player.dead:
		input = AutoBattle.input_for(self, input)
	player.update(dt, input, self)

	if player.dead:
		player.respawn_t -= dt
		if player.respawn_t <= 0.0:
			respawn_player()

	for m in monsters.duplicate():
		m.update(dt, self)
	monsters = monsters.filter(func(m): return not m.dead or m.death_t > 0.0)

	_update_hits(dt)
	_update_projectiles(dt)
	_update_drops(dt)
	for e in effects:
		e.t += dt
	effects = effects.filter(func(e): return e.t < e.dur)
	for t in texts:
		t.t += dt
		t.y -= 40.0 * dt
	texts = texts.filter(func(t): return t.t < t.dur)

	respawn_t -= dt
	if respawn_t <= 0.0:
		respawn_t = RESPAWN_INTERVAL
		for sp in map.spawns:
			if sp.get("respawn", true):
				fill_spawn(sp)

	if boss_timer > 0.0 and boss_result == "":
		boss_timer -= dt
		if boss_timer <= 0.0:
			boss_result = "fail"
			notice("Hết giờ! Bạn bị đưa ra ngoài.", Color("#ff5252"))
			delayed_warp = 3.0
	if delayed_warp > 0.0:
		delayed_warp -= dt
		if delayed_warp <= 0.0:
			load_map("forest", "boss")


# --- skills -----------------------------------------------------------------

func can_use_skill(p, i: int) -> bool:
	var skills: Array = p.job().skills
	return i < skills.size() and p.cooldowns[i] <= 0.0 and p.mp >= float(skills[i].mp)


func use_skill(p, i: int) -> void:
	var skill: Dictionary = p.job().skills[i]
	p.mp -= float(skill.mp)
	p.cooldowns[i] = float(skill.cooldown)
	p.action_t = 0.3 if skill.kind == "buff" else 0.25
	p.action_fx = skill.fx
	var f: int = p.facing
	var mid_y: float = p.y - p.h / 2.0
	match skill.kind:
		"hit":
			var box := {"cx": p.x + f * float(skill.offsetX), "top": mid_y - float(skill.h) / 2.0, "w": float(skill.w), "h": float(skill.h)}
			hit_box(p, skill, box)
			add_effect(skill.fx, box.cx, mid_y, f, 0.4, box.w, box.h)
		"projectile":
			projectiles.append({"x": p.x + f * 20.0, "y": mid_y, "dir": f, "skill": skill, "travelled": 0.0, "hit": []})
		"dash":
			var start_x: float = p.x
			p.x = clampf(p.x + float(skill.distance) * f, p.w / 2.0, float(map.width) - p.w / 2.0)
			p.invuln = maxf(p.invuln, 0.35)
			var cx: float = (start_x + p.x) / 2.0
			var box := {"cx": cx, "top": mid_y - float(skill.h) / 2.0, "w": absf(p.x - start_x) + 80.0, "h": float(skill.h)}
			hit_box(p, skill, box)
			add_effect("dash", cx, mid_y, f, 0.35, box.w, box.h)
		"teleport":
			add_effect("blink", p.x, mid_y, f, 0.3)
			p.x = clampf(p.x + float(skill.distance) * f, p.w / 2.0, float(map.width) - p.w / 2.0)
			add_effect("blink", p.x, mid_y, f, 0.3)
		"buff":
			p.buffs = p.buffs.filter(func(b): return b.id != skill.id)
			p.buffs.append({"id": skill.id, "name": skill.name, "t": float(skill.duration), "dur": float(skill.duration), "atkBonus": float(skill.atkBonus), "critBonus": float(skill.critBonus)})
			add_effect("aura", p.x, mid_y, f, 0.8)


func hit_box(p, skill: Dictionary, box: Dictionary) -> int:
	var targets := monsters.filter(func(m): return not m.dead and Phys.box_hits(box, m))
	targets.sort_custom(func(a, b): return absf(a.x - p.x) < absf(b.x - p.x))
	targets = targets.slice(0, int(skill.maxTargets))
	for m in targets:
		queue_hits(p, skill, m)
	return targets.size()


func queue_hits(p, skill: Dictionary, mob) -> void:
	var s: Dictionary = p.stats()
	for n in int(skill.hits):
		var dmg := Rules.calc_damage(s.atk, float(skill.pct), float(mob.def.def), s.crit, mob.level() - int(p.p.level), roll)
		pending_hits.append({"mob": mob, "dmg": dmg, "t": n * HIT_INTERVAL, "row": n, "dir": p.facing})


func _update_hits(dt: float) -> void:
	var ready: Array = []
	for hit in pending_hits:
		hit.t -= dt
		if hit.t <= 0.0:
			ready.append(hit)
	pending_hits = pending_hits.filter(func(hit): return hit.t > 0.0)
	for hit in ready:
		damage_monster(hit.mob, hit.dmg, hit.row, hit.dir)


func damage_monster(mob, dmg: Dictionary, row: int, dir: int) -> void:
	if mob.dead:
		return
	mob.hp -= dmg.amount
	mob.aggro = true
	if not mob.is_boss():
		mob.hurt_t = 0.25
		mob.vx = dir * 60.0
	add_text(mob.x + rng.randf_range(-10, 10), mob.y - mob.h - 10.0 - row * 28.0, Rules.format_number(dmg.amount), Color("#ff5a8c") if dmg.crit else Color("#ffb22e"), 0.9, "crit" if dmg.crit else "")
	if mob.hp <= 0.0:
		kill_monster(mob)


func kill_monster(mob) -> void:
	mob.dead = true
	mob.death_t = 0.5
	mob.hp = 0.0
	var levels := Rules.gain_exp(progress, int(mob.def.exp))
	add_text(mob.x, mob.y - mob.h - 40.0, "+%d EXP" % int(mob.def.exp), Color("#b7f36b"), 1.1, "small")
	if levels > 0:
		_on_level_up()
	spawn_drop(mob.x, mob.y - mob.h / 2.0, "meso", rng.randi_range(int(mob.def.meso[0]), int(mob.def.meso[1])))
	if rng.randf() < (1.0 if mob.is_boss() else 0.08):
		spawn_drop(mob.x + 20.0, mob.y - mob.h / 2.0, "hpPotion" if rng.randf() < 0.5 else "mpPotion", 10 if mob.is_boss() else 1)
	if mob.is_boss():
		boss_result = "clear"
		progress.bossCleared = true
		notice("Đã đánh bại %s!" % mob.def.name, Color("#ffd54f"))
		for m in monsters:
			if not m.dead:
				kill_monster(m)


func _on_level_up() -> void:
	var s: Dictionary = player.stats()
	player.hp = s.maxHp
	player.mp = s.maxMp
	add_effect("levelup", player.x, player.y - 40.0, 1, 1.5)
	notice("LÊN CẤP! Cấp %d" % progress.level, Color("#ffd54f"))


func _update_projectiles(dt: float) -> void:
	for pr in projectiles:
		var skill: Dictionary = pr.skill
		var step := float(skill.speed) * dt
		pr.x += pr.dir * step
		pr.travelled += step
		var box := {"cx": pr.x, "top": pr.y - 20.0, "w": 30.0, "h": 40.0}
		for m in monsters:
			if m.dead or pr.hit.size() >= int(skill.maxTargets) or pr.hit.any(func(o): return is_same(o, m)):
				continue
			if Phys.box_hits(box, m):
				pr.hit.append(m)
				queue_hits(player, skill, m)
		if pr.hit.size() >= int(skill.maxTargets):
			pr.travelled = float(skill.range)
	projectiles = projectiles.filter(func(pr): return pr.travelled < float(pr.skill.range) and pr.x > 0.0 and pr.x < float(map.width))


# --- player damage / death --------------------------------------------------

func hurt_player(amount: int, from_x: float) -> void:
	if player.dead or player.invuln > 0.0:
		return
	player.hp -= amount
	player.invuln = Rules.HIT_INVULN
	add_text(player.x, player.y - player.h - 10.0, str(amount), Color("#c78bff"), 0.9, "")
	player.climbing = null
	player.vx = (1.0 if player.x >= from_x else -1.0) * 220.0
	player.vy = -320.0
	player.on_ground = false
	player.fh = null
	if player.hp <= 0.0:
		player.hp = 0.0
		player.dead = true
		player.respawn_t = 3.0
		progress.exp = int(floor(progress.exp * 0.9))
		notice("Bạn đã gục ngã! Hồi sinh sau 3 giây.", Color("#ff5252"))


func respawn_player() -> void:
	var s: Dictionary = player.stats()
	player.dead = false
	player.hp = s.maxHp
	player.mp = s.maxMp
	player.invuln = 2.0
	if map.has("bossTimeLimit"):
		load_map("forest", "boss")
		return
	var sp = map.portals[0]
	for pt in map.portals:
		if pt.id == "spawn":
			sp = pt
	player.place_at(float(sp.x), float(sp.y))


func use_potion(id: String) -> bool:
	if player.potion_cd > 0.0 or progress.potions[id] <= 0:
		return false
	var item: Dictionary = Data.ITEMS[id]
	var s: Dictionary = player.stats()
	if item.heal == "hp":
		if player.hp >= s.maxHp:
			return false
		player.hp = minf(s.maxHp, player.hp + s.maxHp * float(item.pct))
	else:
		if player.mp >= s.maxMp:
			return false
		player.mp = minf(s.maxMp, player.mp + s.maxMp * float(item.pct))
	progress.potions[id] -= 1
	player.potion_cd = 0.8
	add_effect("potion", player.x, player.y - 40.0, 1, 0.5, 0.0, 0.0, Color(item.color))
	return true


# --- boss -------------------------------------------------------------------

func boss_shockwave(b) -> void:
	add_effect("shockwave", b.x, b.y, 1, 0.6, 1100.0, 60.0)
	if player.on_ground and player.fh != null and float(player.fh.y) == b.y and absf(player.x - b.x) < 550.0:
		hurt_player(Rules.monster_damage(float(b.def.atk) * 1.6, player.stats().def, roll), b.x)


func boss_summon(b) -> void:
	notice("Nấm Vua gọi thuộc hạ!", Color("#ff7043"))
	var sp := {"mob": "hornyMush", "x1": 100, "x2": int(map.width) - 100, "y": b.y, "count": 0, "respawn": false}
	for i in 3:
		var at := clampf(b.x + rng.randf_range(-300.0, 300.0), 100.0, float(map.width) - 100.0)
		var m = Monster.new("hornyMush", sp, at, rng)
		m.aggro = true
		monsters.append(m)


# --- drops ------------------------------------------------------------------

func spawn_drop(x: float, y: float, kind: String, amount: int) -> void:
	var d := Drop.new()
	d.x = x
	d.y = y
	d.vx = rng.randf_range(-60.0, 60.0)
	d.kind = kind
	d.amount = amount
	drops.append(d)


func _update_drops(dt: float) -> void:
	for d in drops:
		d.t += dt
		if d.on_ground:
			d.vx = 0.0
		Phys.step_body(d, map, dt)
		if d.t > 0.5 and not player.dead and Vector2(d.x - player.x, d.y - player.y).length() < Rules.PICKUP_RANGE * 3.0:
			var k := minf(1.0, dt * 10.0)
			d.x += (player.x - d.x) * k
			d.y += (player.y - 30.0 - d.y) * k
			d.on_ground = false
			d.vy = 0.0
			if Vector2(d.x - player.x, d.y - (player.y - 30.0)).length() < 24.0:
				d.taken = true
				var label: String
				if d.kind == "meso":
					progress.meso += d.amount
					label = "+%d meso" % d.amount
				else:
					progress.potions[d.kind] += d.amount
					label = "+%d %s" % [d.amount, Data.ITEMS[d.kind].name]
				add_text(player.x, player.y - player.h - 30.0, label, Color("#ffe082"), 0.8, "small")
	drops = drops.filter(func(d): return not d.taken and d.t < 60.0)


# --- portals / misc ---------------------------------------------------------

func portal_near(p):
	for pt in map.portals:
		if pt.has("to") and absf(float(pt.x) - p.x) < 40.0 and absf(float(pt.y) - p.y) < 12.0:
			return pt
	return null


func try_portal(p) -> bool:
	var pt = portal_near(p)
	if pt == null:
		return false
	load_map(pt.to, pt.toPortal)
	return true


func enhance_weapon() -> String:
	var before: int = progress.weaponLv
	var result := Rules.try_enhance(progress, roll)
	match result:
		"success":
			notice("Cường hóa thành công! Vũ khí +%d" % progress.weaponLv, Color("#69f0ae"))
		"fail":
			notice("Cường hóa thất bại (+%d)" % before, Color("#ff8a80"))
		"nomoney":
			notice("Không đủ meso (cần %s)" % Rules.format_number(Rules.enhance_cost(before)), Color("#ff8a80"))
		_:
			notice("Vũ khí đã đạt cấp tối đa", Color.WHITE)
	return result


func add_effect(type: String, x: float, y: float, facing: int, dur: float, w: float = 0.0, h: float = 0.0, color: Color = Color("#ffd54f")) -> void:
	effects.append({"type": type, "x": x, "y": y, "facing": facing, "dur": dur, "w": w, "h": h, "color": color, "t": 0.0})


func add_text(x: float, y: float, text: String, color: Color, dur: float, style: String) -> void:
	texts.append({"x": x, "y": y, "text": text, "color": color, "t": 0.0, "dur": dur, "style": style})


func notice(text: String, color: Color) -> void:
	last_notice = {"text": text, "color": color, "t": 0.0}
	noticed.emit(text, color)
