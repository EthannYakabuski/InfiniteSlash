# Production update — local progression and Google handoff

The production update preserves all 14 configured achievement IDs, the original four Incremental targets, three configured boards, package `com.slash.game`, Play Games project `832658811620` and snapshot slot `infiniteslash_profile_v1`. Five Standard achievement slots and two leaderboard slots are intentionally blank pending owner-created IDs. The optional daily board and duplicate local survival badge also remain blank.

See the [registration table and icons](../store/production-update/README.md), [seven-icon download](../store/production-update/InfiniteSlash-production-feature-icons.zip) and [feature manifest](../store/production-update/feature_manifest.json).

## Collection rules

- `record_monster_defeat(id)` validates against the generated creature roster, persists a new species immediately, adds its discovery, and evaluates 50/100/150/200 distinct-species goals. Repeats do not inflate progress or rewrite storage. Temporary summoned minions do not call this API.
- `defeated_monsters` is an additive profile field. A legacy profile missing it migrates its validated kill-only `discovered` identities. Malformed, unknown, non-string and duplicate entries are discarded. The originally supplied non-generated demonstration creature is excluded from generated-species goals.
- `collector` becomes **Bestiary Pioneer**, any 100 distinct discovered/defeated generated species, while retaining its existing ID, Incremental type and 100-step target. Already earned awards are preserved. The new **Monster Scholar** Standard milestone is a separate award in the new series.
- `defeated_bosses` and Crown Census remain separate: all twelve named bosses across runs.
- `record_biome_entry()` unlocks Beyond the Kingdom immediately when gameplay transitions at level 50, including a resumed run beyond the boundary. Repeated calls are harmless.
- Cloud merges union both validated creature and boss collections, merge record maxima, and remain idempotent. Preferences and active simulation remain device-local.

## Competitive record rules

`add_run()` accepts a normalized `level` value alongside existing score, duration, kills, bosses and combo. The profile stores `best_level`, `best_combo` and `best_bosses`. Pending `highest_level` and `highest_combo` scores retain maxima while their IDs are blank. Existing legacy combo records are queued on load. Cloud merges queue higher remote records. Live runs, pause and resume do not complete another run.

The existing `bosses_in_run` leaderboard already provides bosses destroyed per run, so no extra board was created. New combo and level boards use Numeric integer values and larger-is-better ordering. Acknowledging an earlier submission cannot erase a newer high record.

## Verification scope

The service regression suite covers threshold boundaries, unique identity tracking, invalid-input rejection, legacy migration, persistence, cloud union/idempotence, active-run preservation, blank-ID behavior and later replay through simulated native clients. Existing boss achievement IDs still dispatch Standard unlock calls, and existing cloud timeout/conflict/account safeguards remain covered. These tests do not authenticate with a real Google account or prove server-side unlocks, uploads or publication.

The active-run payload budget is now 512 KiB, within the existing 1 MiB envelope. A saturated late-run regression with 140 enemies, 480 bullets, 60 drops, 24 hazards and all upgrade counters uses approximately 149 KiB with moving entity precision, beyond the previous 128 KiB limit. It saves, reloads and restores all entities; oversized/unsupported data remains rejected.

Owner follow-up: create the five Standard achievements and two Numeric boards using the [provided definitions](../store/production-update/README.md); upload matching icons; update the existing collector display metadata; return the seven IDs; then verify on an eligible tester account using the appropriate signed distribution and publish the Console configuration when ready.
