# Crownfall update verification — 0.3.0 / code 8

Verified on 2026-10-16. The release implements the [A–X acceptance ledger](PRODUCTION_UPDATE.md). Evidence here belongs to the expanded 200-species roster, 103-card catalog and new guard/combat rules; earlier 0.2.x reports remain historical.

## Automated checks

| Suite | Result | Evidence |
| --- | --- | --- |
| Actual game scene and five-minute saturated simulation | 355 checks, zero failures | `output/review/production_game_103_release.log` |
| New integrated guard/stages/elementals/builds/persistence | 178 checks, zero failures | `output/review/production_combat_release.log` |
| All 103 upgrades / 72 ordered trade-offs | 841 checks, zero failures | `output/review/production_upgrade_catalog_tests.log` |
| XP bands and level-driven difficulty | 34 checks, zero failures | `output/review/production_progression_tests.log` |
| Local/cloud/Google adapter with simulated clients | 408 checks, zero failures | `output/review/production_services.log` |
| All twelve boss identities saved directly to disk | 72 checks, zero failures | `output/review/production_active_boss.log` |
| Boss discovery, configured IDs and cloud union | 22 checks, zero failures | `output/review/production_boss_progress_verified.log` |
| Boss catalog and weighted selection | 20 checks, zero failures | `output/review/production_boss_catalog.log` |

**1,930 counted checks pass.** Additional UI, audio, image/asset and archive validators pass separately and are not included in that count. Tests use isolated fixture paths and do not overwrite normal player progress.

The five-minute stress simulation advances 18,000 fixed steps, reaches the full 140-enemy/480-projectile bounds and keeps entity/state values finite. Its final run averaged 2.14 ms per simulation step, p95 3.61 ms, with a 104.07 ms maximum during other host work. This is CPU simulation timing, not a phone FPS or thermal measurement.

## Regression cases

- Guard remains active during movement and rest, never drains without attacks, restarts its exact per-class recovery delay after accepted hits, and passes proportional overflow to health.
- Full, partial and exhausted guard all interact consistently with Ward for body contact, projectiles and elemental hazards. Saving cannot refresh a used Phoenix Oath rescue.
- Twelve thousand deterministic spawn selections check day/night exclusivity, level gates, stage-two retirement at 50 and weighted cohort prominence. Actual level-49 veteran tanks are compared with level-50 ascended tanks so changing cohorts cannot make the new stage easier.
- Fire, quake and pulse telegraphs use their collision geometry. Warning phases do no damage, and pulse gaps are safe. Late normal tanks have visible stomp preparation and bounded recast times.
- Dashing through actual shots charges Overdrive, while health immunity, attack bonuses and frozen decision timing remain independent.
- Every trade-off has a real benefit and sacrifice, including inverse delay/cadence/dash values. The catalog verifies rarity gates, rare/legendary choices, floors, ceilings, useful growth through long runs, two distinct offers and seeded repeatability.
- A saturated late run with all enemies, bullets, drops, hazards, build choices and precise positions survives direct storage, reload and restore. A roughly 149 KB case exposed the old 128 KiB limit; active snapshots now allow 512 KiB within the existing 1 MiB profile envelope.
- Legacy original-creature index 100 remaps to the original's new index 200. Modern entities also save stable species IDs. Old XP progress adopts the new goal proportionally; previously offered purses remain selectable even below their new gate. Resuming an older run already above level 50 awards the biome badge immediately.
- Save/restore preserves guard timing, new build flags, used rescue state, elemental geometry, Overdrive, RNG streams and both exact pending offers. Dash-recharge trade-offs above the old baseline survive restore.
- Bestiary milestones count validated unique defeated species, migrate old kill-based discoveries, merge cloud sets without inflation and retain pending online awards while new IDs are blank. Combo/level leaderboard queues preserve newer highs when older submissions acknowledge.

## Visual and asset verification

Layout/input checks pass at 540×960, 540×1110 and 1080×1920, including common/rare/legendary/trade cards, explicit GAIN/COST text, independent audio controls, paused choices, badges and large score/health values. Forty-eight real Godot renderer captures cover day, night, Crownfall Keep, Overdrive, all three elemental warnings/active phases, stage upgrades and audio restoration. Representative views were visually inspected; see [the contact sheet](../output/review/production_contact_sheet.png).

All eight promoted phone views are pixel-identical before and after the drawing optimization. The game now groups warning/halo geometry, monster atlas draws and health/crowns into separate passes. The world uses existing packed Town/Farm atlases; all 30 used regions match their individual source tile pixels exactly.

Asset validation confirms 200 distinct PNG hashes and decoded creature sheets, valid four-frame animation, unchanged original 100 manifest entries, 50 stage-two and 50 night-only additions, all 201 runtime atlas strips, and the existing unclipped seamless music loop. [Creature Mixer export provenance](../output/review/production-mixer/GENERATION_NOTES.md) includes real Randomize/8×/Save evidence and every download's hash.

The refreshed store kit has 24 current screenshots, 19 achievement icons and five leaderboard icons. All dimensions, PNG/RGB requirements, sizes, description limits, source pixels and ZIP CRCs pass. Seven-inch and ten-inch categories intentionally share the same valid 1080×1920 views; the 24 earlier screenshots are preserved separately. The seven new service icons are 512×512 and below 1 MB each. Store screenshot provenance is actual deterministic desktop rendering, not an assertion of tablet hardware capture.

## Performance and native scope

The ordinary level-30 desktop case measured 60.0 FPS. After batching, full-cap level-50 and level-100 cases measured 57.9 and 56.8 FPS with approximately 47% fewer draw calls and stable 23.68 MiB texture memory. Caps remain 140 enemies, 480 bullets and 24 hazards. Absolute-cap frames can still exceed 16.67 ms. See [hardware, workload, host-contention caveats and raw results](PRODUCTION_PERFORMANCE.md).

Final Android artifact hashes, signatures, packaged configuration, alignment and actual emulator smoke results are documented separately in [PRODUCTION_ANDROID.md](PRODUCTION_ANDROID.md). Desktop tests and simulated service clients do not establish physical-phone performance or a live Google achievement unlock.

Before public release, test the signed build through the owner's Play testing track on representative physical phones, including sustained high-level play, background/resume, audio, touch comfort and thermal behavior. Complete eligible-account Play Games checks, provide the five new achievement/two leaderboard IDs and publish their definitions when ready. The [registration kit](../store/production-update/README.md) lists exact goals and icons. No Console upload, publication or Google-account interaction was performed by this task.
