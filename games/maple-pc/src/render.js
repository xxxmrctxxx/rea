"use strict";
// Procedural canvas renderer. All art is drawn from shapes, so no assets
// from the original client are needed or shipped.
(function (root) {
  const MS = root.MS;
  const C = MS.CONST;

  const THEMES = {
    day: {
      sky: ["#8fd3ff", "#e6f7ff"],
      far: "#a7d8a0",
      near: "#6fbf73",
      ground: "#8d6e63",
      top: "#7cc84a",
      ladder: "#c49a6c",
    },
    dusk: {
      sky: ["#3b2a5a", "#f29e6d"],
      far: "#6b4c7a",
      near: "#3e2f4f",
      ground: "#5d4037",
      top: "#4f8a3b",
      ladder: "#a1887f",
    },
    boss: {
      sky: ["#0b0a2a", "#3a1f6b"],
      far: "#2a1950",
      near: "#1b1036",
      ground: "#3c2a63",
      top: "#9f7bff",
      ladder: "#7e6bb3",
    },
  };

  class Renderer {
    constructor(ctx) {
      this.ctx = ctx;
      this.cam = { x: 0, y: 0 };
      this.time = 0;
      this.stars = Array.from({ length: 80 }, () => ({
        x: Math.random(),
        y: Math.random() * 0.7,
        r: Math.random() * 1.8 + 0.4,
      }));
    }

    follow(world, dt, snap) {
      const p = world.player;
      const map = world.map;
      const tx = MS.clamp(
        p.x - C.VIEW_W / 2,
        0,
        Math.max(0, map.width - C.VIEW_W),
      );
      const ty = MS.clamp(
        p.y - C.VIEW_H * 0.62,
        0,
        Math.max(0, map.height - C.VIEW_H),
      );
      const k = snap ? 1 : Math.min(1, dt * 6);
      this.cam.x += (tx - this.cam.x) * k;
      this.cam.y += (ty - this.cam.y) * k;
    }

    render(world, dt) {
      this.time += dt;
      const ctx = this.ctx;
      const theme = THEMES[world.map.theme] || THEMES.day;
      this.drawBackground(theme, world.map);
      ctx.save();
      ctx.translate(-Math.round(this.cam.x), -Math.round(this.cam.y));
      this.drawMap(theme, world.map);
      for (const d of world.drops) this.drawDrop(d);
      for (const m of world.monsters) this.drawMonster(m);
      this.drawPlayer(world.player);
      for (const pr of world.projectiles) this.drawProjectile(pr);
      for (const e of world.effects) this.drawEffect(e);
      for (const t of world.texts) this.drawText(t);
      ctx.restore();
    }

    drawBackground(theme, map) {
      const ctx = this.ctx;
      const g = ctx.createLinearGradient(0, 0, 0, C.VIEW_H);
      g.addColorStop(0, theme.sky[0]);
      g.addColorStop(1, theme.sky[1]);
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, C.VIEW_W, C.VIEW_H);

      if (map.theme !== "day") {
        ctx.fillStyle = "rgba(255,255,255,0.8)";
        for (const s of this.stars) {
          const tw = 0.5 + 0.5 * Math.sin(this.time * 2 + s.x * 50);
          ctx.globalAlpha = tw;
          ctx.beginPath();
          ctx.arc(s.x * C.VIEW_W, s.y * C.VIEW_H, s.r, 0, Math.PI * 2);
          ctx.fill();
        }
        ctx.globalAlpha = 1;
      }
      if (map.theme === "boss") {
        const mx = C.VIEW_W * 0.62 - this.cam.x * 0.05;
        const glow = ctx.createRadialGradient(mx, 190, 40, mx, 190, 230);
        glow.addColorStop(0, "rgba(255,220,255,0.45)");
        glow.addColorStop(1, "rgba(255,220,255,0)");
        ctx.fillStyle = glow;
        ctx.fillRect(0, 0, C.VIEW_W, C.VIEW_H);
        ctx.fillStyle = "#f6e9ff";
        ctx.beginPath();
        ctx.arc(mx, 190, 120, 0, Math.PI * 2);
        ctx.fill();
        this.drawButterflies();
      } else if (map.theme === "day") {
        ctx.fillStyle = "rgba(255,255,255,0.85)";
        for (let i = 0; i < 6; i++) {
          const x =
            ((i * 260 - this.cam.x * 0.1 + this.time * 8) % (C.VIEW_W + 300)) -
            150;
          const y = 80 + (i % 3) * 50;
          ctx.beginPath();
          ctx.ellipse(x, y, 70, 24, 0, 0, Math.PI * 2);
          ctx.ellipse(x + 40, y - 12, 45, 22, 0, 0, Math.PI * 2);
          ctx.fill();
        }
      }
      this.drawHills(theme.far, 0.15, 420, 70, 0.004);
      this.drawHills(theme.near, 0.35, 520, 90, 0.007);
    }

    drawButterflies() {
      const ctx = this.ctx;
      for (let i = 0; i < 14; i++) {
        const t = this.time * 0.6 + i * 1.7;
        const x =
          (((i * 157 + Math.sin(t) * 60 - this.cam.x * 0.3) % C.VIEW_W) +
            C.VIEW_W) %
          C.VIEW_W;
        const y = 120 + ((i * 89) % 420) + Math.cos(t * 1.3) * 30;
        const flap = Math.abs(Math.sin(this.time * 8 + i));
        ctx.fillStyle =
          i % 2 ? "rgba(150,200,255,0.8)" : "rgba(220,140,255,0.8)";
        ctx.beginPath();
        ctx.ellipse(x - 6 * flap, y, 7 * flap + 1, 10, -0.4, 0, Math.PI * 2);
        ctx.ellipse(x + 6 * flap, y, 7 * flap + 1, 10, 0.4, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    drawHills(color, factor, baseY, amp, freq) {
      const ctx = this.ctx;
      const off = this.cam.x * factor;
      const yOff = this.cam.y * factor * 0.5;
      ctx.fillStyle = color;
      ctx.beginPath();
      ctx.moveTo(0, C.VIEW_H);
      for (let x = 0; x <= C.VIEW_W; x += 16) {
        const wx = x + off;
        const y =
          baseY -
          yOff +
          Math.sin(wx * freq) * amp +
          Math.sin(wx * freq * 2.3) * amp * 0.4;
        ctx.lineTo(x, y);
      }
      ctx.lineTo(C.VIEW_W, C.VIEW_H);
      ctx.fill();
    }

    drawMap(theme, map) {
      const ctx = this.ctx;
      for (const l of map.ladders) {
        ctx.strokeStyle = theme.ladder;
        ctx.lineWidth = 4;
        ctx.beginPath();
        ctx.moveTo(l.x - 10, l.top - 6);
        ctx.lineTo(l.x - 10, l.bottom);
        ctx.moveTo(l.x + 10, l.top - 6);
        ctx.lineTo(l.x + 10, l.bottom);
        ctx.stroke();
        ctx.lineWidth = 3;
        for (let y = l.top + 10; y < l.bottom; y += 18) {
          ctx.beginPath();
          ctx.moveTo(l.x - 10, y);
          ctx.lineTo(l.x + 10, y);
          ctx.stroke();
        }
      }
      for (const fh of map.footholds) {
        const ground = fh.y >= map.height - 120;
        const depth = ground ? map.height - fh.y + 200 : 26;
        ctx.fillStyle = theme.ground;
        ctx.beginPath();
        if (ground) ctx.rect(fh.x1, fh.y, fh.x2 - fh.x1, depth);
        else ctx.roundRect(fh.x1, fh.y, fh.x2 - fh.x1, depth, [0, 0, 12, 12]);
        ctx.fill();
        ctx.fillStyle = "rgba(0,0,0,0.12)";
        for (let x = fh.x1 + 20; x < fh.x2 - 10; x += 46) {
          ctx.fillRect(x, fh.y + 12, 18, 6);
        }
        ctx.fillStyle = theme.top;
        ctx.beginPath();
        ctx.roundRect(fh.x1 - 4, fh.y - 6, fh.x2 - fh.x1 + 8, 12, 6);
        ctx.fill();
      }
      for (const p of map.portals) {
        if (!p.to) continue;
        const pulse = 1 + Math.sin(this.time * 4) * 0.08;
        const g = ctx.createRadialGradient(
          p.x,
          p.y - 45,
          4,
          p.x,
          p.y - 45,
          50 * pulse,
        );
        g.addColorStop(0, "rgba(255,255,255,0.95)");
        g.addColorStop(0.4, "rgba(120,200,255,0.75)");
        g.addColorStop(1, "rgba(80,120,255,0)");
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.ellipse(p.x, p.y - 45, 32 * pulse, 50 * pulse, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = "rgba(200,240,255,0.8)";
        ctx.lineWidth = 2;
        for (let i = 0; i < 3; i++) {
          const a = this.time * 3 + (i * Math.PI * 2) / 3;
          ctx.beginPath();
          ctx.ellipse(p.x, p.y - 45, 26, 42, 0, a, a + 1.2);
          ctx.stroke();
        }
      }
    }

    drawMonster(m) {
      const ctx = this.ctx;
      const d = m.def;
      ctx.save();
      ctx.translate(m.x, m.y);
      if (m.dead) {
        ctx.globalAlpha = Math.max(0, m.deathT / 0.5);
        ctx.translate(0, -(0.5 - m.deathT) * 40);
      }
      if (m.hurtT > 0) ctx.filter = "brightness(1.8)";
      ctx.scale(m.facing, 1);
      const w = m.w;
      const h = m.h;
      const bob = m.onGround ? Math.sin(m.anim * 8) * (m.vx ? 2 : 1) : 0;
      ctx.fillStyle = "rgba(0,0,0,0.2)";
      ctx.beginPath();
      ctx.ellipse(0, 0, w * 0.45, 5, 0, 0, Math.PI * 2);
      ctx.fill();

      if (d.shape === "mushroom") {
        ctx.fillStyle = "#f7e1b5";
        ctx.beginPath();
        ctx.roundRect(-w * 0.28, -h * 0.55 + bob, w * 0.56, h * 0.55 - bob, 8);
        ctx.fill();
        ctx.fillStyle = d.color;
        ctx.beginPath();
        ctx.ellipse(0, -h * 0.55 + bob, w * 0.52, h * 0.38, 0, Math.PI, 0);
        ctx.fill();
        ctx.fillStyle = "rgba(255,255,255,0.85)";
        for (const [sx, sy, r] of [
          [-0.25, -0.75, 0.09],
          [0.15, -0.82, 0.07],
          [0.3, -0.62, 0.06],
        ]) {
          ctx.beginPath();
          ctx.arc(w * sx, h * sy + bob, w * r, 0, Math.PI * 2);
          ctx.fill();
        }
        this.drawEyes(w * 0.12, -h * 0.32 + bob, w * 0.06, m);
        if (d.horn) {
          ctx.fillStyle = "#6d4c41";
          ctx.beginPath();
          ctx.moveTo(-w * 0.1, -h * 0.9 + bob);
          ctx.lineTo(0, -h * 1.15 + bob);
          ctx.lineTo(w * 0.1, -h * 0.9 + bob);
          ctx.fill();
        }
        if (d.crown) {
          ctx.fillStyle = "#ffd54f";
          ctx.beginPath();
          const cy = -h * 0.9 + bob;
          ctx.moveTo(-w * 0.2, cy);
          for (let i = 0; i <= 4; i++)
            ctx.lineTo(-w * 0.2 + (w * 0.4 * i) / 4, cy - (i % 2 ? 10 : 34));
          ctx.lineTo(w * 0.2, cy);
          ctx.fill();
        }
      } else if (d.shape === "snail") {
        ctx.fillStyle = "#c8e6c9";
        ctx.beginPath();
        ctx.ellipse(4, -8, w * 0.5, 9, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = d.color;
        ctx.beginPath();
        ctx.arc(-4, -h * 0.55 + bob, h * 0.48, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = "rgba(255,255,255,0.7)";
        ctx.lineWidth = 2;
        ctx.beginPath();
        for (let a = 0; a < 12; a += 0.3)
          ctx.lineTo(
            -4 + Math.cos(a) * a * 1.2,
            -h * 0.55 + bob + Math.sin(a) * a * 1.2,
          );
        ctx.stroke();
        this.drawEyes(w * 0.42, -18, 3, m);
      } else if (d.shape === "slime") {
        const sq = 1 + Math.sin(m.anim * 6) * 0.08;
        ctx.fillStyle = d.color;
        ctx.beginPath();
        ctx.ellipse(
          0,
          -h * 0.45 * sq,
          (w * 0.5) / sq,
          h * 0.45 * sq,
          0,
          0,
          Math.PI * 2,
        );
        ctx.fill();
        ctx.fillStyle = "rgba(255,255,255,0.4)";
        ctx.beginPath();
        ctx.ellipse(-w * 0.18, -h * 0.65, 8, 5, -0.5, 0, Math.PI * 2);
        ctx.fill();
        this.drawEyes(w * 0.12, -h * 0.45, 4, m);
      } else if (d.shape === "pig") {
        ctx.fillStyle = d.color;
        ctx.beginPath();
        ctx.ellipse(0, -h * 0.5 + bob, w * 0.5, h * 0.42, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillRect(-w * 0.35, -h * 0.2, 8, h * 0.2);
        ctx.fillRect(w * 0.22, -h * 0.2, 8, h * 0.2);
        ctx.fillStyle = "#f8bbd0";
        ctx.beginPath();
        ctx.ellipse(w * 0.45, -h * 0.45 + bob, 10, 8, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = "#e91e63";
        ctx.beginPath();
        ctx.moveTo(-w * 0.1, -h * 0.9);
        ctx.lineTo(-w * 0.3, -h * 1.05);
        ctx.lineTo(-w * 0.3, -h * 0.8);
        ctx.lineTo(w * 0.1, -h * 0.95);
        ctx.lineTo(w * 0.1, -h * 0.75);
        ctx.fill();
        this.drawEyes(w * 0.25, -h * 0.6 + bob, 4, m);
      }
      ctx.restore();

      if (!m.dead && !d.boss && m.hp < m.maxHp) {
        const bw = Math.max(40, w);
        ctx.fillStyle = "rgba(0,0,0,0.6)";
        ctx.fillRect(m.x - bw / 2, m.y - h - 16, bw, 6);
        ctx.fillStyle = "#e53935";
        ctx.fillRect(
          m.x - bw / 2 + 1,
          m.y - h - 15,
          (bw - 2) * (m.hp / m.maxHp),
          4,
        );
      }
      if (!m.dead && (d.boss || m.aggro)) {
        ctx.font = "bold 12px sans-serif";
        ctx.textAlign = "center";
        ctx.fillStyle = "rgba(0,0,0,0.55)";
        const label = "Lv." + d.level + " " + d.name;
        const tw = ctx.measureText(label).width + 10;
        ctx.fillRect(m.x - tw / 2, m.y + 4, tw, 16);
        ctx.fillStyle = d.boss ? "#ffd54f" : "#fff";
        ctx.fillText(label, m.x, m.y + 16);
      }
    }

    drawEyes(x, y, r, m) {
      const ctx = this.ctx;
      ctx.fillStyle = "#222";
      const angry = m.aggro;
      for (const ex of [x - r * 2.2, x + r * 0.6]) {
        ctx.beginPath();
        ctx.ellipse(ex, y, r * 0.8, r * (angry ? 0.7 : 1.2), 0, 0, Math.PI * 2);
        ctx.fill();
      }
      if (angry) {
        ctx.strokeStyle = "#222";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(x - r * 3.4, y - r * 1.8);
        ctx.lineTo(x - r * 1.2, y - r * 1.1);
        ctx.moveTo(x + r * 1.8, y - r * 1.8);
        ctx.lineTo(x - r * 0.2, y - r * 1.1);
        ctx.stroke();
      }
    }

    drawPlayer(p) {
      const ctx = this.ctx;
      if (p.dead) {
        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.fillStyle = "#cfd8dc";
        ctx.beginPath();
        ctx.moveTo(-14, 0);
        ctx.lineTo(-14, -40);
        ctx.arc(0, -40, 14, Math.PI, 0);
        ctx.lineTo(14, 0);
        ctx.fill();
        ctx.fillStyle = "#555";
        ctx.font = "bold 12px sans-serif";
        ctx.textAlign = "center";
        ctx.fillText("RIP", 0, -30);
        ctx.restore();
        return;
      }
      if (p.invuln > 0 && Math.floor(this.time * 20) % 2 === 0) return;
      const job = p.job;
      ctx.save();
      ctx.translate(p.x, p.y);
      if (p.buffs.length) {
        ctx.strokeStyle =
          "rgba(255,213,79," + (0.3 + 0.2 * Math.sin(this.time * 6)) + ")";
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.ellipse(0, -2, 34, 9, 0, 0, Math.PI * 2);
        ctx.stroke();
      }
      ctx.fillStyle = "rgba(0,0,0,0.25)";
      ctx.beginPath();
      ctx.ellipse(0, 0, 18, 5, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.scale(p.facing, 1);
      const climbing = !!p.climbing;
      const step = Math.sin(p.walkPhase) * 6;
      // legs
      ctx.strokeStyle = "#3e2723";
      ctx.lineWidth = 6;
      ctx.lineCap = "round";
      ctx.beginPath();
      ctx.moveTo(-5, -20);
      ctx.lineTo(-5 - (climbing ? 0 : step), -3);
      ctx.moveTo(5, -20);
      ctx.lineTo(5 + (climbing ? 0 : step), climbing ? -8 + step : -3);
      ctx.stroke();
      // body
      ctx.fillStyle = job.color;
      ctx.beginPath();
      ctx.roundRect(-12, -40, 24, 24, 6);
      ctx.fill();
      // head
      ctx.fillStyle = "#ffe0bd";
      ctx.beginPath();
      ctx.arc(0, -54, 17, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#5d4037";
      ctx.beginPath();
      if (climbing) {
        ctx.arc(0, -56, 18, 0, Math.PI * 2);
      } else {
        ctx.arc(-2, -58, 18, Math.PI * 0.9, Math.PI * 2.1);
        ctx.lineTo(-18, -50);
      }
      ctx.fill();
      if (!climbing) {
        ctx.fillStyle = "#222";
        ctx.beginPath();
        ctx.ellipse(7, -52, 2.5, 4, 0, 0, Math.PI * 2);
        ctx.fill();
        this.drawWeapon(job.weapon, p.actionT > 0 ? 1 - p.actionT / 0.25 : -1);
      }
      ctx.restore();

      ctx.font = "bold 12px sans-serif";
      ctx.textAlign = "center";
      const label = p.p.name;
      const tw = ctx.measureText(label).width + 12;
      ctx.fillStyle = "rgba(0,0,0,0.6)";
      ctx.beginPath();
      ctx.roundRect(p.x - tw / 2, p.y + 6, tw, 17, 8);
      ctx.fill();
      ctx.fillStyle = "#fff";
      ctx.fillText(label, p.x, p.y + 19);
    }

    drawWeapon(kind, swing) {
      const ctx = this.ctx;
      ctx.save();
      ctx.translate(10, -30);
      const a = swing >= 0 ? -1.6 + swing * 2.6 : 0.4;
      ctx.rotate(a);
      if (kind === "sword") {
        ctx.fillStyle = "#cfd8dc";
        ctx.fillRect(0, -3, 44, 6);
        ctx.fillStyle = "#795548";
        ctx.fillRect(-8, -5, 10, 10);
      } else if (kind === "wand") {
        ctx.fillStyle = "#8d6e63";
        ctx.fillRect(0, -2, 34, 4);
        ctx.fillStyle = "#e1bee7";
        ctx.beginPath();
        ctx.arc(36, 0, 6, 0, Math.PI * 2);
        ctx.fill();
      } else if (kind === "bow") {
        ctx.strokeStyle = "#6d4c41";
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(8, 0, 22, -1.2, 1.2);
        ctx.stroke();
        ctx.strokeStyle = "#eee";
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(8 + Math.cos(-1.2) * 22, Math.sin(-1.2) * 22);
        ctx.lineTo(8 + Math.cos(1.2) * 22, Math.sin(1.2) * 22);
        ctx.stroke();
      } else if (kind === "claw") {
        ctx.fillStyle = "#90a4ae";
        for (let i = -1; i <= 1; i++) ctx.fillRect(4, i * 5 - 1, 18, 2);
      } else {
        ctx.fillStyle = "#ffb74d";
        ctx.beginPath();
        ctx.arc(10, 0, 8, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    }

    drawDrop(d) {
      const ctx = this.ctx;
      const bob = d.onGround ? Math.sin(this.time * 4 + d.x) * 3 : 0;
      ctx.save();
      ctx.translate(d.x, d.y - 10 + bob);
      if (d.kind === "meso") {
        ctx.fillStyle = "#ffca28";
        ctx.strokeStyle = "#ff8f00";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.ellipse(
          0,
          0,
          9 * Math.abs(Math.cos(this.time * 3)) + 2,
          9,
          0,
          0,
          Math.PI * 2,
        );
        ctx.fill();
        ctx.stroke();
      } else {
        ctx.fillStyle = MS.ITEMS[d.kind].color;
        ctx.beginPath();
        ctx.roundRect(-7, -6, 14, 16, 4);
        ctx.fill();
        ctx.fillStyle = "#ddd";
        ctx.fillRect(-3, -11, 6, 6);
      }
      ctx.restore();
    }

    drawProjectile(pr) {
      const ctx = this.ctx;
      ctx.save();
      ctx.translate(pr.x, pr.y);
      ctx.scale(pr.dir, 1);
      const fx = pr.skill.fx;
      if (fx === "arrow") {
        ctx.strokeStyle = "#fff8e1";
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.moveTo(-30, 0);
        ctx.lineTo(10, 0);
        ctx.stroke();
        ctx.fillStyle = "#ffeb3b";
        ctx.beginPath();
        ctx.moveTo(16, 0);
        ctx.lineTo(6, -5);
        ctx.lineTo(6, 5);
        ctx.fill();
      } else if (fx === "star") {
        ctx.rotate(this.time * 20);
        ctx.fillStyle = "#cfd8dc";
        ctx.beginPath();
        for (let i = 0; i < 8; i++) {
          const r = i % 2 ? 4 : 12;
          ctx.lineTo(
            Math.cos((i * Math.PI) / 4) * r,
            Math.sin((i * Math.PI) / 4) * r,
          );
        }
        ctx.fill();
      } else {
        const r = fx === "cannon" ? 20 : 12;
        const g = ctx.createRadialGradient(0, 0, 2, 0, 0, r * 1.6);
        g.addColorStop(0, "#fff");
        g.addColorStop(0.4, fx === "cannon" ? "#ff9800" : "#ce93d8");
        g.addColorStop(1, "rgba(0,0,0,0)");
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(0, 0, r * 1.6, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    }

    drawEffect(e) {
      const ctx = this.ctx;
      const k = e.t / e.dur;
      const fade = 1 - k;
      ctx.save();
      ctx.translate(e.x, e.y);
      ctx.globalAlpha = Math.max(0, fade);
      switch (e.type) {
        case "slash":
        case "punch":
        case "spin": {
          ctx.scale(e.facing, 1);
          ctx.strokeStyle = e.type === "punch" ? "#ffcc80" : "#e3f2fd";
          ctx.lineWidth = 10 * fade + 2;
          const r = Math.max(30, (e.w || 100) * 0.45);
          const start = e.type === "spin" ? k * Math.PI * 4 : -1.2;
          ctx.beginPath();
          ctx.ellipse(
            0,
            0,
            r,
            (e.h || 80) * 0.45,
            0,
            start,
            start + (e.type === "spin" ? 4 : 2.4),
          );
          ctx.stroke();
          break;
        }
        case "quake": {
          ctx.fillStyle = "#ffb74d";
          for (let i = -4; i <= 4; i++) {
            ctx.fillRect(
              i * (e.w / 9) - 6,
              e.h * 0.3 - 30 * Math.sin(k * Math.PI) * (1 - Math.abs(i) / 5),
              12,
              30,
            );
          }
          ctx.strokeStyle = "#fff3e0";
          ctx.lineWidth = 4;
          ctx.beginPath();
          ctx.ellipse(0, e.h * 0.4, (e.w / 2) * k, 18 * k, 0, 0, Math.PI * 2);
          ctx.stroke();
          break;
        }
        case "bolt": {
          ctx.scale(e.facing, 1);
          ctx.strokeStyle = "#fff59d";
          ctx.lineWidth = 4;
          ctx.shadowColor = "#ffee58";
          ctx.shadowBlur = 16;
          ctx.beginPath();
          ctx.moveTo(-e.w / 2, 0);
          for (let x = -e.w / 2; x <= e.w / 2; x += 30)
            ctx.lineTo(x, (Math.random() - 0.5) * 40);
          ctx.stroke();
          break;
        }
        case "ice":
        case "rain": {
          ctx.fillStyle = e.type === "ice" ? "#b3e5fc" : "#fff9c4";
          for (let i = 0; i < 14; i++) {
            const x = -e.w / 2 + ((i * 37) % e.w);
            const y = -e.h + ((k * 2 + i * 0.13) % 1) * e.h * 1.3;
            ctx.beginPath();
            ctx.moveTo(x, y);
            ctx.lineTo(x - 5, y - 26);
            ctx.lineTo(x + 5, y - 26);
            ctx.fill();
          }
          break;
        }
        case "dash":
        case "flash": {
          ctx.scale(e.facing, 1);
          const g = ctx.createLinearGradient(
            -(e.w || 120) / 2,
            0,
            (e.w || 120) / 2,
            0,
          );
          g.addColorStop(0, "rgba(255,255,255,0)");
          g.addColorStop(1, "rgba(200,230,255,0.9)");
          ctx.fillStyle = g;
          ctx.fillRect(
            -(e.w || 120) / 2,
            -(e.h || 40) / 4,
            e.w || 120,
            (e.h || 40) / 2,
          );
          break;
        }
        case "blink":
          ctx.strokeStyle = "#e1bee7";
          ctx.lineWidth = 3;
          ctx.beginPath();
          ctx.arc(0, 0, 10 + k * 40, 0, Math.PI * 2);
          ctx.stroke();
          break;
        case "aura":
        case "potion":
          ctx.fillStyle = e.color || "#ffd54f";
          for (let i = 0; i < 10; i++) {
            const a = (i / 10) * Math.PI * 2 + k * 3;
            ctx.beginPath();
            ctx.arc(
              Math.cos(a) * 30,
              20 - k * 70 + Math.sin(a) * 6,
              4,
              0,
              Math.PI * 2,
            );
            ctx.fill();
          }
          break;
        case "levelup": {
          const g = ctx.createLinearGradient(0, -200, 0, 40);
          g.addColorStop(0, "rgba(255,213,79,0)");
          g.addColorStop(1, "rgba(255,213,79,0.7)");
          ctx.fillStyle = g;
          ctx.fillRect(-40, -200, 80, 240);
          ctx.font = "bold 30px sans-serif";
          ctx.textAlign = "center";
          ctx.fillStyle = "#fff8e1";
          ctx.strokeStyle = "#e65100";
          ctx.lineWidth = 5;
          ctx.strokeText("LEVEL UP!", 0, -90 - k * 30);
          ctx.fillText("LEVEL UP!", 0, -90 - k * 30);
          break;
        }
        case "shockwave":
          ctx.strokeStyle = "#ff7043";
          ctx.lineWidth = 8;
          ctx.beginPath();
          ctx.ellipse(0, 0, (e.w / 2) * k, 30 * k + 4, 0, Math.PI, 0);
          ctx.stroke();
          break;
        default:
          break;
      }
      ctx.restore();
    }

    drawText(t) {
      const ctx = this.ctx;
      const k = t.t / t.dur;
      const size = t.small ? 16 : t.crit ? 34 : 28;
      ctx.save();
      ctx.globalAlpha = k < 0.7 ? 1 : 1 - (k - 0.7) / 0.3;
      ctx.font = "900 " + size + "px 'Trebuchet MS', sans-serif";
      ctx.textAlign = "center";
      ctx.lineWidth = 5;
      ctx.strokeStyle = "rgba(40,20,0,0.85)";
      const pop = k < 0.1 ? 1 + (0.1 - k) * 4 : 1;
      ctx.translate(t.x, t.y);
      ctx.scale(pop, pop);
      ctx.strokeText(t.text, 0, 0);
      ctx.fillStyle = t.color;
      ctx.fillText(t.text, 0, 0);
      ctx.restore();
    }
  }

  MS.Renderer = Renderer;
})(globalThis);
