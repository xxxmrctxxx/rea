extends RefCounted
## Platform physics: one-way horizontal footholds, ladders and gravity.
## Bodies use the feet position (x, y); y is the foothold height when standing.
## A body is any object with x, y, vx, vy, w, h, on_ground, fh, drop_from,
## jumps_used fields.

const Rules = preload("res://scripts/rules.gd")


static func covers(fh, x: float) -> bool:
	return fh != null and x >= float(fh.x1) and x <= float(fh.x2)


## Highest foothold under x whose height lies in [y_from, y_to].
static func foothold_between(map: Dictionary, x: float, y_from: float, y_to: float, ignore = null):
	var best = null
	for fh in map.footholds:
		if ignore != null and is_same(fh, ignore):
			continue
		if not covers(fh, x) or float(fh.y) < y_from or float(fh.y) > y_to:
			continue
		if best == null or fh.y < best.y:
			best = fh
	return best


static func foothold_at(map: Dictionary, x: float, y: float):
	return foothold_between(map, x, y - Rules.STEP_HEIGHT, y + Rules.STEP_HEIGHT)


static func find_ladder(map: Dictionary, x: float, y: float, want_up: bool):
	for l in map.ladders:
		if absf(float(l.x) - x) > Rules.LADDER_GRAB_RANGE:
			continue
		if want_up and y > float(l.top) + 2.0 and y <= float(l.bottom) + 2.0:
			return l
		if not want_up and absf(y - float(l.top)) <= 4.0:
			return l
	return null


## Advances a body by dt. Returns false if it fell below the map.
static func step_body(body, map: Dictionary, dt: float) -> bool:
	var half_w: float = body.w / 2.0
	body.x = clampf(body.x + body.vx * dt, half_w, float(map.width) - half_w)

	if body.on_ground:
		if not covers(body.fh, body.x):
			body.fh = foothold_at(map, body.x, body.y)
			if body.fh == null:
				body.on_ground = false
		if body.fh != null:
			body.y = float(body.fh.y)
			body.vy = 0.0

	if not body.on_ground:
		body.vy = minf(body.vy + Rules.GRAVITY * dt, Rules.MAX_FALL)
		var next_y: float = body.y + body.vy * dt
		if body.drop_from != null and next_y > float(body.drop_from.y) + 4.0:
			body.drop_from = null
		var land = null
		if body.vy > 0.0:
			land = foothold_between(map, body.x, body.y, next_y, body.drop_from)
		if land != null:
			body.y = float(land.y)
			body.vy = 0.0
			body.on_ground = true
			body.fh = land
			body.drop_from = null
			body.jumps_used = 0
		else:
			body.y = next_y

	return body.y <= float(map.height) + 200.0


static func overlaps(a, b) -> bool:
	return absf(a.x - b.x) * 2.0 < a.w + b.w and absf((a.y - a.h / 2.0) - (b.y - b.h / 2.0)) * 2.0 < a.h + b.h


## Box given by centre x, top y, width and height.
static func box_hits(box: Dictionary, body) -> bool:
	return absf(box.cx - body.x) * 2.0 < box.w + body.w and body.y > box.top and body.y - body.h < box.top + box.h
