"use strict";
// Shared namespace and helpers. Every game file attaches to globalThis.MS so
// the game runs from plain <script> tags (no bundler) and from Node tests.
(function (root) {
  const MS = (root.MS = root.MS || {});

  MS.clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
  MS.lerp = (a, b, t) => a + (b - a) * t;

  // Seeded RNG so tests and replays are deterministic.
  MS.makeRng = (seed) => {
    let s = seed >>> 0;
    return () => {
      s = (s + 0x6d2b79f5) >>> 0;
      let t = s;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  };
  MS.rng = MS.makeRng(Date.now());
  MS.rand = (min, max) => min + (max - min) * MS.rng();
  MS.randInt = (min, max) => Math.floor(MS.rand(min, max + 1));

  // Movement constants. The client exposes Gravity, FallSpeed, JumpPower,
  // JumpCount and MoveSpeed fields (see docs/analysis.md); the values below
  // are tuned by eye against the gameplay video, not read from the APK.
  MS.CONST = {
    GRAVITY: 2100,
    MAX_FALL: 950,
    WALK_SPEED: 230,
    JUMP_SPEED: 640,
    DOUBLE_JUMP_SPEED_X: 520,
    DOUBLE_JUMP_SPEED_Y: 380,
    JUMP_COUNT: 2,
    CLIMB_SPEED: 150,
    LADDER_GRAB_RANGE: 14,
    STEP_HEIGHT: 10,
    VIEW_W: 1280,
    VIEW_H: 720,
    HIT_INVULN: 1.0,
    PICKUP_RANGE: 60,
  };

  MS.formatNumber = (n) => {
    const v = Math.floor(n);
    if (v >= 1e9) return (v / 1e9).toFixed(1) + "B";
    if (v >= 1e6) return (v / 1e6).toFixed(1) + "M";
    if (v >= 1e4) return (v / 1e3).toFixed(1) + "K";
    return String(v);
  };

  MS.formatTime = (sec) => {
    const s = Math.max(0, Math.ceil(sec));
    const m = Math.floor(s / 60);
    return String(m).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0");
  };
})(globalThis);
