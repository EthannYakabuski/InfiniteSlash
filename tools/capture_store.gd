extends SceneTree
## Authentically renders the shipped game in independent portrait SubViewports.
## Fixtures compose reproducible combat moments; they are not physical-device tests.

const TARGETS := [
	{"category": "phone", "width": 1080, "height": 1920},
	{"category": "tablet_7", "width": 1440, "height": 2560},
	{"category": "tablet_10", "width": 2160, "height": 3840},
]
const SHOTS := [
	"01_sword_action", "02_shield_parry", "03_boss_bullet_hell", "04_one_thumb_dash",
	"05_thunderblade", "06_hurricane_combo", "07_choose_your_knight", "08_one_more_run",
]
var _manifest: Array[Dictionary] = []
var _failures: Array[String] = []
var _scene


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("SaveData").configure_storage("res://output/test-data/store_capture_profile.json")
	root.get_node("AudioManager").set_enabled(false)
	root.size = Vector2i(432, 768)
	var main := load("res://scenes/main.tscn")
	for target in TARGETS:
		var directory: String = "res://store/screenshots/" + str(target.category)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		var viewport := SubViewport.new()
		viewport.name = "StoreCapture_" + str(target.category)
		viewport.size = Vector2i(int(target.width), int(target.height))
		viewport.size_2d_override = Vector2i(540, 960)
		viewport.size_2d_override_stretch = true
		viewport.disable_3d = true
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		_scene = main.instantiate()
		viewport.add_child(_scene)
		_scene.testing = true
		_scene.set_process(false)
		_scene.set_physics_process(false)
		await process_frame
		await process_frame
		if _scene.arena != Vector2(540, 960):
			_failures.append("Unexpected logical game area: " + str(_scene.arena))
		for index in range(SHOTS.size()):
			_compose(index)
			_scene.world.advance(0, _scene.elapsed)
			_scene._update_hud()
			_scene.queue_redraw()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			# Play upload images are 24-bit RGB PNGs without an alpha channel.
			image.convert(Image.FORMAT_RGB8)
			var filename: String = directory + "/" + str(SHOTS[index]) + ".png"
			var result := image.save_png(filename)
			if result != OK:
				_failures.append("Could not save " + filename + ": " + str(result))
			if image.get_size() != Vector2i(int(target.width), int(target.height)):
				_failures.append("Incorrect output size for " + filename)
			_manifest.append({
				"file": filename.trim_prefix("res://"), "category": target.category,
				"width": image.get_width(), "height": image.get_height(), "logical_viewport": [540, 960],
				"format": "24-bit RGB PNG, no alpha",
				"scenario": SHOTS[index], "style": _scene.style, "elapsed_seconds": _scene.elapsed,
				"seed": str(_scene.run_seed), "score": _scene.score, "level": _scene.level,
				"enemies": _scene.enemies.size(), "bullets": _scene.bullets.size(), "pickups": _scene.drops.size(),
				"renderer": "Godot " + Engine.get_version_info().string + " / OpenGL compatibility",
				"provenance": "Independently rendered actual game scene in a device-sized SubViewport; deterministic composed game-state fixture; no AI gameplay or external service UI; desktop renderer, not physical-device capture",
			})
			print("STORE_CAPTURE ", filename, " ", image.get_size())
		viewport.queue_free()
		await process_frame
		await process_frame
	var manifest := FileAccess.open("res://store/screenshots/manifest.json", FileAccess.WRITE)
	if manifest != null:
		manifest.store_string(JSON.stringify({"captured_at_utc": Time.get_datetime_string_from_system(true), "logical_game_size": [540, 960], "capture_script": "tools/capture_store.gd", "screenshots": _manifest}, "\t"))
	else:
		_failures.append("Cannot write capture manifest")
	root.get_node("AudioManager").stop_for_shutdown()
	await process_frame
	await process_frame
	if _failures.is_empty():
		print("STORE_CAPTURE_PASS: 24 independently rendered portrait screenshots")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _base(choice: String, seconds: float, target_level: int, points: int) -> void:
	_scene.start_run(choice)
	_scene.run_seed = 125100 + int(seconds)
	_scene.rng.seed = _scene.run_seed
	_scene.loot_rng.seed = _scene.run_seed ^ 1234567
	_scene.visual_rng.seed = 876543
	_scene.visual_time = 0.37
	_scene.elapsed = seconds
	_scene.score = points
	_scene.kills = int(points / 24)
	_scene.best_combo = 18
	_scene.combo = 12
	_scene.combo_timer = 2.4
	_scene.bosses = int(seconds / 45)
	_scene.player_pos = Vector2(270, 650)
	_scene.move_direction = Vector2(0.24, -1).normalized()
	_scene.facing = _scene.move_direction
	for next_level in range(2, target_level + 1):
		_scene.level_up()
	_scene.health = roundf(_scene.max_health * 0.86)
	_scene.xp = int(_scene.xp_goal * 0.67)
	_scene.guard_reserve = _scene.guard_capacity * 0.88
	_scene.effects.clear()
	_clear_toasts()


func _clear_toasts() -> void:
	for child in _scene.hud.get("_toasts").get_children():
		_scene.hud._dispose_toast(child)


func _crowd(offset: int = 0, count: int = 16) -> void:
	var places := [
		Vector2(75, 250), Vector2(425, 270), Vector2(170, 305), Vector2(327, 290),
		Vector2(96, 383), Vector2(259, 388), Vector2(448, 405), Vector2(70, 485),
		Vector2(405, 518), Vector2(170, 570), Vector2(348, 566), Vector2(470, 675),
		Vector2(115, 770), Vector2(373, 818), Vector2(252, 832), Vector2(465, 836),
		Vector2(76, 645), Vector2(201, 448), Vector2(370, 426), Vector2(337, 731),
	]
	for index in range(mini(count, places.size())):
		var enemy: Dictionary = _scene.spawn_enemy((offset + index * 7) % 100, false, places[index])
		enemy.age = 1.75 + index * 0.13
		enemy.anim = fmod(index * 0.73, 4.0)
		if index % 5 == 0:
			enemy.hp *= 0.72


func _ranged_index(behavior: String, occurrence: int = 0) -> int:
	var found := 0
	for index in range(_scene.roster.size()):
		if str(_scene.roster[index].behavior) == behavior:
			if found == occurrence:
				return index
			found += 1
	return 0


func _fans(waves: int = 2) -> void:
	var shooters: Array[Dictionary] = []
	for index in range(3):
		var enemy: Dictionary = _scene.spawn_enemy(_ranged_index("fan", index), false, Vector2(115 + index * 152, 330 + index % 2 * 45))
		enemy.age = 4.25
		enemy.aim = (_scene.player_pos - enemy.pos).normalized()
		shooters.append(enemy)
	for wave in range(waves):
		for shooter in shooters:
			_scene._fire_enemy(shooter)
		_scene._update_bullets(0.40)


func _loot() -> void:
	for index in range(12):
		_scene._drop(Vector2(145 + index % 4 * 76, 685 + int(index / 4) * 51), "xp", 2)
	_scene._drop(Vector2(94, 725), "heart", 22)
	_scene._drop(Vector2(427, 740), "hurricane", 1)


func _compose(index: int) -> void:
	match index:
		0:
			_base("sword", 72, 6, 2840)
			_crowd(3, 17)
			_fans(2)
			_loot()
			_scene.perform_slash(Vector2.UP)
			_scene.slash_time = 0.17
		1:
			_base("shield", 184, 11, 8924)
			_crowd(28, 17)
			_scene.guarding = true
			_scene.parry_timer = 0.24
			_scene.move_direction = Vector2.ZERO
			_fans(3)
			_scene._add_bullet(_scene.player_pos + Vector2(24, -10), Vector2.DOWN * 160, 12)
			_scene._update_bullets(0)
			_scene._burst(_scene.player_pos + Vector2(-26, -18), Color("b0edf1"), 9)
			_loot()
		2:
			_base("sword", 326, 16, 16820)
			_scene.player_pos = Vector2(310, 708)
			_crowd(45, 13)
			_scene.boss_number = 4
			var boss: Dictionary = _scene.spawn_enemy(100, true, Vector2(270, 315))
			boss.hp = boss.max_hp * 0.63
			boss.age = 7.45
			boss.phase = 0
			boss.aim = (_scene.player_pos - boss.pos).normalized()
			_scene._fire_enemy(boss)
			_scene._update_bullets(1.35)
			boss.aim = boss.aim.rotated(0.22)
			_scene._fire_enemy(boss)
			_scene._update_bullets(0.70)
			boss.phase = 1
			_scene._fire_enemy(boss)
			_scene._update_bullets(0.52)
			_fans(2)
			_loot()
		3:
			_base("sword", 113, 8, 4890)
			_scene.player_pos = Vector2(192, 687)
			_crowd(17, 18)
			_fans(2)
			_scene.dragging = true
			_scene.active_touch = 0
			_scene.touch_origin = Vector2(376, 829)
			_scene.touch_position = Vector2(418, 785)
			_scene.try_dash(Vector2(1, -0.38))
			for step in range(6):
				_scene.elapsed += 1.0 / 60.0
				_scene._update_player(1.0 / 60.0)
				_scene._process(1.0 / 60.0)
			_loot()
		4:
			_base("shield", 223, 14, 12640)
			_crowd(54, 16)
			_scene.player_pos = Vector2(266, 663)
			_scene.spawn_enemy(_ranged_index("tank", 1), false, Vector2(170, 485))
			_scene.spawn_enemy(_ranged_index("tank", 2), false, Vector2(371, 536))
			_scene.spawn_enemy(_ranged_index("tank", 3), false, Vector2(370, 667))
			_scene.collect_drop({"kind": "spark", "value": 1})
			_scene.collect_drop({"kind": "ward", "value": 1})
			_scene._chain_lightning()
			_loot()
			_clear_toasts()
		5:
			_base("sword", 351, 18, 22860)
			_crowd(76, 18)
			_scene.combo = 36
			_scene.best_combo = 36
			_scene.collect_drop({"kind": "hurricane", "value": 1})
			_scene.collect_drop({"kind": "magnet", "value": 1})
			for target in range(6):
				var point: Vector2 = _scene.player_pos + Vector2.from_angle(-2.40 + target * 0.43) * 82
				_scene.spawn_enemy((target * 11) % 100, false, point, true)
			_scene.perform_slash(Vector2.UP)
			_scene.slash_time = 0.17
			_loot()
			_clear_toasts()
		6:
			_scene.start_run("sword")
			_scene.run_seed = 125000
			_scene.rng.seed = _scene.run_seed
			_scene.loot_rng.seed = _scene.run_seed ^ 1234567
			_scene.visual_rng.seed = 876543
			_scene.world.reset()
			_scene.elapsed = 0
			_scene.visual_time = 0.37
			_scene._show_launch()
			_clear_toasts()
		7:
			_base("shield", 234, 15, 14780)
			_scene.kills = 284
			_scene.bosses = 4
			_scene.best_combo = 42
			_crowd(11, 18)
			_loot()
			_scene.end_run()
			_clear_toasts()
