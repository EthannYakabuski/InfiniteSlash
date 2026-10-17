# The Crownfall update — 0.3.0

This is the current gameplay specification for the 2026-10-16 update. The earlier 0.2.x reports retain their historical test/build evidence. APKs and bundles require the final native verification in `PRODUCTION_ANDROID.md`; desktop tests do not establish real phone thermal or battery performance.

## Stages and escalating encounters

Player level drives encounter strength. Stage 1 is levels 1–29, Stage 2 is 30–49, Stage 3 is 50–79, and the endgame starts at 80. The twelve existing boss identities and their rare variants remain intact. Their weighted selection follows level: tier weights 88/10/2 below 20, 10/76/14 at 20–49, 3/20/77 at 50–79, and 1/9/90 from 80. Immediate repeats remain excluded, and the boss RNG remains separate from loot and upgrade RNG.

Ordinary enemy HP compounds by 1.62 per ten-level band, damage by 1.38, with smaller within-band increments. Stage 2 adds health ×2.4 and damage ×1.65; Stage 3 adds health ×5.5 and damage ×2.65. Movement, shot speed, volley size, attack frequency and spawn population also rise, with bounds to keep the simulation finite. These enemy gains exceed the player's normal additive permanent-stat growth. Level 50 is a major difficulty spike; levels near 100 are deliberately punishing, while the run continues beyond 100.

Boss health applies additional multipliers at 20, 30, 50 and 80, and also increases across encounters. Later bosses pursue the knight, lunge more often, attack sooner and enter an enraged phase below 35% health. The enraged label, movement and cooldown reduction communicate that phase.

From level 20, boss attacks alternate circular fire zones, rectangular ground fissures and expanding concave electric pulse waves. Each spell has a visible 0.9-second warning. Fire lingers, quakes strike their marked strip, and pulses preserve a broad visible escape gap. The same geometry draws and tests each hazard. Dash immunity applies; guard absorbs damage normally. Later levels add simultaneous fire zones and larger projectile volleys. Boss defeat clears both bullets and elemental hazards.

## Creatures, night and Crownfall Keep

The original 100 generated species and supplied Cinder Tinpot are preserved. Fifty additional stage-two species appear exclusively at levels 30–49: 17 fast glass cannons, 17 slow armored tanks and 16 ranged volley specialists. Fifty additional species spawn only at night, with 20 available early, 20 from level 30 and 10 from level 50. All 100 new sheets come from the real Kenney Creature Mixer full Randomize → Save spritesheet workflow at 8×. See the roster and export provenance for exact identities, stats and hashes.

At level 50, surviving cohorts become visibly ascended with violet outlines. Their base stat floors rise before level multipliers are applied, so retiring the stage-two veterans cannot accidentally make the new stage easier. Ascended tanks also telegraph ground-fissure stomps. Their starting health floor is 1,000, fast attackers use at least 100, and ranged units at least 250, before the large stage/level multipliers.

The arena repeats a 180-second day cycle: day until 65 seconds, dusk from 65–85, full night from 85–150 and dawn from 150–180. Night-only arrivals stop at dawn; creatures already present continue fighting. Deep blue environment lighting, warm roadside lights and small ground glints make night distinct while keeping projectiles, the player and the HUD readable.

At level 50, the road enters **Crownfall Keep**. Its pale stone floor, cobbles, ruined arches, battlements and rubble use existing Kenney Tiny Town/Farm assets. Infinite scrolling and scenery-only collision behavior continue. Entering awards **Beyond the Kingdom** locally and queues its future Google unlock.

## Rechargeable guard

Guard protects while moving and standing still. It never drains merely from holding a stance, and it no longer slows automatic slashes. The previous stationary parry mechanic is retired.

| Starting guard stat | Sword | Shield |
| --- | ---: | ---: |
| Reserve | 65 | 165 |
| Attack-free regeneration delay | 0.5 seconds | 0.3 seconds |
| Regeneration rate | 22/second | 28/second |
| Minimum block cost | 12 | 5 |
| Damage-dependent cost | Incoming damage ×1.2 | Incoming damage ×0.8 |

Each accepted attack spends the larger of its minimum block cost and damage-dependent cost, and restarts regeneration delay. Guard absorbs the whole hit if sufficient reserve remains. If only half its required cost remains, it absorbs half the damage and the rest reaches health. Contact hits have a 0.35-second interval to avoid draining guard once per physics frame; individual projectiles each spend reserve. Health damage retains the existing 0.7-second grace period and combo reset. Dash remains invulnerable, and Ward remains a separate three-hit pickup.

Guard starts recovering automatically after the delay, even at zero and while stationary. Upgrade choices can change capacity, regeneration speed and delay. The HUD always displays the actual remaining percentage.

## Build choices and XP

Every level still pauses combat and presents exactly two distinct offers. Selecting one applies one reward. Actors, hazards, world time, combo, buffs, guard recharge, dash and Overdrive freeze during the decision. Excess XP queues further explicit choices. Pending IDs, the build, and RNG state survive a save without rerolling.

The XP goal belongs to the displayed level. The old goal is 8 at level 1, otherwise `int(8 + level^1.28 × 3)`. Round up after multiplying it by 1.25 through level 20, 1.5 at 21–40 and 2 above 40. An old active run preserves its fraction of progress into the next level when adopting the new requirement.

The catalog has **103 choices**, including **72 ordered trade-offs** across damage, slash cadence, reach, maximum health, guard capacity, movement, guard regeneration, regeneration delay and dash recharge. Every ordered pair of different core stats has a named card. Descriptions show the actual before/after benefit and cost; health and guard fractions are preserved when a trade changes their maximum. Choices with no real benefit or no real sacrifice are excluded.

Rare options arrive at levels 10, 20, 30 and 50, including defense and mobility as well as offense. Six legendary upgrades may appear from level 25, at 1.2% per eligible offer slot: Phoenix Oath, Blood Chalice, Worldbreaker, Everguard, Stolen Hourglass and Eternal Encore. They add a once-per-run fatal-hit rescue, lifesteal, exceptional damage/reach, guard recovery, cadence/dash improvements or combo grace. Phoenix Oath restores half health and full guard and cannot be refreshed by saving.

Damage, health and guard retain repeatable growth after level 50. Cadence, reach, speed and recovery have useful safety bounds. A run never falls back to purse-only offers merely because the old class caps were reached. See [the catalog and balance details](PRODUCTION_BUILDS.md).

Purses enter the normal pool from level 40 as optional score sacrifices. Royal Purse gives 10,000 plus 250 per level above 40. Lucky Purse gives 5,000–30,000 plus 500 per level above 40. Permanent upgrades remain available beside treasure.

Random special-drop chance is halved: 8% normally and 11.5% below 40% health. The initial guaranteed Haste is removed; a boss's Hurricane drop is 50% rather than guaranteed. Healing and XP from bosses remain, so random temporary powers have less influence over a run than the player's build.

## Overdrive

Flick through enemy shots to destroy them while dashing. Each cleared shot adds 12 charge; reaching 100 triggers six seconds of Overdrive with +25% slash damage and 15% shorter slash intervals. Charge does not build during an active burst. The lower HUD shows charge, the triggering action, and burst time. This is earned through positioning and timing and uses the existing one-thumb dash gesture.

## Records and backend handoff

Highest combo and highest level join high score, longest run and bosses defeated in one run. The existing bosses board is retained. Completed runs record actual best combo, reached level and boss kills, and preserve higher pending values when older submissions acknowledge.

Bestiary milestones reward 50/100/150/200 **different generated species defeated across runs**, with cloud collection union and duplicate protection. Legacy discoveries were written on kills and migrate into the defeated-species collection. The existing Google collector remains its valid Incremental target of 100 and is labelled Bestiary Pioneer. Crown Census continues to mean all twelve bosses.

Five new Standard achievement IDs and two leaderboard IDs are awaiting the owner. Local goals and queued submissions work in the meantime. The existing fourteen achievement IDs and three boards are preserved. Exact names, descriptions, settings and seven 512×512 icons are in [the registration kit](../store/production-update/README.md).

## Acceptance ledger

| Request | Implementation |
| --- | --- |
| A, M | Level-scaled boss HP/activity, elemental spells and enraged phase |
| B, C, V | Fifty real new stage-two mixer exports, three combat roles |
| D | 10,000+ purses and larger seeded gambling purse |
| E, P, T | Level-50 spike, ten-level scaling, stronger attacks, faster waves |
| F–H | Exact 25%/50%/100% XP bands with upward rounding |
| I–L, N, O | 103 choices, stage rares, six legends, 72 swaps, continued growth |
| Q | Passive rechargeable guard, per-class delays and build stats |
| R | Dramatic cycle, fifty real night exports, four species milestones/icons |
| S | Combo and level boards/icons; existing boss board reused |
| U | Halved random drops and fewer guaranteed temporary buffs |
| W | Existing-asset Crownfall Keep, level-50 achievement/icon |
| X | Skill-earned Overdrive from dashing through shots |

Final test counts, rendered captures, measured performance and native artifacts are recorded in the verification report after completion. Real Play-account unlocks, physical-device performance and Console publication remain owner testing/release steps.
