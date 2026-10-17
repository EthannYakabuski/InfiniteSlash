"""Extend InfiniteSlash's code-native medal family for the production update."""
from __future__ import annotations

import argparse
import hashlib
import json
import zipfile
from pathlib import Path

from PIL import Image, ImageDraw

from build_store_icons import ROOT, P, HERO, MONSTERS, SWORD, badge, crown, font, laurel, poly, sparkle, stamp

OUT = ROOT / "store/production-update"
DEFINITIONS = [
    {"category": "achievements", "key": "bestiary_50", "name": "Field Guide", "description": "Defeat 50 different creature species across your runs.", "type": "Standard", "suggested_points": 10},
    {"category": "achievements", "key": "bestiary_100", "name": "Monster Scholar", "description": "Defeat 100 different creature species across your runs.", "type": "Standard", "suggested_points": 15},
    {"category": "achievements", "key": "bestiary_150", "name": "Midnight Archivist", "description": "Defeat 150 different creature species across your runs.", "type": "Standard", "suggested_points": 20},
    {"category": "achievements", "key": "bestiary_200", "name": "Living Bestiary", "description": "Defeat 200 different creature species across your runs.", "type": "Standard", "suggested_points": 25},
    {"category": "achievements", "key": "biome_50", "name": "Beyond the Kingdom", "description": "Reach level 50 and enter Crownfall Keep.", "type": "Standard", "suggested_points": 20},
    {"category": "leaderboards", "key": "highest_combo", "name": "Unbroken Steel", "description": "Highest kill combo in one completed run.", "type": "Numeric", "decimals": 0, "order": "Larger is better"},
    {"category": "leaderboards", "key": "highest_level", "name": "Highest Level", "description": "Highest level reached in one completed run.", "type": "Numeric", "decimals": 0, "order": "Larger is better"},
]

DIGITS = {"0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
          "2": ["111", "001", "111", "100", "111"], "5": ["111", "100", "111", "001", "111"]}


def number(draw, value, y=92, color=P["cream"]):
    text = str(value)
    size, gap = 2, 2
    x0 = (128 - (len(text) * 6 + (len(text) - 1) * gap)) // 2
    for index, digit in enumerate(text):
        for row, bits in enumerate(DIGITS[digit]):
            for column, bit in enumerate(bits):
                if bit == "1":
                    x, yy = x0 + index * 8 + column * size, y + row * size
                    draw.rectangle((x, yy, x + size - 1, yy + size - 1), fill=color)


def make_icon(key):
    themes = {"bestiary_50": "green", "bestiary_100": "teal", "bestiary_150": "purple",
              "bestiary_200": "cherry", "biome_50": "cherry", "highest_combo": "blue", "highest_level": "purple"}
    im = badge(themes[key])
    d = ImageDraw.Draw(im)
    if key.startswith("bestiary_"):
        milestone = int(key.split("_")[1])
        paper = "#fff2d2" if milestone < 150 else "#c7c7e1"
        poly(d, [(29, 38), (55, 41), (64, 46), (73, 41), (99, 38), (100, 88),
                 (73, 91), (64, 97), (55, 91), (28, 88)], P["gold_shadow"], width=3)
        poly(d, [(32, 41), (56, 44), (64, 49), (64, 88), (56, 84), (32, 82)], paper)
        poly(d, [(64, 49), (73, 44), (96, 41), (96, 82), (73, 85), (64, 89)], "#d8bf9e")
        for x in [36, 73]:
            d.line((x, 78, x + 17, 78), fill=P["gold_shadow"], width=2)
        stamp(im, MONSTERS[{50: 2, 100: 4, 150: 1, 200: 3}[milestone]], 46, 62, 25)
        stamp(im, MONSTERS[{50: 0, 100: 3, 150: 4, 200: 1}[milestone]], 80, 62, 25)
        if milestone == 150:
            d.ellipse((52, 23, 74, 45), fill=P["gold_light"])
            d.ellipse((60, 20, 78, 38), fill="#302e49")
            sparkle(d, 84, 30, 3, P["silver"])
        elif milestone == 200:
            crown(d, 64, 30, 42, 23, P["gold"], P["teal_light"])
            laurel(d, P["gold"])
        else:
            sparkle(d, 64, 31, 6, P["green"] if milestone == 50 else P["teal_light"])
        poly(d, [(42, 88), (86, 88), (88, 104), (40, 104)], P[themes[key]], width=2)
        number(d, milestone)
    elif key == "biome_50":
        # A traversable ruined gate, ash landscape and one recognisable knight.
        d.rectangle((38, 39, 90, 92), fill=P["ink"])
        d.pieslice((38, 23, 90, 75), 180, 360, fill=P["slate"])
        d.rectangle((37, 48, 47, 94), fill=P["slate"])
        d.rectangle((81, 48, 91, 94), fill=P["slate"])
        d.pieslice((48, 34, 80, 73), 180, 360, fill="#872f46")
        d.rectangle((48, 53, 80, 93), fill="#872f46")
        for y in [52, 67, 81]:
            d.line((37, y, 47, y), fill=P["ink"], width=2)
            d.line((81, y, 91, y), fill=P["ink"], width=2)
        poly(d, [(48, 87), (57, 76), (62, 81), (69, 70), (80, 87)], P["gold_shadow"], None)
        poly(d, [(49, 94), (79, 94), (90, 104), (38, 104)], P["gold_shadow"], None)
        stamp(im, HERO, 64, 81, 34)
        for x, y in [(28, 60), (99, 65), (55, 43), (75, 50)]:
            sparkle(d, x, y, 3, P["coral"])
    elif key == "highest_combo":
        # Linked steel rings and a pair of sweeping swords.
        for x, y in [(41, 47), (64, 61), (87, 76)]:
            d.ellipse((x - 15, y - 10, x + 15, y + 10), outline=P["ink"], width=7)
            d.ellipse((x - 14, y - 9, x + 14, y + 9), outline=P["gold"], width=4)
        stamp(im, SWORD, 43, 75, 57, -35)
        stamp(im, SWORD, 86, 45, 57, 35, True)
        poly(d, [(65, 36), (57, 59), (65, 59), (60, 83), (77, 54), (68, 54), (75, 36)], P["teal_light"], width=2)
        sparkle(d, 35, 32, 5)
        sparkle(d, 95, 94, 5)
    elif key == "highest_level":
        # The stairway visibly climbs toward a distant crowned summit.
        for index in range(5):
            x, y = 30 + index * 11, 94 - index * 11
            poly(d, [(x, y), (x + 24, y), (x + 24, 104), (x, 104)], P["slate"] if index % 2 == 0 else P["blue"], width=2)
            d.line((x + 2, y + 2, x + 22, y + 2), fill=P["silver"], width=2)
        crown(d, 83, 37, 36, 22)
        stamp(im, HERO, 46, 67, 31)
        poly(d, [(33, 51), (33, 37), (27, 37), (39, 25), (51, 37), (45, 37), (45, 51)], P["teal_light"], width=2)
        sparkle(d, 102, 64, 4)
    return im.convert("RGB").resize((512, 512), Image.Resampling.NEAREST)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metadata-only", action="store_true")
    args = parser.parse_args()
    config = json.loads((ROOT / "config/play_services.json").read_text("utf-8"))
    items = []
    for definition in DEFINITIONS:
        target = OUT / definition["category"] / (definition["key"] + ".png")
        target.parent.mkdir(parents=True, exist_ok=True)
        if not args.metadata_only:
            make_icon(definition["key"]).save(target, optimize=True)
        with Image.open(target) as image:
            assert image.size == (512, 512) and image.mode == "RGB"
        assert target.stat().st_size < 1_000_000
        google_id = config[definition["category"]].get(definition["key"], "")
        items.append({**definition, "google_id": google_id, "status": "Configured" if google_id else "Awaiting owner-supplied Google ID",
                      "suggested_initial_state": "Revealed" if definition["category"] == "achievements" else None,
                      "relative_path": target.relative_to(ROOT).as_posix(), "filename": target.name,
                      "dimensions": [512, 512], "format": "PNG", "mode": "RGB", "bytes": target.stat().st_size,
                      "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    pending_ids = sum(not item["google_id"] for item in items)
    registration = ("Create the pending Standard achievements and Numeric integer larger-is-better leaderboards, upload matching icons, and return generated IDs by semantic key. Blank IDs track locally and replay after configuration/authentication."
                    if pending_ids else "All five Standard achievements and two Numeric integer larger-is-better leaderboards are configured with owner-supplied Google IDs. Upload matching icons to these existing records; verify eligible-account unlocks, score submissions and offline replay, then publish the Play Games configuration when ready. Do not create duplicate definitions.")
    manifest = {"schema_version": 1, "package_name": "com.slash.game", "game_id": config["game_id"], "features": items,
                "species_metric": "Unique confirmed creature species defeated across runs; repeat kills and boss summons do not count again.",
                "legacy_migration": "Validated legacy discovered species were kill-only discoveries and migrate into unique defeated species.",
                "existing_collector": "Keep the same Google ID, Incremental type and target100. Update its display name to Bestiary Pioneer and description to Defeat 100 different creature species across your runs.",
                "existing_bosses_board": "Crown Hoarder/bosses_in_run already tracks most bosses in a completed run; no duplicate board is needed.",
                "registration": registration,
                "provenance": "Established code-native pixel medal system with existing knight/creature sprite crops; source images unchanged.",
                "generator": "tools/build_production_service_icons.py"}
    (OUT / "feature_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", "utf-8")
    if not args.metadata_only:
        preview = Image.new("RGB", (4 * 384, 2 * 432), P["ink"])
        d = ImageDraw.Draw(preview)
        for index, item in enumerate(items):
            x, y = (index % 4) * 384, (index // 4) * 432
            with Image.open(ROOT / item["relative_path"]) as icon:
                preview.paste(icon.resize((384, 384), Image.Resampling.NEAREST), (x, y))
            d.text((x + 16, y + 388), item["name"], fill=P["cream"], font=font(23))
        preview.save(OUT / "preview.png", optimize=True)
    with zipfile.ZipFile(OUT / "InfiniteSlash-production-feature-icons.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for item in items:
            archive.write(ROOT / item["relative_path"], item["category"] + "/" + item["filename"])
        for name in ["feature_manifest.json", "README.md", "preview.png"]:
            if (OUT / name).is_file():
                archive.write(OUT / name, name)
    print(json.dumps({"passed": True, "icons": len(items), "pending_ids": sum(not i["google_id"] for i in items),
                      "maximum_bytes": max(i["bytes"] for i in items)}, indent=2))


if __name__ == "__main__":
    main()
