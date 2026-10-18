# AdMob Android package and device verification — 0.4.0 / code 10

The Android integration uses the supplied application ID **`ca-app-pub-7719473349082950~3864825368`** and only Google's three public Android demonstration ad units. Production ad-unit fields remain empty. Neither this build process nor its native probe requests production ads or signs into a Play Games account.

The final signed packages and real Android test-ad flows passed the checks below. See [owner setup and placements](ADMOB_INTEGRATION.md), [gameplay verification](ADMOB_VERIFICATION.md), and [UI capture evidence](ADMOB_UI.md).

## Native dependencies and provenance

The complete local Poing **5.1.0** addon was copied into `addons/admob`, retaining its MIT license and all 526 original files. The 60 pre-existing Play Games addon files were checked against their original hashes and preserved. [Copy evidence](../output/review/admob_addon_copy.json).

The matching official Android template is pinned by SHA-256:

```text
f7fdf644d50c0e231d8f02ae044057e489d0bcafcf50e908a4858477e7ee05ee
```

Its 57 extracted native files are independently hashed. The reproducible [native preparation helper](../tools/prepare_admob_native.py) verifies the cached archive before extraction and refuses to overwrite modified native files. [Upstream release](https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0), [extraction evidence](../output/review/admob_android_template.json).

| Component | Verified version |
| --- | --- |
| Godot and Android template | 4.5.1 |
| Poing AdMob plugin | 5.1.0 |
| Google Mobile Ads Next-Gen | 1.4.0 |
| Google User Messaging Platform | 4.0.0 |
| Play Games Services v2 | 21.0.0 |
| Android Gradle Plugin / Gradle | 8.10.1 / 8.11.1 |
| Java / Kotlin | 17 / 2.1.20 |
| Minimum / target Android API | 24 / 36 |

The actual Gradle SDK resolution and Android AAR metadata checks passed. The pinned Next-Gen SDK requires API 24 or later and compile SDK 35 or later; the existing project satisfies those requirements. No mediation SDK was enabled. [Dependency resolution](../output/review/admob_dependency_resolution.log), [AAR metadata check](../output/review/admob_metadata_preflight.log), [SDK metadata](../output/review/admob_sdk_metadata.json), [Google setup requirements](https://developers.google.com/admob/android/next-gen/quick-start).

## Native configuration

- Both export presets use package `com.slash.game`, version **0.4.0**, code **10**. Existing signing settings were retained.
- Both native plugins are enabled. The actual manifest contains the AdMob App ID, Play Games App ID, Play Games plugin registration, and required Poing registrations together.
- Google Mobile Ads initializes through the vendor's background-thread implementation. Its actual bytecode was inspected; the main-thread initialization concern is not deferred to guesswork. [Inspection](../output/review/admob_native_mobileads_javap.txt).
- The Android manifest retains `com.google.android.gms.permission.AD_ID`. A manifest-merger removal eliminates the vendor AAR's extra nonexistent `android.permission.AD_ID` declaration.
- The upstream Next-Gen dependency exclusions prevent legacy `play-services-ads` and `play-services-ads-lite` conflicts. AndroidX Browser is pinned to 1.8.0 as required by the vendor exporter.
- R8 remains disabled. Explicit UMP/Poing/Play Games keep rules are present for any later R8 migration; the real UMP getter is accessed through Godot's Java bridge.
- The native banner also honors safe areas: its actual bytecode reads display-cutout insets and API 30+ system-bar insets, applies all four layout margins and updates them when the layout changes. This complements the game's separate UI safe margins. A modern physical notched phone still needs a final visual check. [Native safe-area inspection](../output/review/admob_native_safe_area_javap.txt), [banner margin inspection](../output/review/admob_native_banner_model_javap.txt).
- iOS support is disabled. The only vendor source adjustment makes its binary installer honor the Android/iOS platform settings, avoiding an unrelated iOS download during headless imports.
- The vendor license is explicitly packaged. Sample scenes, C# sources, translations and vendor skill documents are excluded from exports; the full copied addon remains in the repository.

`android/build` is intentionally ignored by this repository. After recreating Godot's Android build template, rerun `python tools/prepare_admob_native.py` to restore the manifest cleanup, dependency exclusions and future keep rules. The helper is idempotent and leaves an already configured template byte-identical. [Merged-manifest preflight](../output/review/admob_0_4_0_merged_manifest_preflight.json).

## Consent bridge and initial diagnostic

Poing 5.1's wrapper lacks `canRequestAds()`. The adapter calls the public UMP getter using Godot's `JavaClassWrapper` and `AndroidRuntime`, checks Java exceptions and fails closed if the bridge is unavailable. The real Android probe exposed Java booleans arriving as integer **0/1**. A shared strict converter now accepts only booleans and those integer values on both native getter paths. Other integers, strings, floats and null are rejected. Thirteen added regression cases bring the service suite to **170 checks, zero failures**.

The initial bad diagnostic APK/AAB were retained with explicit **`provisional-jni`** filenames. They are not final deliverables. Its failing [native log](../output/android-test/admob_0_4_0/runtime.log) distinguishes the corrected code defect from the separate publisher configuration error below.

## Publisher configuration and testing scope

The real UMP response for the supplied App ID was **“no form(s) configured for the input app ID”**. Publish appropriate messages under this app's **AdMob → Privacy & messaging**, with the real privacy-policy URL and intended distribution regions. The app keeps consent gating active. No fake consent, forced geography or test App ID is substituted.

The actual corrected JNI getter returned **true** after this update error, and the SDK subsequently loaded all three demo formats. The application followed that authoritative permission; no consent bypass was used. This does not establish that publisher messages are correctly configured, nor does it predict another player's regional consent result. All three units are Google's public test units, which permit creative testing without configuring the owner's UMP messages. [Google test units](https://developers.google.com/admob/android/next-gen/test-ads), [UMP configuration and permission checks](https://developers.google.com/admob/android/next-gen/privacy).

**Publication follow-up, 17 October 2026:** the owner subsequently confirmed the privacy messages were published. No extra UMP installation is required: **UMP 4.0.0 is already included in these APK/AAB builds**. A bounded attempt to recheck the published server configuration could not launch the app because the existing isolated emulator rejected its private ADB host as unauthorized. This was a test-device connection failure; it is not a fresh `NoFormsConfigured` response. Message propagation, disappearance of the earlier publisher error and any resulting form remain unverified by this follow-up. No app/consent data was reset, no geography was forced, the shipping package hashes stayed unchanged, and the owned emulator/private ADB server were stopped. Earlier successful native ad evidence remains intact. [Follow-up receipt](../output/android-test/admob_published_2026_10_17/summary.json).

The native probe uses the project's isolated API 30 x86 Android emulator at 1080×2220 with no Google accounts. It checks the actual installed APK hash, SDK/plugin registration, authoritative JNI consent result, runtime errors and gameplay behavior. It preserves and restores the exact original profile/frequency files or their original absence. Any artificial death setup is explicitly labeled as a saved-state test fixture. The emulator uses 4 KB pages; static 16 KB checks do not replace a real 16 KB device test. Its old Google Play Services installation also prevents a live Play Games authentication check.

## Actual native ad flow

The quiet-host device run passed against the corrected APK. [Summary](../output/android-test/admob_0_4_0_quiet/summary.json), [event evidence](../output/android-test/admob_0_4_0_quiet/events.json).

- The real UMP JNI getter succeeded, native initialization completed, and Google's banner, rewarded and interstitial test inventory all loaded.
- The optional continue opened a real test creative. The SDK emitted `shown`, `reward_earned`, then `closed`. The immediate persisted snapshot had full health and full guard. The paused run retained level, score, kill/boss/combo counters and every compared build stat; total completed runs had not increased. [Restoration snapshot](../output/android-test/admob_0_4_0_quiet/earned_restore_snapshot.json).
- Cold resume preserved the consumed continue. The same run's next death completed it once, cleared the active run and offered no second rewarded life.
- Two earlier completed games were explicitly seeded in the local frequency fixture. The following final completion opened a real interstitial test ad. Closing its visible SDK button returned to usable results and reset the cadence counter to zero.
- No script error, fatal exception or native crash appeared in the passing run. Original profile/frequency files were restored to their prior absence. No Google account or production ad unit was used.

Representative actual captures: [home banner](../output/android-test/admob_0_4_0_quiet/04_home_actual_test_banner.png), [rewarded test ad](../output/android-test/admob_0_4_0_quiet/06_actual_rewarded_test_ad.png), [continued run](../output/android-test/admob_0_4_0_quiet/08_continued_run_paused.png), [interstitial test ad](../output/android-test/admob_0_4_0_quiet/09_actual_interstitial_test_ad.png), [final results](../output/android-test/admob_0_4_0_quiet/10_final_results_no_fake_resume.png).

A separate real-SDK placement probe also passed: [pause with a top banner](../output/android-test/admob_0_4_0_banners/11_pause_actual_top_test_banner.png) and [level-up choices with a bottom banner](../output/android-test/admob_0_4_0_banners/12_upgrade_actual_bottom_test_banner.png). Both captures were visually inspected: native creatives occupy their reserved bands and all game controls remain readable and accessible. The upgrade choices are an explicitly saved fixture. [Placement summary](../output/android-test/admob_0_4_0_banners/summary.json).

An earlier attempt overlapped Gradle packaging and suffered an input-timeout ANR inside the SDK's `AdActivity`, while host/device operations were also slow. Its [ANR evidence](../output/review/admob_0_4_0_contended_native_anr.txt) and [diagnostic capture](../output/android-test/admob_0_4_0_verified/native_failure.png) were preserved. The complete flow passed after build processes exited. A final [last-ANR timestamp check](../output/review/admob_0_4_0_final_last_anr_metadata.txt) still identifies only that earlier attempt. This quiet emulator pass does not establish performance or ANR freedom across physical phones; include rewarded dismissal and consent forms in the physical-device release check.

## Final package and device results

| Artifact | Bytes | Version |
| --- | ---: | --- |
| [Debug APK](../builds/InfiniteSlash-debug-0.4.0.apk) | 193,056,069 | 0.4.0 / 10 |
| [Signed Play bundle](../builds/InfiniteSlash-play-0.4.0.aab) | 44,882,567 | 0.4.0 / 10 |

```text
APK SHA256  549f924d65ebf018b43c7084442d61e3d645c8f654aad1bf2111a822d41e6486
AAB SHA256  b741e02929f8837921861a0ae51977a1cf018fd9467ec866db6320dc51ba38c8
```

The [actual package verifier](../output/review/admob_0_4_0_native_artifacts.json) passed ZIP CRCs, exact packaged configurations, all **19 achievement / five leaderboard IDs**, 200 monster records plus the original sheet's atlas entry, native Play Games/AdMob/UMP classes and manifest registrations, the vendor license, version/API settings, and signing checks. All **14 compiled main/service scripts** match between APK and AAB. The **247-file final source freeze** and all **11 previous artifact hashes** were rechecked. [Frozen sources](../output/review/admob_0_4_0_frozen_sources.json), [prior artifacts](../output/review/admob_0_4_0_prior_artifacts.json).

Debug certificate SHA-1 remains `62:EE:05:F2:CA:C9:95:36:48:BF:3A:D7:C8:22:55:8C:C6:33:CD:24`. The signed bundle uses the existing upload certificate `D6:7C:5B:0B:81:C6:7F:EB:A1:FE:1A:F5:2F:33:62:E7:97:C8:5F:AB`; Google Play subsequently signs delivered installations with the owner's managed App Signing certificate. [Debug signature](../output/review/admob_0_4_0_debug_signature.txt), [release signature](../output/review/admob_0_4_0_release_signature.txt), [upload certificate](../output/review/admob_0_4_0_release_certificate.txt).

APK ZIP alignment passed the installed tool's 16 KB check. Release ARM64 ELF load/RELRO checks passed; the bundle declares uncompressed native libraries with `PAGE_ALIGNMENT_16K` delivery. This is static package evidence, not a real 16 KB device certification. [APK alignment](../output/review/admob_0_4_0_apk_zipalign.txt), [bundle configuration](../output/review/admob_0_4_0_bundle_config.json).

The default `builds/InfiniteSlash-debug.apk` was updated only after verification and now has the same hash as the versioned APK. Version 0.3.1 and all older deliverables remain preserved. [Default-copy receipt](../output/review/admob_0_4_0_default_apk.json). Task-owned exporters, temporary Gradle helpers, the isolated emulator and its private ADB server were stopped; the owner's editor and unrelated project's Gradle process were left running.

## Reproduce the native checks

Use the project's installed Python/Godot/Android tools and existing local signing setup:

```powershell
python tools/prepare_admob_native.py
./tools/export_android.ps1 -Preset AndroidDebug -OutputPath builds/InfiniteSlash-debug-0.4.0.apk
./tools/export_android.ps1 -Preset AndroidPlay -Release -OutputPath builds/InfiniteSlash-play-0.4.0.aab
python tools/verify_production_native.py --version 0.4.0 --code 10 --prefix admob_0_4_0 --expected-config output/review/admob_0_4_0_play_services_config.json --achievements 19 --leaderboards 5 --admob-config output/review/admob_0_4_0_admob_config.json
```

Use `--download` with the preparation helper if the pinned archive is absent. Run device probing separately from packaging, using [admob_android_probe.py](../tools/admob_android_probe.py) with the isolated `InfiniteSlash_PGS` emulator, private server port 5038 and explicit APK path. `--exercise-gameplay` verifies actual SDK reward/completion behavior; `--placements-only` captures the real pause/upgrade banners. Both restore the initial local JSON state, require an account-free device, and verify the Google demo-unit configuration before any request. Physical-device consent acceptance/refusal/privacy changes, contemporary Android navigation/cutouts, current Play Services sign-in, production inventory and a real 16 KB phone remain release follow-ups.
