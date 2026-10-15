# InfiniteSlash

**One thumb. Endless trouble.** A portrait, top-down fantasy slasher and bullet hell built in Godot 4.5.1 for Android.

Launch directly into a living arena, tap the sword or shield, and play. Drag anywhere to steer; the knight swings automatically. Lift your thumb to guard, or flick quickly to dash. Defeat absurd creatures, collect upgrades, and keep the combo alive. A fallen knight is one tap away from another run.

## Play

- Open `project.godot` in the tested Godot 4.5.1 editor and press **F5**.
- Android development build: `builds/InfiniteSlash-debug.apk`, produced by the `AndroidDebug` export preset for Android 7.0/API24+ ARM64 phones and the x86 test emulator.
- Desktop controls: mouse drag or WASD/arrows; Space dashes, Escape pauses.
- Class cards show the tradeoffs before one-tap play: Sword has 80 HP, 32 damage and fast swings/movement; Shield has 170 HP, 24 damage and slower attacks/movement with much stronger, longer guarding.
- Guard reserve regenerates while moving. Dashes and damage grace give short, visible protection; neither grants permanent safety.
- Every level pauses the arena for two randomized upgrade choices. Build damage, cadence, reach, health, guard, movement or dash recharge; Keen Edge enters the pool at level 10.

## Included

- 100 unique, named Creature Mixer monsters with four animation frames and eight combat behaviors, plus the originally supplied Cinder Tinpot.
- Endless scrolling meadow, autumn and twilight scenery built from the supplied Kenney tiles.
- Locked charge warnings, aimed shots, fans, orbiters, splitters, tanks, and twelve named crowned bosses drawn from three weighted tiers, including three rare bosses.
- Health, XP, paused two-choice level upgrades, combos, score, six temporary powerups, healing hearts, score gold and XP gems.
- Original knight/sword/shield atlas, original looping music, and reused combat and interface sounds.
- Local bests, run history, 15 badges, monster/boss discoveries, daily seeded runs, and a score-copy challenge card.
- Independent saved music/effects switches, larger dash/guard cards and visible cooldown progress.
- Pause/background safety, recoverable active runs, versioned profile saves and backup recovery.
- Bounded enemies, projectiles, pickups, effects and sound voices. Native-sized monster atlas reduces texture changes and memory while preserving every original export.
- Configurable Google Play Games sign-in, leaderboards, achievements and cloud-profile snapshots through the bundled plugin.

Google Play Games is configured with the supplied real IDs for `com.slash.game`: 12 online achievements, three leaderboards and the stable cloud-profile slot. The local native fork adds awaited snapshot commits and bounded conflict resolution; **live Google validation remains pending** eligible tester access and matching signed installation. Gameplay and local progression remain usable offline. See the [owner/setup guide](docs/PLAY_SERVICES_SETUP.md), [supplied configuration and pending handoff](docs/PLAY_SERVICES_HANDOFF.json), and [native implementation/build evidence](docs/PLAY_SERVICES_IMPLEMENTATION.md). The [store upload kit](store/README.md) contains branding, individual icons mapped to the existing Google IDs and 24 screenshots; do not re-import the old achievement metadata draft. The current API36 native debug APK and signed Play AAB are built and verified; see [version 0.2.0 Android evidence](docs/ROUND2_ANDROID.md). Older unsigned AABs remain preparation artifacts. See also [Android build notes](docs/ANDROID_BUILD.md) and [Android testing](docs/ANDROID_TESTING.md). The package rename does not automatically migrate the old `org.infiniteslash.game` app's local saves.

The [2026-10-15 feature update](docs/ROUND2_UPDATES.md) documents two-choice builds, boss tiers and new achievements. The new badge icons and registration descriptions are in [store/boss-achievements](store/boss-achievements/README.md).

## Verification

Run commands from this project directory with your Godot executable in place of `godot`:

```powershell
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/test_services.gd
godot --headless --path . --script tests/test_game.gd -- --test
godot --headless --path . --script tests/ui_layout_test.gd
godot --headless --path . --script tools/test_audio.gd
godot --path . --script tests/capture_game.gd -- --test
godot --path . --script tests/benchmark_rendered.gd -- --test
```

Tests use separate fixture paths under `output/test-data` or `output/review`; they do not overwrite normal progress. The current gameplay suite passes 379 checks, including class comparisons, upgrade limits and existing-run migration. Configured services tests cover native failure/conflict paths with local storage and fake clients; see the [integration report](docs/PLAY_SERVICES_IMPLEMENTATION.md) for the current count and actual native-build evidence. Historical Shield-damage APK testing passed a focused five-screen Android follow-up with fresh Shield24 and an actual saved Shield18 migration; the preceding twelve-screen full class review is retained separately. Those old packages do not establish the configured native build's validation. Render captures and machine-readable results are in `output/review`. See [QA findings](docs/QA_FINDINGS.md) and [verification report](docs/VERIFICATION.md) for measured results and limits. A desktop simulation or Android emulator does not establish real-phone GPU, battery or thermal performance.

The optional `tools/build_monster_atlas.gd` rebuilds the native-pixel atlas from the original sheets. The generated atlas is already included; run a Godot import after rebuilding it. `tools/validate_assets.py` validates all source sheets, identities, stats, original pixels and the music loop.

## Project map

| Path | Purpose |
| --- | --- |
| `scenes/main.tscn`, `scripts/game.gd` | Fixed-step combat, controls, spawning, rewards and run state |
| `scripts/class_profiles.gd` | Shared Sword/Shield starting balance and distinct upgrade limits |
| `scripts/upgrade_catalog.gd`, `scripts/boss_catalog.gd` | Choice eligibility/effects and weighted stable boss identities |
| `scripts/world.gd`, `scripts/game_ui.gd` | Scrolling environment and portrait interface |
| `scripts/audio_manager.gd` | Cached sound pool and music |
| `scripts/services/` | Local persistence and Google Play adapter |
| `data/monsters.json` | Full roster, stats and source hashes |
| `config/play_services.json` | Backend IDs and feature switch |
| `Assets/Generated/` | Knight, weapons, optimized atlas and original music |
| `tests/`, `tools/` | Gameplay, services, UI, audio, rendering and Android checks |

See [asset review](docs/ASSET_REVIEW.md), [monster roster](docs/MONSTER_ROSTER.md), [game design](docs/GAME_DESIGN.md), and [credits](docs/CREDITS.md).
