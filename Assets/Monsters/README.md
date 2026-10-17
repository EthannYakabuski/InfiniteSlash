# Creature Mixer monsters

The 200 named PNG sheets were created using [Kenney Creature Mixer](https://kenney.itch.io/creature-mixer), with the full **Randomize** command and **Save spritesheet** export at **8x**. Every sheet has four animated 192 x 192 cells, totaling 768 x 192 RGBA pixels. The original exported pixels are preserved.

The separately supplied `creature-sheet (2).png` is also preserved. It is not counted among the 200 generated monsters in `data/monsters.json`; the game appends it as runtime monster 201.

Creature Mixer permits personal, educational and commercial use of its generated creations and artwork, excluding NFT and blockchain projects. Giving credit is appreciated but not mandatory. This permission is distinct from the CC0 licenses bundled with the other Kenney asset packs in this project.

Names, combat roles and statistics are recorded in `data/monsters.json`, `docs/MONSTER_ROSTER.md`, and `docs/MONSTER_ROSTER_EXPANSION.md`. The original 100 entries retain their exact order, data and art. The expansion adds 50 veterans exclusive to levels 30–49 and 50 night-only monsters. It keeps all source downloads intact and grows the native-pixel render atlas to 960 x 504 pixels.

Actual browser workflow evidence, per-download hashes, and named visual contact sheets for the expansion are in `output/review/production-mixer`. Run `tools/validate_assets.py` to verify dimensions, transparency, animation, stage gates, source file and decoded-pixel uniqueness, and all 201 atlas strips against the original PNGs.
