"use strict";
// Progression and damage rules.
(function (root) {
  const MS = root.MS;

  MS.MAX_LEVEL = 60;
  MS.MAX_ENHANCE = 15;

  MS.expToNext = (level) => Math.floor(12 * Math.pow(level, 1.6) + 8);

  MS.enhanceBonus = (lv) => lv * 8 + lv * lv;
  MS.enhanceCost = (lv) => 100 * (lv + 1) * (lv + 1);
  MS.enhanceChance = (lv) => Math.max(0.3, 0.95 - lv * 0.05);

  // Explorer jobs get their AP assigned automatically, as in the mobile
  // client, so derived stats depend only on job, level and weapon level.
  MS.playerStats = (p, buffs) => {
    const job = MS.JOBS[p.job];
    const mainStat = 4 + p.level * 5;
    let atk = Math.floor(
      mainStat * job.atkMul + 10 + MS.enhanceBonus(p.weaponLv),
    );
    let crit = job.crit;
    for (const b of buffs || []) {
      atk = Math.floor(atk * (1 + b.atkBonus));
      crit += b.critBonus;
    }
    return {
      maxHp: 50 + p.level * job.hpPerLv,
      maxMp: 30 + p.level * job.mpPerLv,
      atk,
      def: p.level * 2,
      crit: Math.min(1, crit),
    };
  };

  MS.calcDamage = (atk, pct, targetDef, critRate, levelDiff, rng) => {
    const roll = 0.9 + rng() * 0.2;
    let amount = ((atk * pct) / 100) * roll - targetDef * 0.6;
    if (levelDiff > 0) amount *= Math.max(0.4, 1 - 0.05 * levelDiff);
    const crit = rng() < critRate;
    if (crit) amount *= 1.5;
    return { amount: Math.max(1, Math.round(amount)), crit };
  };

  MS.monsterDamage = (mobAtk, playerDef, rng) =>
    Math.max(1, Math.round(mobAtk * (0.85 + rng() * 0.2) - playerDef * 0.5));

  // Adds exp and returns how many levels were gained.
  MS.gainExp = (p, amount) => {
    let gained = 0;
    p.exp += amount;
    while (p.level < MS.MAX_LEVEL && p.exp >= MS.expToNext(p.level)) {
      p.exp -= MS.expToNext(p.level);
      p.level += 1;
      gained += 1;
    }
    if (p.level >= MS.MAX_LEVEL) p.exp = 0;
    return gained;
  };

  MS.tryEnhance = (p, rng) => {
    if (p.weaponLv >= MS.MAX_ENHANCE) return "max";
    const cost = MS.enhanceCost(p.weaponLv);
    if (p.meso < cost) return "nomoney";
    p.meso -= cost;
    if (rng() < MS.enhanceChance(p.weaponLv)) {
      p.weaponLv += 1;
      return "success";
    }
    return "fail";
  };

  MS.newProgress = (name, job) => ({
    name,
    job,
    level: 1,
    exp: 0,
    meso: 0,
    weaponLv: 0,
    potions: { hpPotion: 20, mpPotion: 20 },
    map: "hill",
    bossCleared: false,
  });
})(globalThis);
