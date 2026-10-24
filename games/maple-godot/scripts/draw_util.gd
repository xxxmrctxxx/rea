extends RefCounted
## Small drawing helpers shared by the world view, background and HUD.

static var _boxes := {}


static func ellipse_points(c: Vector2, rx: float, ry: float, from := 0.0, to := TAU, n := 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a: float = lerp(from, to, float(i) / n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color) -> void:
	ci.draw_colored_polygon(ellipse_points(c, rx, ry, 0.0, TAU, 28), color)


static func ellipse_arc(ci: CanvasItem, c: Vector2, rx: float, ry: float, from: float, to: float, color: Color, width: float) -> void:
	ci.draw_polyline(ellipse_points(c, rx, ry, from, to, 24), color, width, true)


static func rounded(ci: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var key := "%s|%d" % [color.to_html(), int(radius)]
	var sb: StyleBoxFlat = _boxes.get(key)
	if sb == null:
		sb = StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(int(radius))
		sb.anti_aliasing = true
		_boxes[key] = sb
	sb.draw(ci.get_canvas_item(), rect)


static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER, outline := 0, outline_color := Color(0.15, 0.08, 0.0, 0.9)) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	if outline > 0:
		ci.draw_string_outline(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_color)
	ci.draw_string(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func text_width(s: String, size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func bar(ci: CanvasItem, rect: Rect2, frac: float, color: Color, label := "") -> void:
	rounded(ci, rect, rect.size.y / 2.0, Color(0, 0, 0, 0.55))
	var inner := Rect2(rect.position + Vector2(1, 1), Vector2((rect.size.x - 2.0) * clampf(frac, 0.0, 1.0), rect.size.y - 2.0))
	rounded(ci, inner, (rect.size.y - 2.0) / 2.0, color)
	if label != "":
		var size := int(rect.size.y) - 3
		text(ci, Vector2(rect.position.x + rect.size.x / 2.0, rect.position.y + rect.size.y - 3.0), label, size, Color.WHITE)
