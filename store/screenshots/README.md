# InfiniteSlash 0.3.0 store screenshots

These eight views show the Crownfall update's actual game and current interface. They were selected from the 48 acceptance renders produced by Godot 4.5.1's desktop OpenGL compatibility renderer. The ordinary 540×960 game canvas is preserved. There is no added marketing text, device frame, fake service interface, image generation, compositing, retouching or post-capture resizing.

| Upload category | Count | Output size | Format |
| --- | ---: | --- | --- |
| Phone | 8 | 540×960 | 24-bit RGB PNG, no alpha |
| 7-inch tablet | 8 | 1080×1920 | 24-bit RGB PNG, no alpha |
| 10-inch tablet | 8 | 1080×1920 | 24-bit RGB PNG, no alpha |

All images are 9:16 and below 8 MB. Both sides satisfy the requested category limits. The two tablet groups intentionally share the same exact source frames; these are not independent tablet-device captures. Each folder is numbered in upload order:

1. **Meadow Mayhem:** daytime automatic slashing and always-active guard.
2. **Night War Host:** stage-two veterans and night-only creatures.
3. **Crownfall Overdrive:** the level-50 stone biome and active Overdrive.
4. **Boss Fire Circle:** the active circular fire spell zone.
5. **Earthquake Corridor:** the rectangular ground attack and lateral escape routes.
6. **Electric Escape Gap:** the concave pulse's open escape wedge.
7. **Build Your Tradeoff:** paused lifesteal versus a speed/guard-recovery tradeoff, with explicit GAIN and COST.
8. **Legendary Crossroads:** paused Phoenix Oath and Worldbreaker choices.

The source PNGs contain a fully opaque alpha channel. Promotion removes only that redundant channel for the upload format, verifies that **every RGB pixel is identical**, and preserves all original acceptance files. `manifest.json` maps every upload to its exact source path, source PNG SHA-256, matching RGB-pixel SHA-256, output hash, dimensions and scenario. The prior 24 screenshots, manifest and README are preserved in [the historical 0.2.x backup](../../output/review/store-screenshots-0.2/README.md).

These are deterministic composed game states using the actual game renderer and gameplay methods. Scores, levels, timers and enemy placements are demonstration state, not submitted competitive results. The files are desktop renders, not physical-phone/tablet captures. They do not establish hardware performance, cutout/safe-area behavior or live Google Play integration.

The current capture source is `tests/capture_production.gd`. Existing acceptance renders can be promoted without starting a renderer:

```powershell
python tools/promote_production_screenshots.py
python tools/validate_store_screenshots.py
python tools/validate_store_assets.py
```

The promotion script preserves the historical backup and acceptance originals. Validation checks all source RGB pixels, image hashes, count, dimensions, format, file size, eight distinct views within each category and nonblank frames. Visual-review contact sheets and validation reports are under `output/review/store-captures/`.
