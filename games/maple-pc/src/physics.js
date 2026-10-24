"use strict";
// Platform physics: one-way horizontal footholds, ladders, gravity.
// Bodies use the feet position (x, y), so y is the foothold height when
// standing.
(function (root) {
  const MS = root.MS;
  const C = MS.CONST;

  const covers = (fh, x) => x >= fh.x1 && x <= fh.x2;

  // Highest foothold under x whose height lies in [yFrom, yTo].
  MS.footholdBetween = (map, x, yFrom, yTo, ignore) => {
    let best = null;
    for (const fh of map.footholds) {
      if (fh === ignore || !covers(fh, x)) continue;
      if (fh.y < yFrom || fh.y > yTo) continue;
      if (!best || fh.y < best.y) best = fh;
    }
    return best;
  };

  MS.footholdAt = (map, x, y) =>
    MS.footholdBetween(map, x, y - C.STEP_HEIGHT, y + C.STEP_HEIGHT, null);

  MS.findLadder = (map, x, y, wantUp) => {
    for (const l of map.ladders) {
      if (Math.abs(l.x - x) > C.LADDER_GRAB_RANGE) continue;
      // Up: anywhere from the bottom to just under the top.
      // Down: standing on the top platform.
      if (wantUp && y > l.top + 2 && y <= l.bottom + 2) return l;
      if (!wantUp && Math.abs(y - l.top) <= 4) return l;
    }
    return null;
  };

  // Advances a body by dt. Returns "fell" if it dropped below the map.
  MS.stepBody = (body, map, dt) => {
    const halfW = body.w / 2;
    body.x = MS.clamp(body.x + body.vx * dt, halfW, map.width - halfW);

    if (body.onGround) {
      if (!body.fh || !covers(body.fh, body.x)) {
        body.fh = MS.footholdAt(map, body.x, body.y);
        if (!body.fh) body.onGround = false;
      }
      if (body.fh) {
        body.y = body.fh.y;
        body.vy = 0;
      }
    }

    if (!body.onGround) {
      body.vy = Math.min(body.vy + C.GRAVITY * dt, C.MAX_FALL);
      const nextY = body.y + body.vy * dt;
      if (body.dropFrom && nextY > body.dropFrom.y + 4) body.dropFrom = null;
      const land =
        body.vy > 0
          ? MS.footholdBetween(map, body.x, body.y, nextY, body.dropFrom)
          : null;
      if (land) {
        body.y = land.y;
        body.vy = 0;
        body.onGround = true;
        body.fh = land;
        body.dropFrom = null;
        body.jumpsUsed = 0;
      } else {
        body.y = nextY;
      }
    }

    return body.y > map.height + 200 ? "fell" : "ok";
  };

  MS.overlaps = (a, b) =>
    Math.abs(a.x - b.x) * 2 < a.w + b.w &&
    Math.abs(a.y - a.h / 2 - (b.y - b.h / 2)) * 2 < a.h + b.h;

  // Axis-aligned box given by center x, top y, width, height.
  MS.boxHits = (box, body) =>
    Math.abs(box.cx - body.x) * 2 < box.w + body.w &&
    body.y > box.top &&
    body.y - body.h < box.top + box.h;
})(globalThis);
