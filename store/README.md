# InfiniteSlash — Play Console upload kit

The playable game uses **`com.slash.game`**, English (`en-US`), and Play Games project **832658811620**. This kit accompanies the **0.3.1 configuration patch / Android code 9** and reuses the unchanged **0.3.0 Crownfall gameplay** artwork and screenshots. It does not publish anything to Google.

## Files to upload

| Requested item | Location | Count / specification |
| --- | --- | --- |
| Existing achievement icons | `icons/achievements/` | 12 PNGs, 512×512, each below 1 MB |
| Boss achievement icons | `boss-achievements/` | 2 PNGs, 512×512, each below 1 MB; both Google IDs configured |
| New production achievement icons | `production-update/achievements/` | 5 PNGs, 512×512, each below 1 MB; all Google IDs configured |
| Leaderboard icons | `icons/leaderboards/` | 3 PNGs, 512×512, each below 1 MB |
| New production leaderboard icons | `production-update/leaderboards/` | 2 PNGs, 512×512, each below 1 MB; both Google IDs configured |
| Short description | `listing/short_description.txt` | 68 characters; limit 80 |
| Full description | `listing/full_description.txt` | 2,654 characters; limit 4,000 |
| Store app icon | `branding/app_icon.png` | 512×512, 32-bit PNG, below 1 MB |
| Feature graphic | `branding/feature_graphic_v2.png` | 1024×500, 24-bit PNG, below 15 MB; title moved inward for side cropping |
| Phone screenshots | `screenshots/phone/` | 8 PNGs, 540×960 |
| 7-inch tablet screenshots | `screenshots/tablet_7/` | 8 PNGs, 1080×1920 |
| 10-inch tablet screenshots | `screenshots/tablet_10/` | 8 PNGs, 1080×1920 |

Every screenshot is 9:16, opaque RGB and below 8 MB. Upload each screenshot folder in numeric order. The first three show meadow combat, the night war host and level-50 Crownfall Keep with Overdrive. The two tablet groups intentionally share the same 1080×1920 rendered frames. All files satisfy the requested upload dimensions. [Google preview asset guidance](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en)

## New boss records and existing Play Games records

**Royal Upset** (`CgkI5NXU8p0YEAIQEA`) and **Crown Census** (`CgkI5NXU8p0YEAIQEQ`) remain configured as Standard achievements using the owner-supplied IDs. Upload [their unchanged icons](boss-achievements/README.md) to those existing records. Saved local unlocks replay after eligible Google authentication. The complete kit includes 50 upload images: **nineteen configured achievement icons, five configured leaderboard icons**, branding and 24 screenshots. No requested feature IDs remain pending. The separate `boss-achievements/InfiniteSlash-new-boss-achievements.zip` contains the two boss icons and their configured metadata.

All nineteen achievements and five leaderboards now have configured IDs. **Edit their existing records to upload these icons. Do not create duplicate definitions or re-import the earlier achievement metadata draft** into this configured game. `icons/icon_manifest.json` maps the original twelve achievement icons and three board icons to their unchanged Google IDs, names, goals and types. `boss-achievements/achievement_manifest.json` maps the two boss badges. The [production-update handoff](production-update/README.md) and its manifest map all five additional Standard achievements and both additional Numeric boards, including **Highest Level**. The existing collector keeps its ID/Incremental100 target, with display metadata updated to **Bestiary Pioneer**, any 100 species. Crown Census still means all twelve bosses. `achievement-icons.zip` contains all nineteen badge PNGs; `leaderboard-icons.zip` contains all five board PNGs. These are convenience downloads, not Console definition import files.

The app icon is RGBA PNG because Google's Play icon specification requires PNG; JPEG is not the accepted store-icon format. Its foreground identity remains readable within a circular crop, and no rounded-corner mask or ranking/price badges are baked in. [Google Play icon specification](https://developer.android.com/distribute/google-play/resources/icon-design-specifications)

Suggested alt text:

- App icon: **Red-plumed pixel knight swinging a glowing sword with a blue and gold shield against a teal monster backdrop.**
- Feature graphic: **InfiniteSlash knight slashing through colorful fantasy monsters beneath a crowned boss in a bright pixel forest.**
- Screenshot alt text, in order: **Knight defending a bright meadow from a colorful monster swarm.** / **Night creatures and a crowned boss surrounding the road.** / **Overdrive active inside the violet stone halls of Crownfall Keep.** / **Boss fire spell filling a marked circular zone.** / **Rectangular earthquake crossing the battlefield.** / **Electric pulse with a visible gap to escape through.** / **Paused choice between lifesteal and a speed upgrade with a guard-recovery cost.** / **Legendary Phoenix Oath and Worldbreaker upgrade choices.**

## Category and five tags

Choose **Game → Action** as the main category. Recommended five tags:

1. **Arcade** — score chasing and endless quick runs.
2. **Hack & slash** — melee sword combat is the core attack.
3. **Single player** — one knight; leaderboards do not make gameplay multiplayer.
4. **Offline** — the core game and local progression work without Google services.
5. **Pixelated** — the actual game's pixel art is visible in every capture.

These are recommendations, not settings changed in your Console. Verify the available labels in **Store settings → Manage tags**; if Hack & slash is unavailable there, use **Stylized**. Google allows one main category and up to five relevant tags. [Category/tag guidance](https://support.google.com/googleplay/android-developer/answer/9859673?hl=en)

## What was created and checked

The app icon and feature graphic were generated with the built-in imagegen tool using the existing knight/monster artwork as references. Exact prompts, references and formatting notes are in `branding/prompts.json`. Original selected outputs are preserved in `branding/source/`; `tools/prepare_store_brand.ps1` produces the exact upload dimensions and PNG channel formats. The project launcher/editor icon now uses the new brand art under `Assets/Brand`.

Achievement/leaderboard badges reuse the actual sprites with code-native pixel medal compositions. `tools/build_store_icons.py` reproduces the original fifteen feature icons; `tools/build_boss_achievement_icons.py` reproduces the two boss badges; `tools/build_production_service_icons.py` builds the seven new icons. The latter two support `--metadata-only` to refresh public IDs and archives without rewriting artwork. Their filenames and manifest IDs match runtime configuration.

Screenshots show the **actual 0.3.0 Godot game** using reproducible composed states. Eight views were selected from the final acceptance renders at 540×960 and 1080×1920, with the tablet groups sharing the latter frames. The source PNGs are preserved; promotion only removes fully opaque alpha, with identical RGB pixels verified. No resizing, retouching or compositing was performed. They are desktop renders, not physical-device screenshots, and do not claim phone/tablet performance or successful Google server uploads. `screenshots/manifest.json` maps each upload to its preserved source and hashes. The prior 24 screenshots are backed up under `output/review/store-screenshots-0.2/`. See `screenshots/README.md` for reproduction.

`tools/validate_store_assets.py` checks image counts, dimensions, channel formats, file-size limits, Google-ID mappings, incremental targets, duplicate images and description lengths. It writes `validation.json`, `upload_manifest.json`, the two icon archives and `InfiniteSlash-PlayStore-assets.zip`. The complete ZIP contains upload assets and their manifest; large generation sources and review contact sheets are excluded.

The copy describes current gameplay and local features. It avoids unverified cloud claims, fake multiplayer, invented testimonials, rankings and promises of virality. The visual approach emphasizes a recognizable red-plumed knight, a gold slash, absurd creature variety and visible class choices.

## Remaining owner/backend steps

- Authorize tester accounts and choose a distribution route. The supplied **A1:CD:…:64:DB** certificate is Google's Play App Signing certificate and is appropriate for Play-installed builds. A sideloaded debug build needs its **own linked Android OAuth credential** for `com.slash.game` and its actual signer; the developer report records that fingerprint.
- Local upload/release signing is configured. The current patch is **0.3.1 / code 9**; use the signed AAB described in [the current configuration/build report](../docs/PLAY_SERVICES_0_3_1.md) and check that version code 9 is unused on your track. [The 0.3.0 Android report](../docs/PRODUCTION_ANDROID.md), [0.2.0 Android report](../docs/ROUND2_ANDROID.md) and [0.2.1 configuration notes](../docs/BOSS_ACHIEVEMENTS_CONFIGURED.md) retain historical evidence. Older unsigned preparation bundles are not signed releases.
- Add these icons, store descriptions, artwork and screenshot folders to the existing Console records. Publish the Play Games configuration when ready, separately from the app release.
- Run real eligible-account sign-in, online unlock/score, offline replay and two-device save tests. Simulated native tests do not establish successful Google server operation.
- Saved Games was reported enabled at 21:20 Eastern on Oct 12. Activation may take up to 24 hours. Toronto uses EDT (UTC−4) on that date; the handoff records that time-zone assumption explicitly. [Activation guidance](https://developer.android.com/games/pgs/console/enable-features), [Toronto 2026 time zones](https://www.timeanddate.com/time/zone/canada/toronto?year=2026)
- The package rename installs a separate Android app from earlier `org.infiniteslash.game` debug builds. Their local progress does not automatically move into the new package's sandbox.

Content rating, audience, Data safety and other “Set up your app” declarations remain yours, as requested. Build/configuration evidence and remaining live-test limits are in [the native integration report](../docs/PLAY_SERVICES_IMPLEMENTATION.md) and [the owner handoff](../docs/PLAY_SERVICES_HANDOFF.json).
