# Google Play Games Services integration

Verified 2026-10-11 against the bundled `addons/GodotPlayGameServices` scripts and the upstream repository. This project already contains the v3.4.0 editor plugin, debug AAR, release AAR, and MIT license. Upstream's latest release also resolves to [v3.4.0](https://github.com/godot-sdk-integrations/godot-play-game-services/releases/tag/v3.4.0). Retain this plugin rather than installing another copy.

## Integration contract

The plugin has one autoload named **GodotPlayGameServices**. Feature clients are ordinary Nodes with global class names; they are not feature autoloads in v3.x. Use `PlayGamesSignInClient`, `PlayGamesAchievementsClient`, `PlayGamesLeaderboardsClient`, `PlayGamesSnapshotsClient`, and optionally `PlayGamesPlayersClient`.

Initialize the main autoload before client Nodes enter `_ready()`, because each client's `_ready()` connects to the Android singleton only if it is already present. The implemented adapter initializes the wrapper during its own `_ready()` before adding any client Nodes, then connects application callbacks before calling asynchronous methods. Do not repeatedly call `initialize()` as an availability check: the bundled wrapper only returns OK when it creates its Android plugin reference.

The main wrapper calls the native singleton `GodotPlayGameServices`, with `initialize()` returning enum values `OK = 0`, `PLUGIN_NOT_FOUND = 1`. On desktop, web, or unconfigured Android, keep all gameplay and local persistence functional. Gate native setup on Android, an explicit enabled setting, real configuration IDs, and `Engine.has_singleton("GodotPlayGameServices")`.

The plugin editor extension registers its autoload when enabled. This project's default offline build instead keeps the editor extension disabled and registers the vendor wrapper manually in `project.godot`. Enable the editor plugin only for a configured Gradle/services build, retaining exactly one wrapper autoload. See [upstream installation and configuration](https://github.com/godot-sdk-integrations/godot-play-game-services#install-the-plugin).

## Exact bundled GDScript API

All operations below are asynchronous and return `void`, except the main initializer. Callback arguments use wrapper data classes, not native Google objects.

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

Implemented normal milestones include first kill, first boss, 100 kills in a run, 60-second survival, 180-second survival, 25-hit combo, and 10,000 score. Cumulative goals include 100/1,000 lifetime kills, ten runs, and all 100 generated discoveries. Local achievements and notifications work before IDs are configured. The ID map defaults to blank values, which are skipped.

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

signal game_saved(is_saved: bool, save_data_name: String, save_data_description: String)
signal game_loaded(snapshot: PlayGamesSnapshot)
signal conflict_emitted(conflict: PlayGamesSnapshotConflict)
signal snapshots_loaded(snapshots: Array[PlayGamesSnapshotMetadata])
```

Save UTF-8 JSON as `JSON.stringify(profile).to_utf8_buffer()`. Load with `JSON.parse_string(snapshot.content.get_string_from_utf8())`, then validate type, schema, numeric bounds, and allowed keys. `game_loaded` can emit `null` for an absent save. Use one stable filename such as `infiniteslash_profile_v1` (1–100 characters drawn from letters, digits, `- . _ ~`). `PlayGamesSnapshot.DISPLAY_LIMIT_NONE` is -1.

`PlayGamesSnapshot` contains `content: PackedByteArray` and `metadata: PlayGamesSnapshotMetadata`. Metadata includes `unique_name`, `snapshot_id`, `description`, `progress_value`, `played_time`, and `last_modified_timestamp`.

`PlayGamesSnapshotConflict` contains `origin` ("SAVE" or "LOAD"), `conflict_id`, `conflicting_snapshot`, and `server_snapshot`. The GDScript wrapper has no `snapshot_deleted` signal, although v3.4.0's native plugin exposes `snapshotDeleted(success: bool, snapshot_id: String)`; use the native signal directly only if deletion is implemented.

## Snapshot limitations and safe MVP behavior

The upstream native implementation opens saves with highest-progress policy and loads with most-recent policy. Remaining conflicts are emitted without a native resolution entry point. Its save success callback is emitted after starting `commitAndClose`, without awaiting commit completion; some failures produce logs rather than callbacks. These behaviors are verified in [SnapshotsProxy.kt](https://github.com/godot-sdk-integrations/godot-play-game-services/blob/v3.4.0/plugin/src/main/java/com/jacobibanez/plugin/android/godotplaygameservices/snapshots/SnapshotsProxy.kt).

Implement a timeout for all cloud requests. Keep a valid, atomic local save and backup. Mark cloud writes as pending until a later read verifies the payload/revision, rather than claiming that `game_saved(true)` proves remote durability. Persist locally at run end, milestone unlock, settings change, and application backgrounding. Never block a start, resume, or replay on a network request.

If `conflict_emitted` fires, merge and persist the useful progress locally, keep the pending cloud state, and expose a concise cloud-sync status outside the active run. Do not call a nonexistent `resolve_conflict` method or claim the conflict was resolved remotely. A robust native extension can retain conflicting Snapshot handles and add a resolution entry point, then use Google's bounded retry strategy. [Google's conflict-resolution guide](https://developer.android.com/games/pgs/android/saved-games#handle_saved_game_conflicts) documents the necessary native `SnapshotsClient.resolveConflict` operation.

The implemented cloud merge keeps record maxima, unions unlocked achievements/discoveries, and merges lifetime counters through per-device component maxima (up to 64 tracked device components). Independent device progress combines without double-counting repeated snapshots. Preferences and active-run resumes stay device-local; cloud loading cannot replace them. Cloud sync preserves persistent progression only.

## Configuration to supply later

No backend/cloud resources are configured yet. Keep the adapter disabled and configuration IDs blank by default. Do not insert dummy Google IDs or silently authenticate with missing configuration.

1. Create the app's Google Play Games Services project and linked Google Cloud project.
2. Configure OAuth consent and testing access. Link Android OAuth credentials whose package and SHA-1 match debug signing, release signing, and Play App Signing as applicable. Add the testing Google accounts.
3. Create the score/survival leaderboards and matching normal/incremental achievements. Enable Saved Games.
4. Copy the numeric game ID into Android export option `godot_play_game_services/game_id`; copy actual board and achievement IDs into the game's ID map. Set the Android package consistently across export and credentials.
5. Enable custom Gradle build and install the matching Godot Android build template. Enable the services adapter only after supplying IDs.
6. Test on signed Android builds with eligible Google accounts, including offline launch, failed sign-in, callback timeouts, absent saves, two-device conflicts, background/resume, and disabled backend configuration. Publish Play Games Services changes when ready for public access.

Google's [console setup](https://developer.android.com/games/pgs/console/setup) and [Saved Games guide](https://developer.android.com/games/pgs/android/saved-games) describe credential linking, testers, and the Saved Games switch. The bundled export plugin injects game ID metadata and writes `android/build/res/values/strings.xml`; the directory must exist before an enabled services export. Blank game IDs are not a complete Android configuration.

## Local tooling observed

- Godot executable: `C:/Users/swimr/Downloads/Godot_v4.5.1-stable_win64.exe/Godot_v4.5.1-stable_win64_console.exe`.
- Matching export-template folder exists: `C:/Users/swimr/AppData/Roaming/Godot/export_templates/4.5.1.stable`.
- Editor Android SDK setting: `C:/Users/swimr/AppData/Local/Android/Sdk`; `platform-tools/adb.exe` exists.
- Editor Java SDK setting: `C:/Program Files/Java/jdk-17`; `bin/java.exe` exists.
- Bundled export dependencies: Google `play-services-games-v2:21.0.0` and Gson `2.11.0`. Upstream AAR source builds against Godot `4.5.1.stable`, compileSdk 35, Java 17, minSdk 21. See [build definition](https://github.com/godot-sdk-integrations/godot-play-game-services/blob/v3.4.0/plugin/build.gradle.kts).

The signed debug APK export succeeded with the Godot 4.5.1 template (minimum API 24, target API 35). The plugin's own minimum SDK 21 does not lower the engine's Android floor. See `ANDROID_BUILD.md` for the current package/checksum and `ANDROID_TESTING.md` for actual runtime evidence and limits.

## MVP service interface and verification plan

Implemented in `scripts/services/save_data.gd`, `scripts/services/play_services.gd`, `config/play_services.json`, and `tests/test_services.gd` after the creature roster preimplementation steps completed. Vendor files are unchanged. The project's services autoload order is `GodotPlayGameServices` (manual vendor wrapper), `SaveData`, then `PlayServices`; the editor plugin stays disabled for the default offline APK preset. Enable it only for configured services builds.

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
show_leaderboards() -> void
show_achievements() -> void
sync_profile() -> void
```

Gameplay calls `SaveData.add_run` once before `submit_run`, which attempts configured native submissions. `sync_profile` loads/merges a cloud profile before saving. The adapter verifies its write nonce through readback because the vendor save callback does not await commit. A timeout suspends cloud snapshots until the next launch because native callbacks lack request tokens; late results cannot erase newer data. An account mismatch also preserves local data and declines automatic sync. Score and achievement methods run independently, with replayable idempotent updates.

Disabled defaults keep `status` readable ("Local play"), and score/achievement buttons can surface the offline UI without creating native Nodes. `show_leaderboards` and `show_achievements` return true when routed to native UI/sign-in, or false and emit `local_leaderboards_requested` / `local_achievements_requested` for local UI. `is_available()` and `is_authenticated()` let gameplay choose its surface. Configuration holds `enabled: false`, blank IDs, and stable save filename. Both runtime configuration and Android singleton availability are checked before initialization. Native UI should pause gameplay and leave resume to the visible game surface. Status messages never interrupt combat.

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

Cloud credentials and real two-device tests remain postconfiguration requirements. The default offline build can be exported and tested now without claiming server-side verification.

Verification completed 2026-10-12: 82 deterministic assertions passed in Godot 4.5.1, including local corruption/future-version recovery, UTC daily-score routing/rollover, and simulated native callback ordering, timeout, pending-upload, and late-reply behavior. See `output/review/services_runtime.log`. These simulated callbacks do not test real Google authentication or servers.
