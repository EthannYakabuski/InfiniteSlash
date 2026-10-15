# Boss achievement activation build — 0.2.1

This configuration update connects **Royal Upset** (`rare_boss`) to
`CgkI5NXU8p0YEAIQEA` and **Crown Census** (`all_bosses`) to
`CgkI5NXU8p0YEAIQEQ`. Both are standard achievements. All **14 distinct online
achievement IDs** are configured; the intentionally unused duplicate
`survivor_180` slot remains blank. The three existing leaderboards and four
incremental achievement targets remain configured as before.

The export presets use version **0.2.1**, version code **7**, package
`com.slash.game`, minimum API 24 and compile/target API 36. This update changes
configuration and export version only; it retains the gameplay and service
logic verified for [0.2.0](ROUND2_ANDROID.md). No emulator rerun or live Google
account test is claimed for this configuration-only build.

An independent comparison against the preserved, device-tested `0.2.0` APK
confirmed that all **nine compared packaged compiled game scripts** are
byte-for-byte identical. The changed achievement configuration and export
version therefore do not require repeating that gameplay/device run.

## Reproduce

```powershell
./tools/export_android.ps1 -Preset AndroidDebug
./tools/export_android.ps1 -Preset AndroidPlay -Release -OutputPath builds/InfiniteSlash-play-0.2.1.aab
```

The Play export uses the owner's existing local signing configuration. Private
key material and signing credentials stay local. Existing `0.2.0` bundles and
the owner's older `InfiniteSlash-play.aab` are preserved; the former default
debug APK was additionally preserved as `InfiniteSlash-debug-0.2.0.apk`.

## Artifact results

The updated debug APK is `builds/InfiniteSlash-debug.apk`, **182,719,418 bytes**,
SHA-256 `786f838d8750cb5fabe5a1f10396ee862b498bda3be3192bd0c39de7bdb64a58`.
Its packaged JSON matches the configured source exactly, including the two
new IDs and all 14 nonblank achievement IDs. The actual manifest confirms
version `0.2.1`/code `7`, package `com.slash.game`, minimum API 24 and
compile/target API 36. APK signature verification and `zipalign -P 16` passed.
The public debug certificate remains SHA-1
`62:EE:05:F2:CA:C9:95:36:48:BF:3A:D7:C8:22:55:8C:C6:33:CD:24`.

The signed Play bundle is `builds/InfiniteSlash-play-0.2.1.aab`,
**35,920,892 bytes**, SHA-256
`38a5cb0f46249d236f7d79757a127f557beb1a78b15ff922ab9f104818e5dac1`.
`jarsigner -verify` passed with exit code 0. Its public release/upload signer
matches the preserved owner's earlier bundle: SHA-1
`D6:7C:5B:0B:81:C6:7F:EB:A1:FE:1A:F5:2F:33:62:E7:97:C8:5F:AB`.
This is separate from the Google-managed Play App Signing certificate used
for Play-installed builds.

Both actual packages contain configuration identical to the source, including
the two exact new IDs and all 14 distinct configured achievements. APK config
is at `assets/config/play_services.json`; the AAB's install-time asset pack
contains `assetPackInstallTime/assets/config/play_services.json`.

The actual APK and AAB manifests both confirm `com.slash.game`, version
`0.2.1`/code `7`, minimum API 24 and compile/target API 36. CRC integrity checks
passed for both files, and both contain the patched native Play Games bridge
and SDK. The ARM64-only release libraries pass the static ELF 16 KB assessment.
The AAB's parsed delivery configuration enables uncompressed native libraries
with `PAGE_ALIGNMENT_16K`; the actual debug APK passes `zipalign -P 16`.
These static checks do not replace a real 16 KB device or authorized Google
account test.

All three preserved prior artifacts match their pre-build hashes. Normal
signing flags remain enabled, and no emulators or ADB servers were started
for this update. Owned export and inspection processes have completed. No
Console changes, external upload or publication was performed.

Evidence: `output/review/boss_achievements_native_artifacts.json`,
`boss_achievements_apk_badging.txt`, `boss_achievements_bundle_metadata.txt`,
`boss_achievements_debug_signature.txt`, `boss_achievements_release_signature.txt`,
the two `boss_achievements_*_export_stdout.log` files, and the adjacent
`.sha256` files for each finished build.
