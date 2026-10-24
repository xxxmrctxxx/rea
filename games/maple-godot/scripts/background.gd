extends Node2D
## Screen-space sky with parallax hills, drawn behind the world.

const Rules = preload("res://scripts/rules.gd")
const D = preload("res://scripts/draw_util.gd")

const SKIES := {
	"day": [Color("#8fd3ff"), Color("#e6f7ff"), Color("#a7d8a0"), Color("#6fbf73")],
	"dusk": [Color("#3b2a5a"), Color("#f29e6d"), Color("#6b4c7a"), Color("#3e2f4f")],
	"boss": [Color("#0b0a2a"), Color("#3a1f6b"), Color("#2a1950"), Color("#1b1036")],
}

var world
var camera: Camera2D
var time := 0.0
var stars: Array = []


func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 80:
		stars.append(Vector3(r.randf(), r.randf() * 0.7, r.randf() * 1.8 + 0.4))


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var theme: String = world.map.theme
	var sky: Array = SKIES.get(theme, SKIES.day)
	var W := Rules.VIEW_W
	var H := Rules.VIEW_H
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]), PackedColorArray([sky[0], sky[0], sky[1], sky[1]]))
	var cam := camera.get_screen_center_position() - Vector2(W, H) / 2.0 if camera else Vector2.ZERO

	if theme != "day":
		for s in stars:
			draw_circle(Vector2(s.x * W, s.y * H), s.z, Color(1, 1, 1, 0.4 + 0.4 * sin(time * 2.0 + s.x * 50.0)))
	if theme == "boss":
		var mx := W * 0.62 - cam.x * 0.05
		for i in 6:
			draw_circle(Vector2(mx, 190), 120.0 + i * 22.0, Color(1, 0.86, 1, 0.07))
		draw_circle(Vector2(mx, 190), 120.0, Color("#f6e9ff"))
		for i in 14:
			var t := time * 0.6 + i * 1.7
			var x := fposmod(i * 157.0 + sin(t) * 60.0 - cam.x * 0.3, W)
			var y := 120.0 + fmod(i * 89.0, 420.0) + cos(t * 1.3) * 30.0
			var flap := absf(sin(time * 8.0 + i))
			var col := Color(0.6, 0.8, 1, 0.8) if i % 2 else Color(0.86, 0.55, 1, 0.8)
			D.ellipse(self, Vector2(x - 6.0 * flap, y), 7.0 * flap + 1.0, 10.0, col)
			D.ellipse(self, Vector2(x + 6.0 * flap, y), 7.0 * flap + 1.0, 10.0, col)
	elif theme == "day":
		for i in 6:
			var x := fposmod(i * 260.0 - cam.x * 0.1 + time * 8.0, W + 300.0) - 150.0
			var y := 80.0 + (i % 3) * 50.0
			D.ellipse(self, Vector2(x, y), 70, 24, Color(1, 1, 1, 0.85))
			D.ellipse(self, Vector2(x + 40, y - 12), 45, 22, Color(1, 1, 1, 0.85))
	_hills(sky[2], cam, 0.15, 420.0, 70.0, 0.004)
	_hills(sky[3], cam, 0.35, 520.0, 90.0, 0.007)


func _hills(color: Color, cam: Vector2, factor: float, base_y: float, amp: float, freq: float) -> void:
	var pts := PackedVector2Array([Vector2(0, Rules.VIEW_H)])
	var x := 0.0
	while x <= Rules.VIEW_W:
		var wx := x + cam.x * factor
		pts.append(Vector2(x, base_y - cam.y * factor * 0.5 + sin(wx * freq) * amp + sin(wx * freq * 2.3) * amp * 0.4))
		x += 16.0
	pts.append(Vector2(Rules.VIEW_W, Rules.VIEW_H))
	draw_colored_polygon(pts, color)
