extends SceneTree
## Deterministic actual-renderer production acceptance captures, not device claims.

const Hazards = preload("res://scripts/boss_hazards.gd")
const Upgrades = preload("res://scripts/upgrade_catalog.gd")
var game: Variant
var captures: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("SaveData").configure_storage("res://output/test-data/production_capture.json")
	root.get_node("AudioManager").set_enabled(false)
	root.size = Vector2i(540, 960)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.testing = true
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	for dimensions: Vector2i in [Vector2i(540, 960), Vector2i(540, 1110), Vector2i(1080, 1920)]:
		root.size = dimensions
		await process_frame
		await process_frame
		var suffix := "%dx%d" % [dimensions.x, dimensions.y]
		_set_combat(12, 30.0)
		await _capture("day_" + suffix)
		_set_combat(30, 110.0)
		await _capture("night_host_" + suffix)
		_set_combat(50, 110.0)
		game.overdrive_time = 4.5
		game._update_hud()
		await _capture("keep_overdrive_" + suffix)
		for kind: String in ["fire", "quake", "pulse"]:
			game.hazards.clear()
			var hazard := Hazards.make(kind, Vector2(270, 440), 120, Vector2.DOWN)
			hazard.age = 0.65
			game.hazards.append(hazard)
			game.queue_redraw()
			await _capture(kind + "_warning_" + suffix)
			hazard.age = hazard.warning + (0.45 if kind == "pulse" else 0.2)
			game.queue_redraw()
			await _capture(kind + "_active_" + suffix)
		for spec: Array in [[12, "sharper_steel", "stronger_guard", "common"], [20, "vampire_steel", "trade_guard_delay_for_move_speed", "rare_trade"], [30, "titan_heart", "headhunter", "rare30"], [50, "abyssal_steel", "adamant_vow", "rare50"], [25, "phoenix_oath", "worldbreaker", "legendary"]]:
			game.level = int(spec[0])
			var eligible: Array = Upgrades.eligible(game.level, game._upgrade_stats(), {})
			var choices: Array = []
			for key: String in [spec[1], spec[2]]:
				for card: Dictionary in eligible:
					if card.id == key: choices.append(card)
			if choices.size() != 2:
				push_error("Missing capture choices: " + str(spec))
				quit(1)
				return
			game.state = "upgrading"
			game.upgrade_choices = choices
			game.hud.show_upgrade_choices(choices, game.level)
			await _capture(str(spec[3]) + "_choices_" + suffix)
		game.hud.show_audio_settings()
		await _capture("choice_audio_" + suffix)
		game.hud.close_auxiliary_overlay()
		await _capture("choice_audio_restored_" + suffix)
	var file := FileAccess.open("res://output/review/production_capture_manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "provenance": "Actual Godot game scene, deterministic composed state, desktop renderer; not physical-device captures or live service verification", "captures": captures}, "\t"))
	file.close()
	game.queue_free()
	root.get_node("AudioManager").stop_for_shutdown()
	await process_frame
	await process_frame
	print("PRODUCTION_CAPTURE_PASS: ", captures.size(), " rendered acceptance screenshots")
	quit(0)

func _set_combat(level: int, elapsed: float) -> void:
	game.start_run("shield")
	game.level = level
	game.xp_goal = game.Progression.xp_goal(level)
	game.elapsed = elapsed
	game.score = 201840
	game.health = 141
	game.combo = 57
	game.combo_timer = 2.3
	game.guard_reserve = 108
	game.player_pos = Vector2(270, 700)
	game.visual_rng.seed = 834713
	game.rng.seed = 834713
	var indices: Array[int] = []
	for index: int in range(game.roster.size() - 1):
		var info: Dictionary = game.roster[index]
		if int(info.get("stage_min", 1)) > level: continue
		if int(info.get("stage_max", 10000)) < level: continue
		if level >= 30 and (int(info.get("stage_min", 1)) >= 30 or bool(info.get("night_only", false))): indices.append(index)
		elif level < 30 and int(info.get("stage_min", 1)) < 30 and not bool(info.get("night_only", false)): indices.append(index)
	if indices.is_empty(): indices.append(0)
	for index: int in range(12):
		game.spawn_enemy(indices[index * 7 % indices.size()], false, Vector2(65 + index % 4 * 135, 290 + index / 4 * 125))
	game.boss_rng.seed = 834713
	var definition: Dictionary = game.BossCatalog.choose(game.boss_rng, elapsed, "", level)
	var boss: Dictionary = game.spawn_enemy(indices[0], true, Vector2(270, 245), false, definition)
	boss.hp *= 0.65
	for index: int in range(18):
		game._add_bullet(Vector2(270, 410) + Vector2.from_angle(index * TAU / 18.0) * 135, Vector2.DOWN * 120, 30, true)
	game.slash_time = 0.13
	game.slash_angle = -PI * 0.5
	game.world.advance(0, elapsed, level)
	game._update_hud()
	game.queue_redraw()

func _capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var target := "res://output/review/production_%s.png" % label
	var image := root.get_texture().get_image()
	var error := image.save_png(target)
	if error != OK:
		push_error("Capture failed: " + label)
		quit(1)
		return
	captures.append({"label": label, "file": target.trim_prefix("res://"), "size": [image.get_width(), image.get_height()]})
