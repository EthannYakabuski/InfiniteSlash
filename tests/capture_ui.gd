extends SceneTree
## Render local scores/badges and their return controls with a real renderer.

const Interface = preload("res://scripts/game_ui.gd")
const World = preload("res://scripts/world.gd")
const Upgrades = preload("res://scripts/upgrade_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SaveData").configure_storage("res://output/test-data/update_ui_capture_profile.json")
	var audio := root.get_node_or_null("AudioManager")
	if audio != null:
		audio.set_enabled(false)
	var world := World.new()
	root.add_child(world)
	var ui := Interface.new()
	root.add_child(ui)
	root.size = Vector2i(540, 960)
	await process_frame
	world.advance(0, 125)
	var profile := {"best_score": 15420, "run_history": [],
		"achievements": {"first_blood": 1739200123, "boss_slayer": 1739200123,
		"century": 1739200123, "combo_25": 1739200123, "ten_runs": 1739200123}}
	for i in range(10):
		profile.run_history.append({"style": "shield" if i % 2 == 0 else "sword",
			"score": 1240 + i * 890, "duration": 41 + i * 13})
	ui.show_launch(false, 15420)
	await _capture("launch_audio")
	ui.set_audio_settings({"sfx": true, "music": false})
	ui.show_audio_settings()
	await _capture("audio_split")
	ui.close_auxiliary_overlay()
	var upgrade_choices: Array = []
	for upgrade in Upgrades.eligible(10, {"style": "shield"}):
		if upgrade.id in ["keen_edge", "heart_of_a_knight"]:
			upgrade_choices.append(upgrade)
	ui.show_upgrade_choices(upgrade_choices, 10)
	await _capture("upgrade_choices")
	ui.hide_overlay()
	ui.update_hud({"style": "shield", "health": 141, "max_health": 170, "score": 15823,
		"level": 9, "elapsed": 181, "combo": 25, "multiplier": 3,
		"dash_ready": true, "guard_ratio": 0.7, "boss_name": "Moonmallow Majesty",
		"boss_hp": 700, "boss_max": 1100, "buffs": {"haste": 5}, "ward_hits": 2})
	await _capture("hud_ready")
	ui.update_hud({"style": "shield", "health": 141, "max_health": 170, "score": 15823,
		"level": 9, "elapsed": 181, "dash_ready": false, "dash_cooldown": 0.7, "guard_ratio": 0.12,
		"boss_name": "Moonmallow Majesty", "boss_hp": 700, "boss_max": 1100})
	await _capture("hud_recharging")
	ui.show_launch(false, 15420)
	ui.show_scores(profile, "Offline · scores saved on this device")
	await _capture("scores")
	ui.show_achievements(profile)
	await _capture("badges")
	var scroll: ScrollContainer = ui.find_child("AchievementScroll", true, false)
	scroll.scroll_vertical = 1000
	await _capture("badges_scrolled")
	root.size = Vector2i(540, 1110)
	await process_frame
	ui.show_upgrade_choices(upgrade_choices, 10)
	await _capture("upgrade_tall")
	ui.show_achievements(profile)
	await _capture("badges_tall")
	ui.queue_free()
	world.queue_free()
	await process_frame
	await _capture_actual_game()
	print("UI_RENDER_CAPTURE_PASS")
	quit(0)


func _capture_actual_game() -> void:
	# Exercise the real game-to-interface flow as well as the isolated layouts.
	root.size = Vector2i(540, 960)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.testing = true
	game.set_process(false)
	game.set_physics_process(false)
	game.start_run("sword")
	game.run_seed = 171517
	game.rng.seed = 171517
	game.upgrade_rng.seed = 171517
	game.visual_rng.seed = 171517
	game.elapsed = 51.0
	game.score = 2580
	game.player_pos = Vector2(270, 660)
	game.slash_time = 0.13
	game.slash_angle = -PI * 0.5
	for index in range(12):
		game.spawn_enemy(index * 7, false, Vector2(80 + (index % 4) * 125, 300 + int(index / 4) * 155))
	for index in range(18):
		var angle := float(index) * TAU / 18.0
		game._add_bullet(Vector2(270, 390) + Vector2.from_angle(angle) * 160, Vector2.DOWN * 80, 10)
	game.world.advance(0, game.elapsed)
	game._update_hud()
	game.queue_redraw()
	await _capture("actual_combat_hud")
	game.level_up()
	await _capture("actual_level_up")
	game.hud.show_audio_settings()
	await _capture("actual_upgrade_audio")
	game.hud.close_auxiliary_overlay()
	await _capture("actual_upgrade_restored")
	game.hud.find_child("UpgradeChoice1", true, false).pressed.emit()
	game._update_hud()
	game.queue_redraw()
	await _capture("actual_upgrade_resumed")
	game.queue_free()
	await process_frame
	await process_frame


func _capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png("res://output/review/ui_%s.png" % label)
	print("UI_CAPTURE ", label, " -> ", result)
