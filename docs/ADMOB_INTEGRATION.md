# InfiniteSlash AdMob integration and release setup

InfiniteSlash now includes banner, interstitial, and optional rewarded-continue support through the installed Poing Godot AdMob plugin **5.1.0**. The Android dependency set uses **Google Mobile Ads Next-Gen 1.4.0** and **UMP 4.0.0**. The delivered configuration uses your real AdMob application ID with Google's official test ad units. It does not earn advertising revenue yet.

The existing Google Play Games configuration remains separate: its 19 achievement IDs and five leaderboard IDs require no AdMob changes. No new Google Cloud credentials, OAuth secret, or account password is required for this integration.

## What the player sees

| Placement | Behaviour |
| --- | --- |
| Class selection and pause | One banner at the top center, with the interface moved below its actual physical height. |
| Level-up choices | One banner at the bottom center, with the choices moved above it. |
| Active combat and other overlays | No banner. |
| Final completed run | One interstitial opportunity after three completed games. No launch interstitial. |
| Death with an ad ready | An optional rewarded continue, at most once per run. |

A rewarded continue requires the SDK's earned-reward callback followed by dismissal. Closing early, load failure, or show failure never grants a continue. The run keeps its score, build, counters, achievements, and leaderboard eligibility. The gameplay layer persists the per-run limit across save/resume.

The game freezes and its music/effects are hushed during native consent, privacy, and fullscreen ad UI. Returning to the app respects the existing pause/focus state. A 30-second fullscreen cooldown prevents a cancelled continue from immediately chaining into an interstitial. No-fill or network failure leaves the game playable. Google's rewarded and interstitial documentation describes the corresponding SDK events and test units. [Rewarded ads](https://developers.google.com/admob/android/next-gen/rewarded), [interstitial ads](https://developers.google.com/admob/android/next-gen/interstitial).

Interstitial frequency is stored locally in `user://infiniteslash_ad_frequency.json`, with a backup. It is deliberately independent of the game profile and cloud saves. The count resets only after the SDK confirms an interstitial was shown. A due count can carry forward when inventory is unavailable, but never triggers an ad on startup or automatically when a late load finishes.

## Current identifiers and configuration

Configuration is in `config/admob.json`. The Android plugin settings also contain the application ID for the exported manifest and native initialization.

| Item | Configured value |
| --- | --- |
| Android package | `com.slash.game` |
| AdMob application ID | `ca-app-pub-7719473349082950~3864825368` |
| Test banner unit | `ca-app-pub-3940256099942544/6300978111` |
| Test interstitial unit | `ca-app-pub-3940256099942544/1033173712` |
| Test rewarded unit | `ca-app-pub-3940256099942544/5224354917` |
| Test mode | `true` |
| Production units | Three blank fields under `production_ad_units` |

An application ID contains `~`; an ad unit ID contains `/`. They are different identifiers. Debug builds always use Google's test units, even if `test_mode` is changed. Release builds also use test units while `test_mode` is true. Google's testing guide provides the official demo units. [Enable test ads](https://developers.google.com/admob/android/next-gen/test-ads).

The supplied target audience is adults: child-directed treatment and under-age-of-consent flags are false, and no maximum ad-content rating is forced. There is no blanket G-rated ad filter. These request settings do not replace the audience declarations you submit in Play Console.

## What you need to finish in AdMob

1. **Confirm the Android app identity.** Open your AdMob app and confirm its app ID matches the value above and its package is `com.slash.game`. Complete any account verification, payment, or policy tasks shown in your account.
2. **Publish privacy messages.** In **Privacy & messaging**, configure and publish the appropriate messages for this exact AdMob app, including the regions where you distribute the game. Supply your real privacy policy URL and configure consent partners/settings there. Test acceptance, refusal, and later changes to privacy choices. The app automatically exposes the privacy-options action when UMP reports it is required. [UMP setup](https://developers.google.com/admob/android/next-gen/privacy).
3. **Create three Android ad units.** Create one Banner, one Interstitial, and one Rewarded unit for this app. For the rewarded placement, use an understandable reward such as **one continue**. Send the three unit IDs; do not send a password or private key.
4. **Link the public store listing when available.** Complete AdMob's app-readiness review and resolve any serving limitations shown by the console. An unpublished/testing app is not the same as an approved monetizing public app. [App setup and readiness](https://support.google.com/admob/answer/9989980?hl=en).
5. **Complete app-ads.txt verification.** Follow the status/instructions in your AdMob console. Publish its authorized-seller entry at the root of the developer website associated with the store listing, and verify AdMob can crawl it. Use the publisher entry from your console. [Verification requirements](https://support.google.com/admob/answer/14538460?hl=en), [publishing app-ads.txt](https://developers.google.com/admob/android/next-gen/app-ads).
6. **Update Play declarations and your privacy policy.** Declare that the app contains ads and update Data safety and privacy disclosures for the actual SDKs/settings you ship, including the existing Play Games integration. Google describes Next-Gen SDK data collection and sharing, including IP address, interaction/diagnostic data, and identifiers; use that guidance with your complete app behaviour when answering the form. [Google Play data disclosure guidance](https://developers.google.com/admob/android/next-gen/privacy/play-data-disclosure).
7. **Switch a release build to production units only after verification.** Put the three real IDs in `production_ad_units`, set `test_mode` to `false`, export a release build, and verify placement/consent behaviour. Keep development testing on test ads. Do not click your live ads to test the integration.

## Consent and native behaviour

UMP refreshes consent information each launch. Ad initialization and requests require its current **`canRequestAds()`** result; a cached consent string or a consent-status enum never substitutes for that permission. An update error can still permit ads only if this actual SDK getter allows them. Privacy withdrawal discards inventory and blocks further requests until UMP permits them. The code does not force a geography, reset production consent, or bypass a required form. [Google UMP flow](https://developers.google.com/admob/android/next-gen/privacy).

Poing 5.1's wrapper does not expose `canRequestAds()`. `admob_backend.gd` therefore calls the public UMP getter through Godot's Android Java bridge, checks Java exceptions, and fails closed when unavailable. Godot's native bridge can return a Java boolean as integer 0/1; the shared `ads_sdk_values.gd` helper accepts those exact integer values and booleans, rejecting strings, floats, null, and other integers. The application ID is supplied to the manifest and the plugin's Next-Gen initialization path. Native initialization runs through the plugin's background-thread implementation. [Godot Android Java bridge](https://docs.godotengine.org/en/4.5/tutorials/platform/android/javaclasswrapper_and_androidruntimeplugin.html), [Poing plugin source](https://github.com/poingstudios/godot-admob-plugin).

Requests have timeouts and delayed retries. Cached fullscreen ads expire after 55 minutes. Placement generations reject late callbacks; banner auto-refresh keeps its existing view and space. Native in-flight loads are bounded to one per format. Consent retries survive backgrounding and resume when the app is active. Desktop/headless builds do not create a vendor or mock ad backend.

## Validation and troubleshooting

`tests/test_ads_service.gd` currently passes **170 deterministic checks** covering consent gates, strict JNI boolean normalization, privacy withdrawal, banner placement/refresh, late callbacks, reward-only-on-earned-and-dismissed, three-game frequency, persisted counters, no launch ads, fullscreen cooldowns, background recovery, retry backoff, cache expiry, and malformed/future counter files. Results are in `output/review/ads_service_validation.json` and `ads_service_tests.log`. These use an injected fake backend; they prove orchestration without claiming live ad delivery. The Android adapter also passes the Godot script parse check. Native build/device evidence is recorded separately by the Android validation workflow.

With test mode enabled, Android logs contain concise `INFINITESLASH_ADS` events without player data or ad IDs. `consent_getter` with `bridge: jni` proves a successful real getter call; `allowed: false` is a valid SDK refusal. `consent_bridge_unavailable` identifies a runtime/JNI problem separately. Subsequent `initialized`, `loaded`, `shown`, `reward_earned`, and `closed` events identify how far the real SDK progressed. No-fill, account readiness, unpublished consent messages, and device connectivity can prevent delivery even when integration tests pass.
