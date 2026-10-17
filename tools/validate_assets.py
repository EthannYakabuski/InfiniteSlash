"""Check the monster roster, original exports, and generated music deterministically."""
import hashlib
import json
import math
import re
import sys
import wave
from array import array
from collections import Counter
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
roster = json.loads((ROOT / "data/monsters.json").read_text(encoding="utf-8"))
assert len(roster) == 200, f"Expected200 generated monsters, got {len(roster)}"
assert len({m["id"] for m in roster}) == len(roster), "Duplicate monster identifiers"
assert len({m["texture"] for m in roster}) == len(roster), "Duplicate monster texture references"
legacy_baseline = ROOT / "output/review/production-mixer/original100_manifest.json"
assert roster[:100] == json.loads(legacy_baseline.read_text(encoding="utf-8")), "Original 100 roster entries changed"
roles = {"chaser", "skitter", "charger", "spitter", "fan", "orbiter", "tank", "splitter"}
checks, png_hashes, pixel_hashes = [], set(), set()
for index, monster in enumerate(roster):
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
    if index < 100:
        assert 20 <= monster["health"] <= 90
        assert 8 <= monster["damage"] <= 18
        assert 50 <= monster["speed"] <= 125
        assert 10 <= monster["score"] <= 60
    else:
        assert monster["role"] in {"glass_cannon", "tank", "volley"}
        assert monster["stage_min"] in {1, 30, 50}
        assert 20 <= monster["health"] <= 1800
        assert 8 <= monster["damage"] <= 70
        assert 45 <= monster["speed"] <= 250
        assert 15 <= monster["score"] <= 500
        if monster["role"] == "volley":
            assert monster["volley_count"] >= (9 if monster["stage_min"] >= 30 else 5)
        if index < 150:
            assert monster["stage_min"] == 30 and monster["stage_max"] == 49 and not monster["night_only"]
        else:
            assert monster["night_only"]
            assert "stage_max" not in monster
    assert monster["frames"] == 4 and monster["frame_size"] == [192, 192]
    ranged = monster["behavior"] in {"spitter", "fan", "orbiter"}
    assert (monster["shoot_interval"] > 0) == ranged
    assert (monster["bullet_speed"] > 0) == ranged
    checks.append({"id": monster["id"], "sha256": png_hash, "pixel_sha256": pixel_hash, "size": list(image.size), "animated": True})
original = ROOT / "Assets/Monsters/creature-sheet (2).png"
assert original.exists(), "Supplied original creature was removed"
assert hashlib.sha256(original.read_bytes()).hexdigest() not in png_hashes
export_proof = json.loads((ROOT / "output/review/production-mixer/exports.json").read_text(encoding="utf-8"))
assert export_proof.get("pass") and export_proof["scale"] == 8 and len(export_proof["downloads"]) == 100
proof_by_sequence = {item["index"]: item for item in export_proof["downloads"]}
for monster in roster[100:]:
    proof = proof_by_sequence[monster["export_sequence"]]
    assert proof["sha256"] == monster["sha256"]
    assert proof["named_target"] == monster["texture"].removeprefix("res://")
assert Counter(m["role"] for m in roster[100:150]) == {"glass_cannon":17,"tank":17,"volley":16}
assert Counter(m["stage_min"] for m in roster[150:]) == {1:20,30:20,50:10}
# Every atlas strip must match its own untouched source, including original last.
atlas = Image.open(ROOT / "Assets/Generated/monster_atlas.png").convert("RGBA")
assert atlas.size == (960, 24 * math.ceil((len(roster)+1)/10))
for index, path in enumerate([ROOT/m["texture"].removeprefix("res://") for m in roster]+[original]):
    source = Image.open(path).convert("RGBA").resize((96,24), Image.Resampling.NEAREST)
    x,y = (index%10)*96,(index//10)*24
    assert atlas.crop((x,y,x+96,y+24)).tobytes() == source.tobytes(), f"Atlas mismatch at{index}:{path.name}"
# Rendering now uses the supplied packed tile sheets. Only cached/used Town
# regions are interchangeable with the individual files (some unused tiles in
# that supplied pack differ), so verify every actual runtime cache declaration.
world_source = (ROOT / "scripts/world.gd").read_text(encoding="utf-8")
world_atlas_regions = {}
for indices, pack in re.findall(r'for index in \[([^\]]+)\]:\s+_cache\("(town|farm)", index\)', world_source):
    used = [int(index.strip()) for index in indices.split(",")]
    folder = ROOT / "Assets" / ("Town" if pack == "town" else "Farm")
    packed = Image.open(folder / "Tilemap/tilemap_packed.png").convert("RGBA")
    assert packed.size == (192,176), f"Unexpected {pack} packed atlas size"
    for index in used:
        source = Image.open(folder / f"Tiles/tile_{index:04}.png").convert("RGBA")
        x,y = (index%12)*16,(index//12)*16
        assert packed.crop((x,y,x+16,y+16)).tobytes() == source.tobytes(), f"Packed {pack} tile {index} differs from original"
    world_atlas_regions[pack] = used
assert set(world_atlas_regions) == {"town","farm"}, "World cache declarations must expose both tile packs for validation"
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
report = {"pass": True, "generated_monsters": len(roster), "unique_pngs": len(png_hashes), "unique_pixel_sheets": len(pixel_hashes), "original_preserved": True, "stage2_monsters":50,"night_only_monsters":50,"atlas_size":list(atlas.size),"atlas_strips_verified":len(roster)+1,"world_packed_tiles_verified":sum(len(indices) for indices in world_atlas_regions.values()),"world_packed_regions":world_atlas_regions,"roles": dict(Counter(m["behavior"] for m in roster)), "music": music_summary, "monsters": checks}
(ROOT / "output/review").mkdir(parents=True, exist_ok=True)
(ROOT / "output/review/asset_validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({key: value for key, value in report.items() if key != "monsters"}, indent=2))
