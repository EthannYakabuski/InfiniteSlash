# Google Play Games configuration patch — Android 0.3.1

Built and verified on **2026-10-17**, version **0.3.1 / Android code 9**. This patch adds the seven owner-supplied Play Games resource IDs. All eleven main compiled gameplay scripts are byte-identical to the preserved 0.3.0 packages.

## Final packages

| Artifact | Purpose | Architectures | Bytes |
| --- | --- | --- | ---: |
| [InfiniteSlash-debug-0.3.1.apk](../builds/InfiniteSlash-debug-0.3.1.apk) | Signed development APK | ARM64, x86 | 182,935,422 |
| [InfiniteSlash-play-0.3.1.aab](../builds/InfiniteSlash-play-0.3.1.aab) | Signed Play upload bundle | ARM64 | 36,167,240 |

Both actual manifests identify `com.slash.game`, version name `0.3.1`, version code `9`, minimum API `24` and compile/target API `36`. Exports used the existing Godot 4.5.1 engine, Android templates, native plugin and signing setup.

APK SHA-256:

```text
f0889504c2f46a394eb195e6a42937e4b08d6e13cd5f92adb3217124cffe43ae
```

AAB SHA-256:

```text
4caef169d7907e535a23685fee076dc4bfa5502e1ce54dd7bbfbcb5702aa7680
```

Adjacent `.sha256` files record these hashes. The default `builds/InfiniteSlash-debug.apk` was updated to the byte-identical verified 0.3.1 APK after validation. The 0.3.0 APK/AAB and every earlier versioned build remain unchanged. The older unversioned `InfiniteSlash-play.aab` remains historical; upload the explicitly versioned **0.3.1 AAB** above.

## Configuration extracted from both packages

Both actual packages contain **19 configured achievement IDs and five configured leaderboard IDs**, exactly matching the frozen source configuration. Comparing with the actual 0.3.0 APK found exactly these seven blank-to-ID changes:

| Resource | Packaged ID |
| --- | --- |
| `bestiary_50` — Field Guide | `CgkI5NXU8p0YEAIQEg` |
| `bestiary_100` — Monster Scholar | `CgkI5NXU8p0YEAIQEw` |
| `bestiary_150` — Midnight Archivist | `CgkI5NXU8p0YEAIQFA` |
| `bestiary_200` — Living Bestiary | `CgkI5NXU8p0YEAIQFQ` |
| `biome_50` — Beyond the Kingdom | `CgkI5NXU8p0YEAIQFg` |
| `highest_combo` — Unbroken Steel | `CgkI5NXU8p0YEAIQFw` |
| `highest_level` — Highest Level | `CgkI5NXU8p0YEAIQGA` |

All previous IDs, incremental targets, game project `832658811620` and cloud slot `infiniteslash_profile_v1` are unchanged. The optional daily board and duplicate local `survivor_180` mapping remain empty. Achievement types, leaderboard units and owner follow-up are described in [PLAY_SERVICES_0_3_1.md](PLAY_SERVICES_0_3_1.md).

## Artifact verification

The parameterized `tools/verify_production_native.py` returned **`PRODUCTION_NATIVE_ARTIFACTS_PASS version=0.3.1 code=9`**. It verified:

- ZIP CRC integrity, adjacent checksums, actual APK/AAB manifests, package/version/API metadata and exact packaged configuration.
- All 200 generated monster records, including the 50 stage-2 specialists and 50 night creatures, and the imported atlas. The original Tinpot remains the appended runtime entry 201 in unchanged game code.
- Required compiled gameplay, progression, catalog, class, hazard, UI and persistence scripts. All eleven main `.gdc` files match between APK and AAB and match the 0.3.0 APK byte-for-byte.
- Actual native-plugin/Google Games SDK DEX entries, snapshot conflict-resolution method and snapshot-load-failure signal.
- Forty-two frozen runtime/config/export source hashes and nine pre-existing APK/AAB hashes. The former default debug contents are preserved by `InfiniteSlash-debug-0.3.0.apk`.
- Exclusion of tests, tools, documentation, reports and store-kit files from the packages.

The APK passed `apksigner verify`, using public debug certificate SHA-1 `62:EE:05:F2:CA:C9:95:36:48:BF:3A:D7:C8:22:55:8C:C6:33:CD:24`. The AAB passed `jarsigner -verify`, using the existing upload/release certificate SHA-1 `D6:7C:5B:0B:81:C6:7F:EB:A1:FE:1A:F5:2F:33:62:E7:97:C8:5F:AB`. Google-managed Play App Signing uses the owner's A1:CD:…:64:DB certificate when delivering Play installations. Private signing material is not included in the report.

### Static native alignment

The APK passed `zipalign -c -P 16 -v 4`. Both packages' ARM64 ELF LOAD segments have at least 16 KB alignment; RELRO checks passed using the engine libraries' whole-LOAD exception. The release bundle is ARM64 only, with BundleConfig enabling uncompressed delivered native libraries and `PAGE_ALIGNMENT_16K`.

The AAB's own native ZIP entries are compressed; delivery settings are controlled by BundleConfig. Debug x86 libraries serve the existing 4 KB emulator and are not asserted to have 16 KB ELF alignment. These checks do not replace installation on a real ARM64 16 KB device.

## Test scope and cleanup

This configuration-only patch did **not** run a new emulator gameplay smoke or authenticate a live Google account. The unchanged 0.3.0 gameplay's actual Android class/guard, pending-upgrade restart, stage-30 specialists and stage-50 night/elemental stress tests remain historical evidence in [PRODUCTION_ANDROID.md](PRODUCTION_ANDROID.md). Its emulator screenshots are not relabeled as 0.3.1 captures.

The focused service suite separately passed 458 simulated-client checks with zero failures, as recorded in the [configuration report](PLAY_SERVICES_0_3_1.md). Real Play authentication, server-side unlocks, submissions and cross-device cloud-save recovery still require an eligible tester and Play-delivered installation. No Play upload, account sign-in or live resource mutation was performed.

Both exports ran sequentially and returned success. Their temporary Godot and single-use Gradle processes exited normally. No emulator or isolated test ADB server was launched. The owner's existing editor sessions and the default ADB server were left intact.

## Reproduction and evidence

```powershell
./tools/export_android.ps1 -Preset AndroidDebug -OutputPath builds/InfiniteSlash-debug-0.3.1.apk
./tools/export_android.ps1 -Preset AndroidPlay -Release -OutputPath builds/InfiniteSlash-play-0.3.1.aab
python tools/verify_production_native.py --version 0.3.1 --code 9 --prefix pgs_0_3_1 --expected-config output/review/pgs_0_3_1_expected_config.json --achievements 19 --leaderboards 5 --baseline-version 0.3.0
```

The verifier accepts version, code, report prefix, frozen/prior snapshot paths and expected configuration/counts; its defaults retain the preceding 0.3.0 expectations. This invocation writes only the new `pgs_0_3_1_*` evidence and leaves historical `production_*` reports intact.

Evidence is under `output/review/`: `pgs_0_3_1_native_artifacts.json`, `pgs_0_3_1_expected_config.json`, `pgs_0_3_1_config_delta.json`, frozen source and prior artifact snapshots, package signatures/manifests/BundleConfig/zipalign diagnostics, distinct debug/Play export logs and `pgs_0_3_1_delivery.json`.
