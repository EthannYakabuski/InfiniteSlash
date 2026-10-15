# InfiniteSlash — Play Console upload kit

The playable game uses **`com.slash.game`**, English (`en-US`), and Play Games project **832658811620**. This kit contains all requested store assets. It does not publish anything to Google.

## Files to upload

| Requested item | Location | Count / specification |
| --- | --- | --- |
| Existing achievement icons | `icons/achievements/` | 12 PNGs, 512×512, each below 1 MB |
| New boss achievement icons | `boss-achievements/` | 2 PNGs, 512×512, each below 1 MB; new Google IDs pending |
| Leaderboard icons | `icons/leaderboards/` | 3 PNGs, 512×512, each below 1 MB |
| Short description | `listing/short_description.txt` | 68 characters; limit 80 |
| Full description | `listing/full_description.txt` | 2,125 characters; limit 4,000 |
| Store app icon | `branding/app_icon.png` | 512×512, 32-bit PNG, below 1 MB |
| Feature graphic | `branding/feature_graphic_v2.png` | 1024×500, 24-bit PNG, below 15 MB; title moved inward for side cropping |
| Phone screenshots | `screenshots/phone/` | 8 PNGs, 1080×1920 |
| 7-inch tablet screenshots | `screenshots/tablet_7/` | 8 PNGs, 1440×2560 |
| 10-inch tablet screenshots | `screenshots/tablet_10/` | 8 PNGs, 2160×3840 |

Every screenshot is 9:16, opaque RGB and below 8 MB. Upload each screenshot folder in numeric order. The first three emphasize actual Sword combat, Shield defense and boss bullet hell. They satisfy the requested bounds and the current larger-screen guidance. [Google preview asset guidance](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en)

## New boss records and existing Play Games records

The 2026-10-15 update adds **Royal Upset** and **Crown Census**. Create these two Standard achievements using [their names, descriptions and icons](boss-achievements/README.md), then send their Google IDs. They already work locally and queue unlocks for later sync. The complete kit now includes 43 upload images and refreshed screenshots of the current HUD. The separate `boss-achievements/InfiniteSlash-new-boss-achievements.zip` contains just the two new icons and definitions.

Your 12 achievements and three leaderboards already exist. **Edit their existing records to upload these icons. Do not re-import the earlier achievement metadata draft** into this configured game. `icons/icon_manifest.json` maps every semantic filename to its supplied Google ID, name, goal and type. `achievement-icons.zip` and `leaderboard-icons.zip` simply group the PNGs for convenient extraction; they are not Console achievement-definition import files.

The app icon is RGBA PNG because Google's Play icon specification requires PNG; JPEG is not the accepted store-icon format. Its foreground identity remains readable within a circular crop, and no rounded-corner mask or ranking/price badges are baked in. [Google Play icon specification](https://developer.android.com/distribute/google-play/resources/icon-design-specifications)

Suggested alt text:

- App icon: **Red-plumed pixel knight swinging a glowing sword with a blue and gold shield against a teal monster backdrop.**
- Feature graphic: **InfiniteSlash knight slashing through colorful fantasy monsters beneath a crowned boss in a bright pixel forest.**
- Screenshot alt text, in order: **Sword knight slashing a monster swarm.** / **Shield knight parrying enemy shots.** / **Crowned boss surrounded by bullets and monsters.** / **Knight dashing through a projectile gap.** / **Thunderblade lightning striking nearby creatures.** / **Hurricane sword sweep with a growing combo.** / **Sword and Shield class selection with visible stat tradeoffs.** / **Run result with score and one-tap replay choices.**

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

Achievement/leaderboard badges reuse the actual sprites with new code-native pixel medal compositions. `tools/build_store_icons.py` reproduces all 15. Their filenames and manifest IDs match runtime configuration.

Screenshots are independently rendered captures of the **actual Godot game** at each target resolution, with reproducible demonstration state. They are not AI gameplay mockups or physical-device screenshots, and they do not claim phone/tablet performance or successful Google server uploads. `screenshots/manifest.json` records their provenance, seeds, dimensions and hashes. See `screenshots/README.md` for reproduction.

`tools/validate_store_assets.py` checks image counts, dimensions, channel formats, file-size limits, Google-ID mappings, incremental targets, duplicate images and description lengths. It writes `validation.json`, `upload_manifest.json`, the two icon archives and `InfiniteSlash-PlayStore-assets.zip`. The complete ZIP contains upload assets and their manifest; large generation sources and review contact sheets are excluded.

The copy describes current gameplay and local features. It avoids unverified cloud claims, fake multiplayer, invented testimonials, rankings and promises of virality. The visual approach emphasizes a recognizable red-plumed knight, a gold slash, absurd creature variety and visible class choices.

## Remaining owner/backend steps

- Authorize tester accounts and choose a distribution route. The supplied **A1:CD:…:64:DB** certificate is Google's Play App Signing certificate and is appropriate for Play-installed builds. A sideloaded debug build needs its **own linked Android OAuth credential** for `com.slash.game` and its actual signer; the developer report records that fingerprint.
- Local upload/release signing is now configured. Use the versioned signed 0.2.0 AAB described in [the current Android report](../docs/ROUND2_ANDROID.md); check that version code 6 is unused on your track before uploading. Older unsigned preparation bundles are not signed releases.
- Add these icons, store descriptions, artwork and screenshot folders to the existing Console records. Publish the Play Games configuration when ready, separately from the app release.
- Run real eligible-account sign-in, online unlock/score, offline replay and two-device save tests. Simulated native tests do not establish successful Google server operation.
- Saved Games was reported enabled at 21:20 Eastern on Oct 12. Activation may take up to 24 hours. Toronto uses EDT (UTC−4) on that date; the handoff records that time-zone assumption explicitly. [Activation guidance](https://developer.android.com/games/pgs/console/enable-features), [Toronto 2026 time zones](https://www.timeanddate.com/time/zone/canada/toronto?year=2026)
- The package rename installs a separate Android app from earlier `org.infiniteslash.game` debug builds. Their local progress does not automatically move into the new package's sandbox.

Content rating, audience, Data safety and other “Set up your app” declarations remain yours, as requested. Build/configuration evidence and remaining live-test limits are in [the native integration report](../docs/PLAY_SERVICES_IMPLEMENTATION.md) and [the owner handoff](../docs/PLAY_SERVICES_HANDOFF.json).
