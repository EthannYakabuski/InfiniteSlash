"""Append reviewed real Creature Mixer exports; preserve the first 100 and source pixels.

Names are chosen from inspection-only contact sheets. The atlas uses native 24px
cells; the downloaded 8x originals are never resaved or recolored.
"""
import hashlib
import json
import math
from collections import Counter
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/review/production-mixer'
MONSTERS=ROOT/'Assets/Monsters'
manifest=ROOT/'data/monsters.json'
roster=json.loads(manifest.read_text(encoding='utf-8'))
assert len(roster) in {100,200}, 'Unexpected roster count; refusing to rewrite'
legacy=roster[:100]
baseline=OUT/'original100_manifest.json'
if baseline.exists():
    assert json.loads(baseline.read_text(encoding='utf-8'))==legacy, 'First 100 entries changed'
else:
    baseline.write_text(json.dumps(legacy,indent=2)+'\n',encoding='utf-8')
names=json.loads((ROOT/'tools/production_monster_names.json').read_text(encoding='utf-8'))
assert len(names)==100 and len(set(names))==100
evidence=json.loads((OUT/'exports.json').read_text(encoding='utf-8'))
assert evidence.get('pass') and len(evidence['downloads'])==100
proof={entry['index']:entry for entry in evidence['downloads']}

BASE={
  1:{'glass_cannon':(32,13,130,32,0,0), 'tank':(145,19,55,60,0,0), 'volley':(60,12,68,48,2.3,150)},
  30:{'glass_cannon':(78,35,172,145,0,0), 'tank':(720,33,62,225,0,0), 'volley':(185,24,88,190,1.65,210)},
  50:{'glass_cannon':(150,55,220,310,0,0), 'tank':(1420,60,80,440,0,0), 'volley':(350,42,112,380,1.05,285)},
}
TACTICS={
 'glass_cannon':'Fragile high-damage predator with an exceptionally fast pursuit and charge.',
 'tank':'Very slow, heavily armored wall of health; contact hits punish careless routes.',
 'volley':'Keeps distance and releases massive aimed fan volleys with readable escape gaps.',
}
new=[]
for offset,name in enumerate(names):
    number=101+offset
    night=offset>=50
    stage=30 if not night else 1 if offset<70 else 30 if offset<90 else 50
    if not night:
        role=('tank','volley','glass_cannon')[offset%3] if offset<37 else ('glass_cannon','tank','volley')[(offset-37)%3]
    else:
        role=('glass_cannon','tank','volley')[(offset-50)%3]
    slug=name.lower().replace(' ','_').replace('-','_')
    source=MONSTERS/f'production_{number:03}.png'
    target=MONSTERS/f'{slug}.png'
    if source.exists():
        assert not target.exists(), f'Refusing to overwrite{target}'
        assert source.resolve().parent==target.resolve().parent==MONSTERS.resolve()
        source.rename(target)
    assert target.exists(), target
    image=Image.open(target).convert('RGBA')
    assert image.size==(768,192)
    raw=target.read_bytes(); digest=hashlib.sha256(raw).hexdigest()
    assert digest==proof[number]['sha256'], f'Exported pixels/file changed:{target}'
    proof[number]['named_target']=str(target.relative_to(ROOT)).replace('\\','/')
    hp,damage,speed,score,interval,bullet=BASE[stage][role]
    variation=offset%5
    hp+=variation*(24 if role=='tank' and stage>=30 else 4 if role=='tank' else 3)
    damage+=offset%3
    speed+=variation*2
    score+=variation*3
    behavior='tank' if role=='tank' else 'fan' if role=='volley' else 'charger' if offset%2 else 'skitter'
    volley_count=(5 if stage==1 else 9 if stage==30 else 15)+2*(offset%3)
    entry={
      'id':slug,'name':name,'texture':f'res://Assets/Monsters/{slug}.png',
      'behavior':behavior,'role':role,'attack_type':'ranged' if interval else 'melee',
      'health':hp,'damage':damage,'speed':speed,'score':score,
      'shoot_interval':round(interval-variation*0.035,3) if interval else 0.0,
      'bullet_speed':bullet+variation*3 if bullet else 0,'volley_count':volley_count if interval else 0,
      'radius':23 if role=='tank' else 16,'tier':1 if stage==1 else 3 if stage==30 else 5,
      'stage_min':stage,'night_only':night,
      'description':('Appears only at night. ' if night else 'Stage 2 veteran. ')+TACTICS[role],
      'frames':4,'frame_size':[192,192],'animation_fps':8,'generated':True,
      'source':'Kenney Creature Mixer v1.6.0; browser Randomize and Save spritesheet at 8x',
      'sha256':digest,'generation_batch':'production_2026_10_16','export_sequence':number,
    }
    if not night:
        entry['stage_max']=49
    new.append(entry)
assert Counter(m['role'] for m in new[:50])=={'glass_cannon':17,'tank':17,'volley':16}
assert Counter(m['stage_min'] for m in new[50:])=={1:20,30:20,50:10}
roster=legacy+new
assert len({m['id'] for m in roster})==200
assert len({m['sha256'] for m in roster})==200
manifest.write_text(json.dumps(roster,indent=2)+'\n',encoding='utf-8')
evidence['final_named_roster']='data/monsters.json'
evidence['original_sources_unchanged']=True
(OUT/'exports.json').write_text(json.dumps(evidence,indent=2)+'\n',encoding='utf-8')

# Deterministic lossless nearest-neighbor atlas. The original 100 coordinates
# remain unchanged. The supplied original is the final runtime creature (index 200).
atlas=Image.new('RGBA',(960,24*math.ceil((len(roster)+1)/10)),(0,0,0,0))
sources=[ROOT/m['texture'].removeprefix('res://') for m in roster]+[MONSTERS/'creature-sheet (2).png']
for index,path in enumerate(sources):
    strip=Image.open(path).convert('RGBA').resize((96,24),Image.Resampling.NEAREST)
    atlas.paste(strip,((index%10)*96,(index//10)*24))
atlas.save(ROOT/'Assets/Generated/monster_atlas.png')

font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',13)
heading=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',23)
for page in range(2):
    sheet=Image.new('RGB',(1600,870),'#252939'); draw=ImageDraw.Draw(sheet)
    draw.text((22,12),'InfiniteSlash — '+('Stage 2 veterans' if page==0 else 'Night-only nightmares'),font=heading,fill='#ffe8a6')
    draw.text((22,43),'Actual Creature Mixer 8x exports; untouched four-frame animated sources',font=font,fill='#c9d9e9')
    for i,m in enumerate(new[page*50:(page+1)*50]):
        image=Image.open(ROOT/m['texture'].removeprefix('res://')).convert('RGBA')
        tile=image.crop((0,0,192,192)).resize((112,112),Image.Resampling.NEAREST)
        x,y=(i%10)*160,(i//10)*160+70
        sheet.paste(tile,(x+24,y+2),tile)
        draw.text((x+5,y+119),f"{101+page*50+i} {m['name']}",font=font,fill='white')
        draw.text((x+5,y+139),f"L{m['stage_min']} · {m['role']}",font=font,fill='#91c7c8')
    sheet.save(OUT/f'named_roster_{page+1}.png')

lines=['# Expanded monster roster','',
 'The original 100 generated entries retain their exact order, IDs, stats, texture paths and source hashes. This expansion adds 50 stage-2 veterans and 50 night-only monsters exported from the real Kenney Creature Mixer v1.6.0 interface. All 100 new sheets are unique downloads from full Randomize → Save spritesheet at 8×; no source pixels were synthesized, recolored or resaved.','',
 'The 50 non-night stage-2 veterans spawn exclusively at levels 30–49 (`stage_min: 30`, `stage_max: 49`). Night-only creatures are split: 20 unlock at level 1, 20 at level 30 and 10 at level 50; their eligibility remains uncapped. Daylight blocks new night-only spawns; already spawned creatures remain alive. Combat scaling belongs to the game director and compounds these base values.','',
 '| # | Monster | Role | Minimum level | Night only | HP | Damage | Speed | Volley |',
 '| --- | --- | --- | --- | --- | --- | --- | --- | --- |']
for i,m in enumerate(new,101):
    lines.append(f"| {i} | {m['name']} | {m['role']} | {m['stage_min']} | {'yes' if m['night_only'] else 'no'} | {m['health']} | {m['damage']} | {m['speed']} | {m['volley_count'] or '—'} |")
lines+=['','`data/monsters.json` contains 200 generated monsters; the supplied original creature is appended by the game, for 201 runtime types. Atlas packing remains 10 strips per row, 96×24 pixels per four-frame strip. The 201-creature atlas is 960×504 pixels; runtime indices 0–99 keep the previous art and the original moves from 100 to 200. Saved games must migrate that legacy index.','',
 'Export provenance: `output/review/production-mixer/exports.json`. Scale and workflow screenshots plus raw and named contact sheets are in the same folder. Every 8× source is 768×192 RGBA, four 192×192 frames. `tools/validate_assets.py` verifies source file and decoded-pixel uniqueness, animation, role gates, and all 201 atlas strips against source pixels.','',
 'Biome review: the existing TinyTown pack has suitable pale-gray stone floor 109, cobbles 43, stone edges 108/110, battlements 99–101, arches 111–113 and stone walls 76–79. Farm 77 and 89 supply stone/rubble. These assets support a scrolling ruined-keep biome without generating new art. All tile IDs refer to `Assets/Town/Tiles/tile_XXXX.png` unless named Farm.']
(ROOT/'docs/MONSTER_ROSTER_EXPANSION.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('PASS: appended 100 unique reviewed monsters; original 100 unchanged; 960x504 atlas built.')
print(dict(Counter(m['role'] for m in new[:50])),dict(Counter(m['stage_min'] for m in new[50:])))
