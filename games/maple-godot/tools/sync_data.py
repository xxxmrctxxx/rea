"""Regenerates scripts/game_data.gd from games/maple-pc/src/data.js.

Usage: python tools/sync_data.py   (needs Node.js on PATH)
"""

import json
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
JS = r"""
globalThis.MS = {};
require(process.argv[1] + "/core.js");
require(process.argv[1] + "/data.js");
const MS = globalThis.MS;
console.log(JSON.stringify({ JOBS: MS.JOBS, SKILL_KEYS: MS.SKILL_KEYS,
  MONSTERS: MS.MONSTERS, ITEMS: MS.ITEMS, MAPS: MS.MAPS }));
"""


def gd(v, ind=0):
    pad, end = "\t" * (ind + 1), "\t" * ind
    if isinstance(v, dict):
        if not v:
            return "{}"
        items = ['%s"%s": %s,' % (pad, k, gd(x, ind + 1)) for k, x in v.items()]
        return "{\n" + "\n".join(items) + "\n" + end + "}"
    if isinstance(v, list):
        if all(not isinstance(x, (dict, list)) for x in v):
            return "[" + ", ".join(gd(x, ind) for x in v) + "]"
        return "[\n" + "\n".join("%s%s," % (pad, gd(x, ind + 1)) for x in v) + "\n" + end + "]"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return repr(v)
    if isinstance(v, int):
        return str(v)
    return json.dumps(v, ensure_ascii=False)


def main():
    src = os.path.join(ROOT, "..", "maple-pc", "src")
    data = json.loads(subprocess.check_output(["node", "-e", JS, os.path.abspath(src)]))
    lines = [
        "extends RefCounted",
        "## Static game data: jobs, skills, monsters, items and maps.",
        "## Mirrors games/maple-pc/src/data.js; regenerate with tools/sync_data.py.",
        "",
    ]
    for key in ["JOBS", "SKILL_KEYS", "MONSTERS", "ITEMS", "MAPS"]:
        lines.append("const %s = %s\n" % (key, gd(data[key])))
    with open(os.path.join(ROOT, "scripts", "game_data.gd"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    main()
