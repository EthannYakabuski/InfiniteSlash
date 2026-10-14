"""Check upload deliverables and package them; does not modify any image pixels."""
from __future__ import annotations

import hashlib
import json
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
    expected_achievement_keys = {k for k, v in config["achievements"].items() if v}
    expected_board_keys = {k for k, v in config["leaderboards"].items() if v}
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

    categories = {"phone": (1080, 1920), "tablet_7": (1440, 2560), "tablet_10": (2160, 3840)}
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
    if len(hashes) != len(set(hashes)):
        failures.append("Duplicate upload images")
    descriptions = {}
    for name, limit in [("short_description", 80), ("full_description", 4000)]:
        text = (STORE / f"listing/{name}.txt").read_text(encoding="utf-8").strip()
        descriptions[name] = {"characters": len(text), "limit": limit}
        if not text or len(text) > limit:
            failures.append(f"{name}: empty or exceeds limit")
    metadata = json.loads((STORE / "listing/metadata.json").read_text(encoding="utf-8"))
    if metadata["package_name"] != "com.slash.game" or len(metadata["recommended_tags"]) != 5:
        failures.append("Listing package or tag count is incorrect")
    if len({r["google_id"] for r in uploads if "google_id" in r}) != 15:
        failures.append("Expected 15 unique Google feature IDs")
    report = {"passed": not failures, "failures": failures, "image_count": len(uploads),
              "achievements": len(expected_achievement_keys), "leaderboards": len(expected_board_keys),
              "screenshots": len(shots), "description_lengths": descriptions,
              "all_image_bytes": sum(r["bytes"] for r in uploads)}
    (STORE / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    manifest = {"package_name": "com.slash.game", "pgs_game_id": config["game_id"],
                "listing": metadata, "descriptions": descriptions, "images": uploads,
                "upload_note": "Attach feature icons to the existing Google IDs. Do not re-import achievement definitions."}
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

    archive("achievement-icons.zip", list((STORE / "icons/achievements").glob("*.png")))
    archive("leaderboard-icons.zip", list((STORE / "icons/leaderboards").glob("*.png")))
    upload_paths = [STORE / record["file"] for record in uploads]
    upload_paths += [STORE / "README.md", STORE / "upload_manifest.json", STORE / "validation.json",
                     STORE / "icons/icon_manifest.json", STORE / "screenshots/manifest.json",
                     STORE / "listing/short_description.txt", STORE / "listing/full_description.txt",
                     STORE / "listing/metadata.json", STORE / "branding/prompts.json"]
    archive("InfiniteSlash-PlayStore-assets.zip", upload_paths)
    print(f"STORE_ASSET_PASS: {len(uploads)} unique upload images; 12 achievement icons, 3 board icons, 24 screenshots; text and archive checks pass.")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
