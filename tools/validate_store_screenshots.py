"""Validate upload screenshots and create visual-review sheets, without editing frames."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageStat

PROJECT = Path(__file__).resolve().parents[1]
SCREENSHOTS = PROJECT / "store" / "screenshots"
REVIEW = PROJECT / "output" / "review" / "store-captures"
EXPECTED = {"phone": (1080, 1920), "tablet_7": (1440, 2560), "tablet_10": (2160, 3840)}
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
        for path in ["scripts/game.gd", "scripts/game_ui.gd", "scripts/world.gd", "scripts/class_profiles.gd", "tools/capture_store.gd"]
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
    print(f"SCREENSHOT_VALIDATION_PASS: {len(checked)} unique RGB PNGs, correct dimensions/9:16/bounds, under 8 MiB, with capture provenance")


if __name__ == "__main__":
    main()
