# New boss achievements

Create these **two new Standard achievements** in the existing InfiniteSlash Play Games project, then send their Google IDs. Both already unlock locally and their pending unlocks will replay after the IDs are configured. The original twelve configured achievements remain unchanged.

| Key to send back | Display name | Description | Icon |
| --- | --- | --- | --- |
| `rare_boss` | Royal Upset | Defeat a rare boss: Moonmallow Majesty, Gilded Chancellor, or Lime Imperator. | `rare_boss.png` |
| `all_bosses` | Crown Census | Defeat all 12 different bosses across your runs. | `all_bosses.png` |

Suggested points: **20** for Royal Upset and **30** for Crown Census. Suggested initial state: **Revealed**. These are recommendations; use your preferred valid point allocation. Neither achievement is Incremental. Crown Census progress is saved and merged locally/cloud-side as a set of unique defeated boss IDs; the badge unlocks when all twelve are present, across any number of runs.

Both icons are 512×512 RGB PNGs below 1 MB. Upload the individual PNGs to the corresponding new records; the ZIP is a convenience download, not an achievement-definition import file. `achievement_manifest.json` records names, criteria, blank IDs, dimensions, sizes and hashes.

The icons extend the existing pixel medal art with an actual rare boss and a royal ledger holding twelve crown seals. Reproduce them with `tools/build_boss_achievement_icons.py`.
