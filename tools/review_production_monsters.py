"""Inspection-only thumbnails; never edits original exported sheets."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/review/production-mixer'
files=sorted((ROOT/'Assets/Monsters').glob('production_*.png'))
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
for page in range((len(files)+49)//50):
    sheet=Image.new('RGB',(1400,800),'#252939'); draw=ImageDraw.Draw(sheet)
    for i,path in enumerate(files[page*50:(page+1)*50]):
        source=Image.open(path).convert('RGBA')
        assert source.size==(768,192)
        tile=source.crop((0,0,192,192)).resize((120,120),Image.Resampling.NEAREST)
        x,y=(i%10)*140,(i//10)*160
        sheet.paste(tile,(x+10,y+6),tile)
        draw.text((x+48,y+135),path.stem[-3:],font=font,fill='white')
    sheet.save(OUT/f'production_review_{page+1}.png')
print(f'{len(files)} actual exports reviewed via contact sheets')
