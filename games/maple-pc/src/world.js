"use strict";
// World state for the current map: spawning, skills, damage, drops, portals.
(function (root) {
  const MS = root.MS;
  const C = MS.CONST;

  const RESPAWN_INTERVAL = 7;
  const HIT_INTERVAL = 0.09;

  class World {
    constructor(progress, hooks) {
      this.progress = progress;
      this.hooks = hooks || {};
      this.player = new MS.Player(progress);
      this.auto = false;
      this.loadMap(progress.map, null);
    }

    loadMap(mapId, portalId) {
      this.mapId = mapId;
      this.map = MS.MAPS[mapId];
      this.progress.map = mapId;
      this.monsters = [];
      this.drops = [];
      this.projectiles = [];
      this.pendingHits = [];
      this.effects = [];
      this.texts = [];
      this.respawnT = RESPAWN_INTERVAL;
      this.bossTimer = this.map.bossTimeLimit || 0;
      this.bossResult = null;
      for (const sp of this.map.spawns) this.fillSpawn(sp);
      const portal =
        this.map.portals.find((p) => p.id === portalId) ||
        this.map.portals.find((p) => p.id === "spawn") ||
        this.map.portals[0];
      this.player.placeAt(portal.x, portal.y);
      this.notice(this.map.name, "#ffffff");
      if (this.hooks.onMapChange) this.hooks.onMapChange(this);
    }

    fillSpawn(sp) {
      const alive = this.monsters.filter(
        (m) => m.spawn === sp && !m.dead,
      ).length;
      for (let i = alive; i < sp.count; i++) {
        const x = MS.rand(sp.x1 + 40, sp.x2 - 40);
        this.monsters.push(new MS.Monster(sp.mob, sp, x));
      }
    }

    get boss() {
      return this.monsters.find((m) => m.def.boss && !m.dead) || null;
    }

    update(dt, input) {
      const player = this.player;
      if (this.auto && !player.dead) input = MS.autoInput(this, input);
      player.update(dt, input, this);

      if (player.dead) {
        player.respawnT -= dt;
        if (player.respawnT <= 0) this.respawnPlayer();
      }

      for (const m of this.monsters) m.update(dt, this);
      this.monsters = this.monsters.filter((m) => !m.dead || m.deathT > 0);

      this.updateHits(dt);
      this.updateProjectiles(dt);
      this.updateDrops(dt);
      this.effects = this.effects.filter((e) => (e.t += dt) < e.dur);
      for (const t of this.texts) {
        t.t += dt;
        t.y -= 40 * dt;
      }
      this.texts = this.texts.filter((t) => t.t < t.dur);

      this.respawnT -= dt;
      if (this.respawnT <= 0) {
        this.respawnT = RESPAWN_INTERVAL;
        for (const sp of this.map.spawns)
          if (sp.respawn !== false) this.fillSpawn(sp);
      }

      if (this.bossTimer > 0 && !this.bossResult) {
        this.bossTimer -= dt;
        if (this.bossTimer <= 0) {
          this.bossResult = "fail";
          this.notice("Hết giờ! Bạn bị đưa ra ngoài.", "#ff5252");
          this.delayedWarp = 3;
        }
      }
      if (this.delayedWarp > 0) {
        this.delayedWarp -= dt;
        if (this.delayedWarp <= 0) this.loadMap("forest", "boss");
      }
    }

    // --- skills ---------------------------------------------------------

    canUseSkill(player, i) {
      const skill = player.job.skills[i];
      return skill && player.cooldowns[i] <= 0 && player.mp >= skill.mp;
    }

    useSkill(player, i) {
      const skill = player.job.skills[i];
      player.mp -= skill.mp;
      player.cooldowns[i] = skill.cooldown;
      player.actionT = skill.kind === "buff" ? 0.3 : 0.25;
      player.actionFx = skill.fx;
      const f = player.facing;
      const midY = player.y - player.h / 2;

      if (skill.kind === "hit") {
        const box = {
          cx: player.x + f * skill.offsetX,
          top: midY - skill.h / 2,
          w: skill.w,
          h: skill.h,
        };
        this.hitBox(player, skill, box);
        this.addEffect(skill.fx, box.cx, midY, f, 0.4, box.w, box.h);
      } else if (skill.kind === "projectile") {
        this.projectiles.push({
          x: player.x + f * 20,
          y: midY,
          dir: f,
          skill,
          travelled: 0,
          hitIds: new Set(),
        });
      } else if (skill.kind === "dash") {
        const dist = skill.distance * f;
        const startX = player.x;
        player.x = MS.clamp(
          player.x + dist,
          player.w / 2,
          this.map.width - player.w / 2,
        );
        player.facing = f;
        player.invuln = Math.max(player.invuln, 0.35);
        const cx = (startX + player.x) / 2;
        const box = {
          cx,
          top: midY - skill.h / 2,
          w: Math.abs(player.x - startX) + 80,
          h: skill.h,
        };
        this.hitBox(player, skill, box);
        this.addEffect("dash", cx, midY, f, 0.35, box.w, box.h);
      } else if (skill.kind === "teleport") {
        this.addEffect("blink", player.x, midY, f, 0.3);
        player.x = MS.clamp(
          player.x + skill.distance * f,
          player.w / 2,
          this.map.width - player.w / 2,
        );
        this.addEffect("blink", player.x, midY, f, 0.3);
      } else if (skill.kind === "buff") {
        player.buffs = player.buffs.filter((b) => b.id !== skill.id);
        player.buffs.push({
          id: skill.id,
          name: skill.name,
          t: skill.duration,
          dur: skill.duration,
          atkBonus: skill.atkBonus,
          critBonus: skill.critBonus,
        });
        this.addEffect("aura", player.x, midY, f, 0.8);
      }
    }

    hitBox(player, skill, box) {
      const targets = this.monsters
        .filter((m) => !m.dead && MS.boxHits(box, m))
        .sort((a, b) => Math.abs(a.x - player.x) - Math.abs(b.x - player.x))
        .slice(0, skill.maxTargets);
      for (const m of targets) this.queueHits(player, skill, m);
      return targets.length;
    }

    queueHits(player, skill, mob) {
      const s = player.stats();
      for (let h = 0; h < skill.hits; h++) {
        const dmg = MS.calcDamage(
          s.atk,
          skill.pct,
          mob.def.def,
          s.crit,
          mob.level - player.p.level,
          MS.rng,
        );
        this.pendingHits.push({
          mob,
          dmg,
          t: h * HIT_INTERVAL,
          row: h,
          dir: player.facing,
        });
      }
    }

    updateHits(dt) {
      const ready = [];
      this.pendingHits = this.pendingHits.filter((h) => {
        h.t -= dt;
        if (h.t <= 0) ready.push(h);
        return h.t > 0;
      });
      for (const h of ready) this.damageMonster(h.mob, h.dmg, h.row, h.dir);
    }

    damageMonster(mob, dmg, row, dir) {
      if (mob.dead) return;
      mob.hp -= dmg.amount;
      mob.aggro = true;
      if (!mob.def.boss) {
        mob.hurtT = 0.25;
        mob.vx = dir * 60;
      }
      this.texts.push({
        x: mob.x + MS.rand(-10, 10),
        y: mob.y - mob.h - 10 - row * 28,
        text: MS.formatNumber(dmg.amount),
        color: dmg.crit ? "#ff5a8c" : "#ffb22e",
        crit: dmg.crit,
        t: 0,
        dur: 0.9,
      });
      if (mob.hp <= 0) this.killMonster(mob);
    }

    killMonster(mob) {
      mob.dead = true;
      mob.deathT = 0.5;
      mob.hp = 0;
      const p = this.progress;
      const levels = MS.gainExp(p, mob.def.exp);
      this.texts.push({
        x: mob.x,
        y: mob.y - mob.h - 40,
        text: "+" + mob.def.exp + " EXP",
        color: "#b7f36b",
        t: 0,
        dur: 1.1,
        small: true,
      });
      if (levels > 0) this.onLevelUp();
      this.spawnDrop(
        mob.x,
        mob.y - mob.h / 2,
        "meso",
        MS.randInt(mob.def.meso[0], mob.def.meso[1]),
      );
      if (MS.rng() < (mob.def.boss ? 1 : 0.08)) {
        this.spawnDrop(
          mob.x + 20,
          mob.y - mob.h / 2,
          MS.rng() < 0.5 ? "hpPotion" : "mpPotion",
          mob.def.boss ? 10 : 1,
        );
      }
      if (mob.def.boss) {
        this.bossResult = "clear";
        p.bossCleared = true;
        this.notice("Đã đánh bại " + mob.def.name + "!", "#ffd54f");
        for (const m of this.monsters) if (!m.dead) this.killMonster(m);
      }
      if (this.hooks.onProgress) this.hooks.onProgress(this);
    }

    onLevelUp() {
      const player = this.player;
      const s = player.stats();
      player.hp = s.maxHp;
      player.mp = s.maxMp;
      this.addEffect("levelup", player.x, player.y - 40, 1, 1.5);
      this.notice("LÊN CẤP! Cấp " + this.progress.level, "#ffd54f");
    }

    updateProjectiles(dt) {
      for (const pr of this.projectiles) {
        const step = pr.skill.speed * dt;
        pr.x += pr.dir * step;
        pr.travelled += step;
        const box = { cx: pr.x, top: pr.y - 20, w: 30, h: 40 };
        for (const m of this.monsters) {
          if (
            m.dead ||
            pr.hitIds.has(m) ||
            pr.hitIds.size >= pr.skill.maxTargets
          )
            continue;
          if (MS.boxHits(box, m)) {
            pr.hitIds.add(m);
            this.queueHits(this.player, pr.skill, m);
          }
        }
        if (pr.hitIds.size >= pr.skill.maxTargets)
          pr.travelled = pr.skill.range;
      }
      this.projectiles = this.projectiles.filter(
        (pr) =>
          pr.travelled < pr.skill.range && pr.x > 0 && pr.x < this.map.width,
      );
    }

    // --- player damage / death ------------------------------------------

    hurtPlayer(amount, fromX) {
      const player = this.player;
      if (player.dead || player.invuln > 0) return;
      player.hp -= amount;
      player.invuln = C.HIT_INVULN;
      this.texts.push({
        x: player.x,
        y: player.y - player.h - 10,
        text: String(amount),
        color: "#c78bff",
        t: 0,
        dur: 0.9,
      });
      if (player.climbing) player.climbing = null;
      const dir = player.x >= fromX ? 1 : -1;
      player.vx = dir * 220;
      player.vy = -320;
      player.onGround = false;
      player.fh = null;
      if (player.hp <= 0) {
        player.hp = 0;
        player.dead = true;
        player.respawnT = 3;
        this.progress.exp = Math.floor(this.progress.exp * 0.9);
        this.notice("Bạn đã gục ngã! Hồi sinh sau 3 giây.", "#ff5252");
      }
    }

    respawnPlayer() {
      const player = this.player;
      const s = player.stats();
      player.dead = false;
      player.hp = s.maxHp;
      player.mp = s.maxMp;
      player.invuln = 2;
      if (this.map.bossTimeLimit) return this.loadMap("forest", "boss");
      const sp =
        this.map.portals.find((p) => p.id === "spawn") || this.map.portals[0];
      player.placeAt(sp.x, sp.y);
    }

    usePotion(id) {
      const player = this.player;
      const p = this.progress;
      if (player.potionCd > 0 || p.potions[id] <= 0) return false;
      const item = MS.ITEMS[id];
      const s = player.stats();
      if (item.heal === "hp") {
        if (player.hp >= s.maxHp) return false;
        player.hp = Math.min(s.maxHp, player.hp + s.maxHp * item.pct);
      } else {
        if (player.mp >= s.maxMp) return false;
        player.mp = Math.min(s.maxMp, player.mp + s.maxMp * item.pct);
      }
      p.potions[id] -= 1;
      player.potionCd = 0.8;
      this.addEffect(
        "potion",
        player.x,
        player.y - 40,
        1,
        0.5,
        0,
        0,
        item.color,
      );
      return true;
    }

    // --- boss -------------------------------------------------------------

    bossShockwave(boss) {
      this.addEffect("shockwave", boss.x, boss.y, 1, 0.6, 1100, 60);
      const player = this.player;
      if (
        player.onGround &&
        player.fh &&
        player.fh.y === boss.y &&
        Math.abs(player.x - boss.x) < 550
      ) {
        this.hurtPlayer(
          MS.monsterDamage(boss.def.atk * 1.6, player.stats().def, MS.rng),
          boss.x,
        );
      }
    }

    bossSummon(boss) {
      this.notice("Nấm Vua gọi thuộc hạ!", "#ff7043");
      const sp = {
        mob: "hornyMush",
        x1: 100,
        x2: this.map.width - 100,
        y: boss.y,
        count: 0,
        respawn: false,
      };
      for (let i = 0; i < 3; i++) {
        const m = new MS.Monster(
          "hornyMush",
          sp,
          MS.clamp(boss.x + MS.rand(-300, 300), 100, this.map.width - 100),
        );
        m.aggro = true;
        this.monsters.push(m);
      }
    }

    // --- drops --------------------------------------------------------------

    spawnDrop(x, y, kind, amount) {
      this.drops.push({
        x,
        y,
        w: 20,
        h: 20,
        vx: MS.rand(-60, 60),
        vy: -380,
        kind,
        amount,
        onGround: false,
        fh: null,
        t: 0,
      });
    }

    updateDrops(dt) {
      const player = this.player;
      const p = this.progress;
      for (const d of this.drops) {
        d.t += dt;
        if (d.onGround) d.vx = 0;
        MS.stepBody(d, this.map, dt);
        if (
          d.t > 0.5 &&
          !player.dead &&
          Math.hypot(d.x - player.x, d.y - player.y) < C.PICKUP_RANGE * 3
        ) {
          d.x += (player.x - d.x) * Math.min(1, dt * 10);
          d.y += (player.y - 30 - d.y) * Math.min(1, dt * 10);
          d.onGround = false;
          d.vy = 0;
          if (Math.hypot(d.x - player.x, d.y - (player.y - 30)) < 24) {
            d.taken = true;
            if (d.kind === "meso") p.meso += d.amount;
            else p.potions[d.kind] += d.amount;
            const label =
              d.kind === "meso"
                ? "+" + d.amount + " meso"
                : "+" + d.amount + " " + MS.ITEMS[d.kind].name;
            this.texts.push({
              x: player.x,
              y: player.y - player.h - 30,
              text: label,
              color: "#ffe082",
              t: 0,
              dur: 0.8,
              small: true,
            });
          }
        }
      }
      this.drops = this.drops.filter((d) => !d.taken && d.t < 60);
    }

    // --- portals / misc -----------------------------------------------------

    portalNear(player) {
      return (
        this.map.portals.find(
          (p) =>
            p.to &&
            Math.abs(p.x - player.x) < 40 &&
            Math.abs(p.y - player.y) < 12,
        ) || null
      );
    }

    tryPortal(player) {
      const portal = this.portalNear(player);
      if (!portal) return false;
      this.loadMap(portal.to, portal.toPortal);
      return true;
    }

    enhanceWeapon() {
      const before = this.progress.weaponLv;
      const result = MS.tryEnhance(this.progress, MS.rng);
      const msg = {
        success: [
          "Cường hóa thành công! Vũ khí +" + this.progress.weaponLv,
          "#69f0ae",
        ],
        fail: ["Cường hóa thất bại (+" + before + ")", "#ff8a80"],
        nomoney: [
          "Không đủ meso (cần " + MS.formatNumber(MS.enhanceCost(before)) + ")",
          "#ff8a80",
        ],
        max: ["Vũ khí đã đạt cấp tối đa", "#ffffff"],
      }[result];
      this.notice(msg[0], msg[1]);
      if (this.hooks.onProgress) this.hooks.onProgress(this);
      return result;
    }

    addEffect(type, x, y, facing, dur, w, h, color) {
      this.effects.push({
        type,
        x,
        y,
        facing,
        dur,
        w: w || 0,
        h: h || 0,
        color,
        t: 0,
      });
    }

    notice(text, color) {
      this.lastNotice = { text, color, t: 0 };
      if (this.hooks.onNotice) this.hooks.onNotice(text, color);
    }
  }

  MS.World = World;
})(globalThis);
