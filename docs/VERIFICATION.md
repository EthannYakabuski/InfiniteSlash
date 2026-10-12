# MVP verification

Verified on 2026-10-12 with Godot 4.5.1. The portrait game is playable from launch through death and immediate restart. The Android development APK, source project, original monster exports, optimized rendering atlas and test tools are included.

## Sword and Shield revision

The launch and restart cards now show opposing HP/damage/speed/guard arrows, role descriptions and exact starting HP/damage. Sword starts with 80 HP, 32 damage, 0.36-second swings and 290px/s movement; Shield starts with 170 HP, 24 damage, 0.60-second swings and 220px/s movement. Guard reserve, drain/recovery, projectile cost, perfect-guard window and contact protection also differ substantially. The blade/shield sizes and HUD icon distinguish the classes during play. Shared profiles supply combat and card statistics; distinct upgrade caps preserve the differences in longer runs.

The latest follow-up increases only Shield's starting damage from 18 to 24, leaving its other stats and all upgrade limits unchanged. The gameplay suite passes 315 checks, including controlled class comparisons and version-three snapshot migration. Existing version-two Shield runs receive the damage increase once; their other stats/progress remain intact, Sword damage remains unchanged, and repeated restoration does not multiply the buff again. An actual paused Android Shield18 fixture resumed as Shield24 with its health/cadence/reach/guard/style/seed/level preserved, saved/relaunched successfully, and fresh Shield24/Android Back passed. Five follow-up screenshots were visually reviewed with zero runtime errors.

The preceding 274-check class revision, twelve-screen Android full suite and original 125→170 HP migration remain separately recorded with their earlier APK hash and 18-damage Shield balance. Runs predating the class revision still reconstruct upgrades at their saved level while retaining health/guard fractions, actors and random-generator states. Earlier captures are not relabeled as current-package evidence.

## Implemented experience

Launch offers Sword and Shield over the arena. Drag anywhere to move while attacks happen automatically; release to guard and make a deliberate quick flick to dash. Combat includes eight monster behaviors, escalating waves, recurring crowned bosses, scrolling seasonal scenery, healing, six temporary buffs, XP upgrades, combos, sound effects and original looping music. Scores, 13 local badges, discoveries, daily UTC runs, settings and recoverable active runs persist offline.

The supplied four-frame creature is preserved and used as Cinder Tinpot. Exactly 100 additional creatures were exported through Creature Mixer's full Randomize and Save spritesheet workflow at 8×. Each has a unique name, original transparent animated sheet and combat data. Both file hashes and decoded pixel hashes confirm uniqueness. See [asset review](ASSET_REVIEW.md), [roster](MONSTER_ROSTER.md) and `output/review/monster_roster.png`.

## Checks and evidence

| Check | Result | Evidence |
| --- | --- | --- |
| Monster assets and music | Pass: 100 unique animated transparent sheets, original preserved, correct stats, unclipped 32-second loop | `tools/validate_assets.py`; `output/review/asset_validation.json` |
| Actual gameplay scene | Pass: 315 checks, zero failures | `tests/test_game.gd`; `output/review/game_validation.json`; `game_shield_buff_runtime.log` |
| Continuous simulation | Pass: 18,000 fixed steps / five simulated minutes; finite state and caps maintained | Peak 100 enemies, 240 bullets, 60 pickups, 90 effects in the gameplay report |
| Local storage and Play adapter | Pass: 82 checks, zero failures; real-backend calls remain disabled | `tests/test_services.gd`; `output/review/services_runtime.log` |
| Portrait interface | Pass: 540×960 and expanded 540×1110; comparison cards, one-tap input, measured buttons, HUD, local overlays and scrollable badges | `tests/ui_layout_test.gd`; `output/review/ui_layouts.json`; `shield-ui_runtime.log` |
| Audio | Pass: fixed 12-voice effect pool, mute/settings gates and music loop | `tools/test_audio.gd`; `output/review/audio_runtime.log` |
| Rendered acceptance views | Pass: Shield24 launch/restart cards, action, boss, pause, death and taller portrait screenshots | `tests/capture_game.gd`; `output/review/game_*.png`; `shield-capture_runtime.log` |
| Desktop rendering | About 60 FPS in ordinary play and at the 100-enemy/240-bullet caps | [Performance methods and before/after results](PERF.md) |
| Android functionality | Pass on Android 11 / API30 emulator: latest focused five-screen Shield24/saved-run follow-up; preceding full twelve-screen class suite retained separately; zero engine/script/fatal errors | `output/review/shield_damage_followup_report.json`, associated events/log/screens; earlier `classes_android_report.json` |

Gameplay checks cover touch ownership, slow-drag versus flick recognition, dash cooldown and protection, guard exhaustion/recharge/parry, damage grace, slash arc and single-hit rules, all behavior families, splitters, boss spawning under full load, radial escape gaps, rewards, upgrades, pickup expiry, pause/resume, death/restart and strict snapshot validation. Restored RNG state continues the same encounters and loot sequence.

Storage/adapter checks cover temporary and backup recovery, corrupt and future-version profiles, bounded history, known monster IDs, daily records and UTC score routing/rollover, monotonic cross-device progress merge, offline routes, native callback failures/timeouts and cloud readback before acknowledging a write. These adapter scenarios use controlled fake native clients; they do not establish that Google credentials or services work.

The preceding full Android class smoke used real ADB touch input to verify Sword80/32/0.36s/92px/65 and the then-current Shield170/18/0.60s/80px/165. Drag moved the knight 314.5 logical pixels; elapsed stayed at 8.05s through an 11.5-second pause. Local scores/badges, background return, process recovery and Android Back passed; twelve screenshots were reviewed. The current one-stat follow-up separately verified Shield170/24/0.60s/80px/165, migration of the retained version-two Shield18 run, persistence, current card text and Android Back with a live paused process. Its five screenshots and exact current APK hash are preserved separately. The isolated test emulator was stopped after each run.

Historical evidence remains separately identified: `game_runtime.log` records the earlier 199-check baseline; `game_validation_before_shield_buff.json` and `game_class_runtime.log` preserve the 274-check class revision; `android_test_report.json` records the original full ten-screen APK with Sword100/Shield125 HP; `android_latest_report.json` records the UTC leaderboard lookup follow-up; and `classes_android_report.json` records the twelve-screen distinct-class APK before the Shield damage increase. Earlier captures/checksums are not relabeled as proof of the current package.

## Performance scope

The rendered desktop benchmark uses an Intel i5-3570 and NVIDIA GT1030, OpenGL compatibility renderer, a 432×768 window and a 60 FPS cap. The saturated optimized result records a 16.726 ms 95th-percentile frame and about 317 drawing calls, down from about 1,184 and 24.2 FPS before batching. Original sheets remain intact; rendering uses one native-pixel monster atlas plus cached projectile/shadow textures. No combat entity caps were reduced to obtain this result.

The class revision passed a separate fifteen-second rendered saturated regression after five seconds of warmup, maintaining 100 enemies and 240 bullets: 60.056 FPS, 16.740ms 95th-percentile frame and 16.796ms 99th-percentile frame. Its simulation tick was 1.699ms at the 95th percentile. `output/review/class_rendered_benchmark.json` preserves that shorter regression separately from the earlier sixty-second measurements. No new rendered FPS claim is made for the damage-only follow-up. Its current five-minute headless simulation averaged 0.876ms per step, with a 1.494ms 95th percentile; these simulation timings are not measured Android frame rates.

The Android emulator uses WHPX and the host GLES3 translator. Its SwiftShader mode exposed an upstream Godot shader-uniform limitation and rendered blank; the host driver mode rendered correctly. See [Android testing notes](ANDROID_TESTING.md) for reproduction and the upstream issue. Physical ARM64 phone frame rate, battery use, thermal behavior, audio interruptions and device-specific safe areas still need hardware testing.

The restricted Windows test environment emits a root-certificate-store error before Godot uses its bundled certificates. Tests exit successfully; the Android game log has no such error. This host startup diagnostic is distinguished from gameplay, parsing and shader failures.

## Backend and distribution readiness

Google Play Games is gated off in `config/play_services.json` until the owner supplies real game/achievement/leaderboard IDs and linked credentials. The source includes the requested plugin and sign-in, score, achievement and snapshot adapter. Local progression stays usable while the backend is unavailable. Follow [Play Services setup](PLAY_SERVICES_SETUP.md) to enable and test the native integration.

`builds/InfiniteSlash-debug.apk` is a signed installable development build, not a Play release. Its current SHA-256 is `6f32e6ee556c10c739bbcacc4f4c4c92cc12d20bd72c2b8e0b2770e9e3cf3f84`, also recorded in the companion checksum file and Shield-damage follow-up Android report. [Build notes](ANDROID_BUILD.md) record package, size and SDK details. The future `AndroidPlay` AAB preset still needs the Gradle Android build template, native plugin inclusion, production signing, backend configuration and an actual release export/test before store submission.

Tests use disposable project fixtures and redirected user-data locations. They do not overwrite normal player saves or change the existing Android SDK, signing credentials or external emulator configurations. Reproduction commands are in the [README](../README.md) and the relevant test/build notes.
