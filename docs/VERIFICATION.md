# MVP verification

Verified on 2026-10-12 with Godot 4.5.1. The portrait game is playable from launch through death and immediate restart. The Android development APK, source project, original monster exports, optimized rendering atlas and test tools are included.

## Implemented experience

Launch offers Sword and Shield over the arena. Drag anywhere to move while attacks happen automatically; release to guard and make a deliberate quick flick to dash. Combat includes eight monster behaviors, escalating waves, recurring crowned bosses, scrolling seasonal scenery, healing, six temporary buffs, XP upgrades, combos, sound effects and original looping music. Scores, 13 local badges, discoveries, daily UTC runs, settings and recoverable active runs persist offline.

The supplied four-frame creature is preserved and used as Cinder Tinpot. Exactly 100 additional creatures were exported through Creature Mixer's full Randomize and Save spritesheet workflow at 8×. Each has a unique name, original transparent animated sheet and combat data. Both file hashes and decoded pixel hashes confirm uniqueness. See [asset review](ASSET_REVIEW.md), [roster](MONSTER_ROSTER.md) and `output/review/monster_roster.png`.

## Checks and evidence

| Check | Result | Evidence |
| --- | --- | --- |
| Monster assets and music | Pass: 100 unique animated transparent sheets, original preserved, correct stats, unclipped 32-second loop | `tools/validate_assets.py`; `output/review/asset_validation.json` |
| Actual gameplay scene | Pass: 199 checks, zero failures | `tests/test_game.gd`; `output/review/game_validation.json`; `game_runtime.log` |
| Continuous simulation | Pass: 18,000 fixed steps / five simulated minutes; finite state and caps maintained | Peak 100 enemies, 240 bullets, 60 pickups, 90 effects in the gameplay report |
| Local storage and Play adapter | Pass: 82 checks, zero failures; real-backend calls remain disabled | `tests/test_services.gd`; `output/review/services_runtime.log` |
| Portrait interface | Pass: 540×960 and expanded 540×1110; measured buttons, HUD, local overlays and scrollable badges | `tests/ui_layout_test.gd`; `output/review/ui_layouts.json`; `ui_runtime.log` |
| Audio | Pass: fixed 12-voice effect pool, mute/settings gates and music loop | `tools/test_audio.gd`; `output/review/audio_runtime.log` |
| Rendered acceptance views | Pass: launch, action, boss, pause, death and taller portrait screenshots | `tests/capture_game.gd`; `output/review/game_*.png`; `render_capture.log` |
| Desktop rendering | About 60 FPS in ordinary play and at the 100-enemy/240-bullet caps | [Performance methods and before/after results](PERF.md) |
| Android functionality | Pass on Android 11 / API30 emulator: full ten-screen review plus a separate final-package launch/Back regression; zero engine/script/fatal errors | `output/review/android_test_report.json`, `android_latest_report.json`, associated events/logs/screenshots |

Gameplay checks cover touch ownership, slow-drag versus flick recognition, dash cooldown and protection, guard exhaustion/recharge/parry, damage grace, slash arc and single-hit rules, all behavior families, splitters, boss spawning under full load, radial escape gaps, rewards, upgrades, pickup expiry, pause/resume, death/restart and strict snapshot validation. Restored RNG state continues the same encounters and loot sequence.

Storage/adapter checks cover temporary and backup recovery, corrupt and future-version profiles, bounded history, known monster IDs, daily records and UTC score routing/rollover, monotonic cross-device progress merge, offline routes, native callback failures/timeouts and cloud readback before acknowledging a write. These adapter scenarios use controlled fake native clients; they do not establish that Google credentials or services work.

The Android smoke run uses real ADB touch input into the installed game. It verifies Sword health 100, Shield health 125, movement, a pause lasting at least 11.5 seconds without simulation advancing, local scores and all 13 badges, background return paused, process-stop/relaunch recovery, and Android Back leaving a live paused game. The final package was installed and checked again for rendered launch, Shield health, and Back preserving a live paused process. Its only runtime change after the full suite is the UTC date lookup in the disabled backend. The reports preserve each package's checksum separately. The isolated test emulator is stopped after testing.

## Performance scope

The rendered desktop benchmark uses an Intel i5-3570 and NVIDIA GT1030, OpenGL compatibility renderer, a 432×768 window and a 60 FPS cap. The saturated optimized result records a 16.726 ms 95th-percentile frame and about 317 drawing calls, down from about 1,184 and 24.2 FPS before batching. Original sheets remain intact; rendering uses one native-pixel monster atlas plus cached projectile/shadow textures. No combat entity caps were reduced to obtain this result.

The Android emulator uses WHPX and the host GLES3 translator. Its SwiftShader mode exposed an upstream Godot shader-uniform limitation and rendered blank; the host driver mode rendered correctly. See [Android testing notes](ANDROID_TESTING.md) for reproduction and the upstream issue. Physical ARM64 phone frame rate, battery use, thermal behavior, audio interruptions and device-specific safe areas still need hardware testing.

The restricted Windows test environment emits a root-certificate-store error before Godot uses its bundled certificates. Tests exit successfully; the Android game log has no such error. This host startup diagnostic is distinguished from gameplay, parsing and shader failures.

## Backend and distribution readiness

Google Play Games is gated off in `config/play_services.json` until the owner supplies real game/achievement/leaderboard IDs and linked credentials. The source includes the requested plugin and sign-in, score, achievement and snapshot adapter. Local progression stays usable while the backend is unavailable. Follow [Play Services setup](PLAY_SERVICES_SETUP.md) to enable and test the native integration.

`builds/InfiniteSlash-debug.apk` is a signed installable development build, not a Play release. Its SHA-256 is `a31d118a3978c5db5516f6e7cff4c9f846a29df2cbbdd7773e1c19dfe8492926`, also recorded in the companion checksum file and final-package Android report. [Build notes](ANDROID_BUILD.md) record package, size and SDK details. The future `AndroidPlay` AAB preset still needs the Gradle Android build template, native plugin inclusion, production signing, backend configuration and an actual release export/test before store submission.

Tests use disposable project fixtures and redirected user-data locations. They do not overwrite normal player saves or change the existing Android SDK, signing credentials or external emulator configurations. Reproduction commands are in the [README](../README.md) and the relevant test/build notes.
