# Android build and test notes

The project uses Godot 4.5.1 with the compatibility renderer. Two export presets are provided:

| Preset | Purpose | Build | Architectures | SDK behavior |
|---|---|---|---|---|
| `AndroidDebug` | Installable development and emulator checks | Gradle, signed debug APK with native Play Games | ARM64 and x86 | Min API 24, compile/target API 36. |
| `AndroidPlay` | Play distribution | Gradle AAB with native Play Games; unsigned preparation exported | ARM64 | Min API 24, compile/target API 36. Owner upload signing is still required. |

Both presets use package **`com.slash.game`** and the supplied backend feature IDs. Current artifacts, fingerprints and native integration evidence are in [PLAY_SERVICES_IMPLEMENTATION.md](PLAY_SERVICES_IMPLEMENTATION.md) and [ANDROID_BUILD.md](ANDROID_BUILD.md). The configured gameplay suite passes 315 checks and the services suite passes 152 checks.

The current APK (`72951b06…9cec93`) passed an anonymous API 30 Android smoke run with eight visually reviewed screens, correct Sword 80 HP/32 damage and Shield 170 HP/24 damage, drag/flick, pause, Home/Back and local process recovery. The native singleton initialized; this emulator's outdated Google Play services returned unauthenticated. There were zero script/engine/fatal errors. Evidence is `output/review/native_android_events.json`, `native_android_runtime.log` and `output/android-test/native_pgs_smoke/`. No Google account or server result was tested. Static 16 KB packaging/library checks pass; the emulator uses 4 KB pages, so a real 16 KB runtime check remains outstanding.

Debug signing defaults to the local Godot editor's configured debug keystore. For automation, the supported `GODOT_ANDROID_KEYSTORE_DEBUG_PATH`, `GODOT_ANDROID_KEYSTORE_DEBUG_USER` and `GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD` environment variables can override it. Never commit a production keystore/password. Build outputs and emulator data are ignored by Git. `config/*.json` and `data/*.json` are explicitly included so runtime cloud ID mappings and the monster catalog remain available in exported packages.

On this development host, Java 17, Android SDK/build-tools 35 and 36, matching Godot 4.5.1 templates, and the API30 Google APIs x86 system image are already installed. The user's existing SDK and editor settings are read, not rewritten. Tests should redirect editor/user data and logs to a workspace folder when filesystem restrictions require it.

## Isolated emulator

`tools/android_test_emulator.ps1` creates/reuses only `output/android-test/avd/InfiniteSlash_Test.avd`. It sets `ANDROID_AVD_HOME` and `ANDROID_USER_HOME` within the checkout, supplies an explicit AVD path, and does not install SDK components or change Windows settings. `prepare` is the default action; `start` opens a headless emulator, and `stop` first checks the selected serial's AVD name. The console port defaults to 5580, producing serial `emulator-5580`.

```powershell
./tools/android_test_emulator.ps1 -Action prepare
./tools/android_test_emulator.ps1 -Action start
& 'C:/Users/swimr/AppData/Local/Android/Sdk/platform-tools/adb.exe' -s emulator-5580 shell getprop sys.boot_completed
```

The first cold boot was verified complete on 2026-10-12: Android 11/API30, physical 1080×2220 portrait display, `x86,armeabi-v7a,armeabi` ABI list. Logs confirm WHPX operational and Google SwiftShader OpenGL ES 3.0. First boot spent several minutes compiling platform packages. It used substantial RAM, so it was stopped during monster generation and should run only when ready to test an APK. It is a functional test target, not evidence of battery, thermal or physical-phone performance.

The first game launch under `swiftshader_indirect` exposed the engine's known shader-uniform limit failure: Godot's internal Scene/Canvas GLES shaders exceeded `GL_MAX_FRAGMENT_UNIFORM_VECTORS (261)` and rendered a blank screen. This matches [upstream Godot issue 109550](https://github.com/godotengine/godot/issues/109550). The isolated AVD was restarted with the existing host NVIDIA driver; its GLES3 translator renders the game correctly. The helper therefore defaults to `-Gpu host`, while `-Gpu swiftshader_indirect` remains available for OS-only diagnostics. No Windows setting, SDK component or external AVD was changed. Test hardware/renderer compatibility explicitly when preparing a release, including any Play prelaunch software-renderer reports.

## Functional smoke captures

Run `tests/ui_layout_test.gd` in Godot before the Android smoke test. It emits `output/review/ui_layouts.json` with actual named Control rectangles at 540×960 and 540×1110. The smoke script maps these measured buttons to the emulator display instead of assuming fixed pixel positions. It addresses only the explicit emulator serial and never clears app data or restarts the global ADB server.

```powershell
python ./tools/android_smoke.py --adb 'C:/Users/swimr/AppData/Local/Android/Sdk/platform-tools/adb.exe' --serial emulator-5580 --apk ./builds/InfiniteSlash-debug.apk
```

The script captures launch, action, drag/flick/guard, pause, local scores, badges, background return and process-recovery screens. It checks boot/install/process/runtime-error status and saves timestamped actions plus process logs under `output/android-test/smoke`. The current independent class oracle checks fresh Sword stats 80 HP/32 damage/0.36s cadence/92px reach/65 guard and Shield 170/24/0.60s/80px/165 guard, plus snapshot balance version three. If the retained fixture is an original level-one run, it also exercises real migration before starting either fresh class. The optional `--verify-shield-resume-buff` checks a retained version-two Shield18 run's damage-only adjustment before the fresh-class check. Inspect every screenshot before describing the run as accepted; a captured input alone does not prove a game behavior. For existing active-run profiles, it reads only this debug app's private save to choose the correct launch layout. It force-stops only the tested package after saving/backgrounding, then relaunches to exercise recovery.

### Historical full touch and recovery run: 2026-10-12

The older runs below retain their original APK hashes and package/balance/service settings. They are evidence for those earlier builds, not the current native APK. References to “current” within those historical records refer to the build tested at that time.

**PASS** on the isolated API30 emulator with the host GLES3 renderer. The exact tested APK SHA-256 is `0ae39d84dce696e1f766bfd1b659dd14b59e8df8a0bd0e76998cae043c3583b4`. All ten screenshots were visually reviewed, including the actual scrolling thirteen-badge panel, dark text on gold resume/pause buttons, and an actual paused arena after Android Back. The game process remained alive afterward (PID 5712 before emulator shutdown).

Verified actual Android sword and shield choices start with 100 and 125 maximum health respectively; drag/flick input moved the knight 291.3 logical pixels; paused simulation elapsed remained 9.55s through an 11.5s wait; backgrounding preserved the run; and force-stop/relaunch retained style, elapsed, score, health and player position. Debug UI state markers confirm the native touch routes entered scores, badges, return-to-pause, resume and Android Back pause. The combined process logs contain zero Godot engine errors, script errors, fatal exceptions or fatal signals. Native lifecycle messages are retained in the log.

Versionable evidence is in `output/review/android_test_report.json`, `android_smoke_events.json`, `android_runtime.log`, and `android_01_launch.png` through `android_10_android_back_pause.png`. The final launch capture includes Resume because the previous test's active run was deliberately preserved; the fresh launch with only Sword/Shield was also inspected earlier, and the same layout is covered by the desktop UI test. This is functional emulator evidence. No physical-phone performance, battery or thermal measurement was made.

### Original final-package follow-up: 2026-10-12

The original final APK added a correction to the optional native `daily_score` lookup so it uses UTC consistently with gameplay. Its SHA-256 is `a31d118a3978c5db5516f6e7cff4c9f846a29df2cbbdd7773e1c19dfe8492926`. This exact package was installed and accepted in a separate short check: launch rendered correctly, the actual Shield tap started with 125 maximum health, and Android Back opened the paused arena while the app process stayed alive (PID 4604). All three screenshots were visually reviewed and logs contain zero engine/script/fatal errors. The cloud configuration remains disabled.

That follow-up is preserved separately in `output/review/android_latest_report.json`, `android_latest_events.json`, `android_latest_runtime.log`, and `android_latest_*.png`. The earlier full ten-screen proof remains associated with its earlier hash rather than being relabeled as captures from this rebuilt package. The test emulator was stopped after both accepted runs.

### Preceding Sword/Shield class revision: 2026-10-12

**PASS** on the same isolated Android 11/API30 emulator using WHPX and the host GLES3 translator. That class-revision APK SHA-256 is `0e511b1922800bd5553eaad142f3159cbf87f32eda1c6052f4ff89856191f378`, with a size of 63,263,069 bytes. Its compiled shared class profile is present in the package. All twelve screenshots were visually reviewed: new class cards/arrows and stats fit the native portrait display, the HUD shows the appropriate icon/health, Sword has a larger blade and Shield a larger shield, and the local/lifecycle screens render correctly.

The emulator retained an original level-one Shield run with 125 maximum health and no balance version. Actual Resume touch input migrated it to version two, 170 maximum health, 18 damage, 0.60-second swings, 80px reach and 165 guard, while preserving its seed and prior progress. It paused/saved and relaunched correctly before the fresh-class checks. The fresh Sword tap independently verified 80 HP, 32 damage, 0.36-second swings, 92px reach and 65 guard; fresh Shield independently verified its corresponding new stats. Controlled health/guard fraction and upgraded-level migration comparisons are covered by the gameplay suite.

Real drag/flick input moved the knight 314.5 logical pixels. Simulation elapsed stayed at 8.05s through an 11.5-second pause; scores and the thirteen-badge scroll panel opened via actual touch; background return stayed paused; force-stop/relaunch preserved style, elapsed, score, health and position; and Android Back opened the Shield pause overlay with the app still alive (PID4985). Combined native process logs have zero Godot engine errors, script errors, fatal exceptions or fatal signals. The test emulator was then stopped safely.

The separate versionable evidence is `output/review/classes_android_report.json`, `classes_android_events.json`, `classes_android_runtime.log`, and `classes_android_*.png`. Earlier baseline/follow-up reports above retain their exact prior hashes and original 100/125 starting-health results; they are not relabeled as evidence of the class revision. Reproduce the full revision run with:

```powershell
./tools/android_test_emulator.ps1 -Action start -Gpu host
python ./tools/android_smoke.py --adb 'C:/Users/swimr/AppData/Local/Android/Sdk/platform-tools/adb.exe' --serial emulator-5580 --apk ./builds/InfiniteSlash-debug.apk --output ./output/android-test/classes-smoke
./tools/android_test_emulator.ps1 -Action stop
```

The optional legacy-resume branch requires the preserved original level-one fixture; fresh installs still exercise both new classes, touch input and lifecycle recovery. The class revision has functional emulator coverage, with physical-phone GPU/battery/thermal testing still outstanding.

### Shield damage follow-up: 2026-10-12

**PASS** for the current APK SHA-256 `6f32e6ee556c10c739bbcacc4f4c4c92cc12d20bd72c2b8e0b2770e9e3cf3f84`, still 63,263,069 bytes. Only Shield's starting damage changed from 18 to 24; its health, cadence, movement, reach, guarding and all upgrade caps stayed unchanged. A focused follow-up was appropriate after the preceding full suite, with separate evidence rather than attributing the old twelve captures to this package.

The retained paused version-two Shield18 run was resumed through actual touch. It recorded damage24/balance-version-three while retaining maximum health170, cadence0.60s, reach80px, guard165, style, seed and level. Its elapsed time continued rather than resetting. The migrated damage/version remained saved across force-stop/relaunch. A fresh Shield tap then independently verified 170/24/0.60s/80px/165, and Android Back opened a live paused game (PID4214). Five screenshots were visually reviewed, including card text showing `170 HP · 24 DMG`, resumed-save pause, relaunch, fresh Shield and Back pause. The combined process log has zero engine/script/fatal errors; the isolated emulator was stopped afterward.

Evidence is `output/review/shield_damage_followup_report.json`, `shield_damage_followup_events.json`, `shield_damage_followup_runtime.log` and `shield_damage_followup_*.png`. The current gameplay suite separately passes 315 checks, covering version-two Shield's once-only damage adjustment, unchanged Sword damage, preservation of the other saved stats/progress and version-three restore idempotence. No new rendered FPS, phone GPU/battery or thermal measurement was made for this one-stat tuning change.

```powershell
./tools/android_test_emulator.ps1 -Action start -Gpu host
python ./tools/android_smoke.py --adb 'C:/Users/swimr/AppData/Local/Android/Sdk/platform-tools/adb.exe' --serial emulator-5580 --apk ./builds/InfiniteSlash-debug.apk --output ./output/android-test/shield-damage-followup --quick
./tools/android_test_emulator.ps1 -Action stop
```

Add `--verify-shield-resume-buff` only when the selected isolated app fixture still contains a version-two Shield18 run. A previously migrated version-three fixture intentionally does not meet that old-run prerequisite.

## Remaining release verification

The current debug APK and unsigned release AAB have been built and inspected with the native plugin, package identity, API 36 and supplied backend IDs. A Play release still needs the owner's upload signing, an unused version code, eligible tester access and real sign-in/achievement/leaderboard/cloud tests. Install through Play to use the supplied Play App Signing certificate, or register the actual debug signer for sideload tests. Publish the Play Games configuration separately when ready. See [PLAY_SERVICES_SETUP.md](PLAY_SERVICES_SETUP.md). Check current [Google Play target SDK requirements](https://developer.android.com/google/play/requirements/target-sdk), [Godot Android export options](https://docs.godotengine.org/en/4.5/classes/class_editorexportplatformandroid.html), and [Godot's Android export guide](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html) when preparing a release.

Before release, test actual ARM64 Android phones for touch responsiveness, safe areas, rotation lock, Android back/background/resume, audio focus, interruptions, prolonged bullet-heavy play, startup time, thermal/battery load and offline persistence. Emulator timing should never be presented as a measured midrange-device FPS result.
