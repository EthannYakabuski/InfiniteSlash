# Gameplay QA

Verified the actual `scenes/main.tscn` and `scripts/game.gd` under Godot 4.5.1 on 2026-10-12. The test runner uses a separate profile beneath `output/test-data/game-qa`; it does not read or overwrite the player's progress. It loads the scene after startup so the real autoloads, UI, world and cached assets participate.

## Result

`tests/test_game.gd` passed **315 checks with zero failures** after the Shield damage follow-up. It covers both opening choices, movement speed, touch ownership, thumb release and parry, deliberate flick recognition, slow-drag rejection, one dash per gesture, dash cooldown and invulnerability, player bounds, damage grace, guard depletion and regeneration, ward charges, slash arc and reach, projectile clearing, defeated-enemy idempotence, splitter offspring, all eight monster behavior families, off-screen ranged firing, attack windups, boss availability under a full wave, a radial safe wedge, boss reward/relief, pickup expiry, upgrades and buff caps, pause, resume, death and restart.

The same suite exercises a real JSON snapshot round trip, encounter/loot RNG continuation, paused restoration, stale input clearing, wrong-type and non-finite saved scalar values, malformed enemy/bullet/drop dictionaries, large saved entity lists, and safe restored bullet bounds.

## Class distinction

The comparison scenarios exercise actual automatic attacks and finite guarding, using the same target and incoming pressure for both classes. They demonstrate the intended damage-versus-survival choice rather than only asserting stat assignments.

| Scenario | Sword | Shield |
| --- | --- | --- |
| Defeat the same 240 HP target while unguarded | 2.58 seconds | 5.42 seconds |
| Actual guarded attacks' damage across four seconds | 224 | 144 |
| Guard until exhausted, no hits | 2.03 seconds | 7.52 seconds |
| Guard under four bullets per second | 0.77 seconds | 3.87 seconds |
| Health after eight 20-damage contact hits, spaced 0.8 seconds apart | 0; defeated | 138; survives |
| Guard reserve restored by two seconds of movement | 44 | 56 |

Both classes retain distinct health, damage, attack-speed, reach and guard limits after repeated automatic upgrades. Version-three snapshots round-trip those values after switching classes. Legacy runs migrate to the chosen-class balance while preserving the injured-health and remaining-guard proportions, score, actors and RNG continuation. The class cards and HUD icon use the same shared profile source as gameplay.

The follow-up changes only Shield's starting damage from 18 to 24. Its target-clear time improves from the retained prior 7.82s result to 5.42s, and four seconds of actual guarded swings increase from 108 to 144 damage. Sword and all health/guard/recharge/cap comparisons remain unchanged. Version-two Shield snapshots receive a single 4/3 damage adjustment up to the unchanged 95 cap; all other saved stats/progress remain intact. Version-two Sword snapshots retain their damage, and version-three restoration does not repeatedly apply the buff. Fresh, upgraded, capped, previously injured and RNG/actor-continuation cases passed.

## Fixed findings

| Finding | Reproduction and correction | Verification |
| --- | --- | --- |
| A full regular wave could suppress a scheduled boss | The director advanced the boss counter/timer even when the enemy cap made spawning fail. It now makes room in a full ordinary wave before spawning the boss, while the total stays at or below 100. | Saturated regular-wave boss test passed. |
| A splitter's offspring could die in the same slash that created them | The slash iterated the enemy array while death appended fresh minions. Their slash marker now protects them from that creating swing. | Exactly two living offspring and one kill remain after the creating slash. |
| Exhausted stationary guard flickered between empty and tiny refills | The non-guarding branch regenerated reserve while stationary, contrary to the movement recharge rule. Stationary exhaustion now stays empty; movement restores reserve. | Six simulated seconds of stationary guarding reaches zero and stays unguarded, then a drag recharges it. |
| Malformed snapshots could cause unsafe casts or oversized hazards | Vector/scalar values, booleans, roles and relevant entity fields are checked before use, with finite numeric bounds and category caps. | Wrong-type and non-finite input cases were rejected or skipped, and oversized numeric bullet values were safely capped. |
| Music playback leaked at abrupt test shutdown | Audio cleanup now stops playback and clears streams. Music reuses its sole cached PCM resource rather than copying another 1.5 MB. Test runners release playback before their final frames. | The focused audio test passed with verbose shutdown and no ObjectDB/WAV leak warning. |

## Five-minute saturated simulation

The stress scenario drives **18,000 actual fixed steps at 60 steps per simulated second**, beginning at late-run difficulty. It uses the game's invulnerable demo steering and regularly replenishes threats/pickups/effects to exercise their limits. It completes 300 simulated seconds without stopping, with finite player state and bounded arrays throughout.

| Measurement | Result |
| --- | --- |
| Peak enemies | 100 |
| Peak hostile bullets | 240 |
| Peak pickups | 60 |
| Peak effects | 90 |
| Average simulation/visual-update step | 0.876 ms |
| 95th percentile step | 1.494 ms |
| Slowest observed step | 10.009 ms |
| Wall time for the simulation | 16.244 seconds |
| Kills / boss appearances | 4,057 / 6 |
| End level | 36 |

These are desktop **headless simulation** measurements, including the game's update/HUD work. They do not measure drawing throughput or Android device frame rate. The maximum includes a desktop outlier; the 95th percentile describes normal loaded steps more usefully. Portrait screenshots, live input behavior, Android export and emulator/device performance are verified separately by the main task.

All 101 creature entries reference one cached monster atlas, with four frame regions per creature, and the game's world/HUD node count remains fixed during the stress run. Cached projectile and shadow textures also avoid per-frame asset loads. No combat entity loads an asset.

## Reproduction

Set `APPDATA` to a disposable directory inside `output/test-data`, then run the existing Godot console executable against the project with `--headless --script res://tests/test_game.gd --log-file <absolute workspace log path> -- --test`. The project disables default file logging to avoid writing outside the chosen test area. `tools/test_audio.gd` is the shorter focused audio check.

Machine-readable results are saved in `output/review/game_validation.json`; the current 315-check log is `game_shield_buff_runtime.log`. `game_validation_before_shield_buff.json` and `game_class_runtime.log` retain the 274-check class revision before the damage adjustment, `game_runtime.log` preserves the earlier 199-check baseline, and `audio_runtime_verbose.log` records the focused audio check. The bundled Windows engine emits a root-certificate-store warning in this restricted environment before using its built-in certificate bundle. The gameplay and audio checks exit successfully.
