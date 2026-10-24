"""Extract the 2D images shipped inside the MapleStory M APK for local use.

The APK only ships launcher/UI art (title background, loading illustrations,
character-select portraits, skill button frames, HUD pieces). In-game
character and map sprites are downloaded from the game servers after login
and are not in the APK.

Output goes to games/maple-godot/assets/apk/, which is git-ignored: the
images belong to Nexon and must stay on your own machine.

Usage (Python 3.9+):
    pip install UnityPy Pillow
    python tools/extract_apk_assets.py "path/to/MapleStory M.xapk"
"""

import argparse
import io
import os
import sys
import tempfile
import zipfile

# Full textures to export as-is.
TEXTURES = {
    "game_start_bg": "title_bg",
    "DownloadScene_01": "art_01",
    "DownloadScene_02": "art_02",
    "DownloadScene_03": "art_03",
    "DownloadScene_06": "art_06",
    "DownloadScene_07": "art_07",
    "DownloadScene_09": "art_09",
    "DownloadScene_10": "art_10",
    "DownloadScene_11": "art_11",
    "DownloadScene_12": "art_12",
    "DownloadScene_13": "art_13",
    "HPBarMonster": "hpbar_monster",
    "HPBarMonster_Green": "hpbar_monster_green",
}

# Atlases cut into separate images along transparent gaps.
ATLASES = {
    "Creating_CharactersAtlas": "portraits",
    "26_SkillButtonAtlas": "skill_buttons",
}

# Named picks from the sliced atlases, used by the Godot project. Indices
# match APK 2.450.5776; other versions may order slices differently, and the
# game falls back to drawn shapes for any file that is missing.
PICKS = {
    "portraits": {
        "job_warrior": 0,
        "job_magician": 19,
        "job_bowman": 42,
        "job_thief": 57,
        "job_pirate": 111,
    },
    "skill_buttons": {
        "button_attack": 49,
        "button_jump": 44,
        "button_empty": 11,
        "button_ring": 37,
    },
}

UNITY_VERSION = "2022.3.62f2"
BASE_APK = "com.nexon.maplem.global.apk"
DATA_PREFIX = "assets/bin/Data/"


def find_base_apk(path):
    """Accepts a .xapk bundle or the base .apk; returns a ZipFile of the APK."""
    outer = zipfile.ZipFile(path)
    if BASE_APK in outer.namelist():
        return zipfile.ZipFile(io.BytesIO(outer.read(BASE_APK)))
    return outer


def unpack_data(apk, dest):
    for name in apk.namelist():
        if name.startswith(DATA_PREFIX) and not name.endswith("/"):
            rel = name[len(DATA_PREFIX):]
            if rel.startswith("Managed/"):
                continue
            target = os.path.join(dest, rel)
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with open(target, "wb") as f:
                f.write(apk.read(name))


def slice_atlas(image, min_size, out_dir):
    """Cuts an RGBA atlas into its opaque islands (4-connected, alpha > 24)."""
    w, h = image.size
    alpha = image.getchannel("A").load()
    seen = bytearray(w * h)
    boxes = []
    for y0 in range(h):
        for x0 in range(w):
            i = y0 * w + x0
            if seen[i] or alpha[x0, y0] <= 24:
                continue
            stack = [(x0, y0)]
            seen[i] = 1
            x1, y1, x2, y2 = x0, y0, x0, y0
            while stack:
                x, y = stack.pop()
                x1, y1, x2, y2 = min(x1, x), min(y1, y), max(x2, x), max(y2, y)
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not seen[j] and alpha[nx, ny] > 24:
                            seen[j] = 1
                            stack.append((nx, ny))
            if x2 - x1 + 1 >= min_size and y2 - y1 + 1 >= min_size:
                boxes.append((x1, y1, x2 + 1, y2 + 1))
    boxes.sort(key=lambda b: (b[1] // 32, b[0]))
    os.makedirs(out_dir, exist_ok=True)
    for n, box in enumerate(boxes):
        image.crop(box).save(os.path.join(out_dir, "%03d.png" % n))
    return len(boxes)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("apk", help="MapleStory M .xapk or base .apk")
    here = os.path.dirname(os.path.abspath(__file__))
    parser.add_argument("--out", default=os.path.join(here, "..", "assets", "apk"))
    args = parser.parse_args()

    try:
        import UnityPy
    except ImportError:
        sys.exit("Missing dependency: pip install UnityPy Pillow")
    UnityPy.config.FALLBACK_UNITY_VERSION = UNITY_VERSION

    out = os.path.abspath(args.out)
    os.makedirs(out, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        print("Unpacking Unity data from", args.apk)
        unpack_data(find_base_apk(args.apk), tmp)
        env = UnityPy.load(tmp)
        done = set()
        for obj in env.objects:
            if obj.type.name != "Texture2D":
                continue
            tex = obj.read()
            name = tex.m_Name
            if name in done or tex.m_Width <= 1 or (name not in TEXTURES and name not in ATLASES):
                continue
            image = tex.image.convert("RGBA")
            done.add(name)
            if name in TEXTURES:
                if name.startswith("DownloadScene_"):
                    # Full-body character art: trim the transparent margin.
                    image = image.crop(image.getchannel("A").getbbox())
                image.save(os.path.join(out, TEXTURES[name] + ".png"))
                print("  %-28s -> %s.png" % (name, TEXTURES[name]))
            else:
                folder = os.path.join(out, ATLASES[name])
                count = slice_atlas(image, 40, folder)
                print("  %-28s -> %s/ (%d images)" % (name, ATLASES[name], count))
                for pick, index in PICKS.get(ATLASES[name], {}).items():
                    src = os.path.join(folder, "%03d.png" % index)
                    if index < count:
                        with open(src, "rb") as a, open(os.path.join(out, pick + ".png"), "wb") as b:
                            b.write(a.read())
    missing = (set(TEXTURES) | set(ATLASES)) - done
    if missing:
        print("Not found in this APK:", ", ".join(sorted(missing)))
    print("Done:", out)


if __name__ == "__main__":
    main()
