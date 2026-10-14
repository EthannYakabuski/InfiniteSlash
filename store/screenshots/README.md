# InfiniteSlash store screenshots

These are full-frame captures of the actual game and its current interface. Each device category was independently rendered by Godot 4.5.1's OpenGL compatibility renderer. The game's normal 540×960 portrait canvas is preserved at each output density. No image generation, fake service interface, marketing text, device frame or post-capture image scaling was used.

| Upload category | Count | Output size | Format |
| --- | ---: | --- | --- |
| Phone | 8 | 1080×1920 | 24-bit RGB PNG, no alpha |
| 7-inch tablet | 8 | 1440×2560 | 24-bit RGB PNG, no alpha |
| 10-inch tablet | 8 | 2160×3840 | 24-bit RGB PNG, no alpha |

All images are 9:16 and under 8 MiB. Both sides are within the requested category limits. Each folder is numbered in upload order; the first three lead with combat.

1. **Sword action:** meadow slash, mixed creatures, enemy fans and loot.
2. **Shield parry:** autumn guard, perfect block and repeated projectile fans.
3. **Boss bullet hell:** twilight crowned boss, radial shots and aimed volleys.
4. **One-thumb dash:** live dash protection/trail and the floating thumb control.
5. **Thunderblade:** actual chain-lightning powerup and three-hit ward.
6. **Hurricane combo:** wider slash, defeated creatures, gems and the ×4 combo tier.
7. **Choose your knight:** actual one-tap Sword/Shield cards with starting stats.
8. **One more run:** actual result/replay interface with local Scores, Badges and Daily Run entry points.

The scenes use reproducible composed game-state fixtures and actual gameplay methods. Scores, levels, timers and enemy placements are demonstration state, not a submitted leaderboard record. Captures come from independently sized desktop-rendered viewports, not physical phones or tablets; they do not establish hardware performance, cutout/safe-area behavior or live Google Play integration.

`manifest.json` records each capture's dimensions, seed, class, time, score, level, entity counts, renderer, source hashes and image hashes. `output/review/store-captures/validation.json` checks count, dimensions, format, file size, uniqueness and nonblank frames. All 24 were visually reviewed using the three contact sheets in that folder; class cards, result controls, health text, combat effects and the knight remain visible and in bounds.

To reproduce from the project directory with the tested Godot executable:

```powershell
$env:APPDATA = Join-Path (Get-Location) 'output/test-data/store-capture-runtime'
godot --path . --log-file output/review/store_capture.log --script tools/capture_store.gd -- --test
python tools/validate_store_screenshots.py
```

The capture profile is isolated under `output/test-data`; normal player progress is untouched. The format conversion happens inside Godot before saving each screenshot and preserves the rendered RGB pixels.
