# Enable Google Play Games later

InfiniteSlash runs and saves locally with no Google configuration. `config/play_services.json` deliberately ships with `enabled: false` and blank IDs. The supplied v3.4.0 vendor plugin is present but its editor export plugin is disabled for the offline build, preventing a missing `game_services_project_id` resource from breaking Android export. The vendor runtime wrapper is registered manually as an autoload.

## Console and signing setup

Create the Google Play Games Services project, configure its linked Cloud project, and add Android credentials using the game's exact Android package plus the SHA-1 of each relevant signing certificate. Add testing Google accounts before trying unpublished services. Play App Signing may use a different certificate from your upload/release key, so its credential must match the installed Play build. Follow Google's [console setup guide](https://developer.android.com/games/pgs/console/setup).

Enable Saved Games in the Play Games project; see Google's [Saved Games guide](https://developer.android.com/games/pgs/android/saved-games). Create larger-is-better integer leaderboards:

| Configuration key | Submitted value |
| --- | --- |
| `high_score` | Best completed-run score |
| `longest_run` | Best completed-run duration in whole seconds |
| `bosses_in_run` | Most bosses defeated in one completed run |
| `daily_score` | Today's best dated challenge score |

The game seed and optional `daily_score` lookup use the same UTC challenge date. Google's daily leaderboard span may reset on a different boundary, and the native board does not enforce the challenge seed/date. Exact per-challenge competition requires server validation or a per-date board. The `daily_score` ID can remain blank while local UTC challenge bests work normally.

Create standard achievements matching these semantic keys. Each key may have a distinct ID or remain blank to omit it:

| Key | Trigger |
| --- | --- |
| `first_blood` | First lifetime kill |
| `boss_slayer` | First lifetime boss |
| `century` | 100 lifetime kills |
| `survivor` / `survivor_180` | Survive 180 seconds in one run |
| `legend` | Five bosses in one run |
| `collector` | Defeat/discover all 100 generated species |
| `hundred_club` | 100 kills in one run |
| `survivor_60` | Survive 60 seconds |
| `combo_25` | Reach a combo of 25 |
| `score_10000` | Reach 10,000 score |
| `thousand_kills` | 1,000 lifetime kills |
| `ten_runs` | Complete ten runs |

For cumulative incremental achievements, add their semantic keys to `incremental_achievements`, for example `{ "century": 100, "collector": 100, "thousand_kills": 1000, "ten_runs": 10 }`, and configure matching step targets in the console. The adapter sets absolute progress; it does not repeatedly increment cached totals. The numeric configuration values describe your console targets; progress comes from the corresponding local counter. Leave the map empty when using standard achievements.

## Godot export setup

1. Copy actual leaderboard/achievement IDs and the numeric game ID into `config/play_services.json`.
2. Enable `GodotPlayGameServices` under Project Settings → Plugins only for the configured online build. Confirm the existing manual autoload still appears once, before SaveData and PlayServices.
3. Install the Godot Android build template and enable custom Gradle build in the Android preset. The SDK and Java paths are documented in `PLAY_SERVICES_PLAN.md`.
4. Put the same numeric game ID into Android export setting `godot_play_game_services/game_id`. The export plugin writes `android/build/res/values/strings.xml`; the installed build template supplies that folder.
5. Make sure JSON data files are included in export and the Android package matches credentials. Sign with the appropriate debug/release key. Preserve private keystores and passwords outside the repository.
6. Set runtime `enabled: true` only after the above setup is in place, then export and test with an eligible account.

No game server or server OAuth secret is required for these client features. The integration does not request server-side access tokens.

## Data and sync behavior

Local progress is versioned, written through a flushed temporary file, and backed up. Run history keeps 30 results, dated challenge bests keep 14 dates, and generated discoveries validate against the roster. A corrupt primary loads its backup; a future save schema is preserved instead of overwritten. Active-run resumes and audio/haptic preferences remain local.

Cloud progression merges bests, discoveries, achievements, and per-device lifetime counter maxima. The native account ID binds the first configured profile; account changes suspend automatic sync to protect the current progress. Separate account-profile selection would be required to support intentional switching.

The vendor plugin has no native conflict-resolution entry point. If Google reports a remaining snapshot conflict, the adapter merges useful progression locally and suspends remote snapshots for the session. It also suspends timed-out snapshot operations because native callbacks lack request IDs. Progress stays replayable on the next launch. Do not describe these situations as a successful cloud resolution.

The vendor's `game_saved(true)` callback occurs before its commit Task completes. InfiniteSlash reads back a unique write nonce and checks `has_change_pending`; even this is a client-side SDK check, and real server behavior must be verified with configured signed builds. Native conflict/commit limitations can be fixed only by extending the plugin; vendor files currently remain unchanged.

## Validation

Run `tests/test_services.gd` with Godot headless after importing the project. It uses isolated fixture storage under `output/test-data/service-tests`, covers 82 assertions, and passed on 2026-10-12 with Godot 4.5.1. Local persistence, corrupted saves, schema guards, thresholds, discovery, dated highs, UTC submission routing/rollover, cloud merge idempotence, disabled services, and simulated native callback ordering/timeouts are tested. The actual test log is `output/review/services_runtime.log`.

Before publishing configured services, test actual signed Android authentication, rejected sign-in, offline launch, score/unlock replay, missing saves, two-device offline progress, snapshot conflicts, application backgrounding, and account mismatch. These server-dependent checks are pending the user's Google configuration.
