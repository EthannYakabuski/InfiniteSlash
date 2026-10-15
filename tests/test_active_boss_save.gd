extends SceneTree
## Direct storage regression: JSON round-trips must not hide unsafe key types.

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("ACTIVE SAVE: " + description)

func _run() -> void:
	var save = root.get_node("SaveData")
	save.configure_storage("res://output/test-data/active-boss-save/profile.json")
	var audio = root.get_node("AudioManager")
	audio.set_enabled(false)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.testing = true
	game.set_process(false)
	game.set_physics_process(false)
	for definition in game.BossCatalog.all():
		game.start_run("sword")
		game.elapsed = 90.0
		game.boss_number = 2
		game.spawn_enemy(0, true, Vector2(200, 200), false, definition)
		var snapshot: Dictionary = game.serialize_run()
		check(save._json_safe(snapshot), str(definition.id) + " direct snapshot uses JSON-safe keys")
		save.save_active_run(snapshot)
		save.reload_profile()
		check(not save.active_run.is_empty() and save.active_run.get("elapsed", 0) == 90.0, str(definition.id) + " direct boss snapshot persists to disk")
		check(game.restore_run(save.active_run), str(definition.id) + " stored encounter restores")
		if not save.active_run.is_empty():
			check(str(game._boss().boss_id) == str(definition.id), str(definition.id) + " stable identity survives")
		game.resume_run()
		game.tick(0.05)
		snapshot = game.serialize_run()
		check(save._json_safe(snapshot), str(definition.id) + " restored metadata is safe before stringify")
		save.save_active_run(snapshot)
		save.reload_profile()
		check(save.active_run.get("elapsed", 0) > 90.0, str(definition.id) + " resumed boss progress updates on disk")
	game.queue_free()
	audio.stop_for_shutdown()
	await create_timer(0.35, true, false, true).timeout
	await process_frame
	print("ACTIVE_BOSS_SAVE_TESTS checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
