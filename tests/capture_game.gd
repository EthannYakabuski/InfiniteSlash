extends SceneTree
## Deterministic rendered acceptance views; run with a real renderer, not headless.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var store = root.get_node("SaveData")
	store.configure_storage("res://output/test-data/capture_profile.json")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.testing = true
	scene.set_physics_process(false)
	root.size = Vector2i(540, 960)
	await process_frame
	await _capture("launch")
	scene.start_run("sword")
	scene._release_input()
	scene.player_pos = Vector2(270, 650)
	scene.elapsed = 35
	scene.score = 1240
	scene.kills = 36
	scene.combo = 12
	scene.combo_timer = 2.5
	scene.level = 5
	scene.health = 76
	scene.xp = 9
	scene.xp_goal = 24
	scene.enemies.clear()
	for i in range(12):
		scene.spawn_enemy(i * 7, false, Vector2(60 + (i % 4) * 137, 270 + int(i / 4) * 140))
	scene.buffs = {"haste": 7.2, "spark": 6.0}
	scene.perform_slash(Vector2.UP)
	scene._drop(Vector2(370, 770), "heart", 22)
	scene._drop(Vector2(175, 705), "ward", 1)
	for i in range(7): scene._add_bullet(Vector2(60 + i * 67, 575 + sin(i) * 30), Vector2.DOWN * 130, 10)
	scene._update_hud()
	scene.world.advance(0, scene.elapsed)
	await _capture("action")
	scene.boss_number = 1
	scene.elapsed = 47
	scene.spawn_enemy(scene.roster.size() - 1, true, Vector2(270, 245))
	scene._update_hud()
	await _capture("boss")
	scene.pause_run()
	await _capture("pause")
	scene.resume_run()
	scene.end_run()
	await _capture("death")
	root.size = Vector2i(540, 1110)
	await process_frame
	scene.start_run("shield")
	await _capture("tall_portrait")
	root.get_node("AudioManager").stop_for_shutdown()
	scene.queue_free()
	await process_frame
	await create_timer(0.12).timeout
	print("RENDER_CAPTURE_PASS")
	quit(0)

func _capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var target = "res://output/review/game_%s.png" % label
	var result = root.get_texture().get_image().save_png(target)
	print("CAPTURE ", label, " -> ", result)
