# Production update — new Play Games records

The game already tracks all seven goals offline. Their Google IDs are intentionally blank until you return them. The existing 14 online achievement IDs and three leaderboard IDs are preserved.

Download [all seven 512×512 PNG icons and registration metadata](InfiniteSlash-production-feature-icons.zip), or use the individual files below. Every image is RGB PNG and below 1 MB. [Preview all icons](preview.png).

## Create five Standard achievements

Use English, **Standard** type and suggested **Revealed** initial visibility. These count **different creature species defeated across runs**, rather than a total number of kills. Repeating a species and defeating a boss's temporary summons do not add another species. Earlier versions recorded bestiary discovery only on a kill, so validated legacy discoveries retain that progress.

| Return this key with the ID | Suggested name | Description | Suggested points | Icon |
| --- | --- | --- | ---: | --- |
| `bestiary_50` | Field Guide | Defeat 50 different creature species across your runs. | 10 | [PNG](achievements/bestiary_50.png) |
| `bestiary_100` | Monster Scholar | Defeat 100 different creature species across your runs. | 15 | [PNG](achievements/bestiary_100.png) |
| `bestiary_150` | Midnight Archivist | Defeat 150 different creature species across your runs. | 20 | [PNG](achievements/bestiary_150.png) |
| `bestiary_200` | Living Bestiary | Defeat 200 different creature species across your runs. | 25 | [PNG](achievements/bestiary_200.png) |
| `biome_50` | Beyond the Kingdom | Reach level 50 and enter Crownfall Keep. | 20 | [PNG](achievements/biome_50.png) |

The collection persists when a species dies, including runs later abandoned. Biome arrival unlocks immediately at the transition, including resuming beyond level 50. Cloud profiles merge validated species identities as a union. Active runs remain local.

## Update the existing bestiary record

Keep `collector` / **CgkI5NXU8p0YEAIQDQ**, its **Incremental** type and **100-step** target. Update its display name from *Bestiary Complete* to **Bestiary Pioneer**, and its description to **Defeat 100 different creature species across your runs.** It now accepts any 100 of the expanded roster. Existing earned awards remain earned; do not recreate the record or reset progress. The old collector icon is unchanged.

Monster Scholar intentionally adds a new Standard milestone for the updated bestiary series at 100 species; it is separate from the existing collector ID. Keep **Crown Census** unchanged: it still requires all **12 distinct boss identities**, rather than the creature species collection.

## Create two leaderboards

Both use **Numeric**, **zero decimal places**, **larger is better**. Values are the best record from a **completed run**, shared by Sword, Shield and daily mode. Pausing or abandoning a run does not submit a competitive result.

| Return this key with the ID | Suggested name | Description | Units | Icon |
| --- | --- | --- | --- | --- |
| `highest_combo` | Unbroken Steel | Highest kill combo in one completed run. | kill / kills | [PNG](leaderboards/highest_combo.png) |
| `highest_level` | Beyond All Reason | Highest level reached in one completed run. | level / levels | [PNG](leaderboards/highest_level.png) |

**Bosses destroyed already exists:** `bosses_in_run` / **CgkI5NXU8p0YEAIQAw**, **Crown Hoarder**, tracks the most bosses defeated in one completed run. No duplicate is needed. Its [existing icon](../icons/leaderboards/bosses_in_run.png) remains available.

Send back the five achievement IDs and two leaderboard IDs by the keys above. The game skips blank IDs safely, retains earned local badges and best scores, and replays them after the IDs are configured and eligible Google authentication succeeds. No Google account unlock, score submission, or publication has been claimed as verified.

The [machine-readable manifest](feature_manifest.json) includes exact definitions, dimensions, file hashes and current configuration status. Reproduce the art with `tools/build_production_service_icons.py`; its `--metadata-only` option refreshes IDs and the archive without rewriting the images.
