# Google Play Games: owner setup and developer handoff

Updated on **2026-10-12** against the game, owner-supplied console configuration and the local GodotPlayGameServices v3.4.0 extension. This guide retains the initial console workflow for reference and records the current handoff separately from live validation.

## Current setup state

**The real Google IDs are now configured and runtime services are enabled. Live Google sign-in, uploads and cross-device recovery remain unverified.** Desktop and Android builds without the native singleton continue to use local progression. Use [implementation/build evidence](PLAY_SERVICES_IMPLEMENTATION.md) for native Gradle APK/AAB packaging and test status rather than treating an enabled JSON flag as proof that Google services work.

| Item | Current state |
| --- | --- |
| Android identity | `com.slash.game`; supersedes the initial `org.infiniteslash.game` development package |
| PGS game ID | `832658811620`, applied in `config/play_services.json` and the Android export configuration |
| Linked Cloud project | Owner supplied project ID `infiniteslash`, project number `832658811620` |
| Android OAuth client | Owner supplied `832658811620-hsgkm87bv72d31hba64pi0rjslr94319.apps.googleusercontent.com`; OAuth publication and Play App Signing credential reported by the owner |
| Installed Play certificate | Owner confirmed Play App Signing SHA-1 `A1:CD:9D:32:4A:E8:AE:3E:38:38:D3:FB:7D:AF:70:F7:DD:46:64:DB` |
| Achievements | 14 Google IDs configured, including Standard boss badges Royal Upset and Crown Census; four confirmed Incremental goals: `century` / 100, `collector` / 100, `thousand_kills` / 1,000, `ten_runs` / 10 |
| Leaderboards | Three existing IDs configured: `high_score`, `longest_run`, `bosses_in_run` |
| Intentionally omitted | Remote `survivor_180` and `daily_score` remain blank; their local behavior remains available |
| Saved Games | Owner reported enabled on 2026-10-12 at “21:20 EST”; slot stays `infiniteslash_profile_v1` |
| Native snapshot changes | Local fork awaits commit completion, exposes conflict resolution and distinguishes failed reads from absent saves; adapter validates both branches, merges progress and limits resolution attempts to ten |
| Outstanding access/signing | Eligible PGS test accounts/track remain unverified; local release/upload signing is now configured and has produced a signed bundle |

The Saved Games time above preserves the owner's wording. The handoff records **2026-10-13 01:20 UTC under an explicit Toronto-local-time assumption**: Toronto observes EDT (UTC−4) on October 12. Literal EST would instead be 02:20 UTC. The owner-reported wording is not a confirmed UTC activation timestamp. Allow the documented activation window before diagnosing a missing cloud slot.

The package rename creates a different Android app/data sandbox. Existing local progress under `org.infiniteslash.game` is not automatically copied into `com.slash.game`; the old unfinished run is not migrated through profile-only cloud sync.

### Remaining owner steps

1. **Upload the supplied icons to the existing definitions. Do not re-import the old achievement metadata ZIP.** That draft was for initial creation and could create duplicate definitions now. Match each icon to its existing Google ID using [icon_manifest.json](../store/icons/icon_manifest.json); the [store upload kit](../store/README.md) also contains branding and the 24 screenshot files.
2. Add eligible Google accounts in PGS Testing, or enable the chosen test release track for PGS access. Confirm the route and opt-in access. Published OAuth configuration alone does not grant unpublished PGS test access.
3. Choose the build route. A Play-installed build must match the provided Play App Signing credential. A sideloaded debug build uses the separate `62:EE:…` Godot debug signer and needs its **own linked Android OAuth credential for `com.slash.game`** before live sign-in is expected to work.
4. Sign any release/upload AAB locally with the upload key before sending it to Play Console. An unsigned AAB is a build artifact, **not an upload-ready release**. The upload certificate and the certificate Google uses on installed Play builds may differ.
5. Run the live acceptance checks below on the final signed build, including real achievements, all three boards and two-device Saved Games conflicts. Complete the console metadata/publishing checks and app release checklist separately.

The implementation and build report owns final native packaging, artifact checksums and test results. The previous offline API35/debug APK evidence below is historical and does not establish the new configured build's readiness.

## What is already implemented

The current client uses real feature IDs with `enabled: true`. Local play remains immediate when native services or authentication are unavailable. The initial APK was deliberately offline; configured native builds require the Gradle package, correct certificate and eligible Google account.

| Feature | Implemented in the game | Still required |
| --- | --- | --- |
| Sign-in | Authentication check, manual sign-in through Scores/Badges, player identity lookup, local fallback | Eligible testers, matching debug credential or Play-installed build, live testing |
| Achievements | 15 local badges representing 14 distinct goals, all 14 online IDs configured, milestone triggers, replay and four cumulative counters | Upload icons to existing IDs and verify real Standard/Incremental behavior |
| Leaderboards | Three configured boards, pending best submissions; local daily challenge | Upload board artwork and verify the signed build's server records |
| Saved Games | Stable cloud profile slot, validated merge, bounded native conflict resolution, awaited commit and readback verification | Confirm native artifact validation, activation propagation and real two-device tests |
| Offline progression | Atomic local saves, backup recovery, active-run resume, local records/badges | Already usable; no Google setup required |

The current services suite passes **166 deterministic local/fake-client checks**, zero failures (`output/review/configured_boss_achievements_services.log`). The added checks verify both exact boss IDs, Standard unlock calls, persisted offline-earned replay, duplicate in-flight suppression and acknowledgements. The earlier 152-check configuration/conflict/read-failure result and 82-check initial result are historical. Native build evidence is recorded in [PLAY_SERVICES_IMPLEMENTATION.md](PLAY_SERVICES_IMPLEMENTATION.md), with the latest ID-only release in [the current configuration/build notes](BOSS_ACHIEVEMENTS_CONFIGURED.md). Simulated callbacks do not prove Google authentication, server uploads or cross-device recovery. API and adapter details are in [PLAY_SERVICES_PLAN.md](PLAY_SERVICES_PLAN.md).

Failed or timed-out score boards are blocked for the remainder of that app session. Unchanged achievement requests already attempted in that session are also suppressed. Local pending progress persists for replay after relaunch; reconnecting the network alone does not retry those requests. Snapshot timeouts/conflicts have their own session suspension described below.

## 1. Create and identify the app and services project

- [ ] Have a Play Console developer account with permission to edit this app and Play Games Services.
- [x] App/package identity supplied: **`com.slash.game`**. The initial offline APK used `org.infiniteslash.game`; credentials for that old package do not cover the new package.
- [x] Game and linked Cloud project supplied. Initial creation/linking is under **Grow users → Play Games Services → Setup and management → Configuration**; do not create a second game for the configured IDs.
- [ ] Confirm the Google Play Games Services API, **`games.googleapis.com`**, is enabled in the linked project if API/authentication errors occur. Its activation was not separately confirmed in the handoff.
- [x] PGS ID `832658811620`; linked Cloud project ID `infiniteslash`, number `832658811620`. The textual Cloud project ID and numeric IDs are distinct identifier types even when the two numbers coincide.
- [x] Game name remains InfiniteSlash; English defaults to `en-US` in the upload kit. Add the supplied console artwork where required.

Follow [Google's project setup](https://developer.android.com/games/pgs/console/setup). Firebase, your own database, and a game server are not required for the implemented client features.

## 2. Configure Google Auth and Android credentials

The owner reports the OAuth configuration is published. For reference, initial setup is in **Google Auth platform → Branding / Audience / Data Access**: app name, support email, developer contact email and appropriate public links, with External audience for public players. If a separate consent configuration is still in Testing, its test accounts also need OAuth access. See [Google Auth configuration](https://developers.google.com/workspace/guides/configure-oauth-consent).

For this integration the relevant PGS scopes are `games`, `games_lite`, and Saved Games' `drive.appdata`. Follow the PGS setup flow; this build does not request a server authorization code or use a Web/server client secret. [PGS OAuth setup](https://developer.android.com/games/pgs/console/setup)

Create **Android OAuth clients** for the exact package and signing SHA-1 combinations you will test, then **link each as an Android credential inside Play Games Configuration**. Creating a Cloud OAuth client without that PGS link is insufficient. Keep the generated Android OAuth client IDs for diagnosis; the game consumes the numeric game ID and feature IDs, not those client IDs. [Credential linking](https://developer.android.com/games/pgs/console/setup)

### Match the certificate to the installed build

| Installation route | Certificate to register |
| --- | --- |
| Current sideloaded debug APK | Current Godot debug certificate below |
| Locally signed release APK | Certificate of the local release key |
| Play internal/closed/production track | **Play App Signing certificate**, which may differ from the upload key |
| Internal App Sharing | Its separate **Internal App Sharing test certificate** |

Use Play Console's Play app signing page for public certificate fingerprints. Register applicable app-signing certificates if the app has signing upgrades or multiple listed certificates. The private upload key signs uploads; it need not be the certificate Google uses to sign installed apps. [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en)

**Internal testing** and **Internal App Sharing** are different distribution routes. Sharing uploads are re-signed; take that certificate from the Internal App Sharing page when using it. [Internal App Sharing certificates](https://support.google.com/googleplay/android-developer/answer/9844679)

The initial offline APK's public debug certificate was verified on 2026-10-12. Its package was `org.infiniteslash.game`; a new linked debug Android credential must use **`com.slash.game` with this signer**, assuming the configured build retains the same debug key. Check the final build report before registering a different key.

```text
Required new debug credential package: com.slash.game
Signer SHA-1:   62:EE:05:F2:CA:C9:95:36:48:BF:3A:D7:C8:22:55:8C:C6:33:CD:24
Signer SHA-256: 83:82:EC:1C:56:49:4E:B3:51:41:E0:ED:29:98:6D:2E:C5:00:9C:52:9B:09:6A:2F:D6:0D:5F:C5:C5:21:3E:4F
```

Android OAuth uses the **certificate SHA-1**, not the APK file checksum. This is the default Godot debug signer for development; choose a private production upload key for release. If a later build uses a different debug key, register that new signer too.

## 3. Configure the existing achievements

There are **15 local keys but 14 distinct goals**, with **all 14 Google achievement IDs configured**. The two boss achievements are Standard: Royal Upset (`CgkI5NXU8p0YEAIQEA`) and Crown Census (`CgkI5NXU8p0YEAIQEQ`). See [their configured IDs and icons](../store/boss-achievements/README.md). The original twelve achievements and IDs remain unchanged. `survivor` and `survivor_180` both unlock locally after a completed run of at least 180 seconds; remote `survivor_180` is intentionally blank. All local badges continue working. Do not map both keys to the same remote ID or create another copy during icon upload.

The initial definition table is retained below for reference and icon matching. It proposes **Revealed** English definitions and **290** total points; review the existing console entries before publication rather than recreating them. The owner confirmed the four Incremental types and step targets.

| Game configuration key | Console name | Goal | Type / steps | Points |
| --- | --- | --- | --- | ---: |
| `first_blood` | First Slice | Defeat your first creature | Standard | 5 |
| `boss_slayer` | Crown Collector | Defeat your first boss | Standard | 20 |
| `century` | A Hundred Little Problems | Defeat 100 creatures across completed runs | Incremental / 100 | 10 |
| `hundred_club` | A Hundred in a Hurry | Defeat 100 creatures in one completed run | Standard | 20 |
| `survivor_60` | Minute Knight | Complete a run lasting at least 60 seconds | Standard | 10 |
| `survivor` | Still Standing | Complete a run lasting at least 180 seconds | Standard | 25 |
| `legend` | Knight of Infinite Nonsense | Defeat five bosses in one run | Standard | 50 |
| `combo_25` | Slice Streak | Reach a 25-kill combo | Standard | 20 |
| `score_10000` | Five Digits of Slop | Reach 10,000 points in one run | Standard | 20 |
| `collector` | Bestiary Complete | Defeat/discover all 100 generated creature species | Incremental / 100 | 75 |
| `thousand_kills` | Slop Sweeper | Defeat 1,000 creatures across completed runs | Incremental / 1,000 | 25 |
| `ten_runs` | Back for More | Complete ten runs | Incremental / 10 | 10 |

The two boss records are also configured; their suggested points are separate from the historical 290-point table above. Actual Console points and visibility still need owner review.

| Game configuration key | Google achievement ID | Console name | Goal | Type | Suggested points |
| --- | --- | --- | --- | --- | ---: |
| `rare_boss` | `CgkI5NXU8p0YEAIQEA` | Royal Upset | Defeat Moonmallow Majesty, Gilded Chancellor, or Lime Imperator | Standard | 20 |
| `all_bosses` | `CgkI5NXU8p0YEAIQEQ` | Crown Census | Defeat all 12 different bosses across any number of runs | Standard | 30 |

Boss victories persist immediately and merge as a validated set across cloud profiles. A previously earned boss badge is replayed through the Standard unlock API after eligible authentication; no new Incremental counter is used. Missing optional IDs elsewhere do not block these achievements or cloud synchronization.

First kill/boss, five bosses, combo and discovery milestones can update during combat. The 10,000-score check runs on kills and at run completion; a gold pickup crossing the threshold waits for the next such check. Lifetime kills, run count and survival goals are evaluated on completed runs. Merely pausing/resuming a run does not count another completed run. The originally supplied Cinder Tinpot is excluded from the 100 generated-species collection.

Each existing Google ID is already mapped in `config/play_services.json`, [the original icon manifest](../store/icons/icon_manifest.json) or [the boss icon manifest](../store/boss-achievements/achievement_manifest.json). Names are not IDs. Current incremental counters support **only** `century`, `collector`, `thousand_kills`, and `ten_runs`; their targets are confirmed. The JSON map's numeric values describe console targets; runtime uses key membership and actual counters, so changing those numbers alone does not change achievement thresholds.

Achievement point values must be multiples of five, at most 200 each, with a current total cap of 2,000 per game. Review type/initial visibility before publication because published definitions have restrictions on changing them or deleting them. [Achievement rules](https://developer.android.com/games/pgs/achievements), [Console integration](https://developer.android.com/games/pgs/integrate-achievements)

### Import draft and icons

**Do not import [infiniteslash-achievements-draft.zip](pgs/infiniteslash-achievements-draft.zip) again for this game.** Its [AchievementsMetadata.csv](pgs/AchievementsMetadata.csv) is retained as the historical initial-creation draft: 12 rows, no header, seven fields per row, with definitions rather than Google IDs or icons. Re-importing now risks duplicates and different IDs.

Before publication, upload the supplied **512 × 512 RGB PNG** unlocked icons individually to the existing achievements. Match the original twelve `store/icons/achievements/<key>.png` files using [icon_manifest.json](../store/icons/icon_manifest.json); match Royal Upset and Crown Census using [the boss achievement manifest](../store/boss-achievements/achievement_manifest.json). These records include the exact Google ID, name and type. Subjects are centered for circular presentation and contain no localized text. Google supplies the locked appearance. [Achievement assets and import](https://developer.android.com/games/pgs/integrate-achievements)

The configured runtime incremental map is:

```json
{"century":100,"collector":100,"thousand_kills":1000,"ten_runs":10}
```

## 4. Create leaderboards

These three boards already have configured Google IDs. The intended definition is **larger is better**, **Numeric**, **zero decimal places**; confirm those settings in the existing console definitions before live testing. Sword, Shield and daily runs share these ordinary records; separate class boards would require another code change.

| Game configuration key | Proposed console name | Uploaded value | Display units |
| --- | --- | --- | --- |
| `high_score` | Endless Glory | Best completed-run score | points |
| `longest_run` | Last Knight Standing | Best completed-run duration, truncated to whole seconds | second / seconds |
| `bosses_in_run` | Crown Hoarder | Most bosses in one completed run | boss / bosses |

The IDs are mapped in `config/play_services.json` and [the icon manifest](../store/icons/icon_manifest.json). Do not select Google's Time format for `longest_run` with the current code: that format expects milliseconds. Changing to a formatted timer requires submission-unit changes. Sorting/format decisions should be settled before publishing. Google automatically supplies daily, weekly and all-time spans for ordinary boards. [Leaderboard configuration](https://developer.android.com/games/pgs/leaderboards)

**Optional `daily_score`:** proposed name *Daily Slop*, Numeric/integer/larger-is-better. I recommend omitting its ID for the first backend test. The game dates seeded challenges at UTC midnight, while Google's daily span resets at UTC−7 year-round. A fixed native board also cannot enforce the seed/date or prevent fabricated scores. Exact per-challenge competition needs additional validation/design; the existing local daily mode works with its ID blank. [Leaderboard spans](https://developer.android.com/games/pgs/leaderboards)

Upload `store/icons/leaderboards/<key>.png` to the matching existing board and review required metadata. Built-in score tamper protection is not a replacement for a custom authoritative score-validation server.

## 5. Enable Saved Games and understand the save scope

- [x] Owner reported enabling Saved Games on 2026-10-12 at “21:20 EST”; see the timezone note above.
- [ ] Allow up to **24 hours** for activation before treating a missing-save error as a code problem. No pre-created save slot or opaque snapshot ID is needed. [Enable Saved Games](https://developer.android.com/games/pgs/console/enable-features)
- [ ] Keep the automatic slot name **`infiniteslash_profile_v1`** stable. Changing it creates a different logical save instead of migrating the existing one.

| Data | Current behavior |
| --- | --- |
| Best score/time/combo/boss records | Cloud merge keeps maxima |
| Lifetime progression | Per-device counter maxima combine independent progress |
| Achievements and discoveries | Cloud merge unions existing unlocks/species |
| Local UTC challenge records | Cloud merge keeps best records by date |
| Audio/haptic preferences | Stay device-local; payload contains preferences but cloud merge deliberately ignores them |
| Unfinished run / exact combat state | Device-local resume only |
| Recent run history | Device-local only |

This is **profile progression sync**, not cross-device continuation of an unfinished battle. Saved Games is Google-hosted; there is no custom database endpoint to provide. [Saved Games overview](https://developer.android.com/games/pgs/savedgames)

The first authenticated Google player ID binds the local profile. A different ID detected during player loading suspends automatic syncing to protect that progress; the adapter does not continuously listen for account changes or recheck the identity before every write. Account switching/reset, selecting/deleting cloud slots, and directly importing already-unlocked Google achievements into local badges are not implemented. A restored cloud profile can restore local badges; otherwise they must be earned locally.

The original upstream v3.4.0 emitted save success before commit completion and exposed no conflict-resolution operation. The **local InfiniteSlash fork** now awaits commit completion and adds `resolveConflict`, exposed through `supports_conflict_resolution()` / `resolve_conflict()` in the GDScript wrapper. The adapter validates both remote branches, combines supported progression and attempts resolution at most ten times. It still verifies its nonce through readback, including pending-change metadata. A distinct `game_load_failed` signal prevents an open/read failure being treated as an absent save: the adapter preserves local/pending progress and does not start a replacement cloud write. Invalid/newer-schema branches, missing fork support, failed resolution or timeout also suspend automatic snapshot work for the session. The unpatched-plugin path safely keeps the merge local; it does not claim remote resolution. Final native packaging and tests are recorded in [implementation evidence](PLAY_SERVICES_IMPLEMENTATION.md); actual multi-device failures still need live Google testing. [Historical upstream source](https://github.com/godot-sdk-integrations/godot-play-game-services/blob/v3.4.0/plugin/src/main/java/com/jacobibanez/plugin/android/godotplaygameservices/snapshots/SnapshotsProxy.kt), [Google conflict handling](https://developer.android.com/games/pgs/android/saved-games#handle_saved_game_conflicts)

## 6. Authorize testers and select a distribution route

- [ ] Add your own and other test Google account emails in **PGS → Testing**, or explicitly enable the chosen Play release track for PGS access.
- [ ] If Google Auth is still in Testing, ensure these accounts also have OAuth test access.
- [ ] Send the test account list, release track/distribution route, and opt-in URL if using a Play track.
- [ ] Allow for propagation; PGS tester changes can take hours. Installing from an internal test track does not automatically grant access to unpublished PGS unless that track was enabled for it. [PGS test access](https://developer.android.com/games/pgs/test)

Use a Google Play-enabled Android phone for live checks. If anti-piracy/licensing is enabled, sideloaded builds may be rejected; keep it disabled for sideload development or test via the licensed Play route. Confirm that setting in the handoff. [Anti-piracy configuration](https://developer.android.com/games/pgs/android/anti-piracy)

## 7. What to send me

The supplied public configuration has been recorded in [PLAY_SERVICES_HANDOFF.json](PLAY_SERVICES_HANDOFF.json). Complete the remaining tester/signing/contact fields when available. It is a handoff record, not a file to replace runtime configuration blindly; already recorded IDs do not need to be sent again.

### Configuration checklist retained for reference

Game identity, fourteen achievement IDs, three leaderboard IDs, the confirmed four Incremental types/targets, Saved Games confirmation and the Play App Signing credential are already supplied. The list below shows the full initial handoff scope; item 6 and any additional distribution-specific OAuth credentials remain pending; local release signing is configured. Blank optional feature IDs are skipped safely.

1. **Final package name** and confirmation of which installed build/signing route we will use.
2. **Numeric PGS game ID**; linked Cloud project ID/number for troubleshooting.
3. **Three leaderboard IDs** under `high_score`, `longest_run`, `bosses_in_run`; confirm larger-is-better Numeric integers and seconds for survival.
4. **Fourteen achievement IDs** mapped to the tables' keys: the original twelve plus Royal Upset and Crown Census. Four Incremental types/targets are confirmed and both boss badges use Standard unlocks. `survivor_180` remains intentionally blank as a duplicate local goal.
5. Confirmation that **Saved Games and the Games Services API are enabled**, plus the time the Saved Games switch was changed.
6. **Eligible tester Google emails** and confirmation of PGS/OAuth test access; test track and opt-in URL if applicable.
7. **Registered signer SHA-1s and linked Android OAuth client IDs** for the distribution routes in use. Public fingerprints/client IDs are safe to share. Include the Play app-signing fingerprint once available.
8. **Already configured locally:** the upload/release signing workflow. Keep its keystore, alias and passwords local; no signing secrets need to be sent again.

### Needed before public release, or when applicable

- Game/consent display name, default language, support/contact emails, privacy-policy and website URLs, and status of required console metadata/icons.
- Decision on the optional daily board, duplicate survival badge, desired timer formatting, and whether separate Sword/Shield boards are wanted.
- Confirmation that profile-only cloud sync meets your expectation; intentional account switching or cross-device unfinished runs expand the implementation.
- Play app-signing certificates, additional release/sharing credentials, PGS/OAuth publication status, and any exact console validation errors.
- Your intended public release track and whether account-specific production eligibility steps are complete.

**Do not send Google passwords, private signing keys/passwords, OAuth client secrets, or service-account JSON in chat or commit them.** No Firebase config, API key, server URL, or Web OAuth secret is required by the current adapter. We can wire this from the exported public IDs without access to your Google password.

## 8. Developer work after the handoff

These are developer implementation/build tasks, distinct from the remaining owner tester/signing steps. Their final status and evidence belong in [PLAY_SERVICES_IMPLEMENTATION.md](PLAY_SERVICES_IMPLEMENTATION.md).

1. **Configured:** real key/ID mappings, four Incremental targets, `enabled: true`, package `com.slash.game` and the intentionally omitted optional IDs.
2. **Configured for native exports:** Gradle presets and the bundled editor export plugin, with exactly one wrapper autoload before SaveData/PlayServices. Verify the matching template/toolchain in the final build. [Godot Gradle build](https://docs.godotengine.org/en/4.5/tutorials/export/android_gradle_build.html)
3. **Configured:** numeric game ID **`832658811620`** in `godot_play_game_services/game_id`. InfiniteSlash's export plugin generates `game_services_project_id` in the dedicated `android/build/res/values/godot_play_services.xml`, preserving the template's `strings.xml`. Final packaging must include the fork AAR/Maven dependencies and expose the Android singleton. [Upstream plugin configuration](https://github.com/godot-sdk-integrations/godot-play-game-services#configuring-the-plugin)
4. **Owner-dependent:** eligible test access and Console publication. Local release/upload signing is configured. Confirm package/certificate metadata on the final signed build; the old offline APK cannot be converted by editing an external JSON file.
5. **Build validation required:** API36/Gradle is requested in the current presets. Historical API35/offline evidence does not verify that configured export. Consult the final build report and [target API guidance](https://developer.android.com/google/play/requirements/target-sdk).
6. **Artifact/runtime validation required:** check the final libraries/bundle for 16 KB page-size compatibility and run the required runtime. Partial alignment checks alone do not establish compatibility. [Android page-size guidance](https://developer.android.com/guide/practices/page-sizes)
7. **Implemented locally:** native snapshot commit waiting, conflict resolution and explicit read failures; adapter validation and ten-attempt bound. The 152 fake-client checks do not replace live Google commit/conflict failure testing.
8. **Live validation remains:** complete the acceptance checks below and report the actual build/signers/accounts. Events, Recall, authoritative score validation, custom account selection and slot management are separate unwired features.

## 9. Live acceptance checks

These checks require configured, properly signed Android builds and eligible accounts. Test data should use dedicated test profiles rather than your main gameplay profile.

| Check | Expected result |
| --- | --- |
| First launch / sign-in refused / offline launch | Can immediately start and play; local save remains usable |
| Authentication | Correct Google player identity is loaded; tester/certificate mismatches produce a diagnosable status |
| First kill/boss and other Standard milestones | Correct online achievement appears once; pending local unlocks replay after relaunch and authentication following a failed/timed-out request |
| Four cumulative goals | Progress uses absolute counters, reaches the configured targets, and does not inflate when replayed |
| Finished run on each class | Correct best score, whole-second survival, boss count appear on their matching boards |
| Native Scores/Badges UI | Pauses combat and returns to a working explicit resume surface |
| No existing cloud save | Safely creates the stable profile slot after the initial load |
| Reinstall/second device, same account | Restores supported profile progression; local preferences and active run remain local |
| Two devices play offline then reconnect | Progress combines without repeated-counter inflation; conflicts never silently discard local progression |
| Interrupted write, background, timeout, late callback | Local data survives; pending state is honest; native commit/conflict fixes are verified |
| Different Google account | Existing profile is retained and automatic cross-account cloud sync is suspended after mismatch detection |
| Optional daily board enabled | UTC date routing is verified; documented Google reset/seed limitations remain clear |

The SDK/adapter provides useful offline replay, but scores originate in the client and are not authoritative anti-cheat. Public competitive integrity needs a separate validation design if that becomes a requirement.

## 10. Publication is a separate owner step

Resolve Play Games publishing-page validation, publish the services configuration, and allow at least **two hours before the public app release**. Also make the Google Auth audience ready for public users. Publishing PGS does not publish the APK/AAB or store listing. [PGS publishing](https://developer.android.com/games/pgs/console/publish)

For the Android app itself, complete the Play Console tasks presented for your account: store listing/screenshots, app category/contact details, privacy policy, Data safety based on actual SDK behavior, ads declaration, app access, content rating, audience, release signing, test track and production eligibility. These do not block the initial unpublished PGS test. Do not declare cloud/account features absent simply because the offline APK had them disabled.

For personal developer accounts created after 2023-11-13, Google's production-access flow currently requires a closed test with **12 testers continuously opted in for 14 days** before applying. This is separate from the PGS tester allowlist. [Account-specific testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465)

This documentation update records owner-supplied console state; it did not create or publish console resources. Runtime configuration is now enabled with real IDs. Publication, signed-build eligibility and live Google verification remain separate steps.
