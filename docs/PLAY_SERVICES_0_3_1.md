# Google Play Games resource wiring — 0.3.1 / code 9

The owner supplied the seven production-update resource IDs on 2026-10-17. They are configured in `config/play_services.json`; gameplay, progression, saved-profile schema and achievement requirements are unchanged from 0.3.0.

## Configured resources

| Local key | Console name | Google ID | Type / value |
| --- | --- | --- | --- |
| `bestiary_50` | Field Guide | `CgkI5NXU8p0YEAIQEg` | Standard; defeat 50 different generated species |
| `bestiary_100` | Monster Scholar | `CgkI5NXU8p0YEAIQEw` | Standard; defeat 100 different generated species |
| `bestiary_150` | Midnight Archivist | `CgkI5NXU8p0YEAIQFA` | Standard; defeat 150 different generated species |
| `bestiary_200` | Living Bestiary | `CgkI5NXU8p0YEAIQFQ` | Standard; defeat all 200 generated species |
| `biome_50` | Beyond the Kingdom | `CgkI5NXU8p0YEAIQFg` | Standard; reach level 50 / Crownfall Keep |
| `highest_combo` | Unbroken Steel | `CgkI5NXU8p0YEAIQFw` | Numeric, zero decimals, larger is better; best completed-run combo |
| `highest_level` | Highest Level | `CgkI5NXU8p0YEAIQGA` | Numeric, zero decimals, larger is better; best completed-run level |

The app now has **19 configured achievement IDs and five configured leaderboard IDs**. All fourteen earlier achievement IDs and three earlier board IDs are preserved, including Royal Upset, Crown Census and the existing bosses-per-run board. The four Incremental targets, project `832658811620`, package `com.slash.game` and cloud slot `infiniteslash_profile_v1` are unchanged.

The five new achievements use Standard unlocks. Previously earned local badges and queued best scores remain available for replay once an eligible Google account authenticates and account ownership is verified. Acknowledging an older score cannot erase a newer queued high. The optional daily leaderboard and duplicate local `survivor_180` mapping remain intentionally empty.

## Verification and artifacts

The focused service regression suite passed **458 checks with zero failures** (`output/review/configured_production_services.log`). It checks the exact supplied IDs, uniqueness, Standard unlock dispatch, integer leaderboard values, offline replay, acknowledgements, blank-ID fallback fixtures, save migration and cloud conflict handling. It uses simulated native clients; it does not unlock or submit anything to a live Google account.

The [Android package report](PLAY_SERVICES_0_3_1_ANDROID.md) records final hashes, signatures, version metadata and the configuration extracted from both actual packages. Version **0.3.1 / Android code 9** distinguishes this configuration patch from the preserved 0.3.0 packages. The previous [gameplay verification](PRODUCTION_VERIFICATION.md) and [Android smoke report](PRODUCTION_ANDROID.md) remain evidence for the unchanged 0.3.0 gameplay, rather than new device tests of this patch.

- [Installable debug APK](../builds/InfiniteSlash-debug-0.3.1.apk)
- [Signed Play upload bundle](../builds/InfiniteSlash-play-0.3.1.aab)
- [Configured icon and registration table](../store/production-update/README.md)
- [Complete store asset kit](../store/InfiniteSlash-PlayStore-assets.zip)

## Owner follow-up

No further resource IDs are needed for these seven features. Attach the existing icons to the matching Console records, retain Standard achievement types and integer/larger-is-better board settings, and complete any pending Console publication/tester access. Test the signed bundle through the Play testing track so the Google-managed App Signing credential applies. Verify real unlocks, completed-run submissions and cross-device cloud saves with an eligible account. A sideloaded debug APK uses a different certificate and needs its own matching OAuth credential for Google authentication.
