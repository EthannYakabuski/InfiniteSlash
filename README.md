# InfiniteSlash

**One thumb. Endless trouble.** A portrait, top-down fantasy slasher and bullet hell built in Godot 4.5.1 for Android.

Launch directly into a living arena, tap the sword or shield, and play. Drag anywhere to steer; the knight swings automatically. Guard automatically absorbs hits and regenerates after a short attack-free delay. Flick quickly to dash. Defeat absurd creatures, collect upgrades, and keep the combo alive. A fallen knight is one tap away from another run.

## Play

- Open `project.godot` in the tested Godot 4.5.1 editor and press **F5**.
- Android development build: `builds/InfiniteSlash-debug.apk`, produced by the `AndroidDebug` export preset for Android 7.0/API24+ ARM64 phones and the x86 test emulator.
- Desktop controls: mouse drag or WASD/arrows; Space dashes, Escape pauses.
- Class cards show the tradeoffs before one-tap play: Sword has 80 HP, 32 damage and fast swings/movement; Shield has 170 HP, 24 damage and slower attacks/movement with a much larger, more efficient rechargeable guard.
- Guard works while moving and standing still; Sword regenerates after 0.5 seconds without an accepted attack, Shield after 0.3 seconds. Dashes and damage grace give short, visible protection; neither grants permanent safety.
- Every level pauses the arena for two randomized upgrade choices. There are 103 cards, including 72 stat trade-offs, rares at levels 10/20/30/50 and six legendary options from 25. Permanent damage, health and guard upgrades continue after level 50.

## Included

- 200 unique, named Creature Mixer monsters with four animation frames, plus the supplied Cinder Tinpot. Fifty new stage-two creatures unlock at 30; fifty additional species spawn only at night.
- Endless scrolling Kenney scenery, a dramatic day/night cycle, and Crownfall Keep from level 50 using the supplied castle/stone tiles.
- Locked charge warnings, aimed shots, fans, orbiters, splitters, tanks, and twelve named crowned bosses drawn from three weighted tiers, including three rare bosses.
- Health, XP, paused two-choice level upgrades, combos, score, six temporary powerups, healing hearts, score gold and XP gems.
- Original knight/sword/shield atlas, original looping music, and reused combat and interface sounds.
- Local bests, run history, 20 local badge keys, unique species/boss discoveries, daily seeded runs, and a score-copy challenge card.
- Level-scaled enemy pressure and bosses with telegraphed fire circles, ground fissures and concave pulse waves from level 20.
- Dash through shots to earn Overdrive: six seconds of stronger, faster slashes.
- Independent saved music/effects switches, larger dash/guard cards and visible cooldown progress.
- Pause/background safety, recoverable active runs, versioned profile saves and backup recovery.
- Bounded enemies, projectiles, pickups, effects and sound voices. Native-sized monster atlas reduces texture changes and memory while preserving every original export.
- Configurable Google Play Games sign-in, leaderboards, achievements and cloud-profile snapshots through the bundled plugin.

Google Play Games now has **19 configured achievement IDs and five configured leaderboards** for `com.slash.game`, including all seven newly supplied IDs. The original mappings and cloud-profile slot are preserved, and offline badges/best records replay after eligible authentication. See the [configured IDs and seven-icon kit](store/production-update/README.md) and [setup guide](docs/PLAY_SERVICES_SETUP.md). Live Google-account validation requires an eligible tester and matching signed installation. The optional daily board and original duplicate local three-minute badge remain intentionally unmapped.

The current configuration patch is **0.3.1 / Android code 9**; see [its configuration/build report](docs/PLAY_SERVICES_0_3_1.md). It preserves the **0.3.0 / code 8** gameplay update documented in [the acceptance ledger](docs/PRODUCTION_UPDATE.md), [build catalog/balance](docs/PRODUCTION_BUILDS.md), [verification](docs/PRODUCTION_VERIFICATION.md) and [historical Android report](docs/PRODUCTION_ANDROID.md). Older versioned artifacts and their evidence remain historical. Package changes do not migrate another package's local saves automatically.

## Verification

Run commands from this project directory with your Godot executable in place of `godot`:

```powershell
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/test_services.gd
godot --headless --path . --script tests/test_game.gd -- --test
godot --headless --path . --script tests/test_production_combat.gd
godot --headless --path . --script tests/test_production_progression.gd
godot --headless --path . --script tests/test_upgrade_catalog.gd
godot --headless --path . --script tests/ui_layout_test.gd
godot --headless --path . --script tools/test_audio.gd
godot --path . --script tests/capture_game.gd -- --test
godot --path . --script tests/benchmark_rendered.gd -- --test
```

Tests use separate fixture paths under `output/test-data` or `output/review`; they do not overwrite normal progress. The current configured-ID services suite passes **458 checks**, with patch evidence in [the 0.3.1 report](docs/PLAY_SERVICES_0_3_1.md). Gameplay checks and measured limits remain documented in [the 0.3.0 verification report](docs/PRODUCTION_VERIFICATION.md). A desktop simulation or Android emulator does not establish real-phone GPU, battery or thermal performance.

The optional `tools/build_monster_atlas.gd` rebuilds the native-pixel atlas from the original sheets. The generated atlas is already included; run a Godot import after rebuilding it. `tools/validate_assets.py` validates all source sheets, identities, stats, original pixels and the music loop.

## Project map

| Path | Purpose |
| --- | --- |
| `scenes/main.tscn`, `scripts/game.gd` | Fixed-step combat, controls, spawning, rewards and run state |
| `scripts/class_profiles.gd` | Shared Sword/Shield starting balance and legacy migration limits |
| `scripts/upgrade_catalog.gd`, `scripts/progression.gd`, `scripts/boss_catalog.gd` | Builds, level-driven scaling and weighted boss identities |
| `scripts/boss_hazards.gd` | Shared elemental telegraph/damage geometry |
| `scripts/world.gd`, `scripts/game_ui.gd` | Scrolling environment and portrait interface |
| `scripts/audio_manager.gd` | Cached sound pool and music |
| `scripts/services/` | Local persistence and Google Play adapter |
| `data/monsters.json` | Full roster, stats and source hashes |
| `config/play_services.json` | Backend IDs and feature switch |
| `Assets/Generated/` | Knight, weapons, optimized atlas and original music |
| `tests/`, `tools/` | Gameplay, services, UI, audio, rendering and Android checks |

See [asset review](docs/ASSET_REVIEW.md), [monster roster](docs/MONSTER_ROSTER.md), [game design](docs/GAME_DESIGN.md), and [credits](docs/CREDITS.md).
