# Production update — local progression and Google handoff

The **0.3.1 / Android code 9** configuration patch wires the seven owner-supplied IDs: five Standard achievements and two leaderboards. There are now **19 configured achievement IDs and five configured boards**, with no pending IDs for the requested features. The original 14 achievement IDs, four Incremental targets, three board IDs, package `com.slash.game`, Play Games project `832658811620` and snapshot slot `infiniteslash_profile_v1` are preserved. The optional daily board and duplicate local survival badge remain intentionally blank.

See the [configured ID table and icons](../store/production-update/README.md), [seven-icon download](../store/production-update/InfiniteSlash-production-feature-icons.zip), [feature manifest](../store/production-update/feature_manifest.json) and [0.3.1 configuration/build evidence](PLAY_SERVICES_0_3_1.md). Icon pixels and the 0.3.0 gameplay update remain unchanged.

## Collection rules

- `record_monster_defeat(id)` validates against the generated creature roster, persists a new species immediately, adds its discovery, and evaluates 50/100/150/200 distinct-species goals. Repeats do not inflate progress or rewrite storage. Temporary summoned minions do not call this API.
- `defeated_monsters` is an additive profile field. A legacy profile missing it migrates its validated kill-only `discovered` identities. Malformed, unknown, non-string and duplicate entries are discarded. The originally supplied non-generated demonstration creature is excluded from generated-species goals.
- `collector` becomes **Bestiary Pioneer**, any 100 distinct discovered/defeated generated species, while retaining its existing ID, Incremental type and 100-step target. Already earned awards are preserved. The new **Monster Scholar** Standard milestone is a separate award in the new series.
- `defeated_bosses` and Crown Census remain separate: all twelve named bosses across runs.
- `record_biome_entry()` unlocks Beyond the Kingdom immediately when gameplay transitions at level 50, including a resumed run beyond the boundary. Repeated calls are harmless.
- Cloud merges union both validated creature and boss collections, merge record maxima, and remain idempotent. Preferences and active simulation remain device-local.

## Competitive record rules

`add_run()` accepts a normalized `level` value alongside existing score, duration, kills, bosses and combo. The profile stores `best_level`, `best_combo` and `best_bosses`. The configured `highest_level` (**Highest Level**) and `highest_combo` boards submit retained maxima after eligible authentication. Existing legacy combo records are queued on load, and cloud merges queue higher remote records. Offline records remain queued until acknowledged. Live runs, pause and resume do not complete another run.

The existing `bosses_in_run` leaderboard already provides bosses destroyed per run, so no extra board was created. New combo and level boards use Numeric integer values and larger-is-better ordering. Acknowledging an earlier submission cannot erase a newer high record.

## Verification scope

The service regression suite covers threshold boundaries, unique identity tracking, invalid-input rejection, legacy migration, persistence, cloud union/idempotence, active-run preservation and replay through simulated native clients. The five new achievements use Standard unlock calls, both new boards use their exact configured IDs, and existing cloud timeout/conflict/account safeguards remain covered. Current checks are recorded in [the 0.3.1 patch report](PLAY_SERVICES_0_3_1.md); the 0.3.0 verification report remains historical. These tests do not authenticate with a real Google account or prove server-side unlocks, uploads or publication.

The active-run payload budget is now 512 KiB, within the existing 1 MiB envelope. A saturated late-run regression with 140 enemies, 480 bullets, 60 drops, 24 hazards and all upgrade counters uses approximately 149 KiB with moving entity precision, beyond the previous 128 KiB limit. It saves, reloads and restores all entities; oversized/unsupported data remains rejected.

Owner follow-up: upload matching icons to the [existing configured records](../store/production-update/README.md), update the existing collector display metadata if not already done, verify eligible-account unlocks/leaderboard scores/offline replay and two-device saves using the appropriate signed distribution, and publish the Console configuration when ready. No additional achievement or leaderboard IDs are needed for these features; do not create duplicate definitions.
