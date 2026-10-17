# Production update — new Play Games records

All seven owner-supplied Google IDs are now configured in **0.3.1 / Android code 9**. The game retains offline progress and replays earned badges and best records after eligible authentication. There are now **19 configured online achievements and five configured leaderboards**; the original IDs remain unchanged. No IDs remain pending for these requested features.

Download [all seven 512×512 PNG icons and registration metadata](InfiniteSlash-production-feature-icons.zip), or use the individual files below. Every image is RGB PNG and below 1 MB. [Preview all icons](preview.png).

## Five configured Standard achievements

Use English, **Standard** type and suggested **Revealed** initial visibility. These count **different creature species defeated across runs**, rather than a total number of kills. Repeating a species and defeating a boss's temporary summons do not add another species. Earlier versions recorded bestiary discovery only on a kill, so validated legacy discoveries retain that progress.

| Game key | Configured Google ID | Name | Description | Suggested points | Icon |
| --- | --- | --- | --- | ---: | --- |
| `bestiary_50` | `CgkI5NXU8p0YEAIQEg` | Field Guide | Defeat 50 different creature species across your runs. | 10 | [PNG](achievements/bestiary_50.png) |
| `bestiary_100` | `CgkI5NXU8p0YEAIQEw` | Monster Scholar | Defeat 100 different creature species across your runs. | 15 | [PNG](achievements/bestiary_100.png) |
| `bestiary_150` | `CgkI5NXU8p0YEAIQFA` | Midnight Archivist | Defeat 150 different creature species across your runs. | 20 | [PNG](achievements/bestiary_150.png) |
| `bestiary_200` | `CgkI5NXU8p0YEAIQFQ` | Living Bestiary | Defeat 200 different creature species across your runs. | 25 | [PNG](achievements/bestiary_200.png) |
| `biome_50` | `CgkI5NXU8p0YEAIQFg` | Beyond the Kingdom | Reach level 50 and enter Crownfall Keep. | 20 | [PNG](achievements/biome_50.png) |

The collection persists when a species dies, including runs later abandoned. Biome arrival unlocks immediately at the transition, including resuming beyond level 50. Cloud profiles merge validated species identities as a union. Active runs remain local.

## Update the existing bestiary record

Keep `collector` / **CgkI5NXU8p0YEAIQDQ**, its **Incremental** type and **100-step** target. Update its display name from *Bestiary Complete* to **Bestiary Pioneer**, and its description to **Defeat 100 different creature species across your runs.** It now accepts any 100 of the expanded roster. Existing earned awards remain earned; do not recreate the record or reset progress. The old collector icon is unchanged.

Monster Scholar intentionally adds a new Standard milestone for the updated bestiary series at 100 species; it is separate from the existing collector ID. Keep **Crown Census** unchanged: it still requires all **12 distinct boss identities**, rather than the creature species collection.

## Two configured leaderboards

Both use **Numeric**, **zero decimal places**, **larger is better**. Values are the best record from a **completed run**, shared by Sword, Shield and daily mode. Pausing or abandoning a run does not submit a competitive result.

| Game key | Configured Google ID | Name | Description | Units | Icon |
| --- | --- | --- | --- | --- | --- |
| `highest_combo` | `CgkI5NXU8p0YEAIQFw` | Unbroken Steel | Highest kill combo in one completed run. | kill / kills | [PNG](leaderboards/highest_combo.png) |
| `highest_level` | `CgkI5NXU8p0YEAIQGA` | Highest Level | Highest level reached in one completed run. | level / levels | [PNG](leaderboards/highest_level.png) |

**Bosses destroyed already exists:** `bosses_in_run` / **CgkI5NXU8p0YEAIQAw**, **Crown Hoarder**, tracks the most bosses defeated in one completed run. No duplicate is needed. Its [existing icon](../icons/leaderboards/bosses_in_run.png) remains available.

Upload the icons to these existing Google records; do not create duplicate definitions or resend the IDs. Confirm their Standard/Numeric settings and publish the Play Games configuration when ready. Previously earned local badges and best scores are retained and replayed after eligible Google authentication. Verify real account unlocks, score submissions, offline replay and two-device saves on the signed distribution. No Google account unlock, score submission, or publication is claimed as verified by local tests.

The [machine-readable manifest](feature_manifest.json) includes exact definitions, dimensions, file hashes and current configuration status. The preview and icon artwork are unchanged; the table and manifest provide current Console names and IDs. Reproduce the art with `tools/build_production_service_icons.py`; its `--metadata-only` option refreshes IDs and the archive without rewriting the images. See the [0.3.1 patch report](../../docs/PLAY_SERVICES_0_3_1.md) for configuration/build evidence and live-test limits.
