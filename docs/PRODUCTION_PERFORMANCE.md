# Production update performance review

Measured October 16, 2026 on Windows, Intel Core i5-3570 @ 3.40 GHz, NVIDIA GeForce GT 1030, OpenGL Compatibility renderer, at a rendered 540 x 960 viewport. These are **desktop results, not Android phone FPS**.

## Results

Each case excludes five seconds of warmup, then measures 30 seconds. The window remained focused throughout. The engine cap was 60 FPS, VSync was disabled, and low-processor-usage mode was disabled. The small apparent 60.03 FPS overshoot is the inclusive first frame at the measurement boundary, rounded below to 60.0.

| Workload | Average FPS | p95 frame time | p95 gameplay simulation | p95 render CPU | p95 render GPU | p95 draw calls |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Ordinary level 30, before batching changes | 60.0 | 18.64 ms | 4.03 ms | 5.25 ms | 2.70 ms | 394 |
| Full-cap level 50, before batching changes | 46.1 | 26.09 ms | 4.18 ms | 8.00 ms | 3.56 ms | 742 |
| Full-cap level 100, before batching changes | 43.2 | 27.24 ms | 4.32 ms | 8.37 ms | 3.10 ms | 752 |
| Full-cap level 50, optimized | **57.9** | **20.23 ms** | 4.16 ms | **5.41 ms** | 2.59 ms | **399** |
| Full-cap level 100, optimized | **56.8** | **20.11 ms** | 4.22 ms | **5.49 ms** | 3.92 ms | **395** |

Both stress cases held **140 enemies, 480 projectiles and 24 elemental hazards on every measured frame**. No challenge cap was reduced. Optimized texture memory stayed at 23.68 MiB; video memory remained around 30.3 MiB. Scene node count stayed around 79–81 rather than growing with enemy/projectile count.

The optimized runs are a material improvement: approximately 46–47% fewer draw calls and 32–34% lower p95 render CPU time. Gameplay simulation time stayed close to the original values. Frame rate improved about 25–31% in these samples, with the host-load caveats below. Absolute-cap stress still has occasional frames over the 16.67 ms budget, so this is not a locked-60-FPS claim.

## Workloads and interpretation

The ordinary level-30 case uses normal real-time physics, normal spawns and a fixed sequence of 29 ordinary stat upgrades. It adds no artificial enemies, projectiles or hazards. During measurement, it averaged 57 enemies and 240 projectiles, reaching 87 enemies and 391 projectiles. Demo movement suppresses death and external saves so the test can finish; it is not a survival/balance test.

The saturated cases continuously refill the stated caps with actual enemies, projectiles and all three hazard geometries. They include night lighting, the level-50 keep, ascended monsters, boss attacks, late tank quakes, slashes, effects and real dash calls. One fixed 1/60-second gameplay tick executes per rendered frame. Therefore a slower renderer advances less simulated game time over the same wall-clock duration. These cases measure rendering pressure and tick costs; they do not establish real-time survivability or prove that a physical Android device can sustain the same frame rate.

Refill work is measured separately. Optimized p95 refill cost was 0.070 ms at level 50 and 0.074 ms at level 100. It was not the principal cost in these samples. The larger pre-optimization render CPU cost and draw-call count pointed toward CPU-side canvas submission/batching pressure. That is an inference from measured counters, not a full engine profiler attribution.

## Batching changes verified

- Enemy warnings and ascended halos are grouped before the shared monster-atlas pass. Health bars and crowns follow it, rather than breaking the texture batch for every enemy.
- The scrolling world uses the supplied packed Town/Farm tile sheets. Asset validation compares all 30 actually used packed regions against their original individual PNGs; every used region matches exactly. Unused Town regions are deliberately excluded because some supplied unused packed tiles differ.
- Full enemy/projectile/hazard caps, simulation behavior and source monster art remain unchanged by these render optimizations.

## Host-load limitations

The baseline sequence overlapped a headless Android debug export. Its process consumed approximately 16.55 CPU-seconds across the roughly 105-second sequence. It was a headless packaging process, not a leaked gameplay renderer. No emulator was active. The optimized run had no export active; another worker reported a short headless catalog test that may have overlapped part of the final level-100 sample. It had exited by the post-run snapshot, so its exact overlap was not independently measured. Pre-existing owner Godot sessions and ADB were left alone.

Consequently the FPS comparison is not a perfectly isolated hardware experiment. The repeated full-cap occupancy, much lower draw-call count and lower render CPU time provide evidence for the batching improvement, but the entire FPS gain should not be attributed solely to code changes. A physical phone run, sustained thermal/battery testing and representative low-end Android devices remain required before claiming native performance targets.

A smaller-cap comparison was stopped before completion. Its partial log is not a result and was not used in the table. No runtime cap reduction was made.

## Reproduction and evidence

Use `tests/benchmark_production.gd` after asset imports finish and with no other renderer or emulator running. The default runs all three original scenarios. `--stress-only --tag=optimized` runs the two stress cases into separate output files. Output includes per-second pacing, full occupancy summaries, draw calls, CPU/GPU timers, memory, processor/renderer identity and desktop-only labels.

- [Baseline ordinary level 30](../output/review/production_benchmark_ordinary30.json)
- [Baseline full-cap level 50](../output/review/production_benchmark_saturated50.json)
- [Baseline full-cap level 100](../output/review/production_benchmark_saturated100.json)
- [Optimized full-cap level 50](../output/review/production_benchmark_saturated50_optimized.json)
- [Optimized full-cap level 100](../output/review/production_benchmark_saturated100_optimized.json)
- [Baseline combined report](../output/review/production_benchmark_summary.json)
- [Optimized combined report](../output/review/production_benchmark_summary_optimized.json)
- [Baseline host snapshot before](../output/review/production_benchmark_host_before.json) and [after](../output/review/production_benchmark_host_after.json)
- [Optimized host snapshot before](../output/review/production_benchmark_optimized_host_before.json) and [after](../output/review/production_benchmark_optimized_host_after.json)

Each measured case also has a matching PNG capture in `output/review`. The original benchmark's relative log-path diagnostic did not affect stdout capture or its JSON reports; the optimized run uses an absolute log path. The desktop sandbox's certificate-store diagnostic is unrelated to local gameplay rendering and is not evidence of a successful Google account integration test.
