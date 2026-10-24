import test from "node:test";
import assert from "node:assert/strict";
import { MS, seed } from "./load.mjs";

seed(42);

test("exp curve grows with level", () => {
  assert.equal(MS.expToNext(1), 20);
  for (let lv = 1; lv < 30; lv++)
    assert.ok(MS.expToNext(lv + 1) > MS.expToNext(lv));
});

test("gainExp carries overflow across several levels", () => {
  const p = MS.newProgress("t", "warrior");
  const gained = MS.gainExp(p, MS.expToNext(1) + MS.expToNext(2) + 5);
  assert.equal(gained, 2);
  assert.equal(p.level, 3);
  assert.equal(p.exp, 5);
});

test("damage is at least 1 and crits multiply", () => {
  const always = () => 0;
  const hit = MS.calcDamage(100, 100, 0, 1, 0, always);
  assert.equal(hit.crit, true);
  assert.equal(hit.amount, Math.round(100 * 0.9 * 1.5));
  assert.equal(MS.calcDamage(1, 10, 999, 0, 0, () => 0.99).amount, 1);
});

test("higher-level monsters take reduced damage", () => {
  const rng = () => 0.5;
  const even = MS.calcDamage(200, 100, 0, 0, 0, rng).amount;
  const harder = MS.calcDamage(200, 100, 0, 0, 5, rng).amount;
  assert.ok(harder < even);
});

test("buffs raise attack and crit", () => {
  const p = MS.newProgress("t", "bowman");
  const base = MS.playerStats(p, []);
  const buffed = MS.playerStats(p, [{ atkBonus: 0.1, critBonus: 0.3 }]);
  assert.ok(buffed.atk > base.atk);
  assert.ok(Math.abs(buffed.crit - (base.crit + 0.3)) < 1e-9);
});

test("weapon enhancement spends meso and respects limits", () => {
  const p = MS.newProgress("t", "thief");
  assert.equal(
    MS.tryEnhance(p, () => 0),
    "nomoney",
  );
  p.meso = 100000;
  assert.equal(
    MS.tryEnhance(p, () => 0),
    "success",
  );
  assert.equal(p.weaponLv, 1);
  assert.equal(p.meso, 100000 - MS.enhanceCost(0));
  assert.equal(
    MS.tryEnhance(p, () => 0.999),
    "fail",
  );
  assert.equal(p.weaponLv, 1);
  p.weaponLv = MS.MAX_ENHANCE;
  assert.equal(
    MS.tryEnhance(p, () => 0),
    "max",
  );
});

test("every job has a basic attack plus four skills", () => {
  for (const job of Object.values(MS.JOBS)) {
    assert.equal(job.skills.length, MS.SKILL_KEYS.length);
    assert.equal(job.skills[0].id, "basic");
    assert.ok(job.skills.some((s) => s.kind === "buff"));
  }
});
