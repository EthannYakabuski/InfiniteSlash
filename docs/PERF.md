# Performance verification

The optimized rendered game sustains approximately **60 FPS on the development desktop**, including a continuously replenished wave of **100 enemies and 240 hostile bullets**. This is desktop evidence; an emulator smoke test or an installable APK does not establish a physical Android phone's frame rate, battery use or thermal behavior.

## Hardware and method

- Godot 4.5.1, OpenGL compatibility renderer, Windows.
- Intel Core i5-3570 at 3.40 GHz; NVIDIA GeForce GT 1030, driver 560.94.
- Rendered window: 432 x 768 pixels; logical portrait arena: 540 x 960.
- One graphical game process at a time; Android emulator and asset import/export work stopped during these measurements.
- Five seconds of warmup are excluded. Ordinary play is measured for 60 seconds with the real game's fixed physics, automatic movement/combat and natural spawns. Saturation is measured for 15 seconds, continually replenishing the entity limits and using one manual 60 Hz simulation tick per rendered frame for consistency with the initial benchmark.
- The frame cap is 60 FPS. Window focus, actual processor sleep settings, draw calls, primitives, memory and measured viewport CPU/GPU work are recorded by `tests/benchmark_rendered.gd`.

## Rendered results

| Scenario | Average FPS | Frame time, 95th percentile | Render CPU, 95th percentile | Render GPU, 95th percentile | Mean draw calls |
| --- | --- | --- | --- | --- | --- |
| Ordinary first minute, monster atlas present | 59.99 | 16.798 ms | 2.444 ms | 2.009 ms | 218 |
| Saturated, before projectile/shadow batching | 24.20 | 46.858 ms | 12.075 ms | 7.783 ms | 1,184 |
| Saturated, before batching, V-Sync disabled control | 24.46 | 45.178 ms | 11.875 ms | 7.603 ms | 1,191 |
| Saturated, cached projectile/shadow textures and separate render passes | About 60 | 16.726 ms | 3.014 ms | 2.034 ms | 317 |
| Saturated, pronounced class balance and class-card/HUD revision | About 60 | 16.740 ms | 2.728 ms | 2.166 ms | 289 |

The ordinary run reached 17 enemies and 16 bullets through its natural first-minute spawn curve. The saturated comparisons reached the full 100-enemy/240-bullet limits. All windows stayed focused throughout measurement. The optimized saturated run's 99th percentile frame time was 16.781 ms; its 95th percentile simulation tick was 1.733 ms. Small average-FPS boundary-counting variation around 60 is retained in the raw report rather than rounded into a stronger claim.

## Diagnosis and changes

Low processor mode was already disabled, the configured frame delay was zero, and the windows stayed focused. Forcing low processor mode off with a 1,000-microsecond sleep value did not improve the overloaded scene. Disabling V-Sync also left it near 24 FPS. Those controls ruled out the suspected background/sleep/V-Sync explanation for this workload.

The overloaded scene issued about 1,200 draw calls and 58,500 primitives per frame. Each projectile used three separate circle drawing commands. Enemy shadows also interrupted sprite batches. The original monster atlas reduced texture storage but did not solve those command costs by itself.

The game now caches an original small projectile atlas with normal, boss and frost variants. Each projectile draws as one textured quad with the same dark rim, bright core and collision radius. A cached shadow texture is rendered in a separate pass, and the monster sprites remain contiguous for batching. This reduced mean draw calls by approximately **73%**, and rendered primitives from about **58,500 to 7,600**, bringing the saturated scene to its 60 FPS cap. No gameplay entity limits or collision rules were reduced.

The 100 requested full-size Creature Mixer exports remain preserved. Rendering uses a nearest-neighbor atlas at their native 24-pixel design size. The optimized rendered scene used approximately 19.1 MiB of texture memory and 25.4 MiB of total rendering memory as reported by Godot; these values exclude the desktop browser and other applications.

Godot's [processor-mode documentation](https://docs.godotengine.org/en/4.5/classes/class_os.html#class-os-property-low-processor-usage-mode) describes when its sleep setting applies. Its [rendering measurements](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-viewport-get-measured-render-time-cpu) separate viewport CPU/GPU work from frame pacing. The diagnosis above is based on the recorded control runs and the before/after draw measurements.

## Reports and reproduction

`output/review/rendered_ordinary.json` preserves the ordinary baseline. `rendered_benchmark_before_optimization.json` and `rendered_benchmark_after_optimization.json` preserve the comparable saturated runs. `rendered_benchmark_no_vsync.json` preserves the V-Sync control. `rendered_benchmark.json` is the latest saturated result. The accompanying logs retain startup settings and one-second frame traces; `game_ordinary.png` and `game_stress.png` show the rendered scenes.

Run the existing Godot console executable against `tests/benchmark_rendered.gd` without `--headless`, with an absolute workspace `--log-file` and a disposable `APPDATA` directory. Add `-- --test --ordinary --default-processor` for the one-minute ordinary run, `-- --test` for saturation, or `-- --test --no-vsync` for the control. Keep imports, Android emulators and other graphical game instances stopped when collecting comparable measurements.

The class revision was remeasured with the same saturated method, with no Android emulator or export work running. It remained at approximately 60 FPS with a 16.796 ms 99th-percentile frame and 1.699 ms 95th-percentile simulation step. The class-icon/card fonts add a small amount of cached interface texture memory: approximately 19.95 MiB total textures and 26.30 MiB rendering memory in this run. `output/review/class_rendered_benchmark.json` and `class_rendered_benchmark.log` preserve its measurements; `rendered_benchmark.json` is also the latest class revision result. The earlier optimized report remains in `rendered_benchmark_after_optimization.json`.

The subsequent damage-only Shield buff passed 315 gameplay checks, including class-pressure comparisons, modern/legacy snapshot restoration, damage-only migration of existing Shield runs and five continuous simulated minutes at the fixed entity limits. The rendered class-revision benchmark above predates that one-stat buff; no new rendered FPS measurement is claimed for the follow-up. See `QA_FINDINGS.md` and `output/review/game_validation.json` for current functional evidence.
