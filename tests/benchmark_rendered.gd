extends SceneTree
## Rendered ordinary/saturated benchmarks with explicit pacing diagnostics.
## Flags: --ordinary, --default-processor, --no-vsync, --seconds=60, --warmup=5.
## Run one benchmark at a time, after asset imports finish and with no emulator.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ordinary: bool = "--ordinary" in args
	var control_processor: bool = "--default-processor" not in args
	var no_vsync: bool = "--no-vsync" in args
	var duration: float = 60.0 if ordinary else 15.0
	var warmup: float = 5.0
	for arg in args:
		if arg.begins_with("--seconds="): duration = clampf(float(arg.substr(10)), 10, 120)
		if arg.begins_with("--warmup="): warmup = clampf(float(arg.substr(9)), 2, 15)
	var original_low_processor: bool = OS.low_processor_usage_mode
	var original_sleep_usec: int = OS.low_processor_usage_mode_sleep_usec
	var original_vsync: int = DisplayServer.window_get_vsync_mode()
	if control_processor:
		OS.low_processor_usage_mode = false
		OS.low_processor_usage_mode_sleep_usec = 1000
	if no_vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	var pacing := {
		"original_os_low_processor_usage_mode": original_low_processor,
		"original_os_sleep_usec": original_sleep_usec,
		"os_low_processor_usage_mode": OS.low_processor_usage_mode,
		"os_sleep_usec": OS.low_processor_usage_mode_sleep_usec,
		"processor_control_applied": control_processor,
		"project_low_processor_mode": ProjectSettings.get_setting("application/run/low_processor_mode", false),
		"project_sleep_usec": ProjectSettings.get_setting("application/run/low_processor_mode_sleep_usec", 6900),
		"project_frame_delay_msec": ProjectSettings.get_setting("application/run/frame_delay_msec", 0),
		"project_max_fps": ProjectSettings.get_setting("application/run/max_fps", 0),
		"engine_max_fps": Engine.max_fps,
		"original_vsync_mode": original_vsync,
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"screen_refresh_rate": DisplayServer.screen_get_refresh_rate(),
		"delta_smoothing": OS.delta_smoothing,
		"window_mode": root.mode,
		"window_visible": root.visible,
	}
	root.get_node("SaveData").configure_storage("res://output/test-data/benchmark_profile.json")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.testing = true
	game.demo = true
	game.start_run("sword")
	root.get_node("AudioManager").set_enabled(false)
	if not ordinary:
		game.elapsed = 240.0
		game.set_physics_process(false)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var random = RandomNumberGenerator.new()
	random.seed = 55001
	var frame_times: Array[float] = []
	var simulation_times: Array[float] = []
	var monitors := {"process_ms": [], "physics_ms": [], "render_cpu_ms": [], "render_gpu_ms": [], "frame_setup_cpu_ms": [], "draw_calls": [], "render_objects": [], "render_primitives": [], "texture_mb": [], "video_mb": [], "node_count": []}
	var start_time = Time.get_ticks_usec()
	var last_frame = start_time
	var measured_start = 0
	var frames = 0
	var peak_enemies = 0
	var peak_bullets = 0
	var focused_frames: int = 0
	var samples_by_second: Array = []
	var bucket_start: int = start_time
	var bucket_frames: int = 0
	print("RENDERED_BENCHMARK_START ", JSON.stringify({"scenario": "ordinary" if ordinary else "saturated", "duration": duration, "warmup": warmup, "pacing": pacing}))
	while Time.get_ticks_usec() - start_time < int((duration + warmup) * 1000000):
		await process_frame
		var current = Time.get_ticks_usec()
		var measuring: bool = current - start_time >= int(warmup * 1000000)
		if measuring:
			if measured_start == 0: measured_start = current
			frame_times.append((current - last_frame) / 1000.0)
			frames += 1
			if DisplayServer.window_is_focused(): focused_frames += 1
			monitors.process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
			monitors.physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000)
			monitors.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
			monitors.render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			monitors.frame_setup_cpu_ms.append(RenderingServer.get_frame_setup_time_cpu())
			monitors.draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			monitors.render_objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			monitors.render_primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			monitors.texture_mb.append(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0)
			monitors.video_mb.append(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
			monitors.node_count.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		bucket_frames += 1
		if current - bucket_start >= 1000000:
			samples_by_second.append({"wall_second": (current - start_time) / 1000000.0, "fps": bucket_frames * 1000000.0 / (current - bucket_start), "enemies": game.enemies.size(), "bullets": game.bullets.size(), "focused": DisplayServer.window_is_focused()})
			bucket_start = current
			bucket_frames = 0
		last_frame = current
		if not ordinary:
			while game.enemies.size() < game.MAX_ENEMIES:
				if game.spawn_enemy(random.randi_range(0, 99), false, Vector2(random.randf_range(20, 520), random.randf_range(160, 860))).is_empty(): break
			while game.bullets.size() < game.MAX_BULLETS:
				game._add_bullet(Vector2(random.randf_range(20, 520), random.randf_range(180, 900)), Vector2.from_angle(random.randf() * TAU) * 140, 12, true)
			var tick_start = Time.get_ticks_usec()
			game.tick(1.0 / 60.0)
			if measuring: simulation_times.append((Time.get_ticks_usec() - tick_start) / 1000.0)
		elif measuring:
			simulation_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000)
		peak_enemies = maxi(peak_enemies, game.enemies.size())
		peak_bullets = maxi(peak_bullets, game.bullets.size())
	frame_times.sort()
	simulation_times.sort()
	var measured_seconds = (Time.get_ticks_usec() - measured_start) / 1000000.0
	var report = {"method": "%d-second rendered %s test, first %d seconds warmup excluded; 60 FPS cap; %s" % [duration, "ordinary" if ordinary else "saturated", warmup, "real-time normal game physics, no artificial threats" if ordinary else "100 enemies and 240 bullets replenished each frame, one manual 60Hz simulation tick per rendered frame for comparison with initial benchmark"], "scenario": "ordinary" if ordinary else "saturated", "platform": OS.get_name(), "processor": OS.get_processor_name(), "gpu": RenderingServer.get_video_adapter_name(), "rendering_method": RenderingServer.get_current_rendering_method(), "viewport": [root.size.x, root.size.y], "frames": frames, "seconds": measured_seconds, "average_fps": frames / measured_seconds, "p95_frame_ms": frame_times[int(frame_times.size() * 0.95)], "p99_frame_ms": frame_times[int(frame_times.size() * 0.99)], "p95_simulation_ms": simulation_times[int(simulation_times.size() * 0.95)], "max_simulation_ms": simulation_times.back(), "peak_enemies": peak_enemies, "peak_bullets": peak_bullets, "focused_frame_fraction": focused_frames / float(maxi(1, frames)), "pacing": pacing, "monitor_summary": {}, "seconds_trace": samples_by_second, "android_device_performance_verified": false, "monster_atlas_present": ResourceLoader.exists("res://Assets/Generated/monster_atlas.png")}
	for key in monitors:
		report.monitor_summary[key] = _summary(monitors[key])
	var report_name: String = "rendered_ordinary" if ordinary else "rendered_benchmark"
	if no_vsync: report_name += "_no_vsync"
	if not control_processor and not ordinary: report_name += "_default_processor"
	var file = FileAccess.open("res://output/review/" + report_name + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("RENDERED_BENCHMARK ", JSON.stringify(report))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/review/game_ordinary.png" if ordinary else "res://output/review/game_stress.png")
	root.get_node("AudioManager").stop_for_shutdown()
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(0)


func _summary(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	values.sort()
	var total: float = 0.0
	for value in values: total += float(value)
	return {"mean": total / values.size(), "p95": values[int(values.size() * 0.95)], "min": values.front(), "max": values.back()}
