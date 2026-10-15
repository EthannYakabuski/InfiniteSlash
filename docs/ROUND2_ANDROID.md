# Android verification for the 0.2.0 gameplay update

This update is version **0.2.0**, version code **6**. The package remains
`com.slash.game`, minimum API 24 and compile/target API 36. Existing Play Games
project and configured feature IDs are retained. The two newly proposed boss
achievements stay local until their Console IDs are supplied.

The owner's Play export and local signing configuration are preserved. The
development preset had reverted to the original offline package and template;
its public settings now match the current package, Gradle template, native Play
Games ID and branded launcher icon. No passwords, private certificates or
keystore contents are copied into this report.

The preserved October 13 release bundle is signed with the public SHA-1
`D6:7C:5B:0B:81:C6:7F:EB:A1:FE:1A:F5:2F:33:62:E7:97:C8:5F:AB`.
This local release/upload signer is separate from the owner-confirmed
Google-managed Play App Signing certificate. The new bundle's signer is
compared with that existing artifact; Console upload-certificate matching
still belongs to the owner's release check.

## Reproduce

From the Godot project directory:

```powershell
./tools/export_android.ps1 -Preset AndroidDebug
./tools/export_android.ps1 -Preset AndroidPlay -Release -OutputPath builds/InfiniteSlash-play-0.2.0.aab
```

The second command uses the owner's existing local signing configuration. If
that configuration is unavailable, an unsigned preparation can be produced
with `-Unsigned` and a different output name; an unsigned bundle cannot be
uploaded as a signed release. The prior `builds/InfiniteSlash-play.aab` is
preserved.

The functional check uses the isolated workspace `InfiniteSlash_Test` API 30
Google APIs x86 AVD, host GPU, serial `emulator-5580` and a separate ADB server
on port `5038`. It installs the new development APK and operates real Android
touch input against rectangles measured by `tests/ui_layout_test.gd`.

```powershell
python tools/round2_android_smoke.py --adb 'C:/Users/swimr/AppData/Local/Android/Sdk/platform-tools/adb.exe' --serial emulator-5580 --server-port 5038 --apk builds/InfiniteSlash-debug.apk
```

Only this project-owned emulator's app profile is modified by test fixtures.
Its original profile is preserved under the ignored test output directory. The
test uses a serialized pending level-two reward and a rare boss fixture to
reach the new states promptly. These are test scenarios rather than claims
about random selection frequencies. Weighted boss selection and eligibility
are covered separately by the gameplay test suite.

## Scope

The Android check covers two visible upgrade choices; an upgrade pause longer
than ten seconds; Android Back and dragging without bypassing that choice;
fresh live snapshot validation after Android Home; pending-choice recovery
after process restart; all four independent music/effects settings combinations
and persisted settings; one chosen damage reward with the other reward unapplied;
combat resuming; larger dash/guard indicators; and restored rare boss identity.

The emulator has no authorized Play Games account and a 4,096-byte page size.
Google account sign-in, live server achievement/leaderboard results, two-device
cloud saves, physical-device audio listening and a real 16 KB device are outside
this functional check. The inherited native bridge and release packaging are
also inspected statically.

## Results

The corrected debug APK is **182,719,414 bytes**, SHA-256
`d4c515364931cc3dd6a0a72b51c8261b4da7ded77add412f39366cef9ba13ad7`.
Its manifest confirms package `com.slash.game`, version `0.2.0`/code `6`, minimum
API 24 and compile/target API 36. Packaged native bridge/SDK, ARM64 plus x86
libraries, internal debug signature and `zipalign -P 16` checks passed. Its
debug signer remains SHA-1
`62:EE:05:F2:CA:C9:95:36:48:BF:3A:D7:C8:22:55:8C:C6:33:CD:24`.

The corrected APK passed the complete Android touch check. Combat was frozen
for **17.562 seconds**, including ignored Back/drag input, then a newly captured
snapshot retained exactly the same elapsed time, health, score, position,
projectile, enemies, buffs, XP and pending choices. Pending choices and audio
preferences survived process restarts. All four independent music/effects
combinations were saved. Choosing Sharper Steel changed damage from 32 to
36.48, left the unchosen maximum-health reward unapplied at 80 HP and resumed
combat to elapsed 31.6 seconds.

The rare Moonmallow Majesty fixture restored its rare title and spiral
pattern, and the next actual pause wrote fresh elapsed **92.1667 seconds** and
boss age **2.1667 seconds**, with the canonical boss metadata present on disk.
This exercises the repaired save path directly on Android. Zero script/fatal
runtime errors and zero storage failures were observed. All six current
captures were visually reviewed and the larger dash/guard panels fit the
portrait display. The owned emulator and isolated ADB server were stopped.

Evidence: `output/review/round2_android_summary.json`,
`round2_debug_artifact.json`, `round2_apk_badging.txt`,
`round2_debug_export_stdout.log`, and
`output/android-test/round2/{events.json,runtime.log,01_*.png..06_*.png}`.
The signed Play bundle, built from that same corrected source, is
`builds/InfiniteSlash-play-0.2.0.aab`: **35,920,903 bytes**, SHA-256
`51c03f8a91d89f4d576688070a0ad0848d250ba8cbafbe7428031f2e6b00c43b`.
`jarsigner -verify` passed with exit code 0. Its certificate matches the
preserved owner's earlier signed bundle exactly, including public SHA-1
`D6:7C:5B:0B:81:C6:7F:EB:A1:FE:1A:F5:2F:33:62:E7:97:C8:5F:AB`.
Local release signing is configured; no unsigned preparation was needed for
this update. Both normal preset signing flags remain enabled.

The bundle contains the expected package/version strings, patched native
bridge methods/signals and Play Games SDK. ZIP CRC passed. It includes only
ARM64 native libraries; their ELF LOAD alignment and whole-LOAD RELRO checks
passed the existing static 16 KB assessment. The AAB container compresses its
native entries; this report does not equate that container detail with the
alignment of the delivered APK. The debug APK's actual `zipalign -P 16` check
passed. A real 16 KB device and Play-generated delivery APK remain release
verification steps.

Final artifact evidence: `output/review/round2_native_artifacts.json`,
`round2_debug_signature.txt`, `round2_release_signature.txt`,
`round2_release_export_stdout.log` and each build's adjacent `.sha256` file.
The older owner bundle `builds/InfiniteSlash-play.aab` remains unchanged.
The isolated emulator, temporary ADB server and owned build processes are
stopped. No Console configuration, external upload or release publication was
performed by this verification.

A stale owner-created Gradle HTML report initially blocked `:clean` because
the sandbox had only read access to that generated file. An approved, exact-
path cleanup removed only `android/build/build/reports/problems/problems-report.html`;
the retry passed cleanup. No game source, original release bundle or signing
file was removed.

The first native touch run caught a real boss-save regression: reconstructed
boss metadata had `StringName` dictionary keys, which the strict snapshot
validator correctly rejected. The restored rare boss rendered correctly, but
its newer combat state could not be persisted. `_encode_entity` now emits
canonical string keys before vector conversion. A new direct-save regression
suite passed 72 checks across all 12 freshly spawned and restored bosses;
the former JSON-roundtrip tests alone had hidden the key-type difference.
The failing native evidence is retained in
`output/android-test/round2_before_boss_save_fix`; final builds and device
results below use the corrected source.
