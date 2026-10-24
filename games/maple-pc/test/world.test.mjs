import test from "node:test";
import assert from "node:assert/strict";
import { MS, seed } from "./load.mjs";

seed(7);

const STEP = 1 / 60;
const run = (world, seconds, make) => {
  for (let i = 0; i < seconds * 60; i++)
    world.update(STEP, make ? make(i) : MS.emptyInput());
};

test("maps are consistent: ladders end on footholds, portals link both ways", () => {
  for (const [id, map] of Object.entries(MS.MAPS)) {
    for (const l of map.ladders) {
      assert.ok(MS.footholdAt(map, l.x, l.top), id + " ladder top at " + l.x);
      assert.ok(
        MS.footholdAt(map, l.x, l.bottom),
        id + " ladder bottom at " + l.x,
      );
    }
    for (const p of map.portals) {
      assert.ok(
        MS.footholdAt(map, p.x, p.y),
        id + " portal " + p.id + " on ground",
      );
      if (!p.to) continue;
      const back = MS.MAPS[p.to].portals.find((q) => q.id === p.toPortal);
      assert.ok(back, id + " portal " + p.id + " target exists");
      assert.equal(back.to, id);
    }
    for (const sp of map.spawns) assert.ok(MS.MONSTERS[sp.mob]);
  }
});

test("player lands on the ground and can jump", () => {
  const world = new MS.World(MS.newProgress("t", "warrior"));
  run(world, 0.5);
  const p = world.player;
  assert.equal(p.onGround, true);
  assert.equal(p.y, 1000);
  const jump = MS.emptyInput();
  jump.jumpPressed = true;
  world.update(STEP, jump);
  assert.ok(p.vy < 0);
  run(world, 1.5);
  assert.equal(p.onGround, true);
});

test("one-way platforms: jump up through, drop down with down+jump", () => {
  const world = new MS.World(MS.newProgress("t", "warrior"));
  const p = world.player;
  world.respawnT = Infinity;
  world.monsters = [];
  // Ladder at x=600 leads up to the y=820 platform.
  p.placeAt(600, 1000);
  run(world, 0.2);
  run(world, 2, () => Object.assign(MS.emptyInput(), { up: true }));
  assert.equal(p.y, 820);
  assert.equal(p.onGround, true);
  run(world, 0.1);
  world.update(
    STEP,
    Object.assign(MS.emptyInput(), { down: true, jumpPressed: true }),
  );
  run(world, 1);
  assert.equal(p.y, 1000);
});

test("skills damage monsters, kills grant exp and meso drops", () => {
  const world = new MS.World(MS.newProgress("t", "warrior"));
  const p = world.player;
  world.monsters = [];
  run(world, 0.3);
  const mob = new MS.Monster(
    "snail",
    { mob: "snail", x1: 0, x2: 3000, y: 1000, count: 1 },
    p.x + 60,
  );
  mob.maxHp = mob.hp = 1;
  world.monsters.push(mob);
  run(world, 0.2);
  p.facing = 1;
  world.useSkill(p, 0);
  run(world, 0.2);
  assert.equal(mob.dead, true);
  assert.equal(world.progress.exp, MS.MONSTERS.snail.exp);
  assert.ok(world.drops.some((d) => d.kind === "meso"));
  run(world, 2);
  assert.ok(world.progress.meso > 0, "meso auto-looted");
});

test("projectiles pierce up to maxTargets", () => {
  const world = new MS.World(MS.newProgress("t", "bowman"));
  const p = world.player;
  world.monsters = [];
  run(world, 0.3);
  const sp = { mob: "pig", x1: 0, x2: 3000, y: 1000, count: 0 };
  for (let i = 1; i <= 7; i++)
    world.monsters.push(new MS.Monster("pig", sp, p.x + 80 * i));
  run(world, 0.1);
  for (const m of world.monsters) m.update = () => {};
  p.facing = 1;
  world.useSkill(p, 1);
  run(world, 1);
  const hit = world.monsters.filter((m) => m.hp < m.maxHp).length;
  assert.equal(hit, MS.JOBS.bowman.skills[1].maxTargets);
});

test("portal moves the player to the linked map", () => {
  const world = new MS.World(MS.newProgress("t", "magician"));
  const p = world.player;
  p.placeAt(2900, 1000);
  run(world, 0.2);
  world.update(
    STEP,
    Object.assign(MS.emptyInput(), { upPressed: true, up: true }),
  );
  assert.equal(world.mapId, "forest");
  assert.equal(p.x, 100);
});

test("auto-battle hunts on its own and levels up", () => {
  for (const job of Object.keys(MS.JOBS)) {
    const world = new MS.World(MS.newProgress("t", job));
    world.auto = true;
    run(world, 90);
    assert.ok(
      world.progress.level >= 3,
      job + " reached level " + world.progress.level,
    );
  }
});

test("boss fight: timer runs, shockwave hurts grounded players, boss can be cleared", () => {
  const progress = MS.newProgress("t", "warrior");
  progress.level = 30;
  progress.weaponLv = 15;
  progress.map = "kingRoom";
  const world = new MS.World(progress);
  const boss = world.boss;
  assert.ok(boss);
  const start = world.bossTimer;
  run(world, 1);
  assert.ok(world.bossTimer < start);

  const p = world.player;
  p.placeAt(boss.x - 200, 1000);
  run(world, 0.1);
  p.invuln = 0;
  const hp = p.hp;
  world.bossShockwave(boss);
  assert.ok(p.hp < hp);

  boss.hp = 1;
  world.damageMonster(boss, { amount: 5, crit: false }, 0, 1);
  assert.equal(world.bossResult, "clear");
  assert.equal(progress.bossCleared, true);
});
