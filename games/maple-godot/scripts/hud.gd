extends Control
## Screen-space HUD laid out after the mobile client: status top-left with
## the job portrait, minimap top-right, boss bar top-centre, skill wheel
## bottom-right (APK button frames when extracted) and a full-width EXP bar.

const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/rules.gd")
const D = preload("res://scripts/draw_util.gd")
const Assets = preload("res://scripts/apk_assets.gd")

const PANEL := Color(0.06, 0.07, 0.16, 0.72)
const KEYS := ["Z", "A", "S", "D", "F"]

var world
var show_help := true
var paused := false
var dt := 0.0


static func skill_slots() -> Array:
	var cx := Rules.VIEW_W - 110.0
	var cy := Rules.VIEW_H - 110.0
	return [
		{"pos": Vector2(cx, cy), "r": 52.0},
		{"pos": Vector2(cx - 130, cy + 30), "r": 34.0},
		{"pos": Vector2(cx - 112, cy - 60), "r": 34.0},
		{"pos": Vector2(cx - 40, cy - 128), "r": 34.0},
		{"pos": Vector2(cx + 54, cy - 150), "r": 34.0},
	]


static func item_buttons() -> Array:
	var out: Array = []
	var ids := ["hpPotion", "mpPotion", "auto"]
	for i in ids.size():
		out.append({"id": ids[i], "rect": Rect2(Rules.VIEW_W - 560.0 + i * 62.0, Rules.VIEW_H - 84.0, 54.0, 54.0)})
	return out


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(Rules.VIEW_W, Rules.VIEW_H)


func _process(delta: float) -> void:
	dt = delta
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var p = world.player
	var prog: Dictionary = world.progress
	var s: Dictionary = p.stats()

	# Status panel with portrait.
	D.rounded(self, Rect2(12, 12, 390, 96), 10.0, PANEL)
	var portrait := Assets.portrait(prog.job)
	var tx := 24.0
	if portrait != null:
		draw_texture_rect(portrait, Rect2(18, 16, 76, 76 * portrait.get_height() / float(portrait.get_width())), false)
		tx = 100.0
	D.text(self, Vector2(tx, 36), "Lv.%d" % prog.level, 18, Color("#ffd54f"), HORIZONTAL_ALIGNMENT_LEFT)
	D.text(self, Vector2(tx + 60, 36), prog.name, 18, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	D.text(self, Vector2(tx, 54), "%s  ·  Lực chiến %s" % [p.job().name, Rules.format_number(Rules.combat_power(s))], 13, Color("#b0bec5"), HORIZONTAL_ALIGNMENT_LEFT)
	var bw := 390.0 - (tx - 12.0) - 12.0
	D.bar(self, Rect2(tx, 62, bw, 18), p.hp / s.maxHp, Color("#e53935"), "%d / %d" % [ceil(p.hp), s.maxHp])
	D.bar(self, Rect2(tx, 84, bw, 18), p.mp / s.maxMp, Color("#1e88e5"), "%d / %d" % [floor(p.mp), s.maxMp])

	for i in p.buffs.size():
		var b: Dictionary = p.buffs[i]
		var x: float = 24.0 + i * 46.0
		D.rounded(self, Rect2(x, 116, 40, 40), 8.0, PANEL)
		D.text(self, Vector2(x + 20, 132), String(b.name).split(" ")[0], 11, Color("#ffd54f"))
		D.text(self, Vector2(x + 20, 149), "%ds" % ceil(b.t), 11, Color.WHITE)

	_draw_minimap()
	_draw_boss_bar()

	D.rounded(self, Rect2(12, Rules.VIEW_H - 78, 300, 44), 10.0, PANEL)
	D.text(self, Vector2(24, Rules.VIEW_H - 50), "● %s meso" % Rules.format_number(prog.meso), 15, Color("#ffca28"), HORIZONTAL_ALIGNMENT_LEFT)
	D.text(self, Vector2(180, Rules.VIEW_H - 50), "Vũ khí +%d" % prog.weaponLv, 15, Color("#80deea"), HORIZONTAL_ALIGNMENT_LEFT)

	_draw_skills()

	var need := Rules.exp_to_next(prog.level)
	var pct: float = 100.0 if prog.level >= Rules.MAX_LEVEL else prog.exp * 100.0 / need
	D.bar(self, Rect2(0, Rules.VIEW_H - 14, Rules.VIEW_W, 14), pct / 100.0, Color("#c6ff00"), "EXP %.2f%%" % pct)

	var n: Dictionary = world.last_notice
	if not n.is_empty():
		n.t += dt
		if n.t < 3.0:
			var a: float = (3.0 - n.t) * 2.0 if n.t > 2.5 else 1.0
			var w := D.text_width(n.text, 20) + 40.0
			D.rounded(self, Rect2(Rules.VIEW_W / 2.0 - w / 2.0, 150, w, 38), 19.0, Color(PANEL, PANEL.a * a))
			D.text(self, Vector2(Rules.VIEW_W / 2.0, 176), n.text, 20, Color(n.color, a))

	if p.dead:
		draw_rect(Rect2(0, 0, Rules.VIEW_W, Rules.VIEW_H), Color(0, 0, 0, 0.45))
		D.text(self, Vector2(Rules.VIEW_W / 2.0, Rules.VIEW_H / 2.0), "Hồi sinh sau %d..." % ceil(p.respawn_t), 36, Color.WHITE)
	if show_help:
		_draw_help()
	if paused:
		draw_rect(Rect2(0, 0, Rules.VIEW_W, Rules.VIEW_H), Color(0, 0, 0, 0.5))
		D.text(self, Vector2(Rules.VIEW_W / 2.0, Rules.VIEW_H / 2.0), "TẠM DỪNG", 40, Color.WHITE)


func _draw_minimap() -> void:
	var map: Dictionary = world.map
	var w := 230.0
	var sc := w / float(map.width)
	var h := float(map.height) * sc
	var x0 := Rules.VIEW_W - w - 16.0
	var y0 := 36.0
	D.rounded(self, Rect2(x0 - 8, 10, w + 16, h + 34), 10.0, PANEL)
	D.text(self, Vector2(x0 + w / 2.0, 28), map.name, 13, Color.WHITE)
	for fh in map.footholds:
		draw_line(Vector2(x0 + float(fh.x1) * sc, y0 + float(fh.y) * sc), Vector2(x0 + float(fh.x2) * sc, y0 + float(fh.y) * sc), Color("#90a4ae"), 2.0)
	for pt in map.portals:
		if pt.has("to"):
			draw_rect(Rect2(x0 + float(pt.x) * sc - 2, y0 + float(pt.y) * sc - 8, 4, 8), Color("#4fc3f7"))
	for m in world.monsters:
		if not m.dead:
			draw_rect(Rect2(x0 + m.x * sc - 1.5, y0 + m.y * sc - 4, 3, 3), Color("#ef5350"))
	draw_circle(Vector2(x0 + world.player.x * sc, y0 + world.player.y * sc - 4), 4.0, Color("#ffeb3b"))


func _draw_boss_bar() -> void:
	var b = world.boss()
	if b == null and world.boss_timer <= 0.0:
		return
	var w := 520.0
	var x := Rules.VIEW_W / 2.0 - w / 2.0
	D.rounded(self, Rect2(x - 10, 10, w + 20, 70), 10.0, PANEL)
	D.text(self, Vector2(Rules.VIEW_W / 2.0, 30), "Thời gian " + Rules.format_time(world.boss_timer), 14, Color.WHITE)
	if b != null:
		D.text(self, Vector2(Rules.VIEW_W / 2.0, 48), b.def.name, 14, Color("#ffd54f"))
		D.bar(self, Rect2(x, 54, w, 16), b.hp / b.max_hp, Color("#43a047"), "%s / %s" % [Rules.format_number(b.hp), Rules.format_number(b.max_hp)])
	elif world.boss_result == "clear":
		D.text(self, Vector2(Rules.VIEW_W / 2.0, 58), "Đã chinh phục!", 14, Color("#69f0ae"))


func _draw_skills() -> void:
	var p = world.player
	var slots := skill_slots()
	var skills: Array = p.job().skills
	var frame := Assets.tex("button_empty")
	var attack_icon := Assets.tex("button_attack")
	for i in skills.size():
		var skill: Dictionary = skills[i]
		var slot: Dictionary = slots[i]
		var c: Vector2 = slot.pos
		var r: float = slot.r
		var ready: bool = p.cooldowns[i] <= 0.0
		var enough: bool = p.mp >= float(skill.mp)
		var tex := attack_icon if i == 0 and attack_icon != null else frame
		if tex != null:
			draw_texture_rect(tex, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, 0.9))
		else:
			draw_circle(c, r, Color(0.06, 0.07, 0.16, 0.8))
		draw_arc(c, r - 1.0, 0, TAU, 40, Color(p.job().color) if enough else Color("#555555"), 3.0, true)
		if not ready:
			var frac: float = p.cooldowns[i] / float(skill.cooldown)
			var pts := PackedVector2Array([c])
			for j in 25:
				var a := -PI / 2.0 + frac * TAU * j / 24.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			if pts.size() >= 3:
				draw_colored_polygon(pts, Color(0, 0, 0, 0.6))
		if i > 0 or attack_icon == null:
			D.text(self, c + Vector2(0, 4), skill.name, 14 if i == 0 else 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 3, Color(0, 0, 0, 0.8))
		D.text(self, c + Vector2(0, -r + 16), KEYS[i], 12, Color("#ffd54f"), HORIZONTAL_ALIGNMENT_CENTER, 3, Color(0, 0, 0, 0.8))
		if not ready:
			D.text(self, c + Vector2(0, 20), "%.1f" % p.cooldowns[i], 12, Color.WHITE)

	var keys := {"hpPotion": "Q", "mpPotion": "W", "auto": "T"}
	for b in item_buttons():
		var rect: Rect2 = b.rect
		if b.id == "auto":
			D.rounded(self, rect, 12.0, Color("#ffb300") if world.auto else PANEL)
			var col := Color("#3e2723") if world.auto else Color.WHITE
			D.text(self, rect.position + Vector2(27, 30), "AUTO", 14, col)
			D.text(self, rect.position + Vector2(27, 46), keys.auto, 11, col)
			continue
		D.rounded(self, rect, 12.0, PANEL)
		D.rounded(self, Rect2(rect.position + Vector2(18, 14), Vector2(18, 24)), 5.0, Color(Data.ITEMS[b.id].color))
		D.text(self, rect.position + Vector2(5, 14), keys[b.id], 12, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		D.text(self, rect.position + Vector2(50, 50), str(world.progress.potions[b.id]), 12, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_help() -> void:
	var lines := [
		["← →", "Di chuyển"],
		["↑ / ↓", "Leo thang · vào cổng (↑)"],
		["Space / C", "Nhảy · nhảy đôi trên không"],
		["↓ + Space", "Nhảy xuống tầng dưới"],
		["Z", "Đánh thường"],
		["A S D F", "Kỹ năng 1–4"],
		["Q / W", "Thuốc HP / MP"],
		["T", "Bật/tắt tự động săn"],
		["U", "Cường hóa vũ khí (tốn meso)"],
		["P / Esc", "Tạm dừng"],
		["H", "Ẩn/hiện hướng dẫn"],
	]
	var w := 420.0
	var h := 46.0 + lines.size() * 26.0
	var x := Rules.VIEW_W / 2.0 - w / 2.0
	var y := Rules.VIEW_H / 2.0 - h / 2.0
	D.rounded(self, Rect2(x, y, w, h), 16.0, PANEL)
	D.text(self, Vector2(Rules.VIEW_W / 2.0, y + 30), "Điều khiển", 18, Color("#ffd54f"))
	for i in lines.size():
		D.text(self, Vector2(x + 140, y + 62 + i * 26), lines[i][0], 15, Color("#80deea"), HORIZONTAL_ALIGNMENT_RIGHT)
		D.text(self, Vector2(x + 160, y + 62 + i * 26), lines[i][1], 15, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
