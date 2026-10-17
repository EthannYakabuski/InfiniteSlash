"""Build inspection-only contact sheets from original Creature Mixer exports."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "review"
OUT.mkdir(parents=True, exist_ok=True)
manifest = ROOT / "data" / "monsters.json"
if manifest.exists():
    files = [ROOT / m["texture"].removeprefix("res://") for m in json.loads(manifest.read_text(encoding="utf-8"))]
else:
    files = [ROOT / "Assets/Monsters/cinder_cheek.png", ROOT / "Assets/Monsters/hex_hat.png"]
    files += [ROOT / f"Assets/Monsters/mixer_{n:03}.png" for n in range(3, 101)]
font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 16)
for page in range((len(files) + 49) // 50):
    sheet = Image.new("RGB", (1400, 800), "#252939")
    draw = ImageDraw.Draw(sheet)
    for i, path in enumerate(files[page * 50:(page + 1) * 50]):
        image = Image.open(path).convert("RGBA")
        assert image.size == (768, 192), (path, image.size)
        tile = image.crop((0, 0, 192, 192)).resize((120, 120), Image.Resampling.NEAREST)
        x, y = (i % 10) * 140, (i // 10) * 160
        sheet.paste(tile, (x + 10, y + 6), tile)
        draw.text((x + 56, y + 135), f"{page * 50 + i + 1:03}", font=font, fill="white")
    sheet.save(OUT / f"monster_review_{page + 1}.png")
print(f"{len(files)} original exports have valid 768x192 dimensions. Built {(len(files)+49)//50} review sheets.")
