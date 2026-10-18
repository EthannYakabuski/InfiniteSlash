# AdMob gameplay verification — 0.4.0 / code 10

The AdMob update uses Poing 5.1.0, the supplied AdMob App ID and Google demo ad units. The owner's latest clarification controls rewarded continues: one per run, full health and guard, with score, counters, achievements and leaderboard eligibility retained. Previous achievements are not revoked or reset.

## Focused and regression checks

| Suite | Checks | Evidence |
| --- | ---: | --- |
| Actual game rewarded/death/focus/save flow | 99 | `output/review/admob_game_tests.log`, `admob_game_validation.json` |
| Ad service with deterministic native-client fixtures | 170 | `output/review/ads_service_tests.log`, `ads_service_validation.json` |
| Ad-space UI layout and actual GUI input | 236 | `output/review/ad_ui_validation.json`, `ad_ui_rendered_tests.log` |
| Existing game and five-minute saturated simulation | 355 | `output/review/admob_game_regression.log` |
| Existing guard, stages, bosses, builds and persistence | 178 | `output/review/admob_combat_regression.log` |
| Existing Play Games / profile / cloud behavior | 458 | `output/review/admob_pgs_regression.log` |

These suites contain **1,496 counted checks**. Audio suspension and the complete existing three-size UI suite are verified separately. The UI's 236 cases pass both headless and with the actual renderer; the table counts them once. Desktop fake clients do not prove live Google ad delivery or consent-account configuration. [Native package and device evidence](ADMOB_ANDROID.md) records that separate scope.

The corrected Android APK also loaded all three actual Google test formats. The quiet emulator run verified earned-and-dismissed restoration, preserved build/counters, the consumed continue after cold resume, and a third-completion interstitial returning to results. This native flow is separate from the counted desktop checks. Publisher privacy messages and physical-phone consent/performance checks remain release tasks, as detailed in the native report.

## Verified behaviors

- Banners are requested only for home and pause at the top, or level-up choices at the bottom. Running combat, scores, badges, settings, results, continue offers and fullscreen ads have none. Failed, stale and background banner requests release their space. SDK auto-refresh cannot destroy a valid current banner through a duplicate load callback.
- Physical banner height is converted to portrait UI units. Twenty-four actual renderer captures cover three sizes; long cards scroll inside the safe band. Layout fixtures are explicitly labeled and are not served ads. See [UI details and captures](ADMOB_UI.md).
- Only finalized games count toward the device-local three-game interstitial cadence. A rewarded life does not count as another game. No inventory leaves the results immediately usable; a missed opportunity never opens a late ad during gameplay. A saved due counter cannot cause a launch interstitial. A short fullscreen cooldown prevents consecutive rewarded/interstitial presentations.
- Death with an available rewarded ad pauses for an explicit Watch/End run decision. Double taps and stale callbacks cannot grant a second continue. The actual SDK-earned signal and subsequent dismissal are required; closing, skipping or failing gives no health.
- A successful continue restores maximum health and guard and gives brief return protection. It preserves run/RNG state, enemy/projectile/hazard entities, score, elapsed time, kill/boss/combo counters, level/XP, build choices and achievement/leaderboard eligibility. The run is committed only at its eventual final death.
- The used-continue flag persists. Pending death is saved before native presentation, and earned restoration is saved before gameplay resumes. Cold boot after an interrupted unearned ad commits the death once; it cannot load an earlier healthy autosave as a free life.
- Startup consent and finished-run interstitials cannot create fake resumable runs during background/close events. Fullscreen and background audio suspension preserve independent music/effects preferences. Returning from a privacy form keeps the exact settings/upgrade panel and pending choices.
- UMP is refreshed per app launch. Actual SDK `canRequestAds()` gates all loads; failure is not replaced with a cached consent-enum guess. The Android bridge accepts SDK booleans and JNI integers 0/1, rejecting other values. Required privacy options are reachable from settings. Adult flags are false and maximum content rating is unspecified, rather than G-only. Consent/init/load timeouts, bounded retries, background retry recovery, expired inventory and stale generations are covered.
- Existing Play Games IDs, schema, account safeguards, four Incremental targets and cloud slot are preserved. The ad frequency file remains device-local and outside cloud progression.

## Reproduce

Use the installed Godot 4.5.1 executable in place of `godot`, with isolated test user-data paths as in the recorded runs:

```powershell
godot --headless --path . --script tests/test_ads_game.gd
godot --headless --path . --script tests/test_ads_service.gd
godot --headless --path . --script tests/test_ad_ui.gd
godot --headless --path . --script tests/test_game.gd -- --test
godot --headless --path . --script tests/test_production_combat.gd -- --test
godot --headless --path . --script tests/test_services.gd
godot --headless --path . --script tools/test_audio.gd
```

The ad-game runner deliberately omits `--test`: it selects a fresh isolated profile itself and exercises the real cold-boot restoration path. No native ad client is created on desktop. Owner setup, production ad-unit replacement, privacy messaging and Play declarations are listed in [ADMOB_INTEGRATION.md](ADMOB_INTEGRATION.md).
