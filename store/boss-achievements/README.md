# Configured boss achievements

Both **Standard achievements** are configured in InfiniteSlash using the owner-supplied Google IDs below. Upload the matching icons to those existing Play Games records; do not recreate them. Local unlocks already saved on a device will replay after eligible Google authentication. The original twelve configured achievement IDs remain unchanged; the game now has fourteen online achievements and fifteen local badges representing fourteen distinct goals.

| Runtime key | Google achievement ID | Display name | Description | Icon |
| --- | --- | --- | --- | --- |
| `rare_boss` | `CgkI5NXU8p0YEAIQEA` | Royal Upset | Defeat a rare boss: Moonmallow Majesty, Gilded Chancellor, or Lime Imperator. | `rare_boss.png` |
| `all_bosses` | `CgkI5NXU8p0YEAIQEQ` | Crown Census | Defeat all 12 different bosses across your runs. | `all_bosses.png` |

Suggested points: **20** for Royal Upset and **30** for Crown Census. Suggested initial state: **Revealed**. These are recommendations; use your preferred valid point allocation. Neither achievement is Incremental. Crown Census progress is saved and merged locally/cloud-side as a set of unique defeated boss IDs; the badge unlocks when all twelve are present, across any number of runs.

Both icons are unchanged 512×512 RGB PNGs below 1 MB. Upload the individual PNGs to their listed existing records; the ZIP is a convenience download, not an achievement-definition import file. `achievement_manifest.json` records names, criteria, configured IDs, dimensions, sizes and hashes. Actual Google unlocks, offline replay and cross-device recovery still require eligible-account testing; configured IDs alone are not proof of live server behavior.

The icons extend the existing pixel medal art with an actual rare boss and a royal ledger holding twelve crown seals. Reproduce them with `tools/build_boss_achievement_icons.py`; refresh metadata and the archive without rewriting artwork using `tools/build_boss_achievement_icons.py --metadata-only`.
