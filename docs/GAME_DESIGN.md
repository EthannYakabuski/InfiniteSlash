# InfiniteSlash implemented game design

This document describes the playable MVP as implemented in `scripts/game.gd`, `scripts/world.gd`, `scripts/game_ui.gd`, `data/monsters.json`, and the persistence/Play Games services. The priorities are portrait Android, one-thumb play, immediate starts, short restarts, readable combat and bounded performance. Numerical values below describe the current build rather than proposed features.

## Core experience and launch flow

A small knight fights along an endlessly scrolling fantasy road while unlikely creatures arrive from above and the sides. Thumb movement handles positioning; automatic sword swings handle attacks. Clean movement, timed guards, a deliberate dash, temporary pickups and a sustained combo form the skill curve. Funny creature silhouettes, crowded escapes, boss crowns and a copyable score challenge support repeatable, shareable runs.

The first screen shows the arena through a translucent dark veil, with a title and two large sword/shield buttons. Either choice starts immediately. A valid saved run adds a prominent resume button. Scores, badges and other secondary actions are reached from pause/end overlays. Death stops the run, shows score, best, kills, bosses, time and best combo, then presents the same sword/shield choices for one-tap restart. The end card also offers a daily run and copies a short challenge message to the clipboard; it does not post to another application.

## One-thumb controls and combat

| Input | Implemented response |
| --- | --- |
| Touch and drag outside UI buttons | A floating joystick steers the knight; the sword attacks automatically. |
| Release the controlling thumb | Movement stops and the shield rises while guard reserve remains. A movement-to-stop transition can open a short perfect-guard window. |
| Fast directional flick | Dash once during that gesture if the cooldown is ready. |
| Pause button, Escape or Android Back during play | Pause the arena; a large resume action continues it. Android Back while paused also resumes. |
| Desktop mouse drag or WASD/arrows | Equivalent movement support for desktop play and testing. Space dashes in the movement/facing direction. |

The logical arena is 540 x 960. Joystick displacement has a 9px deadzone and reaches full speed at 65px. Its origin follows when displacement exceeds 100px. One active touch owns movement; an extra finger cannot take over or release it. UI controls consume their own input.

A flick needs at least 60px displacement, a gesture age between 0.015 and 0.22 seconds, and speed above 650 logical px/s. A dash travels at 630px/s for 0.18 seconds, about 113px before arena clamping, and has a 1.45-second cooldown. It grants temporary body/projectile damage immunity. A single gesture cannot repeatedly dash. A small arc/trail and HUD readiness label communicate its state.

Auto slash aims at the nearest living enemy within 210px, otherwise at the last movement direction. Base reach is 84px, with a half-arc of 1.24 radians, about 142 degrees total. Enemy radius contributes to the hit test. Each enemy is hit once per swing; the same arc also clears front-facing bullets within reach. The visible sweep lasts 0.18 seconds. Brief hitstop, a damage flash, knockback, particles and reused slash/impact sounds mark successful hits. Splitter offspring survive the swing that creates them.

| Starting style | Health | Damage | Swing interval | Movement | Guard reserve | Perfect guard |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Sword | 100 | 22 | 0.46s | 265px/s | 100 | 0.16s |
| Shield | 125 | 16 | 0.51s | 245px/s | 130 | 0.23s |

Guard reserve drains immediately at 28/s while stationary and guarding; movement restores 20/s. An exhausted stationary knight stays unguarded until movement restores reserve. Perfect guard requires a movement-to-stop transition, more than four reserve points and a 0.65-second rearm interval. Normal guarded contact damage is 65% of the hit for Sword and 35% for Shield. Perfect contact guard cancels damage and refunds ten reserve points. A guarded bullet is removed near the shield: normal blocks cost eight reserve points; perfect blocks refund four and award four score. Guarded sword attacks use a slower 0.83-second interval.

Damage grants 0.70 seconds of grace, resets the combo and briefly tints/blinks the knight. A three-hit ward absorbs damage before health and also grants that grace. Scenery is decorative and cannot damage the player. The knight is clamped to `x = 25..width-25`, `y = 152..height-58`, with a collision radius of 13px.

## Portrait arena, art, HUD and sound

Godot uses a 540 x 960 logical portrait viewport with canvas-item stretching and a 432 x 768 development window. The HUD calculates mobile safe-area insets, with a minimum 22px margin. It shows health, XP, level, score, best, elapsed time, combo/multiplier, guard reserve, dash readiness and active buffs. Boss name/health appear only while a boss lives. Pause and sound controls remain compact. Three simultaneous toasts are the maximum.

The environment reuses Town grass and a three-tile dirt road, with sparse trees and Farm props along the sides. Scrolling runs at 43px/s independently of the knight's movement. Meadow, autumn and twilight tints repeat every 150 seconds; the last eight seconds blend into the next palette. Palette transitions are time-based and do not alter collision or projectile meaning.

The generated knight atlas contains four character poses plus sword and shield cells. The monster atlas preserves native 24px pixels from all 100 requested Creature Mixer exports and the supplied original. All original 8x PNG sheets remain available. Nearest-neighbor sampling maintains crisp silhouettes. Hostile bullets retain dark rims and bright cores; boss shots are orange/red, normal shots gold, and frost-slowed shots pale blue. Lines/rings warn before charges and ranged attacks.

Existing Kenney audio supplies combat, guard, arrival, pickup and reward effects. An original 32-second, mono 24kHz fantasy chiptune loops behind them. Twelve cached effect players bound simultaneous sound voices; frequent effects are throttled and major cues can replace lower-priority sounds. Music/effects can be muted without changing gameplay. Android damage vibration respects the saved haptics preference.

## Eight monster behaviors

The JSON roster contains exactly 100 generated named monsters, plus the separately preserved Cinder Tinpot added by the game. Base health, movement, damage, score and ranged cadence vary per monster. Family availability depends on run time, not the JSON's descriptive tier field.

| Family | Roster base health | Roster base speed | Base damage | Unlock | Actual behavior |
| --- | ---: | ---: | ---: | ---: | --- |
| Chaser | 28-36 | 84-96 | 9-11 | 0s | Steady pursuit. The supplied original is an additional 36-health, 68-speed, 10-damage chaser. |
| Skitter | 22-30 | 112-124 | 8-10 | 12s | Fast pursuit with a sine-weaving direction. |
| Spitter | 32-40 | 60-72 | 10-12 | 16s | Holds roughly 150-245px distance and fires one aimed shot after a 0.6s windup. |
| Tank | 74-86 | 52-58 | 16-18 | 20s | Large, durable pursuit; movement uses an additional 0.85 factor and knockback is reduced. |
| Charger | 44-52 | 89-101 | 13-15 | 25s | Locks its aim during a 0.7s line warning, then charges at 290px/s for 0.48s; cooldown is 2.7s. |
| Fan | 36-44 | 53-65 | 9-11 | 32s | Maintains range and fires a three-shot aimed fan after a 0.6s warning. |
| Orbiter | 30-38 | 98-110 | 10-12 | 38s | Circles with distance correction and fires one aimed shot after a 0.6s warning. |
| Splitter | 42-48 | 81-90 | 11-13 | 45s | Pursues, then splits on defeat into up to two weak chasers; minions cannot split again. |

Ranged monsters wait until on screen and at least 1.1 seconds old before beginning attacks. Body collision has a 0.5-second arrival grace. Normal ranged cooldowns use the roster's `shoot_interval`, reduced gently over time with a 1.2-second floor. Projectile speed is at least 115px/s, using the roster value plus a time bonus capped at 65px/s. Bullets live at most seven seconds and are culled beyond the arena margin. Ordinary enemies expire after 70 seconds or after moving sufficiently below the screen; bosses persist until defeated. Enemies may overlap under pressure; there is no separate crowd-separation system.

Each record uses `id`, `name`, `texture`, `behavior`, `attack_type`, `health`, `damage`, `speed`, `score`, `shoot_interval`, `bullet_speed`, `radius`, `tier`, `description`, frame metadata, source information and an original export hash. The current game uses the `health`/`damage` names rather than the preliminary plan's `hp`/`contact_damage` schema.

## Difficulty and crowned bosses

After a first spawn at 0.45 seconds, ordinary spawning follows `max(0.23, 0.88 - elapsed*0.0018)` seconds. Groups grow from one to four, adding one member every 75 seconds. An active boss multiplies the interval by 1.8; the post-boss relief period multiplies it by 2.8. The enemy cap always remains 100.

Ordinary health scales by `1 + min(1.6, elapsed/430)`, reaching a 2.6x maximum. Speed scales up to 1.4x; damage grows slowly and caps at 26. Weak split minions use `12 * health_scale` health, smaller radius, one XP and 35% of their parent's base score before multipliers. These caps preserve a useful movement/damage skill curve through a long run.

The first boss arrives at 45 seconds. Later arrivals target 45 seconds after the previous spawn, with only one boss alive at once. If a regular wave fills the cap, the director makes room for the scheduled boss. Defeating it enforces at least 12 seconds before the next arrival and five seconds of reduced ordinary spawning.

The first boss uses the original Cinder Tinpot. Later bosses choose a generated monster silhouette and enlarge it to about 103px, with a crown, name and health bar. Health starts at 560 and multiplies by 1.21 per boss, with exponent growth capped after twelve increases. Every boss attack has a 0.85-second warning and a 1.5-2.9-second recovery cadence. Its repeating patterns are a five-shot fan, a three-shot fan for the first boss or locked charge for later bosses, then an eleven-shot ring that leaves three radial slots empty as a safe wedge. It repositions between attacks. Boss charges last 0.48 seconds at 340px/s.

Boss defeat clears all hostile bullets, immediately heals 30 up to maximum, gives 18 XP and 15x normal kill score, and drops a 25-health heart plus Hurricane. Titles cycle through The Tinpot King, Duchess Wobble, Mossjaw the Hungry, Sir Spit-a-Lot, The Pumpkin Problem, Madame Moonmoth, Captain Clatter and The Crown of Slop.

## Rewards, pickups and automatic upgrades

Kills increase the combo and refresh a 2.8-second timeout. A timeout or received damage resets it. The score multiplier is 1x below five kills, 2x at five, 3x at twenty and 4x at thirty-five. Boss and gold rewards use that multiplier; perfect bullet guards award a small flat score.

Every ordinary kill drops two XP, a split minion drops one, and a boss drops eighteen. Gems and other drops move toward the knight within `min(140, 64 + level*3)` pixels, then collect within 23px. Level one needs eight XP; later requirements are `int(8 + level^1.28*3)`. Level-up never opens a selection menu. It cycles these automatic upgrades:

| Upgrade | Increase and cap |
| --- | --- |
| Sharper Steel | Damage +14%, capped at 130. |
| Quicker Slices | Swing interval multiplied by 0.94, floored at 0.27s. |
| Longer Reach | Reach +5px, capped at 116px. |
| Heart of a Knight | Maximum health +8, capped at 220; heal 18. |
| Stronger Guard | Guard capacity +8, capped at 190; restore 30 reserve. |

| Pickup | Implemented effect |
| --- | --- |
| Heart | Heal at least 22, or the pickup's larger value, up to maximum health. |
| Gold | Award `75 * score_multiplier`; it does not pull other gems. |
| Haste / Quicksilver | Add 9s; swings use 0.67x interval and movement becomes 12% faster. |
| Hurricane | Add 9s; reach +34px, half-arc 1.42 radians and damage +30%. |
| Ward | Add 12s and reset protection to three hits. |
| Magnet | Add 9s; attraction radius becomes 230px and pickup movement becomes 310px/s. |
| Frost | Add 6s; enemy movement becomes 0.65x and bullet movement 0.62x. |
| Spark / Thunderblade | Add 9s; every 0.9s damage up to three enemies within 245px for 55% sword damage. |

Timed pickups extend their matching effect up to eighteen seconds; they do not accumulate unlimited strength. Ward charges are replaced rather than added. Non-minion special-drop chance is 16%, or 23% below 40% health; below 35% health the selected special is additionally biased toward a heart. The third kill guarantees Haste. Drops last fourteen seconds and fade near expiry. At the sixty-drop cap, added XP merges into an existing XP pickup; other drops can be suppressed by the cap.

## Local progression, pause and persistence

Local progression keeps score/time/combo/boss bests, lifetime run/kill/boss/playtime/pickup totals, discovered generated monster IDs, thirteen badges, the last thirty completed results and fourteen dated daily bests. Both styles are available from the first launch. A daily run always uses Sword and a shared seed derived from the UTC calendar date; normal runs use a fresh seed. Separate encounter and loot RNG states survive an active-run restore.

Pause releases gestures and stops hazard simulation. Android backgrounding or focus loss pauses/saves; resume grants at least 0.45 seconds of damage grace. Active runs save at start, every ten running seconds, on pause/backgrounding and on a close request. Restored runs wait behind the resume overlay with no stale movement. Finishing a run records completed-run totals and clears its active snapshot.

The version-one local save uses a flushed temporary file, replacement and previous valid backup. The profile is capped at 1 MiB; an active snapshot is capped at 128 KiB. Version, shape, IDs, numeric ranges, finite values and entity counts are checked. Corrupt primaries recover from backups; future-schema files are preserved. An invalid active run can be discarded without erasing a valid profile.

## Achievements, leaderboards and cloud integration

All thirteen local semantic achievement keys work without Google configuration. Names below are the saved badge titles shown by the badge screen; some brief in-run toast labels are shorter.

| Key | Trigger | Badge title |
| --- | --- | --- |
| `first_blood` | First lifetime kill. | First Slice |
| `boss_slayer` | First lifetime boss defeat. | Crown Collector |
| `century` | 100 lifetime kills. | A Hundred Little Problems |
| `hundred_club` | 100 kills in one completed run. | A Hundred in a Hurry |
| `survivor_60` | Survive 60s in one completed run. | Minute Knight |
| `survivor_180` | Survive 180s in one completed run. | Three Minute Hero |
| `survivor` | Survive 180s in one completed run; separate compatible key. | Still Standing |
| `legend` | Defeat five bosses in one run. | Knight of Infinite Nonsense |
| `combo_25` | Reach a 25-kill combo. | Slice Streak |
| `score_10000` | Reach 10,000 score. | Five Digits of Slop |
| `thousand_kills` | 1,000 lifetime kills. | Slop Sweeper |
| `ten_runs` | Complete ten runs. | Back for More |
| `collector` | Defeat/discover all 100 generated species. | Bestiary Complete |

Configurable leaderboard keys are `high_score`, `longest_run` in whole seconds, `bosses_in_run`, and optional `daily_score`. Competitive records come from completed runs, with queued best values rather than per-frame submissions. Daily date keys and lookup use UTC; Google's native daily leaderboard bucket/reset is a separate platform boundary.

`config/play_services.json` ships disabled with blank IDs. The vendor plugin and adapter support Android authentication, native leaderboards/achievements, optional absolute-step incremental achievements, and cloud profile snapshots when configured later. Gameplay, saves and local scores/badges remain available while services are disabled, offline, unavailable or timing out. Native setup and server behavior still require real Google project IDs, linked credentials and signed-device testing; see `PLAY_SERVICES_SETUP.md`.

The saved-game slot is `infiniteslash_profile_v1`. It contains versioned persistent profile progression and a verification nonce. Active runs and run history are not uploaded. Cloud merge preserves maximum bests, discovered species and achievements, and uses per-device counter maxima so repeated merging does not double-count lifetime totals. Merge leaves this device's preferences unchanged. Native account changes suspend automatic sync instead of silently combining another account's data.

The vendor plugin lacks a native conflict-resolution entry point, and its save callback precedes commit completion. The adapter preserves/merges useful local progress, reads back the write nonce and pending-change state before acknowledging a save, and suspends ambiguous/conflicted/timed-out snapshot operations for the session. This is implemented client handling; it is not a claim that live cloud conflicts or server commits have been verified.

## Resource limits and verification

The simulation caps at 100 enemies, 240 hostile bullets, 60 drops, 90 effects and twelve sound voices. There are no separate floating damage-number entities. Fixed physics runs at 60Hz, with bounded catch-up and per-step delta. One cached monster atlas serves 101 creature entries, each with four frame regions. Cached projectile/shadow textures and separated render passes reduce drawing commands without lowering collision/entity limits. Combat never loads an asset.

The gameplay suite covers starts, controls, protection, attacks, all behavior families, bosses, rewards, pause/restart, malformed snapshots, RNG restore and five-minute capped stress. Services, UI, audio, assets, rendered screenshots and Android build/smoke checks have separate evidence. Measured desktop ordinary/saturated rendering reaches the 60 FPS cap after batching. Physical Android phone GPU, battery and thermal performance remains a separate verification requirement. Consult `QA_FINDINGS.md`, `PERF.md`, `ANDROID_TESTING.md` and the final verification report for methods and limits.
