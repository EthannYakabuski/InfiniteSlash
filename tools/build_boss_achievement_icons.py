"""Extend the established store medal family for the two new boss badges."""
from __future__ import annotations

import hashlib
import json
import zipfile
from pathlib import Path

from PIL import Image, ImageDraw

from build_store_icons import ROOT, P, badge, crown, laurel, poly, sparkle, sprite_frame, stamp

OUT = ROOT / "store/boss-achievements"
DEFINITIONS = [
    {"key": "rare_boss", "name": "Royal Upset", "description": "Defeat a rare boss: Moonmallow Majesty, Gilded Chancellor, or Lime Imperator.",
     "short_description": "Defeat any rare boss.", "type": "Standard", "suggested_points": 20, "suggested_initial_state": "Revealed"},
    {"key": "all_bosses", "name": "Crown Census", "description": "Defeat all 12 different bosses across your runs.",
     "short_description": "Defeat all 12 different bosses.", "type": "Standard", "suggested_points": 30, "suggested_initial_state": "Revealed"},
]


def make_icon(key: str) -> Image.Image:
    image = badge("purple" if key == "rare_boss" else "teal")
    draw = ImageDraw.Draw(image)
    if key == "rare_boss":
        laurel(draw, P["purple"])
        # Use one of the actual rare boss sprites beneath a jeweled crown.
        moon = sprite_frame("Assets/Monsters/moon_mallow.png", pixels=28)
        stamp(image, moon, 64, 73, 52)
        crown(draw, 64, 39, 55, 29, P["gold"], P["teal_light"])
        poly(draw, [(64, 22), (70, 30), (64, 38), (58, 30)], P["teal_light"])
        sparkle(draw, 29, 48, 6, P["teal_light"])
        sparkle(draw, 99, 53, 5)
        sparkle(draw, 91, 89, 4, P["gold_light"])
    else:
        # A royal ledger with twelve visible seals, one per stable boss identity.
        poly(draw, [(28, 35), (58, 39), (64, 45), (71, 39), (100, 35),
                    (102, 93), (73, 97), (64, 103), (55, 97), (26, 93)], P["gold_shadow"], width=3)
        poly(draw, [(30, 38), (58, 42), (64, 47), (64, 96), (55, 91), (30, 88)], P["cream"])
        poly(draw, [(64, 47), (72, 42), (98, 38), (98, 88), (73, 91), (64, 96)], "#ead3a6")
        for column in range(4):
            for row in range(3):
                x, y = 38 + column * 17, 57 + row * 13
                crown(draw, x, y, 13, 9, P["gold"], P["coral"] if row == 2 else P["teal_light"])
        crown(draw, 64, 29, 39, 22)
        poly(draw, [(67, 92), (75, 92), (75, 106), (71, 102), (67, 106)], P["coral"], None)
        sparkle(draw, 24, 31, 4)
        sparkle(draw, 105, 86, 4, P["teal_light"])
    return image.convert("RGB").resize((512, 512), Image.Resampling.NEAREST)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    config = json.loads((ROOT / "config/play_services.json").read_text("utf-8"))
    items = []
    for definition in DEFINITIONS:
        target = OUT / (definition["key"] + ".png")
        make_icon(definition["key"]).save(target, optimize=True)
        with Image.open(target) as image:
            assert image.size == (512, 512) and image.mode == "RGB"
        assert target.stat().st_size < 1_000_000
        google_id = config["achievements"].get(definition["key"], "")
        items.append({**definition, "google_id": google_id,
                      "status": "Configured" if google_id else "Awaiting owner-supplied Google achievement ID",
                      "filename": target.name, "dimensions": [512, 512], "format": "PNG",
                      "bytes": target.stat().st_size, "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    manifest = {"package_name": "com.slash.game", "game_id": "832658811620", "achievements": items,
                "instructions": "Create these two new Standard achievements, upload the matching PNGs, then send their IDs. Existing IDs are unchanged. Local unlocks are already saved and queued for replay after the IDs are configured.",
                "provenance": "Extension of the existing code-native pixel medal system; actual moon_mallow sprite reused; no generated-image edits.",
                "generator": "tools/build_boss_achievement_icons.py"}
    (OUT / "achievement_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", "utf-8")
    preview = Image.new("RGB", (1040, 512), P["ink"])
    for index, item in enumerate(items):
        with Image.open(OUT / item["filename"]) as icon:
            preview.paste(icon, (index * 528, 0))
    preview.save(OUT / "preview.png", optimize=True)
    with zipfile.ZipFile(OUT / "InfiniteSlash-new-boss-achievements.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for item in items:
            archive.write(OUT / item["filename"], item["filename"])
        archive.write(OUT / "achievement_manifest.json", "achievement_manifest.json")
        if (OUT / "README.md").exists():
            archive.write(OUT / "README.md", "README.md")
    print(json.dumps({"passed": True, "icons": len(items), "maximum_bytes": max(i["bytes"] for i in items)}, indent=2))


if __name__ == "__main__":
    main()
