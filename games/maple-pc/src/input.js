"use strict";
// Keyboard and mouse input, turned into the per-frame input object.
(function (root) {
  const MS = root.MS;

  const GAME_KEYS = new Set([
    "ArrowLeft",
    "ArrowRight",
    "ArrowUp",
    "ArrowDown",
    "Space",
    "KeyC",
    "KeyZ",
    "KeyA",
    "KeyS",
    "KeyD",
    "KeyF",
    "KeyQ",
    "KeyW",
  ]);
  const SKILL_CODES = ["KeyZ", "KeyA", "KeyS", "KeyD", "KeyF"];

  class Input {
    constructor(target) {
      this.held = new Set();
      this.pressed = new Set();
      this.clickedSkills = new Set();
      target.addEventListener("keydown", (e) => {
        if (e.target && e.target.tagName === "INPUT") return;
        if (GAME_KEYS.has(e.code)) e.preventDefault();
        if (!e.repeat) this.pressed.add(e.code);
        this.held.add(e.code);
      });
      target.addEventListener("keyup", (e) => this.held.delete(e.code));
      target.addEventListener("blur", () => this.held.clear());
    }

    // Reads a one-shot key press and clears it.
    take(code) {
      return this.pressed.delete(code);
    }

    consume() {
      const h = this.held;
      const pr = this.pressed;
      const input = MS.emptyInput();
      input.left = h.has("ArrowLeft");
      input.right = h.has("ArrowRight");
      input.up = h.has("ArrowUp");
      input.down = h.has("ArrowDown");
      input.upPressed = pr.has("ArrowUp");
      input.jumpPressed = pr.has("Space") || pr.has("KeyC");
      input.skills = SKILL_CODES.map(
        (c, i) => h.has(c) || this.clickedSkills.has(i),
      );
      input.hpPressed = pr.has("KeyQ");
      input.mpPressed = pr.has("KeyW");
      this.clickedSkills.clear();
      return input;
    }

    endFrame() {
      this.pressed.clear();
    }
  }

  MS.Input = Input;

  MS.save = {
    KEY: "maple-pc-save-v1",
    load() {
      try {
        const raw = root.localStorage && root.localStorage.getItem(this.KEY);
        const data = raw ? JSON.parse(raw) : null;
        return data && MS.JOBS[data.job] && MS.MAPS[data.map] ? data : null;
      } catch (_e) {
        return null;
      }
    },
    write(progress) {
      try {
        root.localStorage.setItem(this.KEY, JSON.stringify(progress));
      } catch (_e) {
        // Storage can be unavailable (private mode); the game still runs.
      }
    },
  };
})(globalThis);
