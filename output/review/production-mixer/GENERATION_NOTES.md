# Creature Mixer expansion provenance

Generated on October 16, 2026 (America/Toronto) through the actual public [Kenney Creature Mixer](https://kenney.itch.io/creature-mixer), version 1.6.0. The official embedded application is `https://html-classic.itch.zone/html/9229894/index.html`.

Each of the 100 new transparent animated sheets came from clicking the full **Randomize** command, then **Save spritesheet**, with export scale set to **8x**. The export's suggested filename was `creature-sheet.png`. The tool automatically closes its menu after a save, so automation reopened the hamburger menu for each next creature. Randomize shapes and Randomize colors were not used.

The first 37 downloads used automated Edge with software WebGL. That renderer caused excessive CPU load, so the batch was paused and resumed without replacing the saved downloads. Normal Edge hardware rendering completed the remaining 63 exports. `exports.json` records hashes for all 100 downloads; its `startedUtc` is the final resumed session's start, and earlier per-file timestamps are retained where available. The first sheet's timestamp was lost during the first resumption; its original export screenshot and exact file hash remain. No invented timestamp was substituted.

The source PNGs were renamed after visual review. They were never recolored, composited, resaved, or regenerated. `named_target` maps each original temporary download path to its final named asset. Each original sheet is 768 x 192 RGBA with four 192 x 192 cells. File hashes and decoded-pixel hashes are distinct across all 200 generated monsters and the supplied original is separately preserved.

The 50 non-night veterans carry `stage_min: 30` and `stage_max: 49`, making their new spawns exclusive to stage 2. The 50 night-only creatures have uncapped maximum levels, with minimum levels distributed 20/20/10 across levels 1/30/50. These gates are metadata only and do not change any exported pixels.

`01_license.png`, `02_scale8.png`, and periodic export screenshots document the real interface. `production_review_1.png` and `production_review_2.png` show the initial numbered exports; `named_roster_1.png` and `named_roster_2.png` show their reviewed final names and combat roles.

The original 100 roster entries are retained exactly in `original100_manifest.json`. The new atlas packs all 200 generated creatures followed by the supplied original at native pixel resolution, giving 201 runtime types in a 960 x 504 atlas. Source downloads stay intact. The validator checks every atlas strip against its source, as well as all file hashes, unique decoded pixels, animation variation and stage gates.

Creature Mixer permits personal, educational and commercial use, excluding NFT and blockchain projects. Its license is distinct from the supplied Kenney tile packs' CC0 license. The original license dialog and source link are preserved above.
