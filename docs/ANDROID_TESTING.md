# Android build and test notes

The project uses Godot 4.5.1 with the compatibility renderer. Two export presets are provided:

| Preset | Purpose | Build | Architectures | SDK behavior |
|---|---|---|---|---|
| `AndroidDebug` | Installable offline MVP and emulator checks | Signed debug APK using the installed prebuilt template | ARM64 and x86 | Uses the prebuilt template's own SDK defaults. Godot rejects explicit min/target SDK overrides when Gradle is disabled. |
| `AndroidPlay` | Future Play distribution configuration | Gradle AAB, release signing unset | ARM64 | Min API 24 (the Godot 4.5 engine floor), target API 36; requires installing the matching Godot Android build template into this project and supplying release signing/backend IDs. |

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

The script captures launch, action, drag/flick/guard, pause, local scores, badges, background return and process-recovery screens. It checks boot/install/process/runtime-error status and saves timestamped actions plus process logs under `output/android-test/smoke`. Inspect every screenshot before describing the run as accepted; a captured input alone does not prove a game behavior. For existing active-run profiles, it reads only this debug app's private save to choose the correct launch layout. It force-stops only the tested package after saving/backgrounding, then relaunches to exercise recovery.

### Full touch and recovery run: 2026-10-12

**PASS** on the isolated API30 emulator with the host GLES3 renderer. The exact tested APK SHA-256 is `0ae39d84dce696e1f766bfd1b659dd14b59e8df8a0bd0e76998cae043c3583b4`. All ten screenshots were visually reviewed, including the actual scrolling thirteen-badge panel, dark text on gold resume/pause buttons, and an actual paused arena after Android Back. The game process remained alive afterward (PID 5712 before emulator shutdown).

Verified actual Android sword and shield choices start with 100 and 125 maximum health respectively; drag/flick input moved the knight 291.3 logical pixels; paused simulation elapsed remained 9.55s through an 11.5s wait; backgrounding preserved the run; and force-stop/relaunch retained style, elapsed, score, health and player position. Debug UI state markers confirm the native touch routes entered scores, badges, return-to-pause, resume and Android Back pause. The combined process logs contain zero Godot engine errors, script errors, fatal exceptions or fatal signals. Native lifecycle messages are retained in the log.

Versionable evidence is in `output/review/android_test_report.json`, `android_smoke_events.json`, `android_runtime.log`, and `android_01_launch.png` through `android_10_android_back_pause.png`. The final launch capture includes Resume because the previous test's active run was deliberately preserved; the fresh launch with only Sword/Shield was also inspected earlier, and the same layout is covered by the desktop UI test. This is functional emulator evidence. No physical-phone performance, battery or thermal measurement was made.

### Final package follow-up: 2026-10-12

The final APK contains a subsequent correction to the optional native `daily_score` lookup so it uses UTC consistently with gameplay. Its SHA-256 is `a31d118a3978c5db5516f6e7cff4c9f846a29df2cbbdd7773e1c19dfe8492926`. This exact package was installed and accepted in a separate short check: launch rendered correctly, the actual Shield tap started with 125 maximum health, and Android Back opened the paused arena while the app process stayed alive (PID 4604). All three screenshots were visually reviewed and logs contain zero engine/script/fatal errors. The cloud configuration remains disabled.

That follow-up is preserved separately in `output/review/android_latest_report.json`, `android_latest_events.json`, `android_latest_runtime.log`, and `android_latest_*.png`. The earlier full ten-screen proof remains associated with its earlier hash rather than being relabeled as captures from this rebuilt package. The test emulator was stopped after both accepted runs.

## Remaining release verification

The debug APK is an MVP test build. A Play release still needs an owner-controlled package identity, production signing, backend IDs/configuration, the Play Games plugin's Gradle inclusion, and cloud/leaderboard tests with authorized test accounts. The Play preset is configuration intent until its actual AAB is built and inspected. Check current [Google Play target SDK requirements](https://developer.android.com/google/play/requirements/target-sdk), [Godot Android export options](https://docs.godotengine.org/en/4.5/classes/class_editorexportplatformandroid.html), and [Godot's Android export guide](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html) when preparing a release. The API36 setting reflects requirements reviewed in October 2026, not a store-ready guarantee.

Before release, test actual ARM64 Android phones for touch responsiveness, safe areas, rotation lock, Android back/background/resume, audio focus, interruptions, prolonged bullet-heavy play, startup time, thermal/battery load and offline persistence. Emulator timing should never be presented as a measured midrange-device FPS result.
