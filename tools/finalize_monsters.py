"""Name reviewed Creature Mixer exports and build the playable roster.

All source PNGs were exported through the real browser Randomize and Save
spritesheet controls at 8x. This script never generates or alters their pixels.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
MONSTERS = ROOT / "Assets" / "Monsters"
OUT = ROOT / "output" / "review"
OUT.mkdir(parents=True, exist_ok=True)
manifest = ROOT / "data" / "monsters.json"
if manifest.exists() and len(json.loads(manifest.read_text(encoding="utf-8"))) > 100:
    raise SystemExit("This historical first100finalizer must not overwrite the expanded roster. Use finalize_production_monsters.py for the expansion.")

# Each name and combat role was chosen after inspecting the first animation
# frame on monster_review_1.png and monster_review_2.png.
REVIEWED = """
Cinder Cheek|chaser
Hex Hat|fan
Moss Muzzle|tank
Prism Hex|spitter
Mint Munch|chaser
Ember Earl|charger
Moon Mallow|orbiter
Tin Tusk|tank
Amber Imp|skitter
Slate Squid|spitter
Fern Fang|chaser
Bog Boulder|tank
Cherry Gnash|splitter
Copper Cap|spitter
Butter Gob|skitter
Mulberry Bat|orbiter
Ruby Jester|charger
Ghost Wisp|fan
Void Candle|spitter
Bluebell Bandit|skitter
Branch Biter|charger
Sun Puff|splitter
Iron Muffin|tank
Cocoa Snout|chaser
Azure Baron|orbiter
Honey Lump|chaser
Carrot Cavalier|charger
Night Pebble|tank
Pepper Pixie|splitter
Sprout Sprite|skitter
Pumpkin Helm|tank
Thistle Totem|fan
Copper Troll|tank
Soot Gargoyle|charger
Lavender Gremlin|skitter
Dusk Hare|splitter
Bone Bonnet|spitter
Mint Brute|charger
Orchid Ooze|splitter
Lemon Lancer|chaser
River Imp|orbiter
Cloud Crown|fan
Jam Juggernaut|tank
Ivory Imp|skitter
Indigo Fang|charger
Velvet Visor|spitter
Cream Cap|chaser
Scarlet Whistle|spitter
Moss Moth|orbiter
Peach Ogre|tank
Frost Guard|tank
Acorn King|charger
Honey Yawn|splitter
Ash Bonnet|spitter
Mustard Maw|chaser
Gilded Goggle|fan
Ruby Rook|charger
Brick Beard|tank
Golden Gnome|spitter
Ember Bishop|fan
Cinder Sailor|orbiter
Ochre Orb|splitter
Marsh Mask|tank
Peach Wail|spitter
Pepper Guard|charger
Coal Imp|skitter
Apricot Elder|fan
Horned Husk|tank
Sleepy Squash|chaser
Azure Wraith|orbiter
Night Watch|spitter
Corn Husk|splitter
Violet Warden|fan
Lilac Hound|charger
Raincoat Rogue|orbiter
Grave Moth|skitter
Rose Rampart|tank
Clay Crawler|chaser
Crimson Duke|charger
Copper Wizard|fan
Moss Lantern|spitter
Jade Jester|skitter
Rose Granite|tank
Amethyst Earl|orbiter
Ochre Oracle|fan
Lime Royal|splitter
Emerald Gentleman|spitter
Dust Rabbit|skitter
Ember Hood|charger
Cobble Cub|tank
Chestnut Chimera|splitter
Sage Specter|orbiter
Amber Antlers|charger
Slate Scholar|spitter
Coal Cask|tank
Twig Terror|charger
Moss Minotaur|tank
Ruby Robin|skitter
Azure Antlers|fan
Iron Nibbler|chaser
""".strip().splitlines()

ROLES = {
    "chaser": (28, 9, 84, 14, 0.0, 0),
    "skitter": (22, 8, 112, 17, 0.0, 0),
    "charger": (44, 13, 89, 26, 0.0, 0),
    "spitter": (32, 10, 60, 25, 2.1, 142),
    "fan": (36, 9, 53, 30, 2.8, 118),
    "orbiter": (30, 10, 98, 28, 1.9, 132),
    "tank": (74, 16, 52, 46, 0.0, 0),
    "splitter": (40, 11, 78, 29, 0.0, 0),
}
TACTICS = {
    "chaser": "Melee pursuit; steadily closes on the knight.",
    "skitter": "Fast melee pursuit with a weaving approach.",
    "charger": "Melee burst charge after a readable windup.",
    "spitter": "Keeps distance and fires aimed single shots.",
    "fan": "Ranged fan volleys with gaps for a skilled dodge.",
    "orbiter": "Circles the knight while firing aimed shots.",
    "tank": "Slow armored melee threat with high health and damage.",
    "splitter": "Melee creature that splits into smaller offspring when slain.",
}

assert len(REVIEWED) == 100
roster = []
for number, line in enumerate(REVIEWED, 1):
    name, behavior = line.split("|")
    slug = name.lower().replace(" ", "_")
    source = MONSTERS / ("cinder_cheek.png" if number == 1 else "hex_hat.png" if number == 2 else f"mixer_{number:03}.png")
    target = MONSTERS / f"{slug}.png"
    if source != target and source.exists():
        assert not target.exists(), f"Refusing to overwrite {target}"
        assert source.resolve().parent == MONSTERS.resolve()
        assert target.resolve().parent == MONSTERS.resolve()
        source.rename(target)
    assert target.exists(), target
    raw = target.read_bytes()
    image = Image.open(target).convert("RGBA")
    assert image.size == (768, 192), (target, image.size)
    hp, damage, speed, score, interval, bullet_speed = ROLES[behavior]
    variation = number % 5
    roster.append({
        "id": slug,
        "name": name,
        "texture": f"res://Assets/Monsters/{slug}.png",
        "behavior": behavior,
        "attack_type": "ranged" if interval else "melee",
        "health": hp + variation * (4 if behavior == "tank" else 2),
        "damage": damage + number % 3,
        "speed": speed + variation * (2 if behavior == "tank" else 3),
        "score": score + variation * 2,
        "shoot_interval": round(interval - (variation * 0.05 if interval else 0), 2),
        "bullet_speed": bullet_speed + (variation * 3 if bullet_speed else 0),
        "radius": 21 if behavior == "tank" else 16,
        "tier": 1 + (number - 1) // 20,
        "description": TACTICS[behavior],
        "frames": 4,
        "frame_size": [192, 192],
        "animation_fps": 8,
        "generated": True,
        "source": "Kenney Creature Mixer v1.6.0; browser Randomize and Save spritesheet at 8x",
        "sha256": hashlib.sha256(raw).hexdigest(),
    })

assert len({m["id"] for m in roster}) == 100
assert len({m["sha256"] for m in roster}) == 100
original = MONSTERS / "creature-sheet (2).png"
assert hashlib.sha256(original.read_bytes()).hexdigest() not in {m["sha256"] for m in roster}
(ROOT / "data").mkdir(exist_ok=True)
(ROOT / "data" / "monsters.json").write_text(json.dumps(roster, indent=2) + "\n", encoding="utf-8")

font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 13)
heading = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 23)
sheet = Image.new("RGB", (1600, 1670), "#252939")
draw = ImageDraw.Draw(sheet)
draw.text((22, 14), "InfiniteSlash - 100 Creature Mixer monsters", font=heading, fill="#ffe8a6")
draw.text((22, 43), "4-frame animated sprites - all exported at 8x - every sheet has unique original pixels", font=font, fill="#c9d9e9")
for i, monster in enumerate(roster):
    image = Image.open(ROOT / monster["texture"].removeprefix("res://")).convert("RGBA")
    tile = image.crop((0, 0, 192, 192)).resize((112, 112), Image.Resampling.NEAREST)
    x, y = (i % 10) * 160, (i // 10) * 160 + 70
    sheet.paste(tile, (x + 24, y + 2), tile)
    text = f"{i + 1:03} {monster['name']}"
    draw.text((x + 8, y + 119), text, font=font, fill="white")
    draw.text((x + 8, y + 139), monster["behavior"], font=font, fill="#91c7c8")
sheet.save(OUT / "monster_roster.png")

lines = ["# Monster roster", "", "100 unique animated monsters were generated using Kenney Creature Mixer in the browser, with the full Randomize control and Save spritesheet at 8x. The supplied original sheet is preserved separately.", "", "Every sheet is 768 x 192 RGBA pixels, with four 192 x 192 frames. The game displays those frames with nearest-neighbor sampling.", "", "| # | Monster | Role | HP | Damage | Speed | Score |", "| --- | --- | --- | --- | --- | --- | --- |"]
for i, m in enumerate(roster, 1):
    lines.append(f"| {i} | {m['name']} | {m['behavior']} | {m['health']} | {m['damage']} | {m['speed']} | {m['score']} |")
lines += ["", "Ranged roles have individual shoot intervals and bullet speeds in `data/monsters.json`. Tanks trade movement speed for durability; chargers have readable windups; splitters create pressure after defeat. Final encounter pressure is controlled by the game's difficulty director.", "", "The export proof and full visual roster are saved in `output/review`. The exported pixels have not been regenerated or modified."]
(ROOT / "docs" / "MONSTER_ROSTER.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
print("PASS: 100 named monsters, 100 distinct hashes, 100 valid 768x192 RGBA sheets; original preserved.")
print("Manifest: data/monsters.json; visual review: output/review/monster_roster.png")
