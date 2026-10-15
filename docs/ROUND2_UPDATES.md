# Run builds, varied crowns and clearer controls — 2026-10-15

This gameplay update originally shipped as version **0.2.0**, Android version code **6**; its versioned native evidence remains unchanged. The follow-up **0.2.1 / code 7** configures both owner-supplied boss achievement IDs. See [the current configuration/build notes](BOSS_ACHIEVEMENTS_CONFIGURED.md). The package remains `com.slash.game`; use a higher unused version code if the current code was already uploaded.

## Choose a build while the arena waits

Reaching an XP threshold opens two large, distinct randomized cards. No upgrade is applied before selection. Enemies, shots, movement, world scrolling, combo time, temporary buff time and cooldowns freeze. A choice applies exactly one reward, clears stale movement input and resumes with 0.65 seconds of damage grace. Audio remains accessible. Android Back and Escape cannot skip the choice.

| Upgrade | Effect | First offered |
| --- | --- | ---: |
| Sharper Steel | +14% current slash damage | Level 2 |
| Quicker Slices | 6% shorter slash interval | Level 2 |
| Longer Reach | +5 slash reach | Level 2 |
| Heart of a Knight | +8 maximum health, heal up to 18 | Level 2 |
| Stronger Guard | +8 guard capacity, restore up to 30 reserve | Level 2 |
| Fleet Footed | +6% base movement speed per pick; maximum +30% | Level 3 |
| Quickstep | Dash recharges 0.10 seconds sooner; floor 0.90 seconds | Level 5 |
| Keen Edge | +20% slash damage and +3 reach; at most three picks | Level 10 |

The existing distinct Sword/Shield damage, health, guard, reach and cadence limits remain in force. Cards display their effective change near a limit; exhausted stats disappear from the pool. Keen Edge requires both damage and reach to benefit. At the limits, useful recovery or score rewards keep two choices available: Field Rations fully restores health/guard, Royal Purse gives 500 score, and Lucky Purse gives 100–1,000 score.

Overflow XP queues one explicit decision per earned level. Pending card IDs, their seeded RNG, selected build counts and mobility stats survive an active-run save. Resume reopens the original choice; reopening the app does not reroll offers. Earlier automatic-upgrade saves preserve their existing earned stats and adopt choices on their next level-up. Active battles stay local; persistent profile discoveries/achievements can sync through the configured cloud service.

## Three boss pools

There are twelve stable boss identities, four in each tier. Bosses retain their identity, artwork, rarity and attack family across runs. Selection uses a separate run-seeded RNG, skips the immediately preceding identity and occasionally visits another tier. Normal runs vary; the same Daily seed and encounter sequence are reproducible. Saving during a boss retains its identity and the next selection's RNG state.

| Run phase | Tier 1 / Tier 2 / Tier 3 weights |
| --- | --- |
| Before 3 minutes | 88% / 10% / 2% |
| 3–7 minutes | 12% / 78% / 10% |
| After 7 minutes | 8% / 16% / 76% |

Within a selected tier, common identities have weight 28 and the rare identity has weight 9; the last boss is excluded. These are selection weights, not a guaranteed sequence. Health and pressure increase with encounter progression; an early visitor has capped early-run health. Four readable attack families use aimed fans, ring volleys with escape wedges, locked charges and alternating spiral spokes. Each retains a warning interval and bounded projectiles.

| Tier | Bosses |
| --- | --- |
| 1 | Tinpot Tyrant; Moss Baron; Ember Earl; **Moonmallow Majesty (rare)** |
| 2 | Thistle Regent; Azure Archduke; Acorn King; **Gilded Chancellor (rare)** |
| 3 | Violet Sovereign; Crimson Duke; Ochre Oracle; **Lime Imperator (rare)** |

Unique victories save immediately and merge as a set across cloud profiles. Repeated victories cannot inflate the collection.

## Two configured boss achievements

| Runtime key | Google achievement ID | Name | Type | Description |
| --- | --- | --- | --- | --- |
| `rare_boss` | `CgkI5NXU8p0YEAIQEA` | Royal Upset | Standard | Defeat a rare boss: Moonmallow Majesty, Gilded Chancellor, or Lime Imperator. |
| `all_bosses` | `CgkI5NXU8p0YEAIQEQ` | Crown Census | Standard | Defeat all 12 different bosses across your runs. |

Both owner-supplied IDs are configured. Upload [their unchanged 512×512 icons](../store/boss-achievements/README.md) to those existing records; do not recreate them or re-import the old achievement draft. Suggested points remain 20 and 30, with Revealed visibility; actual Console settings are not independently verified. Previously saved local unlocks replay after eligible Google authentication. The original twelve Google IDs are unchanged; the game now has fourteen online achievements and fifteen local badges for fourteen distinct goals.

## Separate audio and clearer HUD

The Audio panel has independent **Background Music** and **Sound Effects** switches. Music only, effects only, both on and both off all work and persist locally. It is accessible from launch, gameplay, pause, results and level-up. Opening it during play pauses the run; leaving returns to Pause. Opening it during a choice returns to the same two offers.

Dash and guard now have large contrasting cards, icons, labels and progress bars near the thumb area. Dash shows ready/recharge and the remaining cooldown; guard shows active/exposed/reserve status. Buffs, ward charges, level and elapsed time use larger text. Safe-area margins and both supported portrait shapes are checked.

## Verification

- Gameplay: **379 checks, zero failures**, including frozen choices, XP conservation, save/restore, independent audio persistence, real boss kill recording and all prior combat/migration checks.
- Active boss save regression: **72 checks**, all passing, covering direct on-disk save/restore/continued progress for all twelve identities. This caught and fixed engine StringName keys in new boss metadata; entity keys now become plain strings before strict save validation.
- Catalogs/profile: **54 upgrade checks, 20 boss-selection checks, 22 boss-progression checks**, all passing.
- Google adapter: the original 0.2.0 suite passed **152 checks** with simulated clients. The 0.2.1 boss-ID follow-up passes **166 checks**, including offline-earned Standard badge replay; neither result establishes a live server result. See [the follow-up notes](BOSS_ACHIEVEMENTS_CONFIGURED.md).
- UI: layout and real button-click checks at 540×960 and 540×1110; fifteen rendered captures reviewed, including actual combat → level-up → audio → original offers → resumed combat.
- Stress: 18,000 fixed steps / 300 simulated seconds with maxima of 100 enemies, 240 bullets, 60 drops and 90 effects. The quiet run averaged 0.893 ms, p95 1.420 ms and maximum 8.556 ms per CPU step. A post-fix repeat during concurrent native building/emulation averaged 1.699 ms, p95 3.163 ms and maximum 67.495 ms; host contention affects those wall-clock samples. This is simulation timing, not phone FPS, battery or thermal certification.

Evidence is under `output/review/round2_*`, `upgrade_catalog_runtime.log`, `boss_catalog_update.log`, `boss_progress_update.log`, `active_boss_save_after.log`, `update_ui_*` and `ui_actual_*.png`. Current rebuilt native package evidence and emulator results are recorded separately in [ROUND2_ANDROID.md](ROUND2_ANDROID.md). Earlier Android reports retain their original hashes and scope.
