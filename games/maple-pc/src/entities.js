"use strict";
// Player and monster behaviour. Both read an input-like object so the
// keyboard and the auto-battle AI drive the player through the same path.
(function (root) {
  const MS = root.MS;
  const C = MS.CONST;

  MS.emptyInput = () => ({
    left: false,
    right: false,
    up: false,
    down: false,
    upPressed: false,
    jumpPressed: false,
    skills: [false, false, false, false, false],
    hpPressed: false,
    mpPressed: false,
  });

  class Player {
    constructor(progress) {
      this.p = progress;
      this.w = 36;
      this.h = 66;
      this.x = 0;
      this.y = 0;
      this.vx = 0;
      this.vy = 0;
      this.facing = 1;
      this.onGround = false;
      this.fh = null;
      this.dropFrom = null;
      this.jumpsUsed = 0;
      this.climbing = null;
      this.cooldowns = [0, 0, 0, 0, 0];
      this.buffs = [];
      this.invuln = 0;
      this.potionCd = 0;
      this.actionT = 0;
      this.actionFx = null;
      this.dead = false;
      this.respawnT = 0;
      this.walkPhase = 0;
      const s = this.stats();
      this.hp = s.maxHp;
      this.mp = s.maxMp;
    }

    get job() {
      return MS.JOBS[this.p.job];
    }

    stats() {
      return MS.playerStats(this.p, this.buffs);
    }

    placeAt(x, y) {
      this.x = x;
      this.y = y;
      this.vx = 0;
      this.vy = 0;
      this.climbing = null;
      this.onGround = false;
      this.fh = null;
    }

    update(dt, input, world) {
      for (let i = 0; i < this.cooldowns.length; i++) {
        this.cooldowns[i] = Math.max(0, this.cooldowns[i] - dt);
      }
      this.buffs = this.buffs.filter((b) => (b.t -= dt) > 0);
      this.invuln = Math.max(0, this.invuln - dt);
      this.potionCd = Math.max(0, this.potionCd - dt);
      this.actionT = Math.max(0, this.actionT - dt);
      if (this.dead) return;

      const s = this.stats();
      this.hp = Math.min(this.hp, s.maxHp);
      this.mp = Math.min(s.maxMp, this.mp + s.maxMp * 0.01 * dt);

      if (input.hpPressed) world.usePotion("hpPotion");
      if (input.mpPressed) world.usePotion("mpPotion");

      const dir = (input.right ? 1 : 0) - (input.left ? 1 : 0);

      if (this.climbing) {
        this.updateClimb(dt, input, dir);
      } else {
        this.updateMove(dt, input, dir, world);
      }

      if (this.actionT <= 0) {
        for (let i = 0; i < input.skills.length; i++) {
          if (input.skills[i] && world.canUseSkill(this, i)) {
            world.useSkill(this, i);
            break;
          }
        }
      }

      if (input.upPressed && this.onGround) world.tryPortal(this);
    }

    updateClimb(dt, input, dir) {
      const l = this.climbing;
      if (input.jumpPressed && dir !== 0) {
        this.climbing = null;
        this.facing = dir;
        this.vx = dir * C.WALK_SPEED * 0.8;
        this.vy = -C.JUMP_SPEED * 0.55;
        this.jumpsUsed = 1;
        return;
      }
      this.vx = 0;
      this.vy = ((input.down ? 1 : 0) - (input.up ? 1 : 0)) * C.CLIMB_SPEED;
      this.y += this.vy * dt;
      if (this.vy !== 0) this.walkPhase += dt * 8;
      if (this.y <= l.top || this.y >= l.bottom) {
        this.y = this.y <= l.top ? l.top : l.bottom;
        this.climbing = null;
        this.onGround = true;
        this.fh = null;
        this.vy = 0;
        this.jumpsUsed = 0;
      }
    }

    updateMove(dt, input, dir, world) {
      const map = world.map;
      if (input.up && !input.jumpPressed) {
        const l = MS.findLadder(map, this.x, this.y, true);
        if (l && !world.portalNear(this)) return this.grab(l, this.y);
      }
      if (input.down && this.onGround && !input.jumpPressed) {
        const l = MS.findLadder(map, this.x, this.y, false);
        if (l) return this.grab(l, l.top + 2);
      }

      const locked = this.actionT > 0 && this.onGround;
      if (dir !== 0 && !locked) this.facing = dir;
      if (this.onGround) {
        this.vx = locked ? 0 : dir * C.WALK_SPEED;
      } else if (dir !== 0) {
        const target = dir * C.WALK_SPEED;
        this.vx += MS.clamp(target - this.vx, -900 * dt, 900 * dt);
      }
      if (this.onGround && this.vx !== 0) this.walkPhase += dt * 10;

      if (input.jumpPressed) {
        const below =
          this.onGround &&
          MS.footholdBetween(map, this.x, this.y + 1, map.height, this.fh);
        if (input.down && below) {
          this.dropFrom = this.fh;
          this.onGround = false;
          this.fh = null;
          this.vy = 0;
        } else if (this.onGround) {
          this.vy = -C.JUMP_SPEED;
          this.onGround = false;
          this.fh = null;
          this.jumpsUsed = 1;
        } else if (this.jumpsUsed < C.JUMP_COUNT) {
          this.jumpsUsed += 1;
          this.vx = this.facing * C.DOUBLE_JUMP_SPEED_X;
          this.vy = -C.DOUBLE_JUMP_SPEED_Y;
          world.addEffect("flash", this.x, this.y - 30, this.facing, 0.3);
        }
      }

      if (MS.stepBody(this, map, dt) === "fell") world.respawnPlayer();
    }

    grab(ladder, y) {
      this.climbing = ladder;
      this.x = ladder.x;
      this.y = y;
      this.vx = 0;
      this.vy = 0;
      this.onGround = false;
      this.fh = null;
    }
  }

  class Monster {
    constructor(defId, spawn, x) {
      this.defId = defId;
      this.def = MS.MONSTERS[defId];
      this.spawn = spawn;
      this.w = this.def.w;
      this.h = this.def.h;
      this.x = x;
      this.y = spawn.y;
      this.vx = 0;
      this.vy = 0;
      this.onGround = false;
      this.fh = null;
      this.maxHp = this.def.hp;
      this.hp = this.def.hp;
      this.facing = MS.rng() < 0.5 ? -1 : 1;
      this.state = "idle";
      this.stateT = MS.rand(0.5, 2);
      this.aggro = false;
      this.hurtT = 0;
      this.dead = false;
      this.deathT = 0;
      this.hopT = MS.rand(1, 3);
      this.anim = MS.rand(0, 10);
      this.skillT = 5;
      this.summonT = 18;
      this.pending = null;
    }

    get level() {
      return this.def.level;
    }

    update(dt, world) {
      this.anim += dt;
      if (this.dead) {
        this.deathT -= dt;
        return;
      }
      this.hurtT = Math.max(0, this.hurtT - dt);
      const player = world.player;

      if (this.def.boss) this.updateBoss(dt, world);
      if (this.state === "stomp" || this.state === "charge") {
        // Boss attack in progress; movement set by updateBoss.
      } else if (this.hurtT > 0) {
        this.vx *= 0.9;
      } else if (this.aggro && !player.dead) {
        const dx = player.x - this.x;
        this.facing = dx >= 0 ? 1 : -1;
        this.vx = Math.abs(dx) > 10 ? this.facing * this.def.speed * 1.3 : 0;
      } else {
        this.stateT -= dt;
        if (this.stateT <= 0) {
          this.state = this.state === "walk" ? "idle" : "walk";
          this.stateT = MS.rand(1, 3);
          if (this.state === "walk" && MS.rng() < 0.5) this.facing *= -1;
        }
        this.vx = this.state === "walk" ? this.facing * this.def.speed : 0;
      }

      if (this.def.hops && this.onGround && this.vx !== 0) {
        this.hopT -= dt;
        if (this.hopT <= 0) {
          this.vy = -380;
          this.onGround = false;
          this.hopT = MS.rand(1.2, 2.5);
        }
      }

      // Stay on the home platform: turn around at its edges.
      const home = this.fh || this.spawnFh;
      if (home && this.onGround) {
        const nx = this.x + this.vx * dt;
        const half = this.w / 2;
        if (nx - half < home.x1 || nx + half > home.x2) {
          this.vx = 0;
          if (!this.aggro) this.facing *= -1;
          this.x = MS.clamp(this.x, home.x1 + half, home.x2 - half);
        }
      }
      MS.stepBody(this, world.map, dt);
      if (this.onGround && !this.spawnFh) this.spawnFh = this.fh;

      if (!player.dead && player.invuln <= 0 && MS.overlaps(this, player)) {
        world.hurtPlayer(
          MS.monsterDamage(this.def.atk, player.stats().def, MS.rng),
          this.x,
        );
      }
    }

    updateBoss(dt, world) {
      const player = world.player;
      this.aggro = true;
      if (this.state === "stomp") {
        this.vx = 0;
        if (this.onGround && this.stateT <= 0) {
          world.bossShockwave(this);
          this.state = "idle";
          this.skillT = MS.rand(4, 7);
        }
        this.stateT -= dt;
        return;
      }
      if (this.state === "charge") {
        this.stateT -= dt;
        this.vx = this.facing * 420;
        if (this.stateT <= 0) {
          this.state = "idle";
          this.skillT = MS.rand(4, 7);
        }
        return;
      }
      this.skillT -= dt;
      this.summonT -= dt;
      if (this.hp < this.maxHp * 0.6 && this.summonT <= 0) {
        this.summonT = 20;
        world.bossSummon(this);
      }
      if (this.skillT <= 0 && this.onGround && !player.dead) {
        if (MS.rng() < 0.55) {
          this.state = "stomp";
          this.stateT = 0.4;
          this.vy = -820;
          this.onGround = false;
          world.notice(
            "Nấm Vua chuẩn bị dậm đất! Hãy nhảy lên để né!",
            "#ffcc33",
          );
        } else {
          this.state = "charge";
          this.stateT = 1.4;
          this.facing = player.x >= this.x ? 1 : -1;
          world.notice("Nấm Vua đang lao tới!", "#ff7043");
        }
      }
    }
  }

  MS.Player = Player;
  MS.Monster = Monster;
})(globalThis);
