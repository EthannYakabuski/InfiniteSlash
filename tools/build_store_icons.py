"""Build the store's pixel-art medal family from existing game artwork.

The original sprites remain untouched. This composes small, code-native medals,
glyphs and existing sprite crops on a 128-pixel canvas, then scales with nearest
neighbour sampling. Run with Python and Pillow from the project directory.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "store" / "icons"
S = 128
P = {
    "ink": "#101a29", "navy": "#142536", "teal": "#255564",
    "teal_light": "#58b5bc", "gold": "#f3b951", "gold_light": "#ffe4a1",
    "gold_shadow": "#a56538", "cream": "#fff2d2", "coral": "#ee615f",
    "cherry": "#953e51", "blue": "#54728e", "silver": "#a7b9d1",
    "slate": "#60728f", "purple": "#665580", "green": "#88c288",
}

ACHIEVEMENTS = [
    ("first_blood", "First Slice", "Defeat your first creature", "Standard", None, "CgkI5NXU8p0YEAIQBA"),
    ("boss_slayer", "Crown Collector", "Defeat your first boss", "Standard", None, "CgkI5NXU8p0YEAIQBQ"),
    ("century", "A Hundred Little Problems", "Defeat 100 creatures across completed runs", "Incremental", 100, "CgkI5NXU8p0YEAIQBg"),
    ("hundred_club", "A Hundred in a Hurry", "Defeat 100 creatures in one completed run", "Standard", None, "CgkI5NXU8p0YEAIQBw"),
    ("survivor_60", "Minute Knight", "Complete a run lasting at least 60 seconds", "Standard", None, "CgkI5NXU8p0YEAIQCA"),
    ("survivor", "Still Standing", "Complete a run lasting at least 180 seconds", "Standard", None, "CgkI5NXU8p0YEAIQCQ"),
    ("legend", "Knight of Infinite Nonsense", "Defeat five bosses in one run", "Standard", None, "CgkI5NXU8p0YEAIQCg"),
    ("combo_25", "Slice Streak", "Reach a 25-kill combo", "Standard", None, "CgkI5NXU8p0YEAIQCw"),
    ("score_10000", "Five Digits of Slop", "Reach 10000 points in one run", "Standard", None, "CgkI5NXU8p0YEAIQDA"),
    ("collector", "Bestiary Pioneer", "Defeat 100 different creature species across your runs", "Incremental", 100, "CgkI5NXU8p0YEAIQDQ"),
    ("thousand_kills", "Slop Sweeper", "Defeat 1000 creatures across completed runs", "Incremental", 1000, "CgkI5NXU8p0YEAIQDg"),
    ("ten_runs", "Back for More", "Complete ten runs", "Incremental", 10, "CgkI5NXU8p0YEAIQDw"),
]
BOARDS = [
    ("high_score", "Endless Glory", "Best completed-run score", "Numeric", None, "CgkI5NXU8p0YEAIQAQ"),
    ("longest_run", "Last Knight Standing", "Best completed-run duration in whole seconds", "Numeric", None, "CgkI5NXU8p0YEAIQAg"),
    ("bosses_in_run", "Crown Hoarder", "Most bosses in one completed run", "Numeric", None, "CgkI5NXU8p0YEAIQAw"),
]


def poly(d, points, fill, outline=P["ink"], width=2):
    d.polygon(points, fill=fill)
    if outline:
        d.line(points + [points[0]], fill=outline, width=width, joint="curve")


def sparkle(d, x, y, r=4, color=P["cream"]):
    poly(d, [(x, y-r), (x+1, y-1), (x+r, y), (x+1, y+1),
             (x, y+r), (x-1, y+1), (x-r, y), (x-1, y-1)], color, None)


def badge(theme="teal"):
    im = Image.new("RGBA", (S, S), P["ink"])
    d = ImageDraw.Draw(im)
    # The outer corners are decorative only; every subject stays inside radius46.
    for y in range(S):
        d.line((0, y, S, y), fill=(14+y//24, 24+y//18, 38+y//18))
    d.ellipse((5, 7, 123, 125), fill="#080e1c")
    d.ellipse((6, 5, 122, 121), fill=P["gold_shadow"])
    d.ellipse((7, 4, 121, 118), fill=P["gold"])
    d.ellipse((11, 8, 117, 114), fill=P["gold_light"])
    d.ellipse((12, 10, 116, 115), fill=P["navy"])
    d.ellipse((16, 14, 112, 110), fill=P[theme])
    d.ellipse((19, 17, 109, 108), fill=P["navy"])
    d.ellipse((22, 21, 106, 106), fill={
        "teal": "#213f4b", "cherry": "#3e293b", "purple": "#302e49",
        "blue": "#253c52", "green": "#243e3c"}.get(theme, "#213f4b"))
    # Tiny square runes are non-linguistic trim and never part of the subject.
    for angle in range(0, 360, 45):
        x = round(64+53*math.cos(math.radians(angle)))
        y = round(61+53*math.sin(math.radians(angle)))
        d.rectangle((x-1, y-1, x+1, y+1), fill=P["cream"])
    d.arc((8, 5, 120, 119), 203, 287, fill=P["cream"], width=2)
    for x, y in [(31, 34), (92, 31), (26, 74), (99, 76), (37, 94), (87, 96)]:
        d.rectangle((x, y, x+1, y+1), fill=P[theme])
    return im


def sprite_frame(path, cell=(0, 0, 192, 192), pixels=None):
    im = Image.open(ROOT / path).convert("RGBA").crop(cell)
    # Crop by the opaque sprite rather than the generated sheet's soft aura.
    bounds = im.getchannel("A").point(lambda a: 255 if a >= 190 else 0).getbbox()
    if bounds:
        im = im.crop(bounds)
    if pixels:
        w, h = im.size
        im = im.resize((max(1, round(w*pixels/h)), pixels), Image.Resampling.NEAREST)
    return im


def stamp(im, sprite, cx, cy, height, rotation=0, flip=False):
    w, h = sprite.size
    sp = sprite.resize((max(1, round(w*height/h)), height), Image.Resampling.NEAREST)
    if flip:
        sp = ImageOps.mirror(sp)
    if rotation:
        sp = sp.rotate(rotation, resample=Image.Resampling.NEAREST, expand=True)
    im.alpha_composite(sp, (round(cx-sp.width/2), round(cy-sp.height/2)))


def crown(d, x, y, w=52, h=29, color=P["gold"], gem=P["coral"]):
    pts = [(x-w//2, y-h//3), (x-w//2+4, y+h//2), (x+w//2-4, y+h//2),
           (x+w//2, y-h//3), (x+w//4, y-1), (x, y-h//2), (x-w//4, y-1)]
    poly(d, pts, color, width=3 if w>40 else 2)
    d.line((x-w//2+7, y+h//2-4, x+w//2-7, y+h//2-4), fill=P["gold_shadow"], width=3)
    d.line((x-w//2+5, y+h//2-7, x+w//2-5, y+h//2-7), fill=P["cream"], width=2)
    poly(d, [(x, y-1), (x+4, y+3), (x, y+7), (x-4, y+3)], gem, None)
    for ox in [-w//2, 0, w//2]:
        d.rectangle((x+ox-2, y-h//2-2, x+ox+2, y-h//2+2), fill=P["gold_light"])


def laurel(d, color=P["gold"], offset=0):
    for side in [-1, 1]:
        d.line([(64+side*20, 99+offset), (64+side*33, 87),
                (64+side*42, 69), (64+side*42, 49)], fill=P["gold_shadow"], width=3)
        for i, (dx, y) in enumerate([(27, 91), (35, 82), (40, 71), (42, 58)]):
            x = 64+side*dx
            poly(d, [(x, y+3), (x+side*6, y-1), (x+side*4, y-9), (x-side*3, y-2)], color, None)


def banner(d, y=98, color=P["cherry"]):
    poly(d, [(31, y-3), (97, y-3), (92, y+7), (36, y+7)], color)
    d.line((38, y, 90, y), fill=P["coral"] if color==P["cherry"] else P["gold_light"], width=2)


def coin(d, x, y, r=10):
    d.ellipse((x-r, y-r, x+r, y+r), fill=P["ink"])
    d.ellipse((x-r+2, y-r+2, x+r-2, y+r-2), fill=P["gold_shadow"])
    d.ellipse((x-r+2, y-r+1, x+r-2, y+r-3), fill=P["gold"])
    d.arc((x-r+4, y-r+3, x+r-4, y+r-5), 180, 285, fill=P["cream"], width=2)
    d.rectangle((x-1, y-r+5, x+1, y+r-5), fill=P["gold_light"])


def hourglass(d, x=64, y=62, w=42, h=60, sand=P["gold"]):
    l, r, top, bottom = x-w//2, x+w//2, y-h//2, y+h//2
    poly(d, [(l+7, top+6), (r-7, top+6), (r-10, y-11), (x+4, y),
             (r-10, y+11), (r-7, bottom-6), (l+7, bottom-6),
             (l+10, y+11), (x-4, y), (l+10, y-11)], P["silver"], width=3)
    poly(d, [(l+11, top+13), (r-11, top+13), (x, y-3)], sand, None)
    poly(d, [(l+11, bottom-10), (r-11, bottom-10), (x, y+10)], sand, None)
    d.rectangle((x-1, y-3, x+1, y+8), fill=P["cream"])
    for xx in [l+1, r-4]:
        d.rectangle((xx, top, xx+4, bottom), fill=P["gold_shadow"])
        d.line((xx+1, top+5, xx+1, bottom-5), fill=P["gold"], width=2)
    for yy in [top-1, bottom-5]:
        d.rectangle((l-2, yy, r+2, yy+6), fill=P["ink"])
        d.rectangle((l, yy, r, yy+4), fill=P["gold"])
        d.line((l+3, yy, r-3, yy), fill=P["cream"], width=2)


def clock(d, x=64, y=60, r=32):
    d.ellipse((x-r-3, y-r-3, x+r+3, y+r+3), fill=P["ink"])
    d.ellipse((x-r, y-r, x+r, y+r), fill=P["silver"])
    d.ellipse((x-r+4, y-r+4, x+r-4, y+r-4), fill=P["cream"])
    for angle in range(0, 360, 30):
        a = math.radians(angle)
        x1, y1 = round(x+(r-8)*math.cos(a)), round(y+(r-8)*math.sin(a))
        x2, y2 = round(x+(r-12)*math.cos(a)), round(y+(r-12)*math.sin(a))
        d.line((x1, y1, x2, y2), fill=P["slate"], width=2)
    d.line((x, y, x, y-18), fill=P["navy"], width=4)
    d.line((x, y, x+14, y+7), fill=P["navy"], width=4)
    d.rectangle((x-2, y-2, x+2, y+2), fill=P["coral"])


HERO = sprite_frame("Assets/Generated/knight_sheet.png", (0, 0, 512, 512), 48)
SWORD = sprite_frame("Assets/Generated/knight_sheet.png", (0, 1024, 512, 1536), 56)
SHIELD = sprite_frame("Assets/Generated/knight_sheet.png", (512, 1024, 1024, 1536), 40)
MONSTER_NAMES = ["cinder_cheek", "hex_hat", "moss_muzzle", "prism_hex", "mint_munch"]
MONSTERS = [sprite_frame("Assets/Monsters/"+name+".png", pixels=24)
            for name in MONSTER_NAMES]
BOSS = sprite_frame("Assets/Monsters/creature-sheet (2).png", pixels=24)


def make_icon(key):
    themes = {"first_blood":"cherry", "boss_slayer":"purple", "century":"green",
              "hundred_club":"cherry", "survivor_60":"blue", "survivor":"teal",
              "legend":"purple", "combo_25":"cherry", "score_10000":"blue",
              "collector":"teal", "thousand_kills":"green", "ten_runs":"teal",
              "high_score":"purple", "longest_run":"blue", "bosses_in_run":"cherry"}
    im = badge(themes[key])
    d = ImageDraw.Draw(im)
    if key == "first_blood":
        poly(d, [(35, 91), (43, 99), (99, 39), (92, 32)], P["cherry"], None)
        stamp(im, MONSTERS[0], 52, 73, 43)
        stamp(im, SWORD, 74, 58, 77, -34)
        sparkle(d, 88, 34, 5)
        sparkle(d, 39, 46, 4, P["coral"])
    elif key == "boss_slayer":
        laurel(d, P["purple"])
        stamp(im, BOSS, 64, 73, 48)
        crown(d, 64, 40, 60, 31)
        sparkle(d, 30, 50, 4)
        sparkle(d, 98, 52, 4)
    elif key == "century":
        stamp(im, MONSTERS[1], 64, 43, 31)
        stamp(im, MONSTERS[2], 44, 67, 37)
        stamp(im, MONSTERS[0], 82, 67, 37)
        coin(d, 53, 93, 10)
        coin(d, 76, 93, 10)
        sparkle(d, 32, 39, 4, P["green"])
        sparkle(d, 95, 40, 4)
    elif key == "hundred_club":
        stamp(im, SWORD, 48, 61, 72, -34)
        stamp(im, SWORD, 80, 61, 72, 34, True)
        stamp(im, MONSTERS[0], 64, 74, 42)
        banner(d, 99)
        sparkle(d, 64, 30, 5, P["gold_light"])
    elif key == "survivor_60":
        clock(d, 64, 56, 30)
        stamp(im, SHIELD, 64, 89, 26)
        sparkle(d, 28, 81, 4, P["teal_light"])
        sparkle(d, 101, 81, 4)
    elif key == "survivor":
        stamp(im, SHIELD, 64, 64, 75)
        hourglass(d, 64, 61, 37, 57)
        sparkle(d, 31, 41, 4, P["teal_light"])
        sparkle(d, 96, 89, 4)
    elif key == "legend":
        laurel(d)
        stamp(im, HERO, 64, 69, 68)
        crown(d, 64, 32, 34, 18)
        for x,y in [(31, 51), (97, 51), (37, 81), (91, 81)]:
            crown(d, x, y, 16, 11, P["gold"], P["teal_light"])
        sparkle(d, 64, 18, 3)
    elif key == "combo_25":
        d.arc((25, 27, 105, 104), 20, 282, fill=P["cherry"], width=13)
        d.arc((28, 26, 103, 101), 22, 274, fill=P["coral"], width=7)
        d.arc((32, 27, 101, 97), 30, 264, fill=P["gold"], width=3)
        stamp(im, SWORD, 65, 65, 77, -37)
        for x,y in [(94, 87), (86, 94), (76, 99)]:
            sparkle(d, x, y, 3, P["cream"])
    elif key == "score_10000":
        for x,y,r in [(34, 49, 10), (94, 56, 11), (39, 86, 11), (86, 91, 10)]:
            coin(d, x, y, r)
        poly(d, [(64, 27), (82, 45), (75, 75), (64, 91), (51, 76), (45, 46)], P["teal_light"], width=3)
        poly(d, [(64, 29), (62, 48), (75, 75), (82, 45)], "#97e6d3", None)
        poly(d, [(46, 46), (62, 48), (64, 90), (51, 76)], "#367e91", None)
        d.line([(64, 29), (62, 48), (75, 75)], fill=P["cream"], width=3)
        sparkle(d, 32, 29, 4)
        sparkle(d, 98, 30, 4, P["gold_light"])
    elif key == "collector":
        poly(d, [(25, 43), (59, 46), (64, 51), (71, 46), (103, 43), (104, 93),
                 (73, 96), (64, 101), (55, 96), (24, 93)], P["gold_shadow"], width=3)
        poly(d, [(27, 41), (58, 44), (64, 49), (64, 94), (56, 90), (27, 87)], P["cream"])
        poly(d, [(64, 49), (71, 44), (101, 41), (101, 87), (72, 90), (64, 94)], "#ebd6ab")
        d.line((64, 51, 64, 91), fill=P["gold_shadow"], width=2)
        stamp(im, MONSTERS[2], 43, 64, 26)
        stamp(im, MONSTERS[0], 83, 64, 26)
        stamp(im, MONSTERS[1], 64, 32, 27)
        for x in [33, 74]:
            d.line((x, 82, x+17, 82), fill=P["gold_shadow"], width=2)
        poly(d, [(68, 92), (75, 92), (75, 105), (71, 102), (68, 105)], P["coral"], None)
    elif key == "thousand_kills":
        laurel(d)
        for x,y,i,h in [(41,45,1,24),(63,37,2,26),(84,45,3,24),
                         (36,68,4,27),(88,68,1,27),(47,90,2,25),(79,90,4,25)]:
            stamp(im, MONSTERS[i], x, y, h)
        stamp(im, MONSTERS[0], 64, 67, 43)
        sparkle(d, 64, 99, 3, P["gold_light"])
    elif key == "ten_runs":
        d.arc((23, 21, 105, 103), 32, 318, fill=P["ink"], width=12)
        d.arc((23, 19, 105, 101), 32, 318, fill=P["gold"], width=8)
        poly(d, [(105, 29), (104, 49), (85, 36)], P["gold"], width=2)
        stamp(im, HERO, 63, 69, 55)
        sparkle(d, 30, 77, 3, P["teal_light"])
    elif key == "high_score":
        laurel(d)
        d.arc((22, 39, 53, 72), 75, 285, fill=P["gold_shadow"], width=7)
        d.arc((76, 39, 107, 72), -105, 105, fill=P["gold_shadow"], width=7)
        d.arc((24, 37, 52, 69), 75, 285, fill=P["gold"], width=4)
        d.arc((77, 37, 105, 69), -105, 105, fill=P["gold"], width=4)
        poly(d, [(40, 36), (88, 36), (84, 64), (73, 77), (55, 77), (44, 64)], P["gold"], width=3)
        poly(d, [(43, 39), (61, 39), (61, 73), (53, 67), (47, 59)], P["gold_light"], None)
        d.rectangle((59, 77, 69, 91), fill=P["gold_shadow"])
        d.rectangle((60, 76, 65, 89), fill=P["gold"])
        poly(d, [(46, 90), (82, 90), (87, 100), (41, 100)], P["gold"], width=3)
        poly(d, [(64, 47), (72, 55), (64, 64), (56, 55)], P["coral"], width=2)
        crown(d, 64, 29, 28, 15)
        sparkle(d, 96, 32, 4)
    elif key == "longest_run":
        laurel(d, P["teal_light"])
        poly(d, [(41, 96), (49, 104), (63, 98), (76, 104), (87, 96), (81, 89), (47, 89)], P["blue"])
        hourglass(d, 64, 60, 49, 70, P["gold_light"])
        sparkle(d, 29, 38, 4)
        sparkle(d, 100, 82, 4, P["teal_light"])
    elif key == "bosses_in_run":
        stamp(im, BOSS, 64, 84, 34)
        crown(d, 39, 57, 33, 23, P["silver"], P["teal_light"])
        crown(d, 89, 57, 33, 23, P["coral"], P["gold_light"])
        crown(d, 64, 37, 47, 28)
        sparkle(d, 28, 86, 4, P["gold_light"])
        sparkle(d, 101, 86, 4, P["gold_light"])
    return im.convert("RGB").resize((512, 512), Image.Resampling.NEAREST)


def font(size):
    for path in ["C:/Windows/Fonts/arial.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def previews(items):
    directory = OUT / "previews"
    directory.mkdir(parents=True, exist_ok=True)
    for tile_size, gap, label_h, file_name in [(512, 12, 46, "contact_sheet_512.png"),
                                             (64, 52, 44, "contact_sheet_64.png")]:
        cw, ch = tile_size+gap, tile_size+label_h+gap
        canvas = Image.new("RGB", (cw*5+gap, ch*3+gap), P["ink"])
        d = ImageDraw.Draw(canvas)
        f = font(20 if tile_size==512 else 11)
        for i,item in enumerate(items):
            x,y = gap+(i%5)*cw, gap+(i//5)*ch
            pic = Image.open(ROOT / item["relative_path"])
            pic = pic.resize((tile_size, tile_size), Image.Resampling.NEAREST)
            canvas.paste(pic, (x,y))
            label = item["key"]
            d.text((x,y+tile_size+5), label, fill=P["cream"], font=f)
            if tile_size==512:
                d.text((x,y+tile_size+27), item["title"], fill=P["gold_light"], font=font(16))
        canvas.save(directory / file_name, optimize=True)


def main():
    items = []
    for category, definitions in [("achievements", ACHIEVEMENTS), ("leaderboards", BOARDS)]:
        directory = OUT / category
        directory.mkdir(parents=True, exist_ok=True)
        for key,title,criterion,kind,steps,google_id in definitions:
            target = directory / f"{key}.png"
            make_icon(key).save(target, format="PNG", optimize=True)
            byte_size = target.stat().st_size
            assert byte_size < 1_000_000, target
            items.append({"category":category, "key":key, "google_id":google_id,
                          "title":title, "criterion":criterion, "type":kind,
                          "steps":steps, "filename":target.name,
                          "relative_path":target.relative_to(ROOT).as_posix(),
                          "dimensions":[512,512], "format":"PNG", "mode":"RGB",
                          "bytes":byte_size, "sha256":hashlib.sha256(target.read_bytes()).hexdigest(),
                          "localized_text":False, "subject_circle_safe":True})
    manifest = {"schema_version":1, "style":"Existing game sprites and code-native pixel medal compositions",
                "created_from":["Assets/Generated/knight_sheet.png",
                                *["Assets/Monsters/"+name+".png" for name in MONSTER_NAMES],
                                "Assets/Monsters/creature-sheet (2).png"],
                "generator":"tools/build_store_icons.py", "icons":items,
                "previews":{"at_64_pixels":"store/icons/previews/contact_sheet_64.png",
                            "at_512_pixels":"store/icons/previews/contact_sheet_512.png"}}
    (OUT / "icon_manifest.json").write_text(json.dumps(manifest, indent=2)+"\n", "utf-8")
    previews(items)
    print(json.dumps({"created":len(items), "maximum_bytes":max(i["bytes"] for i in items),
                      "manifest":str(OUT / "icon_manifest.json")}, indent=2))


if __name__ == "__main__":
    main()
