"use strict";
// Screen-space HUD laid out after the mobile client: status top-left,
// minimap top-right, boss bar top-centre, skill wheel bottom-right and a
// full-width EXP bar.
(function (root) {
  const MS = root.MS;
  const C = MS.CONST;

  const panel = (ctx, x, y, w, h, r) => {
    ctx.fillStyle = "rgba(15,18,40,0.72)";
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, r || 10);
    ctx.fill();
  };

  const bar = (ctx, x, y, w, h, frac, color, label) => {
    ctx.fillStyle = "rgba(0,0,0,0.55)";
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, h / 2);
    ctx.fill();
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.roundRect(
      x + 1,
      y + 1,
      Math.max(0, (w - 2) * MS.clamp(frac, 0, 1)),
      h - 2,
      (h - 2) / 2,
    );
    ctx.fill();
    if (label) {
      ctx.font = "bold " + (h - 4) + "px sans-serif";
      ctx.textAlign = "center";
      ctx.fillStyle = "#fff";
      ctx.fillText(label, x + w / 2, y + h - 3);
    }
  };

  MS.combatPower = (stats) =>
    Math.floor(
      stats.atk * 12 + stats.maxHp * 0.6 + stats.def * 8 + stats.crit * 2000,
    );

  MS.skillSlots = () => {
    // Basic attack is the big button; four skills arc around it.
    const cx = C.VIEW_W - 110;
    const cy = C.VIEW_H - 110;
    return [
      { x: cx, y: cy, r: 52 },
      { x: cx - 130, y: cy + 30, r: 34 },
      { x: cx - 112, y: cy - 60, r: 34 },
      { x: cx - 40, y: cy - 128, r: 34 },
      { x: cx + 54, y: cy - 150, r: 34 },
    ];
  };

  // Potion slots then the AUTO button, left of the skill wheel.
  MS.itemButtons = () =>
    ["hpPotion", "mpPotion", "auto"].map((id, i) => ({
      id,
      x: C.VIEW_W - 560 + i * 62,
      y: C.VIEW_H - 84,
      w: 54,
      h: 54,
    }));

  MS.drawHud = (ctx, world, ui) => {
    const player = world.player;
    const p = world.progress;
    const s = player.stats();

    // Status panel
    panel(ctx, 12, 12, 330, 96);
    ctx.textAlign = "left";
    ctx.font = "bold 18px sans-serif";
    ctx.fillStyle = "#ffd54f";
    ctx.fillText("Lv." + p.level, 24, 38);
    ctx.fillStyle = "#fff";
    ctx.fillText(p.name, 84, 38);
    ctx.font = "13px sans-serif";
    ctx.fillStyle = "#b0bec5";
    ctx.fillText(
      player.job.name + "  ·  Lực chiến " + MS.formatNumber(MS.combatPower(s)),
      24,
      56,
    );
    bar(
      ctx,
      24,
      64,
      306,
      16,
      player.hp / s.maxHp,
      "#e53935",
      Math.ceil(player.hp) + " / " + s.maxHp,
    );
    bar(
      ctx,
      24,
      84,
      306,
      16,
      player.mp / s.maxMp,
      "#1e88e5",
      Math.floor(player.mp) + " / " + s.maxMp,
    );

    // Buffs
    player.buffs.forEach((b, i) => {
      const x = 24 + i * 46;
      panel(ctx, x, 116, 40, 40, 8);
      ctx.fillStyle = "#ffd54f";
      ctx.font = "bold 11px sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(b.name.split(" ")[0], x + 20, 132);
      ctx.fillStyle = "#fff";
      ctx.fillText(Math.ceil(b.t) + "s", x + 20, 149);
    });

    drawMinimap(ctx, world);
    drawBossBar(ctx, world);

    // Meso / weapon
    panel(ctx, 12, C.VIEW_H - 78, 300, 44);
    ctx.textAlign = "left";
    ctx.font = "bold 15px sans-serif";
    ctx.fillStyle = "#ffca28";
    ctx.fillText("● " + MS.formatNumber(p.meso) + " meso", 24, C.VIEW_H - 50);
    ctx.fillStyle = "#80deea";
    ctx.fillText("Vũ khí +" + p.weaponLv, 180, C.VIEW_H - 50);

    drawSkills(ctx, world);

    // EXP bar
    const need = MS.expToNext(p.level);
    const pct = p.level >= MS.MAX_LEVEL ? 100 : (p.exp / need) * 100;
    bar(
      ctx,
      0,
      C.VIEW_H - 14,
      C.VIEW_W,
      14,
      pct / 100,
      "#c6ff00",
      "EXP " + pct.toFixed(2) + "%",
    );

    if (world.lastNotice) {
      const n = world.lastNotice;
      n.t += ui.dt;
      if (n.t < 3) {
        ctx.globalAlpha = n.t > 2.5 ? (3 - n.t) * 2 : 1;
        ctx.font = "bold 20px sans-serif";
        const w = ctx.measureText(n.text).width + 40;
        panel(ctx, C.VIEW_W / 2 - w / 2, 150, w, 38, 19);
        ctx.fillStyle = n.color;
        ctx.textAlign = "center";
        ctx.fillText(n.text, C.VIEW_W / 2, 176);
        ctx.globalAlpha = 1;
      }
    }

    if (player.dead) {
      ctx.fillStyle = "rgba(0,0,0,0.45)";
      ctx.fillRect(0, 0, C.VIEW_W, C.VIEW_H);
      ctx.font = "bold 36px sans-serif";
      ctx.textAlign = "center";
      ctx.fillStyle = "#fff";
      ctx.fillText(
        "Hồi sinh sau " + Math.ceil(player.respawnT) + "...",
        C.VIEW_W / 2,
        C.VIEW_H / 2,
      );
    }

    if (ui.showHelp) drawHelp(ctx);
  };

  function drawMinimap(ctx, world) {
    const map = world.map;
    const w = 230;
    const scale = w / map.width;
    const h = map.height * scale;
    const x0 = C.VIEW_W - w - 16;
    const y0 = 36;
    panel(ctx, x0 - 8, 10, w + 16, h + 34);
    ctx.font = "bold 13px sans-serif";
    ctx.textAlign = "center";
    ctx.fillStyle = "#fff";
    ctx.fillText(map.name, x0 + w / 2, 28);
    ctx.strokeStyle = "#90a4ae";
    ctx.lineWidth = 2;
    for (const fh of map.footholds) {
      ctx.beginPath();
      ctx.moveTo(x0 + fh.x1 * scale, y0 + fh.y * scale);
      ctx.lineTo(x0 + fh.x2 * scale, y0 + fh.y * scale);
      ctx.stroke();
    }
    ctx.fillStyle = "#4fc3f7";
    for (const p of map.portals)
      if (p.to) ctx.fillRect(x0 + p.x * scale - 2, y0 + p.y * scale - 8, 4, 8);
    ctx.fillStyle = "#ef5350";
    for (const m of world.monsters)
      if (!m.dead)
        ctx.fillRect(x0 + m.x * scale - 1.5, y0 + m.y * scale - 4, 3, 3);
    ctx.fillStyle = "#ffeb3b";
    const pl = world.player;
    ctx.beginPath();
    ctx.arc(x0 + pl.x * scale, y0 + pl.y * scale - 4, 4, 0, Math.PI * 2);
    ctx.fill();
  }

  function drawBossBar(ctx, world) {
    const boss = world.boss;
    if (!boss && !world.bossTimer) return;
    const w = 520;
    const x = C.VIEW_W / 2 - w / 2;
    panel(ctx, x - 10, 10, w + 20, 70);
    ctx.textAlign = "center";
    ctx.font = "bold 14px sans-serif";
    ctx.fillStyle = "#fff";
    ctx.fillText(
      "Thời gian " + MS.formatTime(world.bossTimer),
      C.VIEW_W / 2,
      30,
    );
    if (boss) {
      ctx.fillStyle = "#ffd54f";
      ctx.fillText(boss.def.name, C.VIEW_W / 2, 48);
      bar(
        ctx,
        x,
        54,
        w,
        16,
        boss.hp / boss.maxHp,
        "#43a047",
        MS.formatNumber(boss.hp) + " / " + MS.formatNumber(boss.maxHp),
      );
    } else if (world.bossResult === "clear") {
      ctx.fillStyle = "#69f0ae";
      ctx.fillText("Đã chinh phục!", C.VIEW_W / 2, 58);
    }
  }

  function drawSkills(ctx, world) {
    const player = world.player;
    const slots = MS.skillSlots();
    // Slightly see-through so the wheel never fully hides the player.
    ctx.globalAlpha = 0.85;
    player.job.skills.forEach((skill, i) => {
      const slot = slots[i];
      const ready = player.cooldowns[i] <= 0;
      const enough = player.mp >= skill.mp;
      ctx.fillStyle = "rgba(15,18,40,0.8)";
      ctx.beginPath();
      ctx.arc(slot.x, slot.y, slot.r, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = enough ? player.job.color : "#555";
      ctx.lineWidth = 4;
      ctx.stroke();
      if (!ready) {
        const frac = player.cooldowns[i] / skill.cooldown;
        ctx.fillStyle = "rgba(0,0,0,0.6)";
        ctx.beginPath();
        ctx.moveTo(slot.x, slot.y);
        ctx.arc(
          slot.x,
          slot.y,
          slot.r,
          -Math.PI / 2,
          -Math.PI / 2 + frac * Math.PI * 2,
        );
        ctx.fill();
      }
      ctx.textAlign = "center";
      ctx.fillStyle = "#fff";
      ctx.font = "bold " + (i === 0 ? 14 : 11) + "px sans-serif";
      ctx.fillText(skill.name, slot.x, slot.y + 4);
      ctx.font = "bold 12px sans-serif";
      ctx.fillStyle = "#ffd54f";
      ctx.fillText(MS.SKILL_KEYS[i], slot.x, slot.y - slot.r + 16);
      if (!ready) {
        ctx.fillStyle = "#fff";
        ctx.fillText(player.cooldowns[i].toFixed(1), slot.x, slot.y + 20);
      }
    });
    ctx.globalAlpha = 1;

    // Potions and auto button
    const keys = { hpPotion: "Q", mpPotion: "W", auto: "T" };
    for (const b of MS.itemButtons()) {
      if (b.id === "auto") {
        ctx.fillStyle = world.auto ? "#ffb300" : "rgba(15,18,40,0.72)";
        ctx.beginPath();
        ctx.roundRect(b.x, b.y, b.w, b.h, 12);
        ctx.fill();
        ctx.fillStyle = world.auto ? "#3e2723" : "#fff";
        ctx.textAlign = "center";
        ctx.font = "bold 14px sans-serif";
        ctx.fillText("AUTO", b.x + 27, b.y + 30);
        ctx.font = "bold 11px sans-serif";
        ctx.fillText(keys.auto, b.x + 27, b.y + 46);
        continue;
      }
      panel(ctx, b.x, b.y, b.w, b.h, 12);
      ctx.fillStyle = MS.ITEMS[b.id].color;
      ctx.beginPath();
      ctx.roundRect(b.x + 18, b.y + 14, 18, 24, 5);
      ctx.fill();
      ctx.fillStyle = "#fff";
      ctx.font = "bold 12px sans-serif";
      ctx.textAlign = "left";
      ctx.fillText(keys[b.id], b.x + 5, b.y + 14);
      ctx.textAlign = "right";
      ctx.fillText(String(world.progress.potions[b.id]), b.x + 50, b.y + 50);
    }
  }

  function drawHelp(ctx) {
    const lines = [
      ["← →", "Di chuyển"],
      ["↑ / ↓", "Leo thang · vào cổng (↑)"],
      ["Space / C", "Nhảy · nhảy đôi trên không"],
      ["↓ + Space", "Nhảy xuống tầng dưới"],
      ["Z", "Đánh thường"],
      ["A S D F", "Kỹ năng 1–4"],
      ["Q / W", "Thuốc HP / MP"],
      ["T", "Bật/tắt tự động săn"],
      ["U", "Cường hóa vũ khí (tốn meso)"],
      ["P / Esc", "Tạm dừng"],
      ["H", "Ẩn/hiện hướng dẫn"],
    ];
    const w = 420;
    const h = 46 + lines.length * 26;
    const x = C.VIEW_W / 2 - w / 2;
    const y = C.VIEW_H / 2 - h / 2;
    panel(ctx, x, y, w, h, 16);
    ctx.font = "bold 18px sans-serif";
    ctx.textAlign = "center";
    ctx.fillStyle = "#ffd54f";
    ctx.fillText("Điều khiển", C.VIEW_W / 2, y + 30);
    ctx.font = "15px sans-serif";
    lines.forEach(([k, v], i) => {
      ctx.textAlign = "right";
      ctx.fillStyle = "#80deea";
      ctx.fillText(k, x + 140, y + 62 + i * 26);
      ctx.textAlign = "left";
      ctx.fillStyle = "#fff";
      ctx.fillText(v, x + 160, y + 62 + i * 26);
    });
  }
})(globalThis);
