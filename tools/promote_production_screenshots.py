"""Promote existing acceptance renders into the upload kit without changing RGB pixels."""
from __future__ import annotations

import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SHOTS = ROOT / "store/screenshots"
BACKUP = ROOT / "output/review/store-screenshots-0.2"
SOURCES = ROOT / "output/review"
VIEWS = [
    ("day", "01_meadow_mayhem", "Daytime automatic slashing and always-active guard.", 12, 30.0),
    ("night_host", "02_night_war_host", "Stage-two veterans and night-only creatures after dark.", 30, 110.0),
    ("keep_overdrive", "03_crownfall_overdrive", "Level-50 Crownfall Keep with Overdrive active.", 50, 110.0),
    ("fire_active", "04_boss_fire_circle", "An active circular boss fire zone.", 50, 110.0),
    ("quake_active", "05_earthquake_corridor", "An active rectangular earthquake with lateral escape routes.", 50, 110.0),
    ("pulse_active", "06_electric_escape_gap", "A concave electric pulse with a visible safe gap.", 50, 110.0),
    ("rare_trade_choices", "07_build_your_tradeoff", "A paused choice between lifesteal and speed with a guard-recovery cost.", 20, 110.0),
    ("legendary_choices", "08_legendary_crossroads", "A paused choice between Phoenix Oath and Worldbreaker.", 25, 110.0),
]
TARGETS = {"phone": (540, 960), "tablet_7": (1080, 1920), "tablet_10": (1080, 1920)}


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    original_manifest = SHOTS / "manifest.json"
    old = json.loads(original_manifest.read_text("utf-8"))
    plan = []
    # Validate every input before touching the existing upload folders.
    for category, dimensions in TARGETS.items():
        for view, name, description, level, elapsed in VIEWS:
            source = SOURCES / f"production_{view}_{dimensions[0]}x{dimensions[1]}.png"
            with Image.open(source) as image:
                image.load()
                assert image.size == dimensions and image.mode in ["RGB", "RGBA"]
                if image.mode == "RGBA":
                    assert image.getchannel("A").getextrema() == (255, 255), source
                pixels = image.convert("RGB").tobytes()
            plan.append((category, dimensions, source, name, description, level, elapsed, digest(pixels)))

    if not BACKUP.exists():
        assert old.get("game_version") != "0.3.0", "Historical backup must be created from the prior upload kit"
        shutil.copytree(SHOTS, BACKUP)
        for record in old["screenshots"]:
            relative = Path(record["file"]).relative_to("store/screenshots")
            assert (SHOTS / relative).read_bytes() == (BACKUP / relative).read_bytes()
    assert (BACKUP / "manifest.json").is_file(), "Preserved historical manifest is required"

    planned_names = {name + ".png" for _, _, _, name, *_ in plan}
    historical = json.loads((BACKUP / "manifest.json").read_text("utf-8"))
    historical_names = {Path(record["file"]).name for record in historical["screenshots"]}
    for category in TARGETS:
        directory = SHOTS / category
        directory.mkdir(parents=True, exist_ok=True)
        for path in directory.glob("*.png"):
            assert path.resolve().is_relative_to(SHOTS.resolve())
            assert path.name in planned_names | historical_names, f"Unexpected upload file preserved: {path}"
            if path.name in historical_names:
                assert path.read_bytes() == (BACKUP / category / path.name).read_bytes()
            path.unlink()

    records = []
    for category, dimensions, source, name, description, level, elapsed, pixel_hash in plan:
        target = SHOTS / category / (name + ".png")
        with Image.open(source) as image:
            image.convert("RGB").save(target, optimize=True)
        with Image.open(target) as image:
            assert image.mode == "RGB" and digest(image.tobytes()) == pixel_hash
        records.append({"category": category, "scenario": name, "description": description,
                        "file": target.relative_to(ROOT).as_posix(), "source_capture": source.relative_to(ROOT).as_posix(),
                        "source_sha256": digest(source.read_bytes()), "source_rgb_pixel_sha256": pixel_hash,
                        "pixel_sha256": pixel_hash, "sha256": digest(target.read_bytes()), "mode": "RGB",
                        "format": "24-bit RGB PNG, no alpha", "width": dimensions[0], "height": dimensions[1],
                        "bytes": target.stat().st_size, "logical_viewport": [540, 960], "level": level,
                        "elapsed_seconds": elapsed, "score": 201840, "style": "shield", "seed": "834713",
                        "renderer": "Godot 4.5.1 / OpenGL compatibility, desktop",
                        "provenance": "Existing actual-game acceptance render; deterministic composed state; lossless removal of fully opaque alpha only; every RGB pixel verified equal to preserved source; no resize, retouching, compositing, AI mockup or physical-device capture."})
    sources = ["scripts/game.gd", "scripts/game_ui.gd", "scripts/world.gd", "scripts/class_profiles.gd",
               "scripts/progression.gd", "scripts/boss_hazards.gd", "scripts/upgrade_catalog.gd",
               "data/monsters.json", "tests/capture_production.gd"]
    manifest = {"game_version": "0.3.0", "android_version_code": 8,
                "capture_script": "tests/capture_production.gd", "promotion_script": "tools/promote_production_screenshots.py",
                "promoted_at_utc": datetime.now(timezone.utc).isoformat(), "logical_game_size": [540, 960],
                "historical_backup": "output/review/store-screenshots-0.2",
                "shared_tablet_captures": "7-inch and 10-inch upload groups intentionally share the same exact1080x1920 source frames; they are not separate device captures.",
                "source_sha256_at_promotion": {name: digest((ROOT / name).read_bytes()) for name in sources},
                "screenshots": records}
    original_manifest.write_text(json.dumps(manifest, indent=2) + "\n", "utf-8")
    print(json.dumps({"passed": True, "screenshots": len(records), "historical_images_preserved": len(historical["screenshots"]),
                      "source_rgb_pixels_preserved": True, "maximum_bytes": max(item["bytes"] for item in records)}, indent=2))


if __name__ == "__main__":
    main()
