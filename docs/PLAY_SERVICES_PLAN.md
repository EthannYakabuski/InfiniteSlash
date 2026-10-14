# Google Play Games Services integration

Initially audited on 2026-10-11 against the bundled `addons/GodotPlayGameServices` scripts and upstream v3.4.0. Updated on 2026-10-12 for the owner-supplied IDs, configured Android builds and the local snapshot extension. The project retains the [v3.4.0 plugin](https://github.com/godot-sdk-integrations/godot-play-game-services/releases/tag/v3.4.0) and MIT license; InfiniteSlash's native fork and GDScript wrapper changes are documented separately in [PLAY_SERVICES_IMPLEMENTATION.md](PLAY_SERVICES_IMPLEMENTATION.md).

## Current configuration and evidence

- Runtime configuration is **enabled** with PGS game ID `832658811620`, Android package **`com.slash.game`**, 12 existing achievement IDs and three existing leaderboard IDs.
- The four confirmed Incremental goals are `century: 100`, `collector: 100`, `thousand_kills: 1000`, and `ten_runs: 10`. Remote `survivor_180` and `daily_score` are intentionally omitted.
- The owner supplied the linked Cloud project, published OAuth configuration and a Play App Signing Android credential. Saved Games was reported enabled on 2026-10-12 at “21:20 EST”; the [setup guide](PLAY_SERVICES_SETUP.md) and [handoff](PLAY_SERVICES_HANDOFF.json) distinguish that reported time from the assumed Toronto/EDT UTC conversion.
- The configured adapter passes **152 deterministic local/fake-client checks**, including 70 new configuration/conflict/read-failure cases. The previous 82-check suite is historical. See `output/review/services_configured_runtime.log`.
- Native Gradle APK/AAB build evidence belongs in [PLAY_SERVICES_IMPLEMENTATION.md](PLAY_SERVICES_IMPLEMENTATION.md). No fake-client test establishes live Google authentication, score uploads, achievements or two-device recovery.
- Tester access, a debug credential matching the sideload signer or a matching Play installation, and a release/upload signing workflow remain owner tasks. Store artwork and individual icons are in the [upload kit](../store/README.md).

The package change from `org.infiniteslash.game` creates a different Android app/data sandbox. Prior local progress in the old package is **not automatically migrated** into `com.slash.game`. Cloud profile sync begins only after valid authentication and does not transfer the old package's unfinished run.

## Integration contract

The plugin has one autoload named **GodotPlayGameServices**. Feature clients are ordinary Nodes with global class names; they are not feature autoloads in v3.x. Use `PlayGamesSignInClient`, `PlayGamesAchievementsClient`, `PlayGamesLeaderboardsClient`, `PlayGamesSnapshotsClient`, and optionally `PlayGamesPlayersClient`.

Initialize the main autoload before client Nodes enter `_ready()`, because each client's `_ready()` connects to the Android singleton only if it is already present. The implemented adapter initializes the wrapper during its own `_ready()` before adding any client Nodes, then connects application callbacks before calling asynchronous methods. Do not repeatedly call `initialize()` as an availability check: the bundled wrapper only returns OK when it creates its Android plugin reference.

The main wrapper calls the native singleton `GodotPlayGameServices`, with `initialize()` returning enum values `OK = 0`, `PLUGIN_NOT_FOUND = 1`. On desktop, web, or unconfigured Android, keep all gameplay and local persistence functional. Gate native setup on Android, an explicit enabled setting, real configuration IDs, and `Engine.has_singleton("GodotPlayGameServices")`.

The plugin editor extension registers its autoload when enabled. The initial offline build kept it disabled and registered the wrapper manually. The configured project now enables the editor plugin for Gradle/services exports, retaining exactly one `GodotPlayGameServices` wrapper autoload before `SaveData` and `PlayServices`. See [upstream installation and configuration](https://github.com/godot-sdk-integrations/godot-play-game-services#install-the-plugin).

## GDScript API and local extension

Upstream feature operations below are asynchronous and return `void`; the main initializer and the explicitly listed local capability/resolve helpers have return values. Callback arguments use wrapper data classes, not native Google objects.

### Authentication

`PlayGamesSignInClient`:

```gdscript
is_authenticated()
sign_in()
request_server_side_access(server_client_id: String, force_refresh_token: bool)

signal user_authenticated(is_authenticated: bool)
signal server_side_access_requested(token: String)
```

Call `is_authenticated()` after initialization. Both the check and manual `sign_in()` emit `user_authenticated`. The player must be able to start immediately without waiting for this. Offer explicit manual sign-in through the scores/achievements affordance. `server_side_access_requested` supplies an OAuth authorization code, not a reusable access token; only request it when a real game server has been built. No server is required for the MVP's client achievements, scores, or snapshots.

`PlayGamesPlayersClient.load_current_player(force_reload: bool)` emits `current_player_loaded(current_player: PlayGamesPlayer)`. Use the resulting `player_id` to namespace cloud-linked data if account switching is supported. Do not apply one account's cloud save to another account's profile.

### Achievements

`PlayGamesAchievementsClient`:

```gdscript
unlock_achievement(achievement_id: String)
increment_achievement(achievement_id: String, amount: int)
set_achievement_steps(achievement_id: String, num_steps: int)
reveal_achievement(achievement_id: String)
load_achievements(force_reload: bool)
show_achievements()

signal achievement_unlocked(is_unlocked: bool, achievement_id: String)
signal achievement_revealed(is_revealed: bool, achievement_id: String)
signal achievements_loaded(achievements: Array[PlayGamesAchievement])
```

Use normal unlocks for milestone achievements and `set_achievement_steps` for cumulative goals. Absolute step setting is safe to replay after an interrupted request; repeatedly incrementing a cached total can inflate progress. Only send positive amounts/steps. A `false` unlock callback can mean the incremental achievement remains locked, so do not interpret it as a generic network error.

Implemented normal milestones include first kill, first boss, 100 kills in a run, 60-second survival, 180-second survival, five bosses, 25-kill combo, and 10,000 score. Cumulative goals include 100/1,000 lifetime kills, ten runs, and all 100 generated discoveries. Local achievements and notifications remain usable without authentication. Twelve real IDs are configured; blank optional IDs are skipped. Upload the individual icons to those existing IDs using [icon_manifest.json](../store/icons/icon_manifest.json), rather than importing the initial metadata draft again.

### Leaderboards

`PlayGamesLeaderboardsClient`:

```gdscript
submit_score(leaderboard_id: String, score: int)
show_all_leaderboards()
show_leaderboard(leaderboard_id: String)
show_leaderboard_for_time_span(leaderboard_id, time_span)
show_leaderboard_for_time_span_and_collection(leaderboard_id, time_span, collection)
load_player_score(leaderboard_id, time_span, collection)
load_all_leaderboards(force_reload: bool)
load_leaderboard(leaderboard_id, force_reload: bool)
load_top_scores(leaderboard_id, time_span, collection, max_results: int, force_reload: bool)
load_player_centered_scores(leaderboard_id, time_span, collection, max_results: int, force_reload: bool)

signal score_submitted(is_submitted: bool, leaderboard_id: String)
signal score_loaded(leaderboard_id: String, score: PlayGamesLeaderboardScore)
signal top_scores_loaded(leaderboard_id: String, leaderboard_scores: PlayGamesLeaderboardScores)
signal player_centered_scores_loaded(leaderboard_id: String, leaderboard_scores: PlayGamesLeaderboardScores)
signal all_leaderboards_loaded(leaderboards: Array[PlayGamesLeaderboard])
signal leaderboard_loaded(leaderboard: PlayGamesLeaderboard)
```

`time_span` is `PlayGamesLeaderboardVariant.TimeSpan`: DAILY = `TIME_SPAN_DAILY` (0), WEEKLY = `TIME_SPAN_WEEKLY` (1), ALL TIME = `TIME_SPAN_ALL_TIME` (2). `collection` is `PlayGamesLeaderboardVariant.Collection`: `COLLECTION_PUBLIC` (0), `COLLECTION_FRIENDS` (3). `max_results` must be 1–25. The plugin supports signed 64-bit scores; configure larger-is-better boards. InfiniteSlash submits `high_score`, `longest_run` in whole seconds, `bosses_in_run`, and an optional `daily_score` selected using the game's UTC challenge date. Replaying a best score is safe because Google ignores worse scores according to board ordering.

Keep a pending best score per configured board and clear it only on the corresponding successful callback. Native UI functions do not provide a completion signal; pause a run before opening native UI and resume through the game's explicit resume surface. Desktop/offline score controls should show local run history and bests.

### Saved games

`PlayGamesSnapshotsClient`:

```gdscript
save_game(file_name: String, description: String, save_data: PackedByteArray,
          played_time_millis: int = 0, progress_value: int = 0)
load_game(file_name: String, create_if_not_found := false)
load_snapshots(force_reload: bool)
show_saved_games(title: String, allow_add_button: bool, allow_delete: bool, max_snapshots: int)
delete_snapshot(snapshot_id: String)

# InfiniteSlash extension: synchronous capability/start result, asynchronous completion.
supports_conflict_resolution() -> bool
resolve_conflict(conflict_id: String, description: String, save_data: PackedByteArray,
                 played_time_millis: int = 0, progress_value: int = 0) -> bool

signal game_saved(is_saved: bool, save_data_name: String, save_data_description: String)
signal game_loaded(snapshot: PlayGamesSnapshot)
# InfiniteSlash extension: failed open/read is distinct from an absent save.
signal game_load_failed(file_name: String, message: String)
signal conflict_emitted(conflict: PlayGamesSnapshotConflict)
signal snapshots_loaded(snapshots: Array[PlayGamesSnapshotMetadata])
```

Save UTF-8 JSON as `JSON.stringify(profile).to_utf8_buffer()`. Load with `JSON.parse_string(snapshot.content.get_string_from_utf8())`, then validate type, schema, numeric bounds, and allowed keys. `game_loaded` can emit `null` for a genuinely absent save. The local fork emits `game_load_failed` for an open/read failure instead, so the adapter preserves pending/local progress without creating or overwriting a cloud slot. Use one stable filename such as `infiniteslash_profile_v1` (1–100 characters drawn from letters, digits, `- . _ ~`). `PlayGamesSnapshot.DISPLAY_LIMIT_NONE` is -1.

`PlayGamesSnapshot` contains `content: PackedByteArray` and `metadata: PlayGamesSnapshotMetadata`. Metadata includes `unique_name`, `snapshot_id`, `description`, `progress_value`, `played_time`, and `last_modified_timestamp`.

`PlayGamesSnapshotConflict` contains `origin` ("SAVE" or "LOAD"), `conflict_id`, `conflicting_snapshot`, and `server_snapshot`. The GDScript wrapper has no `snapshot_deleted` signal, although v3.4.0's native plugin exposes `snapshotDeleted(success: bool, snapshot_id: String)`; use the native signal directly only if deletion is implemented.

## Historical upstream limitations and current snapshot behavior

The original upstream v3.4.0 opened saves with highest-progress policy and loads with most-recent policy, emitted remaining conflicts without a resolution entry point, and emitted save success after starting `commitAndClose` without awaiting completion. Some failures produced logs rather than callbacks. These are **historical upstream findings**, verified in [SnapshotsProxy.kt](https://github.com/godot-sdk-integrations/godot-play-game-services/blob/v3.4.0/plugin/src/main/java/com/jacobibanez/plugin/android/godotplaygameservices/snapshots/SnapshotsProxy.kt), not a claim that InfiniteSlash's fork still has those behaviors.

The local native fork waits for commit completion before reporting `game_saved`, retains conflicting native snapshots, exposes `resolveConflict` through the wrapper helpers above and reports open/read failures separately. Source/patch provenance, packaged artifact status and native validation are recorded in [PLAY_SERVICES_IMPLEMENTATION.md](PLAY_SERVICES_IMPLEMENTATION.md). `supports_conflict_resolution()` checks the installed native method, so a build accidentally using an unpatched plugin follows the safe fallback instead of calling a missing operation.

On `conflict_emitted`, the adapter validates both remote profiles before remote replacement, merges supported useful progression locally and resolves using new merged bytes. It permits at most **ten resolution attempts** per sync chain, with an operation timeout on each. Malformed/newer-schema branches, missing conflict IDs, absent fork support, failed start, exhausted retries or timeouts preserve local progression and suspend automatic cloud snapshots for that session. With an unpatched plugin, valid progression is merged locally and pending cloud state is kept; the adapter does not claim remote resolution. This follows the bounded pattern in [Google's conflict-resolution guide](https://developer.android.com/games/pgs/android/saved-games#handle_saved_game_conflicts).

The adapter retains nonce/revision readback after a successful callback and checks native pending-change metadata before marking the write verified. An awaited SDK commit or matching cached payload alone is not claimed as proof of server durability. Local atomic primary/backup saves and progress remain usable through failures. Start, resume and replay never wait for cloud requests.

The implemented cloud merge keeps record maxima, unions unlocked achievements/discoveries, and merges lifetime counters through per-device component maxima (up to 64 tracked device components). Independent device progress combines without double-counting repeated snapshots. Preferences and active-run resumes stay device-local; cloud loading cannot replace them. Cloud sync preserves persistent progression only.

## Supplied configuration and remaining owner work

The initial disabled/blank-ID configuration has been replaced with the supplied real values. Current runtime config and export presets use game ID `832658811620` and package `com.slash.game`. The owner's console confirmations and remaining fields are in [PLAY_SERVICES_HANDOFF.json](PLAY_SERVICES_HANDOFF.json).

1. Upload the supplied achievement/leaderboard icons to the existing IDs. Do not re-import the initial metadata draft and create duplicates.
2. Authorize test accounts or the selected release track for PGS. OAuth publication is separate from unpublished PGS test access.
3. For sideloaded debug testing, link an Android OAuth credential for `com.slash.game` plus the `62:EE:…` debug SHA-1. The supplied `A1:CD:…` Play App Signing credential covers matching Play-installed builds instead.
4. Sign release/upload artifacts locally with the upload key. An unsigned AAB cannot be uploaded as the release; upload and Play app-signing certificates may differ.
5. Use the final configured Gradle/native artifact reported in the implementation document. Confirm package, numeric game ID, signer and native singleton instead of relying on the JSON switch alone.
6. Test eligible signed Android builds against real Google services: offline/refused authentication, all achievement types, board uploads, callbacks/timeouts, absent saves, two-device conflicts and background/resume. Publish PGS configuration and the Play app separately when ready.

Google's [console setup](https://developer.android.com/games/pgs/console/setup) and [Saved Games guide](https://developer.android.com/games/pgs/android/saved-games) describe credential linking, testers and Saved Games. InfiniteSlash's enabled export plugin injects game ID metadata and writes the dedicated `android/build/res/values/godot_play_services.xml` with `game_services_project_id`, preserving the template's `strings.xml`. An enabled feature flag is not a substitute for native packaging or matching credentials.

## Local tooling observed

- Godot executable: `C:/Users/swimr/Downloads/Godot_v4.5.1-stable_win64.exe/Godot_v4.5.1-stable_win64_console.exe`.
- Matching export-template folder exists: `C:/Users/swimr/AppData/Roaming/Godot/export_templates/4.5.1.stable`.
- Editor Android SDK setting: `C:/Users/swimr/AppData/Local/Android/Sdk`; `platform-tools/adb.exe` exists.
- Editor Java SDK setting: `C:/Program Files/Java/jdk-17`; `bin/java.exe` exists.
- Bundled export dependencies: Google `play-services-games-v2:21.0.0` and Gson `2.11.0`. Upstream AAR source builds against Godot `4.5.1.stable`, compileSdk 35, Java 17, minSdk 21. See [build definition](https://github.com/godot-sdk-integrations/godot-play-game-services/blob/v3.4.0/plugin/build.gradle.kts).

**Historical initial build:** the offline signed debug APK used the Godot 4.5.1 template, minimum API24, target API35 and package `org.infiniteslash.game`. The plugin's own minimum SDK21 did not lower the engine's floor. Configured `com.slash.game` exports now request API36/Gradle; their successful packaging, checksums and runtime evidence must come from [PLAY_SERVICES_IMPLEMENTATION.md](PLAY_SERVICES_IMPLEMENTATION.md) and the current Android reports, not this old result.

## MVP service interface and verification plan

Implemented in `scripts/services/save_data.gd`, `scripts/services/play_services.gd`, `config/play_services.json`, and `tests/test_services.gd`. The initial implementation left vendor files untouched; the current local fork changes snapshot commit/conflict behavior and adds the GDScript helpers. Autoload order remains `GodotPlayGameServices`, `SaveData`, then `PlayServices`. The editor plugin is enabled for configured Gradle exports. Fork source/patch and build provenance are recorded in the implementation document.

### SaveData autoload

Public state and operations:

```gdscript
var profile: Dictionary
var active_run: Dictionary
signal achievement_unlocked(key: String)

save_profile() -> void
add_run(run: Dictionary) -> void
unlock(key: String) -> bool
save_active_run(run: Dictionary) -> void
clear_active_run() -> void
```

The profile contains `schema_version`, `best_score`, `best_duration`, `best_combo`, `best_bosses`, `total_runs`, `total_kills`, `total_bosses`, `total_played_seconds`, `collected_powerups`, `discovered`, `achievements`, `run_history`, `daily_best`, `settings`, and cloud pending state. `settings` starts with `{ "music": true, "sfx": true, "haptics": true }`. Achievement values are unlock timestamps; run history stores the latest 30 normalized results; daily bests retain 14 dates. The run Dictionary uses `score`, `kills`, `bosses`, `duration` (seconds), `combo`, and `mode` ("sword", "shield", or "daily"). Daily runs also use `style` (actual sword/shield starter) and `challenge_date` in YYYY-MM-DD format. Any explicitly dated run updates that day's best. Missing or invalid inputs normalize conservatively; counters and totals remain nonnegative.

`add_run` updates records, increments lifetime counters, adds history, evaluates milestones, clears active-run resume data, and persists. `unlock` returns true and emits once for a newly unlocked known achievement; repeat calls return false. Active-run snapshots are device-local JSON-safe Dictionaries; serialize Vector2 and other engine objects as arrays or Dictionaries before passing them in. Pause saves may include the entire board and creature state but must have a size ceiling and schema guard.

Milestone keys: `first_blood`, `boss_slayer`, `century`, `survivor`, `legend`, `collector`, `hundred_club`, `survivor_60`, `survivor_180`, `combo_25`, `score_10000`, `thousand_kills`, `ten_runs`. `discover_monster(id)` validates IDs against the generated roster, rejects duplicates/original species, persists first discoveries, and unlocks collector for all 100 generated species. The cloud ID map uses the same keys, allowing replay of local unlocks once sign-in/configuration exists.

The storage implementation writes and flushes a temporary file, retains a valid prior primary as backup, then renames the temporary to primary. On load, validate the primary, then fallback to backup, then defaults. A corrupt primary never replaces a valid backup. Future unknown schema versions are preserved on disk instead of being silently overwritten by an older app. Cloud load preserves local preferences and active runs. Lifetime totals use per-device grow-only counters, merged with component-wise maxima, so repeated snapshots do not double-count and independent device progress combines. Tests use `configure_storage(path)` with isolated storage and never alter a player's real profile.

### PlayServices autoload

```gdscript
var status: String
signal status_changed(status: String)

submit_run(run: Dictionary) -> void
show_leaderboards() -> bool
show_achievements() -> bool
sync_profile() -> void
```

Gameplay calls `SaveData.add_run` once before `submit_run`, which attempts configured native submissions. `sync_profile` loads/merges before saving. The local fork awaits commit, and the adapter additionally verifies nonce/revision and pending-change metadata through readback. Valid conflict branches can be resolved with the bounded merge flow above. A timeout suspends snapshots until the next launch because callbacks lack request tokens; late results cannot erase newer data. An account mismatch detected during player loading preserves local data and declines sync. There is no continuous account-change listener or identity check before every write. Score and achievement methods run independently, with replayable idempotent updates.

Desktop, unavailable native plugin, disabled config and failed authentication preserve readable local status and local Scores/Badges. `show_leaderboards` and `show_achievements` return true when routed to native UI/sign-in, or false and emit `local_leaderboards_requested` / `local_achievements_requested` for local UI. `is_available()` and `is_authenticated()` let gameplay choose its surface. Current configuration holds `enabled: true`, real IDs and the stable profile filename. Configuration and Android singleton availability are checked before initialization. Native UI pauses gameplay and leaves resume to the visible game surface. Status messages never interrupt combat.

### Tests

Use an executable Godot `SceneTree` test script with deterministic assertions:

1. Fresh storage supplies defaults and empty active-run state.
2. A valid run updates highs, lifetime counters, history, and thresholds; lower subsequent results never lower highs.
3. Unlock emits exactly once, and invalid unknown milestone keys do not pollute profile data.
4. Lifetime cumulative achievements unlock at their thresholds across multiple runs.
5. Explicitly dated runs update only their matching date; daily/native submission routing uses the UTC challenge date, respects rollover, and never uploads a stale day's record. Old daily records/history prune at their limits.
6. Settings and active-run snapshots survive write/read, and clear-active persists.
7. Corrupt primary restores backup; corrupt primary plus corrupt backup restores defaults without crashing.
8. Malformed numeric/string/array fields normalize safely; unknown future schema avoids destructive overwrite.
9. Offline PlayServices startup creates no native clients, provides local status, and all public operations return without errors.
10. Configuration IDs blank or plugin absent both preserve immediate local play. Pending score replay uses maxima; achievement replay uses unlock/absolute steps rather than repeated increments.

Real Google account/tester access, matching installed-build credentials and two-device tests remain requirements. Local/offline tests do not establish server verification or release readiness.

Historical verification on 2026-10-12: 82 deterministic assertions passed in Godot 4.5.1, including corruption/future-version recovery, UTC routing, callback ordering/timeouts, pending uploads and late replies (`output/review/services_runtime.log`). **Current configured verification: 152 checks, zero failures**, adding 70 cases for real-ID/type routing, supported conflict resolution, branch validation, bounded retry/failure paths, unpatched-plugin fallback and read failures that must not create or overwrite cloud data (`output/review/services_configured_runtime.log`). Both suites use local storage and controlled fake native clients; neither tests real Google authentication or servers.
