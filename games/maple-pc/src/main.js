"use strict";
// Boot: title screen, fixed-step game loop, pause and save.
(function (root) {
  const MS = root.MS;
  const C = MS.CONST;
  const STEP = 1 / 60;

  const canvas = document.getElementById("game");
  const ctx = canvas.getContext("2d");
  const titleEl = document.getElementById("title");
  const nameEl = document.getElementById("name");
  const jobsEl = document.getElementById("jobs");
  const continueEl = document.getElementById("continue");
  const startEl = document.getElementById("start");

  const input = new MS.Input(root);
  const renderer = new MS.Renderer(ctx);
  const ui = { showHelp: true, paused: false, dt: 0 };
  let world = null;
  let selectedJob = "warrior";
  let saveT = 0;

  function resize() {
    const scale = Math.min(
      root.innerWidth / C.VIEW_W,
      root.innerHeight / C.VIEW_H,
    );
    canvas.style.width = Math.floor(C.VIEW_W * scale) + "px";
    canvas.style.height = Math.floor(C.VIEW_H * scale) + "px";
  }
  root.addEventListener("resize", resize);
  resize();

  // --- title screen ---------------------------------------------------------

  for (const [id, job] of Object.entries(MS.JOBS)) {
    const btn = document.createElement("button");
    btn.className = "job";
    btn.dataset.job = id;
    btn.style.setProperty("--job", job.color);
    btn.innerHTML =
      "<strong>" +
      job.name +
      "</strong><small>" +
      job.skills
        .slice(1, 4)
        .map((s) => s.name)
        .join(" · ") +
      "</small>";
    btn.addEventListener("click", () => selectJob(id));
    jobsEl.appendChild(btn);
  }

  function selectJob(id) {
    selectedJob = id;
    for (const b of jobsEl.children)
      b.classList.toggle("selected", b.dataset.job === id);
  }
  selectJob(selectedJob);

  const saved = MS.save.load();
  if (saved) {
    continueEl.hidden = false;
    continueEl.textContent =
      "Tiếp tục: " +
      saved.name +
      " (Lv." +
      saved.level +
      " " +
      MS.JOBS[saved.job].name +
      ")";
    continueEl.addEventListener("click", () => start(saved));
  }
  startEl.addEventListener("click", () => {
    const name = nameEl.value.trim().slice(0, 12) || "Maple";
    start(MS.newProgress(name, selectedJob));
  });
  nameEl.addEventListener("keydown", (e) => {
    if (e.key === "Enter") startEl.click();
  });

  function start(progress) {
    titleEl.hidden = true;
    world = new MS.World(progress, {
      // Runs from inside the World constructor too, so use the argument.
      onMapChange: (w) => {
        renderer.follow(w, 0, true);
        MS.save.write(progress);
      },
    });
    renderer.follow(world, 0, true);
    MS.save.write(progress);
    canvas.focus();
  }

  // Click on HUD buttons.
  canvas.addEventListener("pointerdown", (e) => {
    if (!world) return;
    const rect = canvas.getBoundingClientRect();
    const x = ((e.clientX - rect.left) / rect.width) * C.VIEW_W;
    const y = ((e.clientY - rect.top) / rect.height) * C.VIEW_H;
    MS.skillSlots().forEach((s, i) => {
      if (Math.hypot(x - s.x, y - s.y) < s.r) input.clickedSkills.add(i);
    });
    for (const b of MS.itemButtons()) {
      if (x < b.x || x > b.x + b.w || y < b.y || y > b.y + b.h) continue;
      if (b.id === "auto") world.auto = !world.auto;
      else world.usePotion(b.id);
    }
  });

  // --- loop -------------------------------------------------------------------

  let last = performance.now();
  let acc = 0;
  function frame(now) {
    const dt = Math.min(0.1, (now - last) / 1000);
    last = now;
    ui.dt = dt;
    if (world) {
      if (input.take("KeyH")) ui.showHelp = !ui.showHelp;
      if (input.take("KeyP") || input.take("Escape")) ui.paused = !ui.paused;
      if (!ui.paused) {
        if (input.take("KeyT")) {
          world.auto = !world.auto;
          world.notice(
            world.auto ? "Tự động săn: BẬT" : "Tự động săn: TẮT",
            "#ffb300",
          );
        }
        if (input.take("KeyU")) world.enhanceWeapon();
        acc += dt;
        // Key presses are kept until a simulation step has read them.
        let first = true;
        while (acc >= STEP) {
          const frameInput = input.consume();
          if (!first) {
            frameInput.jumpPressed = false;
            frameInput.upPressed = false;
            frameInput.hpPressed = false;
            frameInput.mpPressed = false;
          }
          world.update(STEP, frameInput);
          first = false;
          acc -= STEP;
        }
        if (!first) input.endFrame();
        saveT += dt;
        if (saveT > 10) {
          saveT = 0;
          MS.save.write(world.progress);
        }
      }
      renderer.follow(world, dt, false);
      renderer.render(world, ui.paused ? 0 : dt);
      MS.drawHud(ctx, world, ui);
      if (ui.paused) {
        ctx.fillStyle = "rgba(0,0,0,0.5)";
        ctx.fillRect(0, 0, C.VIEW_W, C.VIEW_H);
        ctx.fillStyle = "#fff";
        ctx.font = "bold 40px sans-serif";
        ctx.textAlign = "center";
        ctx.fillText("TẠM DỪNG", C.VIEW_W / 2, C.VIEW_H / 2);
      }
    }
    if (!world || ui.paused) input.endFrame();
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  root.addEventListener("beforeunload", () => {
    if (world) MS.save.write(world.progress);
  });
})(globalThis);
