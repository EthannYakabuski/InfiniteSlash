extends SceneTree
## Render local scores/badges and their return controls with a real renderer.

const Interface = preload("res://scripts/game_ui.gd")
const World = preload("res://scripts/world.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
	ui.show_scores(profile, "Offline · scores saved on this device")
	await _capture("scores")
	ui.show_achievements(profile)
	await _capture("badges")
	var scroll: ScrollContainer = ui.find_child("AchievementScroll", true, false)
	scroll.scroll_vertical = 1000
	await _capture("badges_scrolled")
	root.size = Vector2i(540, 1110)
	await process_frame
	ui.show_achievements(profile)
	await _capture("badges_tall")
	ui.queue_free()
	world.queue_free()
	await process_frame
	print("UI_RENDER_CAPTURE_PASS")
	quit(0)


func _capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png("res://output/review/ui_%s.png" % label)
	print("UI_CAPTURE ", label, " -> ", result)
