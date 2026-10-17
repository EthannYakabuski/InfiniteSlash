"""Check upload deliverables and package them; does not modify any image pixels."""
from __future__ import annotations

import hashlib
import json
import re
import zipfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
STORE = ROOT / "store"


def main() -> None:
    config = json.loads((ROOT / "config/play_services.json").read_text(encoding="utf-8"))
    icons = json.loads((STORE / "icons/icon_manifest.json").read_text(encoding="utf-8"))["icons"]
    shots = json.loads((STORE / "screenshots/manifest.json").read_text(encoding="utf-8"))["screenshots"]
    failures: list[str] = []
    uploads: list[dict] = []

    def check_image(path: Path, size: tuple[int, int], modes: tuple[str, ...], limit: int, role: str) -> dict:
        with Image.open(path) as image:
            image.load()
            if image.size != size or image.mode not in modes or image.format != "PNG":
                failures.append(f"{path.name}: expected PNG {size} {modes}, found {image.format} {image.size} {image.mode}")
            if path.stat().st_size > limit:
                failures.append(f"{path.name}: exceeds {limit} bytes")
            record = {"file": path.relative_to(STORE).as_posix(), "role": role,
                      "width": image.width, "height": image.height, "mode": image.mode,
                      "bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                      "pixel_sha256": hashlib.sha256(image.tobytes()).hexdigest()}
            uploads.append(record)
            return record

    check_image(STORE / "branding/app_icon.png", (512, 512), ("RGBA",), 1_000_000, "app_icon")
    branding = json.loads((STORE / "branding/prompts.json").read_text(encoding="utf-8"))
    check_image(ROOT / branding["feature_graphic"]["output"], (1024, 500), ("RGB",), 15_000_000, "feature_graphic")
    new_boss_keys = {"rare_boss", "all_bosses"}
    production_manifest_path = STORE / "production-update/feature_manifest.json"
    production_features = json.loads(production_manifest_path.read_text(encoding="utf-8"))["features"]
    production_keys = {category: {i["key"] for i in production_features if i["category"] == category}
                       for category in ["achievements", "leaderboards"]}
    if production_keys != {"achievements": {"bestiary_50", "bestiary_100", "bestiary_150", "bestiary_200", "biome_50"},
                           "leaderboards": {"highest_combo", "highest_level"}}:
        failures.append("Expected five production achievements and two production leaderboards")
    expected_achievement_keys = {k for k, v in config["achievements"].items() if v and k not in new_boss_keys | production_keys["achievements"]}
    expected_board_keys = {k for k, v in config["leaderboards"].items() if v and k not in production_keys["leaderboards"]}
    for category, keys in [("achievements", expected_achievement_keys), ("leaderboards", expected_board_keys)]:
        entries = [i for i in icons if i["category"] == category]
        actual_keys = {i["key"] for i in entries}
        if len(entries) != len(keys) or actual_keys != keys:
            failures.append(f"{category}: configured keys do not match icons")
        if len(list((STORE / f"icons/{category}").glob("*.png"))) != len(keys):
            failures.append(f"{category}: extra or missing upload PNGs")
        for entry in entries:
            path = ROOT / entry["relative_path"]
            record = check_image(path, (512, 512), ("RGB",), 1_000_000, category)
            if config[category][entry["key"]] != entry["google_id"]:
                failures.append(f"{entry['key']}: Google ID mismatch")
            if record["sha256"] != entry["sha256"]:
                failures.append(f"{entry['key']}: icon manifest hash mismatch")
            if category == "achievements":
                incremental = config["incremental_achievements"].get(entry["key"])
                if (entry["type"] == "Incremental") != (incremental is not None) or entry["steps"] != incremental:
                    failures.append(f"{entry['key']}: incremental type/target mismatch")
            record.update(key=entry["key"], google_id=entry["google_id"], title=entry["title"])

    # Boss badges use their own artwork folder and can have configured or pending IDs.
    boss_manifest_path = STORE / "boss-achievements/achievement_manifest.json"
    boss_badges = json.loads(boss_manifest_path.read_text(encoding="utf-8"))["achievements"]
    if {entry["key"] for entry in boss_badges} != {"rare_boss", "all_bosses"}:
        failures.append("Expected two new boss achievement definitions")
    for entry in boss_badges:
        google_id = config["achievements"].get(entry["key"], "")
        role = "achievements" if google_id else "pending_achievements"
        record = check_image(STORE / "boss-achievements" / entry["filename"], (512, 512), ("RGB",), 1_000_000, role)
        if config["achievements"].get(entry["key"], "") != entry["google_id"]:
            failures.append(f"{entry['key']}: Google ID mismatch")
        if record["sha256"] != entry["sha256"] or entry["type"] != "Standard":
            failures.append(f"{entry['key']}: icon hash or type mismatch")
        if entry["key"] in config["incremental_achievements"]:
            failures.append(f"{entry['key']}: boss achievements must remain Standard")
        if bool(google_id) != (entry.get("status") == "Configured"):
            failures.append(f"{entry['key']}: configured status does not match runtime ID")
        record.update(key=entry["key"], google_id=entry["google_id"], title=entry["name"])

    for entry in production_features:
        category, key = entry["category"], entry["key"]
        google_id = config[category].get(key, "")
        record = check_image(ROOT / entry["relative_path"], (512, 512), ("RGB",), 1_000_000,
                             category if google_id else "pending_" + category)
        if google_id != entry["google_id"] or record["sha256"] != entry["sha256"]:
            failures.append(f"{key}: production icon ID/hash mismatch")
        if bool(google_id) != (entry.get("status") == "Configured"):
            failures.append(f"{key}: production configured status mismatch")
        if category == "achievements" and (entry["type"] != "Standard" or key in config["incremental_achievements"]):
            failures.append(f"{key}: new production achievements must remain Standard")
        if category == "leaderboards" and (entry["type"] != "Numeric" or entry["decimals"] != 0 or entry["order"] != "Larger is better"):
            failures.append(f"{key}: new board must be Numeric integer and larger is better")
        record.update(key=key, google_id=google_id, title=entry["name"])

    categories = {"phone": (540, 960), "tablet_7": (1080, 1920), "tablet_10": (1080, 1920)}
    if len(shots) != 24:
        failures.append("Expected 24 screenshots")
    for category, size in categories.items():
        entries = [s for s in shots if s["category"] == category]
        if len(entries) != 8 or len(list((STORE / f"screenshots/{category}").glob("*.png"))) != 8:
            failures.append(f"{category}: expected eight screenshots")
        for entry in entries:
            record = check_image(ROOT / entry["file"], size, ("RGB",), 8_000_000, category)
            if record["width"] * 16 != record["height"] * 9 or record["sha256"] != entry["sha256"]:
                failures.append(f"{entry['file']}: aspect/hash mismatch")
            minimum, maximum = (1080, 7680) if category == "tablet_10" else (320, 3840)
            if not all(minimum <= side <= maximum for side in size):
                failures.append(f"{category}: dimensions outside requested bounds")

    hashes = [r["pixel_sha256"] for r in uploads]
    by_pixel_hash: dict[str, list[dict]] = {}
    for record in uploads:
        by_pixel_hash.setdefault(record["pixel_sha256"], []).append(record)
    for duplicates in by_pixel_hash.values():
        if len(duplicates) <= 1:
            continue
        # The owner explicitly chose identical1080x1920 renders for both tablet
        # groups. Other duplicates, including within a group, remain invalid.
        shared_tablet = len(duplicates) == 2 and {r["role"] for r in duplicates} == {"tablet_7", "tablet_10"} \
            and Path(duplicates[0]["file"]).name == Path(duplicates[1]["file"]).name
        if not shared_tablet:
            failures.append("Unexpected duplicate upload images")
    descriptions = {}
    for name, limit in [("short_description", 80), ("full_description", 4000)]:
        text = (STORE / f"listing/{name}.txt").read_text(encoding="utf-8").strip()
        descriptions[name] = {"characters": len(text), "limit": limit}
        if not text or len(text) > limit:
            failures.append(f"{name}: empty or exceeds limit")
    readme_path = STORE / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    for key, label in [("short_description", "Short description"), ("full_description", "Full description")]:
        count, limit = descriptions[key]["characters"], descriptions[key]["limit"]
        readme = re.sub(rf"\| {label} \| `listing/{key}\.txt` \| .*? \|",
                        f"| {label} | `listing/{key}.txt` | {count:,} characters; limit {limit:,} |", readme)
    readme_path.write_text(readme, encoding="utf-8")
    metadata = json.loads((STORE / "listing/metadata.json").read_text(encoding="utf-8"))
    if metadata["package_name"] != "com.slash.game" or len(metadata["recommended_tags"]) != 5:
        failures.append("Listing package or tag count is incorrect")
    expected_feature_ids = {v for category in ["achievements", "leaderboards"] for v in config[category].values() if v}
    configured_id_count = sum(bool(value) for category in ["achievements", "leaderboards"] for value in config[category].values())
    if len(expected_feature_ids) != configured_id_count:
        failures.append("Configured Google feature IDs must be unique")
    if {r["google_id"] for r in uploads if r.get("google_id")} != expected_feature_ids:
        failures.append("Upload icon IDs do not match the configured Google features")
    report = {"passed": not failures, "failures": failures, "image_count": len(uploads), "distinct_image_count": len(set(hashes)),
              "achievements": len(expected_achievement_keys) + len(boss_badges) + len(production_keys["achievements"]),
              "configured_achievements": len(expected_achievement_keys) + sum(bool(i["google_id"]) for i in boss_badges) + sum(bool(i["google_id"]) for i in production_features if i["category"] == "achievements"),
              "pending_achievements": sum(not i["google_id"] for i in boss_badges) + sum(not i["google_id"] for i in production_features if i["category"] == "achievements"),
              "leaderboards": len(expected_board_keys) + len(production_keys["leaderboards"]),
              "configured_leaderboards": len(expected_board_keys) + sum(bool(i["google_id"]) for i in production_features if i["category"] == "leaderboards"),
              "pending_leaderboards": sum(not i["google_id"] for i in production_features if i["category"] == "leaderboards"),
              "screenshots": len(shots), "description_lengths": descriptions,
              "all_image_bytes": sum(r["bytes"] for r in uploads)}
    (STORE / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    pending_definitions = report["pending_achievements"] + report["pending_leaderboards"]
    upload_note = (f"Attach configured feature icons to existing Google IDs. Create only the {pending_definitions} pending feature definitions, following their manifests. Do not re-import historical achievement definitions."
                   if pending_definitions else f"All {report['configured_achievements']} achievement IDs and {report['configured_leaderboards']} leaderboard IDs are configured. Attach icons to their existing Google records using the manifests; do not create duplicate definitions or re-import historical achievement drafts. Live eligible-account testing and Console publication remain owner steps.")
    manifest = {"package_name": "com.slash.game", "pgs_game_id": config["game_id"],
                "listing": metadata, "descriptions": descriptions, "images": uploads,
                "upload_note": upload_note}
    (STORE / "upload_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    if failures:
        raise SystemExit("STORE_ASSET_FAIL\n" + "\n".join(failures))

    def archive(name: str, files: list[Path]) -> None:
        with zipfile.ZipFile(STORE / name, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as target:
            for path in sorted(files):
                target.write(path, path.relative_to(STORE).as_posix())
        with zipfile.ZipFile(STORE / name) as target:
            if target.testzip() is not None:
                raise SystemExit(f"Archive CRC failure: {name}")

    archive("achievement-icons.zip", [STORE / r["file"] for r in uploads if r["role"] in ["achievements", "pending_achievements"]])
    archive("leaderboard-icons.zip", [STORE / r["file"] for r in uploads if r["role"] in ["leaderboards", "pending_leaderboards"]])
    upload_paths = [STORE / record["file"] for record in uploads]
    upload_paths += [STORE / "README.md", STORE / "upload_manifest.json", STORE / "validation.json",
                     STORE / "icons/icon_manifest.json", STORE / "screenshots/manifest.json",
                     STORE / "listing/short_description.txt", STORE / "listing/full_description.txt",
                     STORE / "listing/metadata.json", STORE / "branding/prompts.json"]
    upload_paths += [boss_manifest_path, STORE / "boss-achievements/README.md"]
    upload_paths += [production_manifest_path, STORE / "production-update/README.md"]
    upload_paths += [STORE / "screenshots/README.md"]
    archive("InfiniteSlash-PlayStore-assets.zip", upload_paths)
    print(f"STORE_ASSET_PASS: {len(uploads)} upload images ({len(set(hashes))} distinct; shared tablet captures intentional); {report['achievements']} achievement icons "
          f"({report['configured_achievements']} configured, {report['pending_achievements']} awaiting IDs), "
          f"{report['leaderboards']} board icons, {report['screenshots']} screenshots; text and archive checks pass.")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
