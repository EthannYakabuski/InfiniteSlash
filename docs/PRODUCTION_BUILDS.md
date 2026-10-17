# Stage progression and permanent builds — 0.3.0

This document describes the production gameplay update's progression and upgrade catalog. It does not establish a live Google Play server result or phone performance certification.

## Level and difficulty bands

| Current level | Stage | Progression role |
| --- | --- | --- |
| 1–29 | Meadow Mayhem | Establish a build; rare options begin at 10, elemental bosses at 20 |
| 30–49 | The War Host | Specialist enemy pool, stronger rares and much greater pressure |
| 50–79 | Crownfall Keep | Late biome, overwhelming enemies and powerful permanent choices |
| 80+ | The Impossible Crown | Endgame boss health and sustained survival pressure |

The XP goal belongs to the **current level displayed on the HUD**. Earning that goal advances to the next level. Level 1 now requires 10 XP instead of 8. For subsequent levels, the original integer goal `int(8 + level^1.28 × 3)` is multiplied by 1.25 through current level 20, 1.50 for 21–40, and 2.00 from 41 onward. Fractional results round upward.

Enemy health compounds by **1.62× every ten levels**, and damage by **1.38×**. Both also rise within each ten-level band. At level 30, the new stage adds a 2.4× health / 1.65× damage multiplier; from level 50 these stage multipliers become 5.5× / 2.65×. These are global multipliers applied to individual creature base stats. Speed, projectile speed, volleys and attack frequency increase alongside them.

Bosses apply additional health multipliers: 1.9× from level 20, 2.6× from 30, 3.6× from 50, and 4.8× from 80. Their chase speed and attack frequency also increase. Individual boss identity and encounter scaling remain separate inputs. Elemental eligibility begins at level 20.

Permanent damage, health and guard improvements use **additive gains based on the selected class's starting stats**, rather than repeatedly multiplying the already improved stat. Those gains increase by 1.5% per current level above 1. Enemy scaling therefore overtakes a focused offensive build as a run approaches level 100. The supported numeric progression range is bounded at level 1,000; extreme multipliers have defensive safety ceilings.

## Every level retains a build decision

The catalog contains **103 named choices**: nine common permanent upgrades, thirteen pure rare upgrades, six legendary upgrades, seventy-two tradeoffs, and three recovery/treasure choices. Each level presents two different eligible choices. At least one is a permanent upgrade whenever any permanent choice can still benefit the player. Two purses cannot take over an ordinary late-game level-up.

Damage, maximum health and guard capacity continue improving beyond the previous class caps. The only upper bounds on these three stats are numerical safety limits of one billion, far beyond an achievable run. Physical limits remain for movement, screen reach and attack cadence. A capped benefit disappears from the pool, and a tradeoff also disappears when its downside would no longer cost anything.

| Foundational choice | Effect | First level |
| --- | --- | ---: |
| Sharper Steel | Add 14% of base damage × level growth | 2 |
| Quicker Slices | Reduce slash interval by 6% | 2 |
| Longer Reach | Add 5 reach | 2 |
| Heart of a Knight | Add 8 × growth maximum health; heal up to 18 × growth | 2 |
| Stronger Guard | Add 8 × growth guard capacity; restore up to 30 × growth | 2 |
| Fleet Footed | Add 6% of class base movement speed | 3 |
| Guard Mending | Add 20% of class base guard regeneration × growth | 3 |
| Quickstep | Reduce dash recharge by 0.10 seconds | 5 |
| Swift Recovery | Reduce guard recovery delay by 12% | 5 |

Movement is bounded at 1.75× class base speed, reach at 240, dash recharge at 0.65 seconds, guard regeneration at 2,000 points/second, and guard delay at 0.08 seconds. Minimum slash intervals remain distinct: Sword 0.14 seconds and Shield 0.27 seconds. Tradeoffs can reduce movement to 120, reach to 36, maximum health to 12, guard capacity to 6, and guard regeneration to 3; they can extend slash interval to 3 seconds guard recovery delay to 2 seconds, or dash recharge to 2.5 seconds. Cards display the effective change near these boundaries.

## Rare and legendary choices

Rarity is chosen **before** the card within that rarity. Adding many tradeoffs cannot inflate or dilute legendary odds. Per-slot rare chance is 16% from level 10, 19% from 20, 23% from 30, and 26% from 50. Legendary chance is **1.2% per slot**, beginning at level 25. These chances apply when an eligible card remains in the chosen category; an empty category falls back to useful choices.

| First level | Pure rare choices | Build direction |
| --- | --- | --- |
| 10 | Keen Edge; Bulwark; Wind Dancer; Living Oak | Damage/reach; guard/regen; speed/dash; health/recovery |
| 20 | Vampire Steel; Thornmail; Storm Lungs | Slash lifesteal; reflected contact damage; guard regeneration |
| 30 | Titan Heart; Headhunter; Battle Cadence | Large health/guard; normal-enemy executes; damage/cadence |
| 50 | Abyssal Steel; Adamant Vow; Nightstrider | Large damage; large health/guard; movement/combo/recovery |

Keen Edge allows three picks. Lifesteal stops at 10%, reflected contact damage at 200%, normal-enemy execution threshold at 18% remaining health, and extra combo grace at 3 seconds. Their cards show actual effective values instead of promising an increase beyond a limit.

The six legendary choices begin at level 25:

- **Phoenix Oath:** survive one fatal hit per run, restoring 50% health and full guard. It cannot stack or be reacquired after consumption.
- **Blood Chalice:** add up to six percentage points of slash lifesteal, respecting the 10% cap.
- **Worldbreaker:** add a full class-base damage amount × growth and 20 reach.
- **Everguard:** add 120% of class base guard regeneration × growth and cut recovery delay by 35%.
- **Stolen Hourglass:** cut slash interval by 25% and dash recharge by 0.25 seconds, respecting their floors.
- **Eternal Encore:** add 1.5 seconds of combo grace and half a class-base damage amount × growth.

## Seventy-two meaningful tradeoffs

Every ordered pair of these nine core stats has a named card: damage, slash cadence, reach, maximum health, guard capacity, movement speed, guard regeneration, guard recovery delay, and dash recharge. There are nine possible gains with eight different sacrifices each. Stable saved IDs follow `trade_<sacrificed-stat>_for_<gained-stat>`.

The strongest versions unlock later. Tradeoffs are distributed across level 5, 10, 20, 30 and 50 gates; levels 20+ use rare rarity. All sixteen dash-related tradeoffs unlock at level 10 or later. Late variants improve the upside by 15%, 30%, or 60% while keeping the advertised downside. Damage, health, guard and regeneration upsides also receive normal level growth.

| Gained stat | Base upside | Sacrifice when this stat is the cost |
| --- | --- | --- |
| Damage | Add 26% of class base damage × growth | Lose 16% current damage |
| Slash cadence | Reduce slash interval by 14% | Increase current interval by 12% |
| Reach | Add 14 reach | Lose 10 reach |
| Maximum health | Add 24% of class base health × growth | Lose 16% current maximum health |
| Guard capacity | Add 30% of class base guard × growth | Lose 20% current capacity |
| Movement speed | Add 18% of class base speed | Lose 10% current speed |
| Guard regeneration | Add 40% of class base regeneration × growth | Lose 20% current regeneration |
| Guard recovery delay | Reduce delay by 28% | Increase current delay by 35% |
| Dash recharge | Reduce recharge by 0.12 seconds | Increase recharge by 0.20 seconds |

Examples include **Unburdened** (sacrifice guard for speed), **Glass Blade** (health for damage), **Hollow Armor** (health for guard), **Patient Heart** (cadence for health), **Rooted Renewal** (speed for regeneration), and **Slow Spring** (regeneration for a shorter guard delay). Health and guard capacity trades preserve the current health/reserve fraction, preventing them from secretly granting a full refill. All seventy-two full definitions are emitted to `output/review/production_upgrade_manifest.json` by the catalog test.

## Score versus survival

Purses first appear at level 40 with low selection weight. **Royal Purse awards 10,000 score**, plus 250 for each current level above 40. **Lucky Purse awards 5,000–30,000 score**, plus 500 per current level above 40 to both ends of that range. The chosen reward consumes the seeded run RNG and remains reproducible. Field Rations fully restores health and guard and only appears when one of them needs recovery.

## Verification scope

`tests/test_upgrade_catalog.gd` passes **841 checks**, covering all seventy-two real benefit/downside pairs for both classes, effective descriptions, floors, ratio preservation, eligibility, all rare gates, one-use revival, RNG reproducibility, two different offers, permanent late-game alternatives, purse ranges, dash ceilings and recovery, a ten-thousand-slot rarity sample and safe progression past the old caps.

`tests/test_production_progression.gd` passes **34 checks**, covering exact XP band transitions, stage gates, elemental eligibility, monotonic finite progression through level 1,000, ten-level enemy compounding, endgame pressure and player growth remaining below enemy health growth. These are catalog and progression checks; combat, UI, native package and device evidence are recorded by their respective integration checks.
