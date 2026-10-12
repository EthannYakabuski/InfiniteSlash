# Android debug build

The playable offline APK is `builds/InfiniteSlash-debug.apk`. Exported on 2026-10-12 with Godot 4.5.1 using the installed official Android template and existing debug key. Godot completed APK alignment, signing, and signature verification successfully.

| Property | Verified value |
| --- | --- |
| Package | `org.infiniteslash.game` |
| Version | `0.1.0`, version code 1 |
| Minimum Android API | 24 |
| Target Android API | 35 |
| Architectures | ARM64 and x86 |
| APK size | 63,263,069 bytes (60.33 MiB) |
| Creature data | 100 generated records included |
| Render atlas | Imported monster atlas included |
| Play Games | Disabled configuration included; local gameplay and saves available |

Current build SHA-256: `6f32e6ee556c10c739bbcacc4f4c4c92cc12d20bd72c2b8e0b2770e9e3cf3f84`. The companion `builds/InfiniteSlash-debug.apk.sha256` records the checksum. This follow-up changes Shield's starting damage from 18 to 24, retaining every other class stat and upgrade cap. Version-three snapshots give existing version-two Shield runs the increase once while preserving their other stats/progress. Readable Sword/Shield comparison cards, distinct weapon silhouettes, shared upgrade limits and earlier MVP fixes remain included. Google configuration remains disabled. The current gameplay suite passed 315 checks; the unchanged services suite retains its 82-assertion result.

Package inspection confirmed the main scene's binary remap, compiled combat/world/UI/audio/persistence/services scripts, vendor wrapper, monster JSON, disabled Play Games JSON, and imported atlas. The current package also includes `assets/scripts/class_profiles.gdc` and its `.gd.remap`. Godot exports `.gd` scripts as `.gdc` and the main `.tscn` scene as a binary `.scn` with remap metadata. Tests, tools, docs, output fixtures, build files, editor settings and signing keys are excluded from the APK. Current package metadata again confirms API24 minimum, API35 target, ARM64 and x86.

Run `tools/export_android.ps1` from PowerShell to reproduce the debug export. The helper discovers the installed engine version, copies its existing editor settings and Android templates into writable workspace storage, redirects application/cache folders for the export process, and restores the environment afterward. It also writes a companion SHA-256 file for the resulting package. It does not install tools, modify real editor settings, or create new signing keys. Parameters can override the Godot executable, source Godot configuration folder, preset, and APK output path.

The project enables `rendering/textures/vram_compression/import_etc2_astc`. Godot's Android exporter requires that import format on Windows; omitting it causes a configuration failure with an empty diagnostic. This fix is documented by the engine's [Android exporter](https://github.com/godotengine/godot/blob/4.5.1-stable/platform/android/export/export_plugin.cpp#L2756) and [texture import check](https://github.com/godotengine/godot/blob/4.5.1-stable/editor/import/resource_importer_texture_settings.cpp#L42).

Export evidence is stored in `output/review/android_export.log` and `android_export_stdout.log`. This exact APK passed a focused Android API30 emulator follow-up with five visually reviewed screenshots. A retained version-two Shield18 run resumed as Shield24/version-three with health170, cadence0.60s, reach80px, guard165, style/seed/level and progress retained; the adjusted damage persisted across process restart. Fresh Shield24 and Android Back pause also passed, with zero engine/script/fatal errors and a live app (PID4214). Evidence is `output/review/shield_damage_followup_report.json`, associated events/runtime log and `shield_damage_followup_*.png`. The emulator was stopped afterward.

Earlier evidence is retained separately: build `0ae39d84…c3583b4` passed the original full ten-capture suite; build `a31d118a…8492926` passed the daily lookup follow-up; build `0e511b19…191f378` passed the distinct-class full twelve-capture suite, including the original Shield125→170 HP migration, touch input, pause, local scores/badges, background/process recovery and Android Back. That preceding class report is `classes_android_report.json`; its 18-damage Shield results are not relabeled as current-package evidence. See `ANDROID_TESTING.md` and `VERIFICATION.md` for methods and scope. No new rendered FPS or physical-phone frame-pacing/battery/thermal measurement is claimed for this damage-only change. The debug APK is for development; the separately configured Gradle/Play preset needs release signing and Google configuration before a store build. See `PLAY_SERVICES_SETUP.md` for service activation.
