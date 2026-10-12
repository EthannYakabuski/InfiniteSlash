"""Check the monster roster, original exports, and generated music deterministically."""
import hashlib
import json
import math
import sys
import wave
from array import array
from collections import Counter
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
roster = json.loads((ROOT / "data/monsters.json").read_text(encoding="utf-8"))
assert len(roster) == 100, f"Expected 100 generated monsters, got {len(roster)}"
assert len({m["id"] for m in roster}) == 100, "Duplicate monster identifiers"
assert len({m["texture"] for m in roster}) == 100, "Duplicate monster texture references"
roles = {"chaser", "skitter", "charger", "spitter", "fan", "orbiter", "tank", "splitter"}
checks, png_hashes, pixel_hashes = [], set(), set()
for monster in roster:
    path = ROOT / monster["texture"].removeprefix("res://")
    assert path.resolve().parent == (ROOT / "Assets/Monsters").resolve(), path
    assert path.exists(), f"Missing monster: {path}"
    image = Image.open(path)
    assert image.size == (768, 192), (path, image.size)
    assert image.mode == "RGBA", (path, image.mode)
    alpha = image.getchannel("A")
    assert alpha.getextrema() == (0, 255), f"Transparency missing: {path}"
    png_hash = hashlib.sha256(path.read_bytes()).hexdigest()
    pixel_hash = hashlib.sha256(image.tobytes()).hexdigest()
    assert png_hash == monster["sha256"], f"Export changed: {path}"
    assert png_hash not in png_hashes, f"Duplicate PNG: {path}"
    assert pixel_hash not in pixel_hashes, f"Duplicate creature pixels: {path}"
    png_hashes.add(png_hash)
    pixel_hashes.add(pixel_hash)
    frames = [image.crop((i * 192, 0, (i + 1) * 192, 192)).tobytes() for i in range(4)]
    assert len(set(frames)) >= 2, f"No animation variation: {path}"
    assert monster["behavior"] in roles
    assert 20 <= monster["health"] <= 90
    assert 8 <= monster["damage"] <= 18
    assert 50 <= monster["speed"] <= 125
    assert 10 <= monster["score"] <= 60
    assert monster["frames"] == 4 and monster["frame_size"] == [192, 192]
    ranged = monster["behavior"] in {"spitter", "fan", "orbiter"}
    assert (monster["shoot_interval"] > 0) == ranged
    assert (monster["bullet_speed"] > 0) == ranged
    checks.append({"id": monster["id"], "sha256": png_hash, "pixel_sha256": pixel_hash, "size": list(image.size), "animated": True})
original = ROOT / "Assets/Monsters/creature-sheet (2).png"
assert original.exists(), "Supplied original creature was removed"
assert hashlib.sha256(original.read_bytes()).hexdigest() not in png_hashes
music = ROOT / "Assets/Generated/music_loop.wav"
music_summary = None
if music.exists():
    with wave.open(str(music), "rb") as source:
        assert source.getnchannels() == 1
        assert source.getsampwidth() == 2
        assert source.getframerate() == 24000
        assert source.getnframes() == 768000
        samples = array("h", source.readframes(source.getnframes()))
        if sys.byteorder != "little":
            samples.byteswap()
        peak = max(abs(sample) for sample in samples) / 32767.0
        rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples)) / 32767.0
        seam = abs(samples[0] - samples[-1]) / 32767.0
        assert peak < 0.99, "Music clips"
        assert 0.03 < rms < 0.25, "Music has unexpected loudness or silence"
        assert seam < 0.002, "Music loop has an audible boundary step"
        music_summary = {"channels": 1, "sample_rate": 24000, "seconds": 32.0, "bytes": music.stat().st_size, "peak": peak, "rms": rms, "seam_step": seam}
report = {"pass": True, "generated_monsters": 100, "unique_pngs": len(png_hashes), "unique_pixel_sheets": len(pixel_hashes), "original_preserved": True, "roles": dict(Counter(m["behavior"] for m in roster)), "music": music_summary, "monsters": checks}
(ROOT / "output/review").mkdir(parents=True, exist_ok=True)
(ROOT / "output/review/asset_validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({key: value for key, value in report.items() if key != "monsters"}, indent=2))
