"""Validate upload screenshots and create visual-review sheets, without editing frames."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageStat

PROJECT = Path(__file__).resolve().parents[1]
SCREENSHOTS = PROJECT / "store" / "screenshots"
REVIEW = PROJECT / "output" / "review" / "store-captures"
EXPECTED = {"phone": (540, 960), "tablet_7": (1080, 1920), "tablet_10": (1080, 1920)}
MAX_BYTES = 8 * 1024 * 1024


def main() -> None:
    manifest_path = SCREENSHOTS / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    records = {entry["file"]: entry for entry in manifest["screenshots"]}
    failures = []
    checked = []
    REVIEW.mkdir(parents=True, exist_ok=True)
    font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 16)
    title_font = ImageFont.truetype("C:/Windows/Fonts/segoeuib.ttf", 21)
    source_hashes = {
        path: hashlib.sha256((PROJECT / path).read_bytes()).hexdigest()
        for path in ["scripts/game.gd", "scripts/game_ui.gd", "scripts/world.gd", "scripts/class_profiles.gd", "tests/capture_production.gd", "tools/promote_production_screenshots.py"]
    }
    for category, dimensions in EXPECTED.items():
        images = sorted((SCREENSHOTS / category).glob("*.png"))
        if len(images) != 8:
            failures.append(f"{category}: expected 8 screenshots, found {len(images)}")
        pixel_hashes = set()
        sheet = Image.new("RGB", (1140, 1090), "#19252a")
        draw = ImageDraw.Draw(sheet)
        draw.text((18, 10), f"InfiniteSlash — {category} — {dimensions[0]} × {dimensions[1]}", font=title_font, fill="#fff2d3")
        for index, path in enumerate(images):
            with Image.open(path) as image:
                image.load()
                data = path.read_bytes()
                relative = path.relative_to(PROJECT).as_posix()
                if image.size != dimensions:
                    failures.append(f"{relative}: unexpected size {image.size}")
                if image.width * 16 != image.height * 9:
                    failures.append(f"{relative}: not 9:16")
                minimum, maximum = (1080, 7680) if category == "tablet_10" else (320, 3840)
                if not all(minimum <= side <= maximum for side in image.size):
                    failures.append(f"{relative}: dimensions outside upload bounds")
                if image.mode != "RGB":
                    failures.append(f"{relative}: expected 24-bit RGB without alpha, found {image.mode}")
                if len(data) > MAX_BYTES:
                    failures.append(f"{relative}: exceeds 8 MiB")
                if not relative in records:
                    failures.append(f"{relative}: missing capture provenance")
                stat = ImageStat.Stat(image)
                if max(stat.var) < 100:
                    failures.append(f"{relative}: image appears blank or nearly flat")
                pixel_hash = hashlib.sha256(image.tobytes()).hexdigest()
                source = PROJECT / records[relative]["source_capture"]
                if hashlib.sha256(source.read_bytes()).hexdigest() != records[relative]["source_sha256"]:
                    failures.append(f"{relative}: preserved source hash changed")
                with Image.open(source) as original:
                    if original.mode == "RGBA" and original.getchannel("A").getextrema() != (255, 255):
                        failures.append(f"{relative}: source alpha was not fully opaque")
                    if original.size != image.size or hashlib.sha256(original.convert("RGB").tobytes()).hexdigest() != pixel_hash:
                        failures.append(f"{relative}: rendered source RGB pixels changed")
                if records[relative]["source_rgb_pixel_sha256"] != pixel_hash:
                    failures.append(f"{relative}: recorded source RGB hash mismatch")
                if pixel_hash in pixel_hashes:
                    failures.append(f"{relative}: duplicate image in category")
                pixel_hashes.add(pixel_hash)
                report = {
                    "file": relative, "width": image.width, "height": image.height,
                    "mode": image.mode, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
                    "pixel_sha256": pixel_hash,
                }
                records[relative].update(report)
                checked.append(report)
                thumbnail = image.copy()
                thumbnail.thumbnail((270, 480), Image.Resampling.LANCZOS)
                x, y = 18 + index % 4 * 282, 50 + index // 4 * 514
                sheet.paste(thumbnail, (x, y))
                draw.text((x, y + 483), path.stem.replace("_", " "), font=font, fill="#ffd77a")
        sheet.save(REVIEW / f"{category}_contact_sheet.png")
    report = {"passed": not failures, "count": len(checked), "failures": failures, "files": checked, "source_sha256": source_hashes}
    (REVIEW / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    manifest["source_sha256"] = source_hashes
    manifest["screenshots"] = list(records.values())
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    if failures:
        raise SystemExit("SCREENSHOT_VALIDATION_FAIL\n" + "\n".join(failures))
    print(f"SCREENSHOT_VALIDATION_PASS: {len(checked)} RGB PNGs, eight distinct views per category, correct dimensions/9:16/bounds, under 8 MiB, rendered source pixels verified; tablet categories intentionally share frames")


if __name__ == "__main__":
    main()
