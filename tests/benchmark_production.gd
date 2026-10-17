extends SceneTree
## Desktop rendered production workloads. Never use these results as phone FPS.
## Run after imports and captures, one process at a time, with no emulator.
## Default: ordinary level 30 and saturated levels 50/100, 30 measured seconds
## each after 5 seconds warmup. Optional: --case=ordinary30|saturated50|saturated100.

const HazardCatalog = preload("res://scripts/boss_hazards.gd")
const Upgrades = preload("res://scripts/upgrade_catalog.gd")
const Progression = preload("res://scripts/progression.gd")
const Bosses = preload("res://scripts/boss_catalog.gd")
const CASES := ["ordinary30", "saturated50", "saturated100"]
const DURATION := 30.0
const WARMUP := 5.0
var generator := RandomNumberGenerator.new()
var practical_budget := false
var enemy_budget := 140
var bullet_budget := 480
var hazard_budget := 24
var run_tag := ""
var stress_only := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Production benchmark requires an actual rendered window.")
		quit(2)
		return
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--case="):
			requested = argument.trim_prefix("--case=")
		elif argument == "--practical-budget":
			practical_budget = true
			enemy_budget = 120
			bullet_budget = 360
			hazard_budget = 16
		elif argument == "--tag=optimized":
			run_tag = "optimized"
		elif argument == "--stress-only":
			stress_only = true
	if not requested.is_empty() and requested not in CASES:
		push_error("Unknown benchmark case: " + requested)
		quit(2)
		return
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 1000
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	root.get_node("SaveData").configure_storage("res://output/test-data/production_benchmark_profile.json")
	root.get_node("AudioManager").set_enabled(false)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var reports: Array = []
	for scenario in CASES:
		if stress_only and scenario == "ordinary30":
			continue
		if not requested.is_empty() and scenario != requested:
			continue
		reports.append(await _case(scenario))
	var suffix := ("_practical" if practical_budget else "") + ("_" + run_tag if not run_tag.is_empty() else "")
	var file := FileAccess.open("res://output/review/production_benchmark_summary" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"desktop_only": true, "real_android_device_verified": false, "cases": reports}, "  "))
	file.close()
	root.get_node("AudioManager").stop_for_shutdown()
	await process_frame
	await create_timer(0.15).timeout
	quit(0)


func _build_for_level(game, target_level: int) -> void:
	# Fixed ordinary stat choices make the workload reproducible without giving
	# the knight an artificial damage multiplier, powerup stack or instant kills.
	var cycle := ["sharper_steel", "quicker_slices", "heart_of_a_knight", "sharper_steel", "stronger_guard", "longer_reach", "guard_mending", "swift_recovery", "fleet_footed", "sharper_steel"]
	for next_level in range(2, target_level + 1):
		game.level = next_level
		var id: String = cycle[(next_level - 2) % cycle.size()]
		var changed: Dictionary = Upgrades.apply_upgrade(id, game._upgrade_stats())
		game._apply_build_stats(changed)
		game.upgrade_counts[id] = int(game.upgrade_counts.get(id, 0)) + 1
	game.level = target_level
	game.xp = 0
	game.xp_goal = Progression.xp_goal(target_level)
	game.health = game.max_health
	game.guard_reserve = game.guard_capacity


func _case(scenario: String) -> Dictionary:
	var report_name := scenario + ("_practical" if practical_budget else "") + ("_" + run_tag if not run_tag.is_empty() else "")
	var saturated := scenario.begins_with("saturated")
	var target_level := 100 if scenario == "saturated100" else 50 if saturated else 30
	generator.seed = 60000 + target_level
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.testing = true
	game.demo = true # Actual auto movement, isolated score state, death suppressed.
	game.start_run("sword")
	game.run_seed = 910000 + target_level
	game.rng.seed = game.run_seed
	game.loot_rng.seed = game.run_seed ^ 1234567
	game.upgrade_rng.seed = game.run_seed ^ 734719
	game.boss_rng.seed = game.run_seed ^ 819331
	_build_for_level(game, target_level)
	game.elapsed = 100.0 # Full night: includes new night creatures and lighting.
	game.previous_night = true
	game.previous_stage = Progression.stage(target_level)
	game.next_boss = 100.5 if not saturated else 1000000.0
	if saturated:
		game.spawn_timer = 1000000.0
		game.set_physics_process(false)
		_top_up(game)
	var monitor_samples := {"process_ms": [], "physics_ms": [], "render_cpu_ms": [], "render_gpu_ms": [], "frame_setup_cpu_ms": [], "draw_calls": [], "render_objects": [], "render_primitives": [], "texture_mb": [], "video_mb": [], "node_count": []}
	var frame_times: Array[float] = []
	var simulation_times: Array[float] = []
	var injection_times: Array[float] = []
	var occupancy := {"enemies": [], "bullets": [], "hazards": [], "effects": [], "drops": []}
	var trace: Array = []
	var started := Time.get_ticks_usec()
	var previous := started
	var measured_started := 0
	var frames := 0
	var focused_frames := 0
	var bucket_started := started
	var bucket_frames := 0
	print("PRODUCTION_BENCHMARK_START ", JSON.stringify({"case": scenario, "measured_seconds": DURATION, "warmup_seconds": WARMUP, "level": target_level, "saturated": saturated}))
	while Time.get_ticks_usec() - started < int((DURATION + WARMUP) * 1000000.0):
		await process_frame
		var now := Time.get_ticks_usec()
		var measuring := now - started >= int(WARMUP * 1000000.0)
		var simulation_ms := 0.0
		var injection_ms := 0.0
		if saturated:
			while game.state == "upgrading":
				game.choose_upgrade(str(game.upgrade_choices[0].id))
			if game.dash_cooldown <= 0:
				game.try_dash(Vector2.from_angle(float(game.elapsed) * 1.9))
			var tick_started := Time.get_ticks_usec()
			game.tick(1.0 / 60.0)
			simulation_ms = (Time.get_ticks_usec() - tick_started) / 1000.0
			var injection_started := Time.get_ticks_usec()
			_top_up(game)
			injection_ms = (Time.get_ticks_usec() - injection_started) / 1000.0
		else:
			simulation_ms = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		if measuring:
			if measured_started == 0:
				measured_started = now
			frame_times.append((now - previous) / 1000.0)
			simulation_times.append(simulation_ms)
			injection_times.append(injection_ms)
			frames += 1
			if DisplayServer.window_is_focused():
				focused_frames += 1
			monitor_samples.process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			monitor_samples.physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			monitor_samples.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
			monitor_samples.render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			monitor_samples.frame_setup_cpu_ms.append(RenderingServer.get_frame_setup_time_cpu())
			monitor_samples.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			monitor_samples.render_objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			monitor_samples.render_primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			monitor_samples.texture_mb.append(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0)
			monitor_samples.video_mb.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
			monitor_samples.node_count.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			occupancy.enemies.append(game.enemies.size())
			occupancy.bullets.append(game.bullets.size())
			occupancy.hazards.append(game.hazards.size())
			occupancy.effects.append(game.effects.size())
			occupancy.drops.append(game.drops.size())
		bucket_frames += 1
		if now - bucket_started >= 1000000:
			trace.append({"wall_second": (now - started) / 1000000.0, "fps": bucket_frames * 1000000.0 / (now - bucket_started), "level": game.level, "enemies": game.enemies.size(), "bullets": game.bullets.size(), "hazards": game.hazards.size(), "focused": DisplayServer.window_is_focused()})
			bucket_started = now
			bucket_frames = 0
		previous = now
	var measured_seconds := (Time.get_ticks_usec() - measured_started) / 1000000.0
	var report := {
		"case": scenario, "run_tag": run_tag, "desktop_only": true, "real_android_device_verified": false,
		"method": "30 measured seconds after 5 seconds warmup; actual rendered scene at 60 FPS cap with VSync disabled. " + (("%d enemies, %d bullets and %d mixed telegraphed/active hazards replenished each frame. " % [enemy_budget, bullet_budget, hazard_budget]) + "One fixed 1/60-second gameplay tick per rendered frame; this is a stress workload, not a real-time survival or balance test." if saturated else "Normal real-time gameplay physics and spawns at initial level 30; no artificial enemies, bullets or hazards. Demo auto movement suppresses death and external saves."),
		"practical_budget": practical_budget, "budget": {"enemies": enemy_budget, "bullets": bullet_budget, "hazards": hazard_budget},
		"initial_level": target_level, "final_level": game.level, "platform": OS.get_name(),
		"processor": OS.get_processor_name(), "gpu": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "viewport": [root.size.x, root.size.y],
		"engine_max_fps": Engine.max_fps, "vsync_mode": DisplayServer.window_get_vsync_mode(),
		"low_processor_usage_mode": OS.low_processor_usage_mode, "seconds": measured_seconds,
		"frames": frames, "average_fps": frames / measured_seconds,
		"frame_ms": _summary(frame_times), "simulation_ms": _summary(simulation_times),
		"injection_ms": _summary(injection_times), "focused_frame_fraction": focused_frames / float(maxi(1, frames)),
		"monitors": {}, "occupancy": {}, "seconds_trace": trace,
		"gpu_timer_note": "Zero GPU timing means the renderer/driver did not expose a meaningful GPU timer; it does not prove zero GPU work."
	}
	for key in monitor_samples:
		report.monitors[key] = _summary(monitor_samples[key])
	for key in occupancy:
		report.occupancy[key] = _summary(occupancy[key])
	var file := FileAccess.open("res://output/review/production_benchmark_" + report_name + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("PRODUCTION_BENCHMARK ", JSON.stringify(report))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/review/production_benchmark_" + report_name + ".png")
	game.queue_free()
	await process_frame
	await process_frame
	return report


func _top_up(game) -> void:
	# Alternate budgets affect this test harness only. During tick(), runtime
	# emitters still use their normal caps; trim any overflow before rendering.
	if game.enemies.size() > enemy_budget:
		game.enemies.resize(enemy_budget)
	if game.bullets.size() > bullet_budget:
		game.bullets.resize(bullet_budget)
	if game.hazards.size() > hazard_budget:
		game.hazards.resize(hazard_budget)
	if game.enemies.is_empty():
		game.boss_number = 8 if game.level < 80 else 15
		var definitions: Array = Bosses.all()
		var definition: Dictionary = definitions[definitions.size() - 1]
		var kind := 0
		for index in range(game.roster.size()):
			if str(game.roster[index].id) == str(definition.monster_id):
				kind = index
				break
		game.spawn_enemy(kind, true, Vector2(270, 230), false, definition)
	while game.enemies.size() < enemy_budget:
		var position := Vector2(generator.randf_range(28, 512), generator.randf_range(165, 880))
		if game.spawn_enemy(-1, false, position).is_empty():
			break
	while game.bullets.size() < bullet_budget:
		game._add_bullet(Vector2(generator.randf_range(20, 520), generator.randf_range(160, 900)), Vector2.from_angle(generator.randf() * TAU) * generator.randf_range(180, 500), 65.0, generator.randi_range(0, 1) == 1)
	while game.hazards.size() < hazard_budget:
		var kind: String = ["fire", "quake", "pulse"][game.hazards.size() % 3]
		var hazard: Dictionary = HazardCatalog.make(kind, Vector2(generator.randf_range(50, 490), generator.randf_range(200, 820)), 80.0, Vector2.from_angle(generator.randf() * TAU))
		hazard.age = generator.randf_range(0.0, float(hazard.warning) + float(hazard.duration) * 0.65)
		game._add_hazard(hazard)


func _summary(values: Array) -> Dictionary:
	if values.is_empty():
		return {}
	values.sort()
	var total := 0.0
	for value in values:
		total += float(value)
	return {"mean": total / values.size(), "p50": values[int(values.size() * 0.50)], "p95": values[int(values.size() * 0.95)], "p99": values[int(values.size() * 0.99)], "min": values.front(), "max": values.back()}
