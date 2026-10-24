// Loads the DOM-free game scripts into globalThis.MS for Node tests. Each
// test file runs in its own process, so loading once per file is enough.
const FILES = ["core", "data", "physics", "combat", "entities", "ai", "world"];

for (const f of FILES) {
  await import(new URL("../src/" + f + ".js", import.meta.url).href);
}

export const MS = globalThis.MS;

export const seed = (n) => {
  MS.rng = MS.makeRng(n);
};
