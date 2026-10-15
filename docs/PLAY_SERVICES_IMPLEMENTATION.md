# InfiniteSlash native Play Games implementation

The **2026-10-15 / version 0.2.0** update is documented in [ROUND2_UPDATES.md](ROUND2_UPDATES.md), with rebuilt package hashes and Android results in [ROUND2_ANDROID.md](ROUND2_ANDROID.md). Package sizes, version codes and Android captures below describe the preceding builds; use the newer report for this update.

The game now uses the supplied Play Games project `832658811620` and Android package `com.slash.game`. Native sign-in, achievements, leaderboards and saved profiles are enabled. The three configured leaderboards and twelve achievements are in `config/play_services.json`; daily scores and the duplicate 180-second achievement remain omitted. The confirmed incremental totals are 100 enemies, 100 monster discoveries, 1,000 lifetime kills and 10 runs. Longest Run sends whole seconds to the zero-decimal numeric leaderboard.

## Native build and saved-game behavior

Both Android presets use the editor plugin, one existing runtime wrapper autoload, Gradle, minimum API 24 and target API 36. The launch icon uses `Assets/Brand/launcher_icon.png`. The export plugin adds the game ID in `android/build/res/values/godot_play_services.xml` and the Android application metadata. It preserves the template's app-name strings.

The native bridge is a local MIT-licensed fork of [Godot Play Game Services v3.4.0](https://github.com/godot-sdk-integrations/godot-play-game-services/releases/tag/v3.4.0), pinned to upstream commit `e38b618578572b558691c4f476f70f5e142226ce`. The reproducible source changes are `native/pgs/play_games_v3_4_0.patch`; the upstream license is retained in `native/pgs/LICENSE`. The packaged debug and release AARs include these fixes:

- Both snapshot opens use manual conflict resolution so neither profile branch is selected before the game merges it.
- Native `resolveConflict(conflictId, description, bytes, playedTimeMillis, progressValue)` retains SDK snapshot handles and uses the SDK's four-argument conflict-resolution call with merged data. The wrapper exposes `supports_conflict_resolution()` and `resolve_conflict(...)`.
- `game_saved` acknowledges success only after `commitAndClose` finishes. Open, write, resolve and commit failures report failure.
- Loaded snapshots close in `finally`. Failed resolution and conflict reads release their handles; abandoned conflicts retain at most four native entries. Repeated conflicts re-enter the game's bounded retry flow.
- `game_load_failed(file_name, message)` distinguishes failed reads and unknown open errors from the documented missing-save result. The adapter preserves local progress and suspends cloud writes on failure. Unpatched older binaries retain the existing timeout fallback.

Cloud saves contain profile progression rather than an active combat run or device preferences. The adapter validates both conflicting profiles, merges bounded progression, keeps account ownership checks and verifies completed writes. Local gameplay and saving continue when Google Play authentication is unavailable.

## Rebuilding

Use `tools/prepare_native_android.py` to prepare the locally installed, matching Godot 4.5.1 Android source template. It upgrades the app build to Android Gradle Plugin 8.10.1, Gradle 8.11.1 and API/Build Tools 36, while retaining the installed Godot engine binaries and Java 17. [AGP 8.10 supports API 36 and requires Gradle 8.11.1 and Java 17](https://developer.android.com/build/releases/agp-8-10-0-release-notes). Native plugin compilation uses `tools/build_play_games_plugin.ps1`, its pinned source patch and an isolated dependency cache under `output/test-data`.

Debug export: `tools/export_android.ps1 -Preset AndroidDebug`. Unsigned release preparation: `tools/export_android.ps1 -Preset AndroidPlay -Release -Unsigned -OutputPath builds/InfiniteSlash-play-unsigned.aab`. The unsigned helper temporarily changes only the Play signing flag and restores it afterward. Supply the owner's upload-keystore configuration locally before producing an uploadable release. Never commit signing passwords, Google credentials, client secrets or service-account keys.

## Signing and remaining console checks

The sideload debug APK uses this public certificate:

- SHA-1: `62:EE:05:F2:CA:C9:95:36:48:BF:3A:D7:C8:22:55:8C:C6:33:CD:24`
- SHA-256: `83:82:EC:1C:56:49:4E:B3:51:41:E0:ED:29:98:6D:2E:C5:00:9C:52:9B:09:6A:2F:D6:0D:5F:C5:C5:21:3E:4F`

Register an additional Android OAuth credential for **this certificate plus `com.slash.game`** to test sideload debug builds. The owner-confirmed SHA-1 `A1:CD:9D:32:4A:E8:AE:3E:38:38:D3:FB:7D:AF:70:F7:DD:46:64:DB` belongs to Google Play App Signing and applies to builds installed through Play. It cannot sign this local debug build. [Google's Play Games setup guide](https://developer.android.com/games/pgs/console/setup) explains Android credentials and certificate binding.

The owner confirmed Saved Games is enabled, the four incremental achievement targets and Longest Run's whole-second format. Required API enablement and eligible tester access still need verification in the Console. The release upload keystore is still absent. The current version code is `1`; choose a higher unused version code if the Play app already has an uploaded build. Real account sign-in, achievement/leaderboard server results, cross-device saves, account changes and a real server conflict require an authorized account and correctly signed installation. IDs and offline callback tests alone do not establish those results.

## Verification and limits

The configured gameplay suite passed 315 checks; the Play Games adapter suite passed 152 checks. The native debug and release AARs compile against the SDK. Android artifact and device results are recorded below.

API 36 is selected for the [current Play target-SDK requirement](https://developer.android.com/google/play/requirements/target-sdk). Static inspection of the ARM64 libraries passes 16 KB LOAD alignment; the APK passes `zipalign -P 16`, and `bundletool dump config` confirms `PAGE_ALIGNMENT_16K` with uncompressed native libraries. Both engine libraries' RELRO ends have a nonzero raw modulo, but each RELRO covers its entire LOAD segment. This is an accepted exception in the [Android linker](https://android.googlesource.com/platform/bionic/+/android16-qpr2-release/linker/linker_phdr_16kib_compat.cpp#427), so the raw modulo alone is not a compatibility failure. No ELF headers were modified. The corrected assessment is in `output/review/native_artifacts.json`.

A real 16 KB device run remains unperformed: the tested emulator reports a 4,096-byte page size. Static packaging and ELF checks do not establish runtime behavior on a 16 KB phone. Follow Google's [16 KB testing guidance](https://developer.android.com/guide/practices/page-sizes) before release certification.

### Export and device evidence

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `builds/InfiniteSlash-debug.apk` | 182,695,870 bytes | `72951b0643fd45378bfa599dd649e9beebc4acf6f1160b85d00260caba9cec93` |
| `builds/InfiniteSlash-play-unsigned.aab` | 35,581,852 bytes | `9c02290ec456b0ff7f101f7a69f4521b183f14d326eb434b14db96d6c2062900` |
| Debug native AAR | 88,321 bytes | `75b9ec61c3d8e013c8ca2eb150782e33519144dee94713b44f96147f2de55ee9` |
| Release native AAR | 84,195 bytes | `1f5545274a8b532e24d1f4489345dc8af0e63a1cd506893f85da34dfceb2f708` |

The APK has a valid internal debug signature matching the public certificate above, ARM64 plus x86 libraries, package `com.slash.game`, compile/target API 36 and minimum API 24. Its manifest registers the native Godot plugin and Google initializer, and the APP_ID resource resolves to `832658811620`. The patched bridge methods/signals and Google SDK classes are present in DEX. The stale signature sidecar from the previous APK was removed; each artifact has an adjacent current `.sha256` file.

The release bundle is ARM64 only and has **no signing certificate**. It is a preparation artifact, not an uploadable signed production bundle. Both presets' normal signing flags were restored after export. Exact package metadata, signer, bundle manifest/configuration and structure checks are in `output/review/native_apk_*`, `native_bundle_*` and `native_artifacts.json`.

Anonymous Android smoke passed on the isolated API 30 Google APIs x86 emulator at 1080×2220 using host GPU rendering. The native singleton initializes and its authentication callback returns false; this image's installed Google Play services are outdated. Gameplay continues with local saving. Sword starts with 80 HP/32 damage and Shield with 170 HP/24 damage. Drag/flick movement, a stationary pause longer than the autosave interval, Android Home/Back and exact local profile recovery after process restart passed with zero script, Godot fatal or native crash errors. All eight captured screens were visually reviewed. This is functional emulator evidence, not phone performance certification or server account verification.

Evidence: `output/review/native_android_events.json`, `native_android_runtime.log`, and screenshots under `output/android-test/native_pgs_smoke`. The Play Store image was also available, but its secure local ADB authorization prompt prevented automated guest access, so the established Google APIs image was used for this anonymous check. No Google account was logged in. Both owned test emulators and the temporary isolated ADB server were stopped afterward.
