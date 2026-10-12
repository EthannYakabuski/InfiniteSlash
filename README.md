# InfiniteSlash

**One thumb. Endless trouble.** A portrait, top-down fantasy slasher and bullet hell built in Godot 4.5.1 for Android.

Launch directly into a living arena, tap the sword or shield, and play. Drag anywhere to steer; the knight swings automatically. Lift your thumb to guard, or flick quickly to dash. Defeat absurd creatures, collect upgrades, and keep the combo alive. A fallen knight is one tap away from another run.

## Play

- Open `project.godot` in the tested Godot 4.5.1 editor and press **F5**.
- Android development build: `builds/InfiniteSlash-debug.apk`, produced by the `AndroidDebug` export preset for Android 7.0/API24+ ARM64 phones and the x86 test emulator.
- Desktop controls: mouse drag or WASD/arrows; Space dashes, Escape pauses.
- Class cards show the tradeoffs before one-tap play: Sword has 80 HP, 32 damage and fast swings/movement; Shield has 170 HP, 24 damage and slower attacks/movement with much stronger, longer guarding.
- Guard reserve regenerates while moving. Dashes and damage grace give short, visible protection; neither grants permanent safety.

## Included

- 100 unique, named Creature Mixer monsters with four animation frames and eight combat behaviors, plus the originally supplied Cinder Tinpot.
- Endless scrolling meadow, autumn and twilight scenery built from the supplied Kenney tiles.
- Locked charge warnings, aimed shots, fans, orbiters, splitters, tanks, and recurring crowned bosses.
- Health, XP, automatic level upgrades, combos, score, six temporary powerups, healing hearts, score gold and XP gems.
- Original knight/sword/shield atlas, original looping music, and reused combat and interface sounds.
- Local bests, run history, 13 badges, monster discoveries, daily seeded runs, and a score-copy challenge card.
- Pause/background safety, recoverable active runs, versioned profile saves and backup recovery.
- Bounded enemies, projectiles, pickups, effects and sound voices. Native-sized monster atlas reduces texture changes and memory while preserving every original export.
- Configurable Google Play Games sign-in, leaderboards, achievements and cloud-profile snapshots through the bundled plugin.

Google services are disabled until real game IDs and linked credentials are configured. All gameplay and local progression work offline. See [Play Services setup](docs/PLAY_SERVICES_SETUP.md), [APK build/checksum](docs/ANDROID_BUILD.md), and [Android testing](docs/ANDROID_TESTING.md). `AndroidPlay` is a release preset with signing credentials unset for a future API 36 Gradle AAB; it requires release signing and the Android build template before publication.

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

Tests use separate fixture paths under `output/test-data` or `output/review`; they do not overwrite normal progress. The current gameplay suite passes 315 checks, including class comparisons, upgrade limits and existing-run migration. The services suite retains its 82-assertion result, including UTC daily-score routing. The latest Shield-damage APK passed a focused five-screen Android follow-up with fresh Shield24 and an actual saved Shield18 migration; the preceding twelve-screen full class review is retained separately. Render captures and machine-readable validation results are in `output/review`. See [QA findings](docs/QA_FINDINGS.md) and [verification report](docs/VERIFICATION.md) for measured results and limits. A desktop simulation or Android emulator does not establish real-phone GPU, battery or thermal performance.

The optional `tools/build_monster_atlas.gd` rebuilds the native-pixel atlas from the original sheets. The generated atlas is already included; run a Godot import after rebuilding it. `tools/validate_assets.py` validates all source sheets, identities, stats, original pixels and the music loop.

## Project map

| Path | Purpose |
| --- | --- |
| `scenes/main.tscn`, `scripts/game.gd` | Fixed-step combat, controls, spawning, rewards and run state |
| `scripts/class_profiles.gd` | Shared Sword/Shield starting balance and distinct upgrade limits |
| `scripts/world.gd`, `scripts/game_ui.gd` | Scrolling environment and portrait interface |
| `scripts/audio_manager.gd` | Cached sound pool and music |
| `scripts/services/` | Local persistence and Google Play adapter |
| `data/monsters.json` | Full roster, stats and source hashes |
| `config/play_services.json` | Backend IDs and feature switch |
| `Assets/Generated/` | Knight, weapons, optimized atlas and original music |
| `tests/`, `tools/` | Gameplay, services, UI, audio, rendering and Android checks |

See [asset review](docs/ASSET_REVIEW.md), [monster roster](docs/MONSTER_ROSTER.md), [game design](docs/GAME_DESIGN.md), and [credits](docs/CREDITS.md).
