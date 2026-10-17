# Production Android verification — 0.3.0

Verified on 2026-10-16 after the final gameplay, 103-card upgrade catalog, save migration and rendering changes. These results describe the files below. Earlier Android reports remain historical evidence for their respective builds.

## Deliverables

| Artifact | Purpose | Architectures | Bytes |
| --- | --- | --- | ---: |
| `builds/InfiniteSlash-debug-0.3.0.apk` | Signed installable development build | ARM64, x86 | 182,935,394 |
| `builds/InfiniteSlash-play-0.3.0.aab` | Signed Play upload bundle | ARM64 | 36,167,239 |

Both use package `com.slash.game`, version name **0.3.0**, version code **8**, Godot **4.5.1**, minimum Android API **24**, and compile/target API **36**. The default `builds/InfiniteSlash-debug.apk` was updated to the byte-identical verified 0.3.0 APK after the native smoke passed. Adjacent `.sha256` files identify each package.

Debug APK SHA-256:

```text
c8e9bfd09202453f58b388547477a88019c3078318570f1635478fd2fc732667
```

Signed Play AAB SHA-256:

```text
4dd61060ad0150ddd5cec124289723a122e49f7a14966f45d87f7be1dc41c33f
```

The previous default debug APK is preserved as `builds/InfiniteSlash-debug-0.2.1.apk`, SHA-256 `786f838d8750cb5fabe5a1f10396ee862b498bda3be3192bd0c39de7bdb64a58`. All other pre-existing versioned and unversioned Play artifacts retain their recorded hashes. The older unversioned `InfiniteSlash-play.aab` was not replaced; use the explicitly versioned **0.3.0 AAB** above.

## Actual package checks

`tools/verify_production_native.py` returned `PRODUCTION_NATIVE_ARTIFACTS_PASS`. It inspected the final APK and AAB rather than inferring their contents from source files:

- ZIP CRC integrity, actual manifests, API levels, package identity and version metadata passed.
- Packaged Play Games configuration exactly matches `config/play_services.json`: project 832658811620, the existing **14 configured achievements** and **3 configured leaderboards**. New milestone and leaderboard IDs remain deliberately blank pending owner-created resources; local tracking is present.
- Each package contains all **200 generated creature records**, including the 50 stage-2 specialists and 50 night creatures, plus the imported atlas. The original Tinpot is appended at runtime as roster entry 201; its native snapshot restoration also passed below.
- The required compiled gameplay, progression, class, UI, hazard, catalog and persistence scripts are included. All **11 main compiled scripts match byte-for-byte between APK and AAB**. Fifteen frozen runtime/data/atlas source hashes remained unchanged after export.
- The actual DEX contains the Godot Play Games native plugin, Google Games SDK, conflict-resolution method and snapshot-load-failure signal.
- Tests, tools, reports and store-kit files are excluded from the packages.

The APK passed `apksigner verify`, public debug certificate SHA-1 `62:EE:05:F2:CA:C9:95:36:48:BF:3A:D7:C8:22:55:8C:C6:33:CD:24`. The AAB passed `jarsigner -verify`, signed with the existing upload/release certificate SHA-1 `D6:7C:5B:0B:81:C6:7F:EB:A1:FE:1A:F5:2F:33:62:E7:97:C8:5F:AB`. Private keys, aliases and passwords are not included in this report. Google-managed Play App Signing uses the owner's different A1:CD:…:64:DB certificate, as expected for Play-delivered installations.

### Static 16 KB preparation

The debug APK passed `zipalign -c -P 16 -v 4`. ARM64 ELF LOAD segments have at least 16 KB alignment in both actual packages. RELRO checks passed with the documented whole-LOAD exception used by these engine libraries. The release AAB contains ARM64 only and its decoded BundleConfig enables uncompressed delivered native libraries with `PAGE_ALIGNMENT_16K`.

Native libraries are compressed inside the publishing AAB container; this is separate from the delivered APK settings in BundleConfig. Debug x86 libraries target the existing 4 KB emulator and are not asserted to have 16 KB ELF alignment. A real ARM64 16 KB device installation remains untested.

## Native gameplay smoke

`tools/production_android_smoke.py` returned **`PRODUCTION_ANDROID_SMOKE_PASS`** on the exact APK hash above. The workspace-owned `InfiniteSlash_PGS` Google Play emulator used Android API 30, x86, a 1080×2220 portrait screen and 4096-byte pages. It was isolated on emulator port 5582 and private ADB server port 5038. The APK already installed on this emulator was reused only after its on-device SHA-256 matched the final APK.

| Scenario | Observed result |
| --- | --- |
| Fresh class selection and touch Pause | Sword damage 32 / HP 80; Shield damage 24 / HP 170. Native UI fits the full portrait screen. |
| Guard regeneration while stationary | A restored reserve of 5 recharged to 65 without movement or health loss. Sword delay/regen 0.5s/22 and Shield 0.3s/28 persisted. |
| Paused level-50 choice | Tradeoff and Phoenix Oath cards rendered with readable GAIN/COST text. Elapsed time, health, guard, position and choices stayed unchanged while waiting and backgrounding. |
| Process restart during pending upgrade | The same two choices survived restart. Choosing the trade increased damage from 220 to 238.76576 and dash recharge from 2.10s to 2.30s. The unchosen legendary was not applied. |
| Stage-2 specialists | A level-30 fixture rendered new specialist creatures; 25 enemies were present when paused and saved. |
| Crownfall Keep, night and elemental attacks | A level-50 fixture rendered the new biome, night creatures, rare Moonmallow Majesty, projectile volleys and fire/quake/pulse hazards. |
| Sustained native stress and snapshot continuity | The scene remained responsive to touch Pause, with 85 enemies, 218 bullets and 14 hazards in the final snapshot at elapsed 117.97s. The original 201st Tinpot entry and rare boss survived restore. |
| Runtime and save diagnostics | Zero script, fatal, unsupported-snapshot or save-write errors matched the smoke error filter. The original fresh-AVD profile absence was restored in `finally`. |

The late-stage scenes are explicit saved-state test fixtures, with elevated durability to keep the capture alive. They demonstrate native rendering, systems and persistence; they do not claim a naturally earned level-50 build, a full organic run, or physical-phone frame rates.

The Android first-use fullscreen education dialog initially intercepted HUD taps. Dismissing its observed **Got it** button resolved the test setup issue; app code and HUD coordinates required no changes. On a completely fresh emulator, dismiss that system dialog before running automated gameplay taps.

Actual emulator captures, visually inspected by the development agents:

- [Launch](../output/android-test/production/01_launch.png)
- [Stationary guard recovery](../output/android-test/production/02_guard_recharges_while_stationary.png)
- [Tradeoff and legendary choice](../output/android-test/production/03_legendary_and_tradeoff.png)
- [Level-30 specialists](../output/android-test/production/04_stage30_specialists.png)
- [Crownfall night and elemental hazards](../output/android-test/production/05_crownfall_night_elemental_hazards.png)
- [Later stress frame](../output/android-test/production/06_stage50_stress_2.png)

The final memory sample reported **204,565 KB total PSS** and **290,700 KB RSS** on this emulator. `gfxinfo` captured only 25 Android UI-window frames and does not measure the Godot SurfaceView gameplay loop reliably; its percentiles are not presented as game FPS. Rendered desktop stress measurements and their hardware limits are documented separately in [PRODUCTION_PERFORMANCE.md](PRODUCTION_PERFORMANCE.md).

## Remaining device and Google checks

The native plugin initialized successfully without authentication. This API-30 image's old Play Services reported `SERVICE_VERSION_UPDATE_REQUIRED` (201817022 installed, 203400000 required). The test did not sign in or contact live achievements, leaderboards or cloud snapshots. A GLES cached-shader warning fell back to recompilation successfully; it was not a script or fatal error.

Use the signed AAB through an eligible Play internal test track to verify the Google-managed signing certificate, current Play Services, account eligibility, achievement unlocks, board submissions and two-device cloud conflict recovery. Provide the new achievement/leaderboard resource IDs listed in [PRODUCTION_PLAY_SERVICES.md](PRODUCTION_PLAY_SERVICES.md). Physical ARM64 phones should still be checked for long-run frame pacing, heat, battery use, interruption/audio behavior and the 16 KB configuration before production rollout. No store upload or live Google sign-in was performed in this update.

## Reproduction and evidence

From the project directory, use the existing locally configured signing setup:

```powershell
./tools/export_android.ps1 -Preset AndroidDebug -OutputPath builds/InfiniteSlash-debug-0.3.0.apk
./tools/export_android.ps1 -Preset AndroidPlay -Release -OutputPath builds/InfiniteSlash-play-0.3.0.aab
python tools/verify_production_native.py
./tools/android_play_test_emulator.ps1 -Action start -Port 5582 -AdbServerPort 5038 -Gpu host
python tools/production_android_smoke.py --adb C:/Users/swimr/AppData/Local/Android/Sdk/platform-tools/adb.exe --serial emulator-5582 --server-port 5038 --avd-name InfiniteSlash_PGS --apk builds/InfiniteSlash-debug-0.3.0.apk
./tools/android_play_test_emulator.ps1 -Action stop -Port 5582 -AdbServerPort 5038
```

Use `--skip-install` only when reusing the same installed APK; the helper independently verifies its hash. It backs up and restores the three fixed app profile files, including their original absence on a fresh AVD. It does not manipulate another device or the host's default ADB server.

Machine evidence is in `output/review/production_native_artifacts.json`, the corresponding signature/manifest/BundleConfig/zipalign files, frozen source hashes, preserved artifact hashes, and final `production_debug_export*` / `production_play_export*` logs. Native scenario events, fixtures, runtime log, memory and Android graphics diagnostics are in `output/android-test/production/`. Provisional export and failed setup logs are historical and do not replace the final package hashes or PASS events above.

The test app was force-stopped and its original profile state restored. The owned emulator and its private ADB server were stopped after capture; owner editor sessions and the default ADB server were left intact.
