# Android debug build

The playable offline APK is `builds/InfiniteSlash-debug.apk`. Exported on 2026-10-12 with Godot 4.5.1 using the installed official Android template and existing debug key. Godot completed APK alignment, signing, and signature verification successfully.

| Property | Verified value |
| --- | --- |
| Package | `org.infiniteslash.game` |
| Version | `0.1.0`, version code 1 |
| Minimum Android API | 24 |
| Target Android API | 35 |
| Architectures | ARM64 and x86 |
| APK size | 63,254,714 bytes (60.32 MiB) |
| Creature data | 100 generated records included |
| Render atlas | Imported monster atlas included |
| Play Games | Disabled configuration included; local gameplay and saves available |

Final build SHA-256: `a31d118a3978c5db5516f6e7cff4c9f846a29df2cbbdd7773e1c19dfe8492926`. The companion `builds/InfiniteSlash-debug.apk.sha256` records the checksum. This export includes the minimal launch overlay, cached bullet/shadow rendering, Android Back handling, deferred overlay changes, readable gold CTA text, toast cleanup, and UTC date selection for the optional native daily leaderboard. Google configuration remains disabled. The services suite passed all 82 assertions, including date routing and rollover; its final shutdown log has no ObjectDB/resource warnings.

Package inspection confirmed the main scene's binary remap, compiled combat/world/UI/audio/persistence/services scripts, vendor wrapper, monster JSON, disabled Play Games JSON, and imported atlas. Godot exports `.gd` scripts as `.gdc` and the main `.tscn` scene as a binary `.scn` with remap metadata. Tests, tools, docs, output fixtures, build files, editor settings and signing keys are excluded from the APK.

Run `tools/export_android.ps1` from PowerShell to reproduce the debug export. The helper discovers the installed engine version, copies its existing editor settings and Android templates into writable workspace storage, redirects application/cache folders for the export process, and restores the environment afterward. It also writes a companion SHA-256 file for the resulting package. It does not install tools, modify real editor settings, or create new signing keys. Parameters can override the Godot executable, source Godot configuration folder, preset, and APK output path.

The project enables `rendering/textures/vram_compression/import_etc2_astc`. Godot's Android exporter requires that import format on Windows; omitting it causes a configuration failure with an empty diagnostic. This fix is documented by the engine's [Android exporter](https://github.com/godotengine/godot/blob/4.5.1-stable/platform/android/export/export_plugin.cpp#L2756) and [texture import check](https://github.com/godotengine/godot/blob/4.5.1-stable/editor/import/resource_importer_texture_settings.cpp#L42).

Export evidence is stored in `output/review/android_export.log` and `android_export_stdout.log`. The preceding build (`0ae39d84…c3583b4`) passed the full ten-capture Android API30 emulator touch/lifecycle review. The current rebuild changes only an inactive backend date lookup and separately passed install, rendered launch, actual Shield start (125 maximum health), and Android Back pause with a live app process. Its three reviewed screenshots and error-free Android runtime log are recorded in `output/review/android_latest_report.json`, `android_latest_runtime.log`, and `android_latest_*.png`; the full earlier smoke retains its original checksum. See `ANDROID_TESTING.md` and `VERIFICATION.md` for methods and scope. No physical-phone frame-pacing, battery or thermal measurement is claimed. The debug APK is for development; the separately configured Gradle/Play preset needs release signing and Google configuration before a store build. See `PLAY_SERVICES_SETUP.md` for service activation.
