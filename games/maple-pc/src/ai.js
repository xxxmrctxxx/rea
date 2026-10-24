"use strict";
// Auto-battle ("Tự động săn"), the mobile client's AutoHunt/AutoBattle mode.
// It builds the same input object the keyboard produces, so the player
// follows the normal movement and skill rules.
(function (root) {
  const MS = root.MS;
  const SAME_LEVEL = 30;

  const reach = (skill) => {
    if (skill.kind === "hit") return skill.offsetX + skill.w / 2 - 10;
    if (skill.kind === "projectile") return skill.range - 40;
    if (skill.kind === "dash")
      return skill.distance > 0 ? skill.distance + 30 : 90;
    return 0;
  };

  // Best damaging skill that is ready and reaches dist.
  MS.pickSkill = (world, player, dist) => {
    let best = -1;
    let bestScore = 0;
    player.job.skills.forEach((skill, i) => {
      if (skill.kind === "buff" || skill.kind === "teleport") return;
      if (!world.canUseSkill(player, i) || dist > reach(skill)) return;
      const score = skill.pct * skill.hits * Math.min(skill.maxTargets, 3);
      if (score > bestScore) {
        best = i;
        bestScore = score;
      }
    });
    return best;
  };

  MS.pickTarget = (world, player) => {
    let best = null;
    let bestScore = Infinity;
    for (const m of world.monsters) {
      if (m.dead || m === world.autoSkip) continue;
      const score = Math.abs(m.x - player.x) + Math.abs(m.y - player.y) * 3;
      if (score < bestScore) {
        best = m;
        bestScore = score;
      }
    }
    return best;
  };

  MS.autoInput = (world, manual) => {
    const player = world.player;
    const input = MS.emptyInput();
    // Manual movement always wins, so the player can steer during auto.
    if (manual.left || manual.right || manual.jumpPressed) return manual;

    const s = player.stats();
    const pots = world.progress.potions;
    input.hpPressed = player.hp < s.maxHp * 0.4 && pots.hpPotion > 0;
    input.mpPressed = player.mp < s.maxMp * 0.25 && pots.mpPotion > 0;

    const buffIdx = player.job.skills.findIndex((sk) => sk.kind === "buff");
    if (
      buffIdx >= 0 &&
      world.canUseSkill(player, buffIdx) &&
      !player.buffs.length
    ) {
      input.skills[buffIdx] = true;
      return input;
    }

    const ai = (world.autoState = world.autoState || {
      target: null,
      stuckT: 0,
      lastX: 0,
      lastY: 0,
    });
    if (!ai.target || ai.target.dead || !world.monsters.includes(ai.target)) {
      ai.target = MS.pickTarget(world, player);
      ai.stuckT = 0;
      world.autoSkip = null;
    }
    const target = ai.target;
    if (!target) return input;

    ai.stuckT += 1 / 60;
    if (
      Math.abs(player.x - ai.lastX) > 30 ||
      Math.abs(player.y - ai.lastY) > 30
    ) {
      ai.stuckT = 0;
      ai.lastX = player.x;
      ai.lastY = player.y;
    }
    if (ai.stuckT > 4) {
      world.autoSkip = target;
      ai.target = null;
      return input;
    }

    const dx = target.x - player.x;
    const dy = target.y - player.y;

    if (player.climbing) {
      if (dy < -SAME_LEVEL) input.up = true;
      else input.down = true;
      return input;
    }

    if (Math.abs(dy) <= SAME_LEVEL) {
      const dist = Math.abs(dx);
      const facingOk = (dx >= 0 ? 1 : -1) === player.facing || dist < 20;
      const idx = MS.pickSkill(world, player, dist);
      // When facing away, step toward the target first; attack next frame.
      if (idx >= 0 && facingOk) {
        input.skills[idx] = true;
        ai.stuckT = 0;
      } else if (dx > 0) input.right = true;
      else input.left = true;
      return input;
    }

    if (dy < 0) {
      // Target is higher: walk to a ladder that starts at this level.
      const ladder = world.map.ladders
        .filter((l) => Math.abs(l.bottom - player.y) < 6 && l.top < player.y)
        .sort((a, b) => Math.abs(a.x - player.x) - Math.abs(b.x - player.x))[0];
      if (!ladder) {
        world.autoSkip = target;
        ai.target = null;
        return input;
      }
      if (Math.abs(ladder.x - player.x) < 8) input.up = true;
      else if (ladder.x > player.x) input.right = true;
      else input.left = true;
      return input;
    }

    // Target is lower: drop through the platform, or walk off its edge.
    const below =
      player.onGround &&
      MS.footholdBetween(
        world.map,
        player.x,
        player.y + 1,
        world.map.height,
        player.fh,
      );
    if (below) {
      input.down = true;
      input.jumpPressed = true;
    } else if (dx > 0) input.right = true;
    else input.left = true;
    return input;
  };
})(globalThis);
