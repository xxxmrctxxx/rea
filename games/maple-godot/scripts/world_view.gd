extends Node2D
## Draws the map, monsters, player, drops and effects in world coordinates.
## The player uses full-body character art from the APK when it has been
## extracted; monsters and maps are drawn from shapes.

const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/rules.gd")
const D = preload("res://scripts/draw_util.gd")
const Assets = preload("res://scripts/apk_assets.gd")

const THEMES := {
	"day": {"ground": Color("#8d6e63"), "top": Color("#7cc84a"), "ladder": Color("#c49a6c")},
	"dusk": {"ground": Color("#5d4037"), "top": Color("#4f8a3b"), "ladder": Color("#a1887f")},
	"boss": {"ground": Color("#3c2a63"), "top": Color("#9f7bff"), "ladder": Color("#7e6bb3")},
}
const PLAYER_ART_HEIGHT := 104.0

var world
var time := 0.0
var camera := Camera2D.new()


func _ready() -> void:
	add_child(camera)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.make_current()


func bind(w) -> void:
	world = w
	_apply_limits()
	w.map_changed.connect(_apply_limits)


func _apply_limits() -> void:
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world.map.width)
	camera.limit_bottom = int(world.map.height)
	camera.position = _camera_target()
	camera.reset_smoothing()


func _camera_target() -> Vector2:
	return Vector2(world.player.x, world.player.y - Rules.VIEW_H * 0.12)


func _process(delta: float) -> void:
	if world == null:
		return
	time += delta
	camera.position = _camera_target()
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var theme: Dictionary = THEMES.get(world.map.theme, THEMES.day)
	_draw_map(theme)
	for d in world.drops:
		_draw_drop(d)
	for m in world.monsters:
		_draw_monster(m)
	_draw_player(world.player)
	for pr in world.projectiles:
		_draw_projectile(pr)
	for e in world.effects:
		_draw_effect(e)
	for t in world.texts:
		_draw_text(t)


# --- map --------------------------------------------------------------------

func _draw_map(theme: Dictionary) -> void:
	var map: Dictionary = world.map
	for l in map.ladders:
		var lx := float(l.x)
		draw_line(Vector2(lx - 10, float(l.top) - 6), Vector2(lx - 10, float(l.bottom)), theme.ladder, 4.0)
		draw_line(Vector2(lx + 10, float(l.top) - 6), Vector2(lx + 10, float(l.bottom)), theme.ladder, 4.0)
		var ry := float(l.top) + 10.0
		while ry < float(l.bottom):
			draw_line(Vector2(lx - 10, ry), Vector2(lx + 10, ry), theme.ladder, 3.0)
			ry += 18.0
	for fh in map.footholds:
		var x1 := float(fh.x1)
		var x2 := float(fh.x2)
		var fy := float(fh.y)
		var ground := fy >= float(map.height) - 120.0
		var depth := float(map.height) - fy + 200.0 if ground else 26.0
		if ground:
			draw_rect(Rect2(x1, fy, x2 - x1, depth), theme.ground)
		else:
			D.rounded(self, Rect2(x1, fy, x2 - x1, depth), 12.0, theme.ground)
		var bx := x1 + 20.0
		while bx < x2 - 10.0:
			draw_rect(Rect2(bx, fy + 12.0, 18.0, 6.0), Color(0, 0, 0, 0.12))
			bx += 46.0
		D.rounded(self, Rect2(x1 - 4.0, fy - 6.0, x2 - x1 + 8.0, 12.0), 6.0, theme.top)
	for pt in map.portals:
		if not pt.has("to"):
			continue
		var c := Vector2(float(pt.x), float(pt.y) - 45.0)
		var pulse := 1.0 + sin(time * 4.0) * 0.08
		D.ellipse(self, c, 34.0 * pulse, 52.0 * pulse, Color(0.3, 0.5, 1.0, 0.25))
		D.ellipse(self, c, 24.0 * pulse, 40.0 * pulse, Color(0.5, 0.8, 1.0, 0.45))
		D.ellipse(self, c, 10.0, 18.0, Color(1, 1, 1, 0.9))
		for i in 3:
			var a := time * 3.0 + i * TAU / 3.0
			D.ellipse_arc(self, c, 26.0, 42.0, a, a + 1.2, Color(0.8, 0.95, 1.0, 0.8), 2.0)


# --- monsters ---------------------------------------------------------------

func _draw_monster(m) -> void:
	var d: Dictionary = m.def
	var w: float = m.w
	var h: float = m.h
	var alpha := 1.0
	var lift := 0.0
	if m.dead:
		alpha = maxf(0.0, m.death_t / 0.5)
		lift = -(0.5 - m.death_t) * 40.0
	var base := Color(d.color)
	if m.hurt_t > 0.0:
		base = base.lightened(0.5)
	base.a = alpha
	var bob := sin(m.anim * 8.0) * (2.0 if m.vx != 0.0 else 1.0) if m.on_ground else 0.0
	draw_set_transform(Vector2(m.x, m.y + lift), 0.0, Vector2(m.facing, 1))
	D.ellipse(self, Vector2.ZERO, w * 0.45, 5.0, Color(0, 0, 0, 0.2 * alpha))
	var white := Color(1, 1, 1, 0.85 * alpha)
	match d.shape:
		"mushroom":
			D.rounded(self, Rect2(-w * 0.28, -h * 0.55 + bob, w * 0.56, h * 0.55 - bob), 8.0, Color(0.97, 0.88, 0.71, alpha))
			draw_colored_polygon(D.ellipse_points(Vector2(0, -h * 0.55 + bob), w * 0.52, h * 0.38, PI, TAU, 20), base)
			for s in [[-0.25, -0.75, 0.09], [0.15, -0.82, 0.07], [0.3, -0.62, 0.06]]:
				draw_circle(Vector2(w * s[0], h * s[1] + bob), w * s[2], white)
			_draw_eyes(Vector2(w * 0.12, -h * 0.32 + bob), w * 0.06, m.aggro, alpha)
			if d.get("horn", false):
				draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.1, -h * 0.9 + bob), Vector2(0, -h * 1.15 + bob), Vector2(w * 0.1, -h * 0.9 + bob)]), Color(0.43, 0.3, 0.25, alpha))
			if d.get("crown", false):
				var cy := -h * 0.9 + bob
				var pts := PackedVector2Array([Vector2(-w * 0.2, cy)])
				for i in 5:
					pts.append(Vector2(-w * 0.2 + w * 0.4 * i / 4.0, cy - (10.0 if i % 2 else 34.0)))
				pts.append(Vector2(w * 0.2, cy))
				draw_colored_polygon(pts, Color(1, 0.84, 0.31, alpha))
		"snail":
			D.ellipse(self, Vector2(4, -8), w * 0.5, 9.0, Color(0.78, 0.9, 0.79, alpha))
			draw_circle(Vector2(-4, -h * 0.55 + bob), h * 0.48, base)
			var spiral := PackedVector2Array()
			var a := 0.0
			while a < 12.0:
				spiral.append(Vector2(-4 + cos(a) * a * 1.2, -h * 0.55 + bob + sin(a) * a * 1.2))
				a += 0.3
			draw_polyline(spiral, Color(1, 1, 1, 0.7 * alpha), 2.0)
			_draw_eyes(Vector2(w * 0.42, -18), 3.0, m.aggro, alpha)
		"slime":
			var sq := 1.0 + sin(m.anim * 6.0) * 0.08
			D.ellipse(self, Vector2(0, -h * 0.45 * sq), w * 0.5 / sq, h * 0.45 * sq, base)
			D.ellipse(self, Vector2(-w * 0.18, -h * 0.65), 8.0, 5.0, Color(1, 1, 1, 0.4 * alpha))
			_draw_eyes(Vector2(w * 0.12, -h * 0.45), 4.0, m.aggro, alpha)
		"pig":
			D.ellipse(self, Vector2(0, -h * 0.5 + bob), w * 0.5, h * 0.42, base)
			draw_rect(Rect2(-w * 0.35, -h * 0.2, 8, h * 0.2), base)
			draw_rect(Rect2(w * 0.22, -h * 0.2, 8, h * 0.2), base)
			D.ellipse(self, Vector2(w * 0.45, -h * 0.45 + bob), 10.0, 8.0, Color(0.97, 0.73, 0.82, alpha))
			draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.1, -h * 0.9), Vector2(-w * 0.3, -h * 1.05), Vector2(-w * 0.3, -h * 0.8), Vector2(w * 0.1, -h * 0.95), Vector2(w * 0.1, -h * 0.75)]), Color(0.91, 0.12, 0.39, alpha))
			_draw_eyes(Vector2(w * 0.25, -h * 0.6 + bob), 4.0, m.aggro, alpha)
	draw_set_transform(Vector2.ZERO)

	if not m.dead and not m.is_boss() and m.hp < m.max_hp:
		var bw := maxf(48.0, w)
		var rect := Rect2(m.x - bw / 2.0, m.y - h - 18.0, bw, 10.0)
		var frame := Assets.tex("hpbar_monster")
		if frame != null:
			draw_rect(rect.grow(1.0), Color(0, 0, 0, 0.7))
			var src := Rect2(0, 0, frame.get_width() * (m.hp / m.max_hp), frame.get_height() / 2.0)
			draw_texture_rect_region(frame, Rect2(rect.position, Vector2(bw * (m.hp / m.max_hp), rect.size.y)), src)
		else:
			D.bar(self, rect, m.hp / m.max_hp, Color("#e53935"))
	if not m.dead and (m.is_boss() or m.aggro):
		var label := "Lv.%d %s" % [int(d.level), d.name]
		var tw := D.text_width(label, 12) + 10.0
		draw_rect(Rect2(m.x - tw / 2.0, m.y + 4.0, tw, 16.0), Color(0, 0, 0, 0.55))
		D.text(self, Vector2(m.x, m.y + 16.0), label, 12, Color("#ffd54f") if m.is_boss() else Color.WHITE)


func _draw_eyes(at: Vector2, r: float, angry: bool, alpha: float) -> void:
	var c := Color(0.13, 0.13, 0.13, alpha)
	for ex in [at.x - r * 2.2, at.x + r * 0.6]:
		D.ellipse(self, Vector2(ex, at.y), r * 0.8, r * (0.7 if angry else 1.2), c)
	if angry:
		draw_line(Vector2(at.x - r * 3.4, at.y - r * 1.8), Vector2(at.x - r * 1.2, at.y - r * 1.1), c, 2.0)
		draw_line(Vector2(at.x + r * 1.8, at.y - r * 1.8), Vector2(at.x - r * 0.2, at.y - r * 1.1), c, 2.0)


# --- player -----------------------------------------------------------------

func _draw_player(p) -> void:
	if p.dead:
		draw_colored_polygon(PackedVector2Array([Vector2(p.x - 14, p.y), Vector2(p.x - 14, p.y - 40)]) + D.ellipse_points(Vector2(p.x, p.y - 40), 14, 14, PI, TAU, 12) + PackedVector2Array([Vector2(p.x + 14, p.y)]), Color("#cfd8dc"))
		D.text(self, Vector2(p.x, p.y - 28), "RIP", 12, Color("#555555"))
		return
	if p.invuln > 0.0 and int(time * 20.0) % 2 == 0:
		return
	if not p.buffs.is_empty():
		D.ellipse_arc(self, Vector2(p.x, p.y - 2), 38, 10, 0, TAU, Color(1, 0.84, 0.31, 0.35 + 0.2 * sin(time * 6.0)), 3.0)
	D.ellipse(self, Vector2(p.x, p.y), 20, 5, Color(0, 0, 0, 0.25))

	var art := Assets.look_for(p.p)
	if art != null:
		_draw_player_art(p, art)
	else:
		_draw_player_shapes(p)

	var label: String = p.p.name
	var tw := D.text_width(label, 12) + 12.0
	D.rounded(self, Rect2(p.x - tw / 2.0, p.y + 6.0, tw, 17.0), 8.0, Color(0, 0, 0, 0.6))
	D.text(self, Vector2(p.x, p.y + 19.0), label, 12, Color.WHITE)


## Animates the static full-body art: bob while walking, lean on attack,
## sway while climbing.
func _draw_player_art(p, art: Texture2D) -> void:
	var scale := PLAYER_ART_HEIGHT / art.get_height()
	var size := Vector2(art.get_width(), art.get_height()) * scale
	var bob := 0.0
	var tilt := 0.0
	if p.climbing != null:
		tilt = sin(p.walk_phase) * 0.06
	elif p.on_ground and p.vx != 0.0:
		bob = absf(sin(p.walk_phase)) * -5.0
		tilt = sin(p.walk_phase) * 0.04
	elif not p.on_ground:
		tilt = -0.08
	if p.action_t > 0.0:
		tilt = 0.18 * (p.action_t / 0.25)
	draw_set_transform(Vector2(p.x, p.y + bob), tilt * p.facing, Vector2(p.facing, 1))
	draw_texture_rect(art, Rect2(-size.x / 2.0, -size.y + 4.0, size.x, size.y), false)
	draw_set_transform(Vector2.ZERO)


func _draw_player_shapes(p) -> void:
	var job: Dictionary = p.job()
	draw_set_transform(Vector2(p.x, p.y), 0.0, Vector2(p.facing, 1))
	var climbing: bool = p.climbing != null
	var step: float = sin(p.walk_phase) * 6.0
	draw_line(Vector2(-5, -20), Vector2(-5 - (0.0 if climbing else step), -3), Color("#3e2723"), 6.0)
	draw_line(Vector2(5, -20), Vector2(5 + (0.0 if climbing else step), -8 + step if climbing else -3), Color("#3e2723"), 6.0)
	D.rounded(self, Rect2(-12, -40, 24, 24), 6.0, Color(job.color))
	draw_circle(Vector2(0, -54), 17.0, Color("#ffe0bd"))
	draw_colored_polygon(D.ellipse_points(Vector2(-2, -58), 18, 18, PI * 0.9, PI * 2.1, 16), Color("#5d4037"))
	if not climbing:
		D.ellipse(self, Vector2(7, -52), 2.5, 4.0, Color("#222222"))
		var a: float = -1.6 + (1.0 - p.action_t / 0.25) * 2.6 if p.action_t > 0.0 else 0.4
		draw_set_transform(Vector2(p.x, p.y) + Vector2(10 * p.facing, -30), a * p.facing, Vector2(p.facing, 1))
		draw_rect(Rect2(0, -3, 40, 6), Color("#cfd8dc"))
	draw_set_transform(Vector2.ZERO)


# --- drops, projectiles, effects, texts -------------------------------------

func _draw_drop(d) -> void:
	var bob := sin(time * 4.0 + d.x) * 3.0 if d.on_ground else 0.0
	var c := Vector2(d.x, d.y - 10.0 + bob)
	if d.kind == "meso":
		D.ellipse(self, c, 9.0 * absf(cos(time * 3.0)) + 2.0, 9.0, Color("#ffca28"))
		D.ellipse_arc(self, c, 9.0 * absf(cos(time * 3.0)) + 2.0, 9.0, 0, TAU, Color("#ff8f00"), 2.0)
	else:
		D.rounded(self, Rect2(c + Vector2(-7, -6), Vector2(14, 16)), 4.0, Color(Data.ITEMS[d.kind].color))
		draw_rect(Rect2(c + Vector2(-3, -11), Vector2(6, 6)), Color("#dddddd"))


func _draw_projectile(pr: Dictionary) -> void:
	var fx: String = pr.skill.fx
	var c := Vector2(pr.x, pr.y)
	var dir: float = pr.dir
	match fx:
		"arrow":
			draw_line(c + Vector2(-30 * dir, 0), c + Vector2(10 * dir, 0), Color("#fff8e1"), 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(16 * dir, 0), c + Vector2(6 * dir, -5), c + Vector2(6 * dir, 5)]), Color("#ffeb3b"))
		"star":
			var pts := PackedVector2Array()
			for i in 8:
				var r := 4.0 if i % 2 else 12.0
				var a := time * 20.0 + i * PI / 4.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, Color("#cfd8dc"))
		_:
			var r := 20.0 if fx == "cannon" else 12.0
			var col := Color("#ff9800") if fx == "cannon" else Color("#ce93d8")
			draw_circle(c, r * 1.6, Color(col, 0.3))
			draw_circle(c, r, col)
			draw_circle(c, r * 0.45, Color.WHITE)


func _draw_effect(e: Dictionary) -> void:
	var k: float = e.t / e.dur
	var fade := 1.0 - k
	var c := Vector2(e.x, e.y)
	var f: float = e.facing
	var w: float = e.w if e.w > 0.0 else 120.0
	var h: float = e.h if e.h > 0.0 else 80.0
	match e.type:
		"slash", "punch", "spin":
			var col := Color("#ffcc80") if e.type == "punch" else Color("#e3f2fd")
			var start := k * PI * 4.0 if e.type == "spin" else -1.2
			var span := 4.0 if e.type == "spin" else 2.4
			var pts := D.ellipse_points(c, maxf(30.0, w * 0.45), h * 0.45, start, start + span, 20)
			if f < 0.0:
				for i in pts.size():
					pts[i].x = c.x - (pts[i].x - c.x)
			draw_polyline(pts, Color(col, fade), 10.0 * fade + 2.0, true)
		"quake":
			for i in range(-4, 5):
				var hh := 30.0 * sin(k * PI) * (1.0 - absf(i) / 5.0)
				draw_rect(Rect2(e.x + i * (w / 9.0) - 6.0, e.y + h * 0.3 - hh, 12.0, 30.0), Color(1, 0.72, 0.3, fade))
			D.ellipse_arc(self, c + Vector2(0, h * 0.4), maxf(1.0, w / 2.0 * k), maxf(1.0, 18.0 * k), 0, TAU, Color(1, 0.95, 0.88, fade), 4.0)
		"bolt":
			var pts := PackedVector2Array()
			var bx := -w / 2.0
			while bx <= w / 2.0:
				pts.append(c + Vector2(bx * f, randf_range(-20.0, 20.0)))
				bx += 30.0
			draw_polyline(pts, Color(1, 1, 0.4, fade * 0.5), 10.0)
			draw_polyline(pts, Color(1, 0.96, 0.62, fade), 4.0)
		"ice", "rain":
			var col := Color("#b3e5fc") if e.type == "ice" else Color("#fff9c4")
			col.a = fade
			for i in 14:
				var x: float = e.x - w / 2.0 + fmod(i * 37.0, w)
				var y: float = e.y - h + fmod(k * 2.0 + i * 0.13, 1.0) * h * 1.3
				draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x - 5, y - 26), Vector2(x + 5, y - 26)]), col)
		"dash", "flash":
			var dh: float = (e.h if e.h > 0.0 else 40.0) / 2.0
			var cols := PackedColorArray([Color(1, 1, 1, 0), Color(0.78, 0.9, 1, 0.9 * fade), Color(0.78, 0.9, 1, 0.9 * fade), Color(1, 1, 1, 0)])
			if f < 0.0:
				cols = PackedColorArray([cols[1], cols[0], cols[3], cols[2]])
			draw_polygon(PackedVector2Array([c + Vector2(-w / 2, -dh / 2), c + Vector2(w / 2, -dh / 2), c + Vector2(w / 2, dh / 2), c + Vector2(-w / 2, dh / 2)]), cols)
		"blink":
			draw_arc(c, 10.0 + k * 40.0, 0, TAU, 32, Color(0.88, 0.75, 0.91, fade), 3.0)
		"aura", "potion":
			for i in 10:
				var a := i / 10.0 * TAU + k * 3.0
				draw_circle(c + Vector2(cos(a) * 30.0, 20.0 - k * 70.0 + sin(a) * 6.0), 4.0, Color(e.color, fade))
		"levelup":
			draw_polygon(PackedVector2Array([c + Vector2(-40, -200), c + Vector2(40, -200), c + Vector2(40, 40), c + Vector2(-40, 40)]), PackedColorArray([Color(1, 0.84, 0.31, 0), Color(1, 0.84, 0.31, 0), Color(1, 0.84, 0.31, 0.7 * fade), Color(1, 0.84, 0.31, 0.7 * fade)]))
			D.text(self, c + Vector2(0, -90 - k * 30), "LEVEL UP!", 30, Color(1, 0.97, 0.88, fade), HORIZONTAL_ALIGNMENT_CENTER, 6, Color(0.9, 0.32, 0, fade))
		"shockwave":
			D.ellipse_arc(self, c, maxf(1.0, w / 2.0 * k), 30.0 * k + 4.0, PI, TAU, Color(1, 0.44, 0.26, fade), 8.0)


func _draw_text(t: Dictionary) -> void:
	var k: float = t.t / t.dur
	var size := 16 if t.style == "small" else (34 if t.style == "crit" else 28)
	if k < 0.1:
		size = int(size * (1.0 + (0.1 - k) * 4.0))
	var col: Color = t.color
	col.a = 1.0 if k < 0.7 else 1.0 - (k - 0.7) / 0.3
	D.text(self, Vector2(t.x, t.y), t.text, size, col, HORIZONTAL_ALIGNMENT_CENTER, 6, Color(0.16, 0.08, 0, col.a * 0.85))
